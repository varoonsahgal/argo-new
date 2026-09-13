# Session 7 — Reliability, Troubleshooting, and Lifecycle Operations (modular arc)

> **Day 2 · Session 7 · Concept + hands-on · ~75 minutes**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`; repo-server renders with **Helm v4.2.1**). Lab clusters run **k3s v1.35.8**.
> **Before this:** all earlier sessions and labs. This session prepares you for the **Capstone**.

Every earlier session gave you one piece: Session 2 named the six components and their verbs; Sessions 3–4 covered install, config, and rendering; Sessions 5–6 scaled and fenced the deployment path. This session ties it into one skill — **diagnosing a real incident under pressure without making it worse** — then covers the lifecycle jobs an operator owns.

> **One promise up front:** there is a **fixed order** for gathering evidence during an incident, and following it is what separates a five-minute fix from a two-hour outage. The Capstone is nothing but this method applied to several faults at once.

Delivered as **three short modules**, each with a live ▶ action:

| Module | You will understand... | Hands-on | ~Time |
|---|---|---|---|
| [01 — The six-step method](01-the-six-step-method.md) | The pipeline model, the six steps, and how each names a component | Run the first evidence command | ~20 min |
| [02 — One incident, all six steps](02-worked-incident.md) | The method walked end-to-end on a real incident, including the deletion-shaped-diff trap | Run the read-only evidence commands | ~25 min |
| [03 — Stability, recovery, and upgrades](03-stability-recovery-upgrades.md) | HA, sharding, observability, backup/recovery, upgrades, forks | Export Argo CD's own state | ~30 min |

**→ Start:** [01 — The six-step method](01-the-six-step-method.md)
