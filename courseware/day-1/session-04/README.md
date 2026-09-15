# Session 4 — Helm Deployments, Synchronization, and Promotion (modular arc)

> **Day 1 · Session 4 · Concept + hands-on · ~80 minutes (including Module 1.5)**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`; the repo-server renders charts with **Helm v4.2.1**).
> **Before this:** [Session 3](../session-03/README.md). **Lab 3** is where you deploy this chart, introduce drift, and recover; this session gives you the mental model that makes Lab 3 make sense.

Once Argo CD is holding a Helm chart, what does it actually *do* with it — and how do you move a change safely from development to production? By the end you can explain why `helm rollback` does not work under Argo CD, predict what a sync will and will not delete, read a sync-wave ordering, and describe a promotion as the small, reviewable Git change it really is.

Delivered as **four short modules**, each with a live ▶ action:

| Module | You will understand... | Hands-on | ~Time |
|---|---|---|---|
| [01 — Render, not release](01-render-not-release.md) | Argo CD borrows Helm's typewriter, not its filing cabinet; the precedence ladder | Prove `helm list` is empty; override a value | ~20 min |
| [1.5 — Why is my deployment waiting?](01b-sync-order-phases-waves-kinds-names.md) | Prerequisites and wave boundaries; why a sync can wait | Run a two-resource example; diagnose the missing ConfigMap; fix one wave number in Git | ~20 min |
| [02 — Sync ordering and drift](02-sync-ordering-and-drift.md) | Phases, waves, prune, self-heal | Read wave/hook annotations in the rendered chart | ~20 min |
| [03 — Promotion and recovery](03-promotion-and-recovery.md) | Repo layout, promotion as a moving pin, roll-forward vs rollback | Diff dev↔staging renders; trigger a `required` safety net | ~20 min |

**→ Start:** [01 — Render, not release](01-render-not-release.md)

