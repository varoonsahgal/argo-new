# Intermediate Argo CD Operations

## Student course guide

Use this guide to move through the two-day course in order. Each link opens the next guide or lab module in the course repository. Read each guide from top to bottom and complete its **Do this now** actions before opening the next link.

The course uses Argo CD `v3.5.2`, two k3d Kubernetes clusters, a local Gitea server, and the sample `hello-reconcile` application.

## How sessions and labs fit together

This course has two complementary kinds of learning guides:

### Sessions

This session gives you the model and lets you rehearse each idea with a short observation. You learn the vocabulary, inspect a live object, run a focused command, and answer a quick check before moving on.

### Labs

This lab assumes the preceding session’s concepts. It is not a new lecture; it is where you use those concepts together against a checkpointed environment. You make changes, interpret evidence, and prove the result.

Use the progression below as you work through the course:

| Guide | Your job |
| --- | --- |
| Session | Understand the model and rehearse each idea with a short observation. |
| Lab | Combine the ideas in a longer task: make changes, interpret evidence, and prove the result. |

For Day 1, this means:

- **Session 2** introduces the Argo CD Application model and gives you guided practice observing it.
- **Lab 1** is the first performance task: use that Application to make a Git change, sync it, diagnose the result, and compare desired, rendered, and live state.
- The Application deep dive belongs in Session 2 as guided concept practice; you do not need a separate large “Application deep-dive lab.”

Finish the session modules in order before starting the following lab. When a lab begins, verify its checkpoint first and treat that checkpoint as the starting line.

## Before Day 1

### 1. Prepare your VM

Complete [Lab 0 — Prepare Your VM for Lab 1](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/Lab%200%20%E2%80%94%20Prepare%20Your%20VM%20for%20Lab%201.md).

Lab 0 creates the two clusters, installs the course tools, starts Gitea, and prepares the sample application.

When the guide asks you to download the course materials, use the `varoonsahgal/argo-new` repository on the `main` branch:

```bash
cd ~
git clone --branch main --single-branch https://github.com/varoonsahgal/argo-new.git
cd ~/argo-new
```

If `~/argo-new` already exists, check for local changes before updating it. Do not discard work you need.

Lab 0, Section 5 creates `~/argo-lab-env.sh`. Run this once after creating it, and again in every new terminal:

```bash
source ~/argo-lab-env.sh
```

The file loads the course paths and puts the course commands on your `PATH`. It does not start or recreate the clusters.

Before continuing, confirm that the starting checkpoint passes:

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-01 --verify-only --local
```

Open the local services from the VM desktop:

- [Argo CD](https://localhost:8443)
- [Gitea](http://localhost:3000)

Use the credentials stored under `~/course/credentials/`.

## Day 1 — Understand, configure, and deploy

### 2. Read the welcome and agenda

Start with [Welcome and Course Agenda](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/00-welcome-and-agenda.md).

It explains the course structure, the management and workload clusters, Gitea, k3d, and the sample application.

### 3. Refresh Kubernetes and Helm

Complete [Kubernetes and Helm Refresher](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/refresher/README.md) and its modules in order:

1. [Clusters, the control plane, and k3d](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/refresher/01-clusters-control-plane-and-k3d.md)
2. [Namespaces, Deployments, and Pods](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/refresher/02-namespaces-deployments-and-pods.md)
3. [ConfigMaps, Services, and Helm](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/refresher/03-configmaps-services-and-helm.md)

### 4. Session 1 — GitOps and the Argo CD topology

Open [Session 1](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-01/README.md), then complete:

1. [Why GitOps: a thermostat, not a light switch](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-01/01-why-gitops-thermostat.md)
2. [Topology and ownership](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-01/02-topology-and-ownership.md)
3. [The reconciliation loop](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-01/03-reconciliation-loop.md)

### 5. Session 2 — Argo CD architecture and the Application model

Open [Session 2](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-02/README.md), then complete:

1. [The component team](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-02/01-the-component-team.md)
2. [Four states and the Application](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-02/02-four-states-and-the-application.md)
3. [Sync versus health](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-02/03-sync-vs-health.md)

### 6. Lab 1 — Follow an application through reconciliation

Open [Lab 1](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-01/README.md), then complete:

1. [Setup and dependencies](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-01/01-setup-and-dependencies.md)
2. [Commit a change and sync it](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-01/02-commit-and-sync.md)
3. [Why the app did not change](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-01/03-why-the-app-didnt-change.md)
4. [Three views and wrap-up](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-01/04-three-views-and-wrap-up.md)


> **Why this lab follows Session 2:** This lab assumes the preceding session’s concepts. It is not a new lecture; it is where you use those concepts together against a checkpointed environment.

### 7. Session 3 — Production-oriented configuration

Open [Session 3](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-03/README.md), then complete:

1. [Install model and high availability](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-03/01-install-model-and-ha.md)
2. [Onboarding repositories and clusters](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-03/02-onboarding-repos-and-clusters.md)
3. [Least privilege and change detection](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-03/03-least-privilege-and-change-detection.md)

### 8. Lab 2 — Configure the platform and register a target

Open [Lab 2](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-02/README.md), then complete:

1. [Environment and the address book](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-02/01-environment-and-address-book.md)
2. [Connect the repository and register the cluster](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-02/02-connect-repo-and-register-cluster.md)
3. [Prove least privilege and create the app](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-02/03-prove-least-privilege-and-create-app.md)
4. [Diagnose and wrap up](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-02/04-diagnose-and-wrap-up.md)

Before Session 4, verify the state produced by Lab 2:

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-03 --verify-only --local
```

