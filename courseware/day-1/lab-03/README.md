# Lab 3 — Deploy, Introduce Drift, and Recover (modular arc)

> **Day 1 · Lab 3 · Hands-on · ~60 minutes · Scaffolding G2 (reduced)**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`, Kubernetes `v1.35`; repo-server renders with **Helm v4.2.1**).
> **Before this:** [Session 4](../session-04/README.md) and Lab 2. Every *new* idea here is still explained in full before you use it; the mechanics you already own (logging in, reading a diff, running `argocd`/`kubectl`) are not re-explained — you will often write a command yourself before the guide shows one way.
> **Open:** the Argo CD UI (`https://localhost:8443`, logged in as `admin`), a terminal with `argocd`/`kubectl` (`source ~/argo-lab-env.sh`), and your clones of `storefront-gitops` and `platform-config`.

---

## Why this matters

This is the lab where Day 1 pays off. You will take one Helm application from a Git commit all the way to a running workload on a *separate* cluster, deliberately break it two different ways, and bring it back — every time through Git, never by hand-fixing the cluster. That is the exact loop an on-call engineer runs during a real incident:

- A deployment looks wrong. **Is it drift, a rendering failure, or an ordering failure?** They look equally red and live in different places.
- Someone "fixes" production with `kubectl edit` and it silently reverts. **Bug, or the platform doing its job?**
- A change must be undone now. **Revert, or roll forward?**

The muscle you build here — *find the layer before you touch anything* — is exactly what the Day 2 Capstone grades.

---

## Learning objectives

1. Deploy a Helm app to the registered workload cluster and prove Argo CD renders rather than creating a Helm release (**L3.1**).
2. Apply an environment-specific values file (author a `staging` Application) and **promote a version pin** as a single reviewable Git change (**L3.2**).
3. Introduce live drift and read Argo CD's response — predicting *which* axis changes and why nothing reverts under manual sync (**L3.3**).
4. Configure safe automated sync + self-heal with pruning deliberately off (**L3.4**).
5. Introduce a rendering failure and an ordering failure, tell them apart by where the evidence appears, and recover both through Git (**L3.5**).

Maps to outcomes **O5, O6, O7, O1**. Meeting them *is* the **Day 1 outcome**.

---

## Mental model recap (short)

- **Sync and health are independent** — sync asks "matches Git?", health asks "actually working?". Watching *which* axis moves tells drift from an outage.
- **Three states: desired → rendered → live.** A failure at each stage shows in a different place.
- **Waves and hooks order a sync.** A PreSync migration Job must succeed *before* the main resources; the ConfigMap is wave `-1`, the Deployment/Service wave `0`. **If an earlier stage fails, later stages never run.**
- **Self-heal is a policy about who wins ties, not a safety net.** A `kubectl edit` works for a moment, then is undone. The durable change is a commit.

```mermaid
flowchart LR
    C["Git: storefront-gitops<br/>chart + envs/&lt;env&gt;/values.yaml"] --> R["repo-server<br/>helm template"]
    R --> CMP["controller: compare rendered vs live (every 60s)"]
    CMP --> AP["apply in order:<br/>PreSync hook → wave -1 → wave 0"]
    AP --> L["workload cluster: live objects"]
    L -. "drift discovered here" .-> CMP
```

---

## The four modules

| Module | You will... | Exercises | ~Time |
|---|---|---|---|
| [01 — Environment and new mechanics](01-environment-and-mechanics.md) | Confirm the start state; learn to reach the workload app and where each change lives | — | ~8 min |
| [02 — Deploy and promote](02-deploy-and-promote.md) | Sync dev (prove render-not-release); author staging; promote a tag | **E1, E2** | ~20 min |
| [03 — Drift and self-heal](03-drift-and-self-heal.md) | Introduce drift under manual sync; turn on safe self-heal | **E3, E4** | ~20 min |
| [04 — Break it two ways and recover](04-break-and-recover.md) | Rendering vs ordering failure; recover through Git; the Day 1 checkpoint | **E5** | ~15 min |

**→ Start:** [01 — Environment and new mechanics](01-environment-and-mechanics.md)
