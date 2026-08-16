import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { escapeHtml } from './escape-html.mjs';
import { isSafeRelativePath } from './safe-path.mjs';
import { filterTests, distinctBrowsers } from './filter-tests.mjs';
import { formatDurationMs, browserLabel, statusLabel, formatElapsed } from './format.mjs';
import { computeVideoDownload, buildVideoDownloadFilename, sanitizeFilenameSegment } from './download.mjs';
import { renderActionsHtml } from './render-card.mjs';

// --- escapeHtml / unsafe text handling ------------------------------------

test('escapeHtml neutralizes an injected <script> tag from console error text', () => {
  const out = escapeHtml('<script>alert(1)</script>');
  assert.equal(out.includes('<script>'), false);
  assert.equal(out, '&lt;script&gt;alert(1)&lt;/script&gt;');
});

test('escapeHtml escapes attribute-breaking quotes', () => {
  assert.equal(escapeHtml(`"><img src=x onerror=alert(1)>`), '&quot;&gt;&lt;img src=x onerror=alert(1)&gt;');
});

test('escapeHtml passes real Japanese candidate names through unchanged (no & < > " \')', () => {
  assert.equal(escapeHtml('山田太郎'), '山田太郎');
});

test('escapeHtml handles null/undefined without throwing', () => {
  assert.equal(escapeHtml(null), '');
  assert.equal(escapeHtml(undefined), '');
});

// --- path traversal / unsafe path handling (viewer-side defense in depth) --

test('isSafeRelativePath rejects traversal, absolute paths, and URL schemes', () => {
  assert.equal(isSafeRelativePath('../../etc/passwd'), false);
  assert.equal(isSafeRelativePath('/etc/passwd'), false);
  assert.equal(isSafeRelativePath('javascript:alert(1)'), false);
  assert.equal(isSafeRelativePath('http://evil.example/x'), false);
  assert.equal(isSafeRelativePath('mobile-chromium/../../secret.mp4'), false);
});

test('isSafeRelativePath accepts a normal package-relative path', () => {
  assert.equal(isSafeRelativePath('mobile-chromium/founding-first-assignment-100001.mp4'), true);
  assert.equal(isSafeRelativePath('mobile-webkit/founding-first-assignment-100002.mp4'), true);
});

test('isSafeRelativePath rejects non-string / empty input', () => {
  assert.equal(isSafeRelativePath(null), false);
  assert.equal(isSafeRelativePath(''), false);
  assert.equal(isSafeRelativePath(42), false);
});

// Codex Exact-HEAD review (percent-encoded traversal): resolving a raw
// (undecoded) ".."-equivalent path segment against a same-origin base is
// walked up exactly like a literal ".." by every browser's URL parser
// (WHATWG URL Standard, "double-dot path segment") — see the empirical
// `new URL(...)` verification below. isSafeRelativePath must reject the
// encoded spellings, not just the literal "..".
test('isSafeRelativePath rejects percent-encoded dot-segment traversal (any case, any of the spec spellings)', () => {
  const rejected = [
    '%2e%2e/evil.mp4',
    '.%2e/evil.mp4',
    '%2e./evil.mp4',
    'mobile-chromium/%2e%2e/evil.mp4',
    '%2E%2E/evil.mp4',
    '%2e%2E/evil.mp4',
    '%2E%2e/evil.mp4',
    'mobile-chromium/%2E%2E/../evil.mp4',
  ];
  for (const v of rejected) assert.equal(isSafeRelativePath(v), false, v);
});

test('isSafeRelativePath rejects double-encoded traversal ("%252e%252e") as defense in depth', () => {
  assert.equal(isSafeRelativePath('%252e%252e/evil.mp4'), false);
  assert.equal(isSafeRelativePath('mobile-chromium/%252e%252e/evil.mp4'), false);
});

test('isSafeRelativePath rejects raw and percent-encoded backslash traversal', () => {
  assert.equal(isSafeRelativePath('..\\evil.mp4'), false);
  assert.equal(isSafeRelativePath('mobile-chromium\\..\\evil.mp4'), false);
  assert.equal(isSafeRelativePath('..%5cevil.mp4'), false);
  assert.equal(isSafeRelativePath('..%5Cevil.mp4'), false);
  assert.equal(isSafeRelativePath('mobile-chromium%5c..%5cevil.mp4'), false);
});

