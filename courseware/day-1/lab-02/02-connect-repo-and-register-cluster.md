# Lab 2 · Module 2 — Connect the Repo, Register the Cluster

> **Day 1 · Lab 2 · Module 2 of 4 · ~27 minutes**
> **Goal:** inject a repository credential without ever exposing it (**E1**), then create a least-privilege identity on the workload cluster and register it (**E2**).

> **Ground rule:** the templates showed you the *shapes*. These exercises do **not** hand you the finished commands — you produce them. The separate solution guide has exact answers if your instructor needs them.

> **🗺️ Where this module fits.** This is where you actually build. E1 gives Argo CD a way to **read** your app's Git repository. E2 gives Argo CD a way to **write** to the workload cluster — but only in a few namespaces. After this module, Argo CD holds the keys to both ends of the pipeline: Git on one side, the workload cluster on the other. It tries the Git key straight away; it first uses the cluster key in Module 3, when an Application needs it.

---

## E1 — Connect the private repository

**Difficulty:** Core · **Time:** ~10 minutes · **Objective:** L2.1

> **🧭 What this exercise is for**
> - **In plain words:** the `storefront-gitops` repository is private, so Argo CD needs a username and password to read it. You give Argo CD that password by creating a **repository Secret** — without the password ever appearing on your screen, in your shell history, or in Git.
> - **Think of it like:** giving the delivery driver the key to a locked warehouse. You hand the key over directly. You do not tape it to the front door (Git) or shout it across the street (your terminal).
> - **Connects to:** [Session 3 · Module 2](../session-03/02-onboarding-repos-and-clusters.md) — the repository Secret shape, and "commit the pointer, never the payload."
> - **Big picture:** Argo CD can only deploy what it can *read*. Without this connection there is no desired state, and nothing later in the course works.

**Goal:** turn the repository template into a real Secret by injecting the Gitea password **from the credential file**, apply it, and confirm the connection shows **Successful**. The password must never appear in the template, your shell history, or Git.

**Starter state:** `platform-config` cloned (Module 1). Template at `~/platform-config/repositories/storefront-gitops.secret.template.yaml`. Password at `~/course/credentials/gitea-student.txt`.

**Predict-before-you-verify:** after you apply this Secret, will the connection show Successful *immediately*, or is there a delay? (Hold your answer.)

**Hints (use only if stuck):**
- *Hint 1:* Everything in the template is correct except `<PASSWORD>`. Do not edit the `url`, `username`, or label.
- *Hint 2:* Do not paste or `echo` the password. A substitution tool such as `envsubst` replaces a placeholder with an environment variable's value; load the credential file into that variable so the password stays out of history and Git.
- *Hint 3:* Render the filled-in Secret to standard output and pipe it straight into `kubectl --context k3d-mgmt apply --server-side -f -` so the completed Secret never touches disk. Keep `--server-side`: a plain `kubectl apply` saves a full copy of what you applied, password included, in an annotation (a note stored on the object) called `kubectl.kubernetes.io/last-applied-configuration`. With `--server-side`, no such copy is made.
- *Hint 4:* To verify, use the UI Repositories page and `argocd repo list` — neither reveals the password. To prove no copy was saved, list only the annotation *names* on the Secret (never their values): `kubectl --context k3d-mgmt -n argocd get secret repo-storefront-gitops -o go-template='{{range $k, $v := .metadata.annotations}}{{$k}}{{"\n"}}{{end}}'`. It should print nothing.

**Success criterion:** Settings → Repositories shows `storefront-gitops` with a green **Successful** status; `argocd repo list` shows the same; you did not print or commit the password.

![Argo CD Settings, Repositories showing storefront-gitops Successful (v3.5.2)](../../assets/screenshots/day-1/lab-02-02-repository-connected.png)

*Figure SS-L2-02 — After E1: `storefront-gitops` shows a green **Successful** connection status. It is the only row: no credentials template exists yet.*

<!-- CAPTURE-SPEC: SS-L2-02 — Settings → Repositories after E1. State: repo-storefront-gitops applied, route /settings/repos. Highlight: storefront-gitops row with green Successful status. Fidelity: full page. Argo CD v3.5.2. -->

> **What "Successful" actually means (keep this for the Capstone).** A green status is a *measurement from the last check*, not a permanent guarantee — "the last check reached the repository." Argo CD also **remembers** each repository's result for up to an hour, so the Repositories page can show an old reading. To make it check again, click **Refresh list** on that page, or run `argocd repo list --refresh hard`. A credential that expires next month shows green today and fails the morning it matters. Every status in Argo CD is a reading with a timestamp.

