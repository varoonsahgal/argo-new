# Lab 5 · Module 4 — Deletion Protection and Wrap-Up

> **Day 2 · Lab 5 · Module 4 of 4 · ~10 minutes**
> **Goal:** prove the team role cannot delete an Application, understand where the deletion danger actually lives (**E5**), then confirm your checkpoint.

---

## Exercise 5 — Protect Applications from unintended deletion (5 min · governance)

**Goal.** Prove the team role cannot delete an Application even though it can sync one, and understand *why* an accidental delete is dangerous — which depends less on the object than on how the delete is requested.

**Starter state.** E1–E2 live, throwaways gone, `team-a-guestbook` `Synced`/`Healthy`. `team-a-dev` has `get`/`sync` only.

**Part A — attempt the delete for real.** First confirm the live policy, as `admin`:

```bash
argocd admin settings rbac can team-a-dev delete applications 'team-a/team-a-guestbook' --namespace argocd
```

**Do not continue until this prints `No`** — it is your safety interlock. If your E1 grant were over-broad, the next command would actually delete a working Application.

*Switch to `team-a-dev`* and try it:

```bash
argocd login localhost:8443 --username team-a-dev --insecure
argocd app delete team-a-guestbook
```

**Expected** — a fatal error that, this time, tells you everything:

```text
{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev, iat: ...","time":"..."}
```

