# Lab 2 — Instructor Walkthrough and Solutions

> **INSTRUCTOR ONLY. Never share this file with participants, never project it, and never paste it into a shared channel.**
> **Participant guide (now a modular arc):** [lab-02/README.md](../../day-1/lab-02/README.md)
> **Exercise → module map:** E1, E2 are in [module 02](../../day-1/lab-02/02-connect-repo-and-register-cluster.md); E3, E4 in [module 03](../../day-1/lab-02/03-prove-least-privilege-and-create-app.md); E5 in [module 04](../../day-1/lab-02/04-diagnose-and-wrap-up.md). Exercise IDs and answers below are unchanged.
> **Timebox:** 60 minutes · **Scaffolding:** G1 (maximally guided)
> **Verified:** 2026-09-13, end to end, on the course's local k3d two-cluster sandbox: Argo CD `v3.5.2` (chart `10.8.4`), `argocd` CLI `v3.5.2`, Kubernetes `v1.35.8+k3s1`, Helm `v4.2.1`. **Re-verified the same evening** in the Lab 2 validation pass (`courseware/reviews/lab-02-validation-2026-09-13.md`): server-side apply for every credential Secret, the cluster status that stays `Unknown` until an Application uses it, the one-hour repository status cache, and the stretch A cleanup. Every output block below was captured from those runs unless marked otherwise. SHAs, token lengths, and ages will differ on your machine. **No password or token value appears anywhere in this file.**

---

## How to read this file

| Label | What it tells you |
|---|---|
| **Say** | Words you can use nearly verbatim. Keep the questions — they are prompts for the room. |
| **Do** | A command you run on the projected VM terminal. |
| **Click** | A UI action in Firefox on the VM. |
| **Expect** | What the verified run showed. |
| **Answer key** | The answer participants should reach, with the reasoning. |
| **Wrong turns** | Mistakes participants actually make, and what each one looks like. |
| **Wow moment** | The sentence worth pausing on. |
| **If it goes sideways** | A tested recovery. |

**One rule for the whole lab:** never run a command that prints a credential on the projector. Every command below injects the password or token through a variable or a pipe. If a participant asks "can I see the token?", the answer is "no — and noticing that you wanted to is the lesson".

---

## 0. Before class — pre-flight (10 minutes)

### 0.1 Confirm the start state is really empty

