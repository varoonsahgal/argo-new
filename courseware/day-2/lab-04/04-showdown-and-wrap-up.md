# Lab 4 · Module 4 — Pattern Showdown and Wrap-Up

> **Day 2 · Lab 4 · Module 4 of 4 · ~10 minutes**
> **Goal:** derive the decision table from operations by comparing one task under each pattern (**E6**), then confirm your checkpoint.

> **🗺️ Where this module fits.** You have now used both patterns and broken both. This last exercise has no commands: you compare how the *same* job would go under each pattern, so you can explain *when* to pick which — with reasons from what you just did, not from taste.

---

## Exercise 6 — Pattern Showdown: retire an environment (L4.6) · ~10 min · Synthesis

> **🧭 What this exercise is for**
> - **In plain words:** you take one real task — "retire the staging environment" — and write down how it would go with the factory and with the family tree: which files change, who can review it, what could go wrong, and what gets deleted.
> - **Think of it like:** comparing a stamp and a handwritten note. A stamp makes many identical copies fast — and repeats any mistake many times. A handwritten note is slower but you can read exactly what it says.
> - **Connects to:** [Session 5 · Module 3](../session-05/03-app-of-apps-and-choosing.md) — the decision table and its one-line rule: *derived list → factory; decided list → family tree.*
> - **Big picture:** real platforms use both patterns. Knowing the trade-offs lets you defend a choice in a design review or an incident review.

**Goal:** take one concrete task — **"retire the staging environment"** — and work out, on paper, how it plays out under **each** pattern. There is no winner; the point is to *derive* the decision table from operations, not pick a favourite.

