# Lab 2 · Module 3 — Prove Least Privilege, Create the App

> **Day 1 · Lab 2 · Module 3 of 4 · ~20 minutes**
> **Goal:** confirm the identity you built is genuinely restricted (**E3**), then build the governance fence and deployment instruction (**E4**).

---

## E3 — Predict, then prove least privilege

**Difficulty:** Intermediate · **Time:** ~8 minutes · **Objective:** L2.3

**Goal:** confirm the identity is restricted by asking Kubernetes directly: *is `argocd-manager` allowed to do X?* **Predict each answer first**, then check — the value is in predicting.

**The question form** — `kubectl auth can-i` answers "is this identity allowed?", asked *as* the ServiceAccount:

```bash
kubectl --context k3d-workload auth can-i <verb> <resource> -n <namespace> \
  --as=system:serviceaccount:argocd-access:argocd-manager
```

For a **cluster-scoped** check (a resource with no namespace), drop the `-n <namespace>`.

**▶ Do this now — fill the *Predict* column first, then run each check and fill *Actual*.**

| # | Check | Predict | Actual |
|---|---|---|---|
| 1 | Create a `Deployment` in `storefront-dev` | ? | |
| 2 | Create a `Deployment` in `default` (not in scope) | ? | |
| 3 | Create a `NetworkPolicy` in `team-a` | ? | |
| 4 | Delete a `Namespace` (cluster-scoped — no `-n`) | ? | |

**Shape of a correct result:** four `yes`/`no` answers that **match the least-privilege design**. If any surprises you, that is the lesson — re-read which namespaces got which Role, and which verbs the `team-a` Role deliberately omits.

**Hints:**
- *Hint 1:* RoleBindings exist only in specific namespaces; a namespace with no binding grants nothing.
- *Hint 2:* Compare the full `argocd-deployer` Role with the reduced `argocd-deployer-team` Role — one resource kind is present in the first and absent in the second. That difference is row 3.
- *Hint 3:* There is **no** ClusterRoleBinding with write access anywhere. That alone decides row 4.

**Success criterion:** your four observed answers match the design, and you can state in one sentence *why* each `no` is a `no` (missing binding, unlisted namespace, or missing cluster-scoped grant).

> **Name the payoff now, because Lab 5 and the Capstone grade it.** Every `no` above is **Kubernetes** deciding authorization — a `403 Forbidden` the API server returns *after* a request reaches the cluster. That is a different fence from **Argo CD's own** authorization, which refuses an action *before* any sync reaches Kubernetes. The field-usable rule: **if the sync never started, it was Argo CD that said no; if the sync started and then failed, it was Kubernetes.**

---

## E4 — Create the AppProject and Application declaratively

**Difficulty:** Intermediate · **Time:** ~12 minutes · **Objectives:** L2.4, L2.5

**The AppProject is a fence you build before you need it.** It answers three questions in advance: **which repositories** may an Application deploy from (`sourceRepos`), **which destinations** may it deploy to (`destinations`), and **which resource kinds** may it create (`namespaceResourceWhitelist`, plus a deliberately empty `clusterResourceWhitelist`). The **Application** is the deployment instruction: render *this* chart at *this* revision from *this* repo, into *this* destination, under *this* project — with **manual sync on purpose** so Lab 3 can turn automation on deliberately.

**Goal:** complete the `TODO` fields in both skeletons, commit them, apply them, and confirm `storefront-dev` appears **`OutOfSync`** + **`Missing`** — the correct first result.

**Starter state:** `~/platform-config/projects/storefront.yaml` (AppProject) and `~/platform-config/applications/storefront-dev.yaml` (Application), each with `# TODO (Lab 2 E4)` fields whose comments tell you exactly what to fill.

**Where each answer comes from (you still write it):**
- **`sourceRepos`** (project): must match the Application's `repoURL`.
- **`destinations[].server`** (project) and **`destination.server`** (Application): the workload API server URL from E2.
- **`namespaceResourceWhitelist`** (project): the kinds the chart renders (Deployment, Service, ConfigMap, a migration Job, an HPA).
- **`helm.valueFiles`** (Application): the dev values file **relative to the chart path** `charts/storefront` — count the `..` segments to reach `envs/dev/values.yaml`.

**▶ Predict-before-you-apply.** Immediately after `kubectl apply`, before any sync — what will the sync status and health status be?

**Steps:**
1. Complete the `TODO` fields in both files. Do **not** add an `automated:` block — manual sync is intentional.
2. Commit and push (credentials `student` + `~/course/credentials/gitea-student.txt`):
   ```bash
   cd ~/platform-config
   git add projects/storefront.yaml applications/storefront-dev.yaml
   git commit -m "Lab 2 E4: storefront AppProject and dev Application"
   git push
   ```
3. Apply both to the management cluster:
   ```bash
   kubectl --context k3d-mgmt apply -f projects/storefront.yaml
   kubectl --context k3d-mgmt apply -f applications/storefront-dev.yaml
   ```
4. Open the Applications list and the `storefront-dev` tree and diff.

**Shape of a correct result:** the `storefront` AppProject exists with your source repo/destination/kind allow-list (SS-L2-05); `storefront-dev` appears **`OutOfSync`** / **`Missing`** (SS-L2-06); its tree shows every node **`Missing`** (SS-L2-07); the diff shows **desired-only** resources — everything is "new" because nothing is deployed yet (SS-L2-08).

**Hints:**
- *Hint 1:* A relative path from `charts/storefront` to `envs/dev/values.yaml` must climb *out* of `charts/storefront` first — count the `..` segments.
- *Hint 2:* A red **ComparisonError** instead of `OutOfSync` almost always means a wrong `valueFiles` path. Fix, commit, re-apply.
- *Hint 3:* Stuck **Unknown** means the destination `server` does not match a registered cluster — make it byte-for-byte the E2 workload URL.
- *Hint 4:* The `namespaceResourceWhitelist` must include every kind the chart renders, or Lab 3's sync will be blocked by the fence.

**Success criterion:** `argocd app get storefront-dev` shows `Sync Status: OutOfSync` and `Health Status: Missing`, and the diff shows all resources as newly added. Your one-sentence explanation says *why*: Git describes resources not deployed yet, and sync is manual on purpose.

![Argo CD Project storefront detail (v3.5.2)](../../assets/screenshots/day-1/lab-02-05-project-storefront.png)

*Figure SS-L2-05 — The `storefront` AppProject: allowed source repo, allowed destination, empty cluster-resource allow-list.*

![Applications list showing storefront-dev OutOfSync and Missing (v3.5.2)](../../assets/screenshots/day-1/lab-02-06-applications-with-dev.png)

*Figure SS-L2-06 — `storefront-dev` is `OutOfSync` / `Missing` — the correct first result.*

![storefront-dev resource tree showing Missing nodes (v3.5.2)](../../assets/screenshots/day-1/lab-02-07-dev-tree-missing.png)

*Figure SS-L2-07 — Every node is `Missing` because nothing is deployed yet.*

![Diff view for storefront-dev showing desired-only resources (v3.5.2)](../../assets/screenshots/day-1/lab-02-08-dev-diff-all-new.png)

*Figure SS-L2-08 — The diff: all resources are desired-only (new), because live state is empty.*

<!-- CAPTURE-SPEC: SS-L2-05..08 — Project detail, Applications list, storefront-dev tree (all Missing), and diff (all desired-only). State: after E4 apply. Argo CD v3.5.2. -->

**→ Next:** [04 — Diagnose and wrap-up](04-diagnose-and-wrap-up.md)
