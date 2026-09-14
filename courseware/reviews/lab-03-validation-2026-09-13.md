# Lab 3 validation: Deploy, Introduce Drift, and Recover

- **Date:** 2026-09-13 (evening pass)
- **Scope:** `courseware/day-1/lab-03/` (README and modules 01–04), the stub `lab-03-deploy-drift-and-recover.md`, the Session 4 Module 3 promotion diagram, the instructor walkthrough `courseware/instructor/day-1/lab-03-deploy-drift-and-recover-SOLUTION.md`, rows 2–3 of `courseware/instructor/README.md`, and the environment pieces Lab 3 depends on (image pins, bootstrap, seed repos, `CP-lab-03`/`CP-lab-04` overlays, screenshot harness)
- **Objectives tested:** L3.1–L3.5 (outcomes O5, O6, O7, O1)

## Verdict

**PASS WITH NOTES** (after the fixes below). **Interestingness: STRONG.**

**Before this pass the lab was FAIL.** A participant following the guide exactly would:

- promote to `podinfo:6.16.0`, a tag that does not exist, and get `ImagePullBackOff` / `Degraded` that the guide called an offline-only edge case (E-2);
- after a reset to `CP-lab-03`, never see E2's guardrail rejection, because the checkpoint project already allowed staging and prod;
- commit `migration.shouldFail: true` in E5 Part B and watch nothing happen (the app stays `Synced`; auto-sync never starts), so the "ordering failure" never appears (G-1);
- compare against screenshots of which eight contradicted their captions (two showed "permission denied").

All of these are fixed and were re-executed. The notes that remain are cross-guide items, VM-only checks, and two small pedagogy observations (Section 8).

**Why STRONG:** participants predict before every reveal (render set, sync vs health, revert timing, whether auto-sync will act), diagnose by *where* evidence appears (condition vs sync result), make a revert-vs-roll-forward decision, and meet two real v3.5.2 surprises: hand edits are noticed in about a second, and hook-only commits never trigger auto-sync.

---

## 1. Environment tested

Local two-cluster sandbox on the build Mac (macOS arm64, Docker Desktop), not a provisioned student VM.

| Component | Observed |
|---|---|
| Argo CD server / `argocd` CLI | `v3.5.2` / `v3.5.2` |
| Kubernetes (`k3d-mgmt`, `k3d-workload`) | `v1.35.8+k3s1` |
| Helm / yq (pinned) | `v4.2.1` / `v4.48.1` |
| `timeout.reconciliation` | `60s`, jitter `0s` (platform-config `argocd/values.yaml`) |
| Screenshot harness | `capture.mjs` (Playwright headless Chromium, 1440×900) |
| Docker Hub (tag API, 2026-09-13) | `podinfo:6.14.1` → 200 (2026-07-22), `6.15.0` → 200 (2026-08-31, latest), `6.16.0` → **404** |

**Local mappings (no change to lab semantics):**

- `~` meant `~/.argocd-course/student-home`; `~/course/lab-files` meant `courseware/environment/lab-files`.
- `GIT_CONFIG_GLOBAL` pointed at that home's `.gitconfig` (the `lab-gitea` → `localhost` rewrite). Pushes used a scratchpad credential helper that reads the credential file.
- Scripts ran by full path with `--local`. `~/argo-lab-env.sh` was **never sourced**; `COURSE_USER_HOME` was never set. `seed-repos.sh` has no argument parser, so `--local` alone is ignored; it was run as `COURSE_LOCAL=1 … seed-repos.sh --local` (Section 8, item 6).
- `sed -i ''` (BSD) replaced `sed -i` (GNU) on this Mac; the walkthrough keeps the GNU form for the Ubuntu VM.
- Every `kubectl` call used an explicit `k3d-mgmt` / `k3d-workload` context. The EKS context was never touched.
- **Disclosure:** one early UI probe printed the first ~300 characters of the `storefront-staging` **Application's** `kubectl.kubernetes.io/last-applied-configuration` annotation (the Application spec; it contains no credential). No password, token, CA, or Secret annotation was printed. Later probes filtered annotation text out.

**Parity notes for the real VM** (environment-engineer / instructor):

- VMs built before this fix hold only `podinfo:6.15.0` and seed dev/staging at `6.15.0`, which makes the E2 promotion a no-op. The walkthrough's 0.1 pre-flight detects this.
- Firefox inside the VM desktop was not exercised; the UI paths (Compact diff, Sync Status panel, APP CONDITIONS panel, History ⋮ menu) were verified in headless Chromium.
- Timing under classroom load was not measured (self-heal ~0.7 s, sync ~9 s, Part B failure ~6 s here).

