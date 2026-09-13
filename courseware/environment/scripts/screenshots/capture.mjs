#!/usr/bin/env node
// capture.mjs — scripted, headless-Chrome screenshot harness for the course.
//
// Drives the 71-ID inventory in screenshot-manifest.yaml (blueprint section 9).
// For each entry it:
//   1. authenticates to Argo CD at https://localhost:8443 via POST /api/v1/session
//      (self-signed cert is accepted), and sets the `argocd.token` cookie,
//   2. navigates to the entry's route,
//   3. injects a CSS highlight (3px solid #d7263d) on the target selector,
//   4. captures a PNG at 1440x900, light theme, to
//      courseware/assets/screenshots/<filename-from-manifest>, and
//   5. records the Argo CD version (from /api/version), the capture date, and
//      each ID's state recipe into courseware/assets/screenshots/capture-log.md.
//
// Browser engine: Playwright (headless Chromium). Install once with:
//   npm install                       # installs deps from package.json
//   npx playwright install chromium   # downloads the browser
// (Playwright is chosen over puppeteer for its clean ignoreHTTPSErrors context
// option and per-context cookie/isolation model, which SS-L5-05/07 and SS-S6-02
// need to capture as the team-a-dev user.)
//
// This harness CANNOT capture until the local k3d sandbox is live (bootstrap-vm.sh
// --local). Until then it still parses cleanly (`node --check capture.mjs`) and is
// the authoritative, runnable definition of every shot.
//
// Usage:
//   node capture.mjs                 # capture every shot in the manifest
//   node capture.mjs --only SS-L1-02 # capture a single ID (repeatable)
//   node capture.mjs --guide lab-01  # capture one guide's shots

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { parse as parseYaml } from "yaml";
import { chromium } from "playwright";

// Accept the course's self-signed Argo CD certificate for the raw fetch() calls
// below (session + version). Safe here: everything talks to localhost only.
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

const __dirname = dirname(fileURLToPath(import.meta.url));
// capture.mjs lives at courseware/environment/scripts/screenshots/, so the repo
// root is four directories up.
const REPO_ROOT = resolve(__dirname, "../../../..");
const MANIFEST_PATH = join(__dirname, "screenshot-manifest.yaml");

// ---------------------------------------------------------------------------
// Tiny CLI parsing.
// ---------------------------------------------------------------------------
function parseArgs(argv) {
  const only = [];
  const guides = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--only" && argv[i + 1]) only.push(argv[++i]);
    else if (argv[i] === "--guide" && argv[i + 1]) guides.push(argv[++i]);
  }
  return { only, guides };
}

// ---------------------------------------------------------------------------
// Credentials: env var first, then the on-VM credential file (blueprint 8.5).
// ---------------------------------------------------------------------------
async function readCredential(envVar, fileName) {
  if (process.env[envVar]) return process.env[envVar].trim();
  const path = join(homedir(), "course", "credentials", fileName);
  try {
    return (await readFile(path, "utf8")).trim();
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Argo CD API helpers.
// ---------------------------------------------------------------------------
async function argoSession(baseUrl, username, password) {
  const res = await fetch(`${baseUrl}/api/v1/session`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username, password }),
  });
  if (!res.ok) {
    throw new Error(`session for ${username} failed: HTTP ${res.status}`);
  }
  const body = await res.json();
  if (!body.token) throw new Error(`session for ${username} returned no token`);
  return body.token;
}

async function argoVersion(baseUrl) {
  try {
    const res = await fetch(`${baseUrl}/api/version`);
    if (!res.ok) return "unknown";
    const body = await res.json();
    return body.Version || body.version || "unknown";
  } catch {
    return "unknown (API unreachable)";
  }
}

// ---------------------------------------------------------------------------
// Browser context per auth identity, so cookies do not leak between users.
// ---------------------------------------------------------------------------
async function makeArgoContext(browser, cfg, baseUrl, token) {
  const context = await browser.newContext({
    viewport: { width: cfg.viewport.width, height: cfg.viewport.height },
    deviceScaleFactor: cfg.viewport.device_scale_factor,
    colorScheme: cfg.viewport.color_scheme || "light",
    ignoreHTTPSErrors: true,
  });
  if (token) {
    await context.addCookies([
      { name: "argocd.token", value: token, url: baseUrl },
    ]);
  }
  return context;
}

