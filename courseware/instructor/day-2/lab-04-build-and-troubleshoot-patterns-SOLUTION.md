# Lab 4 — Instructor Walkthrough and Solutions

> **INSTRUCTOR ONLY. Never share this file with participants, never project it, and never paste it into a shared channel.**
> **Participant guide (now a modular arc):** [lab-04/README.md](../../day-2/lab-04/README.md)
> **Exercise → module map:** E1, E2, E3 are in [module 02](../../day-2/lab-04/02-build-and-protect-the-factory.md); E4, E5 in [module 03](../../day-2/lab-04/03-app-of-apps-and-trace-faults.md); E6 in [module 04](../../day-2/lab-04/04-showdown-and-wrap-up.md). Exercise IDs and answers below are unchanged.
> **Timebox:** 75 minutes · **Scaffolding:** G2 (reduced)
> **Verified:** 2026-09-13, end to end, on the course's local k3d two-cluster sandbox: Argo CD `v3.5.2` (chart `10.8.4`), `argocd` CLI `v3.5.2`, Kubernetes `v1.35.8+k3s1`, Helm `v4.2.1`, starting from a freshly reset and verified `CP-lab-04`. Every output block was captured from that run unless marked otherwise. SHAs and times will differ.

---

## How to read this file

| Label | What it tells you |
|---|---|
| **Say** | Words you can use nearly verbatim. Keep the questions. |
| **Do** | A command you run on the projected VM terminal. |
| **Click** | A UI action in Firefox on the VM. |
| **Expect** | What the verified run showed. |
| **Answer key** | What participants should reach, with reasoning. |
| **Wrong turns** | Real mistakes and what they look like. |
| **Wow moment** | The sentence worth pausing on. |
| **If it goes sideways** | A tested recovery. |

---

## 0. Before class — pre-flight (10 minutes)

### 0.1 SECURITY: the Exercise 5A token leak is fixed — confirm it before class

**What used to happen.** When `argocd appset generate` fails with a missing template key, v3.5.2 prints the generator parameters in its error. Those parameters include the cluster Secret's annotations. The course credential Secrets used to be created with client-side `kubectl apply`, which stores a full copy of what it applied — **plaintext bearer token and CA data included** — in the `kubectl.kubernetes.io/last-applied-configuration` annotation. An earlier rehearsal's 5A error printed that annotation.

**What changed (environment fix, 2026-09-13).** `reset-lab.sh` now removes any stale `last-applied-configuration` annotation and applies the credential Secrets **server-side**, which never creates it.

**Re-verified 2026-09-13** at `CP-lab-04` → E1 → E5A: the failing preview (exit 20, `map has no entry for key "namespace"`) was captured to a file and never displayed; it contained **0** `last-applied-configuration`, **0** `bearerToken`, **0** `token`, and **0** `caData` matches. The only Secret that still carries the annotation is `in-cluster`, which holds labels and a server URL — no credential.

**Before class, confirm on your own VM** (each line must print `0`):

```bash
for s in cluster-workload repo-storefront-gitops course-repo-creds; do
  printf '%s ' "$s"; kubectl --context k3d-mgmt -n argocd get secret "$s" -o json | grep -c last-applied-configuration
done
```

If any prints `1` — a VM built or reset before the fix, or a participant who re-applied a Secret client-side in Lab 2 — run `reset-lab.sh CP-lab-04 --local` again and re-check.

**In class:** the failing preview is now safe to project, but it is a 4 KB wall of JSON. The ApplicationSet *conditions* (Section 6) are the readable view. The lesson is still worth one minute with an advanced group: *anything an ApplicationSet template can read, a template author can render* — the cluster generator exposes cluster Secret labels and annotations to templates, which is exactly why credentials must never sit in an annotation.

### 0.2 Confirm the starting checkpoint

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-04 --verify-only --local
```

**Expect** (re-verified 2026-09-13 — 14 rows, identical to the participant guide's Module 1 block):

```text
==> Verification for CP-lab-04
  PASS  Application hello-reconcile absent
  PASS  Application storefront-dev absent
  PASS  Application team-a-guestbook absent
  PASS  AppProject team-a absent
  PASS  AppProject storefront present
  PASS  AppProject platform present
  PASS  Secret in-cluster present
  PASS  Secret repo-storefront-gitops present
  PASS  Secret cluster-workload present
  PASS  Secret course-repo-creds present
  PASS  Repository and cluster Secrets are exactly: in-cluster, repo-storefront-gitops, cluster-workload, course-repo-creds
  PASS  workload namespace storefront-prod present
  PASS  workload SA argocd-manager present
  PASS  workload RoleBinding argocd-deployer (storefront-prod) present

