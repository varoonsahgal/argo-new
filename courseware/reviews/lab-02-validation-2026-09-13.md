# Lab 2 validation: Configure the Platform and Register a Target

- **Date:** 2026-09-13 (evening pass)
- **Scope:** `courseware/day-1/lab-02/` (README and modules 01–04), the stub `lab-02-configure-platform-and-register-target.md`, the instructor walkthrough `courseware/instructor/day-1/lab-02-configure-platform-and-register-target-SOLUTION.md`, and the environment pieces Lab 2 uses (`reset-lab.sh`, `lab-files/lab-02`, the `platform-config` seed and `CP-lab-03` overlay, the screenshot harness)
- **Objectives tested:** L2.1–L2.5 and O7

## Verdict

**PASS WITH NOTES** (after the fixes below). **Interestingness: STRONG.**

**Before this pass the lab was FAIL.** A participant following the guide exactly would:

- reach E2's success criterion ("workload shows green **Successful**") and see `Unknown`. Hint 5 then told them their `server:` line was wrong, when it was right;
- apply E5 record 1 as printed (unrendered), get "authentication required", and name the wrong field;
- after fixing a bad password in E1, keep seeing `Failed` for up to an hour, because repository status is cached;
- compare against four screenshots that showed something other than their captions.

Every one of those is now fixed and re-executed. The remaining notes are VM-only checks and cross-lab items (Section 8).

Why the interest rating is STRONG: participants make a genuine placement decision (which cluster gets the identity), predict and prove a permission matrix, and debug a relative path from a real error. They now also meet two honest v3.5.2 surprises: `Unknown` means "not checked yet", and a status can be an hour old.

---

## 1. Environment tested

Local two-cluster sandbox on the build Mac (macOS arm64, Docker Desktop), not a provisioned student VM.

| Component | Observed |
|---|---|
| Argo CD server / `argocd` CLI | `v3.5.2` / `v3.5.2+e258ee2.dirty` |
| Kubernetes (`k3d-mgmt`, `k3d-workload`) | `v1.35.8` (client `v1.35.8`) |
| Helm / yq (pinned) | `v4.2.1+gd591a19` / `v4.48.1` |
| argocd-server `--connection-status-cache-expiration` | default `1h0m0s` (from `argocd-server --help` in the Pod) |
| Screenshot harness | `capture.mjs` (Playwright headless Chromium, 1440×900) |

**Local mappings (no change to lab semantics):**

- `~` meant `~/.argocd-course/student-home`, and `~/course/lab-files` meant `courseware/environment/lab-files`.
- `GIT_CONFIG_GLOBAL` pointed at that home's `.gitconfig`, where the `lab-gitea` → `localhost` rewrite lives.
- `git push` used a credential helper that reads the credential file.
- Scripts were run by full path with `--local`; `~/argo-lab-env.sh` was **never sourced**, and `COURSE_USER_HOME` was never set.
- UI steps were checked with Playwright (probe scripts and `capture.mjs`).
- Credential-bearing annotations were inspected by **key name only**. No password, token, CA, or annotation value was printed.

**Parity notes for the real VM** (environment-engineer / instructor):

- `envsubst` came from Homebrew here; confirm it is on the VM image.
- `git push` will prompt for credentials on the VM.
- Firefox inside the VM desktop was not exercised.
- The cluster-info update interval (blank → `Unknown` took about 50–60 s here) and the 5 s `Unknown` → `Successful` transition may be slower under classroom load.

---

## 2. Execution log

