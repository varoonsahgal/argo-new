# Session 4 · Module 2 — Sync Ordering and Drift

> **Day 1 · Session 4 · Module 2 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** read a sync as an *ordered* operation (phase → wave → kind → name), and understand what prune and self-heal really do.

---

## 1. A sync is ordered: phase → wave → kind → name

A sync is not one big `kubectl apply`. It is an **ordered** operation decided by four keys, checked in this exact priority: **phase → wave → kind → name.**

> **Read each arrow as "then, only to break a tie."** [Module 1.5](01b-sync-order-phases-waves-kinds-names.md) defines all four words and has you predict, watch, and break the order in a real sync. This section is the summary.

**The 20-second version, using Module 1.5's airport:**

| Step | Airport | Argo CD |
| --- | --- | --- |
| 1 | Pre-boarding, before any group is called | `PreSync` hooks run first and must succeed |
| 2 | Groups are called lowest number first; the agent waits until each group is seated | Waves run lowest first; Argo CD waits until each wave is healthy before starting the next |
| 3 | Within a group, a fixed seating order | Within a wave, sorted by kind, then by name |
| 4 | After the doors close | `PostSync` hooks run after everything is healthy |

Below is the same idea drawn for the storefront chart you deploy in Lab 3.

```text
 PHASE:      PreSync                 │  Sync (ordered by wave)                     │  PostSync
             (hooks that must run    │                                             │  (hooks after
              before anything else)  │                                             │   success)
 ───────────────────────────────────┼─────────────────────────────────────────────┼───────────────
 storefront  ┌───────────────────┐  │  wave -1        wave 0            wave 0      │
 example:    │ Job               │  │  ┌───────────┐  ┌────────────┐   ┌─────────┐  │  (none in this
             │ storefront-       │─▶│  │ ConfigMap │─▶│ Service     │─▶│ Deploy   │ │   chart)
             │ migration         │  │  │ (wave -1) │  │ (wave 0)    │  │ (wave 0) │ │
             └───────────────────┘  │  └───────────┘  └────────────┘   └─────────┘  │
              must SUCCEED first      lower wave first    ~2s wait, waits for Healthy
```

- **Phase dominates.** A PreSync hook runs before *everything* — even a wave `-1` Sync resource. If the PreSync migration Job **fails, none of the Sync-phase resources are created.** That is the point of a PreSync migration: no new code rolls out against an un-migrated database.
- **Waves build low-to-high — and tear down high-to-low.** During a *sync*, wave `-1` precedes wave `0`. During a *prune/delete*, the order **reverses** (higher waves removed first), like dismantling something built in layers.
- **Argo CD waits for each wave to report Healthy before starting the next wave**, plus a short pause of about 2 seconds (set by `ARGOCD_SYNC_WAVE_DELAY`). The waiting happens only *between* waves: when nothing comes after the last wave, the sync can report `Succeeded` while that last wave is still starting up.
- **A resource with no meaningful health check makes wave ordering ineffective** — it "completes instantly" regardless of readiness, so the next wave starts too early. This is the real reason waves sometimes appear not to work (custom health checks, Session 7).

---

## 2. See the ordering annotations in the real chart

**▶ Do this now — render the storefront chart and look at the ordering hints** (in `~/storefront-gitops` from Module 1):

```bash
helm template storefront charts/storefront -f envs/dev/values.yaml \
  | grep -E 'kind:|sync-wave|hook:'
```

**Expected output** (kinds interleaved with their ordering annotations):

```text
kind: ConfigMap
    argocd.argoproj.io/sync-wave: "-1"
kind: Service
    argocd.argoproj.io/sync-wave: "0"
kind: Deployment
    argocd.argoproj.io/sync-wave: "0"
kind: Job
    argocd.argoproj.io/hook: PreSync
```

**🔍 Notice:** the **text order** in the file is *not* the apply order. The ConfigMap carries `sync-wave: "-1"` (created first among Sync resources), the Service and Deployment are wave `0`, and the migration `Job` is a `PreSync` **hook** — so it runs *before* all of them. Argo CD reads these annotations to build the timeline above.

---

## 3. Drift and self-heal

Argo CD does not *block* a change to the cluster — your edit goes through, and Argo CD *discovers* the difference afterwards by comparing live state with Git. How quickly depends on what changed:

- **A hand edit to something Argo CD manages** (`kubectl scale`, `kubectl edit`): the application controller watches those objects, so it compares again almost at once. The app shows `OutOfSync` within a second or two — no timer, no **Refresh** needed.
- **A new commit in Git:** Argo CD checks Git on a timer (`timeout.reconciliation`, **60 seconds** in this course) unless a webhook or a **Refresh** tells it sooner.

Here is the difference self-heal makes to a hand edit:

