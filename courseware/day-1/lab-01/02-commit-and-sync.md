# Lab 1 · Module 2 — Commit a Change and Sync It

> **Day 1 · Lab 1 · Module 2 of 4 · ~12 minutes**
> **Goal:** change one line in Git and follow it through the loop — predict, commit, read the diff, sync — then check what the running app actually serves (**Exercise E2, Part 1**).

This is the core of the lab. You will **predict before you act** at every stage, because the gap between what you expected and what happened is where the model gets built.

> **🗺️ Where this module fits.** You change one line in the recipe book (Git) and follow it until the head chef (Argo CD) has updated the kitchen. Then you taste the food, and something will not add up. Module 3 explains why.

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

Go to **Window A**. For about a minute — sometimes a little longer — Argo CD may show nothing. That is the timer, not a failure. Click **Refresh** to skip the wait. The app flips to **`OutOfSync`**.

> **💡 Analogy — the head chef's rounds.** The head chef compares the recipe book with the kitchen on a regular round, about once a minute. A new page in the book is not noticed until the next round. **Refresh** is tapping the chef on the shoulder and saying "check the book now".

![Argo CD tree showing hello-reconcile OutOfSync after the push and Refresh (v3.5.2)](../../assets/screenshots/day-1/lab-01-05-outofsync-after-refresh.png)

*Figure SS-L1-05 — After the push and a Refresh, the app and its ConfigMap show `OutOfSync`.*

**🔍 Notice:** the app is `OutOfSync` **and still `Healthy`.** Only the **ConfigMap** node carries the yellow icon; the Service and Deployment stay green. Ask yourself: *right now, who is affected by this `OutOfSync`?* (Answer: nobody — the old message is still being served correctly.)

> **💡 Analogy — a new menu that is still in the box.** The restaurant has printed a new menu (Git), but the old menus are still on the tables. Nothing is broken: every diner is served correctly (`Healthy`). The tables do not match the new menu yet (`OutOfSync`). **Sync status and health status answer two different questions**, so they can disagree without anything being wrong.

<!-- CAPTURE-SPEC: SS-L1-05 — Tree after push and Refresh. State: after E2 push + Refresh, route /applications/hello-reconcile. Highlight: OutOfSync badge on the Application and ConfigMap node. Fidelity: full page. -->

**▶ Do this now — read the diff before you approve it.** Click **Diff** in the button bar at the top of the app page (or run `argocd app diff hello-reconcile` in Window B). The **Diff** button is greyed out while the app is `Synced`, because there is nothing to compare. The app does not auto-sync because it uses a **Manual** sync policy — Argo CD separates *detecting* changes from *applying* them.

**Expected command-line output:**

```text
===== /ConfigMap hello/hello-reconcile ======
4c4
<   PODINFO_UI_MESSAGE: Hello from Git, revision one
---
>   PODINFO_UI_MESSAGE: Hello from Git, revision two
```

**🔍 Notice:** exactly one field changed — the ConfigMap's message. The Deployment is **not** in the diff. "Read the diff before you sign it" is the cheapest safety habit in Argo CD — the same reflex as reading a pull request before approving.

**How to read the four lines:** `4c4` means "line 4 changed into line 4". The line starting with `<` is what the cluster has **now** (live); the line starting with `>` is what Git **wants** (desired). Everything not shown is identical.

> **💡 Analogy — the changes page of a contract.** Before you sign an updated contract, you read the page listing what changed. The diff is that page. Syncing without reading it is signing without reading.

![Argo CD diff view highlighting the changed message line (v3.5.2)](../../assets/screenshots/day-1/lab-01-06-app-diff.png)

*Figure SS-L1-06 — The **Diff** tab lists one resource, the ConfigMap. It shows the whole object on both sides and highlights exactly one changed line: the message.*

<!-- CAPTURE-SPEC: SS-L1-06 — Diff tab (Diff button). State: after E2 Refresh, before Sync. Highlight: the single changed message line. Fidelity: full page. -->

