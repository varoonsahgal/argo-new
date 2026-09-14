# Lab 2 · Module 2 — Connect the Repo, Register the Cluster

> **Day 1 · Lab 2 · Module 2 of 4 · ~27 minutes**
> **Goal:** inject a repository credential without ever exposing it (**E1**), then create a least-privilege identity on the workload cluster and register it (**E2**).

> **Ground rule:** the templates showed you the *shapes*. These exercises do **not** hand you the finished commands — you produce them. The separate solution guide has exact answers if your instructor needs them.

**Why are we doing this lab?** Before Argo CD can deploy the storefront application, it needs to know **where to get its deployment files** and **which cluster to deploy them to**, with credentials to access both.

This module prepares you to configure those two connections. You will check what is already registered and examine the YAML templates you will fill in next. Nothing gets deployed yet.

The key idea: Argo CD stores these connection details as **labeled Kubernetes Secrets**. By the end of this lab, you will understand how creating those Secrets connects Argo CD to your repository and workload cluster.

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
# Lab 2 · Module 2 — Connect the Repo, Register the Cluster

> **Day 1 · Lab 2 · Module 2 of 4 · ~27 minutes for exercises; allow extra time for walkthroughs**
> **Goal:** give Argo CD access to the private storefront Git repository (**E1**) and permission to deploy into selected namespaces on the workload cluster (**E2**), while keeping real credentials out of Git and terminal output.

> **Ground rule:** the templates showed you the *shapes*. These exercises do **not** hand you the finished commands — you produce them. Use the walkthroughs below to understand each operation, then assemble your commands using the hints. The separate solution guide provides exact answers when needed.

## Start here — what are we setting up?

Argo CD already runs on the **management cluster**. Before it can deploy storefront, it needs answers to two questions:

| Question | What this module gives Argo CD | Exercise |
| --- | --- | --- |
| Where can I read the deployment files, and how do I log in? | The private Git repository URL, username, and password | E1 |
| Which cluster can I deploy to, and what am I allowed to change? | The workload cluster address, an authentication token, certificate information, and a limited management scope | E2 |

**You are configuring access. You are not deploying storefront yet.** In the next module, you test permissions and create an Application that selects the repository path and deployment destination.

### Who fills in the Secrets?

**Your commands fill in the templates. Kubernetes stores the completed Secrets. Argo CD reads them.** Argo CD does not discover the password or replace `<TOKEN>` for you.

A template is a blank form kept in Git. A completed Secret contains the real connection data and is submitted to Kubernetes. The label tells Argo CD whether to treat that Secret as a repository connection or a cluster connection.

### Where does everything live?

| Item | Location | Purpose |
| --- | --- | --- |
| Blank Secret templates | `platform-config` repository and your local clone | Reusable configuration with placeholders |
| Storefront deployment files | `storefront-gitops` repository | Describe the application to deploy later |
| Repository Secret | Management cluster → `argocd` | Holds the repository connection and credentials |
| ServiceAccount, token Secret, Roles, and RoleBindings | Workload cluster | Establish the identity and permissions Argo CD will use |
| Cluster connection Secret | Management cluster → `argocd` | Holds credentials **for the workload cluster** |

**Two different Secrets participate in E2:** the workload cluster's token Secret supplies a credential; the management cluster's connection Secret stores a copy for Argo CD to use. They have different names, locations, and purposes.

### Before you begin

Continue in the terminal environment prepared for the course, where the Module 1 files and both Kubernetes contexts are available. If using your Mac, those paths and contexts must exist on your Mac; a file on the course VM is not automatically on your Mac.

A **context** is a named connection configuration used by `kubectl`. These read-only commands show the available contexts and check for the lab's ServiceAccount:

```bash
kubectl config get-contexts
kubectl --context k3d-workload -n argocd-access get serviceaccount argocd-manager
```

Both `k3d-mgmt` and `k3d-workload` should be available. Before E2, a `NotFound` response for the ServiceAccount is expected. A connection or authentication error is different: resolve the environment connection before proceeding.

You also need the Module 1 clone of `platform-config`, the provided credentials and RBAC files, and access to the Argo CD UI or an authenticated Argo CD CLI session.

**Before every command, ask:** am I changing Argo CD's connection settings on management, or creating its identity and permissions on workload?

### What will count as finished?

- E1: the private repository is listed with **Successful** connection status.
- E2: the workload cluster is listed with the correct address and five namespaces. **Unknown** with “Cluster has no applications and is not being monitored” is expected at this stage.
- Real passwords and tokens have not been printed, committed, or saved in an extra completed YAML file.


