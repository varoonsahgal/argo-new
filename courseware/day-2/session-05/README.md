# Session 5 — ApplicationSets and App-of-Apps

> **Day 2 · Session 5 · Concept + hands-on · 60 minutes (required path)**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`; repo-server renders with **Helm v4.2.1**).
> **Before this:** all of Day 1, finishing at checkpoint `CP-lab-04`.
> **Run every command in your VM terminal**, after `source ~/argo-lab-env.sh`.
> **← Back to:** [Day 2 map](../README.md)

---

## Session TL;DR

- **What this is.** Two ways to manage many Applications instead of one: a **factory** that generates them, and a **family tree** that lists them.
- **Why it matters.** Day 1 does not scale. Ten hand-copied Applications means ten chances to be wrong, and one shared fix to apply ten times.
- **What to remember.** *ApplicationSet is a factory. App-of-Apps is a family tree. ApplicationSet gives you leverage; App-of-Apps gives you legibility.*
- **The most common mistake.** Expecting a new deployment mechanism. **There is none today.** Both patterns just write ordinary Applications, which the Day-1 controller then reconciles exactly as before.

---

## Why this session exists

Day 1 was about **one Application at a time**. Day 2 is about **scale** — the same app across several environments or clusters, or a whole platform of components that must come up together.

Scale brings two genuinely new failure modes, and both appear in the capstone:

- **Blast radius.** One template line now moves every generated Application. One selector edit can move a fleet.
- **Misread ownership.** A parent that reports `Healthy` above a broken child, and "fixes" that silently revert because you edited the wrong layer.

This session builds the models. Lab 4 breaks them on purpose.

---

## What you will be able to do

1. Explain why a team uses an ApplicationSet instead of copying Application YAML.
2. Point at the **generator**, the **template**, and the resulting **Applications**, and say which controller owns each.
3. Preview an ApplicationSet without creating anything, and **count** what it would produce.
4. Name the three settings that keep a factory safe, and say which layer each one protects.
5. Read an App-of-Apps tree, and explain what deleting its root would do.
6. Choose between the patterns with one question, and defend the choice.

---

## The three modules

| Module | You will understand | Hands-on | Time |
|---|---|---|---|
| [01 — ApplicationSets: one template, many Applications](01-applicationsets-the-factory.md) | fan-out, "it does not deploy anything", the four generators | preview an ApplicationSet that creates nothing | 20 min |
| [02 — Keeping the factory safe](02-safety-and-controls.md) | `missingkey=error`, the two protection layers, preview → count → apply | count a generated fan-out | 20 min |
| [03 — App-of-Apps, and choosing between the patterns](03-app-of-apps-and-choosing.md) | the family tree, cascading deletion, ownership, the decision table | read the root's family tree from Git | 20 min |

**Each module page is the authoritative version of its content.** This page is a map.

### Optional, outside the timebox

| Module | Contents |
|---|---|
| [Optional reference — generator catalogue and Progressive Syncs](90-reference-generators-and-progressive-syncs.md) | the other six generator types, and why Progressive Syncs is not a health gate |

---

## Before you start

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-04 --verify-only --local
```

This prints a PASS/FAIL table and **changes nothing**. Every row should read PASS. If any row fails, see [resetting and recovering](../README.md#resetting-and-recovering).

The hands-on steps in this session are read-only previews. They create nothing and need no cleanup.

---

## Final TL;DR

- **Three modules, 60 minutes, no new deployment mechanism.**
- **Factory for leverage, family tree for legibility.** The question that decides it is *derived or decided?*
- **Preview, count, apply** is the habit that survives into the capstone.
- **The most common mistake** is diagnosing a generated Application without asking whether the *writer* or the *Application* is broken.

**→ Start:** [01 — ApplicationSets: one template, many Applications](01-applicationsets-the-factory.md)
