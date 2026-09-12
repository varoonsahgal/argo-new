# Pedagogy Review — Day 2

## 1. Executive verdict

Day 2's content quality is exceptional: the three-fence model (06), the factory/family-tree metaphor (05), and the six-step pipeline (07) are among the best-designed teaching devices in the whole course, and retrieval/misconception coverage is comprehensive and explicit throughout. The single systemic defect is **pacing**: in five of six files, the internal time budget that `00-course-blueprint.md` §5.2 assigns to topics/exercises *sums to exactly the outline minutes*, leaving zero minutes for required content-contract sections (Why this matters, vocabulary, mental-model debrief, Quick Check discussion, misconceptions, takeaways, guided-walkthrough narrative) that the actual files still contain in full. A second, recurring defect is a content-contract violation: three concept guides (05, 06, 07) end with a "Version and accuracy notes" section written in build-team language ("flagged for `lab-tester`... before final sign-off") that does not belong in a participant-facing file. No file is broken; all six need trimming, one exercise pair needs re-scenario-ing for genuine transfer, and the version-notes sections need to move out.

## 2. Rubric scores (1–5, per `standards/pedagogy-rubric.md`)

| Dimension | Score | Citation for anything below 4 |
|---|---|---|
| Progression | 5 | — |
| Cognitive load and beginner clarity | 4 | `05` lines 11, 173, 505 ("just"/"simply"); `05`/`06`/`07` version-notes sections mix instructor content into participant files |
| Active learning | 5 | — |
| Retrieval and reinforcement | 5 | — |
| Transfer | 4 | `lab-05` Exercises 3A and 4B repeat `06` §5.5's exact scenario, destination, and file path |
| Misconceptions addressed | 5 | — |
| Assessment alignment | 4 | Same `lab-05` E3/E4 overlap weakens what E4's checkpoint can actually prove |
| Pacing | 2 | See §5 for all six files; `07`'s own stated time box (30+25+20=75 min) excludes Sections 1, 3, 8, 10, 11 |
| Engagement and visual support | 5 | — |

## 3. Per-file verdict

| File | Verdict |
|---|---|
| `05-applicationsets-and-app-of-apps.md` | Ready with changes |
| `lab-04-build-and-troubleshoot-patterns.md` | Ready with changes |
| `06-security-multitenancy-governance.md` | Ready with changes |
| `lab-05-enforce-platform-guardrails.md` | Ready with changes |
| `07-reliability-troubleshooting-lifecycle.md` | Ready with changes |
| `capstone-restore-platform.md` | Ready with changes |

## 4. Findings by file

### `05-applicationsets-and-app-of-apps.md`

**1. SHORTEN — "Version and accuracy notes" (lines 665–674).** Quote: *"flagged for live re-confirmation... note them for the reviewer."* This is build-team verification tracking, not participant content — it violates `content-contract.md`'s universal rule "No file mixes participant and instructor-only content" and CLAUDE.md's "Keep verification notes in review artifacts rather than cluttering participant-facing guides." Change: delete the section from the guide; move its contents to a build/verification log. Priority: High. Saves ~2–3 min.

**2. SHORTEN — overall density vs. 60-min budget.** The blueprint's own internal accounting for this file (§5.2 row 8: 8+12+6+5+5+6+3+10+3+2 = 60) already spends the *entire* session on Sections 5.1–5.11 alone, leaving nothing for Why this matters, the mental model, 14 vocabulary terms, three full Predict-first visuals, and four misconceptions — all of which still exist in the file. Change: trim the vocabulary list (§3) from 14 to ~8 essential terms before Lab 4 — fold `merge`, `dry-run/preview`, and `progressive sync` into one-line glosses inside their own boxed/table treatments rather than separate full entries — and cut one "what to notice" point from each of V-19/V-20/V-21 (keep two, not three). Priority: High. Saves ~8–10 min.

**3. CLARIFY — banned phrasing.** Quote (S5-QC3 answer, line 505): *"let teams add an environment simply by adding a folder."* Quote (line 11): *"Both patterns are just new ways of writing Applications."* Rewrite: "...add an environment by adding a folder" and "Both patterns are new ways of writing Applications — not a new deployment mechanism." Priority: Low. 0 min.

