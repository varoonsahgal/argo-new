# Session 6 · Module 2 — AppProjects and RBAC, Up Close

> **Day 2 · Session 6 · Module 2 of 3 · ~18 minutes · concept + hands-on**
> **Goal:** read the real `storefront` AppProject and RBAC policy as *fences*, understand least privilege and the shared ServiceAccount, and unit-test a policy offline.

---

## 1. Fence 2, up close: the real `storefront` AppProject

Here is the completed `storefront` AppProject (the one your Lab 2 exercise produced). Read it as a **fence**, field by field:

```yaml
kind: AppProject
metadata:
  name: storefront
spec:
  sourceRepos:                                             # (1) allowed Git repos
    - http://lab-gitea:3000/course/storefront-gitops.git
  destinations:                                            # (2) allowed cluster + namespace
    - server: https://k3d-workload-server-0:6443
      namespace: storefront-dev
    - { server: https://k3d-workload-server-0:6443, namespace: storefront-staging }
    - { server: https://k3d-workload-server-0:6443, namespace: storefront-prod }
  clusterResourceWhitelist: []                             # (3) NO cluster-scoped kinds
  namespaceResourceWhitelist:                              # (4) only these namespaced kinds
    - { group: "", kind: ConfigMap }
    - { group: "", kind: Service }
    - { group: apps, kind: Deployment }
    - { group: batch, kind: Job }
    - { group: autoscaling, kind: HorizontalPodAutoscaler }
```

1. **`sourceRepos`** — may deploy **only** from `storefront-gitops`. Any other repo → refused.
2. **`destinations`** — may target **only** the three `storefront-*` namespaces on that one workload cluster. Not `kube-system`, not another team's namespace, not the management cluster.
3. **`clusterResourceWhitelist: []`** — an *empty* list means **no cluster-scoped kinds at all** (no ClusterRoles, CRDs, Namespaces). **Empty means deny-all**, not "unset and permissive."
4. **`namespaceResourceWhitelist`** — even inside its namespaces, may create **only** these five kinds. A `Secret`? Not listed → refused.

**An AppProject is a *positive* list** — it permits exactly what it names and refuses everything else. That is what makes it a fence, not a suggestion.

> **The `default` project is the opposite — and that matters.** Every install ships a `default` AppProject, created **maximally permissive**: `sourceRepos: ['*']`, any destination, all cluster kinds. An Application with no `project` set lands there. A fresh install *has* a project and *no boundary* — a door with a lock painted on it. Hardening step one is to **empty** `default`'s allow-lists (Lab 5).

---

## 2. Fence 1, up close: the real Argo CD RBAC policy

Fence 1 decides *who may ask.* Here is a tenant policy's shape (it lives in `argocd-rbac-cm`):

```csv
p, role:payments, applications, get,      payments/*, allow
p, role:payments, applications, sync,     payments/*, allow
p, role:payments, applications, action/*, payments/*, allow
g, payments-dev, role:payments
```

- A **permission** line is `p, subject, resource, action, object, effect` — e.g. the role `payments` may **get** any app matching `payments/*`.
- A **grant** line is `g, subject, role` — the account `payments-dev` *has* the role `payments`.

**Notice what is *not* here:** no `delete` line. The role can see and sync its own apps and **nothing else** — it cannot delete, and has **no visibility** into another tenant's apps. Fence 1 shapes what a subject may *ask for* before any app or cluster is involved.

Notice the last line's shape: `g, payments-dev, role:payments`. In production this would be `g, payments-devs, role:payments` — an SSO **group** mapped to the role, the IdP deciding membership (Module 3). Here, with no IdP, a **local account** stands in for the group — same line, same behavior. *(The base policy ships empty — `policy.default: ""`, `policy.csv: ""` — so a fresh Argo CD grants nobody anything.)*

---

## 3. Fence 3 and least privilege (a 3-minute recap)

Fence 3 is the workload cluster's own RBAC, guarding the **ServiceAccount** Argo CD writes as (built in Lab 2):

