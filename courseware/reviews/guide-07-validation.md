# Guide 07 — execution validation record

**Guide:** `courseware/day-2/07-reliability-troubleshooting-lifecycle.md`
(Day 2 · Session 7 · concept guide · ~75 min)

**Validated by:** `lab-tester`
**Date:** 2026-09-12
**Environment:** local two-cluster build-machine sandbox (`k3d-mgmt` + `k3d-workload` + `lab-gitea`), started from a verified `CP-capstone` checkpoint. **Not** a live classroom VM — see "Environment-parity notes" at the end.

**Scope of this pass:** verify every command the guide tells a participant to run, replace the three placeholder ("Representative") outputs with real captured ones, capture the guide's two missing screenshots, and reconcile the two screenshot-manifest entries. Capstone faults were **not** injected or reverted at any point; `inject-capstone-faults.sh status` reported `clean` for F1–F7 before and after.

---

## 1. Tool and platform versions used

| Tool | Version |
|---|---|
| `kubectl` client | `v1.35.8` (Kustomize `v5.7.1`) |
| Kubernetes (both clusters) | k3s `v1.35.8` |
| `argocd` CLI | `v3.5.2+e258ee2.dirty` (GitTag `v3.5.2`) |
| Argo CD server (`/api/version`) | `v3.5.2` |
| `helm` | `v4.2.1` |
| Node (screenshot harness) | `v20.19.6` |
| Gitea | `gitea/gitea:1.27.3-rootless` |

These match the versions the guide pins in its header (Argo CD `v3.5.2`, Helm `v4.2.1`, k3s `v1.35.8`). No version-drift defects were found; every discrepancy below is a guide defect, not a tool change.

---

## 2. Commands executed, with results

Every fenced `bash` block in the guide was run. "As printed" means the command in the guide *before* this pass.

| # | Guide location | Command as printed | Result | Action |
|---|---|---|---|---|
| 1 | §5 step 1 | `argocd app get storefront-dev-workload` | **PASS** (runs) — but the sample output was fictional | Replaced with real output (healthy and failing) |
| 2 | §5 step 1 | `git ls-remote <repo> main` | **PASS** (runs) — repo URL in the guide did not exist | Replaced URL and both outputs |
| 3 | §5 step 2 | `argocd repo list` | **FAIL as evidence** — prints cached `Successful` during a live outage | Changed to `argocd repo list --refresh hard`; added the cache trap as a teaching point |
| 4 | §5 step 2 | `argocd app manifests <app> --source git` | **FAIL as printed** — does not emit `FATA`; exits `0` and prints `--- null` x3 | Replaced output and narration |
| 5 | §5 step 3 | `argocd app diff <app>` + `echo "exit code: $?"` | **FAIL as narrated** — exit code is **1**, not **2** | Rewrote step 3 around the real (and more dangerous) result |
| 6 | §5 step 4 | `kubectl -n storefront-dev get events …` | **FAIL** — returns `No resources found in storefront-dev namespace.` on the default (`k3d-mgmt`) context | Added `--context k3d-workload`; added a `get pods` line and real output |
| 7 | §5 step 5 | `kubectl -n argocd logs deploy/argocd-repo-server --tail=20` | **PASS** | Added `--context k3d-mgmt`; added a real log line |
| 8 | §5 step 5 | `kubectl top pod -n argocd` | **PASS** | Added `--context k3d-mgmt`; replaced the 4-pod sample with the real 6-pod output |
| 9 | §5 step 6 | `argocd app get` + `argocd app history` | **PASS** | Added the real post-recovery output |
| 10 | §6.4 | `kubectl -n argocd port-forward deploy/argocd-repo-server 8084:8084 &` + `curl … /metrics \| grep -E '^argocd_'` | **PASS** — 123–154 `argocd_*` lines | Added `--context k3d-mgmt`, an expected-output sentence, and how to stop the port-forward |
| 11 | §6.4 (claim) | metric `argocd_app_reconcile` exists on controller port 8082 | **PASS** — `# HELP argocd_app_reconcile Application reconciliation performance in seconds.` | No change |
| 12 | §7.1 / §9 | `argocd admin export -n argocd > backup.yaml` | **PASS** — exit 0, 86,782 bytes | Replaced placeholder counts with real ones |
| 13 | §9 | `grep -E '^kind:' backup.yaml \| sort \| uniq -c` | **PASS** | Replaced output; the guide's sample was not in `sort` order |
| 14 | §9 | `rm -f backup.yaml` | **PASS** | No change |
| 15 | §9 (claim) | "Argo CD will **not** error if you point the export at the wrong namespace" | **FAIL — claim is false** | `argocd admin export -n kube-system` exits **20** with `{"level":"fatal","msg":"configmaps \"argocd-cmd-params-cm\" not found"}` and writes a zero-byte file. Note rewritten. |
| 16 | §7.1 | `argocd admin import - < backup.yaml` | **NOT EXECUTED** (destructive; the guide does not ask a participant to run it). `argocd admin import --help` confirms the `SOURCE`/`-` form is current in v3.5.2. |

