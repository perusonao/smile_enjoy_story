// SES NON-HOME-UI MENU Visual Complete: Screen Verification capture —
// serves build/web on a local port and screenshots the メニュー tab at the
// two required mobile viewports, optionally expanding the collapsed
// "開発・テストメニュー" section first. Throwaway script, mirrors
// e2e/scripts/ses-accounting-visual-complete-screenshot.mjs's own
// server/browser setup.
import { chromium } from '@playwright/test';
import { createServer } from 'http';
import { readFile } from 'fs/promises';
import { extname, join } from 'path';

const ROOT = process.argv[2];
const OUT_DIR = process.argv[3];
const LABEL = process.argv[4] || 'AFTER';
const PORT = Number(process.argv[5] || 8939);
const EXPANDED = process.argv[6] === 'expanded';

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
  page.on('pageerror', (err) => console.log('  [pageerror]', err));
  await page.goto(`http://localhost:${PORT}/?e2e=1#/public-demo-01`, { waitUntil: 'networkidle' });
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });
  await page.waitForTimeout(3000);

  const nav = page.getByRole('tab', { name: 'メニュー', exact: true }).or(
    page.getByRole('button', { name: 'メニュー', exact: true }),
  );
  await nav.first().click();
  await page.waitForTimeout(800);

  if (EXPANDED) {
    const toggle = page.getByText('開発・テストメニュー', { exact: true });
    await toggle.first().click();
    await page.waitForTimeout(500);
  }

  const outPath = `${OUT_DIR}/SES_NON-HOME-UI_MENU_Visual-Complete_${LABEL}_${size.name}.png`;
  await page.screenshot({ path: outPath });
  console.log(`saved ${outPath}`);

  await context.close();
}

await browser.close();
server.close();
