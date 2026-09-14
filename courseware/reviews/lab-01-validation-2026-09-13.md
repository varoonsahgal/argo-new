# Lab 1 validation: Follow an Application Through Reconciliation (plus Lab 0)

- **Date:** 2026-09-13 (evening pass)
- **Scope:** `courseware/day-1/lab-01/` (README and modules 01–04), the stub `lab-01-follow-an-application-through-reconciliation.md`, `Lab 0 — Prepare Your VM for Lab 1.md`, the instructor walkthrough `courseware/instructor/day-1/lab-01-follow-an-application-through-reconciliation-SOLUTION.md`, and the environment pieces Lab 1 uses (`reset-lab.sh`, the `hello-reconcile` seed repo, the screenshot harness)
- **Learning objectives tested:** L1.1 name every external dependency; L1.2 commit → OutOfSync → manual sync → explain why the synced change did not reach the Pod → fix it in Git; L1.3 compare desired, rendered, and live; L1.4 locate status in the UI, the `argocd` CLI, and `kubectl`

## Verdict

**PASS WITH NOTES** (after the fixes below).

Before this pass, a participant could complete the lab, but:

- the guide's expected output did not match v3.5.2;
- two UI labels were wrong;
- E3's command hid the one field the exercise needs;
- four embedded figures showed something other than their captions;
- a `CP-lab-01` reset on a rehearsed sandbox left rollout history that makes Module 3's key evidence (`REVISION 1`) false.

Every one of those is now fixed and re-executed. The remaining notes are VM-only steps that cannot run on this Mac, plus a few items for a human decision (Section 8).

**Interestingness: STRONG.** Participants predict before every push, hit a genuine surprise (Synced, Succeeded, yet the old message is served), gather four pieces of evidence, explain them, and fix the cause in Git. The stretches test the fix and a health edge case.

---

## 1. Environment tested

Local two-cluster sandbox on the build Mac (macOS arm64, Docker Desktop 27.4.0), not a provisioned student VM.

| Component | Observed |
|---|---|
| Argo CD server | `v3.5.2` (from `/api/version`) |
| `argocd` CLI | `v3.5.2+e258ee2.dirty` |
| Kubernetes (`k3d-mgmt`, `k3d-workload`) | `v1.35.8+k3s1` |
| k3d | `v5.9.0` |
| Helm (pinned) | `v4.2.1+gd591a19` |
| yq (pinned) | `v4.48.1` |
| `timeout.reconciliation` / jitter | `60s` / `0s` |
| Screenshot harness | `capture.mjs` (Playwright headless Chromium, 1440×900) |

**Local mappings (no change to lab semantics):**

- scripts were run by full path with `--local`;
- `COURSE_USER_HOME` was left unset and `~/argo-lab-env.sh` was **never sourced**;
- `~` meant `~/.argocd-course/student-home`;
- `GIT_CONFIG_GLOBAL` pointed at that home's `.gitconfig` (the `lab-gitea` → `localhost` rewrite);
- pushes used a non-interactive credential helper that reads the credential file;
- `/tmp/pf.log` was written to the session scratchpad;
- "edit with nano" was done with `sed`/`awk`;
- UI clicks (Refresh, Diff, Sync → Synchronize, Pod node → Events, History and rollback) were driven with Playwright.

No credential value was printed.

**Parity notes for the real VM** (environment-engineer / instructor):

- **Firefox:** runs inside the VM desktop, so `localhost:8443` resolves on the VM.
- **Shell:** the participant shell is bash; `kill %1` was verified under bash.
- **Timing:** Pod readiness (2–7 s here) and Refresh timing may differ under classroom load.

---

## 2. Execution log