Supporting checks that are not guide commands but were needed to judge the above:

- `argocd app diff --help` — confirms the documented exit codes ("2 on general errors, 1 when a diff is found, and 0 when no diff is found"). The guide's *general* exit-code statement is correct; only its claim about this specific incident was wrong.
- `argocd repo list --help` — confirms `--refresh hard` ("Force a cache refresh on connection status") and the current wide-output columns.
- `argocd app manifests --help` — confirms `--source` takes `live|git` and defaults to `git`.
- `kubectl --context k3d-mgmt …` variants of commands 7, 8 and 10 — all **PASS**, so the added context flags are verified, not assumed.

---

## 3. Failure states induced, and how they were reverted

Two temporary failure states were required. Both were induced in the least invasive reversible way, and both were fully reverted. **No capstone fault script was used.**

### State A — Git repository unreachable (for §5 and SS-S7-01)

- **Induced twice** (17:14:15Z and 17:29:47Z UTC) with `docker stop lab-gitea`. Nothing else was touched: no CoreDNS edit, no Application edit, no Secret edit. The container's IP (`172.20.0.2`) was recorded before stopping and confirmed identical after restarting, so the CoreDNS `lab-gitea` host record stayed valid.
- The app was pushed into the visible state with `argocd app get storefront-dev-workload --hard-refresh`.
- **Reverted** with `docker start lab-gitea` (17:19:49Z and 17:30:49Z UTC), confirmed by `curl http://localhost:3000/ -> 200`, then `--hard-refresh` and `argocd app get` returning `Synced to main (cbeba81)` / `Healthy` with no conditions.
- The second induction existed only to capture the **complete** `argocd app diff` output rather than assert an unverified claim about the Service and Deployment sections.

**Why `docker stop` and not a DNS removal:** the guide previously claimed the error message says the host "could not be resolved." Stopping the server produces a TCP connection failure, not a DNS failure. Removing the CoreDNS record would have produced the DNS wording, but on a real student VM `lab-gitea` is resolved from `/etc/hosts`, so the student's own `git ls-remote` would still have resolved the name and the two halves of the narrative would have disagreed. Stopping the server is the only single action that fails the same way from both the student's shell and the repo-server. The narration and both screenshot captions were therefore corrected to the real evidence, not the reverse.

### State B — Sync operation retrying after a failed hook (for SS-S7-02)

Deliberately built on a **throwaway** Application and a **throwaway** repository so that no course-owned Application, repository or branch was ever broken.

1. Created Gitea repo `course/s07-scratch` (public, temporary) via the Gitea API at 17:21:30Z.
2. Pushed two manifests: a trivial `ConfigMap` and a `Job` annotated `argocd.argoproj.io/hook: PreSync` running `sh -c "echo …; exit 1"` with `backoffLimit: 0`.
3. Applied Application `scratch-retry` — project `default`, destination `https://kubernetes.default.svc` (management cluster), namespace `s07-scratch` with `CreateNamespace=true`, `syncPolicy.retry` limit 5.
4. `argocd app sync scratch-retry --async --retry-limit 5 --retry-backoff-duration 45s --retry-backoff-factor 2 --retry-backoff-max-duration 5m`.
5. Captured during the backoff window (`phase=Running`, `retryCount=2`).

