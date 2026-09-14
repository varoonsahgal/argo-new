# Instructor Walkthroughs and Solutions — Intermediate Argo CD Operations

> **INSTRUCTOR ONLY.** Nothing in this folder is ever shared with participants, projected, or pasted into a shared channel. Participant guides live in [`../day-1/`](../day-1/) and [`../day-2/`](../day-2/).

This folder holds one narrated walkthrough per hands-on lab and one for the capstone. Each file is written so you can **walk the class through the solution live**: what to type, what to click, what they will see, what to ask the room before revealing it, and the sentence worth pausing on.

---

## Files

| Participant guide | Instructor walkthrough | Timebox |
|---|---|---|
| [Lab 1 — Follow an Application Through Reconciliation](../day-1/lab-01-follow-an-application-through-reconciliation.md) | [lab-01-…-SOLUTION.md](day-1/lab-01-follow-an-application-through-reconciliation-SOLUTION.md) | 45 min |
| [Lab 2 — Configure the Platform and Register a Target](../day-1/lab-02-configure-platform-and-register-target.md) | [lab-02-…-SOLUTION.md](day-1/lab-02-configure-platform-and-register-target-SOLUTION.md) | 60 min |
| [Lab 3 — Deploy, Introduce Drift, and Recover](../day-1/lab-03-deploy-drift-and-recover.md) | [lab-03-…-SOLUTION.md](day-1/lab-03-deploy-drift-and-recover-SOLUTION.md) | 60 min |
| [Lab 4 — Build and Troubleshoot the Patterns](../day-2/lab-04-build-and-troubleshoot-patterns.md) | [lab-04-…-SOLUTION.md](day-2/lab-04-build-and-troubleshoot-patterns-SOLUTION.md) | 75 min |
| [Lab 5 — Enforce Platform Guardrails](../day-2/lab-05-enforce-platform-guardrails.md) | [lab-05-…-SOLUTION.md](day-2/lab-05-enforce-platform-guardrails-SOLUTION.md) | ~50 min |
| [Capstone — Restore an Argo CD Deployment Platform](../day-2/capstone-restore-platform.md) | [capstone-…-SOLUTION.md](day-2/capstone-restore-platform-SOLUTION.md) | 90 min |

**Not covered here, on purpose:** *Lab 0 — Prepare Your VM* is setup rather than an exercise (its one instructor-relevant check is repeated in the Lab 1 pre-flight). The concept guides (Sessions 1–7) answer their Quick Checks inline, so they have no separate solutions.

---

## How every walkthrough is laid out

Each file follows the same skeleton, so you can find your place mid-class:

1. **Before class — pre-flight.** The checks to run on your own VM, and the **known discrepancies** between the participant guide and Argo CD `v3.5.2` that participants will hit. Read this section before every delivery.
2. **Run of show.** A minute-by-minute plan and what to cut if you're behind.
3. **One section per exercise**, in the guide's order, with these labels:

| Label | Meaning |
|---|---|
| **Say** | Words you can use nearly verbatim. Questions are prompts for the room — ask them *before* revealing the next output. |
| **Do** | A command to run on the projected VM terminal. |
| **Click** | A UI action in Firefox on the VM (screenshots link to the participant guide's own figures). |
| **Expect** | Output captured from a real run. |
| **Answer key** | The answer, and why it's correct. |
| **Wrong turns** | Real mistakes, with what they look like on screen. |
| **Wow moment** | The one line worth pausing on — the thing people repeat to colleagues. |
| **If it goes sideways** | A recovery that was tested in rehearsal. |

4. **Stretch challenges**, **checkpoint grading**, **debrief questions**, and **key takeaways** to say out loud.

---

## How these were verified

Every walkthrough was executed end to end on **2026-09-13** against the course's local two-cluster sandbox (the `bootstrap-vm.sh --local` layout: k3d `mgmt` + `workload` clusters, Gitea, the course checkpoints and fault scripts):

| Component | Version |
|---|---|
| Argo CD server and `argocd` CLI | `v3.5.2` (Helm chart `10.8.4`) |
| Kubernetes (both clusters) | `v1.35.8+k3s1` |
| Helm (pinned) | `v4.2.1` |
| `yq` | `v4.48.1` |

Each lab started from its checkpoint (`reset-lab.sh CP-lab-0N --local`), and each lab's end state was confirmed against the **next** lab's checkpoint verifier — so the answers in these files produce exactly the state the next lab expects. The capstone was run as a full incident: all seven faults injected at once, triaged, and repaired through the controlled change paths in the guide. The detailed evidence log is [`../reviews/solution-validation-2026-09-13.md`](../reviews/solution-validation-2026-09-13.md).

Output blocks are real, with sandbox-specific values (SHAs, Pod suffixes, ages, ports) that will differ on your VMs. Where something could **not** be verified, the file says so explicitly. No password or token value appears in any file.

---

## Read these before you teach — the ten issues most likely to surprise you live

Ranked by how badly each can derail a session. Every one was reproduced in rehearsal; each walkthrough's pre-flight has the details and the classroom workaround.

| # | Where | Issue | Classroom workaround |
|---|---|---|---|
| 1 | **Capstone, fault F5** | The injected "disconnected cluster" fault is a **no-op**: recreating the token Secret with the same name mints a byte-identical legacy token, so connectivity never breaks (`inject-capstone-faults.sh verify F5` → `ABSENT`). The capstone silently runs with six faults | Tested instructor pre-flight that makes F5 real (capstone walkthrough, Section 0) |
| 2 | **Lab 3, Exercise 2** (fixed 2026-09-13) | The old promotion target `podinfo:6.16.0` never existed. The environment now starts dev and staging on `6.14.1` and pre-loads both `6.14.1` and `6.15.0`, so the promotion to `6.15.0` succeeds; `CP-lab-04` puts both back on `6.15.0` for Day 2. **A VM built before this fix** still has only `6.15.0` and seeds dev/staging at `6.15.0`, which turns the promotion into a no-op | Pre-flight check in the Lab 3 walkthrough, 0.1. On an old VM: rebuild it, or pull and import `6.14.1`, re-run `seed-repos.sh`, and reset to `CP-lab-03` |
| 3 | **Lab 3, Exercise 5 Part B** (guide rewritten 2026-09-13) | A hook-only change (`migration.shouldFail: true`) never makes an app `OutOfSync`, so the guide now has participants start the sync explicitly (verified: `Failed` in ~6 s, no retries). If someone pairs the flag with a visible change, automated sync takes over: v3.5.2 **retries 5 times by default**, a pushed fix does not rescue the retrying operation, and a manual sync is refused with `another operation is already in progress` | `argocd app terminate-op storefront-dev`; automated sync then picks up the newest commit (Lab 3 walkthrough, Section 6) |
| 4 | **Lab 4, Exercise 5A** (and anywhere the ApplicationSet preview fails) | The `argocd appset generate` error dumps generator parameters, including the cluster Secret's `last-applied-configuration` annotation — **a plaintext bearer token**. All three course credential Secrets carry their credential in that annotation (client-side `kubectl apply` of `stringData`) | Show the ApplicationSet *conditions* instead of the failing preview; report the environment fix (server-side apply) |
| 5 | **Lab 2, before class** | `reset-lab.sh CP-lab-02` leaves the `repo-storefront-gitops` and `cluster-workload` Secrets in place, so a rehearsed VM shows both already `Successful` and the lab's before/after reveal is gone | Delete the two Secrets before class (Lab 2 walkthrough, 0.1) |
| 6 | **Lab 1, Exercise 2** | Part 1 is *designed* to surprise: the message-only sync succeeds but no Pod restarts, so `curl` shows the **old** message. Participants diagnose it and add a `checksum/config` annotation to the Pod template themselves (Part 3). If a rehearsal leaves that annotation on `main`, the next run has no surprise | Run `reset-lab.sh CP-lab-01 --local` after rehearsing, and confirm `deployment.yaml` has no `annotations:` (Lab 1 walkthrough, 0.2) |
| 7 | **Lab 1, Exercise 3** | The printed `sed` range drops the ConfigMap's `data:` block | Corrected command in the Lab 1 walkthrough |
| 8 | **Lab 5, Exercise 3A** | `argocd app sync` on the refused Application **never returns** (the operation ends instantly, the CLI waits forever) | Always add `--timeout 30` |
| 9 | **Lab 2, stretch A** | `argocd cluster add` fails as the guide says — **after** leaving a cluster-wide ServiceAccount, ClusterRole, binding, and long-lived token on the workload cluster, which no reset removes | Four cleanup commands in the Lab 2 walkthrough |
| 10 | **Capstone, faults F4 → F6 — a false "all resolved"** | The missing RoleBinding also removes *read* access, so F4 appears as `ComparisonError … forbidden` on three Applications, only after F5 is repaired. If F5 is repaired before F4, Argo CD's cache for `storefront-prod` stays stale after F4 is fixed: in rehearsal `capstone-check.sh` reported **all areas resolved (exit 0)** and all eight Applications stayed `Synced`/`Healthy` for two minutes while a leftover HPA fought self-heal over replicas | After the F4 repair, rebuild the workload cluster cache (verified API call) and check that no resource row reads `Unknown` before declaring the incident over — capstone walkthrough, Faults F and G |

Smaller discrepancies (sample-output layouts, message wording, timing) are listed in each file's pre-flight table.

---

## A note on the file location

The repository's `CLAUDE.md` names `courseware/solutions/` as the solution location. These walkthroughs were requested as an **instructor folder**, so they live in `courseware/instructor/`, mirroring the `day-1/` and `day-2/` structure and the `-SOLUTION.md` suffix. If you later move them, update the relative links (screenshots are referenced as `../../assets/screenshots/…`).
