# Refresher 01 — Clusters, the Control Plane, and k3d

> **Day 1 · Session 0 · Module 1 of 3 · ~10 minutes · hands-on**
> **Goal:** be certain what a Kubernetes *cluster* is, what the *control plane* does, and how you point `kubectl` at the right one of your two clusters.

---

## 1. What a Kubernetes cluster actually is

A **Kubernetes cluster** is one complete Kubernetes installation. It has two halves:

- **The control plane** — the "brain." It stores what *should* be running and constantly works to make reality match. You talk to it through the **API server**.
- **The worker nodes** — the "muscle." These are the machines that actually run your containers, packaged as **Pods** (the smallest unit Kubernetes runs; for now, "a Pod ≈ a running container").

> **Analogy — a restaurant.** The **control plane** is the kitchen's head chef: they hold the orders (desired state), watch what is plated, and re-fire anything that is missing or wrong. The **nodes** are the line cooks who actually do the work. You (via `kubectl`) are a waiter handing the head chef a written order — you never cook directly.

You never manage individual containers by hand. You tell the control plane "I want 3 copies of this app running," and the control plane makes it true and *keeps* it true — restarting anything that dies. That "declare the goal, let the control plane converge on it" idea is exactly what Argo CD does one level up, so it is worth feeling again now.

**▶ Do this now — see the control plane's front door.** Run:

```bash
kubectl --context k3d-mgmt cluster-info
```

**Expected output** (addresses/ports may differ slightly):

```text
Kubernetes control plane is running at https://127.0.0.1:6550
CoreDNS is running at https://127.0.0.1:6550/api/v1/namespaces/kube-system/...
Metrics-server is running at https://127.0.0.1:6550/api/v1/namespaces/kube-system/...
```

**🔍 Notice:** the first line — *"Kubernetes control plane is running at..."* — is the **API server's URL**. Every `kubectl` command, and Argo CD itself, talks to a cluster through exactly this address.

---

## 2. Nodes: the machines that run the work

**▶ Do this now — list the nodes of each cluster.**

```bash
kubectl --context k3d-mgmt get nodes
kubectl --context k3d-workload get nodes
```

**Expected output** (two separate one-node clusters):

```text
NAME                STATUS   ROLES           AGE     VERSION
k3d-mgmt-server-0   Ready    control-plane   2d18h   v1.35.8+k3s1

NAME                    STATUS   ROLES           AGE     VERSION
k3d-workload-server-0   Ready    control-plane   2d18h   v1.35.8+k3s1
```

**🔍 Notice three things:**
1. Each cluster has **one** node, and its `ROLES` says `control-plane`. In these small lab clusters the single node runs *both* the control plane and your workloads. Real production clusters separate them across many nodes — the idea is identical, just spread out.
2. `STATUS` is `Ready` — the node is healthy and accepting work. A node that reads `NotReady` is a genuine problem (you may meet one in the capstone).
3. The two node names are **different** (`mgmt` vs `workload`). These are **two separate clusters**, not one. That separation is the entire point of the course's topology.

---

## 3. Where is the control plane? Meet k3s and k3d

If you have used a "full" Kubernetes cluster before, you may expect to see control-plane components (the API server, scheduler, etcd) running as Pods. Let us check.

**▶ Do this now — look at the system namespace.**

```bash
kubectl --context k3d-mgmt -n kube-system get pods
```

**Expected output** (roughly):

```text
NAME                                     READY   STATUS    RESTARTS   AGE
coredns-...                              1/1     Running   0          ...
local-path-provisioner-...               1/1     Running   0          ...
metrics-server-...                       1/1     Running   0          ...
```

**🔍 Notice what is *missing*:** there is no `kube-apiserver` Pod, no `etcd` Pod, no `kube-scheduler` Pod. Where did the control plane go?

This is your first encounter with **k3s** and **k3d**:

- **k3s** is a **lightweight, fully certified Kubernetes distribution** by Rancher/SUSE. Instead of running each control-plane component as a separate process/Pod, k3s **bundles them all into a single small binary**. The API server, scheduler, controller-manager, and datastore run *inside that one process* — which is why they do not appear as Pods. It is still real Kubernetes; the same API answers your commands.
- **k3d** runs each k3s cluster **inside a Docker container**, so a whole cluster is just a container you can create, reset, or delete in seconds.

**▶ Do this now — see the clusters as Docker containers.**

```bash
docker ps --format '{{.Names}}\t{{.Image}}' | grep k3d
```

**Expected output:**

```text
k3d-workload-server-0   rancher/k3s:v1.35.8-k3s1
k3d-mgmt-server-0       rancher/k3s:v1.35.8-k3s1
```

**🔍 Notice:** each of your two "clusters" is literally one Docker container running the `rancher/k3s` image. That is the trick that lets a single VM host the management/workload topology cheaply.

> **Why k3d for this course.** Argo CD's job is to deploy from one cluster to *another*. Faithfully reproducing that normally needs two sets of machines per student. k3d gives every student two real, isolated clusters on one VM, resettable between labs, with a genuine Kubernetes API. Think of it as a **flight simulator**: real controls and physics, but you can reset after a crash in seconds.

---

## 4. Contexts: telling `kubectl` which cluster you mean

You have two clusters. **A context is a saved bundle of "which cluster + which credentials + which default namespace" that `kubectl` points at.** Switching context is how you aim your commands.

**▶ Do this now — list your contexts and see which is active.**

```bash
kubectl config get-contexts -o name
kubectl config current-context
```

**Expected output** includes both course clusters, and shows one as current:

```text
k3d-mgmt
k3d-workload
...
k3d-mgmt
```

(You may see extra contexts from other tools on the VM — ignore them. The two that matter are `k3d-mgmt` and `k3d-workload`.)

**Why this course always writes `--context` explicitly.** You *could* switch the "current" context and drop the flag. We do not, because the most common — and most dangerous — mistake with two clusters is running a command against the wrong one. Naming `--context k3d-mgmt` or `--context k3d-workload` on every command makes that impossible. Get in the habit now; it will save you in Lab 2 and the capstone.

> **Analogy.** A context is the **channel your remote is set to**. Same remote (`kubectl`), same buttons, but "volume up" affects whatever channel you are on. Naming the context every time is like glancing at the channel number before you press a button.

---

## 5. Challenges

**🏋 Challenge 1 — Prove the two clusters are independent.** The `kube-system` namespace exists in both clusters, but the *things running in it* are separate. Run a single command against **each** cluster that shows its `kube-system` Pods, and confirm the Pod names differ between the two. (Hint: you already saw the mgmt one in Section 3.)

**🏋 Challenge 2 — Read a node's details.** Pick one cluster and show the *full* description of its node, then find the line that reports the container runtime and the internal IP address. (Hint: `kubectl --context <ctx> describe node <name>`, then skim for `Container Runtime Version` and `InternalIP`.)

*(Answers are in the instructor solution, not here — try them first.)*

---

## Key takeaways

- A **cluster** = a control plane (the brain that holds desired state and converges on it) + nodes (the muscle that runs Pods).
- **k3s** is real, lightweight Kubernetes with the control plane bundled into one process; **k3d** runs each k3s cluster as a Docker container so you get two clusters cheaply on one VM.
- A **context** tells `kubectl` which cluster to talk to. This course always names it with `--context` so you never hit the wrong cluster.

**→ Next:** [02 — Namespaces, Deployments, and Pods](02-namespaces-deployments-and-pods.md)