```text
 SELF-HEAL OFF                                  SELF-HEAL ON
 ─────────────                                  ────────────
 t0  you: kubectl scale --replicas=5            t0  you: kubectl scale --replicas=5
 t1  seconds later: compare → OutOfSync         t1  seconds later: compare → OutOfSync
     (Healthy)                                      (Healthy)
 t2  ...stays OutOfSync indefinitely            t2  controller RE-APPLIES desired state
     (Argo CD reports drift, changes nothing)   t3  back to Synced; your change is GONE
```

- **With self-heal off**, scaling live replicas 1→5 makes only **sync** change (→ `OutOfSync`); it *stays* there, while **health** stays `Healthy` (five replicas of a working app still work). This is the cleanest proof that sync and health are independent axes — you will run exactly this in Lab 3.
- **Drift is discovered, not prevented.** Argo CD is not an admission controller blocking your change: the edit succeeds, and for a short window the cluster really is different from Git. That window is seconds for a hand edit to a resource Argo CD manages, and up to one Git check (60 s here) for a new commit.
- **Self-heal does not block your edit — it outlives it.** Your `kubectl scale` *succeeds*; the next reconciliation undoes it. During an incident this feels like the system fighting you. The escape hatch is *not* to keep re-editing — it is to disable automated sync on that one Application, stabilize, then commit.

---

## 4. Sync options, and the two adoption rules

Set per-Application (`spec.syncPolicy`) or per-resource (`argocd.argoproj.io/sync-options` annotation). Recognize them; know where to look.

| Option / setting | What it does | When |
|---|---|---|
| `Prune=false` | Refuses to delete a specific resource even if it leaves Git | Protect something you never want auto-deleted |
| `PruneLast=true` | Defers pruning to a final wave, after everything else is Healthy | Avoid deleting the old version before the new one is up |
| `CreateNamespace=true` | Creates the destination namespace if missing | First deploy into a new namespace |
| `ServerSideApply=true` | Uses server-side apply | Large manifests or fields shared with other controllers |
| `retry` (limit, backoff) | Re-attempts a **failed** sync on a backoff schedule | Transient failures (slow image pull, brief API hiccup) |

> **The two rules worth memorizing: turn on self-heal early; turn on prune late.** Self-heal's worst case is an *argument* (it reverts a manual edit — reversible). Prune's worst case is a *deletion* (someone renames a directory; everything under the old path is now "not in Git"; prune removes it — the 3 a.m. incident). That is why `Prune=false` and `PruneLast=true` exist, and why prune deserves a slower, per-application rollout.

---

## 5. Quick Checks

**S4-QC3 — Automated sync on, prune off. A file is deleted from Git.** Someone deletes `service.yaml`; the Service is still running live. What does Argo CD do at the next sync, and what does status show?

<details>
<summary>Show answer</summary>

**Argo CD leaves the live Service running and reports `OutOfSync`.** Desired state no longer includes the Service, so the comparison differs (it shows "requires pruning") — but because **prune is off**, automated sync will **not** delete it. Nothing disappears; the app sits `OutOfSync` until someone prunes deliberately or restores the file. This is exactly why "turn on prune late" is the rule — a deleted file is more often a mistake than an intent.
</details>

**S4-QC4 — Order six resources.** Deployment `web` (Sync, wave 0), Job `db-migration` (PreSync, wave 0), ConfigMap `app-config` (Sync, wave −1), Deployment `api` (Sync, wave 0), Service `api` (Sync, wave 0), Job `smoke-test` (PostSync, wave 0).

<details>
<summary>Show answer</summary>

1. **`db-migration`** (PreSync — before everything). 2. **`app-config`** (Sync, wave −1). 3. **`api` Service** (wave 0; kind order puts Service before Deployment). 4. **`api` Deployment** (wave 0; name lists `api` before `web`). 5. **`web` Deployment** (wave 0 — sent to the cluster at the same moment as `api`, because same-kind resources in one wave go together). 6. **`smoke-test`** (PostSync — last). Keys are checked strictly: **phase → wave → kind → name.** Phase dominates even a wave −1 resource.
</details>

---

## 6. Key takeaways

- **A sync is ordered by phase → wave → kind → name** — pre-boarding, then boarding groups, then seat order. PreSync hooks run first; waves build low-to-high and tear down high-to-low; Argo CD waits for Healthy (plus ~2s) between waves — and a resource with no health check makes waves ineffective.
- **Drift is discovered after it happens, not blocked.** A hand edit to a managed resource shows up within seconds; a new Git commit within one Git check (60 s here). With self-heal off, drift shows as `OutOfSync` + `Healthy` and *stays*; with self-heal on, it is reverted.
- **Self-heal argues (reversible); prune deletes (not).** Turn self-heal on early, prune on late.

**→ Next:** [03 — Promotion and recovery](03-promotion-and-recovery.md)