**Reverted** at 17:24:36Z: `argocd app terminate-op scratch-retry`, `argocd app delete scratch-retry --cascade --yes` (confirmed gone), `kubectl delete namespace s07-scratch`, `DELETE /api/v1/repos/course/s07-scratch` (HTTP 204, confirmed 404 afterwards). The five course repositories are intact and unmodified; no branch was added to any of them.

---

## 4. What changed in the guide

Structure, section order, the timing table, the V-25/V-26/V-27/V-28/V-29 teaching devices, the vocabulary list and all four Quick Checks are unchanged. Only factually wrong or unverified content was edited.

1. **§4 debrief, point 2** — added one honest caveat that an *empty* render makes `argocd app diff` exit **1** (not 2) while showing every resource as deleted. The documented exit-code semantics are kept intact.
2. **§4 prediction answer** — previously said the proof is `argocd app diff` returning exit code 2. Replaced with the real proof chain: the `CONDITION` block from `argocd app get`, confirmed by `argocd repo list --refresh hard`.
3. **§5 step 1** — replaced the fictional source block (`https://gitea.lab.example/platform/storefront-gitops.git`, path `envs/dev`) with the real one (`http://lab-gitea:3000/course/storefront-gitops.git`, path `charts/storefront`, Helm values `../../envs/dev/values.yaml`), plus the full real `CONDITION` block. Corrected `Health Status: Unknown` to the real `Health Status: Healthy` and made that contrast a teaching point. Replaced the `git ls-remote` URL and both its healthy and failing outputs with real ones.
4. **§5 step 2** — `argocd repo list` -> `argocd repo list --refresh hard`, with the real wide-format table (the v3.5.2 output has `INSECURE`/`OCI`/`LFS`/`CREDS`/`PROJECT` columns the guide did not show) and an explanation of the cached-status trap. Replaced the invented `FATA[0002] …` sample for `argocd app manifests --source git` with the real `--- null` output, and explained why a quiet empty answer is still evidence.
5. **§5 step 3** — rewritten around the real result: exit code **1** and a 313-line, deletion-shaped diff with zero `>` lines (headers `1,39d0`, `1,62d0`, `1,203d0`). Added the operational consequence — this Application has `Automated (Prune)`, so acting on that diff would delete a healthy workload — which is a stronger case for "source before platform" than the original narration.
6. **§5 step 4** — added `--context k3d-workload` (the previous command returned `No resources found` on the default context), added a `get pods` line, real event output, a note that `tail -6` drops the header row, and a warning about the wrong-context failure mode. This matches the `--context`-every-time convention that Labs 1, 2 and 3 already establish.
7. **§5 step 5** — added `--context k3d-mgmt`; replaced the 4-pod invented `kubectl top` sample with the real 6-pod output (the guide omitted the applicationset- and notifications-controllers); added a real repo-server log line and a note about the `Defaulted container` message.
8. **§5 step 6** — added the real post-recovery `argocd app get` status lines and `argocd app history` tail, and noted that the condition clears itself.
9. **§6.4** — added `--context` flags, an expected-output sentence for the metrics `curl`, how to stop the backgrounded port-forward, and a note that events must be read on the workload cluster.
10. **§9** — replaced the placeholder kind counts with the real ones in `sort` order, added the real file size, and **corrected the false claim** that a wrong `-n` fails quietly (it exits 20 with a fatal error).
11. **Both screenshot captions, alt texts and CAPTURE-SPEC comments** — rewritten to describe what was actually captured (see §5 below).

### Spoiler check (deliberate rule: §5/§7 must not reveal capstone faults)

The capstone's seven faults are: a bad chart value (F1), an ApplicationSet generator blast radius (F2), a duplicate root/ownership tangle (F3), a Kubernetes RBAC denial (F4), a disconnected workload cluster (F5), a degraded workload behind noisy drift (F6), and a repo-server under memory pressure (F7). The incident used here — **the Git server itself stopped answering** — is none of them, and every real output captured in this pass comes from either the healthy `CP-capstone` baseline or that Git outage. No captured output named, hinted at, or reproduced any fault symptom, so no example had to be swapped. The pre-existing mention of `OOMKilled` in §5 step 5 (as a *negative* result) and in §6.3 was left exactly as it was; it was already in the approved guide and does not disclose that F7 exists.

