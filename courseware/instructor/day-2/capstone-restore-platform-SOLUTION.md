# Capstone — Instructor Walkthrough and Solutions

> **INSTRUCTOR ONLY. Never share this file with participants, never project it, and never leave it open on a screen participants can see — this file names every fault.**
> **Participant guide:** [capstone-restore-platform.md](../../day-2/capstone-restore-platform.md)
> **Timebox:** 90 minutes, plus your debrief · **Scaffolding:** G3 (diagnostic)
> **Verified:** 2026-09-13 as a full incident on the course's local k3d two-cluster sandbox: Argo CD `v3.5.2` (chart `10.8.4`), `argocd` CLI `v3.5.2`, Kubernetes `v1.35.8+k3s1`, Helm `v4.2.1`. The platform was reset to `CP-capstone`, all seven faults were injected with `inject-capstone-faults.sh inject all`, and every fault was diagnosed and repaired through the guide's controlled change paths, with `capstone-check.sh` run after each repair. Output blocks are real; SHAs, Pod names, IPs, and ages will differ.

---

## How this walkthrough is different

The capstone is diagnostic. **During the 90 minutes you do not walk through solutions.** Your job during the clock is to run the incident, keep time, enforce the rules of engagement, and climb the hint ladder with individuals who are stuck — never naming a fault.

This file gives you three things:

1. **Before class:** how to start a reliable incident (including a fix for a fault that silently does nothing).
2. **During class:** a phase-by-phase facilitation script and a hint policy.
3. **After the clock:** the **full model solution**, fault by fault, in the order that works — narrated so you can run the debrief as a live walkthrough on your own VM.

Labels, as in every walkthrough: **Say**, **Do**, **Click**, **Expect**, **Answer key**, **Wrong turns**, **Wow moment**, **If it goes sideways**.

---

## 0. Before class — pre-flight (20 minutes per VM, scriptable)

### 0.1 Reset and inject

**Do** (on each participant VM, before participants sit down):

```bash
source ~/argo-lab-env.sh
reset-lab.sh CP-capstone --local --yes
reset-lab.sh CP-capstone --verify-only --local      # expect 22 x PASS
inject-capstone-faults.sh inject all --local
sleep 90
inject-capstone-faults.sh verify all --local
```

**Expect** (verified):

```text
  ok F1 PRESENT
  ok F2 PRESENT
  ok F3 PRESENT
  ok F6 PRESENT
  ok F4 PRESENT
warn F5 ABSENT
  ok F7 PRESENT
```

### 0.2 F5 does not inject — apply this tested workaround

**Why:** F5 "rotates" the workload token by deleting and recreating the `argocd-manager-token` Secret under the same name. For a legacy ServiceAccount token, that produces a **byte-identical token** — its claims are only the issuer, namespace, Secret name, ServiceAccount name, ServiceAccount UID, and subject (no issue time, no Secret UID), and the signature is deterministic. Verified: live and stored token SHA-256 digests were identical after injection, and `capstone-check.sh` reported connectivity resolved. Without this workaround the class gets **six** faults, not seven.

**Do** (immediately after 0.1; verified to make F5 real without undoing F4):

```bash
kubectl --context k3d-workload -n argocd-access delete serviceaccount argocd-manager
kubectl --context k3d-workload apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-manager
  namespace: argocd-access
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: argocd-access
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
EOF
sleep 10
inject-capstone-faults.sh verify F5 --local
```

**Expect** (verified): `ok F5 PRESENT`.

Why this works: a new ServiceAccount has a new UID, so the token controller mints a different token; the RoleBindings reference the ServiceAccount by name, so they keep applying. **Do not** re-apply the whole `workload-rbac.yaml` here — it would silently repair F4. The instructor-side `revert all` and `reset-lab.sh CP-capstone` both still restore everything afterwards.

Report this to the environment owner (the permanent fix belongs in `F5/inject.sh`).

### 0.3 What the class will see at the start

**Do** (instructor-only — never project `capstone-check.sh --instructor` during the incident):

```bash
kubectl --context k3d-mgmt -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,LAST-OP:.status.operationState.phase,CONDITIONS:.status.conditions[*].type'
```

**Expect** (verified, about one minute after the F5 workaround — your screen will keep moving):

```text
NAME                            SYNC        HEALTH    LAST-OP     CONDITIONS
platform-agent                  OutOfSync   Healthy   Succeeded   SharedResourceWarning
platform-agent-dup              Synced      Healthy   Succeeded   <none>
platform-netpol                 Synced      Healthy   Succeeded   <none>
platform-quotas                 Synced      Healthy   Succeeded   <none>
platform-root                   Unknown     Healthy   Succeeded   ComparisonError
storefront-dev-in-cluster       Unknown     Unknown   <none>      InvalidSpecError
storefront-dev-workload         Unknown     Healthy   Succeeded   ComparisonError
storefront-prod-in-cluster      Unknown     Unknown   <none>      InvalidSpecError
storefront-prod-workload        OutOfSync   Healthy   Error       SyncError
storefront-staging-in-cluster   Unknown     Unknown   <none>      InvalidSpecError
storefront-staging-workload     Unknown     Healthy   Succeeded   ComparisonError
team-a-guestbook                Synced      Healthy   Succeeded   <none>
team-root                       Unknown     Healthy   Succeeded   ComparisonError
```

Thirteen Applications instead of eight; five of them didn't exist before the incident.

### 0.4 The seven faults — instructor map

| Fault | What the "teammate" did | Layer | First evidence a participant can find | Masked by / reveals |
|---|---|---|---|---|
| **F7** | Commit "argocd: right-size repo-server memory" (limit 32Mi) + patched the live Deployment | `PLAT` | `argocd-repo-server` `0/1`, restarts climbing, `Last State: OOMKilled`, `Exit Code: 137` | **Masks** F1, F2, F3 — every render fails with "dial tcp …:8081: connection refused" |
| **F1** | Commit "staging: drop stale image.tag pin (values cleanup)" — blanked `image.tag` | `SRC` | After F7 is fixed: `ComparisonError … image.tag is required (set it in envs/<env>/values.yaml)` on staging | Hidden behind F7 |
| **F5** | Token no longer matches (with the 0.2 workaround) | `CONN` | **Not** the Clusters page (stays `Successful`). The word `Unauthorized` in a sync message: `failed to discover server resources for group version apps/v1: Unauthorized` | Hides F4 until the cluster cache is rebuilt |
| **F2** | Commit "storefront appset: simplify cluster selector" (`matchLabels: {}`) **and** applied it | `GEN` | Three `storefront-*-in-cluster` Applications with `InvalidSpecError … do not match any of the allowed destinations in project 'storefront'`; `argocd appset generate` shows six rows | Its ApplicationSet error is masked by F7 |
| **F3** | Commit "platform: add team-root app-of-apps" — a second root whose child duplicates `platform-agent` | `GEN` (ownership) | `SharedResourceWarning: Deployment/platform-agent is part of applications argocd/platform-agent and platform-agent-dup` | — |
| **F4** | Deleted the `argocd-deployer` RoleBinding in `storefront-prod` on the workload cluster | `POL` | `ComparisonError: Failed to load live state … is forbidden: User "system:serviceaccount:argocd-access:argocd-manager" cannot get resource …` on **three** apps — only after F5 is fixed | Hidden by F5; F4 blocks F6 from deploying |
| **F6** | Tag `storefront-1.1.0` (readiness path `/not-ready`, HPA `minReplicas: 5`) + commit "prod: promote to storefront-1.1.0" | `RUN` + noisy drift | `storefront-prod-workload` `OutOfSync`, `SyncError`; `argocd app diff` shows `/not-ready` and a new HPA | Its degraded rollout never happens unless someone syncs it (see Fault G) |

### 0.5 Participant-guide discrepancies you'll be asked about

