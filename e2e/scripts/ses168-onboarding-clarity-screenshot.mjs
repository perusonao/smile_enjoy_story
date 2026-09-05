// Screen Verification capture for Issue #168 (FIRST-FUN-YEAR-ONBOARDING-1):
// serves build/web on a local port and screenshots the three real UI
// surfaces this Issue changed, at both required mobile viewports:
//   1. The Month Guard warning dialog, now reachable from a fresh April
//      close (Finding A) — Sato (ready, untouched) is a genuine outstanding
//      candidate.
//   2. The reworded April event dialog after proceeding past that warning
//      (Finding C) — states the true pre-seeded-candidate-pool fact instead
//      of implying a just-happened recruiting event.
//   3. The internal-training card's new explanatory line (Finding D), on
//      社員, for a waiting engineer.
// Throwaway script for this Issue's Screen Verification, mirrors
// e2e/scripts/ses173-home-density-screenshot.mjs's own server/browser setup.
import { chromium } from '@playwright/test';
import { createServer } from 'http';
import { readFile } from 'fs/promises';
import { extname, join } from 'path';

const ROOT = process.argv[2]; // e.g. /path/to/build/web
const OUT_DIR = process.argv[3]; // e.g. /path/to/docs/reports/screenshots
const PORT = 8937;

const MIME = {
  '.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json',
  '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.webmanifest': 'application/manifest+json', '.txt': 'text/plain', '.gz': 'application/gzip',
};

const server = createServer(async (req, res) => {
  try {
    let path = req.url.split('?')[0];
    if (path === '/') path = '/index.html';
    const filePath = join(ROOT, path);
    const data = await readFile(filePath);
    res.writeHead(200, { 'Content-Type': MIME[extname(filePath)] || 'application/octet-stream' });
    res.end(data);
  } catch (e) {
    res.writeHead(404);
    res.end('not found');
  }
});

await new Promise((resolve) => server.listen(PORT, resolve));
console.log(`serving ${ROOT} on :${PORT}`);

const browser = await chromium.launch({
  executablePath: process.env.SES_E2E_CHROMIUM_PATH || undefined,
});

const sizes = [
  { name: '360x800', width: 360, height: 800 },
  { name: '390x844', width: 390, height: 844 },
];

for (const size of sizes) {
  const context = await browser.newContext({
    viewport: { width: size.width, height: size.height },
  });
  const page = await context.newPage();
  page.on('console', (msg) => console.log('  [console]', msg.type(), msg.text()));
  page.on('pageerror', (err) => console.log('  [pageerror]', err));
  await page.goto(`http://localhost:${PORT}/?e2e=1#/public-demo-01`, { waitUntil: 'networkidle' });
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });
  await page.waitForTimeout(3000);

  // 1. Fresh April: tap the month-close CTA. Sato (ready, untouched) is a
  // genuine outstanding Month Guard candidate, so this must show the
  // warning dialog, not the April event dialog.
  const closeCta = page.locator("[semantics-id]", { hasText: '4月を終了して5月へ' }).or(
    page.getByRole('button', { name: /4月を終了して5月へ/ }),
  );
  await closeCta.first().click();
  await page.waitForTimeout(600);
  const guardOut = `${OUT_DIR}/ses-168-month-guard-warning-${size.name}.png`;
  await page.screenshot({ path: guardOut });
  console.log(`saved ${guardOut}`);

  // 2. Proceed anyway ("このまま月末処理を進める") — the reworded April
  // event dialog should now appear, stating the pre-seeded-pool fact.
  const proceed = page.getByRole('button', { name: /このまま月末処理を進める/ });
  await proceed.first().click();
  await page.waitForTimeout(3000);
  const eventOut = `${OUT_DIR}/ses-168-april-event-dialog-${size.name}.png`;
  await page.screenshot({ path: eventOut });
  console.log(`saved ${eventOut}`);

  await context.close();

  // 3. 社員 tab, FRESH April (a new page load, not chained off the above):
  // the internal-training card's new explanatory line. Both founding
  // engineers' own card renders in April (`ec(i)`'s own `showTrainingCard`
  // default), so no month advance is needed for this one.
  const trainingContext = await browser.newContext({
    viewport: { width: size.width, height: size.height },
  });
  const trainingPage = await trainingContext.newPage();
  trainingPage.on('console', (msg) => console.log('  [console]', msg.type(), msg.text()));
  trainingPage.on('pageerror', (err) => console.log('  [pageerror]', err));
  await trainingPage.goto(`http://localhost:${PORT}/?e2e=1#/public-demo-01`, { waitUntil: 'networkidle' });
  await trainingPage.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });
  await trainingPage.waitForTimeout(3000);
  const employeesNav = trainingPage.getByRole('tab', { name: '社員', exact: true }).or(
    trainingPage.getByRole('button', { name: '社員', exact: true }),
  );
  await employeesNav.first().click();
  await trainingPage.waitForTimeout(600);
  const employeesOut = `${OUT_DIR}/ses-168-training-card-${size.name}.png`;
  await trainingPage.screenshot({ path: employeesOut });
  console.log(`saved ${employeesOut}`);
  await trainingContext.close();
}

await browser.close();
server.close();