**The scenario.** Staging is being decommissioned. Compare: (1) as an entry in the **storefront ApplicationSet** (remove staging's `config.yaml` from the Git-files input), versus (2) as a hypothetical **App-of-Apps** where each environment is a hand-written child (delete `apps/storefront-staging.yaml`).

**▶ Fill in this grid yourself:**

| Operational question | ApplicationSet (remove the input) | App-of-Apps (delete the child) |
|---|---|---|
| **Files touched** | | |
| **Who reviews it**, and can they tell what it will do? | | |
| **Blast radius** — what else could this move? | | |
| **Deletion behavior** — what happens to staging's Application and workload? | | |
| **Preview capability** — can you see the effect before applying? | | |
| **Cost of one typo** — worst case of one mistyped character? | | |

**What a correct result looks like.** A grid where the *trade-offs* are explicit — e.g. the ApplicationSet change is one line but its deletion behavior depends entirely on `applicationsSync` (Exercise 3), while the App-of-Apps change is a visible file deletion whose cascade depends on the child's finalizer. Your grid should answer the outline's question — *when would you prefer each?* — with reasons, not taste.

**Success criterion:** every cell is filled with a concrete answer tied to something you did in E1–E5, and you can state one situation where you would prefer each pattern, defended on operations.

**Hints:**
- *Hint 1:* The "deletion behavior" row is where Exercise 3 pays off — recall what `create-update` does when an input disappears.
- *Hint 2:* The "preview" row — one pattern has `argocd appset generate`; what is the equivalent for a hand-deleted child?
- *Hint 3:* "Cost of one typo" forces blast radius *and* deletion semantics together — a typo in a factory input is multiplied by the generator; a typo in a hand-written child is not, but the two delete very differently.

### ✅ What you should take away from E6

- **Neither pattern is "better".** Each is cheaper for some jobs and riskier for others.
- **The factory gives you leverage** (one change, many apps, a preview command) and **multiplies mistakes.**
- **The family tree gives you legibility** (every child is a file a person can read) and **needs more hand-written files.**
- **Deletion works differently in each.** For the factory, `applicationsSync` decides whether the Application is deleted, and `preserveResourcesOnDeletion` decides whether its workload goes with it. For the tree, the root's `prune` decides whether the child Application is deleted, and the child's own finalizer decides whether its workload goes with it. (E4 showed the course's children have none.)

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `appset generate` errors: *"map has no entry for key …"* | `missingkey=error` caught a template variable the generator doesn't expose — the strict setting **working** | Correct the variable name against the `config.yaml` keys / cluster generator, or restore the missing key |
| Preview succeeds, but a field (for example `NAMESPACE`) reads `<no value>` | The ApplicationSet is **not** strict, so a missing key rendered as text instead of failing | Add `goTemplate: true` + `goTemplateOptions: ["missingkey=error"]` (the skeleton sets these — don't remove) |
| You "fixed" a generated/child app with `kubectl edit` and it reverted | You edited the *wrong layer* — something above owns that field | **If your fix reverts, you fixed the wrong layer.** Change the owning file in Git and push |
| `platform-root` is `Healthy` but a workload is broken | Root health answers "did I apply the child *object*?", not "is the child healthy?" | Open the **child** directly and read *its* status. Never diagnose App-of-Apps from the root alone |
| You removed a generator input and the app **vanished** | `applicationsSync` permits deletion (default `sync` can delete) | Set `applicationsSync: create-update` **before** changing inputs |
| Preview shows more apps than expected | Selector/glob matches more than intended — a blast-radius surprise caught for free | Do **not** apply; narrow until preview matches your prediction |
| Preview prints only the header row (zero Applications), with no error | The cluster selector matches no cluster — for example, the skeleton's `cluster-role: "TODO"` is still there | Set the selector to the label value you read in Module 1; re-preview and count |
| Preview rows show `TODO` (for example, three rows all named `argocd/TODO`) | The selector works, but other skeleton TODOs are unfilled | Finish every TODO; re-preview until no `TODO` appears in any column |

> **Why `project` is hard-coded and never templated.** If a generator input could choose the project, anyone who can edit that input could move an Application into a more-privileged project — a privilege-escalation path. Keep `project: storefront` fixed. Governance-level protection is Lab 5's subject.

---

## Checkpoint / validation

Met when **all** are true (self-checkable):

**9.1 — The three generated Applications are healthy.**

```bash
argocd app list -o wide | grep 'argocd/storefront-'
```

The pattern includes `argocd/` on purpose. A plain `grep storefront-` also matches `platform-netpol` and `platform-quotas`, whose `NAMESPACE` column is `storefront-dev`.

**Expected output** *(middle columns trimmed to `...`)*:

```text
argocd/storefront-dev-workload      https://k3d-workload-server-0:6443  storefront-dev      storefront  Synced   Healthy  Auto-Prune  ...  main
argocd/storefront-prod-workload     https://k3d-workload-server-0:6443  storefront-prod     storefront  Synced   Healthy  Auto-Prune  ...  storefront-1.0.0
argocd/storefront-staging-workload  https://k3d-workload-server-0:6443  storefront-staging  storefront  Synced   Healthy  Auto-Prune  ...  main
```

All three `Synced`/`Healthy`, and **prod (and only prod)** on `storefront-1.0.0`.

**9.2 — The root tree is traced.** `argocd app get platform-root` shows the root `Synced`/`Healthy` owning the three children, and you can name each child's owning repo and path.

**9.3 — The E5 trace table is complete.** Both rows filled; for each fault you can name the **owning object** and the **file that fixes it**, and explain why editing the live object would have reverted.

> **You have now used five of the six troubleshooting-method steps** — validated the Git source, validated rendering, compared rendered vs live, inspected sync results/events, and (new here) **inspected the responsible component** (you read the ApplicationSet's own conditions). Session 7 formalizes the method and adds the sixth step.

---

## ✅ Key takeaways

**From this module (E6):**

- **Pick the pattern by asking "is this list derived or decided?"** Derived from data (clusters, folders) → ApplicationSet. Decided by a person (a known set of components) → App-of-Apps.
- **Judge each pattern on operations:** files touched, reviewability, blast radius, deletion behaviour, preview, and the cost of one typo.

**From the whole of Lab 4:**

- **Preview before you apply.** `argocd appset generate` costs seconds; an unplanned rollout costs an afternoon. Preview → count → apply.
- **Predict the count *and* the names.** The count catches "wrong number"; the names catch template bugs.
- **Zero is a valid generator output — and where deletion is allowed, zero means delete them all.** `create-update` turns a fleet-wide auto-delete into a deliberate decision.
- **The dangerous bug is a successful render of the wrong thing.** `missingkey=error` turns a silent empty value into a loud, local error. Safer means more failures, sooner, on purpose.
- **A green root can sit over a broken child.** Root health answers "did I apply the child object?", not "is the child working?"
- **Fix the layer that owns the field.** If your fix reverts, you fixed the wrong layer.
- **`project` is never templated** — the tenant boundary must not be selectable by generator data.

---

## Optional stretch challenges (outside the timebox)

1. **Make the root reflect child failure (custom health).** By default Argo CD does not assess the health of an `argoproj.io/Application` inside another Application. That is one reason the broken child did not turn the root red in E5B. Add a custom Lua health check for that kind through `resource.customizations` (a values file applied with `apply-argocd-config.sh <your-file>`). Then run `argocd app get platform-root --hard-refresh` until the children show a value in the root's `HEALTH` column. Now compare **two different child failures**, predicting the root's health before each:
   - **(a)** Re-run E5B: a child that **cannot render** (`ComparisonError`). Look at the child's *health* as well as its sync status.
   - **(b)** A child whose **Pods cannot start**. In a clone of `platform-components` (no earlier step clones it, so run `cd ~ && git clone http://lab-gitea:3000/course/platform-components.git` first), change the image tag in `agent/deployment.yaml` to one that does not exist, commit, and push.

   Two sentences on what the root's health *can* and *cannot* tell you, and on the trade-off: a root that rolls up child health is easier to alert on, but hides *which* layer owns a fault. **Clean up:** revert both commits, and re-run `apply-argocd-config.sh` without your file to remove the check.
2. **Add a merge generator.** Extend the ApplicationSet with a **merge** generator so a per-environment override (e.g. prod `replicaCount`) layers onto the matrix. Preview only — do not apply. *Hint:* strict templating still applies. A key that only prod has (`replicaCount`) fails with `map has no entry for key "replicaCount"` for dev and staging if the template uses it directly. Find a way to add that setting only where the key exists.
3. **The name collision — does the preview catch everything?** Write a *separate* ApplicationSet (for example `collision-test`, with no `automated` sync policy so nothing can deploy) whose template name ignores the environment, such as `collision-test-{{ .name }}`. All three rows now render the **same** `metadata.name`.
   - **Predict, then preview:** does `argocd appset generate` warn you?
   - **Predict, then apply it:** one Application whose spec keeps being rewritten? Three? None? Read the new ApplicationSet's conditions and count its Applications.
   - Write two sentences on what this says about *where* each check happens (the preview vs the controller).
   - **Clean up:** `kubectl --context k3d-mgmt -n argocd delete applicationset collision-test`.

---

## Transition — what's next

You built both Day 2 patterns, protected one against accidental deletion, and traced two faults to their owning layers. Notice what protected you each time: a *guardrail* — `missingkey=error`, `applicationsSync: create-update`, a hard-coded `project`. Every one answered "what is this factory *allowed* to do?"

**The big picture so far:** Day 1 taught one Application at a time. Lab 4 showed two ways to manage *many* — and that every one of them is still an ordinary Application underneath. More apps means more risk, so the next step is rules about who may do what.

That question is where Day 2 goes next. **[Session 6 — Security, Multi-Tenancy, and Governance](../06-security-multitenancy-governance.md)** makes the boundaries explicit: AppProjects as fences, Argo CD RBAC vs Kubernetes RBAC, and who is permitted to cause a deletion at all. Then **[Lab 5 — Enforce Platform Guardrails](../lab-05-enforce-platform-guardrails.md)** has you fence in a team and *feel* each denial land in the layer you predicted.

> **Note on reset:** your instructor may run `reset-lab.sh CP-lab-05 --local` between this lab and Lab 5. That checkpoint carries your completed, protected `storefront` ApplicationSet and healthy `platform-root` tree forward.
