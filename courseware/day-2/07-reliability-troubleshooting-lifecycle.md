# Reliability, Troubleshooting, and Lifecycle Operations

> **Day 2 · Session 7 · Concept guide · ~75 minutes**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`; the repo-server renders charts with **Helm v4.2.1**). Kubernetes on the lab clusters is **k3s v1.35.8**.
> **What you need open:** nothing is required — this is a read-and-think session that prepares you for the capstone. There is one optional, **read-only** command-line exercise at the end (Section 9) that copies Argo CD's own configuration out to a file and changes nothing.
> **Timing, accounted honestly (for you and your instructor) — this session is the densest in the course.** The course allots **75 minutes**. The table below covers *every* section, reading time included, and the honest total at full depth is about **95 minutes**. That gap is real, and it is stated here rather than absorbed by silently rushing: six blocks are marked *self-read* or *compressible*, and taking all six lands the session at roughly **77 minutes**. If you reach Section 7 with fewer than 15 minutes left, take Section 7.4 as a single sentence — "a fork moves you from *consuming* upstream's work to *producing* it" — and read its checklist afterward. Nothing is removed from the file either way.
>
> | Block | Full depth | If time is short |
> |---|---:|---|
> | Section 1 — Why this matters | 3 min | |
> | Section 2 — The pipeline mental model and the six steps | 6 min | never cut |
> | Section 3 — Vocabulary (13 terms) | 4 min | **self-read** before the session |
> | Section 4 — V-25, the six-step pipeline with its evidence commands | 7 min | never cut |
> | Section 5 — The worked incident, all six steps | 15 min | never cut |
> | Sections 6.1–6.2 — HA behavior and controller sharding | 9 min | |
> | Section 6.3 — Repo-server pressure and monorepos | 4 min | |
> | Section 6.4 — Observability, metrics, and alert design | 6 min | |
> | Section 6.5 — Health checks and ignore rules | 5 min | |
> | Section 6.6 — Capacity-factor table | 2 min | **self-read** (it is a reference table) |
> | Sections 7.1–7.2 — Backup, and recovery from a lost management cluster | 8 min | |
> | Section 7.3 — Upgrades and version matching | 6 min | |
> | Section 7.4 — Operating an internal fork | 6 min | **compress** to a 3-minute discussion |
> | Section 8 — Quick Checks (four) | 8 min | **two live, two self-check** |
> | Section 10 — Common misconceptions (four) | 3 min | **self-read** |
> | Section 11 — Key takeaways and transition | 2 min | **self-read** |
> | **Total** | **95 min** | **≈77 min** |
>
> Section 9 (Try It Yourself) is optional and sits **outside** this budget.

**Where this sits in the course.** Every earlier session gave you one piece of the picture: Session 2 named the six components and gave each a verb; Session 3 covered installing and configuring the platform; Session 4 covered how Helm charts are rendered and synced; Sessions 5 and 6 scaled and fenced the deployment path. This session ties all of it into a single skill — **diagnosing a real incident under time pressure without making it worse** — and then covers the lifecycle jobs an operator owns: keeping Argo CD stable, backing it up, and upgrading it safely.

**One promise up front, because it is the spine of everything that follows:** there is a **fixed order** for gathering evidence during an Argo CD incident, and following that order is what separates a five-minute fix from a two-hour outage. You will learn the order, learn *why* it is that order, and walk one full incident through it. The capstone is nothing but this method applied to several faults at once.

---

## 1. Why this matters

It is **09:05** on a Monday. You open the Argo CD web interface (UI, user interface) and every single Application has flipped to **`Unknown`**. Not `OutOfSync`. Not `Degraded`. `Unknown` — the status Argo CD shows when it cannot even *complete a comparison*. Your phone is buzzing. Someone in chat has already typed the sentence that starts most outages getting worse: *"Should I just restart everything?"*

Stop. That question is the trap. Restarting components before you have any evidence does two harmful things at once: it can **erase the very evidence** you need (logs roll, in-flight operations reset), and it can **make a healthy component look like the culprit** because it happened to be the thing you touched right before the symptom changed. An incident is not the moment to start guessing and poking. It is the moment to *walk a known path and read what each step tells you.*

So here is the discipline this whole session installs, stated as two rules you will use for the rest of your career:

- **Evidence before change.** You gather proof of where the failure is *before* you change anything. The first destructive action you take should be the fix, not a diagnostic guess.
- **Source before platform.** You check the declarative source (Git, rendering) *before* you suspect Argo CD's own components — because most incidents are a bad source or an unreachable source, not a broken controller, and because you cannot trust a comparison until you trust both sides of it.

By the end of this session you will be able to:

- walk the **six-step troubleshooting method** in order, and name the **exact evidence command** for each step;
- point at any one of the six steps and say **which Argo CD component** it examines;
- predict what breaks when a specific component fails, and what an upgrade or a lost cluster actually costs;
- explain what to back up (and what is a waste of time to back up), and how to recover when the whole management cluster is gone;
- and recognize the four expensive misconceptions that turn a small incident into a large one.

At **09:05**, the right first move is not a restart. It is step 1. Let us build the method.

---

## 2. Plain-language mental model: walk the pipeline in the direction the data flows

In Session 2 you gave each Argo CD component exactly one verb. That model pays off completely right now. An Argo CD deployment is a **pipeline**: data flows from Git, through rendering, through comparison, into the cluster, and status flows back. When something breaks, you do not poke at random — you **walk the pipeline in the same direction the data travels, and stop at the first step that lies to you.**

The outline's six-step method *is* that walk. Here are the six steps, in the exact wording you should memorize:

1. **Validate the Git source and revision.**
2. **Validate repository access and manifest rendering.**
3. **Compare rendered state with live cluster state.**
4. **Inspect synchronization results, hooks, events, and Kubernetes health.**
5. **Inspect the responsible Argo CD component and its metrics.**
6. **Correct the declarative source and verify reconciliation.**

The order is not arbitrary, and understanding *why* it is this order is what lets you rederive it when you have forgotten the list. **You cannot diagnose a comparison until you trust both sides of it.** Step 3 compares desired against live — but that comparison is meaningless if you have not first confirmed the desired side is the revision you think it is (step 1) and that it rendered at all (step 2). So the source and the rendering come first, always, before the diff means anything.

Now overlay the six steps onto the one-verb-per-component model, because **each step names exactly one component — and finding the step finds the pod whose logs to open:**

| Step | What you validate | Component (and its verb) | Where it lives |
|---|---|---|---|
| 1 | The Git source and revision | **Git** — *stores* | Outside both clusters (the Gitea server) |
| 2 | Repository access and manifest rendering | **repo-server** — *renders* | `argocd` namespace |
| 3 | Rendered state vs live cluster state | **application-controller** — *compares* | `argocd` namespace |
| 4 | Sync results, hooks, events, health | **application-controller** — *applies* + the target cluster's API server | `argocd` namespace + workload cluster |
| 5 | The responsible component and its metrics | whichever component steps 1–4 implicated | `argocd` namespace |
| 6 | Correct the source and verify | **Git**, then the loop runs again | Outside, then back through 1–6 |

This is the single highest-value idea in the session: the method is not just a diagnostic procedure, it is a **localization** procedure. Identify which step lies to you, and you have identified which component to investigate. "Manifests are stale even after a refresh" → the lie is at step 2 → open the **repo-server**. "The sync started and then failed with `forbidden`" → the lie is at step 4 → look at the **target cluster's** permissions, not at Argo CD.

Hold that table in your head. The rest of this session hangs off it.

---

## 3. Vocabulary, grounded before we use it

Each term gets a plain-language definition first, then its role. These thirteen are the words this session introduces; the capstone uses them freely. Four more — **OOMKilled**, **SLA**, **JSON**, and **provenance** — are defined in one line at the moment they first matter (Sections 5, 6.4, 6.5, and 7.4 respectively), because none of them needs a full entry to be usable.

- **HA (high availability), and replica.** A **replica** is one running copy of a component — one pod, or for the application-controller one `StatefulSet` member; "two replicas of the repo-server" means two pods sharing the rendering work. **HA** is a way of running software so that losing one copy does not take the service down: in practice, more than one replica of each component and, for stateful pieces, a topology that survives a node failure. Argo CD ships an HA install mode; this course runs the smaller **non-HA** install (one replica of each component), which is ideal for learning failure behavior because you can watch a single pod's outage directly.

- **sharding.** Splitting a workload across several replicas so each replica handles only part of it. For Argo CD's application-controller, **the unit that gets split is the *cluster*, not the Application** — each replica (shard) owns a set of whole clusters. This one fact explains a lot of scaling surprises (Section 6.2).

- **reconciliation queue.** The application-controller's internal to-do list of Applications waiting to be re-examined. Argo CD keeps two such queues — one for *reconciliation* (recomputing status, measured in milliseconds) and one for *syncing* (applying changes, measured in seconds). Workers pull from these queues; the number of workers is set by `--status-processors` (default 20) and `--operation-processors` (default 10). When the queue grows faster than the workers drain it, everything gets slower — a classic scale symptom.

- **custom health check (Lua).** Argo CD decides whether a resource is `Healthy`, `Progressing`, `Degraded`, or `Missing` using built-in rules — but for custom resource types it does not recognize, you can teach it a rule written in **Lua** (a small scripting language embedded in Argo CD). A custom health check is a short Lua script, configured in the `argocd-cm` ConfigMap, that reads a resource's fields and returns a health verdict. It is how you make a `Healthy` badge *mean* something for a CRD Argo CD has never seen.

- **CRD (Custom Resource Definition).** A way of teaching Kubernetes a brand-new kind of object beyond the built-in ones. Argo CD's own `Application`, `AppProject`, and `ApplicationSet` are CRDs.

- **`ignoreDifferences`.** A configuration that tells Argo CD to **stop treating a specific field as drift.** Without it, any field the cluster changes after you deploy — a replica count a horizontal autoscaler edits, a value an admission webhook injects — would make the Application permanently `OutOfSync` for a reason no human can fix. `ignoreDifferences` silences that noise. Used carelessly, the same mechanism can silence a *real* change forever (Section 6.5).

- **`argocd admin export` / `argocd admin import`.** A pair of Argo CD commands. **Export** reads Argo CD's own Kubernetes objects (its Applications, projects, config, and secrets) out of a cluster and writes them to one **YAML (YAML Ain't Markup Language** — the text format Kubernetes manifests are written in) file. **Import** reads that file back into a cluster. Together they are the backup-and-restore path for the parts of Argo CD's state that live only in the cluster.

- **etcd.** The database Kubernetes itself uses to store every object. When we say "Argo CD's real state is Kubernetes objects," we mean those objects live in the management cluster's etcd — which is exactly why losing that cluster is the scenario worth planning for.

- **compatibility matrix.** A published table stating which versions of two things are tested to work together. Argo CD publishes a **tested-Kubernetes** matrix per release (roughly the last three or four Kubernetes minor versions). Checking it before an upgrade is how you avoid pairing an Argo CD version with a Kubernetes version nobody tested.

- **RKE2 (Rancher Kubernetes Engine 2).** A production Kubernetes distribution from Rancher, common in the environments this course prepares you for. The lab uses the lighter **k3s** instead, but the version-matching discipline (Section 7.3) is identical: match Argo CD to a Kubernetes version its release actually tested against.

- **CVE (Common Vulnerabilities and Exposures).** A publicly catalogued security flaw, each with an identifier like `CVE-2024-12345`. When a CVE is found in Argo CD, the upstream project publishes a patched release. Whether *you* consume that patch or have to *produce* it yourself is the whole cost story of running a fork (Section 7.4).

- **internal fork.** A private copy of Argo CD's source code that your organization has modified and builds itself, instead of running the official released images. A fork can be necessary — but it changes who is responsible for security patches, image provenance, and testing, permanently (Section 7.4).

- **API (application programming interface) / CLI (command-line interface) / UI (user interface).** The three ways you talk to Argo CD: the API server it exposes, the `argocd` command, and the web page. All three read the *same* underlying state, so an incident looks the same through each — a fact that matters when one of them is the thing that is down.

---

## 4. Visual — V-25: the six-step method as a pipeline, with the evidence command for each step

An incident is an invisible process: data is flowing (or failing to flow) through components you cannot see. This diagram makes the flow visible. Read it as a **pipeline with six stations**, left to right — not as a decision tree with branches. You walk it in order and stop at the first station that lies to you. Under each station is the **exact command that produces the evidence** for that step. This is the single most important picture in the course; it reappears, unchanged, in the capstone.

**Predict first:** before you read the debrief, answer this — if every Application shows `Unknown` but you can still log in and the UI is responsive, which station do you expect to be the first one that lies, and which command would prove it?

```text
  DATA FLOWS THIS WAY  ─────────────────────────────────────────────────────────►
                                                                  (status flows back)

  ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐
  │  STEP 1   │   │  STEP 2   │   │  STEP 3   │   │  STEP 4   │   │  STEP 5   │   │  STEP 6   │
  │ Validate  │──►│ Validate  │──►│ Compare   │──►│ Inspect   │──►│ Inspect   │──►│ Correct   │
  │ the Git   │   │ repo      │   │ rendered  │   │ sync      │   │ the       │   │ the       │
  │ source &  │   │ access &  │   │ vs live   │   │ results,  │   │ responsible│  │ declarative│
  │ revision  │   │ manifest  │   │ cluster   │   │ hooks,    │   │ component │   │ source &  │
  │           │   │ rendering │   │ state     │   │ events,   │   │ & its     │   │ verify    │
  │           │   │           │   │           │   │ K8s health│   │ metrics   │   │ reconcile │
  ├───────────┤   ├───────────┤   ├───────────┤   ├───────────┤   ├───────────┤   ├───────────┤
  │ Git       │   │ repo-     │   │ app-      │   │ app-ctrl  │   │ whichever │   │ Git, then │
  │ (stores)  │   │ server    │   │ controller│   │ + target  │   │ step 1–4  │   │ the loop  │
  │           │   │ (renders) │   │ (compares)│   │ cluster   │   │ implicated│   │ runs again│
  ├───────────┤   ├───────────┤   ├───────────┤   ├───────────┤   ├───────────┤   ├───────────┤
  │ EVIDENCE: │   │ EVIDENCE: │   │ EVIDENCE: │   │ EVIDENCE: │   │ EVIDENCE: │   │ EVIDENCE: │
  │ argocd    │   │ argocd    │   │ argocd    │   │ argocd    │   │ kubectl   │   │ git commit│
  │ app get   │   │ repo list │   │ app diff  │   │ app get   │   │ -n argocd │   │ + push,   │
  │ <app>     │   │           │   │ <app>     │   │ <app>     │   │ logs      │   │ then      │
  │  +        │   │  +        │   │           │   │  +        │   │ deploy/<c>│   │ argocd    │
  │ git ls-   │   │ argocd    │   │ (exit 1 = │   │ kubectl   │   │  +        │   │ app get   │
  │ remote    │   │ app       │   │  drift,   │   │ -n <ns>   │   │ kubectl   │   │ <app>     │
  │ <repo>    │   │ manifests │   │  2 =      │   │ get events│   │ top pod   │   │  +        │
  │ <ref>     │   │ <app>     │   │  error)   │   │           │   │ -n argocd │   │ argocd    │
  │           │   │ --source  │   │           │   │           │   │           │   │ app       │
  │           │   │ git       │   │           │   │           │   │           │   │ history   │
  └───────────┘   └───────────┘   └───────────┘   └───────────┘   └───────────┘   └───────────┘
     TRUST           TRUST          NOW the         READ the        OPEN the        FIX in Git,
     the source      the render     diff means      applied         implicated      never by hand
     first           next          something        result          pod's logs      on the cluster
