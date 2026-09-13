# Engagement + Insight Pass — Intermediate Argo CD Operations

> **Scope:** a focused engagement/insight review (not a full rubric audit) of the six hands-on files (Labs 1–5 + Capstone), with quick-win notes on the seven concept guides.
> **Reviewed against:** `standards/pedagogy-rubric.md`, `courseware/00-course-blueprint.md` §10, `courseware/01-insight-map.md`.
> **Headline:** the courseware is exceptionally complete. Nearly every insight-map item is already surfaced, and the labs already use Predict-Before-You-Sync, Break-It/Fix-It, Root-Cause Detective, Guardrail-Bypass, and Pattern Showdown well. The findings below are the *remaining* gaps — a few high-value ones, plus polish. This is enhancement, not repair.

## Apply first — the 12 highest-impact changes (ordered by value)

| # | File · Section | Label | Concrete change | Insight / pattern |
|---|---|---|---|---|
| 1 | Lab 2 · §11 Stretch | **ADD STRETCH** | With `storefront-dev` registered, briefly interrupt the workload connection, **predict `OutOfSync`/`Degraded`/`Unknown`**, observe **`Unknown`**, restore, watch it recover. | **I-L2-06**. Rehearses **Capstone fault #5** a day early; teaches the most-misdiagnosed status. Predict-Before-You-Sync + before/after. |
| 2 | Lab 4 · E5 Part A | **ADD PRACTICE** | Run `missingkey=error` **both ways**: first *remove* it and see the silently-wrong `<no value>` app look normal, then restore strictness and see the loud refusal. | **I-L4-04**. Only the strict path is currently *felt*; "safer config fails more, sooner, louder" needs the contrast. |
| 3 | Lab 3 · E4 debrief | **ADD ACTIVITY** | Make it a decision scenario: *"2 a.m., app needs 10 replicas, self-heal is on — what do you do?"* Debrief self-heal as a policy about who wins ties. | **I-L3-02**. Converts flat recall into on-call judgement. |
| 4 | Lab 5 · §9/§10 close | **ADD ACTIVITY** | Rank the four denial messages by self-serviceability; improve the worst (terse `permission denied`). | **I-L5-07**. Rehearses the Capstone's "guardrail that prevents recurrence" step. |
| 5 | Lab 4 · E4 | **ADD PREDICTION** | Before applying `platform-root`, predict how many children appear and what determines the count (files in `apps/`). | **I-S5-01 / I-L4-02** applied to the family tree. |
| 6 | Lab 1 · E1 | **ADD INSIGHT** | Add: *"every dependency you circle is a future incident — this exact list is what the Capstone breaks."* | **I-L1-01**. |
| 7 | Lab 4 · E6 | **ADD ACTIVITY** | Add a *"what does a single typo cost?"* row forcing blast-radius + deletion semantics recalled together. | **I-L4-07(4)**. Pattern Showdown scored on operations. |
| 8 | Lab 1 · E1 | **ADD PREDICTION** | Predict the dependency count (~8) before listing. | Predict-Before-You-Sync on inventory. |
| 9 | Lab 5 · E5 Part B | **ADD INSIGHT** | Pull "deletion danger lives in the delete **path**, not the object" up from Key Takeaways into the exercise body. | **I-L5-06 / capstone deletion reasoning**. |
| 10 | Guide 04 · §7 | **STRENGTHEN CHECK** | Promote the existing Tuesday/forty-apps upgrade narrative into a Quick Check so the "aha" is tested, not told. | **I-S4-02**. |
| 11 | Lab 2 · E3 | **ADD INSIGHT** | Name the 401-vs-403 / Argo-vs-Kubernetes payoff that Lab 5 + Capstone grade. | **I-S3-03 / I-S6-02**. |
| 12 | Capstone · P4 close | **ADD INSIGHT** | Add the "end where you started" beat: re-ask Lab 1's two questions across faults; one idea at increasing depth. | **I-CAP-08**. |

## Full findings by file
Value tags: **[H]** high · **[M]** moderate · **[L]** polish.