---

## 5. Screenshots

Both were captured live from this course's own Argo CD `v3.5.2` at `https://localhost:8443` using the repo's harness (`courseware/environment/scripts/screenshots/capture.mjs`), 1440x900, light theme, admin session.

### SS-S7-01 — `courseware/assets/screenshots/day-2/s07-01-repo-unreachable.png`

- **Captured:** yes. Shows the **Application conditions** panel with a single `ComparisonError` whose message reads `Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unknown desc = failed to list refs: Get "http://lab-gitea:3000/course/storefront-gitops.git/info/refs?service=git-upload-pack": dial tcp 172.20.0.2:3000: connect: no route to host`, highlighted.
- **Caption/alt corrected.** The old alt text promised "an Unknown sync status and a ComparisonError condition whose message states the Git repository host could not be resolved." Two parts of that were wrong against reality: (a) the message is a **TCP connection failure**, not a DNS resolution failure; (b) the conditions panel is a full-width slide-out that covers the status bar, so the sync-status badge cannot appear in the same frame as the message. A no-click variant was captured and compared; it shows `APP HEALTH: Healthy`, `LAST SYNC: Sync OK`, `APP CONDITIONS: 1 Error` but no error text. The panel version was chosen because §5's own lesson is "go to the place that prints the reason," and the caption now states explicitly how to open the panel and what the status bar behind it reads.
- **Manifest reconciled** (three provisional values were wrong and are now annotated as confirmed-live):
  - `wait_until: load` added — an Application detail page holds an event stream open and never reaches `networkidle` (the first attempt failed with `page.goto: Timeout 45000ms exceeded`).
  - `actions` added — the conditions panel only renders after clicking `.application-status-panel__conditions` (same verified pattern as `SS-L5-03`).
  - `highlight.selector` changed from `.application-conditions` to `.application-conditions__condition`.
  - `produced_by` changed from `CP-lab-05` to `CP-capstone` with the exact recipe.

### SS-S7-02 — `courseware/assets/screenshots/day-2/s07-02-sync-retrying.png`

- **Captured:** yes. Shows `OPERATION: Sync`, `PHASE: Running`, the highlighted `MESSAGE` row reading `one or more synchronization tasks completed unsuccessfully. Retrying attempt #2 at 5:25PM.`, `DURATION 1m35s`, and a `RESULT` table whose second row is the `PreSync` hook Job `s07-failing-presync` — `Failed`, message `Job has reached the specified backoff limit`.
- **Caption/alt corrected** to name the real phase, the real message, and the `RESULT` table (which the old caption did not mention and which is the most useful part of the shot).
- **Manifest reconciled:**
  - `route` changed to `/applications/scratch-retry?operation=true` — the operation-state slide-out opens from that query parameter.
  - `wait_until: load` added (same event-stream reason).
  - `highlight.selector` changed from `.application-operation-state` to `.sliding-panel__body .white-box__details-row:has(pre)`. **There is no `.application-operation-state` element in v3.5.2** — a DOM probe found only `.application-operation-state__message`, `__icons_container` and `__images-count` inside the `RESULT` rows. The first capture attempt recorded `selector not found`.
  - `fidelity` changed from `panel` to `full` — cropping to the message row alone would have discarded the `PHASE` row and the `RESULT` table that the guide's "what to notice" list depends on.
  - `produced_by` expanded to the full throwaway-Application recipe including its teardown.

`courseware/assets/screenshots/capture-log.md` was backed up before capture and restored afterwards, so the repository's 71-shot log is not clobbered by a 2-shot run.

---

## 6. Final sandbox verification

```
reset-lab.sh CP-capstone --local --yes        -> PASS CP-capstone is in the expected state.
reset-lab.sh CP-capstone --local --verify-only -> 22/22 PASS
```

Additional post-run cleanliness checks:

- `inject-capstone-faults.sh status --local` -> `clean` for F1, F2, F3, F6, F4, F5, F7; `ok no faults injected`.
- Gitea org `course` contains exactly its five original repositories; `course/s07-scratch` returns HTTP 404.
- No `s07-scratch` namespace on either cluster; `argocd` namespace holds exactly the eight checkpoint Applications.
- `kube-system/coredns-custom` still maps `172.20.0.2 lab-gitea` — unmodified.
- `lab-gitea`, `k3d-mgmt-server-0`, `k3d-workload-server-0` all running; no other Docker container or network was touched.

