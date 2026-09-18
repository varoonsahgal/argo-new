# Session 3 · Module 2 — Onboarding Repositories and Clusters

> **Day 1 · Session 3 · Module 2 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** learn that "connecting a repo" and "registering a cluster" are just **labeled Kubernetes Secrets**, and read the cluster-registration trust chain end to end.

---

## 1. The install-time checklist (settle these before any `helm install`)

| Decision | This course's choice | Production consideration |
|---|---|---|
| **Namespace** | `argocd` | a dedicated namespace so RBAC, network policy, and quotas scope to the platform |
| **Ingress / exposure** | NodePort `30443` → `https://localhost:8443` | production uses an Ingress/LoadBalancer with a real DNS name |
| **TLS** | Argo CD's self-signed cert; `server.insecure=false` | production terminates TLS with a CA-signed certificate |
| **DNS** | `localhost` (lab shortcut) | production assigns a stable hostname so certs and SSO redirects are stable |
| **Initial access** | local `admin`, password injected as a bcrypt hash at install | production disables routine admin use and logs in via SSO/OIDC (Session 6) |

> **Read the last row against the rule below:** the admin password is a *payload*, so it is injected at install, not committed. The rest of Argo CD's config is a *pointer/shape*, so it lives in Git.

---

## 2. Everything Argo CD "knows" is a labeled Secret

"Connecting a repo" and "registering a cluster" are not feature toggles — they are three shapes of a **labeled Kubernetes Secret in the `argocd` namespace**. The **label** decides what the Secret *is*.

**(1) A repository Secret** — authenticates to *one* private repository:

```yaml
metadata:
  labels:
    argocd.argoproj.io/secret-type: repository   # <-- this label makes it a "repository"
stringData:
  url: http://lab-gitea:3000/course/storefront-gitops.git
  username: student
  password: <PASSWORD>                            # <-- injected in Lab 2; never committed
```

**(2) A credential template (`repo-creds`)** — one entry authenticates *every* repo under a URL prefix:

```yaml
metadata:
  labels:
    argocd.argoproj.io/secret-type: repo-creds    # <-- "repo-creds", not "repository"
stringData:
  url: http://lab-gitea:3000/course/              # <-- a PREFIX: matches every repo under /course/
  username: student
  password: <PASSWORD>
```

The only differences from a repository Secret: the **label** and that `url` is a **prefix**. That turns "credentials for this repo" into "credentials for this whole organization."

**(3) A cluster Secret** — reaches and *limits* Argo CD on a workload cluster. This is where least privilege lives:

```yaml
metadata:
  labels:
    argocd.argoproj.io/secret-type: cluster       # <-- this label makes it a "cluster"
stringData:
  name: workload
  server: https://k3d-workload-server-0:6443      # <-- reachable by CONTAINER NAME, not localhost
  namespaces: storefront-dev,storefront-staging,storefront-prod,team-a,platform-system
  clusterResources: "false"                        # <-- forbid cluster-scoped WRITES
  config: |
    { "bearerToken": "<TOKEN>", "tlsClientConfig": { "insecure": false, "caData": "<CA_DATA>" } }
```

Two fields are the entire least-privilege story on the Argo CD side: **`namespaces:`** lists exactly the namespaces Argo CD may operate in (anywhere else is refused), and **`clusterResources: "false"`** forbids cluster-scoped writes (ClusterRoles, CRDs, namespaces).

---

## 3. The cluster-registration trust chain

```text
 cluster Secret (mgmt)  --bearer token-->  network (k3d-workload-server-0:6443)
       |                                            |
       | namespaces: [ ... ]                        v
       | clusterResources: false          ServiceAccount argocd-manager  (argocd-access)
                                                    |
                                          RoleBinding (in each allowed namespace)
                                                    |
                                          Role argocd-deployer  (write only named kinds)
```

**Read it left to right:** the **cluster Secret** carries a **bearer token** that authenticates Argo CD as one specific **ServiceAccount** (`argocd-manager`, in a dedicated namespace `argocd-access`) on the workload cluster. That ServiceAccount gets power *only* through **per-namespace RoleBindings** to a **Role** (`argocd-deployer`) that permits writing only a named list of kinds. There is **no ClusterRoleBinding granting write** anywhere.

