# Intermediate Argo CD Operations: Course Blueprint

| Field | Value |
|---|---|
| Document type | Internal build-planning document (not participant-facing) |
| Owner | `course-architect` (Phase 1) |
| Consumers | `insight-generator`, `environment-engineer`, `lab-engineer`, `lab-tester`, `lab-solution-engineer`, `pedagogy-reviewer`, `course-reviewer` |
| Source of truth | `argo-cd-outline.md` (scope, sequence, timing) |
| Pinned target | Argo CD **v3.5.2** via argo-helm chart **argo-cd 10.8.4**, on k3s **v1.35.8+k3s1** (Kubernetes 1.35); repo-server bundles **Helm v4.2.1** (evidence in section 12) |
| Blueprint date | 2026-09-10 |

## How to use this blueprint

- This document is decision-dense by design. It plans the course and fixes the names downstream agents must use. It is not guide prose.
- **ID conventions** used throughout (use them in guides, reviews, and solutions so traceability holds):
  - `O1`-`O8`: course learning outcomes (section 3).
  - `B<session>.<n>`: outline bullets (for example `B4.7` = Session 4, bullet 7). Lab bullets are `L<lab>.<n>`. Capstone faults are `CF1`-`CF7`; capstone "participants must" items are `CM1`-`CM5`.
  - `S<n>-QC<k>`: Quick Check `k` in the concept guide for Session `n`. `S<n>-TRY`: that guide's optional Try It Yourself micro-task.
  - `L<n>-E<k>`: exercise `k` in Lab `n`. `CAP-P<k>`: capstone phase `k`.
  - `SS-<file>-<nn>`: screenshot IDs (section 9). `V-<nn>`: diagram IDs (section 11).
  - `F1`-`F7`: capstone fault-injection units (section 8.9). `CP-<name>`: environment checkpoints (section 8.8).
  - `R-<n>`: timing/scope recommendations (section 5.3), always separate from required scope.
- Anything in this document marked **Recommendation** is advisory. Anything marked **Required** is part of the build contract.
- Instructor-facing details (fault mechanics, checkpoint contents) appear here because this is an internal planning file. They must **never** be copied into participant-facing guides.

---

## 1. Course promise

In two days, a DevOps or platform engineer who has touched Kubernetes, Helm, and Git (but may not remember every detail under pressure) learns to operate Argo CD as a reliable internal deployment platform. They leave able to:

- trace any change from a Git commit, through rendering and comparison, to a synchronized and healthy workload on a separately registered cluster;
- configure the management-cluster/workload-cluster topology with least-privilege credentials;
- scale the pattern with ApplicationSets and App-of-Apps without scaling the blast radius;
- enforce tenant guardrails with AppProjects and role-based access control (RBAC);
- restore a broken platform methodically, layer by layer, using evidence instead of guesswork.

Every hands-on minute runs on the participant's own virtual machine (VM). That VM reproduces the production shape of a dedicated Argo CD management cluster plus a registered workload cluster. The course uses Argo CD v3.5.2, the current stable release, and every UI screenshot is captured from that exact version.

---

## 2. Audience assumptions and the beginner-clarity commitment

### 2.1 Who is in the room

- DevOps, CI/CD (continuous integration / continuous delivery), and platform engineers who will host and maintain Argo CD.
- Engineers who onboard repositories, clusters, and deployment patterns.
- Engineers who troubleshoot delivery across lower and higher environments.
- A few software engineers who need Application-level depth or API integration.

### 2.2 What we assume, and what we do not

| We assume participants have... | We do **not** assume they remember... |
|---|---|
| Run `kubectl get`/`apply` against a cluster | kubeconfig contexts, `--context`, how `kubectl auth can-i --as` works |
| Seen Deployments, Services, namespaces | how ReplicaSets and Pods are owned by Deployments, readiness probes, `progressDeadlineSeconds`, HPA (Horizontal Pod Autoscaler) behavior |
| Installed a Helm chart | `helm template` vs `helm install`, values precedence, chart hooks |
| Committed and pushed with Git | `git revert` vs `git reset`, tags as immutable references, reading `git log` for audit |
| Heard of Kubernetes RBAC | ServiceAccounts, Roles vs ClusterRoles, RoleBindings, ServiceAccount tokens, the difference between authentication (401) and authorization (403) |

### 2.3 The beginner-clarity commitment (Required for every guide)

1. **Intermediate pace, assume-nothing prose.** The course moves quickly and reaches production patterns. The writing never skips a step or leaves a term unexplained.
2. **Define before use.** Every acronym is expanded on first use *in each file*. Every product term gets a one-sentence plain-language definition or analogy before it is used functionally.
3. **One idea per paragraph.** Walkthrough steps are numbered and each step does one thing.
4. **Banned phrasing:** "as you know", "obviously", "simply", "just", "trivially", "of course". Reviewers treat each occurrence as a defect.
5. **Inline refreshers, not assumptions.** When a step leans on a prerequisite, the guide includes a short refresher box. To avoid duplicating refreshers across files, each one has a single home:

| Refresher topic | Home file (full refresher) | Later files |
|---|---|---|
| kubeconfig contexts and `--context` | `lab-01` | one-line reminder |
| Git clone / commit / push / `git log` | `lab-01` | one-line reminder |
| Helm chart anatomy (Chart.yaml, values.yaml, templates) | `lab-01` (minimal), `04-helm-sync-and-promotion` (full) | recap |
| ServiceAccount, Role, RoleBinding, token Secret, 401 vs 403 | `03-production-oriented-configuration` | `lab-02` applies it; `06`, `lab-05`, capstone recap |
| Kubernetes Secrets are base64-encoded, not encrypted | `03-production-oriented-configuration` | `06` recap |
| Deployment rollout, readiness probes, `progressDeadlineSeconds` | `04-helm-sync-and-promotion` | `lab-03`, capstone |
| Labels and label selectors | `05-applicationsets-and-app-of-apps` | `lab-04` |
| Kubernetes RBAC verbs and `kubectl auth can-i` | `lab-02` (first use), `06` (full) | `lab-05` |
| HPA and why it edits `spec.replicas` | `07-reliability-troubleshooting-lifecycle` | capstone recap |
| `git revert` vs `git reset` vs moving a tag | `04-helm-sync-and-promotion` | `lab-03`, capstone |

### 2.4 Term first-use register (Required)

The file listed is where the term is **first fully defined**. Later files may recap in one sentence and link back.

| Term | First defined in |
|---|---|
| GitOps, desired state, drift, reconciliation, CI vs CD boundary, management cluster, workload cluster | `01-gitops-and-argo-cd-topology` |
| CRD (Custom Resource Definition), controller, Application, AppProject (intro), API server, repository server (repo-server), application controller, ApplicationSet controller, Redis, notifications controller, Dex, live/target/rendered state, sync status, health status, refresh, hard refresh, compare, sync, resource tracking (tracking-id annotation) | `02-architecture-and-application-model` |
| multi-tenant vs core install, HA (high availability), declarative setup, repository Secret, credential template (repo-creds), cluster Secret, least privilege, webhook, polling, `timeout.reconciliation`, `resource.respectRBAC` | `03-production-oriented-configuration` |
| `helm template` rendering, valueFiles, values precedence, pinned revision, prune, self-heal, sync options, retry, sync phase, sync wave, hook, rollback vs roll-forward, promotion | `04-helm-sync-and-promotion` |
| ApplicationSet, generator (list/cluster/git/matrix/merge), Go template, `missingkey=error`, `applicationsSync` policy, `preserveResourcesOnDeletion`, dry-run preview, progressive sync, App-of-Apps, root Application, child Application, cascading deletion, finalizer | `05-applicationsets-and-app-of-apps` |
| Argo CD RBAC, SSO (single sign-on), OIDC (OpenID Connect), group-to-role mapping, local account, project role, JWT (JSON Web Token) project token, sync window, separation of duties | `06-security-multitenancy-governance` |
| sharding, reconciliation queue, custom health check (Lua), `ignoreDifferences`, `argocd admin export/import`, compatibility matrix, internal fork | `07-reliability-troubleshooting-lifecycle` |

### 2.5 How "intermediate" shows up

- **Pace:** each lab reaches a production-realistic outcome within its allotted time.
- **Depth:** guides explain *why* a behavior exists (for example, why automated sync does not retry a failed commit), not only *what* to type.
- **Scaffolding reduction:** Labs 1-2 are maximally guided, Labs 3-5 explain every *new* concept fully but stop re-teaching mastered mechanics, and the capstone is diagnostic (section 7.3).

---

## 3. Final learning outcomes (verbatim from the outline)

| ID | By the end of the course, participants will be able to... |
|---|---|
| O1 | Explain how Argo CD continuously reconciles Git state with live Kubernetes state |
| O2 | Describe the role of each major Argo CD component and identify where failures occur |
| O3 | Configure Argo CD for a dedicated management-cluster and remote-workload-cluster model |
| O4 | Build and troubleshoot Application, ApplicationSet, and App-of-Apps structures |
| O5 | Deploy Helm applications and safely manage environment-specific configuration |
| O6 | Apply synchronization, promotion, RBAC, and AppProject guardrails |
| O7 | Diagnose repository, rendering, synchronization, health, and cluster-connectivity failures |
| O8 | Plan for high availability, monitoring, scaling, backup, recovery, upgrades, and custom builds |

**Day outcomes (verbatim):**

- **Day 1:** Participants finish Day 1 with a working Git-to-Argo-CD-to-workload-cluster deployment and a repeatable method for locating failures along that path. *Evidence:* `lab-03` checkpoint (section 6).
- **Day 2:** Participants finish Day 2 able to reason through ApplicationSets and App-of-Apps, enforce platform boundaries, and restore stable service during realistic Argo CD incidents. *Evidence:* capstone checkpoint plus written reflection (section 6).

---

## 4. Two-day narrative arc

### 4.1 The running scenario (Required, used consistently in every file)

A platform team runs Argo CD on a dedicated **management cluster** and delivers to a separately registered **workload cluster**. They serve two internal customers:

- **storefront**, a web application owned by an application team and delivered through `dev`, `staging`, and `prod` namespaces on the workload cluster.
- **team-a**, a new tenant onboarding on Day 2 who must be fenced in by guardrails.

The container image for every sample workload is `podinfo` (a small demo web server that displays a configurable message and color). A change in Git becomes visible as a new message in the application's HTTP response, which makes reconciliation observable.

### 4.2 Day 1: understand, configure, deploy

**Narrative question:** *How does one change travel from Git to a remote cluster, and where can it get stuck?*

| Beat | File | What the participant gains |
|---|---|---|
| 1 | `01-gitops-and-argo-cd-topology` | The mental model: Git is the desired state; Argo CD pulls, compares, and converges; CI stops at Git. |
| 2 | `02-architecture-and-application-model` | The machinery: which component does what, and what "Synced" and "Healthy" each actually mean. |
| 3 | `lab-01-follow-an-application-through-reconciliation` | First contact: watch one commit move through the loop on a pre-created Application. |
| 4 | `03-production-oriented-configuration` | The production shape: install choices, declarative onboarding, least-privilege cluster credentials. |
| 5 | `lab-02-configure-platform-and-register-target` | Build the topology: connect a private repo, register the workload cluster, create an AppProject and Application. |
| 6 | `04-helm-sync-and-promotion` | Delivery controls: Helm rendering, sync policies, waves and hooks, promotion, rollback trade-offs. |
| 7 | `lab-03-deploy-drift-and-recover` | Deploy, break, and recover through Git. **Day 1 outcome achieved.** |

### 4.3 Day 2: scale the pattern and operate it reliably

**Narrative question:** *How do we scale that path to many environments and teams without scaling the blast radius, and how do we restore it when it breaks?*

| Beat | File | What the participant gains |
|---|---|---|
| 8 | `05-applicationsets-and-app-of-apps` | Two scaling patterns, their ownership models, and the outline's decision table. |
| 9 | `lab-04-build-and-troubleshoot-patterns` | Generate the storefront environments, protect them, inspect a root/child tree, trace failures to their owning layer. |
| 10 | `06-security-multitenancy-governance` | Where Argo CD authorization ends and Kubernetes authorization begins. |
| 11 | `lab-05-enforce-platform-guardrails` | Fence in team-a and feel each denial layer. |
| 12 | `07-reliability-troubleshooting-lifecycle` | The six-step troubleshooting method, plus HA, scale, observability, backup, upgrades. |
| 13 | `capstone-restore-platform` | A connected, seven-fault incident, restored with evidence and a written reflection. **Day 2 outcome achieved.** |

### 4.4 Recurring anchors (retrieval by design)

- **V-02 reconciliation loop** (Git change, render, compare, synchronize, health assessment) first appears in `01`, is annotated in `02`, is walked live in `lab-01`, is used to localize failures in `lab-02`/`lab-03`, is extended to generators in `05`, and becomes the spine of the troubleshooting method in `07` and the capstone.
- **Sync status vs health status** is taught in `02` and resurfaces in `lab-01` (E4), `lab-02` (OutOfSync does not mean broken), `lab-03` (drift), `lab-04` (root Healthy while child broken), and the capstone (fault F6: noisy OutOfSync hiding a real Degraded workload).
- **The troubleshooting method** (outline Session 7) is seeded before it is named: `lab-01` locates status in three places, `lab-02` diagnoses onboarding failures, `lab-03` diagnoses rendering and ordering failures, `lab-04` traces ownership, and `lab-05` separates authorization layers. `07` then formalizes the six steps, and the capstone applies them.
- **The decision table** (outline Session 5) anchors `05`, is used as the rubric for `lab-04` E6, and reappears in capstone reflection prompts.

---

## 5. Time allocation by session, validated against the outline

### 5.1 Totals (Required: unchanged from the outline)

| Day | Concept minutes | Lab minutes | Total instructional minutes |
|---|---|---|---|
| Day 1 | 45 + 60 + 60 + 60 = **225** | 45 + 60 + 60 = **165** | **390** |
| Day 2 | 60 + 45 + 75 = **180** | 75 + 45 + 90 = **210** | **390** |
| Course | **405 (52%)** | **375 (48%)** | **780** |

The split matches the outline's "approximately 50% guided instruction and 50% hands-on." A suggested day frame (**Recommendation**, not scope): 09:00-17:00 with a 60-minute lunch and two 15-minute breaks, which leaves exactly 390 instructional minutes. Breaks are not part of any session's minutes.

### 5.2 Per-file budget and realism verdict

Budgets include explanation, screenshot orientation, guided practice, Quick Checks or exercises, and debrief. A concept guide's Try It Yourself is optional and sits **outside** the timebox unless a budget below says otherwise.

| # | File | Outline min | Internal budget (minutes) | Verdict |
|---|---|---|---|---|
| 1 | `01-gitops-and-argo-cd-topology` | 45 | Why it matters 5, mental model and topology 10, CI/CD boundary plus Argo Workflows comparison 8, team responsibilities 5, full-flow walkthrough 8, Quick Checks 4, takeaways/transition 5 | **KEEP.** Realistic. Keep the Workflows comparison to one table plus two paragraphs. |
| 2 | `02-architecture-and-application-model` | 60 | Components 12, four states 8, sync vs health 8, Application anatomy 10, credentials/tracking/ownership 8, refresh/compare/sync operations 6, status-cause reference table 4, Quick Checks 4 | **AT CAPACITY.** Apply R-1. |
| 3 | `lab-01-follow-an-application-through-reconciliation` | 45 | Environment check and login 5, guided walkthrough 9, E1 4, E2 15, E3 6, E4 4, checkpoint/debrief 2 | **TIGHT.** Relies on a pre-created Application, the 60 s reconciliation interval, and a credentials file on the VM. E2 grew from 10 to 15 minutes when it gained its diagnose-and-fix cycle (a message-only sync does not restart the Pod; participants add a `checksum/config` annotation in Git). The 5 minutes come from environment check (−2), walkthrough (−1), E1 (−1), and E3 (−1). **Recommendation:** if a cohort runs long, run E4 as a whole-class table. |
| 4 | `03-production-oriented-configuration` | 60 | Install models 8, standard vs HA (narrated instructor demo) 12, Helm install plus declarative self-management 8, namespace/ingress/TLS/DNS/initial-access checklist 6, declarative onboarding plus least privilege 10, webhooks vs polling 5, Rancher/RKE2 mapping 5, Git vs injected configuration 4, Quick Checks 2 | **OVERLOADED.** Apply R-2. |
| 5 | `lab-02-configure-platform-and-register-target` | 60 | Environment check 3, E1 10, E2 17, E3 8, E4 12, E5 8, checkpoint 2 | **TIGHT, HIGH RISK.** Provide the workload-side RBAC manifest and Application/AppProject skeletons. Apply R-7. |
| 6 | `04-helm-sync-and-promotion` | 60 | Helm rendering 8, sources/pins/values/precedence 8, repo layouts 5, Kustomize sidebar 3, manual vs automated 5, prune/self-heal/retry/timeouts/options 8, phases/waves/hooks 10, promotion 5, rollback trade-offs 4, guardrails 4 (Quick Checks folded into sections) | **OVERLOADED.** Apply R-3. |
| 7 | `lab-03-deploy-drift-and-recover` | 60 | Environment check 2, E1 10, E2 10, E3 8, E4 12, E5 15, checkpoint 3 | **REALISTIC, TIGHT.** Stretch work is outside the timebox. |
| 8 | `05-applicationsets-and-app-of-apps` | 60 | AppSet ownership 8, generators 12, Go templating 6, targeting 5, create/update/delete controls 5, blast radius plus preview 6, version-dependent features box 3, App-of-Apps 10, decision table 3, Quick Checks 2 | **OVERLOADED.** Apply R-4. |
| 9 | `lab-04-build-and-troubleshoot-patterns` | 75 | Environment check 3, guided preview workflow 5, E1 15, E2 8, E3 8, E4 10, E5 14, E6 10, checkpoint 2 | **TIGHT.** The App-of-Apps root and children are pre-staged in Git; participants inspect and trace them rather than author them. |
| 10 | `06-security-multitenancy-governance` | 45 | AppProjects 8, Argo CD RBAC vs Kubernetes RBAC 7, SSO and admin removal 6, least-privilege credentials recap 3, separation of duties 4, secrets 6, API accounts/tokens 4, audit/windows/higher environments 4, security of self-service AppSets 3 | **OVERLOADED.** Apply R-5. |
| 11 | `lab-05-enforce-platform-guardrails` | 45 | Environment check 2, E1 10, E2 5, E3 8, E4 12, E5 6, checkpoint 2 | **TIGHT.** team-a repo, local account, and denial "attempt" manifests are pre-staged. |
| 12 | `07-reliability-troubleshooting-lifecycle` | 75 | Six-step method 20, HA and component failure 8, controller load/sharding 7, repo-server pressure 6, webhook/reconcile behavior 3, metrics/alerts/notifications 8, health/diff customization and ignore rules 8, capacity factors 3, backup/recovery/export 6, upgrades/version matching 4, internal fork 2 | **OVERLOADED.** Apply R-6. |
| 13 | `capstone-restore-platform` | 90 | P0 orientation 10, P1 triage (no changes) 15, P2 restore 50, P3 verify 5, P4 written reflection 10 | **TIGHT.** Seven faults in 50 minutes is about 7 minutes each. Apply R-9. |