test('isSafeRelativePath rejects protocol-relative URLs and every disallowed scheme', () => {
  assert.equal(isSafeRelativePath('//evil.example/video.mp4'), false);
  assert.equal(isSafeRelativePath('http://example.com/video.mp4'), false);
  assert.equal(isSafeRelativePath('https://example.com/video.mp4'), false);
  assert.equal(isSafeRelativePath('javascript:alert(1)'), false);
  assert.equal(isSafeRelativePath('data:video/mp4,AAAA'), false);
  assert.equal(isSafeRelativePath('file:///tmp/video.mp4'), false);
});

test('isSafeRelativePath treats malformed percent-encoding as unsafe, never throws', () => {
  assert.doesNotThrow(() => isSafeRelativePath('%'));
  assert.doesNotThrow(() => isSafeRelativePath('%2'));
  assert.doesNotThrow(() => isSafeRelativePath('%zz'));
  assert.doesNotThrow(() => isSafeRelativePath('mobile-chromium/%zz/evil.mp4'));
  assert.equal(isSafeRelativePath('%'), false);
  assert.equal(isSafeRelativePath('%2'), false);
  assert.equal(isSafeRelativePath('%zz'), false);
  assert.equal(isSafeRelativePath('mobile-chromium/%zz/evil.mp4'), false);
});

// --- URL-resolution verification (Section 10: don't just trust string
// matching — confirm against real URL-resolution semantics). Node's URL
// class implements the same WHATWG URL Standard algorithm a browser uses
// to resolve an <a href>/<video src>/fetch() relative reference. ---------

test('URL resolution: every path isSafeRelativePath accepts stays inside the replay package base directory', () => {
  const base = 'https://example.com/e2e-replays/';
  const basePrefix = new URL(base).pathname;
  const accepted = ['mobile-chromium/founding-first-assignment-100001.mp4', 'mobile-webkit/founding-first-assignment-100002.mp4', 'mobile-chromium/scenario.result.json'];
  for (const v of accepted) {
    assert.equal(isSafeRelativePath(v), true, v);
    const resolved = new URL(v, base);
    assert.equal(resolved.pathname.startsWith(basePrefix), true, `${v} -> ${resolved.href}`);
  }
});

test('URL resolution: traversal paths with no directory prefix escape the replay-package base directory entirely', () => {
  const base = 'https://example.com/e2e-replays/';
  const basePrefix = new URL(base).pathname;
  // A single ".." with no directory prefix consumes the base directory
  // itself and lands outside it entirely (verified against real
  // `new URL()` resolution — see the Codex-review investigation above).
  const rejectedTraversal = ['../evil.mp4', '../../evil.mp4', '%2e%2e/evil.mp4', '.%2e/evil.mp4', '%2e./evil.mp4', '%2E%2E/evil.mp4', '..\\evil.mp4', '/absolute/video.mp4'];
  for (const v of rejectedTraversal) {
    assert.equal(isSafeRelativePath(v), false, v);
    const resolved = new URL(v, base);
    assert.equal(resolved.pathname.startsWith(basePrefix), false, `${v} unexpectedly stayed inside the base directory: ${resolved.href}`);
  }
});

