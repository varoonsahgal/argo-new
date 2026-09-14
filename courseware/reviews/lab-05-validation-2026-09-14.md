# Lab 5 validation: Enforce Platform Guardrails (2026-09-14)

- **Date:** 2026-09-14, one continuous run (07:51–12:30 local)
- **Scope:** `courseware/day-2/lab-05/` (README, modules 01–04), the stub `lab-05-enforce-platform-guardrails.md`, the instructor walkthrough `courseware/instructor/day-2/lab-05-enforce-platform-guardrails-SOLUTION.md`, row 8 of `courseware/instructor/README.md`, Session 6 screenshot SS-S6-01, and the screenshot harness
- **Objectives tested:** L5.1–L5.5 (outcomes O6, O7)
- **Earlier reports (untouched):** `lab-05-validation.md` (2026-09-11 run and 2026-09-12 re-test)

## Verdict

**PASS WITH NOTES** (after the fixes below). **Interestingness: STRONG.**

**Before this pass the lab was PASS WITH NOTES, but with two known defects.** Each could stall a participant or a live demo:

- **G-4:** `argocd app sync team-a-wrong-dest` never returns.
- **G-5:** stretch 4's commands produce a project role that can do nothing.

Several expected-output blocks were also not real. Examples:

- a hand-wrapped condition row with a missing column;
- a `grep -n -A6` block missing two lines, with no `...`;
- E3B's `Phase:`/`Message:` block in an invented layout.

Every required-path message still matched the guide word for word. Every item was fixed and re-executed. The remaining notes are environment observations and checks that need a VM (Section 8).

**Why STRONG:** participants predict five refusals before seeing them, write two artifacts from a specification, unit-test a policy offline before shipping it, read a server log, and decide "which team do you page". E3B (two guards, the unexpected one speaks) and E4A/E5A (the same fence discloses different amounts) remain the sharpest moments.

---

## 1. Environment tested

Local two-cluster sandbox on the build Mac (macOS arm64, Docker Desktop), not a provisioned student VM.

| Component | Observed |
|---|---|
| Argo CD server / `argocd` CLI | `v3.5.2` / `v3.5.2+e258ee2.dirty` |
| Helm chart / Helm | `argo-cd-10.8.4` / pinned `v4.2.1` |
| Kubernetes (`k3d-mgmt`, `k3d-workload`) | `v1.35.8` (`argocd cluster list`) |
| Gitea | `lab-gitea` container; repositories re-seeded (`seed-repos.sh --local`) just before this run |
| Screenshot harness | `capture.mjs` (Playwright headless Chromium, 1440×900 unless the shot overrides) |

**Local mappings (no change to lab semantics):**

- `~/platform-config` → `$HOME/.argocd-course/student-home/platform-config`; `~/course/credentials/…` → `$HOME/.argocd-course/student-home/course/credentials/…`. Git ran with `GIT_CONFIG_GLOBAL` set to that home's `.gitconfig` (the `lab-gitea` → `localhost` rewrite); the push used the clone's existing scratchpad credential helper, which reads `gitea-student.txt`.
- Relative commands (`kubectl apply -f platform-config/…`) were run from the student home, which is what a fresh terminal in `~` gives a participant.
- `~/argo-lab-env.sh` was **never sourced**; `COURSE_USER_HOME` stayed unset. Scripts ran by full path with `--local` / `COURSE_LOCAL=1`. Every `kubectl` call named `k3d-mgmt` or `k3d-workload`; the EKS context was never used. `inject-capstone-faults.sh` was not run.
- `argocd login --username team-a-dev` was given `--password "$(cat …/team-a-dev.txt)"` because the shell is non-interactive.
- The guide's `/tmp/*.csv` and `/tmp/team-a-*.yaml` paths were used as printed, then deleted.
- **Secrets:** no password, token, CA, or annotation value was displayed. The stretch 4 JWT went straight into a variable; only its length was printed.
- **Tooling friction (disclosed):** the session's permission classifier blocked one `argocd app wait` and one combined `argocd app get` + `kubectl … jsonpath` call. Health timing came from the object's `status.health.lastTransitionTime` instead.
- The G-4 hang test used `perl -e 'alarm 45; exec …'`, which does **not** stop the Go-based CLI (SIGALRM does not end a Go program). The hung CLI (a process started by this run) was stopped with SIGTERM after 3 min 27 s.