**Two independent brakes** limit the blast radius: the cluster Secret's `namespaces:` + `clusterResources: false` limit what Argo CD *asks*; the per-namespace Roles limit what the cluster *lets* it do. Both point at the same small set of namespaces.

> **The network path is by name.** Argo CD reaches the workload API server as `k3d-workload-server-0:6443` over the shared container network — *not* `localhost`. That detail is the whole reason `argocd cluster add` fails here (Module 3's misconception).

---

## 4. Commit the pointer, never the payload

GitOps says "everything in Git." Security says "no secrets in Git." Both are satisfied by splitting a secret into two parts:

| Belongs in **Git** (declarative) | Injected **at apply time** (never committed) |
|---|---|
| The *reference*: "this app needs a Secret named `db-password`" | The *value* of that Secret |
| The cluster/repository Secret **shape** as a `*.template.yaml` with `<TOKEN>`, `<PASSWORD>` placeholders | The real token / password / CA data |
| AppProjects, Applications, Helm values | Argo CD's admin password (bcrypt hash at install) |
| A cluster's ID / logical name (a pointer) | The bearer token used with it |

**The rule fits in five words: commit the pointer, never the payload.** This is why every course Secret is a `*.template.yaml` with placeholders — Lab 2 renders the real values from per-VM credential files that are never committed.

> **A committed secret is exposed retroactively and permanently.** Git history is the point of Git — rotating a leaked secret does not un-commit it (Session 6 revisits this).

---

## 5. Hands-on: see the onboarding objects and the wide-open default

**▶ Do this now — list the labeled onboarding Secrets by type.**

```bash
kubectl --context k3d-mgmt -n argocd get secret \
  -o jsonpath='{range .items[*]}{.metadata.labels.argocd\.argoproj\.io/secret-type}{"  "}{.metadata.name}{"\n"}{end}' \
  | grep -v '^  '
```

**Expected** (rows present depend on how far setup has progressed; `in-cluster` is always there):

```text
cluster     in-cluster
cluster     cluster-workload
repo-creds  course-repo-creds
repository  repo-storefront-gitops
```

**🔍 Notice:** the first column is the `secret-type` **label** — `cluster`, `repo-creds`, or `repository`. That label is the *only* thing that makes a plain Secret into an onboarding object. `in-cluster` is the management cluster's own entry (labels-only, no credentials — Argo CD uses its in-cluster ServiceAccount there).

> **In a fresh, pre-Lab-2 environment** you may see only `in-cluster` (plus the repo entries) and **no** `cluster-workload` row — because *registering the workload cluster is what Lab 2 does*. Watching that row appear is the point of Lab 2's Settings → Clusters check.

---

## 6. Quick Check

**S3-QC2 — Commit to Git, or inject?** For each: **A.** an AppProject restricting which repos an app team may deploy from · **B.** the bearer token for the workload cluster · **C.** a cluster's logical ID/name · **D.** the Gitea password.

<details>
<summary>Show answer</summary>

**A — Git** (declarative policy, no secret). **B — injected** (a payload; lives in Git only as `<TOKEN>`). **C — Git** (a *pointer*, not a credential — "which cluster" is fine to commit). **D — injected** (a payload). Every item sorts by one test: *pointer or payload?* C is the trap — a cluster ID *feels* sensitive but only identifies a cluster; the token used *with* it is the payload.
</details>

---

## 7. Key takeaways

- "Connecting a repo" / "registering a cluster" = creating a **labeled Secret**; the **label** (`repository` / `repo-creds` / `cluster`) decides what it is.
- The registration **trust chain**: cluster Secret → bearer token → `argocd-manager` ServiceAccount → per-namespace RoleBindings → a narrow Role. **No ClusterRoleBinding granting write.**
- **Commit the pointer, never the payload** — every course Secret is a template with placeholders.

**→ Next:** [03 — Least privilege and change detection](03-least-privilege-and-change-detection.md)
