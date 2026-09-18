# Session 6 — Security, Multi-Tenancy, and Governance

> **This is a short landing page. The authoritative content lives in the linked modules.**
> **→ Canonical entry point for the whole day: [Day 2 map](README.md)**

---

## Purpose

Learn the **four authorization gates** every request passes through in Argo CD, and how to tell instantly which one refused a request — because each is owned by a different team and fixed in a different file.

## Prerequisites

- [Session 5](session-05/README.md) and Lab 4, finishing at checkpoint `CP-lab-05`.
- A VM terminal with `source ~/argo-lab-env.sh` run.

## Time

**45 minutes**, required path. One optional reference module sits outside the timebox.

## The four gates

| Gate | The question it answers | Configured in |
|---|---|---|
| **1 · Argo CD RBAC** | Can this **user** request the action? | `argocd-rbac-cm` (`policy.csv`) |
| **2 · AppProject** | Is this **source, destination, namespace, or resource** allowed? | the `AppProject` |
| **3 · Cluster registration scope** | May Argo CD **manage this scope** at all? | the cluster registration Secret |
| **4 · Kubernetes RBAC** | Can the Argo CD **ServiceAccount** perform the operation? | `Role`/`RoleBinding` on the workload cluster |

> **If you have seen an earlier version of this course**, this material was taught as "three fences" plus a late addition called "fence 2b." It is now four numbered gates throughout Session 6, Lab 5, and Session 7. Same mechanisms, one consistent name each.

## Learning outcomes

1. Name all four gates and the question each answers.
2. Given an error message, name the responsible gate from its vocabulary alone.
3. Prove which gate refused, read-only, without triggering the failure again.
4. Say which team owns each gate's configuration, and therefore who to page.
5. Read an AppProject as a positive allow-list, and explain why an empty list denies.
6. Unit-test an Argo CD RBAC policy as a file, before any user is exposed to it.

## The modules — these pages are authoritative

| Module | Contents |
|---|---|
| [**Session 6 overview**](session-06/README.md) | the session map and prerequisites |
| [01 — The four authorization gates](session-06/01-the-four-gates.md) | each gate with a config example, a denial symptom, an owner, and a proof |
| [02 — AppProjects and Argo CD RBAC, up close](session-06/02-appprojects-and-rbac.md) | real policy lines, least privilege, the shared ServiceAccount |
| [03 — Reading a denial in the wild](session-06/03-reading-denials.md) | the decision tree, the mechanical settler, terse versus detailed denials |
| [Optional reference](session-06/90-reference-sso-secrets-and-governance.md) | SSO, secret patterns, project roles and scoped tokens, sync windows |

**→ Start:** [Session 6 overview](session-06/README.md)
