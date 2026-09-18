# Session 1 · Module 2 — Topology and Ownership

> **Day 1 · Session 1 · Module 2 of 3 · ~15 minutes · concept + hands-on**
> **Goal:** understand the two-cluster shape you will operate, where the CI/CD boundary sits, and who owns what — then see it on your own clusters.

---

## 1. Two clusters, on purpose

```text
   CI pipeline ---- writes a commit ----> [ Git repo: lab-gitea ]
                                                  ^
                                                  | reads (pull)
                            +---------------------------------------+
                            |  MANAGEMENT CLUSTER  (k3d-mgmt)        |
                            |  runs Argo CD                          |   <-- most sensitive cluster you own
                            +---------------------------------------+
                                                  |
                                                  | applies changes (Argo CD holds the credentials)
                                                  v
                            +---------------------------------------+
                            |  WORKLOAD CLUSTER  (k3d-workload)      |
                            |  runs your applications                |
                            +---------------------------------------+
```

**Notice there is no arrow from CI into any cluster.** That is the entire idea. CI's reach ends at the Git repository. Argo CD, running on the **management cluster**, *pulls* the desired state out of Git and then *applies* it to the **workload cluster**. The clusters reach out; nothing reaches in with cluster credentials except Argo CD itself.

Three things to hold onto:
1. There are **two clusters on purpose.** Argo CD lives on the *management* cluster; your apps live on a *separate registered workload* cluster. This mirrors real production, where the deployment platform is isolated from the things it deploys.
2. The **only thing that ever enters Git is a commit** — from CI, from an engineer, from anywhere. Git is the meeting point.
3. **Argo CD holds the workload cluster's credentials**, not CI. The management cluster can change *every* cluster it manages, so its blast radius is the union of all of them. Treat it as the most security-sensitive cluster you own. (Sessions 3, 6, and 7 exist partly to protect it.)

**How the lab maps to production** (`RKE2` = Rancher Kubernetes Engine 2, the production distribution this course is modeled on):

| In your lab | Stands in for, in production |
|---|---|
| `k3d-mgmt` | A Rancher-managed RKE2 **management** cluster running Argo CD |
| `k3d-workload` | A registered RKE2 **downstream workload** cluster |
| `lab-gitea` | Your organization's Git service (GitHub, GitLab, Bitbucket, self-hosted) |

> **Honest lab detail for Lab 1.** To let you learn the reconciliation loop *before* cluster registration exists, the first sample app (`hello-reconcile`) is pointed at the *management* cluster itself. That is a teaching shortcut, not a production pattern — Lab 2 registers the real workload cluster, and Lab 3 deploys to it.

---

## 2. See the topology on your own machine

**▶ Do this now — confirm both clusters exist and are separate.**

```bash
kubectl --context k3d-mgmt get nodes
kubectl --context k3d-workload get nodes
```

**Expected:** two clusters, each with one `Ready` node whose name differs (`k3d-mgmt-server-0` vs `k3d-workload-server-0`). Two separate systems — exactly the management/workload split from the diagram.

**▶ Do this now — see where Argo CD reads its target from.** Ask the live `hello-reconcile` Application which repo, revision, path, and destination it points at:

```bash
kubectl --context k3d-mgmt -n argocd get application hello-reconcile \
  -o jsonpath='repoURL={.spec.source.repoURL}{"\n"}targetRevision={.spec.source.targetRevision}{"\n"}path={.spec.source.path}{"\n"}server={.spec.destination.server}{"\n"}namespace={.spec.destination.namespace}{"\n"}project={.spec.project}{"\n"}'
```

**Expected output:**

```text
repoURL=http://lab-gitea:3000/course/hello-reconcile.git
targetRevision=main
path=chart
server=https://kubernetes.default.svc
namespace=hello
project=default
```

**🔍 Notice:** every one of those fields points at something *outside* the Application — a Git server, a branch, a folder, a destination cluster. The Application object contains **no app YAML at all**; it is pure addressing. (`https://kubernetes.default.svc` is the in-cluster shortcut meaning "the management cluster itself" — the Lab 1 teaching shortcut.) You will turn this list of arrows into a dependency checklist in Lab 1.

---

## 3. Where CI stops and Argo CD starts

**Argo CD does not deploy your code — it deploys your *repository*.** Argo CD never talks to your CI system, never sees your build logs, and never knows a pipeline ran. The handoff between CI and CD is a **commit**: CI builds and tests an artifact, then writes a new version into a Git repo; Argo CD notices the repo changed.

- **CI's job (Continuous Integration):** build the image, run tests, and — as its final step — write the new image tag into Git. That is where CI stops.
- **Argo CD's job (Continuous Delivery):** read Git, render, compare, synchronize, assess health.

Because the handoff is a commit, **CI needs no cluster credentials at all.** In the older "push" style, CI held cluster-admin access to every environment — the highest-privilege secret in the company living in its most plugin-heavy system. In the GitOps "pull" model, that credential *does not exist in CI*: the cluster reaches out to Git, and CI's blast radius shrinks to "can write to a Git repo." The risk does not vanish, though — it **moves and concentrates** onto the management cluster, which is why that cluster is the sensitive one.

---

## 4. Who owns what (micro-activity)

**🔍 Sort these six duties** into exactly one owner each: **CI**, **Argo CD**, **Platform team**, or **Application team**. Decide before opening the answer.

1. Build a container image from application source.
2. Commit the freshly built image tag into the deployment repository.
3. Bring the cluster back into line with Git after a change.
4. Install, upgrade, and operate Argo CD itself on the management cluster.
5. Register a new workload cluster with least-privilege credentials.
6. Open a pull request to change an application's version or configuration.

<details>
<summary>Show answer and the rule behind it</summary>

| # | Duty | Owner |
|---|---|---|
| 1 | Build a container image | **CI** |
| 2 | Commit the image tag into the repo | **CI** (its automated final step) |
| 3 | Bring the cluster in line with Git | **Argo CD** |
| 4 | Install/upgrade/operate Argo CD itself | **Platform team** |
| 5 | Register a workload cluster (least privilege) | **Platform team** |
| 6 | Open a PR to change the app | **Application team** |

**The rule:** each owner touches a *different kind of thing*. **CI** touches artifacts and commits (never a cluster). **Argo CD** touches the cluster, but only to make it match Git (never decides *what* the desired state is). The **platform team** owns the machine and its guardrails (Argo CD itself, cluster registration). The **application team** owns the *content* of the desired state (versions, values), expressed as pull requests. If you put #4 or #5 under "Argo CD," remember: Argo CD is the *tool*; a *team* operates and constrains it.
</details>

---

## 5. Key takeaways

- **Two clusters on purpose:** Argo CD on an isolated management cluster, apps on a separate workload cluster.
- **Nobody pushes to the cluster.** Everybody commits to Git; the cluster pulls and catches up.
- **An Application is an address, not an artifact** — pure arrows pointing at external things.
- **The management cluster can change every cluster it manages** — the most sensitive cluster you own.

**→ Next:** [03 — The reconciliation loop](03-reconciliation-loop.md)