---

## E1 — Connect the private repository

**Difficulty:** Core · **Time:** ~10 minutes · **Objective:** L2.1

> **🧭 What this exercise is for**
> - **In plain words:** the `storefront-gitops` repository is private, so Argo CD needs a username and password to read it. You give Argo CD that password by creating a **repository Secret** — without the password ever appearing on your screen, in your shell history, or in Git.
> - **Think of it like:** giving the delivery driver the key to a locked warehouse. You hand the key over directly. You do not tape it to the front door (Git) or shout it across the street (your terminal).
> - **Connects to:** [Session 3 · Module 2](../session-03/02-onboarding-repos-and-clusters.md) — the repository Secret shape, and "commit the pointer, never the payload."
> - **Big picture:** Argo CD can only deploy what it can *read*. Without valid access to this private repository, Argo CD cannot read storefront’s desired state. The files exist in Git, but Argo CD cannot use them yet.

**Goal:** turn the repository template into a real Secret by injecting the Gitea password **from the credential file**, apply it, and confirm the connection shows **Successful**. The password must never appear in the template, your shell history, or Git.

**Starter state:** `platform-config` cloned (Module 1). Template at `~/platform-config/repositories/storefront-gitops.secret.template.yaml`. Password at `~/course/credentials/gitea-student.txt`.

### E1 walkthrough — what your commands must accomplish

**Destination for the completed Secret: `k3d-mgmt`, namespace `argocd`.**

1. Read the **blank template** to identify its URL, label, username, and placeholder. Reading the blank template is safe; do not display a completed version.
2. Load the password from the supplied credential file into a variable. This means the command names the file instead of containing the literal password.
3. Replace `<PASSWORD>` in memory with that value. This is what **inject** or **render** means here: produce a completed Kubernetes manifest from a template.
4. Send that manifest directly to `kubectl` through a pipe and apply it to management.
5. Check the repository connection in Argo CD. Kubernetes accepting a Secret only proves the object was stored; **Successful** means the repository connection check worked.

A pipe (`|`) sends one command's output into the next command. The `-f -` option tells `kubectl` to read the manifest from that input stream. Running the rendering command by itself would instead print the completed Secret, so keep the pipe attached.

**What “not saved to disk” means:** the original credential file already exists on disk, and Kubernetes persists the Secret. The exercise avoids creating an **additional local file containing the completed manifest**.

**Predict-before-you-verify:** after you apply this Secret, will the connection show Successful *immediately*, or is there a delay? (Hold your answer.)

**Hints (use only if stuck):**
- *Hint 1:* Everything in the template is correct except `<PASSWORD>`. Do not edit the `url`, `username`, or label.
- *Hint 2:* Do not paste or `echo` the password. Load the credential from its file into a variable, then use a renderer to replace the placeholder. **Syntax matters:** `envsubst` recognizes `$VARIABLE` or `${VARIABLE}`, not `<PASSWORD>`. If using it, first convert `<PASSWORD>` to a named variable reference in the input stream, export that variable, and restrict substitution to that variable. Alternatively, use a renderer that explicitly handles the angle-bracket placeholder. Ensure the inserted value is correctly quoted or serialized for YAML; arbitrary passwords can contain YAML-special characters.
- *Hint 3:* Render the filled-in Secret to standard output and pipe it straight into `kubectl --context k3d-mgmt apply --server-side -f -` so you do not create an extra local file containing the completed Secret. Keep `--server-side`: a plain `kubectl apply` saves a full copy of what you applied, password included, in an annotation (a note stored on the object) called `kubectl.kubernetes.io/last-applied-configuration`. With `--server-side`, no such copy is made.
- *Hint 4:* To verify, use the UI Repositories page and `argocd repo list` — neither reveals the password. To check that the client-side apply annotation is absent, list only the annotation *names* on the Secret (never their values): `kubectl --context k3d-mgmt -n argocd get secret repo-storefront-gitops -o go-template='{{range $k, $v := .metadata.annotations}}{{$k}}{{"\n"}}{{end}}'`. For a newly created Secret in this lab, it should print nothing. The specific annotation that must be absent is `kubectl.kubernetes.io/last-applied-configuration`; unrelated annotation names are not evidence that a password was copied. Server-side apply does not remove an old annotation left by an earlier client-side apply.

**Success criterion:** Settings → Repositories shows `storefront-gitops` with a green **Successful** status; `argocd repo list` shows the same; you did not print or commit the password.