```

**The debrief.** Notice three things about the shape:

1. **Steps 1 and 2 establish trust in the *desired* side before any comparison.** Step 1 confirms Argo CD is looking at the Git revision you think it is; step 2 confirms that revision can be reached and rendered into YAML at all. Only then does step 3's diff carry meaning.
2. **Step 3 is the hinge.** `argocd app diff` compares rendered desired state against live cluster state and returns a telling exit code: **0** means no difference, **1** means a real difference was found, **2** means it could not complete the comparison (an error). That exit code alone routes you: a `2` sends you *back* to steps 1–2 (the desired side is broken); a `1` sends you *forward* to step 4 (the diff is real; why did applying it not happen?). One honest caveat you will see for yourself in Section 5: a `1` does **not** always mean the difference is trustworthy. If the desired side rendered to *nothing*, the diff completes and exits **1** while showing every resource as though it were being deleted. That is exactly why steps 1 and 2 come first.
3. **You do not touch a component until step 5.** Steps 1–4 are pure evidence — reading, never changing. Step 5 is the first place you open a component's logs or measure its resource use, and you only get there once steps 1–4 have *told you which component*. Step 6 is where the first change happens, and it happens **in Git**, then flows back through the whole pipeline so you can verify the fix converged.

**Prediction answer:** with every app `Unknown` but logins working, the first station to lie is most likely **step 2 or step 3** — a shared rendering or comparison failure that hits every Application at once, while the responsive UI *clears* the API server (its verb, *talks*, is working fine). "Every app at once" always points at a **shared** dependency, never at one app's Git source. The command that proves it is `argocd app get <app>`, whose `CONDITION` block names a `ComparisonError` and prints the underlying network or rendering error in plain text; you confirm it at the repository level with `argocd repo list --refresh hard`, which re-tests the connection instead of reporting a cached one. That is precisely the incident we walk next.

---

## 5. Worked walkthrough — one incident, all six steps

Let us take a single, complete incident and walk it end to end, running the exact evidence command at each station. This incident's root cause is **the Git repository became unreachable** — a cause chosen deliberately because it is *not* one of the capstone's faults, so working through it here spoils nothing you will face later.

**The symptom.** At 09:05, `storefront-dev-workload` (and, it turns out, every app that sources from that same Git server) shows a red status. Someone wants to restart the repo-server. You do not. You walk the pipeline.

### Step 1 — Validate the Git source and revision

You start where the data starts. What repository, path, and revision is this Application *supposed* to be tracking, and does that revision even exist?

```bash
argocd app get storefront-dev-workload
```

Here is the real output from this course's own cluster during the incident. The fields that matter are the **source block**, the **status lines**, and the **`CONDITION` block** at the bottom:

```text
Name:               argocd/storefront-dev-workload
Project:            storefront
Server:             https://k3d-workload-server-0:6443
Namespace:          storefront-dev
URL:                https://localhost:8443/applications/storefront-dev-workload
Source:
- Repo:             http://lab-gitea:3000/course/storefront-gitops.git
  Target:           main
  Path:             charts/storefront
  Helm Values:      ../../envs/dev/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Unknown
