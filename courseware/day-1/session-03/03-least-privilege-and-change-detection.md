# Session 3 · Module 3 — Least Privilege and Change Detection

> **Day 1 · Session 3 · Module 3 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** understand that least privilege for Argo CD means least *write* privilege, why webhooks vs polling is a question about network *direction*, and that a fresh install ships one wide-open door.

---

## 1. Least privilege = least *write* privilege

On the workload cluster, the `argocd-manager` ServiceAccount is granted power only through a narrow Role. Here is its surprising, audit-critical shape:

```yaml
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]        # READ everything (required — cannot be narrowed)
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["create", "update", "patch", "delete"]   # WRITE only named kinds (this is where you cut)
  # ... services, configmaps, jobs, hpas, networkpolicies, resourcequotas, limitranges ...
```

> **Least privilege for Argo CD means least *write* privilege.** You can genuinely restrict what Argo CD may **create, update, patch, and delete** — down to named namespaces and kinds. You *cannot* meaningfully restrict what it may **read**: `get`, `list`, and `watch` at broad scope are **required** for Argo CD to compute live state and health at all. A read-restricted Argo CD is a blind Argo CD. Say this to your security reviewer *before* they say it to you: **"read-everywhere is a requirement, not an oversight; the control is on writes."** That sentence is the difference between the `cluster-admin` finding from Module 1 and a clean audit.

> **Where `resource.respectRBAC: normal` fits.** Because the credential can *read* broadly but the cluster still has resource types the ServiceAccount may not list, `resource.respectRBAC: normal` tells the controller to **honor those RBAC boundaries quietly** — skip tracking what it may not list — instead of spamming permission errors. (`normal` respects RBAC without an extra pre-flight check per resource; a stricter mode adds that check at a performance cost.)

---

## 2. A fresh install ships one wide-open door

A brand-new Argo CD is not empty of policy — it ships **one** AppProject named `default`, created automatically. It is **maximally permissive**: an Application that names no project lands in `default`, and `default` allows everything.

**▶ Do this now — look at the wide-open door.**

```bash
kubectl --context k3d-mgmt -n argocd get appproject default \
  -o jsonpath='sourceRepos={.spec.sourceRepos}{"\n"}destinations={.spec.destinations}{"\n"}'
```

**Expected output:**

```text
sourceRepos=["*"]
destinations=[{"namespace":"*","server":"*"}]
```

**🔍 Notice:** `"*"` everywhere — any repo, any cluster, any namespace. A fresh install *has* a project and *no boundary*: a door with a lock painted on it. The documented first hardening step is to **empty** those allow-lists (`sourceRepos: []`, `destinations: []`), which removes all permissions from `default` without deleting the project. You will *do* this in Lab 5; here, only notice that "we have a project" is not the same as "we have a guardrail."

---

## 3. Webhook vs polling — a question about network *direction*

```text
POLLING  — Argo CD reaches OUT on a timer  (OUTBOUND, usually already allowed)
   Argo CD --"anything new?"--> Git   every timeout.reconciliation (60s here)

WEBHOOK  — Git reaches IN on an event  (INBOUND, needs a hole in the firewall)
   Git --"push happened!"--> firewall --> Argo CD endpoint
   (requires public/peered ingress + TLS cert + shared secret)
```

- **The trade is about direction, not speed.** Polling is an **outbound** connection from the management cluster to Git — almost always allowed. A webhook is an **inbound** connection into the management cluster — typically a firewall change, a reachable ingress, a TLS certificate, and a shared secret. Many locked-down platforms deliberately **keep polling and shorten the interval** instead.
- **Shortening the poll interval is not free.** A shorter timer multiplies repo-server work across *every* application. This course runs `60s` (`timeout.reconciliation`); dropping everyone to `10s` could overwhelm the repo-server (Session 7).
- **The latency you trade is concrete.** With `60s` polling, a push is noticed within a minute; a webhook is near-instant. Whether that minute matters is a real decision — not an automatic "webhooks win."

---

## 4. Quick Checks

**S3-QC3 — Which direction must the network allow?** Your Git server is on-prem; your management cluster is in a private subnet that freely makes **outbound** connections but blocks almost all **inbound** ones. Which change-detection approach costs less, and what would the other require?

<details>
<summary>Show answer</summary>

**Polling costs less** — it is outbound (already allowed), giving change detection with zero firewall work; you tune `timeout.reconciliation` to trade latency for repo-server load. A **webhook** would require **inbound** access into the private subnet: a firewall change, a reachable ingress, a TLS certificate, and a shared secret — four pieces of work versus zero. The trade is about *direction*, not speed.
</details>

**S3-QC4 — Predict what an out-of-scope Application experiences.** A cluster Secret registers a cluster with `namespaces: [a, b]` and `clusterResources: "false"`. A colleague creates an Application whose destination is namespace **`c`**. What happens?

<details>
<summary>Show answer</summary>

**Argo CD refuses to operate in `c`.** The cluster Secret scopes it to `a` and `b`, so a destination of `c` is outside what the credential may manage — it surfaces an error rather than silently succeeding. A *second, independent* brake would also stop it even if scope allowed `c`: there is **no RoleBinding** for `argocd-manager` in `c` on the workload cluster, so Kubernetes RBAC returns `403 Forbidden` on any write. Two brakes, same direction — "least privilege" produces a specific, predictable *refusal*. (You will see the exact error shapes — and the difference between an Argo CD-level denial and a Kubernetes `403` — in Lab 2 and Lab 5.)
</details>

---

## 5. Common misconceptions

- **"`argocd cluster add` is the production way to register a cluster."** It is the *convenient* way and often the *wrong* one. By default it binds a `argocd-manager` ServiceAccount to **`cluster-admin`** (the Module 1 audit finding) *and* copies the current kubeconfig's server URL — here a `localhost` address Argo CD's pods **cannot reach** (they need `k3d-workload-server-0:6443`). It fails twice over. The declarative cluster Secret fixes both.
- **"Kubernetes Secrets are encrypted, so committing one is fine."** No — a Secret is **base64-encoded, not encrypted** (`base64 -d` reverses it in one command). Its value is protected by cluster RBAC and optional etcd encryption-at-rest, *not* by being a `Secret`. Commit its real value and you have published it in plaintext-equivalent form, permanently, into history.
- **"HA means more replicas of everything, including Redis state."** Two errors: HA is **per component** (the controller shards clusters — one replica is normal even in HA), and **Redis holds no durable state** — HA Redis just survives a node failure without a cold start. Argo CD's real state is its Kubernetes objects; Redis is disposable.

---

## 6. Key takeaways

- **Least privilege for Argo CD means least *write* privilege.** Read-everywhere is a *requirement*; the control is on writes. Say it before your auditor does.
- **Webhooks vs polling is about which *direction* the connection goes**, not which is faster.
- A fresh install's **`default` AppProject is wide open** — "having a project" ≠ "having a guardrail."
- **Commit the pointer, never the payload — and a Kubernetes Secret is base64-encoded, not encrypted.**

---

## 7. Transition — what's next

You have the production shape: install decisions, onboarding objects, the least-privilege trust chain, and the network trade behind change detection. What you have not done is *build* any of it.

That is **Lab 2**. You will connect the private `storefront-gitops` repository (its repository Secret), apply the exact least-privilege RBAC on the workload cluster, register that cluster by building its cluster Secret (the `workload` row that finally appears under Settings → Clusters), and create a first AppProject and Application declaratively — then confirm Argo CD can render and compare the target.

**→ Next:** [Lab 2 — Configure the Platform and Register a Target](../lab-02-configure-platform-and-register-target.md)