PASS CP-lab-04 is in the expected state.
```

### 0.3 Timing surprises to know about

| Where | What happens (verified) | What to do |
|---|---|---|
| Exercise 5A recovery | After the fix is pushed, the ApplicationSet's `ErrorOccurred` condition stayed `True` until the controller's next scheduled re-read. The controller log shows `requeueAfter=3m0s`, and the condition cleared exactly 3 minutes after the error appeared | Confirm the fix instantly with `argocd appset generate` (it reads Git right now). Tell the room the condition can lag by up to 3 minutes — don't let anyone "fix it again" |
| Exercise 3 | Removing the prod input produces **no warning anywhere** — the ApplicationSet conditions stay green | That silence is the teaching point (Section 4) |

### 0.4 Guide discrepancies to recognize

| Where | Guide says | Actually (verified) |
|---|---|---|
| Exercise 1 | *(fixed in the guide 2026-09-13)* The guide now says the untouched skeleton previews only the header row | Re-verified: **zero rows** (header only), no error — `cluster-role: "TODO"` matches no cluster. With only the selector filled, the preview prints three rows all named `argocd/TODO` |
| Exercise 4, trace loop | *(fixed in the guide 2026-09-13)* The guide now uses a `jsonpath` one-liner | The old `grep` loop printed 13–25 lines per child |
| Exercise 4, Notice | *(fixed in the guide 2026-09-13)* It said a cascade delete of the root removes the children "and their workloads" | Verified: the children go, their workloads stay — the children carry no finalizer (Section 5) |
| Exercise 3 | *(fixed in the guide 2026-09-13)* No timing was given | The controller acts on a pushed input change at its next pass (2 minutes here; up to 3). Before that pass, prod is listed with or without the policy |
| Stretch 1 | *(fixed in the guide 2026-09-13)* It used to say "re-run 5B and observe the difference"; it now compares (a) 5B's `ComparisonError` child with (b) an unpullable agent image | Re-verified: (a) **no difference** — the child keeps health `Healthy`, the root stays `Healthy`; (b) the child goes `Progressing` and the root turns `Progressing` 32 s after the push |
| Stretch 3 | *(fixed in the guide 2026-09-13)* It used to hypothesize one flapping Application; it is now predict → preview → apply → explain, with cleanup | Re-verified: the *preview* shows three same-named rows with no error; the controller **refuses** (`contains applications with duplicate name: collision-test-workload`) and creates no Applications |

---

## Run of show (75 minutes)

| Clock | Segment | Your job |
|---|---|---|
| 0:00–0:05 | Why this matters + environment check | Factory vs family tree |
| 0:05–0:10 | Section 6 — labels and preview | Establish preview → count → apply |
| 0:10–0:25 | E1 — complete the factory | Collect name predictions in writing |
| 0:25–0:33 | E2 — broaden the selector | Arithmetic: 2 × 3 |
| 0:33–0:41 | E3 — protection policy | "Silence is the danger" |
| 0:41–0:51 | E4 — root and children | Trace ownership |
| 0:51–1:05 | E5 — two faults, two layers | Don't project the 5A preview (0.1) |
| 1:05–1:15 | E6 — Pattern Showdown | Whole-room grid |

---

## 1. Opening (3 minutes)

**Say:**

> "Yesterday you deployed one app, safely. Today: what happens when you have thirty clusters? Hand-writing thirty Applications means thirty places to make a typo. Day 2 gives you two patterns — a factory and a family tree — and each brings its own new way to fail."

> "Here's the one sentence to hold all day: there is no new deployment mechanism today. The same controller from Lab 1 reconciles every Application. The only thing that changes is *who writes the Application object*."

**Do** (Section 6.1):

```bash
kubectl --context k3d-mgmt -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -o custom-columns='NAME:.metadata.name,ROLE:.metadata.labels.cluster-role,REGION:.metadata.labels.region'
```

**Expect** (verified):

```text
NAME               ROLE         REGION
cluster-workload   workload     lab
in-cluster         management   <none>
```

---

## 2. Exercise 1 — Complete the storefront factory

### Collect the prediction

**Say:** "Write down: how many Applications, and their exact names. Names, not just a count."

### The solution — the five TODOs

| TODO | Answer | Where the value comes from |
|---|---|---|
| Cluster selector | `cluster-role: "workload"` | The workload cluster Secret's label (Section 6.1) |
| `metadata.name` | `"storefront-{{ .env }}-{{ .name }}"` | `.env` from `config.yaml`; `.name` from the cluster generator |
| `targetRevision` | `"{{ .targetRevision }}"` | `config.yaml` — keeps prod on its tag |
| `valueFiles` | `"../../envs/{{ .env }}/values.yaml"` | Relative to `charts/storefront` |
| `destination` | `server: "{{ .server }}"`, `namespace: "{{ .namespace }}"` | Cluster generator; `config.yaml` |

The completed file (verified; it is identical to the checkpoint's `CP-lab-05` copy apart from the protection policy added in E3):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: storefront
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - matrix:
        generators:
          - clusters:
              selector:
                matchLabels:
                  cluster-role: workload
          - git:
              repoURL: http://lab-gitea:3000/course/storefront-gitops.git
              revision: main
              files:
                - path: "envs/*/config.yaml"
  template:
    metadata:
      name: "storefront-{{ .env }}-{{ .name }}"
    spec:
      project: storefront
      source:
        repoURL: http://lab-gitea:3000/course/storefront-gitops.git
        targetRevision: "{{ .targetRevision }}"
        path: charts/storefront
        helm:
          valueFiles:
            - "../../envs/{{ .env }}/values.yaml"
      destination:
        server: "{{ .server }}"
        namespace: "{{ .namespace }}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Run it

**Do:**

```bash
cd ~/platform-config
argocd appset generate applicationsets/storefront.yaml -o wide
```

**Expect** (verified):

```text
NAME                                CLUSTER                             NAMESPACE           PROJECT     STATUS  HEALTH  SYNCPOLICY  CONDITIONS  REPO                                                PATH               TARGET
argocd/storefront-dev-workload      https://k3d-workload-server-0:6443  storefront-dev      storefront                  Auto-Prune  <none>      http://lab-gitea:3000/course/storefront-gitops.git  charts/storefront  main
argocd/storefront-prod-workload     https://k3d-workload-server-0:6443  storefront-prod     storefront                  Auto-Prune  <none>      http://lab-gitea:3000/course/storefront-gitops.git  charts/storefront  storefront-1.0.0
argocd/storefront-staging-workload  https://k3d-workload-server-0:6443  storefront-staging  storefront                  Auto-Prune  <none>      http://lab-gitea:3000/course/storefront-gitops.git  charts/storefront  main
```

**Say:** "Three rows. Read the TARGET column. Why is prod different?" *(Its `config.yaml` pins `storefront-1.0.0`, an immutable tag.)*

**Do:**

```bash
git add applicationsets/storefront.yaml && git commit -m "Lab 4 E1: complete storefront ApplicationSet" && git push
kubectl --context k3d-mgmt apply -f applicationsets/storefront.yaml
argocd app list
```

**Expect** (verified — all three reached `Synced`/`Healthy` within 15 seconds):

```text
NAME                                STATUS  HEALTH   SYNCPOLICY  TARGET
argocd/storefront-dev-workload      Synced  Healthy  Auto-Prune  main
argocd/storefront-prod-workload     Synced  Healthy  Auto-Prune  storefront-1.0.0
argocd/storefront-staging-workload  Synced  Healthy  Auto-Prune  main
```

**Wow moment:**

> "You wrote zero Applications and got three. And those three are reconciled by the exact same controller that ran `hello-reconcile` yesterday. The ApplicationSet controller never touched the workload cluster — it only wrote Application objects. Everything below that line is Day 1."

### Wrong turns (all verified)

**Previewing before filling anything in:**

```text
NAME  CLUSTER  NAMESPACE  PROJECT  STATUS  HEALTH  SYNCPOLICY  CONDITIONS  REPO  PATH  TARGET
```

**Say:** "Zero rows. No error. Why?" *(No cluster has the label `cluster-role: TODO`, so the cluster generator returned nothing, and anything times zero is zero.)*

> "Remember this: zero is a valid generator output. It doesn't error. Hold that thought until Exercise 3."

**A misspelled variable** (`{{ .environment }}` instead of `{{ .env }}`):

```text
{"level":"fatal","msg":"rpc error: code = Unknown desc = unable to generate Applications of ApplicationSet: error generating applications: failed to execute go template storefront-{{ .environment }}-{{ .name }}: template: base:1:14: executing \"base\" at <.environment>: map has no entry for key \"environment\"...
```

That's `missingkey=error` doing its job. (This particular error is safe to show — the credential dump in pre-flight 0.1 appears when a key is missing from *generator data*, as in Exercise 5A. Still, glance at the output before projecting.)

**`targetRevision: main` hard-coded:** the preview succeeds and prod quietly appears on `main`:

```text
argocd/storefront-prod-workload  https://k3d-workload-server-0:6443  storefront-prod  main
```

**Say:** "No error. Every row looks healthy. And production just started following a moving branch. The dangerous bug isn't an error — it's a successful render of the wrong thing. That's why you read the TARGET column, every time."

---

## 3. Exercise 2 — Move the blast radius with labels

### Answer key

**Prediction:** 2 clusters × 3 environment files = **6** Applications. The three new names end in `-in-cluster`.

**Do:**

```bash
yq -i '.spec.generators[0].matrix.generators[0].clusters.selector.matchLabels = {}' applicationsets/storefront.yaml
argocd appset generate applicationsets/storefront.yaml -o wide
git checkout -- applicationsets/storefront.yaml
argocd appset generate applicationsets/storefront.yaml -o wide | awk '{print $1}'
```

**Expect** (verified 2026-09-13 — the CLI sorts by name, so the three `-in-cluster` rows print **first**):

```text
NAME                                  CLUSTER                             NAMESPACE           ...  TARGET
argocd/storefront-dev-in-cluster      https://kubernetes.default.svc      storefront-dev      ...  main
argocd/storefront-prod-in-cluster     https://kubernetes.default.svc      storefront-prod     ...  storefront-1.0.0
argocd/storefront-staging-in-cluster  https://kubernetes.default.svc      storefront-staging  ...  main
argocd/storefront-dev-workload        https://k3d-workload-server-0:6443  storefront-dev      ...  main
argocd/storefront-prod-workload       https://k3d-workload-server-0:6443  storefront-prod     ...  storefront-1.0.0
argocd/storefront-staging-workload    https://k3d-workload-server-0:6443  storefront-staging  ...  main

NAME
argocd/storefront-dev-workload
argocd/storefront-prod-workload
argocd/storefront-staging-workload
```

**Wow moment:**

> "You deleted two lines of YAML. The factory would have doubled the fleet — and three of those new Applications point at the management cluster, the most sensitive cluster you own. A label edit is a fleet edit. Preview costs three seconds; an unplanned rollout costs an afternoon."

> (Instructor-only aside, do not say it now:) this exact change is one of the capstone faults. Participants who internalize this preview habit will find it in a minute.

---

## 4. Exercise 3 — Protect against unintended deletion

### The solution

Add under `spec` (not under `template.spec`):

```yaml
  syncPolicy:
    applicationsSync: create-update
    preserveResourcesOnDeletion: true
```

**Do:**

```bash
git commit -am "Lab 4 E3: storefront AppSet create-update + preserveResourcesOnDeletion" && git push
kubectl --context k3d-mgmt apply -f applicationsets/storefront.yaml
kubectl --context k3d-mgmt -n argocd get applicationset storefront -o jsonpath='{.spec.syncPolicy}{"\n"}'
```

**Expect** (verified): `{"applicationsSync":"create-update","preserveResourcesOnDeletion":true}`

**Also verified — worth showing.** Within seconds of that apply, the controller removed `resources-finalizer.argocd.argoproj.io` from all three generated Applications. That is *how* `preserveResourcesOnDeletion` protects the workload:

```bash
kubectl --context k3d-mgmt -n argocd get applications -o custom-columns='NAME:.metadata.name,FINALIZERS:.metadata.finalizers'
```

```text
NAME                          FINALIZERS
storefront-dev-workload       <none>
storefront-prod-workload      <none>
storefront-staging-workload   <none>
```

Before the apply, every row read `[resources-finalizer.argocd.argoproj.io]`.

### Remove the prod input

**Do:**

```bash
cd ~/storefront-gitops
git mv envs/prod/config.yaml envs/prod/config.yaml.retired
git commit -m "retire prod from the generator input" && git push
cd ~/platform-config
argocd appset generate applicationsets/storefront.yaml -o wide | awk '{print $1, $NF}'
argocd app list -o name
kubectl --context k3d-mgmt -n argocd get application storefront-prod-workload \
  -o jsonpath='owner={.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name} sync={.status.sync.status} health={.status.health.status}{"\n"}'
kubectl --context k3d-mgmt -n argocd get applicationset storefront \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}: {.message}{"\n"}{end}'
```

**Expect** (verified):

```text
NAME TARGET
argocd/storefront-dev-workload main
argocd/storefront-staging-workload main