**▶ Do this now — Sync.** Click **Sync**. A panel slides in from the right. Leave **Prune** unchecked, review the list under **Synchronize resources** (the ConfigMap carries the yellow `OutOfSync` icon), and click **Synchronize** at the top of the panel. Then watch **Window C** for about 20 seconds.

![Argo CD sync panel with Prune unchecked and three resources listed (v3.5.2)](../../assets/screenshots/day-1/lab-01-07-sync-panel.png)

*Figure SS-L1-07 — The sync panel: **Synchronize** and **Cancel** at the top, **Prune** unchecked, and all three resources selected.*

<!-- CAPTURE-SPEC: SS-L1-07 — Sync panel open. State: after E2 Refresh, before Sync. Highlight: Synchronize button, Prune unchecked, resource list. Fidelity: full page. -->

![Argo CD after sync: Synced, Healthy, new revision SHA (v3.5.2)](../../assets/screenshots/day-1/lab-01-08-synced-new-revision.png)

*Figure SS-L1-08 — After the sync: `Synced`/`Healthy`, last sync `Succeeded`, at the new revision.*

<!-- CAPTURE-SPEC: SS-L1-08 — After sync. State: after E2 sync completes. Highlight: last sync Succeeded and the new revision SHA. Fidelity: full page. -->

**🔍 Notice:** the app is `Synced` at your new revision, and the last sync `Succeeded`. **Did anything print in Window C?** (Hold that thought.)

---

## 6. Check what the running app actually says

The app runs inside the cluster, so your terminal cannot reach it directly. A **port-forward** opens a temporary tunnel: requests you send to `localhost:9898` on your VM travel through `kubectl` to one Pod in the cluster.

> **💡 Analogy — a phone call to one cook.** A port-forward is a phone call to one particular cook in the kitchen. While the call is open, you can ask what they are making. When you hang up, the line is gone.

**▶ Do this now — ask the app for its message (Window B).** Run the four lines in order:

```bash
kubectl --context k3d-mgmt -n hello port-forward svc/hello-reconcile 9898:9898 >/tmp/pf.log 2>&1 &
PF_PID=$!
sleep 2
curl -sS http://localhost:9898/ | grep -o '"message": *"[^"]*"'
kill $PF_PID
```

| Line | What it does |
|---|---|
| `kubectl … port-forward … &` | Opens the tunnel in the background (`&`) and writes its messages to `/tmp/pf.log` |
| `PF_PID=$!` | Saves the tunnel's process ID (`$!` means "the program I last started in the background") so you can stop exactly that one later |
| `sleep 2` | Gives the tunnel two seconds to open |
| `curl -sS … \| grep -o …` | Asks the app for its JSON reply and keeps only the `message` field. `-sS` hides the progress bar but still prints an error if the tunnel is not working |
| `kill $PF_PID` | Hangs up the tunnel |

**Expected output** — and this is the surprise:

```text
"message": "Hello from Git, revision one"
```

If `curl` prints `Failed to connect to localhost port 9898`, or nothing at all, run `cat /tmp/pf.log`. A line saying `Unable to listen on port 9898` means an older port-forward is still running: stop it with `pkill -f "port-forward svc/hello-reconcile"`, then run the four lines again.

**Everything says "revision two" — Git, the diff, the ConfigMap, Argo CD's status — yet the running app still serves "revision one."** Fill in the bottom row of your Step A table with what actually happened, and compare it with your prediction. Most people predicted "revision two" here.

In kitchen terms: the recipe book changed, the head chef updated the card on the wall, and the head chef reports "kitchen matches the book". Yet the dish coming out is still the old one. Who has not heard about the change?

Do **not** fix it yet. Module 3 is where you gather evidence, explain *why*, and fix the real cause in Git.

**→ Next:** [03 — Why the app didn't change](03-why-the-app-didnt-change.md)
