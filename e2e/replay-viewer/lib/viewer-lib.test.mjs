import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { escapeHtml } from './escape-html.mjs';
import { isSafeRelativePath } from './safe-path.mjs';
import { filterTests, distinctBrowsers } from './filter-tests.mjs';
import { formatDurationMs, browserLabel, statusLabel, formatElapsed } from './format.mjs';
import { computeVideoDownload, buildVideoDownloadFilename, sanitizeFilenameSegment } from './download.mjs';

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
});

test('isSafeRelativePath rejects non-string / empty input', () => {
  assert.equal(isSafeRelativePath(null), false);
  assert.equal(isSafeRelativePath(''), false);
  assert.equal(isSafeRelativePath(42), false);
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

test('sanitizeFilenameSegment falls back when the cleaned value is empty', () => {
  assert.equal(sanitizeFilenameSegment('###', 'fallback'), 'fallback');
  assert.equal(sanitizeFilenameSegment('', 'fallback'), 'fallback');
  assert.equal(sanitizeFilenameSegment(null, 'fallback'), 'fallback');
});

test('app.js still wires up Replay / Action Trace / Result controls alongside the new Download control (no regressions)', async () => {
  const src = await readFile(new URL('../app.js', import.meta.url), 'utf-8');
  assert.match(src, /replay-btn/);
  assert.match(src, /openReplayModal/);
  assert.match(src, /trace-btn/);
  assert.match(src, /openTraceModal/);
  assert.match(src, /result-btn/);
  assert.match(src, /openResultModal/);
  assert.match(src, /download-btn/);
  assert.match(src, /computeVideoDownload/);
});
