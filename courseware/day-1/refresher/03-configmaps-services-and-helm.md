# Refresher 03 — ConfigMaps, Services, and Helm

> **Day 1 · Session 0 · Module 3 of 3 · ~12 minutes · hands-on**
> **Goal:** re-ground **ConfigMaps** (app settings), **Services** (stable addresses), and — most importantly — how **Helm renders a chart into the exact YAML Kubernetes runs**. This last idea is the one Argo CD is built on top of.

---

## 1. ConfigMaps: settings kept outside the container image

A **ConfigMap** is a Kubernetes object that stores configuration as key/value pairs, separate from the container image. The same image can behave differently in `dev` and `prod` just by pointing it at a different ConfigMap. Our sample app reads its message and color from one.

**▶ Do this now — read the sample app's ConfigMap.**

```bash
kubectl --context k3d-mgmt -n hello get configmap hello-reconcile -o yaml
```

**Expected output** (trimmed — look at the `data:` block):

```yaml
data:
  PODINFO_UI_COLOR: '#326ce5'
  PODINFO_UI_MESSAGE: Hello from Git, revision one
kind: ConfigMap
metadata:
  annotations:
    argocd.argoproj.io/tracking-id: hello-reconcile:/ConfigMap:hello/hello-reconcile
  ...
```

**🔍 Notice two things:**
1. `PODINFO_UI_MESSAGE` here holds the *exact* text the app showed you in the browser in Module 2. The ConfigMap is where that value lives inside the cluster.
2. There is an annotation `argocd.argoproj.io/tracking-id`. **Argo CD stamped that on.** It is how Argo CD remembers "this object belongs to the `hello-reconcile` Application" — its ownership tag. You did not see that on a hand-made ConfigMap; it is proof this object is *managed by Argo CD*. (Session 2 makes ownership a central topic.)

---

## 2. Services: a stable address in front of moving Pods

Pods come and go — they get new names and new IP addresses on every restart. A **Service** solves that by giving a **fixed name and IP** that automatically routes to whichever Pods currently match its **selector** (a label query). You used the Service in Module 2 when you port-forwarded to `svc/hello-reconcile`.

**▶ Do this now — inspect the Service and its selector.**

```bash
kubectl --context k3d-mgmt -n hello get svc hello-reconcile
kubectl --context k3d-mgmt -n hello get svc hello-reconcile -o jsonpath='{.spec.selector}{"\n"}'
```

**Expected output:**

```text
NAME              TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
hello-reconcile   ClusterIP   10.43.24.35   <none>        9898/TCP   6h

{"app.kubernetes.io/name":"hello-reconcile"}
```

**🔍 Notice:** the Service's `selector` is `app.kubernetes.io/name: hello-reconcile` — the same label the Pods carry (Module 2). That label match is the entire "wiring": the Service does not know Pod names, it just forwards to *anything* wearing that label. Scale the Deployment up and new Pods automatically join; scale down and they leave. The address never changes.

> **Analogy.** A Service is a **restaurant's phone number**. Staff (Pods) change shift constantly, but customers always dial the same number and reach whoever is on duty. The selector is "whoever is wearing the uniform."

---

## 3. Helm: a template engine that renders plain Kubernetes YAML

Here is the idea the rest of the course rests on. **Helm is a templating tool for Kubernetes.** A **Helm chart** is a folder containing:

- **`Chart.yaml`** — the chart's name and version (its ID card).
- **`values.yaml`** — the default settings (the knobs you are meant to turn).
- **`templates/`** — Kubernetes YAML files with blanks (`{{ .Values.something }}`) that get filled in from the values.

You already looked at this chart's files in Module 2's sample app. Let us watch Helm *render* it.

**▶ Do this now — render the chart to plain YAML without deploying anything.**

```bash
cd ~/course/repos/hello-reconcile 2>/dev/null || cd /Users/*/course/repos/hello-reconcile 2>/dev/null || cd .
helm template hello ./chart --show-only templates/configmap.yaml
```

> On the standard student VM the repositories live under `~/course/repos`. The command above changes into the `hello-reconcile` repo first; if you are elsewhere, adjust the path to wherever you cloned or find the chart.

