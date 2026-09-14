# Lab 2 · Module 4 — Diagnose and Wrap-Up

> **Day 1 · Lab 2 · Module 4 of 4 · ~10 minutes**
> **Goal:** practice the onboarding-diagnosis reflex (**E5**), then confirm your checkpoint.

> **🗺️ Where this module fits.** You built working connections in Modules 2 and 3. Now you see what *broken* ones look like, while the working ones are fresh in your mind to compare against. Then you check off the lab and see how it sets up Lab 3.

---

## E5 — Diagnose two broken onboarding records

**Difficulty:** Intermediate · **Time:** ~8 minutes · **Objective:** O7
**The second record (the cluster) is optional — do it if you have time.**

> **🧭 What this exercise is for**
> - **In plain words:** you apply an onboarding Secret that has one wrong value, read what Argo CD shows, and name the wrong field. You are practising **reading the symptom before changing anything**.
> - **Think of it like:** a delivery order with a wrong address. The driver's note ("address not found", "gate locked") tells you which line on the order to check.
> - **Connects to:** Modules 2 and 3. Your working `repo-storefront-gitops` and `cluster-workload` Secrets are your "known good" copies to compare against.
> - **Big picture:** "the repo won't connect" and "the cluster shows a bad status" are among the most common real support tickets for Argo CD, and the Capstone includes this kind of fault.

**Goal:** apply a deliberately broken onboarding Secret, read the symptom, name the **single wrong field**, and remove it. You are practicing the diagnosis reflex, not memorizing a fix.

**Starter state:** two provided broken files (a different `metadata.name` from your working ones, so applying them does **not** overwrite E1/E2):
- `~/course/lab-files/lab-02/broken/repo-secret-wrong-url.yaml` (record 1 — required)
- `~/course/lab-files/lab-02/broken/cluster-secret-wrong-server.yaml` (record 2 — optional)

**▶ Do this now — one record at a time:**

1. **Predict first.** `cat` the file. Predict: *what status will Argo CD show, and on which page?*

   | Record | Predicted symptom (status + page) | Which field looks wrong? |
   |---|---|---|
   | 1 — repo, wrong URL | ? | ? |
   | 2 — cluster, wrong server *(optional)* | ? | ? |

2. **Apply it:**
   ```bash
   kubectl --context k3d-mgmt apply -f ~/course/lab-files/lab-02/broken/repo-secret-wrong-url.yaml
   ```
3. **Observe.** Refresh the relevant Settings page (Repositories for record 1, Clusters for record 2) and read the **Failed** status and its message (SS-L2-09 / SS-L2-10). Compare to your prediction.
4. **Name the wrong field** in one sentence — do not fix it in place.
5. **Remove the broken Secret:**
   ```bash
   kubectl --context k3d-mgmt -n argocd delete secret <the-broken-secret-name>
   ```

**Shape of a correct result:** for each record, point to the **one field** that is wrong and explain the symptom. Record 1 fails because the connection cannot reach the repository at the given address. Record 2 fails because the server address is not reachable *from the controller Pod* — the same "valid only from where it is used" rule as the real registration.

**Hints:**
- *Hint 1:* The failing field is one you already got *right* in E1/E2. Compare line by line.
- *Hint 2:* For record 2, ask the mental-model question: could a Pod on the cluster network reach the address in this file?
- *Hint 3:* Read the failure *message*, not just the red badge — Argo CD usually names what it could not do (resolve a host, connect, authenticate).

**Success criterion:** you named the single wrong field in each record you attempted, both Settings pages are clean again, and your E1/E2 connections are untouched (still `Successful`).

![Settings, Repositories showing a failed repository connection (v3.5.2)](../../assets/screenshots/day-1/lab-02-09-repository-failed.png)

*Figure SS-L2-09 — Record 1: a wrong URL shows a red **Failed** connection with a message.*

![Settings, Clusters showing a failed cluster connection (v3.5.2)](../../assets/screenshots/day-1/lab-02-10-cluster-failed.png)

*Figure SS-L2-10 — Record 2 (optional): an unreachable server shows a **Failed** connection.*

<!-- CAPTURE-SPEC: SS-L2-09/10 — Settings → Repositories/Clusters, troubleshooting. State: broken Secret applied. Highlight: Failed status and message. Argo CD v3.5.2. -->

### ✅ What you should take away from E5

- **Read the message, not only the colour.** The text usually says what failed: finding the host, connecting, or logging in.
- **A broken onboarding Secret usually has one wrong field.** Compare it line by line with a copy you know works.
- **An address that works from your laptop can still fail from inside the Argo CD Pod.** Always ask "where is this address being used from?"
- **Removing the broken Secret removes the broken row.** Your working Secrets were never touched, because their names are different.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Settings → Repositories **already** shows `storefront-gitops` (or a `http://lab-gitea:3000/course/` credentials template) before E1 | The environment still holds objects from a later lab | `reset-lab.sh CP-lab-02 --local`, then refresh the page |
| Repository shows **Failed** | Wrong `url`/`username`, or bad password injection | Re-check `url` = `http://lab-gitea:3000/course/storefront-gitops.git`; confirm password came from the credential file; re-apply |
| Cluster shows **Unknown**/error | The `server:` field is a `localhost`/`127.0.0.1` address (means the Pod itself) | Set `server: https://k3d-workload-server-0:6443`; re-apply |
| Cluster shows a **TLS/certificate** error | `caData` wrong or empty | Re-collect `ca.crt` from `argocd-manager-token`, use **as-is** (already base64) |
| Authenticates but every action denied later | Bearer token taken from the wrong field, or read before the Secret populated | Token = **decoded** `token` field; re-read after populated, re-inject |
| `argocd cluster add k3d-workload` **fails** | It reads your kubeconfig's `localhost` server URL, unreachable from the Argo CD Pods | Register **declaratively** with the in-network name (stretch A explains) |
| `auth can-i` returns `no` for everything | Wrong `--as=` string, or RBAC applied to the wrong cluster | Identity is `system:serviceaccount:argocd-access:argocd-manager`; RBAC belongs on `k3d-workload` |
| `storefront-dev` red **ComparisonError** | Wrong `valueFiles` relative path | Fix path from `charts/storefront` to `envs/dev/values.yaml`, commit, re-apply |
| `storefront-dev` stuck **Unknown** | `destination.server` doesn't match the registered cluster URL | Make it byte-for-byte identical to the cluster Secret's `server` |

