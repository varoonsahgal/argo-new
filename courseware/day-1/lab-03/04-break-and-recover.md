# Lab 3 · Module 4 — Break It Two Ways and Recover

> **Day 1 · Lab 3 · Module 4 of 4 · ~15 minutes**
> **Goal:** introduce a rendering failure and an ordering failure, notice they surface in **different places**, recover both through Git (**E5**), then confirm the Day 1 outcome.

---

## Exercise 5 — Break it two ways, and recover through Git

**Difficulty / time:** Challenging · ~15 minutes.

> **The one distinction to hold onto:** a **rendering** failure means the repo-server could not turn Git into manifests at all (it shows as an Application **condition / `ComparisonError`** — nothing gets applied). A **sync/ordering** failure means the manifests rendered fine but something failed *while applying* (it shows inside the **sync result** — a hook or wave failed). Same redness, different owner, different fix.

### Part A — a rendering failure (break the *reference*, not the YAML)

**Do it:** in `platform-config`, edit the `storefront-staging` Application so its `helm.valueFiles` points at a file that **does not exist** (e.g. append `-DOESNOTEXIST` to the filename). Commit, apply to the management cluster, refresh `storefront-staging`.

**▶ Predict first:** will this show as a *comparison/condition* error on the Application, or a *failed sync*? Which component — repo-server or controller — failed?

![storefront-staging ComparisonError from a missing values file (v3.5.2)](../../assets/screenshots/day-1/lab-03-08-comparison-error.png)

*Figure SS-L3-08 — After Part A: a **ComparisonError** condition — the repo-server could not render because the referenced values file is missing.*

**🔍 Notice:** the error is an Application **condition** (`ComparisonError`) at the app level — **not** inside a sync result. The message names the **missing values file**. Nothing on the cluster changed: with no rendered manifests, there was nothing to apply.

<!-- CAPTURE-SPEC: SS-L3-08 — Application error condition. State: after Part A broken valueFiles. Highlight: ComparisonError banner, no sync result changes. Argo CD v3.5.2. -->

**Recover:** restore the correct `valueFiles` reference **through Git** (a `git revert` of the breaking commit is cleanest), apply, refresh. Confirm the `ComparisonError` clears.

### Part B — an ordering failure (a gate that never opens)

The chart ships a **PreSync** "database migration" Job. When `migration.shouldFail` is `true`, the Job runs `exit 1` and, with `backoffLimit: 0`, fails immediately and permanently. Since it is a **PreSync** hook, the **Sync** phase after it — your `ConfigMap`, `Deployment`, `Service` — **never runs**.

**Do it:** in `storefront-gitops`, set `migration.shouldFail: true` in `envs/dev/values.yaml`. Commit and push. Because `storefront-dev` now has auto-sync on, Argo CD attempts the sync on its own.

**▶ Predict first — Job, Secret, or wave problem?**

| Symptom | Hypothesis (Job / Secret / wave) | Where is the evidence? (hook result / diff / events) |
|---|---|---|
| The sync operation is **Failed** | *?* | *?* |
| The Deployment did **not** update | *?* | *?* |

![storefront-dev failed PreSync Job; later waves not applied (v3.5.2)](../../assets/screenshots/day-1/lab-03-09-presync-hook-failed.png)

*Figure SS-L3-09 — After Part B: the PreSync migration Job **failed**, the sync **operation Failed**, and later Sync-phase resources were never applied.*

**🔍 Notice:** the PreSync Job node is red; the **sync operation** is **Failed** inside the sync result (not an app-level condition); the `Deployment`/`Service` did **not** change — the gate never opened.

<!-- CAPTURE-SPEC: SS-L3-09 — Failed sync with PreSync hook. State: after Part B shouldFail=true. Highlight: failed PreSync Job; operation Failed; later resources not applied. Argo CD v3.5.2. -->

**Recover:** set `migration.shouldFail` back to `false` **through Git** and push. Because a failed sync of the *same* commit is not retried automatically, your *new* commit is what lets Argo CD sync cleanly. Watch the PreSync Job succeed and later waves apply in order.

**Then justify your choice — revert vs roll forward.** For each part, write one line: did you **revert** (restore last known-good because you were not yet sure) or **roll forward** (commit a fix because you understood it)? Rule: revert when you do not know why; roll forward when you do — and `git revert` leaves a reviewable receipt either way.

![Both apps Synced/Healthy after recovery (v3.5.2)](../../assets/screenshots/day-1/lab-03-10-recovered.png)

*Figure SS-L3-10 — After E5: both apps back to `Synced` / `Healthy` at your latest commit; recovery commits visible in each repo's `git log`.*

<!-- CAPTURE-SPEC: SS-L3-10 — Applications list, recovered. State: after E5 recovery. Highlight: both apps Synced+Healthy. Argo CD v3.5.2. -->

**Success criterion:**
- After Part A, `storefront-staging` has **no** `ComparisonError` and is `Synced`/`Healthy`.
- After Part B, `storefront-dev`'s PreSync Job **succeeds**, the app is `Synced`/`Healthy`, and `argocd app history storefront-dev` shows the recovery as a new revision.
- You can name, for each part, **which component** owned the failure and **which repo** held the fix.

