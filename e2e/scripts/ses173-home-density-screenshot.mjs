// Screen Verification capture for Issue #173 (PUBLIC-DEMO-HOME-UI-3C): serves
// build/web on a local port and screenshots HOME (fresh April) and the new
// 営業 empty state at the two required mobile viewports. Throwaway script for
// this Issue's Screen Verification, mirrors e2e/scripts/ses171-tab-
// screenshot.mjs's own server/browser setup.
import { chromium } from '@playwright/test';
import { createServer } from 'http';
import { readFile } from 'fs/promises';
import { extname, join } from 'path';

const ROOT = process.argv[2]; // e.g. /path/to/build/web
const OUT_DIR = process.argv[3]; // e.g. /path/to/docs/reports/screenshots
const PORT = 8936;

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

  // HOME, fresh April, no scroll — the "does 今月の重要タスク reach the
  // initial viewport" evidence.
  const homeOut = `${OUT_DIR}/ses-173-home-${size.name}.png`;
  await page.screenshot({ path: homeOut });
  console.log(`saved ${homeOut}`);

  // 営業, fresh April — the new truthful empty state.
  const salesNav = page.getByRole('tab', { name: '営業', exact: true }).or(
    page.getByRole('button', { name: '営業', exact: true }),
  );
  await salesNav.first().click();
  await page.waitForTimeout(600);
  const salesOut = `${OUT_DIR}/ses-173-sales-empty-${size.name}.png`;
  await page.screenshot({ path: salesOut });
  console.log(`saved ${salesOut}`);

  await context.close();
}

await browser.close();
server.close();
