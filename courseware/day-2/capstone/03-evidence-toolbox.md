# Capstone · Module 3 — The Evidence Toolbox

> **Day 2 · Capstone · Module 3 of 6 · reference throughout**
> **Goal:** every read-only tool you already know, organized by layer, plus one fully worked triage row.

Every command here is **read-only** — it reads Git, Argo CD, or Kubernetes and changes nothing. Angle brackets like `<app>` need a name. Start every pass at §0.

---

## §0 — The whole picture (start every pass here)

```bash
argocd app list
kubectl --context k3d-mgmt -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project,SYNC:.status.sync.status,HEALTH:.status.health.status,LAST-OP:.status.operationState.phase,CONDITIONS:.status.conditions[*].type'
argocd app get <app>
argocd app get <app> --show-operation
```

The `kubectl` form reads the Application objects straight from the cluster — it keeps working even when the CLI or UI is slow (the Lab 1 "three windows, one story" lesson). `argocd app get <app>` is the densest single screen: source, target revision, both statuses, conditions, resource list; `--show-operation` adds the last sync's details.
**UI:** the Applications page (filter panel on the left); click a tile for its tree, summary, and conditions.

---

## §SRC — Git source, history, rendering (steps 1–2)

Recent history across all repos (`git -C <repo> pull --ff-only` first if you've pushed):

```bash
cd ~/capstone
for repo in storefront-gitops platform-config platform-components team-a-apps; do
  echo "=== ${repo} ==="; git -C "${repo}" log -n 10 --date=relative --format='%h  %ad  %an  %s'
done
```

One commit in detail; does a revision exist on the server; what Argo CD itself sees:

```bash
git -C ~/capstone/<repo> show --stat <sha>
git -C ~/capstone/<repo> show <sha>
git ls-remote http://lab-gitea:3000/course/<repo>.git <revision>
argocd repo list
argocd app manifests <app> --source git
argocd app manifests <app> --source live
```

A second opinion that does not depend on Argo CD — render the chart yourself with the VM's `helm` (same Helm v4.2.1 the repo-server uses). If it renders here but not in Argo CD, the difference is in Argo CD's inputs; if it fails here too, the difference is in the chart/values:

```bash
cd ~/capstone/storefront-gitops
helm template storefront charts/storefront -f envs/<env>/values.yaml > /tmp/render-<env>.yaml && echo "render OK"
```

To render an app's *exact* target revision (not your clone's `main`), use a throwaway worktree:

```bash
git -C ~/capstone/storefront-gitops worktree add /tmp/rev <revision>
helm template storefront /tmp/rev/charts/storefront -f /tmp/rev/envs/<env>/values.yaml > /tmp/render-rev.yaml && echo "render OK"
git -C ~/capstone/storefront-gitops worktree remove /tmp/rev
```

**UI:** Settings → Repositories (connection status); Gitea history at `http://localhost:3000/course/<repo>/commits/branch/main`.

---

## §RUN — comparison, sync results, runtime health (steps 3–4)

```bash
argocd app diff <app>; echo "exit code: $?"   # 0=no diff, 1=real diff, 2=couldn't complete
argocd app history <app>
```

The workload side (on the **workload** cluster):

```bash
kubectl --context k3d-workload -n <ns> get all
kubectl --context k3d-workload -n <ns> describe deploy <deploy>
kubectl --context k3d-workload -n <ns> get events --sort-by=.lastTimestamp | tail -20
kubectl --context k3d-workload -n <ns> logs deploy/<deploy> --tail=30
for ns in storefront-dev storefront-staging storefront-prod platform-system team-a; do
  echo "=== ${ns} ==="; kubectl --context k3d-workload -n "${ns}" get pods
done
```

Does the app answer? (storefront namespaces have a `storefront` Service on 9898):

```bash
kubectl --context k3d-workload -n <ns> port-forward svc/storefront 9898:9898 >/dev/null 2>&1 &
PF_PID=$!; sleep 2; curl -s localhost:9898; echo; kill "${PF_PID}"
```

> **Refresher:** a Deployment is `Healthy` when enough new Pods pass their readiness probe within the progress deadline; a `Progressing` status that never ends is a rollout still waiting. Every live field has one rightful writer (Git via Argo CD, a controller, or a person) — ask which before you call a difference "drift."

**UI:** a resource node's Summary/Events/Logs tabs; the Diff view; History & Rollback (reading only — a rollback is a change, blocked while auto-sync is on).

---

## §CONN — workload cluster connectivity

```bash
argocd cluster list
argocd cluster get workload
kubectl --context k3d-mgmt -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster   # names/ages only, never contents
kubectl --context k3d-workload get nodes                                                       # is the workload API up, with YOUR creds?
kubectl --context k3d-mgmt -n argocd logs statefulset/argocd-application-controller --tail=300 | grep -i "k3d-workload-server-0" | tail -20
```

> **Refresher — 401 vs 403, two credentials.** **401** = "I don't accept your credential." **403** = "I know you, but you may not." Your `kubectl` uses your admin kubeconfig; Argo CD uses the ServiceAccount token in its cluster Secret. Two different identities.

