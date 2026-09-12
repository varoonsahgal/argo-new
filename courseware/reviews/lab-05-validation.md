# Lab validation — Lab 5, Enforce Platform Guardrails

- **Lab under test:** `courseware/day-2/lab-05-enforce-platform-guardrails.md` (603 lines)
- **Learning objective (as stated):** build a restrictive AppProject for `team-a`, prove each restriction by trying to violate it, and tell an **Argo CD** authorization failure from a **Kubernetes** authorization failure (outline L5.1–L5.5, outcomes O6/O7).
- **Tested by:** `lab-tester`, 2026-09-11 / 2026-09-12
- **Validation status:** **FAIL** (blocking defects 1–5 below; everything else is repairable text)
- **Interestingness rating:** **STRONG** (with one caveat — see "Interestingness" at the end)

> **Superseded — read the re-test first.** The status above is the **first** pass, against the 603-line guide. The guide and the environment have since been revised. The current verdict is **PASS WITH NOTES**, recorded in **[§ Re-test 2026-09-12](#re-test-2026-09-12)** at the end of this file. Sections 1–11 below are kept unchanged as the record of what was originally found.

---

## 1. Environment tested

Local k3d two-cluster sandbox on the build machine (macOS/arm64, Docker Desktop), **not** a provisioned classroom VM. Same scripts, images, chart and checkpoints the VM uses (`bootstrap-vm.sh --local` layout).

| Component | Version observed |
|---|---|
| `kubectl version --client` | `Client Version: v1.35.8`, `Kustomize Version: v5.7.1` |
| `helm version` | `version.BuildInfo{Version:"v4.2.1", GitCommit:"d591a19b953bd9cfdf7d9ddd83c2f4ffdaeafb29", GitTreeState:"clean", GoVersion:"go1.26.4", KubeClientVersion:"v1.36"}` |
| `argocd version --client` | `argocd: v3.5.2+e258ee2.dirty` (GitTag `v3.5.2`, `darwin/arm64`) |
| Argo CD server | `GET /api/version` → `{"Version":"v3.5.2"}` |
| Kubernetes (both clusters) | `rancher/k3s:v1.35.8-k3s1` |
| Gitea | `gitea/gitea:1.27.3-rootless` |
| Screenshot harness | Node `v20.19.6`, Playwright `1.59.0` (cached Chromium rev 1217) |
| shellcheck | `0.11.0` |

All lab-facing commands used the pinned tools in `~/.argocd-course/bin` (the build machine's own `kubectl`/`helm` were never used). Contexts: `k3d-mgmt`, `k3d-workload` only, from `~/.argocd-course/kubeconfig`.

### Deviations required to run locally (none change lab semantics unless noted)

| Guide text | What was run locally | Why |
|---|---|---|
| `reset-lab.sh CP-lab-05 --verify-only` | same + `--local` | build-machine sandbox mode |
| `~/course/...`, `~/platform-config` | `$HOME/.argocd-course/student-home/...` | `COURSE_USER_HOME` in local mode |
| `git clone http://lab-gitea:3000/...` | same URL with `GIT_CONFIG_GLOBAL=$HOME/.argocd-course/student-home/.gitconfig` (`insteadOf` → `localhost:3000`) and a scratch `GIT_ASKPASS` | no `/etc/hosts` entry and no interactive prompt available |
| `/tmp/my-policy.csv`, `/tmp/team-a-*.yaml` | same files under the session scratch directory | agent sandbox policy; path-only difference |
| `argocd login ... --username team-a-dev` then password prompt | `--password "$(cat ~/course/credentials/team-a-dev.txt)"` | non-interactive shell |
| **`apply-argocd-config.sh`** | **`ARGOCD_VALUES_FILE=~/platform-config/argocd/values.yaml apply-argocd-config.sh`** | **Not a local-mode artifact — the guide's literal command does not apply the participant's edit at all. See REQUIRED FIX 1.** |
| `reset-lab.sh`, `apply-argocd-config.sh` invoked bare | `courseware/environment/scripts` added to `PATH` | nothing in `bootstrap-vm.sh` installs the scripts onto the VM `PATH`; flagged for `environment-engineer` |

**Parity notes for the real VM:** everything here is CLI/API behaviour that should be identical on the VM. The two environment-dependent items are (a) the `PATH` question above, and (b) UI access — the sandbox reaches `https://localhost:8443` directly, the VM via SSH tunnel.

---

## 2. Timings observed

| Step | Observed |
|---|---|
| `reset-lab.sh CP-lab-05 --local` (first run, from empty) | 217 s — **ended FAIL** (missing `storefront-1.0.0` tag; see Environment fixes) |
| `reset-lab.sh CP-lab-05 --local` (after the fix, warm) | 53 s — all PASS |
| `reset-lab.sh CP-lab-05 --verify-only` | 1–2 s |
| `apply-argocd-config.sh` (each run) | 4–6 s, plus a forced re-login afterwards |
| E1 (project + policy + unit tests) | ~7 min |
| E2 | ~2 min |
| E3 (both parts) | ~6 min, **+2.5 min if the throwaway carries auto-sync** |
| E4 (both parts) | ~9 min, including a forced 4.5-min wait for auto-sync retries |
| E5 | ~6 min |
| Stretch 1 / 2 / 3 | ~7 / ~3 / ~2 min |
| **Core lab total (expert, answers known)** | **~32 min of commands + ~12 min of waiting ≈ 45 min** |
| **Realistic participant total** | **55–70 min** (they must *write* the AppProject, policy lines and three Applications) |

The header claims **~45 minutes**. That is optimistic once re-logins, the retry wait and manifest authoring are included.

---

## 3. Step-by-step execution log

| # | Guide section / step | Command run | Expected per guide | Actual | Match |
|---|---|---|---|---|---|
| 1 | §5.1 verifier | `reset-lab.sh CP-lab-05 --verify-only` | 19-row PASS table, storefront rows first | 19-row PASS table, **platform rows first**, wording differs | N (cosmetic) |
| 2 | §5.2 UI | Settings → Projects | `default`, `platform`, `storefront`; no `team-a` | exactly that | **Y** |
| 3 | §6.1 | `cat platform-config/projects/storefront.yaml` | shows the four fence fields | shows them (file header reads "COMPLETE storefront AppProject (Lab 2 E4 answers…)") | Y |
| 4 | §6.1 | `grep -n -A6 "rbac:" platform-config/argocd/values.yaml` | 4 lines, no line numbers | 5 lines **with** `-n` line numbers and a different comment | N |
| 5 | §6.2 | `apply-argocd-config.sh` (described) | "rewrites `argocd-rbac-cm` … and rolls the affected components" | rewrites the ConfigMap; **no pod roll** for an RBAC-only change; **revokes all sessions** | N |
| 6 | §6.3 | `argocd admin settings rbac can … --policy-file /tmp/my-policy.csv` | illustrative | **fatal**: `error opening policy file: open /tmp/my-policy.csv: no such file or directory` (file does not exist yet at this point) | N |
| 7 | §6.3 | `kubectl --context k3d-workload auth can-i create deployments.apps -n team-a --as=system:serviceaccount:argocd-access:argocd-manager` | `yes` | `yes` | **Y** |
| 8 | E1-A | write + `kubectl apply -f platform-config/projects/team-a.yaml` | project created | `appproject.argoproj.io/team-a created` | **Y** |
| 9 | E1-A | `argocd proj get team-a` | "one source repo, one destination, empty cluster allow-list, **exactly four allowed namespaced kinds**" | shows sources/destinations/`Allowed Cluster Resources: <none>`; **the four namespaced kinds are not printed** (only `Denied Namespaced Resources: <none>`) | N |
| 10 | E1-B | `argocd admin settings rbac can team-a-dev sync applications 'team-a/…' --policy-file <scratch>` | `Yes` | `Yes` | **Y** |
| 11 | E1-B | same with `delete` | `No` | `No` (exit code 1) | **Y** |
| 12 | E1-B | `apply-argocd-config.sh` after editing the clone | policy becomes live | **`policy.csv` stayed empty**; `rbac can … sync` → `No` | **N — blocking** |
| 13 | E1-B | (deviation) `ARGOCD_VALUES_FILE=… apply-argocd-config.sh` | — | policy live; `sync` → `Yes`, `delete` → `No` | Y (with deviation) |
| 14 | E1/E5 | `argocd admin settings rbac can … ` **live, as printed** | `Yes` / `No` | **fatal**: `please provide exactly one of --policy-file or --namespace` | **N — blocking** |
| 15 | E2 | `kubectl apply -f platform-config/applications/team-a-guestbook.yaml` | applies | works **only after** `mkdir -p platform-config/applications` (directory absent at CP-lab-05) | N |
| 16 | E2 | `argocd app sync team-a-guestbook` | syncs | first attempt **failed**: `invalid session: account password has changed since token issued` (caused by step 12/13); after re-login, `Synced`/`Healthy` | N |
| 17 | E2 | `argocd app get team-a-guestbook` | `Synced`/`Healthy`, Deployment + Service in `team-a` | exactly that | **Y** |
| 18 | E3-A | apply throwaway with destination `storefront-prod`, `argocd app get team-a-wrong-dest` | condition contains `is not permitted in project "team-a"` | `InvalidSpecError  application destination server 'https://k3d-workload-server-0:6443' and namespace 'storefront-prod' do not match any of the allowed destinations in project 'team-a'` | **N — wrong string** (right layer) |
| 19 | E3-A | `kubectl --context k3d-workload -n storefront-prod get deploy guestbook` | nothing created | `NotFound` | **Y** |
| 20 | E3-B | apply + `argocd app sync team-a-clusterrole` | message names `ClusterRole` + `is not permitted in project "team-a"`; fence 2 | `ComparisonError: Failed to load live state: cluster level ClusterRole "team-a-escalation" can not be managed when in namespaced mode` — **the AppProject is never consulted** | **N — wrong layer** |
| 21 | E3-B | `kubectl --context k3d-workload get clusterrole team-a-escalation` | `NotFound` | `NotFound` | **Y** |
| 22 | E3 hint 3 | `argocd app delete team-a-wrong-dest --cascade=false` | deletes the throwaway | works, **no confirmation prompt** at v3.5.2 (prompts disabled by default) | Y |
| 23 | E4-A | `argocd login … --username team-a-dev` | logs in | `'team-a-dev:login' logged in successfully` | **Y** |
| 24 | E4-A | `argocd app sync storefront-prod-workload` | `permission denied: applications, sync, storefront/…` | `rpc error: code = PermissionDenied desc = permission denied` (**terse**; server log shows the denial was on **`get`**) | **N — wrong string** (right layer) |
| 25 | E4-A (UI) | open the app as `team-a-dev` | permission-denied notification after pressing Sync | **no Sync button exists**; page shows `Failed to load data, please try again.` + toast `Unable to load data: permission denied` | N |
| 26 | E4-B | `kubectl … auth can-i create networkpolicies.networking.k8s.io -n team-a --as=…` | `no` | `no` | **Y** |
| 27 | E4-B | `argocd app sync team-a-netpol` | starts, then fails `forbidden … argocd-manager` | first attempt: `another operation is already in progress` (auto-sync retrying, ~4.5 min); after it settled, exactly the expected failure | N (timing) |
| 28 | E4-B | result message | `forbidden` naming the SA and `networkpolicies` | `one or more objects failed to apply, reason: networkpolicies.networking.k8s.io is forbidden: User "system:serviceaccount:argocd-access:argocd-manager" cannot create resource "networkpolicies" in API group "networking.k8s.io" in the namespace "team-a"` | **Y** |
| 29 | E5-A | `argocd admin settings rbac can team-a-dev delete applications 'team-a/team-a-guestbook'` | `No` | fatal without `--namespace argocd`; with it, `No` | N (see 14) |
| 30 | E5-B | add `p, role:team-a, applications, delete, storefront/*, deny`, re-test with a broad allow in the same file | deny wins → `No` | `No` for delete, `Yes` for sync — **deny precedence verified, line form verified verbatim** | **Y** |
| 31 | E5-B | apply for real | live policy updated | works via the deviation; session revoked again | N (see 12/16) |
| 32 | E5-C | `kubectl … get application team-a-guestbook -o jsonpath='{.metadata.finalizers}'` | array containing `resources-finalizer.argocd.argoproj.io` | **empty** — no Application in CP-lab-05 has any finalizer | **N** |
| 33 | E5 (missing step) | delete as `team-a-dev` | (no step exists, but the checkpoint and SS-L5-07 require it) | `permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev, iat: …` | N (step missing) |
| 34 | Stretch 1 | `applicationsetcontroller.policy: create-update` + re-apply | per-AppSet override is disabled | verified: param lands in `argocd-cmd-params-cm`, controller restarts with `ARGOCD_APPLICATIONSET_CONTROLLER_POLICY=create-update`; AppSet asking for `create-delete` **did not** get its app deleted | **Y** |
| 35 | Stretch 2 | deny sync window on `storefront` | window row appears, syncs blocked | `argocd proj windows add storefront --kind deny --schedule "* * * * *" --duration 1h --applications "*"` → `Active deny`; app shows `SyncWindow: Sync Denied`; sync → `cannot sync: blocked by sync window` | **Y** |
| 36 | Stretch 3 | project role + JWT | token minted, scoped to sync | `argocd proj role create team-a ci-sync`, `… add-policy … --action sync`, `… create-token` all work; role policy `p, proj:team-a:ci-sync, applications, sync, team-a/*, allow` | **Y** |
| 37 | Handoff | `reset-lab.sh CP-capstone --local --verify-only` | should PASS after Lab 5 | **PASS (22/22)** — but only because the RBAC change landed via the deviation | Y* |

---

## 4. REQUIRED fixes

### 1. `apply-argocd-config.sh` never reads the participant's clone, so Exercise 1 Part B (and E5 Part B, and stretch 1) silently do nothing — BLOCKING

**Location:** §6.2; E1 Part B ("paste the lines into `values.yaml` and apply for real"); E5 Part B; stretch 1; troubleshooting row 5.

**Evidence (reproduced twice).** After editing `~/platform-config/argocd/values.yaml` and running the guide's command:

```text
$ apply-argocd-config.sh          # succeeds, rc=0
$ kubectl --context k3d-mgmt -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}'
                                   # ← empty
$ argocd admin settings rbac can team-a-dev sync applications 'team-a/team-a-guestbook' --namespace argocd
No
```

The script hard-codes `BASE_VALUES="${ARGOCD_VALUES_FILE:-${COURSE_REPOS_SRC}/platform-config/argocd/values.yaml}"` — the read-only payload copy (`/opt/course-payload/.../environment/repos/...` on the VM), not `~/platform-config`.

**Smallest guide-only fix that works today (verified):** pass the clone as an overlay argument. Replace every bare `apply-argocd-config.sh` in this guide with:

```bash
apply-argocd-config.sh ~/platform-config/argocd/values.yaml
```

Verified result:

```text
$ kubectl --context k3d-mgmt -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}'
p, role:team-a, applications, get, team-a/*, allow
p, role:team-a, applications, sync, team-a/*, allow
p, role:team-a, applications, delete, storefront/*, deny
g, team-a-dev, role:team-a
```

**Why it is blocking:** without it the lab's checkpoint criterion 3 fails, E4 Part A tests nothing (`team-a-dev` has no permissions either way), and Lab 5 does **not** leave `CP-capstone` — `reset-lab.sh CP-capstone --verify-only` would FAIL its `Argo CD RBAC role:team-a -> team-a-dev present` row. `environment-engineer` should decide whether the wrapper should instead read the values from the `platform-config` repo on `main` (the GitOps-faithful behaviour the guide's §6.1 describes).

### 2. Every *live* `argocd admin settings rbac can …` command in the guide is fatal as written — BLOCKING

**Location:** E1 "Output shape of a correct result"; E5 Part A command block; E5 "Output shape"; troubleshooting row 1; checkpoint criterion 3.

**Actual:**

```text
$ argocd admin settings rbac can team-a-dev sync applications 'team-a/team-a-guestbook'
{"level":"fatal","msg":"please provide exactly one of --policy-file or --namespace","time":"..."}
```

**Replacement text (verified):**

```bash
argocd admin settings rbac can team-a-dev sync   applications 'team-a/team-a-guestbook' --namespace argocd   # Yes
argocd admin settings rbac can team-a-dev delete applications 'team-a/team-a-guestbook' --namespace argocd   # No
```

Add one sentence: *"`--namespace argocd` tells the command to read the live `argocd-rbac-cm`; `--policy-file` and `--namespace` are mutually exclusive, and exactly one is required."* Note also that this command reads the cluster through **your kubeconfig**, not through the Argo CD session — it is not "asking as `team-a-dev`".

### 3. `apply-argocd-config.sh` logs everyone out; the guide never says so — BLOCKING for flow

**Location:** §6.2, E1 Part B, E5 Part B.

The wrapper stamps a fresh `argocdServerAdminPasswordMtime` (and `accounts.team-a-dev.passwordMtime`) on **every** run, which revokes all issued tokens. The very next command fails:

```text
$ argocd app sync team-a-guestbook
{"level":"fatal","msg":"rpc error: code = Unauthenticated desc = invalid session: account password has changed since token issued","time":"..."}
```

This bit three times in one run, and in a lab about authorization errors it is a cruel red herring. **Add immediately after each apply step:**

```bash
# Applying the configuration re-stamps the account passwords, which invalidates
# every existing session. Log the CLI in again (and refresh the browser tab —
# the UI will bounce you to the login page too):
argocd login localhost:8443 --username admin \
  --password "$(cat ~/course/credentials/argocd-admin.txt)" --insecure
```

Better long-term fix (for `environment-engineer`): only write `*PasswordMtime` when the hash actually changes.

### 4. Exercise 3 Part A — the expected message does not exist at v3.5.2

**Location:** §4 mermaid ("DENY: … is not permitted in project 'team-a'"), E3 "Output shape", SS-L5-03 alt text and "What to notice" 1, checkpoint table row E3-A, troubleshooting row 2. (Guide 06 §5.5 Case A and QC1 item 2 carry the same wrong string — flagged to `lab-engineer` as a cross-guide fix.)

**Real output to paste verbatim:**

```text
$ argocd app get team-a-wrong-dest
...
Sync Status:        Unknown
Health Status:      Unknown

CONDITION         MESSAGE                                                                                                                                                               LAST TRANSITION
InvalidSpecError  application destination server 'https://k3d-workload-server-0:6443' and namespace 'storefront-prod' do not match any of the allowed destinations in project 'team-a'  2026-09-11 13:32:23 -0400 EDT
```

The searchable phrase is **`do not match any of the allowed destinations in project 'team-a'`**, condition type **`InvalidSpecError`**, single quotes (not double).

Also correct the "no operation runs" claim: applying the Application alone creates no operation, but if a participant *does* press Sync, an operation is recorded and ends instantly with `Phase: Error`, `Duration: 0s` and that same message — still with **zero resources touched**. The reliable tell is not "an operation exists" but "no resource result rows, nothing changed on the cluster".

### 5. Exercise 3 Part B is refused by a different layer than the guide teaches

**Location:** E3 Part B, its "Output shape", SS-L5-04 alt text and notes, checkpoint row E3-B.

**Real output:**

```text
$ argocd app sync team-a-clusterrole
...
Operation:          Sync
Phase:              Error
Duration:           0s
Message:            ComparisonError: Failed to load live state: cluster level ClusterRole "team-a-escalation" can not be managed when in namespaced mode
```

The workload cluster is registered with `clusterResources: "false"` and a `namespaces:` list (Lab 2's `workload.secret.template.yaml`), so Argo CD refuses the cluster-scoped kind while loading live state — **the `team-a` AppProject is never consulted**. A participant who predicted "fence 2, the empty `clusterResourceWhitelist`" is marked right by a message that proves something else. Two acceptable repairs:

- **(a) Reframe (guide-only).** Ask participants to predict *which* Argo CD-side guard speaks first, then reveal that two independent guards would each stop this — the cluster registration scope (Lab 2) fires at comparison time, before the AppProject's `clusterResourceWhitelist` is ever reached. This is a genuinely better diagnostic moment and needs no environment change.
- **(b) Swap the attempt for a namespaced kind the project omits** (`ResourceQuota` or `LimitRange`, which blueprint 8.7.1 says are deliberately denied). Requires a new manifest in `team-a-apps/attempts/` (`environment-engineer`). The AppProject denial then reads exactly like this (captured from a throwaway project during this run):

```text
Phase:   Failed
Message: one or more synchronization tasks are not valid: resource <group>:<Kind> is not permitted in project <project>
```

with the per-resource row `STATUS: SyncFailed` carrying the same text. Note this only appears **at sync time** — there is no pre-sync condition for a kind violation.

### 6. Exercise 4 Part A — the expected message does not exist either

**Location:** E4 Part A "Output shape", SS-L5-05 alt text and notes, checkpoint row E4-A, §4 mermaid fence-1 label.

**Real CLI output:**

```text
$ argocd app sync storefront-prod-workload        # as team-a-dev
{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = permission denied","time":"..."}
```

The detailed form the guide promises exists only in the **server log**, and it names `get`, not `sync` (the CLI's `get` call is refused first, so the `sync` check is never reached):

```text
$ kubectl --context k3d-mgmt -n argocd logs deploy/argocd-server | grep "permission denied"
level=warning msg="user tried to get application which they do not have access to: rpc error: code = PermissionDenied desc = permission denied: applications, get, storefront/storefront-prod-workload, sub: team-a-dev, iat: 2026-09-11T17:38:14Z" application=storefront-prod-workload namespace=argocd project=storefront security=2 user=team-a-dev
```

This is a **gift** for the exercise's own table ("Where is it logged?") — add the `logs` command as the step that answers that column. Also record the contrast the lab can now teach for free: when the subject *can* `get` the app, the client **does** get the detailed string (see fix 8).

Also fix the UI expectation: as `team-a-dev` there is no Sync button at all. The page shows `Failed to load data, please try again.` plus a toast `Unable to load data: permission denied` (that is what SS-L5-05 now shows).

### 7. Throwaway Applications must be renamed and must not inherit auto-sync

**Location:** E3 hint 1 ("change only the one field each part needs"), E3 Part A/B, E4 Part B.

Three problems, all from copying the E2 file verbatim:

1. **Name.** Changing "only one field" leaves `metadata.name: team-a-guestbook`, so applying the copy **mutates the working Application** instead of creating a throwaway (and the guide's later `argocd app get team-a-wrong-dest` then fails). Hint 1 must say *"change the `metadata.name` **and** the one field each part needs."*
2. **Auto-sync destroys the predict-then-observe moment** — the copy syncs itself before the participant runs anything.
3. **Auto-sync blocks the guide's own command.** v3.5.2 gives automated syncs a default `retry: {limit: 5}`, so the operation stays `Running` for ~4.5 minutes and the guide's `argocd app sync team-a-netpol` returns:

```text
{"level":"fatal","msg":"rpc error: code = FailedPrecondition desc = another operation is already in progress","time":"..."}
```

**Fix:** tell participants to delete the `syncPolicy:` block from both throwaways (one line of instruction), which makes every attempt a deliberate, observable act. If auto-sync is kept, add `argocd app terminate-op <app>` to troubleshooting.

### 8. Exercise 5 has no step that actually attempts a delete, but the checkpoint and screenshot require one

**Location:** E5 (add to Part A or B), checkpoint row E5, SS-L5-07.

**Add (verified, and it is safe — the delete is refused):**

```bash
# As team-a-dev, try the delete for real:
argocd login localhost:8443 --username team-a-dev --insecure
argocd app delete team-a-guestbook
```

**Real output to paste:**

```text
{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev, iat: 2026-09-12T04:51:02Z","time":"..."}
```

and, for the same account against a storefront app, the terse form that explains fix 6:

```text
$ argocd app delete storefront-prod-workload
{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = permission denied","time":"..."}
```

### 9. Exercise 5 Part C prints nothing — no Application in this environment carries the finalizer

**Location:** E5 Part C, its "Output shape", hint 3, key takeaway 5.

**Real:**

```text
$ kubectl --context k3d-mgmt -n argocd get application team-a-guestbook -o jsonpath='{.metadata.finalizers}' ; echo

$ kubectl --context k3d-mgmt -n argocd get applications -o custom-columns='NAME:.metadata.name,FINALIZERS:.metadata.finalizers'
NAME                          FINALIZERS
platform-agent                <none>
platform-netpol               <none>
platform-quotas               <none>
platform-root                 <none>
storefront-dev-workload       <none>
storefront-prod-workload      <none>
storefront-staging-workload   <none>
team-a-guestbook              <none>
```

The AppSet-generated ones cannot have it: the `storefront` ApplicationSet sets `preserveResourcesOnDeletion: true`, which is exactly why the controller does not add `resources-finalizer.argocd.argoproj.io`. Blueprint 7.3's "inspect the finalizer on a **generated** Application" is therefore impossible as written.

**Verified cascade facts to build the corrected part on** (each tested and restored during this run):

| Delete path | Finalizer present? | Workload resources |
|---|---|---|
| `kubectl delete application team-a-guestbook` | yes (patched in) | **deleted** (cascade) |
| `kubectl delete application team-a-guestbook` | no | **survive** (orphaned) |
| `argocd app delete team-a-guestbook` (CLI default, and the UI dialog) | no | **deleted anyway** — the server adds the finalizer/propagation policy on request |

Recommended rewrite of Part C: have participants (1) observe that the finalizer is *absent* everywhere, (2) explain why (`preserveResourcesOnDeletion`), (3) open the UI delete dialog and read its three propagation choices — Foreground / Background / **Non-cascading** — which is what SS-L5-07 now shows, and (4) conclude that danger comes from the *delete path chosen*, not only from a field on the object. If the guide keeps the `jsonpath` command, hint 3's patch works but emits a Kubernetes warning worth showing:

```text
Warning: metadata.finalizers: "resources-finalizer.argocd.argoproj.io": prefer a domain-qualified finalizer name including a path (/) to avoid accidental conflicts with other finalizer writers
```

### 10. §5.1 expected verifier output does not match the real table

**Location:** §5.1.

**Real output to paste verbatim:**

```text
==> Verification for CP-lab-05
  PASS  Application platform-root Synced/Healthy
  PASS  Application platform-quotas Synced/Healthy
  PASS  Application platform-netpol Synced/Healthy
  PASS  Application platform-agent Synced/Healthy
  PASS  Application storefront-dev-workload Synced/Healthy
  PASS  Application storefront-staging-workload Synced/Healthy
  PASS  Application storefront-prod-workload Synced/Healthy
  PASS  Application hello-reconcile absent
  PASS  Application storefront-dev absent
  PASS  ApplicationSet storefront present
  PASS  AppProject storefront present
  PASS  AppProject platform present
  PASS  Secret in-cluster present
  PASS  Secret repo-storefront-gitops present
  PASS  Secret cluster-workload present
  PASS  Secret course-repo-creds present
  PASS  workload namespace storefront-prod present
  PASS  workload SA argocd-manager present
  PASS  workload RoleBinding argocd-deployer (storefront-prod) present

PASS CP-lab-05 is in the expected state.
```

The "representative — confirm against the live classroom environment" hedge can now be dropped.

### 11. §6.1 expected `grep` output is wrong

**Location:** §6.1.

**Real output to paste:**

```text
136:  rbac:
137-    # No permissions by default. Anonymous users see nothing. Lab 5 adds a
138-    # role:team-a policy (applied via the CP-capstone values overlay in resets).
139-    policy.default: ""
140-    policy.csv: ""
```

### 12. §6.3's `--policy-file` example runs before the file exists

**Location:** §6.3.

As printed it is copy-runnable and fatal:

```text
{"level":"fatal","msg":"error opening policy file: open /tmp/my-policy.csv: no such file or directory","time":"..."}
```

Either label the block "shape only — you create this file in Exercise 1", or make it self-contained by writing a two-line scratch file first.

### 13. `platform-config/applications/` does not exist at CP-lab-05

**Location:** E2.

The Day-2 checkpoint removed `applications/storefront-dev.yaml`, so the directory is gone and the guide's own apply path fails for anyone using `cat >`/redirection:

```text
$ cat > platform-config/applications/team-a-guestbook.yaml
zsh: no such file or directory: platform-config/applications/team-a-guestbook.yaml
```

Add `mkdir -p platform-config/applications` to E2's starter state.

### 14. The guide never has participants commit the fence it calls "reviewed, versioned, and reversible"

**Location:** §6.1 claim vs E1/E5 steps.

Nothing in Lab 5 commits or pushes `projects/team-a.yaml` or the `values.yaml` edit, so the governance-in-Git claim is never realized and a later `reset-lab.sh` silently discards the participant's work. Add an explicit `git add/commit/push` step in E1 (and E5 Part B), or soften §6.1's claim. This also matters for the capstone: `CP-capstone`'s Git tag already contains `projects/team-a.yaml`, so a participant's uncommitted file diverges from the repo the capstone reasons about.

---

## 5. Optional improvements

1. **E1 hint about `NetworkPolicy`'s API group.** Nothing taught so far gives `group: networking.k8s.io`. Hint 1 mentions only that core kinds use `group: ""`. Point at `kubectl --context k3d-workload api-resources | grep networkpolic` or at `projects/platform.yaml`, which already contains the pair.
2. **E1 hint 3 is wrong about `*`.** Verified: an object of `*` returns **`Yes`** (and over-grants across projects); the form that returns `No` is `team-a` without `/*`. Suggested text: *"If `sync` prints `No`, check the `g,` binding line and the object field — `team-a` alone does not match `team-a/team-a-guestbook`; it must be `team-a/*`. If `delete` prints `Yes`, you granted too much (probably `*` as the action, or `*` as the object, which also hands the role every other project)."*
3. **`argocd cluster list` copy trap** (E1 spec table): the SERVER column prints `https://k3d-workload-server-0:6443 (5 namespaces)`. Say "copy the URL only, not the `(5 namespaces)` suffix".
4. **Show the allow-list where it is actually visible.** `argocd proj get team-a -o yaml` prints the four kinds; the UI project page prints them under **NAMESPACE RESOURCE ALLOW LIST** (as in SS-L5-02). Note also that `clusterResourceWhitelist: []` is dropped from the stored spec (empty == absent == deny-all for cluster kinds) — a nice "empty is not unset" teaching point that is visible in the real object.
5. **SS-L5-02 caption nuance:** the Destinations row shows the **server URL** with the Name column blank (because the Application/AppProject names the server, not the cluster name). The caption says "the `workload` cluster".
6. **`argocd app get` prints `URL: https://argocd.example.com/applications/...`** (the chart's default `global.domain`). Participants will notice a hostname that is not theirs; one sentence would defuse it, or `environment-engineer` can set `global.domain: localhost:8443`.
7. **Timing.** Either raise the header estimate to ~55 minutes or move E5 Part B (the explicit deny) into the stretch section.
8. **Stretch 2 pays for SS-S6-03.** The sync-window stretch works exactly as documented; running it against the `team-a` project (`--applications '*'`) is the cheapest way to produce Guide 06's SS-S6-03 shot. Also worth telling participants the verified behaviour: with `manualSync` off, even an **admin** manual sync is refused (`cannot sync: blocked by sync window`) — not just automated sync.
9. **Stretch 3 detail:** `argocd proj role create` adds `p, proj:team-a:ci-sync, projects, get, team-a, allow` by itself; the `--action sync` policy adds `applications, sync, team-a/*`. Showing `argocd proj role get team-a ci-sync` makes the scoping visible without ever printing the token.
10. **Checkpoint table.** Add a column for "did a resource result row appear?" — after this run, that is the property that actually separates fence 2 from fence 3 (both can show `Phase: Failed`).

---

## 6. Screenshot check

All seven were captured live from this course's own Argo CD v3.5.2 with the harness (`node capture.mjs --only <ID>`), and every PNG was opened and compared with the guide's alt text/caption.

| File | Captured | Shows what the alt text/caption claims | Note |
|---|---|---|---|
| `lab-05-01-env-check-projects.png` | Y | **Y** | `default`, `platform`, `storefront`, no `team-a`. Exactly as described. |
| `lab-05-02-project-team-a.png` | Y | **Y** (one nuance) | Sources/Destinations/allow-lists all visible (needed a 1440×1900 viewport — they are below the fold at 900px). Destinations shows the server URL, Name column blank. |
| `lab-05-03-destination-rejected.png` | Y | **N — text mismatch** | Shows the real `InvalidSpecError … do not match any of the allowed destinations in project 'team-a'`. Alt text says "not permitted in project team-a" (fix 4). |
| `lab-05-04-cluster-scoped-blocked.png` | Y | **N — layer mismatch** | Shows `Phase: Error` + `ComparisonError … can not be managed when in namespaced mode`. Alt text claims an AppProject "not permitted" message (fix 5). |
| `lab-05-05-argocd-rbac-denied.png` | Y | **N — text mismatch** | Shows the real `team-a-dev` view: `Failed to load data…` + toast `Unable to load data: permission denied`. Alt text claims a notification naming `applications, sync, storefront/…` (fix 6). |
| `lab-05-06-kubernetes-forbidden.png` | Y | **Y** | `Phase: Failed` + `forbidden … system:serviceaccount:argocd-access:argocd-manager … networkpolicies … namespace "team-a"`, with a RESULT row `SyncFailed`. Matches all three "what to notice" bullets. |
| `lab-05-07-delete-denied.png` | Y | **Y (better than claimed)** | Delete dialog (Foreground/Background/Non-cascading) plus toast `permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev`. Supports both E5 Part A and Part C. |

Manifest entries for `SS-L5-01`…`SS-L5-07` were corrected in `courseware/environment/scripts/screenshots/screenshot-manifest.yaml` with the confirmed routes, actions, selectors and a dated note on each; four of the seven had provisional routes pointing at `/applications/team-a-guestbook`, which is not where any of those states live.

---

## 7. Environment fixes applied

| File | Change | Why |
|---|---|---|
| `courseware/environment/scripts/seed-repos.sh` | after the checkpoint-tag loop, create `storefront-1.0.0` at `cp-baseline` for `storefront-gitops` only (5 lines + comment) | **Blocked execution.** `envs/prod/config.yaml` pins `targetRevision: storefront-1.0.0`, but nothing ever created that tag, so `storefront-prod-workload` sat in `ComparisonError: unable to resolve 'storefront-1.0.0' to a commit SHA` and `reset-lab.sh CP-lab-05` ended `FAIL 1 check(s) failed`. After the fix the reset passes 19/19. shellcheck 0.11.0 clean. Blueprint 8.7 already specifies this tag. Affects Lab 4, Lab 5 and the capstone equally. |
| `courseware/environment/scripts/screenshots/capture.mjs` | added three optional per-shot fields: `wait_until`, `viewport`, `actions` (click/fill/wait_for/wait_ms) — ~25 lines, `node --check` clean | **Blocked capture.** Application detail routes never reach `networkidle` (the UI holds an event stream open) so every app-page shot timed out at 45 s; the project page needs a taller viewport; and four of the seven states only exist after a UI interaction (open conditions, open the sync result, confirm a delete). |
| `courseware/environment/scripts/screenshots/screenshot-manifest.yaml` | corrected `SS-L5-01`…`SS-L5-07` routes/selectors/actions, added dated confirmation comments | provisional routes/selectors (P-18) did not match the live UI |

No other environment file was touched. No `terraform` was run. No non-course Docker resources were touched.

---

## 8. Cross-guide findings for the orchestrator

1. **Guide 06 carries the same two wrong strings** (`06-security-multitenancy-governance.md` §5.5 Case A and Quick Check S6-QC1 item 2 use `application destination { … } is not permitted in project 'team-a'`). Its own version note says the exact wording is "confirmed by `lab-tester` in Lab 5" — it is now confirmed **different** (fix 4). Its Case B NetworkPolicy string, by contrast, is exactly right.
2. **`apply-argocd-config.sh` values source (capstone question a):** confirmed — it reads only the seed/payload copy, never the participant's clone. This also means capstone fault **F7**'s documented repair ("restore the limits in values and run `apply-argocd-config`") succeeds no matter what the participant does to Git, and the participant's Git fix is never actually what heals the cluster.
3. **Nothing re-applies the ApplicationSet from Git (capstone question b):** confirmed empirically. `inject-capstone-faults.sh inject F2 --local` pushed the selector change to `main`, but the live object kept `{"matchLabels":{"cluster-role":"workload"}}`, no `*-in-cluster` Applications appeared, and `verify F2` reported `F2 not present`. `platform-root` manages `apps/` only, and the ApplicationSet controller does not read its own definition from Git. Either the fault script must `kubectl apply` the changed file (realistic: "a teammate merged **and applied** it"), or the AppSet must become a child of the App-of-Apps. (Marker cleared; `revert F2` ran cleanly.)
4. **VM `PATH`:** `bootstrap-vm.sh` installs the pinned *tools* into `$COURSE_TOOLS_DIR` but never puts `scripts/` (or `/opt/course/bin`) on the student's `PATH`, while every lab calls `reset-lab.sh` and `apply-argocd-config.sh` bare. For `environment-engineer` to confirm on a real VM.

---

## 9. Interestingness

**STRONG.** Participants write a real AppProject from a specification, write RBAC policy lines and unit-test them offline before shipping, predict three refusals, and diagnose which of three systems produced each one. The Guardrail-Bypass-Attempt shape (predict → try → read the message) is exactly the right structure, the prediction always precedes the reveal, and E4's comparison table forces a decision ("which team do you page?") rather than recall. E5's deny-precedence test is a genuine "prove the rule" moment and it works verbatim.

The caveat: today two of the five attempts (E3-B, E4-A) are "confirmed" by messages that say something other than what the guide claims, so a participant who reasons correctly is rewarded by text that contradicts them — and one (E3-B) lands in a different layer entirely. Fixing 4, 5 and 6 turns the weakest moment into the sharpest one, because the real E3-B answer ("two Argo CD guards could stop this; which one spoke first?") is a better question than the one currently asked.

---

## 10. Final sandbox state

- **`reset-lab.sh CP-capstone --local --verify-only` → PASS (22/22)**, including `Argo CD RBAC role:team-a -> team-a-dev present`. The Lab 5 → capstone handoff in blueprint 7.4 holds **provided** fix 1 is applied; on the participant path as written that row would FAIL.
- Applications (all `Synced`/`Healthy`): `platform-root`, `platform-quotas`, `platform-netpol`, `platform-agent`, `storefront-{dev,staging,prod}-workload`, `team-a-guestbook`. Throwaways (`team-a-wrong-dest`, `team-a-clusterrole`, `team-a-netpol`) deleted with `--cascade=false`.
- AppProjects: `default`, `platform`, `storefront`, `team-a`. Live `policy.csv` holds the three E1 lines plus the E5 deny line. No sync windows, no project roles, no capstone fault markers; `applicationsetcontroller.policy` reverted (key absent).
- Workload cluster: `team-a` namespace runs the guestbook Deployment + Service; no NetworkPolicy; no `team-a-escalation` ClusterRole anywhere.
- Git: `platform-config` `main` at `cp-lab-05` (Lab 5 never asks for a commit); `storefront-gitops` `main` carries two `lab-tester` stretch-1 commits whose content is identical to `cp-lab-05` (any `reset-lab.sh <CP>` force-moves `main` back). The student clone at `~/.argocd-course/student-home/platform-config` holds the uncommitted `projects/team-a.yaml` and `argocd/values.yaml` edits.
- Sandbox resource use stayed modest: `k3d-mgmt-server-0` ≈ 1.4 GiB, `k3d-workload-server-0` ≈ 0.6 GiB, `lab-gitea` ≈ 0.12 GiB.

## 11. Retest requirements

1. Re-run E1 Part B, E5 Part B and stretch 1 **exactly as printed** after fix 1 lands (no `ARGOCD_VALUES_FILE`), and confirm `policy.csv` becomes live and `reset-lab.sh CP-capstone --verify-only` still passes.
2. Re-run E3 Part B after whichever repair (a) or (b) is chosen; if (b), the new `attempts/` manifest needs a fresh seed and a re-verified message string.
3. Re-run E3/E4 with `syncPolicy` removed from the throwaways to confirm the retry/`already in progress` problem is gone.
4. Recapture `lab-05-03/04/05` only if the exercises change shape; the current PNGs are accurate to the *current* environment, and the fix is in the guide text, not the images.
5. One pass on a real provisioned VM for the `PATH` question and the SSH-tunnel UI path.

---

## Re-test 2026-09-12

Targeted re-test of the **revised** guide (`courseware/day-2/lab-05-enforce-platform-guardrails.md`, 603 -> 841 lines) after all 14 required fixes and the environment repairs. Everything below is new; nothing above was deleted.

- **Tested by:** `lab-tester`, 2026-09-12
- **Environment:** the same local k3d two-cluster sandbox as the original run (Argo CD `v3.5.2`, chart `10.8.4`, k3s `v1.35.8`, Helm `v4.2.1`, `argocd` CLI `v3.5.2`, Gitea `1.27.3-rootless`). Sandbox handed over at `CP-lab-05`, verified. **Not** a provisioned classroom VM. The Gitea repositories in this sandbox were seeded on 2026-09-11T03:22Z, i.e. **before** commit `d99a26c`, which matters for RE-FIX 4 below.
- **Final verdict: PASS WITH NOTES.**
- **Interestingness: STRONG** (unchanged; the E3 Part B reframe turned the previous weakest moment into the sharpest one — see "Interestingness" note at the end of this section).

### R1. Status of the 14 original required fixes

Each was re-run exactly as printed in the revised guide, as `admin` unless noted.

| # | Original defect | Status | Evidence from this run |
|---|---|---|---|
| 1 | `apply-argocd-config.sh` never applied the participant's values | **CONFIRMED FIXED** | `apply-argocd-config.sh ~/platform-config/argocd/values.yaml` (overlay) made `policy.csv` live. Separately, the bare invocation now prints `ok values source: platform-config main (Gitea bb81436)` and applies the **committed and pushed** values. No `ARGOCD_VALUES_FILE` deviation was needed anywhere in this run. |
| 2 | Live `rbac can …` fatal without a source flag | **CONFIRMED FIXED** | `… sync … --namespace argocd` -> `Yes` (rc 0); `… delete … --namespace argocd` -> `No` (rc 1). The §6.3 flag table and the "reads the ConfigMap through your kubeconfig" note are both accurate. |
| 3 | Apply logs everyone out, guide never said so | **FIXED — but now over-corrected**, see RE-FIX 2 | The script no longer re-stamps passwords: `ok account passwords unchanged: reusing the live hashes (existing logins stay valid)`. The admin session survived **both** applies. The guide's re-login step still works, but the guide's stated cause no longer occurs. |
| 4 | E3 Part A message string wrong | **CONFIRMED FIXED** | Verbatim: `InvalidSpecError  application destination server 'https://k3d-workload-server-0:6443' and namespace 'storefront-prod' do not match any of the allowed destinations in project 'team-a'`, `Sync Status: Unknown`, `Health Status: Unknown`. Matches the guide word for word. |
| 5 | E3 Part B refused by a different layer | **CONFIRMED FIXED (repair (a), reframe)** | Verbatim: `Phase: Error`, `Duration: 0s`, `Message: ComparisonError: Failed to load live state: cluster level ClusterRole "team-a-escalation" can not be managed when in namespaced mode`. `kubectl --context k3d-workload get clusterrole team-a-escalation` -> `NotFound`. The guide's three-step ordering claim (spec check -> live-state load -> resource allow-list) is consistent with what the object shows. |
| 6 | E4 Part A message wrong; UI expectation wrong | **CONFIRMED FIXED** | CLI: `{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = permission denied",…}` (rc 20) — terse, as the guide now says. Server log carries the detailed form naming **`get`**, `security=2`, `user=team-a-dev`. The `logs … \| grep "permission denied"` step works (one caveat, RE-FIX 6). |
| 7 | Throwaways not renamed; inherited auto-sync | **CONFIRMED FIXED** | Hint 1 now says change `metadata.name` **and** the one field, and to remove `syncPolicy:`. With `syncPolicy` absent from E2 onward, `argocd app sync team-a-netpol` ran immediately. **`another operation is already in progress` did not occur once**, and the ~4.5-minute retry wait from the original run is gone. |
| 8 | No step actually attempted a delete | **CONFIRMED FIXED** | As `team-a-dev`: `{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev, iat: 2026-09-12T16:51:07Z",…}`. The safety interlock (`rbac can … delete … --namespace argocd` -> `No`) printed `No` first, and `team-a-guestbook` survived with no `deletionTimestamp`. |
| 9 | E5 Part C printed nothing | **CONFIRMED FIXED** | The `custom-columns` listing printed the guide's exact eight rows, all `<none>`. The cascade table and the "danger is in the delete path" framing are supported by the original run's verified experiments. |
| 10 | §5.1 verifier output wrong | **NOT FIXED — new mismatch**, see RE-FIX 1 | The guide now shows 19 rows; the revised verifier prints **21**. |
| 11 | §6.1 `grep` output wrong | **FIXED for this sandbox; breaks on a fresh VM**, see RE-FIX 4 | Output matched byte for byte here (`136:  rbac:` …). The seed file that a fresh bootstrap pushes to Gitea has since changed. |
| 12 | §6.3 `--policy-file` example ran before the file existed | **CONFIRMED FIXED** | The block now writes `/tmp/rbac-demo.csv` first, then asks. Printed `Yes`. Self-contained and copy-runnable. |
| 13 | `platform-config/applications/` missing | **CONFIRMED FIXED** | E2 now opens with `mkdir -p ~/platform-config/applications`; the subsequent `kubectl apply -f platform-config/applications/team-a-guestbook.yaml` worked from a clean clone. |
| 14 | Fence never committed | **CONFIRMED FIXED** | New E1 Part C ran clean: `[main bb81436] team-a: restricted AppProject and least-privilege RBAC grant` / `93401a2..bb81436  main -> main`. Checkpoint criterion 4 (`git log --oneline -1`) is now satisfiable. One prerequisite caveat: RE-FIX 8. |

**Score: 12 of 14 confirmed fully fixed on the participant path; 1 fixed but over-corrected in the text (3); 1 not fixed (10).**

### R2. Commands executed in this re-test

All run with `KUBECONFIG=$HOME/.argocd-course/kubeconfig`, `COURSE_LOCAL=1`, course scripts on `PATH`.

1. §5.1 `reset-lab.sh CP-lab-05 --verify-only`
2. §6.1 `cat platform-config/projects/storefront.yaml`; `grep -n -A6 "rbac:" platform-config/argocd/values.yaml`
3. §6.3 `cat > /tmp/rbac-demo.csv …`; `argocd admin settings rbac can demo-user sync applications 'demo/demo-app' --policy-file /tmp/rbac-demo.csv`; `kubectl --context k3d-workload auth can-i create deployments.apps -n team-a --as=system:serviceaccount:argocd-access:argocd-manager`
4. E1 hints: `kubectl --context k3d-workload api-resources | grep -i networkpolic`; `argocd cluster list`
5. E1-A: wrote `projects/team-a.yaml` from the spec table; `kubectl --context k3d-mgmt apply -f …`; `argocd proj get team-a`; `argocd proj get team-a -o yaml`
6. E1-B: `/tmp/my-policy.csv` unit tests (`sync` -> `Yes`, `delete` -> `No`); edited `values.yaml`; `apply-argocd-config.sh ~/platform-config/argocd/values.yaml`; the printed `argocd login` re-login; both `rbac can … --namespace argocd` checks
7. Extra (environment verification, not in the guide): bare `apply-argocd-config.sh`
8. E1-C: `git add` / `commit` / `push origin main`
9. E2: `mkdir -p ~/platform-config/applications`; wrote the Application; `kubectl apply`; `argocd app sync`; `argocd app get`
10. E3-A and E3-B: throwaways, `kubectl apply`, `argocd app get` / `argocd app sync … ; argocd app get …`; `kubectl --context k3d-workload get clusterrole team-a-escalation`
11. E4-A: `argocd login … --username team-a-dev`; `argocd app sync storefront-prod-workload`; `argocd app list`; re-login as admin; `kubectl -n argocd logs deploy/argocd-server | grep "permission denied"`
12. E4-B: `kubectl auth can-i create networkpolicies.networking.k8s.io …`; throwaway; `argocd app sync team-a-netpol ; argocd app get team-a-netpol`; plus a non-guide check of `.status.operationState.syncResult.resources` for both E3-B and E4-B
13. E4 cleanup: three `argocd app delete … --cascade=false`
14. E5-A/B: interlock check; `argocd app delete team-a-guestbook` as `team-a-dev`; re-login as admin; the `custom-columns` finalizer listing
15. §9 checkpoint criteria 1, 3, 4
16. Handoff: `reset-lab.sh CP-capstone --local --yes`, then `reset-lab.sh CP-capstone --local --verify-only`

**Deviations from the printed text (same three as the original run, none semantic):** `--local` on the course scripts; `~` maps to `$HOME/.argocd-course/student-home`; `argocd login --username team-a-dev` was given `--password "$(cat ~/course/credentials/team-a-dev.txt)"` and `git push` a scratch `GIT_ASKPASS`, because this shell is non-interactive. No `ARGOCD_VALUES_FILE` override was used at any point — that deviation is now retired.

### R3. Environment changes verified

| Change | Verified? | Evidence |
|---|---|---|
| `apply-argocd-config.sh` base values come from `platform-config` `main` in Gitea | **Yes** | `ok values source: platform-config main (Gitea bb81436)` — the short SHA is the commit E1 Part C had just pushed. Explicit `$ARGOCD_VALUES_FILE` override and the seed fallback are both present in `resolve_base_values()`; the fallback warns loudly. |
| `reset-lab.sh` resets participant clones to `origin/main` | **Yes** | After `reset-lab.sh CP-capstone`, `git -C ~/platform-config log --oneline -1` -> `b14a82c checkpoint CP-capstone` with a clean tree; my `bb81436` commit and both edited files were discarded, exactly as the guide's E1 Part C warns. |
| `reset-lab.sh` deletes non-checkpoint AppProjects and asserts `team-a` / `team-a-guestbook` ABSENT before `CP-capstone` | **Yes** | `CP-lab-05` verify now prints `PASS  Application team-a-guestbook absent` and `PASS  AppProject team-a absent`. |
| Argo CD session survives an apply (root-cause fix for original defect 3) | **Yes** | `ok account passwords unchanged: reusing the live hashes (existing logins stay valid)`; `argocd account get-user-info` still `Logged In: true` with no re-login. |
| Course commands installed on `PATH` | **Code only** | `install_course_commands()` and the `/etc/profile.d/course-path.sh` branch exist in `bootstrap-vm.sh`. This sandbox predates the change (`~/.argocd-course/bin` holds only `argocd`, `helm`, `kubectl`, `yq`), so `PATH` was still set by hand here. **Needs one fresh-bootstrap pass to confirm.** |
| `global.domain: localhost:8443` | **No — not in effect**, see RE-FIX 4 | Present in the on-disk seed file, absent from Gitea `main` in this sandbox. `argocd-cm`'s `url` is still `https://argocd.example.com` and `argocd app get` still prints `https://argocd.example.com/applications/…`. |
| Guide 06 no longer pre-answers Lab 5's E3 example | **Yes** | Guide 06 §5.5 now uses tenant `payments` / namespace `platform-system`, and carries the corrected `do not match any of the allowed destinations in project` string. Its AppProject worked example is `storefront`, not `team-a`. (But see RE-FIX 7 for the RBAC half.) |
| Capstone F2 / `capstone-check` / seed spoiler scrub | **Not re-tested** | Out of scope for a targeted Lab 5 re-test; flagged for the capstone's own validation pass. |

### R4. Required fixes (this re-test)

#### RE-FIX 1. §5.1 "Expected output" is missing two rows the verifier now prints — MEDIUM

**Location:** §5.1 expected-output block, and the sentence immediately after it.

The revised verifier prints **21** rows. The guide shows 19 and omits the two new absence assertions. Replace the block's middle with the real output:

```text
  PASS  Application hello-reconcile absent
  PASS  Application storefront-dev absent
  PASS  Application team-a-guestbook absent
  PASS  AppProject team-a absent
  PASS  ApplicationSet storefront present
```

(the two new rows sit between `storefront-dev absent` and `ApplicationSet storefront present`; every other row and the final `PASS CP-lab-05 is in the expected state.` line are correct as printed).

The paragraph after the block is now self-contradicting. Current text:

> Notice what the verifier does **not** list: there is no `AppProject team-a` and no `team-a-dev` RBAC. That absence is the correct starting state — you will create both.

Replacement:

> Notice the two rows that assert an **absence**: `Application team-a-guestbook absent` and `AppProject team-a absent`. The verifier is not merely silent about team-a — it actively checks that team-a does not exist yet, because that is the correct starting state. You will create both, plus the `team-a-dev` RBAC grant, in Exercise 1.

#### RE-FIX 2. The guide promises a logout on every apply; the environment no longer does that — MEDIUM

**Location:** header time-budget note; §6.2 blockquote "Expect to be logged out — every single time"; E1 Part B ("then log in again, because the apply revoked your session"); E2 Hint 3; troubleshooting row 1; E5 Part B.

`apply-argocd-config.sh` now reuses the live bcrypt hashes and `passwordMtime` when the credential files have not changed, and announces it:

```text
  ok account passwords unchanged: reusing the live hashes (existing logins stay valid)
```

Both applies in this run left the admin CLI session valid (`argocd account get-user-info` -> `Logged In: true` with no re-login) and the `invalid session: account password has changed since token issued` error **never appeared**. The printed re-login command still works and is harmless, but a participant who is told "expect this every single time" and then never sees it will distrust the guide at exactly the moment the lab needs their trust.

Replace the §6.2 blockquote with:

> **If the credentials changed, you will be logged out.** Applying the configuration re-stamps the Argo CD account passwords *only when the underlying credential files have changed*; when they have not, the wrapper reuses the live hashes and prints `account passwords unchanged: reusing the live hashes (existing logins stay valid)`, and your session survives. If instead you see `account passwords (re)stamped: every existing argocd session is now invalid; log in again`, then the very next `argocd` command will fail with:
>
> ```text
> {"level":"fatal","msg":"rpc error: code = Unauthenticated desc = invalid session: account password has changed since token issued","time":"..."}
> ```
>
> That is not a fault — it is the apply, not your policy. Log in again and refresh the browser tab:
>
> ```bash
> argocd login localhost:8443 --username admin \
>   --password "$(cat ~/course/credentials/argocd-admin.txt)" --insecure
> ```

In E1 Part B, change "then log in again, because the apply revoked your session (Section 6.2)" to "the re-login below is harmless either way — run it if the apply reported that it re-stamped the passwords (Section 6.2)". Keep the command block. In the header time budget, delete "Each time you apply Argo CD configuration you are logged out and log in again, which costs about a minute per apply; the guide tells you exactly where that happens." Troubleshooting row 1 should keep the symptom and fix but change "This is expected, not a fault" to "This happens when the apply re-stamped the account passwords — check the wrapper's own output line."

#### RE-FIX 3. Troubleshooting row 2 describes a behaviour the wrapper no longer has — MEDIUM

**Location:** §8 troubleshooting, row "`apply-argocd-config.sh` succeeds but the policy is unchanged", and the §6.2 sentence "so the script applies *your* clone and not the pristine seed copy the course ships".

The wrapper's default base is now `platform-config` `main` as Gitea serves it; the seed copy is a warned last resort. Verified:

```text
$ apply-argocd-config.sh            # no arguments
==> Applying Argo CD configuration (chart 10.8.4, v3.5.2)
  ok values source: platform-config main (Gitea bb81436)
```

Replacement for the troubleshooting row's Likely cause / Fix cells:

| `apply-argocd-config.sh` succeeds but the policy is unchanged | The wrapper applies what is **committed and pushed** to `platform-config` `main`, plus any values file you pass it. An edit that is only in your working copy reaches the cluster only if you pass its path. | Either pass the file — `apply-argocd-config.sh ~/platform-config/argocd/values.yaml` — or commit and push first. Read the wrapper's own `values source:` line to see which it used, then verify with `kubectl --context k3d-mgmt -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}'`. |

And in §6.2, replace "so the script applies *your* clone and not the pristine seed copy the course ships" with "so the script applies the edit that is still only in your working copy — its default is whatever `platform-config` `main` currently holds in Gitea, which will not include your change until Part C pushes it."

#### RE-FIX 4. Two "expected output" claims break on a freshly bootstrapped VM — MEDIUM (environment parity)

**Location:** §6.1 expected `grep` output; E2's "One cosmetic oddity" callout.

`courseware/environment/repos/platform-config/argocd/values.yaml` was rewritten in commit `d99a26c`: comments changed and `global.domain: localhost:8443` was added, which moves `rbac:` from line **136** to line **141**. `seed-repos.sh` pushes that file into Gitea at bootstrap, and `reset-lab.sh` republishes from the seed **mirror**, not from the courseware checkout — so this sandbox (seeded 2026-09-11T03:22Z, before `d99a26c`) still serves the old file while any newly bootstrapped classroom VM will serve the new one.

On a fresh VM the guide's §6.1 block will instead print:

```text
141:  rbac:
142-    # No permissions by default: an account that is not named in policy.csv can
143-    # log in and see nothing. Every grant is written here, deliberately.
144-    policy.default: ""
145-    policy.csv: ""
```

and `argocd app get` will print `URL: https://localhost:8443/applications/team-a-guestbook`, which makes E2's entire "cosmetic oddity" callout wrong.

Two things are needed, and they belong to different owners:
- **`environment-engineer`:** decide and state which content is canonical, and make one bootstrap + `reset-lab.sh CP-lab-05` pass on a machine seeded from `d99a26c` or later, so the guide can be written against a single reality. (This sandbox was deliberately left un-reseeded so the finding stays reproducible.)
- **`lab-engineer`, once that is settled:** paste the resulting `grep` output verbatim into §6.1, and either delete E2's `argocd.example.com` callout (if `global.domain` takes effect) or keep it as written (if it does not). Do not leave the guide matching only a stale sandbox.

#### RE-FIX 5. The lab's central "count the result rows" tell is invisible in the CLI — MEDIUM

**Location:** §4 point 3; E3 Part B "What to notice" 3; E4 Part B "There is also a resource result row …"; §9 checkpoint column "Resource result rows?"; key takeaway "Count the result rows."

The distinction is real in the API object and in the UI, and it is exactly inverted in the CLI. Verified both ways:

```text
$ kubectl -n argocd get app team-a-clusterrole -o jsonpath='{.status.operationState.syncResult.resources}'
                                      # empty  -> no result rows, as the guide says

$ kubectl -n argocd get app team-a-netpol -o jsonpath='{.status.operationState.syncResult.resources}'
[{"group":"networking.k8s.io","kind":"NetworkPolicy","name":"team-a-default-deny","namespace":"team-a",
  "status":"SyncFailed","hookPhase":"Failed","syncPhase":"Sync","message":"networkpolicies… is forbidden: …"}]
```

But `argocd app get` prints the **resource tree**, not the sync result, so **both** failures show a table with a row, and neither shows the word `SyncFailed`:

```text
# E3-B (fence 2b) — a row exists, STATUS is Unknown, MESSAGE is empty
GROUP                      KIND         NAMESPACE  NAME               STATUS   HEALTH   HOOK  MESSAGE
rbac.authorization.k8s.io  ClusterRole             team-a-escalation  Unknown  Missing

# E4-B (fence 3) — a row exists, STATUS is OutOfSync, MESSAGE carries the Kubernetes rejection
GROUP              KIND           NAMESPACE  NAME                 STATUS     HEALTH   HOOK  MESSAGE
networking.k8s.io  NetworkPolicy  team-a     team-a-default-deny  OutOfSync  Missing        networkpolicies.networking.k8s.io is forbidden: User "system:serviceaccount:argocd-access:argocd-manager" cannot create resource "networkpolicies" in API group "networking.k8s.io" in the namespace "team-a"
```

A CLI-only participant following §4 point 3 literally will count a row in both cases and reach the wrong conclusion on the lab's headline question. Add this immediately after §4 point 3:

> **Where to look for the result rows.** In the UI, the sync-result panel has a section literally headed **RESULT**, and a fence-3 failure fills it with a row whose STATUS is `SyncFailed`. In the CLI, `argocd app get` prints the Application's **resource tree** instead, which always has a row for every resource the Application manages — so the tell there is the **MESSAGE column**: empty for an Argo CD-side refusal, carrying the cluster's own rejection text for a Kubernetes-side one. If you want the literal result list from the CLI, ask for it:
>
> ```bash
> kubectl --context k3d-mgmt -n argocd get application <name> \
>   -o jsonpath='{.status.operationState.syncResult.resources}' ; echo
> ```
>
> It prints nothing at all for a fence-2/2b refusal, and one `"status":"SyncFailed"` entry for a fence-3 refusal.

Then change the §9 checkpoint column header from `Resource result rows?` to `Result rows (UI RESULT panel / syncResult)?` so participants know which table is being scored, and adjust E3 Part B "What to notice" 3 to say "no rows in the **RESULT** panel" rather than "no resource result rows in the panel".

#### RE-FIX 6. E4 Part A's log step returns two lines, and the sample drops the real line prefix — LOW

**Location:** E4 Part A, "Expected output (one line per denial; yours will carry your own timestamps)".

Actual, from this run:

```text
$ kubectl --context k3d-mgmt -n argocd logs deploy/argocd-server | grep "permission denied"
time="2026-09-12T16:50:18Z" level=warning msg="user tried to get application which they do not have access to: rpc error: code = PermissionDenied desc = permission denied: applications, get, storefront/storefront-prod-workload, sub: team-a-dev, iat: 2026-09-12T16:50:18Z" application=storefront-prod-workload namespace=argocd project=storefront security=2 user=team-a-dev
time="2026-09-12T16:50:18Z" level=warning msg="finished call" grpc.code=PermissionDenied grpc.component=server grpc.error="rpc error: code = PermissionDenied desc = permission denied" grpc.method=Get grpc.method_type=unary grpc.service=application.ApplicationService grpc.start_time="2026-09-12T16:50:18Z" grpc.time_ms=5.417 peer.address="10.42.0.1:62218" protocol=grpc
```

Change the caption to "**Expected output** (*two* lines per denial — the interesting one first, then gRPC's own record of the same call; yours will carry your own timestamps)", prefix the sample line with `time="2026-09-12T16:50:18Z" `, and add the second line. One extra sentence is worth having: *"The second line is the transport layer reporting the same refusal with `grpc.method=Get` — independent confirmation that the call that was blocked was the `get`, not the `sync`."* That strengthens the point the exercise is already making.

#### RE-FIX 7. Guide 06 still hands participants the answer to E1 Part B — LOW (cross-guide)

**Location:** `06-security-multitenancy-governance.md` §5.2 (lines ~275-278) and §7 "Try It Yourself" (lines ~425-444); affects Lab 5 E1 Part B.

The destination-message spoiler is gone (Guide 06 now uses tenant `payments`), but the RBAC half is not. Guide 06 prints, twice, for the same role and the same account:

```csv
p, role:team-a, applications, get,      team-a/*, allow
p, role:team-a, applications, sync,     team-a/*, allow
p, role:team-a, applications, action/*, team-a/*, allow
g, team-a-dev, role:team-a
```

and its §7 then runs the identical two unit tests Lab 5 E1 Part B asks the participant to devise (`sync` and `delete` on `team-a/team-a-guestbook`, `--policy-file`). Lab 5's "you write both files; the guide gives you the spec and the *shape*, not the finished answer" is therefore not true for Part B. Cheapest repair, mirroring what was already done for the destination example: rename Guide 06's policy example to a different tenant (`role:payments` / `payments-dev` / `payments/*`) and change its Try It Yourself object to `payments/payments-api`. Lab 5 then still teaches the shape without printing team-a's answer.

#### RE-FIX 8. E1 Part C's commit needs a Git identity that only Lab 2 sets — LOW

**Location:** E1 Part C; also an `environment-engineer` item.

`git commit` needs `user.name`/`user.email`. Nothing global sets them; only **Lab 2 §5.3** does, and only inside the clone the participant makes themselves. A participant who skipped or re-made that clone gets:

```text
Author identity unknown
*** Please tell me who you are.
fatal: unable to auto-detect email address
```

In this sandbox the clone is created by `bootstrap-vm.sh`, not by the participant, so it carried no identity and the commit failed until it was set (the Lab 2 values were used: `student@lab.local` / `Student`). Two cheap repairs, either is enough: (a) add one line to E1 Part C — *"If Git replies `Author identity unknown`, set the identity Lab 2 configured: `git -C ~/platform-config config user.email "student@lab.local"` and `… config user.name "Student"`"*; and/or (b) have `bootstrap-vm.sh` write `user.name`/`user.email` into the course `.gitconfig` so every clone inherits them. (b) also fixes the sandbox's parity gap with a participant who did Lab 2.

### R5. Expected vs. actual — no other differences

Every other printed command in the revised guide produced exactly the output the guide claims, including: §6.1 `cat`/`grep`; §6.3 both tools; E1 `argocd proj get team-a` (and the "your four kinds are not in this summary" caveat, plus the `-o yaml` claim that `clusterResourceWhitelist` is absent from the stored spec — confirmed); E2 `Synced`/`Healthy` with both resources; E3-A condition; E3-B sync result; E4-A terse denial and server log; E4-B `no` from `auth can-i` and the verbatim `forbidden` message; the three `--cascade=false` deletes (no prompt, as stated); E5-A interlock and detailed denial; E5-B finalizer listing (all eight rows `<none>`); §9 criteria 1, 3 and 4.

### R6. Runtime

| Segment | Machine time observed |
|---|---|
| §5.1 verifier | 2 s |
| §6.1 + §6.3 | ~6 s |
| E1 (apply project, unit tests, `apply-argocd-config.sh`, re-login, live checks, commit + push) | ~27 s, of which the apply is 17 s |
| bare `apply-argocd-config.sh` (extra verification, not in the guide) | 4 s |
| E2 (apply + sync + get) | ~2 s |
| E3 A + B | ~10 s |
| E4 A + B + cleanup | ~14 s |
| E5 A + B | ~3 s |
| `reset-lab.sh CP-capstone --local --yes` | 58 s |
| `reset-lab.sh CP-capstone --local --verify-only` | 2 s |
| **Total machine time on the required path** | **~65 s** |

Everything else is human time: reading sections 1-6, writing the AppProject from the spec table, writing and unit-testing the policy lines, writing the Application and three throwaways, recording five predictions, and filling the E4 comparison table and the §9 checkpoint table.

The revised header claims **~46 min required, budget 50**. That is now credible — a material improvement on the original 45-min claim, because two of the original time sinks are genuinely gone: the ~4.5-minute auto-sync retry wait (fix 7) and the per-apply re-login (fix 3's environment repair). Expect **50-60 minutes** for a participant writing an AppProject from a specification for the first time; the 8 minutes budgeted for E1 is the tightest cell in the table, since it now contains three authored artifacts plus a commit and push. Note that the budget still charges ~1 min per apply for a re-login that no longer happens, which quietly absorbs some of that overrun (see RE-FIX 2).

### R7. Screenshot accuracy check

All seven PNGs were opened and compared against the **revised** alt text and captions, and against the live states reproduced in this run. **All seven match. Nothing was re-captured.**

| File | Revised caption accurate? | Note |
|---|---|---|
| `lab-05-01-env-check-projects.png` | **Y** | `default`, `platform`, `storefront`; no `team-a`. Sidebar shows `v3.5.2`. Matches §5.2 verbatim. |
| `lab-05-02-project-team-a.png` | **Y** | SOURCE REPOSITORIES one entry; DESTINATIONS one row with **Name blank**; "The cluster resource allow list is empty"; NAMESPACE RESOURCE ALLOW LIST exactly ConfigMap, Service, Deployment/`apps`, NetworkPolicy/`networking.k8s.io`. Identical to the project I built in E1. The caption's four "What to notice" points are all visible. |
| `lab-05-03-destination-rejected.png` | **Y — now correct** | Shows `InvalidSpecError` and the full `do not match any of the allowed destinations in project 'team-a'` message. The revised alt text quotes it exactly; the original mismatch is resolved. |
| `lab-05-04-cluster-scoped-blocked.png` | **Y — now correct** | OPERATION Sync, PHASE Error, the `ComparisonError … can not be managed when in namespaced mode` MESSAGE, identical STARTED AT / FINISHED AT, DURATION 0s, INITIATED BY admin, **and no RESULT section at all**. The revised caption's layer claim now matches the image. |
| `lab-05-05-argocd-rbac-denied.png` | **Y — now correct** | `Failed to load data, please try again.` plus the toast `Unable to load data: permission denied`, and no SYNC/DELETE/REFRESH buttons — exactly what the revised alt text describes and what E4 Part A now predicts. |
| `lab-05-06-kubernetes-forbidden.png` | **Y** | PHASE Failed, the verbatim `forbidden` MESSAGE, and a **RESULT** table with one row, STATUS `SyncF…` (`SyncFailed`), MESSAGE repeating the Kubernetes rejection. This image is also the evidence for RE-FIX 5: the panel that proves the guide's point is labelled RESULT and exists only in the UI. |
| `lab-05-07-delete-denied.png` | **Y** | Delete dialog with the "will delete all the application's managed resources" warning, the typed-name confirmation, the three propagation radios (Foreground selected / Background / Non-cascading), and the toast `Unable to delete application: permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev, iat: …` — the same detailed string the CLI produced in E5 Part A this run. |

### R8. Reproducibility and environment-parity concerns

1. **Seed drift (RE-FIX 4) is the significant one.** Because `reset-lab.sh` republishes from the local seed **mirror** rather than from the courseware checkout, a sandbox and a freshly bootstrapped VM can serve different repository content indefinitely. Any guide text that quotes file line numbers or values-derived output (§6.1's `grep -n`, E2's `URL:` line) is only as stable as the last `seed-repos.sh` run. Recommend `environment-engineer` add a bootstrap/reset banner naming the seed commit, so a tester can tell at a glance which content a machine is serving.
2. **Course commands on `PATH`** are implemented but unexercised here; needs one fresh-bootstrap pass (VM and `--local`).
3. **Git identity** (RE-FIX 8) — the sandbox's bootstrap-created clone does not match a participant's Lab 2-created clone.
4. **Unchanged from the original run:** UI access is direct (`https://localhost:8443`) here and via SSH tunnel on the VM; nothing else in this lab depends on ingress, DNS or external network. No public internet was needed at any point — Gitea, the chart and the images are all local.
5. **Resource use stayed modest** and unchanged from the original run; no lab step is heavy enough to strain a shared classroom VM.

### R9. Optional improvements (new, additive to the original list)

1. **E3 hint 1 could name the file paths it implies.** The printed commands read `/tmp/team-a-wrong-dest.yaml` and `/tmp/team-a-clusterrole.yaml`, but the hint only says "copy your E2 file twice". One clause — "save the copies as `/tmp/team-a-wrong-dest.yaml` and `/tmp/team-a-clusterrole.yaml`, which is what the commands below expect" — removes the only moment in the lab where a participant has to infer a path.
2. **E4-A gains a free reinforcement** from `argocd app list` as `team-a-dev`: it prints only `argocd/team-a-guestbook` (plus any throwaways still in project `team-a`) and no `storefront-*` row at all, which makes "least privilege, not no access" visible rather than asserted. It is one command and supports "What to notice" 3 directly.
3. **The `values.yaml` comment participants read in §6.1 is stale.** It says the `role:team-a` policy is "applied via the CP-capstone values overlay in resets", but resets now pin the checkpoint's values through `$ARGOCD_VALUES_FILE` and the overlay list is empty. The newer seed file already fixes this wording; it is another argument for settling RE-FIX 4.
4. **§9's self-check would be sharper with the `syncResult` one-liner** from RE-FIX 5 offered as the mechanical way to fill the "result rows" column, rather than leaving it to eyeballing.

### R10. Interestingness (re-assessed): **STRONG**

The original caveat is gone. E3 Part B is no longer a prediction contradicted by its own evidence — it now *asks* which of two guards the participant built will speak first, and the answer ("the cluster registration, because live state is loaded before sync tasks are built") is a genuinely non-obvious piece of Argo CD internals that the message text alone proves. E4's contrast between the terse and the detailed `permission denied` is now paid off explicitly in E5 Part A, which is the best single moment in the lab: the same fence, two different amounts of disclosure, with a stated rule for why. E1 Part C turns the governance claim from an assertion into something the participant does and can see discarded by a reset. Participants predict five times, write three artifacts from specifications, unit-test a policy before shipping it, read a server log, and answer "which team do you page" — this is decision-making, not transcription.

The one drag on it is RE-FIX 7: anyone who read Guide 06 §5.2 attentively already has E1 Part B's answer.

### R11. Final sandbox state

- **`reset-lab.sh CP-capstone --local --verify-only` -> PASS (22/22)**, including `Argo CD RBAC role:team-a -> team-a-dev present` — and this time with **no deviation**: the Lab 5 -> capstone handoff holds on the participant path exactly as printed.
- Applications, all `Synced`/`Healthy`: `platform-root`, `platform-quotas`, `platform-netpol`, `platform-agent`, `storefront-{dev,staging,prod}-workload`, `team-a-guestbook`. All three throwaways deleted.
- AppProjects: `default`, `platform`, `storefront`, `team-a`. Live `policy.csv` holds the checkpoint's four lines (`get`, `sync`, `action/*`, and the `g,` binding).
- Participant clone `~/platform-config` reset to `origin/main` at `b14a82c checkpoint CP-capstone`, working tree clean; the E1 commit `bb81436` was discarded by the reset, as the guide warns.
- No sync windows, no project roles, no capstone fault markers, `applicationsetcontroller.policy` absent. Workload cluster: `team-a` runs the guestbook Deployment + Service, no NetworkPolicy, no `team-a-escalation` ClusterRole.
- Gitea repositories still carry the **pre-`d99a26c`** seed content (deliberately not re-seeded, so RE-FIX 4 stays reproducible).

### R12. Environment scripts changed in this re-test

**None.** Nothing blocked execution, so no environment script was modified. The only files this re-test touched under version control are this report and the commit recording it.

### R13. Retest requirements

1. **One fresh-bootstrap pass** (`bootstrap-vm.sh` from `d99a26c` or later, then `reset-lab.sh CP-lab-05`) to settle RE-FIX 4 — the §6.1 `grep` output and whether `global.domain` takes effect — and to confirm the course commands land on `PATH` in both VM and `--local` mode. Until that runs, §6.1 and E2's `URL:` callout are verified only against a stale sandbox.
2. **Re-read §5.1, §6.2, E1 Part B, E2 Hint 3, §8 rows 1-2, §4 point 3 and §9's checkpoint header** after RE-FIX 1, 2, 3 and 5 land; all four are text-only and need no cluster work to verify beyond one `reset-lab.sh CP-lab-05 --verify-only` and one `apply-argocd-config.sh`.
3. **Guide 06** needs its own small pass for RE-FIX 7, then a check that Lab 5 E1 Part B is no longer pre-answered anywhere in Day 2.
4. **One pass on a real provisioned VM** for the SSH-tunnel UI path (carried over from the original run, still outstanding).
5. No re-capture of any Lab 5 screenshot is required unless RE-FIX 5 changes what E3 Part B and E4 Part B ask participants to look at; the seven current PNGs are accurate to the shipped guide and to the live UI.
