# Security, Multi-Tenancy, and Governance

> **Day 2 · Session 6 · Concept guide · ~45 minutes**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`; the repo-server renders charts with **Helm v4.2.1**).
> **What you need open:** nothing is required — this is a read-and-think session. There is one optional, read-only CLI (command-line interface) exercise at the end (Section 7) that tests an RBAC (role-based access control) policy file **offline**, creating and changing nothing. **Lab 5** is where you build a real fence around a new tenant and try to walk through it; this session gives you the mental model that makes Lab 5's error messages readable.

> **Timing, accounted honestly (for you and your instructor).** The course allots this session **45 minutes**, and the table below covers *every* section, reading time included. Walked at full depth the blocks total about **58 minutes**, so four of them are marked *self-read* or *compressible*. Taking all four lands the session at roughly **47 minutes**; the last two come out of the V-23 debrief if your group is already comfortable with single sign-on. Nothing is removed from the file — compressed material stays here to read.
>
> | Block | Full depth | If time is short |
> |---|---:|---|
> | Section 1 — Why this matters | 3 min | |
> | Section 2 — The three-fence mental model | 5 min | never cut: the whole session hangs off it |
> | Section 3 — Vocabulary (14 terms) | 4 min | **self-read** before the session |
> | Section 4 — V-22, the three fences and how each one fails | 5 min | never cut |
> | Section 4 — V-23, SSO group → role mapping | 3 min | |
> | Section 4 — V-24, secret-management patterns | 4 min | **compress** to its two rules (2 min) |
> | Sections 5.1–5.2 — The real AppProject and the real RBAC policy | 9 min | |
> | Sections 5.3–5.4 — Fence 3 recap and the shared ServiceAccount | 6 min | |
> | Section 5.5 — An Argo CD denial next to a Kubernetes 403 | 4 min | never cut: Lab 5 is built on it |
> | Section 5.6 — Governance controls, and why guardrails make the audit trail true | 3 min | |
> | Section 6 — Quick Checks (three) | 5 min | **one live, two self-check** (2 min) |
> | Section 8 — Misconceptions (five) | 3 min | |
> | Section 9 — Key takeaways and transition | 2 min | |
> | Screenshot gallery (SS-S6-01 to SS-S6-03) | 2 min | **self-read** |
> | **Total** | **58 min** | **≈47 min** |
>
> Section 7 (Try It Yourself) is optional and sits **outside** this budget.

**Where this sits in the course.** Session 5 and Lab 4 taught you to *scale* the deployment path — ApplicationSets and App-of-Apps let one change move many Applications. That is leverage, and leverage is exactly what makes governance urgent: the more an action can do, the more it matters *who* can take it and *what* it is allowed to touch. This session is about the fences that keep scale from becoming blast radius.

**One promise up front, because it removes most of the confusion:** there are **three** independent fences in Argo CD, and almost every "Argo CD security" question is really "which of the three fences is this?" Get the three straight and the rest of the session is detail.

---

## 1. Why this matters

A developer on the `storefront` team has a CI (continuous integration) pipeline. CI stands for *continuous integration* — the automated system that builds and tests code every time someone pushes a commit. To let that pipeline talk to Argo CD, someone generated an API (application programming interface) token months ago and pasted it into the pipeline's settings. It has worked fine ever since. Nobody has looked at it.

On a Tuesday, that pipeline runs a cleanup step that was supposed to remove a *stale test* Application. A typo in a variable turns the target into `storefront-prod`. The pipeline calls Argo CD with its token. Argo CD checks the token's permissions, finds that it is allowed to delete Applications, and **deletes the production Application.** Cascading deletion (which you met in Session 5) follows the finalizer down the tree, and the production workload is torn off the cluster.

Nothing malfunctioned. Every component did exactly what it was told. The failure was entirely a **governance** failure, and it has a precise anatomy:

- The token was granted **more than it needed** — it could delete, when it only ever needed to sync.
- Nobody could easily answer **"what can this token do?"** because the permission lived in a policy file few people read.
- There was **no fence at the project level** stopping a `storefront` credential from touching production, and **no deployment window** stopping a destructive change during business hours.

Every one of those is a control this session teaches. By the end you will be able to:

- name the **three fences** a request passes through, and tell, from an error message alone, **which fence refused it**;
- explain why **Argo CD's own permissions** and **the cluster's own permissions** are different systems that fail differently;
- describe how **SSO** (single sign-on) group-to-role mapping removes the need for standing admin access — and how a **local account** stands in for a group in this lab, since there is no identity provider;
- choose a **secret-management pattern** that keeps plaintext out of Git;
- and say what you have actually granted when you let a team **create Applications or ApplicationSets** for themselves.

Let us build the three-fence model first, because it organizes everything else.

---

## 2. Plain-language mental model: three fences a request passes through

Picture a request — "sync the `storefront-prod` Application" — walking toward the cluster. It has to get past **three separate fences**, in order, and each fence is guarded by a **different system that answers a different question**:

1. **Argo CD RBAC — "Are *you* allowed to ask?"** This is Argo CD's own permission layer. It looks at *who is making the request* (a user, a group, a token) and *what verb they want* (get, sync, override, delete) and decides whether to let the request in the door at all. If this fence says no, **no sync ever starts.** Think of it as the receptionist checking your badge before you are allowed to press any button.

2. **The AppProject — "Is *this app* allowed to point there?"** An AppProject is a boundary attached to the Application, not to the person. It restricts *which repositories* an Application may deploy from, *which cluster and namespace destinations* it may target, and *which resource kinds* it may create. Even a request from a full administrator is refused here if the Application points somewhere its project does not permit. Think of it as a fence around the *building the app is allowed to enter* — the badge got you in the door, but this door only opens onto certain floors.

3. **Kubernetes RBAC — "Is the *cluster credential* allowed to do it?"** Once Argo CD has decided to act, it uses a **ServiceAccount** on the workload cluster to actually create and change resources. The workload cluster's own permission system checks that ServiceAccount. If *it* says no, the sync **started** and then **failed** partway through, with a `forbidden` error from the cluster's API server. Think of it as the lock on the specific room — you are in the building, on the right floor, but this particular door has its own key.

Here is the single most useful consequence of the model, and it is worth memorizing because it turns a vague "permission denied" into a diagnosis:

> **If the sync never started, it is Argo CD (fence 1 or 2). If the sync started and then failed, it is Kubernetes (fence 3).**

Two fences live inside Argo CD (RBAC and the AppProject) and one lives out on the cluster (Kubernetes RBAC). They are enforced by different teams' configuration, they fail with different error text, and — this is the trap — **they all show up as roughly the same red badge in the UI (user interface).** The skill this session builds is reading *past* the badge to the fence.

---

## 3. Vocabulary, grounded before we use it

Each term gets a plain-language definition first, then its role. These are the words this file introduces to the rest of Day 2; Lab 5 uses them freely.

- **RBAC (role-based access control).** Any permission system that works by assigning *roles* to *subjects* (people, groups, accounts) and attaching *permissions* to those roles, rather than to individuals one at a time. Both Argo CD and Kubernetes use RBAC — that shared name is exactly why they get confused, so we always say **which** RBAC we mean.

- **Argo CD RBAC.** Argo CD's *own* permission layer, separate from Kubernetes. It decides what a subject may do *inside Argo CD* — see an app, sync it, override a parameter, delete it. It lives in a Kubernetes ConfigMap named `argocd-rbac-cm`, as a list of policy lines. It is **fence 1**.

- **policy line / `policy.csv`.** The Argo CD RBAC rules are written as CSV (comma-separated values) text. Each *permission* line has the shape `p, <subject>, <resource>, <action>, <object>, <allow|deny>` — read as "policy: this subject may take this action on this resource, matching this object." Each *group binding* line has the shape `g, <subject>, <role>` — read as "grant: this subject has this role." You will read real ones in Section 6.

- **AppProject.** A Kubernetes CRD (Custom Resource Definition — a way of teaching Kubernetes a new kind of object) that Argo CD installs. An AppProject object fences *what an Application may point at*: `sourceRepos` (allowed Git repositories), `destinations` (allowed cluster/namespace pairs), `clusterResourceWhitelist` (allowed cluster-scoped kinds), and `namespaceResourceWhitelist` (allowed namespaced kinds). It is **fence 2**. You met it briefly in Session 2 and completed one in Lab 2; here it becomes a security boundary.

- **Kubernetes RBAC.** The workload cluster's *own* permission system, enforced by its API (application programming interface) server. It decides what a **ServiceAccount** may create, read, update, or delete on that cluster. It is **fence 3**, and it is configured by whoever administers the workload cluster — not by Argo CD.

- **ServiceAccount (SA).** A non-human identity inside Kubernetes that a program uses to authenticate to the cluster. Argo CD acts on the workload cluster as one specific ServiceAccount (in this course, `argocd-manager` in the `argocd-access` namespace). Every Application's sync uses **the same** ServiceAccount — a fact with large consequences (Section 5.4).

- **least privilege.** The practice of granting an identity *only the permissions it actually needs* and no more. For Argo CD's workload-cluster credential this means: it can write to the exact namespaces and kinds the course apps use, and nothing else. You built this in Lab 2; this session recaps *why* in three minutes (Section 5.3).

- **SSO (single sign-on).** A setup where people log in through one central **identity provider** rather than each application keeping its own passwords. Log in once, and that identity is trusted by many systems.

- **IdP (identity provider).** The central system that actually authenticates a person and reports *who they are* and *which groups they belong to* — for example, an organization's Okta, Entra ID, or Google Workspace. Argo CD does not store these users; it trusts the IdP's answer.

- **OIDC (OpenID Connect).** The common protocol Argo CD uses to talk to an identity provider. You do not configure it in this course (there is no IdP in the lab), but you should recognize the name: it is *the standard way* Argo CD receives "this person is authenticated, and here are their groups."

- **group-to-role mapping.** The rule that says "everyone in IdP group *X* gets Argo CD role *Y*." It is a single `g, <group>, <role>` line in `policy.csv`. This is the heart of SSO governance: you never grant a *person* permissions; you grant a *group* a role, and the IdP decides who is in the group.

- **local account.** An account defined *inside* Argo CD itself (in `argocd-cm`), with a password Argo CD stores, used when there is no identity provider. In this lab, the local account **`team-a-dev`** stands in for "a member of an SSO group": mapping it to a role with a `g, <account>, <role>` line behaves like mapping a real IdP group, so you can practice the governance without an IdP.

- **project role, and its JWT project token.** A **project role** is a role defined *inside a single AppProject* (`spec.roles`), scoped to only that project's Applications — how a project owner grants narrow, project-local permissions without touching the global `policy.csv`. A **JWT project token** is the credential issued *for* such a role and used by automation: a **JWT (JSON Web Token)** is a signed, self-contained credential string. Together they are the safe replacement for the broad admin token in Section 1's story.

- **separation of duties.** The governance principle that the people who *set* the boundaries (the platform team, who own AppProjects, `policy.csv`, and cluster credentials) are not the same people who *operate within* them (the application teams, who own their app's Git manifests). It is the organizational shape the three fences are built to support.

One more term, **sync window**, is defined in one line where it first matters (the governance table in Section 5.6), because that is where it gets its full treatment.

Two acronyms used throughout: **CI** (continuous integration) and **UI** (user interface); **CLI** is the command-line interface.

---

## 4. Visuals

Three pictures carry this session. Read each one, and answer its **Predict first** question in your head before the debrief under it.

### V-22 · The three fences, and how each one fails

**Predict first:** a request to sync `storefront-prod` is refused. You are handed only the error text. What *one* question tells you which of the three fences refused it?

Follow a single request left to right. Each fence is a different system with a **different error signature** — that signature is the whole point of the diagram.

```text
                        Argo CD                                 Workload cluster
   ┌──────────────────────────────────────────────────┐   ┌────────────────────────┐
   │                                                    │   │                        │
 REQUEST     FENCE 1                 FENCE 2            │   │        FENCE 3          │
 "sync   ┌───────────────┐      ┌───────────────┐      │   │   ┌────────────────┐    │
 store-  │ Argo CD RBAC  │      │  AppProject   │      │   │   │ Kubernetes RBAC│    │
 front-  │ Are YOU       │ ───► │ May this APP  │ ───► │───►   │ May the cluster│    │
 prod"   │ allowed to    │ pass │ point THERE?  │ pass │sync │ │ CREDENTIAL do  │    │
   ───►  │ ask?          │      │ (repo/dest/   │  op  │starts │ it?            │    │
         │ (who + verb)  │      │  kind)        │      │   │   │ (the SA)       │    │
         └───────┬───────┘      └───────┬───────┘      │   │   └───────┬────────┘    │
                 │ DENY                 │ DENY         │   │           │ DENY         │
                 ▼                      ▼              │   │           ▼              │
        "permission denied"   condition                │   │  "forbidden: User        │
        (terse, to you; the   InvalidSpecError:        │   │   \"system:service-      │
         detail is in the     "... do not match any   │   │   account:argocd-access: │
         argocd-server log)    of the allowed          │   │   argocd-manager\"       │
                               destinations in         │   │   cannot create ..."     │
        ── NOTHING IS ──       project '...'"          │   │  ── SYNC STARTED,        │
           APPLIED            ── NOTHING IS ──         │   │     THEN FAILED ──       │
                                 APPLIED               │   │                          │
   └────────────────────────────────────────────────┘   └────────────────────────┘
        Owned by: platform team's       Owned by: platform team's     Owned by: workload-cluster
        policy.csv                      AppProject YAML               RBAC (Role/RoleBinding)
