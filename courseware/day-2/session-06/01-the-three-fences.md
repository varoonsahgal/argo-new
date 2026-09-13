# Session 6 · Module 1 — The Three Fences

> **Day 2 · Session 6 · Module 1 of 3 · ~15 minutes · concept**
> **Goal:** learn the three fences a request passes through, the one question that tells you which fence refused a request, and each fence's error signature.

---

## 1. Why this matters: the deleted production app

A `storefront` developer's CI pipeline was given an Argo CD **API token** months ago. It has worked fine; nobody has looked at it. On a Tuesday, a cleanup step meant to remove a *stale test* Application hits a typo that turns the target into `storefront-prod`. The pipeline calls Argo CD; Argo CD checks the token, finds it *is allowed to delete Applications*, and **deletes the production Application.** Cascading deletion follows the finalizer down the tree, and production is torn off the cluster.

Nothing malfunctioned. Every component did what it was told. The failure was pure **governance**, with a precise anatomy:
- The token was granted **more than it needed** — it could delete, when it only ever needed to sync.
- Nobody could easily answer **"what can this token do?"**
- There was **no fence** stopping a `storefront` credential from touching production, and **no deployment window** stopping a destructive change during business hours.

Every one of those is a control this session teaches.

---

## 2. Three fences a request passes through

Picture a request — "sync `storefront-prod`" — walking toward the cluster. It must pass **three separate fences**, each guarded by a **different system answering a different question**:

1. **Argo CD RBAC — "Are *you* allowed to ask?"** Argo CD's own permission layer. It looks at *who* is asking (user, group, token) and *what verb* they want (get, sync, override, delete). If it says no, **no sync ever starts.** The receptionist checking your badge before you can press any button.

2. **The AppProject — "Is *this app* allowed to point there?"** A boundary attached to the Application, not the person. It restricts *which repositories*, *which cluster/namespace destinations*, and *which resource kinds*. Even a full administrator's request is refused here if the app points somewhere its project forbids. A fence around *which building the app may enter*.

3. **Kubernetes RBAC — "Is the *cluster credential* allowed to do it?"** Once Argo CD decides to act, it uses a **ServiceAccount** on the workload cluster to write. The cluster's own permission system checks it. If *it* says no, the sync **started** and then **failed** partway through with a `forbidden` error. The lock on the specific room.

> **The single most useful consequence, worth memorizing:** **If the sync never started, it is Argo CD (fence 1 or 2). If the sync started and then failed, it is Kubernetes (fence 3).**

Two fences live inside Argo CD (RBAC and the AppProject); one lives on the cluster (Kubernetes RBAC). They are configured by different teams, fail with different error text — and, the trap, **all show up as roughly the same red badge.** The skill is reading *past* the badge to the fence.

---

## 3. The three fences, and how each one fails

```text
                    Argo CD                              Workload cluster
 REQUEST   FENCE 1              FENCE 2                    FENCE 3
 "sync   ┌─────────────┐   ┌───────────────┐          ┌────────────────┐
 store-  │ Argo CD RBAC│   │  AppProject   │   sync    │ Kubernetes RBAC│
 front-  │ Are YOU     │─► │ May this APP  │─► op ────►│ May the cluster│
 prod"   │ allowed to  │   │ point THERE?  │   starts  │ CREDENTIAL do  │
   ────► │ ask?        │   │ (repo/dest/   │          │ it? (the SA)   │
         └──────┬──────┘   └───────┬───────┘          └───────┬────────┘
                │ DENY             │ DENY                     │ DENY
                ▼                  ▼                          ▼
       "permission denied"  InvalidSpecError:          "forbidden: User
       (terse to you; detail "...do not match any of    ...argocd-manager
        in argocd-server log) the allowed destinations   cannot create..."
       ── NOTHING APPLIED ──  in project '...'"          ── SYNC STARTED,
                             ── NOTHING APPLIED ──          THEN FAILED ──
       Owned by: policy.csv  Owned by: AppProject YAML  Owned by: cluster Roles
```

**The one question:** *did a sync operation run?* No operation → inside Argo CD (fence 1: a person/verb it disallows; fence 2: an app pointing where its project forbids). An operation that started and failed with `forbidden` → fence 3.