test('URL resolution: a traversal path prefixed by a browser subdirectory escapes THAT subdirectory (crosses into a sibling test\'s files) even though it stays under the replay-package root', () => {
  // "mobile-chromium/%2e%2e/evil.mp4" (and its raw-backslash equivalent)
  // only walk up ONE level — out of mobile-chromium/ and back into
  // e2e-replays/ itself — so they don't escape the page's own directory
  // the way a bare "../evil.mp4" does. They still break the invariant
  // that a browser's video must resolve to a path *inside that browser's
  // own subdirectory* (e.g. could reach a sibling browser's file, or
  // manifest.json itself) — confirmed against real `new URL()`
  // resolution, not assumed.
  const base = 'https://example.com/e2e-replays/';
  const ownSubdirPrefix = new URL('mobile-chromium/', base).pathname;
  for (const v of ['mobile-chromium/%2e%2e/evil.mp4', 'mobile-chromium\\..\\evil.mp4']) {
    assert.equal(isSafeRelativePath(v), false, v);
    const resolved = new URL(v, base);
    assert.equal(resolved.pathname.startsWith(ownSubdirPrefix), false, `${v} unexpectedly stayed inside mobile-chromium/: ${resolved.href}`);
    assert.equal(resolved.pathname, '/e2e-replays/evil.mp4', v);
  }
});

test('URL resolution: encoded-backslash traversal is rejected as defense-in-depth even though native URL resolution keeps it as a literal, non-traversing segment', () => {
  // Verified fact, not assumption: a browser's URL parser never decodes
  // "%5c" into an actual separator before splitting the path into
  // segments (per the WHATWG URL Standard), so "..%5cevil.mp4" resolves
  // to a literal (harmless) filename-like segment, NOT a traversal —
  // unlike the "%2e%2e"/".%2e"/"%2e." dot-segment forms above, which the
  // spec *does* special-case. isSafeRelativePath still rejects it: its
  // own single percent-decode pass turns "%5c" into a real "\" and finds
  // a ".." segment in the decoded form, a deliberately more conservative
  // check than what native resolution alone would require.
  const base = 'https://example.com/e2e-replays/';
  const basePrefix = new URL(base).pathname;
  for (const v of ['..%5cevil.mp4', 'mobile-chromium%5c..%5cevil.mp4']) {
    assert.equal(isSafeRelativePath(v), false, v);
    const resolved = new URL(v, base);
    assert.equal(resolved.pathname.startsWith(basePrefix), true, `${v} -> ${resolved.href} (expected it to stay a literal in-base segment)`);
  }
});

test('URL resolution: every scheme-bearing path isSafeRelativePath rejects is itself a fully attacker-controlled absolute URL, not a package-relative path', () => {
  // A value that parses as a standalone absolute URL (no base needed)
  // carries its own scheme/host entirely independent of manifest.json's
  // own directory — exactly what must never reach an href/src/fetch.
  const rejectedAbsolute = ['http://example.com/video.mp4', 'https://evil.example/video.mp4', 'javascript:alert(1)', 'data:video/mp4,AAAA', 'file:///tmp/video.mp4'];
  for (const v of rejectedAbsolute) {
    assert.equal(isSafeRelativePath(v), false, v);
    assert.doesNotThrow(() => new URL(v), `${v} should itself be parseable as an absolute URL`);
  }

  // Protocol-relative: inherits whatever scheme the resolving page uses,
  // but always points at a different (attacker-chosen) host.
  const base = 'https://example.com/e2e-replays/';
  const protocolRelative = '//evil.example/video.mp4';
  assert.equal(isSafeRelativePath(protocolRelative), false);
  const resolved = new URL(protocolRelative, base);
  assert.notEqual(resolved.host, new URL(base).host, `${protocolRelative} unexpectedly resolved to the same host: ${resolved.href}`);
});

// --- PASS/FAIL + Chromium/WebKit filtering --------------------------------

const SAMPLE_TESTS = [
  { id: 'a', browser: 'mobile-chromium', status: 'passed' },
  { id: 'b', browser: 'mobile-chromium', status: 'failed' },
  { id: 'c', browser: 'mobile-webkit', status: 'passed' },
  { id: 'd', browser: 'mobile-webkit', status: 'skipped' },
];

test('filterTests "all"/"all" returns every entry', () => {
  assert.equal(filterTests(SAMPLE_TESTS, { browser: 'all', status: 'all' }).length, 4);
});

test('filterTests by browser only', () => {
  const chromium = filterTests(SAMPLE_TESTS, { browser: 'mobile-chromium' });
  assert.deepEqual(chromium.map((t) => t.id), ['a', 'b']);
});

