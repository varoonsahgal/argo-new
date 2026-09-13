# Lab 1 · Module 4 — Three Views and Wrap-Up

> **Day 1 · Lab 1 · Module 4 of 4 · ~10 minutes**
> **Goal:** compare the three states of a resource (**E3**), locate status on all three surfaces (**E4**), then confirm your checkpoint and finish.

---

## 1. Exercise E3 — Compare desired, rendered, and live

**Difficulty:** Intermediate · **Time:** ~6 minutes

**Goal:** look at the same ConfigMap in three forms — what Git says (**desired**), what Argo CD produced from the chart (**rendered**), and what is actually running (**live**) — and explain why the live version has extra fields that do *not* make the app `OutOfSync`.

**▶ Do this now — two views of the ConfigMap:**

```bash
# Rendered from Git (what Argo CD would apply, at the current revision):
argocd app manifests hello-reconcile --source git | sed -n '/kind: ConfigMap/,/^---/p'

# Live (what is actually in the cluster right now):
kubectl --context k3d-mgmt -n hello get configmap hello-reconcile -o yaml
```

**Shape of a correct answer:** a short written comparison naming **at least three fields that appear only in the live object** (absent from rendered/Git), plus one sentence on why their presence is not drift. A complete answer also finds the **resource-tracking annotation** `argocd.argoproj.io/tracking-id` on the live object and says what it does (it marks the resource as one Argo CD owns).

**Hints:**
- *Hint 1:* Kubernetes stamps every object with bookkeeping at creation. Look under `metadata` on the live object for fields no human could have written in Git (`uid`, `resourceVersion`, `creationTimestamp`, `managedFields`).
- *Hint 2:* Argo CD's comparison deliberately ignores server-populated fields — otherwise every object would look "changed" forever. That is *why* these live-only fields do not cause `OutOfSync`.
- *Hint 3:* Search the live object's annotations for `tracking-id`.

**Success criterion:** you can name three live-only fields populated by Kubernetes (not Git) and explain in one sentence why the diff ignores them, and you found the `tracking-id` annotation.

---

## 2. Exercise E4 — Locate status in three places

**Difficulty:** Intermediate · **Time:** ~4–6 minutes

**Goal:** fill a table showing *where* each piece of status lives across the three surfaces, then answer: *if the web interface were down, which surface would you use?*

**▶ Do this now — find each fact live (do not fill from memory):**

| Fact | Web interface (where?) | `argocd` CLI (which command?) | `kubectl` (which command?) |
|---|---|---|---|
| Sync status | | | |
| Health status | | | |
| Last-synced revision | | | |
| Pod events | | | |

Then answer in one or two sentences: **"If the UI were down, which surface would I use, and what (if anything) would be harder to see?"**

**Hints:**
- *Hint 1:* One `argocd` command already prints sync status, health, and revision together (`argocd app get`).
- *Hint 2:* For Pod events on `kubectl`, `kubectl --context k3d-mgmt -n hello describe pod <name>` has an Events section; in the UI, open the Pod node's events tab.
- *Hint 3:* `kubectl` can read the Application's `.status` directly with `-o jsonpath` — decide whether "last-synced revision" lives on the Application object or only in the UI.

![Argo CD Pod node events tab showing event reasons (v3.5.2)](../../assets/screenshots/day-1/lab-01-09-pod-events.png)

*Figure SS-L1-09 — The Pod node's events tab in the interface.*

<!-- CAPTURE-SPEC: SS-L1-09 — Pod node, events tab. State: shortly after E2 rollout, route /applications/hello-reconcile, Pod node selected, events tab. Highlight: event reasons (Scheduled, Pulled, Started). Fidelity: panel. -->

**Success criterion:** every row names a concrete location or command for each surface (or is marked unavailable), the values agree across each row, and you have a one-sentence answer to the "UI is down" question backed by the command you would run.

---

## 3. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| **Nothing happens for up to a minute** after `git push` | The reconciliation timer (`~60s`) has not fired. **Not** a failure. | Wait, or click **Refresh**. |
| Commands run against the wrong cluster; resources "missing" | `kubectl` used a different context. | Always include `--context k3d-mgmt`; confirm with `kubectl config current-context`. |
| `git push` rejected / repeated password prompt | Push needs Gitea write credentials (repo is public-*read*). | Use `student` and the password from `~/course/credentials/gitea-student.txt`. |
| App `OutOfSync` but you expected auto-deploy | Sync policy is **Manual** on purpose. | Click **Sync** (or `argocd app sync hello-reconcile`). Automated sync arrives in Lab 3. |
| `curl` returns the **old** message right after the Module 2 sync | Expected — Module 3 explains it. | Continue to Module 3; do not delete/restart the Pod. |
| `curl` still returns the **old** message after the Module 3 sync | Rollout unfinished, annotation under the wrong `metadata:` block, or wrong namespace. | Confirm `Synced`/`Healthy` and a new Pod in Window C; if none, move the annotation under `spec.template.metadata`, commit, push, Refresh, Sync. Re-run port-forward with `-n hello`. |
| `curl: (7) Failed to connect to localhost port 9898` | The port-forward stopped (it is attached to one Pod; a rollout ends it). | Run the port-forward again. |
| Sync `Unknown` with `ComparisonError` after the template change | Helm cannot render — usually a typo/indentation error in the `checksum/config` line. Nothing was applied. | Run `helm template hello-reconcile chart` to see the same error; fix, commit, push, Refresh. |

