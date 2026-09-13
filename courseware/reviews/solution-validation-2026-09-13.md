# Solution validation — instructor walkthroughs for Labs 1–5 and the Capstone

- **Date:** 2026-09-13
- **Deliverables validated:** `courseware/instructor/README.md` and the six walkthroughs under `courseware/instructor/day-1/` and `courseware/instructor/day-2/`
- **Participant guides:** read, executed, and **not modified**
- **Final status:** **PASS WITH NOTES** for every walkthrough (each solution executes and reaches its stated result). Several **participant guide and environment defects** were found; they are listed in Section 4 for `lab-engineer` and `environment-engineer`. The walkthroughs document classroom workarounds for all of them.

---

## 1. Environment used

Local two-cluster sandbox on the build machine (macOS/arm64, Docker Desktop), the `bootstrap-vm.sh --local` layout. Not a provisioned classroom VM.

| Component | Version observed |
|---|---|
| Argo CD server | `v3.5.2` (chart `10.8.4`) |
| `argocd` CLI | `v3.5.2+e258ee2` |
| Kubernetes (`k3d-mgmt`, `k3d-workload`) | `v1.35.8+k3s1` |
| Helm (pinned, `~/.argocd-course/bin`) | `v4.2.1` |
| `yq` (pinned) | `v4.48.1` |
| `timeout.reconciliation` in `argocd-cm` | `60s` |

### Deviations from the printed commands (none change lab semantics)

| Guide text | Run locally as | Why |
|---|---|---|
| `reset-lab.sh …`, `apply-argocd-config.sh …` | Full script path, with `--local` / `COURSE_LOCAL=1` | Build-machine sandbox mode |
| `~/course/credentials/…`, `~/course/lab-files/…` | `~/.argocd-course/student-home/course/credentials/…`; lab files from `courseware/environment/lab-files/` | Local-mode `COURSE_USER_HOME` |
| Participant clones in `~` | Scratch clones; `git push` via a non-interactive credential helper reading the credential file | Non-interactive shell; values never printed |
| `argocd login --username team-a-dev` (prompt) | `--password "$(cat …/team-a-dev.txt)"` | Non-interactive shell |
| `source ~/argo-lab-env.sh` | **Not sourced** | On this machine the file sets `COURSE_USER_HOME=$HOME`, and `reset-lab.sh` hard-resets and `git clean`s every Gitea-backed clone under that directory. Local mode's default student home was used instead |

---

## 2. Execution summary

| Walkthrough | Start state | Executed | End-state check | Status |
|---|---|---|---|---|
| Lab 1 | `CP-lab-01` verified | Sections 5–6, E1–E4, stretch (`replicaCount: 0`), with and without the chart rollout annotation | Live revision = `git rev-parse HEAD`; new message served | PASS WITH NOTES |
| Lab 2 | `CP-lab-02` after reset | E1 (both `yq` and `envsubst` renderings), E2, E3, E4 (including the one-`..` wrong turn), E5 records 1 and 2, stretches A and C | `reset-lab.sh CP-lab-03 --verify-only` → PASS (11/11) | PASS WITH NOTES |
| Lab 3 | `CP-lab-03` (Lab 2 output) | E1–E5 including the failing promotion and revert, stretches 1 and 2; Part B run three ways | Both environments `Synced`/`Healthy` at the latest commit | PASS WITH NOTES |
| Lab 4 | `CP-lab-04` after reset | E1 (with three wrong turns), E2, E3, E4, E5A (strict and non-strict), E5B (including the wrong-layer patch), stretches 1, 2 (preview), 3 (applied safely) | `reset-lab.sh CP-lab-05 --verify-only` → PASS (21/21) | PASS WITH NOTES |
| Lab 5 | `CP-lab-05` after reset | E1 (with four offline wrong turns), E2–E5, §9 checkpoint, stretches 1, 3, 4 (guide form and corrected form) | `reset-lab.sh CP-capstone --verify-only` → PASS (22/22) | PASS WITH NOTES |
| Capstone | `CP-capstone` after reset; `inject-capstone-faults.sh inject all` | Full incident: triage, repairs F7 → F1 → F5 → F2 → F3 → F4 → F6 through the guide's change paths, `capstone-check.sh` after each repair | See Section 3 | PASS WITH NOTES |

---

## 3. Capstone execution log

