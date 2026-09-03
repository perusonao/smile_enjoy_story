// Minimal, dependency-free static file server for the built Flutter Web
// bundle (`flutter build web`). Used only by playwright.config.ts's
// `webServer` so the E2E harness never needs an extra npm/npx download
// (works offline, and identically on Windows/macOS/Linux/CI).
//
// Usage: node static-server.js <port> <directory> [basePath]
//
// SES-CI-SPEED-2: `flutter build web --base-href "/<repo>/"` (the same
// artifact GitHub Pages deploys) bakes that path into `index.html`'s
// `<base href>` only — every other reference in the built output
// (script/link tags, the service worker's own resource list) is a
// *relative* path, resolved by the browser against that `<base>` tag. So
// once the page itself loads (always requested at `/` — every
// `e2e/tests/*.spec.ts` navigates via `page.goto('/...')`, an absolute
// path that always hits the server root regardless of `baseURL`), the
// browser's own follow-up requests for `main.dart.js` etc. go out
// *prefixed* with that base path. `basePath` (optional 3rd arg — empty by
// default, so plain root-relative builds/local dev are unaffected) tells
// this server to also serve `root`'s contents under that prefix, so one
// `flutter build web --base-href "/<repo>/"` artifact works for both the
// local smoke-e2e server (this file) and the real GitHub Pages deploy —
// no second `flutter build web` needed.
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(process.argv[2] || process.env.SES_E2E_PORT || 4173);
const root = path.resolve(process.argv[3] || process.env.SES_E2E_WEB_DIR || '../build/web');
// Normalize to always start and end with '/' (matching Flutter's own
// --base-href convention), or '' when there is no prefix to strip.
const rawBasePath = process.argv[4] || process.env.SES_E2E_BASE_PATH || '';
const basePath = rawBasePath && rawBasePath !== '/' ? `/${rawBasePath.replace(/^\/+|\/+$/g, '')}/` : '';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.data': 'application/octet-stream',
  '.symbols': 'application/octet-stream',
};

if (!fs.existsSync(root)) {
  console.error(`[static-server] build directory not found: ${root}`);
  console.error('[static-server] run `flutter build web --no-web-resources-cdn` first.');
  process.exit(1);
}

// Resolves a request path to an on-disk file under `root`, or null if it
// escapes `root` (path traversal) or doesn't exist as a file.
function resolveUnderRoot(reqPath) {
  const filePath = path.join(root, reqPath);
  if (!filePath.startsWith(root)) return null;
  try {
    return fs.statSync(filePath).isFile() ? filePath : null;
  } catch {
    return null;
  }
}

const server = http.createServer((req, res) => {
  const reqPath = decodeURIComponent((req.url || '/').split('?')[0]);
  let filePath = resolveUnderRoot(reqPath);
  // basePath fallback: a request like `/<repo>/main.dart.js` (the browser
  // following `<base href="/<repo>/">` from an index.html served at `/`)
  // doesn't exist literally under `root` — retry with the prefix stripped.
  if (!filePath && basePath && reqPath.startsWith(basePath)) {
    filePath = resolveUnderRoot(reqPath.slice(basePath.length - 1));
  }
  if (!filePath) {
    // SPA-style fallback: Flutter Web is a single index.html.
    filePath = path.join(root, 'index.html');
  }
  fs.readFile(filePath, (readErr, data) => {
    if (readErr) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(data);
  });
});

server.listen(port, () => {
  console.log(`[static-server] serving ${root} at http://localhost:${port}/`);
});
