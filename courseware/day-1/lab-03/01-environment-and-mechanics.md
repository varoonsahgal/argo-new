# Lab 3 · Module 1 — Environment and New Mechanics

> **Day 1 · Lab 3 · Module 1 of 4 · ~8 minutes**
> **Goal:** confirm the healthy start state and pick up the two *new* mechanics this lab needs — reaching the workload app, and knowing which of two repos owns each change.

> **🗺️ Where this module fits.** No exercises yet. You confirm that Lab 2's work is in place, and you learn three small things you will use all lab: how to look at the app from your terminal, what "promotion" means in GitOps, and which of the two Git repositories holds which kind of change.

---

## 1. Environment check — confirm `CP-lab-03`

> **🧭 What this step is for**
> - **In plain words:** you check that everything Lab 2 built is present — the repository connection, the workload cluster registration, the `storefront` AppProject, and the `storefront-dev` Application.
> - **Connects to:** Lab 2's checkpoint. `CP-lab-03` is exactly the state Lab 2 ended in.
> - **Why it matters:** this lab deploys onto that setup. If any piece is missing, the first sync fails for a reason that has nothing to do with this lab.

**▶ Do this now:**

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-03 --verify-only --local
```

**Expected output:**

```text
==> Verification for CP-lab-03
  PASS  Application hello-reconcile Synced/Healthy
  PASS  Application storefront-dev present (manual)
  PASS  Application team-a-guestbook absent
  PASS  AppProject team-a absent
  PASS  AppProject storefront present
  PASS  Secret in-cluster present
  PASS  Secret repo-storefront-gitops present
  PASS  Secret cluster-workload present
  PASS  Repository and cluster Secrets are exactly: in-cluster, repo-storefront-gitops, cluster-workload
  PASS  workload namespace storefront-prod present
  PASS  workload SA argocd-manager present
  PASS  workload RoleBinding argocd-deployer (storefront-prod) present

PASS CP-lab-03 is in the expected state.
```

If any row says **FAIL**, run `reset-lab.sh CP-lab-03 --local` (no `--verify-only`) to restore. A full reset discards uncommitted lab work.

**▶ Do this now — confirm both clones are in your home directory.** Lab 2 cloned `platform-config`; Session 4's optional Try It cloned `storefront-gitops`. If `ls` reports either one missing, clone it:

```bash
cd ~
ls -d platform-config storefront-gitops
git clone http://lab-gitea:3000/course/storefront-gitops.git   # only if storefront-gitops is missing
```

Commands in this lab that name `platform-config/…` run from your home directory (`~`). Commands that work inside one repository (`git`, `helm template`) run from that repository's folder.

**▶ Do this now — confirm the starting picture in the UI.** `storefront-dev` should be **`OutOfSync`** / **`Missing`** — the correct starting state, meaning "Argo CD can render and compare, and nothing is deployed yet."

![Applications list showing storefront-dev OutOfSync and Missing at the start of Lab 3 (v3.5.2)](../../assets/screenshots/day-1/lab-03-01-env-check.png)

*Figure SS-L3-01 — At `CP-lab-03`: `storefront-dev` is `OutOfSync` / `Missing`; no `storefront-staging` tile yet; `hello-reconcile` from Lab 1 still `Synced`/`Healthy`.*

<!-- CAPTURE-SPEC: SS-L3-01 — Applications list, environment check. State: CP-lab-03, route /applications. Highlight: storefront-dev OutOfSync+Missing; no storefront-staging tile. Argo CD v3.5.2. -->

---

## 2. New mechanic: reaching a workload with no public address

> **🧭 What this step is for**
> - **In plain words:** Argo CD's statuses tell you what Argo CD *thinks*. To see what users would actually get, you ask the app itself. This step gives you a way to do that from your terminal.
> - **Think of it like:** a status light on a coffee machine says "ready" — but the real test is pouring a cup. `curl` pours the cup.
> - **Refresher:** a **Service** of type `ClusterIP` gives a set of Pods one stable address, but only *inside* the cluster. `kubectl port-forward` opens a temporary tunnel from a port on your machine to that Service.

The storefront app listens on port **9898** (it is `podinfo`). Its `ClusterIP` Service is reachable *inside* the workload cluster but not from your shell — so you open a temporary tunnel and `curl` through it.

**▶ Do this now (you will reuse this all lab):**

```bash
# Terminal A — open the tunnel (leave running; Ctrl-C stops it):
kubectl --context k3d-workload -n storefront-dev port-forward svc/storefront 9898:9898
```

```bash
# Terminal B — read the app through the tunnel:
curl -s localhost:9898 | grep -o '"message": *"[^"]*"'
```

**Expected shape** *(after Exercise 1 deploys it):*

```text
"message": "storefront DEV"
```

The message text comes from the environment's values file, so a change in Git becomes visible here. This is your ground-truth check that a deploy or promotion actually landed.

---

## 3. New mechanic: promotion moves a version pin, not artifacts

> **🧭 What this step is for**
> - **In plain words:** "promoting" a change from dev to staging does not mean copying files or images between servers. It means **changing one version number** in staging's settings file, in a commit that someone can review.
> - **Think of it like:** a recipe card for each kitchen. When the test kitchen (dev) is happy with a new ingredient version, you write the same version on the staging kitchen's card. The recipe (chart) stays the same.
> - **Connects to:** [Session 4 · Module 3](../session-04/03-promotion-and-recovery.md) — "promotion is a moving pin, not a moving artifact."

"Promoting" `dev` → `staging` is **not** a pipeline copying images. In GitOps it is a **one-line edit to a values file, in a commit, with a reviewer.** The storefront repo is laid out for exactly this:

```text
storefront-gitops/
  charts/storefront/            # one chart, rendered for every environment
  envs/dev/values.yaml          # image.tag, ui.message, replicaCount for DEV
  envs/staging/values.yaml      # …for STAGING
  envs/prod/values.yaml         # …for PROD (pinned to a Git tag, not a branch)
