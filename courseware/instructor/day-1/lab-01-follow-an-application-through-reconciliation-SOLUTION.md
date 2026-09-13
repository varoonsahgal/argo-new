# Lab 1 — Instructor Walkthrough and Solutions

> **INSTRUCTOR ONLY. Never share this file with participants, never project it, and never paste it into a shared channel.**
> **Participant guide (now a modular arc):** [lab-01/README.md](../../day-1/lab-01/README.md)
> **Exercise → module map:** E1 is in [module 01](../../day-1/lab-01/01-setup-and-dependencies.md); E2 Part 1 in [module 02](../../day-1/lab-01/02-commit-and-sync.md); E2 Parts 2–3 in [module 03](../../day-1/lab-01/03-why-the-app-didnt-change.md); E3, E4, and the stretch in [module 04](../../day-1/lab-01/04-three-views-and-wrap-up.md). Exercise IDs and answers below are unchanged.
> **Timebox:** 45 minutes · **Scaffolding:** G1 (maximally guided)
> **Verified:** 2026-09-13, end to end, on the course's local k3d two-cluster sandbox: Argo CD `v3.5.2` (chart `10.8.4`), `argocd` CLI `v3.5.2`, Kubernetes `v1.35.8+k3s1`, Helm `v4.2.1`. Every output block below was captured from that run unless it is explicitly marked otherwise. Commit SHAs, Pod suffixes, and ages will differ on your machine. Exercise 2 was redesigned and re-verified end to end on the same sandbox later that day (Parts 1–3, stretch A, and the two Part 3 wrong turns), starting from a fresh `CP-lab-01` reset.

---

## How to read this file

Each exercise is written as a narrated walkthrough you can run live with the class. The labels mean:

| Label | What it tells you |
|---|---|
| **Say** | Words you can use nearly verbatim. Adapt them, but keep the question marks: they are prompts for the room. |
| **Do** | A command you run on the projected VM terminal. |
| **Click** | A UI action in Firefox on the VM. |
| **Expect** | What the verified run showed. |
| **Answer key** | The answer participants should have reached, with the reasoning. |
| **Wrong turns** | Mistakes participants actually make, and what each one looks like on screen. |
| **Wow moment** | The one sentence worth pausing on. These are the lines people repeat to colleagues. |
| **If it goes sideways** | A live-demo recovery, tested in the rehearsal. |

The walkthrough follows the guide's order. When you "walk through the solution with students", run the **Do** steps on your own VM while they watch, and ask the **Say** questions *before* you reveal each **Expect** block.

---

## 0. Before class — pre-flight (10 minutes, on your own VM)

Do all four checks. Two of them catch real defects that will otherwise surprise you in front of the room.

### 0.1 Confirm the starting checkpoint

**Do:**

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-01 --verify-only --local
```

**Expect** (verified; note the two extra "absent" rows that the guide's sample does not show — they are harmless):

```text
==> Verification for CP-baseline
  PASS  Application hello-reconcile Synced/Healthy
  PASS  Application team-a-guestbook absent
  PASS  AppProject team-a absent
  PASS  Secret in-cluster present
  PASS  workload namespace storefront-prod present
  PASS  workload SA argocd-manager absent (not registered)

PASS CP-baseline is in the expected state.
```

### 0.2 Confirm the chart starts *without* a rollout trigger — Exercise 2 depends on it

**Do:**

```bash
git clone -q http://lab-gitea:3000/course/hello-reconcile.git /tmp/hr-check && \
grep -c 'annotations:' /tmp/hr-check/chart/templates/deployment.yaml; rm -rf /tmp/hr-check
```

**Expect:**

```text
0
```

**Why this matters (verified 2026-09-13):** Exercise 2 is built on a deliberate surprise. With no Pod-template annotation in the chart, a message-only sync updates the ConfigMap, **no new Pod starts**, and `curl` still returns the **old** message. Participants diagnose that in Part 2 and add a `checksum/config` annotation to the Pod template themselves in Part 3. The chart participants start from is never changed.

If this prints `1` or more, a rehearsal (possibly yours) left the Part 3 commit on `main`, and Part 1 will roll a Pod with nothing to diagnose. Run `reset-lab.sh CP-lab-01 --local`: it force-moves `main` back to the `cp-baseline` tag. Verified: after a rehearsal that added the annotation, the reset restored `deployment.yaml` to its baseline blob and the count returned to `0`.

### 0.3 Know where the participant guide is out of step with v3.5.2

You do not need to fix the guide mid-class. You need to recognize these when a participant raises a hand.

| Where | What the guide prints | What actually happens | What to tell the room |
|---|---|---|---|
| Section 6.2, `argocd app get` sample | `SyncWinow: <none>`, no `URL:` line, no `Source:` block | v3.5.2 prints a `URL:` line, a `Source:` block, `SyncWindow: Sync Allowed`, and a MESSAGE column such as `configmap/hello-reconcile unchanged` | "Same facts, newer layout. Read the labels, not the positions." |
| Exercise 3, `argocd app manifests … \| sed -n '/kind: ConfigMap/,/^---/p'` | The rendered ConfigMap | **Omits the `data:` block** — the one field participants need. Keys come out alphabetically, so `data:` appears *above* `kind:` and the `sed` range starts too late | Use `argocd app manifests hello-reconcile --source git \| yq 'select(.kind == "ConfigMap")'` |
| Exercise 2, Figure SS-L1-06 | Captioned as the diff view | The image file is the resource tree (identical to SS-L1-05), not the diff panel. The caption itself ("exactly one changed line: the ConfigMap's message") is correct for Part 1 | Show the diff live, or use the CLI diff block printed under the figure. The capture needs redoing |
| Exercise 2 Part 3 | Two capture specs, SS-L1-11 and SS-L1-12, with no image yet | Participants rely on the CLI and Window C output printed in the guide | Project your own tree after the Part 3 Refresh and after the sync |

### 0.4 Arrange your projected screen

Three panes, exactly as participants will: Firefox on the Argo CD Applications page (Window A), a terminal for `argocd` (Window B), and a terminal running the Pod watch (Window C). Increase the terminal font size before class; the diff output is small.

---

## Run of show (45 minutes)

| Clock | Segment | Your job |
|---|---|---|
| 0:00–0:02 | Why this matters | Frame the thermostat idea; ask "what is the smallest thing that can go wrong?" |
| 0:02–0:09 | Environment check + walkthrough (Sections 5–6) | Participants follow along; you narrate the three windows |
| 0:09–0:13 | E1 — dependency table | Silent individual work, then collect the "guess" numbers |
| 0:13–0:28 | E2 — predict, commit, diagnose, fix | Collect Part 1 predictions *before* anyone pushes; run the Part 2 "who's lying?" moment with the whole room before anyone starts Part 3 |
| 0:28–0:34 | E3 — desired vs rendered vs live | Pairs |
| 0:34–0:39 | E4 — status in three places | Pairs, then the "UI is down" question to the room |
| 0:39–0:45 | Solution walkthrough + debrief + takeaways | Run this file's E1–E4 answers live |

E2 grew from 10 to 15 minutes when it gained Parts 2 and 3; the time comes from shaving a minute off the opening, environment check, E1, E3, and debrief. If you are behind at 0:30, do E4 as a whole-class discussion instead of pair work: fill the table on the projector together.

---

## 1. Opening (2–3 minutes)

**Say:**

> "In Session 2 you learned the names. Today you watch the machine move. We are going to change one line in Git and follow that single change through four stations: Git notices, Argo CD compares, you approve, the cluster converges. You will see it three ways at once — the web interface, the `argocd` command line, and raw `kubectl` — and I want you to leave convinced they are telling one story."

> "Quick poll before we touch anything: when you push a commit, how long until Argo CD notices? Shout a number."

Take two or three answers, then:

> "Default is three minutes. This classroom is tuned to 60 seconds. So if you push and nothing happens for a minute, that is the machine working, not the machine broken. Hold that thought — someone will forget it in about ten minutes."

**Wow moment:**

> "Argo CD is a thermostat, not a light switch. `kubectl apply` happens once. Reconciliation never stops."

---

## 2. Environment check and guided walkthrough (Sections 5–6)

### 2.1 Log in to the CLI and read the Application

**Do:**

```bash
argocd login localhost:8443 \
  --username admin \
  --password "$(cat ~/course/credentials/argocd-admin.txt)" \
  --insecure
