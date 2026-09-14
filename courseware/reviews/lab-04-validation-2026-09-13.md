# Lab 4 validation: Build and Troubleshoot the Patterns

- **Date:** 2026-09-13 evening → 2026-09-14 morning (one run, interrupted by an API limit and resumed from the same sandbox state)
- **Scope:** `courseware/day-2/lab-04/` (README and modules 01–04), the stub `lab-04-build-and-troubleshoot-patterns.md`, the instructor walkthrough `courseware/instructor/day-2/lab-04-build-and-troubleshoot-patterns-SOLUTION.md`, row 4 of `courseware/instructor/README.md`, Session 5 screenshot SS-S5-03 and its caption, and the screenshot harness
- **Objectives tested:** L4.1–L4.6 (outcomes O4, O5, O6, O7)

## Verdict

**PASS WITH NOTES** (after the fixes below). **Interestingness: STRONG.**

**Before this pass the lab was FAIL** on the screenshot gate, with several false expected results:

- all ten Lab 4 figures (and SS-S5-03) rendered as broken images; four manifest entries pointed at selectors or routes that do not exist in v3.5.2;
- the SS-L4-09 idea ("root tree shows the broken child") is false — the root's tree shows the broken child with a green **Synced** check;
- checkpoint 9.1's `grep storefront-` prints five rows, not three;
- E4 said a cascade delete of the root removes the children "and their workloads" — the workloads stay;
- E5A said the condition appears and clears promptly — it moves only on the controller's 3-minute ticks;
- stretches 1 and 3 predicted behavior the controller does not have (G-8, G-9).

Every item was fixed and re-executed. Remaining notes are environment/runtime observations and VM-only checks (Section 8).

**Why STRONG:** participants predict before each reveal (count and names, 2 × 3, survive-or-delete, strict-or-silent, root colour), make a real apply/don't-apply decision from a preview, diagnose by *where* evidence lives (ApplicationSet conditions vs child conditions vs the root's tree), and meet genuine v3.5.2 surprises: zero rows is not an error, the controller lags Git by up to 3 minutes, a green root tree hides a broken child, and a cascade stops at the first layer without a finalizer.

---

## 1. Environment tested

Local two-cluster sandbox on the build Mac (macOS arm64, Docker Desktop), not a provisioned student VM.

| Component | Observed |
|---|---|
| Argo CD server / `argocd` CLI | `v3.5.2` / `v3.5.2+e258ee2` |
| Kubernetes (`k3d-mgmt`, `k3d-workload`) | `v1.35.8` (cluster detail page) |
| `timeout.reconciliation` | `60s`, jitter `0s` |
| ApplicationSet controller | `requeueAfter=3m0s` (log) |
| Screenshot harness | `capture.mjs` (Playwright headless Chromium, 1440×900 unless a shot overrides) |

**Local mappings (no change to lab semantics):**