**4. CLARIFY — undefined shorthand.** Line 452's diagram uses "the AppSet" but §3's vocabulary entry only ever writes "ApplicationSet" in full — the abbreviation is never established here, yet `lab-04` and the capstone both introduce "ApplicationSet (AppSet)" as if fresh. Change: add "(often abbreviated **AppSet**)" to the ApplicationSet vocabulary entry in §3. Priority: Low. 0 min.

**5. KEEP — V-19/V-20/V-21.** Predict-first diagrams with numbered debriefs are exemplary; do not restructure.

### `lab-04-build-and-troubleshoot-patterns.md`

**1. SHORTEN — exercise time sums to exactly 75 minutes.** Blueprint §5.2 row 9 (3+5+15+8+8+10+14+10+2 = 75) allocates zero minutes to Sections 1–4 (Why this matters, objectives, prerequisites, the factory/family-tree mental-model recap with a mermaid diagram), which span ~100 lines participants must still read. Change: trim Exercise 1 from 15 to 12 minutes (three of its five TODOs are direct copies of values already shown in the guided preview walkthrough in §6) and explicitly reserve 5 minutes for Sections 1–4 in the printed time table. Priority: High. Nets ~5 min.

**2. CLARIFY — Exercise 6 lacks a filled example cell.** Unlike E1–E5, which each show "the shape of a correct result," E6's comparison grid (line 503) gives only a prose description of what "correct" looks like, no worked cell. Change: add one filled example row, e.g., "**Files touched** — ApplicationSet: 1 (remove `envs/staging/config.yaml`) / App-of-Apps: 1 (delete `apps/storefront-staging.yaml`)" so participants calibrate depth before writing the rest. Priority: Medium. 0 min.

**3. KEEP — Exercise 5 Parts A/B.** These use concrete faults (missing `namespace` key, broken `platform-quotas` path) that are *not* identical to `05`'s abstract examples — genuine transfer. Do not alter.

**4. KEEP — mermaid dual-pattern diagram (§4).** Factory and family-tree drawn side by side is an effective retrieval device; keep as-is.

### `06-security-multitenancy-governance.md`

**1. MOVE — "Version and accuracy notes" (lines 522–533).** Same contract violation as `05` Finding 1, same fix: remove from the participant guide, keep the verification content in a build artifact. Priority: High. Saves ~2 min.