`reset-lab.sh CP-lab-02` deletes every repository, repo-creds, and cluster Secret that the checkpoint does not contain, and its verifier checks for them. (Before 2026-09-13 it did not: a rehearsed VM showed `storefront-gitops` and `workload` already `Successful` before Exercise 1, which destroys the lab's before/after reveal.) The reset also removes anything a rehearsal of stretch A left on the workload cluster.

On any VM you rehearsed on, run:

```bash
reset-lab.sh CP-lab-02 --local --yes
reset-lab.sh CP-lab-02 --verify-only --local
kubectl --context k3d-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=repository
kubectl --context k3d-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
```

**Expect** (verified; the reset took 24 s):

```text
==> Verification for CP-lab-02
  PASS  Application hello-reconcile Synced/Healthy
  PASS  Application team-a-guestbook absent
  PASS  AppProject team-a absent
  PASS  Secret in-cluster present
  PASS  Repository and cluster Secrets are exactly: in-cluster
  PASS  workload namespace storefront-prod present
  PASS  workload SA argocd-manager absent (not registered)

PASS CP-lab-02 is in the expected state.
No resources found in argocd namespace.
NAME         TYPE     DATA   AGE
in-cluster   Opaque   3      2d20h
```

A participant who resets mid-lab gets the same clean state; no extra delete commands are needed. The reset also resets their `~/platform-config` clone. If they then re-run Module 1's `git clone`, Git answers `fatal: destination path 'platform-config' already exists and is not an empty directory.` — the guide tells them to `cd` into the existing copy.

### 0.2 Know where the lab files live

The guide refers to `~/course/lab-files/lab-02/…`. If that directory is missing on a VM, the same files are in the course checkout at `~/argo-cd-material/courseware/environment/lab-files/lab-02/`.

### 0.3 Know the four places where v3.5.2 surprises people

The participant guide now describes all four correctly. Knowing them lets you answer "is this broken?" in one sentence.

| Where | What happens (verified) | What to tell the room |
|---|---|---|
| E2, right after registering | `argocd cluster list` shows an **empty** STATUS for up to a minute, then **Unknown** — *"Cluster has no applications and is not being monitored."* It turns **Successful** about 5 s after E4 creates `storefront-dev` | "Argo CD tests a cluster only when an Application needs it. Nobody has checked yet." (Sections 3 and 5) |
| E1 and E5 record 1, the Repositories page | argocd-server caches each repository's connection result for **1 hour** (`--connection-status-cache-expiration`, default `1h0m0s`). A plain page load or `argocd repo list` can show the old result after a fix | Click **Refresh list** or run `argocd repo list --refresh hard` (Sections 2 and 6) |
| E5 record 2 (loopback cluster) | The UI shows **Unknown**, never Failed; the detail page and CLI say *"Cluster has no applications and is not being monitored."* | "Nobody measured it. `Unknown` is the honest answer." (Section 6) |
| Stretch A | It fails — **after** creating a ServiceAccount, a ClusterRole allowing every verb on every resource, a binding, and a long-lived token on the workload cluster | The guide warns and gives the cleanup; `reset-lab.sh` also removes them (Section 8) |

### 0.4 Why every Secret command in this lab says `--server-side`

A client-side `kubectl apply` stores a full copy of the object — **including the password or token** — in the `kubectl.kubernetes.io/last-applied-configuration` annotation. On Day 2 that annotation leaks in a surprising way (see the Lab 4 walkthrough, Exercise 5A). The guide's E1/E2/E5 steps use `kubectl apply --server-side -f -`, which does not create it, and `reset-lab.sh` strips any stale copy and re-applies server-side.

Verified behavior, if someone asks:

| Situation | Annotation afterwards |
|---|---|
| New Secret, `apply --server-side` | none |
| Secret already has the annotation, then `apply --server-side` | **still there, and rewritten with the new values** |
| Remove it first (`kubectl annotate secret <name> kubectl.kubernetes.io/last-applied-configuration-`), then `apply --server-side` | none |
| Plain `kubectl apply` over a server-side-applied Secret | added again |

Check without printing values — list the key **names** only:

```bash
kubectl --context k3d-mgmt -n argocd get secret repo-storefront-gitops -o go-template='{{range $k, $v := .metadata.annotations}}{{$k}}{{"\n"}}{{end}}'
```

**Expect:** no output.

---

## Run of show (60 minutes)

| Clock | Segment | Your job |
|---|---|---|
| 0:00–0:05 | Why this matters + environment check | Show the empty address book (Section 1) — make them remember "zero repository Secrets" |
| 0:05–0:12 | Module 1 sections 3–5 | Emphasize "valid from where it is used" |
| 0:12–0:22 | E1 — connect the private repo | Watch for passwords being echoed |
| 0:22–0:39 | E2 — register the workload cluster | Collect the "which cluster gets the RBAC?" prediction first; pre-empt "why Unknown?" |
| 0:39–0:47 | E3 — `can-i` matrix | Pairs |
| 0:47–0:55 | E4 — AppProject + Application | The `../../` path is where time goes; show the cluster turning Successful |
| 0:55–0:60 | E5 record 1 + debrief | Record 2 and stretches only if ahead |

---

## 1. Opening (3 minutes)

**Say:**

> "In Lab 1, Argo CD deployed to the cluster it lives on. Production platforms never do that, because the management cluster holds the keys to every other cluster. Today you build the real thing: a private repo, a separate workload cluster, an identity that can do only what it must, and a fence around what teams can deploy."

> "Here's the claim I want you to test today: 'connecting a repository' and 'registering a cluster' are not features. They are Secrets. By the end of Exercise 2 you'll either believe me or prove me wrong."

**Do** (Module 1 section 4, before anything is connected):

```bash
kubectl --context k3d-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=repository
kubectl --context k3d-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
```

**Expect** (on a clean `CP-lab-02` — see pre-flight 0.1):

```text
No resources found in argocd namespace.
NAME         TYPE     DATA   AGE
in-cluster   Opaque   3      2d20h
```

**Say:** "Remember this screen. Zero repositories, one cluster. We'll run the same two commands in twenty minutes."

---

## 2. Exercise 1 — Connect the private repository

### What participants just attempted

Replace `<PASSWORD>` in the template with the value from the credential file — without the password appearing in the file, the shell history, Git, or an annotation — apply it to the management cluster, and confirm `Successful`.

### Prediction answer

**"Successful immediately, or a delay?"** — Immediately. In the verified run, the first `argocd repo list`, run the same second as the apply, already showed `Successful`: listing repositories runs a connection test for a repository it has not tested yet. The catch comes later: that result is then cached for up to an hour (pre-flight 0.3).

### The solution

**Do** (option 1 — `yq`, verified):

```bash
cd ~/platform-config
GITEA_PW="$(cat ~/course/credentials/gitea-student.txt)" \
  yq '.stringData.password = strenv(GITEA_PW)' repositories/storefront-gitops.secret.template.yaml \
  | kubectl --context k3d-mgmt apply --server-side -f -
```

**Do** (option 2 — `envsubst`, as the guide's hint suggests; verified live):

```bash
cd ~/platform-config
export GITEA_PW="$(cat ~/course/credentials/gitea-student.txt)"
sed 's/<PASSWORD>/${GITEA_PW}/' repositories/storefront-gitops.secret.template.yaml \
  | envsubst '${GITEA_PW}' \
  | kubectl --context k3d-mgmt apply --server-side -f -
unset GITEA_PW
```

**Say** (point at option 2): "Why two steps? Because `envsubst` only replaces things that look like `${VARIABLE}`, and the template says `<PASSWORD>`. `sed` turns the placeholder into a variable reference; `envsubst` fills it. And the single quotes on `'${GITEA_PW}'` tell `envsubst` to replace *only* that variable and leave everything else alone."

**Do** (verify without printing the password):

```bash
argocd repo list
kubectl --context k3d-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=repository --show-labels
kubectl --context k3d-mgmt -n argocd get secret repo-storefront-gitops -o go-template='{{range $k, $v := .metadata.annotations}}{{$k}}{{"\n"}}{{end}}'
```

**Expect** (verified; the apply itself printed `secret/repo-storefront-gitops serverside-applied`, and the last command prints nothing):

```text
TYPE  NAME  REPO                                                INSECURE  OCI    LFS    CREDS  STATUS      MESSAGE  PROJECT
git         http://lab-gitea:3000/course/storefront-gitops.git  false     false  false  false  Successful

NAME                     TYPE     DATA   AGE   LABELS
repo-storefront-gitops   Opaque   4      1s    argocd.argoproj.io/secret-type=repository
```

**Click:** Settings (gear) → **Repositories**. Compare with [Figure SS-L2-02](../../assets/screenshots/day-1/lab-02-02-repository-connected.png): one row, no credentials template.

### Why it's correct

- The **label** `argocd.argoproj.io/secret-type: repository` is the entire feature. Argo CD watches for Secrets with that label in its own namespace.
- `$(cat …)` puts the file's contents into a variable. The **command text** saved in shell history contains only `cat ~/course/credentials/…`, never the password.
- Piping to `apply -f -` means the filled-in Secret never exists as a file on disk, so it can never be committed by accident.
- `--server-side` means no copy of the password is stored in the `last-applied-configuration` annotation (pre-flight 0.4).

### Wrong turns

| What they did | What they see | What you say |
|---|---|---|
| Edited the template and typed the password in | It works — and the password is now in a file in a Git working copy | "It works. Now run `git status`. That file is one `git add .` away from being in history forever." |
| `echo "password: $(cat …)"` to check | Password on screen | "Anyone behind you just learned it. Verify with `argocd repo list`, which never shows it." |
| Used `envsubst` without the `sed` step | `argocd repo list --refresh hard` shows `Failed … authentication required: Failed to authenticate user` — the literal text `<PASSWORD>` was sent. If the repository was already `Successful` earlier, a plain `argocd repo list` can keep showing `Successful` (verified) | "`envsubst` only understands `${…}`. Look at what the template actually contains." |
| Fixed the password and re-applied, but the page still says `Failed` | The one-hour status cache (verified: plain list `Failed`, `--refresh hard` `Successful`) | "The Secret is fixed. The page is showing a remembered answer. Click **Refresh list**." |
| Left out `--server-side` | Works; the annotation-name check prints `kubectl.kubernetes.io/last-applied-configuration` | "That annotation now holds your password. Remove it with `kubectl annotate … last-applied-configuration-` and re-apply with `--server-side`." |
| Applied to `k3d-workload` | Repositories page stays empty | "Which cluster runs Argo CD? That's the only cluster whose address book it reads." |

### Wow moment

> "Settings → Repositories is not a database. It's a picture of one labeled Secret. The UI row and the `kubectl` output you just printed are the same object seen through two windows."

> "And that green 'Successful'? It's a measurement from the last check — and on this page, that check can be an hour old. A credential that expires next month shows green today and fails the morning it matters."

---

## 3. Exercise 2 — Register the workload cluster with least privilege

### Collect the prediction first

**Say:** "The RBAC file creates a ServiceAccount, a token, Roles and RoleBindings. Hands up: which cluster gets them — management, or workload?"

Most rooms vote "management". Leave the tally on the board.

### Answer key — the prediction

**The workload cluster** — the one being *managed*. The ServiceAccount is the identity Argo CD will *become* when it talks to that cluster, so it has to exist on that cluster. The management cluster only stores a credential *for* it.

### Move A — create the identity on the workload cluster

**Do:**

```bash
kubectl --context k3d-workload apply -f ~/course/lab-files/lab-02/workload-rbac.yaml
```

**Expect** (verified):

```text
serviceaccount/argocd-manager created
secret/argocd-manager-token created
role.rbac.authorization.k8s.io/argocd-deployer created
rolebinding.rbac.authorization.k8s.io/argocd-deployer created
role.rbac.authorization.k8s.io/argocd-deployer created
rolebinding.rbac.authorization.k8s.io/argocd-deployer created
role.rbac.authorization.k8s.io/argocd-deployer created
rolebinding.rbac.authorization.k8s.io/argocd-deployer created
role.rbac.authorization.k8s.io/argocd-deployer created
rolebinding.rbac.authorization.k8s.io/argocd-deployer created
role.rbac.authorization.k8s.io/argocd-deployer-team created
rolebinding.rbac.authorization.k8s.io/argocd-deployer-team created
```

**Say:** "Count the Roles. Four `argocd-deployer`, one `argocd-deployer-team`. And count the ClusterRoleBindings: zero. Hold on to both numbers for Exercise 3."

### Moves B and C — collect the token and CA, render, apply to the management cluster

**Do** (verified):

```bash
cd ~/platform-config
TOKEN="$(kubectl --context k3d-workload -n argocd-access get secret argocd-manager-token \
  -o jsonpath='{.data.token}' | base64 -d)"
CA="$(kubectl --context k3d-workload -n argocd-access get secret argocd-manager-token \
  -o jsonpath='{.data.ca\.crt}')"
echo "token length=${#TOKEN} ca length=${#CA}"     # proves both are populated, prints no value
sed -e "s|<TOKEN>|${TOKEN}|" -e "s|<CA_DATA>|${CA}|" clusters/workload.secret.template.yaml \
  | kubectl --context k3d-mgmt apply --server-side -f -
unset TOKEN CA
```

**Expect** (verified; your lengths may differ slightly):

```text
token length=936 ca length=756
secret/cluster-workload serverside-applied
```

**Say** (on the `sed` delimiters): "Why `|` instead of `/` in `sed`? Because base64 CA data contains `/` and `+`. A token or CA never contains `|`, so it is a safe delimiter. Choosing a delimiter is a tiny decision that breaks a lot of scripts."

**Say** (on the two fields): "The token gets `base64 -d` because the template wants the raw bearer token. The CA does **not** get decoded, because the `caData` field *expects* base64. Decode the wrong one and you'll get either `Unauthorized` or a TLS error — and those two errors point at different fields."

**Do** (the reveal — same commands as the opening):

```bash
kubectl --context k3d-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
argocd cluster list
```

**Expect** (verified, immediately after the apply):

```text
NAME               TYPE     DATA   AGE
cluster-workload   Opaque   5      0s
in-cluster         Opaque   3      2d20h

SERVER                                             NAME        VERSION  STATUS      MESSAGE  PROJECT
https://k3d-workload-server-0:6443 (5 namespaces)  workload
https://kubernetes.default.svc                     in-cluster  v1.35.8  Successful
```

**Expect** (verified, `argocd cluster list` about a minute later):

```text
SERVER                                             NAME        VERSION  STATUS      MESSAGE                                                  PROJECT
https://k3d-workload-server-0:6443 (5 namespaces)  workload             Unknown     Cluster has no applications and is not being monitored.
https://kubernetes.default.svc                     in-cluster  v1.35.8  Successful
```

**Click:** Settings → **Clusters** ([SS-L2-03](../../assets/screenshots/day-1/lab-02-03-cluster-registered.png)), then click the `workload` row. The detail page ([SS-L2-04](../../assets/screenshots/day-1/lab-02-04-cluster-detail.png)) shows the five namespaces, the `cluster-role=workload region=lab` labels, APPLICATIONS `0`, and Connection state `Unknown`.

**Say** (before anyone asks "why isn't it green?"):

> "`Unknown` is not a failure. Argo CD connects to a cluster only when an Application deploys there, and we haven't given it one — that's Exercise 4. Keep this tab open. You'll watch this row change."

**Wow moment:**

> "Twenty minutes ago that command printed one row. Now it prints two. 'Registering a cluster' was writing a labeled Secret all along."

> "Look at the prediction tally on the board. Most of you said the ServiceAccount goes on the management cluster. It lives on the cluster being managed — the management side only holds a key to it. That inversion *is* the architecture."

### Why the server address is `k3d-workload-server-0`, not localhost

**Do** (safe to project — it prints only the address from your own kubeconfig):

```bash
kubectl config view -o jsonpath='{range .clusters[?(@.name=="k3d-workload")]}{.cluster.server}{"\n"}{end}'
```

**Expect** (verified on the sandbox; the port differs per machine): `https://127.0.0.1:6551`

**Say:**

> "That's how *you* reach the workload cluster: a port on this machine. Now imagine that address copied into the Argo CD controller Pod. Inside that Pod, `127.0.0.1` means the Pod itself. It would dial its own loopback and find nothing. A credential is only valid from the place that will use it — `127.0.0.1` in a kubeconfig is the most-copied bug in GitOps."

### Wrong turns

Because the cluster shows `Unknown` for everyone until E4, most E2 mistakes are **invisible until E4**. Ask each pair to read their `server:` line and decoded/not-decoded fields aloud before moving on.

| What they did | What they see | What you say |
|---|---|---|
| Applied the RBAC file to `k3d-mgmt` | Token Secret read on workload fails with `NotFound`; later, every `can-i` answer is `no` | "Where does the identity have to live?" |
| Read the token before the controller populated it | `token length=0` (in the verified run the token was already populated when first read) | Wait two seconds and read again |
| Decoded the CA with `base64 -d` | Nothing different yet; in E4 the Application reports a certificate error instead of `OutOfSync` *(not re-run in this pass)* | "`caData` wants base64. Leave it encoded." |
| Forgot to decode the token | Nothing different yet; in E4 the Application reports a credentials error *(not re-run in this pass)* | "The template wants the raw bearer token." |
| Used the kubeconfig server address | Nothing different yet; in E4 `storefront-dev` shows `Unknown` with an error naming that address | The `127.0.0.1` speech above |

---

## 4. Exercise 3 — Predict, then prove least privilege

### Answer key

**Do** (verified):

```bash
AS=system:serviceaccount:argocd-access:argocd-manager
kubectl --context k3d-workload auth can-i create deployments -n storefront-dev --as=$AS
kubectl --context k3d-workload auth can-i create deployments -n default --as=$AS
kubectl --context k3d-workload auth can-i create networkpolicies -n team-a --as=$AS
kubectl --context k3d-workload auth can-i delete namespaces --as=$AS
```

**Expect** (verified; the warning on row 4 is printed by `kubectl` and is harmless — the guide now says so):

```text
yes
no
no
Warning: resource 'namespaces' is not namespace scoped

no
```

| # | Check | Answer | Why |
|---|---|---|---|
| 1 | Create a Deployment in `storefront-dev` | **yes** | `argocd-deployer` Role + RoleBinding exist in that namespace and include `deployments` write verbs. |
| 2 | Create a Deployment in `default` | **no** | No RoleBinding in `default`. A namespace with no binding grants nothing. |
| 3 | Create a NetworkPolicy in `team-a` | **no** | `team-a` gets the *reduced* Role `argocd-deployer-team`, which deliberately omits NetworkPolicies, ResourceQuotas, and LimitRanges. (Contrast, verified: the same check in `storefront-dev` is `yes`.) |
| 4 | Delete a Namespace (cluster-scoped) | **no** | There is no ClusterRoleBinding with write access anywhere. Namespaced Roles can never grant a cluster-scoped verb. |

**Bonus demonstration** (verified) — the wrong-context mistake:

```bash
kubectl --context k3d-mgmt auth can-i create deployments -n storefront-dev --as=$AS
# no
```

**Say:** "Same question, wrong cluster, and the answer flips to `no`, because that identity doesn't exist on the management cluster. If every answer in your matrix is `no`, check the context before you check the RBAC."

### Wow moment

> "Every `no` in this table is Kubernetes saying 'I know who you are, and you may not'. That's a 403. It's a completely different fence from Argo CD's own permissions. Here's the rule you'll use in Lab 5 and the capstone: if a sync never started, Argo CD said no. If a sync started and then failed, Kubernetes said no."

> "One honest caveat for the security-minded: this identity can't *write* outside its namespaces, but Argo CD still needs to *read* broadly to compute live state. Least privilege for Argo CD means least *write* privilege."

---

## 5. Exercise 4 — Create the AppProject and Application declaratively

### What participants just attempted

Fill the `TODO` fields in two skeletons, commit, push, apply, and read `OutOfSync` + `Missing` as the correct first result.

### Prediction answer

**Immediately after `kubectl apply`, before any sync:** sync status `OutOfSync`, health `Missing`.

### The solution files (verified)

`~/platform-config/projects/storefront.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: storefront
  namespace: argocd
spec:
  description: Storefront application-team project
  sourceRepos:
    - http://lab-gitea:3000/course/storefront-gitops.git
  destinations:
    - server: https://k3d-workload-server-0:6443
      namespace: storefront-dev
  clusterResourceWhitelist: []
  namespaceResourceWhitelist:
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

`~/platform-config/applications/storefront-dev.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: storefront-dev
  namespace: argocd
spec:
  project: storefront
  source:
    repoURL: http://lab-gitea:3000/course/storefront-gitops.git
    targetRevision: main
    path: charts/storefront
    helm:
      valueFiles:
        - ../../envs/dev/values.yaml
  destination:
    server: https://k3d-workload-server-0:6443
    namespace: storefront-dev
```

> **Note:** the checkpoint copy of the project (`CP-lab-03`) also lists the `storefront-staging` and `storefront-prod` destinations. Lab 2 only needs `storefront-dev`; Lab 3 Exercise 2 widens it deliberately. A participant who adds all three today is not wrong, but ask them why they granted access nobody asked for yet. The `CP-lab-03` verifier does not check destinations, so both versions pass it.

**Do:**

```bash
cd ~/platform-config
git add projects/storefront.yaml applications/storefront-dev.yaml
git commit -m "Lab 2 E4: storefront AppProject and dev Application"
git push
kubectl --context k3d-mgmt apply -f projects/storefront.yaml
kubectl --context k3d-mgmt apply -f applications/storefront-dev.yaml
argocd app get storefront-dev --refresh
```

**Expect** (verified; the storefront-gitops SHA differs per run):

```text
Name:               argocd/storefront-dev
Project:            storefront
Server:             https://k3d-workload-server-0:6443
Namespace:          storefront-dev
URL:                https://localhost:8443/applications/storefront-dev
Source:
- Repo:             http://lab-gitea:3000/course/storefront-gitops.git
  Target:           main
  Path:             charts/storefront
  Helm Values:      ../../envs/dev/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        OutOfSync from main (a0ec068)
Health Status:      Missing

GROUP  KIND        NAMESPACE       NAME        STATUS     HEALTH   HOOK  MESSAGE
       ConfigMap   storefront-dev  storefront  OutOfSync  Missing
       Service     storefront-dev  storefront  OutOfSync  Missing
apps   Deployment  storefront-dev  storefront  OutOfSync  Missing
```

**Do** (the payoff from Exercise 2):

```bash
argocd cluster list
```

**Expect** (verified, 5 s after the Application was applied):

```text
SERVER                                             NAME        VERSION  STATUS      MESSAGE  PROJECT
https://kubernetes.default.svc                     in-cluster  v1.35.8  Successful
https://k3d-workload-server-0:6443 (5 namespaces)  workload    v1.35.8  Successful
```

**Say:** "Remember the `Unknown` row? The moment an Application needed that cluster, Argo CD used your key card for the first time — and it worked."

**Do:**

```bash
argocd proj get storefront
argocd app diff storefront-dev > /tmp/dev-diff.txt; echo "diff exit=$?"; grep '^=====' /tmp/dev-diff.txt
```

**Expect** (verified):

```text
Name:                        storefront
Description:                 Storefront application-team project
Destinations:                https://k3d-workload-server-0:6443,storefront-dev
Repositories:                http://lab-gitea:3000/course/storefront-gitops.git
Source Namespaces:           <none>
Scoped Repositories:         <none>
Allowed Cluster Resources:   <none>
Scoped Clusters:             <none>
Denied Namespaced Resources: <none>
Signature keys:              <none>
Orphaned Resources:          disabled

diff exit=1
===== /ConfigMap storefront-dev/storefront ======
===== /Service storefront-dev/storefront ======
===== apps/Deployment storefront-dev/storefront ======
```

Each diff section begins `0a1,…` followed only by `>` lines — desired-only, nothing live yet.

**Click:** the Applications list ([SS-L2-06](../../assets/screenshots/day-1/lab-02-06-applications-with-dev.png)), the `storefront-dev` tree ([SS-L2-07](../../assets/screenshots/day-1/lab-02-07-dev-tree-missing.png)), and the **Diff** toolbar button ([SS-L2-08](../../assets/screenshots/day-1/lab-02-08-dev-diff-all-new.png)).

### Answer key — the one-sentence explanation

> "It is `OutOfSync` because Git describes three resources the workload namespace does not have yet, and `Missing` because those resources are not deployed — nothing is broken, and sync is manual on purpose."

### Two things to point at

1. **"Where is the migration Job?"** The chart has a PreSync hook Job, yet the tree shows only ConfigMap, Service, and Deployment. **Answer:** hooks are not part of the compared state; they run *during* a sync. You'll see it appear in Lab 3.
2. **"Where is the HPA?"** The project allows `HorizontalPodAutoscaler`, but none is rendered. **Answer:** the chart only renders it when `hpa.enabled` is true, and it's `false` by default. The allow-list is for what the chart *can* create, not what it creates today.

### Wrong turns (verified error text)

**`valueFiles` with one `..` instead of two** — the most common mistake in the lab:

```text
Sync Status:        Unknown
Health Status:      Healthy

CONDITION        MESSAGE
ComparisonError  Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unknown desc = failed to execute helm template command: failed running helm: `helm template . --name-template storefront-dev --namespace storefront-dev --kube-version 1.35.8 --values <path to cached source>/charts/envs/dev/values.yaml <api versions removed> --include-crds` failed exit status 1: Error: open <path to cached source>/charts/envs/dev/values.yaml: no such file or directory
```

**Say:**

> "Read the path in the error: `charts/envs/dev/values.yaml`. Helm resolved your relative path starting *inside* `charts/storefront`. One `..` got you to `charts/`. You need two to get back to the repo root. The error message literally shows you where you ended up."

Also point out the badges: **sync `Unknown`, health `Healthy`.** Argo CD couldn't render, so it couldn't compare — and the health badge is not a real measurement here. Nothing was applied.

| Other mistake | Symptom | Fix |
|---|---|---|
| Destination `server` doesn't byte-match the registered cluster | App stuck `Unknown`; verified condition: `InvalidSpecError  error getting cluster by server "https://127.0.0.1:6551": … cluster "https://127.0.0.1:6551" not found` | Copy the URL from `argocd cluster list`, **without** the ` (5 namespaces)` suffix |
| Forgot a kind in `namespaceResourceWhitelist` | Nothing today; the Lab 3 sync is refused for that kind | Add the kind — the fence allows exactly what it lists |
| Added an `automated:` block | App syncs immediately | Remove it — Lab 3 turns automation on deliberately |

### Wow moment

> "Yellow `OutOfSync` and a `Missing` heart. On most dashboards that looks like trouble. Here it's the best possible news: Argo CD can reach the repo, render the chart, reach the cluster, and compare the two. Everything works except the thing we deliberately haven't done yet."

---

## 6. Exercise 5 — Diagnose two broken onboarding records

### Record 1 — the repository with the wrong URL (required)

**Do** (render exactly like E1):

```bash
GITEA_PW="$(cat ~/course/credentials/gitea-student.txt)" \
  yq '.stringData.password = strenv(GITEA_PW)' ~/course/lab-files/lab-02/broken/repo-secret-wrong-url.yaml \
  | kubectl --context k3d-mgmt apply --server-side -f -
argocd repo list --refresh hard
```

**Expect** (verified):

```text
TYPE  NAME  REPO                                                INSECURE  OCI    LFS    CREDS  STATUS      MESSAGE
git         http://lab-gitea:3000/course/storefront-gitops.git  false     false  false  false  Successful
git         http://lab-gitea:3000/course/storefront-typo.git    false     false  false  false  Failed      Unable to connect to repository: rpc error: code = Unknown desc = error testing repository connectivity: unable to ls-remote HEAD on repository: failed to list refs: repository not found: Repository not found
```

**Click:** Settings → Repositories → **Refresh list**, then the `storefront-typo` row. The message is under **Connection State Details** ([SS-L2-09](../../assets/screenshots/day-1/lab-02-09-repository-failed.png)); the list itself only says Failed.

**Answer key:** the single wrong field is `stringData.url` (`storefront-typo` instead of `storefront-gitops`). The message says "repository not found" — the host was reachable and the credentials were accepted; the *repository path* does not exist.

**Say:** "Read the message from right to left. 'Repository not found.' Not 'no such host'. Not 'authentication failed'. Each of those three messages points at a different field — host, path, or credential."

**If it goes sideways** (both verified):

- **Someone applied the file without rendering it** (the file still says `<PASSWORD>`): the message is `authentication required: Failed to authenticate user`. Gitea refuses the bad password before it reveals whether the repository exists, so the file now has two wrong fields. Delete it and render it properly.
- **They then rendered it and still see "authentication required"**: that is the one-hour status cache. `argocd repo list --refresh hard` (or **Refresh list**) shows "repository not found".

**Do:**

```bash
kubectl --context k3d-mgmt -n argocd delete secret repo-broken-url
```

### Record 2 — the cluster with the loopback server (optional)

**Do:**

```bash
TOKEN="$(kubectl --context k3d-workload -n argocd-access get secret argocd-manager-token \
  -o jsonpath='{.data.token}' | base64 -d)"
sed "s|<TOKEN>|${TOKEN}|" ~/course/lab-files/lab-02/broken/cluster-secret-wrong-server.yaml \
  | kubectl --context k3d-mgmt apply --server-side -f -
unset TOKEN
argocd cluster list
```

**Expect** (verified, immediately — empty STATUS for the new row):

```text
SERVER                                             NAME               VERSION  STATUS      MESSAGE  PROJECT
https://kubernetes.default.svc                     in-cluster         v1.35.8  Successful
https://127.0.0.1:6443                             workload-loopback
https://k3d-workload-server-0:6443 (5 namespaces)  workload           v1.35.8  Successful
```

**Expect** (verified, about a minute later):

```text
SERVER                                             NAME               VERSION  STATUS      MESSAGE                                                  PROJECT
https://k3d-workload-server-0:6443 (5 namespaces)  workload           v1.35.8  Successful
https://kubernetes.default.svc                     in-cluster         v1.35.8  Successful
https://127.0.0.1:6443                             workload-loopback           Unknown     Cluster has no applications and is not being monitored.
```

The UI shows **Unknown** ([SS-L2-10](../../assets/screenshots/day-1/lab-02-10-cluster-failed.png)); clicking the row shows the same message under **Details**. Applying the file without rendering `<TOKEN>` gives exactly the same result (verified) — Argo CD never tries the credential either.

**Answer key:** the wrong field is `stringData.server` (`https://127.0.0.1:6443`). From inside the controller Pod, `127.0.0.1` is the Pod itself.

**The better lesson — use it:**

**Say:**

> "Most of you predicted 'Failed'. We see 'Unknown'. Why?"

> "Because no Application points at this cluster, so Argo CD has never needed to connect to it. Nobody took the measurement. 'Unknown' isn't a failure and it isn't a success. It's Argo CD being honest that it hasn't looked. You saw the same thing with your *good* cluster after Exercise 2. A broken registration can sit there looking harmless for months — until the day someone deploys to it."

**Do:**

```bash
kubectl --context k3d-mgmt -n argocd delete secret cluster-broken-server
argocd cluster list
```

**Expect:** back to two rows, both `Successful`.

---

## 7. Checkpoint — grading at a glance

**Do** (verified):

```bash
reset-lab.sh CP-lab-03 --verify-only --local
```

**Expect** (verified — this passes on the participant's own Lab 2 work after the E5 cleanup, which proves their work matches the objects the next lab starts from):

```text
==> Verification for CP-lab-03
  PASS  Application hello-reconcile Synced/Healthy
  PASS  Application storefront-dev present (manual)
  PASS  Application team-a-guestbook absent
  PASS  AppProject team-a absent
  PASS  AppProject storefront present
  PASS  Secret in-cluster present
  PASS  Secret repo-storefront-gitops present
  PASS  Secret cluster-workload present
  PASS  Repository and cluster Secrets are exactly: in-cluster, repo-storefront-gitops, cluster-workload
  PASS  workload namespace storefront-prod present
  PASS  workload SA argocd-manager present
  PASS  workload RoleBinding argocd-deployer (storefront-prod) present

PASS CP-lab-03 is in the expected state.
```

If a broken E5 Secret is still present, the "exactly" row FAILs — send the participant back to E5 step 5. The verifier does not compare project destinations or Git history (see the note in Section 5).

| # | Criterion | Pass looks like |
|---|---|---|
| 1 | Repo connected | `argocd repo list` → `Successful` |
| 2 | Cluster registered | `argocd cluster list` → `workload` `Successful` at `https://k3d-workload-server-0:6443` |
| 3 | Address book | Two cluster Secrets |
| 4 | Matrix | yes / no / no / no, each with a reason |
| 5 | Render and compare | `OutOfSync` + `Missing`, three desired-only resources in the diff |

---

## 8. Optional stretch challenges

### Option A — why `argocd cluster add k3d-workload` fails here

**Do:**

```bash
argocd cluster add k3d-workload -y
```

**Expect** (verified; your port differs):

```text
{"level":"info","msg":"ServiceAccount \"argocd-manager\" created in namespace \"kube-system\"",...}
{"level":"info","msg":"ClusterRole \"argocd-manager-role\" created",...}
{"level":"info","msg":"ClusterRoleBinding \"argocd-manager-role-binding\" created",...}
{"level":"info","msg":"Created bearer token secret \"argocd-manager-long-lived-token\" for ServiceAccount \"argocd-manager\"",...}
{"level":"fatal","msg":"rpc error: code = Unknown desc = error getting server version: failed to get server version: Get \"https://127.0.0.1:6551/version?timeout=32s\": dial tcp 127.0.0.1:6551: connect: connection refused",...}
```

**Answer key (two sentences):** The command used the server address from the local kubeconfig (`https://127.0.0.1:<port>`). The Argo CD server tested that address from inside its own Pod, where `127.0.0.1` is the Pod itself, so the connection was refused.

**Wow moment — and a warning:**

> "Read the four lines *before* the failure. The command failed — but only after it created a cluster-wide ServiceAccount, a ClusterRole with every verb on every resource, a binding, and a long-lived token on the workload cluster. A failed command left a privileged credential behind. That's why we register declaratively: you can see exactly what you created."

Verified size of the leftover: the ClusterRole's rules are `["*"] ["*"] ["*"]`, and `kubectl --context k3d-workload auth can-i delete namespaces --as=system:serviceaccount:kube-system:argocd-manager` answers `yes`.

**Clean up immediately** (verified; the participant guide shows the same four commands, and `reset-lab.sh` now also removes these on every reset):

```bash
kubectl --context k3d-workload delete clusterrolebinding argocd-manager-role-binding
kubectl --context k3d-workload delete clusterrole argocd-manager-role
kubectl --context k3d-workload -n kube-system delete secret argocd-manager-long-lived-token
kubectl --context k3d-workload -n kube-system delete serviceaccount argocd-manager
```

The E2 identity in `argocd-access` is untouched (verified).

### Option B — a Gitea webhook

**Not verified in the rehearsal.** The guide marks it "partly verified". Treat it as an experiment: if it doesn't fire within a few minutes, fall back to Refresh. The conceptual answer to discuss is the network direction: polling is an *outbound* call from the management cluster; a webhook needs the Git server to reach *into* the management cluster.

### Option C — watch a healthy cluster go `Unknown`

**Prediction answer:** sync status becomes **`Unknown`** — not `OutOfSync`, not `Degraded`.

**Do:**

```bash
kubectl --context k3d-mgmt -n argocd patch secret cluster-workload --type merge \
  -p '{"stringData":{"config":"{\"bearerToken\":\"invalid\",\"tlsClientConfig\":{\"insecure\":true}}"}}'
argocd app get storefront-dev --refresh
argocd cluster list
```

**Expect** (verified, 5 s after the patch):

```text
Sync Status:        Unknown
Health Status:      Healthy

CONDITION        MESSAGE
ComparisonError  Failed to load live state: failed to get cluster info for "https://k3d-workload-server-0:6443": error synchronizing cache state : failed to get server version: failed to get server version: the server has asked for the client to provide credentials
ComparisonError  Failed to load target state: failed to get cluster version for cluster "https://k3d-workload-server-0:6443": ... the server has asked for the client to provide credentials
UnknownError     error synchronizing cache state : failed to get server version: failed to get server version: the server has asked for the client to provide credentials

SERVER                                             NAME        VERSION  STATUS      MESSAGE  PROJECT
https://k3d-workload-server-0:6443 (5 namespaces)  workload    v1.35.8  Successful
https://kubernetes.default.svc                     in-cluster  v1.35.8  Successful
```

**Expect** (verified, `argocd cluster list` about a minute later):

```text
SERVER                                             NAME        VERSION  STATUS      MESSAGE
https://k3d-workload-server-0:6443 (5 namespaces)  workload    v1.35.8  Failed      failed to get server version: failed to get server version: the server has asked for the client to provide credentials
https://kubernetes.default.svc                     in-cluster  v1.35.8  Successful
```

**Say — three observations, in this order:**

1. "Sync is `Unknown`. Argo CD can't read live state, so it refuses to guess."
2. "Health says `Healthy` — a minute ago it said `Missing`, and nothing got deployed. With no live view, that badge is not a measurement."
3. "And look at the cluster list: still `Successful`. That's a reading from *before* we broke it. Give it a minute and it turns `Failed`."

**Wow moment:**

> "`Unknown` was never a statement about the app. It was a statement about Argo CD's eyesight. And 'the server has asked for the client to provide credentials' is Kubernetes' polite way of saying 401 — I don't know who you are. Remember that sentence. You'll meet it again on Day 2 with nobody telling you it's coming."

**Restore — faster than a reset** (verified; no field-ownership conflict with the earlier `kubectl patch`, and back to `OutOfSync`/`Missing` within 5 s; the annotation-name check prints nothing afterwards):

```bash
cd ~/platform-config
TOKEN="$(kubectl --context k3d-workload -n argocd-access get secret argocd-manager-token -o jsonpath='{.data.token}' | base64 -d)"
CA="$(kubectl --context k3d-workload -n argocd-access get secret argocd-manager-token -o jsonpath='{.data.ca\.crt}')"
sed -e "s|<TOKEN>|${TOKEN}|" -e "s|<CA_DATA>|${CA}|" clusters/workload.secret.template.yaml | kubectl --context k3d-mgmt apply --server-side -f -
unset TOKEN CA
argocd app get storefront-dev --refresh | grep -E "Sync Status|Health Status"
```

The guide's slower alternative, `reset-lab.sh CP-lab-03 --local`, was also verified from this broken state: it restores `OutOfSync`/`Missing`, and it replaces the participant's `platform-config` commit with the checkpoint's.

---

## 9. Debrief (5 minutes)

1. **"What is 'registering a cluster', really?"** — Writing a labeled Secret in the `argocd` namespace.
2. **"Where does the ServiceAccount live, and why?"** — On the workload cluster, because it's the identity Argo CD becomes *there*.
3. **"Why did your good cluster say `Unknown` after Exercise 2?"** — Argo CD tests a cluster only when an Application uses it; nobody had checked yet.
4. **"Name three messages that each point at a different field."** — "repository not found" (URL path), "no such host" (hostname), "provide credentials" (token).
5. **"Why was `OutOfSync` + `Missing` good news?"** — It proves repo access, rendering, cluster access, and comparison all work.

### Key takeaways — say them out loud

> "Everything Argo CD knows about your repos and clusters is a labeled Secret in one namespace. Two `kubectl` commands print the whole address book."

> "The ServiceAccount lives in the cluster being managed, not the cluster doing the managing."

> "A credential is only valid from the place that will use it. `127.0.0.1` in a kubeconfig is the most-copied bug in GitOps."

> "`Unknown` does not mean broken. It means Argo CD cannot see — or has not looked yet — and you should go find out which."

> "The AppProject is a fence you build before you need it."

### Transition

**Say:**

> "`storefront-dev` is sitting at `OutOfSync` and `Missing`, and that's exactly where we want it. After Session 4, Lab 3 finally presses Sync — and then we break it on purpose, twice, in two different places."