Health Status:      Healthy

CONDITION        MESSAGE                                                        LAST TRANSITION
ComparisonError  Failed to load target state: failed to generate manifest for   2026-09-12 13:14:25 -0400 EDT
                 source 1 of 1: rpc error: code = Unknown desc = failed to
                 list refs: Get "http://lab-gitea:3000/course/storefront-
                 gitops.git/info/refs?service=git-upload-pack": dial tcp
                 172.20.0.2:3000: connect: no route to host

GROUP  KIND        NAMESPACE       NAME                  STATUS     HEALTH   HOOK     MESSAGE
batch  Job         storefront-dev  storefront-migration  Succeeded  Synced   PreSync  Reached expected number of succeeded pods
       ConfigMap   storefront-dev  storefront            Unknown                      configmap/storefront unchanged
       Service     storefront-dev  storefront            Unknown    Healthy           service/storefront unchanged
apps   Deployment  storefront-dev  storefront            Unknown    Healthy           deployment.apps/storefront unchanged
```

*(The `CONDITION` message is one very long single line in a real terminal; it is wrapped across five lines above so it fits this page.)*

Three things to read off this, in order:

- **The declared source looks correct.** The repository URL, the `main` branch, the `charts/storefront` chart path, and the `../../envs/dev/values.yaml` values file are exactly what you expect. Nobody edited the Application.
- **`Sync Status: Unknown`, but `Health Status: Healthy`.** Argo CD is telling you it cannot *evaluate* the app — and, separately, that the workload it last deployed is still running fine. Those are two different questions, and only one of them is broken.
- **The `CONDITION` block already names the cause.** Argo CD is not hiding anything: it could not list refs on the Git repository because the connection was refused. You have a very strong hypothesis after one command.

Now confirm the repository is unreachable from outside Argo CD too, using plain Git against the same URL:

```bash
git ls-remote http://lab-gitea:3000/course/storefront-gitops.git main
```

If Git is healthy you see a commit hash next to `refs/heads/main`, like this:

```text
cbeba814dc4f10b45548c6f0806308a11796747f	refs/heads/main
```

During the incident you get this instead (and `git` exits with code `128`):

```text
fatal: unable to access 'http://lab-gitea:3000/course/storefront-gitops.git/': Failed to connect to lab-gitea port 3000 after 3112 ms: Could not connect to server
```

That is your first lie — but be disciplined and note *what it tells you and what it does not*. The name `lab-gitea` still resolved (there is no "could not resolve host" here), so this is not a DNS failure; the **server behind the name is not answering**. And it tells you that only **from where you are standing** — it does not by itself prove Argo CD's repo-server sees the same thing. So you continue to step 2 to confirm the failure is where you think it is.

### Step 2 — Validate repository access and manifest rendering

Ask Argo CD's own view of the repository connection. There is a trap in this command that is worth meeting now rather than during an incident: a bare `argocd repo list` reports a **cached** connection status, so during a live outage it can still print `Successful`. Add `--refresh hard` to force Argo CD to actually re-test the connection:

```bash
argocd repo list --refresh hard
```

```text
TYPE  NAME  REPO                                                INSECURE  OCI    LFS    CREDS  STATUS  MESSAGE
git         http://lab-gitea:3000/course/storefront-gitops.git  false     false  false  false  Failed  Unable to connect to repository: rpc error: code = Unknown desc = error testing repository connectivity: unable to ls-remote HEAD on repository: failed to list refs: Get "http://lab-gitea:3000/course/storefront-gitops.git/info/refs?service=git-upload-pack": dial tcp 172.20.0.2:3000: connect: no route to host
```

*(There is also a `PROJECT` column after `MESSAGE`; it is empty here and the very long message pushes it off the page.)*

`STATUS: Failed` on the repository is the confirmation, and the message is the same connection failure the Application's condition reported. Now see how the failure surfaces at **render** time, by asking for the manifests Argo CD would generate from Git:

```bash
argocd app manifests storefront-dev-workload --source git
```

```text
---
null

---
null

---
null

```

Read that carefully, because it is the most easily missed evidence in this whole walkthrough. The command **did not fail** — it exits `0` and prints three empty YAML documents, one per managed resource. Argo CD could not render anything, so "everything" is `null`. **A quiet, empty answer is still a lie at station 2**, and it is the direct cause of the strange thing you are about to see at station 3.

The **repo-server** cannot render because it cannot reach the source. The picture below is what this looks like in the UI — a `ComparisonError` condition on the Application, which is Argo CD saying "I could not complete step 2/3."

![Argo CD v3.5.2 Application conditions panel for storefront-dev-workload, showing a single ComparisonError whose message reports that generating the manifest failed because listing refs on the Git repository returned a connection error.](../assets/screenshots/day-2/s07-01-repo-unreachable.png)

*Argo CD v3.5.2 — the **Application conditions** panel for `storefront-dev-workload`, logged in as admin, after the Git server was made unreachable and the app was hard-refreshed. You open this panel by clicking the red **APP CONDITIONS — 1 Error** item in the Application's status bar. Behind the panel, that same status bar reads **APP HEALTH: Healthy** and **LAST SYNC: Sync OK** — the failure surfaces as a `ComparisonError`, not as a `Degraded` workload.*

<!-- CAPTURE-SPEC: SS-S7-01 — Application ComparisonError from an unreachable repo.
Source: CAPTURED LIVE from this course's Argo CD v3.5.2 at https://localhost:8443 (lab-tester, 2026-09-12), harness state CP-capstone, logged in as admin.
Steps: (1) log in as admin; (2) make Git unreachable with `docker stop lab-gitea`; (3) `argocd app get storefront-dev-workload --hard-refresh` so the condition re-evaluates; (4) open /applications/storefront-dev-workload and click the APP CONDITIONS item; (5) restart Git afterward with `docker start lab-gitea` to leave the environment healthy.
Capture: full viewport 1440x900, light theme, PNG. Highlight the conditions row (.application-conditions__condition) showing the ComparisonError and its connection-failure message.
Note: the real message is a TCP connection failure ("no route to host"), not a DNS "could not resolve host" error, because the recipe stops the Git server rather than removing its DNS record.
Save to: courseware/assets/screenshots/day-2/s07-01-repo-unreachable.png -->

**What to notice:**

1. **The status is `Unknown`/`ComparisonError`, not `Degraded` — and the health badge still says `Healthy`.** A `ComparisonError` means Argo CD could not *evaluate* the app: a step 1–3 failure (source/render/compare), a completely different place from a workload that is running but sick. The deployed Pods are untouched, so the health badge is telling the truth. Reading that distinction is most of triage.
2. **The condition message names the cause in plain text.** It says, in one sentence, that generating the manifest failed because it could not list refs on that repository over TCP. Argo CD is not hiding the reason; the method is largely about *going to the place that prints the reason.*
3. **This is a shared-dependency failure.** Every Application that sources from this Git server shows the same condition at the same time — which is the signature of a source/render problem, never a single app's bug.

### Step 3 — Compare rendered state with live cluster state

This is the hinge step, and this incident produces the single most important surprise in the whole walkthrough. Run it:

```bash
argocd app diff storefront-dev-workload
echo "exit code: $?"
```

```text