argocd/storefront-dev-workload
argocd/storefront-prod-workload
argocd/storefront-staging-workload

owner=ApplicationSet/storefront sync=Synced health=Healthy

ErrorOccurred=False: All applications have been generated successfully
ParametersGenerated=True: Successfully generated parameters for all Applications
ResourcesUpToDate=True: All applications have been generated successfully
```

**Timing (re-verified 2026-09-13).** The preview changes the instant the push lands; the controller does not. Here it acted on the retired input 2 minutes after the push (`generated 2 applications`, then `requeueAfter=3m0s`). The app list, owner, and conditions above were re-checked **after** that pass: prod was still present, still owned by `ApplicationSet/storefront`, still listed in the ApplicationSet's `status.resources`, and its Deployment was `2/2`. Tell the room to wait 3 minutes before judging — before that pass, prod is listed with or without the policy.

**Answer key — prediction:** under `create-update`, `storefront-prod-workload` **stays**. The factory stopped generating it but is not allowed to delete it.

**Say:** "Look at the conditions. All green. 'All applications have been generated successfully.' Does anything on this screen tell you there's an orphan?"

**Wow moment:**

> "No. Nothing warns you. Without this policy, that silence would have been a deletion — prod's Application gone, and its workload with it. With the policy, the silence is an orphan. 'Safe' here doesn't mean 'nothing happened'. It means deletion became a decision a human has to make."

### Answer key — what the operator must do now

Either restore the input (if removing it was a mistake), or retire prod deliberately with a **written cascade decision**:

- `argocd app delete storefront-prod-workload --cascade=false` — removes only the Application object; the running prod workload stays.
- `argocd app delete storefront-prod-workload` (the CLI default, cascading) — removes the Application **and** its workload.

Point out a subtlety that Lab 5 proves: `preserveResourcesOnDeletion` stops the *ApplicationSet controller* from cascading. A human running the CLI's default delete still cascades.

**Restore** (verified — the preview is back to three rows at once; in the wrong-turn run above, where prod's Application had been deleted, the controller re-created `storefront-prod-workload` at its next pass 70 seconds after the push, `Synced`/`Healthy`, adopting the Deployment that had kept running — no Pod restart):

```bash
cd ~/storefront-gitops
git mv envs/prod/config.yaml.retired envs/prod/config.yaml
git commit -m "restore prod generator input" && git push
```

### Wrong turns

- `syncPolicy` placed under `template.spec` → no effect on deletion, and prod disappears. "Which object gets deleted — the Application, or the workload? Then which object's policy matters?"
- Applied the policy **after** removing the input → the Application is already gone. There's no undo for that ordering; restore the input and it regenerates.
- **Verified variant (2026-09-13):** with prod's input already retired, applying the ApplicationSet **without** `spec.syncPolicy` deleted `storefront-prod-workload` within 5 seconds. A change to the ApplicationSet itself triggers an immediate pass, and the controller logged `Deleted application`. The prod Deployment kept running (still present after 4 minutes), because the earlier protected apply had already removed the finalizer. On a first run, where the finalizer is still present, expect the workload to go too (inferred from the finalizer, not re-run). Restoring the input and re-applying the protected file brought prod back.

---

## 5. Exercise 4 — Inspect the App-of-Apps hierarchy

### Answer key — prediction

**Three** children — one per Application manifest in `apps/`. The count is decided by the folder's contents, not by anything in the root manifest.

**Do:**

```bash
cd ~/platform-config
kubectl --context k3d-mgmt apply -f root/platform-root.yaml
argocd app get platform-root
```

**Expect** (verified — root and all three children `Synced`/`Healthy` within 6 seconds):

```text
Name:               argocd/platform-root
Project:            platform
Server:             https://kubernetes.default.svc
Namespace:          argocd
URL:                https://localhost:8443/applications/platform-root
Source:
- Repo:             http://lab-gitea:3000/course/platform-config.git
  Target:           main
  Path:             apps
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to main (85d88f3)
Health Status:      Healthy