| # | Step (module) | Command / action | Expected (guide before fix) | Actual | Result |
|---|---|---|---|---|---|
| 1 | Start | `reset-lab.sh CP-lab-02 --yes --local` | PASS | PASS in 24 s; no repository Secret, one cluster Secret | PASS (E-4 fixed) |
| 2 | M01 §1 | `reset-lab.sh CP-lab-02 --verify-only --local` | 7-row block | identical 7 rows (a blank line precedes `==>`) | PASS |
| 3 | M01 §2 | Settings → Repositories | "No repositories connected" | identical (SS-L2-01 re-captured, same bytes) | PASS |
| 4 | M01 §3 | `git clone …/platform-config.git`; `git config` ×2 | clone succeeds | succeeds anonymously. A second clone attempt: `fatal: destination path 'platform-config' already exists and is not an empty directory.` (rc 128) — no guidance | PASS; **D13** fixed |
| 5 | M01 §4 | two address-book queries | none / `in-cluster` | identical | PASS |
| 6 | M01 §5 | `cat` both templates | abbreviated blocks | the real files have a comment header, `apiVersion`/`kind`/`type`, and multi-line JSON; the `# <--` notes are not in the files | **D12** fixed |
| 7 | E1 | `sed` + `envsubst` → `kubectl apply -f -` (as hinted) | Successful | `created`; first `argocd repo list` (0 s) `Successful`; annotation keys: `kubectl.kubernetes.io/last-applied-configuration` | works; **E-3** reproduced |
| 8 | E1 | same, `apply --server-side -f -` on a fresh Secret | — | `serverside-applied`; `Successful`; annotation keys: *(none)*; `git status` clean | PASS (fix) |
| 9 | E1 wrong turn | `envsubst` without `sed` on the real Secret | Failed | plain `repo list` still **`Successful`** (cached); `--refresh hard` → `Failed … authentication required: Failed to authenticate user`. After the fix, plain list still **`Failed`**; `--refresh hard` → `Successful` | **D3** (fixed) |
| 10 | E2 Move A | `kubectl --context k3d-workload apply -f workload-rbac.yaml` | 12 objects | identical; token already populated; 0 argocd ClusterRoleBindings | PASS |
| 11 | E2 B/C | token + CA → `sed` → `apply --server-side` | `created` | `token length=936 ca length=756`, `serverside-applied`, no annotation keys | PASS |
| 12 | E2 reveal | address book; `argocd cluster list` | two rows; workload **Successful** | two Secret rows; workload STATUS **blank**, then at 60 s **`Unknown` — "Cluster has no applications and is not being monitored."**; UI identical; detail page APPLICATIONS 0 | **D1** (fixed) |
| 13 | E3 | four `can-i` + wrong context | yes/no/no/no | identical; row 4 prints `Warning: resource 'namespaces' is not namespace scoped` + blank line; wrong context `no`; `networkpolicies` in `storefront-dev` `yes` | PASS; **D14** fixed |
| 14 | E4 wrong turn | `valueFiles: ../envs/dev/values.yaml` | red ComparisonError | sync `Unknown`, health `Healthy`, ComparisonError text identical to walkthrough | PASS |
| 15 | E4 | fix path, commit, push, apply ×2, `app get --refresh` | OutOfSync/Missing | `9c90a80` pushed; `OutOfSync from main (a0ec068)` / `Missing`; 3 resources | PASS |
| 16 | E4 | `argocd cluster list` after apply | — | workload **`Successful` at t+5 s** | new callout added |
| 17 | E4 | `proj get`, `app diff` | 3 desired-only sections | identical; 0 live-side lines | PASS |
| 18 | E4 hint 3 | throwaway app, server `https://127.0.0.1:6551` (deleted) | stuck Unknown | `Unknown` + `InvalidSpecError … cluster "https://127.0.0.1:6551" not found` | PASS |
| 19 | E5 rec 1 | apply file as printed (unrendered) | Failed + URL message | `Failed … authentication required: Failed to authenticate user` — a password error, so the file has two wrong fields | **D2** (fixed) |
| 20 | E5 rec 1 | rendered, `--server-side` | "repository not found" | plain list: stale auth message (cache); `--refresh hard`: `repository not found: Repository not found` | PASS after **D2/D3** fixes |
| 21 | E5 rec 1 UI | Repositories | message visible | list shows only `Failed`; message in icon `title` and in the row panel's **Connection State Details**; **Refresh list** calls `/repositories?forceRefresh=true` | **D11** fixed |
| 22 | E5 rec 2 | as-is and rendered | **Failed** | both: blank, then `Unknown` / "Cluster has no applications and is not being monitored."; detail page identical | **G-7** fixed |
| 23 | E5 cleanup | delete both | pages clean, E1/E2 Successful | identical (after `--refresh hard`) | PASS |
| 24 | Checkpoint | `reset-lab.sh CP-lab-03 --verify-only --local` on my own work | PASS | 12/12 PASS, including `…exactly: in-cluster, repo-storefront-gitops, cluster-workload`. Not checked: project allows only `storefront-dev` (checkpoint: 3); Gitea holds my commit | PASS; **D15** wording fixed |
| 25 | Stretch A | `echo y \| argocd cluster add k3d-workload` | fails | rc 20, `dial tcp 127.0.0.1:6551: connect: connection refused`. Leaves SA + `argocd-manager-role` (`["*"] ["*"] ["*"]`) + binding + long-lived token; `can-i delete namespaces` as that SA → **yes** | **G-6** fixed |
| 26 | Stretch A cleanup | 4 deletes | — | all gone; E2 SA in `argocd-access` untouched | PASS |
| 27 | Stretch C | patch token | `Unknown` | t+5 s sync `Unknown`, **health `Healthy`** (was `Missing`), cluster list still `Successful`; t+65 s cluster `Failed … provide credentials` | PASS; **D18** wording |
| 28 | Stretch C restore | `--server-side` re-render (no `--force-conflicts`) | OutOfSync/Missing | no conflict; `OutOfSync`/`Missing` in 5 s; no annotation | PASS |
| 29 | Env proof | seed stale annotations + stretch-A leftovers + stretch-C break → `reset-lab.sh CP-lab-03 --yes --local` | PASS | 22 s; 12/12 PASS; credential Secrets have **no** annotation keys; leftovers 0; `OutOfSync`/`Missing`; clone at `006f5bd checkpoint CP-lab-03`; project has 3 destinations | PASS |
| 30 | Regression | `reset-lab.sh CP-lab-02 --yes --local` | 7 rows | 25 s; identical 7 rows; no repository Secret; leftovers 0 | PASS |
| 31 | End | `reset-lab.sh CP-lab-03 --yes --local` | PASS | 22 s; 12/12 PASS (Section 10) | PASS |