| Step | Change path | Change | `capstone-check` unresolved areas after the step |
|---|---|---|---|
| Inject all | — | F1, F2, F3, F6, F4, F5, F7 | 4 (F5 reported **ABSENT** by `verify` — see finding E-1) |
| Instructor pre-flight | — | Recreated ServiceAccount `argocd-manager` + token Secret (makes F5 real) | 5 |
| C1 — F7 | B | `git revert` of "argocd: right-size repo-server memory"; `apply-argocd-config.sh` (20 s) | 4 |
| C2 — F1 | A | `git revert` of "staging: drop stale image.tag pin" | 3 |
| C3 — F5 | C | Re-rendered and applied `cluster-workload` from the template with the live token and CA | 2 |
| C4 — F2 | A + C + D | `git revert` of "storefront appset: simplify cluster selector"; `kubectl apply` of the ApplicationSet; three `argocd app delete … --cascade=false` | 3 (F4 revealed on three Applications) |
| C5 — F3 | A + D | `git revert` of "platform: add team-root app-of-apps" (root pruned `team-root`); `argocd app delete platform-agent-dup --cascade=false` | 2 |
| C6 — F4 | C | `kubectl --context k3d-workload apply -f workload-rbac.yaml` (only the RoleBinding was created; token unchanged) | 1 |
| Trap (deliberate) | D | `argocd app sync storefront-prod-workload` while pinned to `storefront-1.1.0`, to record what the guide's "make a deliberate sync" advice produces | 1 — HPA created, replicas 2 → 5, new ReplicaSet never Ready (`ProgressDeadlineExceeded`), app flapping `Synced/Progressing` ↔ `OutOfSync/Degraded`; users still served `6.15.0` |
| C7 — F6 | A | `git revert` of "prod: promote to storefront-1.1.0" (ApplicationSet moved the pin after 31 s) | **0 — false green.** `capstone-check` exit 0 and eight `Synced`/`Healthy` Applications for 2 min, while the leftover HPA and self-heal fought every ~90 s; every resource row in prod's tree read `Unknown` (stale cluster cache — finding E-8) |
| Cache rebuild | refresh-class | `POST /api/v1/clusters/<server>/invalidate-cache` (HTTP 200) | 0 — HPA pruned within 4 s; replicas held at 2 for 2 min; no `Unknown` resource rows |
| Pre-merge stretch script | — | Run against repaired `main`, then with F2 and F1 reproduced locally (unpushed) | exit 0 / 1 (three "unexpected Application" lines) / 1 ("FAIL render: staging") |
| Cleanup | — | `reset-lab.sh CP-capstone --local --yes` | `PASS CP-capstone is in the expected state.`; `ok no faults injected`; no HPA in `storefront-prod` |

---

## 4. Defects found (for routing)

Severity: **H** = derails a class session or breaks a lab's success criterion; **M** = misleading, with a workaround; **L** = cosmetic or wording.

### Environment (`environment-engineer`)

