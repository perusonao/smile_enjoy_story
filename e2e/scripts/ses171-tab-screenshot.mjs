// Screen Verification capture for Issue #171 (PUBLIC-DEMO-HOME-UI-3B): serves
// build/web on a local port and screenshots HOME plus each real
// bottom-navigation tab (社員/営業/会計/メニュー) at the two required mobile
// viewports. Throwaway script for this Issue's Screen Verification, mirrors
// e2e/scripts/ses147-screenshot.mjs's own server/browser setup.
import { chromium } from '@playwright/test';
import { createServer } from 'http';
import { readFile } from 'fs/promises';
import { extname, join } from 'path';

const ROOT = process.argv[2]; // e.g. /path/to/build/web
const OUT_DIR = process.argv[3]; // e.g. /path/to/docs/reports/screenshots
const PORT = 8935;

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

const tabs = [
  { key: 'home', name: 'ホーム' },
  { key: 'employees', name: '社員' },
  { key: 'sales', name: '営業' },
  { key: 'accounting', name: '会計' },
  { key: 'menu', name: 'メニュー' },
];

for (const size of sizes) {
  const context = await browser.newContext({
    viewport: { width: size.width, height: size.height },
  });
  const page = await context.newPage();
  page.on('console', (msg) => console.log('  [console]', msg.type(), msg.text()));
  page.on('pageerror', (err) => console.log('  [pageerror]', err));
  // e2e=1 force-enables Flutter Web's accessibility/semantics tree, the
  // same query param every existing Public Demo Playwright spec uses.
  await page.goto(`http://localhost:${PORT}/?e2e=1#/public-demo-01`, { waitUntil: 'networkidle' });
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });
  await page.waitForTimeout(3000);

  for (const tab of tabs) {
    if (tab.key !== 'home') {
      const nav = page.getByRole('tab', { name: tab.name, exact: true }).or(
        page.getByRole('button', { name: tab.name, exact: true }),
      );
      await nav.first().click();
      await page.waitForTimeout(600);
    }
    const outPath = `${OUT_DIR}/ses-171-${tab.key}-${size.name}.png`;
    await page.screenshot({ path: outPath });
    console.log(`saved ${outPath}`);
  }
  await context.close();
}

await browser.close();
server.close();