| # | Step (module) | Command / action | Expected (guide) | Actual | Result |
|---|---|---|---|---|---|
| 1 | Start state | `reset-lab.sh CP-lab-01 --yes --local` | PASS table | PASS in 19 s — **but** the Deployment was at rollout revision 4 with three ReplicaSets and ten sync-history entries left from earlier rehearsals (seen in the first SS-L1-03 re-capture) | **Defect E-9** (fixed, row 2) |
| 2 | Fix proof | new verifier row, then reset, then verify | — | Before: `FAIL Deployment hello-reconcile at rollout revision 1, no Pod-template annotations`. Reset in 33 s. After: 8/8 PASS; `rollout history` = `1`; one ReplicaSet `rev:1`; `argocd app history` = ID `0` only | PASS |
| 3 | M01 §1 | `reset-lab.sh CP-lab-01 --verify-only --local` | 4-row sample with a `▶` header | `==>` header, 8 rows (including `team-a` absent and `Repository and cluster Secrets are exactly: in-cluster`) | **G-16** (fixed) |
| 4 | M01 §2 | Window C `kubectl … get pods -w` | one Running Pod, silent | as expected (run with `--output-watch-events` to label lines) | PASS |
| 5 | M01 §3 | `argocd login …` + `argocd app get hello-reconcile` | pre-3.5 layout (`Repo:` / `Target:` at top level, no `URL:`, no MESSAGE text) | `URL:` line, `Source:` block, `SyncWindow: Sync Allowed`, MESSAGE `… created` | **G-13** (fixed) |
| 6 | M01 §3 | Click tile → tree | Application → Service, ConfigMap, Deployment → ReplicaSet → Pod | as expected after the E-9 fix (before it: three ReplicaSets) | PASS |
| 7 | M01 §4 | `kubectl … get application hello-reconcile -o yaml` | six addressing fields | present; full object 221 lines incl. `status.history` | PASS |
| 8 | M01 E1 | `chart/values.yaml` `image:` | image lives in the chart, not the manifest | `stefanprodan/podinfo:6.15.0`; `image` absent from the Application | PASS |
| 9 | M02 §1–4 | clone, change `message`, commit, push, `git rev-parse HEAD` | push succeeds; SHA printed | `9ec1d9c..4bf9e96`; immediately afterwards still `Synced to main (9ec1d9c)` | PASS |
| 10 | M02 §5 | wait without Refresh | "up to ~60 s" | OutOfSync detected **40 s** after the push | PASS |
| 11 | M02 §5 | UI tree | app and ConfigMap OutOfSync, still Healthy | as expected (SS-L1-05) | PASS |
| 12 | M02 §5 | Click **App Diff** | diff panel | No such button. v3.5.2 labels it **Diff** (greyed out while Synced); opens a **Diff** tab | **D3** (fixed) |
| 13 | M02 §5 | `argocd app diff hello-reconcile` | `4c4` one-line ConfigMap diff | identical; exit 1 | PASS |
| 14 | M02 §5 | Sync, Prune unchecked, "confirm" | sync | Panel button is **Synchronize**; Prune unchecked by default; three resources listed. Sync via UI: `OutOfSync/Healthy` → `Synced/Healthy` in ≈1 s, never `Progressing`; Window C printed nothing | PASS (wording **D4** fixed) |
| 15 | M02 §6 | port-forward + `curl … grep -o '"message": *"[^"]*"'` + `kill %1` (bash) | `"message": "Hello from Git, revision one"` | identical; old G-2 pattern matches 0 lines; port freed | PASS (**G-2** already fixed) |
| 16 | M03 Step E | four evidence commands | `Synced to main (…)`, `revision two`, `…=revision one`, `REVISION 1` | identical (SHA `4bf9e96`) | PASS (only after the E-9 fix) |
| 17 | M03 Step F | add annotation; `helm template … \| grep checksum/config` | `1ef56c65…4e17b`, 8-space indent | identical | PASS |
| 18 | M03 Step G | Refresh; `argocd app get`; `argocd app diff` | only the Deployment OutOfSync; `151a152,153` | identical (SS-L1-11) | PASS |
| 19 | M03 Step G | Sync via UI; Window C | new Pod `1/1` before old `Terminating`; `Synced/Progressing` then `Healthy` | as expected. `Progressing` lasted ≈7 s; new Pod Ready at 7 s; some lines repeat | PASS (wording **D8**) |
| 20 | M03 Step G | prove: sync status, `curl` | `Synced to main (…)`, `revision two` | `f083e46`; `rollout history` 1, 2; two ReplicaSets; `"message": "Hello from Git, revision two"` | PASS |
| 21 | M04 E3 | `argocd app manifests … \| sed -n '/kind: ConfigMap/,/^---/p'` | rendered ConfigMap | **omits `data:`** (keys sorted, `data:` sits above `kind:`) | **G-3** (fixed: `yq 'select(.kind == "ConfigMap")'` shows `data:` and the tracking annotation) |
| 22 | M04 E3 | live ConfigMap | extra server fields | `uid`, `resourceVersion`, `creationTimestamp`, `last-applied-configuration`, tracking-id | PASS |
| 23 | M04 E4 | jsonpath status, `argocd app history`, `argocd app --help`, `describe pod`, UI Events tab | facts on three surfaces | all present. No `events` subcommand in `argocd app` (matches the answer key). UI Events tab shows Scheduled/Pulled/Created/Started | PASS |
| 24 | M04 troubleshooting | `sha256` typo → `helm template` | same error as the ComparisonError | `function "sha256" not defined` | PASS |
| 25 | M04 troubleshooting / walkthrough | annotation under top-level `metadata:` | 4-space indent cue | `    checksum/config: …` (4 spaces) | PASS |
| 26 | M04 checkpoint 1 | `argocd app get … \| grep sync status` vs `git -C ~/hello-reconcile rev-parse HEAD` | short SHA = first 7 chars | `818a665` = `818a6654…` | PASS |
| 27 | Stretch A | revision three | two resources in the diff; new Pod; new message | ConfigMap `4c4` + Deployment `156c156` (`1ef56c…` → `3a0604…`); rolling update; `"revision three"` | PASS |
| 28 | Stretch B | `replicaCount: 0`, then back to `1` | predict the health | `Synced`/`Healthy` with `0/0`; restored to `1/1` | PASS |
| 29 | Walkthrough 2.2 | delete Pod | Argo CD unaffected | replacement `Running`; app `Synced / Healthy` | PASS |
| 30 | Walkthrough E3 wrong turn | `yq '.kind == "ConfigMap"'` (no `select`) | — | prints `true` / `---` / `false` / `---` / `false` | added to walkthrough |
| 31 | End | `reset-lab.sh CP-lab-02 --yes --local` | Lab 2 start | PASS 7/7 in 21 s. Gitea `main` and the participant clone reset to `9ec1d9c` (Lab 1 commits discarded) | PASS (wording **D9**) |

