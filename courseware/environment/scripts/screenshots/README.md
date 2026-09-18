# Screenshot harness

Scripted, headless-Chrome capture of all **71** course screenshots (blueprint
section 9). `screenshot-manifest.yaml` is the authoritative inventory;
`capture.mjs` drives it.

## What it does

For every entry in `screenshot-manifest.yaml`, `capture.mjs`:

1. authenticates to Argo CD at `https://localhost:8443` via `POST /api/v1/session`
   (the self-signed certificate is accepted), and sets the `argocd.token` cookie;
2. navigates to the entry's route;
3. injects a CSS highlight (**3px solid `#d7263d`**) on the target selector;
4. captures a PNG at **1440×900, light theme** to
   `courseware/assets/screenshots/<filename>`; and
5. writes `courseware/assets/screenshots/capture-log.md` with the Argo CD
   version (from `/api/version`), the capture date, and each ID's state recipe.

Three shots (`SS-L5-05`, `SS-L5-07`, `SS-S6-02`) are captured as the `team-a-dev`
user in an isolated browser context; the two Gitea shots log in to Gitea.

## Dependencies

- **Node** 20+ (uses the built-in global `fetch`).
- **[Playwright](https://playwright.dev/)** (headless Chromium) and **[yaml](https://www.npmjs.com/package/yaml)** — declared in `package.json`.

Playwright is chosen over puppeteer for its clean `ignoreHTTPSErrors` context
option and per-context isolation (needed for the `team-a-dev` captures).

## Install

```bash
cd courseware/environment/scripts/screenshots
npm install
npx playwright install chromium
```

## Prerequisite: a live sandbox

Captures require the local two-cluster sandbox to be running with Argo CD
reachable at `https://localhost:8443` and Gitea at `http://localhost:3000`:

```bash
../bootstrap-vm.sh --local
```

The harness reads credentials from environment variables, falling back to the
on-VM files written by bootstrap (`~/course/credentials/`):

| Env var | Fallback file | Used for |
|---|---|---|
| `ARGOCD_ADMIN_PASSWORD` | `argocd-admin.txt` | all `admin` shots |
| `TEAM_A_DEV_PASSWORD` | `team-a-dev.txt` | `SS-L5-05`, `SS-L5-07`, `SS-S6-02` |
| `GITEA_PASSWORD` | `gitea-student.txt` | the two Gitea shots |

## Run

```bash
node capture.mjs                 # every shot
node capture.mjs --only SS-L1-02 # one ID (repeatable)
node capture.mjs --guide lab-01  # one guide's shots
```

Reaching a specific shot's state (checkpoint + lab step) is described in each
manifest entry's `produced_by` field. Drive the sandbox to that state with
`reset-lab.sh <CP>`, the lab's own commands, or `inject-capstone-faults.sh`
before capturing that shot (blueprint 9.1).

## Capstone shots (SS-CAP-01 / 02 / 03)

These three entries are **specified in the manifest but have never been captured** —
`courseware/assets/screenshots/day-2/capstone-0*.png` do not exist, and
`capture-log.md` has no rows for them.

The capstone learner guides therefore **do not embed them**. Where the old guides
showed a screenshot, the rewritten modules show the same information as a rendered
table or diagram, so the capstone reads correctly whether or not a capture run has
happened. The manifest entries are kept so a future capture run still produces them:

```bash
inject-capstone-faults.sh inject all       # SS-CAP-01 needs the faults present
node capture.mjs --only SS-CAP-01
inject-capstone-faults.sh revert all       # SS-CAP-02 and SS-CAP-03 need a restored platform
node capture.mjs --only SS-CAP-02 --only SS-CAP-03
```

If you do capture them, add the figures back to
[capstone module 3](../../../day-2/capstone/03-setup-and-rules.md) (incident start),
[module 7](../../../day-2/capstone/07-restore-verify-reflect.md) (restored list) and
[module 8](../../../day-2/capstone/08-troubleshooting-and-close.md) (restored clusters).

## Provisional routes and selectors (P-18)

Every `route` and `highlight.selector` in the manifest is **provisional** and
must be confirmed live at capture time. `capture.mjs` degrades gracefully when a
selector is not found — it still captures the shot and records "selector not
found" in the capture log. Never copy a provisional route or selector into a
participant guide.

## Alpha UI captions

Entries carrying `caption_note: "ApplicationSet UI is Alpha since v3.5.0"`
(`SS-S5-01/02`, `SS-L4-03/04/05/07/10`) show the ApplicationSet Alpha UI. Their
captions in the guides must state this, and they must be recaptured on any Argo
CD version change.

## Syntax check

```bash
node --check capture.mjs
```
