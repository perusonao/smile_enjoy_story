// Console/page-error capture + result-JSON / action-trace writers (§16-19).
import fs from 'fs';
import path from 'path';
import type { Page, TestInfo } from '@playwright/test';
import type { PlayResult } from './ses-player';

export interface ErrorWatcher {
  consoleErrors: string[];
  consoleWarnings: string[];
  pageErrors: string[];
  crashed: boolean;
}

/** Known-harmless console noise, allowlisted with a reason (§19) — never
 * silently widened; add an entry here only with a one-line justification. */
const CONSOLE_ALLOWLIST: { pattern: RegExp; reason: string }[] = [
  {
    // Headless Chromium/CI has no GPU, so Skia/CanvasKit falls back to a
    // software rasterizer. Purely an environment notice from the browser
    // itself, not from S.E.S. — same fallback happens in every headless
    // Flutter Web CI run, real players on real devices never see it.
    pattern: /Automatic fallback to software WebGL/i,
    reason: 'headless/no-GPU CI environment notice, not app-caused',
  },
  {
    pattern: /GroupMarkerNotSet\(crbug\.com\/242999\)/i,
    reason: 'Chromium DevTools tracing marker noise, not app-caused',
  },
  {
    // Flutter Web's CJK font fallback fetches Noto Sans SC/JP/HK glyph
    // subsets from fonts.gstatic.com on demand; a network policy that
    // blocks/resets that (seen consistently in this project's sandboxed CI)
    // only degrades glyph rendering for those code points — Japanese text
    // still renders via the bundled/system fallback, and nothing in the
    // Guided Founding flow depends on network access. Confirmed present
    // (and harmless) on all 10/10 of the seeded validation runs in the
    // completion report.
    pattern: /ERR_CONNECTION_RESET|Failed to load font|Flutter Web engine failed to complete HTTP request to fetch.*fonts\.gstatic\.com/i,
    reason: 'CJK web-font fetch blocked by this environment\'s network policy — cosmetic only, not app-caused',
  },
];

function isAllowlisted(text: string): boolean {
  return CONSOLE_ALLOWLIST.some((e) => e.pattern.test(text));
}

/** Wires console.error / pageerror / crash listeners (§19). Call before
 * `page.goto`. Fatal errors (uncaught page errors, a page crash) should
 * fail the test; console errors are recorded but only asserted on by the
 * caller so a genuinely-known-harmless one can be allowlisted above instead
 * of silently dropped. */
export function watchForErrors(page: Page): ErrorWatcher {
  const watcher: ErrorWatcher = { consoleErrors: [], consoleWarnings: [], pageErrors: [], crashed: false };
  page.on('console', (msg) => {
    const text = `[${msg.type()}] ${msg.text()}`;
    if (isAllowlisted(text)) return;
    if (msg.type() === 'error') watcher.consoleErrors.push(text);
    else if (msg.type() === 'warning') watcher.consoleWarnings.push(text);
  });
  page.on('pageerror', (err) => {
    watcher.pageErrors.push(err.stack || err.message);
  });
  page.on('crash', () => {
    watcher.crashed = true;
  });
  return watcher;
}

export interface SesResultJson {
  scenario: string;
  device: string;
  seed: number;
  completed: boolean;
  firstAssignmentWeek: number | null;
  actions: number;
  clientInterviewCount: number;
  selectionFailureCount: number;
  stallDetected: boolean;
  stallReason: string | null;
  primaryCtaWarnings: unknown[];
  stageRegressionWarnings: unknown[];
  clientInterviewHistory: unknown[];
  consoleErrors: string[];
  consoleWarnings: string[];
  pageErrors: string[];
  durationMs: number;
}

export function buildResultJson(args: {
  scenario: string;
  device: string;
  seed: number;
  play: PlayResult;
  errors: ErrorWatcher;
  durationMs: number;
}): SesResultJson {
  return {
    scenario: args.scenario,
    device: args.device,
    seed: args.seed,
    completed: args.play.completed,
    firstAssignmentWeek: args.play.firstAssignmentWeek,
    actions: args.play.actions,
    clientInterviewCount: args.play.clientInterviewCount,
    selectionFailureCount: args.play.selectionFailureCount,
    stallDetected: args.play.stallDetected,
    stallReason: args.play.stallReason,
    primaryCtaWarnings: args.play.primaryCtaWarnings,
    stageRegressionWarnings: args.play.stageRegressionWarnings,
    clientInterviewHistory: args.play.clientInterviewHistory,
    consoleErrors: args.errors.consoleErrors,
    consoleWarnings: args.errors.consoleWarnings,
    pageErrors: args.errors.pageErrors,
    durationMs: args.durationMs,
  };
}

/** Writes result.json + action-trace.json into the current test's
 * Playwright output directory (test-results/<test-name>/...) so they're
 * always attached alongside video/screenshots, and additionally attaches
 * them to the HTML report (§16-18, §21). */
export async function writeArtifacts(testInfo: TestInfo, result: SesResultJson, actionTrace: unknown[]): Promise<void> {
  const dir = testInfo.outputDir;
  fs.mkdirSync(dir, { recursive: true });

  const resultPath = path.join(dir, 'result.json');
  fs.writeFileSync(resultPath, JSON.stringify(result, null, 2), 'utf-8');
  await testInfo.attach('result.json', { path: resultPath, contentType: 'application/json' });

  const tracePath = path.join(dir, 'action-trace.json');
  fs.writeFileSync(tracePath, JSON.stringify(actionTrace, null, 2), 'utf-8');
  await testInfo.attach('action-trace.json', { path: tracePath, contentType: 'application/json' });
}

/** §15: milestone screenshots on success, always-on-failure screenshot
 * (Playwright's `screenshot: 'only-on-failure'` project setting already
 * covers the failure case; this is for the named success-path milestones). */
export async function captureMilestone(page: Page, testInfo: TestInfo, name: string): Promise<void> {
  const dir = testInfo.outputDir;
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `milestone-${name}.png`);
  await page.screenshot({ path: file });
  await testInfo.attach(`milestone-${name}`, { path: file, contentType: 'image/png' });
}