### Lab 0 (VM preparation)

| Section | Run here? | Result |
|---|---|---|
| §2 `whoami` = `training`, `docker info`, `df`/`free` | Partly | `docker info` OK, `df` OK. `whoami` is the Mac user; `free` does not exist on macOS. **Not executable locally**, not a defect |
| §3 `k3d version`, `apt-get`, k3d install script | `k3d version` only | `v5.9.0` (meets ≥ 5.9.0). `apt-get` and the install script are VM-only |
| §4 clone/pull branch; annotation count | Branch and count only | `argo-cd-course-build`; `grep -c 'annotations:'` → `0` (the seed chart equals the Gitea chart byte for byte) |
| §5 write and source `~/argo-lab-env.sh` | **Deliberately not run** | Sandbox-safety rule (E-7) |
| §6 `bootstrap-vm.sh --local` | Not re-run | The sandbox already exists; re-running would re-seed it. Bootstrap timing on the provider VM remains unverified |
| §7 nodes Ready, Argo CD Pods, `argocd app get`, verifier | Yes | Both nodes Ready; six Argo CD Pods Running; Synced/Healthy; verifier PASS |
| §8 Firefox inside the VM desktop | UI checked with headless Chromium | Argo CD `/healthz` 200, Gitea 200. The VM-desktop path is not executable here |
| §9 `git ls-remote` | Yes | refs listed |
| §10 "Ready for Lab 1" bullets | Read | One bullet contradicted the redesigned Lab 1 (**D10**, fixed) |