test('filterTests by status only', () => {
  const failed = filterTests(SAMPLE_TESTS, { status: 'failed' });
  assert.deepEqual(failed.map((t) => t.id), ['b']);
});

test('filterTests combines browser + status filters', () => {
  const result = filterTests(SAMPLE_TESTS, { browser: 'mobile-webkit', status: 'passed' });
  assert.deepEqual(result.map((t) => t.id), ['c']);
});

test('filterTests on an empty list returns an empty list', () => {
  assert.deepEqual(filterTests([], { browser: 'all', status: 'all' }), []);
  assert.deepEqual(filterTests(undefined, {}), []);
});

test('distinctBrowsers returns each browser once, in first-seen order', () => {
  assert.deepEqual(distinctBrowsers(SAMPLE_TESTS), ['mobile-chromium', 'mobile-webkit']);
});

// --- formatting -------------------------------------------------------------

test('formatDurationMs formats real elapsedMs as mm:ss', () => {
  assert.equal(formatDurationMs(0), '0:00');
  assert.equal(formatDurationMs(3000), '0:03');
  assert.equal(formatDurationMs(65000), '1:05');
});

test('formatDurationMs never fabricates a time for missing/invalid input', () => {
  assert.equal(formatDurationMs(null), '--:--');
  assert.equal(formatDurationMs(undefined), '--:--');
  assert.equal(formatDurationMs(-5), '--:--');
  assert.equal(formatDurationMs(NaN), '--:--');
});

test('formatElapsed is the same real-time formatting as formatDurationMs', () => {
  assert.equal(formatElapsed(3000), '0:03');
});

test('browserLabel maps known project names, passes through unknown ones', () => {
  assert.equal(browserLabel('mobile-chromium'), 'Chromium');
  assert.equal(browserLabel('mobile-webkit'), 'WebKit');
  assert.equal(browserLabel('desktop-firefox'), 'desktop-firefox');
});

test('statusLabel maps known statuses, passes through unknown ones', () => {
  assert.equal(statusLabel('passed'), '✅ PASS');
  assert.equal(statusLabel('failed'), '❌ FAIL');
  assert.equal(statusLabel('weird'), 'weird');
});

// --- MP4 download control ---------------------------------------------------

test('computeVideoDownload: a valid manifest-relative mp4 path produces an available download link', () => {
  const dl = computeVideoDownload({
    video: 'mobile-chromium/founding-first-assignment-100001.mp4',
    browser: 'mobile-chromium',
    scenario: 'founding-first-assignment',
    seed: 100001,
  });
  assert.equal(dl.available, true);
  assert.equal(dl.href, 'mobile-chromium/founding-first-assignment-100001.mp4');
  assert.equal(dl.filename, 'ses-mobile-chromium-founding-first-assignment-100001.mp4');
});

test('buildVideoDownloadFilename: mobile-chromium entry gets the correct download filename', () => {
  const name = buildVideoDownloadFilename({ browser: 'mobile-chromium', scenario: 'founding-first-assignment', seed: 100001 });
  assert.equal(name, 'ses-mobile-chromium-founding-first-assignment-100001.mp4');
});

test('buildVideoDownloadFilename: mobile-webkit entry gets the correct download filename', () => {
  const name = buildVideoDownloadFilename({ browser: 'mobile-webkit', scenario: 'founding-first-assignment', seed: 100002 });
  assert.equal(name, 'ses-mobile-webkit-founding-first-assignment-100002.mp4');
});

test('computeVideoDownload: missing video (null/undefined/empty) is unavailable — Download disabled/hidden', () => {
  assert.equal(computeVideoDownload({ video: null }).available, false);
  assert.equal(computeVideoDownload({ video: undefined }).available, false);
  assert.equal(computeVideoDownload({ video: '' }).available, false);
  assert.equal(computeVideoDownload({}).available, false);
  const dl = computeVideoDownload({ video: null });
  assert.equal(dl.href, null);
  assert.equal(dl.filename, null);
});

test('computeVideoDownload: "../evil.mp4" traversal is rejected', () => {
  assert.equal(computeVideoDownload({ video: '../evil.mp4' }).available, false);
  assert.equal(computeVideoDownload({ video: 'mobile-chromium/../../evil.mp4' }).available, false);
});