**Hints:**
- *Hint 1:* Part A — read the Application's **conditions**, not the sync result. A rendering failure never reaches the sync result.
- *Hint 2:* Part B — the failing thing is a Job, but the *cause* is a PreSync gate blocking everything after it. Ask "what did this Job stop from running?"
- *Hint 3:* If Part B stays stuck after you fix the value, confirm you **pushed** a *new* commit — Argo CD will not re-attempt the identical failed commit.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `kubectl` shows "nothing there" | Wrong `--context` | `--context k3d-workload` for workload resources, `k3d-mgmt` for Argo CD's objects — the top self-inflicted failure |
| New `storefront-staging` rejected: *"destination … not permitted in project 'storefront'"* | AppProject still permits only `storefront-dev` | Add the `storefront-staging` destination to `projects/storefront.yaml`, commit, re-apply |
| **`ComparisonError`** condition, no sync result | A **rendering** failure (missing `valueFiles`/required value). Owner: repo-server | Fix the reference in its repo, refresh; nothing was applied |
| **Failed sync operation** with a red hook | A **sync/ordering** failure. Owner: application-controller | Read the sync result + hook logs; fix desired state in Git, push a **new** commit |
| Self-heal "won't stay" after a manual edit | Working as configured | The durable change is a commit; during an incident disable auto-sync on that app, stabilize, then commit |
| Drift/fix "takes a while" (~60 s) | Differences discovered on the comparison loop | **Refresh** forces an immediate comparison; **Hard Refresh** also re-renders |
| After promoting `6.16.0`, Deployment `Degraded` / `ImagePullBackOff` | Offline classroom, tag not pre-loaded | `git revert` the promotion to `6.15.0`, push, sync (a real roll-forward-failed → revert moment) |
| Part B stays failed after you fix the value | Argo CD does not re-attempt the identical failed commit | Ensure your fix is a **new** pushed commit; `git revert` produces exactly that |

---

## Checkpoint / validation — the Day 1 outcome

You have met the Day 1 outcome when **both** environments are healthy at your latest commit **and** you can say where you would look first for the four failure classes.

**▶ Do this now:**

```bash
argocd app list -o wide
```

Cross-check: (1) both `storefront-dev` and `storefront-staging` are `Synced`/`Healthy`; (2) each app's revision equals `git -C storefront-gitops rev-parse HEAD`; (3) each serves (`curl` returns `storefront DEV` / `storefront STAGING`).

**Then write a three-line note** for each failure class — *(a)* first place you'd look, *(b)* which component owns that layer, *(c)* which repo/object holds the fix:

| Failure class | You experienced it in… | Your three-line note |
|---|---|---|
| **Repository / access** | Lab 2 (repo would not connect) | *(a) … (b) … (c) …* |
| **Rendering** | E5 Part A (`ComparisonError`) | *(a) … (b) … (c) …* |
| **Synchronization / ordering** | E5 Part B (failed PreSync hook) | *(a) … (b) … (c) …* |
| **Health** | E1/E3 (health vs sync) | *(a) … (b) … (c) …* |

If you can produce those four notes without looking anything up, you have the diagnostic method Day 2 assumes.

> **You just used the troubleshooting method's first four steps** — validated the Git source/revision, validated access and rendering, compared rendered vs live, and inspected sync results/hooks/events. Session 7 names these and adds two more.

---

## Key takeaways

- **`helm list` is empty and that is correct** — Argo CD borrows Helm's typewriter and throws away its filing cabinet. No release to roll back — only a commit to revert.
- **Drift is discovered, not detected** — it appears on the next comparison (~60 s here); Refresh forces it early.
- **Sync and health are independent** — scaling made the app `OutOfSync` but `Healthy`. Which axis moves tells drift from an outage.
- **Self-heal outlives your edit** — `kubectl edit` becomes a suggestion. Git wins because someone chose that Git should win.
- **A rendering failure and an ordering failure are equally red and live in different places** — repo-server (Application condition / `ComparisonError`, nothing applied) vs controller (failed sync result, later phases blocked).
- **Recover through Git, prefer `git revert`** — revert when you do not know why; roll forward when you do. Either way it leaves a receipt.

---

## Optional stretch challenges (outside the timebox)

1. **Rollback is blocked under auto-sync — see it, then explain it.** With auto-sync on for `storefront-dev`, open **History and Rollback** and try to roll back. Predict first. The action is **blocked** — Argo CD would re-sync forward and undo it. Write two sentences: *why* is this refusal correct, and what is the GitOps-consistent way to "roll back"? (A rollback is a cluster action; desired state still says "go forward." The consistent move is `git revert` in the source repo.)

2. **Add retry with backoff and watch it.** Give `storefront-dev` a `syncPolicy.retry` block (small `limit`, a `backoff`). Re-introduce the Part B failure and watch Argo CD **re-attempt the same failing sync** on the schedule — and note the scope: retry re-runs a sync that *failed while executing*; it does **not** invent a new sync when nothing in Git changed. Remove the retry block when done.

> **Not included on purpose:** the "app that can never reach `Synced`" puzzle (a chart rendering a fresh random value each comparison) — the storefront chart is deliberately deterministic. The principle still holds: **a non-deterministic desired state can never be reconciled**, and the fix is in the chart, not Argo CD.

---

## Transition — what's next

You have finished Day 1: one Git-to-cluster deployment, run across two environments, recovered from two classes of failure without ever hand-fixing the cluster. Tomorrow the question changes from *"how do I deploy one application safely?"* to *"how do I deploy fifty without multiplying my blast radius fifty times?"*

Day 2 opens with **[Session 5 — ApplicationSets and App-of-Apps](../../day-2/05-applicationsets-and-app-of-apps.md)**, where the same chart and environments get *generated* instead of hand-written — and where a single template change can touch every environment at once.

> **Note on reset:** the Day 2 environment removes today's hand-made storefront Applications on purpose. Your instructor runs `reset-lab.sh CP-lab-04 --local` between the days.