async function makeGiteaContext(browser, cfg, baseUrl, username, password) {
  const context = await browser.newContext({
    viewport: { width: cfg.viewport.width, height: cfg.viewport.height },
    deviceScaleFactor: cfg.viewport.device_scale_factor,
    colorScheme: cfg.viewport.color_scheme || "light",
    ignoreHTTPSErrors: true,
  });
  if (username && password) {
    const page = await context.newPage();
    try {
      await page.goto(`${baseUrl}/user/login`, { waitUntil: "networkidle" });
      await page.fill('input[name="user_name"]', username);
      await page.fill('input[name="password"]', password);
      await page.click('button[type="submit"]');
      await page.waitForLoadState("networkidle");
    } catch (e) {
      console.warn(`  ! Gitea login failed: ${e.message}`);
    } finally {
      await page.close();
    }
  }
  return context;
}

// ---------------------------------------------------------------------------
// Highlight injection (3px solid #d7263d, per blueprint 9.1).
// ---------------------------------------------------------------------------
async function applyHighlight(page, selector, hl) {
  if (!selector) return "no selector (intentional)";
  try {
    const count = await page.locator(selector).count();
    if (count === 0) return `selector not found: ${selector}`;
    await page.addStyleTag({
      content: `${selector} { outline: ${hl.width_px}px ${hl.style} ${hl.color} !important; outline-offset: 2px !important; }`,
    });
    return "highlighted";
  } catch (e) {
    return `highlight error: ${e.message}`;
  }
}

// ---------------------------------------------------------------------------
// Optional per-shot UI actions, run after the page loads and before the
// highlight. Needed for states that only exist after an interaction (a sliding
// panel, a permission-denied notification). Each step is exactly one of:
//   { click: "<css or playwright selector>" }   click the first match
//   { fill: "<selector>", value: "<text>" }     type into an input
//   { wait_for: "<selector>" }                  wait until visible (15 s)
//   { wait_ms: <n> }                            fixed pause
// ---------------------------------------------------------------------------
async function runActions(page, actions) {
  for (const a of actions || []) {
    if (a.click) await page.locator(a.click).first().click({ timeout: 15000 });
    else if (a.fill) await page.locator(a.fill).first().fill(String(a.value ?? ""), { timeout: 15000 });
    else if (a.wait_for) await page.locator(a.wait_for).first().waitFor({ state: "visible", timeout: 15000 });
    else if (a.wait_ms) await page.waitForTimeout(Number(a.wait_ms));
  }
}

// ---------------------------------------------------------------------------
// Capture one shot.
// ---------------------------------------------------------------------------
async function captureShot(context, shot, cfg, baseUrl) {
  const page = await context.newPage();
  // Optional per-shot viewport override (e.g. a taller page for long panels).
  if (shot.viewport) {
    await page.setViewportSize({
      width: shot.viewport.width || cfg.viewport.width,
      height: shot.viewport.height || cfg.viewport.height,
    });
  }
  const outPath = join(REPO_ROOT, cfg.output_root, shot.filename);
  await mkdir(dirname(outPath), { recursive: true });

  const url = `${baseUrl}${shot.route || "/"}`;
  // Application detail pages hold a live event stream open, so they never reach
  // "networkidle". Default to "load" (which fires reliably) plus a fixed settle
  // for SPA hydration and data fetch; a shot may override via `wait_until`.
  await page.goto(url, { waitUntil: shot.wait_until || "load", timeout: 45000 });
  // Argo CD's UI hydrates and fetches data after the initial load; give it time.
  await page.waitForTimeout(shot.settle_ms || 3500);
  await runActions(page, shot.actions);

  const selector = shot.highlight ? shot.highlight.selector : null;
  const highlightResult = await applyHighlight(page, selector, cfg.highlight);

  // full = whole viewport; panel/detail = crop to the target element if we can.
  let scope = "viewport";
  if (shot.fidelity !== "full" && selector) {
    const el = page.locator(selector).first();
    if ((await el.count()) > 0) {
      await el.screenshot({ path: outPath });
      scope = "element";
      await page.close();
      return { ok: true, scope, highlightResult, outPath };
    }
  }
  await page.screenshot({ path: outPath, fullPage: false });
  await page.close();
  return { ok: true, scope, highlightResult, outPath };
}

