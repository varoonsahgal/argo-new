# Lab validation — Lab 5, Enforce Platform Guardrails

- **Lab under test:** `courseware/day-2/lab-05-enforce-platform-guardrails.md` (603 lines)
- **Learning objective (as stated):** build a restrictive AppProject for `team-a`, prove each restriction by trying to violate it, and tell an **Argo CD** authorization failure from a **Kubernetes** authorization failure (outline L5.1–L5.5, outcomes O6/O7).
- **Tested by:** `lab-tester`, 2026-09-11 / 2026-09-12
- **Validation status:** **FAIL** (blocking defects 1–5 below; everything else is repairable text)
- **Interestingness rating:** **STRONG** (with one caveat — see "Interestingness" at the end)

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
