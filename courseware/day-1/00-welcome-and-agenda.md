# Welcome + Course Agenda — Intermediate Argo CD Operations

> **Day 1 · Session 0 · Read this first · ~10 minutes**
> **Argo CD version this course targets: `v3.5.2`.**
> **What you need open:** nothing yet. Read this, then start the refresher in [`refresher/README.md`](refresher/README.md).

Welcome. Over the next two days you will learn to run **Argo CD** as a real internal deployment platform — the kind a platform team hands to dozens of application teams and then has to keep alive at 2 a.m. This short guide tells you three things: **how the course is organized**, **what the two days look like**, and **what the unusual tool names on your screen (k3d, Gitea, podinfo) actually are and why we chose them.** Nothing here is hard. It just removes every "wait, what is that?" before it can slow you down.

---

## 1. How these guides are organized (please read — it changes how you work)

This course is delivered as many **small Markdown guides** instead of a few huge ones. That is deliberate:

- **Each guide is short** — roughly a screen or two of reading, then you do something. You should never scroll for ten minutes before touching a keyboard.
- **Concept and practice live in the *same* file.** There is no "read the theory here, do the lab over there." When a guide introduces an idea, the very next thing is usually a **Do this now** box that has you run a command or click something in the Argo CD web interface. Learning by reading *and* doing, in the same place, in the same minute.
- **Guides are numbered so you always know the next step.** Follow them in order. Each one ends with a **"→ Next"** pointer.

You will see three kinds of hands-on prompt throughout:

| Prompt | What it means | How long |
|---|---|---|
| **▶ Do this now** | A short, guided action — run a command or click a button — with the exact expected result. Do it before reading on. | 30 s – 2 min |
| **🔍 Notice** | Look at output you just produced and confirm a specific detail. Builds the habit of *reading* what the tools tell you. | 15 – 30 s |
| **🏋 Challenge** | A slightly harder task where you decide *what* to do, not just *how*. Answers are in the instructor solution, not the guide. | 3 – 10 min |

> **Why the small-guide format matters.** Operating Argo CD is a series of small, precise checks — "is it Synced? is it Healthy? which layer failed?" Small guides train that same rhythm: a little input, a concrete result, confirm, move on. It is how you will actually work on call.

---

## 2. The two-day agenda (high level)

The course builds **one working Git → Argo CD → cluster deployment on Day 1**, then **scales and hardens that pattern on Day 2**. Here is the whole arc.

### Day 1 — Understand, configure, and deploy with Argo CD

| # | Session | Focus | ~Time |
|---|---|---|---|
| 0 | **Kubernetes + Helm refresher** | Warm up the muscles: clusters, control plane, namespaces, Deployments, ConfigMaps, Services, Helm — using *this course's* sample app | 30–45 min |
| 1 | GitOps and the Argo CD topology | What Argo CD owns, what it does not, and the management/workload cluster shape | 45 min |
| 2 | Architecture and the Application model | Components, reconciliation, sync status vs health status, ownership | 60 min |
| — | **Lab 1** — Follow an application through reconciliation | Trace one change from Git to a live Pod | 45 min |
| 3 | Production-oriented configuration | Install choices, declarative repos and clusters, least-privilege access | 60 min |
| — | **Lab 2** — Configure the platform and register a target | Onboard a repo, register the workload cluster | 60 min |
| 4 | Helm deployments, sync, and promotion | Rendering, drift, sync policy, waves, promotion through Git | 60 min |
| — | **Lab 3** — Deploy, introduce drift, and recover | Deploy Helm, break it, recover through Git | 60 min |

**End of Day 1:** you have a working Git-to-cluster deployment and a repeatable method for finding failures along that path.

### Day 2 — Scale the pattern and operate it reliably

| # | Session | Focus | ~Time |
|---|---|---|---|
| 5 | ApplicationSets and App-of-Apps | Generate many Applications safely; control the blast radius | 60 min |
| — | **Lab 4** — Build and troubleshoot the patterns | Multi-environment generation and parent/child diagnosis | 75 min |
| 6 | Security, multi-tenancy, and governance | AppProjects, RBAC, SSO, credentials, policy boundaries | 45 min |
| — | **Lab 5** — Enforce platform guardrails | Restrict sources, destinations, actions, deletion | 45 min |
| 7 | Reliability, troubleshooting, and lifecycle | HA, scaling, observability, backup/recovery, upgrades | 75 min |
| — | **Capstone** — Restore the platform | Diagnose and repair a multi-layer failure, then propose a guardrail | 90 min |

**End of Day 2:** you can reason through ApplicationSets and App-of-Apps, enforce platform boundaries, and restore stable service during a realistic incident.

---

## 3. The three tools with the funny names — what they are and why we use them

Your lab environment runs three tools you may not have met. You do **not** need to become an expert in any of them; Argo CD is the star. But you *should* know what each one is and, more importantly, **what problem it solves**, so nothing on your screen is a mystery.

### 3.1 k3d — "how we get two real Kubernetes clusters on one laptop"

**What it is.** **k3d** is a small tool that runs **k3s** clusters inside **Docker** containers. Unpacking that:

- **Kubernetes** is the system that runs your containers across machines. A **Kubernetes cluster** is one complete Kubernetes installation (a control plane plus worker nodes). Normally a cluster means several real or virtual machines — heavy and slow to create.
- **k3s** (the "3" is a play on "k8s") is a **lightweight, fully certified Kubernetes distribution** built by Rancher/SUSE. It packs the whole control plane into a single small binary, so a cluster starts in seconds and sips memory. It is real Kubernetes — the same API, the same `kubectl` — just trimmed for edge, CI, and lab use.
- **k3d** ("k3s in Docker") wraps each k3s node in a Docker container, so you can create, delete, and reset entire clusters with one command.

**The problem it solves.** This course is about the **management-cluster / workload-cluster** topology — Argo CD runs on one cluster and deploys to a *separate* one. Reproducing that faithfully would normally need two sets of machines per student. k3d gives every student **two real, isolated Kubernetes clusters on a single VM**, created in under a minute and resettable between labs. It trades nothing important away: the API your commands hit is genuine Kubernetes.

You already have both clusters. Their names are `k3d-mgmt` (where Argo CD lives) and `k3d-workload` (where apps will run). The refresher's first module has you look at both.

> **Analogy.** k3d is a **flight simulator for Kubernetes**. It is not a toy — the controls, instruments, and physics are the real thing — but you can crash it, reset it, and take off again in seconds, which is exactly what you want while learning.

### 3.2 Gitea — "the Git server that is our single source of truth"

**What it is.** **Gitea** is a **small, self-hosted Git service** — think of it as a private, lightweight GitHub or GitLab that runs entirely on your VM. It stores Git repositories and gives them a web interface for browsing commits, files, and history.

**The problem it solves.** Argo CD is a **GitOps** tool: its entire job is to make a cluster match what is stored in **Git**. So the course *needs* a Git server to point Argo CD at. We could use GitHub, but that would mean external accounts, internet access, rate limits, and no clean way to reset everyone to a known state. Gitea running locally makes the whole course **self-contained, offline-capable, and resettable** — and it hands each student their own copy of the example repositories.

You reach Gitea in a browser at `http://localhost:3000`. It holds five course repositories (you will meet them as you go).

> **Analogy.** If Argo CD is a thermostat that reads a target and holds the room to it, **Gitea is the little dial you set the target on.** Keeping that dial on your own VM means every student's dial starts in the same position, and we can reset it instantly.

### 3.3 podinfo — "the sample app you will actually watch change"

**What it is.** **podinfo** is a **tiny web application** (by Stefan Prodan) built specifically for Kubernetes demos. It does almost nothing on purpose: it shows a **message** and an **accent color**, exposes health and readiness endpoints, and reports which Pod answered you. Its container image is small and starts fast.

**The problem it solves.** To *see* GitOps work, you need an app whose behavior visibly changes when its configuration changes. podinfo is perfect: change one line in Git (`message: "..."`), let Argo CD reconcile, refresh your browser, and the page text changes. That visible cause-and-effect is the whole point. Throughout Day 1 the app is called **`hello-reconcile`** and it *is* podinfo underneath.

> **Analogy.** podinfo is the **dye you put in the water to trace a leak**. The app itself is unimportant; it exists so you can *watch the change travel* from Git, through Argo CD, into the cluster, and onto your screen.

---

## 4. Before you start Day 1

Two quick confirmations, then you begin the refresher.

**▶ Do this now — confirm your two clusters answer.** In a terminal on your VM, run:

```bash
kubectl config get-contexts -o name
```

**Expected:** the list includes both `k3d-mgmt` and `k3d-workload`. (A **context** is just a saved "which cluster + which login" that `kubectl` points at; you pick one with `--context`. The refresher explains this properly.)

**▶ Do this now — confirm Argo CD is up.** Open `https://localhost:8443` in your browser, accept the self-signed-certificate warning, and log in as `admin` (your password is in `~/course/credentials/argocd-admin.txt`). You should see one Application, `hello-reconcile`, marked **Synced** and **Healthy**.

If either check fails, work through your **student setup guide** (`environment/student-setup-guide.md`) or ask your instructor before continuing.

**→ Next:** [`refresher/README.md`](refresher/README.md) — a 30–45 minute hands-on warm-up on Kubernetes and Helm, using this course's own sample app.

---

## 5. High level Agenda

```text
INTERMEDIATE ARGO CD OPERATIONS — 2-DAY AGENDA

DAY 1 — Understand, configure, and deploy
  0. Kubernetes + Helm refresher .................. 30–45 min
  1. GitOps and the Argo CD topology .............. 45 min
  2. Architecture and the Application model ....... 60 min
     Lab 1: Follow an application through reconciliation .. 45 min
  3. Production-oriented configuration ............ 60 min
     Lab 2: Configure the platform and register a target .. 60 min
  4. Helm deployments, sync, and promotion ........ 60 min
     Lab 3: Deploy, introduce drift, and recover ........ 60 min
  → Outcome: a working Git → Argo CD → cluster deployment

DAY 2 — Scale the pattern and operate it reliably
  5. ApplicationSets and App-of-Apps .............. 60 min
     Lab 4: Build and troubleshoot the patterns ......... 75 min
  6. Security, multi-tenancy, and governance ...... 45 min
     Lab 5: Enforce platform guardrails ................. 45 min
  7. Reliability, troubleshooting, and lifecycle .. 75 min
     Capstone: Restore an Argo CD deployment platform ... 90 min
  → Outcome: reason through patterns, enforce boundaries,
    and restore stable service during a real incident

Environment: one VM per student, two real Kubernetes clusters
(k3d: management + workload), Argo CD v3.5.2, Gitea, sample app "podinfo".
```