argocd app get hello-reconcile
```

**Expect** (verified):

```text
Name:               argocd/hello-reconcile
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          hello
URL:                https://localhost:8443/applications/hello-reconcile
Source:
- Repo:             http://lab-gitea:3000/course/hello-reconcile.git
  Target:           main
  Path:             chart
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        Synced to main (ae0e479)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME             STATUS  HEALTH   HOOK  MESSAGE
       ConfigMap   hello      hello-reconcile  Synced                 configmap/hello-reconcile unchanged
       Service     hello      hello-reconcile  Synced  Healthy        service/hello-reconcile unchanged
apps   Deployment  hello      hello-reconcile  Synced  Healthy        deployment.apps/hello-reconcile unchanged
```

**Say:**

> "Read the top block like a shipping label: which repo, which branch, which folder, which cluster, which namespace, which project, what sync policy. Now look at the ConfigMap row. Why is its HEALTH column empty?"

**Answer:** Argo CD has no health check for a ConfigMap — there is nothing about a ConfigMap that can be "working" or "broken". Health is computed only for kinds that have a meaningful running state (Deployments, Services, Pods, and so on).

**Click:** the `hello-reconcile` tile to open the resource tree ([Figure SS-L1-03](../../assets/screenshots/day-1/lab-01-03-resource-tree.png)).

**Say** (pointing at the Deployment → ReplicaSet → Pod chain):

> "Three boxes, but only one of them is in Git. Which one?"

**Answer:** The Deployment. Kubernetes created the ReplicaSet and the Pod on its own.

### 2.2 The 60-second micro-observation: deleting a Pod is not drift

**Do** (in Window C, with the Pod watch running in another pane):

```bash
kubectl --context k3d-mgmt -n hello delete pod -l app.kubernetes.io/name=hello-reconcile
```

**Say** *before* anything prints: "Prediction time. Will Argo CD go `OutOfSync`? Hands up for yes."

**Expect** (verified; the replacement Pod was `Running` within 8 seconds and Argo CD never moved):

```text
NAME                               READY   STATUS    RESTARTS   AGE
hello-reconcile-5b66f8d98c-x7qxq   1/1     Running   0          8h
pod "hello-reconcile-5b66f8d98c-x7qxq" deleted from hello namespace
NAME                               READY   STATUS    RESTARTS   AGE
hello-reconcile-5b66f8d98c-tfxdj   1/1     Running   0          11s
Synced / Healthy
```

**Wow moment:**

> "Two controllers just did two different jobs in front of you. The Kubernetes ReplicaSet controller replaced the Pod — that is its job. Argo CD did nothing, because the Pod was never in Git. Argo CD only watches what it owns. Deleting a Pod is not drift. Deleting the *Deployment* would be."

### 2.3 Read the Application manifest

**Do:**

```bash
kubectl --context k3d-mgmt -n argocd get application hello-reconcile -o yaml | yq '.spec'
```

**Expect** (verified):

```yaml
destination:
  namespace: hello
  server: https://kubernetes.default.svc
project: default
source:
  path: chart
  repoURL: http://lab-gitea:3000/course/hello-reconcile.git
  targetRevision: main
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

**Say:**

> "Find the application in here. The actual YAML for the app — the Deployment, the Service. Take ten seconds."

Let the silence sit.

> "It's not there. There is no workload YAML in an Application at all. An Application is an address, not an artifact. Every line is a pointer to something outside this object — and every pointer is something that can break on its own. That's Exercise 1."

