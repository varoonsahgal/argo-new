# Session 2 · Module 3 — Sync vs Health

> **Day 1 · Session 2 · Module 3 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** read the two independent status axes without confusing them, and know which operation (refresh / hard refresh / sync) actually changes the cluster.

---

## 1. Two independent axes

Sync status and health status are **not** two grades of the same thing. They answer different questions and move independently. Reading them as one combined "is it OK?" light is the single most common Argo CD mistake.

| | **Healthy** *(live works)* | **Progressing** *(coming up)* | **Degraded** *(broken)* |
|---|---|---|---|
| **Synced** *(matches Git)* | Boring, correct. Nothing to do. | Normal deploy in flight — Pods starting. Wait. | **You deployed exactly what Git says — and it is broken.** Bug is *in Git*. Fix forward with a commit. |
| **OutOfSync** *(differs from Git)* | Serving users fine, but cluster ≠ Git (drift or unsynced commit). **Not an outage.** | Mid-sync toward a new commit. | Broken **and** adrift — establish which came first. |

**Three things to notice:**
1. **Every cell is reachable** — any sync value can pair with any health value. "Synced therefore fine" is a fallacy; this grid is the counterexample.
2. **Top-right (`Synced` + `Degraded`)** is the "Synced but broken" scenario from Module 1 — the fix is a commit, not a re-sync.
3. **Bottom-left (`OutOfSync` + `Healthy`)** is *not* an emergency. Users are served by the current version. A short-lived `OutOfSync` is normal; one that *never converges* under automated sync is the real problem.

---

## 2. How each status is computed (different inputs)

**Sync status** — the application controller asks the repo-server to *render* the source, then *compares* rendered vs live. Match → `Synced`; differ → `OutOfSync`; couldn't complete → `Unknown`. Comparison is **read-only**; nothing changes on the cluster. **Sync status is a statement about Git.**

**Health status** — for each live resource, the controller inspects **only that resource's own live state** (a Deployment's available-vs-desired replicas, a Pod's phase) and assigns a value. The Application's health is the **worst** among its immediate children. **Health looks at live state only** — it never reads Git. That is why health can be `Degraded` while sync is `Synced`: the two share no inputs.

---

## 3. Where each value actually lives (this makes you faster than a dashboard)

- **Application-level sync status** is persisted at `.status.sync.status` on the Application object — readable with `kubectl`.
- **Application-level health status** is persisted at `.status.health.status` — also readable with `kubectl`.
- **Per-resource (child) health** is **not** persisted in the Application object by default since Argo CD 3.0. The tree shows it because the controller computes it live and caches it in Redis. For a *child* resource's current health, read the resource tree in the UI or query the live resource directly.

**▶ Do this now — read both axes straight off the object.**

```bash
kubectl --context k3d-mgmt -n argocd get application hello-reconcile \
  -o jsonpath='{.status.sync.status}{"  "}{.status.health.status}{"\n"}'
```

**Expected:**

```text
Synced  Healthy
```

**🔍 Notice:** you just read the **persisted** Application-level values directly — no dashboard needed. If the UI were down, this one command still tells you the two axes.

---

## 4. Refresh, hard refresh, and sync — only one touches the cluster

These are constantly confused. The distinction is small and vital:

- **Refresh** = *"compare again, now."* Re-reads Git and re-runs the comparison instead of waiting for the timer. Updates sync status. **Does not change the cluster.**
- **Hard refresh** = *"forget the cached render, then compare again."* Discards cached rendered manifests first, forcing a fresh render. Use it when Argo CD seems to be ignoring a repository change (a plain refresh will faithfully re-compare a **stale** render). **Does not change the cluster.** Costs real repo-server work — a diagnostic tool, not a habit.
- **Sync** = *"apply the difference."* The **only** operation that **changes the cluster**.

> **The classroom re-check timer is tuned to ~60 seconds** (product default 180s). After a Git change you may see "nothing happening" for up to a minute — that wait is the timer, not a failure. Refresh is the impatient version of waiting; a webhook (Session 3) is the production version of not waiting.

