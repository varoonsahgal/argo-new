# Lab 1 · Module 2 — Commit a Change and Sync It

> **Day 1 · Lab 1 · Module 2 of 4 · ~12 minutes**
> **Goal:** change one line in Git and follow it through the loop — predict, commit, read the diff, sync — then check what the running app actually serves (**Exercise E2, Part 1**).

This is the core of the lab. You will **predict before you act** at every stage, because the gap between what you expected and what happened is where the model gets built.

---

## 1. Clone the repo

Read access needs no credentials; the push later uses your Gitea student login.

**▶ Do this now:**

```bash
cd ~
git clone http://lab-gitea:3000/course/hello-reconcile.git
cd hello-reconcile
git config user.email "student@lab.local"
git config user.name "Student"
```

---

## 2. Step A — Predict first

Before touching anything, fill in this **Predict-Before-You-Sync** table. Write what you expect at each moment; you will compare it to reality at the end.

| Moment | Sync status? | Health status? | New Pod starts? | Which message does the app serve? |
|---|---|---|---|---|
| Right after `git push` (before Argo CD notices) | ? | ? | ? | ? |
| After Refresh / ~60s (noticed, before you Sync) | ? | ? | ? | ? |
| **After** the sync completes | ? | ? | ? | ? |

The cells most people get wrong are the last two in the bottom row. Commit to an answer before you look.

---

## 3. Step B — Make the change

Open `chart/values.yaml` in an editor (`nano chart/values.yaml` — save with `Ctrl+O`, `Enter`; exit with `Ctrl+X`). Change the `message` line:

```yaml
message: "Hello from Git, revision two"
```

---

## 4. Step C — Commit and push

```bash
git add chart/values.yaml
git commit -m "Lab 1: change message to revision two"
git push
git rev-parse HEAD
```

When Git asks for credentials, use username `student` and the password from `~/course/credentials/gitea-student.txt`. Copy the full SHA from `git rev-parse HEAD` — you will match it against what Argo CD deploys.

**🔍 Notice what did *not* happen:** nobody ran `kubectl apply`, nobody touched the cluster, no pipeline "deployed." The only event in the world so far is a new commit in Git.

---

## 5. Step D — Watch it move, read the diff, and sync

Go to **Window A**. For up to ~60 seconds Argo CD may show nothing — that is the timer, not a failure. Click **Refresh** to skip the wait. The app flips to **`OutOfSync`**.

![Argo CD tree showing hello-reconcile OutOfSync after the push and Refresh (v3.5.2)](../../assets/screenshots/day-1/lab-01-05-outofsync-after-refresh.png)

*Figure SS-L1-05 — After the push and a Refresh, the app and its ConfigMap show `OutOfSync`.*

**🔍 Notice:** the app is `OutOfSync` **and still `Healthy`.** Only the **ConfigMap** node carries the yellow icon; the Service and Deployment stay green. Ask yourself: *right now, who is affected by this `OutOfSync`?* (Answer: nobody — the old message is still being served correctly.)

<!-- CAPTURE-SPEC: SS-L1-05 — Tree after push and Refresh. State: after E2 push + Refresh, route /applications/hello-reconcile. Highlight: OutOfSync badge on the Application and ConfigMap node. Fidelity: full page. -->

**▶ Do this now — read the diff before you approve it.** Click **App Diff** (or run `argocd app diff hello-reconcile` in Window B). It does not auto-sync because this app uses a **Manual** sync policy — Argo CD separates *detecting* changes from *applying* them.

**Expected command-line output:**

```text
===== /ConfigMap hello/hello-reconcile ======
4c4
<   PODINFO_UI_MESSAGE: Hello from Git, revision one
---
>   PODINFO_UI_MESSAGE: Hello from Git, revision two
```

**🔍 Notice:** exactly one field changed — the ConfigMap's message. The Deployment is **not** in the diff. "Read the diff before you sign it" is the cheapest safety habit in Argo CD — the same reflex as reading a pull request before approving.

![Argo CD diff view highlighting the changed message line (v3.5.2)](../../assets/screenshots/day-1/lab-01-06-app-diff.png)

*Figure SS-L1-06 — The diff shows exactly one changed line: the ConfigMap's message.*

<!-- CAPTURE-SPEC: SS-L1-06 — Diff view. State: after E2 Refresh, before Sync. Highlight: the single changed message line. Fidelity: panel. -->

**▶ Do this now — Sync.** Click **Sync**, leave **Prune** unchecked, review the resource list, and confirm. Then watch **Window C** for about 20 seconds.

![Argo CD after sync: Synced, Healthy, new revision SHA (v3.5.2)](../../assets/screenshots/day-1/lab-01-08-synced-new-revision.png)

*Figure SS-L1-08 — After the sync: `Synced`/`Healthy`, last sync `Succeeded`, at the new revision.*

<!-- CAPTURE-SPEC: SS-L1-08 — After sync. State: after E2 sync completes. Highlight: last sync Succeeded and the new revision SHA. Fidelity: full page. -->

**🔍 Notice:** the app is `Synced` at your new revision, and the last sync `Succeeded`. **Did anything print in Window C?** (Hold that thought.)

---

## 6. Check what the running app actually says

**▶ Do this now — ask the app for its message (Window B).**

```bash
kubectl --context k3d-mgmt -n hello port-forward svc/hello-reconcile 9898:9898 >/tmp/pf.log 2>&1 &
sleep 2
curl -s http://localhost:9898/ | grep -o '"message": *"[^"]*"'
kill %1
```

**Expected output** — and this is the surprise:

```text
"message": "Hello from Git, revision one"
```

**Everything says "revision two" — Git, the diff, the ConfigMap, Argo CD's status — yet the running app still serves "revision one."** Fill in the bottom row of your Step A table with what actually happened, and compare it with your prediction. Most people predicted "revision two" here.

Do **not** fix it yet. Module 3 is where you gather evidence, explain *why*, and fix the real cause in Git.

**→ Next:** [03 — Why the app didn't change](03-why-the-app-didnt-change.md)
