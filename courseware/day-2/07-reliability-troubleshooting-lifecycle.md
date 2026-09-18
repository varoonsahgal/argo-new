# Session 7 — Reliability and Troubleshooting

> **This is a short landing page. The authoritative content lives in the linked modules.**
> **→ Canonical entry point for the whole day: [Day 2 map](README.md)**

---

## Purpose

Learn a repeatable way to investigate an Argo CD incident: **seven investigation stations**, each answering one question and naming one component. This session prepares you directly for the capstone.

## Prerequisites

- All earlier sessions and labs, finishing at checkpoint `CP-capstone`.
- A VM terminal with `source ~/argo-lab-env.sh` run.

## Time

**75 minutes**, required path. One optional reference module sits outside the timebox.

## The seven stations

| Station | The question | The component it names |
|---|---|---|
| **0 · Scope** | how many Applications, and what do they share? | *(sets your path)* |
| **1 · Source** | is the declared source correct, and does it answer? | **Git** |
| **2 · Render** | did manifests actually come out? | **repo-server** |
| **3 · Compare** | what is genuinely different, and can I trust the diff? | **application controller** |
| **4 · Apply + health** | was anything written, and is the workload healthy? | **application controller** + target cluster API |
| **5 · Component** | is the implicated component itself healthy? | whichever station 1–4 named |
| **6 · Repair + verify** | did the fix converge? | **Git**, then the whole loop again |

**Stations 0 to 5 are pure reading. Station 6 is the first change you make.**

> **If you have seen an earlier version of this course**, this was a rigid six-step pipeline. It is now seven stations plus a branching decision tree, because real incidents skip stations and jump back. The evidence and commands are unchanged.

## Learning outcomes

1. Scope an incident in one command, and tell one broken app from a shared-dependency failure.
2. Walk the stations in order, and say which component each implicates.
3. Recognise a deletion-shaped diff and explain why you must not sync it.
4. Rule an Argo CD component in or out using readiness, restarts, logs, and events.
5. Separate sync status from health status, and say which one is stale.
6. Verify a repair with the same evidence you diagnosed with.

## The modules — these pages are authoritative

| Module | Contents |
|---|---|
| [**Session 7 overview**](session-07/README.md) | the session map and prerequisites |
| [01 — The investigation stations](session-07/01-investigation-stations.md) | the stations, the two rules, the branching tree, the capstone prerequisite map |
| [02 — One incident, walked end to end](session-07/02-worked-incident.md) | an unreachable repository, including the deletion-shaped-diff trap |
| [03 — Component-level diagnosis](session-07/03-component-diagnosis.md) | readiness, restarts, logs, events, and each component's symptom pattern |
| [Optional reference](session-07/90-reference-platform-operations.md) | high availability, sharding, backup and recovery, upgrades, forks |

**→ Start:** [Session 7 overview](session-07/README.md)