**UI:** Settings → Clusters and the cluster detail panel.

---

## §GEN — generation and ownership

```bash
argocd appset list
kubectl --context k3d-mgmt -n argocd get applicationset storefront \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}: {.message}{"\n"}{end}'
argocd appset generate ~/capstone/platform-config/applicationsets/storefront.yaml -o wide
kubectl --context k3d-mgmt -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,GENERATED-BY:.metadata.ownerReferences[0].name,TRACKED-BY:.metadata.annotations.argocd\.argoproj\.io/tracking-id'
argocd app get platform-root -o tree
```

- `GENERATED-BY` = the ApplicationSet that generated an app (owner references).
- `TRACKED-BY` = the `tracking-id` annotation Argo CD writes on everything it applies; its first part names the Application (or root) that applied the object.
- An Application object with **neither** was applied directly by a person (path C) — Argo CD does not reconcile it from Git.

Ownership is a measurement too — read it twice, a few minutes apart. An owner that changes between readings is evidence.
**UI:** the ApplicationSets view (Alpha — prefer the CLI) and a root's tree.

---

## §POL — the three fences

```bash
argocd proj list
argocd proj get <project>
kubectl --context k3d-mgmt -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,LAST-OP:.status.operationState.phase,MESSAGE:.status.operationState.message'
argocd admin settings rbac can <subject> <action> <resource> <object>   # order: subject action resource object!
for ns in storefront-dev storefront-staging storefront-prod platform-system team-a; do
  printf '%-20s ' "${ns}"
  kubectl --context k3d-workload auth can-i create deployments.apps -n "${ns}" --as=system:serviceaccount:argocd-access:argocd-manager
done
kubectl --context k3d-workload auth can-i create clusterroles.rbac.authorization.k8s.io --as=system:serviceaccount:argocd-access:argocd-manager
kubectl --context k3d-workload -n <ns> get roles,rolebindings
```

Read any denial against Lab 5's three signatures:

| Message contains | Fence | Did a sync start? |
|---|---|---|
| `permission denied` | Fence 1: Argo CD RBAC | No |
| `is not permitted in project` | Fence 2: an AppProject | No |
| `forbidden` + `system:serviceaccount:...` | Fence 3: Kubernetes RBAC | Yes, then failed |

**UI:** Settings → Projects; an Application's sync result panel.

---

## §PLAT — Argo CD's own components (step 5)

The Argo CD UI does not show the health of Argo CD's own pods — read this layer with `kubectl`.

```bash
kubectl --context k3d-mgmt -n argocd get pods
kubectl --context k3d-mgmt -n argocd get deploy,statefulset
kubectl --context k3d-mgmt top pod -n argocd
kubectl --context k3d-mgmt -n argocd get events --sort-by=.lastTimestamp | tail -20
kubectl --context k3d-mgmt -n argocd describe pod <pod>    # read State, Last State (Reason/Exit Code), Restart Count, Events
kubectl --context k3d-mgmt -n argocd logs deploy/argocd-server --tail=50
kubectl --context k3d-mgmt -n argocd logs deploy/argocd-repo-server --tail=50
kubectl --context k3d-mgmt -n argocd logs statefulset/argocd-application-controller --tail=50
kubectl --context k3d-mgmt -n argocd logs <pod> --previous --tail=50   # a crashed container's previous run
```

Metrics direct (controller `:8082`, server `:8083`, repo-server `:8084`):

```bash
kubectl --context k3d-mgmt -n argocd port-forward <deploy-or-statefulset>/<component> <port>:<port> >/dev/null 2>&1 &
PF_PID=$!; sleep 2; curl -s localhost:<port>/metrics | grep -E '^argocd_' | head -30; kill "${PF_PID}"
```

---

## §Worked — the method on an incident that is *not* today's

For Session 7's unreachable-Git incident (chosen because it is *not* a capstone fault — so this spoils nothing):

**One triage row:**

| # | Symptom | Where | Step | Layer | Hypothesis | Planned change |
|---|---|---|---|---|---|---|
| S1 | many apps sharing a repo: sync `Unknown`, `ComparisonError`, "no such host" | `argocd app get …`; conditions panel | 2 | `SRC` | Argo CD can't reach the Git host → nothing renders. If true, workloads are fine (step-4 events quiet) and `argocd repo list` shows the repo failing | restore the host's reachability via the owning team (path A). Verify with `argocd repo list`, then `argocd app get` |

**How it was built:** Symptom uses the tool's own words and lists *every* affected app (shared symptom = evidence). Where-observed names a re-runnable command. Step is the first station that lied. Layer is where the *cause* lives (not always where the symptom showed). Hypothesis is testable (states what else must be true). Planned change names the path and the verification.

**The matching change-log row** re-runs the **same** commands for "evidence before" and "evidence after" — that is step 6: verify with the evidence you diagnosed with.

**→ Next:** [04 — P0–P1: brief and triage](04-triage.md)
