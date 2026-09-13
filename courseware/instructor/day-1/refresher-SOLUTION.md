# Instructor Solution — Kubernetes + Helm Refresher (Day 1, Session 0)

> **Instructor-only.** Do not distribute to participants. Answers the **🏋 Challenge** tasks in the three refresher modules. Every command and output below was executed against the course's local sandbox (`k3d-mgmt` / `k3d-workload`, Argo CD `v3.5.2`, k3s `v1.35.8+k3s1`) at checkpoint `CP-baseline`. Suffixes, IPs, and ages will differ per environment; the shapes shown are what participants should see.

---

## Module 01 — Clusters, the control plane, and k3d

### Challenge 1 — Prove the two clusters are independent

**Task:** run one command per cluster showing `kube-system` Pods and confirm the Pod names differ.

**Solution:**

```bash
kubectl --context k3d-mgmt -n kube-system get pods
kubectl --context k3d-workload -n kube-system get pods
```

**What to look for / expected shape:** both clusters run the same *kinds* of system Pods (CoreDNS, `local-path-provisioner`, `metrics-server`), but the random suffixes on the Pod names differ between the two lists, e.g. `coredns-b496cc7f7-hjxws` on `k3d-mgmt` vs a different suffix on `k3d-workload`.

**Teaching point:** identical software, **separate state**. Two clusters that look alike are still two independent systems — exactly why `--context` matters. If a participant sees the *same* Pod names on both, they likely ran the same context twice; have them re-check the `--context` flag.

### Challenge 2 — Read a node's details

**Task:** show a node's full description and find the container runtime and internal IP.

**Solution:**

```bash
kubectl --context k3d-mgmt describe node k3d-mgmt-server-0 | grep -E 'Container Runtime Version|InternalIP'
```

**Expected output (values vary):**

```text
  InternalIP:  172.20.0.3
  Container Runtime Version:  containerd://2.2.7-k3s1
```

**Teaching point:** the runtime is **containerd** (not Docker-inside — Docker only runs the *node container*; inside it, k3s uses containerd to run Pods). The `InternalIP` is on the Docker network k3d created, which is why the clusters can be reached from the VM but are isolated from the outside world.

---

## Module 02 — Namespaces, Deployments, and Pods

### Challenge 1 — Scale by hand and watch Kubernetes react

**Task:** scale the Deployment to 2, re-list Pods, then set it back to 1. Explain why Argo CD did not stop you and whether it stays changed.

**Solution:**

```bash
kubectl --context k3d-mgmt -n hello scale deployment/hello-reconcile --replicas=2
kubectl --context k3d-mgmt -n hello get pods
kubectl --context k3d-mgmt -n hello scale deployment/hello-reconcile --replicas=1
```

**Expected:** two Pods appear, **both sharing the same ReplicaSet prefix** (e.g. `hello-reconcile-5b66f8d98c-77dp9` and `hello-reconcile-5b66f8d98c-txvsm`) — because scaling changes the *count* on the existing ReplicaSet, not the template, so no new ReplicaSet is created. After scaling back, one Pod terminates and you return to a single Pod.

**Answers to the bonus questions:**
- **Why didn't Argo CD stop you?** Argo CD does not block edits to the live cluster — anyone with cluster access can still run `kubectl`. What Argo CD does is *notice*: this manual change makes the app **OutOfSync** (live replicas ≠ Git's `replicaCount: 1`).
- **Would it stay changed?** `hello-reconcile` uses **manual** sync with **no self-heal**, so Argo CD will flag the drift but not revert it on its own. It would stay at 2 until someone Syncs (which restores Git's value of 1) — *or*, as here, until you manually scale back to 1, at which point live matches Git again and the app returns to Synced. (In Lab 3, self-heal is turned on and Argo CD reverts drift automatically. That contrast is the lesson.)

**Cleanup note for instructors:** scaling back to 1 restores the baseline. If a participant leaves it at 2, `reset-lab.sh` also returns the environment to `CP-baseline`.

### Challenge 2 — Find a Pod's node and restart count

**Solution:**

```bash
kubectl --context k3d-mgmt -n hello get pod -o wide
```

**Expected output (abridged):**

```text
NAME                               READY   STATUS    RESTARTS   AGE   IP           NODE                ...
hello-reconcile-5b66f8d98c-77dp9   1/1     Running   0          52m   10.42.0.xx   k3d-mgmt-server-0   ...
```

**Answers:** the Pod runs on node **`k3d-mgmt-server-0`** (the only node in this lab cluster), and `RESTARTS` is **0** on a healthy baseline. A non-zero restart count is worth noticing — it means the container has crashed and been restarted at least once (something the capstone exploits).

---

## Module 03 — ConfigMaps, Services, and Helm

### Challenge 1 — Predict then verify the rendered Service

**Task:** render only the Service template; predict its port and selector; confirm against the live Service.

**Solution:**

```bash
helm template hello ./chart --show-only templates/service.yaml
```

**Expected output:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-reconcile
  labels:
    app.kubernetes.io/name: hello-reconcile
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: hello-reconcile
  ports:
    - name: http
      port: 9898
      targetPort: http
```

**Prediction that should match:** port **9898**, selector **`app.kubernetes.io/name: hello-reconcile`**. Cross-check with the live Service:

```bash
kubectl --context k3d-mgmt -n hello get svc hello-reconcile -o jsonpath='{.spec.ports[0].port} {.spec.selector}{"\n"}'
# 9898 {"app.kubernetes.io/name":"hello-reconcile"}
```

**Teaching point:** the *rendered* chart and the *live* object agree because Argo CD deployed exactly this rendered YAML. That equivalence — "what Helm renders is what runs" — is the foundation for reading diffs in Argo CD later.

### Challenge 2 — Render with a color change and spot every changed line

**Solution:**

```bash
diff <(helm template hello ./chart) <(helm template hello ./chart --set color="#ff0000")
```

**Expected output:**

```text
14c14
<   PODINFO_UI_COLOR: "#326ce5"
---
>   PODINFO_UI_COLOR: "#ff0000"
```

**Answers:** exactly **one** line changes — `PODINFO_UI_COLOR` inside the **ConfigMap**. The Deployment, Service, and every other rendered object are byte-for-byte identical.

**Teaching point:** a single value maps to a single, predictable line of rendered YAML. This is *why* Argo CD's diff view is trustworthy: a one-line intent in Git becomes a one-line difference in the cluster. It also foreshadows a Day-1 subtlety — changing the ConfigMap alone does **not** restart the Pod automatically; Lab 1 shows how the message actually reaches the running app.

---

## Timing and facilitation notes

- **Total:** 30–45 minutes. If time is tight, Module 03 Section 3 (Helm rendering) is the non-negotiable part — it underpins Session 4. Modules 01–02 can be skimmed by a strong cohort.
- **Common stumbles:** (1) forgetting `--context` and running against the wrong cluster; (2) the browser step failing because port 9898 is not forwarded through the SSH tunnel — have them add `-L 9898:localhost:9898`; (3) running `helm template` from the wrong directory — the chart is at `hello-reconcile/chart`.
- **Reset:** `reset-lab.sh` returns everything to `CP-baseline` if any hands-on step left drift behind.
