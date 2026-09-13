# Session 5 — ApplicationSets and App-of-Apps (modular arc)

> **Day 2 · Session 5 · Concept + hands-on · ~60 minutes**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`; repo-server renders with **Helm v4.2.1**).
> **Before this:** all of Day 1. **Lab 4** is where you build the storefront ApplicationSet, trace an App-of-Apps root, break it, and recover; this session builds the mental model.

Day 1 was about **one Application at a time**. Day 2 is about **scale** — the same app across a dozen clusters, or a whole platform of components that must come up in order. This session teaches Argo CD's two patterns for that, **ApplicationSets** and **App-of-Apps**, and how to reason about the new failure modes each introduces.

> **One promise up front:** there is **no new deployment mechanism today.** Both patterns are new ways of *writing Applications*. Once an Application exists, the same Day-1 controller reconciles it exactly as before.

Delivered as **three short modules**, each with a live ▶ action:

| Module | You will understand... | Hands-on | ~Time |
|---|---|---|---|
| [01 — The factory: ApplicationSets and generators](01-applicationsets-the-factory.md) | Fan-out, "they don't deploy anything", the five generators | Preview an ApplicationSet without creating anything | ~22 min |
| [02 — Safety: failing loud and bounding the blast radius](02-safety-and-controls.md) | `missingkey=error`, the three controls, preview→count→apply, progressive sync | Count a generated fan-out | ~18 min |
| [03 — App-of-Apps and choosing the pattern](03-app-of-apps-and-choosing.md) | Family tree, cascading deletion, the decision table, tracing failures | Read the root's family tree | ~20 min |

**→ Start:** [01 — The factory: ApplicationSets and generators](01-applicationsets-the-factory.md)
