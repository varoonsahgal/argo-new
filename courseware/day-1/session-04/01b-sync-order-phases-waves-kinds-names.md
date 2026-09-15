# Session 4 · Module 1.5 — Deploy in the Right Order

> **Day 1 · Session 4 · ~20 minutes · concept + hands-on**
>
> **Goal:** find what is blocking a sync and fix the ordering through Git.
>
> **Practice environment:** Argo CD on `k3d-mgmt`, deploying a separate Application into the `sync-order` namespace.

## 1. What is the point?

A deployment can contain valid YAML and still get stuck. A Job might need configuration that has not been created yet, or an application might start before its database migration finishes.

In Module 1, you saw how Argo CD obtains Kubernetes YAML. Now you will control **what happens first when it applies that YAML**.

You will start with a working practice app, add a Job with a deliberately incorrect order, and fix it. The question to keep asking is:

> **What must be available before this resource can work?**

### How this connects to auto-sync and self-heal

| Feature | Question it answers |
| --- | --- |
| Automated sync | Should changes in Git deploy automatically? |
| Self-heal | Should direct cluster changes trigger automatic correction too? |
| Phases and waves | Once a sync starts, what happens first, and what must finish before continuing? |

This exercise uses **manual sync** so you can observe each operation. Phases and waves work inside the sync, regardless of how it was started.

## 2. The rules you need

**Created does not mean ready.** Kubernetes can create a Job immediately while its task takes another minute to finish. A Deployment can exist while its Pods are still starting.

Argo CD provides two controls for organizing that work:

| Control | Meaning | Example |
| --- | --- | --- |
| **Phase** | A stage of the deployment | Run a migration before applying the app. |
| **Wave** | A numbered group within a phase | Apply configuration in wave `0`, then a dependent Job in wave `1`. |

### Phases: before, during, after

| Phase | What happens |
| --- | --- |
| `PreSync` | Hooks run before the main deployment and must succeed. |
| `Sync` | Normal application resources are applied. |
| `PostSync` | Hooks run after the main deployment succeeds and its required health checks pass. |

