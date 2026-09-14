# Lab 5 · Module 2 — Build the Fence and Prove the Happy Path

> **Day 2 · Lab 5 · Module 2 of 4 · ~13 minutes**
> **Goal:** create team-a's restricted AppProject and least-privilege RBAC grant (**E1**), then deploy an app that lands inside every fence (**E2**).

> **The rhythm:** for every attempt — **(1) predict** which fence refuses and what the message says, **(2) try** it, **(3) read** the actual message and confirm which fence it names.

---

## Exercise 1 — Build team-a's fence and grant its account (8 min · foundational)

**Goal.** Create the `team-a` AppProject from the spec, write the RBAC policy that lets `team-a-dev` use it with **least** privilege, and commit both so the fence is reviewable.

**Part A — the AppProject.** Create `platform-config/projects/team-a.yaml` from this skeleton (field names and nesting are yours):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  description: team-a tenant project
  # TODO(E1a): sourceRepos, destinations, clusterResourceWhitelist, namespaceResourceWhitelist
```

| Fence field | team-a is allowed | How to get the value |
|---|---|---|
| `sourceRepos` | **only** the team-a repo | `http://lab-gitea:3000/course/team-a-apps.git` |
| `destinations` | **only** the `workload` cluster, namespace `team-a` | the cluster's `server` URL from `argocd cluster list` — the URL **only**, not the ` (5 namespaces)` suffix |
| `clusterResourceWhitelist` | **nothing** cluster-scoped | an empty list `[]` |
| `namespaceResourceWhitelist` | `ConfigMap`, `Service`, `Deployment`, `NetworkPolicy` — and **nothing else** (so `ResourceQuota`/`LimitRange` are denied by omission) | four `group`+`kind` pairs |

```bash
kubectl --context k3d-mgmt apply -f platform-config/projects/team-a.yaml
argocd proj get team-a
```

**Part B — the RBAC grant.** Team-a needs to **see** and **sync** its own apps — nothing more. Edit `platform-config/argocd/values.yaml` so `policy.csv` is a block scalar:

```yaml
  rbac:
    policy.default: ""
    policy.csv: |
      # TODO(E1b): grant role:team-a least privilege on team-a/*, then bind team-a-dev.
      # Permission line:  p, <role>, applications, <action>, <project>/<app-glob>, allow
      # Group binding:    g, <subject>, <role>
```

**▶ Unit-test the policy before applying.** Put your candidate lines in `/tmp/my-policy.csv`, then:

```bash
argocd admin settings rbac can team-a-dev sync   applications 'team-a/team-a-guestbook' --policy-file /tmp/my-policy.csv   # expect: Yes
argocd admin settings rbac can team-a-dev delete applications 'team-a/team-a-guestbook' --policy-file /tmp/my-policy.csv   # expect: No
```

Only when the offline test matches your intent, paste the lines into `values.yaml` and apply (pass the path — your edit is not on `main` yet):

```bash
apply-argocd-config.sh ~/platform-config/argocd/values.yaml
```

Read the wrapper's last lines. It should report `account passwords unchanged: reusing the live hashes` (session still valid). Then ask the **live** policy the same two questions with `--namespace argocd` (expect `Yes` then `No`).

**Part C — commit the fence.** A guardrail only on the cluster is not governance — the next `reset-lab.sh` discards it:

```bash
git -C ~/platform-config add projects/team-a.yaml argocd/values.yaml
git -C ~/platform-config commit -m "team-a: restricted AppProject and least-privilege RBAC grant"
git -C ~/platform-config push origin main
```

*(Credentials: `~/course/credentials/gitea-student.txt`. If Git says `Author identity unknown`, set `git config user.email "student@lab.local"` and `user.name "Student"` in this clone and re-commit.)*

**Output shape of a correct result:**
- `argocd proj get team-a` prints one source repo, one destination, `Allowed Cluster Resources: <none>`. (Your four namespaced kinds are *not* in this summary — use `argocd proj get team-a -o yaml` or the UI to see them; note there is **no `clusterResourceWhitelist` key at all**, because an empty list is dropped when stored — empty, absent, and "deny every cluster-scoped kind" are the same thing.)
- Both `rbac can … --namespace argocd` checks answer `Yes` (sync), `No` (delete).

