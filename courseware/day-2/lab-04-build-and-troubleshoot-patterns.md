# Lab 4 — Build and Troubleshoot the Patterns

> **This is a short landing page. The authoritative content lives in the linked modules.**
> **→ Canonical entry point for the whole day: [Day 2 map](README.md)**

---

## Purpose

Build both Day 2 patterns for real, break each one on purpose, and trace each fault to the layer that owns it.

## Prerequisites

- [Session 5](session-05/README.md) and all of Day 1.
- **Starting checkpoint: `CP-lab-04`.** Verify it with `reset-lab.sh CP-lab-04 --verify-only --local`.
- A VM terminal with `source ~/argo-lab-env.sh` run, the Argo CD user interface open, and your `platform-config` and `storefront-gitops` clones.

## Time

**75 minutes.** Stretch challenges sit outside the timebox.

## Learning outcomes

1. Complete a real ApplicationSet and prove with a preview that it produces exactly what you intended.
2. Predict how a selector change moves the blast radius, and verify it without applying.
3. Apply a protection policy and show which layer each setting protects.
4. Inspect a root and child hierarchy, tracing each child to its repository and path.
5. Introduce a fault in each pattern, trace each to its owning layer, and repair through Git.
6. Compare the two patterns on one real task, and defend a choice on operations.
7. Work a five-decision incident under capstone rules.

## The modules — these pages are authoritative

| Module | Exercises |
|---|---|
| [**Lab 4 overview**](lab-04/README.md) | the lab map, hint policy, and recovery table |
| [01 — Starting state and the preview habit](lab-04/01-environment-and-preview.md) | — |
| [02 — Build the factory, and break it once](lab-04/02-build-and-protect-the-factory.md) | **E1, E2, E3** |
| [03 — Build the family tree, and break it once](lab-04/03-app-of-apps-and-trace-faults.md) | **E4, E5** |
| [04 — Compare the patterns, then the bridge incident](lab-04/04-showdown-and-wrap-up.md) | **E6, E7** |

**→ Start:** [Lab 4 overview](lab-04/README.md)
