# Lab 5 — Instructor Walkthrough and Solutions

> **INSTRUCTOR ONLY. Never share this file with participants, never project it, and never paste it into a shared channel.**
> **Participant guide:** [lab-05-enforce-platform-guardrails.md](../../day-2/lab-05-enforce-platform-guardrails.md)
> **Timebox:** ~50 minutes on the required path · **Scaffolding:** G2 (reduced)
> **Verified:** 2026-09-13, end to end, on the course's local k3d two-cluster sandbox: Argo CD `v3.5.2` (chart `10.8.4`), `argocd` CLI `v3.5.2`, Kubernetes `v1.35.8+k3s1`, Helm `v4.2.1`, starting from a freshly reset and verified `CP-lab-05`. Every output block was captured from that run unless marked otherwise. **No password or token value appears in this file.**

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

### 0.1 Confirm the starting checkpoint

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-05 --verify-only --local
```

**Expect** (verified): 21 rows, all `PASS`, matching the guide's Section 5.1 block exactly, ending `PASS CP-lab-05 is in the expected state.`

### 0.2 Three live-demo traps

| Trap | What happens (verified) | What to do |
|---|---|---|
| **Exercise 3 Part A — pressing Sync from the CLI** | `argocd app sync team-a-wrong-dest` **never returns**. The operation itself ends instantly (`Phase: Error`, `Duration: 0s`), but the CLI waits forever for a state that can't be reached. In rehearsal it hung for 7 minutes | Always add `--timeout 30`. It then exits with `timed out (30s) waiting for app "team-a-wrong-dest" match desired state`. Or press **Sync** in the UI instead |
| **Identity switching** | You will be logged in as `team-a-dev` for parts of Exercises 4 and 5. Every later `argocd` command runs as that account | Log back in as `admin` immediately after each `team-a-dev` step. Check with `argocd account get-user-info` before any admin command |
| **Stretch 4 — the guide's `add-policy` command** | `--object 'team-a/*'` produces the policy object `team-a/team-a/*` (the CLI prefixes the project name itself), and a role with only `sync` can't even **get** its Application, so `argocd app sync` is denied | Use `--object '*'` and add **both** `get` and `sync` (Section 9) |

### 0.3 Know what's already right

The Lab 5 guide was validated line by line in a re-test on 2026-09-12 ([courseware/reviews/lab-05-validation.md](../../reviews/lab-05-validation.md)), and this rehearsal re-confirmed every required-path output. The guide's printed messages are verbatim — trust them.

---

## Run of show (50 minutes)

| Clock | Segment | Your job |
|---|---|---|
| 0:00–0:05 | Why this matters + walkthrough | "A guardrail you've never tried to break is a hope" |
| 0:05–0:13 | E1 — the fence and the grant | Push people to unit-test the policy before applying |
| 0:13–0:18 | E2 — the happy path | Positive control |
| 0:18–0:24 | E3 — two refused attempts | Predict which guard speaks first |
| 0:24–0:36 | E4 — Argo CD vs Kubernetes denial | The centerpiece; "which team do you page?" |
| 0:36–0:41 | E5 — deletion | "The danger lives in the delete path" |
| 0:41–0:50 | Checkpoint + design debrief | Rank the error messages |

---

## 1. Opening (3 minutes)

**Say:**

> "When you add a restriction, nothing lights up green. The only proof a fence exists is an attempt that was refused. And the only proof it's a *good* fence is that the refusal said something useful."

> "Today you build team-a's fence and try to walk through it four ways. Four different guards will say no, in four different vocabularies. Your job is to read past the red badge to the guard that actually spoke."

Draw the four guards on the board, left to right: **Argo CD RBAC → AppProject → cluster registration scope → Kubernetes RBAC**. Leave space under each for its error signature.

---

## 2. Walkthrough checks (Section 6) — verified outputs

```bash
grep -n -A6 "rbac:" platform-config/argocd/values.yaml
```

```text
141:  rbac:
142-    # No permissions by default: an account that is not named in policy.csv can
143-    # log in and see nothing. Every grant is written here, deliberately.
144-    policy.default: ""
145-    policy.csv: ""
```

```bash
cat > /tmp/rbac-demo.csv <<'EOF'
p, role:demo, applications, sync, demo/*, allow
g, demo-user, role:demo
EOF
argocd admin settings rbac can demo-user sync applications 'demo/demo-app' --policy-file /tmp/rbac-demo.csv
# Yes
argocd admin settings rbac can demo-user sync applications 'demo/demo-app'
# {"level":"fatal","msg":"please provide exactly one of --policy-file or --namespace",...}
kubectl --context k3d-workload auth can-i create deployments.apps -n team-a \
  --as=system:serviceaccount:argocd-access:argocd-manager
# yes
```

**Wow moment** (after the `Yes`):

> "You just unit-tested a permission model without a cluster, without a user, without a login. That's what 'policy as code' actually means — not that the policy is in Git, but that you can test it before anyone hits it."

---

## 3. Exercise 1 — Build team-a's fence and grant its account

### Part A — the AppProject (verified)

`platform-config/projects/team-a.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  description: team-a tenant project
  sourceRepos:
    - http://lab-gitea:3000/course/team-a-apps.git
  destinations:
    - server: https://k3d-workload-server-0:6443
      namespace: team-a
  clusterResourceWhitelist: []
  namespaceResourceWhitelist:
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Service
    - group: apps
      kind: Deployment
    - group: networking.k8s.io
      kind: NetworkPolicy
```

Hint-1 lookup (verified):

```bash
kubectl --context k3d-workload api-resources | grep -i -E "^NAME|networkpolic"
```

```text
NAME                                SHORTNAMES   APIVERSION                        NAMESPACED   KIND
networkpolicies                     netpol       networking.k8s.io/v1              true         NetworkPolicy
```

**Do:**

```bash
kubectl --context k3d-mgmt apply -f platform-config/projects/team-a.yaml
argocd proj get team-a
argocd proj get team-a -o yaml | yq '.spec'
```

**Expect** (verified):

```text
Name:                        team-a
Description:                 team-a tenant project
Destinations:                https://k3d-workload-server-0:6443,team-a
Repositories:                http://lab-gitea:3000/course/team-a-apps.git
Source Namespaces:           <none>
Scoped Repositories:         <none>
Allowed Cluster Resources:   <none>
Scoped Clusters:             <none>
Denied Namespaced Resources: <none>
Signature keys:              <none>
Orphaned Resources:          disabled
```

```yaml
description: team-a tenant project
destinations:
  - namespace: team-a
    server: https://k3d-workload-server-0:6443
namespaceResourceWhitelist:
  - group: ""
    kind: ConfigMap
  - group: ""
    kind: Service
  - group: apps
    kind: Deployment
  - group: networking.k8s.io
    kind: NetworkPolicy
sourceRepos:
  - http://lab-gitea:3000/course/team-a-apps.git
```

**Say:** "Two things are missing from that output. The four kinds aren't in the summary, and `clusterResourceWhitelist` isn't in the YAML at all. Did we lose the fence?" *(No — an empty list is dropped when stored. Empty, absent, and "deny every cluster-scoped kind" are the same thing here.)*

### Part B — the RBAC grant

**Answer key — the least-privilege policy:**

```csv
p, role:team-a, applications, get, team-a/*, allow
p, role:team-a, applications, sync, team-a/*, allow
g, team-a-dev, role:team-a
```

In `platform-config/argocd/values.yaml`:

```yaml
  rbac:
    policy.default: ""
    policy.csv: |
      p, role:team-a, applications, get, team-a/*, allow
      p, role:team-a, applications, sync, team-a/*, allow
      g, team-a-dev, role:team-a
```

> **Instructor note:** the course's `CP-capstone` checkpoint grants one extra line, `p, role:team-a, applications, action/*, team-a/*, allow` (resource actions such as restarting a Deployment). It's not required here. If a participant adds it and can justify it, accept it; if they can't, ask them to remove it.

**Unit tests** (verified — do these on the projector, they're the best 60 seconds of Part B):

```bash
for a in get sync delete override; do
  printf '%-8s ' $a
  argocd admin settings rbac can team-a-dev $a applications 'team-a/team-a-guestbook' --policy-file /tmp/my-policy.csv
done
argocd admin settings rbac can team-a-dev sync applications 'storefront/storefront-prod-workload' --policy-file /tmp/my-policy.csv
```

```text
get      Yes
sync     Yes
delete   No
override No
No
```

### Wrong turns — each verified with the offline tester

| Candidate policy | Test | Result | Why |
|---|---|---|---|
| Object `team-a` instead of `team-a/*` | `sync team-a/team-a-guestbook` | **No** | The object is `<project>/<application>`; `team-a` alone matches neither |
| `p, role:team-a, applications, *, team-a/*, allow` | `delete team-a/team-a-guestbook` | **Yes** | `*` as the action grants delete |
| `p, role:team-a, applications, sync, *, allow` | `sync storefront/storefront-prod-workload` | **Yes** | `*` as the object grants *every project* |
| Permission lines with no `g,` line | `sync team-a/team-a-guestbook` | **No** | The permissions belong to a role nobody holds |

**Wow moment:**

> "Every one of those wrong policies would have passed a code review from someone skimming. Two of them look *more* restrictive than they are. The tester caught all four in under a second. Write the test before your users find the bug."

**Apply for real** (verified — note the session survives):

```bash
apply-argocd-config.sh ~/platform-config/argocd/values.yaml
kubectl --context k3d-mgmt -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}'; echo
argocd admin settings rbac can team-a-dev sync   applications 'team-a/team-a-guestbook' --namespace argocd
argocd admin settings rbac can team-a-dev delete applications 'team-a/team-a-guestbook' --namespace argocd
```

```text
==> Applying Argo CD configuration (chart 10.8.4, v3.5.2)
  ok values source: platform-config main (Gitea b270c5b)
  ok account passwords unchanged: reusing the live hashes (existing logins stay valid)
  ok overlay: /home/.../platform-config/argocd/values.yaml
  ok Argo CD release applied
  ok argocd-server and argocd-repo-server are ready

p, role:team-a, applications, get, team-a/*, allow
p, role:team-a, applications, sync, team-a/*, allow
g, team-a-dev, role:team-a

Yes
No
```

### Part C — commit (verified)

```bash
git -C ~/platform-config add projects/team-a.yaml argocd/values.yaml
git -C ~/platform-config commit -m "team-a: restricted AppProject and least-privilege RBAC grant"
git -C ~/platform-config push origin main
```

---

## 4. Exercise 2 — Prove the happy path

`platform-config/applications/team-a-guestbook.yaml` (verified — no `syncPolicy`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: team-a-guestbook
  namespace: argocd
spec:
  project: team-a
  source:
    repoURL: http://lab-gitea:3000/course/team-a-apps.git
    targetRevision: main
    path: guestbook
  destination:
    server: https://k3d-workload-server-0:6443
    namespace: team-a
```

```bash
mkdir -p ~/platform-config/applications
kubectl --context k3d-mgmt apply -f platform-config/applications/team-a-guestbook.yaml
argocd app sync team-a-guestbook
argocd app get team-a-guestbook
```

**Expect** (verified):

```text
Name:               argocd/team-a-guestbook
Project:            team-a
Server:             https://k3d-workload-server-0:6443
Namespace:          team-a
URL:                https://localhost:8443/applications/team-a-guestbook
...
Sync Policy:        Manual
Sync Status:        Synced to main (14104c8)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME       STATUS  HEALTH   HOOK  MESSAGE
       Service     team-a     guestbook  Synced  Healthy        service/guestbook created
apps   Deployment  team-a     guestbook  Synced  Healthy        deployment.apps/guestbook created
```

**Say:** "Why prove the happy path before trying to break things?" *(A fence that blocks everything is also a broken fence. This is the positive control.)*

---

## 5. Exercise 3 — Bypass attempts

### Part A — the unauthorized destination

**Answer key — prediction:** the **AppProject** (fence 2) refuses. Nothing reaches the workload cluster.

```bash
yq '.metadata.name = "team-a-wrong-dest" | .spec.destination.namespace = "storefront-prod"' \
  platform-config/applications/team-a-guestbook.yaml > /tmp/team-a-wrong-dest.yaml
kubectl --context k3d-mgmt apply -f /tmp/team-a-wrong-dest.yaml
argocd app get team-a-wrong-dest
```

**Expect** (verified):

```text
Sync Status:        Unknown
Health Status:      Unknown

CONDITION         MESSAGE
InvalidSpecError  application destination server 'https://k3d-workload-server-0:6443' and namespace 'storefront-prod' do not match any of the allowed destinations in project 'team-a'
```

**If someone presses Sync — use a timeout** (pre-flight 0.2):

```bash
argocd app sync team-a-wrong-dest --timeout 30
argocd app get team-a-wrong-dest --show-operation | sed -n '/^Operation/,/^Message/p'
kubectl --context k3d-mgmt -n argocd get application team-a-wrong-dest \
  -o jsonpath='{.status.operationState.syncResult.resources}'; echo
```

**Expect** (verified):

```text
{"level":"fatal","msg":"timed out (30s) waiting for app \"team-a-wrong-dest\" match desired state",...}
Operation:          Sync
Phase:              Error
Duration:           0s
Message:            InvalidSpecError: application destination server 'https://k3d-workload-server-0:6443' and namespace 'storefront-prod' do not match any of the allowed destinations in project 'team-a'

```

(The `syncResult` line is empty.) `kubectl --context k3d-workload -n storefront-prod get deploy guestbook` → `NotFound`.

### Part B — the cluster-scoped kind: two guards, one voice

**Answer key — prediction:** both the AppProject's empty `clusterResourceWhitelist` and the cluster registration's namespaced mode would refuse. **The cluster registration (fence 2b) speaks first.**

```bash
yq '.metadata.name = "team-a-clusterrole" | .spec.source.path = "attempts/cluster-scoped"' \
  platform-config/applications/team-a-guestbook.yaml > /tmp/team-a-clusterrole.yaml
kubectl --context k3d-mgmt apply -f /tmp/team-a-clusterrole.yaml
argocd app sync team-a-clusterrole --timeout 60 ; argocd app get team-a-clusterrole --show-operation
```

**Expect** (verified — this one returns immediately):

```text
{"level":"fatal","msg":"Operation has completed with phase: Error",...}
Operation:          Sync
Phase:              Error
Duration:           0s
Message:            ComparisonError: Failed to load live state: cluster level ClusterRole "team-a-escalation" can not be managed when in namespaced mode

GROUP                      KIND         NAMESPACE  NAME               STATUS   HEALTH   HOOK  MESSAGE
rbac.authorization.k8s.io  ClusterRole             team-a-escalation  Unknown  Missing
```

`syncResult.resources` is empty; `kubectl --context k3d-workload get clusterrole team-a-escalation` → `NotFound`.

**Say:**

> "Search that message for the word 'project'. It isn't there. It says 'namespaced mode' — that's the cluster registration you wrote in Lab 2 with `clusterResources: false`. Argo CD refused while *loading live state*, before it ever built the list of resources that the project's allow-lists check. Your project fence is real. It just never got the microphone."

**Wow moment:**

> "Defense in depth means several guards can refuse the same request — and only the first one gets to speak. A correct prediction confirmed by the wrong message is still a wrong diagnosis. Name the layer from the vocabulary of the message."

---

## 6. Exercise 4 — Argo CD denial vs Kubernetes denial (the centerpiece)

### Part A — Argo CD RBAC (fence 1)

**Answer key — prediction:** Argo CD RBAC refuses; no sync starts; the message tells you almost nothing.

```bash
argocd login localhost:8443 --username team-a-dev --insecure   # password from ~/course/credentials/team-a-dev.txt
argocd app sync storefront-prod-workload
argocd app list -o name
```

**Expect** (verified):

```text
{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = permission denied",...}

argocd/team-a-clusterrole
argocd/team-a-guestbook
argocd/team-a-wrong-dest
```

**Say** (about the list): "As `team-a-dev`, how many storefront Applications exist?" *(From this account's point of view: none. It can't even see them. That's least privilege, not no access.)*

**Switch back and read the server log:**

```bash
argocd login localhost:8443 --username admin --password "$(cat ~/course/credentials/argocd-admin.txt)" --insecure
kubectl --context k3d-mgmt -n argocd logs deploy/argocd-server --since=5m | grep "permission denied" | tail -2
```

**Expect** (verified):

```text
time="2026-09-13T05:29:49Z" level=warning msg="user tried to get application which they do not have access to: rpc error: code = PermissionDenied desc = permission denied: applications, get, storefront/storefront-prod-workload, sub: team-a-dev, iat: 2026-09-13T05:29:48Z" application=storefront-prod-workload namespace=argocd project=storefront security=2 user=team-a-dev
time="2026-09-13T05:29:49Z" level=warning msg="finished call" grpc.code=PermissionDenied grpc.component=server grpc.error="rpc error: code = PermissionDenied desc = permission denied" grpc.method=Get ...
```

**Say:** "Read the first line. Which action was denied?" *(`get`, not `sync`. The CLI fetches the Application first; the fetch was refused, so `sync` was never even evaluated. And `security=2` is the field a security monitoring system would alert on.)*

### Part B — Kubernetes RBAC (fence 3)

```bash
kubectl --context k3d-workload auth can-i create networkpolicies.networking.k8s.io -n team-a \
  --as=system:serviceaccount:argocd-access:argocd-manager
# no
yq '.metadata.name = "team-a-netpol" | .spec.source.path = "attempts/network-policy"' \
  platform-config/applications/team-a-guestbook.yaml > /tmp/team-a-netpol.yaml
kubectl --context k3d-mgmt apply -f /tmp/team-a-netpol.yaml
argocd app sync team-a-netpol --timeout 60 ; argocd app get team-a-netpol --show-operation
kubectl --context k3d-mgmt -n argocd get application team-a-netpol \
  -o jsonpath='{.status.operationState.syncResult.resources}'; echo
```

**Expect** (verified):

```text
{"level":"fatal","msg":"Operation has completed with phase: Failed",...}
Operation:          Sync
Phase:              Failed
Duration:           0s
Message:            one or more objects failed to apply, reason: networkpolicies.networking.k8s.io is forbidden: User "system:serviceaccount:argocd-access:argocd-manager" cannot create resource "networkpolicies" in API group "networking.k8s.io" in the namespace "team-a"

GROUP              KIND           NAMESPACE  NAME                 STATUS     HEALTH   HOOK  MESSAGE
networking.k8s.io  NetworkPolicy  team-a     team-a-default-deny  OutOfSync  Missing        networkpolicies.networking.k8s.io is forbidden: User "system:serviceaccount:argocd-access:argocd-manager" cannot create resource "networkpolicies" in API group "networking.k8s.io" in the namespace "team-a"

[{"group":"networking.k8s.io","hookPhase":"Failed","kind":"NetworkPolicy","message":"networkpolicies.networking.k8s.io is forbidden: ...","name":"team-a-default-deny","namespace":"team-a","status":"SyncFailed","syncPhase":"Sync","version":"v1"}]
```

**Wow moment:**

> "Every Argo CD guard said yes: the project allows NetworkPolicy, the cluster registration allows it, and admin is allowed to sync. And it still failed — because Argo CD, on the workload cluster, is just one ServiceAccount, and Kubernetes said that ServiceAccount can't do this. Argo CD was only the messenger. Notice the `Phase`: `Failed`, not `Error`. And notice the `syncResult`: a row, with `SyncFailed`. Something got far enough to *try*."

### Answer key — the comparison table

| Attempt | Who denied it? | Where is it logged? | Which config fixes it? | Who owns that config? |
|---|---|---|---|---|
| A: `team-a-dev` syncs `storefront-prod-workload` | **Argo CD** (fence 1, Argo CD RBAC), before any sync started | The `argocd-server` log on the management cluster (`security=2`, names `applications, get, …, sub: team-a-dev`). The user sees only "permission denied" | `configs.rbac.policy.csv` in `platform-config/argocd/values.yaml`, applied with `apply-argocd-config.sh` | The platform team that runs Argo CD |
| B: NetworkPolicy in `team-a` | **Kubernetes** API server on the workload cluster (fence 3), after the sync started | The Application's sync result (`SyncFailed` row, `forbidden` message) — visible to the person who pressed Sync — and the workload cluster's API audit trail | The `argocd-deployer-team` Role / RoleBinding in `team-a` on the workload cluster (`workload-rbac.yaml`) | Whoever administers the workload cluster |

**"Which team do you page?"**

- **A:** Nobody, most likely — the fence worked as designed; `team-a-dev` should not sync storefront. If team-a genuinely needs it, that's an access request to the Argo CD platform team.
- **B:** The workload cluster administrators — and first ask whether team-a *should* be allowed to create NetworkPolicies. The AppProject says yes and the cluster says no; one of the two policies is wrong, and they're owned by different people.

### Clean up (verified — no confirmation prompt at v3.5.2)

```bash
argocd app delete team-a-wrong-dest --cascade=false
argocd app delete team-a-clusterrole --cascade=false
argocd app delete team-a-netpol      --cascade=false
```

---

## 7. Exercise 5 — Protect Applications from unintended deletion

### Part A — the delete attempt

```bash
argocd admin settings rbac can team-a-dev delete applications 'team-a/team-a-guestbook' --namespace argocd
# No
argocd login localhost:8443 --username team-a-dev --insecure
argocd app delete team-a-guestbook
argocd login localhost:8443 --username admin --password "$(cat ~/course/credentials/argocd-admin.txt)" --insecure
```

**Expect** (verified):

```text
No
{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev, iat: 2026-09-13T05:29:56Z",...}
```

**Say:** "Same fence as Exercise 4 Part A. Why does this message tell you everything, when that one told you nothing?"

**Answer key:** `team-a-dev` is allowed to *see* `team-a-guestbook`, so Argo CD can describe the denial without revealing anything new. For `storefront-prod-workload`, even saying "you can't sync *that*" would confirm it exists to someone not allowed to know.

**Wow moment:**

> "How much a denial tells you depends on what you're allowed to see. That's not inconsistency — it's the fence protecting information, not just actions."

### Part B — finalizers

```bash
kubectl --context k3d-mgmt -n argocd get applications -o custom-columns='NAME:.metadata.name,FINALIZERS:.metadata.finalizers'
```

**Expect** (verified — every row `<none>`):

```text
NAME                          FINALIZERS
platform-agent                <none>
platform-netpol               <none>
platform-quotas               <none>
platform-root                 <none>
storefront-dev-workload       <none>
storefront-prod-workload      <none>
storefront-staging-workload   <none>
team-a-guestbook              <none>
```

### Answer key — "why is 'there is no finalizer' dangerous to rely on?"

> "Whether an Application's workloads are deleted is decided by *how the delete is requested*, not by a field on the object. A `kubectl delete` of an Application with no finalizer leaves the workloads running, but `argocd app delete` (the CLI default) and the UI's Foreground/Background options ask for the cascade explicitly — so an Application showing no finalizer is one command away from taking its workloads with it. The boundary that actually holds is who is allowed to `delete` at all."

**Wow moment:**

> "The deletion danger doesn't live in the object. It lives in the delete *path*. You can inspect every field of this Application and still not know whether deleting it will take production down — until you know which button someone is about to press."

---

## 8. Checkpoint and design debrief

### The §9 table — answer key

| Attempt | Predicted layer | Observed message contains | Result rows? | Match |
|---|---|---|---|---|
| E3-A wrong destination | Fence 2 · AppProject | `InvalidSpecError … do not match any of the allowed destinations in project 'team-a'` | none | ✓ |
| E3-B ClusterRole | Fence 2b · cluster registration | `ComparisonError … can not be managed when in namespaced mode` | none | ✓ (fence 2 never asked) |
| E4-A `team-a-dev` syncs storefront | Fence 1 · Argo CD RBAC | `permission denied` (terse); server log names `applications, get` | none | ✓ |
| E4-B NetworkPolicy | Fence 3 · Kubernetes RBAC | `forbidden … system:serviceaccount:argocd-access:argocd-manager` | one, `SyncFailed` | ✓ |
| E5 delete as `team-a-dev` | Fence 1 · Argo CD RBAC | `permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev` | n/a | ✓ |

Checkpoint commands (verified): `rbac can … sync` → `Yes`; `rbac can … delete` → `No`; `git -C ~/platform-config log --oneline -1` shows the team-a commit touching `argocd/values.yaml` and `projects/team-a.yaml`.

### Design debrief — rank the denials (most to least self-serviceable)

| Rank | Denial | Why |
|---|---|---|
| 1 | AppProject destination (E3-A) | Names the server, the namespace, and the project. The developer can fix their own Application — or knows exactly what access to request |
| 2 | Kubernetes 403 (E4-B) | Precise (identity, resource, API group, namespace), but the developer can't fix it and it doesn't say who can. It names a ServiceAccount they've never heard of |
| 3 | Cluster registration scope (E3-B) | Names the kind, but "namespaced mode" points at a cluster Secret most developers don't know exists |
| 4 | Terse `permission denied` (E4-A) | Says nothing about what, which, or who |

**A better message for #4 — answer key** (there's no perfect answer; reward anyone who names the tension):

> "Permission denied: your roles (`role:team-a`) do not grant `get` on applications outside project `team-a`. To request access, see <runbook link>."

It describes *the caller's own grants* — which they're allowed to know — instead of the object they asked about, so it doesn't confirm that `storefront-prod-workload` exists.

**Wow moment:**

> "A guardrail nobody can interpret isn't prevention — it's a support ticket wearing a security badge."

---

## 9. Optional stretch challenges

### Stretch 1 — deny precedence (verified offline)

```bash
cat > /tmp/deny.csv <<'EOF'
p, role:team-a, applications, *, */*, allow
p, role:team-a, applications, delete, storefront/*, deny
g, team-a-dev, role:team-a
EOF
argocd admin settings rbac can team-a-dev delete applications 'storefront/storefront-prod-workload' --policy-file /tmp/deny.csv
argocd admin settings rbac can team-a-dev sync   applications 'storefront/storefront-prod-workload' --policy-file /tmp/deny.csv
argocd admin settings rbac can team-a-dev delete applications 'team-a/team-a-guestbook' --policy-file /tmp/deny.csv
```

```text
No
Yes
Yes
```

**Answer key:** the `deny` beats the broad `allow` for storefront deletes; the broad allow still grants everything else — including deleting team-a's own app. A `deny` is a seatbelt against a future over-broad grant, not a replacement for least privilege.

### Stretch 2 — lock the ApplicationSet controller

Not re-run in this rehearsal. Verified by the lab-tester on 2026-09-12 ([lab-05-validation.md](../../reviews/lab-05-validation.md), row 34): `applicationsetcontroller.policy: create-update` lands in `argocd-cmd-params-cm`, the controller restarts with `ARGOCD_APPLICATIONSET_CONTROLLER_POLICY=create-update`, and an ApplicationSet asking for `create-delete` did **not** get its Application deleted. **Answer to the prediction:** no — once the controller-wide policy is set, per-ApplicationSet overrides are disabled by default.

### Stretch 3 — deny sync window (verified)

```bash
argocd proj windows add storefront --kind deny --schedule "* * * * *" --duration 1h --applications "*"
argocd proj windows list storefront
argocd app get storefront-prod-workload | grep -i syncwindow
argocd app sync storefront-prod-workload --timeout 20
argocd proj windows delete storefront 0
```

```text
ID  STATUS  KIND  SCHEDULE   DURATION  APPLICATIONS  NAMESPACES  CLUSTERS  MANUALSYNC  SYNCOVERRUN  TIMEZONE  USEANDOPERATOR
0   Active  deny  * * * * *  1h        *             -           -         Disabled    Disabled     UTC       Disabled
SyncWindow:         Sync Denied
{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = cannot sync: blocked by sync window",...}
```

After deleting the window: `SyncWindow: Sync Allowed`.

**Say:** "That was `admin`, and it was refused. `MANUALSYNC Disabled` means nobody gets through. Every real change freeze needs an escape hatch — the auditable question is who may use it, and whether its use is recorded."

### Stretch 4 — project-role token for automation (corrected, verified)

The guide's `--object 'team-a/*'` produces a doubled prefix (verified):

```text
p, proj:team-a:ci-sync, applications, sync, team-a/team-a/*, allow
```

and a role with only `sync` is denied even on its own project, because the CLI must `get` the Application first (verified: `permission denied` for both `get` and `sync`).

**Use this instead** (verified):

```bash
argocd proj role create team-a ci-sync
argocd proj role add-policy team-a ci-sync --action get  --permission allow --object '*'
argocd proj role add-policy team-a ci-sync --action sync --permission allow --object '*'
argocd proj role get team-a ci-sync
```

```text
p, proj:team-a:ci-sync, projects, get, team-a, allow
p, proj:team-a:ci-sync, applications, get, team-a/*, allow
p, proj:team-a:ci-sync, applications, sync, team-a/*, allow
```

With a token from `argocd proj role create-token team-a ci-sync` (never print it — capture it in a variable):

| Action with the token | Result (verified) |
|---|---|
| `argocd app get team-a-guestbook` | Allowed |
| `argocd app sync team-a-guestbook` | Allowed by RBAC |
| `argocd app delete team-a-guestbook` | `permission denied: applications, delete, team-a/team-a-guestbook, sub: proj:team-a:ci-sync` |
| `argocd app get storefront-prod-workload` | `permission denied` |

**Wow moment:**

> "That's the safe replacement for handing CI an admin token: a credential that can see and sync one project's apps, can't delete anything, and can't even see that other projects exist."

Clean up: `argocd proj role delete team-a ci-sync`.

---

## 10. Hand-off to the capstone

**Do** (verified — this passes on the participant path):

```bash
reset-lab.sh CP-capstone --verify-only --local
```

**Expect:** 22 rows `PASS`, including `PASS  Argo CD RBAC role:team-a -> team-a-dev present`, ending `PASS CP-capstone is in the expected state.`

### Key takeaways — say them out loud

> "A guardrail you have never tried to break is a guardrail you do not have."

> "Four guards, three systems, four error signatures. Name the layer from the vocabulary of the message."

> "If the sync never started, it was Argo CD. If the sync started and failed, it was Kubernetes — and the sync result has a `SyncFailed` row to prove it."

> "`argocd admin settings rbac can` is a unit test for your permission model."

> "The deletion danger lives in the delete path, not in the object."

### Transition

**Say:**

> "Session 7 names the troubleshooting method you've been rehearsing since Lab 1. Then the capstone hands you a platform with several connected failures — and one of them is a denial exactly like the ones you triggered today. This time nobody tells you which guard it is."
