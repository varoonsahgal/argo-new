# Lab 3 — Instructor Walkthrough and Solutions

> **INSTRUCTOR ONLY. Never share this file with participants, never project it, and never paste it into a shared channel.**
> **Participant guide (now a modular arc):** [lab-03/README.md](../../day-1/lab-03/README.md)
> **Exercise → module map:** E1, E2 are in [module 02](../../day-1/lab-03/02-deploy-and-promote.md); E3, E4 in [module 03](../../day-1/lab-03/03-drift-and-self-heal.md); E5 in [module 04](../../day-1/lab-03/04-break-and-recover.md). Exercise IDs are unchanged; E2's promotion and E5 Part B were rewritten on 2026-09-13 (see 0.1 and 0.2).
> **Timebox:** 60 minutes · **Scaffolding:** G2 (reduced)
> **Verified:** 2026-09-13 (evening), end to end, on the course's local k3d two-cluster sandbox: Argo CD `v3.5.2` (chart `10.8.4`), `argocd` CLI `v3.5.2`, Kubernetes `v1.35.8+k3s1`, Helm `v4.2.1`, starting from `reset-lab.sh CP-lab-03` after the environment fix in 0.1. Every output block below was captured from that run unless marked otherwise. SHAs, Pod suffixes, and times will differ on your machine.

---

## How to read this file

| Label | What it tells you |
|---|---|
| **Say** | Words you can use nearly verbatim. Keep the questions. |
| **Do** | A command you run on the projected VM terminal. |
| **Click** | A UI action in Firefox on the VM. |
| **Expect** | What the verified run showed. |
| **Answer key** | What participants should reach, with reasoning. |
| **Wrong turns** | Real mistakes and what they look like. |
| **Wow moment** | The sentence worth pausing on. |
| **If it goes sideways** | A tested recovery. |

---

## 0. Before class — pre-flight (15 minutes)

The two defects that used to derail this lab live are **fixed** in the guide and the environment (re-verified end to end on 2026-09-13). Read 0.1 and 0.2 anyway: they tell you what changed, what to check on your VM, and what participants will see now.

### 0.1 The Exercise 2 promotion is now `6.14.1` → `6.15.0`, with both images pre-loaded

Older versions of this lab promoted to `stefanprodan/podinfo:6.16.0`, which does not exist (Docker Hub on 2026-09-13: `6.16.0` → HTTP 404; newest release `6.15.0`, published 2026-08-31; the one before it `6.14.1`). What changed:

- `envs/dev/values.yaml` and `envs/staging/values.yaml` start on `6.14.1` (tags `cp-baseline` through `cp-lab-03`); `envs/prod/values.yaml` stays on `6.15.0`.
- The VM pre-loads both images on the workload cluster (`PODINFO_PREV_IMAGE` in `courseware/environment/scripts/lib/common.sh`, pulled and imported by `bootstrap-vm.sh`).
- `CP-lab-04` moves dev and staging back to `6.15.0`, so Day 2 and the capstone start exactly as before.

**Do** (on the VM you will project, before class):

```bash
docker exec k3d-workload-server-0 crictl images | grep podinfo
git --git-dir=/opt/course/seed-repos/storefront-gitops.git show cp-lab-03:envs/dev/values.yaml | grep tag
```

**Expect** (verified on the local sandbox, whose mirror lives under `~/.argocd-course/seed-repos` instead):

```text
docker.io/stefanprodan/podinfo               6.14.1              b6bee70366a9d       86.2MB
docker.io/stefanprodan/podinfo               6.15.0              8d0c5e5054411       89.3MB
  tag: "6.14.1"
```

If `6.14.1` is missing, or the tag reads `6.15.0`, the VM was built before the fix. Rebuild it, or run `docker pull stefanprodan/podinfo:6.14.1` and `k3d image import stefanprodan/podinfo:6.14.1 -c workload`, re-run `seed-repos.sh`, and reset to `CP-lab-03`.

### 0.2 Exercise 5 Part B now uses an explicit sync

The old guide told participants to commit `migration.shouldFail: true` and wait for auto-sync. Re-verified on v3.5.2 (2026-09-13):