---

## Checkpoint / validation

You have finished Lab 2 when **all** of these are true:

1. **Repository connected:** `argocd repo list` shows `storefront-gitops` with status `Successful`.
2. **Workload cluster registered:** `argocd cluster list` shows `workload` `Successful` at `https://k3d-workload-server-0:6443`.
3. **Address book has two cluster Secrets:** the Module 1 cluster query now returns `in-cluster` **and** `cluster-workload`.
4. **Least-privilege matrix matches the design:** your E3 table is complete and every `yes`/`no` matches the RBAC (app namespaces allow writes; unlisted namespaces and cluster-scoped deletes do not).
5. **The Application renders and compares:** `argocd app get storefront-dev` shows `OutOfSync` / `Missing`, and the diff shows all resources newly added. You can explain in one sentence why this is correct, not broken.

If all five hold, you have built the real topology. This is exactly checkpoint **`CP-lab-03`**, the starting state for the next lab.

---

## ✅ Key takeaways

**From this module (E5):**

- **Diagnose before you fix.** Read the status *and* its message, then find the one wrong field by comparing with a working copy.
- **Most onboarding failures are an address, a credential, or a certificate** — and the message usually tells you which.

**From the whole of Lab 2:**

- **Argo CD's list of repositories and clusters is just labeled Secrets in the `argocd` namespace.** Two `kubectl get secret -l …` commands show the whole address book.
- **The identity lives on the cluster being managed, not the one doing the managing.** `argocd-manager` is a ServiceAccount on the *workload* cluster; the management cluster only stores a credential *for* it.
- **An address only works from the place that uses it.** Argo CD's controller Pod reaches the workload cluster as `k3d-workload-server-0:6443`. Inside that Pod, `localhost` means the Pod itself — the most common copy-paste mistake when registering a cluster.
- **Least privilege has two locks.** The Roles on the workload cluster decide *what* Argo CD may change; the cluster Secret's `namespaces` and `clusterResources: "false"` decide *where*. `kubectl auth can-i` proves both.
- **`OutOfSync` + `Missing` is the correct first result, not a failure.** Git describes resources the cluster does not have yet, and you have not synced on purpose.
- **Build the AppProject (the fence) before you need it**, so a later access request is a small reviewed change, not an argument.

---

## Optional stretch challenge

> **Clearly optional — pick one.**

**Option A — Explain why `argocd cluster add` fails here (recommended, fully local).** Run `argocd cluster add k3d-workload`. Predict first: *will it succeed?* It will not. Read the message, then answer in two sentences: **which server URL did the command try, and why can the Argo CD Pods not reach it?** (It reads your kubeconfig's `localhost` address, reachable only from your VM — not inside the controller Pod. Your declarative Secret worked because it used `k3d-workload-server-0:6443`.)

**Option B — Configure a Gitea webhook to remove polling delay (partly verified).** Point a Gitea webhook at `https://<your-argocd-host>/api/webhook`, push a trivial commit, and measure how fast `storefront-dev` reflects it versus polling. *Marked partly verified — if the webhook does not fire, fall back to Refresh and note what you observed. Do not spend more than a few minutes.*

**Option C — Watch a healthy cluster go `Unknown` (fully local, reversible).** **Predict first:** if you make the `cluster-workload` credential invalid, will `storefront-dev` become `OutOfSync`, `Degraded`, or `Unknown`? Break it (reversible):

```bash
kubectl --context k3d-mgmt -n argocd patch secret cluster-workload --type merge \
  -p '{"stringData":{"config":"{\"bearerToken\":\"invalid\",\"tlsClientConfig\":{\"insecure\":true}}"}}'
```

Refresh `storefront-dev`. The answer is **`Unknown`** — not `OutOfSync`, not `Degraded`. Argo CD is reporting it **can no longer observe live state at all**; absence of evidence renders as `Unknown`, the single most misdiagnosed status. Restore with `reset-lab.sh CP-lab-03 --local` and refresh again — status returns to `OutOfSync` / `Missing`. **`Unknown` was never a statement about the app — it was a statement about Argo CD's eyesight.**

---

## Transition — what's next

You built the real topology: a private repo connected, a separate workload cluster registered least-privilege, a governance fence, and an Application that renders and compares but has not deployed. That `OutOfSync` / `Missing` state is the deliberate starting line for the next lab.

**In delivery-driver terms:** the address book, the warehouse key, the key card, the rules, and the first delivery order are all in place. Nothing has been delivered yet.

Next, **[Session 4](../session-04/README.md)** explains how Argo CD renders Helm and orders a sync, and **Lab 3** has you finally **sync** `storefront-dev` to the workload cluster you registered today — the first real delivery — then introduce drift, turn on self-healing, and recover a rendering failure through Git.

**Before you move on:** no cleanup required — your `platform-config` commits are the intended output. Lab 3 begins with `reset-lab.sh CP-lab-03 --verify-only --local`.