GROUP        KIND         NAMESPACE  NAME             STATUS  HEALTH  HOOK  MESSAGE
argoproj.io  Application  argocd     platform-agent   Synced                application.argoproj.io/platform-agent created
argoproj.io  Application  argocd     platform-netpol  Synced                application.argoproj.io/platform-netpol created
argoproj.io  Application  argocd     platform-quotas  Synced                application.argoproj.io/platform-quotas created
```

**Say:** "Look at the HEALTH column for the three children. It's blank. Why?" *(Argo CD has no built-in health check for the `Application` kind. The root doesn't know or care whether its children are healthy — keep that in mind for 5B.)*

**Re-verified 2026-09-13:** root and children `Synced`/`Healthy` within 6 seconds; the MESSAGE column can read `unchanged` instead of `created` (a later auto-sync pass replaced the first message). Nothing else differs.

**Cascade, verified — the guide now says this.** `argocd app delete platform-root --yes` (CLI default: cascade) removed all three child Applications within 3 seconds, but **every workload object stayed**: 6 NetworkPolicies, 3 ResourceQuotas, 3 LimitRanges, and the `platform-agent` Deployment. None of the children carries `resources-finalizer.argocd.argoproj.io` (check with the ownership table below plus `FINALIZERS:.metadata.finalizers`). Re-applying `root/platform-root.yaml` brought all four back `Synced`/`Healthy` within 3 seconds, adopting the running objects. Worth one sentence in class: *a cascade stops at the first layer without a finalizer.*

### Trace each child — use this compact command

The guide now uses this same `jsonpath` form (with the destination server added). The old `grep` loop matched `status.resources` too — 13–25 lines per child, including `storefront-prod`/`storefront-staging` namespaces, because the quotas and network-policy files name all three namespaces. Verified output:

```bash
for c in platform-quotas platform-netpol platform-agent; do
  echo "$c: $(kubectl --context k3d-mgmt -n argocd get application $c \
    -o jsonpath='{.spec.source.repoURL} path={.spec.source.path} -> ns={.spec.destination.namespace}')"