**Runtime.** Machine-driven E1–E5 plus stretches took about 20 minutes, excluding screenshot work. Participant-felt waits:

- about 1 minute before E2 shows `Unknown`;
- about 5 s for `Successful` after E4;
- about 1 minute for record 2 to read `Unknown`;
- 22–25 s per reset.

The 60-minute budget is realistic. E2 (17 min) remains the long pole.

---

## 3. Defects found and changes made

### Environment

| ID | Sev | File:line (after edit) | Finding | Change | Proof |
|---|---|---|---|---|---|
| **E-3** | H | `environment/scripts/reset-lab.sh:144–167` | `render_and_apply_secret` used client-side `apply` → credential copied into `last-applied-configuration`. Probe (dummy Secret): server-side apply keeps an **existing** annotation *and rewrites it with the new values*; only remove-then-SSA leaves none | Strip the annotation by name (read from the template with `yq`), then `apply --server-side --force-conflicts` | `bash -n` OK. Seeded both Secrets with a client-side annotation; after the `CP-lab-03` reset both have no annotation keys; 12/12 PASS |
| **G-6** (env part) | M | `reset-lab.sh:423–431` (step 6) | Stretch A leftovers survived every reset | Delete `argocd-manager-role-binding`, `argocd-manager-role`, `kube-system/argocd-manager-long-lived-token`, `kube-system/argocd-manager` on every reset, with an `ok` line | Seeded leftovers (2 cluster-scoped + 2 in kube-system) → 0 after reset; `CP-lab-02` table unchanged |
| D8 | M | `screenshots/screenshot-manifest.yaml:377–394` | SS-L2-04 had no action; selector `.cluster-details` does not exist in v3.5.2 → list captured | Click the workload row; `wait_for .white-box`; state note "after E2, before E4" | Re-captured (Section 5) |
| D9 | M | `screenshot-manifest.yaml:440–455` | SS-L2-08 captured the tree (no Diff click) | Same verified **Diff** actions as SS-L1-06 | Re-captured |
| D10 | L | `screenshot-manifest.yaml:396–412` | SS-L2-05 cut off above DESTINATIONS | Per-shot viewport 1440×1600 | Re-captured |
| D11 | L | `screenshot-manifest.yaml:458–478` | SS-L2-09 intent "Failed status and message", but the list has no message | Click **Refresh list**, then the `storefront-typo` row; highlight the panel | Re-captured |
| — | L | `screenshot-manifest.yaml:362–375, 480–496` | SS-L2-03/-10 intents said Successful/Failed | Truthful state/intent notes | — |

