import { defineConfig, devices } from '@playwright/test';
import path from 'path';

// S.E.S. — Smile. Enjoy. Story. — Playwright E2E config.
//
// Real-UI QA/UX audit layer for the Founding Prologue (Guided Founding),
// independent from the Dart headless simulations under /tool. See
// e2e/README.md for how this fits the Simulation / Playwright / Manual Play
// three-layer QA strategy.

const PORT = Number(process.env.SES_E2E_PORT || 4173);
const WEB_DIR = process.env.SES_E2E_WEB_DIR || path.resolve(__dirname, '../build/web');
const BASE_URL = `http://localhost:${PORT}`;

// Always record video for failed runs (§14 of the E2E brief); set
// SES_E2E_VIDEO=on to additionally keep video for passing runs (useful when
// eyeballing a full 10-seed batch), or =off to disable entirely.
const videoMode = (process.env.SES_E2E_VIDEO as 'on' | 'off' | 'retain-on-failure' | undefined) ?? 'retain-on-failure';

export default defineConfig({
  testDir: './tests',
  outputDir: './test-results',
  fullyParallel: false, // one Flutter Web instance at a time keeps seeded runs easy to reason about
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 2 : undefined,
  timeout: 5 * 60 * 1000, // a full Founding → First Assignment playthrough, incl. slow headless software-rendered semantics start-up
  expect: { timeout: 15_000 },
  reporter: [
    ['html', { outputFolder: './playwright-report', open: 'never' }],
    ['list'],
    ['json', { outputFile: './test-results/playwright-report.json' }],
  ],
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    video: videoMode,
    screenshot: 'only-on-failure',
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    // Escape hatch for environments with a pre-cached browser binary at a
    // fixed path (e.g. a sandboxed CI image) instead of Playwright's own
    // managed install — unset for everyone else, incl. normal CI, which
    // installs its own matching browsers via `playwright install`.
    launchOptions: process.env.SES_E2E_CHROMIUM_PATH ? { executablePath: process.env.SES_E2E_CHROMIUM_PATH } : undefined,
  },
  projects: [
    {
      // Android/Chrome-equivalent mobile profile (§4).
      name: 'mobile-chromium',
      use: { ...devices['Pixel 7'] },
    },
    {
      // iPhone/Safari-equivalent mobile profile (§4, first-choice target —
      // S.E.S. is primarily a smartphone-portrait game).
      name: 'mobile-webkit',
      use: { ...devices['iPhone 14'] },
    },
  ],
  webServer: {
    command: `node scripts/static-server.js ${PORT} ${JSON.stringify(WEB_DIR)}`,
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
