# Lab 4 · Module 1 — Starting State and the Preview Habit

> **Day 2 · Lab 4 · Module 1 of 4 · 10 minutes**
> **Run every command in your VM terminal**, after `source ~/argo-lab-env.sh`.
> **← Back to:** [Day 2 map](../README.md) · [Lab 4](README.md)

---

## Module TL;DR

- **What this is.** Confirm the starting slate, see the labels the factory selects on, and install the one habit that keeps the rest of the lab safe.
- **Why it matters.** One edit to a factory can change many Applications at once. Preview is the cheapest safety check that exists.
- **What to remember.** *Preview, count, apply.* And: **zero is a valid result, not an error message.**
- **The most common mistake.** Applying a factory change without counting what it would produce.

---

## 1. Why this module exists

Nothing is created yet. Before you build anything, you need three things: proof that your starting point is what the lab assumes, an understanding of the labels that decide *where* generated Applications go, and one safety habit.

---

## 2. The exact starting state

Your starting state is checkpoint **`CP-lab-04`**. Here is precisely what that means:

| Present | Absent, on purpose |
|---|---|
| the `storefront` and `platform` AppProjects | Day 1's hand-written `storefront-dev` Application |
| the registered, labelled workload cluster | Day 1's `hello-reconcile` Application |
| the repository connections and credentials | any ApplicationSet |
| the ApplicationSet **skeleton** staged in Git | the App-of-Apps root, not yet applied |
| the App-of-Apps files staged in Git | any `team-a` project |

> **Why Day 1's Applications are gone.** If the hand-made storefront Applications were still here, the factory's new Applications would clash with them and you would not be able to tell which one did what. The clean slate is deliberate.

**▶ Do this now — verify the checkpoint.** This changes nothing:

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-04 --verify-only --local
```

**Expected output:**

```text
==> Verification for CP-lab-04
  PASS  Application hello-reconcile absent
  PASS  Application storefront-dev absent
  PASS  Application team-a-guestbook absent
  PASS  AppProject team-a absent
  PASS  AppProject storefront present
  PASS  AppProject platform present
  PASS  Secret in-cluster present
  PASS  Secret repo-storefront-gitops present
  PASS  Secret cluster-workload present
  PASS  Secret course-repo-creds present
  PASS  Repository and cluster Secrets are exactly: in-cluster, repo-storefront-gitops, cluster-workload, course-repo-creds
  PASS  workload namespace storefront-prod present
  PASS  workload SA argocd-manager present
  PASS  workload RoleBinding argocd-deployer (storefront-prod) present

PASS CP-lab-04 is in the expected state.
```

**If any row says FAIL**, restore the checkpoint:

```bash
reset-lab.sh CP-lab-04 --local
```

> **Notice that some rows assert an *absence*.** A `PASS` on `Application hello-reconcile absent` means the thing is correctly missing. That is a passing result, not a problem.

> **New since Day 1: `course-repo-creds`.** This is a **credential template**. It holds one username and password for *every* repository whose address starts with `http://lab-gitea:3000/course/`. Today's factory reads more than one course repository, so one shared key is simpler than one Secret per repository.

**▶ Confirm the starting picture in the user interface.** Open **Applications**. The page should be **completely empty**.

![Applications page showing "No applications available to you just yet" at the start of Lab 4 (v3.5.2)](../../assets/screenshots/day-2/lab-04-01-env-check.png)

*Figure SS-L4-01 — At `CP-lab-04` the Applications page reads "No applications available to you just yet." There are no `storefront-*` Applications and no `platform-root`. The `storefront` and `platform` projects do already exist, under **Settings → Projects**.*

<!-- CAPTURE-SPEC: SS-L4-01 — Applications list, environment check. State: CP-lab-04. Highlight: empty list. Argo CD v3.5.2. -->

### Mini TL;DR — section 2

- `CP-lab-04` keeps the plumbing and removes Day 1's Applications.
- A `PASS` on an "absent" row means correctly missing.
- Verify before you build; it takes ten seconds and saves an hour.

---

## 3. The data the factory selects on: cluster labels

A **label** is a `key: value` tag on a Kubernetes object. The factory you build next picks clusters by their labels, so these labels decide *where* the generated Applications will run.

> **Think of luggage tags at an airport.** The sorting belt does not read the bag; it reads the tag. Tag a bag wrongly and it flies to the wrong city.

**▶ Do this now — read the registered clusters' labels:**

```bash
kubectl --context k3d-mgmt -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -o custom-columns='NAME:.metadata.name,ROLE:.metadata.labels.cluster-role,REGION:.metadata.labels.region'
```

**Expected output** — verified on the course environment:

```text
NAME               ROLE         REGION
cluster-workload   workload     lab
in-cluster         management   <none>
```

