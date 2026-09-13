# Helm Deployments, Synchronization, and Promotion

> **This session is now delivered as a short, hands-on modular arc.**
>
> **→ Start here: [`session-04/README.md`](session-04/README.md)**

## The three modules

1. [Render, not release](session-04/01-render-not-release.md) — Argo CD borrows Helm's typewriter, not its filing cabinet; the precedence ladder; prove `helm list` is empty.
2. [Sync ordering and drift](session-04/02-sync-ordering-and-drift.md) — phases, waves, prune, self-heal; read the ordering annotations in the rendered chart.
3. [Promotion and recovery](session-04/03-promotion-and-recovery.md) — repo layout, promotion as a moving pin, roll-forward vs rollback; diff dev↔staging renders.

*(This replaces the previous single-file version of Session 4. All diagrams (V-14–V-18), the Kustomize sidebar, sync-option reference tables, screenshots, Quick Checks, and takeaways are preserved across the three modules above.)*