---

## 3. Exercise 1 — List every external dependency

### What participants just attempted

Read the manifest (plus `chart/values.yaml` for the image) and build a table of every external thing `hello-reconcile` depends on, with what breaks if each one fails.

### Run the reveal

**Say:** "Before I show my table: what number did you guess before you started counting? Shout it out."

Collect numbers. Most rooms say two or three.

**Do** (to show where the image comes from):

```bash
cd ~/hello-reconcile 2>/dev/null || git clone -q http://lab-gitea:3000/course/hello-reconcile.git ~/hello-reconcile
grep -A2 '^image:' ~/hello-reconcile/chart/values.yaml
```

**Expect** (verified):

```yaml
image:
  repository: stefanprodan/podinfo
  tag: "6.15.0"
```

### Answer key

A complete answer has the eight rows below. Accept any wording that names the field and a concrete failure.

| # | Dependency | Where it is named | What breaks if it fails |
|---|---|---|---|
| 1 | Git server and repository | `spec.source.repoURL` (`http://lab-gitea:3000/course/hello-reconcile.git`) | Argo CD cannot fetch desired state. The app shows a `ComparisonError`, and nothing can be rendered or synced. |
| 2 | Revision | `spec.source.targetRevision` (`main`) | If the branch is renamed or deleted, rendering fails. If someone pushes to `main`, desired state changes without anyone deciding this environment should change. |
| 3 | Chart path | `spec.source.path` (`chart`) | If the folder moves, the repo-server reports "app path does not exist". |
| 4 | Destination cluster | `spec.destination.server` (`https://kubernetes.default.svc`, the management cluster itself) | If Argo CD cannot reach or authenticate to the cluster, sync status becomes `Unknown`. |
| 5 | Destination namespace | `spec.destination.namespace` (`hello`) | Without `CreateNamespace=true` and a missing namespace, the sync fails. With a wrong name, the app lands in the wrong place. |
| 6 | Governing project | `spec.project` (`default`) | If the project stops allowing this source or destination, Argo CD refuses the Application before any sync starts. |
| 7 | Repository credentials | *None* — the repo is public-read | No credential to expire today. In Lab 2, the private `storefront-gitops` repo adds a credential that *can* expire. |
| 8 | Container image registry/repository and tag | `chart/values.yaml` → `stefanprodan/podinfo:6.15.0` | If the image cannot be pulled, the new Pod sits in `ImagePullBackOff`, the Deployment eventually reports `Degraded`, and the old Pod keeps serving. |

**Bonus rows** (credit anyone who found these; they are not required):

- The **sync option** `CreateNamespace=true` — a dependency on the Argo CD service account being allowed to create namespaces on that cluster.
- **Argo CD's own components** — the repo-server must be running to render, the application controller to compare and apply. (Day 2's capstone breaks exactly this.)
- The **Helm templates** inside `chart/templates/` — a template error breaks rendering even when every address above is correct.

### Why it's correct

Every field under `spec.source` and `spec.destination` is an address, and every address resolves to something outside the Application. The image is the one dependency the manifest hides, because it lives in the chart — which is itself a reminder that "reading the Application" is never the whole picture.

### Wrong turns

- **Stopping at `spec.source`.** Participants list the repo and path and forget the destination and project. Ask: "Where does this app *go*, and who is allowed to send it there?"
- **Listing the ReplicaSet or Pod as dependencies.** Those are consequences, not dependencies. Redirect: "Is it named in the manifest or the chart?"
- **Skipping credentials because "there aren't any".** "None" is an answer, and it is the answer that changes in Lab 2.

### Wow moment

> "You just wrote down, in five minutes, the complete list of ways this application can be broken from the outside. Keep that page. On Day 2, the capstone is an incident where several of these rows break at once — and the people who finish fastest are the ones who start from this list instead of from the reddest badge."

---

## 4. Exercise 2 — Predict, commit a change, and find out why the app did not change

### What participants just attempted

Three parts:

- **Part 1 (Steps A–D):** fill a prediction table, change `message` in `chart/values.yaml`, push, refresh, read the diff, sync, and `curl` the app.
- **Part 2 (Step E):** gather four pieces of evidence and explain why the app still serves the old message.
- **Part 3 (Steps F–G):** add a `checksum/config` annotation to the Deployment's Pod template, push, sync, watch the rollout, and prove the new message is served.

**The design in one sentence:** the starting chart deliberately has no rollout trigger, so the message-only sync succeeds *and changes nothing a user can see*; the exercise turns that into a diagnosis and a real-world Helm fix, without changing the chart participants start from.

### Step A — collect predictions first

**Say:** "Before anyone pushes, look at the bottom row. After the sync completes: does a new Pod start? Which message does the app serve? Hands up if you think a new Pod starts."

Tally the hands and write the number on the board. Most rooms say yes. That number is your payoff in Part 2.

### Answer key — the Part 1 prediction table

| Moment | Sync status | Health status | New Pod? | Message served | Why |
|---|---|---|---|---|---|
| Right after `git push` | `Synced` | `Healthy` | No | revision one | Argo CD has not compared yet. Verified: an immediate `argocd app get` still printed `Synced to main (ae0e479)`, the baseline SHA. |
| After Refresh, before Sync | `OutOfSync` | `Healthy` | No | revision one | Git differs from the cluster, but only in the ConfigMap. The old Pod still serves correctly. |
| After the sync completes | `Synced` | `Healthy` | **No** | **revision one** | The sync updated the ConfigMap. Nothing in the Deployment's Pod template changed, so Kubernetes had no reason to start a Pod, and the running container still holds the old value in its environment. |

Verified: after the Part 1 sync, `argocd app get` was polled once a second for ten seconds, and every sample read `Synced Healthy Succeeded`. Health never passed through `Progressing`, because nothing rolled out.

### Steps B–C — make and push the change

**Do:**

