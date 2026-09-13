# Lab 3 — Instructor Walkthrough and Solutions

> **INSTRUCTOR ONLY. Never share this file with participants, never project it, and never paste it into a shared channel.**
> **Participant guide:** [lab-03-deploy-drift-and-recover.md](../../day-1/lab-03-deploy-drift-and-recover.md)
> **Timebox:** 60 minutes · **Scaffolding:** G2 (reduced)
> **Verified:** 2026-09-13, end to end, on the course's local k3d two-cluster sandbox: Argo CD `v3.5.2` (chart `10.8.4`), `argocd` CLI `v3.5.2`, Kubernetes `v1.35.8+k3s1`, Helm `v4.2.1`, starting from a verified `CP-lab-03`. Every output block below was captured from that run unless marked otherwise. SHAs, Pod suffixes, and times will differ on your machine.

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

This lab has **two defects that will derail you live if you don't know about them in advance.** Read 0.1 and 0.2 even if you skip everything else.

### 0.1 The image tag `6.16.0` does not exist — the Exercise 2 promotion always fails

The guide says "your classroom pre-loads `stefanprodan/podinfo:6.16.0`" and treats a failure as an offline-only edge case. Verified on 2026-09-13:

- The environment pre-loads only `stefanprodan/podinfo:6.15.0` (`PODINFO_IMAGE` in `courseware/environment/scripts/lib/common.sh`).
- **Docker Hub has no `6.16.0` tag.** The newest podinfo release is `6.15.0` (published 2026-08-31); the one before it is `6.14.1`.
- Result: promoting dev to `6.16.0` puts the new Pod in `ImagePullBackOff` with `not found`. The Deployment turns `Degraded` after its 60-second progress deadline, while the **old Pod keeps serving `6.15.0`**.

**Your plan:** run the promotion exactly as written, let it fail, and use it as the "roll forward failed → revert" moment the guide's own Troubleshooting table describes. Section 3 scripts this. It is honestly one of the best moments in Day 1 — *if* you know it is coming.

**Alternative if you prefer the promotion to succeed:** have the environment owner seed the env values at `6.14.1` and promote to `6.15.0`. Both tags exist. Do not improvise this mid-class; the images must be pre-loaded for offline VMs.

### 0.2 Exercise 5 Part B does not reproduce as written on v3.5.2

Verified three times in rehearsal:

1. **Committing only `migration.shouldFail: true` does nothing.** The flag changes only the PreSync hook Job, and hooks are not part of the compared state. The app goes straight to `Synced` at the new commit, automated sync never runs, and the hook never fails.
2. **When the sync does fail, it doesn't stop at `Failed`.** On v3.5.2, automated sync retries a failed sync **5 times by default** (5 s, 10 s, 20 s, 40 s, 80 s) even with no `retry:` block in the Application ([Argo CD docs — Automated Sync Policy](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)). The operation shows `Phase: Running` with `Retrying attempt #N`.
3. **Pushing the fix does not rescue a retrying operation.** The running operation stays pinned to the bad revision. `argocd app terminate-op storefront-dev` releases it, and automated sync then picks up the fix within seconds. (This matches upstream issue [argoproj/argo-cd#11494](https://github.com/argoproj/argo-cd/issues/11494).)

**Your plan:** in Part B, commit the `shouldFail` flag **together with a visible change** (a new `ui.message`), so the app actually goes `OutOfSync` and auto-sync fires. Recover with a roll-forward commit **plus** `argocd app terminate-op`. Section 6 has the exact, verified script.

### 0.3 Other small guide discrepancies

| Where | Guide says | Actually (verified) |
|---|---|---|
| Troubleshooting row 2 | Rejected with *"application destination … is not permitted in project 'storefront'"* | `InvalidSpecError  application destination server 'https://k3d-workload-server-0:6443' and namespace 'storefront-staging' do not match any of the allowed destinations in project 'storefront'` |
| Exercise 4 step 3 | Expect the self-heal revert "within roughly one 60-second interval" | Reverted in **about 2 seconds**, both attempts. The 60-second timer is for Git polling; Argo CD watches the resources it manages |
| Section 9.1 | `argocd app list -o wide` shows a REVISION column with the SHA | v3.5.2's `-o wide` shows `TARGET` (`main`), not the SHA. Use the `kubectl` command in Section 8 |

### 0.4 Confirm the starting checkpoint

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-03 --verify-only --local
```

Expect every row `PASS` (the Lab 2 walkthrough shows the verified 11-row table).

---

## Run of show (60 minutes)

| Clock | Segment | Your job |
|---|---|---|
| 0:00–0:04 | Why this matters + environment check | "Is it drift, rendering, or ordering?" — put the three words on the board |
| 0:04–0:14 | E1 — deploy and "render, not release" | The `helm list` moment |
| 0:14–0:24 | E2 — staging + promotion | Let the promotion fail (0.1); run the revert together |
| 0:24–0:32 | E3 — drift under manual sync | Collect predictions before scaling |
| 0:32–0:44 | E4 — self-heal on, prune off | 2 a.m. debrief |
| 0:44–0:58 | E5 — break it two ways | Use the corrected Part B |
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
| Before sync | chart + dev values | ConfigMap, Service, Deployment, plus the PreSync migration Job (the repo-server can already produce them — that's why Lab 2 showed `OutOfSync`) | Nothing in `storefront-dev` |
| Immediately after Sync | chart + dev values | Same | Migration Job completes first, then ConfigMap (wave −1), then Deployment and Service (wave 0); the Deployment is `Progressing` until its Pod is Ready |

### Run it

**Do:**

```bash
argocd app sync storefront-dev
```

**Expect** (verified — note the order and the Deployment still `Progressing` at the moment the operation finished):

```text
Operation:          Sync
Sync Revision:      cbeba814dc4f10b45548c6f0806308a11796747f
Phase:              Succeeded
Start:              2026-09-13 00:39:39 -0400 EDT
Finished:           2026-09-13 00:39:47 -0400 EDT
Duration:           8s
Message:            successfully synced (all tasks run)

GROUP  KIND        NAMESPACE       NAME                  STATUS     HEALTH       HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Succeeded  Synced       PreSync  Reached expected number of succeeded pods
       ConfigMap   storefront-dev  storefront            Synced                           configmap/storefront created
       Service     storefront-dev  storefront            Synced     Healthy               service/storefront created
apps   Deployment  storefront-dev  storefront            Synced     Progressing           deployment.apps/storefront created
```

Ten seconds later, `argocd app get storefront-dev` shows `Synced` / `Healthy`.

**Say:** "Eight seconds. The first two went to a Job you never listed in any Application. Why did it run first?"

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
"version": "6.15.0"
"message": "storefront DEV"
```

### Wrong turns

- **"Nothing is there"** after syncing → they ran `kubectl` against `k3d-mgmt`. "Which cluster did you deploy *to*?"
- **Expecting a release in `helm list`** → the point of the exercise; don't correct it until after they've seen the empty output.

---

## 3. Exercise 2 — Deploy staging, then promote a tag

### Part 1 — the staging Application

**Answer key — predicted differences** between `envs/dev/values.yaml` and `envs/staging/values.yaml`: namespace (`storefront-dev` → `storefront-staging`), replica count (`1` → `2`), UI message (`storefront DEV` → `storefront STAGING`), UI colour (`#2da44e` → `#bf8700`). **Not different:** the image tag (both `6.15.0`).

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

**Expect** (verified):

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

**Expect** (verified):

```text
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
storefront   2/2     2            2           3s
```

`curl` against `storefront-staging` returns `"message": "storefront STAGING"` and `"version": "6.15.0"` (verified). **Click:** App Details → Parameters for [SS-L3-03](../../assets/screenshots/day-1/lab-03-03-parameters-values-files.png).

**Wow moment:**

> "Same chart. Same repo. Same image. Two different running applications. The only thing that made them different is which values file the Application points at — that's why the values file, not the chart, is where environments live."

### Part 2 — the promotion (it will fail — that's the lesson)

**Say:** "Dev has validated `6.16.0`. Promote it. First to dev."

**Do:**

```bash
cd ~/storefront-gitops
sed -i 's/tag: "6.15.0"/tag: "6.16.0"/' envs/dev/values.yaml
git diff
git commit -am "dev: podinfo 6.16.0" && git push
argocd app sync storefront-dev
```

**Expect** (verified — the diff is one line):

```text
@@ -2,7 +2,7 @@
 namespace: storefront-dev
 replicaCount: 1
 image:
-  tag: "6.15.0"
+  tag: "6.16.0"
```

The sync `Succeeded`. Then health goes `Progressing` for about 60 seconds, then `Degraded` (verified: `Degraded` at t=65 s):

```text
NAME                          READY   STATUS             RESTARTS   AGE
storefront-75cddb6b87-rkz4l   1/1     Running            0          3m30s
storefront-76c6b5ff88-hpchc   0/1     ImagePullBackOff   0          2m3s
```

```text
Warning   Failed   pod/storefront-76c6b5ff88-hpchc   Failed to pull image "stefanprodan/podinfo:6.16.0": rpc error: code = NotFound desc = failed to pull and unpack image "docker.io/stefanprodan/podinfo:6.16.0": failed to resolve reference "docker.io/stefanprodan/podinfo:6.16.0": docker.io/stefanprodan/podinfo:6.16.0: not found
```

**Say — let them diagnose it before you explain:**

> "Sync status?" *(Synced.)* "Health?" *(Degraded.)* "Is the app down?"

**Do:**

```bash
kubectl --context k3d-workload -n storefront-dev port-forward svc/storefront 9898:9898 >/tmp/pf.log 2>&1 &
sleep 2; curl -s localhost:9898 | grep -o '"version": *"[^"]*"'; kill %1
```

**Expect** (verified): `"version": "6.15.0"`

**Wow moment:**

> "`Synced` and `Degraded`. You deployed *exactly* what you asked for — and what you asked for is broken. The bug is in Git. And look: users are still getting 6.15.0, because Kubernetes refused to kill the old Pod until the new one was Ready. The rolling update just saved you. Now: do we roll forward or revert?"

> "We don't know that 6.16.0 will ever exist. When you don't know why, you revert."

**Do** (if participants already promoted staging too, revert both commits in one go — verified):

```bash
cd ~/storefront-gitops
git log --oneline -3
git revert --no-edit HEAD            # add HEAD~1 if staging was promoted as well
git push
argocd app sync storefront-dev
argocd app sync storefront-staging   # only if staging was promoted
argocd app list
```

**Expect** (verified, after reverting both promotions):

```text
3f9c581 Revert "dev: podinfo 6.16.0"
b06f9e5 Revert "staging: promote podinfo 6.16.0 from dev"
8e12dc1 staging: promote podinfo 6.16.0 from dev
afb5890 dev: podinfo 6.16.0

NAME                       ...  STATUS  HEALTH   SYNCPOLICY
argocd/storefront-dev      ...  Synced  Healthy  Manual
argocd/storefront-staging  ...  Synced  Healthy  Manual
```

**Say:**

> "Read that `git log` from the bottom up. Promotion, promotion, revert, revert. Anyone reviewing this tomorrow can see exactly what happened and when. A `git reset --hard` would have erased the evidence."

### The render-only promotion check (still worth showing)

**Do:**

```bash
cd ~/storefront-gitops
helm template storefront charts/storefront -f envs/staging/values.yaml | grep 'image:'
```

**Expect** (verified, with staging on `6.16.0`):

```text
          image: "stefanprodan/podinfo:6.16.0"
          image: busybox:1.37.0
```

**Say:** "Two images. One is our app. The other is the migration Job. `helm template` renders locally, changes nothing on any cluster, and would have shown the new tag — but it can't tell you whether that tag *exists* in a registry. Rendering proves the YAML is right. Only a pull proves the image is real."

### Success criterion — adjusted for 0.1

Grade on: both Applications `Synced`/`Healthy` **after the revert**, staging at `2/2` and `storefront STAGING`, and a `git log` showing the promotion commits **and** their reverts.

---

## 4. Exercise 3 — Introduce live drift under manual sync

### Answer key — the prediction

| After scaling to 3 replicas… | Sync status | Health status | Reverts on its own? |
|---|---|---|---|
| | `OutOfSync` | `Healthy` | **No** |

### Run it

**Say** — take a hand vote on "which badge changes?" before running.

**Do:**

```bash
kubectl --context k3d-workload -n storefront-dev scale deploy/storefront --replicas=3
argocd app get storefront-dev | grep -E "Sync Status|Health Status"
```

**Expect** (verified — read immediately after the scale, *before* any refresh):

```text
Sync Status:        Synced to main (3f9c581)
Health Status:      Healthy
```

**Say:** "Still `Synced`. Did Argo CD miss it?"

**Do:**

```bash
argocd app get storefront-dev --refresh
argocd app diff storefront-dev; echo "diff exit=$?"
```

**Expect** (verified):

```text
Sync Status:        OutOfSync from main (3f9c581)
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

Wait 70 seconds. **Expect** (verified): still `OutOfSync` / `Healthy`, and `storefront   3/3`.

### Answer key — "why didn't health move?" (one sentence)

> "Three ready replicas is a perfectly working Deployment — health asks 'is it working?', and it is; only the sync question ('does it match Git?') changed."

### Wow moment

> "Drift isn't detected, it's discovered. For a moment the cluster was wrong and every badge was green. Then a comparison ran, and the badge caught up. And under manual sync, Argo CD's job ends at *reporting* — it will tell you about this drift forever and never fix it."

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
Sync Status:        Synced to main (3f9c581)
Health Status:      Healthy
```

### The self-heal race

**Say:** "Predict: how long until my edit is undone? Guesses in seconds."

Most rooms say "about a minute" — the guide says so too.

**Do:**

```bash
kubectl --context k3d-workload -n storefront-dev scale deploy/storefront --replicas=3
for i in $(seq 1 30); do
  r=$(kubectl --context k3d-workload -n storefront-dev get deploy storefront -o jsonpath='{.spec.replicas}')
  echo "$(date +%T) spec.replicas=$r"; [ "$r" = "1" ] && break; sleep 1
done
kubectl --context k3d-mgmt -n argocd get application storefront-dev -o jsonpath='{.status.operationState.operation.initiatedBy}{"\n"}'
```

**Expect** (verified, twice in a row):

```text
reverted to spec.replicas=1 after 2s (app sync=Synced)
initiatedBy: {"automated":true}
```

**Wow moment:**

> "Two seconds. Not sixty. The sixty-second timer is how often Argo CD asks *Git* 'anything new?'. The cluster is different — Argo CD keeps a live watch on every resource it manages, so it hears your edit almost immediately. Self-heal doesn't block your edit. It outlives it."

**Click:** the latest Sync operation for [SS-L3-07](../../assets/screenshots/day-1/lab-03-07-self-heal-evidence.png): initiated by the **automated sync policy**, not by a user.

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

**Expect** (verified): `Service/storefront  Prune=false`. Because dev now auto-syncs, the annotation reached the live Service within about 12 seconds (verified). Staging, still manual, shows `OutOfSync` until someone syncs it — a nice unplanned demonstration of the difference between the two policies.

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

**Prove nothing on the cluster changed** (verified — the same two Pods before and after, and the last sync operation still points at the old revision):

```bash
kubectl --context k3d-workload -n storefront-staging get pods
kubectl --context k3d-mgmt -n argocd get application storefront-staging \
  -o jsonpath='phase={.status.operationState.phase} rev={.status.operationState.syncResult.revision}{"\n"}'
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

The `ComparisonError` clears. If the Exercise 4 `Prune=false` commit landed since staging's last sync, staging shows `OutOfSync` on the Service — run `argocd app sync storefront-staging` and it returns to `Synced`/`Healthy` (verified).

**Wow moment:**

> "Sync `Unknown`, health `Healthy`. Argo CD couldn't produce manifests, so it couldn't compare — and it refused to guess. Meanwhile every Pod kept running. A rendering failure is loud in the UI and silent in the cluster."

### Part B — the ordering failure (use this corrected script)

**Why the guide's version doesn't fire** — see pre-flight 0.2. Explain it briefly *after* the demo if anyone tried the guide's step alone and "nothing happened"; it's a genuinely great insight:

> "You changed something that only a hook uses. Hooks aren't part of what Argo CD compares. So from Argo CD's point of view, nothing that it manages changed — the app is already `Synced` — and automated sync only runs when something is `OutOfSync`."

**Do** — the corrected break (a visible change plus the failing migration, in one commit; verified):

```bash
cd ~/storefront-gitops
cat >> envs/dev/values.yaml <<'EOF'
migration:
  shouldFail: true
EOF
sed -i 's/message: "storefront DEV"/message: "storefront DEV v2"/' envs/dev/values.yaml
git diff
git commit -am "dev: new banner text + schema migration" && git push
argocd app get storefront-dev --refresh >/dev/null
```

**Say** — before looking: "Is this a Job problem, a Secret problem, or a wave problem?"

**Do** (watch the operation):

```bash
argocd app get storefront-dev --show-operation
```

**Expect** (verified — note `Running` and "Retrying", not `Failed`):

```text
Operation:          Sync
Sync Revision:      01465466c5e1da17b1f69aae144c8c410b5644f6
Phase:              Running
Duration:           1m24s
Message:            one or more synchronization tasks completed unsuccessfully. Retrying attempt #4 at 4:57AM.

GROUP  KIND        NAMESPACE       NAME                  STATUS     HEALTH   HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Failed     Synced   PreSync  Job has reached the specified backoff limit
       ConfigMap   storefront-dev  storefront            OutOfSync
       Service     storefront-dev  storefront            Synced     Healthy
apps   Deployment  storefront-dev  storefront            Synced     Healthy
```

Verified retry timeline (backoff 5 s, 10 s, 20 s, 40 s…):

```text
t=6s   Running retryCount=1 | one or more synchronization tasks completed unsuccessfully. Retrying attempt #1
t=19s  Running retryCount=2 | ... Retrying attempt #2
t=42s  Running retryCount=3 | ... Retrying attempt #3
t=83s  Running retryCount=4 | ... Retrying attempt #4
operation.retry (as attached by controller) = {"limit":5}
```

**Prove the later phases never ran** (verified):

```bash
kubectl --context k3d-workload -n storefront-dev get cm storefront -o jsonpath='{.data.PODINFO_UI_MESSAGE}{"\n"}'
```

**Expect:** `storefront DEV` — the *old* banner. The ConfigMap in wave −1 never applied.

**Answer key — the symptom table:**

| Symptom | Hypothesis | Where the evidence is |
|---|---|---|
| The sync operation is failing/retrying | **Job** — specifically a PreSync gate | Sync result: the `storefront-migration` row, `HOOK PreSync`, `Job has reached the specified backoff limit` |
| The Deployment / ConfigMap did not update | **Wave** — the Sync phase is blocked behind the failed PreSync phase | The ConfigMap row stays `OutOfSync`; live ConfigMap still has the old message |

It is not a Secret problem: nothing references a Secret.

**Job logs** — use the Pod, because the hook's `BeforeHookCreation` policy deletes and recreates the Job on every retry, so `kubectl logs job/storefront-migration` can briefly return `NotFound` (verified). When it's present, the log reads:

```text
Running storefront schema migration...
migration failed: incompatible schema
```

### Recover — roll forward, then release the stuck operation

**Say:** "We understand the failure — the flag says fail. That's a roll-forward. Commit the fix."

**Do:**

```bash
cd ~/storefront-gitops
sed -i 's/shouldFail: true/shouldFail: false/' envs/dev/values.yaml
git commit -am "dev: fix schema migration (roll forward)" && git push
argocd app get storefront-dev --refresh >/dev/null
argocd app get storefront-dev --show-operation | grep -E "Sync Revision|Phase|Message"
```

**Expect** (verified — **70+ seconds after pushing the fix, the operation was still retrying the *bad* revision**):

```text
Sync Revision:      46743589656ee8d3b861515601908bdda60b7520
Phase:              Running
Message:            Retrying operation. Attempt #4
```

**Wow moment:**

> "We fixed Git, and Argo CD is still trying the broken commit. A running operation is pinned to the revision it started with. Retries are a promise to try *the same thing* again — they don't go looking for new commits."

**Do:**

```bash
argocd app terminate-op storefront-dev
```

**Expect** (verified — auto-sync picked up the fix within 2 seconds and finished in 11):

```text
Application 'storefront-dev' operation terminating

t=2s   Running  rev=bbd58282…  waiting for deletion of hook batch/Job/storefront-migration
t=6s   Running  rev=bbd58282…  waiting for completion of hook batch/Job/storefront-migration
t=11s  Succeeded rev=bbd58282… successfully synced (all tasks run)  app=Synced/Healthy
```

```text
GROUP  KIND        NAMESPACE       NAME                  STATUS     HEALTH   HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Succeeded  Synced   PreSync  Reached expected number of succeeded pods
       ConfigMap   storefront-dev  storefront            Synced                       configmap/storefront configured
       Service     storefront-dev  storefront            Synced     Healthy           service/storefront unchanged
apps   Deployment  storefront-dev  storefront            Synced     Healthy           deployment.apps/storefront unchanged
```

`argocd app history storefront-dev` shows the recovery as a new entry at the fixed SHA (verified).

**Optional tidy-up** so later demos start from the original banner: set `message: "storefront DEV"`, commit, push (verified: auto-synced and `Healthy` in 12 seconds).

### Revert or roll forward — answer key

| Part | Choice | Justification |
|---|---|---|
| A | **Revert** | Fine to revert: the change itself was the mistake, and reverting restores the last known-good reference. (Rolling forward by typing the correct filename is also acceptable if they can say why.) |
| B | **Roll forward** | We understood the cause (a flag that says "fail"). Committing `shouldFail: false` keeps the intended banner change and removes only the failure. |

**Component and repo for each:**

| Part | Owning component | Repo that held the fix |
|---|---|---|
| A | repo-server (rendering) | `platform-config` (the Application's `valueFiles`) |
| B | application-controller (sync execution) | `storefront-gitops` (the env values) |

### If it goes sideways

| Symptom | What's happening | Recovery |
|---|---|---|
| Participant committed only `shouldFail: true`; "nothing happened" | Hook-only change; app already `Synced` | Add a visible change (for example the banner) in a new commit — or run `argocd app sync storefront-dev` manually. *(The manual-sync variant was not rehearsed.)* |
| `another operation is already in progress` on a manual sync | The automated operation is retrying | `argocd app terminate-op storefront-dev` |
| Fix pushed, app still retrying | Operation pinned to the old revision | `argocd app terminate-op storefront-dev` |

---

## 7. Optional stretch challenges

### Stretch 1 — rollback is blocked under auto-sync (verified)

**Do:**

```bash
argocd app history storefront-dev
argocd app rollback storefront-dev <an-earlier-ID>
```

**Expect:**

```text
{"level":"fatal","msg":"rpc error: code = FailedPrecondition desc = rollback cannot be initiated when auto-sync is enabled",...}
```

**Answer key (two sentences):** A rollback changes the cluster but not Git, so automated sync would immediately sync forward to Git again and undo it — refusing is the honest behavior. The GitOps-consistent rollback is `git revert` in the source repository.

### Stretch 2 — retry with backoff (verified, with the Part B correction)

Add to the dev Application's `syncPolicy`:

```yaml
    retry:
      limit: 2
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 1m
```

Then re-introduce the Part B failure **with a visible change**. Verified result: `retryCount` climbs 1 → 2, then the operation ends:

```text
Phase:              Failed
Message:            one or more synchronization tasks completed unsuccessfully (retried 2 times).
```

**Answer key — the precise scope:** retry re-runs a sync that failed *while executing*, for the same revision. It does not start a new sync when nothing in Git changed — and, as Part B showed, it doesn't adopt a newer commit either. Also point out: without any `retry:` block, v3.5.2 automated sync already retries 5 times by default; setting `limit: 2` *reduced* retries.

Remove the `retry:` block when done (re-apply the Application from Git).

---

## 8. Checkpoint — the Day 1 outcome

### 8.1 Both environments green at the latest commit

**Do** (the SHA check that works on v3.5.2):

```bash
argocd app list | grep storefront
kubectl --context k3d-mgmt -n argocd get applications storefront-dev storefront-staging \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision'
git -C ~/storefront-gitops rev-parse HEAD
```

**Expect** (verified shape):

```text
NAME                 SYNC     HEALTH    REVISION
storefront-dev       Synced   Healthy   70a6d64b10db522c59cc10985c7a92577b7a2bf
storefront-staging   Synced   Healthy   70a6d64b10db522c59cc10985c7a92577b7a2bf
```

### 8.2 The four "where I would look first" notes — answer key

| Failure class | (a) First place to look | (b) Owning component | (c) Where the fix lives |
|---|---|---|---|
| Repository / access | Settings → Repositories, or `argocd repo list` — read the MESSAGE ("repository not found" vs "no such host" vs credentials) | repo-server (it fetches Git) | The repository Secret in `argocd` (URL, username, password) |
| Rendering | The Application's **conditions** (`ComparisonError`) — not the sync result | repo-server (`helm template`) | The repo that holds the broken reference or value: `platform-config` for `valueFiles`, `storefront-gitops` for values and templates |
| Synchronization / ordering | The **sync result** — the hook or resource row that failed, and the phase it was in | application-controller | The desired state in Git (here, `envs/dev/values.yaml`), committed as a *new* revision |
| Health | The resource tree's health column, then the workload itself: `kubectl describe` / events / `curl` | application-controller reports it; Kubernetes produces it | Usually Git (image tag, probes, replicas) — `Synced` + `Degraded` means Git asked for something broken |

---

## 9. Debrief (5 minutes)

1. **"Which failure today was loud in the UI but silent in the cluster?"** — Part A, rendering. Nothing was applied.
2. **"Which was quiet in the UI but visible to users?"** — none today, thanks to rolling updates — but the `6.16.0` promotion was `Degraded` while users were fine. Ask: "what if there had been only one replica and no old Pod?"
3. **"Why did the fix not rescue the stuck sync?"** — the running operation is pinned to its revision; `terminate-op` releases it.
4. **"Name the moment `git revert` saved you today."** — the promotion.

### Key takeaways — say them out loud

> "`helm list` is empty and that is correct. There's no release to roll back — only a commit to revert."

> "Drift is not detected, it is discovered — on the next comparison."

> "Self-heal does not block your edit. It outlives it."

> "A rendering failure and a sync failure are equally red and live in completely different places. Telling them apart is most of troubleshooting."

> "Revert when you do not know why; roll forward when you do."

### Transition

**Say:**

> "That's the Day 1 outcome: one Git-to-cluster deployment, two environments, recovered from two kinds of failure without touching the cluster by hand. Tomorrow the question changes from 'how do I deploy one app safely?' to 'how do I deploy fifty without multiplying my blast radius fifty times?'"
