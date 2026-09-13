# Session 5 · Module 3 — App-of-Apps and Choosing the Pattern

> **Day 2 · Session 5 · Module 3 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** understand the family tree, what deleting a root does, how to choose between the patterns, and how to trace a failure to the layer that wrote it.

---

## 1. App-of-Apps: a deliberate family tree

An **App-of-Apps** is not a special CRD — it is an ordinary Application whose *rendered content is other Application manifests*. The course's real root, `platform-config/root/platform-root.yaml`:

```yaml
kind: Application
metadata:
  name: platform-root
spec:
  project: platform                      # hard-coded, like every project field
  source:
    repoURL: http://lab-gitea:3000/course/platform-config.git
    path: apps                           # ← this directory holds child Application manifests
  destination:
    server: https://kubernetes.default.svc   # the MANAGEMENT cluster's argocd namespace
    namespace: argocd
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

Its `path: apps` points at a directory of child Application manifests. Syncing the root **creates three child Applications** on the management cluster; each child deploys real workloads onto the **workload** cluster:

| Child Application | Source path | Deploys to |
|---|---|---|
| `platform-quotas` | `platform-components/quotas` | `storefront-dev` (workload) |
| `platform-netpol` | `platform-components/network-policies` | `storefront-dev` (workload) |
| `platform-agent` | `platform-components/agent` | `platform-system` (workload) |

That is the family tree: `platform-root` → three named children → their workloads. Nobody *derived* this list; a human *decided* it, wrote it by name, and can read it back. That is when you prefer App-of-Apps. **Ordering** (namespaces before what lives in them) is controlled by **sync-waves** (Session 4), just like any sync.

**▶ Do this now — read the family tree from Git.** In your `platform-config` clone:

```bash
ls apps/
cat root/platform-root.yaml | grep -E 'name:|path:|project:'
```

**🔍 Notice:** the `apps/` directory lists the children by name, and the root's `path: apps` is what makes syncing the root create them. You can read the whole intended tree top to bottom — that legibility is the point.

---

## 2. Deleting a root: everything, or nothing

This is the App-of-Apps counterpart to the three `applicationsSync` controls, and the misconception the course must break:

- **With the `resources-finalizer.argocd.argoproj.io` finalizer on the root**, deleting the root **cascades**: Argo CD removes the child Applications and their workloads before the root object is finally gone (default *foreground* propagation waits for children first, tearing down high sync-waves first).
- **Without the finalizer**, deleting the root removes *only the root object*. All three children keep running, now **orphaned** — no parent, no one reconciling the tree, and a future re-apply may collide with them.

Both outcomes are disasters, in opposite directions, **one quiet annotation apart.** This is why the decision table's last row insists on "explicit ownership and deletion boundaries": *decide, on purpose*, where the finalizer lives — never discover it during an incident.

> **A finalizer** is a small annotation that tells Kubernetes "before you remove this object, let Argo CD clean up what it manages first." With it → cascading deletion propagates down the ownership edges. Without it → only the object is removed and everything it managed is orphaned but still running.

![Argo CD platform-root resource tree with three child Applications (v3.5.2)](../../assets/screenshots/day-2/s05-03-root-app-tree.png)

*Figure SS-S5-03 — The `platform-root` tree: root → `platform-quotas`, `platform-netpol`, `platform-agent`. A cascading delete would follow these same edges downward.*

<!-- CAPTURE-SPEC: SS-S5-03 — platform-root App-of-Apps tree. State: CP-lab-05. Highlight: platform-root node and its three child Application nodes with Synced/Healthy badges. Argo CD v3.5.2. -->

---

## 3. Why multiple roots become hard to reason about

Suppose two roots each generate a child managing the *same* namespace or resource. Now two owners both believe they are responsible. Each enforces its own view; the resource **flaps**; and — the nasty part — **both roots report `Synced` and `Healthy`.** It is the GitOps equivalent of two `terraform apply` runs against one state file. The rule that prevents it: **ownership must be a partition, not an overlap** — every resource has exactly one owner in the tree.

---

## 4. Choosing the pattern (the outline's decision table)

| Need | Prefer |
|---|---|
| Generate similar Applications from cluster or Git data | ApplicationSet |
| Bootstrap a known hierarchy of platform components | App-of-Apps |
| Manage many clusters or environments without duplication | ApplicationSet |
| Preserve a deliberate parent-child bootstrap structure | App-of-Apps |
| Combine both patterns | Only with explicit ownership and deletion boundaries |

**Every row is "derived or decided?" in disguise.** Rows 1 and 3 are *derived* lists → factory. Rows 2 and 4 are *decided* hierarchies → family tree. The last row is a **condition, not a recommendation**: combining is allowed *only* with explicit ownership and deletion boundaries.

---

## 5. Tracing a failure: root → repo → child

Because both patterns *write Applications*, a generated app that is wrong is fixed by finding *the layer that wrote it*, not by editing the app directly:

```text
  a failing resource
        ▲
        │ 1. which CHILD Application manages it?           (argocd app get <child>)
        │ 2. what does that child's SPEC say is wrong?      (path? namespace? revision?)
        │ 3. who WROTE that spec — a person, a root, or     (ownerReferences / the tree)
        │    an ApplicationSet?
        │ 4. which FILE in Git produced it?                 (root's path/apps, or the AppSet)
        ▼
  fix the SOURCE in Git, let reconciliation carry it down
```

**The tell that you fixed the wrong layer: your edit reverts.** If you hand-edit a generated child and something above it puts it back, you found the owner — now go fix *there*, in Git. "If your fix reverted, you fixed the wrong layer" is the whole lesson.

---

## 6. Quick Checks

**S5-QC3 — Apply the decision table.** For each, choose ApplicationSet or App-of-Apps and say why in "derived or decided?" terms: (1) deploy the same agent to **every** workload cluster, now and as new ones are added; (2) bootstrap a new cluster with a **known, ordered** set of components; (3) let teams add an environment by **adding a folder**.

<details>
<summary>Show answer</summary>

1. **ApplicationSet** (cluster generator) — the list is **derived** from the fleet. 2. **App-of-Apps** — the list is **decided**, a specific ordered hierarchy. 3. **ApplicationSet** (git generator) — the list is **derived** from Git; adding a folder adds an app with no AppSet change. Every row reduces to "who or what decides the list?"
</details>

**S5-QC4 — Delete a root with cascade.** `platform-root` (with the finalizer) owns three children managing a ResourceQuota, a NetworkPolicy, and a Deployment. You delete it **with cascade**. What is removed, and what would happen **without** the finalizer?

<details>
<summary>Show answer</summary>

**With cascade:** everything in the tree — the delete propagates to the three child Application objects and their workloads (higher sync-waves first), and the root object is removed last. **Without the finalizer:** only the root object is removed; all three children and their workloads keep running, **orphaned**, and a later re-apply can collide with the survivors. "Delete the root" is never small, and the outcome flips on one annotation.
</details>

---

## 7. Common misconceptions

- **"A root's `Healthy` means its children are healthy."** No — a parent Application's health does not roll up child *Application* health by default. A root can be `Healthy` above a `Degraded` child. Check children directly.
- **"`create-update` is always safe, so I can stop worrying about deletion."** It only stops *auto-delete*; removed apps become **orphans** you must delete deliberately.
- **"The UI Preview tab is the stable way to preview."** It is **Alpha since v3.5.0**; the portable path is `argocd appset generate`.
- **"We set `applicationsSync: create-update`, so our App-of-Apps tree is protected from cascading deletion too."** Different mechanisms, different objects: `applicationsSync` guards Applications an **ApplicationSet** generated; cascading deletion of an App-of-Apps tree is decided by the **finalizer** on the root. Ask the two questions separately.
- **"ApplicationSets are advanced; App-of-Apps is for beginners."** Neither — **ApplicationSet = leverage** (derived list), **App-of-Apps = legibility** (decided hierarchy). Ask whether the list is derived or decided.

---

## 8. Key takeaways

- **App-of-Apps is a family tree** — a root Application whose content is child Application manifests; the list is *decided*, not derived.
- **Deleting a root deletes everything or nothing** — the `resources-finalizer` annotation decides which, quietly. Ownership must be a partition, not an overlap.
- **The decision table reduces to "derived → factory, decided → family tree."**
- **Trace failures root → repo → child, and fix in Git** — if your fix reverted, you fixed the wrong layer.

---

## Transition — to Lab 4

You now have both mental models and the vocabulary. **[Lab 4 — Build and Troubleshoot the Patterns](../lab-04-build-and-troubleshoot-patterns.md)** makes them muscle memory: you will complete the real `storefront` ApplicationSet (a **matrix** of the cluster and git-files generators) and run **preview → count → apply**; set `create-update` + `preserveResourcesOnDeletion: true` and watch an app *not* vanish; trigger a missing-key failure and see `missingkey=error` refuse it loudly; and trace a broken child back through its root to the file in Git. Bring the "derived or decided?" question and the "preview before you apply" habit.

**→ Next:** [Lab 4 — Build and Troubleshoot the Patterns](../lab-04-build-and-troubleshoot-patterns.md)
