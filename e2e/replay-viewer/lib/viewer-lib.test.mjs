import test from 'node:test';
import assert from 'node:assert/strict';
import { escapeHtml } from './escape-html.mjs';
import { isSafeRelativePath } from './safe-path.mjs';
import { filterTests, distinctBrowsers } from './filter-tests.mjs';
import { formatDurationMs, browserLabel, statusLabel, formatElapsed } from './format.mjs';

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
