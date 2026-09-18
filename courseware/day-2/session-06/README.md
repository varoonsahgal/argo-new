# Session 6 — Security, Multi-Tenancy, and Governance

> **Day 2 · Session 6 · Concept + hands-on · 45 minutes (required path)**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`; repo-server renders with **Helm v4.2.1**).
> **Before this:** [Session 5](../session-05/README.md) and Lab 4, finishing at checkpoint `CP-lab-05`.
> **Run every command in your VM terminal**, after `source ~/argo-lab-env.sh`.
> **← Back to:** [Day 2 map](../README.md)

---

## Session TL;DR

- **What this is.** Four independent permission systems — **gates** — that every request must pass, and how to tell instantly which one refused.
- **Why it matters.** Session 5 gave you leverage. Leverage is exactly what makes governance urgent: the more one action can do, the more it matters who may take it and what it may touch.
- **What to remember.** *"Permission denied" is not a diagnosis. "Which permission system denied it" is.*
- **The most common mistake.** Treating all four gates as one thing called "Argo CD security." They are four systems, with four owners and four fixes.

---

## The four gates, once, up front

| Gate | The question it answers | Where it is configured |
|---|---|---|
| **1 · Argo CD RBAC** | Can this **user** request the action? | `argocd-rbac-cm` (`policy.csv`) |
| **2 · AppProject** | Is this **source, destination, namespace, or resource** allowed? | the `AppProject` object |
| **3 · Cluster registration scope** | May Argo CD **manage this scope** at all? | the cluster registration Secret |
| **4 · Kubernetes RBAC** | Can the Argo CD **ServiceAccount** perform the operation? | `Role`/`RoleBinding` on the workload cluster |

**Gates 1, 2, and 3 live inside Argo CD and refuse without touching the workload cluster. Gate 4 lives on the workload cluster and refuses during the apply.**

That split gives you the routing question you will use for the rest of the course: **did anything on the cluster actually get touched?**

> **A note if you have seen an earlier version of this course.** This material used to be taught as "three fences" plus a late addition called "fence 2b." It is now four numbered gates throughout, in Session 6, Lab 5, and Session 7. Same mechanisms, one consistent name for each.

---

## What you will be able to do

1. Name all four gates and the question each one answers.
2. Given an error message, name the responsible gate from its **vocabulary** alone.
3. Prove which gate refused, using a read-only command, without triggering the failure again.
4. Say which team owns each gate's configuration, and therefore who to page.
5. Read an AppProject as a positive allow-list, and explain why an empty list denies.
6. Unit-test an Argo CD RBAC policy as a file, before any user is exposed to it.

---

## The three modules

| Module | You will understand | Hands-on | Time |
|---|---|---|---|
| [01 — The four authorization gates](01-the-four-gates.md) | all four gates, each with a config example, a denial symptom, an owner, and a proof | — | 15 min |
| [02 — AppProjects and Argo CD RBAC, up close](02-appprojects-and-rbac.md) | the real AppProject and policy lines, least privilege, the shared ServiceAccount | unit-test a policy offline | 18 min |
| [03 — Reading a denial in the wild](03-reading-denials.md) | the decision tree, the mechanical settler, terse versus detailed denials, deletion paths | — | 12 min |

**Each module page is the authoritative version of its content.** This page is a map.

### Optional, outside the timebox

| Module | Contents |
|---|---|
| [Optional reference — SSO, secrets, and governance controls](90-reference-sso-secrets-and-governance.md) | group-to-role mapping, secret patterns, project roles and scoped tokens, sync windows |

---

## Before you start

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-05 --verify-only --local
```

This prints a PASS/FAIL table and **changes nothing**. Two rows assert an *absence* — `AppProject team-a absent` and `Application team-a-guestbook absent`. A PASS on those means the thing is correctly missing; you create both in Lab 5.

The one hands-on step in this session writes a file to `/tmp` and contacts no cluster. It cleans up with a single `rm`.

---

## Final TL;DR

- **Four gates, four questions, four owners, four message signatures.**
- **Gates 1–3 refuse before anything is applied; gate 4 refuses during the apply.**
- **Kubernetes cannot tell your tenants apart** — the AppProject is the tenancy boundary.
- **The most common mistake** is naming a gate from expectation instead of from the message's vocabulary.

**→ Start:** [01 — The four authorization gates](01-the-four-gates.md)