===== /ConfigMap storefront-dev/storefront ======
1,39d0
< apiVersion: v1
< data:
<   PODINFO_UI_COLOR: '#2da44e'
<   PODINFO_UI_MESSAGE: storefront DEV
< kind: ConfigMap
< metadata:
<   annotations:

===== /Service storefront-dev/storefront ======
1,62d0
< apiVersion: v1
< kind: Service

===== apps/Deployment storefront-dev/storefront ======
1,203d0
< apiVersion: apps/v1
< kind: Deployment
exit code: 1
```

*(The full output is 313 lines; the first few lines of each of the three sections are shown.)*

**Stop and read what that actually says.** Every single line is prefixed with `<` — there is not one `>` line in all 313 — and the three diff headers read `1,39d0`, `1,62d0`, and `1,203d0`, which in diff notation means "lines 1 through N of the live object, **deleted**, leaving nothing." Taken at face value, this diff says: *Git wants the ConfigMap, the Service, and the Deployment all gone.*

It does not. The desired side is empty — exactly the three `null` documents you saw at station 2 — so the diff is comparing a real live cluster against **nothing**, and an empty desired state looks identical to a deliberate deletion. The exit code is **1** ("a real difference was found"), not **2** ("could not complete the comparison"), because from the differ's point of view the comparison completed perfectly well. (The documented exit codes are unchanged and worth memorizing: `argocd app diff --help` states *"2 on general errors, 1 when a diff is found, and 0 when no diff is found"*.)

This is the whole reason **source before platform** is a rule and not a preference. An operator who skipped straight to step 3 would be looking at a diff that appears to demand deleting the entire application — and this Application has **automated sync with prune enabled**. Acting on this diff, or "just syncing to make it green," is how a source-reachability incident becomes a deleted production workload.

Because you did steps 1 and 2 first, you already know the desired side is missing, so you read this diff correctly: **there is nothing to compare, and the problem is upstream.** You have localized the failure to steps 1–2 without changing anything.

### Step 4 — Inspect synchronization results, hooks, events, and Kubernetes health

You still glance at step 4, briefly, to rule out a coincidental second problem and to confirm the live workload is *not* itself broken.

One detail matters enormously here and is easy to get wrong under pressure: **the workload's Pods and events live on the *workload* cluster, not on the management cluster where Argo CD runs.** Your `kubectl` context defaults to the management cluster (`k3d-mgmt`), so you must name the other cluster explicitly with `--context k3d-workload`. Run it without that flag and you get `No resources found in storefront-dev namespace.` — which would wrongly convince you the whole application had vanished.

```bash
argocd app get storefront-dev-workload
kubectl --context k3d-workload -n storefront-dev get pods
kubectl --context k3d-workload -n storefront-dev get events --sort-by=.lastTimestamp | tail -6
```

```text
NAME                          READY   STATUS      RESTARTS   AGE
storefront-75cddb6b87-wbjbg   1/1     Running     0          24h
storefront-migration-p84wv    0/1     Completed   0          5m6s
```

```text
19m         Normal   Completed          job/storefront-migration         Job completed
5m6s        Normal   Pulled             pod/storefront-migration-p84wv   Container image "busybox:1.37.0" already present on machine and can be accessed by the pod
5m6s        Normal   Created            pod/storefront-migration-p84wv   Container created
5m6s        Normal   Started            pod/storefront-migration-p84wv   Container started
5m6s        Normal   SuccessfulCreate   job/storefront-migration         Created pod: storefront-migration-p84wv
5m1s        Normal   Completed          job/storefront-migration         Job completed
```

*(The `tail -6` drops `kubectl`'s header row. The columns are, left to right: `LAST SEEN`, `TYPE`, `REASON`, `OBJECT`, `MESSAGE`.)*

Read the `TYPE` column: every event is `Normal`. The application Pod has been `Running` for a day with zero restarts, and the only recent activity is a PreSync migration Job that completed successfully. No crash loops, no failed hooks, nothing `Warning`. That matters: **the workload is fine; only Argo CD's ability to evaluate it is broken.** If you had panicked and "rolled back" or "restarted the app" — or synced that deletion-shaped diff from step 3 — you would have damaged a perfectly healthy running service to fix a *source-reachability* problem. Step 4 is what stops that mistake.

> **A different-looking symptom, a different cause.** Not every red badge is a `ComparisonError`. The screenshot below shows an operation stuck in a **retrying** state — the app rendered and compared fine, a sync *started*, and something in the apply or a hook keeps failing so Argo CD keeps retrying. That is a step 4 story (sync results and hooks), not a step 2 story (rendering). Learning to tell "never started" from "started and retrying" apart is exactly the skill step 4 builds.

![Argo CD v3.5.2 operation-state panel showing a Sync operation whose phase is Running and whose message reads that one or more synchronization tasks completed unsuccessfully and it is retrying attempt number two, with a RESULT table below listing a failed PreSync hook Job.](../assets/screenshots/day-2/s07-02-sync-retrying.png)

*Argo CD v3.5.2 — the operation-state panel of a throwaway Application configured with a retry policy and a deliberately failing PreSync hook. `PHASE` is **Running** and the highlighted `MESSAGE` row reads "one or more synchronization tasks completed unsuccessfully. Retrying attempt #2 at 5:25PM." The `RESULT` table below shows the culprit: the `PreSync` hook Job `s07-failing-presync` is `Failed` with "Job has reached the specified backoff limit." The sync **started** and is **retrying**, which is a fundamentally different situation from a `ComparisonError`.*

<!-- CAPTURE-SPEC: SS-S7-02 — Operation "retrying" state.
Source: CAPTURED LIVE from this course's Argo CD v3.5.2 at https://localhost:8443 (lab-tester, 2026-09-12), logged in as admin.
Harness: a THROWAWAY Application `scratch-retry` (project default, destination in-cluster namespace s07-scratch, CreateNamespace=true) sourcing a temporary Gitea repo that holds one ConfigMap and one PreSync hook Job which exits 1 with backoffLimit 0.
Steps: (1) log in as admin; (2) apply the throwaway Application; (3) `argocd app sync scratch-retry --async --retry-limit 5 --retry-backoff-duration 45s`; (4) open /applications/scratch-retry?operation=true during a backoff window; (5) afterwards terminate the operation, delete the Application and the namespace, and delete the temporary repo so nothing course-owned is touched.
Capture: full viewport 1440x900, light theme, PNG. Highlight the operation summary's MESSAGE row (the single `.sliding-panel__body .white-box__details-row:has(pre)`).
Note: v3.5.2 has no `.application-operation-state` element; the panel opens from the `?operation=true` query parameter.
Save to: courseware/assets/screenshots/day-2/s07-02-sync-retrying.png -->

**What to notice:**

1. **The operation exists.** There is a sync *operation* with `OPERATION: Sync`, `PHASE: Running`, a start time, and a duration — which by itself proves rendering and comparison already succeeded. Contrast that with SS-S7-01, where there was no operation at all because the app never got past the comparison.
2. **"Retrying" is not "failed forever."** The phase is `Running`, not `Failed`: Argo CD is honoring a retry policy and will try again at the stated time. The evidence to read next is *why each attempt fails*, and the `RESULT` table answers it directly — the `PreSync` hook Job failed. Read that, not the retry count.
3. **This lives in a different panel than the condition in SS-S7-01.** Sync/operation results and comparison errors are two different surfaces because they come from two different steps of the method. Knowing which panel to open is knowing which step you are on.

### Step 5 — Inspect the responsible component and its metrics

Steps 1–4 have already named the suspect: the **repo-server**, because rendering is where the failure surfaced. *Now* — and only now — you open a component's logs and check its resource use:

```bash
kubectl --context k3d-mgmt -n argocd logs deploy/argocd-repo-server --tail=20
kubectl --context k3d-mgmt top pod -n argocd
```

The `logs` command first prints a harmless one-line notice — `Defaulted container "repo-server" out of: repo-server, copyutil (init)` — because that Pod has an init container as well. Then the logs echo the exact same connection failure you have now seen three times. Each log line is a long single line of structured fields; here is one real line from the tail, wrapped, with the trailing gRPC bookkeeping fields cut at `[...]`:

```text
time="2026-09-12T17:16:44Z" level=error msg="finished call" grpc.code=Unknown
grpc.component=server grpc.error="failed to list refs: Get \"http://lab-gitea:3000/
course/storefront-gitops.git/info/refs?service=git-upload-pack\": dial tcp
172.20.0.2:3000: connect: no route to host" grpc.method=GenerateManifest [...]
```

Now the resource picture. Real `kubectl top` output from this course's own cluster (your exact numbers will differ — they move with lab state and how recently the pods restarted):

```text
NAME                                                CPU(cores)   MEMORY(bytes)
argocd-application-controller-0                     8m           247Mi
argocd-applicationset-controller-5fb8c665fd-v97s8   2m           82Mi
argocd-notifications-controller-7797558c68-bx7j9    1m           33Mi
argocd-redis-56d6bd8bb7-5bj6r                       4m           12Mi
argocd-repo-server-dcb4fdc54-cscjj                  1m           46Mi
argocd-server-779878f878-plvdg                      5m           67Mi
```

This is an important negative result: the repo-server is **healthy and idle** at 1 millicore of CPU and 46 MiB of memory — not **OOMKilled** (Out Of Memory Killed — what Kubernetes does to a pod that tries to use more memory than its limit allows: it terminates the process, and you see the word `OOMKilled` in `kubectl describe pod`), not throttled, and with no restarts. That rules out "the repo-server is broken" and confirms "the repo-server is fine but cannot *reach* Git." Restarting the repo-server — the very first thing someone wanted to do at 09:05 — would have changed **nothing**, because the pod was never the problem. The evidence saved you a pointless restart and pointed at the real fix.

### Step 6 — Correct the declarative source and verify reconciliation

The fix is not in Argo CD at all; it is restoring reachability to the Git source (fixing DNS, network policy, or the Gitea server itself — whatever step 5's evidence pointed to). Because this is a *reachability* problem rather than a *content* problem, the "declarative source" you correct here is the platform's networking, but the verification path is identical to any Git fix: once the source is reachable again, let the pipeline run and **verify convergence with the same commands you used as evidence:**

```bash
argocd app get storefront-dev-workload
argocd app history storefront-dev-workload
```

Once the Git server was reachable again, the same two commands returned this (the two status lines from `argocd app get`, then the last line of `argocd app history`):

```text
Sync Status:        Synced to main (cbeba81)
Health Status:      Healthy
```

```text
SOURCE  http://lab-gitea:3000/course/storefront-gitops.git
ID      DATE                           REVISION
...
10      2026-09-12 13:10:55 -0400 EDT  main (cbeba81)
```

The `CONDITION` block is gone entirely — conditions clear themselves once the comparison succeeds — and the history's newest entry names the same revision the status line reports. You are looking for exactly that pair: the status back to `Synced`/`Healthy`, and the history showing the app tracking the expected revision again. **Verification is not optional and it is not "looks green to me."** You confirm with the same evidence you diagnosed with, which closes the loop: source → render → compare → apply → healthy. Only when `argocd app get` reports `Synced`/`Healthy` is the incident actually over.

**The through-line:** six steps, six evidence commands, and the first destructive action you took was the fix. That is the entire method, and it is the entire capstone.

---

## 6. Stability, observability, and scale

The method above handles the incident in front of you. This section is about the operator's other job: keeping Argo CD itself stable, observable, and appropriately sized so that fewer incidents happen. We cover it in the order an operator meets it — what HA buys you, how the controller scales, how the repo-server strains, how to observe all of it, and finally the capacity factors that drive every sizing decision.

### 6.1 What HA actually buys you, component by component — V-26

"Turn on HA" is not one switch. Each component fails differently and is protected differently, so knowing *which is which* tells you what an outage of each one actually costs. This course deliberately runs the **non-HA** install (one replica each) so you can observe a single component's failure cleanly; the table below states what changes when you add replicas in production.

**Predict first:** of the six components, which one's outage causes **no data loss and no stopped syncs** — only a temporary slowdown?

**V-26 · HA component failure-behavior table**

| Component | Verb | Replicated in HA? | What stops when it is down | Data loss? | What keeps working |
|---|---|---|---|---|---|
| **argocd-server** (API/UI) | *talks* | Yes (stateless; scale for availability) | Logins, the UI, the API, webhooks arriving | None | Controllers keep reconciling and syncing without you watching |
| **argocd-repo-server** | *renders* | Yes (stateless; scale for throughput) | New/changed manifests cannot be rendered; refreshes error | None | Already-cached renders; running workloads are untouched |
| **argocd-application-controller** | *compares & applies* | Yes (sharded **by cluster**) | Drift detection and syncing for the clusters on the down shard | None | Clusters owned by *other* shards keep reconciling |
| **argocd-applicationset-controller** | *generates* | Yes (active/standby via leader election) | Generating/updating Applications from ApplicationSets | None | Existing generated Applications keep reconciling on their own |
| **argocd-redis** | *remembers* | Yes (needs a real HA topology of its own) | Nothing stops; caches must be **rebuilt** | **None** | Everything — more slowly, until the cache refills |
| **argocd-notifications-controller** | *announces* | Yes | Outbound notifications (Slack, email) | None | All deployment behavior; only the *telling-you* part pauses |

**The debrief.** Two rows carry the lesson. **Redis** is the answer to the prediction: it holds *only* a cache, so losing it costs a rebuild (CPU and latency across every app) but **never** data — which is why "back up Redis" is backing up the wrong thing. And the **application-controller** row hides the single most misunderstood scaling fact in Argo CD, which gets its own diagram next: it shards by *cluster*, so an HA controller protects you cluster-by-cluster, not Application-by-Application.

### 6.2 Controller load and sharding — V-27

Here is a scaling trap teams hit late and expensively. When the application-controller is overloaded, the instinct is "add a replica." That works **only if you have multiple clusters**, because **the controller distributes clusters across replicas, not Applications.**

**Predict first:** your busiest single cluster holds 5,000 Applications and its controller is maxed out. You add a second controller replica. Does the busy cluster get any faster?

**V-27 · Controller shards by cluster, not by Application**

```text
  CASE A — MANY CLUSTERS  (sharding helps)          CASE B — ONE HUGE CLUSTER  (sharding does NOT help)
  ┌────────────────────────────────────┐            ┌────────────────────────────────────┐
  │ Replica 0  ──owns──►  cluster-1     │            │ Replica 0  ──owns──►  cluster-BIG   │
  │            ──owns──►  cluster-2     │            │                        (5,000 apps) │
  │                                     │            │                                     │
  │ Replica 1  ──owns──►  cluster-3     │            │ Replica 1  ──owns──►  (nothing)     │
  │            ──owns──►  cluster-4     │            │ Replica 2  ──owns──►  (nothing)     │
  │                                     │            │                                     │
  │ Replica 2  ──owns──►  cluster-5     │            │  Extra replicas sit idle. One       │
  │            ──owns──►  cluster-6     │            │  cluster cannot be split across      │
  │                                     │            │  replicas — a cluster is the unit.   │
  │  Load spreads. Adding replicas      │            │  The fix is architectural (more      │
  │  rebalances whole clusters.         │            │  clusters, or a bigger single shard),│
  │                                     │            │  NOT another replica.                │
  └────────────────────────────────────┘            └────────────────────────────────────┘
