# Session 2 · Module 1 — The Component Team

> **Day 1 · Session 2 · Module 1 of 3 · ~20 minutes · concept + hands-on**
> **Goal:** understand that Argo CD is a small team of specialized programs, each with exactly one verb — so a symptom names a suspect.

---

## 1. Why this matters: "Synced but broken"

A platform engineer gets a message during business hours: *"Checkout is throwing 500 errors — customers can't pay."* They open the Argo CD dashboard, find the application, and see a calm green badge: **Synced**. Everything matches Git perfectly.

And yet customers really are getting errors. Both statements are true.

How? Because **"Synced" answers a question that has nothing to do with whether the app works.** "Synced" means only *the live cluster matches what is written in Git.* You can deploy exactly what you asked for — and what you asked for can be broken. The engineer needs to look one column over, at a **second, independent** status: **health**, which here reads **Degraded**. `Synced` + `Degraded` is a precise diagnosis: *you shipped this bug on purpose, straight from Git.* The fix is not "re-sync" — it is a new commit.

To read symptoms like this at a glance you need two things: a map of the **components** that do the work (this module), and a firm grip on the **two status axes** they report (Module 3).

---

## 2. One verb per component

Argo CD is not a single program. It is a team of specialized programs — **components** — each running as one or more **pods** (the smallest deployable unit in Kubernetes) in a namespace called `argocd` on the management cluster (`k3d-mgmt`).

The fastest way to hold them in your head: give each one exactly **one verb**. Name the verb, and you have named the suspect.

- **repository server (repo-server) — *renders.*** Hand it a Git repo and a chart; it hands back plain Kubernetes YAML. It never talks to a workload cluster. *Manifests wrong? Look here.*
- **application controller — *compares and applies.*** Takes the rendered YAML, compares it to what is running, and — when told — applies the difference. It is the **only** component that touches a workload cluster. *Sync failing or drift not corrected? Look here.*
- **API server — *talks.*** The front door: web UI, `argocd` CLI, the API, and login. It deploys nothing. *Can't log in or UI down? Look here.*
- **ApplicationSet controller — *generates Applications.*** Turns one template + a list of inputs into many Application objects. Never touches a workload cluster. (Day 2.)
- **Redis — *remembers (temporarily).*** A cache of rendered manifests and computed results. Deleting it costs performance, not data.
- **Dex — *identifies.*** An optional single-sign-on (SSO) helper. **Disabled in this course**, so you will not see a Dex pod — but it belongs on the map.

One more runs here with no Day-1 job:

- **notifications controller — *announces.*** Watches applications and can send alerts. Present at baseline with none configured; Session 7 returns to it.

> **The payoff:** every symptom maps to one verb. "Manifests are stale" → *renders* → repo-server. "The sync is stuck" → *compares/applies* → application controller. "I can't log in" → *talks* → API server. You are building a lookup table for future incidents.

---

## 3. The architecture, one picture

```text
              +---------------------------------------------------------+
              |  MANAGEMENT CLUSTER  (k3d-mgmt) · namespace argocd       |
              |  [API server]  TALKS ...... UI / CLI / API / login       |
              |  [ApplicationSet ctrl] GENERATES ... writes Applications |
              |  [application controller] COMPARES & APPLIES  <-- red    |
              |  [repo-server] RENDERS ..... Git in -> YAML out          |
              |  [Redis] REMEMBERS ......... cache only                  |
              |  [Dex] IDENTIFIES (disabled in this course)              |
              +----------------------|----------------------------------+
                     ^ reads source  |  ^ caches                | applies rendered YAML
                     |               |  |                       |  (the ONLY arrow into a cluster)
              [ Git: lab-gitea ]     +--+                       v
                                                        [ target cluster: namespace hello ]
```

**Three things to notice:**
1. **Only one arrow enters a cluster** — from the **application controller**. So "the sync did not happen" is almost always a controller or credential story, never a repo-server story.
2. **The repo-server is the only component that reads Git**, and it never reaches a cluster. A *rendering* failure and a *sync* failure live in different places.
3. **Redis is a cache** connected to both. Nothing depends on it for correctness — pull it out and the system rebuilds the cache and keeps working, more slowly.

---

## 4. See the team as running processes

**▶ Do this now — list the components.**

```bash
kubectl --context k3d-mgmt -n argocd get pods
```

**Expected output** (suffixes/ages differ):

```text
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          87m
argocd-applicationset-controller-5fb8c665fd-v97s8   1/1     Running   0          40h
argocd-notifications-controller-7797558c68-bx7j9    1/1     Running   0          40h
argocd-redis-56d6bd8bb7-5bj6r                       1/1     Running   0          2d17h
argocd-repo-server-dcb4fdc54-6ctd2                  1/1     Running   0          87m
argocd-server-779878f878-scrvn                      1/1     Running   0          87m
```

**🔍 Say each pod's verb out loud** as you read it:

| Pod (name starts with…) | Component | Its one verb |
|---|---|---|
| `argocd-server` | API server | **talks** |
| `argocd-repo-server` | repository server | **renders** |
| `argocd-application-controller` | application controller | **compares & applies** |
| `argocd-applicationset-controller` | ApplicationSet controller | **generates** |
| `argocd-redis` | Redis | **remembers** |
| `argocd-notifications-controller` | notifications controller | **announces** |

**🔍 Two meaningful absences:** there is **no `argocd-dex-server` pod** (SSO is disabled here), and the application controller ends in **`-0`** because it runs as a StatefulSet (a workload type that gives its pod a stable identity — you only need the verb today).

---

## 5. Quick Check

**S2-QC1 — One symptom, which component first?** At 9:05 a.m., **every** Application flips to a rendering error (`ComparisonError`) at once. Logins still work and the UI is responsive. Which single component do you inspect first, and why?

<details>
<summary>Show answer</summary>

**The repo-server** (verb: *renders*). Rendering is its sole job and the one component *every* Application shares for it — a fault hitting *all* apps *at once* points at that shared dependency, not any one app's Git source. "Logins still work" also clears the API server (*talks*). The symptom names the verb; the verb names the suspect.
</details>

---

## 6. Key takeaways

- Argo CD is a **team of components**, each with **one verb**: renders, compares/applies, talks, generates, remembers, identifies, announces.
- **Only the application controller touches a workload cluster**; **only the repo-server reads Git**. That split localizes most failures instantly.
- **Redis is a cache, not a database** — deleting it costs performance, not data.

**→ Next:** [02 — Four states and the Application](02-four-states-and-the-application.md)