### Participant guide

| ID | Sev | File:line (after edit) | Finding | Change |
|---|---|---|---|---|
| **D1** | **H** | `02-connect-repo-and-register-cluster.md:8, 68, 84–86, 93, 95–105, 115, 122–125`; `03-…:134–135`; `04-…:91, 108` | E2 goal, shape, success criterion, Hint 5, and SS-L2-03 caption claimed **Successful** right after registration. v3.5.2 leaves the status blank, then `Unknown` ("not being monitored") until an Application uses the cluster | Explained why `Unknown` is expected; success criterion now `Unknown` + detail page; Hint 5 says check `server:` by eye because the mistake surfaces only in E4; new E4 callout "see the cluster half for yourself" (Unknown → Successful); troubleshooting row |
| **D2** | **H** | `04-diagnose-and-wrap-up.md:27, 36–42` | E5 step 2 applied record 1 unrendered → the password is also wrong → "authentication required"; defeats "single wrong field" | Render like E1/E2, apply with `--server-side`; a short "why not as-is" note |
| **D3** | **H** | `02-…:42, 122`; `04-…:44, 61, 89–90` | Repository status is cached for 1 h; the guide said "a measurement taken a moment ago" and "re-apply" | Callout and takeaway corrected; **Refresh list** / `argocd repo list --refresh hard` in E5 step 3, success criterion, and two troubleshooting rows |
| **E-3** (guide part) | H | `02-…:31–32, 47, 92, 121`; `04-…:40, 99` | Hints piped into client-side `apply` | `--server-side` with a plain-language reason; a key-names-only check (verified: prints nothing); troubleshooting row to strip a stale annotation |
| **G-7** | M | `04-…:44–45, 54, 58, 69, 78, 124` | Record 2 "Failed" | "Unknown — nobody measured"; click-row Details; caption; takeaway |
| **G-6** (guide part) | M | `04-…:138–151, 177` | Stretch A had no warning or cleanup | ⚠️ warning naming all four objects and their scope; four verified cleanup commands; transition reminder |
| D7 | M | SS-L2-02 caption `02-…:38` | SS-L2-02 and SS-L2-09 showed a credentials-template row (`course-repo-creds`, a CP-lab-04 object) — contradicting Module 1's own "later lab" warning | Re-captured; caption notes it is the only row |
| D11 | L | `04-…:44, 65` | Caption "with a message"; the list shows only Failed | Step 3 and caption say click the row → **Connection State Details** |
| D12 | M | `01-environment-and-address-book.md:150–203` | Template blocks shown as `cat` output were abbreviated and reformatted | Real lines (comment header marked `# ...`), multi-line JSON, note that `# <--` notes are the guide's |
| D13 | L | `01-…:90–92` | Clone retry fails with no guidance | Note: `cd ~/platform-config`; a reset already restored it; "(other files omitted)" |
| D14 | L | `03-prove-least-privilege-and-create-app.md:29` | Row 4 warning unexplained | One sentence: harmless; the answer is the last line (no answer revealed) |
| D15 | L | `04-…:113` | "This is exactly checkpoint CP-lab-03" | The verifier PASSes; names the two expected differences |
| D16 | L | `02-…:114`; `04-…:129` | "Module 3 tests both" / "`can-i` proves both" locks — `can-i` tests only Kubernetes RBAC | "tests the first lock; the second is a setting Argo CD itself enforces" |
| D17 | L | `03-…:102, 112` | "tree and diff"; `Sync Status: OutOfSync` | Names the **Diff** button; `OutOfSync from main (…)` |
| D18 | L | `04-…:165–167` | Stretch C omitted the `Healthy` badge, the minute of stale `Successful`, and that the reset replaces the clone | Added all three (verified) and offered the quicker Move B/C restore |