- `~/platform-config`, `~/storefront-gitops` → `~/.argocd-course/student-home/…`; `GIT_CONFIG_GLOBAL` → that home's `.gitconfig` (the `lab-gitea` → `localhost` rewrite). Pushes went through the clones' scratchpad credential helper; each `git push` ran as its own command (a combined commit+push+apply was refused by the session's permission classifier, so steps were split — no semantic change).
- `~/argo-lab-env.sh` was **never sourced**; `COURSE_USER_HOME` was never set. Scripts ran by full path with `--local` / `COURSE_LOCAL=1`. Every `kubectl` call named `k3d-mgmt` or `k3d-workload`; the EKS context was never used.
- BSD `sed -i ''` replaced GNU `sed -i` for the walkthrough's `sed` steps.
- Stretch 1 needed a `platform-components` clone; it was made in the scratchpad.
- **Secrets:** no password, token, CA, or Secret annotation value was displayed. Every failing `argocd appset generate` was written to a scratchpad file, checked with `grep -c` for `last-applied-configuration`, `bearerToken`, `token`, `caData`, `password` (all 0 in every case), and deleted. **Disclosure:** one DOM probe printed the `storefront` **ApplicationSet's** own `last-applied-configuration` annotation (its spec; no credential).
- **Host sleep:** the Mac slept from 06:51:55 to about 07:03, 30 seconds after the E5B fix push, so the E5B recovery time was not re-measured (the end state was verified).

**Parity notes for the real VM** (environment-engineer / instructor): Firefox on the VM was not exercised (headless Chromium only); classroom-load timing not measured; VMs reset before the E-3 fix may still carry credential annotations (instructor README row 4 has the check).

---

## 2. Execution log

| # | Step (module) | Command / action | Expected (guide before fix) | Actual | Result |
|---|---|---|---|---|---|
| 1 | M01 §1 | `reset-lab.sh CP-lab-04 --verify-only --local` | 14-row block | identical 14 rows, exit 0 | PASS |
| 2 | M01 §1 UI | Applications page | "empty of storefront apps" | completely empty: "No applications available to you just yet" | PASS; caption made exact |
| 3 | M01 §2 | cluster-label `custom-columns` | 2 rows | identical | PASS |
| 4 | M01 §2 UI | Settings → Clusters → workload | labels | LABELS `cluster-role=workload region=lab`, APPLICATIONS 0 | PASS; click path added |
| 5 | M01 §3 | `argocd appset create --dry-run -o yaml` ("you can also") | preview | 3 names; generation/resourceVersion unchanged (`4/75168`) | PASS |
| 6 | E1 wrong turn | preview untouched skeleton | names containing `TODO` | **header only, zero rows, exit 0** | **G-14** fixed |
| 7 | E1 wrong turn | selector filled, other TODOs not | — | 3 rows `argocd/TODO`, CLUSTER/NAMESPACE/TARGET `TODO` | troubleshooting row added |
| 8 | E1 wrong turns | `.environment`; `targetRevision: main`; one `..`; `project: storefrnt` | error / silent / silent / error | `map has no entry for key "environment"` (exit 20); prod on `main`; preview OK; `ApplicationSet references project storefrnt which does not exist` | PASS; M01 quote fixed |
| 9 | E1 | preview completed file | 4-column table | same rows in an 11-column table (STATUS/HEALTH blank) | fixed (trimmed with `...`) |
| 10 | E1 | commit, push, `kubectl apply` | 3 apps Synced/Healthy | `OutOfSync/Missing` 5 s → `Progressing` 10 s → `Synced/Healthy` 15 s | PASS |
| 11 | E1 UI | ApplicationSets, tree, Applications | "row" | tile (`Applications: 3`); tree shows grey `?` on generated apps; list 3 Healthy/Synced | PASS; captions fixed |
| 12 | E2 | `matchLabels: {}` preview | 6 rows | 6 rows, `-in-cluster` rows **first** | PASS; order noted |
| 13 | E2 UI | Preview tab → EDIT → delete selector line → PREVIEW | DIFF | "edits are not saved"; DIFF lists 3 added `-in-cluster` blocks only; live AppSet generation unchanged | PASS; UI path added |
| 14 | E2 | `git checkout --`; re-preview | 3 rows | 3 names | PASS |
| 15 | E3 | add `spec.syncPolicy`, commit, push, apply | policy set | `{"applicationsSync":"create-update","preserveResourcesOnDeletion":true}`; controller **removed `resources-finalizer`** from all 3 apps | PASS; mechanism added |
| 16 | E3 | retire prod input, push | 2 preview rows, 3 apps | at once: 2 rows / 3 apps; controller pass **2 min** later (`generated 2 applications`): prod still present, owned, in `status.resources`, Deployment 2/2, conditions green | PASS; timing warning added |
| 17 | E3 wrong turn | apply AppSet **without** policy (input retired) | prod vanishes | `Deleted application` within 5 s (AppSet change = immediate pass); prod Deployment kept (finalizer already gone) | Hint 2 rewritten |
| 18 | E3 restore | re-apply protected file; restore input; push | 3 rows | preview at once; prod re-created at next pass (70 s), adopted running Deployment (no restart) | PASS; restore note added |
| 19 | E4 | `kubectl apply` root; `argocd app get platform-root` | root + 3 children | all 4 `Synced/Healthy` within 6 s; children HEALTH blank; MESSAGE `unchanged` | PASS |
| 20 | E4 trace | printed `grep` loop | clean trace | 13 / 25 / 15 lines per child (matches `status.resources` in 3 namespaces) | replaced with `jsonpath` one-liner + real output |
| 21 | E4 cascade check | `argocd app delete platform-root --yes` | children and workloads deleted | children gone in 3 s; **6 NetworkPolicies, 3 ResourceQuotas, agent Deployment stayed**; no child finalizers; re-apply → all 4 back in 3 s | Notice fixed |
| 22 | E5A | delete staging `namespace:`, push | `ErrorOccurred` | preview fails at once; condition **78 s** later at the controller tick; log `generated 2 applications`, nothing applied; all 3 apps unchanged | PASS; timing and wording fixed |
| 23 | E5A leak | failing preview → file | (row 4: token dump) | 4,037 bytes, exit 20, **0** `last-applied-configuration`, **0** `bearerToken`, 0 token/caData/password; deleted | **fixed** |
| 24 | E5A cmd | guide conditions command | — | 7 lines, message + `RenderTemplateParamsError` | expected output added |
| 25 | E5A UI | ApplicationSets → storefront → CONDITIONS | error | panel with 3 conditions; APPSET HEALTH broken heart; sidebar 3 Healthy | PASS; click path added |
| 26 | E5A optional | delete `goTemplateOptions`; preview; restore | `<no value>`, "looks normal" | exit 0; NAMESPACE column **shows** `<no value>`; `-o yaml` `namespace: <no value>`; strict again exit 20 | wording fixed |
| 27 | E5A fix | `git revert`, push, preview, poll | "error clears" | preview 3 rows at once; condition cleared at next tick (50 s after push) | **G-15** fixed |
| 28 | E5B | `path: quotas-typo`, push | child ComparisonError, root green | child `Unknown/Healthy` + `quotas-typo: app path does not exist` (6 s; 101 s in a second run); root `Synced/Healthy` | PASS; timing fixed |
| 29 | E5B UI | root tree; Applications list; child conditions | SS-L4-09 root tree | root tree shows quotas with a **green Synced check**; list shows quotas `Unknown`; conditions panel has the message (+ "revision main must be resolved" toast) | SS-L4-09 moved to the list; warning added |
| 30 | E5B wrong layer | `kubectl patch` child path | revert | reverted within **1 s** | PASS; timing noted |
| 31 | E5B fix | restore path, push | child Synced/Healthy | end state verified (host slept during recovery) | PASS (not timed) |
| 32 | E5 criterion | preview; AppSet conditions; child | 3 rows, no error | 3 names; `ErrorOccurred=False`; quotas `Synced/Healthy` | PASS |
| 33 | E6 | paper exercise | — | answer key checked against rows 15–21 | PASS; takeaway corrected |
| 34 | 9.1 | `argocd app list -o wide \| grep storefront-` | 3 rows | **5 rows** (platform-netpol/quotas match `storefront-dev`) | fixed: `grep 'argocd/storefront-'` + expected output |
| 35 | 9.2 | `argocd app get platform-root` | root + 3 children | `Synced to main (2705d34)`, 3 children | PASS |
| 36 | Stretch 1 | overlay via `COURSE_LOCAL=1 apply-argocd-config.sh <file>` | root reflects child failure | 21 s; children HEALTH shown only after `--hard-refresh`; (a) 5B again: child `Unknown/Healthy`, root **Healthy**; (b) unpullable agent image: child and root **Progressing** 32 s after push | **G-8** fixed |
| 37 | Stretch 1 cleanup | revert both commits; re-run script without overlay | — | health key count 0; agent Healthy | PASS |
| 38 | Stretch 2 | merge + `templatePatch` preview; naive template | preview | prod `parameters=[replicaCount 3]`, dev/staging none; naive → `map has no entry for key "replicaCount"` | PASS; hint added |
| 39 | Stretch 3 | preview + apply `collision-test` (no automated sync) | "flapping" hypothesis | preview 3 same-named rows, exit 0; applied → `contains applications with duplicate name: collision-test-workload`, **0** apps; deleted | **G-9** fixed |
| 40 | Step 4 | `reset-lab.sh CP-lab-05 --verify-only` on participant state | 21 rows | **22** rows PASS; live AppSet spec == `CP-lab-05` file (policy included) | PASS; verifier limit noted |
| 41 | Handoff | `reset-lab.sh CP-lab-05 --yes --local` | PASS, < 3 min | 22/22 PASS in **6 min 46 s** | PASS (runtime note) |
| 42 | SS-S5-03 | capture at CP-lab-05 | tree | root + 3 children, sync check only on children | caption fixed |

**Runtime.** The participant-felt waits are the long pole. E3 needs up to 3 minutes before prod's survival is meaningful. E5A needs up to 3 minutes for the error condition and up to 3 minutes for it to clear. E5B depends on the 60 s Git check. The 24-minute Module 3 budget is tight if a group waits for both E5A ticks. The guide now says to confirm with the preview and keep going. Everything else is quick: E1 apply to Healthy in 15 s, E4 in 6 s, previews under 1 s.

---

## 3. Defects found and changes made

### Participant guide

| ID | Sev | File:line (after edit) | Finding | Change |
|---|---|---|---|---|
| D1 | L | `01-environment-and-preview.md:52–56` | SS-L4-01 caption/text: "empty of storefront apps" — page is completely empty | Exact empty-state text; Settings → Projects path |
| D2 | L | `01-…:89–93` | SS-L4-02 had no click path | Optional UI step; caption quotes the real LABELS and APPLICATIONS 0 |
| D3 | L | `01-…:115` | Quoted project error text wrong | Real text `ApplicationSet references project storefront which does not exist` |
| **G-14** | L | `02-build-and-protect-the-factory.md:41`, `90`; `04-showdown-and-wrap-up.md:61–62` | Unfilled skeleton said to show `TODO` names | Header-only (zero rows) and `argocd/TODO` rows described separately; troubleshooting split in two |
| D4 | M | `02-…:52–60` | Expected output invented a 4-column table | Real columns trimmed with `...`; blank STATUS/HEALTH explained |
| D5 | M | `02-…:72–86` | SS-L4-04/05/06 one caption; "row"; no path; tree's grey `?` unexplained | Timing note, click path, three truthful captions |
| D6 | L | `02-…:124–130` | E2 order unstated; no UI path; SS-L4-03 caption generic | `-in-cluster` rows print first; verified Preview → EDIT → PREVIEW path; caption describes the DIFF block |
| D7 | M | `02-…:174` | E3 gave no timing — without the policy prod is still listed until the controller's pass | "Wait before you judge" (up to ~3 min) |
| D8 | L | `02-…:176–180` | SS-L4-10 caption generic | MANIFEST tab path; lines 48–50 vs the template's own `syncPolicy` |
| D9 | M | `02-…:186`, `190` | Hint 2 blamed only ordering; restore gave no timing | Hint 2 covers ordering and placement with a check command; restore note on re-creation at next pass |
| D10 | L | `02-…:196` | Takeaway did not say how `preserveResourcesOnDeletion` works | Finalizer removal, with a command to see it |
| D11 | M | `03-app-of-apps-and-trace-faults.md:36` | SS-L4-08 caption missed that children show no health | Caption points it out (sets up 5B) |
| **D12** | **H** | `03-…:38` | "cascade would delete all three children (and their workloads)" — false | Verified behavior: children removed, workloads orphaned; "a cascade stops at the first layer without a finalizer" |
| D13 | M | `03-…:44–57` | Trace loop printed 13–25 lines per child | `jsonpath` one-liner, real output, note on multi-namespace children |
| D14 | M | `03-…:100–117` | "generates zero Applications"; no timing; no expected output | "Changes no Application in that pass"; timing callout (78 s, up to ~3 min); real expected output |
| D15 | L | `03-…:120–122` | SS-L4-07 no path; caption vague | CONDITIONS click path; Degraded AppSet health; truthful caption |
| D16 | L | `03-…:132` | Non-strict preview "empty" namespace that "looks normal in a list" | Literal `<no value>` visible in NAMESPACE; exit 0 is the danger |
| **G-15** | L | `03-…:146–148` | "The error clears and all three generate again" | Revert command; confirm with preview; condition lags up to ~3 min; don't "fix it again" |
| **D17** | **H** | `03-…:158–166` | SS-L4-09 idea contradicted by the UI: the root's tree shows the broken child as Synced; "may still report"; no timing | Timing (60 s Git check; 6 s / 101 s); list-based figure and caption; "⚠️ The root's own page hides it completely" |
| D18 | L | `03-…:168` | Revert claim had no evidence | "within about a second" |
| D19 | L | `04-…:47` | Tree deletion "controlled by the finalizer" omitted the factory's two switches | Both patterns' deletion switches, tied to E3/E4 |
| D20 | L | `04-…:56` | Troubleshooting "`<no value>` and looks normal" | "Preview succeeds, but a field reads `<no value>`" |
| **D21** | M | `04-…:75–86` | 9.1 `grep storefront-` prints 5 rows | `grep 'argocd/storefront-'`, why, real expected output |
| **G-8** | M | `04-…:119–123` | Stretch 1 "re-run E5B, observe" shows no difference | Compare (a) non-rendering child vs (b) Pods that cannot start; `--hard-refresh`; cleanup |
| — | L | `04-…:124` | Stretch 2 said only "preview first" | "Preview only"; hint about strict templating |
| **G-9** | M | `04-…:125–129` | Stretch 3 "experimental / flapping" hypothesis | Predict → preview → apply → explain on a scratch `collision-test`; cleanup command; no answer given |
| — | L | `session-05/03-app-of-apps-and-choosing.md:62–64` | SS-S5-03 caption "cascading delete would follow these same edges downward"; spec said children have Synced/Healthy badges | Children show a sync check only; cascade removes child Applications, workloads stay (verified) |

README and stub re-read against the run: accurate, unchanged. Not edited, per instructions: other labs, Session 4, `seed-repos.sh`, capstone.

### Environment and harness

| ID | Sev | File:line (after edit) | Finding | Change | Proof |
|---|---|---|---|---|---|
| S1 | L | `scripts/screenshots/capture.mjs:172–182` | Monaco editor (AppSet Preview) ignores `fill()`; no key actions | New `{ press: "<key>" }` and `{ type: "<text>" }` actions | `node --check` OK; SS-L4-03 |
| S2 | M | `screenshot-manifest.yaml:776–793` | SS-L4-02 `.cluster-details` does not exist | Row click + `.white-box` (as SS-L2-04) | captured |
| S3 | M | `…:796–827` | SS-L4-03 route/selector nonexistent; no actions | Preview deep link; EDIT, delete selector line, PREVIEW, scroll; 1440×1400 | captured; live AppSet unchanged |
| S4 | M | `…:829–840` | SS-L4-04 `.applicationsets-list` does not exist | `.applications-tiles__item` | captured |
| S5 | M | `…:872–889` | SS-L4-07 `.applicationset-conditions` does not exist | CONDITIONS button click + conditions panel | captured |
| S6 | **H** | `…:905–919` | SS-L4-09 route (root tree) cannot show the child's error | `/applications?search=platform`, tile highlight | captured |
| S7 | M | `…:921–937` | SS-L4-10 `?tab=manifest` / `.application-manifest` wrong | Verified deep link, Monaco wait, 1440×1400 | captured |
| S8 | L | `…:749–760` | SS-S5-03 state note vague | Truthful state | captured |

Manifest parses (73 entries, no duplicate IDs). No shell script was edited, so no `bash -n` was needed. `reset-lab.sh`, `seed-repos.sh`, checkpoints: untouched.

### Instructor

- **Walkthrough** (Say / Do / Click / Expect / Answer key / Wrong turns / Wow / If it goes sideways format kept):
  - §0.1 rewritten: the leak is fixed, with a pre-class `grep -c` check.
  - §0.2: the 14-row verify block.
  - §0.4: rows marked fixed and re-verified, plus new E3/E4 rows.
  - E2: real row order.
  - E3: finalizer evidence, 2-minute controller pass, the verified "no policy" wrong turn, and restore timing.
  - E4: timing and messages; cascade result; trace command note.
  - E5A: 78 s condition, safe-to-project note, real non-strict output, 3-minute ticks.
  - E5B: 6 s / 101 s, the root-tree trap click path, 1 s revert.
  - §8: 22 rows, plus the verifier's policy blind spot and a manual check.
  - Stretch 1 table: `--hard-refresh`, 32 s, restart note. Stretch 3: re-verified output and cleanup. Debrief: "within a second".
- **Instructor README row 4** (`instructor/README.md:73`): rewritten as fixed, with the old-VM / client-side re-apply caveat and the confirmation command. Other rows untouched.

---

## 4. Carried-over defects and requested checks

| Item | Status before | Evidence this run | Status now |
|---|---|---|---|
| Missing SS-L4-01…10 | Missing; 5 of 10 manifest selectors/routes invalid | Harness + probes (Section 5) | **Fixed** — all captured, read, captions true |
| SS-S5-03 | Missing | Captured at `CP-lab-05` | **Fixed**; caption corrected |
| **G-8** | Present | Row 36 | **Fixed** (guide + walkthrough) |
| **G-9** | Present | Row 39 | **Fixed** |
| **G-14** | Present | Rows 6–7 | **Fixed** |
| **G-15** | Present | Rows 22, 27 (3-minute ticks 10:41:03 / 10:44:03 / 10:47:03) | **Fixed** |
| **G-16** | Guide already correct; walkthrough §0.2 stale (13 rows, "rows the guide omits") | Row 1 | **Fixed** (walkthrough) |
| **E5A credential leak** | README row 4 / walkthrough §0.1 said the token prints | Row 23: 0 / 0 counts; credential Secrets carry no annotation (`in-cluster` does, labels only) | **Fixed in the environment**; docs rewritten |
| Start-state changes from Lab 3 | — | `CP-lab-04` 14/14; dev/staging `6.15.0` (preview/apps healthy); project allowed all three destinations (all 3 apps synced) | Confirmed |

## 5. Screenshots captured

All captured with `node capture.mjs --only <ID>` (credentials inline from the files, never printed). Each was read after capture; `capture-log.md` rows are all `ok (viewport)`.

| ID | Moment | What the image shows (verified) |
|---|---|---|
| SS-L4-01 | `CP-lab-04` | Applications page empty state (the highlight has nothing visible to outline) |
| SS-L4-02 | `CP-lab-04` | Cluster detail: LABELS `cluster-role=workload region=lab`, APPLICATIONS 0, Successful |
| SS-L4-03 | E2 (before E3) | Preview tab after deleting the selector line; DIFF sub-tab; first added block `storefront-dev-in-cluster` → `https://kubernetes.default.svc` |
| SS-L4-04 | after E1 | One `storefront` tile, Healthy, Applications: 3 |
| SS-L4-05 | after E1 | AppSet node → 3 `application` nodes (grey `?` status), CONDITIONS 3 Info |
| SS-L4-06 | after E1 | Three storefront tiles Healthy/Synced; prod `storefront-1.0.0` |
| SS-L4-07 | E5A (after the controller tick) | "ApplicationSet conditions": 3 rows citing `map has no entry for key "namespace"` |
| SS-L4-08 | after E4 | Root Healthy/Synced → 3 children with sync check only |
| SS-L4-09 | E5B (before patch and fix) | Tiles: root Healthy/Synced; quotas Healthy/**Unknown**, path `quotas-typo` |
| SS-L4-10 | after E3 | MANIFEST tab lines 48–50: `preserveResourcesOnDeletion: true`, `applicationsSync: create-update` |
| SS-S5-03 | after `CP-lab-05` reset | Root Healthy/Synced (`4baad96`) → 3 children, sync check only |

SS-L4-03/04/05/07/10 keep their Alpha notes. SS-L4-03 is the exact requested UI state (edited selector, previewed, never saved), scripted reliably.

## 6. Clarification callouts (🧭 / ✅ / big picture)

All callouts, "in one line" summaries, take-away blocks, module takeaways, and the README big-picture table were kept and checked against the run. Most were accurate: every 🧭 callout, the README tables, the E1/E2/E4 take-aways, Part A/B one-liners, and the Module 1/3 takeaways. Corrected, in the same plain tone:

- **E3 take-away** "two switches, two layers" — true, but now says *how*: the policy removes the clean-up marker (finalizer), with a command to see it.
- **E6 take-away** "the finalizer controls it for the tree; `applicationsSync` for the factory" — incomplete; now names both switches in each pattern and points at E4's evidence.
- **E4 Notice** (not a callout, but the tree mental model) — the cascade claim was false; corrected.
- **Module 3 🧭 E5** "Part B's error is the same rendering failure you met in Lab 3" — verified (ComparisonError); kept.

No participant file gained an answer. The stretch 3 rewrite removed the old hypothesis without stating the result. Stretch 1's hint describes *how* to cause the two failures, not what the root does.

## 7. Reproducibility and fragility

- **ApplicationSet timing is tick-based.** Git-driven changes (E3, E5A break/fix) land on the controller's fixed 3-minute ticks, so the observed delay varies 0–180 s between groups. An ApplicationSet spec change is immediate. The guide now tells participants to confirm with the preview and not to re-fix.
- **App-of-Apps timing** depends on the 60 s Git check (6 s and 101 s observed).
- **Stretch 1** needs `--hard-refresh` before the HEALTH column appears, and `apply-argocd-config.sh` restarts Argo CD (21 s).
- **Alpha UI selectors** (SS-L4-03/04/05/07/10) must be re-verified on any version change; SS-L4-03 depends on Monaco keyboard behavior.

## 8. Open issues needing a human decision

1. **`reset-lab.sh CP-lab-05` took 6 min 46 s** (22/22 PASS), over the script's "under 3 minutes" target. Not diagnosed (output tail only); a likely suspect is cascade deletes plus the Argo CD re-apply. environment-engineer should time the steps on a VM.
2. **The `CP-lab-05` verifier does not check E3's policy.** A participant who skipped E3 still gets PASS. Consider a row for `.spec.syncPolicy.applicationsSync == create-update` (the checkpoint file does include it).
3. **`clean_workload_ns` does not delete ResourceQuota / LimitRange.** A `storefront-dev` quota was 2d17h old at `CP-lab-04`, where the namespace should be empty. Harmless for Lab 4 (the child re-adopts it). Add the kinds, or document.
4. **`CP-lab-04` skeleton comment** says "preview with `argocd appset create --dry-run`"; the guide teaches `argocd appset generate`. Both work (verified), but fixing the checkpoint file needs a re-seed of tags; left alone because `seed-repos.sh` is being edited.
5. **Stretch 1 needs a `platform-components` clone**, which no earlier guide asks for. The stretch says "in a clone of `platform-components`"; add the clone command if you want it copy-runnable.
6. **Host sleep** during E5B's fix: recovery time not re-measured (walkthrough keeps the earlier ~3 s).
7. **Not run:** Firefox on a VM; E1 "wrong context" wrong turns; E6 is a paper exercise (answer key checked against the verified behaviors, not "executed").
8. **Cross-lab (not edited):** Lab 5 inherits this state. `reset-lab.sh CP-lab-05` leaves storefront apps **without** finalizers (policy applied), and the root's children have none either. Any Lab 5 or capstone text that assumes a cascade removes storefront or platform workloads should be re-checked by those testers.

## 9. Retest requirements

- After any change to checkpoints or `reset-lab.sh`:
  - `CP-lab-04` verify (14 rows), then the E1 preview (zero rows unfilled, three filled);
  - `CP-lab-05` verify (22 rows);
  - the credential-annotation check (README row 4).
- On an Argo CD version change, re-check:
  - `-o wide` columns and sort order;
  - AppSet Preview EDIT/PREVIEW/DIFF and the CONDITIONS button (SS-L4-03/07);
  - the grey `?` in the AppSet tree;
  - the duplicate-name refusal;
  - `requeueAfter=3m0s`;
  - `preserveResourcesOnDeletion` finalizer removal;
  - root-tree child icons.
- On the next VM: E3 and E5A timing under load; SS-L4 click paths in Firefox; the reset runtime.

## 10. Final sandbox state

- **Checkpoint:** `reset-lab.sh CP-lab-05 --yes --local` → `PASS CP-lab-05 is in the expected state.` (22/22); a later `--verify-only` also PASS.
- **Argo CD:** seven Applications `Synced`/`Healthy`; only the `storefront` ApplicationSet (`collision-test` deleted); no stretch 1 health customization in `argocd-cm` (the remaining `ignoreResourceUpdates.argoproj.io_Application` key is a chart default).
- **Gitea `main`:** force-moved by the reset to `cp-lab-05` in every repo. platform-config clone at `4baad96 checkpoint CP-lab-05`, storefront-gitops clone at `9fb4f39`, both clean and level with `origin`. Stretch commits to `platform-components` were reverted, then superseded by the reset.
- **Participant clones** keep a local `credential.helper` pointing at this session's scratchpad script (harmless once the scratchpad is gone; `git config --unset credential.helper` if reused). The scratchpad `platform-components` clone is disposable.
- **Processes and shell:** no port-forward or watch processes; `COURSE_USER_HOME` unset; `~/argo-lab-env.sh` never sourced; EKS context never used. `argocd` CLI logged in as `admin` at `localhost:8443`.
- **Git:** nothing committed in the courseware repository.

### Files changed by this pass

- Participant: `courseware/day-2/lab-04/01-environment-and-preview.md`, `02-build-and-protect-the-factory.md`, `03-app-of-apps-and-trace-faults.md`, `04-showdown-and-wrap-up.md`; `courseware/day-2/session-05/03-app-of-apps-and-choosing.md` (SS-S5-03 caption and capture spec only)
- Instructor: `courseware/instructor/day-2/lab-04-build-and-troubleshoot-patterns-SOLUTION.md`; `courseware/instructor/README.md` (row 4 only)
- Harness: `courseware/environment/scripts/screenshots/capture.mjs` (press/type actions); `screenshot-manifest.yaml` (SS-L4-02, -03, -04, -07, -09, -10, SS-S5-03)
- Screenshots (new): `courseware/assets/screenshots/day-2/lab-04-01` … `lab-04-10`, `s05-03-root-app-tree.png`; `capture-log.md` (rows merged by the harness)
- This report: `courseware/reviews/lab-04-validation-2026-09-13.md`