**Parity notes for the real VM** (environment-engineer / instructor):

- UI checks used headless Chromium via the harness, not Firefox on a VM.
- The SSH-tunnel UI path was not exercised.
- Classroom-load timing was not measured.

---

## 2. Reset and runtime timings

| Command | Result | Time |
|---|---|---|
| `reset-lab.sh CP-lab-05 --yes --local` (from the fresh re-seed) | 22/22 PASS | **72 s** (previous run: 6 min 46 s; target "under 3 minutes" met on this Mac) |
| `reset-lab.sh CP-lab-05 --verify-only --local` | 22/22 PASS | 1.9 s |
| `apply-argocd-config.sh <values path>` (E1 Part B) | `account passwords unchanged` | 7 s |
| `reset-lab.sh CP-capstone --verify-only --local` on the participant-built state | 23/23 PASS | ~2 s |
| `reset-lab.sh CP-capstone --yes --local` (final) | 23/23 PASS, `ok no fault markers present` | **47 s** |

The step-9 row `Repository and cluster Secrets are exactly: in-cluster, repo-storefront-gitops, cluster-workload, course-repo-creds` printed PASS in every verification.

**Machine time on the required path** is under two minutes, excluding the one-off G-4 hang. Apply: 7 s. E2: ~2 s. E3/E4 syncs: 0 s each. With `--timeout 30`, E3A adds a deliberate 30 s wait. The ~50-minute budget remains human time: writing the project and policy, predictions, the comparison table, and the debrief.

---

## 3. Execution log