```

**The debrief — prediction answer: no.** A single cluster is a single shard; it cannot be split across controller replicas, so the extra replica sits idle and the busy cluster is exactly as fast as before. The fix is not a setting, it is **architecture** — split the workload across more clusters, or give the one shard more CPU and memory. Worth knowing but not worth memorizing: the number of controller replicas is set by `ARGOCD_CONTROLLER_REPLICAS`; the sharding algorithm can be `legacy` (the default), `round-robin`, or `consistent-hashing`; and the controller's worker counts are `--status-processors` (default 20) and `--operation-processors` (default 10). The headline is the shape, not the flags: **more replicas buy you nothing for a single overloaded cluster.**

### 6.3 Repo-server pressure and monorepos

The repo-server is the component that strains most surprisingly, because its cost is driven by *rendering*, and rendering cost is not obvious from the outside. Three pressures matter:

- **Memory (and OOMKills).** Rendering large charts holds the output in memory. Too many concurrent renders, or one enormous chart, and the pod is **OOMKilled**. The lever is `--parallelismlimit`, which caps how many manifest generations run at once — lower it to trade throughput for stability.
- **The one-render-per-repo constraint.** There is a sharper limit hiding under the parallelism cap: if generating manifests needs to *modify files in the local clone* (as `helm dependency build` does — that command downloads a chart's sub-charts into its local `charts/` folder before rendering, which is a file-**writing** step, not a read), **only one concurrent generation per repo-server is allowed for that repository.** This is why a monorepo with fifty applications can feel serialized *even when CPU is idle* — the constraint is the shared clone, not the processor.
- **The 90-second exec timeout.** The repo-server runs tools like `helm` and `kustomize` under a **90-second** timeout (`ARGOCD_EXEC_TIMEOUT`). This produces one of the most confusing failures in Argo CD: a chart grows slowly over months, one day renders in 95 seconds, the timeout fires, and you get a *rendering error that looks like a chart bug — on a day nobody changed the chart.* The cause is a threshold quietly crossed, not a defect introduced.

The operator's takeaway is diagnostic, not a tuning cookbook: when the repo-server is the suspect (step 5), the questions are "is it out of memory?", "is this a monorepo being serialized?", and "did something get slow enough to hit the timeout?" — in that order.

### 6.4 Observability — metrics, events, alerts, and notifications

You cannot operate what you cannot see. In production, Argo CD's metrics are usually scraped by **Prometheus** (a metrics database) and drawn on **Grafana** dashboards. This course has **no Prometheus/Grafana stack**, so you read the same numbers two more direct ways, which is also exactly how you confirm things during an incident:

- **`kubectl --context k3d-mgmt top pod -n argocd`** for live CPU and memory of each component — the fastest way to spot a pod under pressure (you used it in step 5).
- **The component metrics endpoints**, which every component exposes for scraping and you can read directly. The application-controller serves metrics on port `8082`, the API server on `8083`, and the repo-server on `8084`. You reach one with a port-forward and a plain HTTP request:

  ```bash
  kubectl --context k3d-mgmt -n argocd port-forward deploy/argocd-repo-server 8084:8084 &
  curl -s http://localhost:8084/metrics | grep -E '^argocd_'
  ```

  That prints roughly 120–160 lines on this lab's cluster, all of them Argo CD's own metric series — for example `argocd_git_request_duration_seconds_*`, labelled with the repository and the request type (`ls-remote`, `fetch`). Stop the port-forward afterwards by bringing it to the foreground with `fg` and pressing `Ctrl-C`.

- **Kubernetes events** (`kubectl --context k3d-workload -n <ns> get events`) for what actually happened to the applied resources — the workload-side truth behind a sync result. Name the **workload** context: the applied resources live there, not on the management cluster.
- **The notifications-controller** for *outbound* signals: it watches Application state and sends Slack/email/webhook messages on triggers you define. Notifications are how a human finds out at 09:05 without staring at the UI.

The most useful observability lesson is about **alert design, not metric names.** The obvious alert — "an Application is `OutOfSync`" — is the *wrong* one: it fires constantly (someone committed forty seconds ago), most firings are benign, and teams mute it within a week. The alert that carries information is **compound**: an Application has been `OutOfSync` **and** has automated sync enabled **and** has not converged for N minutes. *That* means reconciliation itself is stuck, which is always worth waking someone for. On the metrics side, the reconciliation-duration metric (`argocd_app_reconcile`) is designed to be read as a heat map — a distribution drifting toward longer times is an early warning that arrives *before* any Application turns red. **Alert on failure to converge, not on `OutOfSync`.**

That compound alert is also where an **SLA (service-level agreement** — a stated commitment about how available or fast a service will be, for example "synced within five minutes of a merge, 99.9% of the time") stops being a slogan: the "N minutes" in the alert *is* the SLA, written as a threshold. An SLA is what turns a vague "keep Argo CD healthy" into a number you can alert on and size capacity against.

### 6.5 Custom health checks, diff customizations, and ignore rules that conceal drift

Two customization levers shape what Argo CD *tells* you, and both can help or harm:

- **Custom health checks (Lua)** teach Argo CD to judge the health of a resource type it does not recognize — a CRD from some operator. Without one, such a resource shows no meaningful health and a "Healthy" tree can hide a sick custom resource. A short Lua script in `argocd-cm` fixes that by returning a real verdict. This is a *good* use of customization: it makes a badge mean more.

- **`ignoreDifferences`** does the opposite kind of thing — it tells Argo CD to stop reporting a field as drift. It is genuinely necessary: a horizontal autoscaler edits `spec.replicas`, an admission webhook injects a sidecar, and without an ignore rule those would show as permanent, unfixable `OutOfSync`. But the exact same mechanism, aimed carelessly, makes a *real* change invisible forever.

The discipline is one sentence: **every ignore rule should name a field, not a resource, and every ignore rule needs a written owner** — the system that is now responsible for that field. Compare the two rules below. Both use `jsonPointers`, which are **JSON (JavaScript Object Notation)** path expressions — a slash-separated address that names one exact field inside a manifest, so `/spec/replicas` means "the `replicas` key inside the `spec` block."

```yaml
# SAFE — field-scoped, with a clear owner.
# Owner: the HorizontalPodAutoscaler manages replica count. Argo CD must not fight it.
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/replicas
```

```yaml
# DANGEROUS — resource-scoped, no owner.
# This ignores the ENTIRE spec of the Deployment. A changed image, a removed
# securityContext, a deleted resource limit — all become invisible. Nobody owns
# "the whole spec," so this is not silenced noise; it is a permanent blind spot.
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec
```

The first rule silences a field a *named* system (the autoscaler) legitimately owns. The second silences everything and owns nothing — it would hide a security-relevant change with no way to notice. **If nothing owns the field, you have not reduced risk; you have built a place for drift to hide.**

### 6.6 Capacity factors — the sizing table

Every "how big should Argo CD be?" conversation reduces to a handful of factors, each of which loads a specific component. Treat this as a **reference table**, not something to memorize — the point is to know *which dial drives which component* so you can reason about a sizing problem.

**Capacity factors and where they land**

| Factor | Why it costs | Component that feels it first |
|---|---|---|
| Number of **Applications** | More items in the reconciliation queue; more status to compute and hold | application-controller |
| Number of **resources per Application** | Bigger live-state fetches and diffs; more cached objects | application-controller (+ Redis cache) |
| Number of **clusters** | Each cluster is a sharding unit; more clusters means more shards to spread | application-controller |
| Number of **repositories** | More connections, credentials, and clones to maintain | repo-server |
| **Repository size** (monorepos) | Longer clones and renders; the one-render-per-repo serialization; timeout risk | repo-server |
| **Change rate** (commits/min, webhook volume) | More frequent refreshes and re-renders | repo-server + application-controller |

Read across any row and you can predict the symptom: a spike in *change rate* on a *monorepo* strains the repo-server (slow renders, maybe timeouts); a jump in *cluster count* strains the controller's sharding. The table turns "it feels slow" into "here is the dial and here is the pod."

---

## 7. Backup, recovery, upgrades, and custom builds

The final operator responsibility is lifecycle: keeping a copy of what matters, recovering when infrastructure is lost, and changing versions without breaking rendering. This block rests on one fact you have met before — **Argo CD's real state is Kubernetes objects; Redis is a disposable cache** — and follows it to its practical conclusions.

### 7.1 Persistent configuration vs disposable cache; `argocd admin export`/`import`

Argo CD is *largely stateless*. Everything that matters — Applications, AppProjects, ApplicationSets, the `argocd-cm` and `argocd-rbac-cm` ConfigMaps, and the repository and cluster **Secrets** — is stored as **Kubernetes objects in the management cluster's etcd.** Redis holds only a cache and can be rebuilt without service disruption.

That reframes the backup question sharply. **Whatever is genuinely in Git does not need *restoring* — it needs *re-applying*.** Your Application and project definitions, if you truly practice GitOps, already live in a Git repository; recovering them is `kubectl apply`, not a restore. So what *does* need backing up is the part that never made it into Git — credentials in the cluster and repository Secrets, and anything someone configured through the UI. That is exactly what `argocd admin export` captures:

```bash
argocd admin export -n argocd > backup.yaml
```

It reads Argo CD's own Kubernetes objects out of the `argocd` namespace and writes them to one YAML file; `argocd admin import - < backup.yaml` reads them back. There is a memorable corollary: **the size of your export file is a receipt for everything you forgot to declare in Git.** A large export from a mature GitOps setup is a warning sign, not a comfort. (You will run the export yourself, read-only, in Section 9.)

### 7.2 Recovery when the management cluster is lost — V-28

Now the scenario worth planning for: the entire **management cluster** (`k3d-mgmt` in this lab) is gone — a node died, a region went dark, someone deleted the wrong thing. Argo CD, its Applications, its config: all vanished with the cluster's etcd. What do you actually do?

The reassuring structure is that **Git lives *outside* both clusters** (the Gitea server in this course, a hosted Git provider in production), so your desired state survived the loss entirely. Recovery is therefore a **rebuild**, not a heroic restore:

**V-28 · Management-cluster loss recovery (a narrated walkthrough)**

1. **Stand up a fresh management cluster** and install the *same* Argo CD version (`v3.5.2`, chart `10.8.4`) the same declarative way you installed it originally. This is plain infrastructure work; nothing Argo-specific has happened yet.
2. **Re-apply what is in Git.** Your Applications, AppProjects, and ApplicationSets are declared in a repository that survived. Point the new Argo CD at that repository (often a single "root" App-of-Apps) and it re-adopts every workload. Because Argo CD tracks resources by annotation, it recognizes the *already-running* workloads on the workload clusters as its own — it does not redeploy them from scratch, it reconnects to them.
3. **Import the parts that were never in Git** from your `argocd admin export` backup — chiefly the repository and cluster **Secrets** (the credentials) and any UI-only settings. This is the step the backup file exists for.
4. **Let Redis rebuild itself.** You do nothing here on purpose. The cache repopulates as the controllers reconcile; a rebuild costs a little CPU and latency and no data.
5. **Verify with the method.** Run `argocd app get` across the fleet and watch statuses return to `Synced`/`Healthy` — the same verification you use to close any incident.

The lesson is the reframe: **if Argo CD is truly declarative, losing the management cluster is a rebuild, not a disaster.** The only irreplaceable pieces are the credentials in those Secrets, which is precisely why the export exists and why it must be protected as sensitive.

> **OPTIONAL live instructor demo.** Your instructor may run this recovery live on the instructor VM (virtual machine) — deleting the management cluster and rebuilding it from Git plus an export — while you watch the workloads stay up on the workload cluster the whole time. This is a demonstration only; you are **not** asked to delete your own management cluster.

### 7.3 Upgrades — V-29, and the case study that makes it real

The most dangerous misconception in Argo CD operations is "an upgrade is only a version bump." It is not — because **Argo CD is the thing that renders your charts, so its bundled Helm version is part of your desired state.** Change the renderer and the *same chart with the same values can produce different YAML,* with no one touching Git.

This is not hypothetical. **Argo CD 3.5 moved to Helm 4** (v4.2.1) as the only binary it uses to render charts. Helm 4 changed how it coalesces `null`/nil values, so for charts that rely on that behavior (nullable defaults, or values relied upon to be dropped during coalescing), **upgrading Argo CD from 3.4 to 3.5 alone can change the rendered manifests.** An operator who treated the upgrade as "just a version bump" would ship a silent manifest change to production.

The practice that prevents this is specific and cheap, and it defines what "test compatibility before upgrading" actually means:

**V-29 · Upgrade planning timeline**

```text
  READ            COMPATIBILITY TEST            CANARY                 ROLLBACK
  release   ──►   (the real work)         ──►  upgrade ONE      ──►   criteria written
  notes           • render your real           non-critical           IN ADVANCE:
  end to          charts with the NEW          Argo CD first,         "if rendered diff
  end             version's Helm and           watch it for           is non-empty on a
  (breaking       DIFF the output against      a real cycle            prod chart, or an
  changes,        the old — a non-empty        before touching        app won't converge,
  removed         diff is a change you         the fleet              we revert to <ver>"
  flags)          are about to ship
                • check the tested-
                  Kubernetes matrix
                • bump the argocd CLI
                  to match the server minor