| Where | Guide says | Actually (verified) | What to say |
|---|---|---|---|
| §6.3.5 denial table, row 2 | Fence 2 message contains `is not permitted in project` | `InvalidSpecError … do not match any of the allowed destinations in project '<name>'` (Lab 5 already uses the new wording) | "Match on 'allowed destinations in project'." |
| §6.3.5 denial table, row 3 | `forbidden` means "a sync started, then failed" | F4's `forbidden` appears while **loading live state** — no sync starts. It shows as a `ComparisonError` | "The vocabulary still names the fence: `forbidden` + a ServiceAccount is Kubernetes RBAC, wherever it appears." |
| §4.2 layers vs `capstone-check` | The tool's areas match the layers | F4 is reported under "application source rendering" and "workload runtime health"; "deployment policy (permissions)" stays **resolved** throughout | "The tool reports which areas are green, not which layer caused them. Your grid can be more right than the tool." |
| Section 8, row "An Application still shows a failed sync…" | "Make a deliberate, logged sync" | For `storefront-prod-workload` that deploys the teammate's bad release (Fault G) | "Read the diff before you sign it." |
| Section 9 "fully restored" / P3 | `capstone-check` all resolved + eight `Synced`/`Healthy` Applications, stable for two minutes | **All of these passed while prod was still broken** — a stale cluster cache hid a leftover HPA fighting self-heal (Sections 4.7 and 5.3) | Add the two checks in Section 5.3 to your own sign-off, and rebuild the cluster cache after the Fault F repair |

---

## 1. Facilitation script — during the 90 minutes

### Run of show

| Clock | Phase | What you do |
|---|---|---|
| Before 0:00 | — | Pre-flight done on every VM. Participants have read Sections 1–4 |
| 0:00 | **Start** | Read the Monday-morning brief aloud (Section 1 of the guide). Say "the clock starts now." |
| 0:00–0:10 | **P0** | Walk the room. Check that every first-move entry names **two possible results** |
| 0:10–0:25 | **P1** | Enforce **no changes**. If you see a `git commit`, `apply`, or `sync`, stop the person kindly and ask them to log it as uncontrolled |
| 0:25 | **C1 gate** | Ask everyone to run the C1 `diff` check. Anyone who fails it: log it, move on |
| 0:25–1:15 | **P2** | Hint ladder only (below). Call time checks at **0:40, 0:55, 1:10**: "sixty seconds, re-read the whole picture" |
| 1:15 | **Stop P2** | Hard stop, whatever state people are in |
| 1:15–1:20 | **P3** | Everyone runs `capstone-check.sh` and pastes it into the log |
| 1:20–1:30 | **P4** | Silent writing |
| After | **Debrief** | Section 5 of this file |

### Opening words

**Say:**

> "For the next 90 minutes I'm not your instructor. I'm your lead on an incident call. I will not tell you what's broken. I will ask you questions. The four rules on page one are not a handicap — they're what stops a two-fault incident becoming a five-fault incident."

> "One more thing. There are seven faults. Nobody is expected to fix all seven. The minimum bar is to find the layer of all seven, restore five, and write about all seven. People who follow the method finish. People who chase the reddest badge re-diagnose the same thing three times."

### Hint policy

Use only the guide's method-level hint ladder. Map these common stuck points to the rung you give — **never** the fault:

| You see the participant… | Say (rung) |
|---|---|
| Staring at thirteen tiles, grid empty after 10 minutes | "Rung 1: which of the six layers have you not collected a single piece of evidence for? Spend two minutes there." (Most have never looked at `PLAT`.) |
| Diagnosing each `ComparisonError` app individually | "Rung 2: four apps share a symptom. What do those four apps share?" |
| Convinced the workload cluster is fine because Clusters says `Successful` | "Rung 2: when was that reading taken, and what would have to be true for it to be stale?" |
| Fixed something, it came back | "If your fix reverted, what's above the object you changed?" |
| About to press Sync on prod | "What does `argocd app diff` say that sync would apply?" |
| Deleting an Application | "Write the cascade decision in your log first. What will this delete?" |
| Ten minutes on one row with no new evidence | "Park it. Take another row. Connected faults unstick each other." |

**If someone makes an uncontrolled change:** follow the guide's Section 8 row. You can restore a single fault area without resetting everything, for example `inject-capstone-faults.sh revert F3 --local` (then re-inject it only if the person wants to retry). Never run `reset-lab.sh` mid-incident — it erases everyone's incident on that VM.

---

## 2. Model answer — P0 first move

**A strong first move** (answer key, one of several):

> **Command:** `kubectl --context k3d-mgmt -n argocd get applications -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,LAST-OP:.status.operationState.phase,CONDITIONS:.status.conditions[*].type'`
> **Possible results:** (a) one or two Applications unhealthy → probably Application-level faults in their own sources; (b) many unrelated Applications share one symptom → look at what they share (the repo-server, the cluster, a project); (c) Applications I don't recognize → a writer (a root or ApplicationSet) created them.

It partitions: it separates "one app" from "many", and "Argo CD" from "Kubernetes", in one screen — and it keeps working even if the Argo CD API is slow.

**A weak first move:** "Open `storefront-staging-workload` and read its error." It can only confirm a hunch about one tile.

**Wow moment (for the debrief):**

> "The best first question in an incident isn't 'what's broken?' It's 'what's the smallest number of things that could explain everything I'm seeing?'"

---

## 3. Model answer — P1 triage grid and layer coverage

### Triage grid (model, as a strong participant would write it at 0:25)

| # | Symptom (as observed) | Where observed | Step | Layer | Hypothesis | Planned controlled change |
|---|---|---|---|---|---|---|
| S1 | `argocd-repo-server` `0/1`, restarts climbing, `OOMKilled`, exit 137 | `kubectl -n argocd get pods`; `describe pod` | 5 | `PLAT` | Repo-server memory limit too low. If true, every render fails, and every `ComparisonError` mentioning port 8081 is a shadow of this | Path B: fix limits in `platform-config/argocd/values.yaml`, run `apply-argocd-config.sh`; verify pods `1/1`, restarts stable |
| S2 | `storefront-staging-workload`, `storefront-dev-workload`, `platform-root`, `team-root`: `ComparisonError` "dial tcp …:8081: connect: connection refused" | `argocd app get <app>` | 2 | `PLAT` (not `SRC`) | Shadow of S1 | Re-check after S1 |
| S3 | ApplicationSet `storefront`: `ErrorOccurred=True` "error retrieving Git files: … Unavailable" | ApplicationSet conditions | 5 | `PLAT` | Shadow of S1 | Re-check after S1 |
| S4 | Three unexpected Applications `storefront-{dev,staging,prod}-in-cluster`, `Unknown`/`Unknown`, `InvalidSpecError … do not match any of the allowed destinations in project 'storefront'` | Inventory vs §5.1; `argocd app get` | 1 | `GEN` | Something generated Applications for the management cluster; the AppProject is refusing them. If true, the ApplicationSet selector changed | Path A+C: fix the ApplicationSet in Git and apply; path D: delete the strays with a written cascade decision |
| S5 | Two unexpected Applications `team-root`, `platform-agent-dup`; `platform-agent` `OutOfSync` + `SharedResourceWarning` | Inventory; condition message | 3 | `GEN` | A second root created a duplicate child claiming the same Deployment | Path A: remove the extra root from Git; path D: delete leftovers without cascade |
| S6 | `storefront-prod-workload` `OutOfSync`, last op `Error`, `SyncError`; target `storefront-1.1.0` | `argocd app get`; `kubectl … custom-columns` | 1 | `RUN`? / `SRC`? | *Cannot tell yet.* Prod is pinned to a new tag; the last sync failed while the repo-server was down | Re-check after S1; read `argocd app diff` before any sync |
| S7 | `git log` shows five "teammate" commits across `storefront-gitops` and `platform-config` since the checkpoint | Section 6.3.1 loop | 1 | (evidence) | Each commit is a candidate cause; match them to S1–S6 | — |

**Layer coverage (model):**

| Layer | Evidence checked | Verdict |
|---|---|---|
| `PLAT` | `get pods`, `describe pod` | **Broken** — repo-server OOMKilled |
| `CONN` | `argocd cluster list` → `Successful`; `kubectl --context k3d-workload get nodes` → `Ready` | **Cannot tell yet** — `Successful` is a stale reading while comparisons use cache; no fresh write has been attempted |
| `SRC` | `git log`; `argocd repo list` → `Successful`; local `helm template` of each env | **Looks broken for staging** — local render of `envs/staging/values.yaml` fails "image.tag is required" (masked in Argo CD by `PLAT`) |
| `GEN` | Inventory; ownership columns | **Broken** — five unexpected Applications, a shared-resource warning |
| `POL` | Operation messages; `auth can-i` loop | **Cannot tell yet** — (a sharp participant finds `can-i create deployments.apps -n storefront-prod` → `no`) |
| `RUN` | Pods loop; `curl` | **Looks healthy for users** — every storefront namespace serves; prod serves `6.15.0` |

**The masking answer (model):** S1 must be confirmed and repaired first — if the repo-server can't render, every `SRC` and `GEN` observation is untrustworthy. `CONN` is the second blind spot, because every live-side observation depends on it.