done
```

**Expect:**

```text
platform-quotas: http://lab-gitea:3000/course/platform-components.git path=quotas -> ns=storefront-dev
platform-netpol: http://lab-gitea:3000/course/platform-components.git path=network-policies -> ns=storefront-dev
platform-agent: http://lab-gitea:3000/course/platform-components.git path=agent -> ns=platform-system
```

**Who wrote each Application** (verified — worth showing, because it's the capstone's ownership tool):

```bash
kubectl --context k3d-mgmt -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,GENERATED-BY:.metadata.ownerReferences[0].name,TRACKED-BY:.metadata.annotations.argocd\.argoproj\.io/tracking-id'
```

```text
NAME                          GENERATED-BY   TRACKED-BY
platform-agent                <none>         platform-root:argoproj.io/Application:argocd/platform-agent
platform-netpol               <none>         platform-root:argoproj.io/Application:argocd/platform-netpol
platform-quotas               <none>         platform-root:argoproj.io/Application:argocd/platform-quotas
platform-root                 <none>         <none>
storefront-dev-workload       storefront     <none>
storefront-prod-workload      storefront     <none>
storefront-staging-workload   storefront     <none>
```

**Wow moment:**

> "Two different kinds of parenthood in one table. Generated Applications have a Kubernetes owner reference pointing at the ApplicationSet. Child Applications have Argo CD's tracking signature pointing at the root. And `platform-root` has neither — which tells you a human applied it. Every Application in this cluster just told you who wrote it."

**Answer key — owning repo and path:** all three children live in `platform-components`, paths `quotas`, `network-policies`, `agent`. Their *specs* live in `platform-config/apps/<child>.yaml`.

---

## 6. Exercise 5 — Break it, then trace each fault to the owning layer

### Part A — a missing template key

**Do:**

```bash
cd ~/storefront-gitops
sed -i '/^namespace:/d' envs/staging/config.yaml
git commit -am "staging: tidy config" && git push
kubectl --context k3d-mgmt -n argocd get applicationset storefront \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}: {.message}{"\n"}{end}'
```

**Expect** (re-verified 2026-09-13 — `ErrorOccurred=True` appeared **78 seconds** after the push, at the controller's next scheduled pass; it can take up to 3 minutes. `argocd appset generate` fails instantly. The controller logged `generated 2 applications` in that pass, but applied nothing: all three existing apps stayed `Synced`/`Healthy`, staging on `storefront-staging`):

```text
ErrorOccurred=True: failed to execute go template {{ .namespace }}: template: base:1:3: executing "base" at <.namespace>: map has no entry for key "namespace"
ParametersGenerated=False: failed to execute go template {{ .namespace }}: template: base:1:3: executing "base" at <.namespace>: map has no entry for key "namespace"
ResourcesUpToDate=False: failed to execute go template {{ .namespace }}: template: base:1:3: executing "base" at <.namespace>: map has no entry for key "namespace"
```

> **Project this command rather than the failing `argocd appset generate`.** The preview's error is now credential-free (pre-flight 0.1 — confirm your VM first), but it is a 4 KB block of JSON; the conditions are the readable view.

**Prove the factory failed safe** (verified):

```bash
kubectl --context k3d-mgmt -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' | grep storefront
```

```text
storefront-dev-workload       Synced   Healthy
storefront-prod-workload      Synced   Healthy
storefront-staging-workload   Synced   Healthy
```

**Answer key — prediction:** the ApplicationSet **refuses** and reports `ErrorOccurred`. It does not create a broken staging Application. The existing Applications — including staging — are **untouched**.

### The optional non-strict comparison

Re-verified 2026-09-13: with the `goTemplateOptions` line deleted from the local file, the preview exits `0` and staging's namespace renders as the literal `<no value>`, both in the `-o wide` NAMESPACE column and as `namespace: <no value>` in `-o yaml`. After `git checkout --`, the strict preview fails again (exit 20). Neither output contained any credential text:

```text
argocd/storefront-dev-workload      https://k3d-workload-server-0:6443  storefront-dev      ...  main
argocd/storefront-prod-workload     https://k3d-workload-server-0:6443  storefront-prod     ...  storefront-1.0.0
argocd/storefront-staging-workload  https://k3d-workload-server-0:6443  <no value>          ...  main
```

**Wow moment:**

> "Same missing key, two behaviours. Strict: a loud error, at the exact layer that owns the template, and nothing changed. Non-strict: a perfectly normal-looking Application that deploys into a namespace called `<no value>` — and fails later, somewhere else, wearing a different disguise. The safer setting failed more, failed sooner, and failed louder. That's *why* it's safer."

### Fix and recover

**Do:**

```bash
cd ~/storefront-gitops
git revert --no-edit HEAD && git push
cd ~/platform-config
argocd appset generate applicationsets/storefront.yaml -o wide | awk '{print $1}'
```

The preview succeeds immediately (three names). **The `ErrorOccurred` condition may stay `True` for up to 3 minutes** (pre-flight 0.3). The guide now says this and tells participants to confirm with the preview. Re-verified 2026-09-13: the controller re-checked `storefront` at fixed 3-minute ticks (10:41:03, 10:44:03, 10:47:03). The error appeared at one tick, 78 s after the breaking push, and cleared at the next, 50 s after the fix push (`generated 3 applications`). Earlier rehearsal log:

```text
level=info msg="end reconcile in 185.615625ms" applicationset=argocd/storefront requeueAfter=3m0s
level=error msg="error generating application from params" applicationset=argocd/storefront error="failed to execute go template {{ .namespace }}: ..."
level=info msg="generated 3 applications" applicationset=argocd/storefront
```

**Say:** "The preview says we're fixed. The condition still says error. Which one is lying?" *(Neither — the condition is a measurement from the controller's last pass, and the next pass is on a 3-minute schedule. Every status is a reading with a timestamp.)*

### Part B — a broken child path

**Do:**

```bash
cd ~/platform-config
sed -i 's/path: quotas$/path: quotas-typo/' apps/platform-quotas.yaml
git commit -am "platform-quotas: move path" && git push
argocd app get platform-root --refresh >/dev/null
argocd app get platform-quotas --refresh
argocd app get platform-root | sed -n '/Sync Status/,$p'
```

**Expect** (verified — with the `--refresh` commands above the child condition appears within seconds; without them it took 6 s in one run and 101 s in another):

```text
  Path:             quotas-typo