---

## 2. Execution log

| # | Step (module) | Command / action | Expected (guide before fix) | Actual | Result |
|---|---|---|---|---|---|
| 1 | Env fix | pull + `k3d image import podinfo:6.14.1 -c workload`; `seed-repos.sh`; mirror check | — | workload holds `6.14.1` and `6.15.0`; tags: `cp-baseline`…`cp-lab-03` dev/staging `6.14.1`, prod `6.15.0`; `cp-lab-04`+ all `6.15.0`; `storefront-1.0.0` prod `6.15.0`; project destinations `cp-lab-02/03` = 1, `cp-lab-04`+ = 3 | PASS |
| 2 | Reset | `reset-lab.sh CP-lab-03 --yes --local` | PASS | 19 s, 12/12 PASS | PASS |
| 3 | M01 §1 | `reset-lab.sh CP-lab-03 --verify-only --local` | 12-row block | identical 12 rows (a blank line precedes `==>`), exit 0 | PASS |
| 4 | M01 §1 UI | Applications list | dev `OutOfSync`/`Missing`, no staging, hello `Synced`/`Healthy` | identical (old SS-L3-01 showed the app page instead) | PASS; SS-L3-01 re-captured |
| 5 | M01 clones | clone `storefront-gitops` | "your clones" — no command | Lab 3 relied on Session 4's *optional* Try It for this clone | **D5** fixed |
| 6 | E1 | `argocd app sync storefront-dev` | Job → CM (−1) → Deploy/Svc (0) | `Succeeded` in 9 s, `d3a4166`; `Synced`/`Healthy` 10 s later; `argocd app manifests` lists only CM/Svc/Deploy (hook not compared) | PASS |
| 7 | E1 | `helm list -A --kube-context k3d-workload` | empty | header only | PASS |
| 8 | E1 | port-forward + `curl` | `storefront DEV` | `storefront DEV`, version `6.14.1` | PASS |
| 9 | E2 wrong turn | apply staging app before widening project | rejection | `created`, then `Unknown`/`Unknown` + `InvalidSpecError … do not match any of the allowed destinations in project 'storefront'` (reproduces after reset now) | PASS; G-10 text fixed |
| 10 | E2 | widen project, commit, push, apply ×2, sync staging | `2/2`, `STAGING` | `configured`/`unchanged`; `Succeeded` 8 s; `2/2`; `storefront STAGING`, `6.14.1` | PASS |
| 11 | E2 promote dev | tag `6.15.0`, commit, push, sync, `curl \| grep version` | new version | one-line diff; `Succeeded` 9 s (Deployment `configured`); `"version": "6.15.0",` | **PASS (was always FAIL — E-2)** |
| 12 | E2 promote staging | same edit; `helm template … \| grep image:`; sync | one-line diff | two image lines (`podinfo:6.15.0`, `busybox:1.37.0`); `Succeeded` 9 s; `2/2`; `6.15.0`; `git log` shows two commits | PASS |
| 13 | E3 | `kubectl scale --replicas=3`; `app get` (no refresh) | `Synced` until Refresh, then `OutOfSync`/`Healthy` | **immediately** `OutOfSync from main (83e2954)` / `Progressing`; after refresh `OutOfSync`/`Healthy`; `app diff` `151c151` replicas 3 vs 1; 70 s later still `OutOfSync`/`Healthy`, `3/3` | PASS; **G-11** text fixed |
| 14 | E3 UI | Diff | replicas line visible | full diff opens on metadata; replicas is 150 lines down; **Compact diff** shows it | **D6** fixed |
| 15 | E4 | manual sync; add `selfHeal: true`/`prune: false`; commit, push, apply | Automated | `Sync Policy: Automated`, `Synced`/`Healthy` | PASS |
| 16 | E4 | scale to 3 ×2, 0.5 s poll | "within roughly one 60-second interval" | reverted after **0.7 s** both times; `initiatedBy={"automated":true}`; operation `retry={"limit":5}`; sync result = Deployment only; Job not re-created; no History entry | PASS; **G-11** fixed |
| 17 | E4 UI | Details → Summary; toolbar **Sync Status** | policy + "initiated by automated" | SYNC POLICY box (auto-sync ✓, prune ☐, self heal ✓); Sync Status panel `INITIATED BY automated sync policy` | PASS; SS-L3-06/07 re-captured |
| 18 | E4 Prune=false | annotate Service template, `helm template \| yq`, commit, push | one resource | `Service/storefront  Prune=false`; live Service annotated 12 s after push+refresh; staging `OutOfSync` on Service | PASS; **D8** (staging sync note) |
| 19 | E5 Part A | valueFiles → `-DOESNOTEXIST`, commit, apply, refresh | ComparisonError | `Unknown`/`Healthy`, `ComparisonError … no such file or directory`; Pods and last-op revision unchanged; UI toast `Unable to load data: revision main must be resolved` | PASS |
| 20 | E5 Part A recover | `git revert`, push, apply, refresh | condition clears, `Synced`/`Healthy` | condition clears; staging `OutOfSync` (Service, from E4) until `argocd app sync storefront-staging` → `Synced`/`Healthy` | PASS after **D8** |
| 21 | E5 Part B as written | commit only `shouldFail: true`, push, refresh, watch 40 s | auto-sync fails the hook | `Synced to main (405e86c)`; **no operation** in 40 s | **FAIL — G-1 reproduced** |
| 22 | Part B new path | `argocd app sync storefront-dev` | — | `Phase: Failed` in 6 s; sync result = Job only (`hookPhase=Failed`); CM/Svc/Deploy rows no message; `retry={}`; no conditions; app `Synced`/`Healthy`; CLI `fatal` line, exit 20; Job log `migration failed: incompatible schema`; 30 s later unchanged | PASS (new design) |
| 23 | Part B recover | `shouldFail: false`, commit, push, refresh; explicit sync; history | — | still `Synced`, op still `Failed` at 20 s; sync `Succeeded` 10 s; History entry 4 `a4963fa` (failed sync not listed) | PASS |
| 24 | Automated path (G-1 facts) | visible banner + `shouldFail: true` | — | auto-sync `Running`, `Retrying attempt #1…#4` (t=5/21/41/84 s); fix pushed at t=47 s — op still on bad commit at t=84 s; CM still old banner | re-verified |
| 25 | Automated path | manual sync while retrying | — | `FailedPrecondition desc = another operation is already in progress` | verified |
| 26 | Automated path | `argocd app terminate-op` | — | auto-sync ran the fix within 2 s, `Succeeded` at 8 s, CM updated | verified |
| 27 | Terminate-first variant | terminate while retrying, wait 30 s, then push fix | — | `Failed`, `Operation terminated (retried 1 times).`; `SyncError` condition; no restart of that commit; fix auto-synced in 12 s | verified |
| 28 | SS-L3-10 moment | Applications list | dev + staging `Synced`/`Healthy` | identical | PASS; re-captured |
| 29 | Checkpoint | `argocd app list -o wide` | REVISION column | no revision column (`TARGET main`) | **G-12** reproduced |
| 30 | Checkpoint (new) | `kubectl … custom-columns …REVISION:.status.sync.revision`; `git rev-parse HEAD`; `curl` ×2 | revisions = HEAD | both `a4963fa…` = HEAD; `storefront DEV` / `storefront STAGING` | PASS |
| 31 | Stretch 1 | `argocd app rollback storefront-dev 2`; UI History | blocked | `FailedPrecondition desc = rollback cannot be initiated when auto-sync is enabled`; UI ⋮ menu shows **Rollback** | PASS |
| 32 | Stretch 2 | `retry: limit 2, backoff 5s×2, max 1m`; visible change + fail | re-attempts | retryCount 1 → 2; `Failed … (retried 2 times).` at 46 s; `SyncError` condition; no new attempt 15 s later; fix auto-synced in 12 s without `terminate-op` | PASS (rewritten) |
| 33 | Stretch 2 cleanup | `git revert` retry commit, apply | default | next automated op `retry={"limit":5}` | PASS |
| 34 | Day 2 handoff | `reset-lab.sh CP-lab-04 --yes --local` | PASS | 34 s, 14/14 PASS; Gitea `main` dev/staging/prod `6.15.0`; project destinations dev/staging/prod; Lab 4 skeleton `appset generate` → 0 rows; completed `cp-lab-05` ApplicationSet → `storefront-{dev,prod,staging}-workload` | PASS |