![Argo CD Settings, Repositories showing storefront-gitops Successful (v3.5.2)](../../assets/screenshots/day-1/lab-02-02-repository-connected.png)

*Figure SS-L2-02 — After E1: `storefront-gitops` shows a green **Successful** connection status. It is the only row: no credentials template exists yet.*

<!-- CAPTURE-SPEC: SS-L2-02 — Settings → Repositories after E1. State: repo-storefront-gitops applied, route /settings/repos. Highlight: storefront-gitops row with green Successful status. Fidelity: full page. Argo CD v3.5.2. -->

> **What "Successful" actually means (keep this for the Capstone).** A green status is a *measurement from the last check*, not a permanent guarantee — "the last check reached the repository." Argo CD can cache repository connection results, so the Repositories page can show an old reading; the duration depends on configuration. To make it check again, click **Refresh list** on that page, or run `argocd repo list --refresh hard`. A credential that expires next month shows green today and fails the morning it matters. Every status in Argo CD is a reading with a timestamp.

### ✅ What you should take away from E1

- Connecting a repository is **one labeled Secret**. The row on the Repositories page appeared because that Secret now exists.
- The password came from a file, went through a variable, and was piped straight into the cluster. It was not printed, committed to Git, saved in an extra local manifest, or copied into a client-side apply annotation. The original credential file and the Kubernetes Secret still contain the credential.
- Compare the page with your Module 1 "before" photo: the empty page now has a row — and you made it.

---

## E2 — Register the workload cluster with least privilege

**Difficulty:** Advanced · **Time:** ~17 minutes · **Objective:** L2.2

> **🧭 What this exercise is for**
> - **In plain words:** you create an identity for Argo CD on the **workload** cluster. Its Roles permit selected changes in five namespaces; they do not grant every possible operation in those namespaces. Then you give Argo CD that login's token by writing a **cluster Secret** on the **management** cluster.
> - **Think of it like:** a hotel key card. The card (token) is made at the hotel (the workload cluster) and opens only certain rooms (namespaces). The guest (Argo CD, living on the management cluster) just carries the card in its wallet (the cluster Secret).
> - **Connects to:** [Session 3 · Module 2](../session-03/02-onboarding-repos-and-clusters.md) — the cluster-registration trust chain; and [Session 3 · Module 3](../session-03/03-least-privilege-and-change-detection.md) — least *write* privilege.
> - **Big picture:** real platforms run Argo CD in one place and deploy to many other clusters. If the key card opened every room, one bad commit could damage the whole workload cluster. Limiting the card limits the damage.

**Words you will meet in this exercise:**

- **ServiceAccount** — a Kubernetes login for a *program* rather than a person. Argo CD will use one called `argocd-manager`.
- **RBAC (Role-Based Access Control)** — Kubernetes' permission system. A **Role** lists allowed actions inside one namespace. A **RoleBinding** gives that Role to an identity, in that namespace only. A **ClusterRoleBinding** would grant permissions across the *whole* cluster — this lab creates none that allow writing.
- **base64** — a way of writing any data as plain text characters. It is *encoding*, not encryption: anyone can decode it.

**Goal:** give Argo CD a scoped identity on the workload cluster, then register the cluster by writing a cluster Secret that carries that identity's token and CA. When you finish, Argo CD lists the workload cluster, scoped to only its allowed namespaces. (Its status will say **Unknown** for now — "Shape of a correct result" explains why.)

**The identity lives on the cluster being *managed*.** When you register a workload cluster, the **ServiceAccount Argo CD authenticates as is created on the workload cluster** — not the management cluster. The management side only stores a *credential for* it (the cluster Secret). The file `~/course/lab-files/lab-02/workload-rbac.yaml` builds that identity **on the workload cluster**: a ServiceAccount `argocd-manager` in namespace `argocd-access`, a token Secret, a `Role argocd-deployer` + RoleBinding in each app namespace, a reduced `argocd-deployer-team` Role in `team-a` (same set *minus* NetworkPolicy/ResourceQuota/LimitRange), and **no** ClusterRoleBinding with write access anywhere.

### Understand the identity before creating it

There are three separate questions:

| Question | Kubernetes mechanism | Meaning in this exercise |
| --- | --- | --- |
| Who is making the request? | ServiceAccount and bearer token | Argo CD authenticates as `argocd-manager` from `argocd-access` |
| What may that identity do? | Roles and RoleBindings | The workload API server enforces allowed actions in each namespace |
| How does Argo CD find and trust the server? | `server` and CA data in its connection Secret | Argo CD gets a reachable address and verifies the server certificate |