---

## 5. A reference table you will come back to

The four status values that generate the most confusion in operations:

| Status | Axis | Plain meaning | Common causes | Where to look first |
|---|---|---|---|---|
| **OutOfSync** | sync | Live ≠ rendered desired | New commit not synced; manual edit (drift); auto-sync off/stuck | Diff panel; History; is auto-sync on? — *application controller* |
| **Unknown** | sync or health | Argo CD can't determine the value | Render failed (`ComparisonError`); target cluster unreachable; no health check | *repo-server* logs (render) or cluster connectivity |
| **Progressing** | health | Live resource working toward ready | Deployment mid-rollout; Pods pulling/starting; probe not passing yet | Resource tree and Pod events; often wait it out |
| **Degraded** | health | Live resource present but not working | Crash loop; failing probe; too few resources; bad config *from Git* | Pod logs and events; then the manifest **in Git** |

Every "where to look" points back at a **verb** from Module 1. Name the symptom → name the verb → name the suspect.

---

## 6. Quick Checks

**S2-QC3 — Read four sync/health pairs.** For each, what does it mean and are users likely affected now? **A.** `Synced`+`Healthy` · **B.** `Synced`+`Degraded` · **C.** `OutOfSync`+`Healthy` · **D.** `OutOfSync`+`Degraded`

<details>
<summary>Show answer</summary>

- **A** — cluster matches Git *and* works. Boring, correct. No impact.
- **B** — matches Git but what Git describes is broken. **You shipped the bug on purpose.** Users likely affected; fix is a **new commit**, not a re-sync.
- **C** — serving users fine but cluster ≠ Git (unsynced commit or drift). **Not an outage**; risk is the divergence persisting.
- **D** — broken *and* adrift. Users likely affected. Establish sequence first: bad deploy, or drift breaking a working app?
</details>

**S2-QC4 — Which operation changes the cluster, and which fixes a "stale render"?**

<details>
<summary>Show answer</summary>

**Only `sync` changes the cluster** — refresh and hard refresh are read-only comparisons. Use **hard refresh** when Argo CD ignores a pushed change: a plain refresh re-compares the *cached* render, so if the render is stale, refresh faithfully re-reports the stale result; hard refresh discards the cache and renders fresh.
</details>

---

## 7. Common misconceptions

- **"OutOfSync means broken."** No — it is a statement about **Git**. `OutOfSync`+`Healthy` serves users fine. The real problem is an `OutOfSync` that *won't converge* under auto-sync.
- **"Synced means Healthy."** Independent axes. `Synced`+`Degraded` is real and dangerous.
- **"Argo CD stores state in its own database."** No — its state is **Kubernetes objects** (Applications, AppProjects, Secrets) in etcd. **Redis is only a cache.** Backing up Redis is backing up the wrong thing (Session 7).
- **"Refresh deploys my change."** No — refresh only re-compares. Only **sync** changes the cluster.

---

## 8. Key takeaways

- **Sync asks "does it match Git?"; health asks "is it working?"** A resource can answer yes to one and no to the other.
- **`Synced` + `Degraded` = you deployed exactly what you asked for, and it is broken. The bug is in Git.**
- **Only `sync` touches the cluster;** refresh/hard-refresh are read-only comparisons.
- Read `.status.sync.status` and `.status.health.status` off the Application object directly — faster than any dashboard.

---

## 9. Transition — what's next

You now have the machinery: the six components and their verbs, the four states, the two independent axes, the Application as a set of external dependencies, and refresh vs sync. What you have **not** done is *watch it happen*.

That is **Lab 1 — Follow an Application Through Reconciliation.** You will inspect the `hello-reconcile` Application, list its dependencies, commit one small change, and trace it stage by stage through the loop — predicting each status *before* you look, across three surfaces at once (UI, CLI, `kubectl`).

**→ Next:** [Lab 1 — Follow an Application Through Reconciliation](../lab-01/README.md)
