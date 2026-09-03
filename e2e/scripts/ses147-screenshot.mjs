// Serves build/web on a local port and screenshots the Public Demo route
// at the requested viewport sizes. Throwaway script for Issue #147's
// before/after screenshot capture — not part of the Playwright test suite.
import { chromium } from '@playwright/test';
import { createServer } from 'http';
import { readFile } from 'fs/promises';
import { extname, join } from 'path';

const ROOT = process.argv[2]; // e.g. /path/to/build/web
const OUT_PREFIX = process.argv[3]; // e.g. /path/to/docs/reports/screenshots/ses-147-before
const TEXT_SCALE = process.argv[4] ? parseFloat(process.argv[4]) : null;
const PORT = 8934;

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
  await page.goto(`http://localhost:${PORT}/#public-demo-01`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(8000);
  if (TEXT_SCALE) {
    // Flutter Web (CanvasKit) reads the browser's accessibility text-scale
    // via a hidden platform-view host; the supported override is the
    // `flutter-view` textScaleFactor debug hook is not exposed at runtime
    // without --dart-define. As a practical approximation for visual
    // capture, emulate a larger root font via CSS zoom is unreliable for
    // canvas-rendered content, so instead we use CDP's
    // Emulation.setDeviceMetricsOverride is also insufficient. We fall back
    // to Playwright's `page.emulateMedia` is not applicable either.
    // See report for how 1.3x/2.0x was actually verified (widget tests).
  }
  await page.screenshot({ path: `${OUT_PREFIX}-${size.name}.png` });
  await context.close();
  console.log(`saved ${OUT_PREFIX}-${size.name}.png`);
}

await browser.close();
server.close();