```

Two supporting disciplines make the timeline work:

- **Match Argo CD to Kubernetes.** Argo CD publishes a tested-Kubernetes **compatibility matrix** per release (roughly the last three or four Kubernetes minors). This lab's k3s `v1.35.8` sits inside every currently-supported Argo CD line, which is why it is a safe teaching version; in production against **RKE2**, you check the matrix the same way. And keep the `argocd` **CLI** matched to the server's *minor* version.
- **Change one variable at a time.** Do not upgrade Argo CD and Kubernetes on the same day. If something renders differently afterward, you want *one* suspect and a control group, not two suspects and a guess.

The Helm-4 story is one instance of a recurring pattern — earlier releases changed RBAC semantics and CRD sizes in ways that surprised operators who did not read the notes. The lesson generalizes: **rehearse the render, not just the rollback.**

### 7.4 Operating an internal fork — a checklist

> ### ⏱️ OPTIONAL / COMPRESSIBLE BLOCK — the one section designed to shrink when the clock runs out
>
> This subsection is deliberately built so an instructor can reduce it to a **three-minute discussion** ("what would you have to own if you forked Argo CD?") without losing anything you cannot read for yourself afterward. It is the first block to compress, and the only one. The checklist below stays in the file either way — it is a decision aid you will want on the day someone proposes a fork, not something to memorize now. Everything above this point (the six-step method, stability, backup, upgrades) is load-bearing for the capstone; this is the one part that is not.

Sometimes an organization needs a private, modified build of Argo CD — an **internal fork**. It can be the right call. But a fork moves you from *consuming* the upstream project's work to *producing* it, and that shift is permanent for the life of the divergence. Before committing to a fork, price it against this checklist — every item is a job you now own forever:

- [ ] **Upstream tracking.** Someone watches every upstream release and security advisory and decides, each time, whether and how to merge it into your fork. Miss this and your fork silently rots.
- [ ] **CVE response.** When a **CVE** lands in Argo CD, upstream ships a patch — but *you* must now apply it to your fork, rebuild, test, and roll it out on your own timeline. You have taken ownership of the security clock.
- [ ] **Image build and provenance** (**provenance** is a verifiable record of *where a software image came from and how it was built* — which source commit, which build system, which signatures). You build and sign your own images, and can prove where each one came from. Production must run *your* verified image, not a mystery binary.
- [ ] **Regression testing.** Every merge from upstream must be re-tested against your modifications, because upstream never tested against your patches. This is a standing test burden, not a one-time cost.
- [ ] **Release cadence.** You decide and maintain your own release schedule, and communicate it — you no longer inherit upstream's cadence.
- [ ] **Minimizing divergence.** Every line you change is a merge you owe forever. The discipline is to carry as few patches as possible and to upstream changes when you can, so the fork stays shallow.

The honest framing to leave with: **forking is not wrong — it is priced.** The question worth asking before you fork is, *"What would have to be true for carrying this patch forever to be cheaper than contributing it upstream?"* Often the answer sends you back upstream, which is the cheaper path.

---

## 8. Quick Checks

Answer each in your head (or on paper) before opening the explanation. These check the reasoning, not the vocabulary.

> **S7-QC1 — Order the evidence, and spot the skipped step.**
> A single Application is stuck `OutOfSync`. A teammate messages: *"I already restarted the repo-server twice and it didn't help."* Using the six-step method, what is the correct **first** evidence step here, and what did your teammate skip past?

<details>
<summary>Show answer</summary>

The correct first step is **Step 1 — validate the Git source and revision** (`argocd app get <app>`, then `git ls-remote <repo> <ref>`). You confirm the Application is tracking the revision you expect and that the revision resolves, *before* anything else.

Your teammate jumped straight to a **Step 5** action — restarting a component — without doing steps 1–4 first. That violates both core rules: **evidence before change** (they changed something before gathering any evidence) and **source before platform** (they suspected an Argo CD component before checking the Git source and the rendering). Restarting the repo-server helps only if steps 1–4 have *implicated* the repo-server; here nothing had, which is exactly why it "didn't help." Walk 1 → 2 → 3 and stop at the first step that lies: for a single-app `OutOfSync`, step 3 (`argocd app diff`, exit code **1**) usually shows the real difference, and the fix is in Git (step 6), not in a pod restart.
</details>

> **S7-QC2 — Three failures, three different impacts.**
> For each of these, state what stops working and whether any data is lost: (a) someone deletes the **Redis** pod; (b) the **repo-server** is **OOMKilled**; (c) one **application-controller shard** is lost (a controller replica that owned some clusters goes down).

<details>
<summary>Show answer</summary>

- **(a) Redis pod deleted:** **nothing stops and no data is lost.** Redis is a disposable cache. A new pod comes up and the cache refills as the controllers reconcile. The only cost is a temporary spike in CPU and latency across all apps while the cache rebuilds. (This is why backing up Redis is backing up the wrong thing.)
- **(b) repo-server OOMKilled:** **rendering stops** for anything that needs a fresh render — new syncs, refreshes, and hard refreshes error out (you see `ComparisonError`/`Unknown` on affected apps). **No data is lost**, and already-running workloads are untouched. The fix is a resource fix (more memory, or lower `--parallelismlimit`), not a data recovery.
- **(c) Controller shard lost:** **the clusters owned by that shard stop reconciling** — no drift detection, no auto-sync — until the shard is rescheduled or rebalanced. Clusters owned by *other* shards are completely unaffected. **No data is lost.** This is the practical payoff of "sharding splits clusters, not Applications": the blast radius of a lost shard is *its clusters*, not the whole fleet.

The through-line: none of the three causes data loss, because Argo CD's real state is Kubernetes objects, not anything held in a pod.
</details>

> **S7-QC3 — Safe rule, or blind spot?**
> A team adds this to an Application to stop a noisy diff:
> ```yaml
> ignoreDifferences:
>   - group: apps
>     kind: Deployment
>     jsonPointers:
>       - /spec/template/spec/containers/0/image
> ```
> Is this rule **safe** or **concealing**? Answer by naming the owner of the ignored field.

<details>
<summary>Show answer</summary>

**Concealing.** The rule ignores the **container image** of the Deployment — and *nothing legitimately owns the image except your Git source.* The image is the single most important thing GitOps is supposed to keep honest: it is what determines the code running in production. Ignoring it means someone could change the running image (a hotfix, a rollback, an attacker) and Argo CD would report `Synced` forever, never flagging the drift.

The test that catches it: **name the owner.** For a *safe* rule like ignoring `/spec/replicas`, the owner is obvious and real — the HorizontalPodAutoscaler, whose entire job is to manage replica count. For this image rule, the honest answer to "what other system is supposed to own the image?" is *nothing* — which means this is not silenced noise, it is a blind spot. A field-scoped ignore rule needs a named, legitimate owner, or it should not exist.
</details>

> **S7-QC4 — An upgrade changed the manifests, and no one touched Git.**
> You upgrade Argo CD from 3.4 to 3.5. Overnight, several Applications go `OutOfSync` even though **no one committed anything.** What happened, what compatibility test would have caught it *before* the upgrade, and — as a bonus — what would this same event have cost if you were running an internal fork?

<details>
<summary>Show answer</summary>

**What happened:** Argo CD 3.5 bundles **Helm 4** (v4.2.1) as the only chart renderer, and Helm 4 changed `null`/nil coalescing. For charts that depend on that behavior, the *same chart with the same values renders different YAML* under the new renderer. Argo CD compared the newly-rendered desired state against the unchanged live state and correctly reported a difference. Nobody touched Git; the *renderer* changed, and the renderer is part of your desired state.

**The compatibility test that would have caught it:** before upgrading, **render your real charts with the new version's Helm and diff the output against the old** (the "compatibility test" station of V-29). A non-empty diff is a manifest change you are about to ship — you would have seen it in a pull request instead of at 2 a.m. Supporting disciplines: check the tested-Kubernetes **compatibility matrix**, keep the `argocd` CLI matched to the server minor, and change one variable at a time (do not upgrade Kubernetes the same day).

**The fork bonus:** if you ran an **internal fork**, the same upgrade would be more expensive, and a related *security* event more so still. When a **CVE** appears in Argo CD, upstream ships a fix — but with a fork, *you* must merge it, rebuild your own image with provenance, re-run your regression tests against your patches, and release on your own cadence. You produce the fix instead of consuming it. That is the standing cost the fork checklist prices.
</details>

---

## 9. Try It Yourself (optional, ~5 minutes, read-only)

This micro-task lets you see the backup story from Section 7.1 with your own eyes. It **only reads** Argo CD's state and writes a file in your home directory — it changes **nothing** in the cluster and is completely safe to run.

On your VM, export Argo CD's own Kubernetes objects to a file, then list which *kinds* of object it contains:

```bash
argocd admin export -n argocd > backup.yaml
grep -E '^kind:' backup.yaml | sort | uniq -c
```

Here is the real output from a course environment at the end of Day 2. Your exact counts will differ depending on how many Applications and projects exist in your current lab state, and `sort` puts the kinds in alphabetical order:

```text
   4 kind: AppProject
   8 kind: Application
   1 kind: ApplicationSet
   4 kind: ConfigMap
   5 kind: Secret