**🔍 Notice the two roles.** The workload cluster is labelled `cluster-role=workload`. The management cluster is `cluster-role=management`.

A cluster generator selecting on `matchLabels: {cluster-role: workload}` therefore matches **exactly one** cluster — and deliberately **excludes the management cluster**. That is how you keep application workloads off the control plane.

**▶ Predict, and hold the answer for Exercise 2:** if you deleted that one line from the selector, how many clusters would match?

**▶ Optional — see the same labels in the user interface:** **Settings → Clusters**, then click the `workload` row.

![Cluster detail page for the workload cluster showing its labels (v3.5.2)](../../assets/screenshots/day-2/lab-04-02-cluster-labels.png)

*Figure SS-L4-02 — The `workload` cluster's detail page. Under **GENERAL**, **LABELS** reads `cluster-role=workload region=lab` — the data the cluster generator selects on. **APPLICATIONS** reads `0`, because nothing has been generated yet.*

<!-- CAPTURE-SPEC: SS-L4-02 — Cluster detail, labels. State: CP-lab-04. Highlight: cluster-role=workload, region=lab. Argo CD v3.5.2. -->

### Mini TL;DR — section 3

- Labels on the cluster Secrets decide placement.
- `cluster-role: workload` matches one cluster and excludes the management cluster.
- A selector is only as good as the labels it reads.

---

## 4. Preview is a command, not a leap of faith

Before you create anything with an ApplicationSet, you ask Argo CD to **show you the list of Applications it would create**. Nothing is created.

> **Think of print preview before sending 300 letters to the printer.** If the preview shows 3,000 pages, you stop — and it cost you nothing.

```bash
argocd appset generate <path-to-appset-file> -o wide
```

`argocd appset generate` renders the Applications the ApplicationSet *would* produce and prints them. **It creates nothing.** It reads the Git-files generator's repository and the live cluster labels server-side, so its output is the real fan-out.

| Flag | Gives you |
|---|---|
| `-o wide` | one line per Application — best for counting and reading names |
| `-o yaml` | the full generated Applications — best for checking one field in detail |

**▶ Do this now — preview the untouched skeleton.** It is not finished yet, and that is the point:

```bash
cd ~/platform-config
argocd appset generate applicationsets/storefront.yaml -o wide
```

**Expected output** — verified on the course environment:

```text
NAME  CLUSTER  NAMESPACE  PROJECT  STATUS  HEALTH  SYNCPOLICY  CONDITIONS  REPO  PATH  TARGET
```

**🔍 That is a header row and nothing else. The command succeeded and exited `0`.**

> **This is the most important thing in the module: zero is a valid generator output, not an error message.** Nothing warns you. Nothing turns red. You have to **count**.
>
> The skeleton's cluster selector is still the placeholder `cluster-role: "TODO"`, which matches no cluster. No clusters times three environments is zero.

### The rhythm, stated once

For **every** factory change in this lab — completing it, widening a selector, breaking a key — you will:

1. **Preview** with `argocd appset generate`.
2. **Count and name** what it would produce.
3. **Apply** only if the count and the names match your prediction.

**If the preview surprises you, you have caught a mistake for free.**

### When a preview fails

`argocd appset generate` prints a **large single-line JSON blob to standard error** and exits with code **20** when generation fails. The useful sentence is at the front, buried in Go internals.

**Cut it to the first line. This works identically on Ubuntu and macOS:**

```bash
argocd appset generate applicationsets/storefront.yaml -o wide 2>&1 | sed 's/\\n.*//'
```

You will need this in Exercise 3.

### Mini TL;DR — section 4

- `argocd appset generate` shows what a factory would create, and creates nothing.
- **Zero output is a result you must notice by counting**, not an error.
- A failed generate exits **20**; `sed 's/\\n.*//'` makes its message readable.

---

## ✅ Key Takeaways from this module

- **Day 2 starts clean on purpose** — the plumbing stays, Day 1's Applications go.
- **Labels decide placement.** `cluster-role: workload` keeps workloads off the management cluster.
- **`argocd appset generate` creates nothing**, and is safe to run at any time.
- **Preview → count → apply.** Only apply when both the number and the names match what you predicted.
- **Zero is a valid result.** Nothing will warn you.

---

## Cleanup

**Nothing to clean up.** Every command in this module was read-only.

---

## Final module TL;DR

- **What this is.** Starting state confirmed, placement labels read, preview habit installed.
- **Why it matters.** Everything that follows is safe only because you check before you apply.
- **What to remember.** Preview, count, apply — and zero counts as a surprise.
- **The most common mistake.** Reading the preview without counting it.

**→ Next:** [02 — Build the factory, and break it once](02-build-and-protect-the-factory.md)