**Runtime.** The machine-driven run of E1–E5, the checkpoint, and both stretches took about 25 minutes, excluding experiments and screenshot work. Participant-felt waits: syncs 8–10 s; self-heal under 1 s; Part B failure 6 s; stretch 2 about 45 s of retries; resets 19–34 s. The 60-minute budget is realistic. E2 (manifest authoring plus two promotions) is the long pole at about 12–15 minutes.

---

## 3. Defects found and changes made

### Environment

| ID | Sev | File:line (after edit) | Finding | Change | Proof |
|---|---|---|---|---|---|
| **E-2** | H | `environment/scripts/lib/common.sh:34–38` | Only `podinfo:6.15.0` pinned; the guide promoted to non-existent `6.16.0` | New `PODINFO_PREV_IMAGE="stefanprodan/podinfo:6.14.1"` with rationale | `bash -n` OK |
| E-2 | H | `environment/scripts/bootstrap-vm.sh:204, 234–236` | `6.14.1` never pulled or imported | Added to the vendored image list and to the workload import loop | `bash -n` OK; same pull/import done by hand on the sandbox |
| E-2 | H | `environment/repos/storefront-gitops/envs/dev/values.yaml:5`, `envs/staging/values.yaml:5` | Nothing to promote *from* | Baseline tag `6.14.1` (prod unchanged at `6.15.0`) | Mirror tags (log row 1); E2 rows 11–12 |
| E-2 | H | **new** `environment/checkpoints/CP-lab-04/repos/storefront-gitops/envs/{dev,staging}/values.yaml` | Day 2 and capstone expect `6.15.0` | Overlay files, byte-identical to the old `6.15.0` files (capstone F1 diffs unchanged) | `cp-lab-04`+ tags `6.15.0`; Gitea `main` after the `CP-lab-04` reset |
| E-2 | L | `environment/scripts/seed-repos.sh:139–147` | Comment said storefront-gitops has "no checkpoint overlays" | Comment explains the one overlay and why prod at `storefront-1.0.0` still reads `6.15.0` | `bash -n` OK; tag check row 1 |
| **AppProject** | H | `environment/checkpoints/CP-lab-03/repos/platform-config/projects/storefront.yaml:1–16` | Checkpoint allowed three destinations; Lab 2's answer allows one, so E2's guardrail lesson vanished after a reset | One destination (`storefront-dev`), with a header explaining why | Live project after reset = `storefront-dev`; rejection reproduced (row 9) |
| AppProject | H | **new** `environment/checkpoints/CP-lab-04/repos/platform-config/projects/storefront.yaml` | Day 2's ApplicationSet needs dev/staging/prod | Overlay restores all three destinations (header updated) | Row 34: three destinations; completed ApplicationSet previews three apps |
| D1 | M | `screenshots/screenshot-manifest.yaml:549–563` | SS-L3-01 route was the app page; caption describes the Applications list | Route `/applications`, verified list selector, truthful state | Re-captured |
| D2 | H | `screenshot-manifest.yaml:578–596` | SS-L3-03 route `?view=parameters` loaded **"permission denied"** | Verified deep link `…&tab=parameters`, wait, `VALUES FILES` selector, 1500 px viewport | Re-captured |
| D3 | M | `screenshot-manifest.yaml:611–631` | SS-L3-05 had no Diff action (captured the tree again) | Diff click + **Compact diff** click | Re-captured |
| D4 | M | `screenshot-manifest.yaml:633–669` | SS-L3-06/07 selectors `.application-summary` / `.application-operation-state` do not exist | Summary-tab deep link + scroll to SYNC POLICY; `?operation=true` Sync Status panel | Re-captured |
| D4 | L | `screenshots/capture.mjs:168–178` | No way to bring a lower panel section into view without clicking (a click would toggle a checkbox) | New `{ scroll: "<selector>" }` action (scrollIntoView, no click) | `node --check` OK; SS-L3-06 |
| D2 | H | `screenshot-manifest.yaml:671–688` | SS-L3-08 showed **"permission denied"** (captured before staging existed) | `?conditions=true` deep link + `.application-conditions` | Re-captured |
| — | L | `screenshot-manifest.yaml:690–720` | SS-L3-09/10 state notes described the old Part B | Truthful state notes for the explicit-sync design | Re-captured |

