# Capstone · Module 6 — Troubleshooting and Completion

> **Day 2 · Capstone · Module 6 of 6 · reference + close**
> **Goal:** the mechanics troubleshooting table, what "restored" means, takeaways, optional stretch, and closing the course.

---

## Troubleshooting (mechanics only — none of these is a fault)

| Likely failure | Cause | What to do |
|---|---|---|
| An `argocd` command hangs/errors while others work | The CLI asks components for answers; a struggling one slows some calls. Evidence to record, not a terminal problem. | `Ctrl+C`; retry with `--timeout 30`; read straight from the object: `kubectl -n argocd get application <app> -o yaml` |
| `argocd` reports an invalid/expired session | Login expired/invalidated | Re-run the login command from [module 02](02-setup-and-rules.md) |
| After `apply-argocd-config.sh`, the UI/CLI log you out | The wrapper re-applied the admin password, ending sessions | Log in again (browser + CLI) |
| `apply-argocd-config.sh` takes several minutes | It waits for components to roll out (up to 5 min) | Let it finish; interrupting leaves the release half-changed |
| You pushed a fix and Argo CD shows the old state | Git is read every 60s; or the object is applied (paths B/C), not reconciled from Git | Click **Refresh** (`argocd app get <app> --refresh`); if applied, apply through its path |
| An app still shows a failed sync after you fixed its cause | Auto-sync does not re-attempt a sync that failed for the same commit (Lab 3) | Make a deliberate, logged sync (path D): `argocd app sync <app>` |
| Your fix worked, then quietly came back | Something above the object owns and rewrote it (Lab 4) | Log it; find the owner (§GEN) and change it there |
| A delete never finishes; the app sits deleting | Its finalizer waits for Argo CD to delete managed resources; anything blocking rendering/reaching/acting keeps it waiting | Do **not** remove the finalizer by hand; record it, find the blocking layer, tell your instructor if stuck |
| `git push` rejected `non-fast-forward` | `main` moved | `git -C ~/capstone/<repo> pull --rebase`, check, push. Never force-push |
| Git keeps asking for a password | Credential cache expired or unset | Re-run the `credential.helper` line ([module 02](02-setup-and-rules.md)); user `student`, password in `~/course/credentials/gitea-student.txt` |
| `kubectl top` says metrics unavailable | metrics-server needs ~1 min of samples | Wait a minute, retry |
| A port-forward fails `address already in use` | An earlier one is still running | `pkill -f "port-forward"`, or use another local port (`9899:9898`) |
| `capstone-check.sh: command not found` | The course environment is not loaded | `source ~/argo-lab-env.sh`, retry; do not look inside the script |
| **You made an uncontrolled change** (or aren't sure) | It happens under pressure | 1. Stop changing things. 2. Write down exactly what/when, marked "uncontrolled". 3. If it was a Git commit, undo with `git revert <sha>` + push (a new, logged commit). 4. For anything else, do **not** hand-undo and do **not** run `reset-lab.sh` (it erases the whole incident); tell your instructor. 5. Carry on with the method. |
| Running out of time | Seven connected faults in 50 min is ambitious by design | Stop P2 on time; run P3 honestly; spend all of P4 on the reflection. The minimum bar does not require every area resolved. |

---

## Checkpoint / validation — what "restored" means

Your platform is **fully restored** when all are observably true:

1. `capstone-check.sh` reports every area `resolved` and exits `0`.
2. The inventory is exactly the known-good eight, all `Synced`/`Healthy`, no conditions.
3. It **stays** that way — the same command two minutes later shows the same result.
4. Settings → Clusters shows the workload cluster connected (SS-CAP-03).
5. Every change went through one of the four paths, with evidence before/after, and nothing off-limits applies.
6. You did not reach green by hiding evidence: auto-sync/self-heal are on wherever they were before, no guardrail is wider than its design, and any ignore rule you added names a single field and its owner.

![Argo CD Settings, Clusters on a restored platform: workload Successful (v3.5.2)](../../assets/screenshots/day-2/capstone-03-clusters-restored.png)

*Figure SS-CAP-03 — the `workload` row shows `Successful` at `https://k3d-workload-server-0:6443` (the in-network address from Lab 2). `Successful` is a measurement taken a moment ago — check it again before relying on it.*

<!-- CAPTURE-SPEC: SS-CAP-03 — Settings → Clusters, restored. State: CP-capstone-restored. Highlight: workload row Successful + server URL. Argo CD v3.5.2. -->

**Completion bars:**
- **Minimum bar:** your reflection names seven faults, each with an evidence-backed layer; at least five have a verified repair in your change log; all seven have a completed reflection block.
- **Full bar:** the minimum bar plus all six criteria above.

> **Self-check without a solution file:** every criterion is a command's output, a status on your screen, or a row in your own log. If a criterion fails, the reason is worth a line in your reflection.

---

## Key takeaways

- **The first move in an incident is not a fix; it is finding out what is true.** Triage with no changes is what makes every later change safe.
- **Some faults hide other faults.** Ask which hypothesis, if true, would make the rest of your evidence untrustworthy, and confirm that one early. After each such repair, look again.
- **A red badge is not the same as a hurting user.** Triage by who is affected, not by what is loudest.
- **If your fix reverted, you fixed the wrong layer.** Find the owner of the field and change it there.
- **When the evidence stops making sense, look at the thing doing the looking.** The components and connections that produce every badge are evidence too.
- **An incident is not over when it is green. It is over when you can name the guardrail that would have caught it.**

---

## Optional stretch challenge (after P4, outside the timebox — do not apply anything live)

1. **An alert rule, written as code.** For one fault you found, write the alert that would have caught it as a **PrometheusRule** (for review, not applied — the lab has no Prometheus). Use a P4-catalogue metric and PromQL, and choose the `for:` duration so it fires on failure-to-converge, not on a briefly-red status. *Success:* a reviewer can tell what fires, when, and what the responder should run first.
2. **A pre-merge check.** Write a short script a CI job could run on every pull request. Start from the skeleton (render every environment with `helm template`; then TODO: run `argocd appset generate … -o wide`, extract the NAME column, compare with an allow-list, `fail=1` on any extra). *Success:* exits `0` on current `main`, non-zero when you reproduce a problem on a local unpushed branch.
3. **A policy, proven by a test.** Pick a P4-catalogue guardrail that would have **blocked** one fault. Write it on a local branch of `~/capstone/platform-config` (do not push) and prove it offline (`argocd admin settings rbac can … --policy-file` for RBAC, or `argocd appset generate` for an ApplicationSet change). *Success:* a before/after test output showing the guardrail refuses the change that caused the fault.

---

## Transition — closing the course

On Day 1 morning, Lab 1 asked you to find one Application's status in three places and predict what a single commit would do. Every fault you met today answers the same question you learned then: **was this a Git problem, a rendering problem, a comparison problem, a sync problem, a health problem, or a component problem?** Those six buckets are the six steps of the method, and the six stations of the reconciliation pipeline you drew on the first day. The course has been one idea, examined at increasing depth.

You have done what the Day 2 outcome promised: reasoned through ApplicationSets and App-of-Apps, enforced platform boundaries, and restored stable service during a realistic incident — with evidence, through Git, and with a written account of what would prevent it next time.

**What happens next.** Your instructor leads a debrief; bring your incident log. Your reflection page — the one that names a guardrail and a signal for each fault — is the artifact most worth keeping. The log lives at `~/capstone/incident-log.md`, and the VM may be reset after the course, so **preserve a copy before you leave.**

This is the last guide in the course. Thank you for working through it with care.