---

## 4. Model answer — P2 repairs, fault by fault

Run this section live in the debrief. The order below is the verified order; Section 4.8 discusses alternatives.

Prepare a workspace exactly as the guide does (Section 5.4), then:

```bash
cd ~/capstone
for repo in storefront-gitops platform-config platform-components team-a-apps; do
  echo "=== ${repo} ==="; git -C "${repo}" log -n 5 --date=relative --format='%h  %ad  %an  %s'
done
```

**Expect** (verified):

```text
=== storefront-gitops ===
06084a6  3 minutes ago  teammate  prod: promote to storefront-1.1.0
823914f  3 minutes ago  teammate  staging: drop stale image.tag pin (values cleanup)
cbeba81  13 hours ago  student  checkpoint CP-baseline
=== platform-config ===
901a85c  3 minutes ago  teammate  argocd: right-size repo-server memory
478a4b8  3 minutes ago  teammate  platform: add team-root app-of-apps
6c4c241  3 minutes ago  teammate  storefront appset: simplify cluster selector
fe95ccd  13 hours ago  student  checkpoint CP-capstone
=== platform-components ===
da6c897  13 hours ago  student  checkpoint CP-baseline
=== team-a-apps ===
14104c8  13 hours ago  student  checkpoint CP-baseline
```

**Say:**

> "Five commits by the same person on a Friday afternoon, across two repositories. Every one of them has a reasonable-sounding message. 'Cleanup.' 'Simplify.' 'Right-size.' None of them says 'break production'. That's what real incidents look like."

---

### 4.1 Fault A — the repo-server under memory pressure (F7 · `PLAT`)

**Evidence:**

```bash
kubectl --context k3d-mgmt -n argocd get pods
kubectl --context k3d-mgmt -n argocd describe pod <argocd-repo-server-pod> | grep -E "State:|Reason:|Exit Code:|Restart Count:|memory:"
```

**Expect** (verified):

```text
argocd-repo-server-dd7b8b6c4-hrwjv                  1/1     Running   2 (34s ago)   2m5s
deployment.apps/argocd-repo-server                 0/1     1            0           2d1h

    State:          Terminated
      Reason:       OOMKilled
      Exit Code:    137
    Last State:     Terminated
      Reason:       OOMKilled
```

Staging, dev, `platform-root`, and `team-root` all show:

```text
ComparisonError: Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing: dial tcp 10.43.60.19:8081: connect: connection refused"
```

**Say:** "Port 8081. Which component listens there?" *(The repo-server.)* "So is this four broken applications, or one broken component?"

**Owner:** the `repoServer.resources` block in `platform-config/argocd/values.yaml`, applied by `apply-argocd-config.sh` → **path B**.

**Change:**

```bash
cd ~/capstone/platform-config
git show 901a85c -- argocd/values.yaml | grep -E '^[-+] +memory'
git revert --no-edit 901a85c && git push
apply-argocd-config.sh
```

**Expect** (verified — the wrapper took 20 seconds):

```text
-      memory: 128Mi
+      memory: 24Mi
-      memory: 512Mi
+      memory: 32Mi

==> Applying Argo CD configuration (chart 10.8.4, v3.5.2)
  ok values source: platform-config main (Gitea 9a41833)
  ok account passwords unchanged: reusing the live hashes (existing logins stay valid)
  ok Argo CD release applied
  ok argocd-server and argocd-repo-server are ready
```

**Verify** (verified): `argocd-repo-server-… 1/1 Running 0`, still `0` restarts 60 seconds later; live limits `{"cpu":"500m","memory":"512Mi"}`.

**Say — about the teammate's diff:**

> "Run `git show` on that commit without the `grep`. The real change is two lines. The diff is sixteen — it also deleted every blank line in the file. A noisy diff is how a dangerous two-line change gets approved. Read diffs with your eyes open, or better, have CI render them."

**What changed on screen (re-triage):** `platform-root`, `team-root`, and `storefront-dev-workload` went back to `Synced`. **Staging did not** — its error changed:

```text
ComparisonError: ... failed to execute helm template command: ... execution error at (storefront/templates/deployment.yaml:12:14): image.tag is required (set it in envs/<env>/values.yaml)
```

**Wow moment:**

> "We fixed one component and a different error appeared underneath it. That's masking. The repo-server outage wasn't staging's problem — it was hiding staging's problem. When the application evidence looks fine but the application is wrong, look at the thing doing the looking."

**If it goes sideways:** the ApplicationSet may still report `ErrorOccurred` for up to three minutes — its controller re-reads Git on a 3-minute schedule (`requeueAfter=3m0s`). Confirm with `argocd appset generate`, which reads Git immediately.

---

### 4.2 Fault B — staging can't render (F1 · `SRC`)

