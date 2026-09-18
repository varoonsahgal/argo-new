# Lab 5 · Module 1 — Starting State and the Two Mechanisms

> **Day 2 · Lab 5 · Module 1 of 4 · 5 minutes**
> **Run every command in your VM terminal**, after `source ~/argo-lab-env.sh`.
> **← Back to:** [Day 2 map](../README.md) · [Lab 5](README.md)

---

## Module TL;DR

- **What this is.** Confirm the start state, and learn the two things you will write — a fence and a policy — plus the two read-only tools that ask each gate its verdict in advance.
- **Why it matters.** You never have to guess what a gate will decide. Both can be asked directly, before anything is at risk.
- **What to remember.** *A permission model can be unit-tested as a file.*
- **The most common mistake.** Getting the argument order wrong in `rbac can`, and believing the confident wrong answer it gives you.

---

## 1. The exact starting state

Your starting state is checkpoint **`CP-lab-05`**:

| Present | Absent, on purpose |
|---|---|
| Lab 4's `storefront` ApplicationSet and its three generated Applications | the `team-a` AppProject |
| the `platform-root` App-of-Apps and its three children | the `team-a-guestbook` Application |
| the `storefront` and `platform` AppProjects | any entry in `policy.csv` |
| the local account `team-a-dev`, able to log in with **zero permissions** | |

**▶ Do this now — verify the checkpoint.** This changes nothing:

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-05 --verify-only --local
```

**Expected:** every row `PASS`. All `platform-*` and `storefront-*-workload` Applications are `Synced`/`Healthy`, `ApplicationSet storefront present`, and two rows that assert an **absence**:

```text
  PASS  Application team-a-guestbook absent
  PASS  AppProject team-a absent
```

**A `PASS` on an absent row confirms the thing is correctly missing.** You create both in Exercise 1.

If any row says **FAIL**, run `reset-lab.sh CP-lab-05 --local`.

**▶ Confirm the starting picture.** In **Settings → Projects** you should see exactly `default`, `platform`, and `storefront` — and **no** `team-a`.

![Settings → Projects at the start of Lab 5: default, platform, storefront, no team-a (v3.5.2)](../../assets/screenshots/day-2/lab-05-01-env-check-projects.png)

<!-- CAPTURE-SPEC: SS-L5-01 — Settings → Projects. State: CP-lab-05. Highlight: default/platform/storefront, NO team-a. Argo CD v3.5.2. -->

### Mini TL;DR — section 1

- Lab 4's work carries forward; team-a does not exist yet.
- `team-a-dev` can log in and see nothing, which is the correct starting point.
- A `PASS` on an "absent" row means correctly missing.

---

## 2. Mechanism one: a fence is a YAML file

**Gate 2 — the AppProject — is one YAML file per project.** Read an existing one:

```bash
cat ~/platform-config/projects/storefront.yaml
```

The four fields that matter:

| Field | Controls | Empty means |
|---|---|---|
| `sourceRepos` | which Git repositories the project's apps may deploy from | nothing allowed |
| `destinations` | which cluster and namespace pairs they may target | nothing allowed |
| `clusterResourceWhitelist` | which **cluster-scoped** kinds they may create | **none at all** |
| `namespaceResourceWhitelist` | which **namespaced** kinds they may create | nothing allowed |

> **Refresher — cluster-scoped versus namespaced.** A **namespaced** resource lives inside one namespace: a Deployment, a Service, a NetworkPolicy. A **cluster-scoped** resource has no namespace and affects the whole cluster: a ClusterRole, a Namespace, a CustomResourceDefinition.

**An AppProject is a positive list.** It permits exactly what it names and refuses everything else.

---

## 3. Mechanism two: a policy is a block of CSV lines

**Gate 1 — Argo CD RBAC — lives in the Argo CD Helm values.** Look at it:

```bash
grep -n -A6 "rbac:" ~/platform-config/argocd/values.yaml
```

**Expected output** — verified on the course environment:

```text
141:  rbac:
142-    # No permissions by default: an account that is not named in policy.csv can
143-    # log in and see nothing. Every grant is written here, deliberately.
144-    policy.default: ""
145-    policy.csv: ""
```

**`policy.csv` is empty today.** That is exactly why `team-a-dev` can log in and see nothing. You fill it in Exercise 1.

| Line type | Shape | Reads as |
|---|---|---|
| `p` — permission | `p, subject, resource, action, object, effect` | "this role may take this action on objects matching this pattern" |
| `g` — grant | `g, subject, role` | "this account holds this role" |

---

## 4. How a values change becomes live Argo CD configuration

**Editing `values.yaml` does nothing on its own.** The platform tooling applies it:

```bash
apply-argocd-config.sh ~/platform-config/argocd/values.yaml
```

| How you call it | What it uses |
|---|---|
| with **no argument** | `platform-config` `main`, as Gitea serves it — the declarative source of truth |
| with a **file path** | that same base, **plus your uncommitted edit layered on top** |

**While you are iterating, pass the path.** Your edit is not on `main` yet. Exercise 1 commits it afterwards.

The wrapper runs `helm upgrade --install`, which rewrites the `argocd-rbac-cm` ConfigMap. **You never edit `argocd-rbac-cm` by hand.**

**Read two lines in its output** — verified wording:

```text
  ok values source: <the base it used>
  ok overlay: /Users/you/platform-config/argocd/values.yaml