A ServiceAccount alone does not grant deployment permissions. A token proves identity; it does not grant extra rights. RoleBindings associate that identity with the permissions defined by Roles.

The ServiceAccount lives in `argocd-access`, but RoleBindings in the five application namespaces can give it access there. Its home namespace does not have to be the namespace where it deploys.

The five target namespaces are `storefront-dev`, `storefront-staging`, `storefront-prod`, `team-a`, and `platform-system`. The provided RBAC file defines the precise allowed resources and actions. Inspect its Roles if you need to know whether a particular action is permitted.

**This exercise has three moves.**

> **Predict-before-you-apply.** The RBAC file creates a ServiceAccount, token Secret, Roles, and RoleBindings. **Which cluster should receive them — `k3d-mgmt` or `k3d-workload`?** Write your answer before Move A.

### Move A — create the identity and permissions on the workload cluster

**Your task:** Apply `workload-rbac.yaml` to the correct cluster (your prediction decides the `--context`). This creates `argocd-manager` and its per-namespace Roles and bindings.

**Why workload?** The workload API server must recognize the identity and enforce its permissions. Creating these objects only on management would not establish that identity on workload.

**Read-only check after applying your command:**

```bash
kubectl --context k3d-workload -n argocd-access get serviceaccount argocd-manager
kubectl --context k3d-workload -n storefront-dev get roles,rolebindings
```

The first command should find the ServiceAccount. The second should show the resources from the RBAC manifest. These checks establish that the objects exist; the next module tests what the identity can actually do.

### Move B — read the credential from the workload cluster

**Your task:** The Secret `argocd-manager-token` (namespace `argocd-access`) holds two fields you need:
- the **bearer token** = the *decoded* value of the Secret's `token` field.
- the **CA data** = the Secret's `ca.crt` field used **as-is** (already base64-encoded, which is what `caData` expects).

**Keep both values in variables instead of displaying them.** The token is a secret credential; the CA certificate is public trust information, not a password.

| Source field in the workload Secret | Transformation | Destination in the connection Secret's JSON `config` |
| --- | --- | --- |
| `.data.token` | Decode base64 once | `bearerToken` |
| `.data.ca.crt` | Keep its existing base64 representation | `tlsClientConfig.caData` |

The two fields are handled differently because their destination fields expect different formats. Base64 decoding does not decrypt anything.

**JSONPath detail:** a dot in a field name must be escaped. The field selector for `ca.crt` is `{.data.ca\.crt}`. Use this inside your variable assignment; do not run a token-extraction command on its own and expose its output.

### Move C — store the connection on the management cluster

**Your task:** Inject the token and CA into the template's `<TOKEN>` and `<CA_DATA>` placeholders, then apply the result to the **management** cluster's `argocd` namespace.

**Why management now?** Argo CD runs there and reads connection Secrets from its `argocd` namespace. You are giving it a copy of the workload credential, not creating a second workload identity.

The finished connection Secret has this meaning:

| Field | Question it answers |
| --- | --- |
| Label `argocd.argoproj.io/secret-type: cluster` | How should Argo CD interpret this Secret? |
| `name: workload` | What is the display name of the destination? |
| `server` | Which Kubernetes API endpoint should Argo CD contact? |
| `bearerToken` inside `config` | Which credential should it present? |
| `tlsClientConfig.caData` inside `config` | Which certificate authority should it trust? |
| `namespaces` | Which namespaces should Argo CD manage? |
| `clusterResources: "false"` | With the namespace list set, should it manage cluster-scoped resources? No. |

**The address must work from Argo CD's Pod.** Keep `https://k3d-workload-server-0:6443`. Your local kubeconfig—the file `kubectl` uses for cluster addresses and credentials—may use a localhost port forwarded by Docker. Inside Argo CD's Pod, localhost refers to that Pod, so copying your local address would point at the wrong place. The lab's internal network and DNS must make the server name reachable from Argo CD.

**Management scope and enforced permissions are different.** The Secret tells Argo CD which resources to manage. The workload cluster's RBAC rules enforce what the token holder may actually do. Setting `clusterResources: "false"` does not itself revoke any permissions from a token. [Argo CD cluster configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)

**Shape of a correct result:** a cluster Secret `cluster-workload` exists in `argocd` on the management cluster. Settings → Clusters lists a `workload` row at `https://k3d-workload-server-0:6443`. Clicking that row opens its detail page, which lists the five scoped namespaces and the `cluster-role`/`region` labels.

