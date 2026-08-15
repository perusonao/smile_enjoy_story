// Minimal, dependency-free static file server for the built Flutter Web
// bundle (`flutter build web`). Used only by playwright.config.ts's
// `webServer` so the E2E harness never needs an extra npm/npx download
// (works offline, and identically on Windows/macOS/Linux/CI).
//
// Usage: node static-server.js <port> <directory>
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(process.argv[2] || process.env.SES_E2E_PORT || 4173);
const root = path.resolve(process.argv[3] || process.env.SES_E2E_WEB_DIR || '../build/web');

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

const server = http.createServer((req, res) => {
  let reqPath = decodeURIComponent((req.url || '/').split('?')[0]);
  let filePath = path.join(root, reqPath);
  if (!filePath.startsWith(root)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }
  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
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
});

server.listen(port, () => {
  console.log(`[static-server] serving ${root} at http://localhost:${port}/`);
});