### Instructor walkthrough

Rewritten in place, keeping its Say / Do / Click / Expect / Answer key / Wrong turns / Wow format.

- **§0.1:** the old "reset does not delete the Secrets" pre-flight is replaced by the verified 7-row reset output and the clone-retry note.
- **§0.3:** now "four places v3.5.2 surprises people" (Unknown until used, 1 h cache, record 2, stretch A).
- **§0.4:** server-side apply, with the four-case probe table and the key-names check.
- **E1:**
  - both options use `--server-side`;
  - a cache note on the prediction;
  - three verified wrong turns (bad password with the cache, fix still `Failed`, missing `--server-side`).
- **E2:**
  - `serverside-applied`;
  - blank and then `Unknown` Expect blocks;
  - a "why not green" Say;
  - wrong turns re-labelled "invisible until E4", with unverified messages marked.
- **E4:** new SHA; `argocd cluster list` → `Successful` payoff; InvalidSpecError text.
- **E5:** `--server-side` and `--refresh hard`; "If it goes sideways" for unrendered and cached cases; record 2 blank → `Unknown` blocks; Say reworded.
- **§7:** adds the "exactly" row and the fields it doesn't check.
- **§8A:** verified ClusterRole scope; reset now removes the leftovers.
- **§8C:** t+65 s `Failed` block; Healthy-badge Say; restore via `--server-side`; reset path verified.
- **Debrief:** adds "why was your good cluster Unknown?".

---

## 4. Carried-over defects

| ID | Status before this pass | Evidence | Status now |
|---|---|---|---|
| **E-3** | **Still present** (guide hints and `reset-lab.sh` client-side) | Annotation key present after hinted E1; probe showed SSA preserves and rewrites a stale annotation | **Fixed** (env + guide + walkthrough). Reset proven to strip stale copies. `in-cluster` still carries a client-side annotation that holds no credential |
| **E-4** | **Fixed** by the owner's step-4 change | `CP-lab-02` reset → no repository Secret; `exactly: in-cluster` row PASS; re-verified after my edits (25 s, 7/7) | Closed. Walkthrough §0.1 and instructor README row 5 were stale; walkthrough fixed, README reported (Section 8) |
| **G-6** | **Still present** | Leftovers created; ClusterRole `*/*/*`; SA can delete namespaces; survived resets | **Fixed** (guide warning + cleanup, reset step 6, walkthrough) |
| **G-7** | **Still present** (step 3, shape, SS-L2-10 caption) | `Unknown`, "Cluster has no applications and is not being monitored.", rendered or not | **Fixed** |

---

## 5. Screenshots

Every PNG the lab embeds was read before and after, and compared with its caption and the live UI at that step. `capture-log.md` rows SS-L2-01…10 merged (v3.5.2, all `ok`, all highlighted).