**2. SHORTEN — 45-minute budget already fully spent internally.** Blueprint §5.2 row 10 sums to exactly 45 (8+7+6+3+4+6+4+4+3), leaving nothing for Why this matters, 15 vocabulary terms (more than `05`'s 14, for a 15-minute-shorter session), three Quick Checks with multi-paragraph rationale, and four misconceptions. This file is the tightest ratio in Day 2 (538 lines / 45 min). Change: collapse §5.6's two governance-features paragraphs (API tokens; deployment windows) into a single two-row reference table — both are already recapped as Lab 5 stretch content — and move three of the least load-bearing vocabulary entries (`CSV`, the full `JWT project token` prose, `SCM`) into one-line glosses inside a table rather than standalone entries. Priority: High. Saves ~6–8 min.

**3. CLARIFY — "impersonation" introduced without grounding (§5.4).** Quote: *"Argo CD documents an advanced 'sync using impersonation' feature."* A beginner meeting "impersonation" in a security section could easily read it as an attack, not a feature. Change: add "('impersonation' here means Argo CD deliberately acts through a narrower, destination-specific ServiceAccount — not an attacker impersonating anyone)." Priority: Low. 0 min.

**4. KEEP — V-22/V-23/V-24.** The three-fence model with its "did a sync operation run?" diagnostic question is the strongest single teaching device in Day 2. Do not restructure.

### `lab-05-enforce-platform-guardrails.md`

**1. CLARIFY (Transfer) — Exercises 3A and 4B repeat `06`'s worked example verbatim.** `06` §5.5 "Case A" already walks a `team-a` Application pointed at `storefront-prod`, with the exact refusal text; "Case B" already walks the exact `attempts/network-policy/netpol.yaml` file in namespace `team-a`, with the exact `forbidden` text. `lab-05` Exercise 3 Part A repeats the identical destination (`storefront-prod`); Exercise 4 Part B repeats the identical file path and namespace. A participant can pattern-match from memory rather than diagnose, which weakens exactly the checkpoint this lab is built around (outline bullet L5.4). Change: vary the concrete scenario while keeping the lesson — e.g., have Part A target `platform-system` instead of `storefront-prod`, and have Part B attempt the `ResourceQuota` denied-by-omission from the AppProject spec table (§ Exercise 1's spec table already denies it) instead of reusing the NetworkPolicy file. This needs a small change to the staged `team-a-apps` repo — flag as a dependency for `lab-engineer`/`environment-engineer`. Priority: High (assessment validity of the lab's centerpiece). 0 min added.

**2. SHORTEN — exercise time sums to exactly 45 minutes.** Blueprint §5.2 row 11 (2+10+5+8+12+6+2 = 45) leaves nothing for Sections 1–6 (Why this matters, objectives, prerequisites, mental-model recap with a mermaid diagram, environment check, and the two-mechanism guided walkthrough in §6), which together span ~165 lines (28% of the file). Change: trim Exercise 1 from 10 to 8 minutes (Part A is a spec-table lookup) and Exercise 3 from 8 to 6 (both sub-parts are copy-and-edit-one-field, per the guide's own Hint 1), and add an explicit "Sections 1–6 reading: ~5 min" line to the file's own header time note, the way `07` does. Priority: High. Nets ~5 min.

**3. KEEP — the Guardrail-Bypass-Attempt framing and the Predicted/Observed/Match checkpoint table (§9).** This is genuinely diagnostic, self-checkable, and reused consistently across E3–E5. Do not alter.

### `07-reliability-troubleshooting-lifecycle.md`

**1. SHORTEN — the file's own stated time budget contradicts its own required sections.** The header box states "Spend about 30 minutes... 25 minutes... 20 minutes" = 75, covering only Sections 2/4/5, 6, and 7. It allocates **zero** minutes to Section 1 (Why this matters, ~500 words), Section 3 (20 vocabulary terms — the longest list in Day 2), Section 8 (four Quick Checks with long multi-paragraph rationale), and Sections 10–11 (four misconceptions, takeaways). This is the single clearest, most self-evident pacing defect in Day 2. Change: the guide already flags §7.4 (internal fork) as "designed to be compressed to a three-minute discussion" — go further and make it a pre-read handout, not walked live, and cut the 20-term vocabulary list to ~13 by folding `OOMKilled`, `JSON/YAML`, and `SLA` into one-line inline glosses at first use rather than standalone entries (none of the three is conceptually hard enough to need a full entry). Priority: High. Saves ~8–10 min; the file will still likely need 90 min in practice — flag this honestly to the instructor rather than silently compressing further.

**2. MOVE — "Version and accuracy notes" (lines 658–668).** Third occurrence of the same violation as `05` and `06`; treat as one systemic fix across all three files. Priority: High. Saves ~2–3 min.

**3. CLARIFY — dense unexplained example (§6.3).** Quote: *"if generating manifests needs to modify files in the local clone (as `helm dependency build` does)."* A beginner may not know what that command does. Change: add "(`helm dependency build` downloads a chart's sub-charts into its local `charts/` folder before rendering — a file-writing step, not a read)." Priority: Low. 0 min.

**4. KEEP — V-25 and the worked incident (§5).** The six-station pipeline diagram with a per-step evidence command, plus a deliberately non-capstone root cause so nothing is spoiled, is the best-designed single unit in the course. Do not alter.

### `capstone-restore-platform.md`

**1. CLARIFY — `git worktree add`/`remove` used without grounding (§6.3.1).** The outline's Git prerequisite covers clone/commit/branches/PRs/history only; `worktree` is materially more advanced and untaught anywhere else in the course. Change: add one clause per the "inline refreshers, not assumptions" rule: "(`git worktree add <path> <ref>` creates a second, temporary checkout of the same repository at a different commit, so you can render an old revision without disturbing your main clone)." Priority: Medium. 0 min; prevents a stalled participant.

**2. CLARIFY/ADD PRACTICE — Phase P4's 10 minutes cannot produce 7 reflection blocks (9 fields each) from nothing, and the guide only prompts a stub for repairs *verified* during P2, not for parked/unresolved rows the completion bar explicitly permits. Change: add one line to the P2 pacing checkpoints (0:40/0:55/1:10): "for any row you park or cannot resolve, still write its two-line stub (layer + evidence) before moving on — P4 will not have time to produce these from nothing." Priority: Medium. Saves ~2–3 min of P4 time pressure.

**3. CLARIFY — template/exercise row-count mismatch.** The `incident-log.md` heredoc (§5.4) pre-populates only one triage row (`S1`), while §7 Phase P1 shows an eight-row grid (`S1`–`S8`). Change: make the heredoc's table match the eight-row placeholder, or add "(add rows as needed)." Priority: Low. 0 min.

**4. KEEP — the masking-question framework (§4.3), the six-layer sorting scheme kept distinct from repair order, and the deliberately unhighlighted incident-start screenshot (SS-CAP-01, explicitly "no highlight... participants must read the screen themselves").** These are the correct diagnostic design for a G3 capstone and match the outline's own description. Do not alter.

## 5. Cross-file section

**Progression.** Clean throughout: Application (Day 1) before ApplicationSet (05); labels/selectors grounded in `05` before `lab-04` uses them; AppProject introduced lightly in Day 1 `lab-02` before becoming a security boundary in `06`; sync-vs-health (Day 1) resurfaces correctly in `lab-04` (root Healthy/child Degraded) and the capstone; the six-step method is seeded across every earlier lab before `07` names it, then the capstone applies it. No concept is used before it is taught.

**Terminology and running scenario.** Storefront/podinfo, team-a, `platform-root`/`platform-quotas`/`platform-netpol`/`platform-agent`, `argocd-manager` ServiceAccount, and cluster names (`workload`/`in-cluster`) are used identically across all six files — no drift found. The one inconsistency is the "AppSet" abbreviation (§4, `05` Finding 4): introduced informally in `05`'s diagram, then redefined from scratch in `lab-04` and the capstone as though new.

**Retrieval.** Excellent and explicit by design: `lab-04`'s mental-model recap explicitly ties back to `05`'s claims; `06` opens by naming `05`'s leverage/blast-radius idea as the reason governance matters; `lab-05`'s prerequisites section quotes `06`'s central claim verbatim before using it; the capstone's §3 table and §4.4 "Four habits you already own" are a deliberate, comprehensive retrieval pass across every prior guide and lab. This is a course-level strength.

**Day 2 timing totals.** The outline total (180 concept + 210 lab = 390 min) is preserved at the macro level. The problem is internal: for `05`, `06`, `07`, `lab-04`, and `lab-05`, the blueprint's own per-topic or per-exercise minute allocations (§5.2, rows 8–11) sum to *exactly* the outline's minutes for that file, systematically excluding the required content-contract sections (Why this matters, vocabulary, mental-model debrief, Quick Check discussion, misconceptions, takeaways, guided-walkthrough narrative) that the delivered files still fully contain. Concretely: `05` needs ~8–10 more minutes than budgeted or must shed that much; `06` needs ~6–8; `07`'s own stated 75-minute box excludes five of eleven sections outright; `lab-04` needs ~5 more; `lab-05` needs ~5 more. The capstone is the one exception — its P0–P4 structure already reserves reading time deliberately outside the clock and includes an explicit minimum-completion bar.

## 6. Missing reinforcement opportunities

- The "OutOfSync does not mean broken" misconception (taught Day 1) is never explicitly re-stated in `05` even though generator fan-out (V-19) is the moment it matters most (six simultaneously-OutOfSync apps mid-rollout look alarming but are not broken). One added sentence in §5.1 would close this.
- `07`'s "evidence before change" rule is not explicitly retrieved inside `lab-04`'s or `lab-05`'s troubleshooting tables (both predate `07`), even though both labs are exactly rehearsing that discipline. A one-line forward-reference ("you are practicing the rule Guide 07 will name") would strengthen the through-line.

## 7. Missing misconceptions

- **"An AppProject with an empty `clusterResourceWhitelist` is just unset/default"** — `06` correctly distinguishes empty-means-deny for `clusterResourceWhitelist`, but this exact trap (empty list ≠ permissive) is not listed in either file's "Common misconceptions" section, only mentioned in passing prose (`06` §5.1). Promote it to a named misconception.
- **"A `create-update` ApplicationSet policy protects against the App-of-Apps deletion problem too"** — `05` and `lab-04` are careful to keep the two protection mechanisms (ApplicationSet `applicationsSync` vs. App-of-Apps finalizers) distinct, but no file explicitly warns that conflating them is a likely error when someone combines both patterns (the decision table's own last row). Worth a named misconception in `05` §8.

## 8. Pacing corrections

1. Remove the three "Version and accuracy notes" sections from `05`, `06`, `07` entirely — this alone recovers ~6–8 minutes across the day and fixes a contract violation.
2. `05`: cut vocabulary 14→8 terms, one "what to notice" point per visual. Saves 8–10 min.
3. `06`: collapse §5.6 to a table, compress three vocabulary entries. Saves 6–8 min.
4. `07`: pre-read the internal-fork checklist, trim vocabulary 20→13. Saves 8–10 min (still likely needs slightly more than 75 min — flag to instructor rather than cut further).
5. `lab-04`: trim Exercise 1 by 3 min, reserve 5 min explicitly for Sections 1–4.
6. `lab-05`: trim Exercises 1 and 3 by a combined 4 min, reserve 5 min explicitly for Sections 1–6.
7. Capstone: no net time change needed; add the P2 stub-writing reminder to protect P4.

## 9. Highest-priority revisions before delivery

1. Delete the "Version and accuracy notes" sections from `05`, `06`, and `07`; relocate their content to a build/verification artifact. (Contract violation, all three files.)
2. Re-scenario `lab-05` Exercises 3A and 4B so they no longer duplicate `06` §5.5's exact destination and file path. (Transfer/assessment validity.)
3. Rebalance `07`'s stated time budget — either compress vocabulary/fork-checklist as specified, or tell instructors honestly it needs ~90 minutes.
4. Rebalance `05`'s vocabulary and visual debriefs to fit inside its own already-fully-allocated 60-minute internal budget.
5. Rebalance `06`'s vocabulary and §5.6 governance-features prose into tables.
6. Add explicit reading-time line items to `lab-04` and `lab-05`'s header time boxes (currently only exercise time is itemized).
7. Fix the two banned-phrasing instances in `05` (lines 11, 505).
8. Ground `git worktree` in the capstone's evidence toolbox with one inline clause.
9. Add the P2 "write the stub even if parked" reminder to the capstone so P4 is executable in 10 minutes.
10. Add "AppSet" as a defined shorthand in `05` §3 so `lab-04`/capstone aren't re-deriving it.

---

## Orchestrator triage (2026-09-12)

Recorded by the lead orchestrator before dispatching revisions. Findings are accepted unless noted.

**Accepted as written:** all `05` findings; all `lab-04` findings; `06` findings 1, 2, 3; `lab-05` findings 2 and 3; all `07` findings except the "pre-read handout" mechanism (see below); all capstone findings; every item in §6 and §7.

**Modified — `lab-05` finding 1 (duplication of `06` §5.5).** The duplication is real and worth fixing, but the proposed remedy is mechanically wrong and must not be implemented as written. Exercise 4 Part B must be a *Kubernetes* denial: an object the AppProject **permits** and Argo CD RBAC **permits**, which the workload-cluster ServiceAccount is nonetheless forbidden to create. Blueprint §8.7.1 designs exactly one such object for namespace `team-a` — NetworkPolicy — because the `argocd-deployer-team` Role omits it while the AppProject allows it. `ResourceQuota` is denied at the **AppProject** layer (blueprint §7.3, Lab 5 E1 spec table), so substituting it would collapse the very contrast the exercise exists to teach, turning a three-fence lesson into two copies of fence 2. Decision: keep Lab 5's objects and destinations unchanged, and instead de-duplicate from the other side — rewrite `06` §5.5 Cases A and B to walk a *different* tenant, destination, and file path (illustrative, not the staged lab artifacts) so the lab remains a genuine diagnosis rather than recall. This also avoids changing the `team-a-apps` seed repo and avoids invalidating Lab 5 execution validation already in progress.

**Modified — `07` finding 1 (mechanism only).** Compressing §7.4 and trimming vocabulary 20→13 are accepted. Converting it to a "pre-read handout" is not: CLAUDE.md and the blueprint's file plan allow no artifact besides the one participant file per session, so a handout would be a new deliverable type. Implement instead as an in-file clearly-marked optional/compressible block, and state the honest timing risk in the instructor-facing timing note rather than silently cramming.

**Deferred, not rejected:** the pacing findings recommend trimming content that the outline requires be covered. Trims are limited to *presentation* (vocabulary folded into inline glosses at first use, prose collapsed into reference tables, duplicate "what to notice" points), never removal of an outline topic. Where a file still cannot fit its minutes after presentation trims, the overflow is reported as an explicit instructor timing note plus a blueprint §5.3-style recommendation — not a silent cut.