### 5.3 Timing and scope recommendations (Recommendation, separate from required scope)

No outline objective or bullet is removed, and no session changes its minutes. Every recommendation below changes **depth or delivery mode** only.

| ID | Label | Recommendation | Reason |
|---|---|---|---|
| R-1 | SHORTEN | In `02`, introduce repository and cluster credentials only as "external dependencies of an Application" (what they are and where they live). Defer mechanics (Secret format, least privilege) to `03`/`lab-02`. Present the OutOfSync/Unknown/Progressing/Degraded causes as a reference table that `lab-01`, `lab-03`, and `07` revisit. | Seven dense bullets in 60 minutes. |
| R-2 | SHORTEN | In `03`, render namespace/ingress/TLS/DNS/initial access as a decision checklist table. Deliver the instructor's installation and HA demonstration as a **narrated walkthrough with captured real output** from the instructor VM's `ha-demo` cluster, which the instructor may also run live. Least-privilege registration is explained conceptually here and practiced in `lab-02`. | Nine bullets plus an instructor demo in 60 minutes. |
| R-3 | SHORTEN | In `04`, make Kustomize a 3-minute sidebar with one inline example and no hands-on work. Put retries/timeouts/sync options in a reference table. Cover cross-environment guardrails briefly and forward-reference `06` (AppProjects). | Ten bullets in 60 minutes. |
| R-4 | SHORTEN | In `05`, teach list, cluster, git, matrix, and merge generators (the outline's five). Mention SCM Provider, Pull Request, Cluster Decision Resource, and Plugin generators in a one-row "exists, out of scope" note. Present progressive sync as a boxed "version-dependent feature" (Beta since v3.3.0; forces autosync off on generated Applications), with no hands-on dependency. | Thirteen bullets plus a table in 60 minutes. |
| R-5 | SHORTEN | In `06`, keep SSO conceptual: a diagram of IdP (identity provider) groups mapped to Argo CD roles. The lab environment simulates groups with **local accounts** (no IdP). Least-privilege credentials become a 3-minute recap of `03`/`lab-02`. | Nine bullets in 45 minutes. No IdP in the environment. |
| R-6 | SHORTEN / OPTIONAL | In `07`, present the internal-fork bullet as a checklist and capacity factors as a table. The management-cluster-loss recovery is a narrated walkthrough; an **OPTIONAL** live instructor demo runs on the instructor VM. | Twenty bullets in 75 minutes. |
| R-7 | OPTIONAL | In `lab-02`, E5 (diagnose two broken onboarding records): the first record is required and the second is optional. Gitea-to-Argo CD webhook configuration is a **stretch**, and its compatibility is only partly verified (section 12). | Protects the 60-minute budget and avoids a partly verified dependency. |
| R-8 | MOVE (de-duplicate) | The outline has "protect generated Applications from unintended deletion" in both Lab 4 and Lab 5. Split it: **`lab-04` E3** = ApplicationSet-level protection (`applicationsSync: create-update`, `preserveResourcesOnDeletion`). **`lab-05` E5** = governance-level protection (Argo CD RBAC denying `applications, delete` to team roles, plus the finalizer/cascade explanation). A controller-wide `policy` lock is a `lab-05` stretch. | Removes duplication, and both bullets keep distinct evidence. |
| R-9 | KEEP with structure | Keep all seven capstone faults, injected at once as a *connected* incident. Provide `capstone-check` (per-fault resolved/unresolved without hints) and an instructor per-fault revert. Minimum completion bar: failure layer correctly identified for all seven faults, at least five restored, and a reflection written for all seven. | Seven faults in 50 minutes of repair time is ambitious. |
| R-10 | KEEP | Keep Session 1 and Session 2 as **separate** concept guides. S1 (45 min) is about purpose, boundaries, and topology. S2 (60 min) is about machinery. Each has enough independent content, and merging would produce a 105-minute guide that violates the one-idea-at-a-time bar. Both feed `lab-01`. | The agent definition allows either choice. This is the reasoning. |

**Explicitly not recommended:** no CUT is proposed. Scope items deliberately **not** added: a Prometheus/Grafana stack per VM (metrics are read from component endpoints and `kubectl top`), a real SSO IdP, a Rancher install, Source Hydrator, and Argo Rollouts. Each would add scope the outline does not ask for.

---

## 6. Objective-to-evidence map

### 6.1 Outcomes to evidence

| Outcome | Taught in | Practiced in | Proven by (checkable evidence) | Retrieved later in |
|---|---|---|---|---|
| O1 Reconciliation | `01` (V-02), `02` (V-06) | `lab-01` E2, E3 | `lab-01` checkpoint: live revision equals `git rev-parse HEAD`, and the participant's written prediction vs observation table | `lab-03` E3/E4 (drift, self-heal), `07` method, capstone P1 |
| O2 Components and failure locations | `02` (V-05) | `lab-01` E4, `S2-TRY` | `S2-QC2` (symptom to component); `lab-01` E4 three-way status table | `07` (V-26), capstone F5/F7 triage grid |
| O3 Management/workload configuration | `03` (V-10, V-11, V-13) | `lab-02` E1-E3 | `lab-02` checkpoint: repo `Successful`, cluster `Successful`, the `kubectl auth can-i` matrix matches the least-privilege design | `06` recap, capstone F4/F5 |
| O4 Application, ApplicationSet, App-of-Apps | `02`, `05` (V-19, V-20, V-21) | `lab-02` E4, `lab-04` E1-E6 | `lab-04` checkpoint: three generated Applications Synced/Healthy, root tree traced, E5 trace table complete | capstone F2/F3 |
| O5 Helm and environment configuration | `04` (V-14, V-15, V-18) | `lab-03` E1/E2, `lab-04` E1 | `lab-03` checkpoint: dev and staging render different values; `helm list` on the workload shows no release (the participant explains why) | capstone F1/F6 |
| O6 Sync, promotion, RBAC, AppProject guardrails | `04`, `06` (V-22) | `lab-02` E4, `lab-03` E4, `lab-04` E3, `lab-05` E1-E5 | `lab-03` E4 (self-heal observed), `lab-04` E3 (protected Application survives), `lab-05` checkpoint (denials land in the predicted layer) | capstone F2/F4 reflections |
| O7 Diagnose repo/render/sync/health/connectivity failures | `02` status table, `07` (V-25) | `lab-02` E5, `lab-03` E5, `lab-04` E5, `lab-05` E4 | Capstone P1 triage grid (layer per symptom *before* changes) plus `capstone-check` all resolved | n/a (culminating) |
| O8 HA, monitoring, scale, backup, recovery, upgrades, custom builds | `03` (HA), `07` (V-26 to V-29) | `S3-TRY`, `S7-TRY` | `S7-QC2`/`S7-QC4`; capstone reflection for F7 (monitoring/alert change) | n/a |

### 6.2 Outline bullet traceability (Required: no bullet may be orphaned)

"Evidence" means the specific Quick Check, exercise, or checkpoint that proves the bullet was learned. File names are abbreviated (`01` = `day-1/01-gitops-and-argo-cd-topology.md`; see section 7 for full paths).

**Session 1: GitOps and the Argo CD topology → `01`**

| ID | Outline bullet | Where taught | Evidence |
|---|---|---|---|
| B1.1 | Git as desired-state source and audit trail | `01` mental model plus walkthrough | `S1-TRY` (read `git log` and the Gitea commits page); retrieved in `lab-01` E2 |
| B1.2 | Continuous reconciliation, drift detection, declarative recovery | `01` V-02, V-17 preview | `S1-QC1`; practiced in `lab-03` E3/E4 |
| B1.3 | CI vs Argo CD division of responsibility | `01` V-03 | `S1-QC1` |
| B1.4 | Argo CD compared with Argo Workflows | `01` V-04 (the only place Workflows appears) | `S1-QC4` |
| B1.5 | Production topology: management and registered workload clusters | `01` V-01 (with lab-mapping overlay) | `S1-QC2`; practiced in `lab-02` E2 |
| B1.6 | Platform-team vs application-team responsibilities | `01` responsibility table | `S1-QC2`; retrieved in `06`, `lab-05` E1 |
| B1.7 | Complete flow: Git change → render → compare → synchronize → health | `01` V-02 walkthrough | `S1-QC3`; practiced in `lab-01` E2 |
| KO1 | Key outcome: what Argo CD owns and does not own | `01` takeaways | `S1-QC2` |

**Session 2: Architecture and the Application model → `02`**

| ID | Outline bullet | Where taught | Evidence |
|---|---|---|---|
| B2.1 | API server, application controller, repo-server, ApplicationSet controller, Redis, supporting components | `02` V-05 | `S2-QC2`, `S2-TRY`; `lab-01` E4 |
| B2.2 | Desired, live, target state, rendered manifests | `02` V-06 | `lab-01` E3 |
| B2.3 | Sync status vs health status | `02` V-07 | `S2-QC1`; `lab-01` E4; capstone F6 |
| B2.4 | Application resource: source, revision, path/chart, destination, project, sync policy | `02` V-08 | `lab-01` E1; `lab-02` E4 |
| B2.5 | Repository credentials, cluster credentials, resource tracking, ownership | `02` vocabulary plus V-09 (credentials introduced only, per R-1) | `lab-01` E1 (identify the credentials dependency), `lab-01` E3 (find the `argocd.argoproj.io/tracking-id` annotation) |
| B2.6 | Refresh, compare, reconcile, synchronize operations | `02` walkthrough | `S2-QC3`; `lab-01` E2 |
| B2.7 | Common causes of OutOfSync, Unknown, Progressing, Degraded | `02` reference table | `S2-QC1`; `lab-01` stretch; `lab-03` E3/E5; capstone |

**Lab 1 → `lab-01`**

| ID | Outline bullet | Evidence |
|---|---|---|
| L1.1 | Inspect an Application manifest and identify every external dependency | `lab-01` E1 |
| L1.2 | Commit a small change and observe the reconciliation flow | `lab-01` E2 |
| L1.3 | Compare desired, rendered, and live resources | `lab-01` E3 |
| L1.4 | Use the UI, CLI, and Kubernetes resources to locate status and events | `lab-01` guided steps plus E4 |

**Session 3: Production-oriented configuration → `03`**

| ID | Outline bullet | Where taught | Evidence |
|---|---|---|---|
| B3.1 | Multi-tenant vs core install, and why multi-tenant fits | `03` V-10 | `S3-QC1` |
| B3.2 | Standard vs HA install choices | `03` V-10 plus narrated HA walkthrough | `S3-TRY` (`helm template` diff of HA values); retrieved in `07` |
| B3.3 | Helm-based installation and declarative management of Argo CD itself | `03` walkthrough (values in `platform-config/argocd/values.yaml`, applied by `apply-argocd-config`) | Used in `lab-05` E4/E5 and capstone F7 |
| B3.4 | Namespace, ingress, TLS, DNS, initial access | `03` checklist table (R-2) | `S3-QC1` (scenario includes access choice) |
| B3.5 | Declarative repository and cluster onboarding | `03` walkthrough | `lab-02` E1/E2 |
| B3.6 | Remote cluster registration with least-privilege credentials | `03` V-11 | `S3-QC4`; `lab-02` E2/E3 |
| B3.7 | Webhooks vs polling and network implications | `03` V-12 | `S3-QC3`; `lab-02` stretch |
| B3.8 | Rancher/RKE2 considerations; separating management and workload clusters | `03` section plus V-01 mapping | `S3-QC2` |
| B3.9 | Configuration in Git vs injected securely | `03` V-13 | `S3-QC2`; `lab-02` E1 (credential injected from a file, never committed) |
| B3.D | Instructor demonstrates installation and HA | `03` narrated walkthrough (captured from the instructor VM `ha-demo` cluster) | n/a (demonstration) |

**Lab 2 → `lab-02`**

| ID | Outline bullet | Evidence |
|---|---|---|
| L2.1 | Connect a prepared Git repository | `lab-02` E1 |
| L2.2 | Register a separate workload cluster | `lab-02` E2 |
| L2.3 | Verify repository and cluster connectivity | `lab-02` E1/E2 checks, E3, E5 |
| L2.4 | Create a basic AppProject and Application declaratively | `lab-02` E4 |
| L2.5 | Confirm Argo CD can render and compare the target application | `lab-02` checkpoint (OutOfSync plus Missing, with a diff showing all resources as new) |

**Session 4: Helm deployments, synchronization, promotion → `04`**

| ID | Outline bullet | Where taught | Evidence |
|---|---|---|---|
| B4.1 | Argo CD uses Helm to render, not to manage a release lifecycle | `04` V-14 plus misconception | `lab-03` E1 (predict, then run `helm list -A` on the workload: no release) |
| B4.2 | Chart sources, pinned revisions, values files, parameters, overrides | `04` V-14 precedence ladder | `S4-QC3`; `lab-03` E2; `lab-04` E1 (prod pinned to a tag) |
| B4.3 | Repository-layout options for reusable Helm deployments | `04` V-15 | `S4-TRY`; `lab-04` E6 reasoning |
| B4.4 | Where Kustomize complements Helm without unclear ownership | `04` sidebar (R-3) | `S4-QC4` |
| B4.5 | Manual vs automated synchronization | `04` | `lab-03` E3/E4 |
| B4.6 | Pruning, self-healing, retries, timeouts, safe sync options | `04` reference table | `S4-QC1`; `lab-03` E4; `lab-03` stretch (retry) |
| B4.7 | Sync phases, waves, hooks, resource ordering | `04` V-16 | `S4-QC2`; `lab-03` E1 (observe), E5 part B (ordering failure) |
| B4.8 | Promotion through Git across environments | `04` V-18 | `lab-03` E2 (promote a tag from dev values to staging values) |
| B4.9 | Roll-forward, rollback, recovery trade-offs | `04` trade-off table | `lab-03` E5 (justify revert vs roll-forward); `lab-03` stretch (rollback blocked under auto-sync) |
| B4.10 | Guardrails against accidental pruning, cross-env deployment, mutable revisions | `04` | `lab-03` E4 (prune left off; `Prune=false` on one resource), `lab-02` E4 (AppProject destinations), `lab-04` E1 (tag-pinned prod) |

**Lab 3 → `lab-03`**

| ID | Outline bullet | Evidence |
|---|---|---|
| L3.1 | Deploy a Helm-based application to the registered workload cluster | `lab-03` E1 |
| L3.2 | Apply an environment-specific values file | `lab-03` E2 |
| L3.3 | Introduce live drift and observe Argo CD's response | `lab-03` E3 |
| L3.4 | Configure safe automated sync and self-healing | `lab-03` E4 |
| L3.5 | Introduce a rendering or ordering failure and recover through Git | `lab-03` E5 (part A rendering, required; part B ordering, required) |
| DO1 | Day 1 outcome | `lab-03` checkpoint |

**Session 5: ApplicationSets and App-of-Apps → `05`**

| ID | Outline bullet | Where taught | Evidence |
|---|---|---|---|
| B5.1 | How an ApplicationSet generates and owns Applications | `05` V-19 | `S5-QC1`; `lab-04` E1 |
| B5.2 | List, cluster, Git, matrix, merge generators | `05` generator table plus examples | `S5-TRY` (list, dry-run); `lab-04` E1 (matrix of cluster and git files); merge in `lab-04` stretch |
| B5.3 | Go templating and failing safely on missing values | `05` | `S5-QC2`; `lab-04` E5 part A |
| B5.4 | Multi-cluster and multi-environment targeting | `05` | `lab-04` E1/E2 |
| B5.5 | Controlling whether generated Applications may be created/updated/deleted | `05` | `lab-04` E3 (per R-8); `lab-05` stretch (controller-wide policy) |
| B5.6 | Reducing blast radius of generator/template changes | `05` | `lab-04` E2 (preview before apply); capstone F2 |
| B5.7 | Previewing generated output before rollout | `05` (CLI `--dry-run`, stable; UI Preview tab, Alpha) | `S5-TRY`; `lab-04` guided preview plus E2 |
| B5.8 | Version-dependent features (progressive sync) and when not to depend on them | `05` boxed note (R-4) | `S5-QC1` distractor; capstone F2 reflection prompt |
| B5.9 | Root and child Applications and ownership flow | `05` V-20 | `S5-QC4`; `lab-04` E4 |
| B5.10 | Repository organization, naming, responsibility boundaries | `05` | `lab-04` E4 (trace each child to its repo), E6 |
| B5.11 | Ordering, pruning, cascading deletion, circular dependency risks | `05` | `S5-QC4`; `lab-04` E4 (what cascade would delete); capstone F3 (remove the extra root without cascade) |
| B5.12 | Why multiple roots are hard to reason about | `05` | capstone F3 |
| B5.13 | Tracing failures from root to repository and child resource | `05` worked walkthrough | `lab-04` E5 part B |
| B5.14 | Choosing the right pattern (decision table) | `05` V-21 (outline table reused verbatim) | `S5-QC3`; `lab-04` E6 |

**Lab 4 → `lab-04`**

| ID | Outline bullet | Evidence |
|---|---|---|
| L4.1 | Generate Helm Applications for multiple target environments | `lab-04` E1 |
| L4.2 | Use labels and cluster data to control placement | `lab-04` E2 |
| L4.3 | Apply a protection policy that limits unintended Application deletion | `lab-04` E3 |
| L4.4 | Inspect a root and child Application hierarchy | `lab-04` E4 |
| L4.5 | Introduce a template or child-application error and trace it to the owning layer | `lab-04` E5 (both) |
| L4.6 | Compare the operational impact of each pattern for the same scenario | `lab-04` E6 |

**Session 6: Security, multi-tenancy, governance → `06`**

| ID | Outline bullet | Where taught | Evidence |
|---|---|---|---|
| B6.1 | AppProjects as boundaries (sources, destinations, namespaces, kinds) | `06` V-22 | `S6-QC1`; `lab-05` E1-E3 |
| B6.2 | Argo CD RBAC vs Kubernetes RBAC | `06` V-22 | `S6-QC1`; `lab-05` E4 |
| B6.3 | SSO concepts, group-to-role mapping, removing routine admin access | `06` V-23 (conceptual, R-5) | `S6-QC3`; `lab-05` E4 (local account mapped to a role stands in for a group) |
| B6.4 | Least-privilege repository and workload-cluster credentials | `06` recap | `lab-02` E3 evidence (retrieved); `S6-QC1` |
| B6.5 | Separation of duties between platform and application teams | `06` duty table | `lab-05` E1 (who owns the project), E5 |
| B6.6 | Managing secrets without plaintext in Git | `06` V-24 | `S6-QC3`; `lab-02` E1 (retrieved) |
| B6.7 | API accounts and tokens for approved automation | `06` | `lab-05` stretch (project-role token scoped to one project) |
| B6.8 | Auditability, deployment windows, higher-environment controls | `06` | `lab-05` stretch (deny sync window); SS-S6-03 |
| B6.9 | Security implications of letting teams create Applications/ApplicationSets | `06` | `S6-QC2` |

**Lab 5 → `lab-05`**

| ID | Outline bullet | Evidence |
|---|---|---|
| L5.1 | Create a restricted AppProject | `lab-05` E1 |
| L5.2 | Permit an approved source, namespace, and workload cluster | `lab-05` E2 |
| L5.3 | Block an unauthorized destination and a cluster-scoped resource | `lab-05` E3 |
| L5.4 | Compare an Argo CD authorization failure with a Kubernetes authorization failure | `lab-05` E4 |
| L5.5 | Protect generated Applications from unintended deletion | `lab-05` E5 (per R-8) |

**Session 7: Reliability, troubleshooting, lifecycle → `07`**

| ID | Outline bullet | Where taught | Evidence |
|---|---|---|---|
| B7.M1 to B7.M6 | Six-step method (Git source/revision; repo access and rendering; rendered vs live; sync results/hooks/events/health; responsible component and metrics; correct declaratively and verify) | `07` V-25 flowchart plus a worked incident | `S7-QC1`; capstone P1/P2 |
| B7.S1 | HA architecture and component failure behavior | `07` V-26 | `S7-QC2` |
| B7.S2 | Application-controller load, cluster sharding, reconciliation queues | `07` V-27 | `S7-QC2`; capstone F7 reflection |
| B7.S3 | Repo-server memory, disk, concurrency, timeouts, monorepo pressure | `07` | capstone F7 |
| B7.S4 | Webhook and reconciliation behavior | `07` (recaps `03` V-12) | `S7-QC1` scenario |
| B7.S5 | Prometheus metrics, dashboards, alerts, events, notifications | `07` | `S7-TRY` alternative (read a metrics endpoint); capstone reflection (every fault asks for an alert) |
| B7.S6 | Custom health checks, diff customizations, reconcile optimizations | `07` | `lab-04` stretch (Application health Lua); capstone F6 |
| B7.S7 | Avoiding ignore rules that conceal meaningful drift | `07` | `S7-QC3`; capstone F6 (narrow vs broad `ignoreDifferences`) |
| B7.S8 | Capacity factors | `07` table (R-6) | `S7-QC2` |
| B7.B1 | Kubernetes resources as persistent configuration; Redis as disposable cache | `07` | `S7-QC2` |
| B7.B2 | Declarative configuration plus `argocd admin export`/`import` | `07` | `S7-TRY` |
| B7.B3 | Recovery when the management cluster is lost | `07` V-28 narrated walkthrough (OPTIONAL live instructor demo) | `S7-QC2` |
| B7.B4 | Upgrade planning, release notes, compatibility testing, rollback criteria | `07` V-29 (Helm 4 rendering case study) | `S7-QC4` |
| B7.B5 | Matching Argo CD and Kubernetes/RKE2 versions | `07` (tested-versions table) | `S7-QC4` |
| B7.B6 | Operating an internal fork (upstream tracking, CVE response, provenance, regression tests, cadence, divergence) | `07` checklist (R-6) | `S7-QC4` |

**Capstone → `capstone-restore-platform`**

| ID | Outline item | Evidence |
|---|---|---|
| CF1 | Broken Helm values reference or rendering error | F1; per-fault checkpoint; reflection |
| CF2 | ApplicationSet change with an unexpectedly large blast radius | F2; per-fault checkpoint; reflection |
| CF3 | Root or child Application ownership problem | F3; per-fault checkpoint; reflection |
| CF4 | AppProject or Kubernetes RBAC denial | F4 (Kubernetes RBAC) plus the AppProject denial surfaced by F2; reflection |
| CF5 | Disconnected workload cluster | F5; per-fault checkpoint; reflection |
| CF6 | Degraded workload combined with noisy or misleading drift | F6; per-fault checkpoint; reflection |
| CF7 | Argo CD component under resource pressure | F7; per-fault checkpoint; reflection |
| CM1 | Identify the failure layer without uncontrolled changes | CAP-P1 triage grid (checkpoint C1, completed before any change) |
| CM2 | Use Argo CD and Kubernetes evidence to determine root cause | Evidence log column in the triage grid |
| CM3 | Repair desired state or platform configuration | CAP-P2 (all repairs via Git or declarative platform config) |
| CM4 | Verify reconciliation, synchronization, application health | CAP-P3 `capstone-check` plus final-state checkpoint (SS-CAP-02) |
| CM5 | Explain the guardrail or monitoring change that prevents recurrence | CAP-P4 written reflection (Markdown answers, one per fault) |
| DO2 | Day 2 outcome | Capstone checkpoint plus reflection |

**Course design assumptions.** "Kustomize where currently used" maps to B4.4. "Rancher/RKE2" maps to B3.8 and V-01. "Class size up to 20" maps to section 8.10. "50/50 delivery" maps to section 5.1.

---

## 7. Guide file map

### 7.1 Summary (13 participant files, in delivery order)

Scaffolding levels: **G1** = maximal (exact clicks and commands, screenshot at every meaningful step, "you should now see X" after each). **G2** = reduced (new concepts fully explained; mastered mechanics not re-taught; participants produce commands or manifests before any reveal). **G3** = diagnostic (method fully explained; no fault-specific answers). **C** = concept guide.

| # | Path | Covers | Type | Level | Min | Objectives | Starts at | Leaves behind |
|---|---|---|---|---|---|---|---|---|
| 1 | `courseware/day-1/01-gitops-and-argo-cd-topology.md` | Session 1 | Concept | C | 45 | O1, O3 (intro) | CP-baseline | no change |
| 2 | `courseware/day-1/02-architecture-and-application-model.md` | Session 2 | Concept | C | 60 | O1, O2, O4 (intro) | CP-baseline | no change |
| 3 | `courseware/day-1/lab-01-follow-an-application-through-reconciliation.md` | Lab 1 | Lab | G1 | 45 | O1, O2, O7 | CP-lab-01 | extra commits in `hello-reconcile` (harmless) |
| 4 | `courseware/day-1/03-production-oriented-configuration.md` | Session 3 | Concept | C | 60 | O3, O8 | any | no change |
| 5 | `courseware/day-1/lab-02-configure-platform-and-register-target.md` | Lab 2 | Lab | G1 | 60 | O3, O4, O7 | CP-lab-02 | = CP-lab-03 |
| 6 | `courseware/day-1/04-helm-sync-and-promotion.md` | Session 4 | Concept | C | 60 | O5, O6 | any | no change |
| 7 | `courseware/day-1/lab-03-deploy-drift-and-recover.md` | Lab 3 | Lab | G2 | 60 | O5, O6, O7, O1 | CP-lab-03 | Day 1 end state (dev and staging Synced/Healthy) |
| 8 | `courseware/day-2/05-applicationsets-and-app-of-apps.md` | Session 5 | Concept | C | 60 | O4 | CP-lab-04 | no change |
| 9 | `courseware/day-2/lab-04-build-and-troubleshoot-patterns.md` | Lab 4 | Lab | G2 | 75 | O4, O5, O6, O7 | CP-lab-04 | = CP-lab-05 |
| 10 | `courseware/day-2/06-security-multitenancy-governance.md` | Session 6 | Concept | C | 45 | O6 | any | no change |
| 11 | `courseware/day-2/lab-05-enforce-platform-guardrails.md` | Lab 5 | Lab | G2 | 45 | O6, O7 | CP-lab-05 | = CP-capstone (before faults) |
| 12 | `courseware/day-2/07-reliability-troubleshooting-lifecycle.md` | Session 7 | Concept | C | 75 | O2, O7, O8 | any | no change (Try It is read-only) |
| 13 | `courseware/day-2/capstone-restore-platform.md` | Capstone | Lab (capstone) | G3 | 90 | O1-O8 (O7 primary) | CP-capstone plus `inject-capstone-faults.sh inject all` | CP-capstone-restored |

**Solution files** (owned by `lab-solution-engineer`, written after the lab guide passes `lab-tester`):

| Lab guide | Solution file |
|---|---|
| `day-1/lab-01-...` | `courseware/solutions/day-1/lab-01-follow-an-application-through-reconciliation-SOLUTION.md` |
| `day-1/lab-02-...` | `courseware/solutions/day-1/lab-02-configure-platform-and-register-target-SOLUTION.md` |
| `day-1/lab-03-...` | `courseware/solutions/day-1/lab-03-deploy-drift-and-recover-SOLUTION.md` |
| `day-2/lab-04-...` | `courseware/solutions/day-2/lab-04-build-and-troubleshoot-patterns-SOLUTION.md` |
| `day-2/lab-05-...` | `courseware/solutions/day-2/lab-05-enforce-platform-guardrails-SOLUTION.md` |
| `day-2/capstone-restore-platform.md` | `courseware/solutions/day-2/capstone-restore-platform-SOLUTION.md` |

**Documented deviation:** the canonical tree lists `solutions/capstone-restore-platform-SOLUTION.md` at the solutions root. `CLAUDE.md` requires solutions to *mirror the guide's path*. The capstone guide lives in `day-2/`, so its solution lives in `solutions/day-2/`.

**Concept guides get no solution file.** Quick Check answers are answered inline in the guide itself, as the contract requires.

### 7.2 Concept guide cards

Each concept guide follows the contract order: Why this matters, mental model, vocabulary, visual, worked walkthrough, Quick Checks (2-4, answered inline), Try It Yourself (optional), misconceptions, takeaways, transition.

**`01-gitops-and-argo-cd-topology`** (45 min)
- *Opening scenario:* a hotfix was applied with `kubectl edit` at 2 a.m. and silently reverted the next morning. Who was right, the engineer or the platform?
- *Visuals:* V-01, V-02, V-03, V-04. *Screenshots:* SS-S1-01, SS-S1-02.
- *Quick Checks:* S1-QC1 (a CI job pushes a new image tag commit; predict who deploys it and when). S1-QC2 (sort ten duties into Argo CD / CI / platform team / app team). S1-QC3 (order the five flow stages and name the evidence each leaves). S1-QC4 (classify three scenarios as Argo CD or Argo Workflows).
- *Try It:* `git log --oneline` in the `hello-reconcile` clone plus the Gitea commits page. Find who changed what and when.
- *Misconceptions:* "Argo CD is a CI tool"; "GitOps means pushing to the cluster from the pipeline"; "Argo CD and Argo Workflows are the same product."
- *Environment dependency:* VM reachable, Gitea up (CP-baseline). No state change.

**`02-architecture-and-application-model`** (60 min)
- *Opening scenario:* the dashboard shows "Synced" but users report errors. How can both be true?
- *Visuals:* V-05, V-06, V-07, V-08, V-09. *Screenshots:* SS-S2-01 to SS-S2-03.
- *Quick Checks:* S2-QC1 (interpret four sync/health pairs, including Synced+Degraded and OutOfSync+Healthy). S2-QC2 (given a symptom such as "every Application shows ComparisonError at once", name the component to inspect first). S2-QC3 (refresh vs hard refresh vs sync: which changes the cluster?). S2-QC4 (why the live `status:` block never makes an Application OutOfSync).
- *Try It:* `kubectl --context k3d-mgmt -n argocd get pods` and map each pod to V-05. Then read `.status.sync.status` and `.status.health.status` from `hello-reconcile` with `kubectl`.
- *Misconceptions:* "OutOfSync means broken"; "Healthy means Synced"; "Argo CD stores state in its own database" (it stores configuration as Kubernetes resources, and Redis is a cache); "refresh deploys."
- *Note:* resource-level health is not persisted in the Application CR by default since 3.0, while Application-level health is (section 12, row EV-19). Guides must say where each value lives.

**`03-production-oriented-configuration`** (60 min)
- *Opening scenario:* a security review finds that Argo CD's workload-cluster credential is `cluster-admin`. What should it be?
- *Visuals:* V-01 (lab-to-Rancher mapping overlay), V-10, V-11, V-12, V-13. *Screenshots:* SS-S3-01, SS-S3-02.
- *Worked walkthrough:* (a) Helm install of Argo CD from the vendored chart with the course values file; (b) narrated HA install on the instructor `ha-demo` cluster (three nodes, required by pod anti-affinity) with real captured `kubectl get pods` output; (c) the anatomy of a repository Secret, a credential template, and a cluster Secret (`namespaces`, `clusterResources: false`).
- *Quick Checks:* S3-QC1 (choose install type and access method for a scenario). S3-QC2 (sort configuration items into "commit to Git" vs "inject at deploy time"; includes a Rancher cluster-ID item). S3-QC3 (webhooks vs polling: which direction must the network allow?). S3-QC4 (given a cluster Secret with `namespaces: [a, b]` and `clusterResources: false`, predict what an Application targeting namespace `c` experiences).
- *Try It:* `helm template` the vendored chart twice (course values vs HA-style values) and count the extra objects. No cluster change.
- *Misconceptions:* "`argocd cluster add` is the production way" (it creates a `cluster-admin` ServiceAccount by default, and in this lab its kubeconfig URL is unreachable from Argo CD's pods); "Kubernetes Secrets are encrypted"; "HA means more replicas of everything including Redis state."
- *Rancher/RKE2 content:* diagrams only. No Rancher UI screenshots (none exists in the environment, and fabrication is forbidden). Cover the Rancher proxy URL vs the authorized cluster endpoint (ACE) and the dependency on Rancher availability (section 12, P-14).

**`04-helm-sync-and-promotion`** (60 min)
- *Opening scenario:* someone ran `helm rollback` on a cluster managed by Argo CD, and Argo CD "undid" it within seconds.
- *Visuals:* V-14, V-15, V-16, V-17, V-18. *Screenshots:* SS-S4-01 to SS-S4-04.
- *Quick Checks:* S4-QC1 (automated sync without prune: a file is deleted from Git; predict what happens live). S4-QC2 (order six resources by phase/wave/kind/name, with one PreSync hook). S4-QC3 (which value wins: parameter vs `valuesObject` vs `valueFiles` vs chart default). S4-QC4 (Kustomize patches `replicas` on Helm output: who owns the field, and why is that risky?).
- *Try It:* `helm template` the storefront chart with dev and staging values, and `diff` the outputs. Predict the differences first. Uses the VM's Helm v4.2.1, which matches the repo-server.
- *Misconceptions:* "Argo CD runs `helm upgrade`" (it runs `helm template`; no Helm release exists); "self-heal retries failed syncs" (automated sync does not re-attempt a failed sync of the same commit and parameters); "rollback is always available" (it is blocked while auto-sync is on); "`main` is a version."

**`05-applicationsets-and-app-of-apps`** (60 min)
- *Opening scenario:* one line changed in a generator, and forty Applications changed with it.
- *Visuals:* V-19, V-20, V-21. *Screenshots:* SS-S5-01 to SS-S5-03.
- *Quick Checks:* S5-QC1 (given a matrix of two clusters and three env files, predict the generated Application names; a distractor claims progressive sync is on by default). S5-QC2 (a template references a missing key: what renders with and without `missingkey=error`?). S5-QC3 (apply the decision table to three scenarios). S5-QC4 (a root Application is deleted with cascade: what disappears, and in what order?).
- *Try It:* `argocd appset create --dry-run -o yaml` on `platform-config/examples/appset-list.yaml`. Nothing is created.
- *Misconceptions:* "A root Application's Healthy means its children are healthy" (child Application health is not assessed by default since 1.8); "`create-update` is always safe" (orphans must then be cleaned up deliberately); "the UI Preview is the stable way to preview" (it is Alpha since v3.5.0; the CLI `--dry-run` is the portable method).
- *Required caveats:* templated `project` fields are a privilege-escalation risk. Keep `project` hard-coded in every course AppSet.

**`06-security-multitenancy-governance`** (45 min)
- *Opening scenario:* a developer's CI token can delete production Applications. How did that happen?
- *Visuals:* V-22, V-23, V-24. *Screenshots:* SS-S6-01 to SS-S6-03.
- *Quick Checks:* S6-QC1 (given three real error messages, name the layer that denied each: Argo CD RBAC, AppProject, or Kubernetes RBAC). S6-QC2 (why only admins should create ApplicationSets). S6-QC3 (choose a secret-management pattern and an SSO group mapping for a scenario).
- *Try It:* `argocd admin settings rbac can` against a provided policy CSV file (offline). Predict allow/deny first. Command verification is pending (section 12, P-10).
- *Misconceptions:* "AppProject restrictions are Kubernetes RBAC"; "the `default` project is safe to use"; "a sealed Secret in Git is the same as a plaintext Secret in Git."

**`07-reliability-troubleshooting-lifecycle`** (75 min)
- *Opening scenario:* at 09:05 every Application turns Unknown. Where do you look first, and what do you **not** touch?
- *Visuals:* V-25, V-26, V-27, V-28, V-29. *Screenshots:* SS-S7-01, SS-S7-02. These deliberately show **different** root causes than the capstone faults, to avoid spoilers.
- *Worked walkthrough:* one full incident narrated through all six method steps (Git repo unreachable), with the exact evidence command at each step.
- *Quick Checks:* S7-QC1 (order the evidence steps for a given symptom). S7-QC2 (Redis pod deleted, repo-server OOMKilled, controller shard lost: impact of each). S7-QC3 (is this `ignoreDifferences` rule safe or concealing?). S7-QC4 (an upgrade from 3.4 to 3.5 changes rendered manifests with no Git change: what happened, and what would your compatibility test have caught? Includes version matching and fork CVE response).
- *Try It:* `argocd admin export -n argocd > backup.yaml` on the VM, then list the resource kinds it contains. Read-only for the cluster.
- *Misconceptions:* "Restarting pods is a diagnosis"; "Redis loss means data loss"; "ignore rules reduce risk"; "an upgrade is only a version bump."

### 7.3 Lab guide cards

Each lab guide follows the contract order: Why this matters, objectives, prerequisites, mental model recap, environment check (healthy screenshot), guided walkthrough, exercises, troubleshooting, checkpoint, takeaways, optional stretch, transition. Every exercise includes a goal restatement, input and output *shape*, a time/difficulty estimate, escalating hints, a checkable success criterion, and starter state (content contract).

**`lab-01-follow-an-application-through-reconciliation`** (45 min, G1)
- *Starting state:* CP-lab-01. Application `hello-reconcile` (project `default`, destination `in-cluster`/namespace `hello`, manual sync) is Synced/Healthy. The repo is public-read (no credentials needed; this is contrasted with Lab 2's private repo).
- *Why in-cluster:* Lab 1 deliberately deploys to the management cluster so reconciliation can be learned before registration exists. The guide must say plainly that production platforms avoid deploying workloads to the management cluster, and that Lab 2 fixes this.
- *Guided walkthrough:* UI login (SS-L1-01, SS-L1-02); CLI login `argocd login localhost:8443 --insecure`; open the tree (SS-L1-03); read the Application YAML (SS-L1-04).
- *Exercises:*
  - E1 (5 min, easy): list every external dependency (Git URL, revision, path, chart, destination, namespace, project, credentials "none", image registry) as a table.
  - E2 (15 min): **predict, commit, diagnose, fix**. The starting chart is unchanged (no Pod-template annotation). Part 1: change `message` in `chart/values.yaml`, predict sync status, health, "does a new Pod start?", and "which message is served?" after push, after Refresh, and after Sync; sync. The sync succeeds but no Pod restarts and `curl` still returns the old message (a ConfigMap change does not restart the Pods that read it as environment variables). Part 2: gather evidence (`argocd app get`, live ConfigMap, container environment via `kubectl exec`, `rollout history`) and explain it in one sentence. Part 3: fix it in Git by adding a `checksum/config` annotation to the Deployment's Pod template, predict which resource goes OutOfSync, sync, and watch the rollout (`Synced` + `Progressing` → `Healthy`). Success: the Synced revision equals `git rev-parse HEAD`, and `curl` returns the new message.
  - E3 (7 min): compare `argocd app manifests --source git`, `--source live`, and `kubectl get -o yaml` for the ConfigMap. Find at least three live-only fields and explain why they do not cause OutOfSync. Find the tracking-id annotation.
  - E4 (4-6 min): fill a three-way table (UI / `argocd` CLI / `kubectl`) for sync status, health, last-synced revision, and Pod events. Answer: "which would you use if the UI were down?"
- *Stretch:* predict the health status for `replicaCount: 0`.
- *Screenshots:* SS-L1-01 to SS-L1-12 (SS-L1-11 and SS-L1-12 cover E2 Part 3 and are capture specs awaiting capture).

**`lab-02-configure-platform-and-register-target`** (60 min, G1)
- *Starting state:* CP-lab-02. The workload cluster is running but **not registered**. The private repo `storefront-gitops` exists but is **not connected**. Workload namespaces are pre-created by the platform (this maps to Rancher Projects owning namespaces).
- *Exercises:*
  - E1 (10 min): create the repository Secret declaratively from `platform-config/repositories/storefront-gitops.secret.template.yaml`, with the password injected from `~/course/credentials/gitea-student.txt` (never committed). Verify `Successful` in the UI (SS-L2-02) and in `argocd repo list`.
  - E2 (17 min): apply the provided least-privilege RBAC on the workload cluster (`~/course/lab-files/lab-02/workload-rbac.yaml`), create the long-lived token Secret, and build and apply the cluster Secret: `name: workload`, `server: https://k3d-workload-server-0:6443`, `namespaces` list, `clusterResources: false`, labels `cluster-role=workload`, `region=lab`. Verify (SS-L2-03, SS-L2-04).
  - E3 (8 min): **predict, then prove** least privilege with `kubectl auth can-i --as=system:serviceaccount:argocd-access:argocd-manager` (four checks with predetermined yes/no answers, participants predict first).
  - E4 (12 min): complete the four `TODO` fields in the `projects/storefront.yaml` and `applications/storefront-dev.yaml` skeletons, commit, and `kubectl apply`. Confirm OutOfSync plus Missing (SS-L2-06 to SS-L2-08). Explain in one sentence why this is correct and not broken.
  - E5 (8 min; the second record is optional per R-7): apply `broken/repo-secret-wrong-url.yaml` and `broken/cluster-secret-wrong-server.yaml` one at a time, find the symptom, name the wrong field, and remove it.
- *Stretch:* Gitea webhook to `https://<argocd>/api/webhook` (partly verified: P-7) and measure detection latency; or try `argocd cluster add k3d-workload` and explain why it fails here (kubeconfig server URL unreachable from pods).
- *Leaves:* CP-lab-03.

**`lab-03-deploy-drift-and-recover`** (60 min, G2)
- *Starting state:* CP-lab-03 (`storefront-dev` OutOfSync/Missing, manual sync).
- *Exercises:*
  - E1 (10 min): sync dev and watch the PreSync hook and waves (SS-L3-02). Predict, then run `helm list -A --kube-context k3d-workload` (empty). Verify with a port-forward and `curl`.
  - E2 (10 min): participants write `storefront-staging` (valueFiles `../../envs/staging/values.yaml` or the equivalent path form the lab-engineer verifies) and predict rendered differences. Promote the dev image tag into the staging values through a commit.
  - E3 (8 min): introduce drift (`kubectl scale`, `kubectl edit configmap`) under manual sync. Predict, observe the diff (SS-L3-04, SS-L3-05). Nothing reverts.
  - E4 (12 min): change the Application in Git to `automated: {selfHeal: true, prune: false}` and apply it. Repeat the drift and observe the self-heal (default timeout 5 s). Add `argocd.argoproj.io/sync-options: Prune=false` to one resource and justify it.
  - E5 (15 min): part A, rendering failure (commit a `valueFiles` reference to a file that does not exist, producing ComparisonError; SS-L3-08). Part B, ordering failure (set `migration.shouldFail: true`, so the PreSync hook fails and later waves never apply; SS-L3-09). Recover both through Git. Justify revert vs roll-forward.
- *Stretch:* try a UI rollback with auto-sync on (blocked) and explain; add `retry` with backoff and observe.
- *Checkpoint (Day 1 outcome):* dev and staging Synced/Healthy at the participant's latest commit, and a written three-line "where I would look first" note for each of repo, render, sync, and health failures.

**`lab-04-build-and-troubleshoot-patterns`** (75 min, G2)
- *Starting state:* CP-lab-04. Day 1 hand-made storefront Applications and `hello-reconcile` are removed (the recap explains why). A credential template covers all course repos. Project `platform` exists. `applicationsets/storefront.yaml` is a skeleton with TODOs. `root/platform-root.yaml` and `apps/*` are ready.
- *Guided preview workflow:* `argocd appset create --dry-run -o yaml` (stable) and the UI Preview tab (Alpha; SS-L4-03).
- *Exercises:*
  - E1 (15 min): complete the AppSet. Matrix of a cluster generator (`selector: cluster-role=workload`) and a git files generator (`envs/*/config.yaml`); `goTemplate: true`; `goTemplateOptions: ["missingkey=error"]`; name `storefront-{{.env}}-{{.name}}`; project hard-coded `storefront`; prod pinned via `targetRevision` from `config.yaml`. Preview, commit, apply. Success: three Applications, `storefront-{dev,staging,prod}-workload`.
  - E2 (8 min): **predict** what labeling the `in-cluster` Secret `cluster-role=workload` would generate. Confirm with preview only (never apply). Explain why the AppProject would block it anyway. Use `{{index .metadata.labels "region"}}` in the template.
  - E3 (8 min): set `applicationsSync: create-update` and `preserveResourcesOnDeletion: true`. Remove prod from the generator input and predict. Observe that prod survives. State what an operator must now do.
  - E4 (10 min): apply `platform-root` and draw the ownership tree (root, three child Applications, repos, resources). Answer: what would cascade-deleting the root remove?
  - E5 (14 min): part A, apply the provided commit that removes `namespace` from `envs/staging/config.yaml` (AppSet ErrorOccurred; existing Applications untouched, "fails safe"; SS-L4-07). Part B, apply the commit that breaks the `platform-quotas` child path (child ComparisonError while the root still looks Healthy/Synced; SS-L4-09). Fill the trace table (symptom, owning object, owning repo/file, fix) and fix both via Git.
  - E6 (10 min): scenario "retire staging." Execute it with the AppSet (under create-update, deletion must be deliberate) and reason through the App-of-Apps equivalent in a comparison table (files touched, reviewers, blast radius, deletion behavior, preview capability), using V-21 as the rubric.
- *Stretch:* restore child-Application health with `resource.customizations.health.argoproj.io_Application` via `apply-argocd-config` and watch the root reflect child failure; or add a merge generator.
- *Leaves:* CP-lab-05.

**`lab-05-enforce-platform-guardrails`** (45 min, G2)
- *Starting state:* CP-lab-05 plus pre-staged `team-a-apps` repo and local account `team-a-dev` (login only, **no** RBAC grants yet).
- *Exercises:*
  - E1 (10 min): write `projects/team-a.yaml` from a spec table (source only `team-a-apps`; destination only `workload`/`team-a`; `clusterResourceWhitelist: []`; deny ResourceQuota and LimitRange; **allow** NetworkPolicy at the AppProject level). Write the RBAC policy granting `role:team-a` to `team-a-dev` via `platform-config/argocd/values.yaml` and apply it with `apply-argocd-config`.
  - E2 (5 min): create `team-a-guestbook` from `team-a-apps/guestbook`, which reaches Synced/Healthy.
  - E3 (8 min): predict, then observe: (a) an Application targeting `storefront-prod` is rejected (destination not permitted); (b) `attempts/cluster-scoped` is blocked (ClusterRole not permitted).
  - E4 (12 min): **compare denials**. (a) Log in as `team-a-dev` and try to sync `storefront-prod-workload`: Argo CD RBAC denies with "permission denied". (b) Sync `attempts/network-policy`: the AppProject allows it and Argo CD RBAC allows it, but Kubernetes forbids the ServiceAccount. Complete the comparison table (who denied, where logged, which config fixes it, who owns that config). Use `argocd admin settings rbac can` and `kubectl auth can-i --as`.
  - E5 (6 min): add `p, role:team-a, applications, delete, storefront/*, deny` (or the exact verified form). Test as `team-a-dev`. Inspect the `resources-finalizer.argocd.argoproj.io` finalizer on a generated Application and explain the cascade.
- *Stretch:* controller-wide `applicationsetcontroller.policy: create-update` (overrides are then disabled by default; verified from source); a deny sync window on `storefront-prod`; a project-role JWT for CI with `argocd proj role create-token`.
- *Leaves:* CP-capstone (pre-fault).

**`capstone-restore-platform`** (90 min, G3)
- *Starting state:* CP-capstone plus `inject-capstone-faults.sh inject all` (run by the instructor or the participant's own `start-capstone` wrapper).
- *Phases:*
  - P0 (10 min): incident brief. Rules: no change before evidence; every repair goes through Git or the declarative platform configuration; log every command.
  - P1 (15 min): triage. Walk the `07` method across all Applications and fill the **triage grid** (symptom, evidence, layer: platform / connectivity / source-render / generation-ownership / policy / runtime, hypothesis). *Checkpoint C1:* grid complete, no changes made.
  - P2 (50 min): restore. The guide gives a per-fault **sanity check** that describes the observable healthy signal for that area without naming the cause or fix.
  - P3 (5 min): `capstone-check` reports resolved/unresolved per area. Final state is SS-CAP-02.
  - P4 (10 min): written reflection. For each fault: root cause, the evidence that proved it, the change made, and the guardrail or monitoring change that prevents recurrence. Markdown answers, no presentation.
- *The guide must not* name faults by cause, show fault symptoms beyond the incident-start Applications list (SS-CAP-01), or order the faults for the participant.

### 7.4 State handoff contract (Required)

| Transition | Participant-created state that must exist | Reset command that recreates it |
|---|---|---|
| lab-01 → lab-02 | none required (Lab 1 commits are harmless) | `reset-lab.sh CP-lab-02` |
| lab-02 → lab-03 | repository Secret `repo-storefront-gitops`, cluster Secret `cluster-workload` (label `argocd.argoproj.io/secret-type: cluster`), AppProject `storefront`, Application `storefront-dev` (OutOfSync/Missing); commits in `platform-config` | `reset-lab.sh CP-lab-03` |
| lab-03 → Day 2 | none carried forward (reset removes Day 1 storefront Applications on purpose) | `reset-lab.sh CP-lab-04` |
| lab-04 → lab-05 | AppSet `storefront` (three generated Applications Synced/Healthy, `create-update`, `preserveResourcesOnDeletion`), root `platform-root` plus three children Synced/Healthy, cluster labels | `reset-lab.sh CP-lab-05` |
| lab-05 → capstone | AppProject `team-a`, Application `team-a-guestbook`, RBAC `role:team-a` bound to `team-a-dev` | `reset-lab.sh CP-capstone`, then `inject-capstone-faults.sh inject all` |

Every lab's Environment check must begin with `reset-lab.sh <CP> --verify-only`, which prints PASS/FAIL per expected object. If a participant fails it, the guide tells them to run the reset command (with the warning that it discards their work).

---

## 8. Environment specification (contract for `environment-engineer`)

### 8.1 Decisions already made by the user (encoded, not reopened)

1. **Provider-agnostic Terraform.** One Linux VM per participant (class up to 20) plus one instructor/reference VM, parameterized by `student_count`. The compute layer is a thin, swappable module (generic VM shape plus cloud-init bootstrap), so an instructor can plug in any cloud. **No agent ever runs `terraform apply` or `terraform destroy`.**
2. **Local validation sandbox.** Bootstrap, reset, and fault-injection scripts, and every lab and solution, are executed locally on the build machine with **k3d on Docker**, using the same two-cluster topology defined below.
3. **Live screenshots.** Captured from the local Argo CD instance by scripted headless Chrome into `courseware/assets/screenshots/day-1/` and `day-2/` (section 9).

### 8.2 Pinned versions (Required; evidence in section 12)

| Component | Pin | Status |
|---|---|---|
| Argo CD | **v3.5.2** (`quay.io/argoproj/argocd:v3.5.2`) | VERIFIED |
| Argo CD Helm chart (argo-helm) | **`argo-cd` 10.8.4** (appVersion `v3.5.2`), vendored as `/opt/course/charts/argo-cd-10.8.4.tgz` for offline resets | VERIFIED |
| Helm bundled inside repo-server | **v4.2.1** (Helm 4; `spec.source.helm.version: v3` is ignored in 3.5) | VERIFIED (upstream doc headline says 4.2.0; the source and "Helm Upgraded" section say 4.2.1; confirm in-cluster, P-1) |
| k3s image | **`rancher/k3s:v1.35.8-k3s1`** (Kubernetes 1.35; amd64 and arm64) | VERIFIED. Inside Argo CD 3.5's tested range (1.33 to 1.36) and also 3.4/3.3's (1.32 to 1.35) |
| k3d | **v5.9.0**. Always pass `--image`; never rely on k3d's default k3s | VERIFIED |
| kubectl (VM and local tools dir) | **v1.35.8** | VERIFIED (`dl.k8s.io/release/stable-1.35.txt`) |
| helm CLI (VM and local tools dir) | **v4.2.1**, deliberately matching the repo-server's bundled Helm (Helm 4.3.0 and 3.22.0 exist but are **not** used) | VERIFIED exists |
| argocd CLI | **v3.5.2** | VERIFIED |
| Gitea | **`gitea/gitea:1.27.3-rootless`** | VERIFIED tag exists (amd64, arm64) |
| Sample workload image | **`stefanprodan/podinfo:6.15.0`** (Docker Hub; amd64, arm64) | VERIFIED tag exists |
| Hook/utility image | busybox, exact tag **TO-PIN** by `environment-engineer` after checking | PENDING (P-16) |
| Redis image | whatever chart 10.8.4 pins by default (read from `helm show values`) | PENDING (P-16) |
| Docker Engine, `yq`, `jq`, Git on the VM | **TO-PIN** by `environment-engineer` | PENDING (P-16) |
| Terraform | `>= 1.12` (build machine has 1.12.2); providers pinned by `environment-engineer` after verification | PENDING (P-16) |
| VM OS | Ubuntu Server 24.04 LTS (x86_64) default; the scripts must be arch-aware (amd64/arm64) | Design decision |

**Build-machine rule (Required):** the build machine's own `kubectl` v1.30.5 is outside the supported version skew for Kubernetes 1.35, and its `helm` v3.19.1 renders differently from Argo CD's Helm 4. All lab-facing commands and outputs must come from the pinned tools installed into `${COURSE_TOOLS_DIR:-$HOME/.argocd-course/bin}` and prepended to `PATH` in local mode. `lab-tester` and `lab-solution-engineer` must record `kubectl version --client`, `helm version`, and `argocd version --client` at the top of each report.

### 8.3 Topology and names (Required; downstream guides use these names verbatim)

```text
VM (Ubuntu, Docker) ─── user-defined Docker network: argocd-lab
│
├─ k3d cluster "mgmt"      context: k3d-mgmt       API: 127.0.0.1:6550
│    node container: k3d-mgmt-server-0
│    namespace argocd  → Argo CD v3.5.2 (Helm release "argocd", chart 10.8.4)
│    namespace hello   → Lab 1 destination (in-cluster)
│    Argo CD UI/API: NodePort 30443 → published as https://localhost:8443
│
├─ k3d cluster "workload"  context: k3d-workload   API: 127.0.0.1:6551
│    node container: k3d-workload-server-0  (reachable from mgmt pods as
│                                            https://k3d-workload-server-0:6443)
│    namespaces: argocd-access, storefront-dev, storefront-staging,
│                storefront-prod, team-a, platform-system
│
└─ container "lab-gitea"   gitea/gitea:1.27.3-rootless
     internal URL (Argo CD and VM shell): http://lab-gitea:3000/course/<repo>.git
     host publish: 127.0.0.1:3000
```

| Item | Value |
|---|---|
| Docker network | `argocd-lab` (user-defined bridge; both clusters are created with `--network argocd-lab`, and Gitea joins it) |
| Clusters | 1 server node each, no agents. Disable `traefik` and `servicelb` on both. **Keep `metrics-server`** on both (needed for `kubectl top` and for the HPA in F6). |
| Workload TLS SAN | Add `--k3s-arg "--tls-san=k3d-workload-server-0@server:0"` so certificate verification with `caData` works by container name (belt and braces; a practitioner source reports it works without this) |
| Argo CD cluster names | `in-cluster` (`https://kubernetes.default.svc`; explicit Secret created by bootstrap with label `cluster-role=management`, so label selectors can address it) and `workload` (created by participants in Lab 2) |
| Default kube context | `k3d-mgmt` |
| Why Gitea runs outside both clusters | Git must survive the loss of the management cluster (Session 7 recovery story), exactly as production Git lives outside Argo CD's cluster |
| Name resolution for `lab-gitea` and `k3d-workload-server-0` from mgmt pods | Must work by name. k3d injects Docker-network hosts into CoreDNS, but those entries can be lost after a Docker or VM restart. `bootstrap-vm.sh` and `reset-lab.sh` must call `scripts/lib/refresh-coredns-hosts.sh`, which writes deterministic entries (for example via the k3s-supported `coredns-custom` ConfigMap). Test that it survives a VM reboot (P-5). |
| One URL everywhere | On the VM, `/etc/hosts` maps `lab-gitea` to `127.0.0.1`, so participants clone from the **same** `http://lab-gitea:3000/...` URL that Argo CD uses. In local mode (no sudo), use `git config url."http://localhost:3000/".insteadOf "http://lab-gitea:3000/"` in a dedicated `GIT_CONFIG_GLOBAL`. |
| Production mapping (for `03` and V-01) | `k3d-mgmt` = Rancher-managed RKE2 management cluster running Argo CD. `k3d-workload` = RKE2 downstream workload cluster registered with Argo CD. Workload namespaces pre-created by the platform = namespaces owned by Rancher Projects. `lab-gitea` = the organization's Git service. |

### 8.4 Access (Required)

| What | URL / command | Notes |
|---|---|---|
| Argo CD UI (VM and laptop) | `https://localhost:8443` | Participants connect over an SSH tunnel: `ssh -i <key> -L 8443:localhost:8443 -L 3000:localhost:3000 student@<vm-ip>`. Self-signed certificate: the student setup guide shows the browser warning and how to proceed. |
| Argo CD CLI (on VM) | `argocd login localhost:8443 --username admin --password "$(cat ~/course/credentials/argocd-admin.txt)" --insecure` | Direct gRPC to the NodePort; no `--grpc-web` needed |
| Gitea UI | `http://localhost:3000` via the tunnel (clone URLs shown by Gitea use `lab-gitea`) | `ROOT_URL=http://lab-gitea:3000/` |
| Workload app check | `kubectl --context k3d-workload -n storefront-dev port-forward svc/storefront 9898:9898` then `curl -s localhost:9898` | No ingress in the lab |
| Firewall (Terraform) | Inbound **22/tcp only** from `allowed_ssh_cidrs` (required, no default). Optional `allowed_ui_cidrs` (default empty) opens 8443/3000 for classrooms that block SSH tunnels. | Least privilege |

### 8.5 Credentials and secrets (Required)

- Generated **per VM at bootstrap**, stored mode `0600` under `/home/student/course/credentials/`: `argocd-admin.txt` (admin password set explicitly through chart values, then `argocd-initial-admin-secret` deleted), `gitea-student.txt`, and `team-a-dev.txt` (Lab 5 local account).
- Root-only: `/opt/course/secrets/gitea-teammate.txt`, used by fault injection to author "teammate" commits.
- Per-student SSH keypairs come from Terraform (`tls_private_key`) and appear only in **sensitive** outputs or an instructor-only rendered file that is git-ignored.
- **Nothing** secret is committed to any seed repo. Repository and cluster Secrets exist in Git only as `*.template.yaml` files with placeholders (`<TOKEN>`, `<CA_DATA>`, `<PASSWORD>`). This is the working example for B3.9 and B6.6.

### 8.6 Argo CD installation values (Required intent; verify key paths with `helm show values` for chart 10.8.4, P-2)

The values live in `platform-config/argocd/values.yaml` and are applied **only** by `/opt/course/bin/apply-argocd-config`. That wrapper runs `helm upgrade --install argocd /opt/course/charts/argo-cd-10.8.4.tgz -n argocd -f <values>` and waits for the rollout. It stands in for "the platform pipeline that manages Argo CD declaratively." The lab environment does **not** make Argo CD self-manage (a self-managing Argo CD could break itself during the capstone). `03` teaches self-management as the production option.

| Setting | Value | Why |
|---|---|---|
| Install type | Multi-tenant, **non-HA** (standard) | The HA demo runs only on the instructor VM's `ha-demo` cluster |
| `server.service` | NodePort, HTTPS NodePort 30443 | Maps to `https://localhost:8443` |
| TLS | Argo CD self-signed; `server.insecure` stays false | Realistic TLS; no ingress |
| Dex | disabled | No IdP in the lab (R-5) |
| Notifications controller | enabled (no triggers configured at baseline) | Present in the component map (V-05); discussed in `07` |
| `timeout.reconciliation` / `timeout.reconciliation.jitter` | **`60s` / `0s`** | **Lab-only deviation** from the defaults of `120s` / `60s` (maximum about 3 minutes). Every guide that times reconciliation must say so. Verify that `0s` is accepted (P-6). |
| `resource.respectRBAC` | `normal` | The controller watches only what the least-privilege ServiceAccount can list |
| `application.resourceTrackingMethod` | leave default (`annotation`, the 3.x default) | Taught in `02` |
| `cluster.inClusterEnabled` | default `true` | Lab 1 uses `in-cluster`; `03` presents `false` as hardening |
| Admin | enabled; password from the generated credential | `06` explains removing routine admin use |
| Local accounts | `accounts.team-a-dev: login` (password set at bootstrap); **no** RBAC grants until Lab 5 | Simulates an SSO group member |
| RBAC | `policy.default: ""` at baseline; Lab 5 adds `role:team-a` | |
| ApplicationSet controller policy | **unset** (so the per-AppSet `applicationsSync` is honored by default; verified from source) | `lab-05` stretch sets it to show the controller-level lock |
| Child-Application health customization | **absent** at baseline | `lab-04` shows the root-looks-Healthy trap; the stretch adds it |
| repo-server resources | explicit requests and limits (calibrate; for example 128Mi/512Mi) | F7 lowers the limit |
| Dex, ingress, HA settings | off | |

### 8.7 Sample Git repositories (Required)

Gitea org: `course`. All repos are seeded from `courseware/environment/repos/<repo>/` by `scripts/seed-repos.sh`. Each checkpoint is a Git **tag** `cp-<name>` in every repo, and resets force-move `main` to that tag. The Gitea user `student` owns the org. The user `teammate` authors capstone fault commits.

**1. `hello-reconcile`** (public read; Lab 1)

```text
hello-reconcile/
  README.md
  argocd/hello-reconcile-app.yaml   # the Application (applied by bootstrap; read in Lab 1 E1)
  chart/
    Chart.yaml                      # name: hello-reconcile, version: 0.1.0
    values.yaml                     # message, color, replicaCount: 1
    templates/
      configmap.yaml                # message/color → podinfo env (verify env names, P-17)
      deployment.yaml               # podinfo 6.15.0, envFrom ConfigMap, readiness /readyz
      service.yaml                  # port 9898
```

**2. `storefront-gitops`** (private; Labs 2-4, capstone). The Helm application plus environment values.

```text
storefront-gitops/
  README.md
  charts/storefront/
    Chart.yaml                      # version 1.0.0
    values.yaml                     # image.repository/tag (podinfo 6.15.0), replicaCount,
                                    # ui.message, ui.color, probes.readinessPath (/readyz),
                                    # progressDeadlineSeconds: 60, migration.enabled: true,
                                    # migration.shouldFail: false, hpa.enabled: false, resources
    templates/
      _helpers.tpl
      configmap.yaml                # sync-wave "-1"
      migration-job.yaml            # hook: PreSync; hook-delete-policy: BeforeHookCreation
      deployment.yaml               # sync-wave "0"; uses `required` for image.tag
      service.yaml                  # sync-wave "0"
      hpa.yaml                      # only when hpa.enabled
  envs/
    dev/values.yaml      dev/config.yaml       # config.yaml: env, namespace, targetRevision: main
    staging/values.yaml  staging/config.yaml   # targetRevision: main
    prod/values.yaml     prod/config.yaml      # targetRevision: storefront-1.0.0 (Git tag = pinned)
```

- Tags: `storefront-1.0.0` (good) and, created **only** by F6 injection, `storefront-1.1.0` (bad readiness path, `hpa.enabled: true` with `minReplicas` above `replicaCount`).
- **Chart rule:** no `null` values used to delete defaults, and no nullable defaults, because Helm 4 null handling differs (P-3). `progressDeadlineSeconds: 60` makes Degraded appear within about a minute (verify timing, P-12).

**3. `platform-config`** (private; Labs 2-5, capstone). Owned by the platform team: Argo CD's own declarative configuration plus the App-of-Apps definitions.

```text
platform-config/
  README.md
  argocd/values.yaml                        # Helm values for the Argo CD release (8.6)
  clusters/
    in-cluster.secret.yaml                  # labels only, no credentials (applied by bootstrap)
    workload.secret.template.yaml           # placeholders only (Lab 2)
  repositories/
    storefront-gitops.secret.template.yaml  # placeholders only (Lab 2)
    course-repo-creds.secret.template.yaml  # credential template for http://lab-gitea:3000/course/ (CP-lab-04)
  projects/
    storefront.yaml                         # skeleton with TODOs at cp-lab-02; complete at cp-lab-03
    platform.yaml                           # present from cp-lab-04 (allows argoproj.io/Application in in-cluster/argocd)
    team-a.yaml                             # absent until Lab 5 E1
  applications/
    storefront-dev.yaml                     # skeleton at cp-lab-02 (Lab 2 E4)
    storefront-staging.yaml                 # written in Lab 3 E2
    team-a-guestbook.yaml                   # written in Lab 5 E2
  applicationsets/
    storefront.yaml                         # skeleton with TODOs at cp-lab-04; complete at cp-lab-05
  root/platform-root.yaml                   # root Application → path apps/ (destination in-cluster/argocd, project platform)
  apps/                                     # child Applications owned by platform-root
    platform-quotas.yaml                    # → platform-components/quotas
    platform-netpol.yaml                    # → platform-components/network-policies
    platform-agent.yaml                     # → platform-components/agent
  examples/                                 # used only by S5-TRY (dry-run)
    appset-list.yaml  appset-cluster.yaml  appset-git-files.yaml  appset-matrix.yaml  appset-merge.yaml
```

**4. `platform-components`** (private; Lab 4, capstone). Sources for the children.

```text
platform-components/
  quotas/             # ResourceQuota and LimitRange for storefront-* and team-a (calibrate so they never block labs)
  network-policies/   # default-deny plus allow-same-namespace for storefront-*
  agent/              # tiny Deployment in platform-system (podinfo as a stand-in "platform agent")
```

**5. `team-a-apps`** (private; Lab 5)

```text
team-a-apps/
  guestbook/                        # Deployment and Service (podinfo) for namespace team-a
  attempts/
    cluster-scoped/clusterrole.yaml # blocked by AppProject (cluster-scoped kind)
    network-policy/netpol.yaml      # allowed by AppProject, forbidden by Kubernetes RBAC in team-a
```

**Capstone broken-state variants.** These are not separate repos. They are fault units under `courseware/environment/scripts/capstone/faults/F1..F7/`. Git-based faults are realistic commits on `main` by `teammate`, so `git log` is useful evidence. The seed tag `cp-capstone` is the revert anchor.

### 8.7.1 Workload-cluster least-privilege design (applied by participants in Lab 2 from `~/course/lab-files/lab-02/workload-rbac.yaml`)

| Object | Scope | Grants |
|---|---|---|
| ServiceAccount `argocd-manager` | namespace `argocd-access` | identity used by Argo CD |
| Secret `argocd-manager-token` (type `kubernetes.io/service-account-token`) | `argocd-access` | long-lived bearer token (rotating it is F5) |
| Role `argocd-deployer` plus RoleBinding in each of `storefront-dev`, `storefront-staging`, `storefront-prod`, `platform-system` | namespaced | get/list/watch on `*`; create/update/patch/delete on Deployments, ReplicaSets, Services, ConfigMaps, Jobs, HPAs, ServiceAccounts, NetworkPolicies, ResourceQuotas, LimitRanges |
| Role `argocd-deployer-team` plus RoleBinding in `team-a` | namespaced | same as above **minus NetworkPolicies, ResourceQuotas, LimitRanges** (drives `lab-05` E4) |
| No ClusterRoleBinding with write access | cluster | cluster Secret uses `clusterResources: false` |

The exact verbs, and whether any cluster-scoped read (for example, namespace get) is needed for Argo CD to function in namespaced mode, must be validated in the local sandbox (P-8).

### 8.8 Checkpoints and reset strategy (Required)

**Command:** `/opt/course/bin/reset-lab.sh <CP> [--yes] [--verify-only]` and `reset-lab.sh --list`. It must be idempotent, work **offline**, finish in 3 minutes or less (target), and print a PASS/FAIL table of expected objects at the end.

| Checkpoint | Start of | Git (`main` of each repo forced to tag) | Argo CD objects present | Workload cluster |
|---|---|---|---|---|
| `CP-baseline` = `CP-lab-01` | Lab 1 | all repos at `cp-baseline` | Application `hello-reconcile` Synced/Healthy; `in-cluster` Secret labeled `cluster-role=management`; project `default` only; no repo Secrets | namespaces pre-created; **no** `argocd-access` RBAC; not registered |
| `CP-lab-02` | Lab 2 | `cp-lab-02` (`platform-config` skeletons with TODOs) | as baseline (`hello-reconcile` reset to seed) | as baseline |
| `CP-lab-03` | Lab 3 | `cp-lab-03` (Lab 2 answers committed) | + repository Secret, cluster Secret `workload`, AppProject `storefront`, Application `storefront-dev` (manual, OutOfSync/Missing) | + `workload-rbac.yaml` applied and token Secret created |
| `CP-lab-04` | Lab 4 (Day 2 start) | `cp-lab-04` (AppSet skeleton; root and children ready) | `hello-reconcile` and Day 1 storefront Applications **removed** (cascade); + `course-repo-creds` template, AppProject `platform` | storefront namespaces emptied |
| `CP-lab-05` | Lab 5 | `cp-lab-05` | + AppSet `storefront` (3 generated Applications Synced/Healthy, `create-update`, `preserveResourcesOnDeletion`), `platform-root` plus 3 children Synced/Healthy; cluster labels | workloads running |
| `CP-capstone` | Capstone | `cp-capstone` | + AppProject `team-a`, Application `team-a-guestbook`, RBAC `role:team-a` → `team-a-dev` | + team-a workload |
| `CP-capstone-restored` | (validation only) | `cp-capstone-restored` | the expected end state after a correct restoration (used by `capstone-check` and the solution validation) | all healthy |

**Reset algorithm (Required order):**
1. Run `inject-capstone-faults.sh revert all` if any fault marker exists (a disconnected cluster makes finalizers hang).
2. Run `refresh-coredns-hosts.sh`.
3. Force-move `main` in every repo to `cp-<name>` from the local seed mirrors in `/opt/course/seed-repos/*.git`.
4. Delete ApplicationSets not in the checkpoint, then Applications not in the checkpoint (cascade, root before children), waiting on finalizers with a timeout and a clear message.
5. Re-apply the checkpoint's declarative bundle from `/opt/course/checkpoints/<CP>/` (with Secrets rendered from the credential files).
6. Re-apply the workload-side RBAC state for that checkpoint.
7. Clean or recreate workload namespaces.
8. Run `apply-argocd-config` with the checkpoint's `argocd/values.yaml` (this also reverts Lab 5 RBAC and F7 limits).
9. Wait for the expected statuses (`argocd app wait` with timeouts), then print verification.

A **full rebuild** (`bootstrap-vm.sh --rebuild`) deletes and recreates both k3d clusters and Gitea data from local image tarballs and the vendored chart. This is the last resort and must also work offline.

### 8.9 Capstone fault injection (Required)

**Command:** `/opt/course/bin/inject-capstone-faults.sh {inject|verify|revert|status} {F1..F7|all}`
- `inject` records the pre-fault state under `/var/lib/course/capstone/<F>.orig`, applies the fault, and writes a marker.
- `verify` exits 0 if the fault's symptom is present (used by `lab-tester` and the solution validation).
- `revert` restores exactly. `status` lists the markers.
- `all` injects in the order F1, F2, F3, F6, F4, F5, F7 and reverts in reverse order.

**Companion:** `/opt/course/bin/capstone-check` reports **resolved/unresolved per area** (for example "workload cluster connectivity: unresolved") without naming causes or fixes. It is used in CAP-P3 and by the instructor.

> The table below is instructor-only planning. `lab-engineer` must not copy fault causes or fixes into `capstone-restore-platform.md`. They belong in the SOLUTION file.

| Fault | Outline item | Injection (reversible) | Layer | Intended correct repair (solution only) | Connected to |
|---|---|---|---|---|---|
| F1 | Broken Helm values reference / rendering error | A `teammate` commit to `storefront-gitops` `envs/staging/values.yaml` that makes rendering fail **for staging only** (for example, the `required` `image.tag` blanked by a "cleanup"). It must differ from `lab-03` E5 part A (missing values file). | Source/render | Fix the values in Git; verify ComparisonError clears | Masked by F7 (everything shows ComparisonError until the repo-server is healthy) |
| F2 | ApplicationSet change with unexpectedly large blast radius | A `teammate` commit to `platform-config` `applicationsets/storefront.yaml` that drops the cluster selector's `cluster-role: workload` requirement, so Applications are also generated for `in-cluster` (the management cluster) | Generation | Revert in Git. Because of `create-update`, the stray Applications **remain**: delete them deliberately. The AppProject rejects them (destination not permitted), which is the AppProject-denial half of CF4. | F7 blocks the git-files generator until fixed |
| F3 | Root/child ownership problem | A `teammate` commit adds `team-root/` plus Application `team-root` whose path includes a duplicate of the `platform-agent` child. Two roots now claim one child (shared-resource warning / ownership flapping). | Ownership | Remove the duplicate from `team-root` (or delete `team-root` **without cascade**). The cascade-delete trap would remove the shared child and its workload. | Needs F7 fixed to render |
| F4 | AppProject or Kubernetes RBAC denial | Delete the `argocd-deployer` RoleBinding in `storefront-prod` on the workload cluster | Policy (Kubernetes RBAC, 403) | Restore the RoleBinding from the declarative RBAC file | Hidden behind F5 (no connection at all); surfaces when F6 is repaired |
| F5 | Disconnected workload cluster | Rotate the `argocd-manager-token` Secret (delete and recreate) so the token in the cluster Secret is invalid (401 Unauthorized). Do **not** stop containers. | Connectivity (authentication) | Mint the new token and update the cluster Secret declaratively (the Lab 2 procedure) | Masks F4 and F6 |
| F6 | Degraded workload plus noisy/misleading drift | Create tag `storefront-1.1.0` (bad readiness path; HPA with `minReplicas` above `replicaCount`). A `teammate` commit points `envs/prod/config.yaml` at it, and the script syncs prod once as "teammate". | Runtime/health, plus diff noise | Roll prod back to `storefront-1.0.0` (or forward to a fixed tag) in Git. Remove the replicas conflict (narrow `ignoreDifferences` on `/spec/replicas`, or stop rendering `replicas` when the HPA is on). Do **not** add broad ignore rules. | Blocked by F5; collides with F4 on sync |
| F7 | Argo CD component under resource pressure | Lower the repo-server memory limit in `platform-config/argocd/values.yaml` (a `teammate` commit such as "right-size argocd") and run `apply-argocd-config`, leading to OOMKilled / CrashLoopBackOff. Calibrate the value so it is deterministic. Fallback if OOM is not deterministic: a CPU limit low enough that rendering times out. | Platform component | Restore the limits in values and run `apply-argocd-config`; verify restarts stop | Masks F1, F2, F3 |

**Validation requirements** (for `environment-engineer` and `lab-tester`):
- Each fault must inject, verify, and revert individually and as `all`, three times in a row without drift.
- After `revert all`, `reset-lab.sh CP-capstone --verify-only` must PASS.
- Record actual symptom strings (UI and CLI) for the SOLUTION file.

### 8.10 VM sizing (Required baseline; `environment-engineer` must measure actuals)

| VM | vCPU | RAM | Disk | Hosts |
|---|---|---|---|---|
| Participant VM (×`student_count`, max 20) | **4** | **16 GiB** | **60 GiB** SSD | 2 k3d clusters, Argo CD non-HA, Gitea, sample workloads |
| Instructor/reference VM (×1) | **8** | **32 GiB** | **120 GiB** SSD | Same as participant **plus** `ha-demo` k3d cluster (1 server, 3 agents; HA requires at least 3 nodes due to pod anti-affinity) for the `03` HA demonstration and the optional `07` management-cluster-loss demo |

Estimated steady state on a participant VM: k3s `mgmt` about 0.6 GiB, Argo CD about 1.0-1.5 GiB (repo-server spikes while rendering), k3s `workload` about 0.5 GiB, workloads about 0.4 GiB, Gitea about 0.2 GiB, OS and Docker about 0.8 GiB. That totals roughly 3.5-4.5 GiB, leaving headroom for render spikes and fault F7. 8 GiB is the absolute floor and is not recommended. `environment-engineer` must record measured `docker stats` / `kubectl top` peaks from the local smoke test and the capstone run in `courseware/reviews/environment-validation.md`, and adjust this table if needed.

### 8.11 Terraform shape (Required)

```text
courseware/environment/terraform/
  versions.tf  variables.tf  main.tf  outputs.tf  terraform.tfvars.example
  modules/
    lab-fleet/                 # provider-neutral: names, tags, per-VM SSH keys (tls_private_key),
                               # cloud-init user-data (renders bootstrap-vm.sh + pinned versions), outputs
    compute-adapter-contract.md  # the interface every compute adapter must implement
  adapters/
    local-render/              # REQUIRED: writes user-data and inventory to disk; lets fmt/validate/plan run without cloud credentials
    <one-reference-cloud>/     # RECOMMENDED: a single worked example adapter (choice left to environment-engineer), clearly labeled swappable
```

- **Adapter interface.** Inputs: `vm_count`, `name_prefix`, `vm_shape = {vcpu, memory_gib, disk_gib}`, `image_hint`, `ssh_public_keys[]`, `user_data[]`, `allowed_ssh_cidrs`, `allowed_ui_cidrs`, `tags`. Output: a list of `{name, public_ip, private_ip}`.
- **Root variables:** `student_count` (validation 1..20), `instructor_vm_enabled` (default true), shapes per section 8.10, `allowed_ssh_cidrs` (required), `allowed_ui_cidrs` (default `[]`), `course_payload_ref`, `tags`.
- **Outputs:** per-student name, IP, SSH user, key (sensitive), and the tunnel command; instructor VM info; where credentials live on each VM.
- **Validation:** `terraform fmt -check`, `validate`, and `plan` against `local-render` with placeholder variables. The cloud adapter reaches `validate`, and `plan` only if credentials exist (otherwise NOT EXECUTABLE, documented). Never `apply`/`destroy`.
- **Offline-in-class guarantee:** internet is used only during provisioning. After bootstrap, `/opt/course/` holds the vendored chart, image tarballs (`docker save`, for `k3d image import` on rebuild), seed mirrors, and checkpoint bundles. Resets, fault injection, and every lab run offline.

### 8.12 Scripts and local mode (Required)

| Script | Purpose |
|---|---|
| `scripts/bootstrap-vm.sh [--local] [--rebuild]` | Idempotent. Installs pinned tools (to `/usr/local/bin`, or `$COURSE_TOOLS_DIR` with `--local`), creates the network, clusters, and Gitea, installs Argo CD via `apply-argocd-config`, seeds repos and tags, creates credentials, reaches `CP-baseline`, and runs a smoke test |
| `scripts/reset-lab.sh` | Section 8.8 |
| `scripts/inject-capstone-faults.sh` plus `scripts/capstone/faults/F1..F7/` | Section 8.9 |
| `scripts/capstone-check.sh` | Section 8.9 |
| `scripts/apply-argocd-config.sh` | Section 8.6 |
| `scripts/lib/refresh-coredns-hosts.sh` | Section 8.3 |
| `scripts/seed-repos.sh` | Builds seed repos and `cp-*` tags from `courseware/environment/repos/` |
| `scripts/screenshots/capture.mjs` plus `screenshot-manifest.yaml` | Section 9 |

All scripts must pass `shellcheck` (0.11.0 on the build machine). `--local` mode must run on the macOS build machine (Docker Desktop, arm64 or amd64) without sudo. `bootstrap-vm.sh --local` followed by `reset-lab.sh CP-<each>` and `inject-capstone-faults.sh inject/revert all` is the environment smoke test.

---

## 9. Screenshot plan (feeds the `screenshot-capture` skill)

### 9.1 Capture conventions (Required)

- **Source:** live capture only, from the course's own Argo CD v3.5.2 at `https://localhost:8443` (and Gitea at `http://localhost:3000`), on the local k3d sandbox, using scripted headless Chrome (`courseware/environment/scripts/screenshots/capture.mjs` driven by `screenshot-manifest.yaml`). There are no documentation screenshots and **no Rancher UI screenshots** (Rancher is shown only by diagrams V-01/V-11).
- **Authentication:** the harness obtains a session via `POST /api/v1/session`, sets the `argocd.token` cookie, and ignores the self-signed certificate. For SS-L5-05, SS-L5-07, and SS-S6-02 it logs in as `team-a-dev`.
- **Viewport** 1440×900, device scale factor 1, light theme, browser zoom 100%, PNG.
- **Fidelity:** `full` = whole viewport. `panel` = crop to the slide-out panel or dialog. `detail` = small crop of a badge or field.
- **Highlighting:** injected CSS outline (3 px solid `#d7263d`) on the target selector(s), plus optional numbered badges. No manual image editing.
- **Paths:** `courseware/assets/screenshots/<day-folder>/<file-id>-<NN>-<slug>.png`. File IDs are `env`, `s01`...`s07`, `lab-01`...`lab-05`, `capstone`.
- **Every embed** gets descriptive alt text, a caption, and a numbered "what to notice" list, so the guide stays usable if the image fails.
- **State reproducibility:** each row names the checkpoint plus the lab step that produces the state. The harness may call `reset-lab.sh`, the lab's own commands, or `inject-capstone-faults.sh` to reach it.
- **Version stamp:** the harness writes the Argo CD version (from `/api/version`), capture date, and state recipe per ID into `courseware/assets/screenshots/capture-log.md`.
- **UI routes and labels** below are descriptive. Exact routes and button labels must be confirmed at capture (P-18) and never invented in a guide.
- **Alpha UI:** SS-S5-01, SS-S5-02, SS-L4-03, SS-L4-04, SS-L4-05, SS-L4-07, and SS-L4-10 show the ApplicationSet UI, which is **Alpha since v3.5.0** (EV-12). Their captions must say so. Recapture on any Argo CD version change.
- **Spoiler rule:** `07` screenshots use causes different from the capstone faults, and the capstone guide shows only SS-CAP-01/02/03.

### 9.2 Screenshot inventory (71 IDs)

| ID | Guide | Filename (under `assets/screenshots/`) | UI page / state | Produced by | Highlight | Fidelity |
|---|---|---|---|---|---|---|
| SS-ENV-01 | student-setup-guide | `day-1/env-01-applications-baseline.png` | Applications list after first login | CP-baseline | `hello-reconcile` tile with Synced/Healthy | full |
| SS-ENV-02 | student-setup-guide | `day-1/env-02-gitea-course-repos.png` | Gitea org `course` repo list | CP-baseline | five repos | full |
| SS-S1-01 | `01` | `day-1/s01-01-applications-list.png` | Applications list | CP-baseline | the single Application and its destination | full |
| SS-S1-02 | `01` | `day-1/s01-02-gitea-commit-history.png` | Gitea commits for `hello-reconcile` `main` | CP-baseline | author, message, SHA columns | full |
| SS-S2-01 | `02` | `day-1/s02-01-app-tree-synced-healthy.png` | `hello-reconcile` tree view | CP-baseline | sync-status and health-status indicators (separately) | full |
| SS-S2-02 | `02` | `day-1/s02-02-app-details-summary.png` | App details summary panel | CP-baseline | repo URL, target revision, path, destination, project, sync policy | panel |
| SS-S2-03 | `02` | `day-1/s02-03-live-manifest-tracking-id.png` | Deployment node, live manifest | CP-baseline | `argocd.argoproj.io/tracking-id` annotation | panel |
| SS-L1-01 | `lab-01` | `day-1/lab-01-01-login.png` | Login page | logged out | username/password fields | full |
| SS-L1-02 | `lab-01` | `day-1/lab-01-02-applications-healthy.png` | Applications list (**healthy environment check**) | CP-lab-01 | Synced/Healthy | full |
| SS-L1-03 | `lab-01` | `day-1/lab-01-03-resource-tree.png` | Tree view | guided walkthrough | Application → Service/ConfigMap/Deployment → ReplicaSet → Pod chain | full |
| SS-L1-04 | `lab-01` | `day-1/lab-01-04-app-manifest.png` | App details, manifest tab | guided walkthrough | `source`, `destination`, `project`, `syncPolicy` blocks | panel |
| SS-L1-05 | `lab-01` | `day-1/lab-01-05-outofsync-after-refresh.png` | Tree after push and Refresh | E2 | OutOfSync on the app and the ConfigMap node | full |
| SS-L1-06 | `lab-01` | `day-1/lab-01-06-app-diff.png` | Diff view | E2 | changed `message` line | panel |
| SS-L1-07 | `lab-01` | `day-1/lab-01-07-sync-panel.png` | Sync panel open | E2, before sync | prune unchecked, dry-run option, resource list | panel |
| SS-L1-08 | `lab-01` | `day-1/lab-01-08-synced-new-revision.png` | After sync | E2 | last sync Succeeded and the new revision SHA | full |
| SS-L1-09 | `lab-01` | `day-1/lab-01-09-pod-events.png` | Pod node, events tab | E4 | event reasons | panel |
| SS-L1-10 | `lab-01` | `day-1/lab-01-10-history.png` | History and rollback panel | after E2 | two revisions | panel |
| SS-L1-11 | `lab-01` | `day-1/lab-01-11-deployment-outofsync-checksum.png` | Tree after Part 3 push and Refresh | E2 Part 3, before sync | OutOfSync on the Deployment node, ConfigMap Synced | full |
| SS-L1-12 | `lab-01` | `day-1/lab-01-12-rollout-new-replicaset.png` | Tree after Part 3 sync | E2 Part 3 | two ReplicaSets (old scaled to 0, new with a running Pod) | full |
| SS-S3-01 | `03` | `day-1/s03-01-settings.png` | Settings landing page | CP-baseline | Repositories, Clusters, Projects entries | full |
| SS-S3-02 | `03` | `day-1/s03-02-clusters-before-registration.png` | Settings, Clusters | CP-lab-02 | only `in-cluster` listed | full |
| SS-L2-01 | `lab-02` | `day-1/lab-02-01-repositories-empty.png` | Settings, Repositories (**environment check**) | CP-lab-02 | no private repo connected | full |
| SS-L2-02 | `lab-02` | `day-1/lab-02-02-repository-connected.png` | Settings, Repositories | E1 | `storefront-gitops` connection Successful | full |
| SS-L2-03 | `lab-02` | `day-1/lab-02-03-cluster-registered.png` | Settings, Clusters | E2 | `workload` row Successful, server URL | full |
| SS-L2-04 | `lab-02` | `day-1/lab-02-04-cluster-detail.png` | Cluster detail | E2 | namespaces scoping, labels | panel |
| SS-L2-05 | `lab-02` | `day-1/lab-02-05-project-storefront.png` | Project `storefront` detail | E4 | source repos, destinations, empty cluster-resource allow list | full |
| SS-L2-06 | `lab-02` | `day-1/lab-02-06-applications-with-dev.png` | Applications list | E4 | `storefront-dev` OutOfSync/Missing | full |
| SS-L2-07 | `lab-02` | `day-1/lab-02-07-dev-tree-missing.png` | `storefront-dev` tree | E4 | Missing resource nodes | full |
| SS-L2-08 | `lab-02` | `day-1/lab-02-08-dev-diff-all-new.png` | Diff view | E4 | desired-only resources | panel |
| SS-L2-09 | `lab-02` | `day-1/lab-02-09-repository-failed.png` | Settings, Repositories (troubleshooting) | E5 record 1 applied | Failed status and message | full |
| SS-L2-10 | `lab-02` | `day-1/lab-02-10-cluster-failed.png` | Settings, Clusters (troubleshooting) | E5 record 2 applied | Failed connection and message | full |
| SS-S4-01 | `04` | `day-1/s04-01-sync-options.png` | Sync panel with options expanded (`storefront-dev`) | CP-lab-03 | prune, dry run, apply only, force, sync-option checkboxes | panel |
| SS-S4-02 | `04` | `day-1/s04-02-sync-policy.png` | App details, sync policy section | CP-lab-03 | auto-sync, prune, self-heal controls | panel |
| SS-S4-03 | `04` | `day-1/s04-03-presync-hook-in-tree.png` | `storefront-dev` tree after sync | `lab-03` E1 state | PreSync Job node | full |
| SS-S4-04 | `04` | `day-1/s04-04-history-rollback.png` | History and rollback | `lab-03` E2 state | rollback action on an older revision | panel |
| SS-L3-01 | `lab-03` | `day-1/lab-03-01-env-check.png` | `storefront-dev` OutOfSync/Missing (**environment check**) | CP-lab-03 | status badges | full |
| SS-L3-02 | `lab-03` | `day-1/lab-03-02-synced-with-hook.png` | Tree after first sync | E1 | completed PreSync Job; Healthy Deployment | full |
| SS-L3-03 | `lab-03` | `day-1/lab-03-03-parameters-values-files.png` | App details, parameters (`storefront-staging`) | E2 | values-files list | panel |
| SS-L3-04 | `lab-03` | `day-1/lab-03-04-live-drift.png` | Tree after `kubectl scale` | E3 | Deployment OutOfSync | full |
| SS-L3-05 | `lab-03` | `day-1/lab-03-05-drift-diff.png` | Diff view | E3 | `spec.replicas` live vs desired | panel |
| SS-L3-06 | `lab-03` | `day-1/lab-03-06-auto-sync-enabled.png` | Sync policy section | E4 | automated and self-heal on, prune off | panel |
| SS-L3-07 | `lab-03` | `day-1/lab-03-07-self-heal-evidence.png` | Sync/operation status | E4, after drift | initiated by the automated sync policy | panel |
| SS-L3-08 | `lab-03` | `day-1/lab-03-08-comparison-error.png` | `storefront-staging` with error condition | E5 part A | Helm error text | full |
| SS-L3-09 | `lab-03` | `day-1/lab-03-09-presync-hook-failed.png` | `storefront-dev` sync failed | E5 part B | failed PreSync Job; operation Failed; later wave not applied | full |
| SS-L3-10 | `lab-03` | `day-1/lab-03-10-recovered.png` | Applications list | after E5 | dev and staging Synced/Healthy | full |
| SS-S5-01 | `05` | `day-2/s05-01-applicationsets-list.png` | ApplicationSets list (Alpha UI) | CP-lab-05 | `storefront` row | full |
| SS-S5-02 | `05` | `day-2/s05-02-applicationset-tree.png` | ApplicationSet detail tree | CP-lab-05 | AppSet node → 3 generated Applications | full |
| SS-S5-03 | `05` | `day-2/s05-03-root-app-tree.png` | `platform-root` tree | CP-lab-05 | child Application nodes | full |
| SS-L4-01 | `lab-04` | `day-2/lab-04-01-env-check.png` | Applications list (**environment check**) | CP-lab-04 | no storefront Applications | full |
| SS-L4-02 | `lab-04` | `day-2/lab-04-02-cluster-labels.png` | Cluster detail `workload` | CP-lab-04 | labels `cluster-role`, `region` | panel |
| SS-L4-03 | `lab-04` | `day-2/lab-04-03-appset-preview-diff.png` | ApplicationSet Preview tab, DIFF sub-tab (Alpha) | E2 (edited selector, not saved) | proposed extra Applications | full |
| SS-L4-04 | `lab-04` | `day-2/lab-04-04-applicationsets-list.png` | ApplicationSets list | E1 | `storefront` row | full |
| SS-L4-05 | `lab-04` | `day-2/lab-04-05-appset-generated-tree.png` | ApplicationSet detail tree | E1 | three generated Applications | full |
| SS-L4-06 | `lab-04` | `day-2/lab-04-06-generated-apps-list.png` | Applications list (filtered) | E1 | `storefront-*-workload` | full |
| SS-L4-07 | `lab-04` | `day-2/lab-04-07-appset-error-condition.png` | ApplicationSet summary or events | E5 part A | ErrorOccurred with missing-key message | panel |
| SS-L4-08 | `lab-04` | `day-2/lab-04-08-root-child-tree.png` | `platform-root` tree | E4 | root → three children | full |
| SS-L4-09 | `lab-04` | `day-2/lab-04-09-child-broken-root-fine.png` | `platform-root` tree plus child status | E5 part B | child ComparisonError vs root status | full |
| SS-L4-10 | `lab-04` | `day-2/lab-04-10-appset-sync-policy.png` | ApplicationSet manifest tab | E3 | `applicationsSync: create-update`, `preserveResourcesOnDeletion` | panel |
| SS-S6-01 | `06` | `day-2/s06-01-projects-list.png` | Settings, Projects | CP-capstone (pre-fault) | four projects | full |
| SS-S6-02 | `06` | `day-2/s06-02-team-a-dev-view.png` | Applications list as `team-a-dev` | CP-capstone (pre-fault) | only permitted Applications visible | full |
| SS-S6-03 | `06` | `day-2/s06-03-sync-window.png` | Project, sync windows section | `lab-05` stretch state | deny window row | panel |
| SS-L5-01 | `lab-05` | `day-2/lab-05-01-env-check-projects.png` | Settings, Projects (**environment check**) | CP-lab-05 | no `team-a` yet | full |
| SS-L5-02 | `lab-05` | `day-2/lab-05-02-project-team-a.png` | Project `team-a` detail | E1 | sources, destinations, cluster-resource list | full |
| SS-L5-03 | `lab-05` | `day-2/lab-05-03-destination-rejected.png` | Application error or condition | E3 part a | "not permitted in project" message | panel |
| SS-L5-04 | `lab-05` | `day-2/lab-05-04-cluster-scoped-blocked.png` | Sync result or resource status | E3 part b | ClusterRole not permitted | panel |
| SS-L5-05 | `lab-05` | `day-2/lab-05-05-argocd-rbac-denied.png` | Sync attempt as `team-a-dev` | E4 part a | permission-denied notification | full |
| SS-L5-06 | `lab-05` | `day-2/lab-05-06-kubernetes-forbidden.png` | Sync result for the network-policy attempt | E4 part b | "forbidden ... `system:serviceaccount:argocd-access:argocd-manager`" | panel |
| SS-L5-07 | `lab-05` | `day-2/lab-05-07-delete-denied.png` | Delete attempt as `team-a-dev` | E5 | permission denied | panel |
| SS-S7-01 | `07` | `day-2/s07-01-repo-unreachable.png` | Application ComparisonError from an unreachable repo | harness: CP-lab-05, `docker stop lab-gitea`, hard refresh (restart afterward) | condition message | full |
| SS-S7-02 | `07` | `day-2/s07-02-sync-retrying.png` | Operation "retrying" state | harness: retry policy plus failing hook on a scratch Application | retry attempt message | panel |
| SS-CAP-01 | capstone | `day-2/capstone-01-incident-start.png` | Applications list at incident start | CP-capstone + `inject all` | none (participants must read it themselves) | full |
| SS-CAP-02 | capstone | `day-2/capstone-02-restored.png` | Applications list, all Synced/Healthy | CP-capstone-restored | all badges | full |
| SS-CAP-03 | capstone | `day-2/capstone-03-clusters-restored.png` | Settings, Clusters | CP-capstone-restored | `workload` Successful | full |

Count: 2 (environment) + 69 (guides) = **71**.

---

## 10. Assessment strategy

### 10.1 Instruments by file type

| Instrument | Where | Design rule | Answer location |
|---|---|---|---|
| **Quick Checks** (2-4 per concept guide; 27 total, listed in section 7.2) | Concept guides | Scenario, prediction, diagnosis, or sorting. Never pure definition recall. Multiple-choice distractors are built from named misconceptions. Each passes the `assessment-designer` test: "could someone answer this by memorizing one sentence?" | Answered **inline** in the guide (collapsible `<details>` block), with rationale |
| **Try It Yourself** (1 per concept guide) | Concept guides | Optional, 5-10 minutes, reset-safe or read-only, uses only concepts already explained in that file or earlier | Expected-output shape shown inline |
| **Predict-then-observe prompts** | Every lab, before every sync, reveal, or diagnostic | The participant writes a prediction in the guide's prediction table *before* acting | Self-checked against observed output |
| **Exercises** (Lab 1: 4, Lab 2: 5, Lab 3: 5, Lab 4: 6, Lab 5: 5) | Lab guides | Ordered easy to hard; at least one pure application of the walkthrough pattern before any diagnosis; the contract fields in section 7.3 | SOLUTION file only |
| **Checkpoints** | End of every lab | Participant-checkable: `argocd app get`/`list` output shape, UI status, `kubectl auth can-i` matrix, `reset-lab.sh <next CP> --verify-only` | Self-check; SOLUTION shows the real output |
| **Capstone diagnostic checklist** | Capstone | Triage grid plus per-area sanity checks plus `capstone-check` plus written reflection | SOLUTION file |

### 10.2 Capstone diagnostic checklist (structure `lab-engineer` must implement)

1. **Triage grid** (completed in P1 before any change). Columns: *Symptom (as observed)*, *Where observed (UI/CLI/kubectl/metrics)*, *Method step (1-6)*, *Layer* (platform component / cluster connectivity / Git source and rendering / generation and ownership / policy (Argo CD RBAC, AppProject, Kubernetes RBAC) / runtime health and drift), *Hypothesis*, *Planned controlled change*.
2. **Change log** (P2). One row per change: timestamp, what changed, through which declarative path (Git commit SHA or `apply-argocd-config`), and the expected observable result.
3. **Per-area sanity checks.** Observable healthy signals only (for example "the workload cluster shows a Successful connection status and a recent cache update"). Never a cause or fix.
4. **Verification** (P3). `capstone-check`, then `argocd app list` shape, then SS-CAP-02 comparison.
5. **Reflection prompts** (P4), one set per fault: *What was the root cause? What evidence proved it? What did you change and why that layer? Which guardrail (AppProject, RBAC, `applicationsSync` policy, `FailOnSharedResource=true`, pinned revisions, preview-in-PR, progressive sync where appropriate) or monitoring signal (component restarts, `argocd_cluster_connection_status`, `argocd_app_info` health/sync labels, repo-server pending requests, AppSet condition alerts, notifications) would have prevented or caught it sooner?*
6. **Completion bar** (R-9): layer correct for 7 of 7 faults, 5 or more restored, 7 reflections written.

### 10.3 Retrieval schedule (spaced, deliberate)

| Concept | First assessed | Re-assessed |
|---|---|---|
| Sync status vs health status | S2-QC1 | `lab-01` E4 → `lab-02` E4 → `lab-04` E5 part B → capstone F6 |
| Reconciliation timing (refresh vs poll vs webhook) | S2-QC3 | `lab-01` E2 → S3-QC3 → S7-QC1 |
| Least-privilege credentials, 401 vs 403 | S3-QC4 | `lab-02` E3 → `lab-05` E4 → capstone F4/F5 |
| Rendering failures | S2 status table | `lab-03` E5 part A → capstone F1 |
| Blast radius and preview | S5-QC1 | `lab-04` E2 → capstone F2 |
| Ownership and cascade | S5-QC4 | `lab-04` E4 → `lab-05` E5 → capstone F3 |
| Ignore rules vs meaningful drift | S7-QC3 | capstone F6 |

---

## 11. Visual teaching opportunities (feeds the `visual-teaching` skill)

**Format rules.** Use Mermaid (fenced as `mermaid`) for flows, trees, and timelines. Use Markdown tables for decisions and comparisons. Use a fenced `text` block for topology when Mermaid layout is unclear. Each diagram reveals **one** relationship, is paired with a prediction or observation question, and is followed by a "what to notice" debrief.

| ID | Diagram | The single relationship it reveals | Used in |
|---|---|---|---|
| V-01 | Production topology with lab-mapping overlay | Argo CD lives on a management cluster and reaches out to registered workload clusters; CI never touches the clusters. Lab names mapped to Rancher/RKE2. | `01`, `03`, `lab-02` recap |
| V-02 | Reconciliation loop: Git change → render → compare → synchronize → health assessment | The loop runs continuously and each stage leaves distinct evidence | `01`, `02`, `lab-01`, `07`, capstone (recurring anchor) |
| V-03 | CI/CD responsibility boundary | CI ends at a Git commit; Argo CD begins at the Git read | `01` |
| V-04 | Argo CD vs Argo Workflows table | Continuous state convergence vs run-to-completion task orchestration | `01` only |
| V-05 | Component architecture | Which component handles which request, and where each failure surfaces | `02`, `07` |
| V-06 | Four states: desired (Git), target (revision), rendered (manifests), live (cluster) | Sync status is a comparison of rendered vs live, not Git vs live | `02`, `lab-01` |
| V-07 | Sync × health 2×3 matrix | The two statuses are independent axes | `02` |
| V-08 | Annotated Application YAML | Every field is an external dependency | `02`, `lab-01` |
| V-09 | Tracking vs ownerReferences | Argo CD tracks top-level resources by annotation; Kubernetes owns children via ownerReferences | `02` |
| V-10 | Installation decision table (multi-tenant/core × non-HA/HA) | Which install fits a platform team, and why | `03` |
| V-11 | Cluster registration trust chain | Cluster Secret → token → ServiceAccount → RoleBinding per namespace; network path by name | `03`, `lab-02` |
| V-12 | Webhook vs polling timeline | Detection latency and the direction the network must allow | `03`, `07` |
| V-13 | Git vs injected configuration table | What is safe to commit | `03` |
| V-14 | Helm rendering pipeline plus precedence ladder | Argo CD runs `helm template`, not a release; which value wins | `04` |
| V-15 | Repo-layout options comparison | Directory-per-env vs branch-per-env vs repo-per-env trade-offs | `04`, `lab-04` E6 |
| V-16 | Sync phase/wave timeline | Ordering, and where one failure blocks the rest | `04`, `lab-03` |
| V-17 | Drift before/after with the self-heal loop | Manual sync reports drift; self-heal reverts it | `04`, `lab-03` |
| V-18 | Promotion flow dev → staging → prod | Promotion is a Git change; prod is pinned to an immutable tag | `04` |
| V-19 | Generator fan-out (matrix of clusters and env files) | One input change multiplies across every generated Application | `05`, `lab-04` |
| V-20 | App-of-Apps ownership tree with cascade path | What deleting a root removes | `05`, `lab-04` |
| V-21 | Pattern decision table (the outline's own, verbatim) | When to prefer each pattern | `05`, `lab-04` E6 |
| V-22 | Authorization layers | User → Argo CD RBAC → AppProject → cluster credential → Kubernetes RBAC; each layer's error signature | `06`, `lab-05` |
| V-23 | SSO group → role mapping | Identity comes from the IdP, permission from Argo CD RBAC | `06` |
| V-24 | Secret-management patterns | Destination-cluster secret management vs render-time injection | `06` |
| V-25 | Six-step troubleshooting flowchart (outline's method) with the evidence command per step | Evidence before change, source before platform | `07`, capstone |
| V-26 | HA component failure-behavior table | What stops working when each component is down | `07` |
| V-27 | Controller sharding by cluster | Load distributes per cluster, not per Application | `07` |
| V-28 | Management-cluster loss recovery | Git plus export rebuild everything; Redis is recreated | `07` |
| V-29 | Upgrade planning timeline | Release notes → compatibility test (including rendered-manifest diff) → canary → rollback criteria | `07` |
| V-30 | Blank incident triage grid | Symptoms map to layers before any change | capstone |

---

## 12. Current-practice verification checklist

Checked 2026-09-10 against primary sources following the `technical-source-check` procedure. Status values: **VERIFIED** (primary source confirms for the pinned version), **QUALIFIED** (confirmed with caveats or only by an issue or secondary source), **PENDING** (must be confirmed by the named agent before a guide relies on it), **UNVERIFIED** (attempted, not confirmed; the attempt is described). Source paths refer to `github.com/argoproj/argo-cd` at tag `v3.5.2` unless stated otherwise.

### 12.1 Verified and qualified evidence

| ID | Claim | Status | Source | Courseware implication |
|---|---|---|---|---|
| EV-01 | Argo CD latest stable is v3.5.2 (2026-08-27); v3.4.8 and v3.3.14 are other supported lines | VERIFIED | GitHub releases (orchestrator check) plus the release page | Pin v3.5.2 everywhere |
| EV-02 | argo-helm chart `argo-cd` 10.8.4 has `appVersion: v3.5.2` (published 2026-09-09; redis-ha dependency 4.38.0; `kubeVersion >=1.25.0-0`) | VERIFIED | `argoproj/argo-helm` tag `argo-cd-10.8.4`, `charts/argo-cd/Chart.yaml` | Vendor this tgz |
| EV-03 | Tested Kubernetes: Argo CD 3.5 = v1.36, v1.35, v1.34, v1.33. Argo CD 3.4 and 3.3 = v1.35, v1.34, v1.33, v1.32 | VERIFIED | `docs/operator-manual/tested-kubernetes-versions.md` (included by `installation.md`) | k3s 1.35 is inside every supported line, which is useful for the `07` version-matching lesson |
| EV-04 | k3s v1.35 channel latest is v1.35.8+k3s1; image `rancher/k3s:v1.35.8-k3s1` exists (amd64, arm64, arm) | VERIFIED | `update.k3s.io/v1-release/channels`; Docker Hub tag API | Pin it |
| EV-05 | kubectl stable-1.35 is v1.35.8 | VERIFIED | `dl.k8s.io/release/stable-1.35.txt` | Pin it |
| EV-06 | k3d v5.9.0 released 2026-06-02; its notes mention a hard-coded k3s fallback of 1.32 (the build machine reports v1.35.5-k3s1 as its default) | VERIFIED | `k3d-io/k3d` releases | Always pass `--image` |
| EV-07 | Argo CD 3.5 repo-server bundles **Helm v4.2.1**; `spec.source.helm.version: v3` is ignored; Helm 4 OCI requires explicit plain-HTTP flags | VERIFIED | `hack/tool-versions.sh` (`helm4_version=4.2.1` at v3.5.0 and v3.5.2); `docs/operator-manual/upgrading/3.4-3.5.md` "Helm Upgraded" section; 3.5.0 changelog #28076 (migration) and #28273 (4.2.1 bump). Upstream inconsistency: the Breaking Changes heading in the same doc says 4.2.0. | VM helm CLI pinned to 4.2.1; `04` states Helm 4 |
| EV-08 | **Prior-draft claim "3.5 moved to Helm 4 and this changes null-coalescing/rendering"**: Helm 4 confirmed (EV-07). The rendering change is **QUALIFIED**: reported in open issue #29059 (duplicate #29068). The same chart and values render explicit `null` fields (Loki chart example) where Argo CD 3.4 (Helm 3.19.2) omitted them. Separately, helm/helm#31943 (open) reports that using `null` to delete a default key no longer works reliably in Helm 4. **Not** documented in the official 3.4-3.5 upgrade guide. | QUALIFIED | argoproj/argo-cd#29059, #29068; helm/helm#31943 | Use as the `07` upgrade-testing case study with qualified wording ("reported by users; tracked upstream"). Sample charts avoid null patterns (P-3). |
| EV-09 | Generators: List, Cluster, Git, Matrix, Merge, SCM Provider, Pull Request, Cluster Decision Resource, Plugin | VERIFIED | `docs/operator-manual/applicationset/Generators.md` (stable) | R-4 table |
| EV-10 | `goTemplate: true`; `goTemplateOptions: ["missingkey=error"]` is recommended but not the default (backward compatibility) | VERIFIED | `docs/operator-manual/applicationset/GoTemplate.md` | `lab-04` E1/E5 |
| EV-11 | `applicationsSync`: `create-only`, `create-update`, `create-delete`, `sync`. `preserveResourcesOnDeletion: true`. Controller `--policy` takes precedence when set. From source: `--policy` defaults to `""` (AppSets default to `sync` but may override), and `--enable-policy-override` defaults to `policy == ""`, so **per-AppSet policy is honored by default** and locked once a controller policy is set | VERIFIED | `Controlling-Resource-Modification.md`; `cmd/argocd-applicationset-controller/commands/applicationset_controller.go` | `lab-04` E3; `lab-05` stretch |
| EV-12 | Preview: `argocd appset create --dry-run` ("evaluate the ApplicationSet template on the server", `-o json/yaml/wide`). UI: `/applicationsets` list, detail tabs Summary/Manifest/Events/**Preview** (sub-tabs DIFF, LIVE APPS, DESIRED APPS). Preview edits are never saved. Preview requires `applicationsets, create` on the project. **Alpha feature since v3.5.0.** | VERIFIED | `docs/user-guide/commands/argocd_appset_create.md`; `argo-cd.readthedocs.io/en/release-3.5/user-guide/application-set-ui/`; 3.5.0 changelog #26666, #27799, #26601 | Include the Preview screenshot (SS-L4-03) with an Alpha caption; CLI dry-run is primary |
| EV-13 | Progressive Syncs: **Beta since v3.3.0**, enabled via `applicationsetcontroller.enable.progressive.syncs`; strategy `RollingSync`; **forces autosync disabled on all generated Applications**. The controller flag help text still says "experimental." | VERIFIED (with a label inconsistency) | `Progressive-Syncs.md`; controller flag source | `05` version box only; no hands-on dependency |
| EV-14 | Application controller shards **by cluster** (`ARGOCD_CONTROLLER_REPLICAS`); algorithms `legacy` (default), `round-robin` (Alpha), `consistent-hashing` (Alpha); `--status-processors` 20, `--operation-processors` 10 | VERIFIED | `docs/operator-manual/high_availability.md` | V-27; S7-QC2 |
| EV-15 | Redis is "only used as a disposable cache and can be safely rebuilt without service disruption"; the HA install needs at least 3 nodes (anti-affinity); repo-server `--parallelismlimit`, `ARGOCD_EXEC_TIMEOUT` (90 s default), disk and memory pressure notes | VERIFIED | `high_availability.md` | `07`; instructor `ha-demo` needs 3+ nodes |
| EV-16 | `argocd admin export` and `import` still documented; export will not fail when run in the wrong namespace | VERIFIED | `docs/operator-manual/disaster_recovery.md` | `S7-TRY` must pass `-n argocd` |
| EV-17 | Notifications controller present in 3.5.2 (release note fixes it). Metrics: controller :8082, API server :8083, repo-server :8084, commit server :8087; `argocd_app_info`, `argocd_app_sync_total`, `argocd_app_reconcile`, `argocd_cluster_connection_status`, `argocd_git_request_total`, `argocd_repo_pending_request_total`, `argocd_redis_request_total` documented | VERIFIED | v3.5.2 release notes; `docs/operator-manual/metrics.md` | `07`; capstone reflections |
| EV-18 | Default resource tracking is annotation-based (`argocd.argoproj.io/tracking-id`) since 3.0 | VERIFIED | `upgrading/2.14-3.0.md`; `argocd-cm.yaml` | `02`, `lab-01` E3 |
| EV-19 | Resource-level health is no longer persisted in the Application CR by default since 3.0 (`controller.resource.health.persist`) | VERIFIED | `upgrading/2.14-3.0.md` | `02` must say where each status lives; `lab-01` E4 |
| EV-20 | 3.0: `update`/`delete` RBAC applies only to the Application itself (not sub-resources); logs RBAC enforced; legacy repo config in `argocd-cm` removed | VERIFIED | `upgrading/2.14-3.0.md` | `06`, `lab-05` |
| EV-21 | 3.3: the ApplicationSet CRD exceeds the client-side apply size limit, so upgrades require server-side apply with conflict resolution | VERIFIED | `upgrading/3.2-3.3.md` | `07` upgrade case; `03` self-management note |
| EV-22 | 3.4: cluster version reported as `vMajor.Minor.Patch`; app health is `Missing` only when all resources are missing | VERIFIED | `upgrading/3.3-3.4.md` | Screenshot text expectations |
| EV-23 | Auto-sync: `automated.enabled`, `prune`, `selfHeal`, `allowEmpty`. Prune and allowEmpty are off by default. Self-heal timeout 5 s (`--self-heal-timeout-seconds`). `timeout.reconciliation` 120 s plus 60 s jitter (maximum about 3 min). A failed sync of the same commit and parameters is not re-attempted. Rollback is blocked while auto-sync is on. | VERIFIED | `docs/user-guide/auto_sync.md` | `04`, `lab-03` |
| EV-24 | Sync options: `Prune=false`/`confirm`, `Delete=false`/`confirm`, `PruneLast`, `ApplyOutOfSyncOnly`, `ServerSideApply`, `CreateNamespace`, `FailOnSharedResource`, `RespectIgnoreDifferences`, `PrunePropagationPolicy`, `Replace`, `Force`, `Validate=false`, `SkipDryRunOnMissingResource`, `ClientSideApplyMigration` | VERIFIED | `docs/user-guide/sync-options.md` | `04` reference table |
| EV-25 | Phases `PreSync`/`Sync`/`PostSync`/`SyncFail`/`PostDelete`/`Skip`; delete policies `HookSucceeded`/`HookFailed`/`BeforeHookCreation` (default); ordering phase → wave → kind → name; wave delay 2 s (`ARGOCD_SYNC_WAVE_DELAY`); the next wave waits for Healthy | VERIFIED | `docs/user-guide/sync-waves.md` | V-16; `lab-03` |
| EV-26 | Helm used only via `helm template`; hook mapping (`pre-install`/`pre-upgrade` → PreSync, `post-*` → PostSync, `hook-weight` → sync-wave; test and rollback hooks unsupported); precedence `parameters > valuesObject > values > valueFiles > chart values.yaml`; last value file wins; glob `valueFiles` (3.5.0 #26768); `ignoreMissingValueFiles` | VERIFIED | `docs/user-guide/helm.md`; 3.5.0 changelog | `04`, `lab-03` |
| EV-27 | `argocd cluster add` flags `--namespace`, `--system-namespace`, `--cluster-resources`, `--service-account`, `--label`, `--annotation`, `--upsert`, `--cluster-endpoint`. By default it creates `argocd-manager` with cluster-admin | VERIFIED | `docs/user-guide/commands/argocd_cluster_add.md` | `03` misconception |
| EV-28 | Declarative cluster Secret (`argocd.argoproj.io/secret-type: cluster`; `name`, `server`, `namespaces`, `clusterResources`, `config.bearerToken`, `config.tlsClientConfig.caData`); repository Secret (`type`, `url`, `username`, `password`, optional `project`); `repo-creds` credential template; self-management should use `ServerSideApply=true` | VERIFIED | `docs/operator-manual/declarative-setup.md` | `03`, `lab-02` |
| EV-29 | `argocd-cm` keys `resource.respectRBAC` (`normal`/`strict`), `timeout.reconciliation`, `timeout.reconciliation.jitter`, `application.resourceTrackingMethod`, `accounts.<name>: apiKey, login`, `admin.enabled`, `cluster.inClusterEnabled`, `users.anonymous.enabled` | VERIFIED | `docs/operator-manual/argocd-cm.yaml` | Section 8.6 |
| EV-30 | Health assessment of `argoproj.io/Application` removed in 1.8; restorable via a Lua `resource.customizations` health check | VERIFIED | `docs/operator-manual/health.md` | `05` misconception; `lab-04` stretch |
| EV-31 | Cluster generator params (`name`, `nameNormalized`, `server`, `project`, `metadata.labels.*`, `metadata.annotations.*`, `values.*`). The local cluster has no Secret, so label selectors exclude it unless a Secret is created for it. | VERIFIED | `Generators-Cluster.md` | Bootstrap creates the labeled `in-cluster` Secret; `lab-04` E2; F2 |
| EV-32 | AppProject fields (`sourceRepos`, `destinations`, `clusterResourceWhitelist`/`Blacklist`, `namespaceResourceWhitelist`/`Blacklist`, `sourceNamespaces`, `roles`, JWT via `argocd proj role create-token`, `syncWindows`). The `default` project is permissive. Docs still use whitelist/blacklist names | VERIFIED | `docs/user-guide/projects.md` | `lab-02` E4, `lab-05` E1 |
| EV-33 | ApplicationSet security: only admins should create, update, or delete ApplicationSets; a templated `project` enables escalation | VERIFIED | `applicationset/Security.md` | S6-QC2; hard-code `project` |
| EV-34 | Sync window fields (`kind`, `schedule`, `duration`, `applications`, `namespaces`, `clusters`, `manualSync`, `timeZone`, `andOperator`, `description`); `argocd proj windows add` | VERIFIED | `docs/user-guide/sync_windows.md` | `lab-05` stretch |
| EV-35 | Argo CD recommends destination-cluster secret management (Sealed Secrets, External Secrets Operator, Secrets Store CSI Driver, Vault Secrets Operator, and others) over render-time injection; generated manifests are stored in plaintext in Redis | VERIFIED | `docs/operator-manual/secret-management.md` | V-24 |
| EV-36 | Webhook providers documented: GitHub, GitLab, Bitbucket, Bitbucket Server, Azure DevOps, Gogs. Endpoint `/api/webhook`. Gitea is not listed. Parser order in source: Azure DevOps, Gogs, GitHub, and so on | VERIFIED | `docs/operator-manual/webhook.md`; `util/webhook/webhook.go` | Webhook is a stretch only (P-7) |
| EV-37 | `argocd app manifests --source git/live`, `--revision`, `--local` | VERIFIED | `docs/user-guide/commands/argocd_app_manifests.md` | `lab-01` E3 |
| EV-38 | Rancher authorized cluster endpoint (ACE) lets clients reach an RKE2/K3s downstream API without the Rancher proxy (useful when Rancher is down); it must be enabled manually | VERIFIED (Rancher docs) | `ranchermanager.docs.rancher.com` ACE page | `03` Rancher section (the Argo CD-specific recommendation remains P-14) |
| EV-39 | k3d cross-cluster registration works with a shared Docker network, `https://k3d-<name>-server-0:6443`, and `caData`. `argocd cluster add` fails because the kubeconfig URL is host-only. CoreDNS entries for other containers can disappear after a restart. | QUALIFIED (secondary source) | brakkee.org (2023); k3d discussions #596/#1015 | Section 8.3 design; P-4, P-5 |
| EV-40 | Gitea 1.27.3 (2026-08-29) and `gitea/gitea:1.27.3-rootless` exist; podinfo 6.15.0 (2026-08-31) exists on Docker Hub (amd64, arm64) | VERIFIED | GitHub releases; Docker Hub tag API | Pins |
| EV-41 | 3.4 → 3.5 other changes: React 19 UI (extensions must externalize `react/jsx-runtime`), gRPC event-list type change, impersonation extended to server operations, GnuPG replaced by Source Integrity, opt-in repo-server mTLS, `--repo-server-strict-tls` deprecated | VERIFIED | `upgrading/3.4-3.5.md` | `07` upgrade discussion |

### 12.2 Pending: must be confirmed before a guide relies on it

| ID | Claim to confirm | Owner | How |
|---|---|---|---|
| P-1 | Running repo-server reports Helm v4.2.1 | `environment-engineer` | `kubectl -n argocd exec deploy/argocd-repo-server -- helm version` |
| P-2 | Chart 10.8.4 value key paths for section 8.6 (NodePort, Dex, notifications, admin password, `configs.cm`, `configs.rbac`, `configs.params`, repo-server resources, `commitServer` default) | `environment-engineer` | `helm show values /opt/course/charts/argo-cd-10.8.4.tgz` |
| P-3 | The sample charts render identically with helm CLI 4.2.1 and the repo-server (no null patterns) | `environment-engineer` | `helm template` vs `argocd app manifests` diff |
| P-4 | Certificate verification with `caData` to `k3d-workload-server-0:6443` succeeds | `environment-engineer` | Lab 2 flow in the sandbox |
| P-5 | `lab-gitea` and `k3d-workload-server-0` resolve from mgmt pods, including after a Docker/VM restart | `environment-engineer` | Smoke test, then restart, then retest |
| P-6 | `timeout.reconciliation.jitter: 0s` is accepted | `environment-engineer` | Controller logs plus observed timing |
| P-7 | Gitea webhooks are accepted by Argo CD (via the Gogs parser) | `lab-engineer` (stretch only) | Sandbox test; if it fails, drop the stretch |
| P-8 | Namespaced least-privilege Role set (section 8.7.1) is sufficient with `resource.respectRBAC: normal`; whether any cluster-scoped read is required | `environment-engineer` | Sandbox sync of all course apps |
| P-9 | Two roots claiming one child produce a visible shared-resource/ownership symptom (F3) | `environment-engineer` | Inject F3; record the UI/CLI text |
| P-10 | `argocd admin settings rbac can` syntax and offline policy-file flag in the 3.5.2 CLI | `lab-engineer` | `argocd admin settings rbac can --help` |
| P-11 | With `missingkey=error`, a missing key yields an ApplicationSet error condition while existing Applications stay untouched | `lab-engineer` / `lab-tester` | `lab-04` E5 part A |
| P-12 | Deployment reaches Degraded about 60 s after a failing readiness probe with `progressDeadlineSeconds: 60` | `lab-tester` | F6 and `lab-03` timing |
| P-13 | HPA vs rendered `replicas` produces persistent OutOfSync; exact narrow `ignoreDifferences` syntax (`jsonPointers` or `jqPathExpressions`) | `environment-engineer` / `lab-solution-engineer` | F6 |
| P-14 | Argo CD-specific guidance for registering Rancher-managed clusters (ACE or direct API endpoint vs Rancher proxy URL with a Rancher token) | `lab-engineer` (`03`) | Rancher and Argo CD docs; present as a trade-off, not a rule, unless a primary source states it |
| P-15 | `templatePatch` syntax, if `lab-04` makes prod manual-sync | `lab-engineer` | `applicationset/Template.md`; otherwise use uniform sync policy |
| P-16 | Exact pins for busybox, the Redis image in chart 10.8.4, Docker Engine, `yq`, `jq`, Terraform providers | `environment-engineer` | Registries and release pages |
| P-17 | podinfo 6.15.0 environment variable names for message and color | `environment-engineer` | podinfo README / `--help` |
| P-18 | Argo CD 3.5.2 UI routes and labels (diff, history/rollback, sync panel options, settings pages, ApplicationSet detail route) | `lab-engineer` / screenshot harness | Live capture |
| P-19 | Non-cascade deletion (`argocd app delete --cascade=false` or the UI option) and the `resources-finalizer.argocd.argoproj.io` name in 3.5 | `lab-engineer` | `argocd app delete --help` plus sandbox |
| P-20 | Exact RBAC deny syntax for `applications, delete, storefront/*` in 3.x | `lab-engineer` | `docs/operator-manual/rbac.md` |
| P-21 | `argocd cluster add k3d-workload` failure message in this topology (`lab-02` stretch) | `lab-engineer` | Sandbox |

### 12.3 Unverified (attempted, not confirmed)

| ID | Item | What was tried | Handling |
|---|---|---|---|
| U-1 | Gitea webhook compatibility with Argo CD | Docs list Gogs, not Gitea; source shows the Gogs parser is checked before GitHub; Gitea's header behavior was not checked | Optional stretch only (R-7, P-7) |
| U-2 | Whether k3s adds the node container hostname to its serving-certificate SANs by default | A secondary source succeeded with `caData`; no k3s primary source found | Add an explicit `--tls-san` (section 8.3) |
| U-3 | Chart 10.8.4 defaults for `notifications.enabled`, `commitServer.enabled`, `server.insecure`, `applicationSet.replicas` | `values.yaml` fetch was truncated | Set explicitly; confirm via P-2 |
| U-4 | Helm v4.2.1 publication date | The release page fetch returned an implausible year | Irrelevant to the pin (the release exists) |

---

## 13. Risk and overload analysis

| # | Risk | Likelihood / impact | Mitigation (owner) |
|---|---|---|---|
| K-1 | Content overload in `03`, `04`, `05`, `06`, `07` | High / High | R-2 to R-6; `pedagogy-reviewer` checks pacing against section 5.2 budgets |
| K-2 | `lab-02` overruns (the most mechanics-heavy lab) | High / High | Provided RBAC manifest and skeletons; E5 second record optional (R-7); `lab-tester` must time a clean run at 45 minutes or less |
| K-3 | Capstone too large for 90 minutes | Medium / High | Connected faults with masking; `capstone-check`; instructor per-fault revert; completion bar (R-9) |
| K-4 | Cross-cluster DNS breaks after a VM or Docker restart | Medium / High | `refresh-coredns-hosts.sh` in bootstrap and reset; reboot test (P-5) |
| K-5 | Reconciliation-timing nondeterminism stalls labs | Medium / Medium | 60 s interval with 0 s jitter (lab-only deviation, disclosed); teach Refresh; `argocd app wait` in checks |
| K-6 | Local helm/kubectl differ from Argo CD (Helm 4 vs 3; kubectl skew) | High if ignored / High | Pinned tools directory; versions recorded in every test report (section 8.2) |
| K-7 | Alpha ApplicationSet UI changes in a patch release | Medium / Medium | CLI dry-run primary; Alpha captions; recapture on a version change |
| K-8 | Resets hang on finalizers (for example while the cluster is disconnected) | Medium / High | Reset reverts faults first; finalizer wait with timeout and a clear message |
| K-9 | F7 memory limit not deterministic | Medium / Medium | Calibrate; CPU-throttle fallback (section 8.9) |
| K-10 | Participants deviate and later labs break | Medium / Medium | `reset-lab.sh --verify-only` in every Environment check |
| K-11 | Corporate networks block SSH tunnels | Low-Medium / High | `allowed_ui_cidrs` fallback; participants may pair (outline allows pairs) |
| K-12 | Self-signed certificate warning confuses participants | Medium / Low | Student setup guide screenshot and explanation |
| K-13 | Two Git URLs for the same repo | Medium / Medium | Single `lab-gitea` URL via `/etc/hosts` or `insteadOf` (section 8.3) |
| K-14 | Rancher material with no Rancher instance | Medium / Medium | Diagrams plus the mapping table; no fabricated UI; P-14 for claims |
| K-15 | Capstone spoilers leak through `07` screenshots or the capstone guide | Medium / High | Spoiler rule (section 9.1); `course-reviewer` checks |
| K-16 | Day 2 reset discards Day 1 participant work | Certain / Low | Explained in the `lab-04` recap as intentional; Day 1 answers exist in the `cp-lab-04` tag |
| K-17 | Helm 4 rendering differences surprise chart authors | Low for the course's charts / Medium | No null patterns (P-3); taught as an upgrade lesson (EV-08) |
| K-18 | VM undersized for the capstone | Low / High | 16 GiB baseline; measure actuals (section 8.10) |
| K-19 | Scope creep (IdP, Prometheus stack, Rollouts, Hydrator) | Medium / Medium | Explicit exclusions (section 5.3) |
| K-20 | Unverified webhook path wastes class time | Low / Low | Stretch only |

---

## 14. Proposed output file tree

The canonical layout, plus two documented additions: `environment/repos/` and `environment/checkpoints/` (seed content has to live somewhere versioned), and the solution-path deviation from section 7.1.

```text
courseware/
  00-course-blueprint.md                      # this file
  01-insight-map.md                           # insight-generator (Phase 2)
  environment/
    instructor-setup-guide.md
    student-setup-guide.md
    terraform/                                # section 8.11
      versions.tf  variables.tf  main.tf  outputs.tf  terraform.tfvars.example
      modules/lab-fleet/  modules/compute-adapter-contract.md
      adapters/local-render/  adapters/<reference-cloud>/
    scripts/
      bootstrap-vm.sh  reset-lab.sh  inject-capstone-faults.sh  capstone-check.sh
      apply-argocd-config.sh  seed-repos.sh
      lib/refresh-coredns-hosts.sh
      capstone/faults/F1 ... F7/
      screenshots/capture.mjs  screenshots/screenshot-manifest.yaml
    repos/                                    # seed sources (addition)
      hello-reconcile/  storefront-gitops/  platform-config/  platform-components/  team-a-apps/
    checkpoints/                              # declarative bundles per CP (addition)
      CP-baseline/ CP-lab-02/ CP-lab-03/ CP-lab-04/ CP-lab-05/ CP-capstone/ CP-capstone-restored/
  day-1/
    01-gitops-and-argo-cd-topology.md
    02-architecture-and-application-model.md
    lab-01-follow-an-application-through-reconciliation.md
    03-production-oriented-configuration.md
    lab-02-configure-platform-and-register-target.md
    04-helm-sync-and-promotion.md
    lab-03-deploy-drift-and-recover.md
  day-2/
    05-applicationsets-and-app-of-apps.md
    lab-04-build-and-troubleshoot-patterns.md
    06-security-multitenancy-governance.md
    lab-05-enforce-platform-guardrails.md
    07-reliability-troubleshooting-lifecycle.md
    capstone-restore-platform.md
  solutions/
    day-1/lab-01-follow-an-application-through-reconciliation-SOLUTION.md
    day-1/lab-02-configure-platform-and-register-target-SOLUTION.md
    day-1/lab-03-deploy-drift-and-recover-SOLUTION.md
    day-2/lab-04-build-and-troubleshoot-patterns-SOLUTION.md
    day-2/lab-05-enforce-platform-guardrails-SOLUTION.md
    day-2/capstone-restore-platform-SOLUTION.md   # mirrors the guide path (deviation from canonical root placement)
  assets/
    screenshots/capture-log.md
    screenshots/day-1/   # env-*, s01-*, s02-*, lab-01-*, s03-*, lab-02-*, s04-*, lab-03-*
    screenshots/day-2/   # s05-*, lab-04-*, s06-*, lab-05-*, s07-*, capstone-*
  reviews/
    environment-validation.md
    lab-validation-<lab-name>.md              # lab-tester, one per lab guide
    solution-validation-<lab-name>.md         # lab-solution-engineer, one per solution
    pedagogy-day-1.md  pedagogy-day-2.md
  99-final-quality-report.md
```

In the filesystem, Day 1 files sort as `01, 02, 03, 04, lab-01, lab-02, lab-03`. **Delivery order** is defined in section 7.1, and every guide's Transition section links to the next file in delivery order.

---

## 15. Definition of done

The course build is done only when **all** of the following hold:

1. **Coverage:** every row in section 6.2 has its evidence present in the named file, and `course-reviewer`'s objective-coverage matrix shows no orphaned bullet.
2. **Files:** all 13 participant files, 6 solution files, 2 setup guides, Terraform, and scripts exist at the section 14 paths.
3. **Contract:** every concept guide and lab guide follows its section order in `standards/content-contract.md`. Concept guides have 2-4 inline-answered Quick Checks and one Try It. Lab exercises carry all six required exercise fields.
4. **Clarity:** no banned phrasing (section 2.3); every acronym expanded on first use per file; every term defined before use, consistent with the section 2.4 register.
5. **Sequencing:** no exercise requires a concept not explained earlier in the same file or an earlier file (checked by `pedagogy-reviewer`).
6. **Scaffolding:** Labs 1-2 at G1, Labs 3-5 at G2, capstone at G3, as defined in section 7.1.
7. **Execution:** every lab guide has a `lab-tester` report of PASS or PASS WITH NOTES from execution in the local two-cluster sandbox using the pinned tools. Every SOLUTION file has an execution-based `lab-solution-engineer` report. No unresolved FAIL.
8. **Environment:** Terraform `fmt`/`validate`/`plan` (local-render) clean; `shellcheck` clean; bootstrap, every `reset-lab.sh CP-*`, and `inject`/`verify`/`revert all` pass locally three times; reboot test passes (P-5); `environment-validation.md` records measured resource peaks. No agent ran `terraform apply`/`destroy`.
9. **Screenshots:** all 71 IDs captured live from v3.5.2 (or an explicit, precisely specified "SCREENSHOT NEEDED" callout remains, listed in the final report). `capture-log.md` records version and date. Alpha captions are present. No capstone spoilers.
10. **Currency:** every P-item that a shipped guide relies on is resolved to VERIFIED or QUALIFIED and recorded in a review file. No guide states an UNVERIFIED item as fact.
11. **Separation:** no solution content, fault causes, or instructor-only notes appear in participant files.
12. **Timing:** `lab-tester` observed runtimes fall within the section 5.2 budgets (labs) or are flagged with a remediation. Pedagogy reviews addressed.
13. **Final gate:** `99-final-quality-report.md` shows no unresolved BLOCKER or HIGH findings.
