# Session 5 · Optional Reference — The Full Generator Catalogue and Progressive Syncs

> **Optional. Outside the Day 2 timebox. Nothing here is required for Lab 4, Lab 5, or the capstone.**
> Read it after the capstone, or when a real project pushes you past the four generators the course uses.
> **← Back to:** [Day 2 map](../README.md) · [Session 5](README.md)

---

## Page TL;DR

- **What this is.** The generators and rollout features that Session 5 deliberately leaves out, gathered in one place.
- **Why it matters.** Real platforms eventually need one of these. Knowing they exist, and what each is *for*, is enough today.
- **What to remember.** The four course generators — List, Cluster, Git files, Matrix — cover most real needs. Reach past them only when the list genuinely comes from somewhere else.
- **The most common mistake.** Adopting Progressive Syncs as a production health gate. It is not one, for reasons below.

---

## 1. Why this material is optional

Session 5 teaches four generators because those four appear in Lab 4 and in the capstone. Everything here is real and supported, and none of it is exercised by this course.

If you are preparing for the capstone, close this page and go to [Lab 4](../lab-04/README.md).

---

## 2. The complete generator catalogue

A **generator** answers one question: *where do the rows come from?* That is the only thing that differs between these.

| Generator | YAML key | Rows come from | Typical use | In this course |
|---|---|---|---|---|
| **List** | `list` | values you type in the ApplicationSet | a small, fixed set | **Session 5 · M1** |
| **Cluster** | `clusters` | registered cluster Secrets matching a label selector | one app per cluster in a fleet | **Lab 4** |
| **Git files** | `git` (`files`) | files matching a glob in a repository | one app per environment folder | **Lab 4** |
| **Git directories** | `git` (`directories`) | directories matching a glob | one app per component folder | no |
| **Matrix** | `matrix` | every combination of two generators | environments × clusters | **Lab 4** |
| **Merge** | `merge` | rows from several generators, joined on a key | a base list with per-item overrides | no |
| **SCM Provider** | `scmProvider` | the repositories in a GitHub/GitLab organisation | onboard every repo in an org | no |
| **Pull Request** | `pullRequest` | open pull requests in a repository | ephemeral preview environments per PR | no |
| **Cluster Decision Resource** | `clusterDecisionResource` | a separate controller's decision about placement | multi-cluster schedulers | no |
| **Plugin** | `plugin` | an HTTP service you write | rows from a CMDB or inventory system | no |

### Notes worth having

**Git directories versus Git files.** `directories` gives you one row per folder and tells you the folder's name. `files` reads the *contents* of matching files, so each row can carry several named values. Lab 4 uses `files` because each environment needs a namespace and a target revision, not just a name.

**Merge needs a join key.** Every generator feeding a merge must produce rows sharing the field named in `mergeKeys`. Rows that do not match on that key are dropped silently, which is a common source of "why is my app missing?"

**Matrix takes exactly two generators.** To combine three, nest a matrix inside a matrix.

**Pull Request generators create and destroy Applications as PRs open and close.** That is a deletion path driven by an external system, so `applicationsSync` and `preserveResourcesOnDeletion` matter more here than anywhere else.

**SCM Provider and Plugin generators reach outside the cluster** and need credentials. Those credentials become part of your blast radius.

### Mini TL;DR — section 2

- Ten generator types exist; they differ only in where rows come from.
- `files` carries named values; `directories` carries only names.
- Generators that talk to external systems add credentials and an external deletion path.

---

## 3. Progressive Syncs

**What it is.** `RollingSync` updates generated Applications in labelled **stages** instead of all at once, so a bad change reaches a few Applications before it reaches all of them.

**Status.** Beta, off by default, and version-dependent. This course does not enable it and the capstone does not use it.

**Two sharp edges you must know before using it:**

1. **`RollingSync` turns automated sync off for every generated Application.** The ApplicationSet controller drives the syncs itself. If you were relying on auto-sync elsewhere in that set, it stops.
2. **A stalled stage can be promoted on a timeout** — by default around 300 seconds — even if the stage never actually became healthy. That means a stage can "pass" without succeeding.

> **Because of edge 2, do not treat Progressive Syncs as a guaranteed production health gate.** It reduces the odds of a simultaneous fleet-wide bad rollout. It does not prove a stage was healthy before moving on.

**What to use instead for real traffic control.** Per-application canary or blue/green traffic shifting is **Argo Rollouts** — a different tool, operating at a different layer. Argo Rollouts manages how traffic moves to new Pods of one application. Progressive Syncs manage the order in which many Applications get updated. They are not substitutes.

### Mini TL;DR — section 3

- Progressive Syncs stage **which Applications** update, not **how traffic shifts**.
- It disables auto-sync on the generated Applications.
- A timeout can promote a stage that never became healthy, so it is not a health gate.

---

## ✅ Key Takeaways

- **The four course generators cover most real needs.** Reach further only when the list truly lives somewhere else.
- **`files` versus `directories` is about how much data each row carries.**
- **Generators that call external systems import their credentials and their failure modes.**
- **Progressive Syncs is a staging mechanism, not a health gate**, and it turns off auto-sync.
- **Argo Rollouts is the answer for traffic shifting**, and it is a separate tool.

---

## Final page TL;DR

- **What this is.** Everything Session 5 left out, in one optional place.
- **Why it matters.** You will meet these in real platforms; you do not need them to pass the capstone.
- **What to remember.** Generators differ only in the source of their rows.
- **The most common mistake.** Trusting Progressive Syncs to prove health. It cannot.

**→ Back to:** [Session 5](README.md) · [Day 2 map](../README.md)
