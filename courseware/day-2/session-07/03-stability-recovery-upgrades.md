# Session 7 · Module 3 — Stability, Recovery, and Upgrades

> **Day 2 · Session 7 · Module 3 of 3 · ~30 minutes · concept + hands-on**
> **Goal:** keep Argo CD stable, observable, and recoverable — HA, sharding, backup/recovery, and safe upgrades.

---

## 1. What HA actually buys you, component by component (V-26)

"Turn on HA" is not one switch — each component fails differently. This course runs the **non-HA** install (one replica each) so you can watch a single component's outage cleanly.

**▶ Predict first:** which component's outage causes **no data loss and no stopped syncs** — only a slowdown?

| Component | Verb | What stops when down | Data loss? | What keeps working |
|---|---|---|---|---|
| **server** (API/UI) | *talks* | logins, UI, API, webhooks | None | controllers keep reconciling/syncing unattended |
| **repo-server** | *renders* | new/changed manifests can't render | None | cached renders; running workloads |
| **application-controller** | *compares & applies* | drift detection + syncing for clusters on the down shard | None | clusters on *other* shards keep reconciling |
| **applicationset-controller** | *generates* | generating/updating Applications from ApplicationSets | None | existing generated apps keep reconciling |
| **redis** | *remembers* | nothing — caches must **rebuild** | **None** | everything, more slowly |
| **notifications-controller** | *announces* | outbound alerts | None | all deployment behavior |

**Prediction answer: Redis.** It holds *only* a cache, so losing it costs a rebuild (CPU + latency) but **never** data — which is why "back up Redis" is backing up the wrong thing.

---

## 2. Controller load and sharding (V-27) — splits *clusters*, not Applications

When the application-controller is overloaded, the instinct is "add a replica." That works **only if you have multiple clusters**, because **the controller distributes clusters across replicas, not Applications.**

**▶ Predict:** your busiest cluster holds 5,000 Applications and its controller is maxed. You add a second replica. Does that cluster get faster?

```text
  MANY CLUSTERS (sharding helps)          ONE HUGE CLUSTER (sharding does NOT help)
  Replica 0 → cluster-1, cluster-2        Replica 0 → cluster-BIG (5,000 apps)
  Replica 1 → cluster-3, cluster-4        Replica 1 → (nothing)
  Replica 2 → cluster-5, cluster-6        Replica 2 → (nothing)
  Load spreads; adding replicas           A cluster can't split across replicas —
  rebalances whole clusters.              extra replicas sit idle. Fix is ARCHITECTURAL.
```

**Prediction answer: no.** A single cluster is a single shard; it cannot be split, so the extra replica sits idle. The fix is **architecture** — more clusters, or a bigger single shard.

---

## 3. Repo-server pressure, observability, and ignore rules (compressed)

**Repo-server pressure** has three drivers: **memory/OOMKills** (rendering holds output in memory; the lever is `--parallelismlimit`); the **one-render-per-repo constraint** (if rendering must *write* files in the clone, like `helm dependency build`, only one concurrent generation per repo is allowed — a monorepo can feel serialized even with idle CPU); and the **90-second exec timeout** (`ARGOCD_EXEC_TIMEOUT`) — a chart that grows slowly can one day render in 95s and fail *on a day nobody changed it*.

**Observability** — with no Prometheus/Grafana here, read the same numbers directly: `kubectl top pod -n argocd` (live CPU/memory), the component `/metrics` endpoints (controller `:8082`, server `:8083`, repo-server `:8084`), Kubernetes events on the **workload** cluster, and the notifications-controller for outbound signals. **The key lesson is alert design:** the obvious alert ("an app is `OutOfSync`") is *wrong* — it fires constantly and gets muted. The alert that carries information is **compound**: an app has been `OutOfSync` **and** has automated sync **and** has not converged for N minutes. **Alert on failure to converge, not on `OutOfSync`.** That "N minutes" *is* your SLA (service-level agreement) written as a threshold.

**Health checks and ignore rules** shape what Argo CD *tells* you. A **custom health check (Lua)** teaches Argo CD to judge a CRD it does not recognize — a *good* use (makes a badge mean more). **`ignoreDifferences`** tells Argo CD to stop reporting a field as drift — necessary (an autoscaler edits `/spec/replicas`), but the same mechanism, aimed carelessly, hides a *real* change forever.

