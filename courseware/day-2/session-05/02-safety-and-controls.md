# Session 5 · Module 2 — Safety: Failing Loud and Bounding the Blast Radius

> **Day 2 · Session 5 · Module 2 of 3 · ~18 minutes · concept + hands-on**
> **Goal:** keep `project` hard-coded, make missing values fail loudly, bound what the factory may do, and build the preview→count→apply habit.

---

## 1. Keep `project` hard-coded in every ApplicationSet

The template is one Application with `{{ ... }}` blanks (turn Go templating on with `goTemplate: true`). There is exactly **one field you must never templatize**, and it is a security rule:

> ### 🔒 Keep `spec.project` a literal string
>
> An Application's `spec.project` names the **AppProject** (the tenant boundary from Session 6) that decides which repos, clusters, namespaces, and resource kinds it may touch. If you write `project: "{{ .project }}"` and let a generator supply it, then **whoever controls the generator's data source controls which security boundary the generated Applications land in** — a straightforward privilege escalation. Every ApplicationSet in this course keeps `project` a literal (`project: storefront`, `project: platform`). Templatize names, destinations, and value files freely; never templatize `project`.

---

## 2. The dangerous bug is a successful render of the *wrong thing*

The most counterintuitive idea in the session: with Go templating on and **default** settings, a placeholder whose key is *missing* from the generator does **not** error — it renders as an **empty string**. The controller then creates a real Application with an empty field (path `""`, namespace `""`, revision `""`). Nothing errors at generation time; the failure surfaces later, elsewhere, disguised as a sync error or a wrong-namespace deploy.

The fix is to **opt into strictness**:

```yaml
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]   # a missing key is now an ERROR, not ""
```

With this on, a missing key raises a template **error condition** and generates *nothing* for that entry — the other Applications are untouched, and you get a loud, local signal.

> **The safer configuration produces _more_ failures, earlier — and that is the point.** An error at generation is cheap and local; a successfully-generated wrong Application is expensive and remote. Every `examples/*.yaml` here sets `missingkey=error`. It is **not** the default, so any older ApplicationSet in your estate is almost certainly rendering empties silently.

---

## 3. The three controls that bound what the factory may do

Leverage needs a brake. `spec.syncPolicy.applicationsSync` decides what the controller may do to Applications it already made:

| `applicationsSync` value | May **create**? | May **update**? | May **delete**? |
|---|:---:|:---:|:---:|
| `create-only` | ✅ | ❌ | ❌ |
| `create-update` | ✅ | ✅ | ❌ |
| `create-delete` | ✅ | ❌ | ✅ |

- **`create-only`** — make new apps, never modify or delete. Maximum protection; template edits do *not* propagate.
- **`create-update`** — create and update, **never delete**. The common safe production default: template edits flow, but removing a generator item does **not** auto-delete the app (you clean up orphans deliberately).
- **`create-delete`** — create and delete, not modify. Rare.

And a fourth setting on a **different layer** — do not conflate:

- **`preserveResourcesOnDeletion: true`** — when a generated **Application** *is* deleted, leave its **child workload resources running** instead of cleaning them up. The three `applicationsSync` values control the **Application objects**; this controls the **workloads underneath**. Two layers, two switches.

You will set `create-update` + `preserveResourcesOnDeletion: true` in Lab 4, remove a generator item, and watch the app *not* vanish — "safe" here means "deletion is now your deliberate decision, not the factory's reflex."

---

## 4. Preview → count → apply

The antidote to blast radius is **dry-run / preview** — rendering the Applications an ApplicationSet *would* produce without creating any. Three ways, most dependable first:

1. **`argocd appset generate <file>`** — the dependable, portable CLI command (Module 1). Add `-o yaml`/`json`.
2. **`argocd appset create --dry-run <file>`** — server-side evaluation, creates nothing.
3. **The web UI Preview tab** — new on 3.5 but **Alpha**; a "you can also," not what you rely on.

> **The habit that survives a real 40-cluster estate: preview → count → apply.** Before you change a generator or template, render the output and read the generated Application names *out loud*. If you expected three and see thirty, you caught a blast-radius mistake for free.

**▶ Do this now — count a matrix fan-out.** In your `platform-config` clone, generate the matrix example and count how many Applications it produces:

```bash
argocd appset generate examples/appset-matrix.yaml -o yaml | grep -c 'kind: Application'
```

**🔍 Notice:** the count equals *(matching workload clusters) × (env config files)*. In this single-workload-cluster classroom that is `1 × 3 = 3`; a second workload cluster would make it `6`. Read the number *before* you ever apply. *(If you see a "project storefront does not exist" error, you are at a pre-Lab-2 checkpoint — the project is created in Lab 2.)*

---

## 5. Progressive sync — optional, version-dependent, not relied upon

> ### ⚠️ OPTIONAL / VERSION-DEPENDENT — Progressive Syncs (Beta since v3.3.0). No hands-on dependency in this course.
>
> By default, changing an ApplicationSet updates **all** generated Applications at once (`AllAtOnce`). **Progressive Syncs** (`RollingSync`) instead rolls the change out in labeled **stages**, waiting for each stage to become `Healthy` before the next. It is **off by default** and this course never enables it.
>
> Two genuinely surprising facts answer "when *not* to depend on it":
> 1. **`RollingSync` forces auto-sync _off_ on every generated Application** — a large, easy-to-miss side effect.
> 2. **A stalled stage can be promoted to `Healthy` by a _timeout_** (default 300 s), not by actually becoming healthy. That is a rollout convenience, *not* a health gate you can trust for production promotion.
>
> Per-application canary/blue-green with traffic shifting is **Argo Rollouts'** job — a different tool. Do not expect canaries here.

---

## 6. Quick Checks

**S5-QC1 — Missing key, with and without `missingkey=error`.** A git-files generator reads `envs/*/config.yaml`; one file is missing its `namespace:` line; the template has `namespace: "{{ .namespace }}"`. Predict (a) default, (b) with `missingkey=error`.

<details>
<summary>Show answer</summary>

**(a) Default:** the missing key renders as `""`; the controller creates a real Application with `namespace: ""` that looks normal and fails later at *sync* time, far from the cause. **(b) With `missingkey=error`:** a template **error**; no Application is generated for that entry; the valid ones are untouched. The safer setting produces more failures, earlier — on purpose. Remember it is opt-in, not default.
</details>

**S5-QC2 — "We set `create-update`, so deletion is handled."** True or false, and why?

<details>
<summary>Show answer</summary>

**False.** `create-update` only means the factory will not *auto-delete* Applications when their generator entry disappears — those apps become **orphans** (still running, no longer generated) that someone must delete **deliberately**. "Safe" means "deletion is now a human decision," not "deletion is handled for you." Forgetting the orphans is its own incident.
</details>

---

## 7. Key takeaways

- **Keep `project` hard-coded** — a templated `project` is a privilege-escalation path.
- **The dangerous bug is a successful render of the wrong thing** — `goTemplate: true` + `missingkey=error` turns silent empties into loud, local errors. Safer means more failures, earlier, on purpose.
- **Three controls bound the factory** (`create-only`/`create-update`/`create-delete` on the Application objects); `preserveResourcesOnDeletion` governs the workloads underneath. Keep the layers separate.
- **Preview → count → apply** — read the generated count before you edit.

**→ Next:** [03 — App-of-Apps and choosing the pattern](03-app-of-apps-and-choosing.md)
