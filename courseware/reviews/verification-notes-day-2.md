# Verification Notes — Day 2 Concept Guides

**Status:** build-team artifact. Not participant-facing.

**Why this file exists.** The three Day 2 concept guides (`05`, `06`, `07`) each ended with a "Version and accuracy notes" section written in build-team language ("flagged for `lab-tester` … before final sign-off"). That mixes instructor/build content into participant files, which violates `standards/content-contract.md` ("No file mixes participant and instructor-only content") and `CLAUDE.md` ("Keep verification notes in review artifacts rather than cluttering participant-facing guides"). The sections were removed from the guides on 2026-09-12 and their **full substance is preserved below, unchanged in claim and qualification**, organized by guide.

**Scope of this move.** Nothing was deleted. Every claim, source, confirmation status, and open-verification item that lived in the three guides is recorded here. Downstream verification (`technical-source-check`, `lab-tester`, `course-reviewer`) should treat this file as the authoritative list of version-sensitive Day 2 claims.

**Course-wide pin:** Argo CD **`v3.5.2`**, Helm chart **`10.8.4`**, repo-server renders with **Helm v4.2.1**, lab Kubernetes is **k3s v1.35.8**. All UI paths, CLI flags, message shapes, and feature-maturity statements in Day 2 are written to those versions.

---

## 1. `05-applicationsets-and-app-of-apps.md`

Moved from the guide's former "Version and accuracy notes" section (previously at the end of the file, before the transition). Original framing: claims were checked against the `release-3.5` documentation; re-confirm against the live classroom instance before each delivery.

| # | Claim | Status as recorded | Follow-up owner |
|---|---|---|---|
| 05-V1 | **ApplicationSet web UI (list page, resource tree, Preview tab) is Alpha, since v3.5.0.** | **Confirmed** on the `release-3.5` docs ("Alpha Feature (Since v3.5.0)"; "Edits in the Preview tab are never saved"; preview requires create-ApplicationSet permission). | Because it is Alpha, screenshots **SS-S5-01** and **SS-S5-02** must be recaptured on any version change, and the CLI remains the taught path. |
| 05-V2 | **Progressive Syncs is Beta, since v3.3.0**, and **`RollingSync` forces auto-sync off on all generated Applications.** | **Confirmed** on the `release-3.5` docs ("Beta Feature (Since v3.3.0)"); the auto-sync-off behavior is confirmed in those same docs. | — |
| 05-V3 | **A stalled progressive-sync stage is promoted to `Healthy` by a timeout** (`applicationsetcontroller.default.application.progressing.timeout`, default **300** seconds). | **Open.** Reported from Progressive-Syncs documentation but **not re-read line by line** during authoring. | `technical-source-check` / `lab-tester` before final sign-off. The guide now states the behavior with a participant-facing caution to re-read it against their own version's documentation before relying on progressive sync in production. |
| 05-V4 | **`goTemplateOptions: ["missingkey=error"]` is opt-in, not the default** (kept off for backwards compatibility). | **Confirmed** on the `release-3.5` GoTemplate docs. | — |
| 05-V5 | **`argocd appset generate <file>`** (with `-o json\|yaml\|wide`) and **`argocd appset create --dry-run <file>`** both render without creating anything. | **Confirmed** on the `release-3.5` command reference. The **printed output shape** shown in the guide's Section 7 is *representative*. | Exact output shape is verified against the live environment in Lab 4. |
| 05-V6 | **Child-Application health is not assessed as part of a parent Application's health by default** (the basis of the Section 8 misconception "a root's `Healthy` means its children are healthy"). | **Open.** Long-standing Argo CD behavior; needs a one-line live confirmation against `v3.5.2`. | `lab-tester` before final sign-off. The guide now points participants at Lab 4, where they observe a healthy root above a degraded child. |

---

## 2. `06-security-multitenancy-governance.md`

Moved from the guide's former "Version and accuracy notes" section. Original framing: items marked *confirmed* were checked during authoring; the rest were flagged for `lab-tester` / `technical-source-check` before final sign-off.