```yaml
# SAFE — field-scoped, clear owner (the HPA owns replica count):
ignoreDifferences: [{ group: apps, kind: Deployment, jsonPointers: [/spec/replicas] }]
# DANGEROUS — ignores the ENTIRE spec; a changed image or removed securityContext
# becomes invisible. Nobody owns "the whole spec" — a permanent blind spot.
ignoreDifferences: [{ group: apps, kind: Deployment, jsonPointers: [/spec] }]
```

> **The discipline in one sentence:** every ignore rule should name a **field**, not a resource, and needs a written **owner**. If nothing owns the field, you have not reduced risk — you have built a place for drift to hide.

**Capacity factors** (which dial drives which component): number of **Applications**, **resources per app**, and **clusters** → application-controller; number of **repositories**, **repository size** (monorepos), and **change rate** → repo-server. Read a row and you can predict the symptom.

---

## 4. Backup, and recovery from a lost management cluster (V-28)

Argo CD is *largely stateless*: Applications, projects, the `argocd-cm`/`argocd-rbac-cm` ConfigMaps, and the repository/cluster **Secrets** live as Kubernetes objects in the management cluster's **etcd**. Redis is a disposable cache.

**Whatever is genuinely in Git does not need *restoring* — it needs *re-applying*.** What *does* need backing up is the part that never made it into Git — credentials in the Secrets, and anything configured through the UI. `argocd admin export` captures it:

```bash
argocd admin export -n argocd > backup.yaml   # read it back with: argocd admin import - < backup.yaml
```

> **The size of your export file is a receipt for everything you forgot to declare in Git.** A large export from a mature GitOps setup is a warning sign, not a comfort.

**Recovery when the whole management cluster is lost** (V-28) — Git lives *outside* both clusters, so desired state survived; recovery is a **rebuild**:
1. Stand up a fresh management cluster; install the *same* Argo CD version the same declarative way.
2. Re-apply what is in Git (often one root App-of-Apps). Argo CD tracks resources by annotation, so it **re-adopts** the already-running workloads rather than redeploying them.
3. Import the parts never in Git from your export — chiefly the repository/cluster **Secrets**.
4. Let Redis rebuild itself (you do nothing).
5. Verify with the method — `argocd app get` across the fleet until `Synced`/`Healthy`.

**The reframe:** if Argo CD is truly declarative, losing the management cluster is a *rebuild, not a disaster.* The only irreplaceable pieces are the credentials in those Secrets — which is why the export exists and must be protected as sensitive.

---

## 5. Upgrades (V-29) — the renderer is part of your desired state

The most dangerous misconception is "an upgrade is only a version bump." **Argo CD renders your charts, so its bundled Helm version is part of your desired state.** Change the renderer and *the same chart with the same values can produce different YAML,* with no one touching Git. Real case: **Argo CD 3.5 moved to Helm 4** (v4.2.1) as the only renderer, changing `null` coalescing — so upgrading 3.4 → 3.5 alone can change rendered manifests.

The upgrade timeline: **read release notes** end-to-end → **compatibility test** (the real work: *render your real charts with the new version's Helm and diff the output* — a non-empty diff is a change you are about to ship; also check the tested-Kubernetes **compatibility matrix** and bump the `argocd` CLI to match the server minor) → **canary** one non-critical Argo CD first → **rollback criteria written in advance**. Two disciplines: **match Argo CD to Kubernetes** (this lab's k3s `v1.35.8` sits inside supported lines), and **change one variable at a time** (never upgrade Argo CD and Kubernetes the same day). **Rehearse the render, not just the rollback.**

> **Operating an internal fork (compressible).** A **fork** moves you from *consuming* upstream's work to *producing* it — permanently. Before forking, price the jobs you now own forever: upstream tracking, **CVE** response (you merge/rebuild/test/release the patch yourself), image build and **provenance**, regression testing against your patches, release cadence, and minimizing divergence. **Forking is not wrong — it is priced.** Often the cheaper answer is to contribute upstream instead.

---

## 6. Hands-on: export Argo CD's own state (read-only)