// ---------------------------------------------------------------------------
// Capture log.
// ---------------------------------------------------------------------------
function buildCaptureLog(version, results) {
  const date = new Date().toISOString();
  const lines = [
    "# Screenshot capture log",
    "",
    `- **Argo CD version (from /api/version):** ${version}`,
    `- **Captured:** ${date}`,
    `- **Viewport:** 1440x900, light theme, device scale 1`,
    "",
    "| ID | Guide | File | State recipe (produced by) | Result | Highlight |",
    "|---|---|---|---|---|---|",
  ];
  for (const r of results) {
    const result = r.error ? `FAILED: ${r.error}` : `ok (${r.scope})`;
    lines.push(
      `| ${r.id} | ${r.guide} | ${r.filename} | ${r.produced_by} | ${result} | ${r.highlightResult || "-"} |`,
    );
  }
  const failures = results.filter((r) => r.error).length;
  lines.push(
    "",
    `Captured ${results.length - failures}/${results.length} shots; ${failures} need attention.`,
    "",
  );
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Main.
// ---------------------------------------------------------------------------
async function main() {
  const { only, guides } = parseArgs(process.argv.slice(2));
  const manifest = parseYaml(await readFile(MANIFEST_PATH, "utf8"));
  const cfg = manifest.config;

  let shots = manifest.shots;
  if (only.length) shots = shots.filter((s) => only.includes(s.id));
  if (guides.length) shots = shots.filter((s) => guides.includes(s.guide));
  if (shots.length === 0) {
    console.error("No shots matched the given filters.");
    process.exit(1);
  }

  const argocdBase = cfg.argocd_base_url;
  const giteaBase = cfg.gitea_base_url;

  const adminPassword = await readCredential("ARGOCD_ADMIN_PASSWORD", "argocd-admin.txt");
  const teamPassword = await readCredential("TEAM_A_DEV_PASSWORD", "team-a-dev.txt");
  const giteaPassword = await readCredential("GITEA_PASSWORD", "gitea-student.txt");

  const version = await argoVersion(argocdBase);
  console.log(`Argo CD version: ${version}`);

  // Obtain tokens up front; team-a-dev is optional (only three shots need it).
  const tokens = {};
  if (adminPassword) tokens.admin = await argoSession(argocdBase, "admin", adminPassword);
  else console.warn("! No admin password available; admin shots will be unauthenticated.");
  if (teamPassword) {
    try {
      tokens["team-a-dev"] = await argoSession(argocdBase, "team-a-dev", teamPassword);
    } catch (e) {
      console.warn(`! team-a-dev session failed: ${e.message}`);
    }
  }

  const browser = await chromium.launch({ headless: true, args: ["--ignore-certificate-errors"] });

  // Lazily created, reusable contexts keyed by "app:auth".
  const contexts = {};
  async function contextFor(shot) {
    const key = `${shot.app}:${shot.auth}`;
    if (contexts[key]) return contexts[key];
    let ctx;
    if (shot.app === "gitea") {
      ctx = await makeGiteaContext(browser, cfg, giteaBase, "student", giteaPassword);
    } else if (shot.auth === "none") {
      ctx = await makeArgoContext(browser, cfg, argocdBase, null);
    } else {
      ctx = await makeArgoContext(browser, cfg, argocdBase, tokens[shot.auth]);
    }
    contexts[key] = ctx;
    return ctx;
  }

  const results = [];
  for (const shot of shots) {
    const baseUrl = shot.app === "gitea" ? giteaBase : argocdBase;
    const base = {
      id: shot.id,
      guide: shot.guide,
      filename: shot.filename,
      produced_by: shot.produced_by,
    };
    try {
      const ctx = await contextFor(shot);
      const r = await captureShot(ctx, shot, cfg, baseUrl);
      results.push({ ...base, ...r });
      console.log(`  ok ${shot.id} -> ${shot.filename} [${r.scope}] (${r.highlightResult})`);
    } catch (e) {
      results.push({ ...base, error: e.message });
      console.error(`  FAIL ${shot.id}: ${e.message}`);
    }
  }

  for (const key of Object.keys(contexts)) await contexts[key].close();
  await browser.close();

  const logPath = join(REPO_ROOT, cfg.capture_log);
  await mkdir(dirname(logPath), { recursive: true });
  await writeFile(logPath, buildCaptureLog(version, results), "utf8");
  console.log(`\nWrote capture log: ${logPath}`);

  if (results.some((r) => r.error)) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