```

That file was about 85 KB (`wc -c backup.yaml` reported 86,782 bytes). Now reflect on what the list *is*:

- The **ConfigMaps** are Argo CD's configuration (`argocd-cm`, `argocd-rbac-cm`, and friends).
- The **AppProjects**, **Applications**, and **ApplicationSets** are your declared desired state — the parts that *should* also live in Git.
- The **Secrets** are the credentials — repository passwords and cluster tokens — and these are usually the parts that are **not** in Git. This is the receipt from Section 7.1: the Secrets are what the export truly exists to protect.

Clean up when you are done (this removes the file you created):

```bash
rm -f backup.yaml
```

**Note:** passing `-n argocd` matters — it points the export at the namespace where Argo CD's objects live. Point it somewhere else and the command fails loudly rather than silently writing a useless file. Pointing it at `kube-system`, for example, produces this and exits with code `20`, leaving a zero-byte output file:

```text
{"level":"fatal","msg":"configmaps \"argocd-cmd-params-cm\" not found","time":"2026-09-12T13:34:27-04:00"}
```

That is a helpful failure: the export refuses to run at all unless it can find Argo CD's own configuration in the namespace you named. If you ever see a backup file that is suspiciously small, check its size before you trust it — `wc -c backup.yaml` costs nothing.

---

## 10. Common misconceptions

**"Restarting pods is a diagnosis."** A restart is an *intervention*, not evidence — and it is often a harmful one. It can erase the logs and in-flight state you needed to read, and it makes a healthy component look guilty because you touched it right before the symptom changed. The method's first four steps are pure evidence for exactly this reason. Restarting a component belongs at step 5 *at the earliest*, and only after steps 1–4 have named that component as the suspect.

**"Redis loss means data loss."** Redis holds only a cache. Argo CD's real state is Kubernetes objects in the management cluster's etcd. Delete Redis and Argo CD rebuilds the cache, losing performance for a few minutes, not data. If you find yourself designing a Redis backup, you are backing up the wrong thing — back up the export and, above all, keep your desired state in Git.

**"Ignore rules reduce risk."** `ignoreDifferences` reduces *noise*, which is not the same as reducing risk. A field-scoped rule with a named owner (an autoscaler owning replica count) is good hygiene. A broad rule that silences a resource, or a rule over a field nothing legitimately owns (like the container image), *increases* risk by turning real drift invisible. Every ignore rule is a promise that something else owns that field; a rule with no owner is a blind spot you built on purpose.

**"An upgrade is only a version bump."** Argo CD renders your charts, so its bundled Helm version is part of your desired state. The 3.4 → 3.5 move to Helm 4 can change rendered manifests with no Git change at all. Treat every upgrade as a potential manifest change: read the notes, render your real charts with the new version and diff, canary before the fleet, and write the rollback criteria in advance.

---

## 11. Key takeaways

- **Walk the pipeline in the direction the data flows, and stop at the first step that lies to you.** The six-step method is a walk from source to cluster: Git source/revision → repo access/rendering → rendered vs live → sync/hooks/events/health → responsible component/metrics → correct the source and verify.
- **Each step names one component — find the step and you have found the pod.** Step 2 lies → open the repo-server; step 4 lies with a `forbidden` → look at the target cluster. Localization, not just diagnosis.
- **Evidence before change, source before platform.** Your first destructive action should be the fix. Restarting a component before steps 1–4 have implicated it is guessing, and it can destroy the evidence.
- **Sharding splits clusters, not Applications.** An HA controller protects you cluster-by-cluster. Adding a replica does nothing for a single overloaded cluster — that fix is architectural.
- **Argo CD's real state is Kubernetes objects; Redis is a disposable cache.** Losing the management cluster is a *rebuild* from Git plus an export, not a disaster. The export's size is a receipt for what you forgot to declare.
- **An upgrade can change your manifests with no Git change** — because the renderer is part of your desired state. Rehearse the render (diff your real charts under the new version) before you rehearse the rollback.

---

## Transition — to the Capstone

You now have the one thing every earlier session was building toward: a **repeatable method** you can run under pressure, a way to turn "everything is red and my phone is ringing" into "walk the six steps, stop at the first lie, fix it in Git." You have also seen what it takes to keep Argo CD itself stable, observable, and recoverable.

The **capstone** is this method, applied for real, to **several connected faults at once.** You will receive an environment that is broken in more than one layer — a rendering problem, a blast-radius surprise, an ownership tangle, a permission denial, a disconnected cluster, a degraded workload hiding behind noisy drift, a component under pressure — and your job is exactly the discipline you just learned: **identify the failure layer with evidence before you change anything.** Bring the pipeline diagram (V-25) with you; bring the two rules (*evidence before change, source before platform*); and bring the habit of naming the step, then naming the pod. The capstone does not ask you to be clever. It asks you to be methodical — and you now have the method.
