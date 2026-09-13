# Capstone · Module 4 — P0–P1: Brief and Triage

> **Day 2 · Capstone · Module 4 of 6 · work at 0:00–0:25**
> **Goal:** get oriented (P0), then build a complete, evidence-backed triage grid — changing nothing (P1).

The capstone is one continuous exercise in five phases. The hints are about the **method**, never a specific fault.

| Phase | Minutes | Clock | You produce |
|---|---|---|---|
| **P0** brief + first move | 10 | 0:00–0:10 | workspace, incident-start SHAs, written first move |
| **P1** triage, no changes | 15 | 0:10–0:25 | triage grid + layer coverage; Checkpoint C1 |
| **P2** restore | 50 | 0:25–1:15 | change log; each layer's sanity check passing |
| **P3** verify | 5 | 1:15–1:20 | `capstone-check.sh` output; comparison with SS-CAP-02 |
| **P4** reflection | 10 | 1:20–1:30 | one reflection block per fault |

---

## P0 — Incident brief and your first move (10 min · easy)

**Goal.** Get oriented: read the rules, set up your workspace, and commit *in writing* to the first thing you will look at and what you expect it to tell you.

**Do this:**
1. Complete [module 02](02-setup-and-rules.md): tools, workspace, and a first look at the Applications page.
2. Skim [module 03](03-evidence-toolbox.md): the toolbox headings.
3. In `incident-log.md`, under "P0: my first diagnostic action", write **one** command or screen you will look at first, and **what you expect to learn** — at least two different results it could show, and what each would mean.
4. **Do not run your first move yet** — you run it as the first action of P1.

**The shape of a good output.** A strong first move **partitions** the problem: whatever it shows, it rules out a large part of the platform at once (e.g. separates "one Application" from "many", or "Argo CD" from "Kubernetes"). A weak first move can only confirm a hunch.

**Success criterion:** `~/capstone` holds four clones and `incident-start-shas.txt`; `argocd account get-user-info` shows you as `admin`; your first-move entry names one command/screen and ≥2 possible results with meanings.

**Hints:**
- *Hint 1:* Ask whether the trouble is in one Application, a group, or everywhere — what would each imply about shared dependencies?
- *Hint 2:* Prefer a view showing several kinds of information at once (source, revision, both statuses, conditions) over one showing a single fact.

---

## P1 — Triage: build the grid, change nothing (15 min · medium)

**Goal.** Build a complete, evidence-backed picture: every symptom, where you saw it, which method step first showed it, which layer you believe it lives in, and a hypothesis. **Change nothing.**

**The rule for this phase:** only read-only commands from [module 03](03-evidence-toolbox.md), plus Refresh/hard-refresh. No commits, applies, syncs, or deletes.

**Do this:**
1. **Run your first move.** Under "What I actually saw", write one line on what matched your prediction and what did not.
2. **Take the whole picture** (§0). Add a grid row for each Application not both `Synced` and `Healthy`, and for anything else that looks wrong (a cluster, repo, ApplicationSet, component). One row may cover several apps sharing a symptom — list them all.
3. **Walk the six steps for each row** and stop at the first step that lies. Record that step and your layer.
4. **Fill in layer coverage.** For each of the six layers, write the evidence you checked and a verdict: *looks healthy*, *looks broken*, or *cannot tell yet* (and why).
5. **Apply the masking question** to every *cannot tell yet* and every hypothesis. Write down which rows depend on something unconfirmed.
6. **Plan, do not act.** For each row, write the controlled change you would make (its path from [module 02 §6](02-setup-and-rules.md), and the verification evidence).

Your triage grid (add rows as needed):

| # | Symptom (as observed) | Where observed | Step (1-6) | Layer | Hypothesis | Planned controlled change |
|---|---|---|---|---|---|---|
| S1 | | | | | | |
| S2 | | | | | | |
| ... | | | | | | |

Your layer coverage table:

| Layer | Evidence I checked | Verdict (healthy / broken / cannot tell yet, and why) |
|---|---|---|
| `PLAT` argo cd platform components | | |
| `CONN` workload cluster connectivity | | |
| `SRC` application source rendering | | |
| `GEN` application generation and ownership | | |
| `POL` deployment policy (permissions) | | |
| `RUN` workload runtime health | | |

**The shape of a correct result.** Every row cites a re-runnable command or a named screen. All six layers have a verdict. Every hypothesis says something *testable* (what else would be true if it were right). Several rows may share a layer, and some layers may honestly read *cannot tell yet* — that is a sign of good triage, not failure.

---

## Checkpoint C1 — grid complete, no changes made

Before P2, confirm all five:

1. Every Application not both `Synced`/`Healthy` appears in ≥1 row.
2. Every row has evidence and a layer.
3. Every layer in the coverage table has a verdict.
4. You ran nothing outside [module 03](03-evidence-toolbox.md), apart from Refresh/hard-refresh.
5. **Git is unchanged** since the incident started:

```bash
cd ~/capstone
for repo in storefront-gitops platform-config platform-components team-a-apps; do
  printf '%-20s %s\n' "${repo}" "$(git -C "${repo}" ls-remote origin refs/heads/main | awk '{print $1}')"
done | diff - incident-start-shas.txt && echo "C1 check: main is unchanged in every repository"
```

**Expected:** the single line `C1 check: main is unchanged in every repository`. Any other output means `main` moved somewhere.

If C1 fails because you already made a change, record it honestly in your change log (time, what, why), then read the "You made an uncontrolled change" row in [module 06](06-troubleshooting-completion-close.md).

**Hints (method-level):**
- *Hint 1:* Which layer has no evidence yet? Run the cheapest command for it in [module 03](03-evidence-toolbox.md).
- *Hint 2:* Could any symptom be a shadow of another? Mark rows whose evidence depends on an unconfirmed box in the masking chain.
- *Hint 3:* For a symptom that fits two layers, ask what single piece of evidence tells them apart — and go get exactly that.

**→ Next:** [05 — P2–P4: restore, verify, reflect](05-restore-verify-reflect.md)