### Runtime

Machine-driven execution from the fixed reset to the end of stretch B took about 13 minutes, including screenshot captures. The waits participants will feel:

- up to 60 s of timer per push if they skip Refresh (40 s observed);
- ≈1 s for the Part 1 sync;
- ≈7 s for the Part 3 rollout;
- 33 s for a `CP-lab-01` reset.

The 45-minute budget (10 + 12 + 12 + 10) is realistic for reading, predicting, writing the E1/E4 tables, and explaining. It is not padded.

---

## 3. Defects found and changes made

### Environment

| ID | Sev | Finding | Change | Proof |
|---|---|---|---|---|
| **E-9** (new) | **H** | `reset-lab.sh CP-lab-01` forced Git back and re-synced, but left a rehearsal's ReplicaSets, Deployment rollout revision (4), and ten Application history entries. Module 3 Step E then prints `REVISION 2 3 4`, not `1`, which falsifies "no new Pod was ever started". It also polluted SS-L1-03 and the History panel. Hits every instructor who rehearses on the VM and every participant who resets to retry | `courseware/environment/scripts/reset-lab.sh`: header comment lines 19–21; step 4 lines 286–295 (for `CP-baseline` only, `delete_app_cascade hello-reconcile` and wait for the workload to go; step 5 re-applies it and step 9 syncs it, as bootstrap does); helpers `hello_workload_gone` / `hello_fresh_rollout` lines 476–491; new verifier row for `CP-baseline` lines 514–518 | `bash -n` OK. Contaminated state: verify exit 1 with the new row FAIL. Reset 33 s, then 8/8 PASS, `rollout history` = 1, one ReplicaSet, history ID 0. `CP-lab-02` path unchanged (7/7 PASS, matches Lab 2's sample) |
| **E-10** (new) | M | Screenshot manifest entries SS-L1-06, -07, -09, -10 had no `actions`, so the harness captured the bare app page. The committed PNGs were copies of SS-L1-05 (tree) or the list view | `screenshot-manifest.yaml` lines 199–281: click actions for **Diff**, **Sync**, Pod node → **Events**, **History and rollback**; working selectors; SS-L1-08 highlight now targets the LAST SYNC item (the old selector drew a 0-px line) | All four re-captured and visually confirmed (Section 5) |

### Participant guide and Lab 0

| ID | Sev | File:line (after edit) | Finding | Change |
|---|---|---|---|---|
| D1 = **G-16** | M | `lab-01/01-setup-and-dependencies.md` §1, lines 21–41 | Verifier sample had a `▶` header and 4 rows; real output has `==>` and 8 rows | Real output pasted. Three rows explained in plain language (rollout, ServiceAccount expanded) |
| D2 = **G-13** (part) | M | `01-setup-and-dependencies.md` §3, the `argocd app get` block (≈ lines 80–106) | Pre-3.5 layout, placeholder SHA, empty MESSAGE column | Real output, including login lines. Address-label paragraph maps each field name; one sentence explains MESSAGE |
| D3 | M | `02-commit-and-sync.md:77`, `03-why-the-app-didnt-change.md:118`, `04-three-views-and-wrap-up.md:118` | "Click **App Diff**" — no such control in v3.5.2 | **Diff**; notes that it is greyed out while Synced |
| D4 | L | `02-commit-and-sync.md:97`, `03-why-the-app-didnt-change.md:135` | "and confirm" — the button is **Synchronize** | Named the panel and the **Synchronize** button; embedded SS-L1-07 (module 02 lines 99–103) |
| D5 | M | `02-commit-and-sync.md:91–95`; `04-three-views-and-wrap-up.md:60–62, 122–124` | SS-L1-06, SS-L1-09, SS-L1-10 images contradicted their captions | Re-captured; captions now describe the real panel |
| D6 = **G-3** | M | `04-three-views-and-wrap-up.md:17–25` | `sed` range drops `data:` | `yq 'select(.kind == "ConfigMap")'` plus a sanity check that does not reveal the answer |
| D7 | M | `03-why-the-app-didnt-change.md:129–133, 147–151` | Step G's UI actions had no screenshot (CLAUDE.md rule); SS-L1-11/12 existed only as specs | Captured and embedded SS-L1-11 and SS-L1-12 with capture-spec comments |
| D8 | L | `03-why-the-app-didnt-change.md:135, 145` | "`Progressing` can vanish in a blink" (observed ≈7 s); sample Window C has no variance note | Note that names, ages, and repeated lines vary; `Progressing` "lasts until the readiness check passes — a few seconds" |
| D9 | M | `04-three-views-and-wrap-up.md:134` | "Your extra commits … are harmless" — the Lab 2 reset discards them from Gitea and the clone (verified) | States that the reset discards Lab 1 commits, and how to keep a copy |
| D10 | M | `Lab 0 — Prepare Your VM for Lab 1.md:280–282` | "Expect a message change to affect both the ConfigMap and the Deployment annotation" contradicts the redesigned Lab 1 (Part 1 diff = ConfigMap only). The stale-baseline paragraph gave no way to detect the problem | Corrected bullet; paragraph now points at the verifier row that FAILs on a stale baseline |
| D11 | L | `02-commit-and-sync.md:77` | Pronoun "It" became ambiguous after the D3 insertion | "The app does not auto-sync…" |

