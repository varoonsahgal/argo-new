# Session 4 · Module 3 — Promotion and Recovery

> **Day 1 · Session 4 · Module 3 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** see how one chart serves many environments, understand a promotion as a moving version pin, and know when to roll forward vs roll back.

---

## 1. Repository layout: one chart, per-environment values

This course's `storefront-gitops` uses the recommended **directory-per-environment** layout:

```text
storefront-gitops/                 # ONE repo, ONE chart, per-env values in directories
  charts/storefront/               # the chart, rendered for every environment
  envs/
    dev/values.yaml                # replicaCount: 1, UI "storefront DEV"
    staging/values.yaml            # replicaCount: 2, UI "storefront STAGING"
    prod/values.yaml               # replicaCount: 2, UI "storefront PROD"
```

| Layout | How environments differ | Strengths | Watch-outs |
|---|---|---|---|
| **Directory-per-env** (this course) | Different values file, same branch | Every env's config visible side-by-side; promotion is a one-file diff | Everyone shares one branch's history |
| **Branch-per-env** | Different branch | Familiar Git-flow; per-env branch protection | Promotion becomes a merge; drift between branches is easy to miss |
| **Repo-per-env** | A separate repo per env | Hardest blast-radius/access boundaries | Duplication; keeping the chart in sync is manual |

**Directory-per-env makes promotion legible:** because all three environments' values sit next to each other, "promote dev to staging" is a diff you can *see* and review in one pull request. The trade is boundary strength vs friction — pick for the boundary you actually need.

---

## 2. Promotion is a moving pin, not a moving artifact

Promotion under GitOps is **moving a version pin from one environment's config into the next.** The chart does not move. The image does not move. A **number** moves — in a pull request, with a reviewer.

```text
   dev/values.yaml            staging/values.yaml          prod/  (config.yaml)
   image.tag: 6.16.0   ──▶    image.tag: 6.16.0    ──▶     targetRevision: storefront-1.0.0
   (tracks main, moves         (promoted after a week        (pinned to an IMMUTABLE Git TAG:
    freely in dev)              of clean dev soak)             prod never tracks a moving branch)

   PROMOTION = a one-line diff:   -  image.tag: 6.15.0
                                  +  image.tag: 6.16.0
```

- **The smallest promotion is a one-line diff** — write the tag `dev` has proven into `staging/values.yaml`.
- **Environments differ by their pin, not their chart.** Here, `dev` and `staging` track `main`; `prod` is pinned to the **immutable tag** `storefront-1.0.0`. Production changes only when a human deliberately moves that pin.

> **"`main` is not a version — it is a subscription."** Pointing `targetRevision` at `main` means your desired state changes whenever *anyone else* commits. Fine for `dev`; for a higher environment it means the environment has no owner. Pin a tag or SHA where a human must decide.

---

## 3. Recovery: roll forward or roll back?

Recovery is decided by one question — *do I know why it broke?*

- **You know why → roll forward.** Commit the fix; move to a new, better state.
- **You do not know why, and users are affected → roll back.** Restore the last known-good desired state with **`git revert`** (not `git reset --hard`), so the recovery is itself an auditable event — then investigate with the pressure off.

Notice what is *not* in either path: `helm rollback`. There is no release to roll back to — the version record is Git history. That is exactly why the paged engineer in Module 1 found an empty filing cabinet.

> **Sidebar — Kustomize on Helm, and the ownership trap.** Argo CD can render a Helm chart and then apply a Kustomize patch on top. Useful for a last-mile tweak the chart does not expose (e.g. a label on every object). The risk is **ownership**: a patch that sets `replicas: 3` on a Deployment the chart rendered with `replicas: 1` means two tools claim the same field — the values file says `1`, the cluster runs `3`, the truth is a patch a rung away. Reserve Kustomize-on-Helm for what the chart genuinely cannot express, and never let it silently re-own a field (guardrails in Session 6).

---

## 4. Hands-on: see what actually differs between environments (read-only)

This changes **nothing** — it renders the chart twice and diffs.

**▶ Do this now — diff dev vs staging** (in `~/storefront-gitops`). **Predict first:** the two envs differ in namespace, replica count, and UI message/color — which of those will show in the *rendered manifests*?

