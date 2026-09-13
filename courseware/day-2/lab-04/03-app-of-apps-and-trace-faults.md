# Lab 4 · Module 3 — App-of-Apps and Tracing Faults

> **Day 2 · Lab 4 · Module 3 of 4 · ~24 minutes**
> **Goal:** apply the App-of-Apps root and read ownership top-down (**E4**); then break the factory and the tree, and trace each fault to the layer that owns it (**E5**).

---

## Exercise 4 — Inspect the App-of-Apps hierarchy (L4.4) · ~10 min · Core

**Goal:** apply the App-of-Apps **root** and watch it bring three **child** Applications into being; then trace each child back to the repo and path it deploys from.

**Starter state.** `root/platform-root.yaml` and `apps/*.yaml` are staged, in the `platform` project. Nothing applied yet.

> **▶ Predict first.** How many child Applications will `platform-root` create, and **what determines that number**? The count is not in the root manifest — it is decided by the files under the root's `source.path` (`apps/`), one child per Application manifest. The root does not *list* its children; it *points at a folder* and adopts whatever is inside.

**Do this — apply the root:**

```bash
cd ~/platform-config
kubectl --context k3d-mgmt apply -f root/platform-root.yaml
argocd app get platform-root
```

**Expected shape:** `platform-root` is `Synced`/`Healthy`, and its resources include three `Application` objects — `platform-quotas`, `platform-netpol`, `platform-agent`.

![platform-root tree owning three child Applications (v3.5.2)](../../assets/screenshots/day-2/lab-04-08-root-child-tree.png)

*Figure SS-L4-08 — `platform-root` owning `platform-quotas`, `platform-netpol`, `platform-agent` — the family tree made real.*

**🔍 Notice:** the root's tree contains *Application* objects, not Deployments — the root deploys **children**, and each child deploys the actual workload. Each child has its own sync/health, independent of the root. Deleting `platform-root` **with cascade** would delete all three children (and their workloads).

<!-- CAPTURE-SPEC: SS-L4-08 — platform-root tree. State: after E4 apply. Highlight: root → three child Application nodes. Argo CD v3.5.2. -->

**▶ Trace each child to its source:**

```bash
for c in platform-quotas platform-netpol platform-agent; do
  echo "== $c =="
  argocd app get "$c" -o json | grep -E '"repoURL"|"path"|"namespace"'
done
```

**What a correct result looks like:** all three children source from the `platform-components` repository, each from a different path (`quotas`, `network-policies`, `agent`), deploying to the workload cluster. You can now name, for any child, the exact repo and path a fix would live in.

**Success criterion:** `argocd app get platform-root` shows the root `Synced`/`Healthy` with three children; you can write each child's **owning repo + path** without opening the UI.

**Hints:**
- *Hint 1:* The root's `path` is a *folder*; every `Application` manifest in it becomes a child. Read `apps/platform-quotas.yaml` for a child's own `source`.
- *Hint 2:* If no children appear, the root may be `OutOfSync`/unsynced — check `argocd app get platform-root`, and confirm the `platform` project permits the `argoproj.io/Application` kind in `argocd`.

---

## Exercise 5 — Break it, then trace each fault to the owning layer (L4.5) · ~14 min · Core (diagnosis)

The lab's centrepiece: two faults — one in the factory, one under the family tree. For each, find *the layer that owns it* before changing anything. **If a fix reverts, you fixed the wrong layer.**

Fill this trace table as you go:

| Part | Symptom (what/where) | Owning object | Owning repo + file | Fix you made |
|---|---|---|---|---|
| A | | | | |
| B | | | | |

### Part A — a missing template key (the factory refuses to generate)

**Do this.** In `storefront-gitops`, remove the `namespace:` line from `envs/staging/config.yaml`, commit, push. The template still references `.namespace`, and the ApplicationSet is strict.

> **▶ Predict first.** With `missingkey=error` set, does the ApplicationSet generate a broken staging app, or refuse and report an error? And what happens to the already-generated dev and prod apps?

**What a correct result looks like.** The ApplicationSet reports an **error condition** (`ErrorOccurred`) — "map has no entry for key namespace" — and generates **zero** Applications *for that reconcile*. The existing `storefront-dev-workload` and `storefront-prod-workload` are **untouched** — the factory failed *safe*.