Sync Status:        Unknown
Health Status:      Healthy

CONDITION        MESSAGE
ComparisonError  Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unknown desc = quotas-typo: app path does not exist
```

```text
Sync Status:        Synced to main (07e37b8)
Health Status:      Healthy

GROUP        KIND         NAMESPACE  NAME             STATUS  HEALTH  HOOK  MESSAGE
argoproj.io  Application  argocd     platform-quotas  Synced                application.argoproj.io/platform-quotas unchanged
argoproj.io  Application  argocd     platform-agent   Synced
argoproj.io  Application  argocd     platform-netpol  Synced
```

**Re-verified 2026-09-13 (no manual refresh):** the child's `ComparisonError` appeared 6 seconds after the push in one run and **101 seconds** after it in a second run (right after an Argo CD restart); the root moved to the new commit, `Synced`/`Healthy`. The root only notices a commit on its 60-second Git check, so tell the room "about a minute" — or run `argocd app get platform-root --refresh` on the projector.

**Click — the trap, verified.** Open `platform-root`: its tree shows **all three children with a green Synced check**, `platform-quotas` included — the child *object* matches Git, typo and all. Then open **Applications**, search `platform`: `platform-quotas` reads `Healthy` / `Unknown`, path `quotas-typo` (SS-L4-09 now shows this list, because the old root-tree shot showed no error at all). Click `platform-quotas` → **APP CONDITIONS** for the message. A toast "Unable to load data: revision main must be resolved" may appear on the child's page — same cause as Lab 3.

**Answer key — prediction:** root `Synced`/`Healthy`; child `ComparisonError` (sync `Unknown`). The root applied the child *object* successfully; that's all the root measures.

### The "fix the wrong layer" demonstration — do this live, it takes 10 seconds

**Do:**

```bash
kubectl --context k3d-mgmt -n argocd patch application platform-quotas --type merge -p '{"spec":{"source":{"path":"quotas"}}}'
for i in $(seq 1 10); do echo "$(date +%T) path=$(kubectl --context k3d-mgmt -n argocd get application platform-quotas -o jsonpath='{.spec.source.path}')"; sleep 1; done
```

**Expect** (re-verified 2026-09-13 — the root's automated self-heal put the typo back within **1 second**; an earlier rehearsal took 3):

```text
t=0s live child path=quotas
t=1s live child path=quotas-typo
```

**Wow moment:**

> "I fixed it. It was fixed. A second later my fix was gone. Nothing is broken — the root owns that field, and the root is doing exactly what Git tells it. If your fix reverts, you fixed the wrong layer."

**Fix the owning file** (verified — child back to `Synced`/`Healthy` in about 3 seconds):

```bash
sed -i 's/path: quotas-typo$/path: quotas/' apps/platform-quotas.yaml
git commit -am "platform-quotas: restore path" && git push
argocd app get platform-root --refresh >/dev/null
```

### Answer key — the trace table

| Part | Symptom (what / where) | Owning object | Owning repo + file | Fix |
|---|---|---|---|---|
| A | `ErrorOccurred=True`, "map has no entry for key namespace", on the **ApplicationSet** conditions; generated apps unchanged | ApplicationSet `storefront` (template + generator input) | `storefront-gitops` → `envs/staging/config.yaml` | Restore `namespace: storefront-staging` (`git revert`) |
| B | `ComparisonError` "quotas-typo: app path does not exist" on the **child** `platform-quotas`; root green | Root `platform-root` (it writes the child's spec) | `platform-config` → `apps/platform-quotas.yaml` | Restore `path: quotas` |

---

## 7. Exercise 6 — Pattern Showdown: retire staging

Run this as a whole-room grid on the board. There is no winner.

### Answer key

| Question | ApplicationSet (remove `envs/staging/config.yaml`) | App-of-Apps (delete `apps/storefront-staging.yaml`) |
|---|---|---|
| **Files touched** | One file removed in `storefront-gitops` | One file removed in `platform-config` |
| **Who reviews, and can they tell what it does?** | The storefront repo owners. The diff shows a deleted config file; the *effect* is only visible with `argocd appset generate` — a reviewer reading the PR alone sees a file, not an Application | The platform-config owners. The diff shows the deleted Application manifest itself — the effect is legible in the PR |
| **Blast radius** | Every cluster the selector matches: one config file × N clusters. One environment removed everywhere at once | Exactly one Application |
| **Deletion behavior** | Depends on `applicationsSync`. With `create-update` (E3): the Application **stays**, orphaned, until someone deletes it. With a deleting policy: the Application is removed, and `preserveResourcesOnDeletion` decides whether the workload survives | The root has `prune: true`, so the child Application object is pruned. Whether the *workload* goes too depends on the child's `resources-finalizer.argocd.argoproj.io` — none of the course's children carry one, so the workload would be orphaned |
| **Preview** | Yes — `argocd appset generate` shows the before/after list exactly | No generated preview; `argocd app diff platform-root` after pushing to a branch, or reading the PR |
| **Cost of one typo** | A typo in a selector or glob can match *zero* files or *every* cluster: zero means "delete everything" under a deleting policy; wrong glob multiplies across the fleet | A typo in one child manifest breaks one Application — but a wrong `path:` in the root could prune every child at once |

**When to prefer each (accept any version of these):**

- **ApplicationSet** when the list is *derived* from data — many clusters or environments that should look alike.
- **App-of-Apps** when the list is *decided* — a deliberate, reviewable bootstrap hierarchy of different platform components.

**Wow moment:**

> "ApplicationSet gives you leverage. App-of-Apps gives you legibility. Leverage means one change moves forty things. Legibility means a human can read the tree and say what's supposed to exist. Most platforms need both — with an explicit line drawn where one pattern's ownership ends and the other begins."

---

## 8. Checkpoint — grading at a glance

**Do** (verified):

```bash
reset-lab.sh CP-lab-05 --verify-only --local
```

**Expect** (re-verified 2026-09-13 against a participant-built end state, before any reset): **22** rows, all `PASS`, including `Repository and cluster Secrets are exactly: in-cluster, repo-storefront-gitops, cluster-workload, course-repo-creds`, ending `PASS CP-lab-05 is in the expected state.`

**Know the verifier's limit.** It checks that the `storefront` ApplicationSet *exists* and that all seven Applications are `Synced`/`Healthy`. It does **not** check E3's protection policy. So a participant who skipped E3 still gets PASS. Check the policy by hand:

```bash
kubectl --context k3d-mgmt -n argocd get applicationset storefront -o jsonpath='{.spec.syncPolicy}{"\n"}'
```

Expect `{"applicationsSync":"create-update","preserveResourcesOnDeletion":true}`. The run's live spec matched the `CP-lab-05` checkpoint file exactly, so `reset-lab.sh CP-lab-05` does carry the policy forward.

| Criterion | Pass looks like |
|---|---|
| 9.1 | Three generated apps `Synced`/`Healthy`; only prod on `storefront-1.0.0` |
| 9.2 | Root `Synced`/`Healthy` with three children; owning repo + path named for each |
| 9.3 | Both trace-table rows filled, including why editing the live object would revert |

---

## 9. Optional stretch challenges

### Stretch 1 — custom health for `Application` (verified, with a caveat)

Overlay values (apply with `apply-argocd-config.sh <this-file>`):

```yaml
configs:
  cm:
    resource.customizations.health.argoproj.io_Application: |
      hs = {}
      hs.status = "Progressing"
      hs.message = ""
      if obj.status ~= nil then
        if obj.status.health ~= nil then
          hs.status = obj.status.health.status
          if obj.status.health.message ~= nil then
            hs.message = obj.status.health.message
          end
        end
      end
      return hs
