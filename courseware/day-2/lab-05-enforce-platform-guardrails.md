# Lab 5 — Enforce Platform Guardrails

> **This is a short landing page. The authoritative content lives in the linked modules.**
> **→ Canonical entry point for the whole day: [Day 2 map](README.md)**

---

## Purpose

Build a real fence around a new tenant, prove it lets the right thing through, then try to walk through it — once refused by Argo CD, once refused by Kubernetes — and name the owner of each refusal.

## Prerequisites

- [Session 6](session-06/README.md) and all earlier labs.
- **Starting checkpoint: `CP-lab-05`.** Verify it with `reset-lab.sh CP-lab-05 --verify-only --local`.
- A VM terminal with `source ~/argo-lab-env.sh` run, the Argo CD user interface open, and your `platform-config` clone.

## Time

**45 minutes.** Stretch challenges sit outside the timebox.

## Learning outcomes

1. Create a restricted AppProject from a specification, and write a least-privilege Argo CD RBAC grant.
2. Deploy an Application that reaches `Synced`/`Healthy` *because* it lands inside every gate.
3. Trigger an AppProject denial and read its signature.
4. Trigger a Kubernetes RBAC denial and compare the two on who denied it, where it is logged, which configuration fixes it, and who owns that configuration.
5. Prove a least-privilege role cannot delete, and explain where deletion danger actually lives.

## The modules — these pages are authoritative

| Module | Exercises |
|---|---|
| [**Lab 5 overview**](lab-05/README.md) | the lab map, the four gates, hint policy, and recovery table |
| [01 — Starting state and the two mechanisms](lab-05/01-environment-and-mechanisms.md) | — |
| [02 — Build the fence, prove the happy path](lab-05/02-build-fence-and-happy-path.md) | **E1, E2** |
| [03 — Two denials, two systems](lab-05/03-bypass-attempts.md) | **E3, E4** |
| [04 — Deletion, finalizers, and wrap-up](lab-05/04-deletion-protection-and-wrap-up.md) | **E5** |

**→ Start:** [Lab 5 overview](lab-05/README.md)
