# Session 1 — GitOps and the Argo CD Topology (modular arc)

> **Day 1 · Session 1 · Concept + hands-on · ~45 minutes**
> **Argo CD version this course targets: `v3.5.2`.**
> **Before this:** the [welcome guide](../00-welcome-and-agenda.md) and the hands-on [Kubernetes + Helm refresher](../refresher/README.md).

This session gives you the **mental model** the whole course hangs on: what Argo CD is for, what it owns, what it deliberately does **not** own, and the shape of the production system you will operate. Unlike a pure lecture, each part ends with a short **▶ Do this now** action against your live environment, so the ideas are never abstract.

It is delivered as **three short modules** you read in order:

| Module | You will understand... | Hands-on | ~Time |
|---|---|---|---|
| [01 — Why GitOps: a thermostat, not a light switch](01-why-gitops-thermostat.md) | Why a hand-edited cluster silently reverts, and the core GitOps idea | See the app serving live; `curl` its message | ~15 min |
| [02 — Topology and ownership](02-topology-and-ownership.md) | The management/workload cluster shape and who owns what | Explore both clusters; read an Application's addressing | ~15 min |
| [03 — The reconciliation loop](03-reconciliation-loop.md) | The continuous loop and the evidence each stage leaves | Delete a Pod and prove it is *not* drift | ~15 min |

**What you need open:** a terminal on your VM (with `kubectl` and `argocd` working) and the Argo CD web interface at `https://localhost:8443`. If either is not ready, work through the [student setup guide](../../environment/student-setup-guide.md) first.

**→ Start:** [01 — Why GitOps: a thermostat, not a light switch](01-why-gitops-thermostat.md)
