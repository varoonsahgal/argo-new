# Capstone — Restore an Argo CD Deployment Platform (modular arc)

> **Day 2 · Capstone · Diagnostic lab · 90 minutes · Scaffolding G3 (diagnostic)**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`, Kubernetes `v1.35`; repo-server renders with **Helm v4.2.1**).
> **Before this:** every guide and lab in the course, especially [Session 7](../session-07/README.md).

This guide explains the **method** in full — how to gather evidence, decide which layer a symptom belongs to, change something safely, and prove a repair worked. It deliberately gives **no fault-specific answers.** Finding out what is broken is the exercise.

> **What you need open:** two VM terminals (`source ~/argo-lab-env.sh` in each), the Argo CD UI at `https://localhost:8443` (logged in as `admin`), and a text editor for your incident log. **The clock starts when your instructor announces the incident has begun.**

---

## How the capstone is organized

Read **modules 01–03** during the first phase (they are your reference), then work **modules 04–05** as the clock runs. Module 06 is your troubleshooting and completion reference.

| Module | What it is | When |
|---|---|---|
| [01 — The brief and the mental model](01-brief-and-mental-model.md) | Why this matters, objectives, the six-step method, six layers, the masking chain | Read in P0 |
| [02 — Setup and rules of engagement](02-setup-and-rules.md) | Environment check, incident start, workspace, the rules, the four change paths | Read in P0 |
| [03 — The evidence toolbox](03-evidence-toolbox.md) | Every read-only tool, organized by layer, plus one fully worked row | Reference throughout |
| [04 — P0–P1: brief and triage](04-triage.md) | Your first move; build the triage grid; Checkpoint C1 | Work at 0:00–0:25 |
| [05 — P2–P4: restore, verify, reflect](05-restore-verify-reflect.md) | The repair loop, sanity checks, verification, written reflection | Work at 0:25–1:30 |
| [06 — Troubleshooting and completion](06-troubleshooting-completion-close.md) | Mechanics troubleshooting, what "restored" means, takeaways, stretch, close | Reference + close |

## The four rules of this capstone

1. **Find out what is true before you touch anything.**
2. **Every change goes through Git or the platform's declarative configuration.** No hand edits on a live cluster.
3. **Write everything down:** what you saw, what you changed, what happened next.
4. **When it is fixed, tell us what would have caught it sooner.**

The incident contains **seven faults** across more than one layer, and some are connected — one can hide or change the symptoms of another. People who chase the loudest red badge diagnose the same thing three times. People who follow a method finish.

**→ Start:** [01 — The brief and the mental model](01-brief-and-mental-model.md)
