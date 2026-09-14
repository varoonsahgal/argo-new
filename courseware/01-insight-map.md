# Insight Map — Intermediate Argo CD Operations

> **Status:** Internal build-planning document (Phase 2). **Not a classroom deliverable.**
> **Author role:** Insight Generator. **Consumer:** `lab-engineer` (Phase 4), with `screenshot-capture` and `visual-teaching` as secondary consumers.
> **Upstream:** [`argo-cd-outline.md`](../argo-cd-outline.md) (scope) and [`courseware/00-course-blueprint.md`](00-course-blueprint.md) (architecture).
> **Pinned target:** Argo CD **`v3.5.2`**, Helm chart **`10.8.4`**, Kubernetes **`v1.34`**, k3d/k3s (blueprint §8.3).

---

## How to use this document

This is **a menu, not a mandate.** It contains more ideas than any guide should use. `lab-engineer` picks the ones that serve the file's stated learning objective and drops the rest. An insight that does not reinforce the objective is decoration, and decoration costs minutes the blueprint's timing does not have.

**Three rules for the authoring agent:**

1. **Do not invent competing frameworks.** Two structural anchors are fixed by blueprint §7: S7's **6-step repeatable troubleshooting method** (the spine of Lab 3, Lab 4, and the Capstone) and S5's **"Choosing the Right Pattern" decision table** (the spine of Lab 4). Every insight below either feeds one of those or stands alone — none replaces them.
2. **Labs are weighted heavier on purpose.** For Lab 1–5 and the Capstone, the lab guide is the *only* explanation a participant gets for that hands-on concept. Those sections carry the strongest analogies and the sharpest "aha" moments.
3. **Never trade accuracy for catchiness.** Every one-liner below is written to survive a participant repeating it to a colleague who knows Argo CD well. If a phrasing has to be softened to stay true, soften it.

**Insight ID convention:** `I-<session>-<nn>` (e.g. `I-S4-02`, `I-L3-05`, `I-CAP-04`). Guides can cite these in review artifacts so reviewers can trace an explanation back to its source.

**Category tags used below:** `STICKY` (sticky explanation) · `VISUAL` (visual revelation) · `COUNTER` (counterintuitive result) · `TRADE-OFF` (engineering trade-off) · `FAILURE` (failure story) · `MODERN` (modern platform-engineering connection). **Key takeaways** get their own block at the end of each session.

---

## Verification method and its limits — read before trusting any version claim

**Verification pass date: 2026-09-10.** Method: `WebSearch` restricted to primary sources (`argo-cd.readthedocs.io`, `github.com/argoproj/*`, `blog.argoproj.io`).

**Stated limitation, so nobody over-trusts this file:** direct page fetch (`WebFetch`) was **blocked in the authoring sandbox for every domain attempted**, including `argo-cd.readthedocs.io`, `raw.githubusercontent.com`, and `github.com`. Every claim below marked "verified" was therefore verified from a **search engine's summary of a primary-source page**, not from reading the page directly. That is strong enough to plan content around and **not** strong enough to ship a CLI flag or a UI path on. The blueprint §12 checklist still owns final confirmation, and §12 already assigns those items to `lab-engineer` and `environment-engineer`.

**A second, sharper caveat about doc URLs.** Most search hits resolved to `/en/stable/` or `/en/latest/`, not `/en/release-3.5/`. At the time of this pass `stable` should track the **3.5 line** (blueprint §8.3 verified `v3.5.2` as current stable), so `/stable/` claims are very likely correct for the pin. **`/latest/` tracks `master` and can document behavior that has not shipped in `v3.5.2`.** Anything below sourced only from `/latest/` is flagged.