```bash
cd ~
git clone http://lab-gitea:3000/course/hello-reconcile.git
cd hello-reconcile
git config user.email "student@lab.local"
git config user.name "Student"
sed -i 's/^message: .*/message: "Hello from Git, revision two"/' chart/values.yaml
git add chart/values.yaml
git commit -m "Lab 1: change message to revision two"
git push
git rev-parse HEAD
```

(When Git asks for credentials: username `student`, password from `~/course/credentials/gitea-student.txt`.)

### Step D — refresh, read the diff, sync, check the app

**Say:** "I've pushed. Nobody touch anything. What does the Applications page show right now?" (Answer: still `Synced` — it hasn't looked yet.)

**Click:** **Refresh** on the `hello-reconcile` tile (or run the CLI below).

**Do:**

```bash
argocd app get hello-reconcile --refresh
```

**Expect** (verified):

```text
Sync Status:        OutOfSync from main (17cb57e)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME             STATUS     HEALTH   HOOK  MESSAGE
       ConfigMap   hello      hello-reconcile  OutOfSync                 configmap/hello-reconcile configured
       Service     hello      hello-reconcile  Synced     Healthy        service/hello-reconcile unchanged
apps   Deployment  hello      hello-reconcile  Synced     Healthy        deployment.apps/hello-reconcile unchanged
```

This matches [Figure SS-L1-05](../../assets/screenshots/day-1/lab-01-05-outofsync-after-refresh.png): only the ConfigMap node carries the `OutOfSync` icon.

**Say:** "Right now, who is affected by this `OutOfSync`?"

**Answer:** Nobody. The previous version is still serving correctly. `OutOfSync` is a sentence about Git, not about users.

**Do:**

```bash
argocd app diff hello-reconcile; echo "diff exit=$?"
```

**Expect** (verified):

```text
===== /ConfigMap hello/hello-reconcile ======
4c4
<   PODINFO_UI_MESSAGE: Hello from Git, revision one
---
>   PODINFO_UI_MESSAGE: Hello from Git, revision two
diff exit=1
```

**Say** (plant the seed; do not explain it yet): "One resource in this diff. Remember which resource is *not* in it."

**Note for the exit code:** `argocd app diff` exits `1` when it finds a difference, `0` when there is none, and `2` when the comparison itself failed. The capstone relies on this.

**Click:** **Sync**. Leave **Prune** unchecked ([Figure SS-L1-07](../../assets/screenshots/day-1/lab-01-07-sync-panel.png)). Confirm.

**Expect in Window C** (verified): **nothing.** The Pod watch prints no new line. [Figure SS-L1-08](../../assets/screenshots/day-1/lab-01-08-synced-new-revision.png) was captured in exactly this state: `Synced` at the new SHA, and the same ReplicaSet `hello-reconcile-5b66f8d98c` (`rev:1`) as in SS-L1-05.

**Do:**

```bash
argocd app get hello-reconcile | grep -i "sync status"
kubectl --context k3d-mgmt -n hello port-forward svc/hello-reconcile 9898:9898 >/tmp/pf.log 2>&1 &
sleep 2
curl -s http://localhost:9898/ | grep -o '"message": *"[^"]*"'
kill %1
```

**Expect** (verified; the rehearsal forwarded local port `19898` because `9898` was already in use on that machine):

```text
Sync Status:        Synced to main (17cb57e)
"message": "Hello from Git, revision one"
```

**Say:** "Hands up if your app is saying revision two." (No hands.) "Now hands up if you predicted a new Pod." Point at the number on the board.

**Wow moment:**

> "Argo CD says `Synced`. The sync `Succeeded`. And your users are still reading revision one. Hold on to that contradiction for two minutes — it's the most useful thing you'll learn today."

### Step E (Part 2) — gather evidence, then explain

**Say:** "So who's lying? Git says two. Argo CD says it synced our commit. The app says one. Don't guess. Get one piece of evidence from each layer."

**Do:**

```bash
argocd app get hello-reconcile | grep -i "sync status"
kubectl --context k3d-mgmt -n hello get configmap hello-reconcile -o jsonpath='{.data.PODINFO_UI_MESSAGE}{"\n"}'
kubectl --context k3d-mgmt -n hello exec deploy/hello-reconcile -- env | grep PODINFO_UI_MESSAGE
kubectl --context k3d-mgmt -n hello rollout history deploy/hello-reconcile
kubectl --context k3d-mgmt -n hello get pods
```

**Expect** (verified; the sync finished at 20:26:55 UTC and the Pod had started at 17:05:09 UTC, which is why its age is hours — on a class VM it will be however long ago Lab 0 or the last reset ran):

```text
Sync Status:        Synced to main (17cb57e)
Hello from Git, revision two
PODINFO_UI_MESSAGE=Hello from Git, revision one
deployment.apps/hello-reconcile
REVISION  CHANGE-CAUSE
1         <none>

NAME                               READY   STATUS    RESTARTS   AGE
hello-reconcile-5b66f8d98c-fzsm9   1/1     Running   0          3h22m
```

Walk the evidence top to bottom: Argo CD deployed our commit. The ConfigMap object holds revision two. The **process** inside the container holds revision one. The Deployment has had exactly one rollout, ever, and the Pod is older than the sync.

### Answer key — the explanation

> The container copies `PODINFO_UI_MESSAGE` from the ConfigMap into its environment **once, when it starts**. The sync changed the ConfigMap but nothing in the Deployment's Pod template, so Kubernetes never started a new Pod — the same Pod (same name, same age, rollout revision still `1`) is still running with the old value.

Accept any answer with both halves: **(1) the value is read once, at container start**, and **(2) no Pod-template change means no rollout**.

Nobody lied. Git, Argo CD, and the ConfigMap agree. The running process is the one layer that never re-read.

**Wow moment:**

> "`Synced` means the *objects* in the cluster match Git. It does not mean every running program has picked up the change. Argo CD manages objects. It doesn't restart programs — Kubernetes does, and only when the Pod template changes."

### Part 3 — handle the tempting shortcut first

**Say:** "What's the fastest way to make it say revision two?"

Someone will say "delete the Pod" (they did it in Section 6.3) or "`kubectl rollout restart`".

**Answer:** Either works: a new Pod starts and reads the new ConfigMap. (Rehearsed in an earlier validation pass with `kubectl rollout restart deploy/hello-reconcile`.) Then ask:

> "Where is that restart recorded in Git? And what happens the *next* time someone changes the message?"

A manual restart fixes today's Pod and leaves the chart broken for every future change. The fix belongs in Git.

### Step F — add the checksum annotation

**Do:** edit `chart/templates/deployment.yaml` on the projector, then show the change:

```bash
cd ~/hello-reconcile
git --no-pager diff
```

**Expect** (verified):

```diff
diff --git a/chart/templates/deployment.yaml b/chart/templates/deployment.yaml
index 8c6ec0a..a808c41 100644
--- a/chart/templates/deployment.yaml
+++ b/chart/templates/deployment.yaml
@@ -13,6 +13,8 @@ spec:
     metadata:
       labels:
         app.kubernetes.io/name: hello-reconcile
+      annotations:
+        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
     spec:
       containers:
         - name: podinfo
```

**Say** (the chain, slowly, one link per sentence): "We change the message. The ConfigMap renders differently. Its fingerprint changes. The fingerprint lives inside the Pod template. So the Pod template changed. Kubernetes rolls a new Pod. The new Pod reads the new ConfigMap."

**Where the pattern comes from:** it is the Helm project's own recommendation, "Automatically Roll Deployments" in the *Chart Development Tips and Tricks* page (<https://helm.sh/docs/howto/charts_tips_and_tricks/>). Many public charts use exactly this line. The fingerprint changes when anything in the rendered ConfigMap changes — verified locally with Helm `v4.2.1`: changing `message` or `color` changed the checksum; changing `replicaCount` did not.

**Do** (the pre-push check participants run):

```bash
helm template hello-reconcile chart | grep 'checksum/config'
```

**Expect** (verified with the message `Hello from Git, revision two`):

```text
        checksum/config: 1ef56c65fb66d081174eb14dceaeb05c2e1fc624d4c006dca251d1dd7ba4e17b
```

**Say:** "Remember that fingerprint. In a minute, Argo CD's diff will show the *same* 64 characters — because Argo CD renders the chart with Helm too. Same chart, same values, same output."

**Say** (prediction, before pushing): "Which resource goes `OutOfSync` this time — ConfigMap, Deployment, or both? And what's the health *during* the sync?"

**Do:**

```bash
git add chart/templates/deployment.yaml
git commit -m "Lab 1: roll Pods when the ConfigMap changes"
git push
git rev-parse HEAD
```

### Step G — sync, watch, prove

**Do:**

```bash
argocd app get hello-reconcile --refresh
```

**Expect** (verified):

```text
Sync Status:        OutOfSync from main (22291a6)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME             STATUS     HEALTH   HOOK  MESSAGE
       ConfigMap   hello      hello-reconcile  Synced                    configmap/hello-reconcile configured
       Service     hello      hello-reconcile  Synced     Healthy        service/hello-reconcile unchanged
apps   Deployment  hello      hello-reconcile  OutOfSync  Healthy        deployment.apps/hello-reconcile unchanged
```

**Answer:** only the Deployment. The ConfigMap already matches Git — Part 1 synced it.

**If someone asks about the MESSAGE column:** it reports the result of the *last sync operation*, not the current comparison. That is why the ConfigMap still says `configured` (Part 1's sync) and the Deployment says `unchanged`. Read the STATUS column for the comparison.

**Do:**

```bash
argocd app diff hello-reconcile; echo "diff exit=$?"
```

**Expect** (verified — note the fingerprint is identical to the local `helm template` output):

```text
===== apps/Deployment hello/hello-reconcile ======
151a152,153
>       annotations:
>         checksum/config: 1ef56c65fb66d081174eb14dceaeb05c2e1fc624d4c006dca251d1dd7ba4e17b
diff exit=1
```

**Click:** **Sync**, Prune unchecked, confirm.

**Expect — status transitions** (verified, polling the Application every 0.5 s; the `Succeeded` on the first line belongs to Part 1's operation):

```text
20:28:17 OutOfSync/Healthy/Succeeded
20:28:19 Synced/Progressing/Succeeded
20:28:21 Synced/Healthy/Succeeded
```

**Expect in Window C** (verified; captured with `--output-watch-events` so each line is labeled, and duplicate lines removed):

```text
EVENT      NAME                               READY   STATUS              RESTARTS   AGE
ADDED      hello-reconcile-67fc76f88b-jgw7c   0/1     Pending             0          0s
MODIFIED   hello-reconcile-67fc76f88b-jgw7c   0/1     ContainerCreating   0          0s
MODIFIED   hello-reconcile-67fc76f88b-jgw7c   0/1     Running             0          1s
MODIFIED   hello-reconcile-67fc76f88b-jgw7c   1/1     Running             0          2s
MODIFIED   hello-reconcile-5b66f8d98c-fzsm9   1/1     Terminating         0          3h23m
MODIFIED   hello-reconcile-5b66f8d98c-fzsm9   0/1     Completed           0          3h23m
DELETED    hello-reconcile-5b66f8d98c-fzsm9   0/1     Completed           0          3h23m
```

**Wow moment:**

> "Look at the middle status line. `Synced` and `Progressing` at the same time. Sync says 'the cluster now matches Git'. Health says 'but the new Pod isn't ready yet'. Two separate questions, and for two seconds they gave two different answers. Now look at Window C: the new Pod was `1/1` Ready *before* the old one started terminating. At no moment did this app have zero Pods. That's a rolling update."

**Do** (prove):

```bash
argocd app get hello-reconcile | grep -i "sync status"
git -C ~/hello-reconcile rev-parse --short HEAD
kubectl --context k3d-mgmt -n hello rollout history deploy/hello-reconcile
kubectl --context k3d-mgmt -n hello get rs
kubectl --context k3d-mgmt -n hello port-forward svc/hello-reconcile 9898:9898 >/tmp/pf.log 2>&1 &
sleep 2
curl -s http://localhost:9898/ | grep -o '"message": *"[^"]*"'
kill %1
```

**Expect** (verified):

```text
Sync Status:        Synced to main (22291a6)
22291a6
deployment.apps/hello-reconcile
REVISION  CHANGE-CAUSE
1         <none>
2         <none>

NAME                         DESIRED   CURRENT   READY   AGE
hello-reconcile-5b66f8d98c   0         0         0       5h14m
hello-reconcile-67fc76f88b   1         1         1       36s
"message": "Hello from Git, revision two"
```

**Say:** "Two rollouts in the history now. Two ReplicaSets: the old one scaled to zero, kept so you can roll back. And the app finally says what Git says."

### Wrong turns

| What the participant sees | What happened | What you say |
|---|---|---|
| Nothing changes for a minute after pushing | The 60-second reconciliation timer | "The thermostat hasn't checked yet. Press Refresh — that's the impatient version of waiting." |
| `git push` rejected or prompts repeatedly | Wrong username, or the password pasted with a trailing newline | Username is `student`; use the credentials file |
| Part 2: participant deletes the Pod or runs `kubectl rollout restart`, and the new message appears | It works, and it skips the lesson | "Great — now change the message to revision three. Did it reach the app without you touching anything?" Steer them to Part 3 |
| Part 3: sync `Succeeded`, the Deployment was in the diff, but **no new Pod** and `curl` still shows the old message | The annotation went under the Deployment's **top-level** `metadata:` (the first one in the file). That annotates the Deployment object, not the Pod template. Verified: the diff shows `5a6` / `>     checksum/config: …` (four spaces, near the top of the object) instead of `151a152,153`; the sync succeeds; `rollout history` gains no revision; the container still has the old `PODINFO_UI_MESSAGE` | "Which of the two `metadata:` blocks describes the *Pods*? Only a change under `spec.template` rolls Pods." Cue: `helm template … \| grep checksum` shows the line indented by four spaces instead of eight |
| Part 3: sync status `Unknown` and a `ComparisonError` condition right after pushing | A typo in the template line. Verified with `sha256` instead of `sha256sum`: `Failed to load target state: … failed to execute helm template command … parse error at (hello-reconcile/templates/deployment.yaml:8): function "sha256" not defined`. Health stayed `Healthy` | "That's the repo-server failing to *render*. Nothing was applied, so the running app is untouched." Have them run `helm template hello-reconcile chart` locally — verified to print the same `function "sha256" not defined` error — fix, commit, push, Refresh |
| Part 3: `curl` cannot connect to `localhost:9898` | A port-forward left running from Part 1 was attached to the old Pod and exited when the rollout deleted that Pod (verified: a port-forward open across the rollout had exited, and `curl` returned exit code `7`) | "A port-forward follows one Pod, not the Service. New Pod, new port-forward." |
| Participant ticked **Prune** in the sync panel | Harmless here (nothing to prune) | "Nothing to delete this time. In Lab 3 we'll talk about why that checkbox deserves respect." |

### If it goes sideways

- **Part 1 rolls a new Pod and `curl` shows the new message immediately.** The class VM's `main` already contains a Pod-template annotation — usually a rehearsal that was not reset. The Part 2 diagnosis has nothing to diagnose. Recover live by making the point from the diff: "See the Deployment in this diff? Somebody already added the fix you'd have built." Then skip to Step F and have participants *read* the annotation instead of adding it. Before the next class, run pre-flight 0.2.
- **The rollout in Part 3 is too fast to see `Progressing` in the browser.** Expected (about two seconds in rehearsal). Point at Window C instead: the order of the Pod lines is the durable evidence.

---

## 5. Exercise 3 — Compare desired, rendered, and live

### What participants just attempted

View the ConfigMap as rendered from Git and as it lives in the cluster, name at least three live-only fields, explain why they are not drift, and locate the tracking annotation.

### Run it

**Do** (the corrected commands — see pre-flight 0.3):

```bash
# Rendered from Git, at the revision Argo CD is tracking:
argocd app manifests hello-reconcile --source git | yq 'select(.kind == "ConfigMap")'

# Live, in the cluster:
kubectl --context k3d-mgmt -n hello get configmap hello-reconcile -o yaml
```

**Expect** (verified):

```yaml
# --- rendered ---
apiVersion: v1
data:
  PODINFO_UI_COLOR: '#326ce5'
  PODINFO_UI_MESSAGE: Hello from Git, revision two
kind: ConfigMap
metadata:
  annotations:
    argocd.argoproj.io/tracking-id: hello-reconcile:/ConfigMap:hello/hello-reconcile
  labels:
    app.kubernetes.io/name: hello-reconcile
  name: hello-reconcile
  namespace: hello
```

```yaml
# --- live ---
apiVersion: v1
data:
  PODINFO_UI_COLOR: '#326ce5'
  PODINFO_UI_MESSAGE: Hello from Git, revision two
kind: ConfigMap
metadata:
  annotations:
    argocd.argoproj.io/tracking-id: hello-reconcile:/ConfigMap:hello/hello-reconcile
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{...},"kind":"ConfigMap","metadata":{...}}
  creationTimestamp: "2026-09-12T19:53:35Z"
  labels:
    app.kubernetes.io/name: hello-reconcile
  name: hello-reconcile
  namespace: hello
  resourceVersion: "45018"
  uid: d60a55ea-faf7-445f-b584-11fcb4c1d7da
```

### Answer key

**Live-only fields** (any three earn full credit):

| Field | Who writes it | What it is |
|---|---|---|
| `metadata.uid` | The Kubernetes API server | A unique identifier for this exact object instance. Delete and recreate it, and the UID changes. |
| `metadata.resourceVersion` | The API server | A counter that changes on every write; used for optimistic concurrency. |
| `metadata.creationTimestamp` | The API server | When the object was first created. |
| `metadata.annotations."kubectl.kubernetes.io/last-applied-configuration"` | The client-side apply that Argo CD performs | A copy of what was last applied, used to calculate future changes. |
| `metadata.managedFields` (hidden by default; add `--show-managed-fields`) | The API server | A record of which client owns which field. |

**Why these are not drift** (one sentence is enough):

> Argo CD compares the fields that the desired manifest sets; values that Kubernetes adds on its own are not part of desired state, so their presence does not make the resource `OutOfSync`.

**The tracking annotation:** `argocd.argoproj.io/tracking-id: hello-reconcile:/ConfigMap:hello/hello-reconcile`. It records which Application manages this object, plus the object's group, kind, namespace, and name. Argo CD uses it to decide "this resource is mine".

### The detail most people miss (use it)

**Say:** "The tracking annotation appears in the *rendered* output too. Is it in Git? Open `chart/templates/configmap.yaml` and look."

**Do:**

```bash
cat ~/hello-reconcile/chart/templates/configmap.yaml
```

It is **not** in the template. `argocd app manifests --source git` shows the manifest *as Argo CD will apply it*, after Argo CD has stamped its tracking annotation on.

**Wow moment:**

> "That annotation is Argo CD signing its work. It's not in Git, it's not from Helm — Argo CD adds it on the way out, so that later it can look at any object in any cluster and say 'that one's mine'. On Day 2 we'll use that signature to catch two Applications fighting over one Deployment."

### Wrong turns

- **The `sed` command printed no `data:` block**, so participants conclude "the rendered ConfigMap has no message". Correct the command (pre-flight 0.3) and use the moment: "Tools that slice text are fragile. Tools that parse YAML aren't."
- **Listing `data` as a live-only field.** It is in both. Ask them to diff the two blocks line by line.
- **Saying "Argo CD ignores metadata".** Too broad — Argo CD does compare labels and annotations that *Git* sets. It is the server-populated fields that don't count.

---

## 6. Exercise 4 — Locate status in three places

### What participants just attempted

Fill a table showing where each fact lives in the UI, the `argocd` CLI, and `kubectl`, and answer: "If the UI were down, which surface would I use?"

### Answer key

| Fact | Web interface | `argocd` CLI | `kubectl` |
|---|---|---|---|
| Sync status | Badge on the tile; header of the app page | `argocd app get hello-reconcile` → `Sync Status:` line | `kubectl --context k3d-mgmt -n argocd get application hello-reconcile -o jsonpath='{.status.sync.status}'` |
| Health status | Badge on the tile; header of the app page | Same command → `Health Status:` line | Same object → `'{.status.health.status}'` |
| Last-synced revision | App header / sync status panel; **History and Rollback** ([SS-L1-10](../../assets/screenshots/day-1/lab-01-10-history.png)) | `argocd app get` → `Synced to main (<sha>)`; `argocd app history hello-reconcile` | `'{.status.sync.revision}'` or `'{.status.operationState.syncResult.revision}'` |
| Pod events | Pod node → **Events** tab ([SS-L1-09](../../assets/screenshots/day-1/lab-01-09-pod-events.png)) | **Blank.** v3.5.2 has no `argocd app` subcommand for Kubernetes events. `argocd app logs` shows container logs, not events | `kubectl --context k3d-mgmt -n hello describe pod <pod>` (Events section) or `kubectl --context k3d-mgmt -n hello get events` |

**Verified CLI evidence:**

```text
$ kubectl --context k3d-mgmt -n argocd get application hello-reconcile \
    -o jsonpath='sync={.status.sync.status}{"\n"}health={.status.health.status}{"\n"}revision={.status.sync.revision}{"\n"}'
sync=Synced
health=Healthy
revision=ef2f45d2e245bf427093b8dfde16026119001818
```

```text
$ kubectl --context k3d-mgmt -n hello describe pod hello-reconcile-6d7df89d88-4wfb2 | sed -n '/^Events:/,$p'
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  38s   default-scheduler  Successfully assigned hello/hello-reconcile-6d7df89d88-4wfb2 to k3d-mgmt-server-0
  Normal  Pulled     38s   kubelet            spec.containers{podinfo}: Container image "stefanprodan/podinfo:6.15.0" already present on machine and can be accessed by the pod
  Normal  Created    38s   kubelet            spec.containers{podinfo}: Container created
  Normal  Started    38s   kubelet            spec.containers{podinfo}: Container started
```

To prove the blank cell, show the subcommand list:

```bash
argocd app --help | sed -n '/Available Commands/,/^Flags/p'
```

(The verified list contains `logs`, `manifests`, `resources`, `get-resource`, and others — no `events`.)

### The "UI is down" answer — and the twist

**Say:** "The UI is down. Which surface do you use?"

Most rooms say "the CLI". Then:

> "What does the UI talk to? What does the CLI talk to?"

**Answer:** Both talk to the same Argo CD API server (`argocd-server`). If the UI is down because the API server is down, the CLI is down too. `kubectl` does not go through Argo CD at all — it reads the Application object straight from the management cluster's own API. So the complete answer is: *"Try the CLI; if the API server itself is down, use `kubectl` against the Application object, which still carries sync status, health, and revision. The one thing that gets harder is the tree view and events per resource — for those you query Kubernetes directly."*

**Wow moment:**

> "The UI and the CLI share one front door. `kubectl` uses the side door. When the front door is jammed, the people who know the side door are the ones who fix the incident."

---

## 7. Optional stretches

### Stretch A — prove the fix is permanent (verified)

After Part 3, change only `message` to `Hello from Git, revision three`, push, and refresh.

**Expect** (verified):

```text
Sync Status:        OutOfSync from main (8bee0ab)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME             STATUS     HEALTH   HOOK  MESSAGE
       ConfigMap   hello      hello-reconcile  OutOfSync                 configmap/hello-reconcile unchanged
       Service     hello      hello-reconcile  Synced     Healthy        service/hello-reconcile unchanged
apps   Deployment  hello      hello-reconcile  OutOfSync  Healthy        deployment.apps/hello-reconcile configured
```

```text
===== /ConfigMap hello/hello-reconcile ======
4c4
<   PODINFO_UI_MESSAGE: Hello from Git, revision two
---
>   PODINFO_UI_MESSAGE: Hello from Git, revision three

===== apps/Deployment hello/hello-reconcile ======
156c156
<         checksum/config: 1ef56c65fb66d081174eb14dceaeb05c2e1fc624d4c006dca251d1dd7ba4e17b
---
>         checksum/config: 3a0604828066800c8382b6c481e19e32ec6ce44d4d0fb8b4874ad314a3021f64
```

After Sync, the status went `OutOfSync/Healthy/Running` → `Synced/Progressing/Succeeded` → `Synced/Healthy/Succeeded` in about two seconds. A new Pod (`hello-reconcile-8748fd844-4zbz8`) was Ready before the old one terminated, and `curl` returned `"message": "Hello from Git, revision three"`.

**Answer:** two resources this time, versus one in Part 1. One edit in Git now changes both the ConfigMap and the fingerprint in the Pod template, so every future message or colour change rolls the Pods with no human in the loop.

**Wow moment:**

> "One line in Git, two resources in the diff. That second resource is the chart telling Kubernetes 'start new Pods when this changes' — and you wrote that sentence twenty minutes ago."

### Stretch B — `replicaCount: 0` (verified)

After setting `replicaCount: 0`, pushing, refreshing, and syncing:

```text
Sync Status:        Synced to main (f098188)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME             STATUS  HEALTH   HOOK  MESSAGE
       ConfigMap   hello      hello-reconcile  Synced                 configmap/hello-reconcile unchanged
       Service     hello      hello-reconcile  Synced  Healthy        service/hello-reconcile unchanged
apps   Deployment  hello      hello-reconcile  Synced  Healthy        deployment.apps/hello-reconcile configured

NAME                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-reconcile   0/0     0            0           8h
```

**`Synced` and `Healthy` — with zero Pods.**

**Why:** Sync is `Synced` because the live Deployment says `replicas: 0`, exactly as Git does. Health is `Healthy` because a Deployment is healthy when its available replicas meet its *desired* replicas — and zero available meets zero desired.

**Wow moment:**

> "Nobody on Earth can reach this application, and every badge is green. `Healthy` means 'doing what it was told to do', not 'serving your users'. That's why we'll write alerts on real signals later in the course, not on badge colours."

**Reset:** set `replicaCount: 1`, commit, push, sync. Verified: back to `Synced`/`Healthy` with one Pod.

**History panel:** `argocd app history hello-reconcile` lists every sync with its SHA. On a rehearsed VM you will see extra entries from earlier resets; on a fresh VM you'll see the bootstrap sync plus each sync from this lab.

---

## 8. Checkpoint — grading at a glance

| # | Criterion | What "pass" looks like |
|---|---|---|
| 1 | Deployed revision equals the commit | The short SHA in `argocd app get … \| grep -i "sync status"` equals the first 7 characters of `git rev-parse HEAD` |
| 2 | App serves the new message | `curl … \| grep -o '"message": *"[^"]*"'` shows it |
| 3 | E1 dependency table | 8 rows, including the image and "credentials: none" |
| 4 | E2 notes complete | Step A bottom row corrected to **no new Pod / old message** if they predicted otherwise; a Part 2 explanation with both halves (read once at container start; no Pod-template change, no rollout); Part 3 statuses recorded as `Synced` + `Progressing`, then `Healthy` |
| 5 | E4 three-way table | Pod events blank in the CLI column, and the `kubectl` side-door answer |

---

## 9. Debrief (5 minutes)

Ask these in order. Each has a short answer; let participants give it.

1. **"Which of your predictions was wrong?"** — Expect the bottom row of Step A: most people predicted a new Pod and the new message. Celebrate the wrong ones: "Being surprised on purpose is how the model sticks."
2. **"When exactly was the cluster 'wrong' today?"** — Two answers. `OutOfSync`: from each push until its sync, and nobody was hurt, because `OutOfSync` is not an outage. The sneaky one: after the Part 1 sync, Argo CD was `Synced` while users still saw the old message, until Part 3. That gap was not drift — the chart never told Kubernetes to start a new Pod.
3. **"You deleted a Pod and nothing happened in Argo CD. Name something you could delete that *would* make it `OutOfSync`."** — The Deployment, Service, or ConfigMap — anything that is in Git.
4. **"If a teammate says 'Argo CD is broken, it shows OutOfSync', what's your first question?"** — "Is anyone actually affected — what does health say?"

### Key takeaways — say them out loud

> "An Application is an address, not an artifact — and every address in it is something that can go down."

> "`OutOfSync` is a sentence about Git, not a sentence about your users. `OutOfSync` that never converges is the real problem."

> "Read the diff before you sign it."

> "`Synced` means the objects match Git. It doesn't mean the running program picked up the change."

> "Deleting a Pod is not drift. Deleting the Deployment is — because only one of them is in Git."

> "You already used the first four steps of a troubleshooting method we haven't taught yet: check the Git source, check it rendered, compare rendered with live, read the sync result and events. Session 7 will give those steps names. You've already done them."

### Transition

**Say:**

> "Today's app deployed to the same cluster Argo CD runs on. That was a teaching shortcut, and real platforms never do it. After the next session, Lab 2 builds the real topology: a private repo, a separate workload cluster, and a credential that — unlike today — can actually expire."
