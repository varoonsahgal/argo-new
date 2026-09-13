# Lab 5 · Module 1 — Environment and the Two Mechanisms

> **Day 2 · Lab 5 · Module 1 of 4 · ~5 minutes**
> **Goal:** confirm the start state, and learn the two mechanisms you will use (writing a fence and a policy) plus the two read-only tools that ask each fence its verdict.

---

## 1. Environment check — confirm `CP-lab-05`

Your starting state: Lab 4's `storefront` ApplicationSet (three generated apps) and the `platform-root` App-of-Apps with its three children are running; `storefront` and `platform` projects exist. **team-a does not exist yet** — no `team-a` project, and `team-a-dev` can log in but has zero permissions.

**▶ Do this now:**

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-05 --verify-only --local
```

**Expected** *(abridged):* all `platform-*` and `storefront-*-workload` apps `Synced`/`Healthy`, `ApplicationSet storefront present`, and — importantly — two rows that assert an **absence**: `AppProject team-a absent` and `Application team-a-guestbook absent`. A "PASS" on an *absent* row confirms the thing is correctly missing; you create both in Exercise 1. If any row says **FAIL**, run `reset-lab.sh CP-lab-05 --local`.

**▶ Confirm the starting picture.** In Settings → Projects you should see exactly `default`, `platform`, `storefront` — **no** `team-a`.

![Settings → Projects at the start of Lab 5: default, platform, storefront, no team-a (v3.5.2)](../../assets/screenshots/day-2/lab-05-01-env-check-projects.png)

<!-- CAPTURE-SPEC: SS-L5-01 — Settings → Projects. State: CP-lab-05. Highlight: default/platform/storefront, NO team-a. Argo CD v3.5.2. -->

---

## 2. Where the two Argo CD fences are configured

Both fences you control live in `platform-config`, applied by the platform tooling — not typed into the cluster. That is the point of GitOps governance: the fence is reviewed, versioned, and reversible.

**Fence 2 — the AppProject — is a YAML file per project.**

```bash
cat platform-config/projects/storefront.yaml
```

The fields that matter: `sourceRepos`, `destinations`, `clusterResourceWhitelist` (cluster-scoped kinds; `[]` = **none**), `namespaceResourceWhitelist` (namespaced kinds; listed = only those).

> **Refresher — cluster-scoped vs namespaced.** A **namespaced** resource lives in one namespace (Deployment, Service, NetworkPolicy). A **cluster-scoped** one has no namespace and affects the whole cluster (ClusterRole, Namespace, CRD).

**Fence 1 — Argo CD RBAC — is a block of policy lines** inside the Argo CD Helm values:

```bash
grep -n -A6 "rbac:" platform-config/argocd/values.yaml
```

**Expected:**

```text
141:  rbac:
144-    policy.default: ""
145-    policy.csv: ""
```

`policy.csv` is empty today — which is why `team-a-dev` can log in but see nothing. You fill it in Exercise 1.

---

## 3. How a values change becomes live Argo CD configuration

Editing `values.yaml` does nothing on its own. The platform tooling applies it with one wrapper:

```bash
apply-argocd-config.sh ~/platform-config/argocd/values.yaml
```

With **no argument**, the wrapper reads `platform-config` `main` as Gitea serves it — the declarative source of truth. Passing a **file path** layers your *uncommitted* edit on top of that base, which is what you want while iterating (Exercise 1 commits it afterward). The wrapper announces which it did on a `values source:` line. It runs `helm upgrade --install`, which rewrites `argocd-rbac-cm`. You do **not** edit `argocd-rbac-cm` by hand.

> **You normally stay logged in — check the wrapper's output.** Applying re-stamps account passwords **only when the credential files changed** (usually not). When they have not, it prints `account passwords unchanged: reusing the live hashes` and your session keeps working. **If** it re-stamped them, the next `argocd` command fails with `invalid session: account password has changed since token issued` — a red herring about the apply, not your policy. If you see it, log in again:
> ```bash
> argocd login localhost:8443 --username admin \
>   --password "$(cat ~/course/credentials/argocd-admin.txt)" --insecure
> ```

---

## 4. The two tools that read a fence's verdict

You do not have to guess what a fence will decide.

**Argo CD RBAC (fence 1)** — `argocd admin settings rbac can` answers `Yes`/`No`. It requires **exactly one** source flag:

| Flag | Reads | Use when |
|---|---|---|
| `--policy-file <path>` | a CSV file on disk (nothing on the cluster) | testing a policy *before* shipping it |
| `--namespace argocd` | the live `argocd-rbac-cm` | checking what is in force *now* |

**▶ Try the offline mode** (changes nothing):

```bash
cat > /tmp/rbac-demo.csv <<'EOF'
p, role:demo, applications, sync, demo/*, allow
g, demo-user, role:demo
EOF
argocd admin settings rbac can demo-user sync applications 'demo/demo-app' --policy-file /tmp/rbac-demo.csv
```

**Expected:** `Yes`. This is what "policy as code" means — unit-test a permission model before any user is exposed to it.

> **Watch the argument order — a genuine trap.** In a `policy.csv` *line* the order is `p, subject, resource, action, object`. In the `rbac can` *command* it is `can <subject> <action> <resource> <object>` — resource and action **swap places**.

**Kubernetes RBAC (fence 3)** — `kubectl auth can-i … --as`:

```bash
kubectl --context k3d-workload auth can-i create deployments.apps -n team-a \
  --as=system:serviceaccount:argocd-access:argocd-manager
```

**Expected:** `yes` — fence 3 saying the workload ServiceAccount may create Deployments in `team-a`. In Exercise 4 you ask the *same* question about a NetworkPolicy and get a very different answer.

**→ Next:** [02 — Build the fence and prove the happy path](02-build-fence-and-happy-path.md)
