# Lab 4 · Module 1 — Environment and the Preview Rhythm

> **Day 2 · Lab 4 · Module 1 of 4 · ~10 minutes**
> **Goal:** confirm the clean starting slate, see the cluster labels the factory selects on, and install the habit that keeps the whole lab safe: **preview → count → apply.**

---

## 1. Environment check — confirm `CP-lab-04`

Your starting state is checkpoint **`CP-lab-04`**: Day 1's hand-made storefront Applications and `hello-reconcile` are removed on purpose (the `cp-lab-04` Git tag preserves the answers). The `storefront` and `platform` AppProjects exist, the workload cluster is registered and labelled, and the ApplicationSet skeleton plus the App-of-Apps files are staged in Git.

**▶ Do this now:**

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-04 --verify-only --local
```

**Expected output** *(representative):*

```text
==> Verification for CP-lab-04
  PASS  Application hello-reconcile absent
  PASS  Application storefront-dev absent
  PASS  AppProject storefront present
  PASS  AppProject platform present
  PASS  Secret cluster-workload present
  PASS  workload SA argocd-manager present

PASS CP-lab-04 is in the expected state.
```

If any row says **FAIL**, run `reset-lab.sh CP-lab-04 --local` (no `--verify-only`).

**▶ Do this now — confirm the starting picture.** The Applications list should be **empty of any `storefront` Application** and have no `platform-root` yet — a clean slate you are about to fill with a factory.

![Applications list empty of storefront apps at the start of Lab 4 (v3.5.2)](../../assets/screenshots/day-2/lab-04-01-env-check.png)

*Figure SS-L4-01 — At `CP-lab-04`: no `storefront-*` Applications, no `platform-root`. The `storefront` and `platform` projects already exist (Settings → Projects).*

<!-- CAPTURE-SPEC: SS-L4-01 — Applications list, environment check. State: CP-lab-04. Highlight: clean list, no storefront-*/platform-root tiles. Argo CD v3.5.2. -->

---

## 2. The data the factory selects on: cluster labels

The ApplicationSet you complete in Exercise 1 chooses clusters by label.

**▶ Do this now — read the registered clusters' labels:**

```bash
kubectl --context k3d-mgmt -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -o custom-columns='NAME:.metadata.name,ROLE:.metadata.labels.cluster-role,REGION:.metadata.labels.region'
```

**Expected output** *(representative):*

```text
NAME               ROLE         REGION
cluster-workload   workload     lab
in-cluster         management   <none>
```

**🔍 Notice:** the **workload** cluster is labelled `cluster-role=workload`; the **management** cluster is `cluster-role=management`. A cluster generator with `matchLabels: {cluster-role: workload}` matches **exactly one** cluster — the workload one — and deliberately excludes the management cluster. That is how you keep application workloads off the control plane.

![Cluster detail for the workload cluster showing its labels (v3.5.2)](../../assets/screenshots/day-2/lab-04-02-cluster-labels.png)

*Figure SS-L4-02 — The `workload` cluster's labels `cluster-role: workload` and `region: lab` — the data the cluster generator selects on.*

<!-- CAPTURE-SPEC: SS-L4-02 — Cluster detail, labels. State: CP-lab-04, Settings → Clusters → workload. Highlight: cluster-role=workload, region=lab. Argo CD v3.5.2. -->

---

## 3. Preview is a command, not a leap of faith

The dependable, portable way to preview an ApplicationSet is the CLI:

```bash
argocd appset generate <path-to-appset-file> -o wide
```

`argocd appset generate` renders the Applications the ApplicationSet *would* produce and prints them. **It creates nothing.** It reads the Git-files generator's repository and the live cluster labels server-side, so its output is the real fan-out. Add `-o yaml` to inspect a full generated Application, or `-o wide` for a one-line-per-app table.

*(There is a server-side equivalent, `argocd appset create --dry-run -o yaml <file>`, and an **Alpha** Preview tab in the UI. Treat those as "you can also"; the CLI is the required path here because it is stable and scriptable. Note: `appset generate` also validates that the referenced `project` exists — if you see "project storefront does not exist," you are not at `CP-lab-04`.)*

> **The rhythm, stated once:** for every ApplicationSet change today — completing it, broadening a selector, breaking a key — you will **(1) preview** with `argocd appset generate`, **(2) count and name** what it would produce, then **(3) apply** only if the count and names match your prediction. If preview surprises you, you caught a mistake for free.

**→ Next:** [02 — Build and protect the factory](02-build-and-protect-the-factory.md)