```bash
kubectl --context k3d-mgmt -n argocd get applicationset storefront \
  -o jsonpath='{.status.conditions}' | tr ',' '\n' | grep -iE 'error|message'
```

![ApplicationSet ErrorOccurred condition citing the missing key (v3.5.2)](../../assets/screenshots/day-2/lab-04-07-appset-error-condition.png)

*Figure SS-L4-07 — the error lives on the **ApplicationSet**, not on any generated Application. **Alpha UI.***

<!-- CAPTURE-SPEC: SS-L4-07 — ApplicationSet error condition. State: after E5A push. Highlight: ErrorOccurred + missing-key message; generated apps unchanged. Argo CD v3.5.2 (Alpha UI). -->

**▶ Optional (~3 min) — feel why strict is safer by turning it off.** While staging's `namespace` is still removed, temporarily delete the `goTemplateOptions: ["missingkey=error"]` line in your local `applicationsets/storefront.yaml`, then preview (no commit, no apply):

```bash
argocd appset generate applicationsets/storefront.yaml -o wide
```

This time there is **no error** — the ApplicationSet cheerfully renders a `storefront-staging-workload` whose namespace is **empty** (`<no value>` in `-o yaml`) and looks normal in a list; it would fail later, elsewhere, in disguise. Restore strictness and re-preview to watch the loud refusal return:

```bash
git checkout -- applicationsets/storefront.yaml
argocd appset generate applicationsets/storefront.yaml -o wide
```

**🔍** One line changed, two behaviours. The safer configuration **failed more, sooner, louder — and that is why it is safer.** Which would you rather be handed at 4 p.m. on a Friday?

**Trace it and fix it.** Symptom on the *ApplicationSet* → owner is the *template + generator input* → file `envs/staging/config.yaml` in `storefront-gitops`. Restore the `namespace:` line, commit, push. The error clears and all three generate again.

### Part B — a broken child path (the child breaks, the root looks fine)

**Do this.** In `platform-config`, break the `platform-quotas` child: edit `apps/platform-quotas.yaml` and change its `source.path` from `quotas` to something wrong (e.g. `quotas-typo`), commit, push.

> **▶ Predict first.** After this pushes, will `platform-root` be `Healthy` or `Degraded`? And `platform-quotas`? Two different questions one level apart.

**What a correct result looks like.** `platform-quotas` shows a **ComparisonError** (the repo-server cannot render a nonexistent path). But `platform-root` may still report **`Synced`/`Healthy`** — the root's job was only to *apply the child Application object*, and it did. **Root health does not roll up child health.** A green root over a broken child.

![platform-root Healthy while platform-quotas shows a ComparisonError (v3.5.2)](../../assets/screenshots/day-2/lab-04-09-child-broken-root-fine.png)

*Figure SS-L4-09 — root health answers "did I apply the child object?", not "is the child healthy?".*

**🔍 Notice:** the child's error is a **ComparisonError** — a *rendering* failure at the repo-server (same class as Lab 3). The root's status did not change. Editing the child object directly (`kubectl edit`) would revert — the root owns that spec via the file in `apps/`.

<!-- CAPTURE-SPEC: SS-L4-09 — child broken, root fine. State: after E5B push. Highlight: platform-quotas ComparisonError vs platform-root Synced/Healthy. Argo CD v3.5.2. -->

**Trace it and fix it.** Symptom on the *child* → but the child's spec is **owned by the root**, written from `apps/platform-quotas.yaml` in `platform-config` → the fix goes in that file, not the live child. Restore `source.path` to `quotas`, commit, push. Confirm the child returns to `Synced`/`Healthy`.

**Success criterion:** both parts of the trace table are filled, and for each you can name the owning object *and* the file that fixes it; after both fixes, `appset generate` prints three rows with no error condition, and `platform-quotas` is `Synced`/`Healthy`. Rule in your words: **fix the layer that owns the field, not the layer where the symptom appeared.**

**Hints:**
- *Hint 1 (A):* An ApplicationSet's health lives on the `ApplicationSet` object's `status.conditions`, not the Applications list.
- *Hint 2 (B):* Do not trust the root's colour. Open the child and read *its* condition; ask "who wrote this child's `path`?"
- *Hint 3:* If a fix seems not to take, confirm you pushed a **new** commit.

**→ Next:** [04 — Pattern showdown and wrap-up](04-showdown-and-wrap-up.md)