```

**The one question:** *did a sync operation run?* If no operation ever started, the refusal was inside Argo CD — fence 1 (a person/verb it does not allow) or fence 2 (an app pointing where its project forbids). If an operation started and then failed with `forbidden`, it was fence 3 — the cluster credential. That single question routes you to the right fence, the right error text, and the right *team* to talk to.

**One refinement, so the question never misleads you.** A fence-2 refusal usually produces no operation at all: Argo CD marks the Application with an `InvalidSpecError` condition and stops. But if someone *presses Sync anyway* on such an Application, an operation **is** recorded — and it ends instantly, with `Phase: Error`, a duration of `0s`, and **not a single resource result row.** So the sharper form of the question is: *did anything on the cluster actually get touched?* Fences 1 and 2 touch nothing. Fence 3 is the one where Argo CD genuinely started applying and the cluster pushed back partway through.

Notice the ownership line at the bottom. It is this session's through-line: **who owns the field decides where the fix goes.** A fence-1 problem is fixed in `policy.csv`; a fence-2 problem is fixed in the AppProject; a fence-3 problem is fixed in the workload cluster's Roles.

### V-23 · SSO group → role mapping (identity from the IdP, permission from Argo CD)

**Predict first:** in an SSO setup, if someone leaves the `storefront` team, who removes their Argo CD access — and which file changes?

```text
   IDENTITY (who you are)                 PERMISSION (what you may do)
   lives in the IdP                        lives in Argo CD's policy.csv
   ┌─────────────────────────┐             ┌──────────────────────────────────────┐
   │  Identity Provider       │  OIDC       │  argocd-rbac-cm (policy.csv)          │
   │  (Okta / Entra / Google) │  login      │                                      │
   │                          │ ─────────►  │  g, storefront-devs, role:storefront │◄─ group→role
   │  groups:                 │  "you are   │  p, role:storefront, applications,   │
   │   • storefront-devs  ────┼─  in group  │       sync, storefront/*, allow      │◄─ role→permission
   │   • platform-admins      │  storefront │  p, role:storefront, applications,   │
   │                          │   -devs"    │       delete, storefront/*, deny     │
   └─────────────────────────┘             └──────────────────────────────────────┘
                                                          │
                                          ┌───────────────┴───────────────┐
                                          │  IN THIS LAB (no IdP):         │
                                          │  a LOCAL ACCOUNT stands in     │
                                          │  for a group —                 │
                                          │  g, <account>, <role>          │
                                          └────────────────────────────────┘
```

**The debrief:** identity and permission are **two different files owned by two different systems.** The IdP owns *who you are and which groups you are in*; Argo CD's `policy.csv` owns *what a group may do.* When someone leaves the `storefront` team, an IdP administrator removes them from the `storefront-devs` group and their Argo CD access is gone **with no change to `policy.csv` at all** — because Argo CD never knew them as a person, only as a group member. That is the entire governance win of SSO: **you stop managing people in Argo CD.** It is also why routine admin logins can be removed — a real person becomes an admin by being in the admin *group*, only when they need to be.

Because this lab has **no identity provider** (Dex, the component that would broker OIDC, is disabled), you cannot demonstrate a real group login. Instead, the local account `team-a-dev` plays the part: a `g, <account>, <role>` line is the *same shape* as a real group mapping, with a local account name where a group name would be. Everything you learn about the mapping transfers directly.

### V-24 · Secret-management patterns — commit the pointer, never the payload

**Predict first:** a `Secret` manifest with a base64-encoded password is committed to Git, then the password is rotated a day later. Who can still read the old password?

```text
   ✗ ANTI-PATTERN                     ✓ PATTERN A                      ✓ PATTERN B
   plaintext Secret in Git            destination-cluster mgmt         render-time injection
   ┌──────────────────────┐          ┌──────────────────────┐         ┌──────────────────────┐
   │ Git:                 │          │ Git (the POINTER):   │         │ Git (the POINTER):   │
   │  kind: Secret        │          │  kind: SealedSecret / │        │  kind: ExternalSecret│
   │  data:               │          │  ExternalSecret       │        │   (name + which key) │
   │   password: cGFzc==  │◄ base64, │   (ciphertext / ref) │         │                      │
   │   (NOT encryption)   │  anyone  └──────────┬───────────┘         └──────────┬───────────┘
   └──────────────────────┘  with repo          │ Argo CD applies                │ operator pulls
              │               read reads it      ▼ the pointer                    ▼ from a secret store
              ▼                          ┌──────────────────┐              ┌──────────────────┐
   exposed RETROACTIVELY &               │ In-cluster       │              │ Vault / cloud    │
   PERMANENTLY (Git history              │ controller       │              │ secret manager   │
   keeps it even after rotation)         │ decrypts → Secret│              │ → Secret at apply│
                                         └──────────────────┘              └──────────────────┘
```

**The debrief:** base64 is **encoding, not encryption** — anyone with read access to the repository can decode it in one command, so a plaintext `Secret` in Git is a leaked secret. Worse, it is leaked **retroactively and permanently**: Git keeps history, so rotating the password on Wednesday does not un-commit Tuesday's value. Anyone who ever had repo read can still read the old one.

The fix is a rule you already met in Session 3, now at governance depth: **commit the pointer, never the payload.** What lives in Git is a *reference* — "this app needs a secret with this name, sourced from over there." The *value* is assembled elsewhere:

- **Pattern A — destination-cluster secret management** (the direction Argo CD's own documentation recommends): the encrypted or referenced object goes in Git, and an in-cluster controller turns it into a real `Secret` **on the destination cluster** (Sealed Secrets, External Secrets Operator, the Secrets Store CSI Driver, Vault-based operators, and others). The plaintext value never passes through Argo CD.
- **Pattern B — render-time injection**: a plugin or operator injects the value while manifests are prepared. It works, but there is a sharp caveat to know — Argo CD stores **rendered manifests in Redis in plaintext**, so a value injected at render time can end up cached in plaintext. That is a real reason the documentation prefers Pattern A.

We name the tool *categories* and stop there — evaluating specific secret tools is out of this course's scope. The rule is what you carry: **the pointer is safe to commit; the payload never is.**

---

## 5. Worked walkthrough — reading the fences in the real environment

Now we make the model concrete against the **actual** AppProjects and RBAC policy this course ships. Nothing here is invented; every block is a file you can open on your VM. Read along.

### 5.1 Fence 2, up close: the real `storefront` AppProject

Here is the completed `storefront` AppProject (the one your Lab 2 exercise produced). Read it as a **fence**, field by field:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: storefront
  namespace: argocd
spec:
  description: Storefront application-team project
  sourceRepos:                                             # (1) allowed Git repos
    - http://lab-gitea:3000/course/storefront-gitops.git
  destinations:                                            # (2) allowed cluster + namespace
    - server: https://k3d-workload-server-0:6443
      namespace: storefront-dev
    - server: https://k3d-workload-server-0:6443
      namespace: storefront-staging
    - server: https://k3d-workload-server-0:6443
      namespace: storefront-prod
  clusterResourceWhitelist: []                             # (3) NO cluster-scoped kinds
  namespaceResourceWhitelist:                              # (4) only these namespaced kinds
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Service
    - group: apps
      kind: Deployment
    - group: batch
      kind: Job
    - group: autoscaling
      kind: HorizontalPodAutoscaler
```

Read as four fences in one object:

1. **`sourceRepos`** — an Application in this project may deploy **only** from `storefront-gitops`. Point it at any other repository and fence 2 refuses it. This is how a project says "you may run code, but only *this team's* code."
2. **`destinations`** — an Application in this project may target **only** the three `storefront-*` namespaces on **that one** workload cluster. It cannot deploy to `kube-system`, cannot deploy to another team's namespace, cannot deploy to the management cluster.
3. **`clusterResourceWhitelist: []`** — an *empty* list means **no cluster-scoped resource kinds are allowed at all.** This app may not create ClusterRoles, CustomResourceDefinitions, Namespaces, or anything else that lives outside a namespace. Empty is not "unset and permissive" — for `clusterResourceWhitelist`, empty means *deny all*.
4. **`namespaceResourceWhitelist`** — even inside its namespaces, the app may create **only** these five kinds. A `Secret`? Not listed — refused. A `NetworkPolicy`? Not listed — refused. The fence is deliberately narrow.

The lesson: an AppProject is a *positive* list. It permits exactly what it names and refuses everything else. That is what makes it a fence rather than a suggestion.

> **The `default` project is the opposite of this — and that matters.** Every Argo CD install ships an AppProject named `default`, and it is created **maximally permissive**: `sourceRepos: ['*']`, any destination server and namespace, and a cluster-resource allow-list that permits every group and kind. An Application with no `project` set lands in `default`. So a fresh install *has* a project and *no boundary.* The `storefront` project above is what a fence looks like; `default` is a door with a lock painted on it. Hardening step one is to **empty** `default`'s allow-lists — you will feel exactly why in Lab 5.

### 5.2 Fence 1, up close: the real Argo CD RBAC policy

Now fence 1 — the permission layer that decides *who may ask.* Here is the policy the hypothetical `payments` tenant runs with (it lives in `argocd-rbac-cm`, applied by the platform's apply step). In Lab 5 you will write the equivalent policy for a tenant of your own, so read this for its *shape* rather than memorizing the lines:

```csv
p, role:payments, applications, get,      payments/*, allow
p, role:payments, applications, sync,     payments/*, allow
p, role:payments, applications, action/*, payments/*, allow
g, payments-dev, role:payments
```

Read line by line:

- **`p, role:payments, applications, get, payments/*, allow`** — the role `payments` may **get** (see) any Application whose name matches `payments/*` (project `payments`, any app). A permission line is `p, subject, resource, action, object, effect`.
- **`p, role:payments, applications, sync, payments/*, allow`** — the same role may **sync** those apps.
- **`p, role:payments, applications, action/*, payments/*, allow`** — the role may run resource **actions** (like restarting a Deployment) on those apps.
- **`g, payments-dev, role:payments`** — the *grant* line: the account **`payments-dev`** *has* the role `payments`. A group line is `g, subject, role`.

Notice what is **not** here: there is no `delete` line. The `payments` role can see and sync its own apps and nothing else — it **cannot delete** an Application, and it has **no visibility at all** into another tenant's apps. That is fence 1 doing its job: shaping what a subject may *ask for* before any app or cluster is involved.

Notice also the last line's shape: **`g, payments-dev, role:payments`.** In a real deployment this would read `g, payments-devs, role:payments` — an SSO *group* mapped to the role, with the IdP deciding who is in that group (V-23). Here, with no IdP, a **local account** stands in for the group. Same line, same behavior; only the subject's nature differs. This is the substitution that lets Lab 5 teach group governance without an identity provider. *(The base policy ships empty — `policy.default: ""`, `policy.csv: ""` — so a fresh Argo CD grants nobody anything; a tenant policy like this one is layered on top.)*

### 5.3 Fence 3, and a 3-minute recap of least-privilege credentials

Fence 3 is the workload cluster's own Kubernetes RBAC, and it guards the **ServiceAccount** Argo CD uses to write. You built this identity in Lab 2, so this is a recap, not new material — but the *reason* is governance, so it belongs here:

- Argo CD authenticates to the workload cluster as the ServiceAccount **`argocd-manager`** in namespace **`argocd-access`**.
- Its permissions are **least privilege**: RoleBindings grant it write access **only** in `storefront-dev/staging/prod` and `platform-system`, and a deliberately *narrower* set in the tenant namespace `team-a`. Exactly where that narrower set stops is something you will find out for yourself in Lab 5 — by reading the denial the cluster produces, not by being told.
- There is **no ClusterRoleBinding** giving it cluster-wide write. It cannot create Namespaces, cannot touch `kube-system`, cannot write cluster-scoped objects.

Two properties are worth restating because auditors ask about them:

- **You can restrict *write* freely** — down to named namespaces, groups, and kinds.
- **You cannot meaningfully restrict *read*** — `get`, `list`, and `watch` at cluster scope are *required* for Argo CD to compute live state and health at all. "Least privilege for Argo CD" means **least *write* privilege**, and saying that out loud before your security reviewer does is the difference between a story that survives the audit and one that collapses.

### 5.4 The uncomfortable truth: every tenant syncs as the *same* ServiceAccount

Here is the fact that makes fence 2 carry so much weight. **Every** Application's sync — `storefront`'s, `team-a`'s, anyone's — runs as the **same** `argocd-manager` ServiceAccount on the workload cluster. From the cluster's point of view there is exactly one client. Kubernetes literally **cannot tell your tenants apart.**

That has a sharp consequence: **for tenancy, Argo CD is the only fence you have.** Kubernetes RBAC (fence 3) can stop *any* Argo CD write to a forbidden namespace or kind, but it cannot say "this write is `team-a`'s and that one is `storefront`'s" — they are the same identity to the cluster. So the thing that actually keeps `team-a` out of `storefront`'s namespaces is the **AppProject `destinations` list** (fence 2), not Kubernetes. If your auditor asks "how does the cluster know which team deployed this?", the honest answer is "it does not — Argo CD's AppProject does." *(Argo CD documents an advanced "sync using impersonation" feature that gives each destination its own ServiceAccount, which would change this answer — "impersonation" here means Argo CD deliberately acts through a narrower, destination-specific ServiceAccount, not an attacker impersonating anyone. Treat it as a named direction to investigate, not a lab step, and check its maturity against your own Argo CD version before relying on it.)*

### 5.5 Contrast in the wild: an Argo CD denial vs a Kubernetes 403

Now the payoff. Two failures that *look* identical in the UI and are told apart by the one question from V-22.

> **Read these two cases as illustrations, not as objects in your lab.** They use a **hypothetical** tenant called `payments` — another team at another company running this same platform, with its own `payments` AppProject and its own `payments` namespace on a workload cluster. No project, namespace, or file named below exists in your environment. What transfers is the *shape* of each message; Lab 5 makes you read that shape against different objects, which is the actual skill.

The setup is a deliberate **asymmetry**, and it is extremely common in real platforms: the `payments` AppProject **permits** the `NetworkPolicy` kind (a Kubernetes object that controls which pods may talk to which), while the workload cluster's own least-privilege ServiceAccount was **never granted** permission to create NetworkPolicies in that namespace. Two fences, two different answers about the same object. That asymmetry is what makes the pair diagnosable rather than merely annoying.

**Case A — a fence-2 (AppProject) denial.** An engineer points a `payments` Application at the `platform-system` namespace — where the platform team's own components live — which is **not** in the `payments` project's `destinations`. Argo CD refuses it *before any sync runs*, and records the refusal as a **condition** on the Application rather than as a failed sync. Run `argocd app get <app>` and the condition block reads in this shape:

```text
CONDITION         MESSAGE
InvalidSpecError  application destination server 'https://k3d-workload-server-0:6443' and
                  namespace 'platform-system' do not match any of the allowed destinations
                  in project 'payments'
```

Two details to fix in memory, because they are what you will actually search for. The condition **type** is `InvalidSpecError` — the spec itself is invalid against its project, which is why it never becomes a sync problem. And the searchable phrase is **`do not match any of the allowed destinations in project`**, in single quotes around the names.

No operation started. (If someone presses Sync regardless, the operation is recorded and ends immediately with `Phase: Error`, `Duration: 0s`, and **no resource rows at all** — nothing on the cluster is touched.) The fix lives in the **AppProject** (fence 2) — either the destination is genuinely wrong (fix the app) or the project should permit it (a platform-team decision).

**Case B — a fence-3 (Kubernetes) denial.** A *permitted* `payments` Application — correct repo, correct destination, project-approved kind — tries to sync the NetworkPolicy declared at `manifests/network/default-deny.yaml`. The AppProject allows the kind, so Argo CD **starts the sync**; then the workload cluster's API server refuses the write, and the `forbidden` error appears **inside the sync result**:

```text
networkpolicies.networking.k8s.io is forbidden: User
"system:serviceaccount:argocd-access:argocd-manager" cannot create resource
"networkpolicies" in API group "networking.k8s.io" in the namespace "payments"
```

A sync operation **ran** and **failed**. The fix lives on the **workload cluster** (fence 3) — a Role/RoleBinding decision — not in Argo CD at all.

Same red badge. Opposite systems, opposite owners, opposite fixes. The question "*did a sync operation run?*" — in its sharper form from V-22, *did anything on the cluster actually get touched?* — separated them in one step.

Two reading notes before you meet these for real. First, the ServiceAccount named in Case B — `argocd-manager` in namespace `argocd-access` — **is** the real identity your Argo CD uses on the workload cluster, so that part of the text will look familiar when you hit a genuine fence-3 denial; only the tenant, the namespace, and the file path above are invented. Second, exact message wording shifts between Argo CD versions and between Kubernetes versions: read for the **signature** (a subject and a verb; an `InvalidSpecError` condition saying the destination does not match the project's allowed destinations; "forbidden … serviceaccount"), never for a character-for-character match.

### 5.6 Governance features that ride on the fences

Two more governance controls ride on top of the three fences. Both are exactly what an audit conversation turns on, so here they are as a compact reference:

| Control | What it is, and where it lives | The governance question it answers |
|---|---|---|
| **API account and scoped token** | A **project role** (defined inside one AppProject's `spec.roles`) issued a **JWT project token** — for example a role inside a tenant's project granted only `sync` on that project's apps, whose signed token the CI pipeline uses. Permissions are enforced at **fence 1**. | *"What can this credential do?"* A typo in that pipeline could not touch `storefront-prod`, because the token's fence-1 permissions never reach it. The lesson of Section 1's story is not "tokens are dangerous" — it is "tokens should be **scoped**, and admin tokens should not live in pipelines." Removing routine admin access (SSO admins by group, only when needed) is the same idea applied to humans. |
| **Deployment window** (higher-environment control) | A **sync window**: an entry on the AppProject that **allows** or **denies** syncing during a time range, with a schedule, a duration, and a scope (applications, namespaces, or clusters). A deny window is a change freeze expressed as configuration. Its escape hatch is `manualSync: true`, which lets a named person sync by hand during the freeze — and that use is itself a recorded sync. You will see the panel in SS-S6-03. | *"Who may bypass the freeze, and does the bypass show up afterward?"* — never merely "is there a freeze?" A freeze nobody can audit is a rule, not a control. |

And the through-line that ties every fence together: **guardrails are what make the audit trail true.** "Every deployment is a commit, so we have a complete audit trail" is only true if nobody can deploy *without* going through Argo CD. If engineers keep direct `kubectl` write access to the workload clusters, the Git history is a record of what people *usually* did. The fences are not bureaucracy layered on GitOps — they are the precondition that makes GitOps' central claim factual.

---

## 6. Quick Checks

Answer each in your head (or on paper) **before** opening the collapsed answer. These are diagnosis and design questions, not vocabulary quizzes.

### S6-QC1 — Name the fence that denied each request

You are handed three pieces of evidence, all from the hypothetical `payments` tenant of Section 5.5. For each, name **which fence refused it** (Argo CD RBAC, AppProject, or Kubernetes RBAC) and state the one piece of evidence that tells you.

1. An engineer's terminal printed only `permission denied`. In the `argocd-server` pod's log, the matching line reads: `permission denied: applications, get, payments/payments-web, sub: dana, iat: ...`
2. An Application carries the condition `InvalidSpecError`, with the message `application destination server 'https://k3d-workload-server-0:6443' and namespace 'platform-system' do not match any of the allowed destinations in project 'payments'`
3. `networkpolicies.networking.k8s.io is forbidden: User "system:serviceaccount:argocd-access:argocd-manager" cannot create resource "networkpolicies" in API group "networking.k8s.io" in the namespace "payments"`

<details>
<summary>Show answer and rationale</summary>

1. **Argo CD RBAC (fence 1).** Evidence: `permission denied` with a log line naming a **subject** (`sub: dana`) and a **verb** (`get`). The request was refused because of *who asked and what they asked for.* Note the two-part shape, which surprises people: what the user sees can be the bare words `permission denied`, while the useful detail — subject, verb, and object — is written to the **`argocd-server` log**. If you are ever handed only "permission denied," that log is where the rest of the sentence lives. Nothing was applied. Fix lives in `policy.csv`.
2. **AppProject (fence 2).** Evidence: the condition type **`InvalidSpecError`** and the phrase **`do not match any of the allowed destinations in project`** — the refusal is about *where the app points*, not who asked. The destination namespace is not in the project's `destinations`. No sync operation ran, and nothing was applied. Fix lives in the AppProject YAML (or the app is pointed wrong).
3. **Kubernetes RBAC (fence 3).** Evidence: **`forbidden`** naming the **ServiceAccount** `system:serviceaccount:argocd-access:argocd-manager`. This came from the *cluster's* API server, which means the sync **started and then failed** — Argo CD had already decided to act. Fix lives on the workload cluster (a Role/RoleBinding), not in Argo CD.

**Rationale:** the routing question is *did anything on the cluster get touched?* Evidence 1 and 2 refused the request before any resource was applied (Argo CD's two fences); evidence 3 refused a write *during* an operation (the cluster's fence). Then the exact words confirm it: a **subject+verb** (in the message or in the server log) = fence 1, **`InvalidSpecError` / "do not match any of the allowed destinations"** = fence 2, **"forbidden … serviceaccount"** = fence 3.
</details>

### S6-QC2 — Why should only administrators create ApplicationSets?

Your platform lets application teams create their own **Applications** within their project's fences. A team asks for permission to create **ApplicationSets** too, "to save the platform team some tickets." Why is that a materially bigger grant, and what is the specific escalation risk?

<details>
<summary>Show answer and rationale</summary>

**Because an ApplicationSet is a factory that writes Applications, and the field that names each generated app's project — `spec.template.spec.project` — is inside the template the creator controls.** If a team can create an ApplicationSet, they can write a template whose `project` is set to a **more privileged project** (or a templated value they steer), and the ApplicationSet controller will happily stamp out Applications in that project. That is a **privilege-escalation path**: creating one ApplicationSet becomes the power to create Applications *in projects the team was never granted.*

Creating a single **Application** is bounded — it names one project, and fence 1 governs which projects the creator may use. Creating an **ApplicationSet** hands the team the *pen that writes Applications*, and a templated `project` turns that into "deploy into whatever project I can template." Argo CD's own documentation is explicit: **only admins should create, update, or delete ApplicationSets.**

**Rationale:** "letting a team create Applications is letting them deploy anywhere the project allows" — bounded by the project. "Letting a team create ApplicationSets is letting them *choose the project*" — that is the bound itself becoming editable. The course mitigation, which you will follow in Lab 4/5: keep `project` **hard-coded** in every ApplicationSet, and keep ApplicationSet creation with the platform team.
</details>

### S6-QC3 — Choose a secret pattern and a group mapping for a scenario

A new team, `payments`, needs: (a) their app to consume a database password **without any plaintext in Git**, and (b) their five engineers to be able to **sync but not delete** their own Applications, managed through the company's existing Okta groups. Sketch the secret-management choice and the two `policy.csv` lines you would add.

<details>
<summary>Show answer and rationale</summary>

**(a) Secret management — commit the pointer, never the payload (V-24, Pattern A).** Store a *reference* object in Git (for example a SealedSecret's ciphertext or an ExternalSecret naming the store and key) and let an in-cluster controller assemble the real `Secret` **on the destination cluster**. Do **not** commit a `Secret` with a base64 value — base64 is encoding, not encryption, and Git would keep it retroactively and permanently even after rotation. Prefer destination-cluster management over render-time injection, partly because Argo CD caches rendered manifests in Redis in plaintext.

**(b) Group mapping and permissions (V-23):**

```csv
p, role:payments, applications, sync, payments/*, allow
g, payments-devs, role:payments
```

The `p` line grants the role `sync` (and you would add `get`) on `payments/*` — and note the **absence** of a `delete` line, which is how you say "sync but not delete." The `g` line maps the **Okta group** `payments-devs` to that role, so identity is owned by Okta and permission by Argo CD. Adding or removing an engineer is an Okta group change with **no edit to `policy.csv`.** (You would also fence the app with a `payments` AppProject — but the question asked for the secret choice and the mapping.)

**Rationale:** this is the whole session in one scenario — the secret rule keeps the payload out of Git, the *missing* `delete` line shapes what the role may ask (fence 1), and the group mapping puts identity where it belongs (the IdP) so you stop managing people inside Argo CD.
</details>

---

## 7. Try It Yourself (optional, ~5 minutes, offline, creates nothing)

You can **unit-test an RBAC policy before anyone deploys it** — which is what "policy as code" means in practice. The command `argocd admin settings rbac can` answers "may this subject take this action on this object?" against a policy file, touching no cluster and no live Argo CD.

**Predict first.** Given this policy (the `payments` policy from Section 5.2), write down **Yes** or **No** for each of the four checks *before* running anything:

```csv
p, role:payments, applications, get,      payments/*, allow
p, role:payments, applications, sync,     payments/*, allow
p, role:payments, applications, action/*, payments/*, allow
g, payments-dev, role:payments
```

1. May `payments-dev` **sync** the app `payments/payments-web`?
2. May `payments-dev` **delete** the app `payments/payments-web`?
3. May `payments-dev` **sync** the app `storefront/storefront-prod`?
4. May `payments-dev` **get** the app `payments/payments-web`?

Now save the policy and run the checks. The argument order is `<subject> <action> <resource> <object>` — note that the resource type (`applications`) and the object (`payments/payments-web`) are **separate** arguments:

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

Output (captured from the course's `argocd` **v3.5.2** client during authoring — confirm it matches on your VM):

```text
Yes
No
No
Yes
```

**What to make of it:**

- **1 → `Yes`, 4 → `Yes`:** the role explicitly allows `sync` and `get` on `payments/*`, and `payments-dev` has the role via the `g,` line.
- **2 → `No`:** there is **no `delete` line**, and Argo CD RBAC denies by default. The *absence* of a permission is the permission model working.
- **3 → `No`:** the object `storefront/storefront-prod` does not match `payments/*`, so the role's allow lines never apply. This is fence 1 stopping a cross-tenant request before any app or cluster is touched.
- **The point:** every one of those answers came from a **text file**, with no cluster and no risk. That is where an RBAC change belongs — tested in CI, before your users discover the bug by hitting it. (Clean up with `rm /tmp/s6-policy.csv` when done.)

**One flag to remember for the live variant.** The command above reads a file, so it needs `--policy-file`. If you instead want to ask the question against the **policy your running Argo CD is actually using**, swap that flag for `--namespace argocd` (the namespace Argo CD is installed in), like this: `argocd admin settings rbac can <account> sync applications '<project>/<app>' --namespace argocd`. Argo CD requires **exactly one** of the two flags; supplying neither fails with `please provide exactly one of --policy-file or --namespace`.

---

## 8. Common misconceptions

**"AppProject restrictions are Kubernetes RBAC."** They are not — an AppProject is **Argo CD's own admission layer** (fence 2), enforced by Argo CD *before* it ever contacts the cluster. A `destinations` violation is refused with an `InvalidSpecError` condition reading `... do not match any of the allowed destinations in project '...'`, and **nothing is applied.** Kubernetes RBAC (fence 3) is a *different* system on the *workload* cluster that refuses a write *during* a sync with `forbidden ... serviceaccount`. Confusing them sends you to fix the wrong file, owned by the wrong team. The tell is always the same: did anything on the cluster actually get touched?

**"The `default` project is safe to use."** The `default` AppProject is the **most permissive** object in a fresh install — `sourceRepos: ['*']`, any destination, all cluster resource kinds. An Application with no `project` set lands there and is fenced by *nothing.* "It has a project" is not "it has a boundary." Put real apps in real projects, and **empty** `default`'s allow-lists as a hardening step (you will do exactly this in Lab 5 and watch a scratch app stop syncing).

**"An AppProject with an empty `clusterResourceWhitelist` is unset, so it allows everything."** It is the opposite: **empty means deny.** `clusterResourceWhitelist: []` permits **no cluster-scoped resource kinds at all** — no ClusterRoles, no CustomResourceDefinitions, no Namespaces. The trap is that an empty list *looks* like a field nobody filled in, and in many configuration systems an unset list does mean "no restriction." An AppProject is a **positive** list: it permits exactly what it names and refuses everything else, so an empty list names nothing and therefore permits nothing. Read `[]` as a closed gate, not an open one — and, by the same reading rule, notice that `['*']` (what the `default` project ships with) is the genuinely open gate.

**"A sealed Secret in Git is the same as a plaintext Secret in Git."** They are opposites. A plaintext `Secret` in Git carries a **base64-encoded** value — encoding, not encryption — that anyone with repo read can decode in one command, and Git keeps it forever. A **SealedSecret** in Git carries **ciphertext** that only the in-cluster controller's private key can decrypt; repo read reveals nothing usable. One is a leaked secret; the other is a safe *pointer* to a secret. "It's in Git either way" misses the entire point of the pattern.

**"We have Kubernetes RBAC, so our tenants are isolated in Argo CD."** Every tenant syncs as the **same** `argocd-manager` ServiceAccount, so Kubernetes cannot tell them apart (Section 5.4). For tenancy, the isolating fence is the **AppProject**, not Kubernetes RBAC. "We have cluster RBAC" is not an answer to "how are tenants isolated."

---

## 9. Key takeaways

- **Three fences, three questions.** Argo CD RBAC asks *are you allowed to ask?*; the AppProject asks *may this app point there?*; Kubernetes RBAC asks *may the cluster credential do it?* Almost every Argo CD security question is "which fence is this?"
- **One question routes you: *did anything on the cluster get touched?*** Nothing applied = Argo CD (fence 1 or 2); an operation that started and then failed = Kubernetes (fence 3). The exact words confirm it — a subject and a verb (sometimes only in the `argocd-server` log), the condition `InvalidSpecError` with "do not match any of the allowed destinations in project", or "forbidden … serviceaccount."
- **Who owns the field decides where the fix goes.** Fence 1 → `policy.csv`; fence 2 → the AppProject; fence 3 → the workload cluster's Roles. The error message is a routing slip to a team.
- **Identity from the IdP, permission from Argo CD.** SSO maps a *group* to a *role* (`g, group, role`); you stop managing people inside Argo CD, and routine admin access can be removed. The lab's local account `team-a-dev` stands in for a group.
- **Every tenant syncs as the same ServiceAccount.** Kubernetes cannot tell tenants apart, so the **AppProject** is the only tenancy fence you have.
- **The `default` project is a door with a lock painted on it.** Emptying its allow-lists is hardening step one.
- **Commit the pointer, never the payload.** A secret in Git is exposed retroactively and permanently; keep the value in a secret manager and reference it. Prefer destination-cluster management over render-time injection.
- **Scope tokens, don't hand out admin.** Project roles with JWT project tokens give automation exactly what it needs; a broad admin token in a pipeline is the Section 1 incident waiting to happen.
- **Guardrails make the audit trail true.** GitOps' "every change is a commit" only holds if nobody can deploy around Argo CD.

---

## Screenshots referenced in this session

These three screens make the fences visible. Each block gives an image reference with alt text, a version-stamped caption, a numbered "what to notice," and a capture specification so the image can be produced consistently from the live course instance. Where an image has not yet been captured, the capture spec is authoritative — the guide still works from the numbered notes if the image does not render.

### SS-S6-01 · The Projects list — four fences at a glance

![Argo CD Settings Projects list in v3.5.2, showing four AppProjects named default, storefront, platform, and team-a, each with its description.](../assets/screenshots/day-2/s06-01-projects-list.png)

*Argo CD v3.5.2 — Settings ▸ Projects (`/settings/projects`), logged in as admin, checkpoint CP-capstone (pre-fault). Four projects: `default`, `storefront`, `platform`, `team-a`.*

<!-- CAPTURE-SPEC: SS-S6-01 — Settings ▸ Projects list.
Source: live capture only, course Argo CD v3.5.2 at https://localhost:8443, checkpoint CP-capstone pre-fault (reset-lab.sh CP-capstone), logged in as admin.
Steps: (1) log in as admin; (2) open Settings (gear icon) in the left nav; (3) click Projects; land on /settings/projects.
Capture: full page, viewport 1440x900, light theme, 100% zoom, PNG. Highlight the four project rows (default, storefront, platform, team-a) in the .argo-table-list.
Save to: courseware/assets/screenshots/day-2/s06-01-projects-list.png -->

**What to notice:**

1. **`default` sits right next to the real fences.** It looks like one more project in the list, which is exactly the trap — it is the maximally permissive one, and it is one click away from the tight ones.
2. **Each project is a fence you can open and read.** Clicking `storefront` or `team-a` shows the `sourceRepos`, `destinations`, and whitelists you read as YAML in Section 5 — the UI is a view onto the same object.
3. **Four projects means four tenancy boundaries.** This is the multi-tenancy story made concrete: separate app teams, separate fences, one Argo CD.

### SS-S6-02 · The same Argo CD, seen as `team-a-dev`

![Argo CD Applications list in v3.5.2 while logged in as the team-a-dev local account, showing only the team-a Applications and none of the storefront or platform Applications.](../assets/screenshots/day-2/s06-02-team-a-dev-view.png)

*Argo CD v3.5.2 — the Applications list (`/applications`) logged in as the local account **`team-a-dev`**, checkpoint CP-capstone (pre-fault). Only permitted Applications are visible.*

<!-- CAPTURE-SPEC: SS-S6-02 — Applications list as team-a-dev.
Source: live capture only, course Argo CD v3.5.2, checkpoint CP-capstone pre-fault, logged in as the team-a-dev local account (password from ~/course/credentials/team-a-dev.txt).
Steps: (1) log out of admin; (2) log in as team-a-dev; (3) land on /applications.
Capture: full page, viewport 1440x900, light theme, PNG. Highlight the .applications-list showing only team-a Applications; note the absence of storefront/platform apps.
Save to: courseware/assets/screenshots/day-2/s06-02-team-a-dev-view.png -->

**What to notice:**

1. **Fence 1 is visible as *absence*.** `payments-dev` cannot even **see** another tenant's apps — the `get` permission is scoped to `payments/*`, so those apps are not hidden; they do not exist for this subject at all.
2. **This is what an SSO group member would see.** The local account is standing in for a group (V-23); a real `storefront-devs` member would see the mirror image — their apps and not `team-a`'s.
3. **Compare it to SS-S6-01.** The admin sees four projects; `team-a-dev` sees one tenant's worth of Applications. Same Argo CD, two very different views — that is `policy.csv` doing its job.

### SS-S6-03 · A sync window — a change freeze as configuration

![Argo CD project sync-windows panel in v3.5.2 for the team-a project, showing a deny window row with its schedule, duration, and manual-sync setting.](../assets/screenshots/day-2/s06-03-sync-window.png)

*Argo CD v3.5.2 — the `team-a` project's sync-windows panel (`/settings/projects/team-a`), logged in as admin, from the Lab 5 stretch state. A deny window row is shown.*

<!-- CAPTURE-SPEC: SS-S6-03 — Project sync-windows panel.
Source: live capture only, course Argo CD v3.5.2, lab-05 stretch state (a deny sync window configured on the team-a project), logged in as admin.
Steps: (1) log in as admin; (2) Settings ▸ Projects ▸ team-a; (3) scroll to the Sync Windows section at /settings/projects/team-a.
Capture: panel only (not full page), viewport 1440x900, light theme, PNG. Highlight the deny window row in .project-sync-windows: kind=deny, its schedule, duration, and the manualSync toggle.
Save to: courseware/assets/screenshots/day-2/s06-03-sync-window.png -->

**What to notice:**

1. **A change freeze is a row in a config file.** The window has a kind (allow/deny), a schedule, and a duration — a policy you can review in a pull request, not a tribal rule.
2. **The escape hatch is the governance-interesting field.** Whether `manualSync` is on decides *who can override the freeze* — and because the override is a recorded sync, its use is auditable.
3. **This is a stretch state, not the baseline.** The baseline `team-a` project has no window; you would add one in the Lab 5 stretch. Do not expect to see this row on a fresh reset.

---

## Transition — to Lab 5

You now have the three-fence model and the one diagnostic question that reads any denial. **Lab 5 (Enforce Platform Guardrails)** turns that model into muscle memory, and its whole shape is a **guardrail bypass attempt**: you will fence in the new `team-a` tenant, then *genuinely try to walk through the fence* and read the exact error each time. You will empty the `default` project and watch a scratch app stop syncing (hardening breaks things too — on purpose). You will trigger a **fence-2** denial (an Application pointed at a destination its project does not allow) and a **fence-3** denial (a resource the workload cluster's ServiceAccount may not create) minutes apart, and answer the question that makes it stick: *which team do you page?* You will confirm a denial with `argocd admin settings rbac can` **before** hitting it, and protect a tenant's Applications from unintended deletion. Bring the one question with you — *did anything on the cluster actually get touched?* — because Lab 5 is where you learn to trust your own answer.