**Everything requiring a primary-source re-check is collected in [§ Unverified and flagged claims](#unverified-and-flagged-claims-route-to-technical-source-check) at the end of this file.** Route that list to `technical-source-check`.

---

## Course-wide through-lines

Four ideas must be introduced early and then *re-earned* in a new context in every later file. They are the retrieval spine the blueprint asks for (§4). Every session below reinforces at least one.

| Through-line | Introduced | Re-earned in |
|---|---|---|
| **Two independent questions:** sync = "does it match Git?", health = "is it working?" | S2 | Lab 1, Lab 3, Lab 4, Capstone |
| **Three states:** desired (Git) → rendered (manifests) → live (cluster) | S2 | Lab 1, S4, Lab 3, S7, Capstone |
| **One verb per component** — naming the verb names the suspect | S2 | Lab 1, S7, Capstone |
| **Ownership:** who owns this field decides where the fix goes | S2 | S4, S5, Lab 4, S6, Capstone |

---

## S1 — GitOps and the Argo CD topology
**File:** `courseware/day-1/01-gitops-and-topology.md` · Concept · 45 min · Objective 1

#### I-S1-01 · The thermostat, not the light switch `STICKY`
- **Insight:** `kubectl apply` is a light switch — it happens once, and after that the room is on its own. Argo CD is a thermostat — it holds a target and keeps checking, forever. Nothing about a thermostat is "a deployment"; it is a *standing instruction*.
- **Why it is useful:** It converts "continuous reconciliation" from a phrase into a machine participants already own a mental model for, and it pre-loads drift, self-heal, and the 3-minute polling interval without naming any of them yet.
- **Best delivery moment:** The first 5 minutes, before the word "reconciliation" is used at all. Teach intuition before terminology (CLAUDE.md).
- **Visual / activity:** The reconciliation-loop diagram (blueprint §11) drawn *as a thermostat loop* first — read target, read actual, act, repeat — then relabeled with Argo CD's vocabulary in a second pass of the same diagram.
- **Source / verification:** Analogy, not a product claim. No verification needed.

#### I-S1-02 · Argo CD does not deploy your code — it deploys your repository `COUNTER`
- **Insight:** Argo CD never talks to your CI system, never sees your build, and never knows a pipeline ran. The handoff between CI and CD is a **commit**: CI builds an artifact and writes a new version into a Git repo; Argo CD notices the repo changed. That is the entire integration surface.
- **Why it is useful:** It settles the outline's "division of responsibility between CI and Argo CD" in one sentence and prevents the persistent expectation that Argo CD should "trigger on a build."
- **Best delivery moment:** Immediately after the thermostat analogy, as the first hard boundary of the session.
- **Visual / activity:** A two-box diagram with the *only* connecting arrow being a commit. Ask: "draw the line where CI stops." Most participants draw it too far right.
- **Source / verification:** Architectural framing consistent with Argo CD's pull model. No version-specific claim.

#### I-S1-03 · The pull model's real payoff is a credential that no longer exists `MODERN`
- **Insight:** In push CD, the CI system holds cluster-admin credentials for every environment, which means the highest-privilege secret in the company lives in the most-integrated, most-extended, most-plugin-laden system in the company. In pull CD, that credential does not exist: the cluster reaches out, and CI's blast radius shrinks to "can write to a Git repo."
- **Why it is useful:** It is the honest, non-hype reason platform teams adopt GitOps, and it lands with a security-aware audience far better than "declarative is nicer."
- **Best delivery moment:** When introducing the management-cluster/workload-cluster topology — it explains *why* the topology is shaped that way.
- **Visual / activity:** Topology diagram (blueprint §11) drawn twice: push (arrows from CI into every cluster) vs pull (arrows from each cluster out to Git). The arrow-direction flip is the whole argument.
- **Accuracy caveat:** Do not overstate — Argo CD's own management cluster still holds credentials to every workload cluster. The risk **moves and concentrates**; it does not vanish. Say this explicitly (it sets up I-S1-05).
- **Source / verification:** General architectural property of pull-based CD. No version claim.

#### I-S1-04 · Argo CD is a state engine; Argo Workflows is a step engine `STICKY` `MODERN`
- **Insight:** Argo CD's job never finishes — it describes a *state* the cluster should be in and keeps converging on it. Argo Workflows describes a *sequence of steps* that runs, completes, and stops. "Deploy this app" is a state. "Run these ten data-processing steps in this order" is a workflow.
- **Why it is useful:** It answers the ecosystem question cleanly and closes it, which is exactly what the outline asks for.
- **Best delivery moment:** A **~2-minute sidebar box**, per blueprint §5.3 (S1 · OPTIONAL). Hard stop.
- **Accuracy caveat:** Blueprint §5.3 and CLAUDE.md both cap this. **Do not** expand into a Workflows lesson, do not compare feature lists, do not mention Argo Events/Rollouts here.
- **Source / verification:** Project-positioning claim, stable across versions. No `v3.5.2`-specific detail needed.

#### I-S1-05 · The management cluster is the most security-sensitive cluster you own `STICKY`
- **Insight:** The Argo CD management cluster holds working credentials to every workload cluster it manages. It is not "the cluster where the deployment tool lives" — it is the cluster from which every other cluster can be changed. Its blast radius is the union of all of them.
- **Why it is useful:** It motivates the whole of S3 (least-privilege registration), S6 (guardrails), and S7 (backup/recovery) before any of them is taught, and it stops the management cluster from being treated as low-stakes infrastructure.
- **Best delivery moment:** As the closing beat of the topology section, right after the two-cluster diagram is on screen.
- **Visual / activity:** On the topology diagram, shade the management cluster and label the shading "everything reachable from here." Prediction question: "If exactly one of these clusters is compromised, which one hurts most?"
- **Source / verification:** Architectural reasoning, not a product claim.

#### I-S1-06 · Three minutes of nothing is normal `COUNTER`
- **Insight:** By default Argo CD polls repositories on a timer rather than reacting instantly. The default reconciliation timeout is **`180s` (3 minutes)**, set by `timeout.reconciliation` in the `argocd-cm` ConfigMap. Webhooks exist specifically to remove that delay; setting the value to `0` disables automatic polling entirely, leaving only webhooks and manual syncs.
- **Why it is useful:** It pre-empts the single most common "is it broken?" moment in Lab 1, and it makes the webhooks-vs-polling trade-off in S3 concrete instead of abstract.
- **Best delivery moment:** At the end of the end-to-end deployment-flow walkthrough, as the answer to "how fast is this?"
- **Visual / activity:** Add a labeled clock to the reconciliation-loop diagram at the "detect change" edge.
- **Accuracy caveat:** `180s` is the **default**, and it is the interval at which an application is *refreshed*, not a guaranteed sync latency. A classroom environment may have it tuned; state the value the environment actually ships (`environment-engineer` owns that number).
- **Source / verification:** ✅ Verified 2026-09-10 via search summaries of `argo-cd.readthedocs.io` FAQ and Webhook Configuration pages: default polling interval 3 minutes, controlled by `timeout.reconciliation` in `argocd-cm`, `0` disables polling. Holds for the 3.5 line (`/stable/`). **Re-confirm the value against the pinned instance** — this is a number participants will see on a stopwatch.

### Key takeaways — S1

> **"Git is the source of truth; the live cluster is just today's rendering of it."**
>
> **"CI proves the artifact is good. Argo CD proves the cluster matches the approved answer. The only thing that crosses between them is a commit."**
>
> **"Argo CD is a thermostat, not a light switch. `kubectl apply` happens once; reconciliation never stops."**
>
> **"Nobody deploys to the cluster. Everybody commits to Git, and the cluster catches up."**
>
> **"The management cluster can change every cluster it manages. Treat it as the most sensitive cluster you own, because it is."**

---

## S2 — Argo CD architecture and the Application model
**File:** `courseware/day-1/02-architecture-and-application-model.md` · Concept · 60 min · Objectives 1, 2, 4

> **Scope guard (blueprint §5.3):** teach each component only to the depth Lab 1 needs. Controller sharding, reconciliation-queue internals, and repo-server tuning are **MOVED to S7** — cross-reference forward, do not pre-teach.

#### I-S2-01 · One verb per component — name the verb, name the suspect `STICKY` `VISUAL`
- **Insight:** Give each component exactly one verb and the architecture becomes memorable in a single pass:
  - **repo-server — *renders.*** Git in, plain Kubernetes YAML out. It never talks to a workload cluster.
  - **application-controller — *compares and applies.*** It is the only component that touches a workload cluster.
  - **API server — *talks.*** UI, CLI, API, authentication. It does not deploy anything.
  - **ApplicationSet controller — *writes Applications.*** It never touches a workload.
  - **Redis — *remembers.*** A cache. Deleting it costs performance, not data.
  - **Dex (optional) — *identifies.*** SSO only.
- **Why it is useful:** It converts "six components" from a memorization task into a diagnostic tool, and it is the direct ancestor of S7's troubleshooting method, where each step maps to one component. This is the highest-leverage sentence in the session.
- **Best delivery moment:** Immediately, as the component list is introduced — *before* any component's internals.
- **Visual / activity:** Component diagram where each box carries only its verb, then a matching exercise: six symptoms, six components, draw the lines. ("Manifests are stale" → renders. "App is stuck Progressing" → compares/applies. "I can't log in" → talks.)
- **Accuracy caveat:** These are deliberate simplifications for teaching order. Note in a progressive-disclosure box that the API server also serves the repo/cluster configuration surface and that Dex is optional (many installs use an external OIDC provider directly).
- **Source / verification:** Component roles are stable across the 3.x line. No `v3.5.2`-specific flag claimed.

#### I-S2-02 · Two questions, two independent axes `STICKY` `VISUAL`
- **Insight:** Sync status and health status are not two grades of the same thing. **Sync status compares rendered manifests against live state — it is a statement about Git.** **Health status looks only at live state — it is a statement about whether the thing works.** They are independent, which produces four real quadrants:
  - `Synced` + `Healthy` — the boring, correct state.
  - `Synced` + `Degraded` — **you deployed exactly what you asked for, and what you asked for is broken.** Git is the problem.
  - `OutOfSync` + `Healthy` — the app is serving users fine; it just isn't what Git says. Usually drift or an unsynced commit. **Not an outage.**
  - `OutOfSync` + `Degraded` — broken *and* adrift; establish which came first.
- **Why it is useful:** This is the single most-reused distinction in the course and the source of the two biggest misconceptions the course must break ("OutOfSync means broken" and "Synced means healthy"). Teaching it as a 2×2 makes both misconceptions structurally impossible to hold.
- **Best delivery moment:** The centerpiece of the session. Everything before it is setup; everything after it is application.
- **Visual / screenshot:** The state-triangle diagram (blueprint §11) *plus* **SS-02-02** (summary header showing Sync Status and Health side by side). Then a 2×2 grid with one real scenario written into each cell.
- **Activity:** Quick Check in the blueprint §10 shape: "Given `OutOfSync` + `Healthy`, is the app broken? Who is currently affected?" (Correct answer to the second question: nobody.)
- **Source / verification:** Core Argo CD semantics, stable across 3.x. Exact badge wording to be confirmed against the pinned instance during screenshot capture.

#### I-S2-03 · Health is computed per resource and is *not* inherited from grandchildren `COUNTER`
- **Insight:** An Application's health is the **worst health among its immediate child resources** — and a resource's own health is calculated **using only information about that resource itself**, never inherited up from its children. The documented priority, most to least healthy, is: `Healthy` → `Suspended` → `Progressing` → `Missing` → `Degraded` → `Unknown`.
- **Why it is useful:** It explains a class of confusing observations exactly ("why did the tree go red *there* and not *there*?") and it is the mechanical reason custom health checks exist for CRDs. It also sets up S7's custom-health-check topic honestly.
- **Best delivery moment:** Right after the resource-tree screenshot, when participants can see the hierarchy the rule applies to.
- **Visual / screenshot:** **SS-02-01** (resource tree). Annotate which nodes contribute to the Application's rolled-up status and which do not.
- **Accuracy caveat:** Do **not** simplify this to "a crashing Pod won't show up." A crash-looping Pod normally *does* surface, because the Deployment's own status reflects unavailable replicas. The accurate statement is about **mechanism and timing**: health propagates through each resource's own status, so there can be a lag, and a resource type with no health check (or a wrong custom one) breaks the chain.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `argo-cd.readthedocs.io/en/stable/operator-manual/health/`: "App health is inferred from the health of its immediate child resources"; "The health of a resource is not inherited from child resources — it is calculated using only information about the resource itself"; priority order as listed. `/stable/` ≈ 3.5 line. **Re-confirm the priority order verbatim** before it appears in a guide.

#### I-S2-04 · The Application is an address, not an artifact `STICKY`
- **Insight:** An Application manifest contains **no workload YAML at all**. It is a small set of addressing fields — which repo, which revision, which path or chart, which destination cluster and namespace, which project, and what sync policy. Everything a user actually cares about is somewhere else, referenced by those fields.
- **Why it is useful:** It reframes "reading an Application" as "reading a set of pointers to things that can each fail independently," which is precisely the skill Lab 1's first exercise tests and precisely the mental model the Capstone requires.
- **Best delivery moment:** As the Application anatomy is introduced, before walking any individual field.
- **Visual / activity:** Show the manifest with each addressing field drawn as an arrow leaving the box toward the external thing it names. Every arrow is a future failure mode.
- **Source / verification:** Structural, stable. Field names (`source`, `destination`, `project`, `syncPolicy`) to be confirmed against the 3.5 Application specification reference by `lab-engineer`.

#### I-S2-05 · Refresh compares again; hard refresh forgets first `COUNTER`
- **Insight:** A normal **refresh** re-runs the comparison. A **hard refresh** additionally discards the cached rendered manifests, forcing the repo-server to render from scratch. That is the practical difference: if Argo CD is not noticing something you changed in the repository, a plain refresh will faithfully re-compare *the stale rendering*.
- **Why it is useful:** It is the resolution to a very common dead end ("I pressed Refresh five times and nothing changed") and it makes caching visible as a real part of the system rather than an invisible optimization.
- **Best delivery moment:** When teaching the refresh → compare → reconcile → sync operations, as the distinction between the first two.
- **Visual / activity:** Add the manifest cache to the reconciliation-loop diagram as an explicit box between repo-server and controller, with refresh and hard-refresh drawn as two different arrows.
- **Accuracy caveat:** Hard refresh is a diagnostic tool, not a habit — it forces re-rendering and, at scale, that is real load on the repo-server. Say so.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `argo-cd.readthedocs.io/en/stable/user-guide/diff-strategies/`: "`--hard-refresh` refreshes application data as well as target manifests cache," and diff results are re-computed on refresh/hard-refresh, a new repo revision, an Application spec change, or a live resource version change. **Confirm the exact CLI flag and UI menu label at 3.5.**

#### I-S2-06 · Redis is disposable — if you are backing it up, you are backing up the wrong thing `COUNTER`
- **Insight:** Argo CD is largely stateless. Its real state is Kubernetes objects (Applications, AppProjects, ApplicationSets, ConfigMaps, Secrets) persisted in the cluster's etcd. **Redis is only a cache and can be safely rebuilt without service disruption.**
- **Why it is useful:** It corrects a genuinely common operator instinct, and it plants the seed for S7's backup/recovery section a full day early — which is exactly the spaced-reinforcement pattern the blueprint asks for.
- **Best delivery moment:** As a one-paragraph beat when Redis is named in the component list, with an explicit forward pointer: "we will spend real time on this in Session 7."
- **Visual / activity:** Colour the component diagram by persistence: one colour for "state lives here," another for "cache."
- **Accuracy caveat:** "Disposable" means *no data loss*, not *no impact*. Losing Redis causes a rebuild that costs CPU and latency across every application. Do not let participants conclude Redis is unimportant in production — that is why HA installs run Redis in HA mode.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/`: "Argo CD is largely stateless. All data is persisted as Kubernetes objects, which in turn is stored in Kubernetes' etcd. Redis is only used as a disposable cache and can be safely rebuilt without service disruption."

#### I-S2-07 · Argo CD only sees what it owns `STICKY`
- **Insight:** Argo CD tracks the resources it created and ignores everything else in the namespace. A hand-made Deployment sitting next to a managed one is not "extra" and not "drift" — as far as Argo CD is concerned, it does not exist.
- **Why it is useful:** It defines ownership as a real boundary rather than a vague concept, and it sets up three later topics precisely: pruning (S4), App-of-Apps ownership (S5), and the Capstone's ownership fault.
- **Best delivery moment:** With the resource tree on screen — "everything you can see here is owned; the interesting question is what is in this namespace that you *cannot* see here."
- **Visual / activity:** Side-by-side: `kubectl get deploy -n <ns>` output vs the Argo CD tree, with the unmanaged resource circled in the terminal and absent from the tree.
- **Accuracy caveat:** The mechanism (resource-tracking method — annotation vs label) is an **OPTIONAL progressive-disclosure box** per blueprint §5.3. Teach the *behaviour* in the main flow; keep the mechanism in the box.
- **Source / verification:** Behavioural claim, stable. Tracking-method default at 3.5 to be confirmed by `lab-engineer` if the box ships.

### Key takeaways — S2

> **"Sync status asks 'does it match Git?' Health status asks 'is it actually working?' A resource can answer yes to one and no to the other."**
>
> **"`Synced` and `Degraded` at the same time means you deployed exactly what you asked for — and what you asked for is broken. The bug is in Git."**
>
> **"Every Argo CD component has exactly one verb. Name the verb and you have named the suspect."**
>
> **"An Application is an address, not an artifact. Every field in it points at something that can fail on its own."**
>
> **"Redis is a cache, not a database. If you are backing up Redis, you are backing up the wrong thing."**

---

## Lab 1 — Follow an application through reconciliation
**File:** `courseware/day-1/lab-01-follow-an-application-through-reconciliation.md` · Lab · **HEAVY** scaffolding · 45 min · Objectives 1, 2, 4

> **Weighting note:** this is the course's first hands-on file and the proof of S1+S2. Scaffolding is maximal (exact clicks, exact commands, a screenshot at every meaningful step). The insights below are chosen so that *observation* does the teaching — this lab changes almost nothing and explains almost everything.

#### I-L1-01 · Circle every external dependency — each circle is a future incident `STICKY` `VISUAL`
- **Insight:** Open the `helm-guestbook` Application manifest and mark every field that points at something outside the manifest: the Git server, the revision, the chart/path, the destination cluster credential, the destination namespace, the AppProject. That is a complete list of everything that can break this application from the outside — and it is short enough to hold in your head.
- **Why it is useful:** It is the outline's own first bullet ("identify every external dependency") turned into a produced artifact, and that artifact is reusable: the Capstone's fault list maps almost one-to-one onto those circles.
- **Best delivery moment:** The lab's opening exercise, before anything is changed. It costs 5 minutes and repays them all day.
- **Visual / activity:** **SS-L1-02** (Application manifest view). Participants annotate a printed/pasted copy, then compare their list against the field-by-field walkthrough. Close the loop out loud: "Git server unreachable → which circle? Bad revision → which circle? Cluster credential expired → which circle?"
- **Source / verification:** Pedagogical framing over the Application spec. Field names to match the 3.5 Application specification reference.

#### I-L1-02 · Predict all three, not just the end state `STICKY`
- **Insight:** Before committing the change, participants write down three predictions, not one: (a) what the **sync status** will be within 3 minutes, (b) what the **health status** will be *during* the sync, (c) what health will be *after*. The one almost everyone gets wrong is (b) — people forget health passes through `Progressing` and expect it to stay `Healthy` throughout.
- **Why it is useful:** Predicting the transient state is what forces the two-axis model (I-S2-02) to become operational rather than recited. Getting (b) wrong is more instructive than getting all three right.
- **Best delivery moment:** Immediately before the commit — the blueprint's "Predict Before You Sync" pattern, in its highest-value placement in the whole course.
- **Visual / screenshot:** **SS-L1-03** (diff panel, now `OutOfSync`) then **SS-L1-04** (`Progressing` → `Synced`/`Healthy`). The two screenshots side by side *are* the answer to the prediction.
- **Source / verification:** Standard status transitions; exact badge text confirmed at screenshot-capture time against the pinned `v3.5.2` instance.

#### I-L1-03 · Three windows, three vocabularies, one story `VISUAL` `STICKY`
- **Insight:** Run the lab with three surfaces open at once: the Argo CD **UI** (tree + diff), a terminal on `argocd app get`, and a second terminal watching the **workload cluster** with `kubectl --context k3d-workload-1 get ... -w`. All three describe the same event in different words. Learning to move between them is what lets you later answer the only question that matters in an incident: *is this Argo CD, or is this Kubernetes?*
- **Why it is useful:** It is the outline's "use the UI, CLI, and Kubernetes resources to locate status and events" bullet, converted from a checklist into a habit — and it is the exact skill the Capstone grades.
- **Best delivery moment:** Set the three windows up during the environment check, before anything happens, so the layout is already familiar when the change lands.
- **Visual / activity:** A single figure showing the same moment rendered three ways. Then: "Point at where each surface says `Progressing`."
- **Accuracy caveat:** Guides must always name the `kubectl` context explicitly (blueprint §8.4) — the wrong-cluster mistake is the most common self-inflicted failure in a two-cluster lab.
- **Source / verification:** Context names `k3d-argocd-mgmt` / `k3d-workload-1` are the blueprint's convention (§8.4); `environment-engineer` owns confirming them.

#### I-L1-04 · Read the diff before you sign it `STICKY`
- **Insight:** `argocd app diff <app>` (or the UI's Diff panel) shows exactly what a sync *would* change, before it changes anything. Making "diff, then sync" a two-step reflex is the cheapest safety habit in Argo CD, and it is the same reflex as reading a pull request before approving it.
- **Why it is useful:** It transfers a habit participants already have (code review) into a new context, and it is the direct ancestor of Lab 4's "preview before you apply" and the Capstone's "no uncontrolled changes" rule.
- **Best delivery moment:** As the very first thing done after the commit registers, before the sync.
- **Visual / screenshot:** **SS-02-03** / **SS-L1-03** (Diff panel, single differing field highlighted).
- **Source / verification:** `argocd app diff` is a documented command; a command reference page exists on the current docs. **Confirm exact flags at 3.5** before they appear in a guide.

#### I-L1-05 · `OutOfSync` is a sentence about Git, not about your users `COUNTER`
- **Insight:** The moment the commit lands and before the sync runs, the application is `OutOfSync` and **completely healthy**. Users are being served, correctly, by the previous version. `OutOfSync` states that the cluster does not match Git; it says nothing about whether anyone is having a bad day.
- **Why it is useful:** This is the course's **anchor misconception #1**, and Lab 1 is the only place it can be demonstrated in a completely safe, completely obvious way. Break it here and it stays broken.
- **Best delivery moment:** In the gap between the commit and the sync — a deliberate pause with a question, not a step.
- **Visual / activity:** The question is the activity: **"Right now, who is affected by this `OutOfSync`?"** Let the silence sit. Answer: nobody.
- **Accuracy caveat:** Do not overcorrect into "`OutOfSync` is harmless." A long-lived `OutOfSync` on an auto-sync application means reconciliation is *stuck*, which is a real problem. The accurate rule: **`OutOfSync` is not an outage; `OutOfSync` that will not converge is.**
- **Source / verification:** Semantics of sync status; no version-specific claim.

#### I-L1-06 · Deleting a Pod is not drift `COUNTER` `VISUAL`
- **Insight:** In the resource tree, `Deployment → ReplicaSet → Pod` are shown, but only the **Deployment** is in Git. Delete a Pod and Argo CD does not consider anything out of sync — Kubernetes simply makes another one, and Argo CD watches it happen. Delete the **Deployment**, and *that* is drift, because that resource is in Git.
- **Why it is useful:** It draws the ownership boundary (I-S2-07) on a concrete tree that participants are looking at, and it inoculates against the belief that Argo CD "watches the cluster for changes" in some general sense.
- **Best delivery moment:** During the tree walkthrough, as a 60-second micro-experiment: delete a Pod, watch two controllers do two different jobs.
- **Visual / screenshot:** **SS-02-01** / the lab's tree view, with the Git-owned node boxed and the Kubernetes-generated nodes shaded differently.
- **Accuracy caveat:** Keep this scoped to the observation. Do **not** drift into pruning or `Prune=false` here — that is S4's material and this lab is deliberately observation-only.
- **Source / verification:** Behavioural; verifiable live in the lab environment. `lab-tester` will confirm on execution.

#### I-L1-07 · Three minutes of nothing, revisited `COUNTER`
- **Insight:** After the commit, the UI may show nothing for up to three minutes. That is the `timeout.reconciliation` default (I-S1-06) doing its job, not a failure. Pressing **Refresh** is the impatient version of waiting; a webhook is the production version of not waiting.
- **Why it is useful:** In a 45-minute lab with 20 participants, this single sentence prevents the most common false-alarm escalation and reclaims real classroom minutes.
- **Best delivery moment:** As an inline note attached to the commit step, phrased as an expectation rather than a troubleshooting entry — then repeated in the Troubleshooting section as "symptom: nothing happened."
- **Accuracy caveat:** Give the number the environment actually ships, not the upstream default, if `environment-engineer` tuned it.
- **Source / verification:** See I-S1-06. ✅ Verified via search summary of the Argo CD FAQ/webhook docs; **confirm against the pinned instance.**

#### I-L1-08 · You just used the first four steps of a method you have not been taught yet `STICKY`
- **Insight:** Close the lab by naming what they did: checked the Git source and revision, confirmed the repo rendered, compared rendered against live, and read the sync result and events. Those are **steps 1–4 of the 6-step troubleshooting method** taught formally in S7.
- **Why it is useful:** It makes S7 a *recognition* rather than an introduction — which is exactly the blueprint's sequencing claim (§5, "earlier labs each rehearse a subset so it is not brand-new at the capstone"), and it makes the method feel earned rather than imposed.
- **Best delivery moment:** The lab's closing beat, immediately before Key Takeaways.
- **Visual / activity:** Show the 6-step flow with steps 1–4 already ticked and 5–6 greyed out, captioned "you will meet these two on Day 2."
- **Accuracy caveat:** Use S7's exact step wording from the outline. Do not paraphrase into a competing list (blueprint §7, structural anchors).
- **Source / verification:** Internal course structure; outline §7 is the source of the step text.

### Key takeaways — Lab 1

> **"An Application is an address, not an artifact — and every address in it is something that can go down."**
>
> **"`OutOfSync` is a sentence about Git, not a sentence about your users. `OutOfSync` that never converges is the real problem."**
>
> **"Read the diff before you sign it."**
>
> **"Deleting a Pod is not drift. Deleting the Deployment is — because only one of them is in Git."**
>
> **"The UI, the CLI, and `kubectl` tell the same story in three vocabularies. Fluency in all three is how you answer 'is this Argo CD or is this Kubernetes?'"**

---

## S3 — Production-oriented configuration
**File:** `courseware/day-1/03-production-oriented-configuration.md` · Concept · 60 min · Objective 3

> **Boundary guard (blueprint §7.1):** this file explains *what* a production install and an HA topology look like and *why*. The executable install/HA runbook belongs to `courseware/environment/instructor-setup-guide.md`. No stage directions in this file.

#### I-S3-01 · Who deploys the deployer? `STICKY`
- **Insight:** Argo CD manages everything declaratively from Git — including itself. That is a chicken-and-egg problem with an unglamorous answer: **you install Argo CD imperatively exactly once, then hand its own configuration to itself.** After that first install, changes to Argo CD are commits like everything else.
- **Why it is useful:** Naming the bootstrap paradox out loud prevents it from being discovered as a contradiction later, and it explains why "Argo CD manages Argo CD" is a real pattern rather than a party trick.
- **Best delivery moment:** Opening the installation-choices section, as the frame for everything that follows.
- **Visual / activity:** A timeline with one imperative step at the far left and an unbroken chain of commits after it.
- **Accuracy caveat:** Self-management has a genuine hazard worth one sentence: an Argo CD that manages itself can sync a change that breaks its own controller. That is an argument for staged upgrades, not against self-management.
- **Source / verification:** Practice framing. No version-specific claim.

#### I-S3-02 · The `default` AppProject is a wide-open door `COUNTER`
- **Insight:** Every Argo CD install ships an AppProject named `default`, created automatically, and it is configured to be **maximally permissive**: `sourceRepos: ['*']`, destinations of `'*'` server and `'*'` namespace, and a cluster-resource allow-list permitting all groups and kinds. An Application with no project specified lands there. So a fresh install has a project, and no boundary.
- **Why it is useful:** It is genuinely surprising to most operators, it makes "guardrails" concrete on Day 1 instead of Day 2, and it produces a specific, actionable first hardening step. It is also the setup for Lab 5.
- **Best delivery moment:** In the declarative-configuration section, as the first thing to change after install.
- **Visual / activity:** Show the `default` project's YAML with the three wildcards highlighted. Quick Check: "This install has one AppProject. What is it currently preventing?" (Nothing.)
- **Accuracy caveat:** The documented hardening move is to *empty* the allow-lists (`sourceRepos: []`, `sourceNamespaces: []`, `destinations: []`), which removes all permissions from `default` — not to delete the project.
- **Source / verification:** ✅ Verified 2026-09-10 via search summaries of `argo-cd.readthedocs.io` RBAC and Projects pages: the `default` project is created automatically, "permits deployments from any source repo, to any cluster, and all resource Kinds," with `sourceRepos: '*'`, destinations `'*'`/`'*'`, and a permissive `clusterResourceWhitelist`; removing all permissions is done by setting `sourceRepos`, `sourceNamespaces`, and `destinations` to empty lists. **Confirm the exact field set at 3.5** before it becomes a lab step.

#### I-S3-03 · "Least privilege" for Argo CD means least *write* privilege `COUNTER` `TRADE-OFF`
- **Insight:** You can genuinely restrict what Argo CD may **create, update, patch, and delete** on a workload cluster — down to named namespaces, groups, and kinds. You cannot meaningfully restrict what it can **read**: `get`, `list`, and `watch` at cluster scope are required for Argo CD to function at all, because that is how it computes live state and health.
- **Why it is useful:** It is the difference between a security story that survives an audit conversation and one that collapses in it. It also explains *why* the management cluster is so sensitive (I-S1-05) — it can read everything, everywhere, by design.
- **Best delivery moment:** In the workload-cluster registration section, immediately after "least-privilege credentials" is first said.
- **Visual / activity:** A two-column table: "restrictable" (write verbs, namespaces, kinds) vs "required" (read verbs, cluster scope). Discussion prompt: "How would you describe this to a security reviewer?"
- **Accuracy caveat:** Namespace-scoped modes exist and narrow the picture further; treat them as a named option, not the default, and do not present them as fully removing cluster-scope reads without confirming the current behaviour.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `argocd cluster add` / cluster-management docs: `argocd-manager-role` rules "can be modified to only have create, update, patch, delete privileges to a limited set of namespaces, groups, and kinds, though get, list, watch privileges are required at the cluster-scope for Argo CD to function." **Re-confirm at 3.5**; also confirm the current state of namespaced mode.

#### I-S3-04 · Webhooks vs polling is a question about network direction, not about speed `TRADE-OFF`
- **Insight:** Polling means the management cluster makes an **outbound** connection to Git on a timer. A webhook means the Git server makes an **inbound** connection to the management cluster on an event. In a locked-down enterprise, outbound is easy and inbound is a firewall change, a public or peered ingress, a TLS certificate, and a shared secret. That is why many mature platforms deliberately keep polling and simply shorten the interval.
- **Why it is useful:** It reframes a topic usually taught as "webhooks are better" into an actual engineering decision with a network-security cost, which is exactly the outline's framing ("webhooks versus polling and their **network implications**").
- **Best delivery moment:** After the reconciliation interval is established (I-S1-06), so the latency being traded is a concrete number.
- **Visual / activity:** One diagram, two arrow directions, with the firewall drawn in. Quick Check: "Your Git server is on-prem and the management cluster is in a private subnet. Which is cheaper to operate?"
- **Accuracy caveat:** Shortening the polling interval is not free — it multiplies repo-server load across every application. Link forward to S7's repo-server pressure material rather than presenting it as a costless dial.
- **Source / verification:** ✅ Polling default and `timeout.reconciliation` verified (see I-S1-06). Webhook configuration is documented at `operator-manual/webhook/`. **Confirm current webhook setup path and secret handling at 3.5** before any step relies on it.

#### I-S3-05 · Commit the pointer, never the payload `STICKY`
- **Insight:** GitOps says "everything in Git." Security says "no secrets in Git." Both are satisfied by splitting the secret in two: the **reference** — that this application needs a secret with this name in this namespace — is declarative and lives in Git. The **value** is injected at apply time by a secret manager (External Secrets, Sealed Secrets, SOPS, a CSI driver). Git stays complete; the secret stays out of it.
- **Why it is useful:** It resolves what participants often experience as a genuine contradiction in GitOps, in one sentence, and it gives them a phrase they can take to their own repo.
- **Best delivery moment:** In the "configuration that should be stored in Git versus injected securely" section — this insight *is* that section's thesis.
- **Visual / activity:** A single manifest with the reference highlighted green and an empty value slot highlighted red, and an arrow from an external secret store into the red slot.
- **Accuracy caveat:** Name the tool categories without evaluating them — CLAUDE.md forbids turning this into a tooling survey, and S6 revisits secrets at governance depth.
- **Source / verification:** Ecosystem practice, not an Argo CD version claim. Keep tool names generic.

#### I-S3-06 · Multi-tenant vs core is a question about who needs to *see* `TRADE-OFF` `MODERN`
- **Insight:** Argo CD Core drops the API server, UI, SSO, and RBAC layer — it is a lean controller for a single team that drives everything through the CLI and Git. The full multi-tenant install exists so that *other people* — application teams — can see their own application's status without a platform engineer in the loop. This course's model (a platform team serving many app teams) makes multi-tenant the right answer, and the reason is self-service, not features.
- **Why it is useful:** It converts an installation-mode choice into an organizational question, which is how a platform engineer actually decides it, and it connects directly to the internal-developer-platform theme.
- **Best delivery moment:** Opening the installation-choices section, before HA.
- **Visual / activity:** Two boxes listing "who can answer 'is my app deployed?'" — one says "the platform team"; the other says "the person asking."
- **Accuracy caveat:** Do not present Core as insecure or unserious; it is a legitimate choice for automation-only environments.
- **Source / verification:** Argo CD Core is documented at `operator-manual/core/`. **Confirm the current component list Core omits at 3.5** before any comparison table ships.

#### I-S3-07 · What HA actually buys you, component by component `STICKY`
- **Insight:** "HA" is not one switch. Each component fails differently and scales differently: the **API server** is stateless (scale for availability), the **repo-server** is stateless (scale for rendering throughput), the **application-controller** scales by sharding *clusters* across replicas, and **Redis** needs a genuine HA topology of its own. Knowing which is which tells you what an outage of each one costs.
- **Why it is useful:** It makes the instructor's HA demo legible instead of decorative, and it plants the sharding fact that S7 develops into an architecture decision (I-S7-03).
- **Best delivery moment:** As the participant-facing framing *around* the instructor demo — what to watch for while it runs.
- **Visual / activity:** The component diagram again, annotated with "what breaks if this is down" per box: UI/API down → you cannot see or click, but reconciliation continues. Controller down → nothing reconciles. Repo-server down → nothing renders, and cached apps look fine until they need re-rendering.
- **Accuracy caveat:** The controller-sharding detail is **MOVED to S7** by blueprint §5.3 — mention that sharding is by cluster and forward-reference; do not teach the algorithms here.
- **Source / verification:** ✅ Sharding-by-cluster and the HA component shape verified via search summary of `operator-manual/high_availability/` (see I-S7-03 for the detailed citation). **Confirm HA chart values at chart `10.8.4`** — `environment-engineer` owns this.

### Key takeaways — S3

> **"The `default` AppProject is a wide-open door with a lock painted on it. Emptying it is your first hardening step."**
>
> **"Least privilege for Argo CD means least *write* privilege. Read-everywhere is a requirement, not a setting — say that out loud before your auditor does."**
>
> **"Webhooks versus polling is a question about which direction the connection goes, not about which is faster."**
>
> **"Commit the pointer, never the payload."**
>
> **"Argo CD is installed imperatively exactly once. After that, it is commits all the way down."**

---

## Lab 2 — Configure the platform and register a target
**File:** `courseware/day-1/lab-02-configure-platform-and-register-target.md` · Lab · **HEAVY** scaffolding · 60 min · Objectives 3, 6 (partial)

> **Weighting note:** the second and last maximally-guided lab. After this, scaffolding drops. Spend the explanation budget on *what the commands produce*, because the produced objects are what participants will read for the rest of the course.

#### I-L2-01 · Everything Argo CD knows is a labeled Secret in one namespace `STICKY` `VISUAL`
- **Insight:** "Registering a cluster" and "connecting a repository" sound like features. They are objects. Both are Kubernetes Secrets in the `argocd` namespace, distinguished by a label:
  ```bash
  kubectl --context k3d-argocd-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
  kubectl --context k3d-argocd-mgmt -n argocd get secret -l argocd.argoproj.io/secret-type=repository
  ```
  Two commands and Argo CD's entire address book is on screen.
- **Why it is useful:** This is the lab's single biggest "aha." It collapses two abstract-sounding onboarding features into readable objects, it makes declarative onboarding obviously possible (you can just *write* those Secrets), and it gives participants a diagnostic they will use in the Capstone when a cluster goes missing.
- **Best delivery moment:** Run it **twice** — once before registering anything (empty result), once immediately after `argocd cluster add` succeeds. The before/after is the reveal.
- **Visual / screenshot:** **SS-L2-03** (Settings → Clusters showing `Successful`) paired with the terminal output of the same fact. Caption: "the UI row and this Secret are the same object."
- **Accuracy caveat:** Show the Secret's *existence and labels*, never its decoded contents. Blueprint/CLAUDE.md forbid surfacing credentials in guides.
- **Source / verification:** ✅ Secret-type labels (`cluster`, `repository`) are the documented declarative mechanism per `operator-manual/declarative-setup/`. **Confirm the exact label key and values at 3.5** before this becomes a printed command.

#### I-L2-02 · The ServiceAccount is created in the cluster being managed, not the one doing the managing `COUNTER`
- **Insight:** Ask before running the command: "`argocd cluster add` is about to create a ServiceAccount and RBAC. **Which cluster gets them?**" Most people say the management cluster. It is the **workload** cluster — the one being managed. Argo CD then stores a credential *for* that ServiceAccount back on the management side.
- **Why it is useful:** That inversion *is* the architecture. Getting it wrong in the classroom, once, out loud, is worth more than reading it correctly three times. It also makes the least-privilege discussion (I-S3-03) land, because now it is obvious *whose* RBAC you are narrowing.
- **Best delivery moment:** The prediction beat immediately before the registration command.
- **Visual / activity:** After the command succeeds, prove it: list the ServiceAccount on `k3d-workload-1` and the Secret on `k3d-argocd-mgmt`. Two clusters, two different objects, one relationship.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `user-guide/commands/argocd_cluster_add/` and cluster-management docs: the command uses a system-namespace service account in the target cluster (`--service-account`), with `--namespace` limiting manageable namespaces, and an `argocd-manager-role` whose write verbs can be narrowed. **Confirm the exact flag list at 3.5** — blueprint §12 already assigns this.

#### I-L2-03 · A cluster credential is only valid from the place that will use it `FAILURE`
- **Insight:** The most-repeated cluster-registration bug in GitOps is a kubeconfig whose server address is `https://127.0.0.1:6443`. It works perfectly from your laptop. Copy it into the management cluster and the application controller dials **itself**, because `127.0.0.1` means "me" wherever it is read. Symptom: the cluster registers, then shows a connection failure or `Unknown` — a timeout or connection-refused against a loopback address.
- **Why it is useful:** It is a real incident, it is *the* environment hazard the blueprint already flagged (§8.8), and it generalizes into a rule participants will reuse for every credential they ever move between machines.
- **Best delivery moment:** In Troubleshooting as "likely failure → likely cause → fix," and as a one-line warning attached to the registration step itself.
- **Visual / activity:** Show the offending line in a kubeconfig and the resulting error side by side. Optional stretch: deliberately register with a bad address, observe the failure, then fix it.
- **Accuracy caveat:** Blueprint §8.8 makes `environment-engineer` responsible for pre-solving the advertised-address wiring so registration "just works" in class. Teach this as **why it works**, not as a step participants must debug — unless the environment build decides otherwise.
- **Source / verification:** Well-known operational failure mode; the specific k3d/Docker manifestation is flagged in blueprint §8.8. `lab-tester` confirms the actual error text on execution.

#### I-L2-04 · Do it imperatively once so you can recognise it declaratively forever `TRADE-OFF`
- **Insight:** `argocd cluster add` and the UI's "Connect repo" form are excellent teaching tools and poor operational practice. Neither leaves a record in Git. The sequence that teaches best is: run the imperative command → read the object it created → recognise that a declarative onboarding just writes that object from a repository.
- **Why it is useful:** It resolves an apparent contradiction (a GitOps course teaching a click-driven form) by making the imperative step explicitly a *learning* step, and it turns declarative onboarding from new material into a re-labeling of something already understood.
- **Best delivery moment:** Immediately after I-L2-01's "after" command — the object is on screen, so the point makes itself.
- **Visual / activity:** Side-by-side: the imperative command, and the committed manifest that produces the same result. Quick Check: "Your management cluster is rebuilt from scratch tomorrow. Which of these two survives?"
- **Source / verification:** Declarative repo/cluster onboarding is documented at `operator-manual/declarative-setup/`. **Confirm current manifest shape at 3.5.**

#### I-L2-05 · "Connection Successful" is a measurement, not a guarantee `COUNTER`
- **Insight:** The green connection state on a repository or cluster row means the last check succeeded. It is a health probe with a timestamp, not a permanent property. A token that expires next month will show green today and `Unknown` the morning it matters.
- **Why it is useful:** It prevents "but it said Successful" from becoming a dead end in the Capstone, and it introduces the idea that *every* status in Argo CD is a measurement taken at a moment — which is the same idea as `OutOfSync` being a comparison result.
- **Best delivery moment:** At the connectivity-verification checkpoint, as the sentence that comes right after the success screenshot.
- **Visual / screenshot:** **SS-L2-02** (repo connected) and **SS-L2-03** (cluster `Successful`), captioned with what the badge actually asserts.
- **Source / verification:** Behavioural framing; the exact connection-state labels to be confirmed at screenshot capture.

#### I-L2-06 · Rehearse the Capstone's disconnected-cluster fault in 60 seconds `FAILURE`
- **Insight:** Once the workload cluster is registered and an Application is comparing against it, deliberately interrupt the connection briefly and watch what changes. The application does not go `Degraded` in a way that means "the app is broken" — it goes **`Unknown`**, because Argo CD can no longer *observe* live state. Absence of evidence renders as `Unknown`, not as failure.
- **Why it is useful:** It rehearses Capstone fault #5 a full day early, and it teaches the most misread status in Argo CD. Participants who have never seen `Unknown` in a controlled setting will misdiagnose it under pressure.
- **Best delivery moment:** As the lab's optional stretch challenge, clearly marked — it is a perfect optional because it is fast, reversible, and diagnostic.
- **Visual / activity:** Predict first: "Will this app go `OutOfSync`, `Degraded`, or something else?" Then observe. Then restore and watch it recover on its own.
- **Accuracy caveat:** Only include this if the environment provides a clean, reversible way to interrupt connectivity. `environment-engineer` owns the mechanism; if there is no reversible mechanism, cut the exercise rather than improvise one.
- **Source / verification:** `Unknown` is a documented health value (see I-S2-03's priority list). Exact observed behaviour to be confirmed by `lab-tester` on execution.

#### I-L2-07 · The first AppProject is a fence you build before you need it `STICKY` `MODERN`
- **Insight:** Creating an AppProject in this lab is not paperwork. It answers three questions in advance — which repositories may be sources, which cluster/namespace pairs may be destinations, and which resource kinds are allowed — so that later, when an application team asks for access, the answer is a small diff to a fence rather than an argument.
- **Why it is useful:** It plants the governance model on Day 1 as a *design* act, and it is the object Lab 5 will tighten and try to break. Framing it early means S6 is a deepening, not a new topic.
- **Best delivery moment:** As the reasoning attached to the AppProject creation step, before the fields are filled in.
- **Visual / screenshot:** **SS-L2-04** plus a three-row table: sources / destinations / kinds, each with "what this fence prevents."
- **Accuracy caveat:** Keep it to a **basic** project (outline: "Create a basic AppProject"). Restriction, denial testing, and the Argo-vs-Kubernetes contrast are Lab 5's material.
- **Source / verification:** AppProject fields documented at `operator-manual/project-specification/`. **Confirm at 3.5.**

### Key takeaways — Lab 2

> **"Everything Argo CD knows about your repos and clusters is a labeled Secret in one namespace. Two `kubectl` commands print the whole address book."**
>
> **"The ServiceAccount lives in the cluster being managed, not in the cluster doing the managing."**
>
> **"A credential is only valid from the place that will use it. `127.0.0.1` in a kubeconfig is the most-copied bug in GitOps."**
>
> **"Register a cluster imperatively to learn it. Register it declaratively to keep it."**
>
> **"`Unknown` does not mean broken. It means Argo CD cannot see — and you should go find out why it went blind."**

---

## S4 — Helm deployments, synchronization, and promotion
**File:** `courseware/day-1/04-helm-deployments-sync-and-promotion.md` · Concept · 60 min · Objectives 5, 6

> **Density guard (blueprint §5.3 / §13):** the densest Day 1 session. Kustomize is **one bounded box**. Repository layout is **one recommended layout plus a two-row comparison table**. The exhaustive sync-option field list is a **reference table**, not lecture material. The render-vs-release distinction is the anchor and gets the time.

#### I-S4-01 · Argo CD borrows Helm's templating engine and throws away Helm's release manager `COUNTER` `VISUAL`
- **Insight:** Argo CD renders charts with `helm template` and then applies the resulting manifests itself. It does **not** run `helm install` or `helm upgrade`. Four consequences follow, and each one is a small independent "aha":
  1. **There is no Helm release.** `helm list -n <namespace>` shows nothing. No release secrets, no release history.
  2. **`helm rollback` does not exist here.** Rolling back means reverting a commit.
  3. **Helm hooks are re-interpreted**, not executed by Helm — they map onto Argo CD's own hook/phase model.
  4. **Charts that generate random values at render time never converge.** A chart using `randAlphaNum` produces a different value on every comparison, so the application is permanently `OutOfSync`. The documented mitigation is to set the value explicitly so it is stable between comparisons.
- **Why it is useful:** This is the course's **anchor misconception #2** (CLAUDE.md names it explicitly) and the root of more confused Argo CD tickets than any other single idea. Consequence 4 is the proof: it is a symptom that is inexplicable under the wrong model and obvious under the right one.
- **Best delivery moment:** The first substantive beat of the session. Everything else in S4 depends on it.
- **Visual / activity:** The **"Helm-render vs helm-release"** diagram (blueprint §11). Best single activity in the session: run `helm list` against the namespace of a working, healthy, Argo-CD-deployed Helm application. The empty output *is* the lesson.
- **Accuracy caveat:** Do not overstate into "Argo CD does not use Helm." It uses Helm — the binary, the templating engine, the values semantics. It declines Helm's release lifecycle.
- **Source / verification:** ✅ Verified 2026-09-10 via search summaries of `argo-cd.readthedocs.io` Helm user-guide: Argo CD "run[s] the `helm template <CHART>` command to generate helm manifests," does not use `helm install`, and the `randAlphaNum` case "will always be in an `OutOfSync` state," mitigated "by explicitly setting a value in the `values.yaml`." **Confirm hook-mapping wording at 3.5** before it ships as instruction.

#### I-S4-02 · Upgrading Argo CD can change your manifests without anyone touching a chart `COUNTER` `FAILURE` `MODERN`
- **Insight:** Because Argo CD *is* the thing running Helm, **Helm's version is part of your desired state.** Argo CD 3.5 moved to Helm 4 (reported as **4.2.1** in the v3.4→v3.5 upgrade notes) and made it the only Helm binary used to render charts. Helm 4 changed null/nil value coalescing, so **the same chart with the same values can render different manifests after upgrading Argo CD alone** — most visibly for charts with nullable defaults or ones that relied on nulls being dropped during coalescing.
- **Why it is useful:** It is the most current, most concrete, most *surprising* fact available for this course, and it does double duty: in S4 it proves the render-vs-release point at the deepest level, and in S7 it turns "read the release notes" from a platitude into a specific rehearsal ("render your real charts with the new version's Helm and diff before you upgrade").
- **Best delivery moment:** Directly after I-S4-01, as its most powerful consequence — then cross-referenced from S7's upgrade section rather than re-taught.
- **Visual / activity:** Discussion prompt, no lab work: "You upgraded Argo CD on Tuesday. On Wednesday, forty applications show a diff and nobody committed anything. What happened, and what should you have done on Monday?"
- **Accuracy caveat:** Report the **exact patch version with care** — one primary-source summary said Helm `4.2.0` and another said `4.2.1`. State "Helm 4.x, per the v3.4→v3.5 upgrade notes" until the exact patch is confirmed. Also state the scope honestly: it affects charts that rely on null-coalescing behaviour, **not** every chart.
- **Source / verification:** ⚠️ **Verified via search summaries only** (2026-09-10): `argo-cd.readthedocs.io/en/latest/operator-manual/upgrading/3.4-3.5/` ("Helm was upgraded to 4.2.1"; "The only Helm binary used to render charts in Argo CD (starting with version 3.5) is v4"; Helm 4 OCI now requires explicit `--plain-http` for non-TLS registries) and `argoproj/argo-cd` issues **#29068 / #29059** ("Document Helm rendering behavior changes when upgrading to Argo CD 3.5"). **Route to `technical-source-check`:** confirm the exact bundled Helm patch version at `v3.5.2` and the precise coalescing wording. Note the upgrade page was read from `/latest/`.

#### I-S4-03 · Drift is discovered, not detected `STICKY`
- **Insight:** Argo CD does not *block* a `kubectl edit`; the edit succeeds. Argo CD then **compares** rendered state against live state, and "drift" is simply the name for a comparison that came back different. The comparison is triggered by a watch on the resources it manages (a hand edit shows `OutOfSync` within a second or two — verified in the 2026-09-13 Lab 3 run), by the Git polling timer (60 s here) for new commits, and by Refresh. There is always a window in which the cluster was wrong; for a hand edit it is short.
- **Why it is useful:** It explains the timing participants will observe in Lab 3, and it prevents the belief that Argo CD is an admission controller blocking changes — a belief that leads directly to wrong incident decisions.
- **Best delivery moment:** Opening the drift/self-heal section, before either term is defined.
- **Visual / activity:** A timeline: edit at t=0, comparison at t=n, correction at t=n+ε. Ask participants to mark on the timeline "when was the cluster wrong?" — the honest answer is the whole interval.
- **Source / verification:** Mechanism follows from the reconciliation model; interval verified at I-S1-06.

#### I-S4-04 · Self-heal does not block your edit — it outlives it `COUNTER` `TRADE-OFF`
- **Insight:** With self-heal on, a well-intentioned `kubectl scale deploy/api --replicas=10` during an incident **works**, and then is undone at the next reconciliation. The engineer scales again. It reverts again. The system looks broken and is behaving exactly as configured. The rule: **with self-heal on, the only durable change is a commit.** The escape hatch during an incident is not to fight it — it is to disable automated sync on that one Application, stabilise, then commit.
- **Why it is useful:** It is a named anchor misconception for this course, it is a genuine on-call trap, and it is the clearest example in the course of a feature whose value and whose hazard are the *same behaviour*.
- **Best delivery moment:** As the climax of the sync-policy section, immediately before the prune discussion.
- **Visual / screenshot:** **SS-04-01** (sync policy panel with the automated-sync and self-heal switches). The switch is the escape hatch — show it in the same figure as the trap.
- **Accuracy caveat:** Be precise about *what* self-heal reverts: it re-applies desired state for the resources Argo CD manages. It does not restore a resource that was never in Git, and it is not an admission webhook — there is a real window in which the manual change is live.
- **Source / verification:** ✅ Self-heal semantics per `user-guide/auto_sync/`. **Confirm the current option name (`selfHeal`), any backoff behaviour, and the UI toggle labels at 3.5** — blueprint §12 already assigns sync-option naming to `lab-engineer`.

#### I-S4-05 · Turn on self-heal early; turn on prune late `TRADE-OFF` `FAILURE`
- **Insight:** Self-heal's failure mode is an argument. **Prune's failure mode is a deletion.** Automated sync with prune deletes anything that leaves Git — which is correct, and which is also what happens when someone renames a directory, mistypes a `path`, or ships an ApplicationSet template that suddenly renders nothing. Self-heal is safe to adopt early because its worst case is reversible; prune deserves a slower, per-application rollout and explicit protections.
- **Why it is useful:** It gives an actionable adoption order rather than a feature description, and it motivates the outline's "guardrails against accidental pruning" bullet with a reason rather than a warning.
- **Best delivery moment:** Immediately after self-heal, as the deliberate contrast.
- **Failure story to tell:** *The 3 a.m. prune.* Someone reorganises a repository and renames a directory. Auto-sync with prune is on. Every resource under the old path is, by definition, no longer in Git. Argo CD deletes it — correctly, promptly, and catastrophically. Nobody made a mistake in Kubernetes; someone made a mistake in a directory name.
- **Visual / activity:** Introduce the protections *as the response to the story*: the `Prune=false` sync option (settable per-resource via the `argocd.argoproj.io/sync-options` annotation) and `PruneLast=true`, which defers pruning to a final implicit wave after everything else is deployed and healthy.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `user-guide/sync-options/`: `Prune=false` via `argocd.argoproj.io/sync-options`; `PruneLast=true` prunes "as a final, implicit wave of a sync operation, after the other resources have been deployed and become healthy"; multiple options comma-separated in one annotation. Other confirmed option names: `ApplyOutOfSyncOnly=true`, `CreateNamespace=true`, `ServerSideApply`, `Replace`, `RespectIgnoreDifferences`. **Confirm the full option list and exact spellings at 3.5** (blueprint §12 assigns this).

#### I-S4-06 · Waves build low-to-high and tear down high-to-low `COUNTER` `VISUAL`
- **Insight:** Sync waves are set with the `argocd.argoproj.io/sync-wave` annotation; resources and hooks default to wave `0`, and negative waves run first. Creation proceeds from the lowest wave to the highest. **Pruning reverses the order — higher waves are pruned first.** Argo CD also waits between waves (a documented ~2-second delay, configurable via `ARGOCD_SYNC_WAVE_DELAY`) and assesses health before advancing.
- **Why it is useful:** The reversal is genuinely surprising and it is also *correct* — you tear down in the opposite order you build, exactly as you would by hand. It makes ordering failures diagnosable rather than mysterious, which is the outline's stated purpose for this topic.
- **Best delivery moment:** With the sync-phases/waves timeline diagram (blueprint §11) on screen, as the second half of the ordering explanation.
- **Visual / screenshot:** **SS-04-02**. The diagram should draw the *same* wave list twice — once with a downward arrow labeled "create," once with an upward arrow labeled "prune."
- **Accuracy caveat (important, and it is the practical one):** because Argo CD waits for health before advancing, **a resource kind with no meaningful health check can make wave ordering ineffective** — the wave "completes" instantly regardless of readiness. That is a direct forward link to S7's custom health checks, and it is the real reason wave-based ordering sometimes appears not to work.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `user-guide/sync-waves/`: annotation name; default wave 0; negatives allowed; "During pruning, the wave order is reversed... Resources in higher waves are pruned first"; "the current delay between each sync wave is 2 seconds and can be configured via the environment variable `ARGOCD_SYNC_WAVE_DELAY`"; the delay exists partly to avoid assessing health "too quickly (against the stale object)." Phases confirmed as `PreSync`, `Sync`, `PostSync`, `SyncFail`. **Confirm the 2-second default and phase list at 3.5.**

#### I-S4-07 · Promote a number, not a chart `STICKY` `MODERN`
- **Insight:** Promotion in GitOps is not a pipeline that copies artifacts between environments. It is **moving a version pin from one values file to another**: the tag that `values-dev.yaml` has been running for a week gets written into `values-staging.yaml`. The chart does not move. The image does not move. A number moves, in a pull request, with a reviewer.
- **Why it is useful:** It makes promotion concrete and reviewable, it explains why environment-specific values files are the recommended layout, and it directly connects to how progressive delivery is actually governed in current platform practice.
- **Best delivery moment:** Opening the promotion section — it is the section's thesis.
- **Visual / activity:** Show the two values files with only the tag line differing, and the promotion rendered as a one-line diff. Quick Check: "What is the smallest possible promotion?" (A one-line diff.)
- **Accuracy caveat:** Keep this to the outline's scope. Do not introduce dedicated promotion tooling — CLAUDE.md forbids the tooling survey, and the blueprint gives S4 no budget for it.
- **Source / verification:** Practice framing built on Argo CD's documented `valueFiles` / parameter mechanics. **Confirm `helm.valueFiles` / parameter override syntax at 3.5.**

#### I-S4-08 · `targetRevision: HEAD` is not a version — it is a subscription `COUNTER` `STICKY`
- **Insight:** Pointing an Application at `HEAD` or a branch name means your desired state changes whenever someone else commits, without anyone deciding that *this* environment should change *now*. For development that is the point. For a higher environment it means the environment has no owner. Pin a tag or a commit SHA where a human must decide.
- **Why it is useful:** It converts "mutable revisions" from a bullet point into a memorable, slightly alarming reframe, and it is one of the guardrails the outline explicitly asks for.
- **Best delivery moment:** In the guardrails beat that closes the session, alongside cross-environment protections.
- **Visual / activity:** Quick Check: "Two environments both use `targetRevision: main`. What is the difference between them?" (Timing and luck.)
- **Source / verification:** `targetRevision` semantics are stable. **Confirm accepted value forms at 3.5.**

### Key takeaways — S4

> **"Argo CD borrows Helm's templating engine and throws away Helm's release manager. There is no release to roll back — only a commit to revert."**
>
> **"With self-heal on, the only durable change is a commit. `kubectl edit` becomes a suggestion."**
>
> **"Turn on self-heal early; turn on prune late. One argues with you. The other deletes things."**
>
> **"Sync waves build low-to-high and tear down high-to-low — and a resource with no health check makes waves meaningless."**
>
> **"`targetRevision: HEAD` is not a version, it is a subscription."**
>
> **"Promote a number, not a chart. The smallest possible promotion is a one-line diff with a reviewer's name on it."**

---

## Lab 3 — Deploy, introduce drift, and recover
**File:** `courseware/day-1/lab-03-deploy-drift-and-recover.md` · Lab · **MED-HEAVY** scaffolding · 60 min · Objectives 5, 6, 7

> **Weighting note:** the first reduced-scaffolding lab and Day 1's payoff. Every *new* concept is still explained in full; mastered mechanics (logging in, finding an app, reading a diff) are no longer re-explained. This lab is where the two-axis model stops being a diagram and becomes muscle memory.

#### I-L3-01 · Stage the drift experiment in three acts `VISUAL` `STICKY`
- **Insight:** Do not demonstrate drift once. Demonstrate it three times, changing exactly one thing each time:
  - **Act 1 — self-heal OFF.** `kubectl scale` the Deployment on the workload cluster. **Predict first: which of the two statuses changes?** Answer: only sync. It goes `OutOfSync` and stays there, perfectly `Healthy`, indefinitely.
  - **Act 2 — turn self-heal ON with the drift still present.** Predict: *what* happens and *how long* it takes. Watch it revert.
  - **Act 3 — try the same edit again with self-heal on.** Watch it be undone. Then name the winner and say why.
- **Why it is useful:** Act 1 alone proves the entire sync-vs-health distinction with a single observation — it is the cleanest evidence in the whole course. Acts 2 and 3 then convert it into policy understanding. Splitting them is what makes each observation attributable to one cause.
- **Best delivery moment:** The lab's central guided walkthrough; everything else arranges itself around it.
- **Visual / screenshot:** **SS-L3-02** (drift visible, self-heal off) then **SS-L3-03** (self-heal reverting). Two screenshots, one variable changed.
- **Accuracy caveat:** Give a realistic time expectation for Act 2 rather than "immediately," and tie it back to the reconciliation interval (I-S4-03). `lab-tester` supplies the observed timing.
- **Source / verification:** Behavioural; confirmed on execution by `lab-tester`.

#### I-L3-02 · The winner is always Git — and that is a decision someone made `STICKY` `TRADE-OFF`
- **Insight:** After Act 3, ask participants to state the rule in their own words. The answer is not "Argo CD wins." It is **"Git wins, because a human turned on a switch that says Git wins."** Self-heal is a *policy about who wins ties*, not a safety mechanism. It makes the cluster more predictable and makes emergency manual action harder. Both are true at once, and choosing it is an operations decision, not a best practice.
- **Why it is useful:** It is the honest version of a feature usually taught as an unambiguous good, and it gives participants language for a real conversation with their own teams.
- **Best delivery moment:** The debrief immediately after Act 3, before moving on.
- **Visual / activity:** Discussion prompt: "It is 2 a.m. Your app needs 10 replicas right now and self-heal is on. What do you actually do?" Correct answers include disabling automated sync on that one Application, or committing the change — not repeatedly scaling.
- **Source / verification:** Framing over verified self-heal behaviour (I-S4-04).

#### I-L3-03 · Break the *reference*, not the YAML `STICKY` `FAILURE`
- **Insight:** The most instructive break is not malformed YAML. It is **valid YAML that points at something missing** — a `valueFiles` entry naming a file that is not there, or a values key the chart does not use. That produces a **rendering** failure, which surfaces in a completely different place than a **sync** failure: a rendering failure shows up as an Application condition / comparison error (the repo-server could not produce manifests), while a sync failure shows up inside the sync result (the manifests existed and the cluster rejected them).
- **Why it is useful:** Telling those two apart is most of Argo CD troubleshooting, and this lab is the first place a participant can see both in one sitting. It builds the "which layer?" instinct the Capstone grades.
- **Best delivery moment:** The lab's second half, after drift is fully understood — one deliberate rendering failure, then one deliberate sync/ordering failure, with an explicit "notice where you found each one."
- **Visual / screenshot:** **SS-L3-04**, plus a two-column comparison: *rendering failure* → where the message appears, which component owns it; *sync failure* → where the message appears, which component owns it.
- **Accuracy caveat:** Use the environment's real error text captured by `lab-tester`. Never invent an error message (CLAUDE.md).
- **Source / verification:** Behavioural; error text supplied by `lab-tester` on execution.

#### I-L3-04 · An ordering failure looks like an application bug and is not one `FAILURE`
- **Insight:** A classic, entirely realistic break: a Job in wave `0` that needs a Secret created in wave `1`. The Job fails. Every symptom points at the Job. Nothing is wrong with the Job — the *order* is wrong, and the fix is one annotation in Git.
- **Why it is useful:** It makes wave ordering (I-S4-06) operationally real, it produces a diagnosis where the loudest evidence is a red herring, and it rehearses the Capstone's central skill in miniature.
- **Best delivery moment:** As the ordering half of the break/fix pair, immediately after the rendering failure.
- **Visual / activity:** Predict-then-check: "Before you fix it — is this a Job problem, a Secret problem, or a wave problem?" Fix through Git, then watch the ordered rebuild in the correct sequence.
- **Accuracy caveat:** Keep the wave numbers small and legible. This teaches ordering, not hook taxonomy.
- **Source / verification:** ✅ Wave mechanics verified at I-S4-06. Scenario to be validated end-to-end by `lab-tester`.

#### I-L3-05 · Revert when you do not know why; roll forward when you do `TRADE-OFF` `STICKY`
- **Insight:** The recovery decision has a clean rule. If you understand the failure, **roll forward** — commit the fix. If you do not yet understand it and users are affected, **revert** — restore the last known-good desired state, then investigate with the pressure off. And prefer `git revert` over `git reset --hard`: the revert is itself an auditable event, so the recovery is as reviewable as the change that caused it.
- **Why it is useful:** It gives participants a decision rule for the highest-pressure moment in their job, and it makes the GitOps audit-trail claim concrete: even the emergency action leaves a record.
- **Best delivery moment:** As the framing for the recovery step, before they choose their approach — then debrief which they chose and why.
- **Visual / activity:** A two-branch decision diagram with "do I know why?" as the only question. Quick Check: "Which of these two leaves a reviewer able to see what happened?"
- **Source / verification:** Git practice, not an Argo CD claim.

#### I-L3-06 · Some applications can never reach `Synced`, and it is the chart's fault `COUNTER`
- **Insight:** An application that renders a fresh random value on every comparison — the documented `randAlphaNum` case — will be `OutOfSync` forever no matter how many times it is synced. Argo CD is working perfectly; the desired state is *non-deterministic*. The fix is in the chart or the values, not in Argo CD.
- **Why it is useful:** It is a superb diagnostic puzzle, it is the sharpest possible proof of "Argo CD renders and compares" (I-S4-01), and it teaches a general principle: **a desired state that is not deterministic cannot be reconciled.**
- **Best delivery moment:** The **optional stretch challenge**, clearly marked. It is the right shape for a stretch: fast to observe, hard to explain, and genuinely illuminating.
- **Visual / activity:** Sync, watch it return to `OutOfSync`, sync again, watch it happen again. Then: "What is different each time?"
- **Accuracy caveat:** Ship this only if the environment's repos include a suitable chart. If `environment-engineer` does not provide one, **cut the exercise** — do not simulate it with a fabricated example.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of the Argo CD Helm user-guide: charts using `randAlphaNum` "will always be in an `OutOfSync` state," mitigated by setting the value explicitly.

#### I-L3-07 · Name the method you are already using `STICKY`
- **Insight:** Close the lab by mapping what they just did onto the outline's numbered steps: validated the Git source and revision; validated repository access and rendering; compared rendered against live; inspected sync results, hooks, and events. That is **steps 1–4** again — but this time applied to a real failure they had to find, not a change they made on purpose.
- **Why it is useful:** Spaced repetition of the course's spine, with increasing difficulty. Lab 1 rehearsed the steps on a known change; Lab 3 rehearses them on an unknown failure. S7 then names them and adds steps 5–6.
- **Best delivery moment:** Closing beat, before Key Takeaways.
- **Accuracy caveat:** Use the outline's exact step wording (blueprint §7 structural anchor).
- **Source / verification:** Internal course structure.

### Key takeaways — Lab 3

> **"Drift is not blocked, it is discovered — seconds after a hand edit, within a Git check after a commit. There is always a window in which the cluster was wrong."**
>
> **"Self-heal does not block your edit. It outlives it."**
>
> **"Git wins because someone decided Git should win. Self-heal is a policy about who wins ties, not a safety feature."**
>
> **"A rendering failure and a sync failure are equally red and live in completely different places. Telling them apart is most of troubleshooting."**
>
> **"Revert when you do not know why; roll forward when you do. `git revert` is the rollback button, and it leaves a receipt."**
>
> **"A desired state that is not deterministic can never be reconciled."**

---

## S5 — ApplicationSets and App-of-Apps
**File:** `courseware/day-2/05-applicationsets-and-app-of-apps.md` · Concept · 60 min · Objective 4

> **Structural anchor (blueprint §7):** the outline's **"Choosing the Right Pattern" decision table** is this session's frame. Do not invent a competing model. **list**, **cluster**, and **Git** generators get full depth; **matrix** and **merge** are named with one worked example each; progressive syncing is **version-flagged and optional**.

#### I-S5-01 · A factory and a family tree `STICKY`
- **Insight:** An **ApplicationSet is a factory**: it takes a data source and stamps out near-identical Applications from a template. **App-of-Apps is a family tree**: someone wrote down a deliberate hierarchy of specific things and their order. The choosing rule falls straight out of the metaphor — **use a factory when the list is *derived*, and a family tree when the list is *decided*.**
- **Why it is useful:** It maps one-to-one onto the outline's decision table (cluster/Git data → ApplicationSet; a known hierarchy of platform components → App-of-Apps; many clusters without duplication → ApplicationSet; a deliberate bootstrap structure → App-of-Apps) without adding a competing framework. Participants can re-derive the table from the metaphor.
- **Best delivery moment:** Before either pattern's mechanics — it is the session's organising idea, and it makes the decision table feel like a summary rather than a lookup.
- **Visual / activity:** Present the decision table, then ask participants to add one row from their own organisation and justify it with "derived or decided?"
- **Source / verification:** Framing over the outline's own table. No product claim.

#### I-S5-02 · ApplicationSets do not deploy anything `COUNTER` `STICKY`
- **Insight:** The ApplicationSet controller creates, updates, and deletes **Application objects**. That is all. It never contacts a workload cluster, never renders a chart, never applies a Deployment. Everything after an Application exists is the same application-controller doing exactly what it did in Lab 1.
- **Why it is useful:** It is the biggest cognitive-load reduction available on Day 2: **there is no new deployment mechanism today — only a new way of writing Applications.** It also localises troubleshooting instantly ("is the *Application* wrong, or is the *thing that wrote it* wrong?"), which is precisely Lab 4's tracing drill and a Capstone fault.
- **Best delivery moment:** The first sentence of the ApplicationSet section, before any generator.
- **Visual / screenshot:** The **ApplicationSet fan-out** diagram (blueprint §11) drawn with a hard horizontal line under the generated Applications, labeled "everything below this line is Day 1." Pair with **SS-05-01**.
- **Source / verification:** Architectural; consistent with the component verbs in I-S2-01.

#### I-S5-03 · Every template line is multiplied by the generator `VISUAL` `TRADE-OFF`
- **Insight:** Blast radius here is arithmetic, not vibes. One character changed in a template, times N generated Applications, equals N simultaneous changes — applied by a controller that has no idea you were nervous. If the generator yields 40 clusters, editing `targetRevision` is a 40-cluster change, and nothing in the editing experience looks any different from editing one.
- **Why it is useful:** It gives "blast radius" a number, which is what makes the safety controls in I-S5-04 feel necessary rather than fussy. It is also the honest cost of the leverage the pattern provides.
- **Best delivery moment:** Immediately after the generators are understood, as the transition into safety controls.
- **Visual / activity:** The fan-out diagram with a single edit at the top rendered in red and every downstream Application also red. Quick Check (blueprint §10 shape): "You need the same app on 12 clusters — ApplicationSet or App-of-Apps, and what is the cost of the answer you chose?"
- **Source / verification:** Arithmetic. No claim to verify.

#### I-S5-04 · The dangerous failure is not an error — it is a successful render of the wrong thing `COUNTER`
- **Insight:** With Go templating, a value that is missing from the generator renders as **empty** by default, and the ApplicationSet controller cheerfully creates an Application with an empty field. Nothing errors. You get a real Application pointing at the wrong path, or into the wrong namespace, and the failure surfaces somewhere else entirely, minutes later, wearing a different disguise. The documented fix is to opt into strictness: `goTemplate: true` with `goTemplateOptions: ["missingkey=error"]`, which the docs explicitly recommend and which is **not** the default, for backwards compatibility.
- **Why it is useful:** This is the outline's "failing safely on missing values" bullet, and it is one of the strongest counterintuitive insights in the course: **the safer configuration produces more failures, earlier — and that is the point.** It also generalises far beyond Argo CD.
- **Best delivery moment:** With the templating section, as the reason the option exists rather than as an option in a list.
- **Visual / activity:** Show the same generator with one key removed, rendered both ways: silently wrong vs loudly refused.
- **Accuracy caveat:** State plainly that `missingkey=error` is opt-in and that older ApplicationSets in a participant's own estate almost certainly do not have it.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `operator-manual/applicationset/GoTemplate/`: `goTemplateOptions: ["opt1", ...]` alongside `goTemplate: true`; "the recommended setting of `goTemplateOptions` is `["missingkey=error"]`, which ensures that if undefined values are looked up by your template then an error is reported instead of being ignored silently. This is not currently the default behavior, for backwards compatibility."

#### I-S5-05 · Three named controls decide what the factory is allowed to do to its output `STICKY`
- **Insight:** The blast radius is bounded by three specific, nameable settings — teach them as a trio, because they answer three different questions:
  - `syncPolicy.applicationsSync: create-only` — the controller may create generated Applications but **not modify or delete** them.
  - `syncPolicy.applicationsSync: create-update` — it may create and update, but **not delete**.
  - `syncPolicy.applicationsSync: create-delete` — it may create and delete, but **not modify**.
  - `preserveResourcesOnDeletion: true` — when a generated **Application** is deleted, its **child resources survive**.
- **Why it is useful:** It converts "reducing the blast radius of generator and template changes" from advice into configuration a participant can apply on Monday, and it maps directly to Lab 4's deletion-protection exercise and Capstone fault #2.
- **Best delivery moment:** Directly after I-S5-03's arithmetic — the problem, then the three dials.
- **Visual / activity:** A small matrix: rows = create / update / delete; columns = the three policies; cells = allowed or refused.
- **Accuracy caveat:** These control the **Application objects**, while `preserveResourcesOnDeletion` controls the **workloads underneath**. Participants routinely conflate the two layers; separate them explicitly.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `operator-manual/applicationset/Controlling-Resource-Modification/`: `create-only` "prevents ApplicationSet controller from modifying or deleting Applications"; `create-update` "prevents ApplicationSet controller from deleting Applications (Update is allowed)"; a third option prevents modifying while allowing delete; `preserveResourcesOnDeletion: true` "prevents an Application's child resources from being deleted, when the parent Application is deleted." **Confirm the exact spelling of the third policy value (`create-delete`) and the full field path at 3.5.**

#### I-S5-06 · Preview is a real feature now, not a discipline `MODERN` `VISUAL`
- **Insight:** The outline asks for "previewing generated output before rollout," and as of the 3.5 line there are three ways to do it — one of them new:
  - `argocd appset generate <file>` — renders the Applications an ApplicationSet would produce.
  - `argocd appset create --dry-run <file>` — evaluates the template server-side and returns the Applications that would be managed.
  - **The Argo CD Web UI's ApplicationSet views**, new on the 3.5 line, including a **Preview tab** that renders what an ApplicationSet would generate, diffed against live state. Edits made in the Preview tab are never saved — it is a sandbox, and persisting a change still goes through Git or `kubectl apply`/`argocd appset create`. Generating a preview requires permission to create ApplicationSets in the target project; without it the tab returns a permission-denied message rather than a diff.
- **Why it is useful:** It turns "be careful" into a concrete pre-flight step, and it is the most current, most demonstrable thing in the session. It also carries its own governance lesson: **preview is read-only on purpose — Git remains the write interface.**
- **Best delivery moment:** Immediately after the blast-radius arithmetic. The answer to "how do I not do that" should arrive within a minute of the fear.
- **Visual / screenshot:** A dedicated capture of the ApplicationSet Preview tab on the course's own `v3.5.2` instance (this is **not** in blueprint §9 — recommend adding it as a new ID, e.g. `SS-05-03`, and flag the addition to `course-architect`).
- **Accuracy caveat:** ⚠️ **Maturity is unresolved.** The `release-3.5` docs page exists and describes the Preview tab, but an Argo Project blog post describes the ApplicationSet UI as read-only "in the alpha phase." Present it as **new and read-only**, teach the **CLI commands as the dependable path**, and do not build a required lab step on the UI until maturity and layout are confirmed against the live pinned instance.
- **Source / verification:** ⚠️ **Verified via search summaries only** (2026-09-10): `argo-cd.readthedocs.io/en/release-3.5/user-guide/application-set-ui/` (Preview tab renders generated Applications with a diff against live; "Edits in the Preview tab are never saved"; preview requires create-ApplicationSet permission in the target project); `user-guide/commands/argocd_appset_generate/` and `argocd_appset_create/` (`--dry-run` "will populate the returned ApplicationSet's status with the Applications which would be managed"); `blog.argoproj.io` post on the ApplicationSet UI (owner badge linking to parent; "read-only in the alpha phase"). **Route to `technical-source-check`.**

#### I-S5-07 · Deleting a root Application either deletes everything or deletes nothing `COUNTER` `FAILURE`
- **Insight:** With the `resources-finalizer.argocd.argoproj.io` finalizer on a root Application, deleting the root **cascades** to its children and their resources. Without it, deleting the root deletes only the Application object and leaves every child **orphaned but still running**. Two opposite footguns, one quiet annotation apart. A non-cascading delete explicitly removes the finalizer and leaves managed resources in place; foreground is the default cascading propagation policy, and `resources-finalizer.argocd.argoproj.io/background` selects background instead.
- **Why it is useful:** This is the "cascading deletion from a root Application" misconception the course must break, and it is the App-of-Apps counterpart to I-S5-05. The memorable form is the symmetry: **both outcomes are disasters, in opposite directions.**
- **Best delivery moment:** In the App-of-Apps ownership section, as the concrete consequence of "ownership flows between root and child."
- **Visual / screenshot:** The **App-of-Apps ownership flow** diagram (blueprint §11) drawn twice — with and without the finalizer — and the deletion outcome shaded in each. Pair with **SS-05-02**.
- **Accuracy caveat:** Be precise that the finalizer governs whether **managed resources** are cleaned up, and note that deletion behaviour from the Applications list versus the parent's resource tree was made consistent on the 3.x line (reported as of 3.2). **Confirm current behaviour at 3.5 before writing any deletion step.**
- **Source / verification:** ✅ Verified 2026-09-10 via search summaries of `user-guide/app_deletion/` and `operator-manual/cluster-bootstrapping/`: finalizer name and YAML placement; "if you want to ensure that child-apps and all of their resources are deleted when the parent-app is deleted make sure to add the appropriate finalizer"; non-cascading removes the finalizer and leaves resources running; foreground is the default propagation policy with a `/background` finalizer variant and a `--propagation-policy <foreground|background>` CLI flag; consistent deletion behaviour "starting in 3.2."

#### I-S5-08 · Two roots that both think they own a namespace `FAILURE` `TRADE-OFF`
- **Insight:** The outline says multiple roots "become difficult to reason about." The concrete reason: two root Applications whose children overlap is the GitOps equivalent of two `terraform apply` runs against one state file. Each root faithfully enforces its own view; the resource flaps; both roots report success. **Ownership must be a partition, not an overlap.**
- **Why it is useful:** It gives an abstract warning a mechanism, and the flapping-with-both-sides-green symptom is exactly what the Capstone's ownership fault feels like.
- **Best delivery moment:** As the closing beat of the App-of-Apps section, right before the decision table is revisited.
- **Visual / activity:** Two trees drawn overlapping at one node, with the contested node coloured. Quick Check: "Both roots say `Synced`. Is anything wrong?"
- **Source / verification:** Architectural reasoning. No product claim.

#### I-S5-09 · Leverage versus legibility — and the last row of the table `TRADE-OFF`
- **Insight:** State the trade-off cleanly: **ApplicationSet gives you leverage; App-of-Apps gives you legibility.** Leverage means one change moves forty things. Legibility means a human can read the tree and say what is supposed to exist. Most platform teams need both — which is exactly what the decision table's last row says: combine them **only with explicit ownership and deletion boundaries.**
- **Why it is useful:** It stops the session from resolving into "ApplicationSets are the advanced one," which is the most common wrong takeaway, and it explains why the table's final row carries a condition rather than a recommendation.
- **Best delivery moment:** The session's closing synthesis, with the decision table back on screen.
- **Visual / activity:** Ask for the condition in participants' own words: what does "explicit ownership and deletion boundaries" actually mean in a repo? (Answers should mention who writes which Application, and which layer holds the finalizer.)
- **Source / verification:** Outline's own table; framing only.

#### I-S5-10 · Progressive syncs: a timeout that promotes an unhealthy app to `Healthy` `COUNTER` `MODERN`
- **Insight:** Progressive syncing is off by default and enabled with `applicationsetcontroller.enable.progressive.syncs: true` (or `ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_PROGRESSIVE_SYNCS=true`). `RollingSync` groups generated Applications by labels/`matchExpressions` and rolls stage by stage, waiting for each group to become `Healthy`. **The detail that answers the outline's "when not to depend on it":** an Application considered `Pending` for `applicationsetcontroller.default.application.progressing.timeout` seconds (default **300**) is **automatically moved to `Healthy`** so the rollout can continue. A stage gate that gives up after five minutes and declares success is a *rollout convenience*, not a safety guarantee.
- **Why it is useful:** It is the rare version-dependent feature taught with a *specific reason* to be careful rather than a vague warning — and the reason is genuinely surprising.
- **Best delivery moment:** A clearly-marked, version-flagged **OPTIONAL** box at the end of the ApplicationSet material (blueprint §5.3).
- **Modern connection (one sentence, then stop):** this is Argo CD's *fleet-level* staged rollout. Per-application canary and blue/green with traffic shifting is Argo Rollouts' job — name the boundary so nobody expects canaries here, and do not expand.
- **Accuracy caveat:** ⚠️ Blueprint §8.3/§12 record Progressive Syncs as **Beta** (alpha since v2.6.0), and this pass corroborates Beta ("generally stable, but there may be unhandled edge cases"). That corroboration came from search summaries, not the `release-3.5` feature-maturity table. **Never present it as a stable default**, and re-confirm the label before S5 ships.
- **Source / verification:** ⚠️ **Verified via search summaries only** (2026-09-10): Progressive Syncs docs (enable flag/env var, default false; `RollingSync` label grouping; waits for `Healthy`; `applicationsetcontroller.default.application.progressing.timeout` default 300 with automatic promotion to `Healthy`; "respects sync windows and is performed with the same `syncPolicy` configured for the Application") and the Feature Maturity page (Beta). **Route to `technical-source-check`** to confirm the maturity label and `RollingSync` syntax at `v3.5.2`, and to confirm the blueprint's separate claim that `RollingSync` forces generated Applications to have auto-sync disabled — **that specific claim was not re-confirmed in this pass.**

#### I-S5-11 · Generators, taught by the question they answer `STICKY`
- **Insight:** Teach the three in-depth generators by the question each one answers, not by their fields: **list** — "here are the environments, I am telling you." **cluster** — "make one per cluster Argo CD already knows about." **Git** — "make one per directory or file in this repo, so adding an environment is adding a folder." Then name **matrix** ("every combination of two of the above") and **merge** ("combine outputs and let one override another on a key") with one example each.
- **Why it is useful:** Blueprint §5.3 explicitly demands generators be taught by *when you reach for each*, not as a field reference. The question-form makes the decision table's first and third rows self-evident.
- **Best delivery moment:** The generator section, in that order — list is the easiest to read, cluster is the one that fits the course's topology, Git is the one that scales with a team.
- **Visual / activity:** One small table: generator → the question → the data source. Offer **matrix** as Lab 4's stretch challenge (blueprint §5.3), not as class material.
- **Accuracy caveat:** The full generator set is larger than the outline's five — current docs also document **SCM Provider**, **Pull Request**, **Cluster Decision Resource**, and **Plugin**. Mention that the list is longer *in one sentence* for honesty, then stay inside the outline's five. Do not teach the others.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `operator-manual/applicationset/Generators/` and the per-generator pages: List, Cluster, Git, Matrix, Merge, SCM Provider, Pull Request, Cluster Decision Resource, Plugin. **Confirm the generator set and syntax at 3.5** (blueprint §12 already assigns this).

### Key takeaways — S5

> **"An ApplicationSet is a factory; App-of-Apps is a family tree. Use a factory when the list is derived, and a family tree when the list is decided."**
>
> **"ApplicationSets do not deploy anything. They write Applications — and Day 1's controller does the rest."**
>
> **"Every line in a template is multiplied by the generator. Count your Applications before you edit."**
>
> **"The dangerous ApplicationSet bug is not an error — it is a successful render of the wrong thing. `missingkey=error` turns that silence into a failure."**
>
> **"Deleting a root Application either deletes everything or deletes nothing. A finalizer decides which, and it decides quietly."**
>
> **"ApplicationSet gives you leverage; App-of-Apps gives you legibility. Combining them is fine — combining them without an ownership boundary is not."**

---

## Lab 4 — Build and troubleshoot the patterns
**File:** `courseware/day-2/lab-04-build-and-troubleshoot-patterns.md` · Lab · **MED** scaffolding · 75 min · Objectives 4, 7

> **Weighting note:** the longest lab in the course. Its spine is S5's decision table (for the comparison exercise) and S7's method (for the tracing exercise). New concepts are still explained fully; Day 1 mechanics are not re-explained.

#### I-L4-01 · Preview first, apply second — make it the lab's rhythm `STICKY`
- **Insight:** Sequence **every** ApplicationSet action in this lab as preview → count → apply. Before the first `kubectl apply`, run `argocd appset generate` and have participants read the generated Application names out loud. Establishing that rhythm is more valuable than any individual thing they build today, because it is the habit that survives contact with a real 40-cluster estate.
- **Why it is useful:** It is the operational form of I-S5-06 and the direct descendant of Lab 1's "read the diff before you sign it." It also makes the blast-radius exercise safe enough to actually perform.
- **Best delivery moment:** The lab's very first hands-on step, before anything is created.
- **Visual / activity:** Terminal output of `argocd appset generate` with the generated names highlighted; if the 3.5 Preview tab is confirmed usable, show it as the UI equivalent of the same command.
- **Accuracy caveat:** Make the **CLI** the required path and the UI Preview tab an optional "you can also" (see I-S5-06's maturity caveat).
- **Source / verification:** ✅ Command existence verified (I-S5-06). **Confirm exact flags/output at 3.5** before printing the command.

#### I-L4-02 · Predict the count *and* the names `VISUAL` `STICKY`
- **Insight:** Before applying, ask for two predictions: how many Applications this generator produces, and **what they will be called**. The count is easy. The names are where the learning is, because names come from the template and are therefore where template bugs first become visible.
- **Why it is useful:** It is Predict-Before-You-Sync adapted to fan-out, and it sets up the failure mode in I-L4-03, which is invisible unless you were already thinking about names.
- **Best delivery moment:** Immediately before each generator is applied — twice, so the second prediction is better than the first.
- **Visual / activity:** Participants write predicted names, then diff against `argocd appset generate` output. Being wrong is the useful outcome.
- **Source / verification:** Pedagogical.

#### I-L4-03 · Two generator entries that render the same name do not error — they fight `FAILURE` `COUNTER`
- **Insight:** If a template produces the same `metadata.name` for two generator entries, you do not get a collision error and you do not get two Applications. You get **one** Application whose spec is repeatedly rewritten by whichever entry was reconciled last. Symptom: an Application that changes its own source or destination on a cycle, with nothing in Git changing.
- **Why it is useful:** It is a real, under-taught ApplicationSet failure, it is a superb Root-Cause Detective scenario, and it teaches that **the absence of an error is not the presence of correctness** — the same lesson as `missingkey=error`, in a different costume.
- **Best delivery moment:** As a diagnostic exercise in the lab's troubleshooting half, or as a strong stretch challenge if time is short.
- **Visual / activity:** Present the flapping Application without showing the generator; ask what could possibly cause a spec to change with no commits. Reveal the template.
- **Accuracy caveat:** ⚠️ **Reasoned from the controller's reconciliation model, not confirmed against a primary source in this pass.** Validate the exact observed behaviour with `lab-tester` in the real environment before shipping it as a scenario, and adjust the described symptom to whatever actually happens.
- **Source / verification:** ⚠️ **Unverified.** Route to `technical-source-check` and to `lab-tester` for empirical confirmation.

#### I-L4-04 · Run the `missingkey=error` demonstration twice `VISUAL` `COUNTER`
- **Insight:** Do it without the option first: a value is missing, the Application is created with an empty field, it appears in the list looking normal, and it fails later at a different layer. Then add `goTemplateOptions: ["missingkey=error"]` and repeat: the ApplicationSet reports a template error and generates nothing.
- **Why it is useful:** Two runs, one variable, and the counterintuitive conclusion arrives on its own: **the safer configuration failed more, sooner, and louder — and that is why it is safer.** Participants who only see the safe version never feel why it matters.
- **Best delivery moment:** Directly after the first successful generation, while the mechanism is fresh.
- **Visual / activity:** Two screenshots side by side: a silently-wrong Application vs a refused generation. Ask which one they would rather get at 4 p.m. on a Friday.
- **Source / verification:** ✅ Option and default behaviour verified at I-S5-04. Exact error text from `lab-tester`.

#### I-L4-05 · Zero is a valid generator output `FAILURE` `COUNTER`
- **Insight:** A cluster generator with a label selector that stops matching — because someone removed a label from a cluster Secret — does not error. It produces **zero** parameters, therefore zero Applications. And if the sync policy permits deletion, the existing generated Applications are now *extra*, so they are removed. A label edit becomes a fleet-wide deletion, and every component involved behaved correctly.
- **Why it is useful:** It is the most alarming and most instructive ApplicationSet failure available, it maps directly onto Capstone fault #2 ("an ApplicationSet change with an unexpectedly large blast radius"), and it is the clearest justification for `create-only`/`create-update` that exists.
- **Best delivery moment:** As the motivation immediately before the deletion-protection exercise, so the protection is applied as a response to a felt danger.
- **Visual / activity:** Predict-then-observe with protection **on**: set `applicationsSync: create-update`, break the selector, and watch the controller decline to delete. Preview the change first (I-L4-01) so the count drop is visible before anything happens.
- **Accuracy caveat:** Perform this **only** with deletion protection enabled or in a fully resettable state. `environment-engineer` owns the reset path (blueprint §8.6).
- **Source / verification:** ✅ Policy names and semantics verified at I-S5-05; cluster-generator behaviour per `Generators-Cluster` docs. **`lab-tester` confirms observed behaviour.**

#### I-L4-06 · Fix the layer that owns the field, not the layer where the symptom appeared `STICKY`
- **Insight:** A generated child Application is wrong. Editing it directly appears to work — and is reverted, because something above it owns that field. The tracing chain is always the same: **failing resource → the child Application's spec → who wrote that spec (a person, a root Application, or an ApplicationSet) → the file in Git that produced it.** The rule: **if your fix reverted, you fixed the wrong layer.**
- **Why it is useful:** It is Lab 4's central skill, it is the same lesson as self-heal one level up (which makes it a retrieval event, not a new idea), and it is the Capstone's ownership fault stated in advance.
- **Best delivery moment:** The parent/child tracing exercise — the lab's diagnostic centrepiece.
- **Visual / screenshot:** **SS-L4-04** (root → child hierarchy with an injected child error traced). If confirmed present at 3.5, the **owner badge** on a generated Application's resource tree — which names the parent and links to it — makes this trace a single click; capture it.
- **Accuracy caveat:** ⚠️ The owner badge is reported in an Argo Project blog post about the ApplicationSet UI, not confirmed in the `release-3.5` docs during this pass. Teach the **trace by hand** as the required path and treat the badge as a shortcut to confirm live.
- **Source / verification:** ⚠️ Owner-badge claim **unverified** (blog only). Ownership/tracing reasoning is architectural and safe. Route the badge to `technical-source-check`.

#### I-L4-07 · Pattern Showdown, scored on operations rather than taste `TRADE-OFF`
- **Insight:** The outline's comparison bullet becomes a real exercise if it is scored on four operational questions rather than preference. Implement "the same app in dev, staging, and prod" both ways, then answer for each: **(1)** How do you add environment #4? **(2)** How do you remove environment #2 — and what does the tool do to its resources? **(3)** Who reviews that change, and can they tell what it will do? **(4)** What does a single typo cost?
- **Why it is useful:** It converts the decision table from something read into something *derived*, and question (4) forces the blast-radius arithmetic and the deletion semantics to be recalled together, which is exactly the synthesis this lab exists for.
- **Best delivery moment:** The lab's final exercise, after both patterns have been built and broken.
- **Visual / activity:** A four-row comparison grid participants fill in themselves; the debrief compares their grid against the decision table.
- **Accuracy caveat:** There is no winner. A guide that implies ApplicationSet "wins" has broken the session's main point (I-S5-09).
- **Source / verification:** Outline's own comparison bullet and decision table.

#### I-L4-08 · Rehearse steps 1–5, and notice that step 5 is new `STICKY`
- **Insight:** The tracing drill in this lab requires something Lab 3 did not: **inspecting the responsible component** — asking whether the ApplicationSet controller itself did what it was supposed to do. That is step 5 of the method. Name it at the close: "you have now used five of the six steps."
- **Why it is useful:** It continues the deliberate laddering (Lab 1 → steps 1–4 on a known change; Lab 3 → steps 1–4 on an unknown failure; Lab 4 → step 5 appears), so S7 lands as a naming ceremony and the Capstone as an exam on something already practised.
- **Best delivery moment:** Closing beat, before Key Takeaways.
- **Accuracy caveat:** Use the outline's exact step wording (blueprint §7 anchor).
- **Source / verification:** Internal course structure.

### Key takeaways — Lab 4

> **"Preview before you apply. `argocd appset generate` costs three seconds; a rollback costs an afternoon."**
>
> **"Zero is a valid generator output — and where deletion is allowed, zero means delete them all."**
>
> **"If your fix reverted, you fixed the wrong layer. Trace up until you find who owns the field."**
>
> **"Two generator entries that render the same Application name do not error. They fight, and the loser changes every few minutes."**
>
> **"The absence of an error is not the presence of correctness."**

---

## S6 — Security, multi-tenancy, and governance
**File:** `courseware/day-2/06-security-multitenancy-governance.md` · Concept · 45 min · Objective 6

> **Scope guard (blueprint §5.3):** **SSO is conceptual only** — group-to-role mapping and removing routine admin access. **No live identity-provider integration.** That constraint is what protects the 45 minutes. API accounts and tokens are an OPTIONAL box.

#### I-S6-01 · Three fences, three different escapes `STICKY` `VISUAL`
- **Insight:** There are three independent boundaries, and confusing them is the source of most Argo CD security confusion:
  - **AppProject** fences *what an Application may point at* — which repositories, which cluster/namespace destinations, which resource kinds.
  - **Argo CD RBAC** fences *what a person may do inside Argo CD* — see, sync, override, delete.
  - **Kubernetes RBAC** fences *what the ServiceAccount may do to the cluster* — the API server's own answer.
  Escaping one is not escaping another, and each fails in a distinguishable way.
- **Why it is useful:** It gives the whole session a structure participants can hold, and it is the frame that makes Lab 5's side-by-side denial comparison legible rather than fiddly.
- **Best delivery moment:** The first two minutes, as the session's map.
- **Visual / screenshot:** The **AppProject/RBAC boundary** diagram (blueprint §11) drawn as three nested or adjacent fences with a different actor at each. Pair with **SS-06-01**.
- **Source / verification:** Structural; individual mechanisms verified below.

#### I-S6-02 · Argo CD RBAC is about the button; Kubernetes RBAC is about the cluster `STICKY` `COUNTER`
- **Insight:** The cleanest distinction of the day, and the outline asks for it explicitly. An **Argo CD RBAC denial** means *you cannot press sync* — the request is refused at the Argo CD layer and **no sync operation ever starts**. A **Kubernetes RBAC denial** means *Argo CD pressed sync on your behalf and the API server said no* — a sync operation **does** start and then **fails**, with a `forbidden` error inside the sync result. Same colour badge, two different systems, two different teams.
- **Why it is useful:** It is the single most practically useful diagnostic distinction in the governance material, and it yields a field-usable rule: **if the sync never started, it is Argo CD; if the sync started and failed, it is Kubernetes.**
- **Best delivery moment:** As the centre of the RBAC section, and as the explicit set-up for Lab 5's comparison exercise.
- **Visual / activity:** A two-column table: where the error appears, what the message names, who owns the fix, what you change. Quick Check: "A team reports 'permission denied.' What is your first question?" (Did a sync operation run?)
- **Accuracy caveat:** Get the mechanism right — an AppProject destination violation is an **Argo CD**-layer refusal, while a resource the `argocd-manager` ServiceAccount may not create is a **Kubernetes**-layer refusal. `lab-engineer` must confirm the exact error text of both against the live instance rather than paraphrasing.
- **Source / verification:** ✅ RBAC model verified via search summary of `operator-manual/rbac/` (policy form `p, subject, resource, action, object, effect`; group bindings `g, <group>, <role>`; "if you want to assign policies to a group, you must first assign a role to it"). **Confirm both error messages empirically** — `lab-tester`.

#### I-S6-03 · By default, Argo CD's cluster credential is more powerful than any of your users `COUNTER`
- **Insight:** Every application team's sync runs as the **same** `argocd-manager` ServiceAccount on the workload cluster. Kubernetes therefore cannot tell your tenants apart — from the API server's point of view there is exactly one client. That is why AppProject destinations matter so much: **for tenancy, Argo CD is the only thing enforcing the boundary**, and Kubernetes RBAC cannot help you.
- **Why it is useful:** It is genuinely uncomfortable and genuinely true, and it explains why "we have Kubernetes RBAC" is not an answer to "how do you isolate tenants in Argo CD." It also makes the impersonation feature comprehensible as a solution to a specific problem rather than an exotic option.
- **Best delivery moment:** In the multi-tenancy section, as the reason AppProjects carry so much weight.
- **Visual / activity:** Draw three tenants collapsing into one ServiceAccount at the cluster boundary. Discussion prompt: "Your auditor asks how Kubernetes knows which team deployed this. What do you say?"
- **Modern connection (name and move on):** Argo CD documents **sync using impersonation** — an AppProject's `destinationServiceAccounts` maps a destination server/namespace to a ServiceAccount used for that sync, so the cluster finally sees per-tenant identity, while the cluster credential is reserved for control-plane operations.
- **Accuracy caveat:** ⚠️ **Maturity not confirmed.** The impersonation docs were reached at `/latest/`, which tracks `master`. Present impersonation as **a named direction to investigate**, not as a lab step or a recommendation, until its availability and maturity at `v3.5.2` are confirmed.
- **Source / verification:** ⚠️ **Verified via search summary only** (2026-09-10), and from `/latest/`: `operator-manual/app-sync-using-impersonation/` — `AppProject.spec.destinationServiceAccounts` with `defaultServiceAccount` per destination server/namespace, used for impersonation during sync. **Route to `technical-source-check`.**

#### I-S6-04 · Letting a team create Applications is letting them deploy anywhere the project allows `COUNTER`
- **Insight:** An Application is just a custom resource. Whoever can create one in a namespace Argo CD watches has, in effect, been granted deployment rights — bounded only by the AppProject it names and by which projects they may use. The outline's bullet, "security implications of allowing teams to create Applications or ApplicationSets," resolves to exactly this: **the AppProject is the grant, and the ability to create an Application is the exercise of it.**
- **Why it is useful:** It reframes self-service from a permissions question into a *project design* question, which is the actual platform-engineering decision and the natural bridge to internal developer platforms.
- **Best delivery moment:** Late in the session, once AppProjects and RBAC are both established.
- **Visual / activity:** Quick Check: "You give a team `kubectl` create rights on Applications in the `argocd` namespace. What have you just granted?"
- **Accuracy caveat:** The mechanics of Applications in non-control-plane namespaces (`sourceNamespaces` / apps-in-any-namespace) are real and current but **out of the outline's scope at this depth**. Name the capability in one sentence; do not teach the configuration.
- **Source / verification:** Follows from the AppProject/RBAC model (I-S6-01/02). **Confirm `sourceNamespaces` semantics at 3.5** if the sentence ships.

#### I-S6-05 · Commit the pointer, never the payload — the governance version `STICKY`
- **Insight:** Revisit I-S3-05 at governance depth. The rule is unchanged; what is added is the audit consequence: **a secret in Git is not just exposed, it is exposed retroactively and permanently**, because history is the point of Git. Rotating it does not un-commit it.
- **Why it is useful:** Deliberate spaced reinforcement of a Day 1 idea in a new frame (blueprint §4 through-line requirement), and the "retroactive and permanent" phrasing is what makes people actually change behaviour.
- **Best delivery moment:** The secrets section — short, because the pattern is already known.
- **Visual / activity:** One sentence and a question: "Your token was committed on Tuesday and rotated on Wednesday. Who could still read it?"
- **Accuracy caveat:** Keep tool names generic (CLAUDE.md: no tooling survey).
- **Source / verification:** Git property, not an Argo CD claim.

#### I-S6-06 · Deployment windows are change-freeze as code — and the escape hatch is the interesting part `MODERN` `TRADE-OFF`
- **Insight:** AppProject **sync windows** are allow/deny rules with a schedule and duration, scoped to applications, namespaces, or clusters, with a `manualSync` setting that permits manual syncs inside a restricted window. The governance insight is not the window — it is the escape hatch: **every real change freeze has one, and the auditable question is who may use it and whether its use is recorded.**
- **Why it is useful:** It connects a niche-looking feature to something every regulated organisation already argues about, and it teaches participants to evaluate controls by their exceptions.
- **Best delivery moment:** In the auditability / higher-environment controls section.
- **Visual / activity:** Discussion prompt: "Your freeze window is on and production is down. Who can sync, and where does that decision show up afterwards?"
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `user-guide/sync_windows/` and `operator-manual/project-specification/`: windows declared in the AppProject with kind (allow/deny), schedule, duration; scoped to applications/namespaces/clusters; `manualSync` permits manual syncs during restricted windows; `argocd proj windows list PROJECT` / `argocd proj windows enable-manual-sync` exist. **Confirm schedule syntax and CLI at 3.5** before any step relies on it.

#### I-S6-07 · Guardrails are what make the audit trail true `STICKY` `MODERN`
- **Insight:** "Every deployment is a commit, so we have a complete audit trail" is only true if nobody can deploy *without* going through Argo CD. If engineers retain direct `kubectl` write access to the workload clusters, the Git history is a record of what people *usually* did. Guardrails are not bureaucracy layered on top of GitOps — **they are the precondition that makes GitOps' central claim factual.**
- **Why it is useful:** It is the session's thesis in one sentence and it reframes governance from "friction" to "the thing that makes the benefit real," which is the argument participants will actually need to make internally.
- **Best delivery moment:** The session's closing synthesis.
- **Modern connection (one sentence each, then stop):** AppProjects are Argo CD's own guardrail layer; cluster-side policy engines (Kyverno, OPA Gatekeeper) enforce what AppProjects cannot express, such as image-registry provenance. Defence in depth — two sentences, not a survey.
- **Source / verification:** Architectural reasoning. Tool names are category examples only.

### Key takeaways — S6

> **"Argo CD RBAC decides who may press the button. Kubernetes RBAC decides whether the cluster obeys it. You need both, and they fail differently."**
>
> **"If the sync never started, it is Argo CD. If the sync started and failed, it is Kubernetes."**
>
> **"An AppProject fences the Application; RBAC fences the person. Neither substitutes for the other."**
>
> **"Every tenant syncs as the same ServiceAccount, so Kubernetes cannot tell your tenants apart. For tenancy, Argo CD is the only fence you have."**
>
> **"Commit the pointer, never the payload — a secret in Git is exposed retroactively and permanently."**
>
> **"Without guardrails, the audit trail is a story about what people usually did."**

---

## Lab 5 — Enforce platform guardrails
**File:** `courseware/day-2/lab-05-enforce-platform-guardrails.md` · Lab · **MED-LIGHT** scaffolding · 45 min · Objective 6

> **Weighting note:** the shortest lab, and the most tightly scoped. Its entire shape is **Guardrail Bypass Attempt** — build the fence, then genuinely try to walk through it, and read the exact error each time. The learning is in the error text, not in the success.

#### I-L5-01 · A guardrail you have never tried to break is a guardrail you do not have `STICKY`
- **Insight:** Frame the whole lab this way in its first paragraph. Configuring an AppProject restriction produces no feedback that it works. The only evidence a fence exists is an attempt that was refused, and the only evidence it is a *good* fence is that the refusal said something useful.
- **Why it is useful:** It sets the lab's success criterion as a **failed action**, which is unusual enough to be memorable and correct enough to change how participants ship guardrails at work.
- **Best delivery moment:** The lab's "Why this matters" section — one sentence, load-bearing.
- **Visual / activity:** State the lab's shape up front: three deliberate bypass attempts, three error messages, three explanations of which system refused.
- **Source / verification:** Pedagogical framing.

#### I-L5-02 · Two denials, side by side — the lab's centrepiece `VISUAL` `COUNTER`
- **Insight:** Engineer the exercise so participants trigger both, in the same sitting, minutes apart:
  - **(a) An Argo CD denial.** An Application whose destination namespace or cluster is not in the project's `destinations` allow-list is refused at the Argo CD layer. **No sync operation runs.**
  - **(b) A Kubernetes denial.** A permitted Application syncing something the ServiceAccount may not create — or a cluster-scoped kind excluded by `clusterResourceWhitelist` — produces a sync that **starts and then fails**, with a `forbidden` error from the API server inside the sync result.
  Then ask the question that makes it stick: **"Which team do you page?"**
- **Why it is useful:** It is the outline's explicit bullet ("compare an Argo CD authorization failure with a Kubernetes authorization failure"), it converts I-S6-02 from a table into an experience, and it produces a diagnostic rule participants keep.
- **Best delivery moment:** The core guided walkthrough — this is what the 45 minutes are for.
- **Visual / screenshot:** **SS-L5-03** (Argo CD denial) and **SS-L5-04** (Kubernetes denial), deliberately captured to be shown **adjacent**, with the differing region highlighted in each. These two screenshots are the most important pair in the lab.
- **Accuracy caveat:** Both error texts must be captured from the real `v3.5.2` instance. Never paraphrase or invent an authorization message (CLAUDE.md).
- **Source / verification:** ✅ Mechanism verified at I-S6-02. Exact messages from `lab-tester` on execution.

#### I-L5-03 · Unit-test the permission model before your users find the bug `MODERN` `STICKY`
- **Insight:** `argocd admin settings rbac can` evaluates whether a given subject is permitted a given action on a given object, and `argocd admin settings rbac validate` checks a policy for validity. That means an RBAC policy is **testable before it is deployed** — which is what "policy as code" actually means in practice, as opposed to as a slogan.
- **Why it is useful:** It gives participants a tool most have never seen, it makes the policy-as-code connection concrete rather than aspirational, and it is exactly the kind of thing a platform engineer can put in CI on Monday.
- **Best delivery moment:** After the first denial is observed — "you just discovered that by trying it; here is how to know beforehand."
- **Visual / activity:** Write the expected answer first, run the command, compare. Optional stretch: propose where in a pipeline this check would live.
- **Accuracy caveat:** ⚠️ The command reference pages found in this pass were on older release paths (2.x) plus `/latest/`. **Confirm the command exists with this exact spelling and syntax at `v3.5.2`** before it becomes a lab step.
- **Source / verification:** ⚠️ **Partially verified** (2026-09-10): `argocd admin settings rbac can` and `argocd admin settings rbac validate` command-reference pages exist on `argo-cd.readthedocs.io`, observed on release-2.x and `/latest/` paths. **Route to `technical-source-check` for a 3.5 confirmation.**

#### I-L5-04 · Close the default project and watch something legitimate stop `FAILURE` `TRADE-OFF`
- **Insight:** Empty the `default` AppProject's allow-lists (I-S3-02) and watch a previously-working scratch application stop being able to sync. This is a **safe rehearsal of a real hardening change**, and it makes the blast radius of a guardrail concrete in the direction people forget: guardrails break things too, and they break them for people who were not doing anything wrong.
- **Why it is useful:** It closes the loop on a Day 1 insight, it teaches that hardening is a change with its own rollout risk, and it produces the practice rule: **roll a fence out in a lower environment first, exactly like any other change.**
- **Best delivery moment:** Early in the lab, as the first hands-on action — it is fast, it is reversible, and it establishes stakes.
- **Visual / activity:** Predict first: "After this change, which existing applications stop working?" Most people underestimate.
- **Accuracy caveat:** Requires a clean reset path. `environment-engineer` owns `reset-lab.sh` for this lab (blueprint §8.6).
- **Source / verification:** ✅ Verified at I-S3-02 (empty `sourceRepos` / `sourceNamespaces` / `destinations` removes all permissions from `default`). **Confirm the field set at 3.5.**

#### I-L5-05 · The guardrail that forgot a kind `FAILURE`
- **Insight:** A `clusterResourceWhitelist` that omits `CustomResourceDefinition` works perfectly — until the day a team adopts a chart that ships a CRD. Then a sync fails for a reason nobody changed, in a component nobody touched, and the error names a Kubernetes kind rather than a policy. The lesson: **a guardrail must be tested against the full set of things a real chart deploys, not against the happy path you had in mind when you wrote it.**
- **Why it is useful:** It is a realistic incident with an unglamorous cause, it reinforces the Argo-vs-Kubernetes denial distinction from a third angle, and it produces a concrete practice (enumerate what your real charts actually create).
- **Best delivery moment:** In Troubleshooting, as "likely failure → likely cause → fix," or as the lab's stretch challenge.
- **Visual / activity:** Show the allow-list and a chart's resource inventory side by side and ask what is missing before revealing the error.
- **Source / verification:** ✅ `clusterResourceWhitelist` is a documented AppProject field (I-S3-02 / project specification). **Confirm field name at 3.5**; scenario validated by `lab-tester`.

#### I-L5-06 · Deletion protection is a guardrail too — and it links Lab 4 to Lab 5 `STICKY`
- **Insight:** The outline places "protect generated Applications from unintended deletion" in **both** Lab 4 and Lab 5. Treat that as deliberate: Lab 4 applies protection as a *blast-radius* control on a factory; Lab 5 revisits the same controls as a *governance* boundary — who is allowed to cause a deletion at all. Same settings (`applicationsSync`, `preserveResourcesOnDeletion`, `Prune=false`), two different arguments for them.
- **Why it is useful:** It gives the two labs a shared object rather than duplicated content, and it demonstrates that a control's justification depends on who is asking.
- **Best delivery moment:** As the bridge between the AppProject work and the deletion-protection step.
- **Accuracy caveat:** Do not re-teach the mechanics from Lab 4. Reference them and spend the time on the governance framing (scaffolding-reduction rule).
- **Source / verification:** ✅ Control names verified at I-S5-05 and I-S4-05.

#### I-L5-07 · A good guardrail fails loudly and names the rule `TRADE-OFF`
- **Insight:** Every guardrail you add is a support ticket someone will eventually file. The right question is not "is this too restrictive?" but **"is the failure obvious, and can the person fix it themselves?"** A denial that names the project and the disallowed destination is a good guardrail. A denial that says only "forbidden" is a bad one, even if it enforces exactly the same rule.
- **Why it is useful:** It gives participants a design criterion for guardrails rather than a list of them, and it is a direct rehearsal of the Capstone's "explain the guardrail that would prevent recurrence" step — where a guardrail nobody can interpret is not actually prevention.
- **Best delivery moment:** The lab's closing debrief, evaluating the error messages they collected during the bypass attempts.
- **Visual / activity:** Rank the three error messages they triggered from most to least self-serviceable, and say what would improve the worst one.
- **Source / verification:** Design judgement over the observed messages.

### Key takeaways — Lab 5

> **"A guardrail you have never tried to break is a guardrail you do not have."**
>
> **"Two denials, two systems: if the sync never started, it is Argo CD. If the sync started and failed, it is Kubernetes."**
>
> **"`argocd admin settings rbac can` is a unit test for your permission model. Write it before your users find the bug."**
>
> **"Hardening is a change, with a change's blast radius. Roll a fence out in a lower environment first."**
>
> **"A good guardrail fails loudly and names the rule it enforced. A silent denial is a support ticket wearing a security badge."**

---

## S7 — Reliability, troubleshooting, and lifecycle operations
**File:** `courseware/day-2/07-reliability-troubleshooting-lifecycle.md` · Concept · 75 min · Objectives 2, 7, 8

> **Priority guard (blueprint §5.3 / §13):** the worst overload in the course. Budget **30 min** for the troubleshooting method (the last thing cut, never the first), **25 min** for stability/observability/scale, **20 min** for backup/recovery/upgrades. Capacity factors are a **reference table**. The internal-fork bullet is a **one-page box plus a 3-minute discussion** and is the only pre-authorised compression in the course.

#### I-S7-01 · Walk the pipeline in the direction the data flows, and stop at the first step that lies to you `STICKY` `VISUAL`
- **Insight:** The outline's six steps are not a checklist — they are a **walk down the pipeline in the same order the data travels**: Git source and revision → repository access and rendering → rendered versus live → sync results, hooks, events, and Kubernetes health → the responsible component and its metrics → correct the source and verify. The ordering is not arbitrary: **you cannot diagnose a comparison until you trust both sides of it**, so the source and the rendering must be established before the diff means anything.
- **Why it is useful:** A method participants understand the *reason* for is a method they will still use in six months. The pipeline framing also makes the order re-derivable when they have forgotten the list.
- **Best delivery moment:** The opening 30 minutes — the session's and the day's priority anchor.
- **Visual / screenshot:** The **troubleshooting-method flow** diagram (blueprint §11), drawn as a pipeline with the six steps as stations, not as a decision tree with branches. Reused verbatim in the Capstone.
- **Accuracy caveat:** Use the outline's exact step wording. This is a blueprint §7 structural anchor — no paraphrasing into a competing list, in this file or any other.
- **Source / verification:** Outline §7, verbatim.

#### I-S7-02 · Each step names exactly one component — so finding the step finds the pod `STICKY`
- **Insight:** Overlay the six steps onto S2's one-verb-per-component model and they line up: source and revision → **Git** (external). Repository access and rendering → **repo-server**. Rendered versus live → **application-controller**. Sync results, hooks, events, health → **application-controller** plus the **target cluster's API server**. Responsible component and metrics → whichever component the previous steps implicated. Correct and verify → **Git**, then the loop again.
- **Why it is useful:** This is the highest-value sentence in S7. It converts a diagnostic procedure into a *localisation* procedure: identifying the failing step tells you which pod's logs to open. It also pays off the Day 1 investment in I-S2-01, which is exactly the retrieval structure the blueprint asks for.
- **Best delivery moment:** Immediately after the six steps are stated — before any example.
- **Visual / activity:** The pipeline diagram with a component name under each station. Quick Check: "Manifests are stale even after a refresh. Which step, and which pod?"
- **Source / verification:** Composition of two verified models (I-S2-01 and the outline's method).

#### I-S7-03 · Sharding splits clusters, not Applications `COUNTER` `TRADE-OFF`
- **Insight:** Scaling the application-controller means running more replicas and distributing **clusters** across them. **Applications are not the unit of distribution.** So a single cluster with 5,000 Applications cannot be split across controller replicas — adding replicas does nothing for it. The fix is architectural (more clusters, or a bigger shard), not a config change. Supporting facts worth stating: supported sharding algorithms are `legacy` (default), `round-robin`, and `consistent-hashing`; classic sharding uses `ARGOCD_CONTROLLER_REPLICAS` with StatefulSet ordinals and requires restarting pods to redistribute; **dynamic cluster distribution** (available since v2.9) instead reads the replica count from the controller Deployment and rebalances via an `argocd-app-controller-shard-cm` ConfigMap with heartbeats, avoiding the full restart.
- **Why it is useful:** It is the best engineering trade-off in S7 because it changes an **architecture decision**, not a setting — and it is the kind of thing teams discover far too late. It also explains a mystery ("we added replicas and nothing improved").
- **Best delivery moment:** The stability/scale block, as the headline fact about controller scaling.
- **Visual / activity:** Two diagrams: N clusters spread across 3 replicas (works), and 1 cluster with 5,000 apps facing 3 replicas (one replica does everything). Quick Check: "Your busiest cluster is the bottleneck. Does adding a controller replica help?"
- **Accuracy caveat:** Present both the classic and dynamic mechanisms, and be explicit that the details differ between them. Do **not** state a specific "applications per shard" number — that is capacity guidance the blueprint marks as reference depth, and it is deployment-dependent.
- **Source / verification:** ✅ Verified 2026-09-10 via search summaries of `operator-manual/high_availability/`, `operator-manual/dynamic-cluster-distribution/`, and the application-controller command reference: replicas + `ARGOCD_CONTROLLER_REPLICAS`; algorithms `[legacy, round-robin, consistent-hashing]` (default `legacy`); shard assignment per cluster, with a cluster forceable to a shard via the `shard` field in its cluster Secret; StatefulSet ordinal-based shard identity and the restart requirement; dynamic distribution since v2.9 reading replicas from the Deployment and using `argocd-app-controller-shard-cm`. **Confirm the default algorithm and the dynamic-distribution defaults at 3.5.**

#### I-S7-04 · Repo-server concurrency can collapse to one `COUNTER` `FAILURE`
- **Insight:** `--parallelismlimit` caps concurrent manifest generations to avoid OOM kills — but there is a sharper constraint underneath it: **if manifest generation needs to modify files in the local repository clone (as `helm dependency build` does), only one concurrent generation per repo-server instance is allowed.** That is why a monorepo with 50+ applications feels serialised no matter how much CPU you give it. Related, documented levers: generated manifests are cached (24h by default, tunable with `--repo-cache-expiration`), the `argocd.argoproj.io/manifest-generate-paths` annotation limits what is sent for generation, and the repo-server enforces a **90-second** exec timeout on tools like `helm` and `kustomize`, changeable via `ARGOCD_EXEC_TIMEOUT`.
- **Why it is useful:** It explains the outline's "monorepo pressure" bullet mechanically instead of vaguely, and it yields the best small failure story in S7 (below).
- **Best delivery moment:** The stability/scale block, immediately after sharding — controller scaling, then rendering scaling.
- **Failure story — *the chart that got five seconds too big*:** a chart grows slowly over months. One day it renders in 95 seconds. The 90-second exec timeout fires. The symptom is a rendering error that looks like a chart bug, arriving on a day when nobody changed the chart meaningfully. The cause is a threshold, not a defect.
- **Visual / activity:** Discussion prompt: "Your monorepo's syncs got slow after you added twenty apps and CPU is idle. What is the constraint?"
- **Accuracy caveat:** Quote the defaults as defaults and flag that HA-docs numbers must be re-checked at 3.5. Do not turn this into a tuning cookbook — blueprint marks capacity work as reference depth.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `operator-manual/high_availability/` and the repo-server command reference: `--parallelismlimit` semantics; "if the manifest generation requires to change a file in the local repository clone then only one concurrent manifest generation per server instance is allowed"; monorepo slowdown noted at 50+ apps; manifests cached 24h with `--repo-cache-expiration`; "the `argocd-repo-server` executes config management tools such as `helm` or `kustomize` and enforces a 90 second timeout, which can be changed by using the `ARGOCD_EXEC_TIMEOUT` env variable"; `argocd.argoproj.io/manifest-generate-paths`. **Confirm all defaults at 3.5.**

#### I-S7-05 · Every ignore rule is a promise that something else owns that field `COUNTER` `TRADE-OFF`
- **Insight:** `ignoreDifferences` (per-Application, or system-wide via `resource.customizations` in `argocd-cm`, using JSON pointers or `jqPathExpressions`) is how you stop an HPA-managed replica count or an injected sidecar from producing permanent, meaningless `OutOfSync`. It is also, in exactly the same motion, how you make a *real* change invisible forever. The discipline: **an ignore rule should name a field, not a resource, and every ignore rule needs a written owner** — the system that is now responsible for that field. If nothing owns it, you have not silenced noise; you have built a blind spot.
- **Why it is useful:** The outline explicitly calls for "avoiding ignore rules that conceal meaningful drift," and this converts that warning into a reviewable rule with a test ("name the owner"). It is also a direct set-up for the Capstone's noisy-drift fault.
- **Best delivery moment:** In the observability block, immediately after custom health checks and diff customisations are introduced.
- **Visual / activity:** Show a field-scoped ignore rule and a resource-scoped one side by side and ask which one could hide a security-relevant change.
- **Accuracy caveat:** Do not present ignore rules as bad. They are necessary — HPA and admission-webhook mutation are real. The rule is about *scope* and *accountability*, not abstinence.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `user-guide/diffing/`: Application-level `ignoreDifferences` and system-level `resource.customizations` in `argocd-cm`; RFC6902 JSON patches and `jqPathExpressions`; `resource.compareoptions` including `ignoreResourceStatusField`. **Confirm syntax at 3.5.**

#### I-S7-06 · If Argo CD is truly declarative, losing the management cluster is a rebuild, not a restore `STICKY` `COUNTER`
- **Insight:** Argo CD's persistent state is Kubernetes objects in etcd — Applications, AppProjects, ApplicationSets, `argocd-cm`/`argocd-rbac-cm`, and the repository and cluster Secrets. Redis is a disposable cache (I-S2-06). So the backup question has a sharper form than "what do we back up?": **whatever is genuinely in Git does not need restoring — it needs re-applying.** `argocd admin export` and `argocd admin import` exist for the parts that never made it into Git. Which means the size of your export file is a measurement: **it is a receipt for everything you forgot to declare.**
- **Why it is useful:** It reframes backup from a chore into a *diagnostic of your own maturity*, which is far more memorable than a procedure, and it gives teams a concrete self-assessment they can run next week.
- **Best delivery moment:** Opening the backup/recovery block — it makes the rest of the block make sense.
- **Visual / activity:** The **backup/recovery** diagram (blueprint §11): persistent Kubernetes objects on one side, disposable cache on the other, with the export/import path drawn between. Quick Check: "Your management cluster is gone. What do you actually need to have kept?"
- **Accuracy caveat:** Do **not** let this become "you do not need backups." The credentials in cluster and repository Secrets, and anything configured through the UI, are exactly the parts that are usually *not* in Git — which is why the export exists and why it must be protected as sensitive.
- **Source / verification:** ✅ Verified 2026-09-10 via search summary of `operator-manual/disaster_recovery/` and the `argocd admin export`/`import` command references: "Argo CD is largely stateless. All data is persisted as Kubernetes objects... Redis is only used as a disposable cache and can be safely rebuilt without service disruption"; `argocd admin export > backup.yaml` / `argocd admin import - < backup.yaml`. **Confirm export/import semantics and flags at 3.5** (blueprint §12 assigns this).

#### I-S7-07 · Upgrading Argo CD can change your manifests — so rehearse the render, not just the rollback `COUNTER` `FAILURE`
- **Insight:** Bring I-S4-02 forward as the upgrade section's anchor. Because Argo CD renders your charts, **its bundled Helm version is part of your desired state**, and the 3.4 → 3.5 upgrade replaced the chart renderer with Helm 4 — changing null/nil coalescing so that identical charts and values can render different manifests. The practice that follows is specific and cheap: **before upgrading, render your real charts with the new version's Helm and diff the output.** That is what "test compatibility before upgrading" actually means, as opposed to what it usually means.
- **Why it is useful:** It makes upgrade planning concrete, current, and slightly frightening — which is the correct emotional register for upgrading a deployment platform. It is also the strongest possible argument for the outline's "release notes, compatibility testing, and rollback criteria" bullet.
- **Best delivery moment:** The upgrade block, as its opening fact.
- **Supporting examples from the same 3.x line (state as evidence that this recurs, not as detail to memorise):** Argo CD **3.0** changed fine-grained RBAC so that `update`/`delete` on an Application **no longer implies** its sub-resources; **3.2** capped an ApplicationSet's `status.resources` at 5000 entries by default (configurable via `applicationsetcontroller.status.max.resources.count`) to avoid etcd bloat; **3.5** also made Helm 4's OCI handling stricter, requiring explicit `--plain-http` for non-TLS registries.
- **Visual / activity:** Discussion prompt: "Which of these three changes would your current setup have noticed, and how would you have found out?"
- **Accuracy caveat:** ⚠️ Exact Helm patch version unresolved (`4.2.0` vs `4.2.1` across sources) — see I-S4-02. Upgrade pages were read from `/latest/`. Present the *pattern* confidently and the *version numbers* provisionally.
- **Source / verification:** ⚠️ **Verified via search summaries only** (2026-09-10): `operator-manual/upgrading/3.4-3.5/`, `.../3.1-3.2/`, `.../2.14-3.0/`, and `argoproj/argo-cd` issues #29068/#29059. **Route to `technical-source-check`.**

#### I-S7-08 · Alert on failure to converge, not on `OutOfSync` `TRADE-OFF` `MODERN`
- **Insight:** The obvious alert — "application is `OutOfSync`" — is the wrong one. It fires constantly, most firings are benign (someone committed 40 seconds ago), and teams mute it within a week. The alert that carries information is compound: **an application has been `OutOfSync` *and* has automated sync enabled *and* has not converged for N minutes.** That condition means reconciliation itself is stuck, which is always worth waking someone for. On the metrics side, `argocd_app_reconcile` reports reconciliation duration and is designed to be read as a heat map — a distribution shifting right is an early warning that precedes any application-level symptom.
- **Why it is useful:** It teaches alert design rather than metric names, it directly serves the outline's "alerts and notifications" bullet, and it explains why most Argo CD alerting is ignored in practice.
- **Best delivery moment:** In the observability block, as the practical conclusion of the metrics material.
- **Visual / screenshot:** **SS-07-01** (notifications/metrics surface). Contrast a noisy single-condition alert with the compound one.
- **Accuracy caveat:** Only name metrics that are confirmed. `argocd_app_reconcile` is corroborated; treat other metric names as unverified until checked.
- **Source / verification:** ✅ Partially verified 2026-09-10 via search summary of `operator-manual/metrics/`: application metrics exposed on `argocd-metrics:8082/metrics`; `argocd_app_reconcile` "reports application reconciliation duration in seconds and can be used to build reconciliation duration heat maps." Controller queue facts also corroborated: two separate queues (reconciliation in milliseconds, syncing in seconds) with `--status-processors` (default 20) and `--operation-processors` (default 10). ⚠️ `argocd_app_info`, `argocd_app_sync_total`, and `argocd_cluster_api_resource_objects` were **not** individually confirmed — **do not print them without a check.**

#### I-S7-09 · The honest cost model for an internal fork `TRADE-OFF` `MODERN`
- **Insight:** Keep this at reference depth (blueprint §5.3) and make it one idea: **every patch you carry is a merge you owe forever, and a CVE clock you now own.** Forking moves you from consuming a security response to producing one — you must track upstream, rebuild images with provenance, re-run regression tests, and ship on your own cadence, for the life of the divergence. The discussion prompt is better than a lecture: *"What would have to be true for a fork to be cheaper than an upstream contribution?"*
- **Why it is useful:** It gives a genuinely senior framing in the least amount of time, and it is the first thing to compress if S7 overruns — which the blueprint pre-authorises, so it must be written to be compressible.
- **Best delivery moment:** The final block, explicitly marked as reference/discussion depth.
- **Accuracy caveat:** Do not present forking as wrong. Sometimes it is necessary. Present it as *priced*.
- **Source / verification:** Practice framing; no product claim.

#### I-S7-10 · Upgrade Argo CD and Kubernetes on different days `STICKY`
- **Insight:** Argo CD publishes a tested-Kubernetes matrix per release and supports roughly the last three Kubernetes minors; the `argocd` CLI should match the server's **minor** version. Practical rule: **change one variable at a time.** If you upgrade Argo CD and Kubernetes together and something renders differently, you have two suspects and no control group.
- **Why it is useful:** It is an unglamorous operational discipline that participants will actually apply, and it makes the version-matching bullet actionable rather than informational.
- **Best delivery moment:** Closing the upgrade block, as the rule that follows from I-S7-07.
- **Accuracy caveat:** ⚠️ The **exact tested-Kubernetes matrix for Argo CD 3.5 remains unconfirmed** — blueprint §12 already carries this as a ⚠️ qualified item owned by `environment-engineer`. Teach the *policy* (roughly the last three minors, published per release) and let the environment spec supply the confirmed numbers.
- **Source / verification:** ⚠️ Policy corroborated in blueprint §12; the per-release matrix page could not be fetched in this pass either. **Route to `technical-source-check` / `environment-engineer`.**

### Key takeaways — S7

> **"Walk the pipeline in the direction the data flows, and stop at the first step that lies to you."**
>
> **"Each troubleshooting step names one component. Find the step and you have found the pod."**
>
> **"You cannot diagnose a comparison until you trust both sides of it."**
>
> **"Sharding splits clusters, not Applications. If one cluster is your bottleneck, more replicas will not save you."**
>
> **"Every ignore rule is a promise that something else owns that field. An ignore rule with no owner is a blind spot."**
>
> **"If Argo CD is truly declarative, losing the management cluster is a rebuild, not a restore — and your export file is a receipt for everything you forgot to put in Git."**
>
> **"Upgrading Argo CD can change your manifests without anyone changing a chart."**
>
> **"Alert on failure to converge, not on `OutOfSync`. One is a symptom; the other is just Tuesday."**

---

## Capstone — Restore an Argo CD deployment platform
**File:** `courseware/day-2/capstone-restore-platform.md` · Capstone · **DIAGNOSTIC** · 90 min · Objectives 2, 4, 6, 7, 8

> **Weighting note: this is the most important file in the course.** It is deliberately *not* procedural (blueprint §5.3): identify the layer → evidence-based root cause → repair desired state → verify → explain the preventing guardrail. Default scenario runs **4–5 of the seven faults**, independently toggleable. Suggested internal budget: 10 briefing · 25 triage · 35 root cause and repair · 15 verification · 5 prevent-recurrence.

#### I-CAP-01 · You are not solving a puzzle — you are running an incident `STICKY`
- **Insight:** Frame the capstone as an incident, not an exercise, and enforce the framing structurally. The first move in a real incident is **not** to fix anything; it is to establish what is true. So the capstone's first phase is a **written triage pass in which no changes are permitted**, and thereafter **every change must be a commit** — which is the outline's own "identify the failure layer without making uncontrolled changes" requirement turned into a rule of play.
- **Why it is useful:** It changes participant behaviour immediately and measurably. Without the rule, most people start editing within three minutes. With it, they produce evidence — and the debrief has something to talk about.
- **Best delivery moment:** The briefing, as the first and clearest instruction.
- **Visual / screenshot:** **SS-CAP-01** (environment check of the broken platform, multi-symptom) as the "here is what you walked into" opening image.
- **Source / verification:** Pedagogical framing over the outline's own capstone requirements.

#### I-CAP-02 · Fix the faults that hide other faults first `COUNTER` `STICKY`
- **Insight:** **This is the capstone's central intellectual content.** With several connected faults, symptoms alias: a disconnected workload cluster makes *everything* on it report `Unknown`, which completely masks the rendering error underneath it, which in turn masks a workload that was already degraded. Chasing the loudest symptom means re-diagnosing the same fault three times. The heuristic that resolves it is an ordering by **what blocks observation**:
  1. **Connectivity** — can Argo CD see the cluster at all? (Nothing below this is trustworthy while this is broken.)
  2. **Rendering** — can it produce manifests? (Without this there is no desired state to compare.)
  3. **Permissions** — is it allowed to act? (A sync that cannot run tells you nothing about health.)
  4. **Ownership** — is something above you rewriting your fix?
  5. **Workload health** — is the application itself actually broken?
- **Why it is useful:** It is the most transferable thing in the entire course — it is real on-call reasoning, it generalises far past Argo CD, and it is exactly what separates a 20-minute recovery from a 90-minute one. It also maps cleanly onto S7's pipeline ordering, so it is a *derivation* rather than a new framework.
- **Best delivery moment:** Give it as a heuristic during the briefing, then let the debrief reveal why it works — most teams that ignored it will have re-diagnosed something.
- **Visual / activity:** A layered diagram with "what this layer hides when it is broken" written on each layer. Debrief question: **"Which fault did you diagnose twice, and what was hiding it?"**
- **Accuracy caveat:** It is a heuristic for triage order, not a strict dependency graph — say so, so participants do not apply it mechanically when evidence points elsewhere.
- **Source / verification:** Reasoning built on verified status semantics (`Unknown` when live state is unobservable, I-S2-03/I-L2-06) and the outline's own fault list.

#### I-CAP-03 · You get one diagnostic action `STICKY`
- **Insight:** Before anyone touches anything, each participant writes down **one** command or screen they would look at first, **and what they expect to learn from it**. The second half is the graded half. The best answers *partition* the fault space — they distinguish "is this Argo CD or is this Kubernetes?", or "is this one application or the whole platform?" The weakest answers confirm a hunch.
- **Why it is useful:** It makes an invisible expert skill — choosing the highest-information next step — explicit, comparable, and discussable. It is also the fastest possible debrief: read four different first moves aloud and the class can rank them itself.
- **Best delivery moment:** The gate between the briefing and the triage phase.
- **Visual / activity:** Collect the answers before anything is opened. A strong opening move is `argocd app get <app>` — it shows sync status, health, the revision actually rendered, and recent conditions on one screen, which partitions several faults at once. Do **not** print that as the answer in the participant guide; it belongs in the solution file.
- **Accuracy caveat:** Participant guide poses the question; the solution file holds the reasoning (CLAUDE.md instructor-solution separation).
- **Source / verification:** Pedagogical pattern named in `START-PROMPT.txt`; `argocd app get` output shape to be confirmed by `lab-tester`.

#### I-CAP-04 · The loudest signal is often the least important one `COUNTER` `STICKY`
- **Insight:** One of the outline's faults is deliberately "a degraded workload combined with **noisy or misleading drift**." That pairing is the most realistic thing in the scenario. The drift is loud, red, and hurting **nobody** — the previous version is serving fine. The degraded workload is quieter in the UI and is hurting **users right now**. Triage by **who is in pain**, not by what is red.
- **Why it is useful:** It is the Day 1 sync-versus-health distinction (I-S2-02, I-L1-05) returning under pressure with real consequences, which is precisely the retrieval structure the blueprint's through-line demands — and it is a lesson that transfers directly to every dashboard participants own.
- **Best delivery moment:** Naturally, during triage. Then made explicit in the debrief.
- **Visual / screenshot:** **SS-CAP-02** (evidence surfaces, diagnostic only). Debrief question: "Rank the faults by user impact. Now rank them by how loud they were. Compare the two lists."
- **Accuracy caveat:** The drift must be genuinely benign in the scenario for the lesson to be honest. `environment-engineer` must ensure the noisy-drift fault does not incidentally break anything.
- **Source / verification:** Scenario design over verified status semantics.

#### I-CAP-05 · If your fix reverted, you fixed the wrong layer `STICKY`
- **Insight:** The ownership fault (root or child Application) is where teams lose the most time, and its signature is unmistakable once you know it: **you make a change, it works, and then it comes back.** Recognising that pattern in under a minute — and immediately looking *up* the ownership chain rather than repeating the fix — is the capstone's sharpest skill test.
- **Why it is useful:** It is the same lesson as self-heal (Lab 3) and generated-Application ownership (Lab 4), now arriving unannounced and under time pressure. Three encounters across two days is what makes it permanent.
- **Best delivery moment:** Emerges on its own. Name it in the debrief as a recurring pattern rather than a one-off trick.
- **Visual / activity:** Debrief prompt: "Who here fixed the same thing twice? What was above it?"
- **Source / verification:** Ownership semantics verified at I-S5-07 and I-S5-05.

#### I-CAP-06 · When the application evidence looks fine but the application is wrong, look at the thing doing the looking `COUNTER`
- **Insight:** The "Argo CD component under resource pressure" fault is the only one where **application-level evidence stops being trustworthy**. Statuses look plausible but stale; refreshes take too long or do not complete; some apps update and others do not. This is step 5 of the method — inspect the responsible component and its metrics — and it is the only fault in the set that cannot be diagnosed from the Applications list at all.
- **Why it is useful:** It is the reason the method has six steps instead of four, and it teaches participants to distrust their instruments in the specific circumstance where instruments fail.
- **Best delivery moment:** Include this fault in the default 4–5 whenever the cohort is strong; it is what makes the capstone feel genuinely operational rather than application-level.
- **Visual / screenshot:** **SS-07-02** (a component surface under stress). Debrief: "What told you the problem was not in any application?"
- **Accuracy caveat:** The fault must produce *observable* component symptoms (restarts, latency, saturation) rather than an invisible slowdown, or it is unfair rather than difficult. `environment-engineer` owns making it detectable and reversible.
- **Source / verification:** Repo-server/controller pressure mechanisms verified at I-S7-03 and I-S7-04.

#### I-CAP-07 · The prevention step is the part that makes them a platform engineer `STICKY` `MODERN`
- **Insight:** The outline's final requirement — explain the guardrail or monitoring change that prevents recurrence — is not a formality. Require **one line per fault**, and provide the mapping as the debrief artifact:

  | Fault | Guardrail or signal that would have caught it first |
  |---|---|
  | Broken Helm values reference / rendering error | Render the chart in CI on every pull request — a rendering failure should fail a PR, not a sync |
  | ApplicationSet blast radius | Preview before apply (`argocd appset generate`) + `applicationsSync: create-update` + `missingkey=error` |
  | Root/child ownership problem | Explicit ownership boundaries and a documented finalizer decision per root |
  | AppProject or Kubernetes RBAC denial | Test the policy before shipping it (`argocd admin settings rbac can`); denial messages that name the rule |
  | Disconnected workload cluster | Alert on cluster connection state, not on the applications downstream of it |
  | Degraded workload + noisy drift | A field-scoped ignore rule **with a named owner**; alert on failure to converge rather than on `OutOfSync` |
  | Component under resource pressure | Resource and queue/latency alerting on the controller and repo-server, watched as a trend |

- **Why it is useful:** It converts the whole two days into a single reusable page, and it is the artifact most likely to be pinned in a team channel a month later. It also proves objective 8, which otherwise has the lightest hands-on evidence (blueprint §6).
- **Best delivery moment:** The final 5 minutes, as the closing synthesis.
- **Accuracy caveat:** The participant guide asks for the mapping; the **completed** table is solution-file content. Do not print the answers in the capstone guide (CLAUDE.md).
- **Source / verification:** Each row rests on a verified insight above; no new claims.

#### I-CAP-08 · End where you started `STICKY` `VISUAL`
- **Insight:** Close the course by re-asking Lab 1's question across every fault: **"Was this a Git problem, a rendering problem, a comparison problem, a sync problem, a health problem, or a component problem?"** Six buckets — the same six as the troubleshooting method, the same six as the pipeline, the same distinction they first met on Day 1 morning.
- **Why it is useful:** It makes the two days feel like one idea examined at increasing depth rather than fourteen topics, which is the single strongest driver of long-term retention. It also gives the course a genuine ending rather than a stop.
- **Best delivery moment:** The last activity before the final key takeaways.
- **Visual / activity:** The troubleshooting pipeline diagram one final time, with participants placing each capstone fault onto the station where it lived.
- **Source / verification:** Internal course structure.

#### I-CAP-09 · An opening narrative that sets the register `FAILURE`
- **Insight:** Open the briefing with a short, realistic incident narrative rather than a task list: a template change merged late on Friday, a weekend, a Monday morning of red badges and a queue of Slack messages from three application teams, and a platform engineer who has been told not to break anything else. Two or three sentences.
- **Why it is useful:** It sets the emotional register the capstone needs — pressure without panic — and it makes the no-uncontrolled-changes rule feel like professionalism rather than an artificial constraint.
- **Best delivery moment:** The first paragraph of the briefing.
- **Accuracy caveat:** Keep it generic and fictional. No real company, no real incident, no implication that it describes anyone's employer.
- **Source / verification:** Narrative framing; no claims.

### Key takeaways — Capstone

> **"In a multi-fault incident, fix the faults that hide other faults first: connectivity, then rendering, then permissions, then ownership, then health."**
>
> **"The loudest signal in Argo CD is usually `OutOfSync`, and it is usually the least important thing on the screen. Triage by who is hurting, not by what is red."**
>
> **"If your fix reverted, you fixed the wrong layer."**
>
> **"When the application evidence looks fine but the application is wrong, look at the thing doing the looking."**
>
> **"The first move in an incident is not a fix. It is finding out what is true."**
>
> **"An incident is not over when it is green. It is over when you can name the guardrail that would have caught it."**

---

## Coverage summary

| Session | Insights | Categories represented | Key takeaways |
|---|---|---|---|
| S1 | 6 | STICKY, COUNTER, MODERN | 5 |
| S2 | 7 | STICKY, VISUAL, COUNTER | 5 |
| **Lab 1** | **8** | STICKY, VISUAL, COUNTER | 5 |
| S3 | 7 | STICKY, COUNTER, TRADE-OFF, MODERN | 5 |
| **Lab 2** | **7** | STICKY, VISUAL, COUNTER, FAILURE, TRADE-OFF, MODERN | 5 |
| S4 | 8 | STICKY, VISUAL, COUNTER, TRADE-OFF, FAILURE, MODERN | 6 |
| **Lab 3** | **7** | STICKY, VISUAL, COUNTER, TRADE-OFF, FAILURE | 6 |
| S5 | 11 | STICKY, VISUAL, COUNTER, TRADE-OFF, FAILURE, MODERN | 6 |
| **Lab 4** | **8** | STICKY, VISUAL, COUNTER, FAILURE, TRADE-OFF | 5 |
| S6 | 7 | STICKY, VISUAL, COUNTER, TRADE-OFF, MODERN | 6 |
| **Lab 5** | **7** | STICKY, VISUAL, COUNTER, FAILURE, TRADE-OFF, MODERN | 5 |
| S7 | 10 | STICKY, VISUAL, COUNTER, TRADE-OFF, FAILURE, MODERN | 8 |
| **Capstone** | **9** | STICKY, VISUAL, COUNTER, FAILURE, MODERN | 6 |
| **Total** | **102** | all seven categories | **73** |

**Approximate distribution by category** (insights carry more than one tag, so these overlap): sticky explanations ≈ 44 · visual revelations ≈ 20 · counterintuitive results ≈ 33 · engineering trade-offs ≈ 21 · failure stories ≈ 14 · modern platform-engineering connections ≈ 14 · memorable one-liners / key takeaways **73**.

**Weighting check:** the six hands-on files (Labs 1–5 + Capstone) carry **46 of 102** insights and **32 of 73** takeaways, with the highest density of failure stories and diagnostic activities — matching the brief's instruction to weight effort toward the guides participants actually work through.

**Anchor-misconception coverage** (all six named in the brief are broken explicitly, most of them more than once):

| Misconception | Broken in |
|---|---|
| "`OutOfSync` means broken" | I-S2-02, **I-L1-05**, I-CAP-04 |
| "Argo CD runs `helm upgrade`" | **I-S4-01**, I-S4-02, I-L3-06 |
| "`Synced` means healthy" | **I-S2-02**, I-S2-03, I-L3-01 |
| Self-heal fighting a well-intentioned `kubectl edit` | I-S4-04, **I-L3-01/02**, I-CAP-05 |
| ApplicationSet blast radius | I-S5-03, I-S5-05, **I-L4-05**, I-CAP-07 |
| Cascading deletion from a root Application | **I-S5-07**, I-S5-08, I-L5-06 |

---

## Unverified and flagged claims — route to `technical-source-check`

Ordered by risk to the participant experience. **None of these should reach a participant guide unconfirmed.**

| # | Claim | Where it is used | Status | What to confirm |
|---|---|---|---|---|
| 1 | **Bundled Helm version in Argo CD 3.5** — sources disagree between `4.2.0` and `4.2.1`; the null-coalescing behaviour change | I-S4-02, I-S7-07 | ⚠️ Search-summary only; upgrade page read from `/latest/` | Exact Helm patch shipped in **`v3.5.2`**, and the precise coalescing wording, from `operator-manual/upgrading/3.4-3.5/` on the **release-3.5** path |
| 2 | **ApplicationSet Web UI + Preview tab** maturity — docs page exists on the release-3.5 path; an Argo Project blog post calls the UI read-only "in the alpha phase" | I-S5-06, I-L4-01 | ⚠️ Conflicting maturity signals | Official maturity label at `v3.5.2` and whether the UI is enabled by default; confirm layout live before any screenshot spec |
| 3 | **Owner badge** on generated Applications linking to the parent ApplicationSet | I-L4-06 | ⚠️ Blog only | Presence and behaviour at `v3.5.2`; capture live or drop the shortcut |
| 4 | **Progressive Syncs maturity = Beta** and `RollingSync` syntax; the blueprint's separate claim that **`RollingSync` forces auto-sync off** on generated Applications | I-S5-10 | ⚠️ Beta corroborated by search summary; the auto-sync-off claim **was not re-confirmed this pass** | The feature-maturity label on the **release-3.5** page, `RollingSync` syntax, and the auto-sync interaction |
| 5 | **`argocd admin settings rbac can` / `validate`** — reference pages observed on 2.x and `/latest/` paths | I-L5-03 | ⚠️ Partially verified | Existence, exact spelling, and syntax at `v3.5.2` |
| 6 | **Sync-using-impersonation** (`AppProject.spec.destinationServiceAccounts`) | I-S6-03 | ⚠️ `/latest/` only — may document unreleased behaviour | Availability and maturity at `v3.5.2`; if not GA, keep it a one-sentence mention |
| 7 | **ApplicationSet name-collision behaviour** — two generator entries rendering the same `metadata.name` produce one flapping Application rather than an error | I-L4-03 | ⚠️ **Unverified** — reasoned from the controller model | Confirm against docs **and** empirically via `lab-tester` before shipping the scenario; adjust the described symptom to observed reality |
| 8 | **Metric names** `argocd_app_info`, `argocd_app_sync_total`, `argocd_cluster_api_resource_objects` | I-S7-08 (deliberately not printed) | ⚠️ **Unverified** | Confirm before any metric name appears in a guide. `argocd_app_reconcile` **is** corroborated |
| 9 | **Argo CD 3.5 tested-Kubernetes matrix** includes the pinned **v1.34** | I-S7-10 | ⚠️ Still open — page unreachable in this pass **and** in the blueprint's pass | Already blueprint §12's ⚠️ item, owned by `environment-engineer`. Unchanged and still blocking |
| 10 | **Defaults quoted from the HA/scale docs**: `ARGOCD_SYNC_WAVE_DELAY` = 2s · `ARGOCD_EXEC_TIMEOUT` = 90s · repo cache 24h · `--status-processors` 20 · `--operation-processors` 10 · `timeout.reconciliation` 180s · progressing timeout 300s · default sharding algorithm `legacy` | I-S1-06, I-S4-06, I-S5-10, I-S7-03, I-S7-04, I-S7-08 | ⚠️ Search summaries of `/stable/` | Re-confirm each at 3.5, and reconcile against whatever the built environment actually ships |
| 11 | **Sync-option and AppProject field spellings** (`Prune=false`, `PruneLast`, `ApplyOutOfSyncOnly`, `ServerSideApply`, `Replace`, `RespectIgnoreDifferences`, `CreateNamespace`; `clusterResourceWhitelist`, `sourceNamespaces`, `destinationServiceAccounts`; `applicationsSync: create-delete`) | S4, S5, S6, Labs 3–5 | ⚠️ Corroborated but not read from the page | Blueprint §12 already assigns sync-option naming to `lab-engineer`; extend it to the AppProject fields listed here |
| 12 | **UI menu paths, badge text, and every screenshot** | all UI steps | ⚠️ Not verifiable from this sandbox at all | Capture live from the course's own `v3.5.2` instance (`screenshot-capture`); blueprint §9 governs |

**One structural recommendation for `course-architect`:** blueprint §9 has no screenshot ID for the **ApplicationSet Preview tab**, which I-S5-06 and I-L4-01 both rely on. If item 2 above confirms the feature, add an ID (suggested `SS-05-03`) to the S5 screenshot plan.

---

*End of insight map. Next deliverable in the pipeline: environment build (`environment-engineer`), then guide authoring (`lab-engineer`) in outline order. This document is build-planning input only and is never shipped to participants.*