> **Why the status says `Unknown`, not `Successful` (this is expected).** In this lab, the application controller does not start monitoring workload resources until an Application targets the cluster. No Application uses `workload` yet, so registration alone has not established that deployment access works. In `argocd cluster list`, the STATUS column may briefly stay blank before the row reads **Unknown**, with the message *"Cluster has no applications and is not being monitored."* That is not a failure — nobody has checked yet. In E4 you create the first Application for this cluster. With working networking, credentials, and permissions, monitoring should then report **Successful**. Allow time for reconciliation; investigate an error rather than assuming registration already proved connectivity.

**Hints (use only if stuck):**
- *Hint 1:* Re-run the cluster "address book" command from Module 1 after Move C — it should now return **two** rows.
- *Hint 2:* The token Secret may take a few seconds to populate after Move A. If `token` is empty, wait and re-read it.
- *Hint 3:* `kubectl get secret ... -o jsonpath='{.data.<field>}'` returns one field. Remember which needs `base64 -d` and which is used as-is (Module 1's template comments).
- *Hint 4:* Keep the token and CA out of history and Git the same way you kept the password out in E1 (variables + `apply --server-side -f -`, never a committed file).
- *Hint 5:* The `Unknown` status cannot tell you yet whether your `server:` line is right, so check it by eye now: it must be `https://k3d-workload-server-0:6443`, not any `localhost` address. A wrong address may surface in E4 when the application controller starts using this destination.

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
- **The limits are written in two places.** The workload Roles and RoleBindings enforce allowed actions and namespace access. The cluster Secret configures Argo CD’s management scope. Module 3’s E3 tests the enforced permissions.
- **`Unknown` right after registering means "not checked yet", not "broken".** In this lab, monitoring starts when an Application targets the cluster; registration by itself is not a connectivity test.

---

## If your result is different

| What you see | What it means or what to check |
| --- | --- |
| `kubectl` cannot connect before applying anything | Check the chosen context and whether that lab cluster is running. |
| No repository row after E1 | Check that `repo-storefront-gitops` exists on management in `argocd` and has the repository label. |
| Repository row exists but connection fails | Registration succeeded, but access did not. Check the template URL and credential-loading process without printing the password. Request a fresh connection check. |
| Empty token during Move B | The token controller may still be populating the Secret. Re-read after a few seconds; do not submit an empty token. |
| No workload row after E2 | Check the cluster Secret's destination namespace, context, and cluster label. |
| Workload is `Unknown` with the no-applications message | Expected here. Continue to the next module; this does not prove the address or token works. |
| A later Application reports connection refused or DNS failure | Check the internal server address and lab networking. A localhost address in the connection Secret is incorrect here. |
| A later request reports `Unauthorized` | Check that a valid, decoded bearer token was supplied. |
| A later request reports `Forbidden` | Check the identity's Roles and RoleBindings for the requested resource, action, and namespace. |

To request a fresh repository connection check:

```bash
argocd repo list --refresh hard
```

This refreshes the cached connection status; it does not deploy an application. [Argo CD command reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_repo_list/)

## Explain what you built

Before moving on, answer these in your own words:

1. Who replaced the placeholders: your commands or Argo CD?
2. Why is the repository Secret stored on management?
3. Why is the ServiceAccount created on workload?
4. Why does the cluster Secret contain a copy of the workload token?
5. Does seeing the workload row prove deployment permissions work?
6. What still needs to be created before Argo CD knows which application files to deploy?

**Check your understanding:** your commands supplied the values; Argo CD reads connections on management; workload recognizes and authorizes its own ServiceAccount; the copied token lets Argo CD authenticate remotely; registration does not prove deployment access; an Application still needs to select the source and destination.

## ✅ Key takeaways from this module

- **Connecting a repository = applying one labeled Secret.** Your commands fill in the password at apply time without printing it, committing it, or creating a client-side apply annotation.
- **A green Successful is a reading from the last check**, not a promise that it will stay green. Connection results can be cached — use `argocd repo list --refresh hard` to request a fresh check.
- **The identity Argo CD uses lives on the cluster being managed.** The management cluster only holds the key card, not the room.
- **Registering a cluster = applying one labeled cluster Secret** with the in-network server address, the token, and the CA data. In the expected starting state, its status is `Unknown` because no Application uses it yet.
- **After this module Argo CD holds the keys to read Git and reach the workload cluster** — the two ends of every deployment in the rest of the course.

**→ Next:** [03 — Prove least privilege, create the app](03-prove-least-privilege-and-create-app.md)