| # | Claim | Status as recorded | Follow-up owner |
|---|---|---|---|
| 06-V1 | **`argocd admin settings rbac can <subject> <action> <resource> <object> --policy-file <csv>`** — the Section 7 command, its argument order, and the `Yes`/`No` output. | **Confirmed at v3.5.2.** Run against the course's `argocd` v3.5.2 client during authoring using the real `team-a` policy CSV. Argument shape matters: the resource *type* (`applications`) and the *object* (`team-a/team-a-guestbook`) are **separate** arguments; passing the object where the resource type belongs errors with "not a valid resource name." | Participants still confirm output on their own VM. **Addendum (2026-09-12, from `lab-05-validation.md`):** run against the live cluster rather than a file, the command requires `--namespace argocd`; supplying neither flag fails with `please provide exactly one of --policy-file or --namespace`. The guide's Section 7 now states this. |
| 06-V2 | **The AppProject destination-denial string.** Originally recorded as `... is not permitted in project '...'`, matching wording used in the Lab 3 guide and the environment's screenshot manifest, with exact rendering to be confirmed by `lab-tester` in Lab 5. | **Resolved and corrected 2026-09-12.** Live execution against v3.5.2 (`courseware/reviews/lab-05-validation.md`, fix 4) shows the real form is an **`InvalidSpecError`** condition reading: `application destination server '<server>' and namespace '<ns>' do not match any of the allowed destinations in project '<project>'` (single quotes). The searchable phrase is **`do not match any of the allowed destinations in project`**. Guide 06 §5.5 Case A, the V-22 diagram, Quick Check S6-QC1 item 2, the misconceptions section, the key takeaways, and the transition were all updated. | Closed for `06`. `lab-04`/`capstone` should be checked for the same stale string. |
| 06-V3 | **The Kubernetes `forbidden` string** naming `system:serviceaccount:argocd-access:argocd-manager` for a NetworkPolicy create. | **Confirmed 2026-09-12** by live execution (`lab-05-validation.md`: the Case B string is "exactly right"). Matches the real workload ServiceAccount (`argocd-manager` in `argocd-access`) and the environment's screenshot manifest. | — |
| 06-V4 | **Argo CD RBAC (fence 1) denial text.** | **Corrected 2026-09-12** (`lab-05-validation.md`, fix 6). At v3.5.2 the client can receive only the terse `permission denied`; the descriptive form (`permission denied: applications, <verb>, <project>/<app>, sub: <subject>, iat: …`) appears in the **`argocd-server` log**, and in the client's output when the subject can `get` the object but not perform the verb. Guide 06 no longer promises a descriptive client-visible RBAC message anywhere (V-22 diagram, S6-QC1 item 1, key takeaways). | Closed for `06`. |
| 06-V5 | **Fence-2 refusals and the "did a sync operation run?" heuristic.** | **Refined 2026-09-12** (`lab-05-validation.md`, fix 4). Applying an Application whose destination the project forbids creates no operation; however, pressing Sync on it *does* record an operation that ends instantly with `Phase: Error`, `Duration: 0s` and **no resource result rows**. The reliable tell is "nothing on the cluster was touched," not "no operation exists." Guide 06 keeps the routing question and adds this refinement in the V-22 debrief, §5.5 Case A, S6-QC1's rationale, the misconceptions section, and the takeaways. | Check `lab-04`, `lab-05`, and the capstone for the unrefined claim. |
| 06-V6 | **SSO is conceptual only in this course.** Dex is disabled and there is **no identity provider**; the local account `team-a-dev` stands in for an SSO group. No OIDC/IdP configuration is taught or demonstrated. | **Confirmed** (blueprint R-5). | — |
| 06-V7 | **Secret management (V-24).** Argo CD's documentation recommends destination-cluster secret management (Sealed Secrets, External Secrets Operator, Secrets Store CSI Driver, Vault-based operators, and others) over render-time injection, and stores rendered manifests in **Redis in plaintext**. | **Confirmed** via the operator-manual secret-management docs. Tool *categories* only; no tool is evaluated. | — |
| 06-V8 | **Sync windows** (SS-S6-03, Section 5.6): the AppProject sync-window fields (kind, schedule, duration, scope, `manualSync`) and the `argocd proj windows` CLI are documented. | **Open.** The **exact schedule syntax and CLI at v3.5.2** are not confirmed. The session only *describes* windows; no step depends on the syntax. | `technical-source-check` before any step depends on it (including the Lab 5 stretch challenge, which configures a deny window). |
| 06-V9 | **Sync using impersonation** (`AppProject.spec.destinationServiceAccounts`) — named once as a direction to investigate. | **Open / not confirmed.** Availability and maturity at v3.5.2 are not confirmed, and it is not a lab step. | `technical-source-check` if the guide ever promotes it beyond a named direction. The guide now also grounds the word "impersonation" so it is not read as an attack. |

---

## 3. `07-reliability-troubleshooting-lifecycle.md`

