# Session 3 — Production-Oriented Configuration (modular arc)

> **Day 1 · Session 3 · Concept + hands-on · ~60 minutes**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`).
> **Before this:** [Session 2](../session-02/README.md). **Lab 2** is where you actually connect a repository and register a workload cluster; this session gives you the mental model that makes Lab 2 make sense.

Session 1 gave you the platform's *shape*; Session 2 named its *components*. This session answers the next question a platform engineer asks: **how do you stand this thing up for production, and onboard repositories and clusters without handing out the keys to everything?** By the end you can defend three decisions to a security reviewer — which install model, how much high availability, and exactly how much power Argo CD gets on each cluster.

Delivered as **three short modules**, each with a live ▶ action:

| Module | You will understand... | Hands-on | ~Time |
|---|---|---|---|
| [01 — Install model and high availability](01-install-model-and-ha.md) | Multi-tenant vs Core, HA per component, and "who deploys the deployer" | Count what HA adds, via `helm template` | ~20 min |
| [02 — Onboarding repositories and clusters](02-onboarding-repos-and-clusters.md) | The three onboarding Secrets and the cluster-registration trust chain | Read the labeled onboarding Secrets and the default project | ~20 min |
| [03 — Least privilege and change detection](03-least-privilege-and-change-detection.md) | Least *write* privilege, `respectRBAC`, webhooks vs polling, pointer-vs-payload | Inspect the wide-open `default` project's allow-lists | ~20 min |

**→ Start:** [01 — Install model and high availability](01-install-model-and-ha.md)