### 9. Session 4 — Helm deployments, synchronization, and promotion

Open [Session 4](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-04/README.md). Complete all four modules in this order:

1. [Render, not release](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-04/01-render-not-release.md)
2. [The running order](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-04/01b-sync-order-phases-waves-kinds-names.md)
3. [Sync ordering and drift](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-04/02-sync-ordering-and-drift.md)
4. [Promotion and recovery](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-04/03-promotion-and-recovery.md)

The running-order module is an additional Module 1.5. Complete its cleanup before moving on.

### 10. Lab 3 — Deploy, introduce drift, and recover

Open [Lab 3](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-03/README.md), then complete:

1. [Environment and new mechanics](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-03/01-environment-and-mechanics.md)
2. [Deploy and promote](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-03/02-deploy-and-promote.md)
3. [Drift and self-heal](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-03/03-drift-and-self-heal.md)
4. [Break it two ways and recover](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/lab-03/04-break-and-recover.md)

At the end of Day 1, verify the state needed for Day 2:

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-04 --verify-only --local
```

## Day 2 — Scale and operate the platform

### 11. Session 5 — ApplicationSets and App-of-Apps

Open [Session 5](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-05/README.md), then complete:

1. [The factory: ApplicationSets and generators](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-05/01-applicationsets-the-factory.md)
2. [Safety: failing loud and bounding the blast radius](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-05/02-safety-and-controls.md)
3. [App-of-Apps and choosing the pattern](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-05/03-app-of-apps-and-choosing.md)

### 12. Lab 4 — Build and troubleshoot the patterns

Open [Lab 4](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-04/README.md), then complete:

1. [Environment and the preview rhythm](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-04/01-environment-and-preview.md)
2. [Build and protect the factory](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-04/02-build-and-protect-the-factory.md)
3. [App-of-Apps and tracing faults](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-04/03-app-of-apps-and-trace-faults.md)
4. [Pattern showdown and wrap-up](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-04/04-showdown-and-wrap-up.md)

### 13. Session 6 — Security, multi-tenancy, and governance

Open [Session 6](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-06/README.md), then complete:

1. [The three fences](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-06/01-the-three-fences.md)
2. [AppProjects and RBAC, up close](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-06/02-appprojects-and-rbac.md)
3. [SSO, secrets, and governance](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-06/03-sso-secrets-and-governance.md)

### 14. Lab 5 — Enforce platform guardrails

Open [Lab 5](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-05/README.md), then complete:

1. [Environment and the two mechanisms](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-05/01-environment-and-mechanisms.md)
2. [Build the fence and prove the happy path](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-05/02-build-fence-and-happy-path.md)
3. [Bypass attempts](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-05/03-bypass-attempts.md)
4. [Deletion protection and wrap-up](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/lab-05/04-deletion-protection-and-wrap-up.md)

Before Session 7, verify the next checkpoint:

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-lab-05 --verify-only --local
```

### 15. Session 7 — Reliability, troubleshooting, and lifecycle

Open [Session 7](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-07/README.md), then complete:

1. [The six-step method](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-07/01-the-six-step-method.md)
2. [One incident, all six steps](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-07/02-worked-incident.md)
3. [Stability, recovery, and upgrades](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/session-07/03-stability-recovery-upgrades.md)

## Final exercise — Capstone

### 16. Restore an Argo CD deployment platform

Open [Capstone overview](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/capstone/README.md). Work through its modules in this order:

1. [The brief and the mental model](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/capstone/01-brief-and-mental-model.md)
2. [Setup and rules of engagement](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/capstone/02-setup-and-rules.md)
3. [The evidence toolbox](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/capstone/03-evidence-toolbox.md)
4. [P0–P1: brief and triage](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/capstone/04-triage.md)
5. [P2–P4: restore, verify, reflect](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/capstone/05-restore-verify-reflect.md)
6. [Troubleshooting and completion](https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-2/capstone/06-troubleshooting-completion-close.md)

When the incident starts, follow the rules in the capstone. Do not reset the lab after faults have been injected. Record your evidence, repairs, verification results, and reflection.

## Companion reference — Argo CD best practices

Use the [Argo CD Best Practices Field Guide](courseware/reference/argo-cd-best-practices.md) alongside both days and after the course. It connects the session topics to production decisions through 18 practices, embedded diagrams, examples, and seven short exercises.

Consult the relevant practices as each topic comes up. Use the final production-review exercise and ten-question review card after Session 7 or as a follow-up to the capstone. The guide is a reference, not an additional required lab or checkpoint.

## Commands you will reuse

Run this in every new terminal:

```bash
source ~/argo-lab-env.sh
```

Use explicit checkpoint verification before a new lab:

```bash
reset-lab.sh CP-lab-02 --verify-only --local
reset-lab.sh CP-lab-03 --verify-only --local
reset-lab.sh CP-lab-04 --verify-only --local
reset-lab.sh CP-lab-05 --verify-only --local
```

A checkpoint verification inspects the expected starting state. It does not reset your work because of `--verify-only`.

## Course habits

- Read the guide’s purpose and prediction prompt before running a command.
- Check the output before continuing.
- Name the cluster explicitly in `kubectl` commands when the guide does so.
- Treat Git as the durable source of desired state.
- Use the Argo CD UI, CLI, and `kubectl` as three views of the same system.
- Ask which layer failed: desired state, rendering, synchronization, or live health.
- Keep credentials out of Git, screenshots, and chat.

