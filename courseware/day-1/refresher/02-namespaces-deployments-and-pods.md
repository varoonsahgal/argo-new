# Refresher 02 — Namespaces, Deployments, and Pods

> **Day 1 · Session 0 · Module 2 of 3 · ~12 minutes · hands-on**
> **Goal:** re-ground the objects Argo CD spends all day managing — Namespaces, Deployments, ReplicaSets, and Pods — and **see the sample app answer you in a browser.**

You will use the course's sample app, **`hello-reconcile`** (which is **podinfo** underneath — the tiny demo web app introduced in the welcome guide). It is already running on the management cluster in a namespace called `hello`.

---

## 1. Namespaces: folders for cluster objects

A **namespace** is a way to divide one cluster into named groups of objects — like folders on a disk. Two apps can each have a `web` Deployment without colliding, as long as they live in different namespaces. Namespaces are also where access control and quotas attach, which matters a lot once many teams share a cluster (Day 2's whole security session leans on this).

**▶ Do this now — list the namespaces on the management cluster.**

```bash
kubectl --context k3d-mgmt get namespaces
```

**Expected output:**

```text
NAME              STATUS   AGE
argocd            Active   2d18h
default           Active   2d18h
hello             Active   2d16h
kube-node-lease   Active   2d18h
kube-public       Active   2d18h
kube-system       Active   2d18h
```

**🔍 Notice:** `argocd` (where Argo CD itself runs), `hello` (where the sample app runs), and `kube-system` (Kubernetes' own components). Everything you deploy this week lands in a namespace you can name and inspect.

---

## 2. The ownership chain: Deployment → ReplicaSet → Pod

When you ask Kubernetes to run an app, you usually create a **Deployment**. A Deployment does not run containers directly. Instead:

- A **Deployment** says *"keep N healthy copies of this Pod template running, and roll out changes safely."*
- It creates a **ReplicaSet**, whose one job is *"make sure exactly N Pods matching this template exist."*
- The ReplicaSet creates the **Pods** — the actual running containers.

> **Analogy — a franchise.** The **Deployment** is corporate HQ ("there must always be 3 open stores, and here is the new store blueprint"). Each **ReplicaSet** is a specific blueprint version and counts the stores built from it. The **Pods** are the individual stores serving customers. When you update the blueprint, HQ opens stores from the *new* ReplicaSet and closes the old ones — that is a rolling update.

**▶ Do this now — see all three layers at once.**

```bash
kubectl --context k3d-mgmt -n hello get deploy,rs,pod
```

**Expected output** (your suffixes will differ; you may see extra ReplicaSets scaled to 0 from earlier rollouts):

```text
NAME                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-reconcile   1/1     1            1           6h

NAME                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/hello-reconcile-5b66f8d98c   1         1         1       6h
replicaset.apps/hello-reconcile-67fc76f88b   0         0         0       1h

NAME                                   READY   STATUS    RESTARTS   AGE
pod/hello-reconcile-5b66f8d98c-77dp9   1/1     Running   0          52m
```

**🔍 Notice the naming tells the story:** the Pod name (`hello-reconcile-5b66f8d98c-77dp9`) starts with the ReplicaSet name (`hello-reconcile-5b66f8d98c`), which starts with the Deployment name (`hello-reconcile`). The chain of ownership is written right into the names. Any ReplicaSet showing `0` is a *previous* version, kept around so a rollback is instant.

**▶ Do this now — confirm ownership explicitly.** Ask the Pod who created it:

```bash
kubectl --context k3d-mgmt -n hello get pod -l app.kubernetes.io/name=hello-reconcile -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}{"\n"}'
```

**Expected output:**

```text
ReplicaSet
```

The Pod's owner is a ReplicaSet — not the Deployment directly. That is the middle link of the chain, proven from the live object.

> **Why this matters for Argo CD.** When you change an app in Git, Argo CD updates the **Deployment**, and Kubernetes' own controllers do the rest (new ReplicaSet, new Pods, old ones removed). Argo CD does not micromanage Pods — it sets the desired state of the top-level object and lets Kubernetes converge. Recognizing this chain is how you will read the resource tree in the Argo CD UI later today.

---

## 3. See the sample app answer you — in a browser

A **Service** gives a stable address to a set of Pods (more on Services in Module 3). The `hello-reconcile` Service listens on port **9898**. Right now it is only reachable *inside* the cluster, so we open a temporary tunnel to it with **port-forward**.

**▶ Do this now — forward the app's port to your VM.** Run this and **leave it running** (open a second terminal for the next steps):

```bash
kubectl --context k3d-mgmt -n hello port-forward svc/hello-reconcile 9898:9898
```

**Expected output** (it keeps running):

```text
Forwarding from 127.0.0.1:9898 -> 9898
Forwarding from [::1]:9898 -> 9898
```

**▶ Do this now — ask the app who it is (from a second terminal on the VM):**

```bash
curl -s http://localhost:9898/
```

**Expected output:**

```json
{
  "hostname": "hello-reconcile-5b66f8d98c-77dp9",
  "version": "6.15.0",
  "color": "#326ce5",
  "message": "Hello from Git, revision one",
  ...
}
```

**🔍 Notice two fields that are the heart of the whole course:**
- **`hostname`** is the **Pod name** — the app is telling you *which Pod* answered. Compare it to the Pod name from Section 2; they match.
- **`message`** and **`color`** came from a **ConfigMap**, which came from a **Helm chart**, which came from **Git**. In Lab 1 you will change that one line in Git and watch this exact value change here.

**▶ Do this now — view it in your browser.** The app is served on the VM's port 9898; forward that port to your laptop so your browser can reach it. In a **new** terminal on your laptop, add 9898 to your SSH tunnel:

```bash
ssh -i <your-key>.pem -L 9898:localhost:9898 student@<your-vm-ip>
```

Then open **`http://localhost:9898`** in your browser. You will see the same JSON document, formatted by the browser — the live `message` and `color` the Pod is serving, plus its `hostname`. **That JSON *is* your sample pod, viewed in a browser.** (If your browser already had 9898 forwarded from setup, just open the URL.)

> **Local build machine?** If you are running the environment directly (not through SSH), skip the tunnel — the `port-forward` already binds `localhost:9898`, so open `http://localhost:9898` straight away.

When you are done looking, return to the `port-forward` terminal and press **Ctrl+C** to close the tunnel.

---

## 4. Challenges

**🏋 Challenge 1 — Scale by hand and watch Kubernetes react.** Temporarily set the Deployment to 2 replicas with `kubectl --context k3d-mgmt -n hello scale deployment/hello-reconcile --replicas=2`, then re-list the Pods. How many are there now, and do their names share the same ReplicaSet prefix? (Then set it back to 1.) *Bonus:* why did Argo CD not stop you — and would it stay changed? (You will answer that properly in Lab 1.)

**🏋 Challenge 2 — Find a Pod's node and restart count.** Using a single `kubectl get pod ... -o wide` command, find which node the `hello-reconcile` Pod is running on and how many times it has restarted.

*(Answers are in the instructor solution — try first.)*

---

## Key takeaways

- A **namespace** groups objects like a folder; access control and quotas attach here.
- Running an app is a chain: **Deployment** (keep N healthy, roll out safely) → **ReplicaSet** (maintain N Pods of one version) → **Pod** (the running container). The names encode the chain.
- **port-forward** opens a temporary tunnel to a Service so you can reach it; podinfo's JSON shows the `hostname` (Pod name) and the `message`/`color` that trace all the way back to Git.

**→ Next:** [03 — ConfigMaps, Services, and Helm](03-configmaps-services-and-helm.md)
