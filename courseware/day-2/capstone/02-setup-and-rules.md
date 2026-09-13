# Capstone · Module 2 — Setup and Rules of Engagement

> **Day 2 · Capstone · Module 2 of 6 · read in P0**
> **Goal:** confirm your tools, build your incident workspace, and learn the rules — the only ways you may change anything.

---

## 1. What your platform looked like before the incident (known-good inventory)

When Lab 5 ended, your platform was at checkpoint **`CP-capstone`**, containing:

- **Eight Applications, all `Synced`/`Healthy`:** the three from the `storefront` ApplicationSet (`storefront-dev-workload`, `-staging-`, `-prod-`); the App-of-Apps root `platform-root` and its children `platform-quotas`, `platform-netpol`, `platform-agent`; and `team-a-guestbook`.
- **One ApplicationSet:** `storefront`.
- **Four AppProjects:** `storefront`, `platform`, `team-a`, `default`.
- **Two registered clusters:** `workload`, `in-cluster`.
- **One Argo CD RBAC grant:** `role:team-a` bound to `team-a-dev`.

This is your **known-good inventory** and your restoration target.

> **In every other lab you run the verifier here. Not today.** Once the incident has started, `reset-lab.sh --verify-only` compares against a stored answer — and a real incident has no answer key. It is off limits (Section 3).

The incident contains **seven faults**, in more than one layer, some connected. That is all this guide will say about them. Wait for your instructor's go-ahead; the 90-minute clock then starts.

---

## 2. Confirm your tools work (these say nothing about the platform's health)

```bash
source ~/argo-lab-env.sh
argocd login localhost:8443 --username admin --password "$(cat ~/course/credentials/argocd-admin.txt)" --insecure
argocd account get-user-info        # expect: Logged In: true, Username: admin
kubectl config get-contexts -o name  # expect: k3d-mgmt and k3d-workload
export HISTTIMEFORMAT='%F %T  '      # turn your shell history into a timeline
```

---

## 3. Build your incident workspace

Make fresh clones (the first line caches your Gitea password in memory for two hours; username `student`, password in `~/course/credentials/gitea-student.txt`):

```bash
git config --global credential.helper 'cache --timeout=7200'
mkdir -p ~/capstone && cd ~/capstone
for repo in storefront-gitops platform-config platform-components team-a-apps; do
  git clone -q "http://lab-gitea:3000/course/${repo}.git"
  git -C "${repo}" config user.name "Student"
  git -C "${repo}" config user.email "student@lab.local"
done
```

Record the exact commit each repo's `main` pointed at when the incident started (Checkpoint C1 compares against this):

```bash
cd ~/capstone
for repo in storefront-gitops platform-config platform-components team-a-apps; do
  printf '%-20s %s\n' "${repo}" "$(git -C "${repo}" rev-parse HEAD)"
done | tee ~/capstone/incident-start-shas.txt
```

Create your **incident log** — one Markdown file for every table and answer:

```bash
cat > ~/capstone/incident-log.md <<'EOF'
# Incident log: capstone

## Incident-start SHAs
(paste ~/capstone/incident-start-shas.txt here)

## P0: my first diagnostic action
- Command or screen:
- What I expect to learn (>=2 possible results, and what each would mean):
- What I actually saw (fill in at the start of P1):

## P1: triage grid
| # | Symptom (as observed) | Where observed | Step (1-6) | Layer | Hypothesis | Planned controlled change |
|---|---|---|---|---|---|---|
| S1 | | | | | | |

## P1: layer coverage
| Layer | Evidence I checked | Verdict (healthy / broken / cannot tell yet, and why) |
|---|---|---|
| PLAT | | |
| CONN | | |
| SRC | | |
| GEN | | |
| POL | | |
| RUN | | |

## P2: change log
| # | Time | Change (SHA or command) | Path | Why (grid rows) | Evidence before | Predicted | Evidence after |
|---|---|---|---|---|---|---|---|
| C1 | | | | | | | |

## P3: verification
(paste capstone-check.sh output here)

## P4: reflection
EOF
```

Open it with `nano ~/capstone/incident-log.md` or the desktop editor.

---

## 4. The incident-start picture

Open the UI at `https://localhost:8443` — the **Applications** page is the platform at the moment the incident started.

![Argo CD Applications list at the start of the capstone incident (v3.5.2)](../../assets/screenshots/day-2/capstone-01-incident-start.png)