**The capstone validation can start from a clean `CP-capstone`.**

### One pre-existing environment finding (not caused by this pass)

The very first `--verify-only` run, *before* any work began, reported **21/22** with `FAIL Application platform-root Synced/Healthy`. The cause was that `main` in `course/platform-config` was sitting at the `cp-baseline` commit (`ca5fec8`) instead of `cp-capstone` (`fe95ccd`), so the `apps/` directory `platform-root` tracks did not exist and the app held a `ComparisonError: apps: app path does not exist`. A plain `reset-lab.sh CP-capstone --local --yes` fixed it (step 3 force-moves `main` to the checkpoint tag) and it has not recurred across three subsequent resets. Flagging it for `environment-engineer`: a sandbox described as "verified CP-capstone" can silently be one commit behind if a previous session left `main` moved, so **`--verify-only` should be run before trusting a handed-over checkpoint**, not just after.

---

## 7. Environment-parity notes (for `environment-engineer` / instructor)

Validated on the local build-machine sandbox, not a provisioned student VM. Three differences are worth confirming there:

1. **Git hostname resolution.** On the build machine, `~/.argocd-course/student-home/.gitconfig` rewrites `http://lab-gitea:3000/` to `http://localhost:3000/` via `insteadOf`, so the host-side `git ls-remote` failure message names `localhost`. On a student VM the name is resolved from `/etc/hosts`, so the message names `lab-gitea`. To keep the guide truthful for the VM audience, the `git ls-remote` failure output printed in §5 step 1 was captured from a resolver that behaves like the VM (`kubectl -n argocd exec deploy/argocd-repo-server -- git ls-remote …`), which produced `Failed to connect to lab-gitea port 3000 after 3112 ms: Could not connect to server`. **Please re-confirm this one line on a real VM.** Only the elapsed-milliseconds number should vary.
2. **`kubectl top` requires metrics-server.** It worked on both k3d clusters here. Confirm it is present on the provisioned VM, or §5 step 5 and §6.4 lose their evidence command.
3. **Context names.** The guide now names `k3d-mgmt` and `k3d-workload` explicitly in §5 step 4/5 and §6.4, matching Labs 1–3. Confirm those are the context names in the VM's kubeconfig.

---

## 8. Non-blocking items left for `lab-engineer` / `pedagogy-reviewer`

These were **not** changed, because they are judgement calls rather than factual errors:

1. **V-25 diagram, station 2** still shows `argocd repo list` without `--refresh hard`. The ASCII box is 11 characters wide and cannot hold the flag without breaking the diagram's alignment. §5 step 2 now teaches the cached-status trap explicitly, so a participant who copies from the diagram meets the trap in exactly the place the guide explains it — but a footnote under the diagram would be safer.
2. **V-25 diagram, station 4** shows `kubectl -n <ns> get events` without a context flag. The station's component row already reads "app-ctrl + target cluster."
3. **Reading time.** §5 grew by roughly 450 words of narration plus four code blocks. The header's honest timing table still budgets 15 minutes for §5; at full depth it is now closer to 17–18. The table was left intact per the concept-guide constraint, but the total should be revisited.
4. **`argocd admin export` and kube context.** The command works because the default context is `k3d-mgmt`. `argocd admin export --context k3d-mgmt -n argocd` was verified to work identically and would be more robust, but it introduces a second meaning of "context" (kubeconfig vs. `argocd` CLI context) that the guide's vocabulary section does not ground, so it was not added.

---

## 9. Status

**PASS WITH NOTES.** Every command in the guide now runs exactly as printed against the pinned v3.5.2 toolchain and produces the output the guide shows; the worked incident behaves as narrated; both screenshots exist and match their captions; and the sandbox is back at a clean 22/22 `CP-capstone`. The notes in section 8 are non-blocking. Retest is required only if the Argo CD version changes (both screenshots and the `argocd repo list` / `argocd app manifests` output shapes are version-sensitive) or if the environment's Git hostname handling changes.
