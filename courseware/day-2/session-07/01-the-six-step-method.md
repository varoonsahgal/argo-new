# Session 7 · Module 1 — The Six-Step Method

> **Day 2 · Session 7 · Module 1 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** learn the two rules of incident triage, the six-step method, and the fact that makes it powerful — each step names exactly one component.

---

## 1. Why this matters: 09:05, everything is `Unknown`

It is **09:05** on a Monday. Every Application in the UI has flipped to **`Unknown`** — the status Argo CD shows when it cannot even *complete a comparison*. Someone in chat types the sentence that makes most outages worse: *"Should I just restart everything?"*

Stop. That question is the trap. Restarting before you have evidence does two harmful things: it can **erase the evidence** you need (logs roll, in-flight operations reset), and it can **make a healthy component look guilty** because you touched it right before the symptom changed. An incident is not the moment to guess and poke — it is the moment to *walk a known path and read what each step tells you.*

Two rules install the discipline:

- **Evidence before change.** Gather proof of *where* the failure is *before* you change anything. Your first destructive action should be the fix, not a diagnostic guess.
- **Source before platform.** Check the declarative source (Git, rendering) *before* you suspect Argo CD's own components — because most incidents are a bad or unreachable source, not a broken controller, and you cannot trust a comparison until you trust both sides of it.

---

## 2. Walk the pipeline in the direction the data flows

An Argo CD deployment is a **pipeline**: data flows from Git, through rendering, through comparison, into the cluster, and status flows back. When something breaks, you **walk the pipeline in the same direction the data travels, and stop at the first step that lies to you.**

The outline's **six-step method** *is* that walk (memorize the wording):

1. **Validate the Git source and revision.**
2. **Validate repository access and manifest rendering.**
3. **Compare rendered state with live cluster state.**
4. **Inspect synchronization results, hooks, events, and Kubernetes health.**
5. **Inspect the responsible Argo CD component and its metrics.**
6. **Correct the declarative source and verify reconciliation.**

**Why this order?** **You cannot diagnose a comparison until you trust both sides of it.** Step 3 compares desired against live — meaningless unless you first confirm the desired side is the revision you think it is (step 1) and that it rendered at all (step 2). Source and rendering come first, always.

**The highest-value idea: each step names exactly one component — finding the step finds the pod whose logs to open.**

| Step | What you validate | Component (verb) | Where |
|---|---|---|---|
| 1 | Git source and revision | **Git** — *stores* | the Gitea server |
| 2 | Repo access and rendering | **repo-server** — *renders* | `argocd` ns |
| 3 | Rendered vs live | **application-controller** — *compares* | `argocd` ns |
| 4 | Sync results, hooks, events, health | **application-controller** — *applies* + target cluster API | `argocd` ns + workload |
| 5 | The responsible component and metrics | whichever step 1–4 implicated | `argocd` ns |
| 6 | Correct the source and verify | **Git**, then the loop runs again | outside, then back through 1–6 |

The method is not just diagnostic, it is a **localization** procedure. "Manifests are stale even after a refresh" → the lie is at step 2 → open the **repo-server**. "The sync started and then failed with `forbidden`" → the lie is at step 4 → look at the **target cluster's** permissions, not Argo CD.

---

## 3. V-25 — the six-step pipeline with its evidence commands

Read it as a **pipeline with six stations**, left to right — not a decision tree. Walk it in order, stop at the first station that lies.

```text
  DATA FLOWS THIS WAY ──────────────────────────────────────────────────►  (status flows back)

  STEP 1          STEP 2          STEP 3          STEP 4          STEP 5          STEP 6
  Validate Git    Validate repo   Compare         Inspect sync    Inspect the     Correct the
  source &        access &        rendered vs     results, hooks, responsible     source & verify
  revision        rendering       live            events, health  component       reconcile
  ─────────       ─────────       ─────────       ─────────       ─────────       ─────────
  Git (stores)    repo-server     app-controller  app-ctrl +      whichever       Git, then the
                  (renders)       (compares)      target cluster  step 1–4        loop runs again
  ─────────       ─────────       ─────────       ─────────       implicated      ─────────
  EVIDENCE:       EVIDENCE:       EVIDENCE:       EVIDENCE:       ─────────       EVIDENCE:
  argocd app get  argocd repo     argocd app      argocd app get  EVIDENCE:       git commit+push,
  <app> +         list --refresh  diff <app>      <app> +         kubectl -n      then argocd app
  git ls-remote   hard +          (exit 1=drift,  kubectl get     argocd logs     get <app> +
  <repo> <ref>    argocd app      2=error)        events          deploy/<c> +    argocd app
                  manifests …                                     kubectl top pod history
  TRUST source    TRUST render    diff MEANS sth  READ applied    OPEN the pod    FIX in Git,
  first           next                            result          logs            never by hand
```

Three things about the shape:
1. **Steps 1–2 establish trust in the *desired* side before any comparison.**
2. **Step 3 is the hinge.** `argocd app diff` returns a telling exit code: **0** = no difference, **1** = a real difference, **2** = could not complete. A `2` sends you *back* to steps 1–2; a `1` sends you *forward* to step 4. (Caveat you will see in Module 2: if the desired side rendered to *nothing*, the diff completes and exits **1** showing every resource as if being deleted — exactly why steps 1–2 come first.)
3. **You do not touch a component until step 5.** Steps 1–4 are pure evidence. Step 6 is the first change, and it happens **in Git**, then flows back through the whole pipeline so you can verify convergence.

---

## 4. Hands-on: run the first evidence command

**▶ Do this now — step 1 on a healthy app** (`source ~/argo-lab-env.sh` first):

```bash
argocd app get hello-reconcile
```

**🔍 Notice** the fields the method reads: the **Source** block (repo, revision, path), the two **status lines** (`Sync Status`, `Health Status`), and — when something is wrong — a **`CONDITION` block** naming the cause in plain text. On a healthy app there is no condition.

**▶ Do this now — confirm the source resolves (step 1's second half):**

```bash
git ls-remote http://localhost:3000/course/storefront-gitops.git main
```

**Expected** — a commit hash next to `refs/heads/main`:

```text
a0ec06895cf47505add1e1c37d7e691d88287ff8	refs/heads/main
```

**🔍 Notice:** a healthy source answers with a hash. In Module 2 you see what this same command prints when the source is *unreachable* — and why reading that difference correctly saves a production workload.

---

## 5. Quick Check

**S7-QC1 — Order the evidence, and spot the skipped step.** A single app is stuck `OutOfSync`. A teammate says: *"I already restarted the repo-server twice and it didn't help."* What is the correct **first** step, and what did they skip?

<details>
<summary>Show answer</summary>

The first step is **Step 1 — validate the Git source and revision** (`argocd app get`, then `git ls-remote`). Your teammate jumped to a **Step 5** action (restarting a component) without steps 1–4 — violating **evidence before change** *and* **source before platform**. Restarting the repo-server helps only if steps 1–4 *implicated* it; nothing had, which is why it "didn't help." Walk 1 → 2 → 3 and stop at the first lie: for a single-app `OutOfSync`, step 3 (`argocd app diff`, exit code **1**) usually shows the real difference, and the fix is in Git (step 6).
</details>

---

## 6. Key takeaways

- **Walk the pipeline in the direction the data flows, and stop at the first step that lies.** Six steps: source → render → compare → sync/health → component → correct-and-verify.
- **Each step names one component — find the step and you have found the pod.** Localization, not just diagnosis.
- **Evidence before change, source before platform.** Your first destructive action should be the fix.

**→ Next:** [02 — One incident, all six steps](02-worked-incident.md)