*Figure SS-CAP-01 — The only picture of the broken platform in this guide. Everything else, you find yourself.*

**Ask of the picture (these are questions, not answers):** read each tile's **two badges** separately; look for **patterns across tiles** (a shared repository, cluster, project, or writer — a shared symptom points at a shared dependency); compare the tiles with your **known-good inventory**; and remember a badge tells you *that* something is wrong, never *why*. Trust your own screen over the figure (statuses keep moving; this lab reconciles every 60 seconds).

<!-- CAPTURE-SPEC: SS-CAP-01 — Applications list at incident start. State: CP-capstone + injected faults. No highlight (participants read it themselves). Argo CD v3.5.2. -->

---

## 5. Rules of engagement

A change is **controlled** when all four are true: (1) justified by a triage-grid row; (2) made through one of the four change paths (Section 6); (3) its predicted, observable result written down *first*; (4) recorded in your change log, with evidence before and after. Anything else is **uncontrolled** — and off limits:

| Off limits | Why |
|---|---|
| Editing/patching/scaling/deleting live objects Argo CD manages (`kubectl edit/patch/scale/delete`, UI live-manifest edits) | Argo CD may revert you, and you destroy the evidence (Lab 3) |
| Restarting/deleting pods or `kubectl rollout restart` "to see what happens" | A restart is an intervention, not a diagnosis (Session 7) |
| Removing finalizers by hand | Skips Argo CD's clean-up; can orphan resources (Lab 5) |
| Force-pushing, `git reset` on `main`, rewriting history | Git is your audit trail — undo with `git revert` (Lab 4) |
| **Widening** a guardrail (AppProject, Argo CD RBAC, K8s RBAC) beyond its Lab 2/5 design | Trades an outage for a security hole. *Restoring* a guardrail to its designed state is allowed; loosening past it is not (Session 6) |
| Hiding evidence: turning off auto-sync/self-heal to stop a symptom, or a whole-resource / no-owner ignore rule | Silence is not repair (Session 7) |
| Running `reset-lab.sh` in any form; opening the course tooling's scripts/state; using `cp-*` tags | These are the scaffolding and answer key. `reset-lab.sh` without `--verify-only` also erases the whole incident |
| Running `capstone-check.sh` before Phase P3 | It is the scoreboard, not an instrument |

**Always allowed:** every read-only command in [module 03](03-evidence-toolbox.md), plus Refresh and hard refresh (note in your grid when you hard-refresh — it discards cached rendering).

**Deletions** are controlled only if you first write down what they remove: the Application object alone (`--cascade=false`), or the object **and** every managed resource (the default). A delete can also arrive through Git (a root pruning a removed child file) — make the same written cascade decision first.

**Credentials stay hidden** — never print, commit, or paste a token/password. Inject at apply time as Lab 2 taught.

---

## 6. Controlled change paths — the only four ways to change anything

| Path | Use for | How | Log |
|---|---|---|---|
| **A. Git commit to the owning repo** | anything Argo CD reconciles from Git (charts, values, env files, Application manifests a root syncs) | edit in your `~/capstone` clone, `git commit`, `git push`; undo with `git revert <sha>` + push | the commit SHA |
| **B. Argo CD's own configuration** | settings in `platform-config/argocd/values.yaml` | edit/commit/push, then `apply-argocd-config.sh` (Lab 5) | SHA + wrapper finish time |
| **C. A declarative file applied with `kubectl`** | objects the platform team applies (AppProjects, top-level Applications/ApplicationSets, repo/cluster Secrets from templates, workload RBAC) | `kubectl --context <ctx> apply -f <file>` from a clone (commit/push first) or `~/course/lab-files/`, credentials injected at apply time | file path + SHA if in Git |
| **D. A deliberate Argo CD operation** | a sync, or a delete with a written cascade decision | `argocd app sync <app>`; `argocd app delete <app> --cascade=<true|false>` | the exact command |

**Which path a repair needs depends on which object owns the field** (Lab 4). Find the owner first; the path follows. Some objects are reconciled from Git by Argo CD; others are applied by the platform team and change only when someone applies them. [Module 03 §GEN](03-evidence-toolbox.md) shows how to tell which is which.

**→ Next:** [03 — The evidence toolbox](03-evidence-toolbox.md)
