// Verification-only static server for the Issue #117 Screen Verification Gate.
//
// The repo's own e2e/scripts/static-server.js serves a single `build/web`
// bundle at the server root. The deployed Public Demo, however, lives under
// GitHub Pages' project path (`/smile_enjoy_story/`) and is entered through a
// real directory (`/smile_enjoy_story/public-demo/index.html`, the meta/JS
// redirect committed in `web/public-demo/`). Reproducing that URL shape
// faithfully needs two behaviours the root-only server does not have:
//
//   1. `<dir>/` must resolve to `<dir>/index.html` (GitHub Pages' directory
//      index), so the `/public-demo/` redirect page is actually served
//      instead of being swallowed by the SPA fallback.
//   2. The SPA fallback must land on the *project* index.html
//      (`/smile_enjoy_story/index.html`), matching the base-href the Pages
//      build was compiled with.
//
// Nothing here touches production code or the existing E2E harness; it only
// mirrors the hosting layout so the verified URL is the deployed URL.
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(process.argv[2] || 4199);
const root = path.resolve(process.argv[3] || 'pages-root');
const projectPath = process.argv[4] || '/smile_enjoy_story/';

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
  '.txt': 'text/plain; charset=utf-8',
};

if (!fs.existsSync(root)) {
  console.error(`[pages-static-server] root not found: ${root}`);
  process.exit(1);
}

const send = (res, filePath) => {
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
      'Content-Length': data.length,
      'Cache-Control': 'no-store',
    });
    res.end(data);
  });
};

const server = http.createServer((req, res) => {
  const reqPath = decodeURIComponent((req.url || '/').split('?')[0].split('#')[0]);
  const resolved = path.resolve(path.join(root, reqPath));
  if (resolved !== root && !resolved.startsWith(root + path.sep)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }
  fs.stat(resolved, (err, stat) => {
    if (!err && stat.isFile()) return send(res, resolved);
    if (!err && stat.isDirectory()) {
      const indexFile = path.join(resolved, 'index.html');
      if (fs.existsSync(indexFile)) return send(res, indexFile);
    }
    // SPA fallback to the project's own index.html (base-href aware).
    return send(res, path.join(root, projectPath, 'index.html'));
  });
});

server.listen(port, () => {
  console.log(`[pages-static-server] ${root} on http://localhost:${port}${projectPath}`);
});