1. **A hook-only commit never starts auto-sync.** Hooks are not part of the compared state, so the app goes straight to `Synced` at the new commit (watched for 40 s: no operation). The guide now teaches this and has participants run `argocd app sync storefront-dev`. A manual sync has no retries (`operation.retry` is empty), so it ends `Failed` in about 6 seconds, and nothing automated follows.
2. **If someone pairs the flag with a visible change** (or you demo it), automated sync takes over. The guide covers this only in a callout, a troubleshooting row, and Stretch 2:
   - it **retries 5 times by default** (backoff 5 s, 10 s, 20 s, 40 s, 80 s) with no `retry:` block in the Application; the controller attaches `operation.retry = {"limit":5}`, and the operation shows `Phase: Running` with `Retrying attempt #N` ([Argo CD docs — Automated Sync Policy](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/));
   - **a pushed fix does not rescue the retrying operation.** It stayed pinned to the bad commit 50 s after the fix was pushed, and a manual sync is refused with `another operation is already in progress`. `argocd app terminate-op storefront-dev` releases it; auto-sync ran the fix within 2 s. (Upstream [argoproj/argo-cd#11494](https://github.com/argoproj/argo-cd/issues/11494); Argo CD v3.2 added an opt-in `syncPolicy.retry.refresh: true` so retries use the newest commit.)
   - when the retries run out, or you terminate first, the app gets a **`SyncError` condition** (`Failed last sync attempt to [<sha>]: …`) and Argo CD does not try that commit again. The next commit is picked up by auto-sync with no `terminate-op`.

Section 6 has the verified script for the guide's path and for the automated path.

### 0.3 Other things participants will now see (all reflected in the guide)

| Where | Verified behavior |
|---|---|
| E2 guardrail step | Applying `storefront-staging` before widening the project prints `created`, then `Unknown`/`Unknown` with `InvalidSpecError  application destination server 'https://k3d-workload-server-0:6443' and namespace 'storefront-staging' do not match any of the allowed destinations in project 'storefront'`. `CP-lab-03`'s project now allows only `storefront-dev`, exactly like Lab 2's answer, so this reproduces after a reset too |
| E3 | `OutOfSync` shows within a second or two of `kubectl scale`, before any Refresh, and health reads `Progressing` briefly while the extra Pods start. Argo CD watches the objects it manages; the 60-second timer is for Git |
| E3 Diff | The full diff opens at the top of the Deployment; `replicas` is on line 151. Tick **Compact diff** |
| E4 | Self-heal reverted `replicas: 3` → `1` in **about 0.7 seconds**, twice. The self-heal sync re-applies only the drifted Deployment (RESULT has one row; the PreSync hook does not run) and adds no History entry |
| Checkpoint | `argocd app list -o wide` shows `TARGET` (`main`), not a SHA. The guide now uses the `kubectl … custom-columns` command in Section 8 |

### 0.4 Confirm the starting checkpoint

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-03 --verify-only --local
```

Expect every row `PASS`: the 12-row table printed in Module 1 of the participant guide (identical on 2026-09-13).

---

## Run of show (60 minutes)

| Clock | Segment | Your job |
|---|---|---|
| 0:00–0:04 | Why this matters + environment check | "Is it drift, rendering, or ordering?" — put the three words on the board |
| 0:04–0:14 | E1 — deploy and "render, not release" | The `helm list` moment |
| 0:14–0:24 | E2 — staging + promotion | The guardrail rejection, then a clean one-line promotion; ask "what if that tag had not existed?" |
| 0:24–0:32 | E3 — drift under manual sync | Collect predictions before scaling |
| 0:32–0:44 | E4 — self-heal on, prune off | The timing prediction; 2 a.m. debrief |
| 0:44–0:58 | E5 — break it two ways | Part B: "why didn't auto-sync run it?" |
| 0:58–0:60 | Day 1 outcome | The four "where I'd look first" notes |

---

## 1. Opening (3 minutes)

**Say:**

> "Today you take a Helm app from a commit to a separate cluster, break it two different ways, and bring it back — every time through Git, never by hand-fixing the cluster. That's not a drill. It's the loop an on-call engineer runs at 2 a.m."

Write on the board: **DRIFT · RENDERING · ORDERING**.

> "These three all turn things red. They live in completely different places. By the end of the hour you'll be able to point at a red badge and say which one it is before you touch anything."

---

## 2. Exercise 1 — Deploy dev and prove "render, not release"

### Answer key — the prediction table

| Stage | Desired (Git) | Rendered | Live |
|---|---|---|---|
| Before sync | chart + dev values | ConfigMap, Service, Deployment — the three resources Argo CD compares (`argocd app manifests storefront-dev` lists exactly these; that is why Lab 2 showed three `OutOfSync` rows). The chart also renders the PreSync migration Job, but a hook runs during a sync and is not compared | Nothing in `storefront-dev` |
| Immediately after Sync | chart + dev values | Same | Migration Job completes first, then ConfigMap (wave −1), then Deployment and Service (wave 0); the Deployment is `Progressing` until its Pod is Ready |

### Run it

**Do:**

```bash
argocd app sync storefront-dev
```

**Expect** (verified — note the order and the Deployment still `Progressing` at the moment the operation finished):

```text
Operation:          Sync
Sync Revision:      d3a4166e218b57d42feacf3076c42a2aff855b28
Phase:              Succeeded
Start:              2026-09-13 21:46:40 -0400 EDT
Finished:           2026-09-13 21:46:49 -0400 EDT
Duration:           9s
Message:            successfully synced (all tasks run)

GROUP  KIND        NAMESPACE       NAME                  STATUS     HEALTH       HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Succeeded  Synced       PreSync  Reached expected number of succeeded pods
       ConfigMap   storefront-dev  storefront            Synced                           configmap/storefront created
       Service     storefront-dev  storefront            Synced     Healthy               service/storefront created
apps   Deployment  storefront-dev  storefront            Synced     Progressing           deployment.apps/storefront created
```

Ten seconds later, `argocd app get storefront-dev` shows `Synced` / `Healthy`.

**Say:** "Nine seconds. The first ones went to a Job you never listed in any Application. Why did it run first?"

**Answer:** It carries `argocd.argoproj.io/hook: PreSync`. Argo CD runs PreSync hooks and waits for them to succeed before applying anything else.

### The `helm list` moment

**Say:** "Prediction, out loud: when I run `helm list` against the workload cluster, how many releases will I see? We just deployed a Helm chart."

**Do:**

```bash
helm list -A --kube-context k3d-workload
```

**Expect** (verified — the header row, and nothing else):

```text
NAME	NAMESPACE	REVISION	UPDATED	STATUS	CHART	APP VERSION
```

**Answer key (one sentence):** Argo CD ran `helm template` to render manifests and applied them itself; it never ran `helm install`, so no Helm release exists.

**Wow moment:**

> "Argo CD borrows Helm's typewriter and throws away Helm's filing cabinet. There is no release. Which means there is no `helm rollback`. The only rollback button you have in GitOps is `git revert` — and it leaves a receipt."

**Do** (the ground-truth check):

```bash
kubectl --context k3d-workload -n storefront-dev port-forward svc/storefront 9898:9898 >/tmp/pf.log 2>&1 &
sleep 2; curl -s localhost:9898 | grep -o '"message": *"[^"]*"\|"version": *"[^"]*"'; kill %1
```

**Expect** (verified):

```text
"message": "storefront DEV"
"version": "6.14.1"
```

### Wrong turns

- **"Nothing is there"** after syncing → they ran `kubectl` against `k3d-mgmt`. "Which cluster did you deploy *to*?"
- **Expecting a release in `helm list`** → the point of the exercise; don't correct it until after they've seen the empty output.

---

## 3. Exercise 2 — Deploy staging, then promote a tag

### Part 1 — the staging Application

**Answer key — predicted differences** between `envs/dev/values.yaml` and `envs/staging/values.yaml`: namespace (`storefront-dev` → `storefront-staging`), replica count (`1` → `2`), UI message (`storefront DEV` → `storefront STAGING`), UI colour (`#2da44e` → `#bf8700`). **Not different:** the image tag (both `6.14.1` before the promotion).

**The solution manifest** (`platform-config/applications/storefront-staging.yaml`, verified):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: storefront-staging
  namespace: argocd
spec:
  project: storefront
  source:
    repoURL: http://lab-gitea:3000/course/storefront-gitops.git
    targetRevision: main
    path: charts/storefront
    helm:
      valueFiles:
        - ../../envs/staging/values.yaml
  destination:
    server: https://k3d-workload-server-0:6443
    namespace: storefront-staging
```

**The project change** (add this item under `spec.destinations` in `platform-config/projects/storefront.yaml`):

```yaml
    - server: https://k3d-workload-server-0:6443
      namespace: storefront-staging
```

### Show the wrong turn first — it's worth 60 seconds

**Do** (apply the Application *before* widening the project):

```bash
kubectl --context k3d-mgmt -n argocd apply -f platform-config/applications/storefront-staging.yaml
argocd app get storefront-staging --refresh
```

**Expect** (verified — `kubectl` prints `application.argoproj.io/storefront-staging created` first):

```text
Sync Status:        Unknown
Health Status:      Unknown

CONDITION         MESSAGE
InvalidSpecError  application destination server 'https://k3d-workload-server-0:6443' and namespace 'storefront-staging' do not match any of the allowed destinations in project 'storefront'
```

**Say:**

> "Read that message like a support ticket. It names the server, the namespace, and the project. Nobody needs to page you — the person who hit this can fix it themselves. That's what a good fence looks like. You built this fence in Lab 2, and it just did its job."

**Do** (the fix):

```bash
cd ~/platform-config
git add projects/storefront.yaml applications/storefront-staging.yaml
git commit -m "Lab 3 E2: storefront-staging Application and staging destination"
git push
cd ~
kubectl --context k3d-mgmt -n argocd apply -f platform-config/projects/storefront.yaml
kubectl --context k3d-mgmt -n argocd apply -f platform-config/applications/storefront-staging.yaml
argocd app sync storefront-staging
kubectl --context k3d-workload -n storefront-staging get deploy storefront
```

**Expect** (verified — the project is `configured`; the Application is `unchanged` because the wrong turn already created it; the condition is gone and the app reads `OutOfSync` / `Missing` until the sync):

```text
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
storefront   2/2     2            2           13s
```

`curl` against `storefront-staging` (port-forward on `9899:9898`) returns `"message": "storefront STAGING"` and `"version": "6.14.1"` (verified). **Click:** `storefront-staging` → **Details** → **Parameters** for [SS-L3-03](../../assets/screenshots/day-1/lab-03-03-parameters-values-files.png) (the figure was captured after the promotion, so it shows `image.tag` `6.15.0`).

**Wow moment:**

> "Same chart. Same repo. Same image. Two different running applications. The only thing that made them different is which values file the Application points at — that's why the values file, not the chart, is where environments live."

### Part 2 — the promotion

**Say:** "Dev and staging both run podinfo `6.14.1`. `6.15.0` is out. Promote it — dev first."

**Do:**

```bash
cd ~/storefront-gitops
sed -i 's/tag: "6.14.1"/tag: "6.15.0"/' envs/dev/values.yaml
git diff
git commit -am "dev: podinfo 6.15.0" && git push
argocd app sync storefront-dev
```

**Expect** (verified — the diff is one line, and the sync reconfigures only the Deployment):

```text
@@ -2,7 +2,7 @@
 namespace: storefront-dev
 replicaCount: 1
 image:
-  tag: "6.14.1"
+  tag: "6.15.0"
 ui:
   message: "storefront DEV"
   color: "#2da44e"
```

```text
Phase:              Succeeded
Duration:           9s
Message:            successfully synced (all tasks run)

GROUP  KIND        NAMESPACE       NAME                  STATUS     HEALTH       HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Succeeded  Synced       PreSync  Reached expected number of succeeded pods
       ConfigMap   storefront-dev  storefront            Synced                           configmap/storefront unchanged
       Service     storefront-dev  storefront            Synced     Healthy               service/storefront unchanged
apps   Deployment  storefront-dev  storefront            Synced     Progressing           deployment.apps/storefront configured
```

About ten seconds later `argocd app get storefront-dev` shows `Synced` / `Healthy`, and `curl -s localhost:9898 | grep version` through dev's port-forward prints `  "version": "6.15.0",` (verified).

**Do** (the promotion, then the render-only check):

```bash
sed -i 's/tag: "6.14.1"/tag: "6.15.0"/' envs/staging/values.yaml
git diff
git commit -am "staging: promote podinfo 6.15.0 from dev" && git push
helm template storefront charts/storefront -f envs/staging/values.yaml | grep 'image:'
argocd app sync storefront-staging
git log --oneline -3
```

**Expect** (verified):

```text
          image: "stefanprodan/podinfo:6.15.0"
          image: busybox:1.37.0
```

```text
83e2954 staging: promote podinfo 6.15.0 from dev
086c24b dev: podinfo 6.15.0
d3a4166 checkpoint CP-baseline
```

Staging: `Phase: Succeeded` in 9 s, `2/2`, and `curl` returns `"message": "storefront STAGING"` and `"version": "6.15.0"` (verified).

**Say:** "Two images in `helm template`. One is our app. The other is the migration Job. `helm template` renders locally and changes nothing on any cluster — it proves the YAML is right. It cannot tell you whether the tag *exists* in a registry. Only a pull proves the image is real."

**Say — the question an earlier version of this lab answered by accident:**

> "Suppose the tag you promoted did not exist. What would you see — sync status, health — and would users be hurt?"

**Answer key:** `Synced` (you deployed exactly what Git says) and, after the Deployment's 60-second progress deadline, `Degraded` (the new Pod sits in `ImagePullBackOff`). Users keep getting the old version, because a rolling update does not remove the old Pod until the new one is Ready. You do not know whether the tag will ever exist, so you **revert** the promotion commit. *(Verified in an earlier rehearsal that promoted the non-existent `6.16.0`: the new Pod was `ImagePullBackOff` with `not found`, health `Degraded` at t=65 s, and `curl` still returned the old version.)*

**Wow moment:**

> "The whole promotion was two one-line commits. Read that `git log` from the bottom up: baseline, dev, staging. Anyone reviewing this tomorrow can see what moved and when — and `git revert` on either line is the rollback."

### Success criterion

Grade on: both Applications `Synced`/`Healthy`, staging at `2/2` and `storefront STAGING`, both environments on `6.15.0`, and a `git log` showing the dev change and the promotion as separate commits.

---

## 4. Exercise 3 — Introduce live drift under manual sync

### Answer key — the prediction

| After scaling to 3 replicas… | Sync status | Health status | Reverts on its own? |
|---|---|---|---|
| | `OutOfSync` | `Healthy` (after a few seconds of `Progressing`) | **No** |

### Run it

**Say** — take a hand vote on "which badge changes?" before running.

**Do:**

```bash
kubectl --context k3d-workload -n storefront-dev scale deploy/storefront --replicas=3
argocd app get storefront-dev | grep -E "Sync Status|Health Status"
```

**Expect** (verified — read immediately after the scale, *before* any refresh):

```text
Sync Status:        OutOfSync from main (83e2954)
Health Status:      Progressing
```

**Say:** "Already `OutOfSync`, and nobody clicked Refresh. And health says `Progressing` — is the app broken?"

**Answer:** No. Argo CD watches the objects it manages, so the scale triggered a comparison at once. `Progressing` is the two new Pods starting; within seconds it reads `Healthy`. The 60-second timer is how often Argo CD checks *Git*.

**Do:**

```bash
argocd app get storefront-dev --refresh
argocd app diff storefront-dev; echo "diff exit=$?"
```

**Expect** (verified):

```text
Sync Status:        OutOfSync from main (83e2954)
Health Status:      Healthy

GROUP  KIND        NAMESPACE       NAME                  STATUS     HEALTH   HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Succeeded  Synced   PreSync  Reached expected number of succeeded pods
       ConfigMap   storefront-dev  storefront            Synced                       configmap/storefront unchanged
       Service     storefront-dev  storefront            Synced     Healthy           service/storefront unchanged
apps   Deployment  storefront-dev  storefront            OutOfSync  Healthy           deployment.apps/storefront configured

===== apps/Deployment storefront-dev/storefront ======
151c151
<   replicas: 3
---
>   replicas: 1
diff exit=1
```

**Click:** **Diff**, then tick **Compact diff** for [SS-L3-05](../../assets/screenshots/day-1/lab-03-05-drift-diff.png). Without Compact diff the panel opens on the Deployment's metadata, 150 lines above the change.

Wait 70 seconds. **Expect** (verified): still `OutOfSync` / `Healthy`, and `storefront   3/3`.

### Answer key — "why didn't health move?" (one sentence)

> "Three ready replicas is a perfectly working Deployment — health asks 'is it working?', and it is; only the sync question ('does it match Git?') changed."

### Wow moment

> "Drift is discovered by a comparison — and for a hand edit Argo CD doesn't wait a minute to compare, because it watches what it manages. But under manual sync, Argo CD's job ends at *reporting*. It will tell you about this drift forever and never fix it."

---

## 5. Exercise 4 — Configure safe automated sync and self-healing

### The solution

First, sync by hand back to 1 replica (`argocd app sync storefront-dev`). Then add to `platform-config/applications/storefront-dev.yaml`:

```yaml
  syncPolicy:
    automated:
      selfHeal: true
      prune: false
```

**Do:**

```bash
cd ~/platform-config
git commit -am "Lab 3 E4: storefront-dev automated sync, selfHeal on, prune off" && git push
cd ~
kubectl --context k3d-mgmt -n argocd apply -f platform-config/applications/storefront-dev.yaml
argocd app get storefront-dev | grep -E "Sync Policy|Sync Status|Health Status"
```

**Expect** (verified):

```text
Sync Policy:        Automated
Sync Status:        Synced to main (83e2954)
Health Status:      Healthy
```

**Click:** **Details** → **Summary** → scroll to **SYNC POLICY** for [SS-L3-06](../../assets/screenshots/day-1/lab-03-06-auto-sync-enabled.png): **ENABLE AUTO-SYNC** and **SELF HEAL** ticked, **PRUNE RESOURCES** not.

### The self-heal race

**Say:** "Predict: how long until my edit is undone? Guesses in seconds."

Most rooms say "about a minute", because the environment "checks every 60 seconds".

**Do:**

```bash
t0=$(python3 -c 'import time; print(time.time())')
kubectl --context k3d-workload -n storefront-dev scale deploy/storefront --replicas=3
for i in $(seq 1 120); do
  r=$(kubectl --context k3d-workload -n storefront-dev get deploy storefront -o jsonpath='{.spec.replicas}')
  [ "$r" = "1" ] && python3 -c "import time; print('reverted to spec.replicas=1 after %.1fs' % (time.time()-$t0))" && break
  sleep 0.5
done
kubectl --context k3d-mgmt -n argocd get application storefront-dev -o jsonpath='initiatedBy={.status.operationState.operation.initiatedBy}{"\n"}'
```

**Expect** (verified, twice in a row, about 8 seconds apart):

```text
reverted to spec.replicas=1 after 0.7s
initiatedBy={"automated":true}
```

**Wow moment:**

> "Under a second. Not sixty. The sixty-second timer is how often Argo CD asks *Git* 'anything new?'. The cluster is different — Argo CD keeps a live watch on every resource it manages, so it hears your edit almost immediately. Self-heal doesn't block your edit. It outlives it."

**Click:** **Sync Status** in the application toolbar for [SS-L3-07](../../assets/screenshots/day-1/lab-03-07-self-heal-evidence.png): **INITIATED BY** automated sync policy, not a user. **RESULT** has a single row, the Deployment: self-heal re-applied only the drifted object. The PreSync hook did not run (the Job's creation time did not change), and `argocd app history storefront-dev` gained no entry (verified).

### Protect one resource from future pruning

**Solution** — add the annotation to the Service template (`charts/storefront/templates/service.yaml`), directly under the existing sync-wave annotation:

```yaml
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    argocd.argoproj.io/sync-options: Prune=false
```

**Do:**

```bash
cd ~/storefront-gitops
helm template storefront charts/storefront -f envs/dev/values.yaml \
  | yq 'select(.metadata.annotations."argocd.argoproj.io/sync-options" != null) | .kind + "/" + .metadata.name + "  " + .metadata.annotations."argocd.argoproj.io/sync-options"'
git commit -am "storefront chart: protect Service from pruning (Prune=false)" && git push
```

**Expect** (verified): `Service/storefront  Prune=false`. Because dev now auto-syncs, the annotation reached the live Service about 12 seconds after the push and a Refresh (verified; the automated sync ran the full hook and waves). Staging, still manual, shows `OutOfSync` on its Service until someone syncs it — a nice unplanned demonstration of the difference between the two policies, and the reason Part A's recovery ends with a staging sync.

**Answer key — the one-sentence justification** (accept any version of this):

> "It's defense in depth: app-wide prune is off today, but if someone turns it on later, or an Application is deleted with cascade, this one resource — which other systems depend on — still won't be removed automatically."

The Service is a good choice because its address is what other things depend on. Recreating it can change its cluster IP.

### The 2 a.m. debrief

**Say:** read the scenario from the guide, then wait for written answers.

**Answer key:** Either of these is correct —

1. **Disable automated sync on that one Application**, scale to 10, stabilize, then commit `replicaCount: 10` to Git and re-enable automation; or
2. **Commit `replicaCount: 10` first** (in that environment's values file) and let the sync carry it.

The wrong answer is to keep scaling and fight the loop.

**Wow moment:**

> "Git wins. Not because Argo CD is stubborn — because a human turned on a switch that says Git wins. Self-heal is a policy about who wins ties, not a safety feature. At 2 a.m. the fastest path is to change the policy or change Git — never to out-type the controller."

---

## 6. Exercise 5 — Break it two ways, recover through Git

### Part A — the rendering failure (works as written)

**Do:**

```bash
cd ~/platform-config
sed -i 's#envs/staging/values.yaml#envs/staging/values-DOESNOTEXIST.yaml#' applications/storefront-staging.yaml
git commit -am "staging: switch values file" && git push
cd ~
kubectl --context k3d-mgmt -n argocd apply -f platform-config/applications/storefront-staging.yaml
argocd app get storefront-staging --refresh
```

**Expect** (verified):

```text
Sync Status:        Unknown
Health Status:      Healthy

CONDITION        MESSAGE
ComparisonError  Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unknown desc = failed to execute helm template command: failed running helm: `helm template . --name-template storefront-staging --namespace storefront-staging --kube-version 1.35.8 --values <path to cached source>/envs/staging/values-DOESNOTEXIST.yaml <api versions removed> --include-crds` failed exit status 1: Error: open <path to cached source>/envs/staging/values-DOESNOTEXIST.yaml: no such file or directory

GROUP  KIND        NAMESPACE           NAME                  STATUS     HEALTH   HOOK     MESSAGE
batch  Job         storefront-staging  storefront-migration  Succeeded  Synced   PreSync  Reached expected number of succeeded pods
       ConfigMap   storefront-staging  storefront            Unknown                      configmap/storefront unchanged
       Service     storefront-staging  storefront            Unknown    Healthy           service/storefront unchanged
apps   Deployment  storefront-staging  storefront            Unknown    Healthy           deployment.apps/storefront configured
```

**Click:** the header's **APP CONDITIONS — 1 Error** for [SS-L3-08](../../assets/screenshots/day-1/lab-03-08-comparison-error.png). A pop-up `Unable to load data: revision main must be resolved` may appear on the page as well (verified); it is the same rendering failure.

**Prove nothing on the cluster changed** (verified — the same two Pods before and after, and the last sync operation still points at the old revision):

```bash
kubectl --context k3d-workload -n storefront-staging get pods
kubectl --context k3d-mgmt -n argocd get application storefront-staging \
  -o jsonpath='phase={.status.operationState.phase} rev={.status.operationState.syncResult.revision}{"\n"}'
```

```text
phase=Succeeded rev=83e2954765e2ef0491447dc02df726e43513ac68
```

**Answer key — prediction:** a **condition** (`ComparisonError`) on the Application, not a failed sync. The **repo-server** failed. Nothing was applied, so nothing needs cleaning up.

**Recover (verified):**

```bash
cd ~/platform-config
git revert --no-edit HEAD && git push
cd ~
kubectl --context k3d-mgmt -n argocd apply -f platform-config/applications/storefront-staging.yaml
argocd app get storefront-staging --refresh | grep -E "Sync Status|Health Status|CONDITION"
```

The `ComparisonError` clears. Because the Exercise 4 `Prune=false` commit landed after staging's last sync, staging shows `OutOfSync` on the Service — run `argocd app sync storefront-staging` and it returns to `Synced`/`Healthy` (verified; the guide now tells participants this).

**Wow moment:**

> "Sync `Unknown`, health `Healthy`. Argo CD couldn't produce manifests, so it couldn't compare — and it refused to guess. Meanwhile every Pod kept running. A rendering failure is loud in the UI and silent in the cluster."

### Part B — the ordering failure (the guide's explicit-sync path)

**Say** — after participants push the `shouldFail: true` commit, before anyone syncs: "`storefront-dev` has auto-sync on. Did Argo CD run your commit? Why not?"

**Do:**

```bash
cd ~/storefront-gitops
cat >> envs/dev/values.yaml <<'EOF'
migration:
  shouldFail: true
EOF
git diff
git commit -am "dev: schema migration (hook-only change)" && git push
argocd app get storefront-dev --refresh | grep -E "Sync Status|Health Status"
```

**Expect** (verified — and in the next 40 seconds no operation started):

```text
+migration:
+  shouldFail: true
Sync Status:        Synced to main (405e86c)
Health Status:      Healthy
```

**Answer:**

> "You changed something that only a hook uses. Hooks aren't part of what Argo CD compares — `argocd app manifests storefront-dev` lists the ConfigMap, Service, and Deployment, not the Job. So from Argo CD's point of view nothing it manages changed, the app is `Synced`, and automated sync only runs when something is `OutOfSync`."

**Say** — before the sync: "Is this going to be a Job problem, a Secret problem, or a wave problem? Where will the evidence be?"

**Do:**

```bash
argocd app sync storefront-dev
```

**Expect** (verified — `Failed` in 6 seconds; a manual sync has no retries):

```text
Operation:          Sync
Sync Revision:      405e86c4066bd8bfa10de7e3065dffce009c33a5
Phase:              Failed
Start:              2026-09-13 22:03:28 -0400 EDT
Finished:           2026-09-13 22:03:34 -0400 EDT
Duration:           6s
Message:            one or more synchronization tasks completed unsuccessfully

GROUP  KIND        NAMESPACE       NAME                  STATUS  HEALTH   HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Failed  Synced   PreSync  Job has reached the specified backoff limit
       ConfigMap   storefront-dev  storefront            Synced
       Service     storefront-dev  storefront            Synced  Healthy
apps   Deployment  storefront-dev  storefront            Synced  Healthy
{"level":"fatal","msg":"Operation has completed with phase: Failed","time":"2026-09-13T22:03:34-04:00"}
```

**Prove it stopped at the gate, and that it is not a condition** (verified):

```bash
kubectl --context k3d-mgmt -n argocd get application storefront-dev \
  -o jsonpath='sync={.status.sync.status} health={.status.health.status} phase={.status.operationState.phase} retry={.status.operationState.operation.retry} conditions={.status.conditions}{"\n"}'
kubectl --context k3d-workload -n storefront-dev logs job/storefront-migration
```

```text
sync=Synced health=Healthy phase=Failed retry={} conditions=
Running storefront schema migration...
migration failed: incompatible schema
```

The operation's sync result holds one entry, the Job (`hookPhase=Failed`). The ConfigMap, Service, and Deployment rows have no message because this sync never reached them. Thirty seconds later nothing had changed (verified): no automated attempt, no condition.

**Click:** the tree for [SS-L3-09](../../assets/screenshots/day-1/lab-03-09-presync-hook-failed.png): LAST SYNC **Sync failed**, the Job red, the app still `Synced`/`Healthy`.

**Answer key — the symptom table:**

| Symptom | Hypothesis | Where the evidence is |
|---|---|---|
| The sync operation is **Failed** | **Job** — specifically a PreSync gate | Sync result: the `storefront-migration` row, `HOOK PreSync`, `Job has reached the specified backoff limit`; the Job's log says `migration failed: incompatible schema` |
| ConfigMap, Service, and Deployment rows have an empty MESSAGE | **Wave** — the Sync phase is blocked behind the failed PreSync phase | The sync result lists only the Job; the other resources were never applied in this operation |

It is not a Secret problem: nothing references a Secret.

### Recover — roll forward, then sync explicitly

**Say:** "We understand the failure — the flag says fail. That's a roll-forward. Commit the fix. Will auto-sync pick it up this time?"

**Do:**

```bash
cd ~/storefront-gitops
sed -i 's/shouldFail: true/shouldFail: false/' envs/dev/values.yaml
git commit -am "dev: fix schema migration (roll forward)" && git push
argocd app get storefront-dev --refresh | grep -E "Sync Status|Health Status"
```

**Expect** (verified — 20 seconds later there was still no automated sync, and the last operation was still the `Failed` one at `405e86c`):

```text
Sync Status:        Synced to main (a4963fa)
Health Status:      Healthy
```

**Do:**

```bash
argocd app sync storefront-dev
argocd app history storefront-dev
```

**Expect** (verified):

```text
Phase:              Succeeded
Duration:           10s
Message:            successfully synced (all tasks run)

GROUP  KIND        NAMESPACE       NAME                  STATUS     HEALTH   HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Succeeded  Synced   PreSync  Reached expected number of succeeded pods
       ConfigMap   storefront-dev  storefront            Synced                       configmap/storefront unchanged
       Service     storefront-dev  storefront            Synced     Healthy           service/storefront unchanged
apps   Deployment  storefront-dev  storefront            Synced     Healthy           deployment.apps/storefront unchanged

ID      DATE                           REVISION
...
3       2026-09-13 21:59:26 -0400 EDT  main (fb5b61c)
4       2026-09-13 22:05:22 -0400 EDT  main (a4963fa)
```

History lists successful syncs only, so the failed attempt at `405e86c` has no entry.

**Wow moment:**

> "Auto-sync was on the whole time, and it did nothing — correctly. It syncs when Git and the cluster disagree, and a hook isn't part of that comparison. When your change lives only in a hook, *you* press Sync. And the failure was loud in the sync result and completely absent from the conditions — the opposite of Part A."

### The automated path — demo it, or use it when someone pairs the flag with a visible change

If a participant commits `shouldFail: true` **together with** a visible change (for example a new `ui.message`), the app goes `OutOfSync`, automated sync starts on its own, and v3.5.2 behaves very differently (0.2). Verified script:

```bash
cd ~/storefront-gitops
sed -i 's/shouldFail: false/shouldFail: true/; s/message: "storefront DEV"/message: "storefront DEV v2"/' envs/dev/values.yaml
git commit -am "dev: new banner + schema migration" && git push
argocd app get storefront-dev --refresh >/dev/null
argocd app get storefront-dev --show-operation
```

**Expect** (verified — `Running` and "Retrying", not `Failed`; the ConfigMap in wave −1 never applied, so the live ConfigMap still says `storefront DEV`):

```text
Operation:          Sync
Sync Revision:      9e6ac509b16e2500b1a1654fde445038e908bfd4
Phase:              Running
Duration:           1m22s
Message:            one or more synchronization tasks completed unsuccessfully. Retrying attempt #4 at 2:09AM.

GROUP  KIND        NAMESPACE       NAME                  STATUS     HEALTH   HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Failed     Synced   PreSync  Job has reached the specified backoff limit
       ConfigMap   storefront-dev  storefront            OutOfSync
       Service     storefront-dev  storefront            Synced     Healthy
apps   Deployment  storefront-dev  storefront            Synced     Healthy
```

Verified retry timeline (polled every 5–6 s; the controller attached `operation.retry = {"limit":5}`):

```text
t=5s   Running retryCount=1 | Retrying attempt #1
t=21s  Running retryCount=2 | Retrying attempt #2
t=41s  Running retryCount=3 | Retrying attempt #3
t=47s  fix commit 96c4d9d pushed, app refreshed
t=78s  Running retryCount=3 | operation revision still 9e6ac50 (the bad commit)
t=84s  Running retryCount=4 | Retrying attempt #4, still 9e6ac50
```

A manual sync during this is refused (verified):

```text
{"level":"fatal","msg":"rpc error: code = FailedPrecondition desc = another operation is already in progress",...}
```

**Do:**

```bash
argocd app terminate-op storefront-dev
```

**Expect** (verified — auto-sync picked up the fix within 2 seconds and finished in 8):

```text
Application 'storefront-dev' operation terminating

t=2s  Running    revision 96c4d9d (the fix)
t=4s  Running    waiting for completion of hook batch/Job/storefront-migration
t=8s  Succeeded  successfully synced (all tasks run); live ConfigMap now says storefront DEV v2
```

**Wow moment:**

> "We fixed Git, and Argo CD kept trying the broken commit. A running operation is pinned to the revision it started with. Retries are a promise to try *the same thing* again — they don't go looking for new commits."

Two more verified variations:

- **Terminate first, fix second.** `terminate-op` while it is still retrying gives `Phase: Failed`, `Operation terminated (retried 1 times).`, and a `SyncError` condition `Failed last sync attempt to [<sha>]: Operation terminated (retried 1 times).` Auto-sync did **not** restart that commit (watched 30 s). Pushing the fix then synced it automatically in 12 s.
- **Let the retries run out.** Automated sync stops with `Phase: Failed` and a `SyncError` condition; the next commit is picked up automatically with no `terminate-op` (verified with `limit: 2` in Stretch 2).

**Optional tidy-up** after the demo: set `message: "storefront DEV"` again, commit, push (verified: auto-synced and `Healthy` in 12 seconds).

### Revert or roll forward — answer key

| Part | Choice | Justification |
|---|---|---|
| A | **Revert** | Fine to revert: the change itself was the mistake, and reverting restores the last known-good reference. (Rolling forward by typing the correct filename is also acceptable if they can say why.) |
| B | **Roll forward** | We understood the cause (a flag that says "fail"). Committing `shouldFail: false` is a roll forward; `git revert` of the breaking commit reaches the same state and is equally fine here. |

**Component and repo for each:**

| Part | Owning component | Repo that held the fix |
|---|---|---|
| A | repo-server (rendering) | `platform-config` (the Application's `valueFiles`) |
| B | application-controller (sync execution) | `storefront-gitops` (the env values) |

### If it goes sideways

| Symptom | What's happening | Recovery |
|---|---|---|
| Participant pushed `shouldFail: true`; "nothing happened" | Expected: hook-only change, the app is already `Synced` | Point at the guide's step 2 and have them run `argocd app sync storefront-dev` (verified) |
| Participant also changed the banner; the operation shows `Running` / `Retrying attempt #N` | Automated sync with the default 5 retries | Use it: run "The automated path" above; recover with the fix commit plus `argocd app terminate-op storefront-dev` (verified) |
| `another operation is already in progress` on a manual sync | The automated operation is running or retrying | `argocd app terminate-op storefront-dev` (verified) |
| Fix pushed, app still retrying | Operation pinned to the old revision | `argocd app terminate-op storefront-dev` (verified) |
| `SyncError` condition `Failed last sync attempt to [...]` | An automated sync failed or was terminated; that commit will not be tried again | Push the fix; auto-sync runs the new commit (verified) |

---

## 7. Optional stretch challenges

### Stretch 1 — rollback is blocked under auto-sync (verified)

**Do:**

```bash
argocd app history storefront-dev
argocd app rollback storefront-dev 2
```

**Expect:**

```text
{"level":"fatal","msg":"rpc error: code = FailedPrecondition desc = rollback cannot be initiated when auto-sync is enabled","time":"2026-09-13T22:05:53-04:00"}
```

**Click** (the guide's UI path): **History and Rollback** → the **⋮** menu on an older entry → **Rollback**. The menu item is present in v3.5.2 (verified); the UI's refusal message itself was not captured.

**Answer key (two sentences):** A rollback changes the cluster but not Git, so automated sync would immediately sync forward to Git again and undo it — refusing is the honest behavior. The GitOps-consistent rollback is `git revert` in the source repository.

### Stretch 2 — automated retries (verified)

Add to the dev Application's `syncPolicy`, commit, and apply:

```yaml
    retry:
      limit: 2
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 1m
```

Then re-introduce the Part B failure **with a visible change** (a hook-only change never starts automated sync). Verified timeline:

```text
t=10s  Running retryCount=1 | Retrying attempt #1
t=20s  Running retryCount=2 | Retrying attempt #2
t=46s  Failed  retryCount=2 | one or more synchronization tasks completed unsuccessfully (retried 2 times).
       condition SyncError: Failed last sync attempt to [07883e0f0d054017bd543d2af9c1f946bd8649ec]: one or more synchronization tasks completed unsuccessfully (retried 2 times).
t+15s  still Failed; no new attempt on that commit
fix 4aea0d0 pushed and refreshed -> automated sync started by itself -> Succeeded 12 s later (no terminate-op)
```

**Answer key — the precise scope:** retry re-runs a sync that failed *while executing*, for the **same** revision, up to the limit. It does not start a new sync when nothing in Git changed, and — as the automated path in Section 6 showed — it does not adopt a newer commit while it is still retrying (unless `syncPolicy.retry.refresh: true`, added in v3.2). Once the retries are exhausted, a new commit is picked up normally. Also point out: without any `retry:` block, v3.5.2 automated sync already retries 5 times, so `limit: 2` *reduced* retries.

Remove the `retry:` block when done: `git revert` that commit and apply the file again (verified: the next automated operation carried `retry={"limit":5}` again).

---

## 8. Checkpoint — the Day 1 outcome

### 8.1 Both environments green at the latest commit

**Do** (the SHA check that works on v3.5.2; run from `~`):

```bash
argocd app list | grep storefront
kubectl --context k3d-mgmt -n argocd get applications storefront-dev storefront-staging \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision'
git -C storefront-gitops rev-parse HEAD
```

**Expect** (verified, right after Part B's recovery and before the stretches):

```text
argocd/storefront-dev      https://k3d-workload-server-0:6443  storefront-dev      storefront  Synced  Healthy  Auto        <none>      http://lab-gitea:3000/course/storefront-gitops.git  charts/storefront  main
argocd/storefront-staging  https://k3d-workload-server-0:6443  storefront-staging  storefront  Synced  Healthy  Manual      <none>      http://lab-gitea:3000/course/storefront-gitops.git  charts/storefront  main
NAME                 SYNC     HEALTH    REVISION
storefront-dev       Synced   Healthy   a4963fa5a7232fae2d37bd6a93213376ff57ff91
storefront-staging   Synced   Healthy   a4963fa5a7232fae2d37bd6a93213376ff57ff91
a4963fa5a7232fae2d37bd6a93213376ff57ff91
```

Staging last *synced* at `fb5b61c`, yet reports `a4963fa`: `status.sync.revision` is the commit Argo CD compared against, and nothing staging renders changed since. `curl` returned `storefront DEV` and `storefront STAGING` (verified).

### 8.2 The four "where I would look first" notes — answer key

| Failure class | (a) First place to look | (b) Owning component | (c) Where the fix lives |
|---|---|---|---|
| Repository / access | Settings → Repositories, or `argocd repo list` — read the MESSAGE ("repository not found" vs "no such host" vs credentials) | repo-server (it fetches Git) | The repository Secret in `argocd` (URL, username, password) |
| Rendering | The Application's **conditions** (`ComparisonError`) — not the sync result | repo-server (`helm template`) | The repo that holds the broken reference or value: `platform-config` for `valueFiles`, `storefront-gitops` for values and templates |
| Synchronization / ordering | The **sync result** — the hook or resource row that failed, and the phase it was in (for an automated sync, also a `SyncError` condition once it stops) | application-controller | The desired state in Git (here, `envs/dev/values.yaml`), committed as a new revision and synced |
| Health | The resource tree's health column, then the workload itself: `kubectl describe` / events / `curl` | application-controller reports it; Kubernetes produces it | Usually Git (image tag, probes, replicas) — `Synced` + `Degraded` means Git asked for something broken |

---

## 9. Debrief (5 minutes)

1. **"Which failure today was loud in the UI but silent in the cluster?"** — Part A, rendering. Nothing was applied.
2. **"Which kind of failure is quiet in the UI but visible to users?"** — none today. Replay E2's question: a promoted tag that doesn't exist gives `Synced` + `Degraded` while users are still fine, thanks to the rolling update. Ask: "what if there had been only one replica and no old Pod?"
3. **"Why didn't auto-sync run Part B?"** — a hook isn't compared, and automated sync needs `OutOfSync`. If anyone hit the automated path: a running operation is pinned to its revision, and `terminate-op` releases it.
4. **"Name the moment `git revert` saved you today."** — Part A: one reviewable commit restored the values-file reference.

### Key takeaways — say them out loud

> "`helm list` is empty and that is correct. There's no release to roll back — only a commit to revert."

> "Drift is discovered by a comparison: for a hand edit within a second, for a new commit within a minute."

> "Self-heal does not block your edit. It outlives it."

> "A rendering failure and a sync failure are equally red and live in completely different places. Telling them apart is most of troubleshooting."

> "Revert when you do not know why; roll forward when you do."

### Transition

**Say:**

> "That's the Day 1 outcome: one Git-to-cluster deployment, two environments, recovered from two kinds of failure without touching the cluster by hand. Tomorrow the question changes from 'how do I deploy one app safely?' to 'how do I deploy fifty without multiplying my blast radius fifty times?'"