### ✅ What you should take away from E1

- Connecting a repository is **one labeled Secret**. The row on the Repositories page appeared because that Secret now exists.
- The password came from a file, went through a variable, and was piped straight into the cluster. It never landed on screen, on disk, in Git, or (thanks to `--server-side`) in an annotation on the Secret.
- Compare the page with your Module 1 "before" photo: the empty page now has a row — and you made it.

---

## E2 — Register the workload cluster with least privilege

**Difficulty:** Advanced · **Time:** ~17 minutes · **Objective:** L2.2

> **🧭 What this exercise is for**
> - **In plain words:** you create a login for Argo CD on the **workload** cluster. That login may only change things in five namespaces. Then you give Argo CD that login's token by writing a **cluster Secret** on the **management** cluster.
> - **Think of it like:** a hotel key card. The card (token) is made at the hotel (the workload cluster) and opens only certain rooms (namespaces). The guest (Argo CD, living on the management cluster) just carries the card in its wallet (the cluster Secret).
> - **Connects to:** [Session 3 · Module 2](../session-03/02-onboarding-repos-and-clusters.md) — the cluster-registration trust chain; and [Session 3 · Module 3](../session-03/03-least-privilege-and-change-detection.md) — least *write* privilege.
> - **Big picture:** real platforms run Argo CD in one place and deploy to many other clusters. If the key card opened every room, one bad commit could damage the whole workload cluster. Limiting the card limits the damage.

**Words you will meet in this exercise:**

- **ServiceAccount** — a Kubernetes login for a *program* rather than a person. Argo CD will use one called `argocd-manager`.
- **RBAC (Role-Based Access Control)** — Kubernetes' permission system. A **Role** lists allowed actions inside one namespace. A **RoleBinding** gives that Role to an identity, in that namespace only. A **ClusterRoleBinding** would grant permissions across the *whole* cluster — this lab creates none that allow writing.
- **base64** — a way of writing any data as plain text characters. It is *encoding*, not encryption: anyone can decode it.

**Goal:** give Argo CD a scoped identity on the workload cluster, then register the cluster by writing a cluster Secret that carries that identity's token and CA. When you finish, Argo CD lists the workload cluster, scoped to only its allowed namespaces. (Its status will say **Unknown** for now — "Shape of a correct result" explains why.)

**The identity lives on the cluster being *managed*.** When you register a workload cluster, the **ServiceAccount Argo CD authenticates as is created on the workload cluster** — not the management cluster. The management side only stores a *credential for* it (the cluster Secret). The file `~/course/lab-files/lab-02/workload-rbac.yaml` builds that identity **on the workload cluster**: a ServiceAccount `argocd-manager` in namespace `argocd-access`, a token Secret, a `Role argocd-deployer` + RoleBinding in each app namespace, a reduced `argocd-deployer-team` Role in `team-a` (same set *minus* NetworkPolicy/ResourceQuota/LimitRange), and **no** ClusterRoleBinding with write access anywhere.

**This exercise has three moves.**

> **Predict-before-you-apply.** The RBAC file creates a ServiceAccount, token Secret, Roles, and RoleBindings. **Which cluster should receive them — `k3d-mgmt` or `k3d-workload`?** Write your answer before Move A.

**Move A — create the identity.** Apply `workload-rbac.yaml` to the correct cluster (your prediction decides the `--context`). This creates `argocd-manager` and its per-namespace Roles.

**Move B — collect the token and CA.** The Secret `argocd-manager-token` (namespace `argocd-access`) holds two fields you need:
- the **bearer token** = the *decoded* value of the Secret's `token` field.
- the **CA data** = the Secret's `ca.crt` field used **as-is** (already base64-encoded, which is what `caData` expects).

**Move C — render and apply the cluster Secret.** Inject the token and CA into the template's `<TOKEN>` and `<CA_DATA>` placeholders, then apply the result to the **management** cluster's `argocd` namespace.

**Shape of a correct result:** a cluster Secret `cluster-workload` exists in `argocd` on the management cluster. Settings → Clusters lists a `workload` row at `https://k3d-workload-server-0:6443`. Clicking that row opens its detail page, which lists the five scoped namespaces and the `cluster-role`/`region` labels.