test('computeVideoDownload: "/absolute/path.mp4" is rejected', () => {
  assert.equal(computeVideoDownload({ video: '/absolute/path.mp4' }).available, false);
});

test('computeVideoDownload: external URL "https://example.com/video.mp4" is rejected', () => {
  assert.equal(computeVideoDownload({ video: 'https://example.com/video.mp4' }).available, false);
});

test('computeVideoDownload: "javascript:alert(1)" is rejected', () => {
  assert.equal(computeVideoDownload({ video: 'javascript:alert(1)' }).available, false);
});

test('computeVideoDownload: "data:" URL is rejected', () => {
  assert.equal(computeVideoDownload({ video: 'data:text/html,<script>alert(1)</script>' }).available, false);
});

test('computeVideoDownload: "file:///tmp/video.mp4" is rejected', () => {
  assert.equal(computeVideoDownload({ video: 'file:///tmp/video.mp4' }).available, false);
});

// Codex Exact-HEAD review: computeVideoDownload shares isSafeRelativePath
// with the Replay/Result/Action Trace paths, so the percent-encoded
// traversal fix applies here too — a manifest.json entry with an encoded
// traversal `video` must never produce a download link.
test('computeVideoDownload: percent-encoded and backslash traversal in `video` is rejected', () => {
  const rejected = ['%2e%2e/evil.mp4', '.%2e/evil.mp4', '%2e./evil.mp4', '%2E%2E/evil.mp4', 'mobile-chromium/%2e%2e/evil.mp4', '%252e%252e/evil.mp4', 'mobile-chromium\\..\\evil.mp4', '..%5cevil.mp4'];
  for (const video of rejected) {
    const dl = computeVideoDownload({ video, browser: 'mobile-chromium', scenario: 'x', seed: 1 });
    assert.equal(dl.available, false, video);
    assert.equal(dl.href, null, video);
  }
});

test('buildVideoDownloadFilename sanitizes special characters in scenario/browser into a safe filename', () => {
  const name = buildVideoDownloadFilename({
    browser: 'mobile/chrom<ium>',
    scenario: '../weird "scenario"!! 名前',
    seed: '10<>01',
  });
  assert.match(name, /^ses-[A-Za-z0-9._-]+\.mp4$/);
  assert.equal(name.includes('..'), false);
  assert.equal(name.includes('/'), false);
  assert.equal(name.includes('<'), false);
  assert.equal(name.includes('"'), false);
});

test('buildVideoDownloadFilename sanitizes path separators, quotes, and control characters/newlines in every field', () => {
  const name = buildVideoDownloadFilename({
    browser: '../../etc/passwd',
    scenario: "line1\nline2\r\ttab'quote\\back",
    seed: '..\\..\\evil',
  });
  assert.match(name, /^ses-[A-Za-z0-9._-]+\.mp4$/);
  for (const bad of ['/', '\\', '..', '"', "'", '<', '>', '&', '\n', '\r', '\t']) {
    assert.equal(name.includes(bad), false, `filename ${JSON.stringify(name)} unexpectedly contains ${JSON.stringify(bad)}`);
  }
});

test('sanitizeFilenameSegment falls back when the cleaned value is empty', () => {
  assert.equal(sanitizeFilenameSegment('###', 'fallback'), 'fallback');
  assert.equal(sanitizeFilenameSegment('', 'fallback'), 'fallback');
  assert.equal(sanitizeFilenameSegment(null, 'fallback'), 'fallback');
});

// --- render-card: DOM-equivalent render-result assertions -------------------
// renderActionsHtml is the exact markup app.js hands to `card.innerHTML` —
// asserting against its output (not just "does app.js's source contain
// this substring") verifies what an <a>/<button> actually renders with,
// including attribute values, for a given manifest test entry.

