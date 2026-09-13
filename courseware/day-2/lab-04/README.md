# Lab 4 — Build and Troubleshoot the Patterns (modular arc)

> **Day 2 · Lab 4 · Hands-on · ~75 minutes · Scaffolding G2 (reduced)**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`, Kubernetes `v1.35`; repo-server renders with **Helm v4.2.1**).
> **Before this:** [Session 5](../session-05/README.md) and all of Day 1. Every *new* idea is explained before you use it; Day-1 mechanics are not re-explained — you will often write a command yourself first.
> **Open:** the Argo CD UI (`https://localhost:8443`, `admin`), a terminal with `argocd`/`kubectl` (`source ~/argo-lab-env.sh`), and your clones of `platform-config` and `storefront-gitops`.

---

## Why this matters

On Day 1 you took **one** application from commit to running workload. That does not scale: hand-writing one `Application` per target means every copy is a place to make a typo, and every typo is a separate incident. Day 2's two patterns solve that, each with a new failure mode:

- An **ApplicationSet** is a factory — describe the shape once, feed it data, it stamps out one Application per combination. New danger: **blast radius** — one wrong template line moves *every* generated Application; one removed label can quietly delete a fleet.
- An **App-of-Apps** is a family tree — one *root* owns several *child* Applications. New danger: **misread ownership** — a root that reports `Healthy` over a broken child, and "fixes" applied to the wrong layer that silently revert.

This lab builds both, then deliberately breaks them, to practise the one skill the Capstone grades hardest: **finding the layer that owns a failure before you touch anything.**

---

## Learning objectives

1. Generate Helm Applications for multiple environments by completing a real ApplicationSet (a *matrix* of cluster + Git-files generators), proving with a preview it produces exactly what you intended (**L4.1**).
2. Use labels and cluster data to control placement, previewing how a selector change moves the blast radius (**L4.2**).
3. Apply a protection policy (`applicationsSync: create-update` + `preserveResourcesOnDeletion`) and prove a generated Application *survives* a removed input (**L4.3**).
4. Inspect a root/child hierarchy, tracing each child to its repo and path (**L4.4**).
5. Introduce a template error and a child-application error, trace each to the owning layer, recover through Git (**L4.5**).
6. Compare the same change under each pattern, scored on operations (**L4.6**).

Maps to outcomes **O4, O5, O6, O7**.

---

## Mental model recap (short — Session 5 taught this)

- **The ApplicationSet is a factory** — you write the *thing that writes* the Applications. When a generated app is wrong, ask "what is wrong with the factory that produced it?"
- **The App-of-Apps is a family tree** — the root's *health* answers "did I apply the child objects?", **not** "are the children healthy?" (the Exercise 5B trap).
- **The same controller reconciles both** — a generated app and a child app are ordinary `Application` objects. Only *who wrote the object* changed. So every failure localizes to: **is the Application wrong, or is the thing that wrote it wrong?**

```mermaid
flowchart LR
    subgraph factory["ApplicationSet — a factory"]
      T["one template"] --> A1["storefront-dev-workload"]
      T --> A2["storefront-staging-workload"]
      T --> A3["storefront-prod-workload"]
    end
    subgraph tree["App-of-Apps — a family tree"]
      R["root: platform-root"] --> C1["platform-quotas"]
      R --> C2["platform-netpol"]
      R --> C3["platform-agent"]
    end
```

---

## The four modules

| Module | You will... | Exercises | ~Time |
|---|---|---|---|
| [01 — Environment and the preview rhythm](01-environment-and-preview.md) | Confirm the clean slate; install preview→count→apply | — | ~10 min |
| [02 — Build and protect the factory](02-build-and-protect-the-factory.md) | Complete the ApplicationSet; move the blast radius; protect against deletion | **E1, E2, E3** | ~31 min |
| [03 — App-of-Apps and tracing faults](03-app-of-apps-and-trace-faults.md) | Inspect the root/child tree; break it two ways and trace each | **E4, E5** | ~24 min |
| [04 — Pattern showdown and wrap-up](04-showdown-and-wrap-up.md) | Compare patterns on one task; checkpoint and stretch | **E6** | ~10 min |

**→ Start:** [01 — Environment and the preview rhythm](01-environment-and-preview.md)