**Expected output:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello-reconcile
  labels:
    app.kubernetes.io/name: hello-reconcile
data:
  PODINFO_UI_MESSAGE: "Hello from Git, revision one"
  PODINFO_UI_COLOR: "#326ce5"
```

**🔍 Notice:** `helm template` did **not** talk to any cluster. It read the chart plus its values and printed the finished Kubernetes YAML — the blanks now filled in. This is called **rendering**.

**▶ Do this now — change a value and re-render.** Override the message on the command line:

```bash
helm template hello ./chart --set message="Refresher test" --show-only templates/configmap.yaml | grep PODINFO_UI_MESSAGE
```

**Expected output:**

```text
  PODINFO_UI_MESSAGE: "Refresher test"
```

**🔍 Notice:** changing one value changed exactly one line of the rendered output. That predictable "values in → YAML out" behavior is why platforms build on Helm.

> **This is the single most important refresher idea for Argo CD.** When Argo CD deploys a Helm app, it runs *this same rendering step* (`helm template`) to produce plain YAML, then applies that YAML to the cluster. **Argo CD does not run `helm install` or `helm upgrade`** and does not track a "Helm release." It renders, compares the rendered YAML to the live cluster, and syncs the difference. Session 4 says this again with emphasis — but you just watched the mechanism with your own eyes.

---

## 4. Why Gitea? Because GitOps needs a home for these charts

Everything you just rendered — the chart, its `values.yaml`, its templates — has to *live* somewhere that Argo CD can read. In GitOps, that somewhere is a **Git repository**, and the Git server hosting it is the platform's **single source of truth**.

This course runs its own small Git server, **Gitea**, on your VM. Gitea is a lightweight self-hosted Git service — a private, minimal GitHub/GitLab. We use it (instead of the real GitHub) so the course is **self-contained** (no external accounts or internet needed), **resettable** (every student starts from an identical set of repositories, and an instructor can reset them instantly), and **safe to break** (you can push mistakes without touching anything real).

**▶ Do this now — see the charts' home in your browser.** Open Gitea at **`http://localhost:3000`**, go to the **`course`** organization, and open the **`hello-reconcile`** repository. Browse to `chart/values.yaml`. That file — the one you just rendered from the command line — is the *desired state* Argo CD reads. In Lab 1 you will edit it here and watch the change flow to the cluster.

> **The full picture now.** Git (in Gitea) holds the chart and values → Helm renders them into Kubernetes YAML → that YAML creates a ConfigMap, a Deployment (→ ReplicaSet → Pods), and a Service → podinfo serves the `message` you can see in a browser. Argo CD's job, starting in Session 1, is to run that whole pipeline **continuously and automatically**, and to notice the moment reality stops matching Git.

---

## 5. Challenges

**🏋 Challenge 1 — Predict then verify the rendered Service.** Without deploying, render *only* the Service template and predict what port it exposes and what selector it uses. Then confirm your prediction against the live Service from Section 2. (Hint: `helm template hello ./chart --show-only templates/service.yaml`.)

**🏋 Challenge 2 — Render with a color change and spot every line that changed.** Render the whole chart twice — once with defaults, once with `--set color="#ff0000"` — and identify *every* line of output that differs. How many lines changed, and in which object(s)? What does that tell you about how tightly a value maps to rendered YAML?

*(Answers are in the instructor solution — try first.)*

---

## Key takeaways

- A **ConfigMap** holds app settings outside the image; Argo CD stamps a `tracking-id` annotation on the objects it owns.
- A **Service** is a stable address that routes to Pods by **label selector**, so Pods can come and go without breaking clients.
- **Helm renders** a chart + values into plain Kubernetes YAML (`helm template`). **Argo CD uses exactly this rendering step** — it does not run `helm install`/`upgrade`.
- **Gitea** hosts the Git repositories that are GitOps's source of truth, kept local so the course is self-contained and resettable.

**You are warmed up.** You have re-grounded clusters, the control plane, k3d, namespaces, the Deployment→ReplicaSet→Pod chain, ConfigMaps, Services, and Helm rendering — all against the same app you will drive with Argo CD next.

**→ Next:** [Session 1 — GitOps and the Argo CD topology](../session-01/README.md)
