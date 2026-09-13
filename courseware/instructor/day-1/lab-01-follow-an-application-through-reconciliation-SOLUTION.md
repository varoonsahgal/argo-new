# Lab 1 — Instructor Walkthrough and Solutions

> **INSTRUCTOR ONLY. Never share this file with participants, never project it, and never paste it into a shared channel.**
> **Participant guide:** [lab-01-follow-an-application-through-reconciliation.md](../../day-1/lab-01-follow-an-application-through-reconciliation.md)
> **Timebox:** 45 minutes · **Scaffolding:** G1 (maximally guided)
> **Verified:** 2026-09-13, end to end, on the course's local k3d two-cluster sandbox: Argo CD `v3.5.2` (chart `10.8.4`), `argocd` CLI `v3.5.2`, Kubernetes `v1.35.8+k3s1`, Helm `v4.2.1`. Every output block below was captured from that run unless it is explicitly marked otherwise. Commit SHAs, Pod suffixes, and ages will differ on your machine.

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

### 0.2 Confirm the rollout annotation is in the chart — this decides whether Exercise 2 "works"

**Do:**

```bash
git ls-remote http://lab-gitea:3000/course/hello-reconcile.git >/dev/null && \
git clone -q http://lab-gitea:3000/course/hello-reconcile.git /tmp/hr-check && \
grep -n 'course.message:' /tmp/hr-check/chart/templates/deployment.yaml; rm -rf /tmp/hr-check
```

**Expect:** a line containing `course.message: {{ .Values.message | quote }}`.

**Why this matters (verified both ways in rehearsal):**

- **With the annotation** (the GitHub `argo-cd-course-build` branch from commit `21a3fc8` onward): a message change edits *both* the ConfigMap and the Deployment's Pod template. The sync rolls a new Pod, health passes through `Progressing`, and `curl` returns the new message. This is what the guide describes.
- **Without the annotation** (an environment seeded before `21a3fc8`): only the ConfigMap changes. The sync succeeds, **no new Pod starts**, and `curl` still returns the **old** message. The running container read its message from environment variables when it started, and nothing restarted it.

If the annotation is missing on the class VMs, have the environment owner re-seed the `hello-reconcile` repository before class. If you discover it live, use the recovery in Section 4 ("If it goes sideways") — it turns into one of the best teaching moments of the day.

### 0.3 Know the three places where the participant guide's text is out of step with v3.5.2

You do not need to fix the guide mid-class. You need to recognize these when a participant raises a hand.

| Where | What the guide prints | What actually happens | What to tell the room |
|---|---|---|---|
| Section 6.2, `argocd app get` sample | `SyncWinow: <none>`, no `URL:` line, no `Source:` block | v3.5.2 prints a `URL:` line, a `Source:` block, `SyncWindow: Sync Allowed`, and a MESSAGE column such as `configmap/hello-reconcile unchanged` | "Same facts, newer layout. Read the labels, not the positions." |
| Exercise 2 Step E, `curl … \| grep -o '"message":"[^"]*"'` | Expects your new message | **Prints nothing.** podinfo's JSON has a space after the colon (`"message": "…"`) | Use `grep -o '"message": *"[^"]*"'` (the ` *` allows the space) |
| Exercise 3, `argocd app manifests … \| sed -n '/kind: ConfigMap/,/^---/p'` | The rendered ConfigMap | **Omits the `data:` block** — the one field participants need. Keys come out alphabetically, so `data:` appears *above* `kind:` and the `sed` range starts too late | Use `argocd app manifests hello-reconcile --source git \| yq 'select(.kind == "ConfigMap")'` |

Also note: Figure SS-L1-06's caption says the diff shows "exactly one changed line". With the rollout annotation present, the diff shows **two** resources changing (ConfigMap and Deployment). Both are the same single edit in Git.

### 0.4 Arrange your projected screen

Three panes, exactly as participants will: Firefox on the Argo CD Applications page (Window A), a terminal for `argocd` (Window B), and a terminal running the Pod watch (Window C). Increase the terminal font size before class; the diff output is small.

---

## Run of show (45 minutes)

| Clock | Segment | Your job |
|---|---|---|
| 0:00–0:03 | Why this matters | Frame the thermostat idea; ask "what is the smallest thing that can go wrong?" |
| 0:03–0:10 | Environment check + walkthrough (Sections 5–6) | Participants follow along; you narrate the three windows |
| 0:10–0:15 | E1 — dependency table | Silent individual work, then collect the "guess" numbers |
| 0:15–0:25 | E2 — predict, commit, follow | Collect predictions *before* anyone pushes |
| 0:25–0:32 | E3 — desired vs rendered vs live | Pairs |
| 0:32–0:38 | E4 — status in three places | Pairs, then the "UI is down" question to the room |
| 0:38–0:45 | Solution walkthrough + debrief + takeaways | Run this file's E1–E4 answers live |