### Instructor walkthrough

`courseware/instructor/day-1/lab-01-follow-an-application-through-reconciliation-SOLUTION.md` keeps its Say/Do/Click/Expect/Answer key/Wrong turns/Wow format. Changes:

- **Header:** revalidation note.
- **0.1:** 8-row verifier output.
- **0.2:** new paragraph on rehearsal rollout history and the reset fix.
- **0.3:** the "guide out of step" table is replaced by a "what still varies" table (SHAs, the MESSAGE column, Window C timing, `Progressing`).
- **Section references:** run of show and §2 heading now say "Module 01, sections 1–4"; "Section 6.3" → "2.2".
- **2.1 and Step D Expect blocks:** real output (`created` MESSAGE, 40 s detection note).
- **Step E Expect:** Pod age and name from this run, with a corrected note.
- **Timing wording:** "two seconds" → "a few seconds" / "two to seven seconds".
- **E3:** Do note; `yq` leading `---`; the `sed` wrong turn replaced by the verified `yq` no-`select` wrong turn.
- **Stretch history note:** a reset now clears history; verified IDs.

---

## 4. Status of the carried-over defects

| ID | Status before this pass | Evidence | Status now |
|---|---|---|---|
| **G-2** | **Already fixed** in the modular guide | `02-commit-and-sync.md` and module 03 use `'"message": *"[^"]*"'`; returns `"message": "Hello from Git, revision one"`; the old pattern matches 0 lines | Closed, no change |
| **G-3** | **Still present** | `sed` output had no `data:` | **Fixed** (D6) |
| **G-13** | **Still present** (module 01 sample pre-3.5; SS-L1-06 was the tree image) | Real `argocd app get` differs; PNG identical to SS-L1-05 | **Fixed** (D2, D5). The "diff shows two resources" part is obsolete: after the redesign the Part 1 diff shows one resource and stretch A two, both verified |
| **G-16** (Lab 1 part) | **Still present** | 4 rows in the guide vs 7 (now 8) real | **Fixed** (D1). Lab 4's sample is out of scope and was not checked |
| **E-5** | **Obsolete as written, risk still real** | The lab was redesigned so the chart deliberately has *no* Pod-template annotation. Seed chart, Gitea `cp-baseline`, and live Deployment all have none. A sandbox seeded from an older chart would still break the lab silently | **Resolved**: the new verifier row (`rollout revision 1, no Pod-template annotations`) FAILs on an old seed or a leftover Part 3 commit; Lab 0 §10 now tells the participant to stop if it does |

---

## 5. Screenshots