Moved from the guide's former Section 12, "Version and accuracy notes." Original framing: items marked *confirmed* were run against this course's own v3.5.2 client and cluster during authoring; the rest were flagged for `lab-tester` / `technical-source-check` before final sign-off.

| # | Claim | Status as recorded | Follow-up owner |
|---|---|---|---|
| 07-V1 | **`argocd admin export -n argocd`** (Section 9 Try It Yourself). | **Confirmed at v3.5.2.** Run against the course cluster during authoring: exit 0, a multi-document YAML file whose objects are grep-able by `kind:` (observed kinds `Secret`, `ConfigMap`, `AppProject`; `Application`/`ApplicationSet` appear when present). Exact counts vary by lab state. Export does **not** error when pointed at a namespace with no Argo CD objects. | — |
| 07-V2 | **The six evidence commands exist and behave as described at v3.5.2:** `argocd app get`, `argocd repo list`, `argocd app manifests <app> --source git\|live` (the `--source` flag is `one of: live\|git`, default `git`), `argocd app diff` (exit codes 0/1/2), `argocd app history`, `kubectl -n argocd logs`, `kubectl top pod -n argocd`. | **Confirmed.** All were run during authoring; the `kubectl top` output shown in Section 5 Step 5 is **real captured output**. | — |
| 07-V3 | **Controller sharding is by cluster**, with `ARGOCD_CONTROLLER_REPLICAS`, algorithms `legacy` / `round-robin` / `consistent-hashing`, and worker counts `--status-processors` (default 20) / `--operation-processors` (default 10). | **Open.** Documented for the HA install; the **default algorithm** and **dynamic-distribution defaults at v3.5** should be reconfirmed against the operator manual. | `technical-source-check`. The guide presents the shape (V-27) as the headline and explicitly marks the flags as "worth knowing but not worth memorizing." |
| 07-V4 | **Helm 4 rendering change on upgrade.** Argo CD 3.5 uses Helm 4 (reported as v4.2.1 in the 3.4→3.5 upgrade notes) as its only renderer; the `null`/nil coalescing change can alter rendered manifests with no Git change. | **Partially confirmed — present the pattern confidently, the exact patch provisionally.** The coalescing change is reported by users and tracked upstream (argo-cd issues **#29059 / #29068**) rather than stated in the official upgrade guide. It affects charts that rely on null-coalescing behavior, **not** every chart. This course's sample charts avoid null patterns so the classroom stays stable. | `technical-source-check`. |
| 07-V5 | **Metrics endpoints and names.** Component ports: application-controller `8082`, API server `8083`, repo-server `8084`; reconciliation-duration metric `argocd_app_reconcile`. | **Partially confirmed.** Ports and `argocd_app_reconcile` are documented; **other individual metric names** should be confirmed before any step depends on printing them. The course reads metrics via endpoint scrape and `kubectl top` only — there is no Prometheus/Grafana stack. | `technical-source-check`. |
| 07-V6 | **90-second repo-server exec timeout (`ARGOCD_EXEC_TIMEOUT`), `--parallelismlimit`, and the one-render-per-repo constraint** for generations that write into the local clone. | **Open.** Documented HA-tuning facts; the exact defaults at v3.5 should be reconfirmed against the operator manual before any *tuning* step relies on them. The guide uses them diagnostically only. | `technical-source-check`. |
| 07-V7 | **Tested-Kubernetes compatibility matrix.** | Teach the **policy** (roughly the last three or four Kubernetes minor versions, published per release). The confirmed per-release numbers come from the environment specification. | `course-reviewer` keeps guide and environment spec aligned. |

---

## 4. Open items at a glance

Items still needing confirmation before final sign-off:

- **05-V3** — progressive-sync stalled-stage timeout promotion (`technical-source-check` / `lab-tester`).
- **05-V6** — child-Application health not rolled up into parent health by default (`lab-tester`, one-line live check).
- **06-V8** — sync-window schedule syntax and `argocd proj windows` at v3.5.2 (needed before the Lab 5 stretch depends on it).
- **06-V9** — sync-using-impersonation availability/maturity at v3.5.2.
- **07-V3** — controller sharding defaults at v3.5.
- **07-V4** — Helm 4 null-coalescing change (upstream issues, not the official upgrade guide).
- **07-V5** — metric names beyond `argocd_app_reconcile`.
- **07-V6** — repo-server timeout/parallelism defaults at v3.5.

Items closed by live execution on 2026-09-12 (see `courseware/reviews/lab-05-validation.md`): **06-V2**, **06-V3**, **06-V4**, **06-V5**, and the `--namespace argocd` addendum to **06-V1**.
