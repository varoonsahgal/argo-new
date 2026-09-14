# Capstone · Module 5 — P2–P4: Restore, Verify, Reflect

> **Day 2 · Capstone · Module 5 of 6 · work at 0:25–1:30**
> **Goal:** return every layer to health one controlled change at a time (P2), verify with evidence you did not produce (P3), and turn the incident into prevention (P4).

---

## P2 — Restore (50 min · hard)

**Starter state:** Checkpoint C1 passed; triage grid and layer coverage complete.

### The repair loop (repeat per hypothesis)

1. **Choose.** Apply the masking question across your whole grid. Pick the hypothesis whose truth would make the most other evidence untrustworthy. If none stands out, pick the one that hurts users most.
2. **Re-confirm.** Re-run that row's evidence — evidence goes stale, and connected faults change each other's symptoms.
3. **Find the owner.** Identify the object and file that own the field you intend to change (Lab 4). The owner decides the change path.
4. **Predict.** Write the observable result you expect, and how soon (Git is read every 60s; Refresh reads it immediately).
5. **Change.** Make **one** controlled change, through **one** path from [module 02 §6](02-setup-and-rules.md).
6. **Verify.** Re-run the evidence you diagnosed with, then the sanity check for that layer (below).
7. **Log.** Complete the change-log row, including when the result did not match. Once a repair is verified, start that fault's P4 reflection block with two lines (its layer + the evidence) — ten minutes is not enough to write seven blocks from nothing.
8. **Re-triage.** Re-read the whole picture (§0). Add rows for any newly-appeared symptom (mark "revealed after C<n>"); mark resolved rows resolved.

When a result contradicts your prediction, **stop and treat the surprise as new evidence.** Do not stack a second change on a surprise.

**Pacing.** ~7 minutes per fault. If 10 minutes pass on one hypothesis with no new evidence, climb the hint ladder; if the third rung does not help, **park** the row and take another (connected faults often unstick each other). At 0:40, 0:55, and 1:10, re-read the whole picture.

### Sanity checks — what healthy looks like, layer by layer

A check tells you whether a layer looks healthy **now** — not whether it was ever broken, why, or how to fix it.

- **`PLAT`:** every pod in `argocd` on `k3d-mgmt` is `Running` and fully `READY`; every Deployment/StatefulSet reports all replicas ready; `RESTARTS` is the same in two readings ~2 min apart; a Refresh completes promptly. → `kubectl -n argocd get pods` / `get deploy,statefulset`.
- **`CONN`:** `argocd cluster list` and Settings → Clusters show `workload` `Successful`, no error; `argocd cluster get workload` shows a recent cache sync; every workload-targeting app shows a real comparison (never `Unknown`). → `argocd cluster list` / `argocd cluster get workload`.
- **`SRC`:** no app carries a `ComparisonError`; `argocd app manifests <app> --source git` prints manifests for every app; `argocd app diff` exits `0`/`1` (never `2`); `argocd repo list` shows every repo `Successful`.
  ```bash
  for app in $(kubectl --context k3d-mgmt -n argocd get applications -o jsonpath='{.items[*].metadata.name}'); do
    argocd app diff "${app}" >/dev/null 2>&1; echo "${app}  diff-exit=$?"
  done
  ```
- **`GEN`:** the inventory holds exactly the eight known-good Applications and no others; `argocd appset generate` prints exactly the three expected names and the `ErrorOccurred` condition is `False`; each object/resource has exactly one owner, stable across readings; no app reports a condition (`CONDITIONS` reads `<none>`). → `argocd appset generate …` / the ownership `custom-columns` query.
- **`POL`:** every app's most recent operation ended `Succeeded`; no message/condition contains `permission denied`, `is not permitted in project`, or `forbidden`; the Lab 2 matrix holds (`create deployments.apps` → `yes` in all five namespaces; `create clusterroles…` → `no`); every AppProject still matches its design. → the `LAST-OP`/`MESSAGE` query + the `auth can-i` loop.
- **`RUN`:** all eight apps `Synced`/`Healthy` and **stay** so across ≥2 reconciliation cycles (~2 min); Pods `Running`/Ready with non-climbing restarts; a port-forward returns the normal response; each synced revision is a commit you can find and explain. → `argocd app list` + the Pods loop + port-forward.

### The hint ladder (any stuck point, in order)