**🔍 The rule** (compare with E4 Part A's bare `permission denied`): **when the subject may `get` the object, Argo CD names the rule** — resource, action, object, subject (`sub`), issued-at (`iat`). **When the subject may *not* `get` the object, the answer is stripped to two words**, because describing the denial would confirm the object exists. Same fence; the difference is what you are allowed to know.

**Part B — the cascade choice, and where the real danger lives.** *As `team-a-dev` in the browser*, open `team-a-guestbook`, press **DELETE**, and read the dialog before confirming.

![Delete dialog for team-a-guestbook as team-a-dev: Foreground/Background/Non-cascading, permission-denied toast (v3.5.2)](../../assets/screenshots/day-2/lab-05-07-delete-denied.png)

**🔍 Notice:** the dialog warns **Foreground**/**Background** deletion "will delete all the application's managed resources"; **Non-cascading** removes only the Application object and orphans the workloads. Confirmation is a typed name (friction by design). Confirming as `team-a-dev` produces the same detailed denial — the fence holds in both interfaces (both go through the same API server).

<!-- CAPTURE-SPEC: SS-L5-07 — delete dialog + denial as team-a-dev. State: E5B. Highlight: propagation radios, permission-denied toast. Argo CD v3.5.2. Auth: team-a-dev. -->

*Switch to `admin`* and check the objects themselves:

```bash
argocd login localhost:8443 --username admin \
  --password "$(cat ~/course/credentials/argocd-admin.txt)" --insecure
kubectl --context k3d-mgmt -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,FINALIZERS:.metadata.finalizers'
```

**Expected** — **every** app says `<none>`:

```text
NAME                          FINALIZERS
platform-agent                <none>
...
team-a-guestbook              <none>
```

**Not a single Application carries the `resources-finalizer.argocd.argoproj.io` finalizer.** The `storefront-*` apps cannot (Lab 4's `preserveResourcesOnDeletion: true` is exactly an instruction not to add it); the hand-written ones do not because nobody wrote it. And yet the UI dialog still offers to delete all managed resources. Both true — together the real rule:

| How the delete is requested | Finalizer | What happens to the workloads |
|---|---|---|
| `kubectl delete application <name>` | present | **deleted** (finalizer runs the cascade) |
| `kubectl delete application <name>` | absent | **survive**, orphaned |
| `argocd app delete <name>` (default) or the UI's Foreground/Background | absent | **deleted anyway** — the server adds the finalizer for you as it deletes |

**How far that cascade reaches: one layer.** It deletes the Application's *own* managed resources. For `team-a-guestbook` those are its Deployment and Service. For `platform-root` they are the three child *Application objects* — and because those children carry no finalizer either, their workloads keep running, orphaned (the Lab 4 Exercise 4 Notice).

> **Say the rule out loud:** the deletion danger does not live in the object — it lives in the delete **path**. Whether the workloads die is decided by *how the delete is requested* (the propagation policy the client asks for, or a finalizer running the cascade), not by any field on the Application. An app showing `<none>` for finalizers is not safe; it is one `argocd app delete` away from taking its workloads down with it.

**▶ Write two or three sentences:** *why is "there is no finalizer on it" a dangerous thing to rely on?* Connect the delete **path** to the outcome, not the object's fields. This is the reasoning the capstone expects when an Application and its workloads disappear together.

**Hints:**
- *Hint 1:* The Part A interlock exists because `argocd app delete` at v3.5.2 does not prompt. If `rbac can … --namespace argocd` prints `Yes`, stop and fix E1 first.
- *Hint 2:* Terse `permission denied` (not the detailed line) means the account cannot even `get` that object — check which account and which app.

---

## Troubleshooting

*(You are practising **evidence before change** — read the condition/sync-result/log/`can-i` answer before touching config. Session 7 names the habit.)*

| Likely failure | Cause | Fix |
|---|---|---|
| `invalid session: account password has changed since token issued` | An apply re-stamped passwords (uncommon — check the apply's output line) | Log in again (Module 1 §3); refresh the browser |
| `apply-argocd-config.sh` succeeds but the policy is unchanged | It applies what is **committed/pushed** to `main`, plus any values file you pass | Pass the path, or commit and push first; read the wrapper's `values source:` line; verify with `kubectl --context k3d-mgmt -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}'` |
| `please provide exactly one of --policy-file or --namespace` | The command has no default source | Add `--policy-file <path>` or `--namespace argocd` — never both |
| `team-a-dev` logs in but sees an empty list and every action fails | The E1 grant was not applied, or `policy.csv` is empty | Confirm `rbac can team-a-dev get applications 'team-a/*' --namespace argocd` prints `Yes`; if `No`, re-check and re-apply with the values path |
| Unexpected `InvalidSpecError … do not match any of the allowed destinations` | Fence 2 — the `source`/`destination` is outside team-a's allow-lists; nothing applied | Read the named value; fix the app or widen the project deliberately and commit |
| Sync `Phase: Error`, `0s`, `can not be managed when in namespaced mode` | Fence 2b — cluster registration forbids cluster-scoped kinds, reached before the project's allow-lists | Intended in E3B; outside the lab, fix the cluster Secret (`clusterResources`/`namespaces`) |
| Sync **starts**, `SyncFailed` row, `forbidden` | Fence 3 (Kubernetes RBAC), **not** the AppProject | Fixed on the **workload** cluster (a `Role`/`RoleBinding`); confirm with `auth can-i … --as` |
| `another operation is already in progress` | A previous sync is still running (a copy kept an automated `syncPolicy`) | `argocd app terminate-op <app>`, remove the `syncPolicy:` block, re-apply |
| `rbac can` fails with `error in RBAC request: 'sync' is not a valid resource name`, or answers `No` when you expected `Yes` | Argument order is `can <subject> <action> <resource> <object>` — resource/action swapped vs a `policy.csv` line; or the object is not `<project>/<app>` | Re-run with the correct order; object is `<project>/<app>` |

---

## Checkpoint / validation — did every denial land in the layer you predicted?

The checkpoint is not "did anything turn green" — it is **"did each refusal come from the layer I predicted, with a message that named the rule?"**

| Attempt | Predicted layer | Message contains | Result rows? | Match? |
|---|---|---|---|---|
| E3-A wrong destination | Fence 2 · AppProject | `InvalidSpecError … do not match any of the allowed destinations in project 'team-a'` | none | |
| E3-B cluster-scoped ClusterRole | Fence 2b · cluster registration | `ComparisonError … can not be managed when in namespaced mode` | none | |
| E4-A `team-a-dev` syncs storefront | Fence 1 · Argo CD RBAC | `permission denied` (terse); log adds `applications, get, storefront/…, sub: team-a-dev` | none | |
| E4-B NetworkPolicy in `team-a` | Fence 3 · Kubernetes RBAC | `forbidden … system:serviceaccount:argocd-access:argocd-manager` | one, `SyncFailed` | |
| E5 delete own app | Fence 1 · Argo CD RBAC | `permission denied: applications, delete, team-a/team-a-guestbook, sub: team-a-dev` | n/a | |

The result-rows column separates fence 2/2b from fence 3 when both show a failed operation — score it from the UI's RESULT panel or:

```bash
kubectl --context k3d-mgmt -n argocd get application <name> \
  -o jsonpath='{.status.operationState.syncResult.resources}' ; echo
```

Empty = "none"; a list with `"status":"SyncFailed"` = "one".

**You pass when:** (1) `team-a-guestbook` is `Synced`/`Healthy` and the three throwaways are gone; (2) all five attempts were refused and each observed message names the predicted layer — or you can say which guard spoke instead and why it got there first; (3) `rbac can team-a-dev sync …` prints `Yes` and `delete` prints `No`; (4) `git -C ~/platform-config log --oneline -1` shows your commit with `projects/team-a.yaml` and the `values.yaml` edit.

> **Design debrief — a guardrail is only as good as the message it fails with.** Rank the four denials by how easily a developer who hit them cold (no access to your `argocd-server` logs) could self-diagnose. The terse `permission denied` (E4-A) almost certainly ranks last — **write a better message for it.** What would it need to say to be self-serviceable *without* leaking the existence of an object the caller may not see? (There may be no fully satisfying answer — noticing that tension is the lesson.) This rehearses the Capstone's closing step: a guardrail nobody can interpret is not prevention.

---

## Key takeaways

- **A guardrail you have never tried to break is one you do not have.** The proof it works is a refused attempt; the proof it is *good* is a refusal that names the rule.
- **Four guards, three systems, four error signatures:** Argo CD RBAC, the AppProject, the cluster registration scope, and Kubernetes RBAC. Three live in Argo CD; one on the workload cluster.
- **Several guards can refuse the same request, and only the first speaks.** Name the layer from the message's **vocabulary** (`project` vs `namespaced mode` vs `system:serviceaccount:`), not from what you predicted.
- **Read the sync result — and know where it lives.** Argo CD-side refusal = `Duration: 0s`, empty result; Kubernetes-side = a `SyncFailed` row per resource. That tells you which team to page.
- **How much a denial tells you depends on what you may see** — Argo CD names the exact rule when you can `get` the object, and says only `permission denied` when you cannot. The full detail is always in the `argocd-server` log (`security=2`).
- **`rbac can … --policy-file` is a unit test for your permission model**; `--namespace argocd` is the production check.
- **Deletion danger lives in the delete *path*, not the object.** No Application here carries the cascade finalizer, and a UI/CLI delete would still take that app's own workloads down. Least privilege on `delete` is the boundary that holds.

---

## Optional stretch challenges (clearly optional)

1. **Add an explicit `deny` and prove deny precedence.** In Argo CD RBAC a `deny` always beats an `allow`, regardless of order. Add `p, role:team-a, applications, delete, <project>/*, deny`; prove it offline (both a broad `allow` and your `deny` in a scratch file → still `No`) and live.
2. **Lock the ApplicationSet controller.** In `~/platform-config/argocd/values.yaml`, add `applicationsetcontroller.policy: create-update` under `configs.params` (the `params:` block, next to `server.insecure`), then apply with the path, as in Exercise 1. Confirm it landed: `kubectl --context k3d-mgmt -n argocd get cm argocd-cmd-params-cm -o jsonpath='{.data.applicationsetcontroller\.policy}'` prints `create-update`. **Predict:** can a single ApplicationSet still opt into `create-delete`? Test it with a scratch ApplicationSet whose Application has nothing to deploy, then delete the scratch ApplicationSet. Revert without losing your Lab 5 work: `git -C ~/platform-config checkout -- argocd/values.yaml`, then run `apply-argocd-config.sh` with no argument (it re-applies `main`, which holds your committed E1 grant).
3. **Add a deny sync window on `storefront`.** `argocd proj windows add storefront --kind deny --schedule "* * * * *" --duration 1h --applications "*"`. With `manualSync` off, even an **admin** manual sync is refused (`cannot sync: blocked by sync window`). Remove it when done: `argocd proj windows list storefront` shows its `ID` (`0` if it is the only window), then `argocd proj windows delete storefront 0`.
4. **Issue a project-role JWT for automation.** A *project role* is an identity that lives inside one AppProject; a JWT (JSON Web Token) is the signed credential a CI job presents instead of a password.

   ```bash
   argocd proj role create team-a ci-sync
   argocd proj role add-policy team-a ci-sync --action get  --permission allow --object '*'
   argocd proj role add-policy team-a ci-sync --action sync --permission allow --object '*'
   argocd proj role get team-a ci-sync
   ```

   Two details matter. `--object` is the Application name **inside this project** — the CLI adds the `team-a/` prefix itself, so `'*'` becomes `team-a/*` (typing `'team-a/*'` produces `team-a/team-a/*`, which matches nothing). And a role needs `get` as well as `sync`, because the CLI fetches the Application before it syncs it. Then create a token straight into a shell variable, so it is **never printed**: `TOKEN="$(argocd proj role create-token team-a ci-sync -t)"` (`-t` outputs only the token), and pass it to commands with `--auth-token "$TOKEN"`. Predict before you try: which of `argocd app get team-a-guestbook`, `argocd app delete team-a-guestbook`, and `argocd app get storefront-prod-workload` does the token allow? This is the safe alternative to handing automation a broad admin token. Clean up with `unset TOKEN` and `argocd proj role delete team-a ci-sync`.

---

## Transition — from fences to failures

You have built and *felt* every boundary a platform team owns, and you can read an authorization denial down to the exact guard that produced it — including when the guard you expected never got to speak.

That reading skill becomes the core of the course's finale. **[Session 7 — Reliability, Troubleshooting, and Lifecycle Operations](../07-reliability-troubleshooting-lifecycle.md)** formalizes the repeatable troubleshooting method you have built since Lab 1 and names the discipline you used here: **evidence before change**. Then the **Capstone** hands you a platform with *several* connected failures at once — one an authorization denial like these, except nobody tells you which guard it is. The habits you built today — *did anything actually get applied?* and *whose vocabulary is this message written in?* — are how you will find it.
