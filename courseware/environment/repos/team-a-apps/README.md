# team-a-apps

The tenant repository for **team-a**, who onboard on Day 2 (Lab 5). It contains:

- `guestbook/` — a small podinfo Deployment and Service that team-a is allowed to
  deploy into the `team-a` namespace.
- `attempts/` — two manifests used to *feel* each guardrail layer:
  - `cluster-scoped/clusterrole.yaml` — a cluster-scoped `ClusterRole`, blocked by
    the team-a **AppProject** (cluster resources not permitted).
  - `network-policy/netpol.yaml` — a `NetworkPolicy`, which the AppProject *allows*
    but the workload cluster's **Kubernetes RBAC** forbids for team-a's
    least-privilege ServiceAccount.

Lab 5 uses these to compare an Argo CD authorization failure with a Kubernetes
authorization failure.
