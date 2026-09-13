# Session 4 · Module 1 — Render, Not Release

> **Day 1 · Session 4 · Module 1 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** understand the one fact the whole session hangs on — Argo CD renders Helm charts but creates no Helm release — and how values combine.

---

## 1. Why this matters: the rollback that does nothing

An engineer is paged: the `storefront` app is misbehaving after a bad release. They know Helm, so they run:

```bash
helm rollback storefront
```

Nothing happens — there is **no release history**. `helm list` in the namespace is **empty**, even though a Helm chart is clearly running. So they hand-edit the live Deployment to the previous image with `kubectl edit`. It works for a minute — then **flips back** to the broken image, on its own. They edit again; it reverts again. The cluster appears to be fighting them.

Nothing is broken. All three surprises come from one fact about how Argo CD uses Helm:
- No release to roll back **because Argo CD never created one.**
- `helm list` empty **for the same reason.**
- The Deployment reverts **because Argo CD holds the cluster to what Git says.**

---

## 2. Argo CD borrows Helm's typewriter, not its filing cabinet

Helm does two very different jobs:
1. **A templating engine** — takes a chart (templates + values) and produces finished Kubernetes YAML. Think **typewriter**: values in, finished pages out.
2. **A release manager** — `helm install`/`helm upgrade` *apply* those pages *and* record a numbered release in a Secret. Think **filing cabinet** of every version. `helm rollback` and `helm list` read that cabinet.

> **Argo CD borrows Helm's typewriter and throws away Helm's filing cabinet.**

Concretely: Argo CD runs `helm template` to render the chart, then **Argo CD itself** applies the manifests and tracks them like any other resource. It does **not** run `helm install`/`upgrade`. No numbered release exists. That single choice explains four consequences:

1. **No Helm release** — `helm list` in the namespace is empty, forever. That empty output is *proof the model works*, not a bug.
2. **`helm rollback` does not exist here** — "rolling back" means reverting a commit in Git, because Git is the version record.
3. **Helm hooks are re-interpreted, not run by Helm** — a `helm.sh/hook` annotation maps onto Argo CD's own phase model (Module 2).
4. **A chart that renders a fresh random value every render can never settle** — Argo CD re-renders on a schedule, so a `randAlphaNum` value differs every comparison → permanently `OutOfSync`. Fix is in the chart, not Argo CD.

> **One honest boundary.** This does *not* mean "Argo CD does not use Helm." It uses Helm heavily — the binary, the templating, values semantics, `--set`. What it declines is Helm's *release lifecycle*.

---

## 3. Prove it: a running chart with no Helm release

**▶ Do this now — ask Helm for its releases in the namespace where a chart is running.**

```bash
helm list --kube-context k3d-mgmt -n hello
```

**Expected output** (a header, and **no rows**):

```text
NAME    NAMESPACE       REVISION        UPDATED STATUS  CHART   APP VERSION
```

**🔍 Notice:** `hello-reconcile` is a Helm chart, it is running in the `hello` namespace, and yet Helm reports **zero releases**. Argo CD rendered the chart and applied it itself — it never ran `helm install`, so there is nothing in Helm's filing cabinet. This empty output is exactly what the paged engineer saw.

---

## 4. The precedence ladder — which value wins

When the same key is set in several places, priority (not proximity) decides. Highest first:

```text
  ▲ HIGHEST PRIORITY (wins)
  │  1. parameter     spec.source.helm.parameters   (like `helm --set replicaCount=4`)
  │  2. valuesObject  spec.source.helm.valuesObject  (inline values in the Application)
  │  3. valueFiles    spec.source.helm.valueFiles    (e.g. envs/dev/values.yaml)
  │  4. chart default the chart's own values.yaml
  ▼ LOWEST PRIORITY (fallback)
```

Almost all day-to-day customization uses `valueFiles` (rung 3) — one chart, one values file per environment. Parameters (rung 1) are for surgical, per-Application overrides.

**▶ Do this now — watch the top rung beat a values file.** Clone the storefront repo (same pattern Lab 2 used), then render with an override:

```bash
cd ~ && git clone http://lab-gitea:3000/course/storefront-gitops.git 2>/dev/null; cd storefront-gitops
helm template storefront charts/storefront -f envs/dev/values.yaml --set replicaCount=4 | grep 'replicas:'
```

**Expected output:**

```text
  replicas: 4
```

**🔍 Notice:** the `dev` values file sets `replicaCount: 1`, but the parameter (`--set replicaCount=4`) sits at the top of the ladder and wins. In an Argo CD Application this same override is written declaratively as a `spec.source.helm.parameters` entry — same mechanism, source of truth in Git.

---

## 5. One warning to carry into Day 2: Helm's version is part of your desired state

Because Argo CD *is* the thing running Helm, the **Helm version it renders with is part of your desired state.**

> Argo CD `v3.5` moved its bundled renderer to **Helm 4** (`4.2.1`) as the **only** Helm binary. Helm 4 changed how `null`/nil values coalesce. Effect: **the same chart with the same values can render *different* manifests after you upgrade Argo CD alone** — most visibly for charts that relied on nulls being dropped.

Picture it: you upgrade Argo CD on Monday, touch no chart and no values, and Tuesday forty apps show a diff nobody committed. Under "Argo CD runs Helm" this is inexplicable; under the typewriter model it is obvious — **you replaced the typewriter, so the pages came out different.** The cheap practice: **before upgrading Argo CD, render your real charts with the new Helm and `diff` the output** (Session 7). Your VM's `helm` is pinned to `v4.2.1` so local renders match the repo-server.

> One gotcha: because Helm 4 is the only renderer in `v3.5`, setting `spec.source.helm.version: v3` is **ignored** — there is no "render with Helm 3" switch anymore.

---

## 6. Quick Checks

**S4-QC1 — Which value wins?** Chart default `1`, `valueFiles` `2`, `valuesObject` `3`, `parameters` `4`. Rendered replica count?

<details>
<summary>Show answer</summary>

**`4`.** The ladder (highest first) is parameter → valuesObject → valueFiles → chart default. `parameters` sits at the top, so `4` overrides all three lower sources. Same key in multiple places is resolved by *priority*, not proximity.
</details>

**S4-QC2 — Forty apps drift and nobody committed anything.** You upgrade Argo CD Monday, touch no chart/values, and Tuesday forty apps show a diff. What happened, and what one cheap Monday step would have caught it?

<details>
<summary>Show answer</summary>

**Argo CD's bundled Helm version changed, so the same charts rendered different manifests** (Helm 4 coalesces nulls differently). You changed the *renderer*, not the desired state — and because Argo CD renders with `helm template` and applies the result, **Helm's version is part of your desired state.** The cheap step: **render your real charts with the new Helm and `diff` before upgrading.**
</details>

---

## 7. Key takeaways

- **Argo CD borrows Helm's templating engine and throws away Helm's release manager** — `helm template`, then applies it itself. No release, no history, nothing for `helm rollback`. The empty `helm list` is proof.
- **Values resolve by a ladder:** parameter → valuesObject → valueFiles → chart default (highest first). Environment differences normally live in `valueFiles`.
- **Helm's version is part of your desired state** — upgrading Argo CD can change rendered manifests with no Git change.

**→ Next:** [02 — Sync ordering and drift](02-sync-ordering-and-drift.md)