| ID | Sev | Finding | Evidence | Recommended fix |
|---|---|---|---|---|
| E-1 | **H** | Capstone **F5 is a no-op.** Deleting and recreating `argocd-manager-token` under the same name produces a byte-identical legacy token (claims: `iss`, namespace, `secret.name`, `service-account.name`, `service-account.uid`, `sub` — no issue time, no Secret UID; deterministic signature) | `inject-capstone-faults.sh verify F5` → `ABSENT`; live and stored token SHA-256 identical after inject; `capstone-check` reported connectivity resolved | In F5 `inject.sh`, recreate the **ServiceAccount** (new UID → new token) *without* re-applying the RoleBindings, or create the token Secret under a new name. Verified workaround in the capstone walkthrough §0 |
| E-2 | **H** | `podinfo:6.16.0` does not exist; Lab 3 E2's promotion always fails | Docker Hub tag API: `6.16.0` → 404, `6.15.0` → 200 (latest, 2026-08-31); `ImagePullBackOff` "not found" | Seed env values at `6.14.1`, pre-load `6.14.1` and `6.15.0`, promote to `6.15.0` — or keep the failure and rewrite E2 as a planned revert exercise |
| E-3 | **H** | Credentials in `last-applied-configuration`. Client-side `kubectl apply` of `stringData` Secrets stores the password/token in the annotation; `argocd appset generate` errors dump it; ApplicationSet templates can read it through the cluster generator | All three course credential Secrets contain the field; Lab 4 E5A preview error printed the cluster bearer token; a server-side-applied test Secret had no such annotation | Use `kubectl apply --server-side` (or strip the annotation) in `reset-lab.sh`, the F5 revert, and the Lab 2 guide commands |
| E-4 | M | `reset-lab.sh CP-lab-02` leaves `repo-storefront-gitops` and `cluster-workload` in place; the verifier doesn't check their absence | Both Secrets 46 h old after reset; repo and cluster already `Successful` at Lab 2 start | Delete non-checkpoint repository/cluster Secrets in step 4; add absence rows to the `CP-lab-02` verifier |
| E-5 | M | The sandbox's `hello-reconcile` chart predates commit `21a3fc8` (no `course.message` rollout annotation) | Message change synced, no Pod restart, old message served | Re-seed; add the annotation check to the Lab 0 / baseline verifier |
| E-6 | M | Capstone **F4 comment and design are inaccurate**: removing the `argocd-deployer` RoleBinding also removes `get/list/watch`, so F4 appears as `ComparisonError … forbidden` on `storefront-prod-workload`, `platform-quotas`, and `platform-netpol`, and `capstone-check` reports it under "source rendering" and "runtime health" rather than "deployment policy" | Condition messages and `capstone-check --instructor` output during C4–C5 | Either accept and document (the capstone walkthrough does), or split read and write verbs into separate Roles so F4 is a sync-time 403 |
| E-7 | L | `~/argo-lab-env.sh` sets `COURSE_USER_HOME=$HOME`; `reset-lab.sh` then resets every Gitea-backed clone in the home directory | Code reading of `refresh_participant_clones()` | Scope the clone refresh to the course repository names |
| E-8 | **H** | **`capstone-check.sh` can report a false "all areas resolved".** When F5 is repaired before F4, the cluster cache is rebuilt while `storefront-prod` reads are still forbidden; repairing F4 does not rebuild it. Argo CD then compares prod against a stale cache: every resource row reads `Unknown`, `argocd app diff` exits 0, a leftover HPA is never pruned, and self-heal fights it — while every Application reports `Synced`/`Healthy` | `capstone-check` exit 0 and an unchanged eight-row inventory across 2 min while replicas flipped 5 ↔ 2; `POST …/invalidate-cache` → HTTP 200 → HPA `Pruned` in 4 s. Re-applying the unchanged cluster Secret did not rebuild the cache | (a) In `capstone-check`, treat any Application whose `status.resources[*].status` contains `Unknown` as unresolved, and compare live `spec.replicas` for prod with Git; (b) have `F4/revert.sh` (and the capstone solution path) invalidate the workload cluster cache after restoring the RoleBinding; (c) consider an `argocd` CLI-free "invalidate cache" helper for instructors |

### Participant guides (`lab-engineer`)

