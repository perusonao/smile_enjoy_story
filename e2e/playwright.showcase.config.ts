import { defineConfig, devices } from '@playwright/test';
import path from 'path';

// S.E.S. — Smile. Enjoy. Story. — dedicated Playwright config for the
// **video-showcase spec only** (tests-showcase/ui-showcase-video.spec.ts).
//
// Deliberately a *separate* config file/testDir from ../playwright.config.ts
// — not a project or testMatch tweak bolted onto it — so this file can be
// created without touching a single line of the existing E2E config (its
// timeout/retries/workers/skip settings, its testDir, its projects) and so
// the showcase spec is structurally invisible to `npm test`/CI's own
// `playwright test` invocation (that command only ever looks inside
// `./tests`, never `./tests-showcase`). Run explicitly via
// `npm run showcase:video` (see package.json) — never picked up by the
// normal E2E run, never adds to normal CI time.
//
// Purpose is different too: the normal suite proves the UI never dead-ends;
// this one exists purely so a human can *watch* a real playthrough exercise
// the 社員/案件タブ Phase 2 redesigns and the image-backed event modal, on a
// real Chromium mobile-portrait profile — see e2e/README.md's "Video
// showcase (manual only)" section.
const PORT = Number(process.env.SES_E2E_SHOWCASE_PORT || 4174);
const WEB_DIR = process.env.SES_E2E_WEB_DIR || path.resolve(__dirname, '../build/web');
const BASE_URL = `http://localhost:${PORT}`;

export default defineConfig({
  testDir: './tests-showcase',
  outputDir: './test-results-showcase',
  fullyParallel: false,
  forbidOnly: false,
  retries: 0,
  workers: 1,
  // A full Founding→First Assignment playthrough plus several weeks of
  // Beginner Mode enrichment (recruiting/starting sales) *and* several
  // deliberate on-screen viewing pauses — materially longer than the normal
  // suite's own per-test timeout, but this is its own dedicated budget, not
  // a change to playwright.config.ts's.
  timeout: 15 * 60 * 1000,
  expect: { timeout: 15_000 },
  reporter: [
    ['html', { outputFolder: './playwright-report-showcase', open: 'never' }],
    ['list'],
  ],
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    // Always record — this spec's entire reason to exist is the video.
    // Matches devices['Pixel 7'].viewport exactly (412x839) — a mismatched
    // recordVideo size would letterbox/scale the recording instead of
    // capturing the real portrait viewport pixel-for-pixel.
    video: { mode: 'on', size: { width: 412, height: 839 } },
    screenshot: 'off',
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
  },
  projects: [
    {
      // Chromium, smartphone-portrait only (§ task brief) — WebKit is
      // deliberately never configured here at all, not merely unused.
      name: 'mobile-chromium-showcase',
      use: {
        ...devices['Pixel 7'],
        // Same escape hatch as ../playwright.config.ts's mobile-chromium
        // project, for environments with a pre-cached Chromium binary
        // instead of Playwright's own managed install.
        launchOptions: process.env.SES_E2E_CHROMIUM_PATH ? { executablePath: process.env.SES_E2E_CHROMIUM_PATH } : undefined,
      },
    },
  ],
  webServer: {
    command: `node scripts/static-server.js ${PORT} ${JSON.stringify(WEB_DIR)}`,
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
