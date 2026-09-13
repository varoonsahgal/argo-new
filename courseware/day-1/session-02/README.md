# Session 2 — Argo CD Architecture and the Application Model (modular arc)

> **Day 1 · Session 2 · Concept + hands-on · ~60 minutes**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`).
> **Before this:** [Session 1](../session-01/README.md). You should have a terminal on your VM and the Argo CD UI at `https://localhost:8443`.

Session 1 gave you the *purpose and shape* of Argo CD — a thermostat that pulls desired state from Git and converges a cluster. This session **opens up the thermostat and names every part**, so that given any symptom you can say which component to suspect and read the two status words — **Synced** and **Healthy** — without ever confusing them.

Delivered as **three short modules**, each ending with a live ▶ action:

| Module | You will understand... | Hands-on | ~Time |
|---|---|---|---|
| [01 — The component team](01-the-component-team.md) | The six components and their one-verb jobs | List the running components; map each to its verb | ~20 min |
| [02 — Four states and the Application](02-four-states-and-the-application.md) | desired → target → rendered → live, and what an Application really is | Read an Application's addressing and its ownership stamp | ~20 min |
| [03 — Sync vs health](03-sync-vs-health.md) | The two independent status axes and refresh/hard-refresh/sync | Read sync and health straight off the object | ~20 min |

**→ Start:** [01 — The component team](01-the-component-team.md)