| ID | Before this pass | Action | After (verified against the live UI) |
|---|---|---|---|
| SS-L2-01 | Matched (owner's fix) | Re-captured at `CP-lab-02` | "No repositories connected" — byte-identical |
| SS-L2-02 | **Contradiction:** extra credentials-template row (CP-lab-04 object) | Re-captured after E1 | One `storefront-gitops` row, Successful |
| SS-L2-03 | **Contradiction:** workload **Successful** (captured at CP-lab-03) | Re-captured after E2, before E4; caption fixed | workload `Unknown`, in-cluster Successful |
| SS-L2-04 | **Contradiction:** plain cluster list, no detail panel | Manifest action; re-captured; caption fixed | Detail page: namespaces, labels, APPLICATIONS 0, Connection state Unknown + message |
| SS-L2-05 | Partial: destinations and allow-list cut off | Viewport 1600 | Source repo, destination `storefront-dev`, "cluster resource allow list is empty" |
| SS-L2-06 | Matched | Re-captured after E4 | `storefront-dev` Missing/OutOfSync |
| SS-L2-07 | Matched | Re-captured after E4 | All nodes Missing/OutOfSync, `a0ec068` |
| SS-L2-08 | **Contradiction:** same tree image as SS-L2-07 | Diff actions; re-captured | **Diff** tab, ConfigMap/Service desired-only |
| SS-L2-09 | **Contradiction:** credentials-template row; no message visible | Refresh list + row click; caption fixed | Panel with **Connection State Details** "…repository not found" |
| SS-L2-10 | Image correct (`Unknown`); **caption said Failed** | Re-captured (byte-identical); caption fixed | `workload-loopback` Unknown beside `workload` Successful |

## 6. Clarification callouts (🧭 / ✅ / big picture)

All callouts and takeaways were kept, and most were accurate against what I observed: the README delivery-driver table, all Module 1 callouts, and the E3/E4 callouts. False sentences corrected, in the same plain tone:

- **Module 2 🗺️:** "After this module, Argo CD can see both ends" → it *holds the keys* to both ends; it first uses the cluster key in Module 3.
- **E1 "What Successful actually means":** "a measurement taken a moment ago" → "from the last check", which Argo CD remembers for up to an hour; Refresh list re-checks.
- **E1 takeaway:** "never landed on screen, on disk, or in Git" → added "or in an annotation" (it did land there before E-3).
- **E2 takeaway:** "Module 3 tests both" → "Module 3's E3 tests the first one"; added "Unknown right after registering means not checked yet".
- **Module 2 takeaways:** "a reading taken a moment ago" and "Argo CD can … reach the workload cluster" corrected as above.
- **Module 4 whole-lab takeaway:** "`kubectl auth can-i` proves both" locks → tests the first; the second is enforced by Argo CD.
- **E5 🧭 "Think of it like":** extended with the "no note at all" case; one E5 takeaway added about `Unknown` hiding a broken record.

No participant file gained an answer: E5 step 2 reuses E1/E2 methods without printing them, and captions describe the UI, not the wrong fields.

## 7. Reproducibility and fragility

- **Blank → `Unknown` timing** depends on the controller's cluster-info refresh (≈1 min here). The guide says "up to a minute".
- **The 1 h repository status cache** is the biggest live-class trap. It is now documented everywhere the guide says to re-check.
- **Stretch A** is now safe to leave in: the warning, cleanup, and reset path are all verified.
- **The `CP-lab-03` verifier** passes on both the participant's one-destination project and the checkpoint's three-destination project (see Section 8, item 3).

## 8. Open issues needing a human decision

1. **Lab 4 lesson changes (lab-engineer, Lab 4 tester).** `instructor/day-2/lab-04-…-SOLUTION.md` §0.1 and `instructor/README.md` rows 4–5 describe the credential in `last-applied-configuration` and the old CP-lab-02 behavior. With E-3 fixed, resets through `CP-lab-04` no longer create that annotation (`course-repo-creds` also goes through `render_and_apply_secret`), so the Exercise 5A leak should no longer reproduce. Re-validate and reword. Not edited (other lab / shared README).
2. **Capstone — listed, not edited.**
   - `environment/scripts/capstone/faults/F5/revert.sh:44` pipes the rendered cluster Secret (token + CA) into client-side `kmgmt apply -f -`, which re-creates the leak on every F5 revert. Suggested: the same strip-then-`--server-side --force-conflicts` pattern.
   - `courseware/instructor/day-2/capstone-restore-platform-SOLUTION.md` contains `apply -f -`; check whether it renders credentials.
3. **Lab 3 cross-lab state.** A participant arriving from their own Lab 2 has a `storefront` project with only `storefront-dev`. A participant arriving via `reset-lab.sh CP-lab-03` has all three namespaces. Lab 3's troubleshooting row "destination … not permitted in project" only happens on the first path. The Lab 3 tester should confirm Lab 3 E2 reads correctly for both.
4. **Remove the cache trap at the source? (environment-engineer).** Setting `server.connection.status.cache.expiration` lower (for example `1m`) in the course's `argocd/values.yaml` would remove it. Not changed: it alters Argo CD configuration for every lab, and the guide now teaches the real default.
5. **`in-cluster` Secret** still gets a client-side annotation (bootstrap and reset step 5). It holds labels and a server URL, no credential. Switching it is optional for consistency.
6. **Not re-run:** E2 wrong turns (decoded CA, undecoded token, localhost `server:` after E4) and the "RBAC on the wrong cluster" symptom. The walkthrough marks the ones whose messages were not re-run. Option B (webhook) remains unverified.
7. **E-7 still open** (from Lab 1): `~/argo-lab-env.sh` sets `COURSE_USER_HOME=$HOME`.
8. **VM-only:** Firefox label and behavior of **Refresh list**; `envsubst` on the VM image; interactive `git push`; timing under load.

## 9. Retest requirements

- After any change to `reset-lab.sh`:
  - seed a client-side annotation on `repo-storefront-gitops`, reset to `CP-lab-03`, and confirm no annotation keys;
  - confirm `CP-lab-02` still prints the 7-row table.
- If the Argo CD version pin changes, re-check:
  - the blank/`Unknown` cluster status and its message;
  - the `--connection-status-cache-expiration` default;
  - the **Refresh list** and **Diff** labels;
  - SS-L2-01…10, using the manifest states (SS-L2-03/-04 after E2 and *before* E4; SS-L2-10 at least 1 minute after record 2).
- On the next provisioned VM: run E1–E5 in Firefox, and time E2's `Unknown` appearance.

## 10. Final sandbox state

- **Checkpoint:** `reset-lab.sh CP-lab-03 --yes --local` (22 s) → `PASS CP-lab-03 is in the expected state.` (12/12, `--verify-only` exit 0).
- **Applications and connections:** `storefront-dev` `OutOfSync from main (a0ec068)` / `Missing`; `hello-reconcile` Synced/Healthy; `storefront-gitops` Successful (`--refresh hard`); `workload` and `in-cluster` Successful.
- **Annotations and leftovers:** `repo-storefront-gitops` and `cluster-workload` have no annotations; `in-cluster` has only the credential-free `last-applied-configuration`. No `argocd-manager` objects in `kube-system`, and no `argocd-manager-role*` on the workload cluster.
- **Probe cleanup:** probe namespace, probe Application, and probe or broken Secrets deleted (confirmed at the end of the run).
- **Participant clones:** `~/.argocd-course/student-home/platform-config` is at `006f5bd checkpoint CP-lab-03`. The pre-existing clone from earlier runs (`a1e53e9`) was moved to this session's scratchpad before Module 1 so `git clone` could run as written. `hello-reconcile` clone untouched.
- **Processes and shell state:** no port-forward or watch processes; `COURSE_USER_HOME` never set; `~/argo-lab-env.sh` never sourced; the EKS context never used.
- **argocd CLI:** logged in as `admin` at `localhost:8443` (as the reset leaves it).
- **Git:** nothing committed.

### Files changed by this pass

- `courseware/day-1/lab-02/01-environment-and-address-book.md`, `02-connect-repo-and-register-cluster.md`, `03-prove-least-privilege-and-create-app.md`, `04-diagnose-and-wrap-up.md` (README and stub unchanged — accurate)
- `courseware/instructor/day-1/lab-02-configure-platform-and-register-target-SOLUTION.md`
- `courseware/environment/scripts/reset-lab.sh` (on top of the owner's and Lab 1 tester's uncommitted changes)
- `courseware/environment/scripts/screenshots/screenshot-manifest.yaml`
- `courseware/assets/screenshots/day-1/lab-02-02` … `lab-02-09` (re-captured; `-01` and `-10` re-captured byte-identical)
- `courseware/assets/screenshots/capture-log.md` (rows merged by the harness)
- `courseware/reviews/lab-02-validation-2026-09-13.md` (this report)
