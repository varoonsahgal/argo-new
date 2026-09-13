# Lab 3 · Module 1 — Environment and New Mechanics

> **Day 1 · Lab 3 · Module 1 of 4 · ~8 minutes**
> **Goal:** confirm the healthy start state and pick up the two *new* mechanics this lab needs — reaching the workload app, and knowing which of two repos owns each change.

---

## 1. Environment check — confirm `CP-lab-03`

**▶ Do this now:**

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-03 --verify-only --local
```

**Expected output** *(representative):*

```text
▶ Verification for CP-lab-03
  PASS  Application hello-reconcile Synced/Healthy
  PASS  Application storefront-dev present (manual)
  PASS  AppProject storefront present
  PASS  Secret repo-storefront-gitops present
  PASS  Secret cluster-workload present
  PASS  workload SA argocd-manager present

PASS CP-lab-03 is in the expected state.
```

If any row says **FAIL**, run `reset-lab.sh CP-lab-03 --local` (no `--verify-only`) to restore. A full reset discards uncommitted lab work.

**▶ Do this now — confirm the starting picture in the UI.** `storefront-dev` should be **`OutOfSync`** / **`Missing`** — the correct starting state, meaning "Argo CD can render and compare, and nothing is deployed yet."

![Applications list showing storefront-dev OutOfSync and Missing at the start of Lab 3 (v3.5.2)](../../assets/screenshots/day-1/lab-03-01-env-check.png)

*Figure SS-L3-01 — At `CP-lab-03`: `storefront-dev` is `OutOfSync` / `Missing`; no `storefront-staging` tile yet; `hello-reconcile` from Lab 1 still `Synced`/`Healthy`.*

<!-- CAPTURE-SPEC: SS-L3-01 — Applications list, environment check. State: CP-lab-03, route /applications. Highlight: storefront-dev OutOfSync+Missing; no storefront-staging tile. Argo CD v3.5.2. -->

---

## 2. New mechanic: reaching a workload with no public address

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

Keep these straight — the second half of the lab depends on it:

| You want to change… | Edit this repo | How Argo CD sees it |
|---|---|---|
| The **Application** itself (sync policy, which values file, destination) | `platform-config` | `git commit`, then `kubectl --context k3d-mgmt -n argocd apply -f …` |
| The **application's desired state** (chart, `envs/<env>/values.yaml`) | `storefront-gitops` | `git commit` **and push**; Argo CD reads it on next refresh |

A rendering failure and an ordering failure in Exercise 5 live in *different* repos for this reason. Noticing which repo owns a change is half of finding a failure fast.

**→ Next:** [02 — Deploy and promote](02-deploy-and-promote.md)