If you are behind at 0:30, do E4 as a whole-class discussion instead of pair work: fill the table on the projector together.

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

## 4. Exercise 2 — Predict, then commit a change and follow reconciliation

### What participants just attempted

Fill a four-row prediction table, change `message` in `chart/values.yaml`, push, refresh, read the diff, sync, and prove the new message is served.

### Step A — collect predictions first

**Say:** "Before anyone pushes: row three. *During* the sync, while the new Pod rolls out — what is the health? Hands up: Healthy? Degraded? Progressing?"

Tally the hands. Then proceed.

### Answer key — the prediction table

| Moment | Sync status | Health status | Why |
|---|---|---|---|
| Right after `git push` (before Argo CD notices) | `Synced` | `Healthy` | Argo CD has not compared yet. Verified: an immediate `argocd app get` still printed `Synced to main (ae0e479)`, the *old* SHA. |
| After Refresh / ~60 s (noticed, before Sync) | `OutOfSync` | `Healthy` | Git now differs from the cluster; the old Pod still serves correctly. |
| During the sync, while the new Pod rolls out | `Synced` | `Progressing` | The manifests are applied, so sync flips first; the new Pod is not Ready yet. |
| After the sync completes | `Synced` | `Healthy` | Converged. |

Row three is the one most people get wrong, and in the verified run it lasted **about two seconds**. The sync status turned `Synced` *before* health left `Progressing`:

```text
t=1x0.5s  sync/health/op = OutOfSync/Healthy/Running
t=2x0.5s  sync/health/op = Synced/Progressing/Succeeded
t=6x0.5s  sync/health/op = Synced/Healthy/Succeeded
```

**Wow moment:**

> "Look at the middle line. `Synced` and `Progressing` at the same time. Sync says 'the cluster now matches Git'. Health says 'but the new thing isn't ready yet'. Two separate questions, and for two seconds they gave two different answers. That is the whole two-axis model on one line."

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

### Step D — refresh, read the diff, sync

