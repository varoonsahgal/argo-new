# Session 5 — ApplicationSets and App-of-Apps

> **This is a short landing page. The authoritative content lives in the linked modules.**
> **→ Canonical entry point for the whole day: [Day 2 map](README.md)**

---

## Purpose

Learn the two Argo CD patterns for managing **many** Applications instead of one: an **ApplicationSet**, which is a factory that generates Applications from data, and an **App-of-Apps**, which is a family tree of Applications a person wrote by name.

## Prerequisites

- All of Day 1, finishing at checkpoint `CP-lab-04`.
- A VM terminal with `source ~/argo-lab-env.sh` run.

## Time

**60 minutes**, required path. One optional reference module sits outside the timebox.

## Learning outcomes

By the end you will be able to:

1. Explain why a team uses an ApplicationSet instead of copying Application YAML.
2. Name the generator, the template, and the two controllers involved, and say which owns what.
3. Preview an ApplicationSet without creating anything, and count what it would produce.
4. Name the three settings that keep a factory safe and which layer each protects.
5. Read an App-of-Apps tree and explain what deleting its root would do.
6. Choose between the two patterns with one question, and defend the choice.

## The modules — these pages are authoritative

| Module | Contents |
|---|---|
| [**Session 5 overview**](session-05/README.md) | the session map and prerequisites |
| [01 — ApplicationSets: one template, many Applications](session-05/01-applicationsets-the-factory.md) | fan-out, the two controllers, the four generators, previewing |
| [02 — Keeping the factory safe](session-05/02-safety-and-controls.md) | `missingkey=error`, the two protection layers, preview → count → apply |
| [03 — App-of-Apps, and choosing between the patterns](session-05/03-app-of-apps-and-choosing.md) | the family tree, cascading deletion, ownership, the decision table |
| [Optional reference](session-05/90-reference-generators-and-progressive-syncs.md) | the other six generators, and why Progressive Syncs is not a health gate |

**→ Start:** [Session 5 overview](session-05/README.md)
