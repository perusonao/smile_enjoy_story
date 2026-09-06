// Screen capture for SES HOME Final Visual Match: serves build/web on a
// local port and screenshots the fresh-April HOME at the two required
// mobile viewports. Throwaway script for this task's Visual Acceptance
// evidence, mirrors e2e/scripts/ses173-home-density-screenshot.mjs's own
// server/browser setup.
//
// PR #182 Codex P2: this script used to also compare
// `document.scrollingElement`'s `scrollHeight`/`clientHeight` and report
// that as "real-browser no-scroll confirmed". That comparison is not
// evidence of anything: Flutter Web's `HTMLElementView`/canvas host paints
// into a browser document that is itself viewport-sized regardless of
// whatever a Flutter-side `ListView` is doing internally — an *overflowing*
// Flutter `ListView` still reports `scrollHeight == clientHeight` on the
// surrounding HTML document, because the scrolling happens entirely inside
// Flutter's own engine/semantics tree, never as browser-level document
// overflow. This script no longer makes that check or that claim. The
// numeric no-scroll evidence is
// `test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`'s
// `ScrollableState.position.maxScrollExtent == 0` (a real Flutter
// `ScrollPosition`, not a DOM measurement) — see the Result Report. This
// script now only captures screenshots, for visual (not numeric) SSOT
// comparison.
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

  const homeOut = `${OUT_DIR}/ses-home-final-visual-match-${size.name}.png`;
  await page.screenshot({ path: homeOut });
  console.log(`saved ${homeOut}`);

  await context.close();
}

await browser.close();
server.close();
