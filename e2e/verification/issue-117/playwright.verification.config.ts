import { defineConfig } from '@playwright/test';
import path from 'path';

// Issue #117 — Screen Verification Gate harness.
//
// Deliberately separate from e2e/playwright.config.ts: the gate demands two
// *explicit* viewport widths (360 and 390 CSS px), not a device preset, and
// it demands video + trace + milestone screenshots on the PASSING path —
// while the main config keeps video/trace on failure only. Nothing in the
// main harness is modified or weakened; this config only adds a stricter,
// evidence-producing profile on top of it.
const PORT = Number(process.env.SES_VERIFY_PORT || 4199);
const PAGES_ROOT = process.env.SES_VERIFY_PAGES_ROOT || path.resolve(__dirname, '../../../.verification/pages-root');
const PROJECT_PATH = process.env.SES_VERIFY_PROJECT_PATH || '/smile_enjoy_story/';
const BASE_URL = `http://localhost:${PORT}`;

// Explicit CSS-pixel viewports required by the gate. deviceScaleFactor is
// pinned to a real mobile value and isMobile/hasTouch are on, so layout is
// evaluated the way a phone actually evaluates it — but the *width* is set
// literally, never inferred from a device preset.
const mobile = (width: number) => ({
  viewport: { width, height: 800 },
  // Recorded at the viewport's own size so the 360px video is a 360px video,
  // not a letterboxed 390px one.
  video: { mode: 'on' as const, size: { width, height: 800 } },
  deviceScaleFactor: 3,
  isMobile: true,
  hasTouch: true,
  userAgent:
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36',
  launchOptions: process.env.SES_E2E_CHROMIUM_PATH
    ? { executablePath: process.env.SES_E2E_CHROMIUM_PATH }
    : undefined,
});

export default defineConfig({
  testDir: __dirname,
  testMatch: /screen-verification\.spec\.ts/,
  outputDir: path.resolve(__dirname, '../../../.verification/test-results'),
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 5 * 60 * 1000,
  expect: { timeout: 15_000 },
  reporter: [
    ['list'],
    ['json', { outputFile: path.resolve(__dirname, '../../../.verification/verification-report.json') }],
  ],
  use: {
    baseURL: BASE_URL,
    // Evidence, not diagnostics: the gate has to be provable on a green run.
    // Screencast frames are switched off because the always-on video already
    // carries the visual record — keeping both put ~60MB of duplicate JPEGs
    // in the traces and pushed the artifact bundle over its delivery limit.
    // Actions, DOM snapshots, network and sources are all retained.
    trace: { mode: 'on', screenshots: false, snapshots: true, sources: true },
    // Per-project video size is set in `mobile()` below.
    screenshot: 'only-on-failure',
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
  },
  projects: [
    { name: 'mobile-360', use: mobile(360) },
    { name: 'mobile-390', use: mobile(390) },
  ],
  webServer: {
    command: `node ${JSON.stringify(path.join(__dirname, 'pages-static-server.js'))} ${PORT} ${JSON.stringify(PAGES_ROOT)} ${JSON.stringify(PROJECT_PATH)}`,
    url: `${BASE_URL}${PROJECT_PATH}`,
    reuseExistingServer: true,
    timeout: 30_000,
  },
});