- **Rung 1 — Which layer have you not ruled out?** A layer marked *cannot tell yet*, or never checked, is a blind spot. Spend two minutes getting one piece of evidence from it before digging deeper where you are stuck.
- **Rung 2 — What could be masking this?** Trace the badge you rely on back through the masking chain; for every box, ask "have I confirmed this box is working?" If a fix worked and came back, look **up** the ownership chain (Lab 4).
- **Rung 3 — Where does the evidence live?** Go to the matching toolbox block and read the evidence at its source (the commit that changed the field, the condition/operation message, the ApplicationSet's conditions, the cluster's connection status, the component's pod status/logs). Then ask: which repository+file, or which applied object, owns the field I want to change?

**Success criterion:** for each layer, the sanity-check signal is observable now; every change went through a path in [module 02 §6](02-setup-and-rules.md); nothing off-limits applies.

---

## P3 — Verify (5 min · easy)

> **▶ Predict first.** Before running anything, write which of the six areas you expect `capstone-check.sh` to report resolved.

```bash
capstone-check.sh
echo "exit code: $?"
```

**Expected when every area is restored:**

```text
==> Capstone restoration status by area
  resolved   argo cd platform components
  resolved   workload cluster connectivity
  resolved   application source rendering
  resolved   application generation and ownership
  resolved   deployment policy (permissions)
  resolved   workload runtime health

  ok all areas resolved
exit code: 0
```

An unresolved area prints `unresolved` and a short note; the exit code is then `1`. Compare with your prediction, paste both into your log, and write one sentence explaining any difference (that sentence goes into your reflection).

**▶ Take the whole picture one last time:**

```bash
kubectl --context k3d-mgmt -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project,SYNC:.status.sync.status,HEALTH:.status.health.status,LAST-OP:.status.operationState.phase,CONDITIONS:.status.conditions[*].type'
```

A fully restored platform shows all **eight** apps `Synced`/`Healthy`/`Succeeded`/`<none>`.

![Argo CD Applications list, fully restored: eight tiles all Synced/Healthy (v3.5.2)](../../assets/screenshots/day-2/capstone-02-restored.png)

*Figure SS-CAP-02 — A fully restored platform (also exactly what it looked like before the incident). Eight tiles, every one `Synced` and `Healthy`, no warning indicators — holding across ≥2 reconciliation cycles.*

<!-- CAPTURE-SPEC: SS-CAP-02 — Applications list, fully restored. State: CP-capstone-restored. Highlight: sync/health badges on all eight tiles. Argo CD v3.5.2. -->

**Hints:** if the tool reports an area unresolved that your sanity check called healthy, re-run the sanity check (statuses are measurements). If the tool will not run, see [module 06](06-troubleshooting-completion-close.md) — do not look inside it.

---

## P4 — Written reflection (10 min · medium)

Group your grid rows into **faults** (one fault = one root cause, possibly several symptom rows). Name each Fault A, B, C… and write one block per fault, **seven total** — including any you did not restore (give its layer, evidence, and the change you would make).

```markdown
### Fault A: <your short name>
- **Symptom rows it explains:** S_, S_
- **Layer:** PLAT / CONN / SRC / GEN / POL / RUN
- **Method step where first real evidence appeared (1-6):**
- **Root cause (1-2 sentences):**
- **Evidence that proved it (command/screen, and what it showed):**
- **Change made (change-log row, and which path):**
- **How you verified it (the sanity-check signal you observed):**
- **What it masked, or what masked it (if anything):**
- **Guardrail that would have prevented it (setting/file/policy, and owner):**
- **Monitoring signal that would have caught it sooner (metric/condition/notification, and when it fires):**
```

**A catalogue to choose from** (a **guardrail** prevents/blocks; a **signal** detects sooner — not every item applies, some faults need more than one, and you may propose your own):

*Guardrails:* render+preview in CI before merge; treat Argo CD changes as releases; `goTemplateOptions: ["missingkey=error"]`; `applicationsSync` policy; `preserveResourcesOnDeletion`; hard-coded `project` + AppProject destinations; AppProject source/destination/kind restrictions; Argo CD RBAC least privilege with explicit `deny`; workload-cluster RBAC from a reviewed file; pinned immutable revisions for higher environments; sync windows; `FailOnSharedResource=true`; deliberate finalizer/cascade decisions; field-scoped `ignoreDifferences` with a named owner; progressive sync.

*Signals:* component readiness + restart counts; `argocd_cluster_connection_status`; `argocd_app_info` (`sync_status`/`health_status` — **alert on failure to converge**, not on every brief `OutOfSync`); `argocd_app_sync_total`; `argocd_app_reconcile` (a rising trend warns before red); `argocd_repo_pending_request_total`; `argocd_appset_info` + ApplicationSet error conditions; notification triggers `on-sync-failed`, `on-health-degraded`, `on-sync-status-unknown`.

**Closing questions** (2-3 sentences each): (1) Which symptom did you diagnose more than once, and what hid it? (2) Rank your faults by user impact, then by UI loudness — compare. (3) Did any fix revert? What was above the object you changed? (4) Place each fault on the six-step station where its first real evidence appeared. (5) **End where you started** — for each fault, say which of Day 1's two questions (*does it match Git?* / *is it working?*) it first failed, or whether it broke something beneath them both so neither could be answered honestly. One idea, two days, increasing depth.

**Success criterion:** seven fault blocks (each field filled, or an honest "not restored" + the change you would make) plus the four closing answers. Each guardrail names a concrete setting/file/policy and owner; each signal names a concrete metric/condition and when it fires. A teammate not in the room could read any one block and know what broke, how you proved it, what you changed, and what to do next month.

**Hints:** "better monitoring" is not an answer — name the metric, threshold, and how long it must persist. For each guardrail, ask "would this have *blocked* the fault, or only *told* someone sooner?" If it only tells, it belongs in the monitoring line.

**→ Next:** [06 — Troubleshooting and completion](06-troubleshooting-completion-close.md)
