# Session 5 · Module 1 — The Factory: ApplicationSets and Generators

> **Day 2 · Session 5 · Module 1 of 3 · ~22 minutes · concept + hands-on**
> **Goal:** understand the factory metaphor, the fan-out and its blast radius, that ApplicationSets do not deploy anything, and the five generators.

---

## 1. Why this matters: forty Applications changed

It is Wednesday. A platform engineer needs to bump the image tag for `storefront`, which runs in every environment. They open the one file that defines all of them — an **ApplicationSet** — and change a single line. They commit and get coffee.

By the time they are back, **forty Applications have changed.** Every environment the ApplicationSet generates picked up the edit at once, and the controller began syncing all of them. Two were mid-incident. One was production.

Nothing malfunctioned. The ApplicationSet did precisely what it is *for*: it took one template and one data source and applied a change uniformly. That is the whole value — **leverage**: one edit moves forty things. It is also the whole danger — **blast radius**: one edit moves forty things. This session is about holding both truths at once.

---

## 2. The mental model: a factory and a family tree

Two patterns, two pictures.

**An ApplicationSet is a factory.** You give it a *template* (the shape of one Application, with blanks) and a *data source* (a list of values to fill the blanks). It stamps out one nearly-identical Application per item. Add an item, a new Application appears with no new writing. Change the template, every copy changes together. A factory is defined by its *inputs* — you *derive* the products.

**App-of-Apps is a family tree.** Someone deliberately wrote out a hierarchy: this **root** Application creates these specific **child** Applications, in roughly this order. There is no "list to fill in" — the list *is* the decision. A family tree is defined by *intent* — each member is *decided*, written by name.

> **The choosing rule, and the entire decision table in one line:** use a **factory when the list is _derived_**; use a **family tree when the list is _decided_.**

Two framings to carry through:
- **ApplicationSet gives you _leverage_** — one change moves many things (power and risk in one gesture).
- **App-of-Apps gives you _legibility_** — a human can read the tree and say exactly what should exist, in what order.

Most teams want **both** — allowed *only with explicit ownership and deletion boundaries* (Module 3).

---

## 3. The fan-out — one edit, multiplied

```text
           ONE TEMPLATE                        ONE DATA SOURCE (generator)
   ┌──────────────────────────┐        ┌───────────────────────────────────────┐
   │ name: storefront-{{.env}} │   ×    │ matrix: 2 clusters × 3 env files       │
   │       -{{.name}}          │        │   → 6 combinations                     │
   └──────────────────────────┘        └───────────────────────────────────────┘
                    │  ApplicationSet controller stamps one Application per combination
                    ▼
   6 Application OBJECTS: storefront-dev-workload-a … storefront-prod-workload-b
════════════════════════════════════════════════════════════════════ everything BELOW
   the SAME application-controller reconciles each Application onto its cluster,    this line
   exactly as it did for one Application in Lab 1. No new deployment mechanism.     is DAY 1
```

**🔍 Two things to notice:**
1. **Blast radius is arithmetic:** `(items in the generator) × (one template edit) = that many simultaneous changes`. Editing one line with a 40-cluster generator is a 40-cluster change — and the *editing experience looks identical* to editing one. That is why **counting** the generated Applications before you edit (Module 2) is a safety practice.
2. **Everything below the line is Day 1.** Once the Application objects exist, each is reconciled by the same application controller, same sync/health axes, same drift behavior. **There is no new deployment path to learn today.**

---

## 4. The one sentence that removes today's fear

> **The ApplicationSet controller creates, updates, and deletes _Application objects_. That is all.**

It never contacts a workload cluster, never renders a chart, never applies a Deployment. The instant a generated Application exists, the Day-1 **application controller** takes over.

So there are only two questions when an ApplicationSet-generated app is wrong:
- **Is the _Application_ wrong?** → the Day-1 application controller's domain (rendering, sync, health).
- **Is the _thing that wrote the Application_ wrong?** → the ApplicationSet controller and its generator.

Keeping those separate is the entire tracing drill of Lab 4. And retrieve one Day-1 lesson: when a generator produces six Applications at once, you see six turn `OutOfSync` — a wall of yellow that looks alarming and is not. **`OutOfSync` does not mean broken.** Read the count, not the color.

---

## 5. The five generators, by the question each answers

| Generator | The question it answers | Data source |
|---|---|---|
| `list` | "Here are the items; I'm telling you." | Hand-written elements |
| `cluster` | "One per cluster Argo CD knows about." | Registered cluster Secrets (by label) |
| `git` | "One per file/folder in this repo." | Files or directories in Git |
| `matrix` | "Every combination of two generators." | Two child generators (cross-product) |
| `merge` | "Combine, and let one override another." | Several child generators (by merge key) |

- **`list`** — you write the items by hand. Small sets you *decide* directly.
- **`cluster`** — reads registered clusters and emits one per matching label. This course labels the workload cluster `cluster-role: workload`; the selector `cluster-role: workload` *excludes* the management cluster, so the app can never be generated onto the Argo CD cluster itself.
- **`git`** — scans a repo, one entry per matching file/directory. Adding an environment is a pull request that adds a folder. The generator that best embodies GitOps.
- **`matrix`** — the cross-product of two child generators ("this app, on every environment, on every workload cluster").
- **`merge`** — overlays generators on a merge key so a later one overrides an earlier one for the same item.

> Current Argo CD also has **SCM Provider**, **Pull Request**, **Cluster Decision Resource**, and **Plugin** generators — they exist, out of scope here. Knowing the five above is enough for Lab 4 and the capstone.

---

## 6. Hands-on: preview an ApplicationSet without creating anything

The antidote to the blast radius is **preview** — rendering what an ApplicationSet *would* produce, creating none of it.

**▶ Predict first:** `examples/appset-list.yaml` has a `list` generator with two elements (`dev`, `staging`) and names each app `example-{{ .env }}`. How many Applications will it print, and what are their names?

**▶ Do this now** (logged into the `argocd` CLI, in your `platform-config` clone):

```bash
argocd appset generate examples/appset-list.yaml -o yaml
```

**Expected output** (two Applications *printed*, none created):

```yaml
- kind: Application
  metadata:
    name: example-dev
  spec:
    project: storefront
    destination:
      namespace: storefront-dev
- kind: Application
  metadata:
    name: example-staging
    # ... namespace: storefront-staging
```

**▶ Confirm nothing was created:**

```bash
argocd app list -o name | grep example    # (no output — nothing exists)
```

**🔍 Notice:** the count equals the number of generator elements, every time; `generate` renders but does not apply. *(Note: `appset generate` validates that the referenced `project` exists — here `storefront`, created in Lab 2. If you see "project storefront does not exist," you are at a pre-Lab-2 checkpoint.)*

---

## 7. Key takeaways

- **An ApplicationSet is a factory; App-of-Apps is a family tree.** Derived list → factory; decided list → family tree.
- **ApplicationSets do not deploy anything** — the controller writes *Application objects*; the Day-1 controller does the rest. Everything below the fan-out line is old news.
- **Blast radius is arithmetic** — one template line × N generator items = N simultaneous changes. Preview before you edit.
- **Five generators**, learned by the question each answers: list, cluster, git, matrix, merge.

**→ Next:** [02 — Safety: failing loud and bounding the blast radius](02-safety-and-controls.md)