A **hook** is a resource, commonly a Job, assigned to one of these stages using an annotation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
```

### Waves: numbered groups with a waiting boundary

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

- Lower wave numbers go first **within the same phase**.
- Normal resources have phase `Sync`; an omitted wave defaults to `0`.
- An earlier wave can block later waves while resources are unhealthy or unfinished. A Job must complete; a ConfigMap has no running process to wait for.

The full ordering rule is **phase → wave → kind → name**. Kind and name break ties within a wave. Do not rely on alphabetical names to make one resource become ready before another starts. [Argo CD phases and waves](https://argo-cd.readthedocs.io/en/release-3.5/user-guide/sync-waves/)

> **Example:** a `PostSync` Job in wave `-10` still runs after a normal Deployment in wave `0`. Phase is checked first.

## 3. Start with a working practice app

**Purpose:** establish a healthy baseline before introducing the ordering mistake.

Use your configured lab terminal, your existing `hello-reconcile` checkout, and the supplied course files. The Argo CD CLI should already be logged in. `lab-gitea` must resolve from this terminal.

### A. Add the practice files

These steps assume a first run: no existing `sync-order-lab` Application or `sync-order` namespace. A previous run can leave the ConfigMap present and hide the intended failure. If repeating the exercise, use the cleanup commands at the end first.

```bash
cd ~/hello-reconcile
git pull --ff-only
mkdir -p sync-order-lab
cp ~/course/lab-files/session-04/sync-order-lab/*.yaml sync-order-lab/
git add sync-order-lab
git commit -m "Add sync-order-lab practice app"
git push
```

If prompted, use the same Gitea credentials as Lab 1: username `student` and the password supplied in `~/course/credentials/gitea-student.txt`.

For a repeat run, also remove any previous `09-warm-cache.yaml` and `10-cache-settings.yaml` practice files before committing this baseline. Do not remove unrelated work.

### B. Create and sync the Application

```bash
argocd app create sync-order-lab \
  --repo http://lab-gitea:3000/course/hello-reconcile.git \
  --path sync-order-lab \
  --revision main \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace sync-order \
  --sync-option CreateNamespace=true

argocd app sync sync-order-lab
```

**Same repository, separate Application:** `hello-reconcile` reads `chart/`. This Application reads the plain YAML in `sync-order-lab/` and deploys it into `sync-order`. No automated sync policy is enabled.

Watch for the three stages:

| Stage | What to notice |
| --- | --- |
| `PreSync` | The `db-migrate` hook completes first. |
| `Sync` | Configuration and web resources are applied in their waves. |
| `PostSync` | The `smoke-test` hook runs after the main resources are ready. |

Check the result:

```bash
argocd app get sync-order-lab
```

**Checkpoint:** the Application should be `Synced` and `Healthy`, with a successful operation. Resolve a baseline failure before continuing.

## 4. Introduce the mistake—and follow the waiting chain

### A. Add a Job and its configuration

```bash
cd ~/hello-reconcile
cp ~/course/lab-files/session-04/teammate-change/*.yaml sync-order-lab/
git add sync-order-lab
git commit -m "Add cache warm-up with incorrect ordering"
git push
```

Read the two new files:

```bash
cat sync-order-lab/09-warm-cache.yaml
cat sync-order-lab/10-cache-settings.yaml
```

Find these details:

| Resource | Wave | What it needs |
| --- | --- | --- |
| Job `warm-cache` | `1` | Loads environment variables from ConfigMap `cache-settings`. |
| ConfigMap `cache-settings` | `2` | Must wait until Argo CD can advance past wave `1`. |

In the Job's container configuration, this reference establishes the dependency:

```yaml
envFrom:
  - configMapRef:
      name: cache-settings
```

**Predict:** can the Job finish before its required ConfigMap exists? Can Argo CD reach wave `2` before the Job finishes?

### B. Run the sync

```bash
argocd app get sync-order-lab --refresh
argocd app sync sync-order-lab --timeout 40
```

The CLI stops waiting after 40 seconds. **That timeout does not cancel the operation running in Argo CD.**

### C. Ask three questions

**1. What is Argo CD waiting for?**

```bash
argocd app get sync-order-lab --show-operation
```

Look for an operation still `Running` and a message naming `warm-cache`, such as:

```text
waiting for healthy state of batch/Job/warm-cache
```

**2. Why can the Job not finish?**

```bash
kubectl --context k3d-mgmt -n sync-order get pods
```

Look for the `warm-cache` Pod with status `CreateContainerConfigError`.

**3. Which configuration is missing?**

```bash
kubectl --context k3d-mgmt -n sync-order describe pods -l job-name=warm-cache
```

In **Events**, look for a message such as:

```text
Error: configmap "cache-settings" not found
```

Exact output and Pod names vary. These are the observations to find, not a verbatim transcript.

### Explain the blockage

**The Job waits for the ConfigMap. Argo CD waits for the Job before creating the ConfigMap.** This circular wait is a deadlock.

Argo CD follows the wave numbers you supplied; it does not infer the dependency and move the ConfigMap earlier. With no deadline ending the operation and no external change creating the ConfigMap, it keeps waiting.

## 5. Fix the order through Git

### A. Stop the stuck operation

```bash
argocd app terminate-op sync-order-lab
```

The operation was started against the earlier revision. Stop it so you can start a new sync with the corrected configuration. The ordinary `warm-cache` Job should remain available to recover when its configuration appears.

### B. Move the prerequisite earlier

Open `sync-order-lab/10-cache-settings.yaml` and change its wave from `"2"` to `"0"`:

```yaml
metadata:
  name: cache-settings
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

Keep the rest of the file unchanged. Leave the Job in wave `1`.

| Before | After |
| --- | --- |
| Wave 1: Job waits for missing configuration | Wave 0: ConfigMap is created |
| Wave 2: ConfigMap cannot be reached | Wave 1: Job can start and complete |

### C. Commit and sync the fix

```bash
git add sync-order-lab/10-cache-settings.yaml
git commit -m "Move cache-settings before warm-cache"
git push
argocd app get sync-order-lab --refresh
argocd app sync sync-order-lab
```

If Argo CD says an operation is still in progress, wait for termination to finish and retry the sync.

### D. Verify recovery

```bash
kubectl --context k3d-mgmt -n sync-order logs job/warm-cache
argocd app get sync-order-lab
```

Expected Job log:

```text
warming cache for web
cache warm
```

**Success:** the Job completes, the sync succeeds, and the Application returns to `Synced` and `Healthy`.

Once the ConfigMap exists, Kubernetes can retry starting the waiting container. You corrected the prerequisite rather than manually restarting the workload.

### Explain what you learned

| Question | Answer |
| --- | --- |
| Why could the Job not finish? | Its required ConfigMap did not exist. |
| Why could Argo CD not create that ConfigMap? | It was in a later wave blocked by the unfinished Job. |
| Why did the fix work? | The prerequisite was moved before its dependent resource. |

> **Keep this troubleshooting habit:** read what Argo CD is waiting for, inspect what that resource needs, then check where the prerequisite is scheduled.

### Clean up

Remove only the practice Application and namespace:

```bash
argocd app delete sync-order-lab --yes
kubectl --context k3d-mgmt delete namespace sync-order --ignore-not-found
```

The practice files can remain in Git. They are outside the `chart/` path used by `hello-reconcile`.

**Next:** [Module 2 — Sync ordering and drift](02-sync-ordering-and-drift.md).