- Argo CD authenticates as `argocd-manager` in namespace `argocd-access`.
- Its permissions are **least privilege**: RoleBindings grant write **only** in `storefront-dev/staging/prod` and `platform-system`, and a *narrower* set in `team-a`. There is **no ClusterRoleBinding** with cluster-wide write.

Two properties auditors ask about:
- **You can restrict *write* freely** — down to named namespaces, groups, kinds.
- **You cannot meaningfully restrict *read*** — `get`/`list`/`watch` at cluster scope are *required* for Argo CD to compute live state and health. **"Least privilege for Argo CD" means least *write* privilege** — say it before your reviewer does.

---

## 4. The uncomfortable truth: every tenant syncs as the *same* ServiceAccount

**Every** Application's sync — `storefront`'s, `team-a`'s, anyone's — runs as the **same** `argocd-manager` ServiceAccount. From the cluster's view there is exactly one client. **Kubernetes literally cannot tell your tenants apart.**

Consequence: **for tenancy, Argo CD is the only fence you have.** Kubernetes RBAC (fence 3) can stop *any* Argo CD write to a forbidden namespace/kind, but it cannot say "this write is `team-a`'s." The thing that keeps `team-a` out of `storefront`'s namespaces is the **AppProject `destinations` list** (fence 2), not Kubernetes. If an auditor asks "how does the cluster know which team deployed this?", the honest answer is "it does not — the AppProject does." *(Argo CD's advanced "sync using impersonation" gives each destination its own ServiceAccount and would change this — a named direction to investigate, not a lab step.)*

---

## 5. Hands-on: unit-test an RBAC policy offline (creates nothing)

You can **test an RBAC policy before anyone deploys it.** `argocd admin settings rbac can` answers "may this subject take this action on this object?" against a policy file, touching no cluster.

**▶ Predict first** (Yes/No for each) against the policy above:
1. May `payments-dev` **sync** `payments/payments-web`?
2. May `payments-dev` **delete** `payments/payments-web`?
3. May `payments-dev` **sync** `storefront/storefront-prod`?
4. May `payments-dev` **get** `payments/payments-web`?

**▶ Do this now:**

```bash
cd /tmp
cat > s6-policy.csv <<'EOF'
p, role:payments, applications, get,      payments/*, allow
p, role:payments, applications, sync,     payments/*, allow
p, role:payments, applications, action/*, payments/*, allow
g, payments-dev, role:payments
EOF
argocd admin settings rbac can payments-dev sync   applications 'payments/payments-web'      --policy-file s6-policy.csv
argocd admin settings rbac can payments-dev delete applications 'payments/payments-web'      --policy-file s6-policy.csv
argocd admin settings rbac can payments-dev sync   applications 'storefront/storefront-prod' --policy-file s6-policy.csv
argocd admin settings rbac can payments-dev get    applications 'payments/payments-web'      --policy-file s6-policy.csv
```

**Expected output** (captured from the course's `argocd` v3.5.2 client):

```text
Yes
No
No
Yes
```

**🔍 What to make of it:**
- **1, 4 → Yes:** the role explicitly allows `sync` and `get` on `payments/*`, and `payments-dev` has the role.
- **2 → No:** there is **no `delete` line**, and Argo CD RBAC denies by default. *The absence of a permission is the permission model working.*
- **3 → No:** `storefront/storefront-prod` does not match `payments/*` — fence 1 stopping a cross-tenant request before any app or cluster is touched.
- Every answer came from a **text file**, no cluster, no risk. That is where an RBAC change belongs — tested in CI. (Clean up: `rm /tmp/s6-policy.csv`.)

> **One flag for the live variant.** The command reads a file, so it needs `--policy-file`. To ask against your *running* Argo CD's policy, swap that for `--namespace argocd`. Argo CD requires **exactly one** of the two (neither fails with `please provide exactly one of --policy-file or --namespace`).

**→ Next:** [03 — SSO, secrets, and governance](03-sso-secrets-and-governance.md)