```bash
diff \
  <(helm template storefront charts/storefront -f envs/dev/values.yaml) \
  <(helm template storefront charts/storefront -f envs/staging/values.yaml)
```

**Expected output:**

```diff
15,16c15,16
<   PODINFO_UI_MESSAGE: "storefront DEV"
<   PODINFO_UI_COLOR: "#2da44e"
---
>   PODINFO_UI_MESSAGE: "storefront STAGING"
>   PODINFO_UI_COLOR: "#bf8700"
50c50
<   replicas: 1
---
>   replicas: 2
```

**🔍 Notice what is *absent*:** the **UI text/color and replica count** differ (they land in the ConfigMap and Deployment), but the **`namespace` value does NOT appear in the diff.** `helm template` renders object *contents*, not the namespace they get applied *into* — the namespace is decided by the Application's `destination`, not a field in these manifests. That absence is a small, concrete proof of the render-vs-apply split.

**▶ Do this now — see the chart's safety net fire.** The chart requires an image tag rather than defaulting to `latest`:

```bash
helm template storefront charts/storefront -f envs/dev/values.yaml --set image.tag=""
```

**Expected output:**

```text
Error: execution error at (storefront/templates/deployment.yaml:12:14): image.tag is required (set it in envs/<env>/values.yaml)
```

**🔍 Notice:** rendering **fails** with a readable message rather than silently deploying `latest`. A chart can build its own guardrails using Helm's `required`.

---

## 5. Quick Check

**S4-QC5 — A Kustomize patch sets `replicas` on Helm's output.** A team renders the `storefront` chart (which sets `replicas` from `replicaCount`) and then applies a Kustomize patch that also sets `replicas: 3`. Who owns `replicas`, and why is that risky?

<details>
<summary>Show answer</summary>

**The Kustomize patch owns `replicas`** — it is applied *after* Helm renders, so it wins. The risk is **unclear ownership**: the Helm values file shows one number, the cluster runs another, the truth is in a patch a step removed. When someone needs to change the count, "where does this value live?" has no obvious answer, and editing the Helm values appears to do nothing. It gets sharper if an **HPA** also manages `replicas` — chart, patch, and autoscaler all fight. Reserve Kustomize-on-Helm for what the chart cannot express (guardrails in Session 6).
</details>

---

## 6. Common misconceptions

- **"Argo CD runs `helm upgrade`."** No — `helm template` then applies it itself. No release; `helm list` is empty; nothing for `helm rollback`.
- **"Self-heal retries a failed sync."** No — self-heal re-applies desired state when the *live cluster drifts*. Re-attempting a *failed* sync is the separate **`retry`** setting.
- **"Rollback is always available."** The UI/CLI rollback is **blocked while automated sync is on** (Git would immediately win it back). Revert in Git, or disable auto-sync first.
- **"`main` is a version."** It is a **subscription** — desired state changes whenever anyone commits. Pin a tag/SHA for owned environments.

---

## 7. Key takeaways

- **Promotion is a moving pin, not a moving artifact** — the smallest promotion is a one-line diff with a reviewer's name on it; production is pinned to an immutable tag, never a moving branch.
- **Directory-per-env makes promotion reviewable** because both files sit side by side.
- **Recovery is a Git operation** — roll forward if you know why, `git revert` to roll back if you do not. Never `helm rollback`.
- **Kustomize-on-Helm risks unclear field ownership** — reserve it for what the chart cannot express.

---

## 8. Transition — to Lab 3

You now have the model; **Lab 3 (Deploy, Introduce Drift, and Recover)** makes it muscle memory. You will deploy this exact `storefront` chart to the workload cluster, watch the PreSync migration hook run, then run the drift experiment in three deliberate acts — self-heal off, self-heal on, edit-again — predicting each result first. Then you will break the app on purpose (a rendering failure, then an ordering failure) and recover it through Git. Lab 3 is the first lab that stops re-explaining mastered mechanics and starts asking you to predict and decide.

**→ Next:** [Lab 3 — Deploy, Introduce Drift, and Recover](../lab-03-deploy-drift-and-recover.md)