```

**Verified results** (re-verified 2026-09-13; the guide's stretch 1 now asks for exactly rows 2 and 3):

| Child state | Child health | Root health with the check |
|---|---|---|
| Healthy | `Healthy` | `Healthy` (children show `Healthy` in the root's HEALTH column — only after `argocd app get platform-root --hard-refresh`; a plain refresh left the column blank for a minute) |
| `ComparisonError` (Exercise 5B again) | `Healthy` (sync `Unknown`) | **`Healthy` — no difference** |
| Unpullable image in `platform-agent` (`agent/deployment.yaml` tag changed in `platform-components`) | `Progressing` | **`Progressing`** — 32 s after the push here (4 s in an earlier rehearsal) |

`apply-argocd-config.sh <overlay>` took 21 s and restarted the application controller, repo-server, and API server — expect a short UI reconnect on the projector.

**Say:**

> "The health check rolls up *health*. A rendering failure isn't a health problem — the child's last known health is still Healthy. So the root lit up for a Pod that couldn't start, and stayed green for a child that couldn't even render. A rolled-up status is easier to alert on and hides which layer owns the fault."

Remove the customization afterwards by re-running `apply-argocd-config.sh` without the overlay (verified: the key is removed).

### Stretch 2 — merge generator (preview verified)

A naive template that references `{{ .replicaCount }}` fails for every environment without that key (verified: `map has no entry for key "replicaCount"`) — strict templating again. A working shape (verified by preview; not applied):

```yaml
  generators:
    - merge:
        mergeKeys: [env]
        generators:
          - matrix:
              generators:
                - clusters:
                    selector:
                      matchLabels:
                        cluster-role: workload
                - git:
                    repoURL: http://lab-gitea:3000/course/storefront-gitops.git
                    revision: main
                    files:
                      - path: "envs/*/config.yaml"
          - list:
              elements:
                - env: prod
                  replicaCount: "3"
  templatePatch: |
    {{- if hasKey . "replicaCount" }}
    spec:
      source:
        helm:
          parameters:
            - name: replicaCount
              value: "{{ .replicaCount }}"
    {{- end }}