**▶ Do this now** (reads Argo CD's state and writes a file in your home dir — changes nothing):

```bash
argocd admin export -n argocd > backup.yaml
grep -E '^kind:' backup.yaml | sort | uniq -c
```

**Expected shape** (counts vary with lab state):

```text
   4 kind: AppProject
   8 kind: Application
   1 kind: ApplicationSet
   4 kind: ConfigMap
   5 kind: Secret
```

**🔍 Notice what the list *is*:** the **ConfigMaps** are Argo CD's configuration; the **AppProjects/Applications/ApplicationSets** are your declared desired state (which *should* also live in Git); and the **Secrets** are the credentials — usually the parts **not** in Git, and the reason the export exists. Clean up: `rm -f backup.yaml`. *(Passing `-n argocd` matters — point it elsewhere and it fails loudly rather than writing a useless file.)*

---

## 7. Quick Checks

**S7-QC2 — Three failures, three impacts.** State what stops and whether data is lost: (a) delete the **Redis** pod; (b) the **repo-server** is **OOMKilled**; (c) one **application-controller shard** is lost.

<details>
<summary>Show answer</summary>

**(a)** Nothing stops, no data lost — Redis is a disposable cache; the only cost is a rebuild spike. **(b)** Rendering stops (new syncs/refreshes error with `ComparisonError`/`Unknown`); no data lost; running workloads untouched; fix is resources (more memory / lower `--parallelismlimit`). **(c)** The clusters owned by that shard stop reconciling; other shards unaffected; no data lost — the blast radius of a lost shard is *its clusters*. None causes data loss, because Argo CD's real state is Kubernetes objects.
</details>

**S7-QC3 — Safe rule or blind spot?** A team ignores `/spec/template/spec/containers/0/image`. Safe or concealing?

<details>
<summary>Show answer</summary>

**Concealing.** *Nothing legitimately owns the image except your Git source* — it is the single most important thing GitOps keeps honest. Ignoring it means someone (a hotfix, a rollback, an attacker) could change the running image and Argo CD would report `Synced` forever. The test: **name the owner.** For `/spec/replicas` the owner is real (the HPA); for the image, the honest answer is *nothing* — so it is a blind spot, not silenced noise.
</details>

**S7-QC4 — An upgrade changed the manifests, no one touched Git.** You upgrade 3.4 → 3.5 and apps go `OutOfSync` with no commits. What happened, and what test would have caught it?

<details>
<summary>Show answer</summary>

**Argo CD 3.5 bundles Helm 4, which changed `null` coalescing** — the same chart+values renders different YAML under the new renderer; the renderer is part of your desired state. The test: **render your real charts with the new Helm and diff the output before upgrading** (plus check the tested-Kubernetes matrix, match the CLI, change one variable at a time). *(Fork bonus: a CVE fix you now merge/rebuild/test/release yourself instead of consuming.)*
</details>

---

## 8. Common misconceptions

- **"Restarting pods is a diagnosis."** A restart is an *intervention*, not evidence — often harmful (erases logs/state, makes a healthy component look guilty). It belongs at step 5 at the earliest, only after steps 1–4 name the suspect.
- **"Redis loss means data loss."** Redis is a cache; Argo CD's real state is Kubernetes objects in etcd. Back up the export and keep desired state in Git.
- **"Ignore rules reduce risk."** They reduce *noise*. A field-scoped rule with a named owner is hygiene; a broad rule or one over a field nothing owns *increases* risk.
- **"An upgrade is only a version bump."** The renderer is part of your desired state — rehearse the render, not just the rollback.

---

## 9. Key takeaways

- **Walk the pipeline in the direction the data flows, and stop at the first step that lies.**
- **Each step names one component — find the step and you have found the pod.**
- **Evidence before change, source before platform.**
- **Sharding splits clusters, not Applications** — an HA controller protects you cluster-by-cluster.
- **Argo CD's real state is Kubernetes objects; Redis is disposable.** Losing the management cluster is a rebuild from Git plus an export.
- **An upgrade can change your manifests with no Git change** — rehearse the render before the rollback.

---

## Transition — to the Capstone

You now have a **repeatable method** you can run under pressure — turn "everything is red and my phone is ringing" into "walk the six steps, stop at the first lie, fix it in Git" — plus what it takes to keep Argo CD stable, observable, and recoverable.

The **[Capstone](../capstone-restore-platform.md)** is this method applied for real, to **several connected faults at once**: a rendering problem, a blast-radius surprise, an ownership tangle, a permission denial, a disconnected cluster, a degraded workload hiding behind noisy drift, a component under pressure. Your job is exactly the discipline you just learned: **identify the failure layer with evidence before you change anything.** Bring V-25, the two rules (*evidence before change, source before platform*), and the habit of naming the step, then naming the pod.

**→ Next:** [Capstone — Restore an Argo CD Deployment Platform](../capstone-restore-platform.md)