---

## 4. Checkpoint / validation

You have finished Lab 1 when **all** of these are true:

1. **The deployed revision equals your commit:**
   ```bash
   argocd app get hello-reconcile | grep -i "sync status"
   git -C ~/hello-reconcile rev-parse HEAD
   ```
   The short SHA in the first line matches the first 7 characters of the second. *(This is the outline's Day 1 evidence: live revision equals `git rev-parse HEAD`.)*
2. **The running app serves your message** — port-forward + `curl` returns your committed `message`.
3. **Your E1 dependency table** names every addressing field plus the container image.
4. **Your E2 notes are complete:** the Step A table is annotated with what happened, you have a one/two-sentence explanation of why the first sync did not change the running app, and you recorded the sync/health statuses during the Module 3 rollout.
5. **Your E4 three-way table** is complete, and you can say which surface you would use if the interface were down.

---

## 5. Key takeaways

- **An Application is an address, not an artifact.** Every field points at something external that can fail on its own. Circling those dependencies (E1) is the same list the Capstone breaks.
- **`OutOfSync` is a sentence about Git, not about your users.** A fresh commit is `OutOfSync` while still perfectly `Healthy`. `OutOfSync` that will not converge is the real problem.
- **Read the diff before you sign it** — the cheapest safety habit in Argo CD.
- **`Synced` means the objects match Git — not that every running program picked up the change.** A ConfigMap consumed as env vars reaches a container only when a new Pod starts, and a Deployment starts new Pods only when its Pod template changes. The `checksum/config` annotation connects the two — and the fix lives in Git, not a manual restart.
- **Deleting a Pod is not drift; deleting the Deployment is** — because only one is in Git.
- **The interface, the CLI, and `kubectl` tell one story in three vocabularies.** Fluency in all three is how you answer the incident question: *is this Argo CD, or is this Kubernetes?*
- **You already used steps 1–4 of the six-step troubleshooting method** (check source/revision, confirm render, compare rendered vs live, read sync result and events). Steps 5–6 arrive in Session 7 and the Capstone.

---

## 6. Optional stretch challenge

> **Clearly optional — not required to complete the lab.**

**Stretch A — prove the fix is permanent.** Change `message` to `"Hello from Git, revision three"` (nothing else), commit, push, and Refresh. **Predict first:** how many resources will the diff list this time, and will a new Pod start on sync? Then open **App Diff**, sync, and check Window C and `curl`. In one sentence, explain why this diff differs from your Module 2 diff.

**Stretch B — predict the health for `replicaCount: 0`.** Before changing anything, **write your prediction:** if you set `replicaCount: 0`, commit, push, and sync, what will the **sync status** and **health status** be? A Deployment scaled to zero has no Pods — is "zero Pods, exactly as requested" healthy, degraded, or something else? Then test it: set `replicaCount` to `0`, commit, push, Refresh, Sync, and observe. **Reset when done:** set it back to `1`, commit, push, sync.

![Argo CD history and rollback panel showing revisions (v3.5.2)](../../assets/screenshots/day-1/lab-01-10-history.png)

*Figure SS-L1-10 — Deployment history with the revisions from this lab.*

<!-- CAPTURE-SPEC: SS-L1-10 — History and rollback panel. State: after E2 (and the stretch), route /applications/hello-reconcile history panel. Highlight: two or more revisions with their SHAs. Fidelity: panel. -->

---

## 7. Transition — what's next

You watched one change move from Git to a running workload, on the **management cluster** as a deliberate teaching shortcut. Production platforms avoid that. Next, **Guide 03 — Production-Oriented Configuration** shapes a real platform, and **Lab 2** has you register a *separate* workload cluster and connect a *private* repository (contrast with today's public-read one).

**Before you move on:** no cleanup is required — your extra commits in `hello-reconcile` are harmless. Lab 2 begins with `reset-lab.sh CP-lab-02 --local` to hand you its exact starting state.