test('renderActionsHtml: valid video produces a real <a> Download link with the safe href and correct filename', () => {
  const html = renderActionsHtml({
    video: 'mobile-chromium/founding-first-assignment-100001.mp4',
    browser: 'mobile-chromium',
    scenario: 'founding-first-assignment',
    seed: 100001,
    actionTrace: 'mobile-chromium/founding-first-assignment-100001.trace.json',
    result: 'mobile-chromium/founding-first-assignment-100001.result.json',
  });
  assert.match(html, /<a class="download-btn secondary" href="mobile-chromium\/founding-first-assignment-100001\.mp4" download="ses-mobile-chromium-founding-first-assignment-100001\.mp4">/);
});

test('renderActionsHtml: WebKit entry gets the correct href and download filename', () => {
  const html = renderActionsHtml({
    video: 'mobile-webkit/founding-first-assignment-100002.mp4',
    browser: 'mobile-webkit',
    scenario: 'founding-first-assignment',
    seed: 100002,
  });
  assert.match(html, /<a class="download-btn secondary" href="mobile-webkit\/founding-first-assignment-100002\.mp4" download="ses-mobile-webkit-founding-first-assignment-100002\.mp4">/);
});

test('renderActionsHtml: video=null renders a disabled Download button, no <a> at all', () => {
  const html = renderActionsHtml({ video: null, actionTrace: null, result: null });
  assert.match(html, /<button type="button" class="download-btn secondary" disabled>/);
  assert.equal(/<a class="download-btn/.test(html), false);
});

test('renderActionsHtml: unsafe video (traversal/absolute/scheme) renders a disabled Download button, never an href', () => {
  const unsafeValues = ['../evil.mp4', '%2e%2e/evil.mp4', '/absolute/video.mp4', 'https://evil.example/video.mp4', 'javascript:alert(1)'];
  for (const video of unsafeValues) {
    const html = renderActionsHtml({ video, actionTrace: null, result: null });
    assert.match(html, /<button type="button" class="download-btn secondary" disabled>/, video);
    assert.equal(html.includes(video), false, `unsafe video ${JSON.stringify(video)} leaked into rendered markup`);
  }
});

test('renderActionsHtml: Replay button reflects video presence (enabled/disabled + label)', () => {
  const withVideo = renderActionsHtml({ video: 'mobile-chromium/x.mp4' });
  assert.match(withVideo, /<button type="button" class="replay-btn" >▶ Replay<\/button>/);

  const withoutVideo = renderActionsHtml({ video: null });
  assert.match(withoutVideo, /<button type="button" class="replay-btn" disabled>動画なし<\/button>/);
});

test('renderActionsHtml: Action Trace button reflects actionTrace presence', () => {
  const withTrace = renderActionsHtml({ actionTrace: 'mobile-chromium/x.trace.json' });
  assert.match(withTrace, /<button type="button" class="trace-btn secondary" >Action Trace<\/button>/);

  const withoutTrace = renderActionsHtml({ actionTrace: null });
  assert.match(withoutTrace, /<button type="button" class="trace-btn secondary" disabled>Action Trace<\/button>/);
});

test('renderActionsHtml: Result button reflects result presence', () => {
  const withResult = renderActionsHtml({ result: 'mobile-chromium/x.result.json' });
  assert.match(withResult, /<button type="button" class="result-btn secondary" >Result<\/button>/);

  const withoutResult = renderActionsHtml({ result: null });
  assert.match(withoutResult, /<button type="button" class="result-btn secondary" disabled>Result<\/button>/);
});

test('app.js still wires up Replay / Action Trace / Result / Download controls via renderActionsHtml (no regressions)', async () => {
  const src = await readFile(new URL('../app.js', import.meta.url), 'utf-8');
  assert.match(src, /replay-btn/);
  assert.match(src, /openReplayModal/);
  assert.match(src, /trace-btn/);
  assert.match(src, /openTraceModal/);
  assert.match(src, /result-btn/);
  assert.match(src, /openResultModal/);
  assert.match(src, /renderActionsHtml/);
  const renderCardSrc = await readFile(new URL('./render-card.mjs', import.meta.url), 'utf-8');
  assert.match(renderCardSrc, /download-btn/);
  assert.match(renderCardSrc, /computeVideoDownload/);
});