### Lab 1 — strong (three windows, `OutOfSync` pause, delete-a-Pod, steps-1–4 close all present)
- §7 E1 · **ADD PREDICTION [M]** — predict dependency count (#8).
- §7 E1 · **ADD INSIGHT [M]** — "each circle is a future incident" (#6, I-L1-01).
- §7 E4 · **STRENGTHEN CHECK [L]** — table is recall-leaning; already saved by the "UI is down" transfer question. Optionally add a 15-sec "only `kubectl` — is this Argo CD or Kubernetes?" micro-scenario. *I-L1-03.*

### Lab 2 — strong (address book, predict-which-cluster, `127.0.0.1` story, `OutOfSync`+`Missing`-is-correct)
- §11 Stretch · **ADD STRETCH [H]** — disconnect→`Unknown` (#1, I-L2-06). Needs a reversible interrupt mechanism → flag `environment-engineer`; if none, frame as predict-then-observe rather than cut.
- §7 E3 · **ADD INSIGHT [M]** — 401-vs-403 forward payoff (#11).
- §7 E5 · **KEEP** — good Root-Cause Detective.

### Lab 3 — very strong (three-act drift, break-two-ways, revert-vs-roll-forward; `randAlphaNum` honestly cut)
- §7 E4 · **ADD ACTIVITY [H]** — 2 a.m. decision scenario (#3, I-L3-02).
- §7 E3 · **KEEP** — cleanest sync-vs-health proof in the course.
- §11 Stretch · **KEEP**.

### Lab 4 — very strong (preview→count→apply, predict-names, zero-is-valid, ownership tracing, showdown)
- §7 E5A · **ADD PRACTICE [H]** — `missingkey=error` both ways (#2, I-L4-04).
- §7 E4 · **ADD PREDICTION [M]** — predict child count (#5).
- §7 E6 · **ADD ACTIVITY [M]** — "cost of one typo" row (#7).
- §11 Stretch #3 · **KEEP** — name-collision correctly hedged as experimental.

### Lab 5 — extremely thorough (Guardrail-Bypass, four fences, Argo-vs-K8s denial, `rbac can` unit test, `<none>` surprise). Risk is density, not engagement.
- §9/§10 close · **ADD ACTIVITY [H]** — rank denial messages (#4, I-L5-07).
- §7 E5B · **ADD INSIGHT [M]** — delete-path one-liner into exercise body (#9).
- §7 · **SHORTEN (hedge) [L]** — if the clock slips, move `.status.operationState.syncResult.resources` mechanics to a collapsible aside.

### Capstone — exceptionally complete (narrative, no-change triage, one diagnostic action, masking question, fix-hiding-faults-first, prevention catalogue). Model file.
- P4 close · **ADD INSIGHT [M]** — "end where you started" retrieval beat (#12, I-CAP-08).
- P0/P1/P2 · **KEEP**.

## Concept guides — quick wins only (all already use Predict-first, prediction Quick Checks, Try-It-Yourself, named misconceptions)
- Guide 04 §7 · **STRENGTHEN CHECK [M]** — Tuesday/forty-apps as a Quick Check (#10, I-S4-02).
- Guide 05 §8 · **ADD INSIGHT [L]** — confirm close lands on "leverage vs legibility" (I-S5-09), not "ApplicationSets are the advanced one."
- Guide 06 §8 · **ADD INSIGHT [L]** — confirm the thesis line "without guardrails, the audit trail is a story about what people usually did" (I-S6-07).
- Guide 07 §7 · **KEEP** — "walk the pipeline, stop at the first station that lies" is the strongest sticky/visual content in the concept set.

## Missing reinforcement opportunities
- **`Unknown` = "Argo CD went blind"** is defined and named for the Capstone but never observed in a safe, reversible setting first — the only anchor status without a rehearsal (Apply-first #1 closes it).
- **"Safer config fails louder"** (`missingkey=error`) is stated three times but experienced only in its safe form (Apply-first #2).

## Missing misconceptions
None. All six anchor misconceptions are broken explicitly, most more than once.

## Pacing corrections
- **Lab 5** is the densest engagement-positive file — watch the required-path clock; use the SHORTEN hedge before cutting any bypass attempt.
- All Apply-first items are additive-but-cheap and fit existing timeboxes, except #1 and #2 (~3–5 min each), which belong in the optional/stretch budget, not the required path.

## Highest-priority revisions before delivery
1. Lab 2 disconnect→`Unknown` stretch (#1) — closes the one unrehearsed anchor status.
2. Lab 4 E5A `missingkey=error` both ways (#2) — makes the sharpest counterintuitive lesson *felt*.
3. Lab 3 & Lab 5 debrief activities (#3, #4) — convert two flat "state the rule" moments into judgement/design activities that rehearse Capstone steps.
