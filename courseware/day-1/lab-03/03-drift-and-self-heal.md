# Lab 3 · Module 3 — Drift and Self-Heal

> **Day 1 · Lab 3 · Module 3 of 4 · ~20 minutes**
> **Goal:** introduce live drift under manual sync and predict which axis moves (**E3**); then turn on safe automated sync + self-heal and watch it outlive an edit (**E4**).

> **🗺️ Where this module fits.** Your app is deployed and matches Git. Now someone changes the cluster by hand. E3 shows what Argo CD does about that when sync is manual (it tells you, and does nothing). E4 turns on automatic correction and shows what "Git wins" feels like — including why that can surprise you during an incident.

---

## Exercise 3 — Introduce live drift under manual sync

> **🧭 What this exercise is for**
> - **In plain words:** **drift** means the live cluster no longer matches Git because someone changed it directly. You create drift on purpose (scale the app by hand), then check which of Argo CD's two statuses changes.
> - **Think of it like:** a thermostat set to 20°. Someone opens a window. The display now shows the room is not at 20° — but in manual mode, the thermostat does not turn the heating on. It reports; it does not act.
> - **Connects to:** [Session 2 · Module 3](../session-02/03-sync-vs-health.md) — sync ("does it match Git?") and health ("is it working?") are separate questions; and [Session 4 · Module 2](../session-04/02-sync-ordering-and-drift.md) — "drift is discovered, not detected."
> - **Big picture:** in a real incident you need to tell "someone changed it" from "it is broken". Which status moved tells you which one you have.