**Say:** "I've pushed. Nobody touch anything. What does the Applications page show right now?" (Answer: still `Synced` — it hasn't looked yet.)

**Click:** **Refresh** on the `hello-reconcile` tile (or run the CLI below).

**Do:**

```bash
argocd app get hello-reconcile --refresh
```

**Expect** (verified, with the rollout annotation present):

```text
Sync Status:        OutOfSync from main (bebccf0)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME             STATUS     HEALTH   HOOK  MESSAGE
       ConfigMap   hello      hello-reconcile  OutOfSync                 configmap/hello-reconcile configured
       Service     hello      hello-reconcile  Synced     Healthy        service/hello-reconcile unchanged
apps   Deployment  hello      hello-reconcile  OutOfSync  Healthy        deployment.apps/hello-reconcile configured
```

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

===== apps/Deployment hello/hello-reconcile ======
156c156
<         course.message: Hello from Git, revision one
---
>         course.message: Hello from Git, revision two
diff exit=1
```

**Say:** "One line in Git, two resources in the diff. Why would the chart author deliberately copy the message into the Deployment as an annotation?"

**Answer:** Changing a ConfigMap does not restart the Pods that read it. Copying the value into the Pod template changes the template, which makes Kubernetes roll new Pods that read the new value. It is the same trick many public Helm charts use with a checksum annotation.

**Note for the exit code:** `argocd app diff` exits `1` when it finds a difference, `0` when there is none, and `2` when the comparison itself failed. The capstone relies on this.

**Click:** **App Diff**, then **Sync**. Leave **Prune** unchecked ([Figure SS-L1-07](../../assets/screenshots/day-1/lab-01-07-sync-panel.png)). Confirm.

**Expect in Window C** (verified; abbreviated — the new Pod starts and the old one completes):

```text
ADDED      hello-reconcile-6d7df89d88-4wfb2   0/1     Pending             0          0s
MODIFIED   hello-reconcile-6d7df89d88-4wfb2   0/1     ContainerCreating   0          0s
MODIFIED   hello-reconcile-6d7df89d88-4wfb2   0/1     Running             0          2s
MODIFIED   hello-reconcile-6d7df89d88-4wfb2   1/1     Running             0          3s
MODIFIED   hello-reconcile-5b66f8d98c-tfxdj   0/1     Completed           0          3m3s
DELETED    hello-reconcile-5b66f8d98c-tfxdj   0/1     Completed           0          3m4s
```

**Say:** "Watch Window C, not the browser. The browser will show `Progressing` for about two seconds — blink and you miss it. The terminal shows the whole handover: new Pod Ready, old Pod gone."

### Step E — prove it

**Do:**

```bash
argocd app get hello-reconcile | grep -i "sync status"
git -C ~/hello-reconcile rev-parse --short HEAD
kubectl --context k3d-mgmt -n hello port-forward svc/hello-reconcile 9898:9898 >/tmp/pf.log 2>&1 &
sleep 2
curl -s http://localhost:9898/ | grep -o '"message": *"[^"]*"'
kill %1
```

**Expect** (verified):

```text
Sync Status:        Synced to main (bebccf0)
bebccf0
"message": "Hello from Git, revision two"
```

### Wrong turns

| What the participant sees | What happened | What you say |
|---|---|---|
| Nothing changes for a minute after pushing | The 60-second reconciliation timer | "The thermostat hasn't checked yet. Press Refresh — that's the impatient version of waiting." |
| `curl` prints **nothing** | The guide's `grep` pattern has no space after the colon | "podinfo pretty-prints its JSON. Add ` *` after the colon." |
| `git push` rejected or prompts repeatedly | Wrong username, or the password pasted with a trailing newline | Username is `student`; use the credentials file |
| `curl` shows the **old** message after a successful sync | Either the rollout hasn't finished, or the chart lacks the rollout annotation | Check `Synced`/`Healthy` first. If the Pod did not restart at all, see "If it goes sideways" below |
| Participant ticked **Prune** in the sync panel | Harmless here (nothing to prune) | "Nothing to delete this time. In Lab 3 we'll talk about why that checkbox deserves respect." |

### If it goes sideways — the chart has no rollout annotation

Verified in rehearsal on an environment seeded before `21a3fc8`: the diff shows **only** the ConfigMap, the sync `Succeeded`, the Pod watch shows **no new Pod**, and `curl` returns `"message": "Hello from Git, revision one"`.

Do not hide this. Turn it into a lesson:

**Say:**

> "Look at this. Git says revision two. Argo CD says `Synced` to our commit. The ConfigMap in the cluster says revision two. And the app is still saying revision one. Who's lying?"

Let them work it out, then:

> "Nobody. podinfo reads that message from an environment variable, once, when the container starts. Updating a ConfigMap doesn't restart anything. Argo CD did its job perfectly — it made the cluster match Git. The *chart* didn't say 'restart when this changes'. This is exactly why so many Helm charts put a checksum of their ConfigMap into the Pod template."

To show the new message for the rest of the demo, restart the Deployment **on your VM only**, and say out loud that it is a manual intervention outside Git:

```bash
kubectl --context k3d-mgmt -n hello rollout restart deploy/hello-reconcile
```

Then log it for the environment owner: the `hello-reconcile` seed needs commit `21a3fc8`.

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

## 7. Optional stretch — `replicaCount: 0`

### Answer key (verified)

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
| 4 | E2 prediction table annotated | Row 3 corrected to `Synced` + `Progressing` if they predicted otherwise |
| 5 | E4 three-way table | Pod events blank in the CLI column, and the `kubectl` side-door answer |

---

## 9. Debrief (5 minutes)

Ask these in order. Each has a short answer; let participants give it.

1. **"Which of your four predictions was wrong?"** — Expect row 3. Celebrate the wrong ones: "Being surprised on purpose is how the model sticks."
2. **"When exactly was the cluster 'wrong' today?"** — From the push until the sync. Nobody was hurt, because `OutOfSync` is not an outage.
3. **"You deleted a Pod and nothing happened in Argo CD. Name something you could delete that *would* make it `OutOfSync`."** — The Deployment, Service, or ConfigMap — anything that is in Git.
4. **"If a teammate says 'Argo CD is broken, it shows OutOfSync', what's your first question?"** — "Is anyone actually affected — what does health say?"

### Key takeaways — say them out loud

> "An Application is an address, not an artifact — and every address in it is something that can go down."

> "`OutOfSync` is a sentence about Git, not a sentence about your users. `OutOfSync` that never converges is the real problem."

> "Read the diff before you sign it."

> "Deleting a Pod is not drift. Deleting the Deployment is — because only one of them is in Git."

> "You already used the first four steps of a troubleshooting method we haven't taught yet: check the Git source, check it rendered, compare rendered with live, read the sync result and events. Session 7 will give those steps names. You've already done them."

### Transition

**Say:**

> "Today's app deployed to the same cluster Argo CD runs on. That was a teaching shortcut, and real platforms never do it. After the next session, Lab 2 builds the real topology: a private repo, a separate workload cluster, and a credential that — unlike today — can actually expire."