```

Promoting the tag `dev` has been running into `staging` is a single changed line in `envs/staging/values.yaml`, committed and pushed (Exercise 2).

---

## 4. New mechanic: everything you change lives in one of two repos

> **🧭 What this step is for**
> - **In plain words:** there are two kinds of change in this lab. Changing **how Argo CD handles the app** (for example, turning on automatic sync) happens in `platform-config`. Changing **the app itself** (its chart or its settings) happens in `storefront-gitops`.
> - **Think of it like:** a restaurant has the *recipes* (what the food is — `storefront-gitops`) and the *kitchen rules* (who cooks what, when, and where — `platform-config`). A bad dish can come from either, and the fix goes wherever the mistake is.
> - **Why it matters later:** in Module 4 you break one thing in each repo. Knowing which repo owns a change is half of finding a failure fast.

Keep these straight — the second half of the lab depends on it:

| You want to change… | Edit this repo | How Argo CD sees it |
|---|---|---|
| The **Application** itself (sync policy, which values file, destination) | `platform-config` | `git commit`, then `kubectl --context k3d-mgmt -n argocd apply -f …` |
| The **application's desired state** (chart, `envs/<env>/values.yaml`) | `storefront-gitops` | `git commit` **and push**; Argo CD reads it on next refresh |

A rendering failure and an ordering failure in Exercise 5 live in *different* repos for this reason. Noticing which repo owns a change is half of finding a failure fast.

---

## ✅ Key takeaways from this module

- **You start where Lab 2 finished:** `storefront-dev` exists, is `OutOfSync` / `Missing`, and uses manual sync.
- **Statuses are Argo CD's opinion; `curl` is the app's answer.** Use the port-forward to check that a change really reached users.
- **Promotion = changing one version number in the next environment's values file**, as a reviewable commit. The chart does not move.
- **Two repos, two kinds of change:** `platform-config` for how Argo CD manages the app, `storefront-gitops` for what the app is.

**→ Next:** [02 — Deploy and promote](02-deploy-and-promote.md)