**Goal:** change the running cluster *directly* (behind Argo CD's back) and predict, before you look, **which** status axis moves — and confirm that under manual sync, nothing reverts on its own.

**Difficulty / time:** Straightforward · ~8 minutes. **Starter state:** `storefront-dev` `Synced`/`Healthy`, still **manual** sync.

**▶ Predict first:**

| After you scale the Deployment on the cluster… | Sync status | Health status | Reverts on its own? |
|---|---|---|---|
| *your prediction* | `Synced` or `OutOfSync`? | `Healthy` or `Degraded`? | yes / no |

**Do it:**

1. Scale the live Deployment on the **workload** cluster:
   ```bash
   kubectl --context k3d-workload -n storefront-dev scale deploy/storefront --replicas=3
   ```
2. In the UI, refresh `storefront-dev` and read both badges. Open the **diff**.
3. Wait through a reconciliation interval (this environment reconciles every **60 seconds**). Watch whether Argo CD does anything.

![storefront-dev Deployment OutOfSync after a manual scale (v3.5.2)](../../assets/screenshots/day-1/lab-03-04-live-drift.png)

*Figure SS-L3-04 — After E3: the Deployment is `OutOfSync` (live replicas ≠ Git) but still `Healthy`.*

![Diff showing spec.replicas live 3 vs desired 1 (v3.5.2)](../../assets/screenshots/day-1/lab-03-05-drift-diff.png)

*Figure SS-L3-05 — The diff: live `spec.replicas: 3` vs desired `1` — the exact field Argo CD sees as drift; everything else matches.*

**🔍 Notice:** the app header flips to `OutOfSync`, but health stays **`Healthy`** — three replicas is a working app, just not the *desired* one. Nothing changes over the next minute: manual sync reports drift, it does not correct it.

<!-- CAPTURE-SPEC: SS-L3-04/05 — Tree + diff after drift. State: after scaling replicas=3, Refresh. Highlight: Deployment OutOfSync, health Healthy; diff spec.replicas 1 vs 3. Argo CD v3.5.2. -->

**Success criterion:**
- `argocd app get storefront-dev` shows **`OutOfSync`** but **`Healthy`**, and *stays* that way across at least one 60-second interval.
- You can state in one sentence why the health axis did **not** move.

**Hints:**
- *Hint 1:* If the badge still says `Synced`, click **Refresh** — drift is *discovered* on comparison, not the instant you type.
- *Hint 2:* If you see no live Pods, you scaled the wrong context. Confirm with `kubectl --context k3d-workload -n storefront-dev get deploy storefront`.

### ✅ What you should take away from E3

- **Drift changes the sync status, not the health status.** Three working replicas are still healthy — they just are not what Git asked for.
- **The diff shows exactly which field drifted** (`spec.replicas`), and nothing else.
- **With manual sync, Argo CD reports drift but leaves it alone.** Someone has to decide to sync.

---

## Exercise 4 — Configure safe automated sync and self-healing

> **🧭 What this exercise is for**
> - **In plain words:** you switch `storefront-dev` to **automated sync with self-heal**. Now when someone changes the cluster by hand, Argo CD puts it back to match Git. You leave **prune** off on purpose, because prune *deletes* things.
> - **Think of it like:** switching the thermostat to automatic. Open the window and it turns the heating on until the room is back at 20°. If you want 22°, you change the setting (Git) — fighting the thermostat by opening more windows does not work.
> - **Connects to:** [Session 4 · Module 2](../session-04/02-sync-ordering-and-drift.md) — "turn on self-heal early; turn on prune late."
> - **Big picture:** once self-heal is on, **Git is the only lasting way to change the app.** That is great for consistency and surprising at 2 a.m. The debrief at the end of this exercise is about exactly that moment.

**Goal:** turn on automated sync with **self-heal** so the cluster is held to Git — but leave **prune off**, deliberately. Then repeat the drift and watch self-heal outlive your edit. Finally, protect one resource from future pruning.

**Difficulty / time:** Moderate · ~12 minutes. **Starter state:** `storefront-dev` `OutOfSync`/`Healthy` (3 replicas), manual sync. First sync it by hand to return to `1` replica and `Synced`.

**Why prune stays off.** Self-heal's worst case is an *argument* (re-applies desired state — reversible). Prune's worst case is a *deletion* (removes anything that leaves Git — a renamed directory, a template that renders nothing). Safe adoption order: **self-heal early, prune late.**

**Do it (produce the change yourself):**

1. Edit the `storefront-dev` Application in `platform-config` to add a `syncPolicy.automated` block with **self-heal on** and **prune off** (you decide the two boolean fields).
2. Commit, then apply:
   ```bash
   kubectl --context k3d-mgmt -n argocd apply -f platform-config/applications/storefront-dev.yaml
   ```
3. Repeat the drift (`kubectl … scale … --replicas=3`). **▶ Predict how long** until it reverts, then watch. Self-heal re-applies after a short debounce (default **5 seconds**) once the next comparison discovers the drift — so expect the revert within roughly one 60-second interval, sooner if you **Refresh**.
4. Try the edit a second time. Watch it be undone again. State the rule in your own words.

**Then protect one resource from future pruning.** In the chart templates, add the annotation `argocd.argoproj.io/sync-options: Prune=false` to **one** resource. Render with `helm template` to confirm it appears, commit, and push. Write one sentence explaining *why* you would protect a specific resource even though app-wide prune is already off.

![Sync policy: automated + self-heal on, prune off (v3.5.2)](../../assets/screenshots/day-1/lab-03-06-auto-sync-enabled.png)

*Figure SS-L3-06 — After E4: automated sync and self-heal are on; prune is off, on purpose.*

![Operation status: sync initiated by the automated policy after drift (v3.5.2)](../../assets/screenshots/day-1/lab-03-07-self-heal-evidence.png)

*Figure SS-L3-07 — After re-introducing drift: the sync that reverted it was **initiated by the automated sync policy**, not by you.*

<!-- CAPTURE-SPEC: SS-L3-06/07 — Sync policy + operation status. State: after E4 automated policy + drift. Highlight: Automated+Self Heal on, Prune off; sync "initiated by automated sync policy"; replicas restored to 1. Argo CD v3.5.2. -->

**Success criterion:**
- After you scale to `3`, the Deployment returns to **1** on its own, attributed to the **automated policy**.
- The sync policy shows **automated + self-heal on, prune off**.
- Your `Prune=false` annotation appears in `helm template` output on exactly one resource, with a one-sentence justification.

**Hints:**
- *Hint 1:* The two fields live under `spec.syncPolicy.automated` — one re-applies drift, one deletes what left Git.
- *Hint 2:* If self-heal seems not to fire, click **Refresh** — the debounce starts *after* the comparison discovers drift, and the comparison is on the 60-second loop.
- *Hint 3:* A good reason for per-resource `Prune=false` is defense-in-depth — it keeps that resource safe even if someone enables app-wide prune later.

**Debrief — a decision, not a rule.** You have watched self-heal undo a manual edit twice. Work this scenario:

> *It is 2 a.m. Production needs **10 replicas right now**, and self-heal is on. You scale — and 30 seconds later it snaps back to 1. What do you do?*

Write your answer before reading on. The wrong answer is to keep scaling and fight the loop. Two are defensible: **disable automated sync on that one Application, stabilize, then commit the real number** — or **commit `replicas: 10` first and let the sync carry it.** The point is *why*: **Git wins because a human turned on a switch that says Git wins.** Self-heal is a policy about who wins ties, not a safety feature — naming it that way lets you make the right call at 2 a.m. instead of scaling five times.

### ✅ What you should take away from E4

- **Self-heal undoes hand edits.** Your `kubectl scale` worked for a moment, then Argo CD put the cluster back to match Git.
- **The reverting sync is labelled as started by the automated policy**, so you can always tell who changed it back.
- **Prune stays off until you trust it**, because prune deletes. `Prune=false` on one resource protects it even if someone turns prune on later.
- **With self-heal on, change Git — not the cluster.** In an emergency, turn automation off for that one app first, or commit the change.

---

## ✅ Key takeaways from this module

- **Drift = the cluster no longer matches Git because someone changed it directly.** It shows up as `OutOfSync`, while health can stay `Healthy`.
- **Manual sync reports drift; automated sync with self-heal corrects it.**
- **Self-heal early, prune late.** Self-heal's worst case can be undone; prune's worst case is a deletion.
- **Git wins because someone chose that Git should win.** When self-heal is on, the lasting fix is always a commit.

**→ Next:** [04 — Break it two ways and recover](04-break-and-recover.md)