**Evidence** (a second opinion that doesn't depend on Argo CD):

```bash
cd ~/capstone/storefront-gitops
helm template storefront charts/storefront -f envs/staging/values.yaml > /tmp/render-staging.yaml && echo "render OK"
git show 823914f
```

**Expect** (verified):

```text
Error: execution error at (storefront/templates/deployment.yaml:12:14): image.tag is required (set it in envs/<env>/values.yaml)
```

```diff
 image:
-  tag: "6.15.0"
+  tag: ""
```

**Owner:** `envs/staging/values.yaml` in `storefront-gitops` → **path A**.

**Change and verify** (verified — staging returned to `Synced`/`Healthy` immediately, because the live Deployment already matched `6.15.0`; no sync was needed):

```bash
git revert --no-edit 823914f && git push
helm template storefront charts/storefront -f envs/staging/values.yaml >/dev/null && echo "render OK"
argocd app get storefront-staging-workload --refresh | grep -E "Sync Status|Health Status"
```

**Wow moment:**

> "The chart's author left a tripwire: `required`. Without it, a blank tag would have rendered `podinfo:` — and deployed whatever 'latest' happened to be. The chart failed loudly, at render time, before anything touched the cluster. That's the Lab 4 lesson again, in Helm: fail sooner, fail louder, fail safer."

---

### 4.3 Fault C — the workload credential is stale (F5 · `CONN`)

**The hard part is noticing.** Verified: `argocd cluster list` and `argocd cluster get workload` kept reporting `Successful` for the entire incident, and Applications on the workload cluster kept showing plausible statuses. Argo CD's controller keeps a live, already-authenticated watch on the cluster, so read-only comparisons continued to work from cache.

**Evidence that exists** — the first moment Argo CD had to make a *fresh* call to the workload cluster (here, `platform-agent` trying to sync while two Applications fought over its Deployment):

```bash
argocd app get platform-agent --show-operation | grep -E "Phase|Message"
kubectl --context k3d-mgmt -n argocd logs statefulset/argocd-application-controller --since=10m | grep -i unauthorized | tail -3
```

**Expect** (verified):

```text
level=info msg="Updating operation state. phase: Running -> Failed, message: 'Retrying operation. Attempt #3' -> 'one or more synchronization tasks are not valid: failed to discover server resources for group version apps/v1: Unauthorized'" application=platform-agent
level=info msg="Adding resource result, status: 'SyncFailed', phase: '', message: 'failed to discover server resources for group version apps/v1: Unauthorized'" application=platform-agent kind=Deployment name=platform-agent namespace=platform-system
```

**Say:**

> "`Unauthorized`. Not `forbidden`. What's the difference?"

**Answer key:** `Unauthorized` is a **401** — the workload API server doesn't accept the credential at all ("I don't know who you are"). `forbidden` is a **403** — it knows who you are and refuses the action. A 401 lives in `CONN` (the credential); a 403 lives in `POL` (the permissions). Same red badge, different layer, different fix.

**Owner:** the `cluster-workload` Secret in `argocd`, applied by the platform team from a template → **path C**, exactly the Lab 2 procedure.

**Change** (verified):

```bash
cd ~/capstone/platform-config
TOKEN="$(kubectl --context k3d-workload -n argocd-access get secret argocd-manager-token -o jsonpath='{.data.token}' | base64 -d)"
CA="$(kubectl --context k3d-workload -n argocd-access get secret argocd-manager-token -o jsonpath='{.data.ca\.crt}')"
sed -e "s|<TOKEN>|${TOKEN}|" -e "s|<CA_DATA>|${CA}|" clusters/workload.secret.template.yaml \
  | kubectl --context k3d-mgmt apply -f -
unset TOKEN CA
```

**Verify:** `argocd cluster get workload` shows a fresh `attemptedAt` with `Successful`; after the next write attempt, no operation message contains `Unauthorized`. (`capstone-check` area "workload cluster connectivity" turned `resolved`.)

**What changed on screen:** within a minute, **three Applications turned `Unknown`/`Missing`** — `storefront-prod-workload`, `platform-quotas`, `platform-netpol`. Re-registering the cluster rebuilt Argo CD's cache with a fresh list call, and that revealed Fault F. Log it as "revealed after C3".

**Wow moment:**

> "The Clusters page said 'Successful' for the whole incident. It was telling the truth about the last thing it measured — an old, still-open connection. 'Successful' is a measurement with a timestamp, not a guarantee. You met that sentence on Day 1. Today it cost you twenty minutes."

---

### 4.4 Fault D — the ApplicationSet's blast radius (F2 · `GEN`)

**Evidence:**

```bash
cd ~/capstone/platform-config
argocd appset generate applicationsets/storefront.yaml -o wide | awk '{print $1, $2, $3}'
argocd app get storefront-prod-in-cluster | grep -A2 CONDITION
git show 6c4c241
```

**Expect** (verified):

```text
NAME CLUSTER NAMESPACE
argocd/storefront-dev-workload https://k3d-workload-server-0:6443 storefront-dev
argocd/storefront-prod-workload https://k3d-workload-server-0:6443 storefront-prod
argocd/storefront-staging-workload https://k3d-workload-server-0:6443 storefront-staging
argocd/storefront-dev-in-cluster https://kubernetes.default.svc storefront-dev
argocd/storefront-prod-in-cluster https://kubernetes.default.svc storefront-prod
argocd/storefront-staging-in-cluster https://kubernetes.default.svc storefront-staging

CONDITION         MESSAGE
InvalidSpecError  application destination server 'https://kubernetes.default.svc' and namespace 'storefront-prod' do not match any of the allowed destinations in project 'storefront'
```

```diff
               selector:
-                matchLabels:
-                  cluster-role: workload
+                matchLabels: {}
```

**Say:** "Two guardrails just worked, and one didn't. Which?"

**Answer key:**

- **Worked:** the AppProject refused the three strays (they deployed nothing — this is the "AppProject denial" half of outline item CF4), and `applicationsSync: create-update` means nothing will be *deleted* when we fix the selector.
- **Didn't exist:** a preview in CI. Six rows instead of three would have failed a pull request.

**Owner:** `applicationsets/storefront.yaml` in `platform-config` — but the live object is **applied**, not reconciled from Git. So the fix is **path A** (commit) **and path C** (apply). The strays need **path D**.

**Change** (verified):

```bash
git revert --no-edit 6c4c241 && git push
argocd appset generate applicationsets/storefront.yaml -o wide | awk '{print $1}'   # preview BEFORE applying: 3 rows
kubectl --context k3d-mgmt apply -f applicationsets/storefront.yaml
kubectl --context k3d-mgmt -n argocd get applications -o custom-columns='NAME:.metadata.name,FINALIZERS:.metadata.finalizers,DEST:.spec.destination.server' | grep in-cluster
```

**Expect** (verified — the strays **remain** after the apply, with no finalizers):

```text
storefront-dev-in-cluster       <none>       https://kubernetes.default.svc
storefront-prod-in-cluster      <none>       https://kubernetes.default.svc
storefront-staging-in-cluster   <none>       https://kubernetes.default.svc
```

**Written cascade decision (model):** "Delete the three `*-in-cluster` Applications with `--cascade=false`. They were refused by the AppProject, so they manage no resources; non-cascading guarantees nothing on the management cluster is touched."

```bash
for e in dev staging prod; do argocd app delete storefront-$e-in-cluster --cascade=false; done
```

**Expect** (verified): three `application '…' deleted` lines; no `in-cluster` Applications remain.

**Wrong turn:** reverting the commit and waiting. **Nothing happens** — nothing reconciles the ApplicationSet object from Git. "Which change path owns an object that the platform team applies?"

**Wow moment:**

> "A two-line 'simplification' pointed the storefront at the management cluster — the cluster that holds the keys to every other cluster. The project fence stopped it from deploying. The deletion policy stopped the fix from deleting production. Two guardrails you built in Labs 4 and 5 just earned their keep, on a Monday, with nobody watching."

---

### 4.5 Fault E — two roots claim one Deployment (F3 · `GEN` ownership)

**Evidence:**

```bash
argocd app get platform-agent | sed -n '/CONDITION/,/^$/p'
for i in 1 2 3; do
  kubectl --context k3d-workload -n platform-system get deploy platform-agent \
    -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}{"\n"}'; sleep 10
done
kubectl --context k3d-mgmt -n argocd get applications team-root platform-agent-dup \
  -o custom-columns='NAME:.metadata.name,FINALIZERS:.metadata.finalizers,TRACKED-BY:.metadata.annotations.argocd\.argoproj\.io/tracking-id'
```

**Expect** (verified):

```text
CONDITION              MESSAGE
SharedResourceWarning  Deployment/platform-agent is part of applications argocd/platform-agent and platform-agent-dup

platform-agent-dup:apps/Deployment:platform-system/platform-agent
platform-agent-dup:apps/Deployment:platform-system/platform-agent
platform-agent-dup:apps/Deployment:platform-system/platform-agent

NAME                 FINALIZERS   TRACKED-BY
team-root            <none>       platform-root:argoproj.io/Application:argocd/team-root
platform-agent-dup   <none>       team-root:argoproj.io/Application:argocd/platform-agent-dup
```

**Say:** "The live Deployment is signed by `platform-agent-dup`. The `platform-agent` Application thinks it owns it. Trace up: who wrote `platform-agent-dup`? And who wrote *that*?"

**Answer key:** `team-root` wrote `platform-agent-dup`; `platform-root` wrote `team-root`, from `apps/team-root.yaml` in `platform-config`. The owner of the problem is a **file in Git** two levels above the symptom.

**Owner:** `platform-config` → `apps/team-root.yaml` and `team-root/` → **path A**; the orphan → **path D**.

**Change** (verified — order matters):

```bash
cd ~/capstone/platform-config
git revert --no-edit 478a4b8 && git push
argocd app get platform-root --refresh >/dev/null
kubectl --context k3d-mgmt -n argocd get application team-root platform-agent-dup
```

**Expect** (verified — `platform-root` pruned `team-root` within 3 seconds; its sync result lists `"name":"team-root","status":"Pruned"`), but **`platform-agent-dup` is still there** — `team-root` had no finalizer, so deleting it did not cascade to its child.

**Written cascade decision (model):** "Delete `platform-agent-dup` with `--cascade=false`. It shares the live `platform-agent` Deployment with the real child; a cascading delete would delete that shared Deployment."

```bash
argocd app delete platform-agent-dup --cascade=false
kubectl --context k3d-workload -n platform-system get deploy platform-agent
```

**Expect** (verified): the Deployment survives (`1/1`). About 25 seconds later `platform-agent` is `Synced`/`Healthy` with no conditions, and the live tracking annotation reads `platform-agent:apps/Deployment:platform-system/platform-agent`.

**Wrong turns — and why the order matters:**

- **Deleting `platform-agent-dup` first, while `team-root` still exists:** `team-root` has automated self-heal and recreates it. The environment's own revert script records this behavior ("deleting the child first simply let the root recreate it"). *If your fix reverted, you fixed the wrong layer.*
- **`argocd app delete platform-agent-dup` with the default (cascading):** the CLI asks Argo CD to delete every resource that Application manages — including the Deployment the real `platform-agent` depends on. (Not executed in rehearsal, deliberately; this follows the delete-path behavior verified in Lab 5.)

**Wow moment:**

> "Two Applications, both reporting success, both enforcing their own view of the same object. That's the GitOps version of two `terraform apply`s against one state file. Ownership must be a partition, not an overlap — and the most dangerous command in this whole fault was a delete with the default flags."

---

### 4.6 Fault F — Kubernetes RBAC in production (F4 · `POL`)

**Evidence** (revealed after the Fault C repair):

```bash
for a in storefront-prod-workload platform-quotas platform-netpol; do
  echo "$a: $(kubectl --context k3d-mgmt -n argocd get application $a -o jsonpath='{.status.conditions[0].message}')"
done
AS=system:serviceaccount:argocd-access:argocd-manager
kubectl --context k3d-workload auth can-i get services -n storefront-prod --as=$AS
kubectl --context k3d-workload auth can-i get services -n storefront-staging --as=$AS
kubectl --context k3d-workload -n storefront-prod get roles,rolebindings
```

**Expect** (verified):

```text
storefront-prod-workload: Failed to load live state: failed to get managed objects: unexpected error getting managed object: services "storefront" is forbidden: User "system:serviceaccount:argocd-access:argocd-manager" cannot get resource "services" in API group "" in the namespace "storefront-prod"
platform-quotas: Failed to load live state: ... limitranges "storefront-limits" is forbidden: ... cannot get resource "limitranges" in API group "" in the namespace "storefront-prod"
platform-netpol: Failed to load live state: ... networkpolicies.networking.k8s.io "default-deny" is forbidden: ... cannot get resource "networkpolicies" in API group "networking.k8s.io" in the namespace "storefront-prod"
no
yes
NAME                                             CREATED AT
role.rbac.authorization.k8s.io/argocd-deployer   2026-09-13T04:36:39Z
```

**Say:** "Three Applications, three different resource kinds, one namespace. What do they share?" *(`storefront-prod`.)* "The Role is there. What's missing?" *(The RoleBinding.)*

**Answer key:** `forbidden` naming `system:serviceaccount:argocd-access:argocd-manager` is **fence 3, Kubernetes RBAC**, even though it arrived as a `ComparisonError` rather than a failed sync — the RoleBinding carried the read verbs too, so Argo CD couldn't even *look* at prod.

**Owner:** the least-privilege design file on the workload cluster → **path C**.

**Change** (verified — only the missing RoleBinding was created, and the token did not change):

```bash
kubectl --context k3d-workload apply -f ~/course/lab-files/lab-02/workload-rbac.yaml | grep -v unchanged
kubectl --context k3d-workload auth can-i create deployments.apps -n storefront-prod --as=$AS
```

```text
rolebinding.rbac.authorization.k8s.io/argocd-deployer created
yes
```

`platform-quotas` and `platform-netpol` returned to `Synced`/`Healthy` immediately.

**Then rebuild the cluster cache — do not skip this if Fault C was repaired first.** The cache was rebuilt at the Fault C repair while `storefront-prod` was still unreadable, and restoring the RoleBinding does not rebuild it. Verified consequence: `storefront-prod-workload`'s resource rows all stayed `Unknown`, Argo CD stopped seeing changes in that namespace, and the verifier later reported a false "all resolved" (Section 4.7). Rebuild it now with the API call shown in Section 4.7, then confirm prod's rows show real statuses:

```bash
argocd app get storefront-prod-workload | sed -n '/^GROUP/,$p'
```

**Expect:** `Synced` / `OutOfSync` in the STATUS column — not `Unknown`.

**Wow moment:**

> "This fault was invisible for most of the incident — not because it was subtle, but because a broken credential stood in front of it. Until Argo CD could authenticate, it couldn't discover that it wasn't authorized. 401 hides 403."

---

### 4.7 Fault G — a bad release pinned to production (F6 · `RUN` + noisy drift)

**Evidence:**

```bash
argocd app get storefront-prod-workload | grep -E "Target|Sync Status|Health Status"
kubectl --context k3d-mgmt -n argocd logs statefulset/argocd-application-controller --since=5m | grep "application=storefront-prod-workload" | grep -i "skipping auto-sync" | tail -1
cd ~/capstone/storefront-gitops
git show 06084a6
git diff storefront-1.0.0 storefront-1.1.0 -- charts/ | grep -E '^[-+] ' | grep -v '^[-+]$'
argocd app diff storefront-prod-workload | grep -E '^=====|path: /|minReplicas|maxReplicas'
```

**Expect** (verified):

```text
level=warning msg="Skipping auto-sync: failed previous sync attempt to [9711d80f877a9e34b635123fb495b57722f2af18] and will not retry for [9711d80f877a9e34b635123fb495b57722f2af18]" application=storefront-prod-workload
```

```diff
-targetRevision: storefront-1.0.0
+targetRevision: storefront-1.1.0
```

```text
-  readinessPath: /readyz
+  readinessPath: /not-ready
-  enabled: false
-  minReplicas: 2
+  enabled: true
+  minReplicas: 5

===== apps/Deployment storefront-prod/storefront ======
<             path: /readyz
>             path: /not-ready
===== autoscaling/HorizontalPodAutoscaler storefront-prod/storefront ======
>   maxReplicas: 5
>   minReplicas: 5
```

**Say:** "Prod is `OutOfSync`, and Argo CD has given up retrying. The guide's troubleshooting table says: make a deliberate sync. Who wants to press it?"

Let a volunteer argue for it. Then:

> "Read the diff first. What would that sync deploy?"

**Answer key:** the teammate's `storefront-1.1.0` release — a readiness probe on a path that doesn't exist, and an autoscaler that forces five replicas while the chart still renders two. Prod users are currently fine (`curl` → `"version": "6.15.0"`, `"message": "storefront PROD"`). Syncing would make things worse.

#### What happens if someone does press Sync — verified, so you can describe it

```text
Operation:          Sync
Sync Revision:      9711d80f877a9e34b635123fb495b57722f2af18
Phase:              Succeeded
Duration:           36s

t=0s    app=Synced/Progressing   deploy spec=2  ready=2/3  hpa min=5
t=18s   app=Synced/Progressing   deploy spec=5  ready=2/7  (HPA scaled the Deployment to 5)
t=117s  app=OutOfSync/Degraded   op=Running   (self-heal pushing replicas back toward Git's 2)
t=123s  app=Synced/Progressing   hpa current=2
t=136s  app=Synced/Progressing   hpa current=5
```

```text
Warning   Unhealthy   pod/storefront-64b48b8d4f-hgw4x   Readiness probe failed: HTTP probe failed with statuscode: 404
Progressing=False ProgressDeadlineExceeded: ReplicaSet "storefront-64b48b8d4f" has timed out progressing.
level=info msg="Initiated automated sync to '9711d80f877a9e34b635123fb495b57722f2af18'" application=storefront-prod-workload
```

The new ReplicaSet never had a Ready Pod; the old ReplicaSet kept serving (`curl` still returned `6.15.0`), so users were never hurt. But the Application flipped between `Synced/Progressing` and `OutOfSync/Degraded`, and self-heal and the HPA fought over `spec.replicas` every couple of minutes — the "degraded workload combined with noisy drift" the outline describes.

**Wow moment:**

> "Look at who is fighting. The HPA writes `replicas: 5`. Git says 2. Self-heal writes 2 back. The HPA writes 5 again. Nobody is wrong, and the badge will never settle. Every field has one rightful writer — and this chart gave `spec.replicas` two."

#### The repair

**Owner:** the prod pin in `envs/prod/config.yaml` (`storefront-gitops`), read by the ApplicationSet → **path A**.

**Change:**

```bash
cd ~/capstone/storefront-gitops
git revert --no-edit 06084a6 && git push
argocd appset generate ~/capstone/platform-config/applicationsets/storefront.yaml -o wide | awk '/prod/ {print $1, $NF}'
```

**Expect** (verified): the commit is one line. The *live* ApplicationSet picked up the new pin on its own — **31 seconds** after the push in rehearsal (allow up to 3 minutes; a preview run in the same second as the push may still show `storefront-1.1.0`). Then automated sync moved prod back:

```text
t=0s    target=storefront-1.1.0  Synced/Progressing    op=Succeeded  hpa=present  replicas=5 ready=4/7
t=31s   target=storefront-1.0.0  OutOfSync/Progressing op=Running    hpa=present  replicas=5 ready=4/7
t=87s   target=storefront-1.0.0  OutOfSync/Progressing op=Succeeded  hpa=present  replicas=2 ready=2/2
t=210s  target=storefront-1.0.0  Synced/Healthy        op=Succeeded  hpa=present  replicas=5 ready=5/5
```

```text
4       2026-09-13 02:08:33 -0400 EDT  storefront-1.0.0 (cbeba81)
"version": "6.15.0"
"message": "storefront PROD"
```

**If nobody pressed the trap sync,** that's the end of Fault G: no HPA ever existed, and prod settles on `storefront-1.0.0`.

#### ⚠ If someone did press it: the leftover HPA, and a false green you must know about

Look at the last line of the timeline: `Synced/Healthy` — with the HPA **still present** and **5 replicas** (Git says 2). Verified over the next six minutes: every ~90 seconds self-heal set replicas to 2 and the HPA set them back to 5, while `storefront-prod-workload` reported `Synced`/`Healthy` almost continuously.

And **`capstone-check.sh` reported all six areas `resolved` (exit code 0), and the P3 inventory showed all eight Applications `Synced`/`Healthy`, stable across two minutes.** Every completion criterion in the participant guide passed — on a platform that was still fighting itself.

**Why:** Argo CD's cached view of the workload cluster was rebuilt when Fault C (the credential) was repaired — *while Fault F (the missing RoleBinding) still blocked reads in `storefront-prod`*. Repairing Fault F afterwards did not rebuild that cache. So Argo CD was comparing `storefront-prod` against a stale, partial cache: it never saw the HPA it had created, so it never pruned it, and `argocd app diff` exited `0` while live replicas were 5.

**The visible clue:** the application-level badges look fine, but **every resource row in the tree says `Unknown`**:

```text
$ argocd app get storefront-prod-workload
Sync Status:        Synced to storefront-1.0.0 (cbeba81)
Health Status:      Healthy

GROUP  KIND        NAMESPACE        NAME                  STATUS   HEALTH  HOOK  MESSAGE
       ConfigMap   storefront-prod  storefront            Unknown                configmap/storefront unchanged
       Service     storefront-prod  storefront            Unknown                service/storefront unchanged
apps   Deployment  storefront-prod  storefront            Unknown                deployment.apps/storefront configured
batch  Job         storefront-prod  storefront-migration  Unknown
```

**The fix — rebuild the cluster cache** (verified; it changes neither Git nor the cluster, so log it like a hard refresh). `argocd` v3.5.2 has no CLI subcommand for this, so call the API with the CLI's own session token, without printing it:

```bash
ARGOCD_TOKEN="$(yq '.users[] | select(.name == "localhost:8443") | ."auth-token"' ~/.config/argocd/config)"
curl -sk -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" -d '{}' \
  "https://localhost:8443/api/v1/clusters/https%3A%2F%2Fk3d-workload-server-0%3A6443/invalidate-cache"
unset ARGOCD_TOKEN
```

**Expect** (verified): `200`, and within **4 seconds**:

```text
level=info msg="Invalidated cluster" server="https://k3d-workload-server-0:6443"
level=info msg="Adding resource result, status: 'Pruned', phase: 'Succeeded', message: 'pruned'" application=storefront-prod-workload kind=HorizontalPodAutoscaler name=storefront namespace=storefront-prod
```

```text
Sync Status:        Synced to storefront-1.0.0 (cbeba81)
Health Status:      Healthy

GROUP        KIND                     NAMESPACE        NAME                  STATUS     HEALTH   HOOK  MESSAGE
autoscaling  HorizontalPodAutoscaler  storefront-prod  storefront            Succeeded  Pruned         pruned
apps         Deployment               storefront-prod  storefront            Synced     Healthy        deployment.apps/storefront configured
             ConfigMap                storefront-prod  storefront            Synced
             Service                  storefront-prod  storefront            Synced     Healthy
```

Replicas then held at `2` across two minutes (verified).

**Two things that did *not* work** (verified, so you don't waste time live): re-applying the unchanged `cluster-workload` Secret, and adding an annotation to it. Neither rebuilt the cache. A malformed API call (no JSON body) returns HTTP `415`.

**Recommendation:** make the cache rebuild part of the Fault F repair whenever Fault C was repaired first — see Section 4.6.

**Wow moment:**

> "Every check in the guide said we were done. The tool said resolved. Eight green tiles, stable for two minutes. And prod was still scaling itself up and down every ninety seconds. When the application evidence looks fine but the application is wrong, look at the thing doing the looking — and when every row in the tree says `Unknown`, the thing doing the looking is blind."

**Wrong turns:**

- **Adding `ignoreDifferences` for `/spec/replicas` to make the `OutOfSync` stop.** On the bad release it hides the noise and leaves prod `Degraded` — the rules of engagement call this hiding evidence. It is only a legitimate *design* change when an HPA is intended, with the HPA named as the field's owner, or better, when the chart stops rendering `replicas` while the HPA is enabled.
- **Deleting the `storefront-1.1.0` tag.** Tags are how humans pin; rewriting them destroys the audit trail. Leave the tag, move the pin.

---

### 4.8 Other valid repair orders

The guide deliberately gives no fixed order. Accept any order that respects masking, and discuss these consequences in the debrief:

| If a participant… | They will see |
|---|---|
| Starts with F1 (staging) before F7 | No change — every render still fails at the repo-server. A good participant notices the error mentions port 8081 and moves to `PLAT` |
| Fixes F5 before F2/F3 | F4's `forbidden` surfaces sooner; otherwise the same |
| Reverts F6 before fixing F4 | The prod sync to `storefront-1.0.0` needs write access in `storefront-prod`, so F4 appears as a sync-time `forbidden` instead — arguably the cleaner way to meet F4 |
| Fixes F4 before F5 | The RoleBinding is restored, but nothing visibly improves — the credential is still stale |

---

## 5. P3 — verification (model)

### 5.1 The course verifier

**Do:**

```bash
capstone-check.sh
echo "exit code: $?"
```

**Expect** (verified, after all seven repairs and the cache rebuild):

```text
==> Capstone restoration status by area
  resolved   argo cd platform components
  resolved   workload cluster connectivity
  resolved   application source rendering
  resolved   application generation and ownership
  resolved   deployment policy (permissions)
  resolved   workload runtime health

  ok all areas resolved
exit code: 0
```

### 5.2 The inventory, twice, two minutes apart

```bash
kubectl --context k3d-mgmt -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project,SYNC:.status.sync.status,HEALTH:.status.health.status,LAST-OP:.status.operationState.phase,CONDITIONS:.status.conditions[*].type'
```

**Expect** (verified — identical on both readings):

```text
NAME                          PROJECT      SYNC     HEALTH    LAST-OP     CONDITIONS
platform-agent                platform     Synced   Healthy   Succeeded   <none>
platform-netpol               platform     Synced   Healthy   Succeeded   <none>
platform-quotas               platform     Synced   Healthy   Succeeded   <none>
platform-root                 platform     Synced   Healthy   Succeeded   <none>
storefront-dev-workload       storefront   Synced   Healthy   Succeeded   <none>
storefront-prod-workload      storefront   Synced   Healthy   Succeeded   <none>
storefront-staging-workload   storefront   Synced   Healthy   Succeeded   <none>
team-a-guestbook              team-a       Synced   Healthy   Succeeded   <none>
```

`argocd cluster list` shows `workload` `Successful` at `https://k3d-workload-server-0:6443`. (The participant guide's Figures SS-CAP-01, SS-CAP-02, and SS-CAP-03 have capture specifications but **no image files in `assets/screenshots/day-2/` yet** — if a participant asks why the pictures are missing, that's why. Use the CLI output above as the reference.)

### 5.3 Two more checks — because 5.1 and 5.2 can both pass on a broken platform

**Verified in rehearsal:** with a stale cluster cache and a leftover HPA fighting self-heal (Section 4.7), `capstone-check.sh` returned **exit 0** and the 5.2 inventory was **identical to the table above** for two full minutes. The verifier reports *whether each area looks green*, and a blind comparison looks green.

Before you — or a participant — declares the incident over:

**Do (1) — no resource Argo CD manages should have status `Unknown`:**

```bash
for a in $(kubectl --context k3d-mgmt -n argocd get applications -o jsonpath='{.items[*].metadata.name}'); do
  n=$(kubectl --context k3d-mgmt -n argocd get application "$a" \
        -o jsonpath='{range .status.resources[*]}{.status}{"\n"}{end}' | grep -c '^Unknown$')
  [ "$n" != "0" ] && echo "$a: $n resource(s) with status Unknown"
done
```

**Expect:** no output. (Verified: during the false green, every prod resource was `Unknown`; after the cache rebuild, none were. One reading showed a transient `team-a-guestbook: 2 resource(s) with status Unknown` that cleared on the next reading — re-read before acting.)

**Do (2) — the workload matches Git, not only the badge:**

```bash
kubectl --context k3d-workload -n storefront-prod get deploy storefront -o jsonpath='replicas={.spec.replicas} ready={.status.readyReplicas}{"\n"}'
kubectl --context k3d-workload -n storefront-prod get hpa
```

**Expect** (verified): `replicas=2 ready=2`, and `No resources found in storefront-prod namespace.` Read the replica count twice, two minutes apart.

**Model sentence for the participant's log** (when the tool and their own sanity checks disagree):

> "`capstone-check` reported every area resolved, but prod's resources all showed `Unknown` and the replica count changed between readings, so the comparison itself was untrustworthy; after rebuilding the cluster cache, the leftover HPA was pruned and every check agreed."

**Wow moment:**

> "The scoreboard said we won. The scoreboard was reading from a camera that had been pointing at an old picture for thirty minutes. A green verifier is a measurement too — ask what it measured, and when."

---

## 6. P4 — model reflection

Use these as the answer key when you confirm layer assignments. A participant's wording will differ; check that each block names **a concrete setting or signal, its owner, and when it would fire**.

### Fault A: repo-server starved of memory

- **Symptom rows:** S1, S2, S3
- **Layer:** `PLAT` · **Method step:** 5
- **Root cause:** a values change lowered the repo-server's memory limit below its start-up footprint, so it was OOMKilled on every start and nothing could render.
- **Evidence:** `describe pod` → `Last State: Terminated, Reason: OOMKilled, Exit Code: 137`; every `ComparisonError` named port 8081.
- **Change:** `git revert 901a85c` in `platform-config`, then `apply-argocd-config.sh` (path B).
- **Verified by:** repo-server `1/1`, restart count stable across two readings.
- **Masked:** Faults B, D (its ApplicationSet error), and E.
- **Guardrail:** treat Argo CD's own configuration as a release — render the Helm upgrade in CI and require a second reviewer for `argocd/values.yaml`; set a policy floor for component resource limits. Owner: platform team.
- **Signal:** `kube_pod_container_status_restarts_total` for `argocd-repo-server` increasing by ≥3 in 10 minutes; plus an alert when `argocd_app_info` shows many Applications with the same `ComparisonError` at once.

### Fault B: staging image tag blanked

- **Symptom rows:** staging `ComparisonError` (revealed after Fault A)
- **Layer:** `SRC` · **Method step:** 2
- **Root cause:** a "cleanup" commit set `image.tag: ""` in `envs/staging/values.yaml`; the chart's `required` check refused to render.
- **Evidence:** local `helm template` → `image.tag is required`; `git show 823914f`.
- **Change:** `git revert 823914f` (path A).
- **Verified by:** staging `Synced`/`Healthy`, no conditions.
- **Masked by:** Fault A.
- **Guardrail:** a CI job that runs `helm template` for every environment on every pull request (the stretch script). Owner: storefront team.
- **Signal:** notification trigger `on-sync-status-unknown`, or `argocd_app_info{sync_status="Unknown"}` for more than 10 minutes.

### Fault C: stale workload credential

- **Symptom rows:** `Unauthorized` in `platform-agent`'s sync message and the controller log
- **Layer:** `CONN` · **Method step:** 3 (the live side of every comparison)
- **Root cause:** the workload ServiceAccount's token changed; the `cluster-workload` Secret still held the old one.
- **Evidence:** `failed to discover server resources for group version apps/v1: Unauthorized` (401), while the Clusters page still read `Successful`.
- **Change:** re-rendered and applied `cluster-workload` from the template with the live token and CA (path C).
- **Verified by:** fresh `attemptedAt` on `argocd cluster get workload`; subsequent syncs to the workload cluster succeeded.
- **Masked:** Fault F.
- **Guardrail:** manage cluster credentials declaratively with rotation that updates both sides together (or short-lived credentials issued by an external secret manager). Owner: platform team.
- **Signal:** an alert on sync operations or controller log lines containing `Unauthorized` for any registered cluster. *Note:* the Clusters page — Argo CD's own connection measurement — read `Successful` throughout this fault, so an alert on connection status alone may well not have fired. (The `argocd_cluster_connection_status` metric itself was not sampled during the fault; it read `1` for both clusters after restoration.)

### Fault D: ApplicationSet selector emptied

- **Symptom rows:** S4
- **Layer:** `GEN` · **Method step:** 1 (the Application inventory) and 5 (the ApplicationSet controller)
- **Root cause:** `matchLabels: {}` matched both clusters, generating three Applications for the management cluster.
- **Evidence:** `argocd appset generate` → six rows; `InvalidSpecError` on the three strays.
- **Change:** `git revert 6c4c241` + `kubectl apply` (paths A and C); deleted the strays with `--cascade=false` (path D).
- **Verified by:** preview shows three names; inventory matches §5.1.
- **Guardrails that held:** AppProject destinations; `applicationsSync: create-update`.
- **Guardrail to add:** preview in CI with an allow-list of generated names (the stretch script), and reconcile the ApplicationSet object itself from Git so the applied object can't drift from the reviewed file. Owner: platform team.
- **Signal:** an alert when the number of Applications per ApplicationSet changes, or on any `InvalidSpecError` condition.

### Fault E: duplicate root claims a shared Deployment

- **Symptom rows:** S5
- **Layer:** `GEN` (ownership) · **Method step:** 3
- **Root cause:** a second root (`team-root`) generated `platform-agent-dup`, which deploys the same source into the same namespace as `platform-agent`.
- **Evidence:** `SharedResourceWarning`; the live tracking annotation named `platform-agent-dup`.
- **Change:** `git revert 478a4b8` (path A); `argocd app delete platform-agent-dup --cascade=false` (path D).
- **Verified by:** the Deployment survived; `platform-agent` `Synced`/`Healthy`, tracking annotation restored.
- **Guardrail:** `FailOnSharedResource=true` in the platform children's `syncOptions`, so a second owner's sync *fails* instead of taking over; code-owner review on `apps/`. Owner: platform team.
- **Signal:** alert on any `SharedResourceWarning` condition.

### Fault F: missing RoleBinding in production

- **Symptom rows:** `forbidden` on three Applications (revealed after Fault C)
- **Layer:** `POL` (Kubernetes RBAC, fence 3) · **Method step:** 3/4
- **Root cause:** the `argocd-deployer` RoleBinding in `storefront-prod` was deleted, removing Argo CD's read and write access in that namespace.
- **Evidence:** `cannot get resource "services" … in the namespace "storefront-prod"`; `auth can-i` → `no` in prod, `yes` in staging; Role present, RoleBinding absent.
- **Change:** re-applied `workload-rbac.yaml` (path C).
- **Verified by:** `auth can-i create deployments.apps -n storefront-prod` → `yes`; the three Applications recovered.
- **Masked by:** Fault C.
- **Guardrail:** manage workload-cluster RBAC from Git through a separate, reviewed pipeline (or an admission policy that protects `argocd-deployer` bindings). Owner: workload cluster administrators.
- **Signal:** Kubernetes audit log alert on deletion of RoleBindings whose subject is `argocd-manager`; Argo CD notification on any condition containing `forbidden`.

### Fault G: bad release promoted to production

- **Symptom rows:** S6
- **Layer:** `RUN` (health) plus diff noise · **Method step:** 1 (the pinned revision) and 4 (health)
- **Root cause:** prod was pinned to `storefront-1.1.0`, whose chart has a readiness path that never succeeds and an HPA that fights `spec.replicas`.
- **Evidence:** `git show 06084a6`; `git diff storefront-1.0.0 storefront-1.1.0`; `argocd app diff`.
- **Change:** `git revert 06084a6` (path A).
- **Verified by:** prod back on `storefront-1.0.0`, `Synced`/`Healthy` across two reconciliation cycles, no HPA.
- **Guardrail:** promotion to prod only through a reviewed pull request that must show the rendered-manifest diff and pass a staging soak; the chart should stop rendering `replicas` when `hpa.enabled`. Owner: storefront team (chart) and release managers (promotion).
- **Signal:** `argocd_app_info{health_status="Degraded"}` for 5 minutes on a prod Application; Deployment condition `ProgressDeadlineExceeded`; *not* a plain `OutOfSync` alert, which would have been noise.

### Closing questions — model answers

1. **Diagnosed more than once?** Staging: first it looked like a repo-server outage (Fault A was hiding Fault B). Prod: first a failed sync, then `forbidden`, then a bad release — three faults stacked on one tile.
2. **User impact vs loudness.**
   - *By user impact:* almost none of these hurt end users — prod served `6.15.0` throughout. *By platform impact:* C (no deployments possible to the workload cluster), A (no rendering anywhere), F (prod undeployable), E (one bad delete from losing the agent), G (one sync away from a degraded prod), B (staging undeployable), D (refused strays).
   - *By loudness in the UI:* D (three `Unknown`/`Unknown` tiles) and A (errors everywhere) were loudest; **C and F were close to invisible**.
   - The quietest faults were among the most dangerous.
3. **Did any fix revert?** Deleting `platform-agent-dup` before removing `team-root` would have — the root recreates it. Reverting the ApplicationSet commit without applying it "reverted" nothing at all.
4. **Stations:** A → 5; B → 2; C → 3; D → 1 and 5; E → 3; F → 3/4; G → 1 and 4.
5. **End where you started.** A broke *both* Day 1 questions at once — nothing could render, so neither "does it match Git?" nor "is it working?" could be answered honestly. C and F broke the layer beneath both (Argo CD couldn't see, or wasn't allowed to look). B and D failed "does it match Git?" (no valid desired state / refused spec). E made "does it match Git?" flap between two Gits. G passed "does it match Git?" and failed "is it working?" — the Day 1 `Synced` + `Degraded` quadrant, exactly.

---

## 7. Debrief script (20–30 minutes)

Run Section 4 live on your VM, one fault at a time, asking the room for the evidence before you show it.

**Opening — say:**

> "Hands up if you found the repo-server first." *(Count.)* "Hands up if you spent more than ten minutes on staging before you found the repo-server." *(Count again.)* "That second group just learned masking the expensive way. Let's walk it."

**Five questions that make it stick:**

1. "Which symptom did you diagnose twice — and what was hiding it?"
2. "What did the Clusters page say the whole time?" *(`Successful`.)* "Was it lying?"
3. "Who pressed Sync on prod? What happened? What did the diff say before you pressed it?"
4. "Two faults were refused by guardrails you built earlier in the course. Which ones, and which guardrails?" *(D: AppProject + `create-update`. E's cascade trap: the delete path from Lab 5.)*
5. "Name the one guardrail you'd put in place at work on Monday."

**The ending — say:**

> "On Day 1 morning you asked one application two questions: does it match Git, and is it working? Today, seven faults later, every single one of them was an answer to those same two questions — or it broke Argo CD's ability to ask them. One idea, two days, increasing depth."

> "An incident isn't over when it's green. It's over when you can name the guardrail that would have caught it. You just wrote seven. Pin that page."

---

## 8. Between cohorts

```bash
inject-capstone-faults.sh status --local
reset-lab.sh CP-capstone --local --yes         # reverts any remaining faults, then restores the checkpoint
reset-lab.sh CP-capstone --verify-only --local
```

**Expect** (verified, run after the rehearsal's own manual repairs, including the leftover-HPA case):

```text
==> 1/9 Revert any capstone faults
==> 2/9 Refresh CoreDNS host records
==> 3/9 Force every repo's main to cp-capstone
==> 4/9 Delete non-checkpoint ApplicationSets, then Applications
==> 5/9 Apply the checkpoint declarative bundle
==> 6/9 Reconcile workload-side RBAC
==> 7/9 Clean/recreate workload namespaces
==> 8/9 Apply Argo CD configuration
==> 9/9 Wait for expected statuses
PASS CP-capstone is in the expected state.

  ok no faults injected
```

`kubectl --context k3d-workload -n storefront-prod get hpa` → `No resources found in storefront-prod namespace.` (verified).

Three things to know:

- **Participants' repairs do not clear the fault markers.** `inject-capstone-faults.sh status` still lists every fault as injected after a perfect restoration. That's expected; the reset handles it.
- **The reset force-moves every repository's `main` back to `cp-capstone`,** which erases participants' revert commits. Tell people to copy `~/capstone/incident-log.md` somewhere safe *before* you reset.
- **The F5 pre-flight workaround (Section 0.2) is compatible with the reset** — verified.

---

## 9. Optional stretch challenges — model answers

### 9.1 An alert rule, written as code

**What was verified:** every metric name in the guide's catalogue exists on the live v3.5.2 components (Prometheus itself is not installed in the lab, so the rules below were *not* evaluated):

| Metric | Served by (port) | Verified labels / sample |
|---|---|---|
| `argocd_app_info` | application controller (8082) | `name`, `project`, `dest_namespace`, `dest_server`, `health_status`, `autosync_enabled`, `operation`, `repo`, … |
| `argocd_app_sync_total` | application controller (8082) | `name`, `project`, `dest_server`, `phase` (values seen: `Error`, `Succeeded`), `dry_run` |
| `argocd_app_reconcile` | application controller (8082) | histogram |
| `argocd_cluster_connection_status` | application controller (8082) | `server`, `k8s_version`; value `1` for both clusters after restoration |
| `argocd_repo_pending_request_total` | repo-server (8084) | present |
| `argocd_appset_info` | ApplicationSet controller (8080) | present (also `argocd_appset_owned_applications`, `argocd_appset_reconcile_*`) |

**Model answer:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-platform-guardrails
  namespace: argocd
spec:
  groups:
    - name: argocd.platform
      rules:
        - alert: ArgoCDProdApplicationDegraded
          expr: argocd_app_info{dest_namespace="storefront-prod", health_status="Degraded"} == 1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "{{ $labels.name }} has reported Degraded health in storefront-prod for 5 minutes."
            runbook: "argocd app get {{ $labels.name }} --show-operation, then read the Deployment's conditions and events on the workload cluster."
        - alert: ArgoCDSyncsFailing
          expr: increase(argocd_app_sync_total{phase=~"Error|Failed"}[15m]) > 0
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "{{ $labels.name }} has had failed or errored sync operations for 10 minutes."
            runbook: "argocd app get {{ $labels.name }} --show-operation; look for Unauthorized (credential), forbidden (Kubernetes RBAC), or hook failures."
```

**Why these `for:` durations:** a rollout legitimately passes through `Progressing`, and an operation can fail once and succeed on retry. Five and ten minutes fire on a failure to *converge*, not on a status that is briefly red.

**Say during the debrief:**

> "Notice what's *not* here: an alert on `OutOfSync`. It would have fired all weekend on noise, and everyone would have muted it by Tuesday. And notice the other thing: the Clusters page said `Successful` through the entire credential fault. Alert on the symptom that proves a problem — `Unauthorized` in a sync, a failed operation — not on the status that was wrong."

### 9.2 A pre-merge check (verified)

Completed script:

```bash
#!/usr/bin/env bash
# pre-merge-check.sh: run from ~/capstone. Exits non-zero if any check fails.
set -uo pipefail
fail=0

# Check 1: every environment's values render with the chart.
for env in dev staging prod; do
  if ! helm template storefront storefront-gitops/charts/storefront \
       -f "storefront-gitops/envs/${env}/values.yaml" >/dev/null 2>&1; then
    echo "FAIL render: ${env}"
    fail=1
  fi
done

# Check 2: the ApplicationSet generates only the names you allow.
allowed="storefront-dev-workload storefront-staging-workload storefront-prod-workload"
names="$(argocd appset generate platform-config/applicationsets/storefront.yaml -o wide 2>/dev/null \
  | awk 'NR > 1 { sub("^argocd/", "", $1); print $1 }')"
if [ -z "${names}" ]; then
  echo "FAIL appset: the preview produced no Applications (or it errored)"
  fail=1
fi
for name in ${names}; do
  case " ${allowed} " in
    *" ${name} "*) ;;
    *) echo "FAIL appset: unexpected Application ${name}"; fail=1 ;;
  esac
done

exit "${fail}"
```

**Verified results** (the faults were reproduced in the *local* clones only, never pushed):

| State of the working tree | Output | Exit |
|---|---|---|
| Repaired `main` | *(none)* | `0` |
| Fault D reproduced (`matchLabels: {}`) | `FAIL appset: unexpected Application storefront-dev-in-cluster` (and `…-prod-…`, `…-staging-…`) | `1` |
| Fault B reproduced (`image.tag: ""` in staging) | `FAIL render: staging` | `1` |

Two design points worth crediting in a participant's answer: the empty-preview check (Lab 4's "zero is a valid generator output" — a selector that matches nothing must also fail), and `2>/dev/null` on the preview so a failing preview can't dump generator parameters into CI logs (see the Lab 4 walkthrough's credential warning).

### 9.3 A policy, proven by a test

**Model answer for Fault D:** the allow-list in 9.2 *is* the policy, and its before/after output above is the proof — the same check passes on `main` and refuses a branch that reproduces the fault.

**Model answer for Fault E (not rehearsed):** add `FailOnSharedResource=true` to the `syncOptions` in `apps/platform-agent.yaml` and `apps/platform-netpol.yaml`/`apps/platform-quotas.yaml` on a local branch. The course tools can't unit-test it offline; the honest proof would be to apply the duplicate child in a scratch copy and show the second sync *fails* instead of taking ownership. Credit participants who say so rather than claiming an offline test.
