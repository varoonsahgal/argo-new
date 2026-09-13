# Lab 2 · Module 1 — Environment and the Address Book

> **Day 1 · Lab 2 · Module 1 of 4 · ~10 minutes**
> **Goal:** confirm the healthy starting state, see that Argo CD's knowledge of repos and clusters is just labeled Secrets, and study the two templates you will fill in.

---

## 1. Environment check — confirm `CP-lab-02`

**▶ Do this now — load the environment and verify (changes nothing).**

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-02 --verify-only --local
```

**Expected output** *(representative):*

```text
▶ Verification for CP-lab-02
  PASS  Application hello-reconcile Synced/Healthy
  PASS  Secret in-cluster present (management cluster registered)
  PASS  No repository Secret present (storefront-gitops NOT connected)
  PASS  No cluster Secret 'cluster-workload' present (workload NOT registered)
  PASS  workload namespaces present (argocd-access, storefront-dev, storefront-staging, storefront-prod, team-a, platform-system)
  PASS  workload SA argocd-manager absent (RBAC not yet applied)
  PASS  platform-config skeletons present

PASS CP-lab-02 is in the expected state.
```

**🔍 The whole starting story:** the workload cluster is **running but not registered**; the private repo is **not connected**; the workload **namespaces already exist** (the platform team pre-creates them — you do not); skeleton files with `TODO` markers wait in `platform-config`.

> **If any row says `FAIL`:** run `reset-lab.sh CP-lab-02 --local` (no `--verify-only`) to rebuild. It discards in-progress work and asks you to type the checkpoint name to confirm.

---

## 2. Look at "empty" in the web interface

**▶ Do this now:** in Argo CD, open **Settings** (gear icon) → **Repositories**.

![Argo CD Settings, Repositories with no private repository connected (v3.5.2)](../../assets/screenshots/day-1/lab-02-01-repositories-empty.png)

*Figure SS-L2-01 — Settings → Repositories at `CP-lab-02`: `storefront-gitops` is not connected yet.*

**🔍 Notice:** no `storefront-gitops` entry. This is where the green **connection status** will appear once you connect it in E1.

<!-- CAPTURE-SPEC: SS-L2-01 — Argo CD Settings → Repositories, environment check. State: CP-lab-02, route /settings/repos. Highlight: absence of a storefront-gitops row. Fidelity: full page. Argo CD v3.5.2. -->

---

## 3. Clone the platform repository you will edit

**▶ Do this now:**

```bash
cd ~
git clone http://lab-gitea:3000/course/platform-config.git
cd platform-config
git config user.email "student@lab.local"
git config user.name "Student"
```

It holds the templates and skeletons you will fill in:

```text
platform-config/
  repositories/storefront-gitops.secret.template.yaml   # E1: repository Secret template
  clusters/workload.secret.template.yaml                # E2: cluster Secret template
  projects/storefront.yaml                              # E4: AppProject skeleton (TODOs)
  applications/storefront-dev.yaml                      # E4: Application skeleton (TODOs)
```

Two more files live on the VM (not in Git, because they touch credentials): `~/course/credentials/gitea-student.txt` (the Gitea password) and `~/course/lab-files/lab-02/workload-rbac.yaml` (the least-privilege RBAC for E2).

---

## 4. The two-command address book

Argo CD's entire knowledge of your repos and clusters is a set of labeled Secrets in the `argocd` namespace. Print the whole "address book" with two commands — **before** you have connected anything.

**▶ Do this now:**

```bash
kubectl --context k3d-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=repository
kubectl --context k3d-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
```

**Expected now** *(representative):*

```text
# repository Secrets:
No resources found in argocd namespace.

# cluster Secrets:
NAME         TYPE     DATA   AGE
in-cluster   Opaque   3      2d
```

**🔍 Notice:** no repository Secrets yet (matching the empty page), and **one** cluster Secret — the management cluster (`in-cluster`). By the end of E2 the second command returns **two** rows. That before/after *is* the reveal: "registering a cluster" was always creating a labeled Secret.

> **Never print a Secret's decoded contents in this course.** These commands show a Secret's *existence and labels*, never its values.

---

## 5. Study the two templates you will fill in

**▶ Do this now — read the repository template:**

```bash
cat ~/platform-config/repositories/storefront-gitops.secret.template.yaml
```

```yaml
metadata:
  name: repo-storefront-gitops
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository   # <-- this label makes it a repository connection
stringData:
  type: git
  url: http://lab-gitea:3000/course/storefront-gitops.git   # in-network Gitea address
  username: student
  password: <PASSWORD>                            # <-- the ONLY placeholder; injected in E1
```

**▶ Do this now — read the cluster template:**

```bash
cat ~/platform-config/clusters/workload.secret.template.yaml
```

```yaml
metadata:
  name: cluster-workload
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster       # <-- this label makes it a cluster registration
    cluster-role: workload
    region: lab
stringData:
  name: workload
  server: https://k3d-workload-server-0:6443      # <-- in-network name, NOT localhost
  namespaces: storefront-dev,storefront-staging,storefront-prod,team-a,platform-system
  clusterResources: "false"                        # <-- forbid cluster-scoped WRITES
  config: |
    { "bearerToken": "<TOKEN>", "tlsClientConfig": { "insecure": false, "caData": "<CA_DATA>" } }
```

**🔍 The single most important line** is `server: https://k3d-workload-server-0:6443`. Your kubeconfig reaches the workload cluster over a `localhost` port, but Argo CD's controller Pod cannot use `localhost` to mean the workload cluster — inside that Pod, `localhost` means the Pod itself. `k3d-workload-server-0` is a name every Pod on the shared network can resolve. The `namespaces` + `clusterResources: "false"` fields are the least-privilege scope.

**→ Next:** [02 — Connect the repo, register the cluster](02-connect-repo-and-register-cluster.md)
