# Kubernetes + Helm Refresher — Overview

> **Day 1 · Session 0 (refresher) · ~30–45 minutes total · hands-on**
> **Do this before Session 1.** It wakes up the Kubernetes and Helm knowledge the course assumes, using *this course's own* environment and sample app so nothing is abstract.

## Why we start here

You were invited to this course because you have touched Kubernetes, Helm, `kubectl`, and Git before. But "have touched" and "remember every detail at 9 a.m. on day one" are different things. Argo CD's whole job is to manage Kubernetes objects (Deployments, ConfigMaps, Services) defined by Helm charts stored in Git. If those building blocks are fuzzy, Argo CD will feel like magic — and you cannot operate magic.

So before we add Argo CD on top, we spend 30–45 minutes re-grounding the layer *underneath* it, entirely hands-on, against the two real clusters already running on your VM. Every command here is one you will reuse all week.

> **This is not a lecture.** Each module is mostly **▶ Do this now** actions with the exact expected output, plus a couple of **🏋 Challenge** tasks. Type the commands yourself — muscle memory is the goal.

## What you will refresh

| Module | You will re-ground... | Uses |
|---|---|---|
| [01 — Clusters, the control plane, and k3d](01-clusters-control-plane-and-k3d.md) | What a Kubernetes cluster *is*, the control plane, nodes, `kubectl` contexts, and how k3d gives you two clusters | ~10 min |
| [02 — Namespaces, Deployments, and Pods](02-namespaces-deployments-and-pods.md) | Namespaces, the Deployment → ReplicaSet → Pod ownership chain, and **viewing the sample app in your browser** | ~12 min |
| [03 — ConfigMaps, Services, and Helm](03-configmaps-services-and-helm.md) | ConfigMaps, Services, and how Helm *renders* a chart into the YAML Kubernetes actually runs | ~12 min |

## One command style used everywhere

Every `kubectl` command in the refresher names its cluster explicitly with `--context`, like this:

```bash
kubectl --context k3d-mgmt get nodes
```

That is on purpose. In this course you juggle **two** clusters, and forgetting which one you are pointing at is the single most common mistake. Naming the context every time makes it impossible to run a command against the wrong cluster by accident. Module 01 explains exactly what a context is.

## Before you begin

**▶ Do this now — confirm you can reach the management cluster.** Run:

```bash
kubectl --context k3d-mgmt get nodes
```

**Expected output** (the `AGE` will differ):

```text
NAME                STATUS   ROLES           AGE     VERSION
k3d-mgmt-server-0   Ready    control-plane   2d18h   v1.35.8+k3s1
```

If you see a node with `STATUS` of `Ready`, you are good to go. If you get an error, check the **student setup guide** or ask your instructor.

**→ Next:** [01 — Clusters, the control plane, and k3d](01-clusters-control-plane-and-k3d.md)