> **One refinement so the question never misleads you.** A fence-2 refusal usually produces no operation — Argo CD marks the app with an `InvalidSpecError` condition and stops. But if someone *presses Sync anyway*, an operation **is** recorded and ends instantly with `Phase: Error`, `Duration: 0s`, and **no resource result rows**. So the sharper form is: *did anything on the cluster actually get touched?* Fences 1 and 2 touch nothing; fence 3 is where Argo CD genuinely started applying and the cluster pushed back.

**Who owns the field decides where the fix goes** — fence 1 → `policy.csv`; fence 2 → the AppProject; fence 3 → the cluster's Roles. The error message is a routing slip to a team.

---

## 4. Two failures that look identical, told apart in one step

*(Illustration using a **hypothetical** `payments` tenant — no such project/namespace exists in your lab. What transfers is the *shape*.)*

The setup is a common **asymmetry**: the `payments` AppProject **permits** the `NetworkPolicy` kind, while the workload cluster's least-privilege ServiceAccount was **never granted** permission to create NetworkPolicies there.

**Case A — a fence-2 (AppProject) denial.** An engineer points a `payments` app at `platform-system`, not in the project's `destinations`. Refused *before any sync runs*, recorded as a **condition**:

```text
CONDITION         MESSAGE
InvalidSpecError  application destination server '...' and namespace 'platform-system'
                  do not match any of the allowed destinations in project 'payments'
```

Condition **type** `InvalidSpecError`; searchable phrase **"do not match any of the allowed destinations in project"**. No operation started. Fix lives in the **AppProject**.

**Case B — a fence-3 (Kubernetes) denial.** A *permitted* app tries to sync a NetworkPolicy. The project allows the kind, so Argo CD **starts the sync**; the cluster's API server refuses the write, and `forbidden` appears **inside the sync result**:

```text
networkpolicies.networking.k8s.io is forbidden: User
"system:serviceaccount:argocd-access:argocd-manager" cannot create resource
"networkpolicies" in API group "networking.k8s.io" in the namespace "payments"
```

A sync **ran** and **failed**. Fix lives on the **workload cluster** (a Role/RoleBinding), not in Argo CD.

Same red badge. Opposite systems, owners, fixes. The question "*did anything on the cluster actually get touched?*" separated them in one step. Read for the **signature** (subject+verb; `InvalidSpecError`/"do not match any allowed destinations"; "forbidden … serviceaccount"), never a character-for-character match — wording shifts between versions.

---

## 5. Quick Check

**S6-QC1 — Name the fence that denied each request.** For each, which fence (Argo CD RBAC / AppProject / Kubernetes RBAC), and the one piece of evidence?

1. Log line: `permission denied: applications, get, payments/payments-web, sub: dana, iat: ...`
2. Condition `InvalidSpecError`: `... do not match any of the allowed destinations in project 'payments'`
3. `networkpolicies... is forbidden: User "system:serviceaccount:argocd-access:argocd-manager" cannot create...`

<details>
<summary>Show answer</summary>

1. **Argo CD RBAC (fence 1)** — a **subject** (`sub: dana`) and **verb** (`get`); the user may see only `permission denied` while the detail lives in the `argocd-server` log. Nothing applied. Fix: `policy.csv`.
2. **AppProject (fence 2)** — `InvalidSpecError` + "do not match any of the allowed destinations in project." No operation ran. Fix: the AppProject YAML.
3. **Kubernetes RBAC (fence 3)** — `forbidden` naming the **ServiceAccount**; the sync **started and failed**. Fix: the workload cluster's Roles. The routing question is *did anything on the cluster get touched?*
</details>

---

## 6. Key takeaways

- **Three fences, three questions:** *are you allowed to ask?* (Argo CD RBAC), *may this app point there?* (AppProject), *may the cluster credential do it?* (Kubernetes RBAC).
- **One question routes you:** *did anything on the cluster get touched?* Nothing → Argo CD (fence 1/2); started-then-failed → Kubernetes (fence 3).
- **Who owns the field decides where the fix goes** — `policy.csv`, the AppProject, or the cluster's Roles.

**→ Next:** [02 — AppProjects and RBAC, up close](02-appprojects-and-rbac.md)
