# Session 3 · Module 1 — Install Model and High Availability

> **Day 1 · Session 3 · Module 1 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** decide which Argo CD install model fits a platform team, understand HA as a per-component question, and resolve the "who deploys the deployer?" puzzle.

---

## 1. Why this matters: the `cluster-admin` audit finding

Picture a security review, three months after your team put Argo CD into production. The reviewer finds that the credential Argo CD uses to deploy to production is bound to **`cluster-admin`** — the Kubernetes role that can do *anything* to *any* resource in *any* namespace.

They ask one question: *"If someone compromised the Argo CD management cluster, what could they do to production?"* The honest answer is **everything** — delete every namespace, read every Secret, install a backdoor. That is the blast radius Session 1 warned about (the red management cluster), now on an audit finding.

How did it get that way? Almost certainly because someone ran the friendly onboarding command `argocd cluster add`, which **creates a `cluster-admin` ServiceAccount by default.** The convenient path and the audit-failing path were the same path. This session is about *not* being in that room. Three decisions decide whether you pass the review: **install model**, **how much HA**, and **how little power** Argo CD gets (Module 3).

---

## 2. Who deploys the deployer?

Argo CD's pitch is that **everything is deployed from Git, continuously**. So what deploys *Argo CD*? Git cannot deploy itself onto an empty cluster.

> **You install Argo CD imperatively exactly once. After that, Argo CD manages itself from Git like everything else.**

"Imperatively" = you run a command that does the install now (a `helm install`). "Declaratively" = you write the desired state in Git and let a controller converge. Argo CD's own config starts as that one imperative install; from then on, every change is a **commit**. Picture a timeline: **one imperative step at the far left** (bootstrap `helm install`), then **an unbroken chain of commits** to the right.

> **One honest caveat.** A self-managing Argo CD can sync a change that breaks its own controller — sawing off the branch it sits on. That argues for *staged, careful* self-management (test upgrades on a non-production Argo CD first), not against it (Session 7).

> **What this course does.** So a broken commit during the Capstone can never brick the classroom, this course does **not** fully self-manage Argo CD. A wrapper script `apply-argocd-config` runs `helm upgrade --install` and stands in for "the platform pipeline that manages Argo CD." You get the production *pattern* without the production *foot-gun*.

---

## 3. The install decision: two independent choices

Argo CD's install choice is really **two** choices on a grid.

| | **Standard (non-HA)** — one replica per component | **High availability (HA)** — redundancy per component |
|---|---|---|
| **Multi-tenant** (API server + UI + SSO + RBAC) | Many teams share one Argo CD; one pod each. Fine for labs/small platforms. **← this course** | Many teams share one Argo CD; no single pod failure takes it down. Production target. |
| **Core** (controller only; CLI + Git) | One team, automation-only, no UI. Lean. | One team, automation-only, made resilient. Rare but valid. |

**Multi-tenant vs Core is a question about *who needs to see*.** Core drops the API server, UI, SSO, and RBAC — perfect when a *single* team drives everything through the CLI and Git. The moment *application teams* need to answer "is my app deployed?" themselves, you need the multi-tenant UI and per-team RBAC. This course models a platform team serving many app teams, so **multi-tenant is right, and the reason is self-service, not features.** (Core is a legitimate, secure choice — not the "lite" version.)

**HA is not one switch — it is per component, because each fails differently:**

| Component | Stateless? | How HA scales it | If it is down |
|---|---|---|---|
| API server | yes | more replicas behind a load balancer | can't see/click, but **reconciliation keeps running** |
| repo-server | yes | more replicas for rendering throughput | nothing renders; cached apps look fine until re-render |
| application controller | (stateful identity) | **shards clusters** across replicas | **nothing reconciles at all** |
| Redis | genuinely stateful HA | replicated set with failover | cache cold-starts under load |

This course runs the **top-left cell** (multi-tenant, non-HA) on your VM; the instructor demonstrates the HA shape on a separate three-node cluster. You run the simple thing; you *watch* the resilient thing.

---

## 4. See how many components you run

**▶ Do this now — count your (non-HA) components.**

```bash
kubectl --context k3d-mgmt -n argocd get pods
```

**Expected:** exactly **six** pods — one of each component (server, repo-server, application-controller, applicationset-controller, redis, notifications-controller). That is the standard install. HA changes *how many* of each run, not *what* they do.

---

## 5. Hands-on: see what HA actually adds (read-only)

This changes **nothing** — `helm template` only *renders* YAML; it never contacts a cluster. It is the safe way to inspect what a chart *would* create (and it is exactly how Argo CD's repo-server works).

**▶ Do this now — render non-HA and count objects** (on the student VM the chart is at `/opt/course/charts/`):

```bash
helm template argocd /opt/course/charts/argo-cd-10.8.4.tgz -n argocd \
  -f platform-config/argocd/values.yaml | grep -cE '^kind:'
```

**▶ Do this now — render an HA overlay and count again. Predict first:** a *few* extra objects, or *dozens*?

```bash
cat > /tmp/ha-values.yaml <<'EOF'
redis-ha:
  enabled: true
server:
  replicas: 2
repoServer:
  replicas: 2
applicationSet:
  replicas: 2
EOF
helm template argocd /opt/course/charts/argo-cd-10.8.4.tgz -n argocd \
  -f /tmp/ha-values.yaml | grep -cE '^kind:'
```

**Representative result** *(exact numbers depend on the values file — confirm on your VM):* non-HA ≈ **49** objects, HA ≈ **74** — roughly **two dozen extra**. The additions are the `redis-ha` StatefulSet and its HAProxy Service, extra Roles/RoleBindings/ServiceAccounts/ConfigMaps, a one-shot config-init **Job**, and **HorizontalPodAutoscaler** objects.

**🔍 Notice:** HA is not "one bigger thing" — it is *many small pieces of redundancy*, exactly the per-component picture from Section 3. Clean up: `rm /tmp/ha-values.yaml`.

---

## 6. Quick Check

**S3-QC1 — Choose the install type.** A platform team runs **one** Argo CD that **twelve** app teams use; each must see their own apps' status without a ticket; it must survive the loss of any node. Pick (a) multi-tenant or Core, (b) standard or HA.

<details>
<summary>Show answer</summary>

**(a) Multi-tenant** — twelve teams needing self-service visibility is exactly what Core (no UI, no per-team RBAC) cannot serve; the deciding factor is *who needs to see*. **(b) HA** — "survive the loss of any node" is the requirement HA exists to meet (replicated Redis, multiple API/repo-server replicas across nodes via anti-affinity, controller sharding for many clusters). The two choices are independent (top-right cell of the grid).
</details>

---

## 7. Key takeaways

- **Argo CD is installed imperatively exactly once; after that it is commits all the way down.**
- **Multi-tenant vs Core is about who needs to *see*; HA is answered per component, not by one switch.**
- HA adds *many small pieces of redundancy* (replicated Redis, extra stateless replicas, HPAs) — not one bigger thing.

**→ Next:** [02 — Onboarding repositories and clusters](02-onboarding-repos-and-clusters.md)
