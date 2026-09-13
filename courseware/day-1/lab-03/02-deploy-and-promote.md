# Lab 3 · Module 2 — Deploy and Promote

> **Day 1 · Lab 3 · Module 2 of 4 · ~20 minutes**
> **Goal:** deploy dev and prove "render, not release" (**E1**); author a staging Application and promote a tag (**E2**).

Throughout, **predict before you observe** — fill your prediction first, then run the step, then compare.

---

## Exercise 1 — Deploy dev and prove "render, not release"

**Goal:** sync `storefront-dev` so the app runs on the workload cluster, watch the PreSync hook and sync waves go by in order, then prove — with evidence — that Argo CD did **not** create a Helm release.

**Difficulty / time:** Straightforward · ~10 minutes. **Starter state:** `storefront-dev` is `OutOfSync` / `Missing`, **manual** sync.

**▶ Predict first — the three states:**

| Stage | Desired (Git) | Rendered (manifests) | Live (workload cluster) |
|---|---|---|---|
| Right now (before sync) | chart + dev values | *?* | *?* |
| Immediately after Sync | chart + dev values | *?* | *?* |

**Do it:**

1. Sync `storefront-dev` (UI **Sync**, or `argocd app sync storefront-dev`). Watch the resource tree apply.
2. Observe the order: the **PreSync** migration Job runs first and must succeed; then the `ConfigMap` (wave `-1`); then the `Deployment` and `Service` (wave `0`). The Deployment goes `Progressing` → `Healthy`.
3. **▶ Predict, then run** the release check (write your prediction for the output first):
   ```bash
   helm list -A --kube-context k3d-workload
   ```
4. Verify the app is serving, using the port-forward + `curl` from Module 1.

![storefront-dev tree after first sync: completed PreSync Job, Healthy Deployment (v3.5.2)](../../assets/screenshots/day-1/lab-03-02-synced-with-hook.png)

*Figure SS-L3-02 — After E1: the PreSync migration Job completed; the Deployment is Synced / Healthy.*

**🔍 Notice:** the migration Job appears as a completed **PreSync** hook, separate from the main tree; ConfigMap/Deployment/Service are `Synced`; the app header reads **`Synced`** / **`Healthy`**.

<!-- CAPTURE-SPEC: SS-L3-02 — Application tree after first sync. State: after E1 sync. Highlight: completed PreSync Job; app Synced/Healthy. Argo CD v3.5.2. -->

**Success criterion:**
- `argocd app get storefront-dev` shows **`Synced`** / **`Healthy`**.
- `helm list -A --kube-context k3d-workload` returns **no storefront release** — and you can say in one sentence *why* that empty result is proof the model works (Argo CD ran `helm template`, not `helm install`).
- `curl` through the port-forward returns a message containing **`storefront DEV`**.

**Hints:**
- *Hint 1:* If Sync does nothing, confirm you are on `storefront-dev` and its sync is manual (it waits for you).
- *Hint 2:* If the Deployment stays `Progressing`, check `kubectl --context k3d-workload -n storefront-dev get pods` — wrong context is the usual cause of "nothing is there."
- *Hint 3:* The empty `helm list` is Session 4's one-sentence thesis.

---

## Exercise 2 — Deploy staging from its own values file, then promote a tag

**Goal:** author a **second** Application, `storefront-staging`, that renders the *same* chart with the *staging* values file; then **promote** the image tag `dev` has been running into staging as a single reviewable commit.

**Difficulty / time:** Moderate · ~10 minutes. **Starter state:** `storefront-dev` `Synced`/`Healthy`; no `storefront-staging` yet; reference is `platform-config/applications/storefront-dev.yaml`.

**What "correct" looks like:** a new `storefront-staging` Application that reads `envs/staging/values.yaml`, deploys to the `storefront-staging` namespace, and reaches `Synced`/`Healthy` with **2** replicas and UI message **`storefront STAGING`**.

**▶ Predict first — rendered differences.** Comparing `envs/dev` and `envs/staging` values, predict which differ: namespace, replica count, UI message, UI color, image tag.

**Do it (produce the manifest yourself):**

1. Create `platform-config/applications/storefront-staging.yaml`, modeled on dev. Change only what must change for staging.
2. **The guardrail step (do not skip):** the `storefront` AppProject permits **only** `storefront-dev`. Widen `platform-config/projects/storefront.yaml` to also permit the `storefront-staging` namespace, or Argo CD will *reject* the new Application (see Troubleshooting).
3. Commit both files, then apply from the **management** cluster:
   ```bash
   kubectl --context k3d-mgmt -n argocd apply -f platform-config/projects/storefront.yaml
   kubectl --context k3d-mgmt -n argocd apply -f platform-config/applications/storefront-staging.yaml
   ```
4. Sync `storefront-staging` and verify staging's settings (port-forward to the `storefront-staging` namespace, or read the UI).

**Now promote a tag.** A newer podinfo release, **`6.16.0`**, has been validated in `dev`:

1. In `storefront-gitops`, set `image.tag: "6.16.0"` in `envs/dev/values.yaml`, commit, push, sync `storefront-dev`, confirm the new version (`curl … | grep version`).
2. **Promote** by making the *same* one-line change to `envs/staging/values.yaml`, commit, push. Before syncing, render locally to see it is a one-line diff:
   ```bash
   helm template storefront charts/storefront -f envs/staging/values.yaml | grep 'image:'
   ```
3. Sync `storefront-staging`.

> **Environment note:** promoting a new tag pulls a new image on the workload cluster. Your classroom pre-loads `stefanprodan/podinfo:6.16.0`. If offline and that tag is unavailable, the Deployment stalls on `ImagePullBackOff` — recovery is in Troubleshooting, itself a revert-vs-roll-forward lesson.

![storefront-staging App Details showing the staging values file (v3.5.2)](../../assets/screenshots/day-1/lab-03-03-parameters-values-files.png)

*Figure SS-L3-03 — After E2: App Details show `envs/staging/values.yaml` driving this environment; 2 replicas.*

<!-- CAPTURE-SPEC: SS-L3-03 — App Details, Helm values-files. State: after E2. Highlight: valueFiles pointing at envs/staging/values.yaml; staging replica/UI values. Argo CD v3.5.2. -->

**Success criterion:**
- `argocd app list` shows **both** apps `Synced` / `Healthy`.
- `curl` against staging returns **`storefront STAGING`**, and `kubectl --context k3d-workload -n storefront-staging get deploy storefront` shows `2/2`.
- Staging's `image.tag` matches dev's after promotion, and `git log` on `storefront-gitops` shows the promotion as its own commit.

**Hints:**
- *Hint 1:* The `helm.valueFiles` path is *relative to the chart path* (`charts/storefront`) — count the `../` to the sibling env directory.
- *Hint 2:* A project error on the new Application means you skipped the AppProject destination step.
- *Hint 3:* "Promote a number" literally: the *only* changed line in `envs/staging/values.yaml` is the `image.tag`.

**→ Next:** [03 — Drift and self-heal](03-drift-and-self-heal.md)