| ID | Sev | Guide | Finding | Evidence / correct text |
|---|---|---|---|---|
| G-1 | **H** | Lab 3 E5 Part B | A hook-only change (`migration.shouldFail: true`) never triggers auto-sync; failing automated syncs retry 5× by default; a fix commit does not replace a retrying operation | Verified 3×; `operation.retry = {"limit":5}` attached with no spec retry; recovery needed `argocd app terminate-op` |
| G-2 | M | Lab 1 E2 Step E | `grep -o '"message":"[^"]*"'` matches nothing | Use `grep -o '"message": *"[^"]*"'` |
| G-3 | M | Lab 1 E3 | `sed -n '/kind: ConfigMap/,/^---/p'` omits `data:` | Use `yq 'select(.kind == "ConfigMap")'` |
| G-4 | M | Lab 5 E3 Part A | `argocd app sync team-a-wrong-dest` never returns | Add `--timeout 30` |
| G-5 | M | Lab 5 stretch 4 | `--object 'team-a/*'` → `team-a/team-a/*`; a sync-only role cannot `get` | `--object '*'`, and add `--action get` |
| G-6 | M | Lab 2 stretch A | `argocd cluster add` leaves cluster-wide RBAC and a long-lived token on the workload cluster | Add cleanup commands and a warning |
| G-7 | M | Lab 2 E5 record 2, SS-L2-10 caption | Guide says "Failed"; UI shows `Unknown`, CLI status empty (no Application uses the cluster) | Reword around "nobody measured" |
| G-8 | M | Lab 4 stretch 1 | A `ComparisonError` child keeps health `Healthy`, so re-running 5B shows no difference; a `Progressing` child does propagate | Change the suggested experiment |
| G-9 | M | Lab 4 stretch 3 | The controller refuses duplicate names (`contains applications with duplicate name`) and creates nothing; it does not flap | Replace the "experimental" hypothesis with the verified behavior |
| G-10 | L | Lab 3 troubleshooting row 2 | Message is now `InvalidSpecError … do not match any of the allowed destinations in project 'storefront'` | Update the string |
| G-11 | L | Lab 3 E4 | Self-heal reverted in ~2 s, not "roughly one 60-second interval" | Distinguish Git polling from resource watches |
| G-12 | L | Lab 3 §9.1 | `argocd app list -o wide` has no REVISION column | Use `kubectl … -o custom-columns=…REVISION:.status.sync.revision` |
| G-13 | L | Lab 1 §6.2, Lab 1 SS-L1-06 caption | Sample output layout is pre-3.5; with the rollout annotation the diff shows two resources | Refresh sample; reword caption |
| G-14 | L | Lab 4 E1 | The unfilled skeleton previews zero rows, not names containing `TODO` | Mention zero rows |
| G-15 | L | Lab 4 E5A recovery | The ApplicationSet condition can lag up to 3 min (`requeueAfter=3m0s`) after the fix | Say so, and confirm with `argocd appset generate` |
| G-16 | L | Lab 1 / Lab 4 verifier samples | Real verifier output has extra "team-a absent" rows | Refresh samples |
| G-17 | **H** | Capstone | (a) Section 8's "make a deliberate, logged sync" advice, applied to `storefront-prod-workload` while it is pinned to `storefront-1.1.0`, deploys the bad release (verified: HPA created, `ProgressDeadlineExceeded`, `Degraded` ↔ `Progressing` flapping). (b) Section 9's "fully restored" criteria and `capstone-check` can all pass on a stale cache (E-8). (c) §6.3.5 signature table: the fence-2 text is now `do not match any of the allowed destinations in project`, and a Kubernetes `forbidden` can arrive as a `ComparisonError` with no sync started (F4) | Add "read `argocd app diff` before any deliberate sync" to Section 8; add a no-`Unknown`-resources check and a two-reading replica check to P3 / Section 9; update the signature table |
| G-18 | M | Capstone | The guide embeds `capstone-01-incident-start.png`, `capstone-02-restored.png`, and `capstone-03-clusters-restored.png`; none of the three files exists in `courseware/assets/screenshots/day-2/`, so all three figures render as broken images | Capture them per the guide's CAPTURE-SPEC comments (SS-CAP-01 needs the F5 injection fix from E-1 first, or it will show a six-fault incident) |

---

## 5. Answer-separation check

- All solution content lives under `courseware/instructor/`. No participant guide was edited.
- Each walkthrough carries an "INSTRUCTOR ONLY" banner.
- No password, token, or CA value appears in any walkthrough or in this report. Verified by construction: every credential was injected through a variable or pipe; token comparisons used truncated SHA-256 digests only.

## 6. Screenshot / UI consistency

No screenshots were re-captured (no browser automation was used in this pass). The walkthroughs link the participant guides' existing figures. Two captions disagree with verified behavior (G-7 SS-L2-10, G-13 SS-L1-06). SS-L3-09 shows an operation in `Failed`; under v3.5.2 defaults an **automated** Part B failure shows `Running` with retries for several minutes (G-1), so that figure most likely came from a manual sync — not re-verified.

## 7. Sandbox state at the end of this pass

- `reset-lab.sh CP-capstone --local --yes` → `PASS CP-capstone is in the expected state.` (22 checks).
- `inject-capstone-faults.sh status --local` → `ok no faults injected`.
- No HPA in `storefront-prod`; no leftover `argocd-manager` ServiceAccount, ClusterRole, ClusterRoleBinding, or token in `kube-system` on the workload cluster (Lab 2 stretch A cleanup verified).
- No throwaway ApplicationSets, Applications, AppProject roles, or sync windows remain.
- Scratch clones and helper scripts live only in the session scratch directory; nothing under `courseware/environment/` was modified.