```

Verified preview: `storefront-prod-workload` gets `parameters=[{"name":"replicaCount","value":"3"}]`; dev and staging get none.

### Stretch 3 — the name collision (verified; the guide's hypothesis is wrong)

The guide now frames this as predict → preview → apply → explain, with the scratch ApplicationSet `collision-test` and a cleanup command (G-9 fixed 2026-09-13).

**Preview** (re-verified 2026-09-13) with `name: "collision-test-{{ .name }}"`: exit 0, **three rows all named `argocd/collision-test-workload`**, no error.

**Applied** as a separate ApplicationSet with no `automated` sync (re-verified; the condition appeared within 3 seconds, because a new ApplicationSet is reconciled at once):

```text
ErrorOccurred=True: ApplicationSet collision-test contains applications with duplicate name: collision-test-workload
ParametersGenerated=True: Successfully generated parameters for all Applications
ResourcesUpToDate=False: ApplicationSet collision-test contains applications with duplicate name: collision-test-workload
```

**Zero** Applications were created (controller log: `validation error found during application validation: … duplicate name`). `kubectl --context k3d-mgmt -n argocd delete applicationset collision-test` left only `storefront`.

**Say:**

> "The guide warned 'the absence of an error is not the presence of correctness', and suggested these would fight. The controller is smarter than that — it refuses. But look where the error showed up: the *controller* caught it, and the *preview* didn't. Preview is necessary. It isn't sufficient."

---

## 10. Debrief (5 minutes)

1. **"What does zero mean for a generator?"** — A valid output. Under a deleting policy, it means "delete them all".
2. **"The root was green and a child was broken. Why?"** — Root health measures "did I apply the child object?", not "is the child healthy?".
3. **"Your fix reverted within a second. What do you do?"** — Stop, and trace up to the owner of the field.
4. **"Which of today's guardrails would have caught a selector typo before merge?"** — Preview in CI, plus `create-update`.

### Key takeaways — say them out loud

> "Preview before you apply. `argocd appset generate` costs three seconds; a rollback costs an afternoon."

> "Zero is a valid generator output — and where deletion is allowed, zero means delete them all."

> "The dangerous ApplicationSet bug is a successful render of the wrong thing. `missingkey=error` turns that silence into a failure."

> "A green root can sit over a broken child."

> "If your fix reverted, you fixed the wrong layer."

### Transition

**Say:**

> "Every guardrail that saved you today answered one question: what is this thing *allowed* to do? Next session makes that question explicit — who can deploy where, which kinds, and who is allowed to cause a deletion. Then Lab 5 has you build a fence and genuinely try to walk through it."