```

> **You normally stay logged in — but check.** The wrapper re-stamps account passwords **only when the credential files changed**, which is usually not the case. When they have not, it prints:
>
> ```text
>   ok account passwords unchanged: reusing the live hashes (existing logins stay valid)
> ```
>
> **If it did re-stamp them**, your next `argocd` command fails with `invalid session: account password has changed since token issued`. That is a red herring about the apply, not about your policy. Log in again:
>
> ```bash
> argocd login localhost:8443 --username admin \
>   --password "$(cat ~/course/credentials/argocd-admin.txt)" --insecure
> ```

### Mini TL;DR — sections 2 to 4

- A fence is a YAML file; a policy is a block of CSV lines. Both live in `platform-config`.
- `apply-argocd-config.sh` turns a values edit into live configuration.
- Pass the file path while iterating; commit afterwards.

---

## 5. The two tools that read a gate's verdict in advance

**You never have to guess what a gate will decide.**

### Gate 1 — `argocd admin settings rbac can`

It answers `Yes` or `No`, and requires **exactly one** source flag:

| Flag | Reads | Use it when |
|---|---|---|
| `--policy-file <path>` | a CSV file on disk; contacts no cluster | testing a policy **before** shipping it |
| `--namespace argocd` | the live `argocd-rbac-cm` | checking what is in force **now** |

**▶ Try the offline mode.** This changes nothing:

```bash
cat > /tmp/rbac-demo.csv <<'EOF'
p, role:demo, applications, sync, demo/*, allow
g, demo-user, role:demo
EOF
argocd admin settings rbac can demo-user sync applications 'demo/demo-app' --policy-file /tmp/rbac-demo.csv
```

**Expected:** `Yes`

**That is what "policy as code" means:** you unit-tested a permission model before any user was exposed to it.

Clean up: `rm -f /tmp/rbac-demo.csv`

> **⚠️ Watch the argument order — this is a genuine trap.**
>
> In a `policy.csv` **line**: `p, subject, resource, action, object`
> In the **command**: `can <subject> <action> <resource> <object>`
>
> **Resource and action swap places.** Get it backwards and you will see `error in RBAC request: 'sync' is not a valid resource name` — or, worse, a confident `No` to a question you did not actually ask.

**With neither flag**, the command fails clearly — verified:

```text
{"level":"fatal","msg":"please provide exactly one of --policy-file or --namespace"}
```

### Gate 4 — `kubectl auth can-i ... --as`

**▶ Try it:**

```bash
kubectl --context k3d-workload auth can-i create deployments.apps -n team-a \
  --as=system:serviceaccount:argocd-access:argocd-manager
```

**Expected:** `yes` — gate 4 confirming that the workload ServiceAccount may create Deployments in `team-a`.

**In Exercise 4 you will ask the same question about a NetworkPolicy and get a very different answer.**

### Mini TL;DR — section 5

- Both gates answer questions read-only, before you trigger anything.
- `--policy-file` is the CI check; `--namespace argocd` is the production check.
- The `rbac can` argument order is **not** the policy file's order.

---

## ✅ Key Takeaways from this module

- **`CP-lab-05` carries Lab 4 forward and deliberately omits team-a.**
- **A fence is a YAML file; a policy is CSV lines.** Both are reviewable, versioned, and reversible.
- **`apply-argocd-config.sh` is the only way a values edit becomes live**, and you never hand-edit `argocd-rbac-cm`.
- **Every gate can be interrogated read-only**, before anything is at risk.
- **Resource and action swap places** between a policy line and the `rbac can` command.

---

## Cleanup

One temporary file, if you created it:

```bash
rm -f /tmp/rbac-demo.csv
```

---

## Final module TL;DR

- **What this is.** Start state confirmed, both mechanisms read, both verdict tools tried.
- **Why it matters.** Everything after this is safe because you can ask before you act.
- **What to remember.** Test the policy as a file first.
- **The most common mistake.** The swapped argument order in `rbac can`.

**→ Next:** [02 — Build the fence, prove the happy path](02-build-fence-and-happy-path.md)