Every PNG the lab embeds was read before and after re-capture, and compared with its caption and with the live UI at that step.

| ID | File | Before this pass | Action | After |
|---|---|---|---|---|
| SS-L1-02 | `lab-01-02-applications-healthy.png` | Matched (older SHA/dates) | Re-captured at `CP-lab-01` | One tile, Synced/Healthy, `default`, `hello` — matches |
| SS-L1-03 | `lab-01-03-resource-tree.png` | Matched. The first re-capture showed **three ReplicaSets** (E-9) | Re-captured after the E-9 fix | App → cm/svc/deploy → one ReplicaSet `rev:1` → Pod — matches. Pod node slightly clipped at the right edge (cosmetic) |
| SS-L1-05 | `lab-01-05-outofsync-after-refresh.png` | Matched, but the commit comment differed from the guide's message | Re-captured after the Part 1 push | App + ConfigMap OutOfSync, Healthy; comment "Lab 1: change message to revision two" |
| SS-L1-06 | `lab-01-06-app-diff.png` | **Contradiction:** byte-identical to SS-L1-05 (tree, no diff) | Manifest actions + re-capture | **Diff** tab, ConfigMap only, one highlighted line (`one` → `two`); caption updated |
| SS-L1-07 | `lab-01-07-sync-panel.png` | **Contradiction:** identical to SS-L1-05 (linked by the walkthrough) | Manifest actions + re-capture; now embedded in module 02 | Panel with **Synchronize**/**Cancel**, Prune unchecked, three resources |
| SS-L1-08 | `lab-01-08-synced-new-revision.png` | Matched (older SHAs) | Re-captured after the Part 1 sync | Synced to `4bf9e96`, Sync OK, same `rev:1` ReplicaSet (no new Pod) — matches |
| SS-L1-09 | `lab-01-09-pod-events.png` | **Contradiction:** resource list view, no events tab | Manifest actions + re-capture after the Part 3 rollout | Pod `…-zmpxt` **Events** tab: Pulled, Created, Started, Scheduled; caption updated |
| SS-L1-10 | `lab-01-10-history.png` | **Contradiction:** identical to SS-L1-09 (list view), baseline SHA | Manifest actions + re-capture after stretch A | **History and rollback**: `37434aa`, `f083e46`, `4bf9e96`, newest first; caption updated |
| SS-L1-11 | `lab-01-11-deployment-outofsync-checksum.png` | Did not exist | Captured; embedded in module 03 | Deployment OutOfSync, ConfigMap Synced, ReplicaSet `rev:1` |
| SS-L1-12 | `lab-01-12-rollout-new-replicaset.png` | Did not exist | Captured; embedded in module 03 | Deployment `rev:2`; new ReplicaSet `rev:2` with the Pod; old `rev:1` at 0 |
| SS-L1-01, SS-L1-04 | login, manifest tab | Not embedded in the modular guide | Not reviewed | — |

`capture-log.md` rows for all ten re-captured IDs merged (Argo CD `v3.5.2`, all `ok`, all highlighted).

---

## 6. Answer-separation check

Participant modules gained no answers:

- The E3 sanity check says only that `data:` must be present.
- The captions describe UI locations, not the E4 table.
- The Module 01 row explanations describe the environment, not E1.

Answers remain only in the instructor walkthrough.

## 7. Reproducibility and fragility notes

- **Timer:** detection ≤ 60 s is deterministic here (jitter `0s`); Refresh makes it immediate.
- **Rollout timing:** 2–7 s across runs (readiness probe period 5 s). The guide's wording now allows for it.
- **Mid-class `CP-lab-01` reset:** now recreates the app, so it restarts the Pod (≈15 s with no `hello-reconcile` Pod). Harmless between classes; worth knowing mid-class.
- **Participant clone:** a `CP-lab-02` reset hard-resets it, and the guide now says so.

## 8. Open issues needing a human decision

1. **E-7 still open (environment-engineer).** Lab 0 has participants source `~/argo-lab-env.sh`, which sets `COURSE_USER_HOME=$HOME`. `reset-lab.sh` then hard-resets and `git clean`s *every* Gitea-backed clone in `$HOME`, not only course repositories. On a dedicated VM that matches "discards your work"; on a shared or personal machine it is destructive. Not changed (outside Lab 1's files beyond the reset fix).
2. **Pod-delete demonstration is instructor-only.** Module 04's takeaway "Deleting a Pod is not drift; deleting the Deployment is" is observed only in the walkthrough's §2.2 demo. Self-paced participants never see it. Consider a 60-second optional micro-step in Module 01 (lab-engineer decision; verified behavior is in row 29).
3. **SS-L1-03 Pod node clipped** at the right edge of a 1440 px viewport. Cosmetic. Options: a per-shot wider viewport, or a "fit to screen" click action in the manifest.
4. **Concurrent edit not made by this pass:** `courseware/environment/instructor-setup-guide.md` changed at 20:43:50 during this run (it now points at `courseware/reviews/lab-0N-validation-<date>.md` reports). Left untouched; confirm it is intended.
5. **Lab 0 §10 bullet** "Use VM terminal windows wherever the guide says 'SSH session'" — Lab 1 never says "SSH session" (only `student-setup-guide.md` does). Harmless; left.
6. **VM-only verification still outstanding:**
   - Lab 0 §2–§6 on the provider VM: the `training` account, `apt-get`, the k3d install script, cloning from GitHub, the env file, and a fresh `bootstrap-vm.sh --local` with its 20–30 min estimate;
   - Firefox inside the VM desktop;
   - that a fresh bootstrap yields rollout revision 1 (expected from the code — one sync of a new Application — but not re-run here).

## 9. Retest requirements

- On the next provisioned VM: run Lab 0 end to end, then `reset-lab.sh CP-lab-01 --verify-only --local`. Expect the new 8-row PASS table.
- After any change to `reset-lab.sh`: re-run `CP-lab-01` from a post-Lab-1 state and confirm `rollout history` = `1`; confirm `CP-lab-02` still prints Lab 2's 7-row sample.
- If the Argo CD version pin changes: re-capture SS-L1-02 to SS-L1-12 with `node capture.mjs --only …` at the states in the manifest, and re-check the **Diff** / **Synchronize** / **History and rollback** labels.

## 10. Final sandbox state

- `reset-lab.sh CP-lab-02 --yes --local` → `PASS CP-lab-02 is in the expected state.` (7/7; `--verify-only` exit 0).
- `hello-reconcile` is `Synced`/`Healthy` at `9ec1d9c`; Gitea `main` = `cp-lab-02` tag.
- Participant clone `~/.argocd-course/student-home/hello-reconcile` is clean at `9ec1d9c`.
- No `kubectl port-forward` or watch processes remain; port 9898 is free.
- `COURSE_USER_HOME` was never set; the real `~/hello-reconcile` directory was not touched.
- `argocd` CLI context `localhost:8443` is logged in as `admin` (as the reset script leaves it).
- Nothing was committed.

### Files changed by this pass

- `courseware/day-1/lab-01/01-setup-and-dependencies.md`, `02-commit-and-sync.md`, `03-why-the-app-didnt-change.md`, `04-three-views-and-wrap-up.md`
- `courseware/day-1/Lab 0 — Prepare Your VM for Lab 1.md`
- `courseware/instructor/day-1/lab-01-follow-an-application-through-reconciliation-SOLUTION.md`
- `courseware/environment/scripts/reset-lab.sh` (on top of the owner's uncommitted onboarding-Secret change)
- `courseware/environment/scripts/screenshots/screenshot-manifest.yaml`
- `courseware/assets/screenshots/day-1/lab-01-02, -03, -05, -06, -07, -08, -09, -10` (re-captured); `lab-01-11`, `lab-01-12` (new)
- `courseware/assets/screenshots/capture-log.md` (rows merged by the harness)
- `courseware/reviews/lab-01-validation-2026-09-13.md` (this report)
