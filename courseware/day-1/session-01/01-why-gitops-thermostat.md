# Session 1 · Module 1 — Why GitOps: a Thermostat, Not a Light Switch

> **Day 1 · Session 1 · Module 1 of 3 · ~15 minutes · concept + short hands-on**
> **Goal:** understand *why* a hand-edited cluster silently reverts, and the one idea — GitOps — that explains it.

---

## 1. A 2 a.m. mystery

It is 2 a.m. A production service is throwing errors. An on-call engineer does the fastest thing that works: they run `kubectl edit deployment` against the live cluster, bump the container image to a known-good version by hand, and the errors stop. They go back to bed. The fix worked.

The next morning, the errors are back — and the hand-edited image is gone, silently replaced by the old one. Nobody touched it. No alert fired. The engineer swears they fixed it. The dashboard swears nothing changed.

Both are telling the truth. The engineer *did* fix the live cluster. And a piece of software named **Argo CD** *did* quietly undo the fix — on purpose, because the fix never existed in the one place Argo CD trusts: **Git**.

By the end of this module you will be able to say precisely **who was right** (both), **why the change reverted** (it was never committed), and **how to make that hotfix stick** (change Git, not the cluster).

> **Term check — Git.** Git is the version-control system that stores your files as committed snapshots, each with an author, a message, a timestamp, and a unique identifier (a **commit hash**, often shown as a short **SHA**). Teams already keep application source and Kubernetes configuration in Git. Argo CD adds one idea to the Git you know: *the cluster should look like the repo, always.*

---

## 2. The mental model: a thermostat, not a light switch

Before any Argo CD vocabulary, hold one picture in your head.

A **light switch** is a one-time action. You flip it, the light turns on, and the switch stops caring. If someone turns the light off a minute later, the switch does nothing — it already did its one job.

Running `kubectl apply` (or `kubectl edit`) by hand is a light switch. You send a change, the cluster accepts it, and after that moment nobody is watching. If the change is overwritten or drifts, `kubectl` will not notice, because it already finished.

A **thermostat** is completely different. You do not "turn on" a thermostat. You give it a *target* — "hold this room at 21 °C" — and it never stops working. It reads the target, reads the actual temperature, acts if they differ, waits, and checks again. Forever. It is a **standing instruction**.

**Argo CD is the thermostat.** You do not "deploy" with Argo CD the way you flip a switch. You give it a target — "this cluster should match this Git repository" — and it reads the target, reads the actual cluster, acts if they differ, waits, and checks again. Continuously.

That single shift — from *one-time action* to *standing instruction* — is the whole reason the 2 a.m. hotfix reverted. The engineer flipped a switch (`kubectl edit`). But a thermostat was running the whole time, set to a target that still said "old image." The next time it checked, it saw a mismatch and corrected it — exactly as designed.

---

## 3. See the thermostat idle — live

You already have this exact machine running. Let us look at it before we name its parts.

**▶ Do this now — see Argo CD's report.** Open the Argo CD web interface at `https://localhost:8443` (accept the self-signed-certificate warning; log in as `admin` with the password from `~/course/credentials/argocd-admin.txt`). You will see **one** Application tile, `hello-reconcile`, with a green **Synced** badge and a green **Healthy** badge.

That tile *is* the thermostat's status light: **Synced** means "the cluster matches Git right now," and the loop is quietly idling because target and reality already agree.

**▶ Do this now — ask the running app what it is serving.** In a terminal, open a temporary tunnel to the app and read its message (a **port-forward** connects a local port to the app inside the cluster):

```bash
kubectl --context k3d-mgmt -n hello port-forward svc/hello-reconcile 9898:9898 >/tmp/pf.log 2>&1 &
sleep 2
curl -s http://localhost:9898/ | grep -o '"message": *"[^"]*"'
kill %1
```

**Expected output:**

```text
"message": "Hello from Git, revision one"
```

**🔍 Notice:** that message text (`Hello from Git, revision one`) lives in a file in Git. The app is serving it because Argo CD made the cluster match Git. In Lab 1 you will change that one line in Git and watch this exact output change. Right now, hold the picture: **Git says one thing, the cluster matches it, and Argo CD keeps it that way.**

---

## 4. The core idea, named

- **GitOps.** A way of operating systems where a **Git repository is the single source of truth for what should be running**, and an automated agent continuously makes the real system match the repo. The 2 a.m. story failed because the engineer operated the *cluster* directly instead of operating *Git* — the exact anti-pattern GitOps removes.
- **Desired state.** What the system is *supposed* to look like. In GitOps it lives in Git. It is the thermostat's *target*.
- **Live state.** What is *really* running in the cluster right now. It is the *current room temperature*.
- **Drift.** Any difference between desired state (Git) and live state (cluster). The 2 a.m. hand-edit *created* drift. Drift is not automatically "broken" — it is just "the room is not at the target yet."
- **Reconciliation.** The continuous loop that *reduces drift*: read desired, read live, compare, and bring live back toward desired. It is the thermostat *doing its job*, over and over.

---

## 5. Quick Check

**S1-QC1 — Make the hotfix stick.** The 2 a.m. engineer wants tomorrow's fix to *not* revert. In one sentence, what should they do differently, and why does it work?

<details>
<summary>Show answer</summary>

**Commit the image change to Git** (open a pull request into the deployment repo), instead of editing the live cluster. It works because Argo CD's target is Git: once Git says "new image," reconciliation makes the cluster match *and keeps it matched*. Editing the cluster directly changes reality but not the target, so the next reconciliation pass reverts it. **Change the target, not the room.**
</details>

---

## 6. Key takeaways

- **`kubectl edit` is a light switch; Argo CD is a thermostat.** One acts once; the other holds a target forever.
- **Git is the source of truth; the live cluster is just today's rendering of it.**
- A hand-edit to the cluster is **drift**, and reconciliation removes it — that is a feature, not a bug.

**→ Next:** [02 — Topology and ownership](02-topology-and-ownership.md)