| # | Step (module) | Command / action | Expected (guide before fix) | Actual | Result |
|---|---|---|---|---|---|
| 1 | M01 §1 | `reset-lab.sh CP-lab-05 --verify-only --local` | abridged: apps Synced/Healthy, AppSet present, `team-a` / `team-a-guestbook` absent | 22 rows PASS incl. both absence rows and the new Secrets row | PASS |
| 2 | M01 §1 UI | Settings → Projects (SS-L5-01) | `default`, `platform`, `storefront`, no `team-a` | identical; re-capture byte-identical | PASS |
| 3 | M01 §2 | `cat platform-config/projects/storefront.yaml` | four fence fields | three destinations, `clusterResourceWhitelist: []`, five namespaced kinds | PASS |
| 4 | M01 §2 | `grep -n -A6 "rbac:" …/values.yaml` | 3 lines (141, 144, 145) | **5 lines** (141–145, incl. two comment lines) | **D1** fixed |
| 5 | M01 §4 | offline `rbac can` demo; `auth can-i create deployments.apps` | `Yes`; `yes` | `Yes`; `yes` | PASS |
| 6 | E1 A | `argocd cluster list`; `api-resources \| grep -i networkpolic`; write + apply project; `proj get` (+ `-o yaml`) | URL has ` (5 namespaces)` suffix; summary; no `clusterResourceWhitelist` key | exactly as described (`https://k3d-workload-server-0:6443 (5 namespaces)`; `Allowed Cluster Resources: <none>`; key absent) | PASS |
| 7 | E1 B offline | unit tests + wrong turns | sync `Yes` / delete `No` | `Yes`/`No`; object `team-a` → `No`; `*` action → delete `Yes`; `*` object → storefront sync `Yes`; no `g,` → `No`; swapped args → fatal `error in RBAC request: 'sync' is not a valid resource name`; no source flag → 84 lines of help then fatal `please provide exactly one of --policy-file or --namespace` | PASS; troubleshooting row **D2** fixed |
| 8 | E1 B apply | `apply-argocd-config.sh <path>`; live `rbac can` ×2 | `account passwords unchanged`; `Yes`/`No` | `values source: platform-config main (Gitea 3800f4e)`, `account passwords unchanged`, overlay line; session survived; `policy.csv` 3 lines; `Yes`/`No` | PASS |
| 9 | E1 C | `git add/commit/push` | commit + push | `[main 3892023]`; `3800f4e..3892023 main -> main` | PASS |
| 10 | E1 UI | SS-L5-02 | one repo, one destination (Name blank), empty cluster list, four kinds | identical; re-capture byte-identical | PASS |
| 11 | E2 | `mkdir`; apply; `argocd app sync`; `argocd app get` | `Synced`/`Healthy` | sync 1 s, rc 0, **its final table shows both resources `OutOfSync`/`Missing`** (MESSAGE `created`); immediate `get`: `Synced`, **`Progressing`**; `Healthy` about 1 s later; `URL: https://localhost:8443/applications/team-a-guestbook` | **D3** note added |
| 12 | E3A | yq copy; apply; `argocd app get` | `Unknown`/`Unknown`, hand-wrapped condition | `Unknown`/`Unknown`; one-line condition row with a `LAST TRANSITION` column | **D4** fixed |
| 13 | E3A sync (no timeout) | `argocd app sync team-a-wrong-dest` | "ends immediately" | operation `Phase: Error`, `Duration: 0s`, empty `syncResult` — but the **CLI was still waiting after 207 s** | **G-4** confirmed |
| 14 | E3A sync (timeout) | `argocd app sync team-a-wrong-dest --timeout 30` | — | rc 20 after 30 s: `timed out (30s) waiting for app "team-a-wrong-dest" match desired state`; `storefront-prod` has no `guestbook` | **G-4** fixed |
| 15 | E3A UI | SS-L5-03 | InvalidSpecError row | identical message | PASS; re-captured |
| 16 | E3B | yq copy; apply; `argocd app sync team-a-clusterrole ; argocd app get …` | `Phase: Error` block | **returns in 0 s**, rc 1, ends `{"level":"fatal","msg":"Operation has completed with phase: Error",…}`; Phase/Duration/Message printed by the *sync* (20-column layout); `get` shows a `ComparisonError` condition, `Unknown`/`Missing`; `syncResult` empty; ClusterRole `NotFound` | **D5** fixed (real block, safety `--timeout 60`) |
| 17 | E3B UI | SS-L5-04 | Phase Error, ComparisonError, no RESULT | identical | PASS; re-captured |
| 18 | E4A | login `team-a-dev`; `argocd app sync storefront-prod-workload`; `argocd app list -o name` | terse `permission denied` | rc 20 in 0 s, terse message; list shows only the three `team-a` apps | PASS (no hang) |
| 19 | E4A log | admin login; `logs deploy/argocd-server \| grep "permission denied"` | two lines, `get`, `security=2` | two lines, identical shape (`applications, get, storefront/storefront-prod-workload, sub: team-a-dev`; `grpc.method=Get`) | PASS |
| 20 | E4A UI | SS-L5-05 as `team-a-dev` | "Failed to load data" + toast | identical | PASS; re-captured |
| 21 | E4B | `auth can-i create networkpolicies…`; yq copy; apply; sync ; get; `syncResult` | `no`; `Phase: Failed`; forbidden; `SyncFailed` row | `no`; returns in 0 s, rc 1, fatal `…phase: Failed`; verbatim forbidden message; tree row `OutOfSync` with the message; `syncResult` one `"status":"SyncFailed"` entry | PASS; **D6** (safety timeout + fatal line) |
| 22 | E4B UI | SS-L5-06 | Phase Failed, RESULT SyncFailed | identical | PASS; re-captured |
| 23 | E4 cleanup | three `argocd app delete … --cascade=false` | no prompt | `application '…' deleted` ×3, rc 0; only `team-a-guestbook` left; nothing new on the workload cluster | PASS |
| 24 | E5A | interlock; login `team-a-dev`; `argocd app delete team-a-guestbook`; admin login | `No`; detailed denial | `No`; `permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev, iat: …` (rc 20, 0 s); no `deletionTimestamp` | PASS |
| 25 | E5B | `custom-columns` finalizer listing | every row `<none>` | 8 rows, all `<none>` | PASS |
| 26 | E5B UI | SS-L5-07 as `team-a-dev` | dialog + detailed toast | identical (sidebar "Synced 2 / Healthy 2" are the app's two resources, not apps) | PASS; re-captured |
| 27 | Checkpoint | criteria 1–4 | — | guestbook `Synced`/`Healthy`; throwaways gone; `Yes`/`No`; `git log -1 --stat` shows `3892023` touching `argocd/values.yaml` and `projects/team-a.yaml` | PASS |
| 28 | Procedure step 4 | `reset-lab.sh CP-capstone --verify-only --local` on participant state | "finishing Lab 5 = capstone start" | **23/23 PASS**; three unchecked gaps (Section 7) | PASS WITH NOTES |
| 29 | Stretch 1 | offline deny (both orders); live overlay | `No` | offline delete `No` / sync `Yes` in both orders; live `policy.csv` carries the deny; delete `No`, sync `Yes` | PASS |
| 30 | Stretch 2 | key placement; apply; cm; env; probe AppSet; revert | "set in the values … revert with a reset" | the chart has no default key; the values file has a tempting top-level `applicationSet:` block; `configs.params` works → cm `create-update`, env `ARGOCD_APPLICATIONSET_CONTROLLER_POLICY`; probe (`create-delete`) kept its Application 30 s after emptying the list (`generated 0 applications`); `checkout --` + bare apply → key gone, E1 grant intact | **D7** fixed |
| 31 | Stretch 3 | add deny window; list; sync as admin; remove | `cannot sync: blocked by sync window` | `Active deny … MANUALSYNC Disabled`; `SyncWindow: Sync Denied`; fatal `cannot sync: blocked by sync window` in 0 s; `windows delete storefront 0` → `Sync Allowed` | PASS; **D8** (removal command) |
| 32 | Stretch 4 (guide) | `role create`; `add-policy --action sync --object 'team-a/*'`; token | a usable CI role | policy `applications, sync, team-a/team-a/*`; token `get` and `sync` → terse `permission denied` | **G-5** confirmed |
| 33 | Stretch 4 (fixed) | `--object '*'`, `get` + `sync`; token tests; delete role | — | `team-a/*` for both; token `get` OK; `sync` `Phase: Succeeded`; `delete` → `permission denied: applications, delete, team-a/team-a-guestbook, sub: proj:team-a:ci-sync`; storefront `get` terse denial; role deleted | **G-5** fixed |
| 34 | Delete-path check (after step 28) | `kubectl delete application team-a-guestbook` | table row 2: survive | Deployment + Service survived, **same UID**; re-apply + sync re-adopted | PASS |
| 35 | Delete-path check | `argocd app delete team-a-guestbook` (default) | row 3: deleted | server added `resources-finalizer.argocd.argoproj.io` during the delete; Deployment + Service **deleted** | PASS; row wording **D9** |
| 36 | Delete-path check | `argocd app delete storefront-dev-workload` (default) | row 3 | `storefront-dev` Deployment **deleted** despite `preserveResourcesOnDeletion` | PASS |
| 37 | Delete-path check | `kubectl delete application storefront-staging-workload` | row 2 | Deployment survived (creation time unchanged); AppSet re-created the Application in <1 s | PASS |
| 38 | Delete-path check | `argocd app delete platform-root` (default) | (Lab 4 note) | root + 3 children gone; NetworkPolicies 6, ResourceQuotas 3, agent 1 **unchanged**; re-applying root restored the children in ~1 s | **D9** one-layer paragraph |
| 39 | Side effect of row 36 | AppSet passes at 12:21:47 and 12:24:47; re-apply AppSet; controller restart | re-creation | both passes `generated 3 applications`, **no `created Application`**; re-apply `unchanged`, no effect; `rollout restart deploy/argocd-applicationset-controller` → `created Application storefront-dev-workload` at 12:27:07, Deployment back 1/1 | open issue 1 |
| 40 | Handoff | `reset-lab.sh CP-capstone --yes --local` | PASS | 23/23 PASS, 47 s, no fault markers | PASS |
| 41 | SS-S6-01 | capture at pre-fault `CP-capstone` | four projects | `default`, `platform`, `storefront`, `team-a` | PASS; caption true |

---

## 4. Defects found and changes made

### Participant guide

| ID | Sev | File:line (after edit) | Finding | Change |
|---|---|---|---|---|
| D1 | L | `01-environment-and-mechanisms.md:51–57` | Expected `grep -n -A6` output omitted real lines 142–143 without `...` | Real five-line output |
| D3 | L | `02-build-fence-and-happy-path.md:123` | A participant who pastes the three E2 commands sees `Progressing` and a sync table showing `OutOfSync`/`Missing`, against "Output shape: Synced / Healthy" | Short "two things that look wrong but are not" note |
| D4 | L | `03-bypass-attempts.md:21–30` | E3A expected block was hand-wrapped and dropped the `LAST TRANSITION` column | Real `argocd app get` layout, trimmed with `...` |
| **G-4** | M | `03-bypass-attempts.md:34–49` | `argocd app sync team-a-wrong-dest` never returns (207 s and counting) | Callout: `--timeout 30`, why in plain words, Ctrl+C escape, real output, "the last line is the CLI giving up, not a second error" |
| D5 | M | `03-bypass-attempts.md:61–78` | E3B block in an invented layout; the `fatal … phase: Error` exit line unexplained; unclear that the Phase lines come from `sync` | `--timeout 60` safety net with a one-line reason (verified: returns at once), real block, explanation of the fatal line and of what `get` shows |
| D10 | L | `03-bypass-attempts.md:97` | Hint 1 left the `/tmp/…` file names for participants to infer | Names both paths |
| D6 | L | `03-bypass-attempts.md:166–169` | E4B: the fatal exit line unexplained; no timeout (for consistency with E3B) | `--timeout 60`; the fatal `…phase: Failed` line described |
| D9 | M | `04-deletion-protection-and-wrap-up.md:69–71`, `136` | Row 3 said the server "adds the propagation behaviour" (vague); nothing said how far a cascade reaches, although `platform-root` is in the listing (cross-lab note from the Lab 4 tester) | Row 3: "the server adds the finalizer for you as it deletes" (observed); a one-layer paragraph (leaf app vs `platform-root`, citing the Lab 4 E4 Notice); takeaway "that app's own workloads" |
| D2 | L | `04-…:97` | Troubleshooting said a swapped `rbac can` gives a "wrong answer" — it fails with a fatal error | Real error text plus the wrong-object case |
| D7 | M | `04-…:143` | Stretch 2: key location unstated (the values file has a top-level `applicationSet:` block that looks right); no way to confirm; "revert with a reset" would discard the participant's Lab 5 work | `configs.params` next to `server.insecure`; confirm command; scratch-ApplicationSet test; verified non-destructive revert. The answer is not given |
| D8 | L | `04-…:144` | Stretch 3 said "remove it when done" with no command | `windows list` + `windows delete storefront 0` |
| **G-5** | M | `04-…:145–154` | `--object 'team-a/*'` → `team-a/team-a/*`; a sync-only role cannot `get` | Corrected commands in a code block; expanded "project role" and "JWT"; why `'*'` and why `get`; token-to-variable command; a prediction without the answer; cleanup |

README and the stub were re-read against the run: accurate, unchanged. No participant file gained an answer.

### Instructor

- **Walkthrough** (`lab-05-enforce-platform-guardrails-SOLUTION.md`; Say / Do / Click / Expect / Answer key / Wrong turns / Wow / If it goes sideways format kept):
  - line 7: re-verification note;
  - §0.1 (28–35): 22 real rows and the 72 s reset;
  - §0.2 (37–43): G-4 and G-5 marked fixed in the guide, re-verified evidence, Ctrl+C;
  - §0.3 (45–47): points at this report;
  - §7 (559–569): evidence table for the delete-path rows, one-layer cascade, and the verified "If it goes sideways" for a generated app deleted with `argocd app delete` (controller restart);
  - §9 stretch 2 (641+): re-run evidence, key placement, the answer (with `applicationsetcontroller.enable.policy.override`, default `false` — checked against the Argo CD docs "Controlling Resource Modification" page on 2026-09-14 and in the live controller env), and the revert;
  - §9 stretch 4 (687, 712): guide now fixed; token captured with `-t`; sync `Phase: Succeeded`;
  - §10 (735–741): 23 rows and the three verifier blind spots.
- **Instructor README row 8** (`instructor/README.md:77`): marked fixed, with the 207 s evidence, the Ctrl+C escape, and the E3B/E4B safety net. Other rows untouched.

### Environment and harness

No script, checkpoint, seed repository, or manifest entry needed a change. The SS-L5 routes, selectors, and actions all worked as written, and so did SS-S6-01. No `bash -n` was needed.

---

## 5. Requested-item status

| Item | Status before | Evidence this run | Status now |
|---|---|---|---|
| **G-4** — refused sync never returns | Present (`03…:29`, no timeout anywhere) | Row 13: 207 s, still waiting. Rows 16, 18, 21: E3B, E4A, E4B return in 0 s | **Fixed** — `--timeout 30` on E3A with explanation; `--timeout 60` safety net on E3B/E4B |
| **G-5** — stretch 4 object and missing `get` | Present (`04…:143`) | Rows 32–33 | **Fixed** (guide + walkthrough) |
| **Finalizer / cascade assumption** (Lab 4 cross-lab note) | Unverified at `CP-lab-05` state | Rows 25, 34–38: every app `<none>`; `kubectl delete` orphans; `argocd app delete` adds the finalizer and deletes the app's own resources, even for a `preserveResourcesOnDeletion` app; `platform-root`'s cascade stops at the children | **Lab 5 text was right for leaf apps**; the one-layer nuance added (D9) |
| **SS-S6-01** missing from disk | Missing | Row 41 | **Captured**; caption and alt text already true, no text change |

---

## 6. Screenshots

All seven Lab 5 figures were read before the run, compared with their captions, then re-captured at the right moment with `node capture.mjs --only <ID>`. Credentials were passed inline from the files and never printed. Each new PNG was read, and the `capture-log.md` rows show `ok (viewport)`.

| ID | Moment captured | Caption true? | Change on disk |
|---|---|---|---|
| SS-L5-01 | `CP-lab-05`, before E1 | Yes — `default`, `platform`, `storefront` | byte-identical |
| SS-L5-02 | after E1 Part A apply | Yes — one repo, destination Name blank, empty cluster list, four kinds | byte-identical |
| SS-L5-03 | E3A (after the timeout sync) | Yes — `InvalidSpecError … in project 'team-a'` | new timestamp |
| SS-L5-04 | E3B after sync | Yes — PHASE Error, ComparisonError, 0s, no RESULT; revision `60f6a02` | new timestamp/revision |
| SS-L5-05 | E4A as `team-a-dev` | Yes — "Failed to load data", toast `Unable to load data: permission denied` | new |
| SS-L5-06 | E4B after sync | Yes — PHASE Failed, forbidden message, RESULT row `SyncF…` | new timestamp |
| SS-L5-07 | E5 as `team-a-dev` | Yes — Foreground/Background/Non-cascading, typed name, detailed denial toast | new timestamp |
| SS-S6-01 | after final `CP-capstone` reset, pre-fault | Yes — "four projects … `default` sits right next to the real fences" | **new file** |

No screenshot contradicted its text before or after re-capture. The older SS-L5-03…07 images only showed an older revision and dates.

---

## 7. Hand-off to the capstone (procedure step 4)

`reset-lab.sh CP-capstone --verify-only --local` on the state built by following the guide: **23/23 PASS**. The verifier does not check the following, and the diff against `checkpoints/CP-capstone/repos/platform-config` shows it:

1. **`team-a-guestbook` sync policy.** The checkpoint's copy has `syncPolicy.automated {prune, selfHeal}`. The participant's is manual, because E2 says to leave it out.
2. **The `action/*` line.** The checkpoint's `policy.csv` adds `p, role:team-a, applications, action/*, team-a/*, allow`; the participant's does not.
3. **The Application file.** E1 Part C commits only the project and values files. `applications/team-a-guestbook.yaml` stays untracked, so Gitea `main` has no Application file.

`reset-lab.sh CP-capstone --yes --local` replaces all three (verified after the final reset).

---

## 8. Open issues needing a human decision

1. **A generated Application deleted with `argocd app delete` was not re-created by its ApplicationSet (environment-engineer / capstone tester).** This happened for `storefront-dev-workload`, which carries `applicationsSync: create-update`.
   - Two 3-minute passes logged `generated 3 applications` with no `created Application`.
   - Re-applying the unchanged ApplicationSet had no effect.
   - A controller restart re-created it within 2 s.
   - A `kubectl delete` of `storefront-staging-workload` was re-created instantly.
   - Not diagnosed. The only clue is that the controller logged `updated Application storefront-dev-workload` while that object was terminating.
   - Lab 5 never does this. **The capstone pass should know it** if any repair expects an ApplicationSet to regenerate an Application that was deleted through the Argo CD API.
2. **Capstone start state (capstone owner).** The three verifier blind spots in Section 7 matter only if faults are injected onto an un-reset Lab 5 state; the capstone guide forbids participants from running `reset-lab.sh`. Either confirm the instructor always resets to `CP-capstone` first, or add verifier rows for the sync policy and the Application file.
3. **Reset runtime** is now 72 s (`CP-lab-05`) and 47 s (`CP-capstone`) on this Mac, down from 6 min 46 s. It was not re-measured on a VM.
4. **Session 6 step text** (not edited; out of scope) lists `default`, `storefront`, `platform`, `team-a`; the UI sorts them `default`, `platform`, `storefront`, `team-a`. Cosmetic.
5. **Optional, not changed:**
   - **Paths.** Module 1/2 mix relative `platform-config/…` paths with `~/platform-config/…`. Both work from a terminal opened in `~`.
   - **Stretch 1 cleanup.** Stretch 1 does not say to remove the deny line afterwards. It is harmless, but it leaves an uncommitted edit.
6. **Not exercised:**
   - troubleshooting rows `invalid session …` (every apply reused the hashes) and `another operation is already in progress`;
   - pressing **Sync** in the UI on `team-a-wrong-dest`;
   - Firefox on a VM;
   - the E1 Git-identity note (the clone already had an identity).
7. **Participant clone config.** `platform-config` in the student home has a local `credential.helper` pointing at a scratchpad script from earlier sessions (it was reused here). It is harmless once the scratchpad is gone; clear it with `git config --unset credential.helper` if the clone is reused.

## 9. Retest requirements

- After any change to `reset-lab.sh` or the checkpoints: `CP-lab-05` verify (22 rows), `CP-capstone` verify on a participant-built state (23 rows), and the Section 7 diff.
- On an Argo CD or CLI version change, re-check:
  - whether `argocd app sync` on an `InvalidSpecError` app still hangs (G-4);
  - the E3B/E4B fatal exit lines;
  - the `proj role add-policy --object` prefixing (G-5);
  - server-added finalizer on `argocd app delete`;
  - SS-L5-04/06 panel selectors;
  - the ApplicationSet re-creation behavior in open issue 1.
- On the next VM: SS-L5 click paths in Firefox, reset runtimes, and E3A's 30 s timeout under load.

## 10. Final sandbox state

- **Checkpoint:** `reset-lab.sh CP-capstone --yes --local` → `PASS CP-capstone is in the expected state.` (23/23), `ok no fault markers present`. It is a clean pre-fault start for the capstone pass.
- **Argo CD:** eight Applications `Synced`/`Healthy` (`platform-root` + 3 children, three `storefront-*-workload`, `team-a-guestbook` with automated sync). Projects `default`, `platform`, `storefront`, `team-a`, with no roles and no sync windows. One ApplicationSet (`storefront`); `policy-probe` deleted. `applicationsetcontroller.policy` unset. `policy.csv` = the checkpoint's four lines.
- **Gitea `main`:** force-moved by the reset to `cp-capstone`. My E1 commit `3892023` was discarded, as the guide warns.
- **Participant clones** (all clean): `platform-config` at `0a18123 checkpoint CP-capstone`, `storefront-gitops` at `d50d13d`, `hello-reconcile` at `b3ed117`.
- **Processes and shell:** no port-forward, watch, `argocd`, or capture processes. `COURSE_USER_HOME` unset; `~/argo-lab-env.sh` never sourced; EKS context never used. `argocd` CLI logged in as `admin` at `localhost:8443`. `/tmp` lab files deleted.
- **Git:** nothing committed in the courseware repository.

### Files changed by this pass

- Participant: `courseware/day-2/lab-05/01-environment-and-mechanisms.md`, `02-build-fence-and-happy-path.md`, `03-bypass-attempts.md`, `04-deletion-protection-and-wrap-up.md`
- Instructor: `courseware/instructor/day-2/lab-05-enforce-platform-guardrails-SOLUTION.md`; `courseware/instructor/README.md` (row 8 only)
- Screenshots: `courseware/assets/screenshots/day-2/lab-05-03` … `lab-05-07` (re-captured), `s06-01-projects-list.png` (new); `courseware/assets/screenshots/capture-log.md` (rows merged by the harness)
- This report: `courseware/reviews/lab-05-validation-2026-09-14.md`