![Argo CD project detail for team-a: one source repo, one destination, empty cluster allow-list, four namespaced kinds (v3.5.2)](../../assets/screenshots/day-2/lab-05-02-project-team-a.png)

**🔍 Notice:** SOURCE REPOSITORIES lists exactly one repo; DESTINATIONS one row (its **Name** column blank because you named the cluster by `server` URL — both forms valid); CLUSTER RESOURCE ALLOW LIST reads "The cluster resource allow list is empty" (your `[]`); NAMESPACE RESOURCE ALLOW LIST has four kinds and no more (`ResourceQuota`/`LimitRange` absent = denied).

<!-- CAPTURE-SPEC: SS-L5-02 — Project detail for team-a. State: after E1 apply. Highlight: source repos, destinations, empty cluster allow-list, four namespaced kinds. Argo CD v3.5.2. -->

**Hints:**
- *Hint 1:* `clusterResourceWhitelist: []` is the whole "no cluster-scoped" rule. For `namespaceResourceWhitelist`, each entry is `- group: …` / `kind: …`; `ConfigMap` uses `group: ""`; find others with `kubectl --context k3d-workload api-resources | grep -i networkpolic`.
- *Hint 2:* "Least privilege" is **two** actions: `get` and `sync`. Do **not** add `delete`/`override`/`create`/`*`. The account also needs the `g,` binding, or the permission lines apply to a role nobody holds.
- *Hint 3:* If `sync` prints `No`, check the `g,` binding and the object — it must be `team-a/*`, not `team-a`. If `delete` prints `Yes`, you granted too much (probably `*` as action or object).

---

## Exercise 2 — Prove the happy path: deploy team-a's app (5 min · easy)

**Goal.** Create an Application that lands **inside every fence** and reaches `Synced`/`Healthy`. Before proving the fences *block* things, prove they *let the right thing through*.

**Starter state.** The `team-a` project and grant are live. The `team-a-apps` repo has a `guestbook/` app (a small `podinfo` Deployment + Service targeting namespace `team-a`). Create the applications directory first:

```bash
mkdir -p ~/platform-config/applications
```

**What to write** — an `Application` with:

| Field | Value |
|---|---|
| `metadata.name` | `team-a-guestbook` |
| `metadata.namespace` | `argocd` |
| `spec.project` | `team-a` |
| `spec.source` | repo `team-a-apps.git`, `path: guestbook`, `targetRevision: main` |
| `spec.destination` | the `workload` cluster, `namespace: team-a` |
| `spec.syncPolicy` | **leave it out entirely** — sync by hand |

Leaving `syncPolicy` out is deliberate — every sync should be one *you* asked for, so "did the sync start?" has a meaningful answer, and the throwaways in E3/E4 do not sync themselves.

```bash
kubectl --context k3d-mgmt apply -f platform-config/applications/team-a-guestbook.yaml
argocd app sync team-a-guestbook
argocd app get team-a-guestbook
```

**Output shape:** `Synced` / `Healthy`, with the guestbook `Deployment` and `Service` in namespace `team-a`, each `Synced`. Because this app obeys every guard — approved repo, approved destination, namespaced kinds only, kinds the SA can create — nothing refuses it.

> **Two things that look wrong but are not.** The table that `argocd app sync` prints at the end shows both resources as `OutOfSync`/`Missing` — that is their state *before* the sync created them (the MESSAGE column already says `created`). And if you run `argocd app get` straight away, `Health Status` may still read `Progressing` while the Pod starts; run it again a few seconds later and it reads `Healthy`.

> **One line worth reading.** `argocd app get` prints a `URL:` line (`https://localhost:8443/applications/team-a-guestbook`). It is built from `global.domain` in the values file (written into `argocd-cm`) — the one-click path from a terminal finding to the same object in the UI. You will use it constantly in the capstone.

**Hints:**
- *Hint 1:* If Argo CD rejects it with a condition mentioning your project, the `source`, `destination`, or a kind does not match the E1 fence — the condition names which.
- *Hint 2:* If it stays `OutOfSync`/`Missing`, you have not synced yet, or `path` is not `guestbook`.

**→ Next:** [03 — Bypass attempts](03-bypass-attempts.md)
