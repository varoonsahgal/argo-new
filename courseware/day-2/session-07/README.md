# Session 7 — Reliability and Troubleshooting

> **Day 2 · Session 7 · Concept + hands-on · 75 minutes (required path)**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`; repo-server renders with **Helm v4.2.1**). Lab clusters run **k3s v1.35.8**.
> **Before this:** all earlier sessions and labs. This session prepares you directly for the capstone.
> **Run every command in your VM terminal**, after `source ~/argo-lab-env.sh`.
> **← Back to:** [Day 2 map](../README.md)

---

## Session TL;DR

- **What this is.** A repeatable way to investigate an Argo CD incident: seven **stations**, each answering one question and naming one component.
- **Why it matters.** Under pressure people guess and restart things, which erases evidence and makes healthy components look guilty.
- **What to remember.** *Evidence comes before change.* And: *source problems come before render problems.*
- **The most common mistake.** Acting on a diff that looks like a deletion order. It usually means the desired side is missing, not that Git wants everything gone.

---

## Why this session exists

Every earlier session gave you one piece. Session 2 named the six components. Sessions 3 and 4 covered install, configuration, and rendering. Sessions 5 and 6 scaled and fenced the deployment path.

This session ties them into one skill: **diagnosing a real incident under pressure without making it worse.**

The capstone is nothing but this method, applied to seven faults at once.

---

## The seven stations, once, up front

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

> **A note if you have seen an earlier version of this course.** This was taught as a rigid six-step pipeline. It is now seven stations plus a branching tree, because real incidents skip stations and jump back. The evidence and the commands are unchanged.

---

## What you will be able to do

1. Scope an incident in one command, and tell one broken app from a shared-dependency failure.
2. Walk the stations in order, and say which component each one implicates.
3. Recognise a deletion-shaped diff and explain why you must not sync it.
4. Rule an Argo CD component in or out using readiness, restarts, logs, and events.
5. Separate sync status from health status, and say which one is stale.
6. Verify a repair with the same evidence you diagnosed with.

---

## The three modules

| Module | You will understand | Hands-on | Time |
|---|---|---|---|
| [01 — The investigation stations](01-investigation-stations.md) | the seven stations, the two rules, the branching decision tree, the capstone prerequisite map | run the first two evidence commands | 25 min |
| [02 — One incident, walked end to end](02-worked-incident.md) | the method on a real incident, including the deletion-shaped-diff trap | predict at each station, then read the evidence | 30 min |
| [03 — Component-level diagnosis](03-component-diagnosis.md) | readiness, restarts, logs, events, and each component's symptom pattern | run a full component health sweep | 20 min |

**Each module page is the authoritative version of its content.** This page is a map.

### Optional, outside the timebox

| Module | Contents |
|---|---|
| [Optional reference — platform operations after the capstone](90-reference-platform-operations.md) | high availability, sharding, alert design, ignore rules, backup and recovery, upgrades, forks |

---

## Before you start

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-capstone --verify-only --local
```

Every hands-on step in this session is **read-only**. Nothing here creates, changes, or deletes anything, and there is nothing to clean up.

> **Use Applications that exist at your checkpoint.** The Day 1 application `hello-reconcile` is removed from `CP-lab-04` onward. Check what is present with `argocd app list -o name`.

---

## Final TL;DR

- **Seven stations, two rules, one branching tree.**
- **Evidence comes before change; source problems come before render problems.**
- **Each station names one component**, so finding the station finds the pod.
- **The most common mistake** is trusting a diff whose desired side was never rendered.

**→ Start:** [01 — The investigation stations](01-investigation-stations.md)