> **Why the status says `Unknown`, not `Successful` (this is expected).** Argo CD connects to a cluster only when an Application deploys to it. No Application uses `workload` yet, so Argo CD has not tried your key card. In `argocd cluster list` the STATUS column can stay blank for up to a minute; then the row reads **Unknown**, with the message *"Cluster has no applications and is not being monitored."* That is not a failure — nobody has checked yet. In E4 you create the first Application for this cluster, and within seconds of that the row turns **Successful**.

**Hints (use only if stuck):**
- *Hint 1:* Re-run the cluster "address book" command from Module 1 after Move C — it should now return **two** rows.
- *Hint 2:* The token Secret may take a few seconds to populate after Move A. If `token` is empty, wait and re-read it.
- *Hint 3:* `kubectl get secret ... -o jsonpath='{.data.<field>}'` returns one field. Remember which needs `base64 -d` and which is used as-is (Module 1's template comments).
- *Hint 4:* Keep the token and CA out of history and Git the same way you kept the password out in E1 (variables + `apply --server-side -f -`, never a committed file).
- *Hint 5:* The `Unknown` status cannot tell you yet whether your `server:` line is right, so check it by eye now: it must be `https://k3d-workload-server-0:6443`, not any `localhost` address. A wrong address only shows up in E4, when Argo CD first tries to use it.

**Success criterion:** Settings → Clusters shows a `workload` row at server `https://k3d-workload-server-0:6443` with status **Unknown** (SS-L2-03); its detail page shows the five scoped namespaces and the labels (SS-L2-04); and the Module 1 cluster "address book" command returns two rows.

![Argo CD Settings, Clusters listing workload at k3d-workload-server-0:6443 with status Unknown (v3.5.2)](../../assets/screenshots/day-1/lab-02-03-cluster-registered.png)

*Figure SS-L2-03 — After E2: the `workload` cluster is listed at `https://k3d-workload-server-0:6443`. Its status is **Unknown** because no Application uses it yet.*

<!-- CAPTURE-SPEC: SS-L2-03 — Settings → Clusters after E2, before E4. State: cluster-workload applied, no Application targets it, route /settings/clusters. Highlight: workload row, server URL, Unknown status. Fidelity: full page. Argo CD v3.5.2. -->

![Argo CD cluster detail page for workload showing namespaces, labels, and connection state Unknown (v3.5.2)](../../assets/screenshots/day-1/lab-02-04-cluster-detail.png)

*Figure SS-L2-04 — The `workload` cluster's detail page (click its row): the five namespaces, the `cluster-role`/`region` labels, and **Connection state** `Unknown` — "Cluster has no applications and is not being monitored."*

<!-- CAPTURE-SPEC: SS-L2-04 — Cluster detail page. State: after E2, before E4; click the workload row on /settings/clusters. Highlight: GENERAL (namespaces, labels) and CONNECTION STATE boxes. Fidelity: full page. Argo CD v3.5.2. -->

### ✅ What you should take away from E2

- **Two clusters, two jobs.** The identity (`argocd-manager`) was created on the **workload** cluster. The management cluster only stores a *copy of its token* in the cluster Secret.
- **Registering a cluster is one more labeled Secret** — the address book now has two cluster cards.
- **The cluster Secret carries three things:** where to go (`server`), who to be (the token), and how to recognise the real cluster (the CA data).
- **The limits are written in two places.** The Roles on the workload cluster say *what* Argo CD may change. The cluster Secret's `namespaces` and `clusterResources: "false"` say *where*. Module 3's E3 tests the first one.
- **`Unknown` right after registering means "not checked yet", not "broken".** Argo CD connects to a cluster only when an Application needs it.

---

## ✅ Key takeaways from this module

- **Connecting a repository = applying one labeled Secret.** The password is filled in at apply time and never shown, committed, or copied into an annotation.
- **A green Successful is a reading from the last check**, not a promise that it will stay green. Argo CD remembers repository results for up to an hour — click **Refresh list** for a fresh one.
- **The identity Argo CD uses lives on the cluster being managed.** The management cluster only holds the key card, not the room.
- **Registering a cluster = applying one labeled cluster Secret** with the in-network server address, the token, and the CA data. Until an Application uses the cluster, its status is `Unknown`.
- **After this module Argo CD holds the keys to read Git and reach the workload cluster** — the two ends of every deployment in the rest of the course.

**→ Next:** [03 — Prove least privilege, create the app](03-prove-least-privilege-and-create-app.md)
