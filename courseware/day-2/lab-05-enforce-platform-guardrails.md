# Lab 5 — Enforce Platform Guardrails

> **This lab is now delivered as a short, hands-on modular arc.**
>
> **→ Start here: [`lab-05/README.md`](lab-05/README.md)**

## The four modules

1. [Environment and the two mechanisms](lab-05/01-environment-and-mechanisms.md) — confirm the start state; how a fence and a policy are written, applied, and read.
2. [Build the fence and prove the happy path](lab-05/02-build-fence-and-happy-path.md) — **E1** (team-a AppProject + RBAC grant), **E2** (deploy inside every fence).
3. [Bypass attempts](lab-05/03-bypass-attempts.md) — **E3** (wrong destination + cluster-scoped kind), **E4** (Argo CD denial vs Kubernetes denial — the centerpiece).
4. [Deletion protection and wrap-up](lab-05/04-deletion-protection-and-wrap-up.md) — **E5** (delete denied, the deletion-path danger), checkpoint, stretch.

*(This replaces the previous single-file version of Lab 5. All exercises (E1–E5), screenshots, the four-fence model, troubleshooting, and the checkpoint are preserved across the four modules. The instructor solution still maps to exercise IDs E1–E5.)*