### Participant guide

| ID | Sev | File:line (after edit) | Finding | Change |
|---|---|---|---|---|
| **E-2** | H | `02-deploy-and-promote.md:96–117` | Promotion to `6.16.0`; environment note claimed it was pre-loaded | Start state `6.14.1` → promote `6.15.0`; real expected output for `curl … \| grep version` and `helm template`; environment note names both pre-loaded images |
| E-2 | M | `02-…:121–128` | SS-L3-03 caption/criteria | Caption names the Details → Parameters path and values; success criteria add version `6.15.0` and two separate commits |
| **G-10** | L | `02-…:86`; `04-break-and-recover.md:130` | "Argo CD will *reject*"; old rejection text | Explains `created` then `Unknown`/`Unknown` + real `InvalidSpecError` text |
| D7 | L | `02-…:92` | Staging port-forward on `9898` collides with dev's tunnel; "read the UI" had no path | Use `9899:9898`; **Details** → **Parameters** |
| **D5** | M | `01-environment-and-mechanics.md:46–55` | Hidden dependency on Session 4's optional clone; no note on working directory | Clone check with the Session 4 command; where commands run from |
| **G-11** | L | `03-drift-and-self-heal.md:34–35, 45, 54` | E3 implied drift appears only on the 60 s loop / Refresh; health "stays Healthy" | Notice: `OutOfSync` within a second or two (watch), brief `Progressing`; the 60 s timer is for Git; Hint 1 rewritten |
| **D6** | L | `03-…:34, 43` | Diff opens far above the changed field | Tick **Compact diff**; SS-L3-05 caption |
| **G-11** | L | `03-…:86–87, 99, 110, 115` | "debounce 5 s … within roughly one 60-second interval"; Hint 2 "click Refresh … 60-second loop"; debrief "30 seconds later" | Predict step without the answer; Notice with verified ~1 s revert and "only the drifted object"; Sync Status click path; Hint 2 checks the policy really applied; "a second later" |
| — | M | `03-…:93, 97` | SS-L3-06/07 captions described UI not shown | Captions name the exact panel and fields |
| **D8** | M | `04-…:36` | After Part A, staging is `OutOfSync` (E4's Prune=false commit), so the success criterion failed without a sync | Recover step says to sync staging |
| — | L | `04-…:30, 32` | SS-L3-08 caption/notice lacked where to click; UI toast unexplained | APP CONDITIONS click path, real message tail, `Unknown`/`Healthy`, toast explained |
| **G-1** | H | `04-…:40–103` | Part B never fails as written; claimed auto-sync attempt; claimed "a failed sync of the same commit is not retried automatically, your new commit lets it sync cleanly" (a hook-only fix does not sync either) | Rewritten: the "hooks are not compared" fact stated first; predict whether auto-sync acts; explicit `argocd app sync`; symptom table row 2 changed to what is really observable; real expected output; SS-L3-09 caption/notice; recovery with an explicit sync; callout on automated retries, same-commit pinning, `SyncError`, `terminate-op` |
| G-1 | M | `04-…:109, 115, 121` | SS-L3-10 caption promised `git log` on screen; success criterion/Hint 3 relied on the old mechanics | Caption fixed; criterion notes history lists successful syncs only; Hint 3 rewritten |
| G-1/G-11/E-2 | M | `04-…:132–139` | Troubleshooting rows for 60 s drift, `6.16.0`, "new commit" | Rows split into Git-poll vs watch; promotion row generic; new rows: hook-only push, retrying + `another operation is already in progress`, `SyncError` |
| **G-12** | L | `04-…:143–166` | `argocd app list -o wide` has no revision | `kubectl … custom-columns …REVISION:.status.sync.revision` + `git rev-parse HEAD`, real expected shape, one-line explanation |
| — | L | `04-…:191, 196` | Whole-lab takeaway "drift is discovered on the next comparison, not the instant it happens" | Hand edit within seconds, commit within a minute; added hook-only takeaway |
| **D9** | M | `04-…:206–211` | Stretch 1 printed its own answer in parentheses and revealed the outcome before the prediction | Predict → try (UI ⋮ → Rollback, or CLI) → explain; answer removed |
| **G-1 (stretch)** | M | `04-…:212–222` | Stretch 2 as written could not fire (hook-only), and omitted default retries / pinning | Step-by-step with a visible change; watch retries end; fix after exhaustion; then default retries + push-while-retrying + `terminate-op`; cleanup |
| E-2 | L | `session-04/03-promotion-and-recovery.md:37–42` | Diagram showed `6.15.0` → `6.16.0` | `6.14.1` → `6.15.0` |

README and stub: re-read against the run; accurate, unchanged.

### Instructor

- **Walkthrough** (`instructor/day-1/lab-03-deploy-drift-and-recover-SOLUTION.md`, 957 lines, Say / Do / Click / Expect / Answer key / Wrong turns / Wow / If it goes sideways format kept):
  - §0.1 is now the fix plus a VM pre-flight (`crictl images`, mirror tag check) with verified output. §0.2 covers the new Part B, and §0.3 lists the other verified behaviors. §0.4 is now 12 rows. The run of show is updated.
  - **E1:** the rendered set excludes the hook; real output (`d3a4166`, 9 s, version `6.14.1`).
  - **E2:** the tag answer key is `6.14.1`. Wrong-turn output. Part 2 has the real promotion output, and the old failure became a "what if the tag did not exist" answer key (marked as earlier-rehearsal evidence).
  - **E3:** the output appears immediately (`OutOfSync`/`Progressing`), with the Compact diff click and a reworded wow moment.
  - **E4:** 0.7 s loop and output, SYNC POLICY and Sync Status clicks, and the facts that only the Deployment is re-applied, the hook does not run, and no history entry is added.
  - **E5 Part A:** SS-L3-08 click path, the toast, and the staging-sync note.
  - **E5 Part B:** the explicit-sync script with real output and proofs, a separate verified "automated path" (retry timeline, refusal text, `terminate-op`, and the terminate-first variant), and a rebuilt "If it goes sideways" table.
  - **Stretches 1–2:** real outputs.
  - **§8.1:** real checkpoint output. **§9:** debrief questions and takeaways no longer reference the `6.16.0` failure.
- **Instructor README rows 2–3** (`instructor/README.md:71–72`): rewritten as fixed, with the old-VM caveat and the automated-path recovery.

---

## 4. Carried-over defects

| ID | Status before this pass | Evidence | Status now |
|---|---|---|---|
| **E-2** | Still present | Docker Hub 404; only `6.15.0` preloaded; all envs `6.15.0` | **Fixed** (env + guide + diagram + walkthrough + README). Day 2 proven unaffected (row 34) |
| **AppProject mismatch** | Still present | `CP-lab-03` project had 3 destinations | **Fixed**: `CP-lab-03` = dev only (rejection reproduces); `CP-lab-04` = three (Lab 4 preview OK) |
| **G-1** | Still present | Row 21 (no operation in 40 s); rows 24–27 (5 default retries, pinning, refusal, `terminate-op`, `SyncError`) | **Fixed** (Part B rewritten around an explicit sync; automated behavior taught in a callout, troubleshooting, and Stretch 2) |
| **G-10** | Still present | Real `InvalidSpecError` text | **Fixed** |
| **G-11** | Still present (and larger than reported) | Self-heal 0.7 s; E3 `OutOfSync` before Refresh | **Fixed** in the E3/E4 steps, notices, hints, debrief, troubleshooting, and takeaways |
| **G-12** | Still present | `-o wide` has no revision column | **Fixed** (custom-columns command + expected shape) |

---

## 5. Screenshots

Every PNG the lab embeds was read before and after, and compared with its caption and the live UI at that step. All ten were re-captured at the right moment (`capture-log.md` rows SS-L3-01…10, v3.5.2, all `ok`, all highlighted).

| ID | Before this pass | Action | After (verified against the live UI) |
|---|---|---|---|
| SS-L3-01 | **Contradiction:** `storefront-dev` app page, not the Applications list; no `hello-reconcile` | Manifest route fixed; captured at `CP-lab-03` | List: `hello-reconcile` Healthy/Synced, `storefront-dev` Missing/OutOfSync, no staging |
| SS-L3-02 | Matched (old SHA) | Re-captured after E1 | Tree: PreSync Job (hook icon, healthy), all Synced; `Synced`/`Healthy` |
| SS-L3-03 | **Broken:** "Failed to load data … permission denied" | Deep link + taller viewport | Details → Parameters: VALUES FILES `../../envs/staging/values.yaml`, `image.tag` 6.15.0, `replicaCount` 2, `ui.message` storefront STAGING |
| SS-L3-04 | Matched | Re-captured during E3 drift | Deployment OutOfSync, app Healthy |
| SS-L3-05 | **Contradiction:** identical to SS-L3-04 (no diff) | Diff + Compact diff actions | Compact diff: line 151 `replicas: 3` vs `replicas: 1` |
| SS-L3-06 | **Contradiction:** resource list; no sync-policy toggles visible | Summary tab + scroll action | SYNC POLICY: ENABLE AUTO-SYNC ✓, PRUNE RESOURCES ☐, SELF HEAL ✓ (annotation row off-screen) |
| SS-L3-07 | **Contradiction:** plain tree; "initiated by" not visible | Sync Status panel deep link | INITIATED BY automated sync policy; RESULT one row (Deployment) |
| SS-L3-08 | **Broken:** "permission denied" | Conditions panel deep link | Application conditions: ComparisonError naming `values-DOESNOTEXIST.yaml` (UI toast visible, explained in text) |
| SS-L3-09 | Old hook-only manual sync (matched *new* design by accident) | Re-captured after the new Part B explicit sync | LAST SYNC Sync failed to `405e86c`, Job red, app Synced/Healthy |
| SS-L3-10 | **Contradiction:** no staging tile; `storefront-dev` "Sync failed" | Re-captured after recovery | `hello-reconcile`, `storefront-dev`, `storefront-staging` all Healthy/Synced |

Cross-lab check: SS-L2-08 (Lab 2 diff) shows only ConfigMap/Service above the fold, so the `6.14.1` baseline does not contradict it.

## 6. Clarification callouts (🧭 / ✅ / big picture)

All callouts, "Part A/B in one line" summaries, "What you should take away" blocks, module takeaways, and the README big-picture table were kept and checked against the run. Most were accurate: README tables, Module 1 callouts, all E1/E2/E3/E4 🧭 callouts, and the E1–E4 take-away blocks. Corrected, in the same plain tone:

- **Part B "in one line"** — added "A change that touches only a hook needs an explicit sync, because hooks are not compared" (the old mechanics implied auto-sync would run it).
- **Module 4 E5 takeaways** — added the hook-only takeaway.
- **Whole-lab takeaway** "Drift is discovered on the next comparison, not the instant it happens" — false for hand edits (noticed within a second). It now reads "Argo CD notices a hand edit within seconds, and a new commit within a minute… Refresh makes it check Git now."
- **Module 2 E2 callout** "Promotion is copying one line from the dev card to the staging card" — still true; the surrounding step text changed tags only.
- **Module 3 E3 "Connects to" quote** ("drift is discovered, not detected", from Session 4) kept: Argo CD does discover drift by a comparison, and the new Notice explains that a watch triggers it at once. Session 4's own wording is a cross-guide issue (Section 8, item 1).

No participant file gained an answer. One was removed (stretch 1's parenthetical). The new Part B shows observed output only after the prediction prompts.

## 7. Reproducibility and fragility

- **Self-heal and E3 timing** come from the watch, not the 60 s poll, so they are fast and deterministic here. Under load they may take a few seconds; the guide says "within a second or two".
- **Part B** is now deterministic: a manual sync has no retries, and a hook-only change never triggers auto-sync. The automated path (retries) is timing-dependent (`Running` for about 2.5 minutes vs `Failed`); the guide's troubleshooting and the walkthrough cover both states.
- **Stretch 2 step 5** needs the fix pushed within the retry window (about 2.5 minutes with the default 5 retries). That is comfortable; with `limit: 2` it would be tight, which is why the guide reverts to the default first.
- **Old VMs** (built before this fix) silently turn E2 into a no-op; the walkthrough's pre-flight catches it.

## 8. Open issues needing a human decision

1. **Session 4 Module 2 wording (lab-engineer; other guide, not edited).** `day-1/session-04/02-sync-ordering-and-drift.md:60, 72, 116` say drift is found "on the next comparison" and call Argo CD "comparison-on-a-schedule". For live edits the comparison is triggered by a watch within about a second (verified). Suggest: "Argo CD compares on a schedule for Git and on a watch for the live objects it manages; it never blocks your edit."
2. **Blueprint pin table** (`courseware/00-course-blueprint.md:627, 725, 736`) lists only `podinfo:6.15.0`. Add `6.14.1` (Day 1 dev/staging baseline). Not edited (design document).
3. **Rebuild or patch existing VMs** (environment-engineer / instructor). Any provisioned VM or image built before today needs `6.14.1` imported and `seed-repos.sh` re-run.
4. **Capstone and Lab 4/5 untouched**, as instructed. The `CP-lab-04` overlays restore their exact prior content (dev/staging values byte-identical; the project differs from the old `CP-lab-03` file only in its header comment). The Lab 5 guide `cat`s `projects/storefront.yaml`; its text quotes no header. The capstone solution quotes the staging values diff (`-  tag: "6.15.0"`), still true at `cp-capstone`. **Lab 4 and capstone testers should still re-run their start states** after this change.
5. **Pedagogy (not changed; lab-engineer decision).** E4 Hint 3 states the `Prune=false` justification outright, and the E4 debrief prints the defensible answers directly under "write your answer before reading on". Both are existing design choices that weaken the prediction.
6. **`seed-repos.sh --local`** does nothing (no argument parsing); `COURSE_LOCAL=1` is required. Either parse `--local` like `reset-lab.sh` or fix the docs that say `seed-repos.sh --local`.
7. **Not re-run:** Firefox on the VM; the UI refusal message for Rollback under auto-sync (CLI verified, UI menu item verified); E1/E2 "wrong context" wrong turns (trivial); `argocd app sync` from the UI's Sync panel for Part B (CLI verified).
8. **E-7 still open** (from Lab 1): `~/argo-lab-env.sh` sets `COURSE_USER_HOME=$HOME`; the guides still tell participants to source it (correct on the VM).

## 9. Retest requirements

- After any change to image pins, seed repos, or checkpoints:
  - check the mirror tag table (row 1);
  - `reset-lab.sh CP-lab-03` → project has one destination and dev tag `6.14.1`;
  - `reset-lab.sh CP-lab-04` → three destinations, all tags `6.15.0`, ApplicationSet preview three rows.
- If the Argo CD version pin changes, re-check:
  - default automated retry (`{"limit":5}`) and `retry.refresh`;
  - hook-only changes not triggering auto-sync;
  - self-heal timing;
  - the Compact diff, Sync Status (`?operation=true`), and APP CONDITIONS (`?conditions=true`) paths;
  - the `InvalidSpecError` text and the `-o wide` columns;
  - SS-L3-01…10 at their manifest states (SS-L3-07 before the `Prune=false` commit; SS-L3-09 after the explicit failing sync and before the fix).
- On the next provisioned VM: run the walkthrough's 0.1 pre-flight, then E2 and E5 Part B in Firefox.

## 10. Final sandbox state

- **Checkpoint:** `reset-lab.sh CP-lab-04 --yes --local` (34 s) → `PASS CP-lab-04 is in the expected state.` (14/14; `--verify-only` exit 0). No Applications exist (Day 2 start).
- **Gitea `main`:** storefront-gitops `9fb4f39 checkpoint CP-lab-04` (dev/staging/prod `6.15.0`); platform-config `abba9b1 checkpoint CP-lab-04`; `storefront` AppProject allows dev, staging, and prod.
- **Workload images:** `podinfo:6.14.1` and `6.15.0` present.
- **Participant clones** (`~/.argocd-course/student-home`): `platform-config` and `storefront-gitops` (new, cloned by this pass) reset to `origin/main` at `CP-lab-04`; the `hello-reconcile` clone is untouched. Both clones carry a local `credential.helper` pointing at this session's scratchpad script. It is harmless once the scratchpad is gone, but remove it with `git config --unset credential.helper` if the clones are reused.
- **Processes and shell state:** no port-forward or watch processes; `COURSE_USER_HOME` never set; `~/argo-lab-env.sh` never sourced; the EKS context never used.
- **argocd CLI:** logged in as `admin` at `localhost:8443`.
- **Git:** nothing committed.

### Files changed by this pass

- Participant: `courseware/day-1/lab-03/01-environment-and-mechanics.md`, `02-deploy-and-promote.md`, `03-drift-and-self-heal.md`, `04-break-and-recover.md`; `courseware/day-1/session-04/03-promotion-and-recovery.md` (diagram only)
- Instructor: `courseware/instructor/day-1/lab-03-deploy-drift-and-recover-SOLUTION.md`, `courseware/instructor/README.md` (rows 2–3)
- Environment:
  - `courseware/environment/scripts/lib/common.sh`, `bootstrap-vm.sh`, `seed-repos.sh` (comment);
  - `repos/storefront-gitops/envs/{dev,staging}/values.yaml`;
  - `checkpoints/CP-lab-03/repos/platform-config/projects/storefront.yaml`;
  - **new** `checkpoints/CP-lab-04/repos/platform-config/projects/storefront.yaml` and `checkpoints/CP-lab-04/repos/storefront-gitops/envs/{dev,staging}/values.yaml`;
  - `scripts/screenshots/capture.mjs` (scroll action), `scripts/screenshots/screenshot-manifest.yaml` (SS-L3 entries).
- Screenshots: `courseware/assets/screenshots/day-1/lab-03-01` … `lab-03-10` (all re-captured); `capture-log.md` (rows merged by the harness)
- This report: `courseware/reviews/lab-03-validation-2026-09-13.md`
- Not changed by this pass: `reset-lab.sh` (its uncommitted diff is from the Lab 1/2 testers); README and stub of Lab 3 (accurate)
