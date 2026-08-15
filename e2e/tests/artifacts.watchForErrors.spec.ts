// watchForErrors()-level event-sequence coverage for the font allowlist
// correlation fix (re-review §9-13). artifacts.allowlist.spec.ts already
// covers the pure helper functions in isolation; this file exercises the
// actual `watchForErrors()` closures — the stateful per-URL correlation
// map — against the exact interleaved `requestfailed`/`console` event
// sequences the review called out, which a pure-function test can't reach.
//
// A minimal fake `Page` (just the `.on(event, cb)` surface `watchForErrors`
// actually uses) drives events in a fully deterministic, explicit order —
// deliberately not a real browser page, since the whole point here is
// pinning down exact interleavings, and real network/console event timing
// (see the investigation notes in helpers/artifacts.ts) is not something a
// test should depend on to stay non-flaky.
import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';

type Listener = (...args: unknown[]) => void;

function createFakePage(): { page: Page; emit: (event: string, ...args: unknown[]) => void } {
  const listeners: Record<string, Listener[]> = {};
  const fakePage = {
    on(event: string, cb: Listener) {
      (listeners[event] ??= []).push(cb);
      return fakePage;
    },
  };
  return {
    page: fakePage as unknown as Page,
    emit: (event: string, ...args: unknown[]) => {
      for (const cb of listeners[event] ?? []) cb(...args);
    },
  };
}

/** Shaped like the subset of Playwright's `Request` that `watchForErrors`
 * actually reads (`.url()`, `.failure()`). */
function fakeRequestFailed(url: string, errorText: string) {
  return { url: () => url, failure: () => ({ errorText }) };
}

/** Shaped like the subset of Playwright's `ConsoleMessage` that
 * `watchForErrors` actually reads (`.type()`, `.text()`, `.location()`). */
function fakeConsoleMessage(type: 'error' | 'warning' | 'log', text: string, locationUrl = '') {
  return {
    type: () => type,
    text: () => text,
    location: () => ({ url: locationUrl, lineNumber: 0, columnNumber: 0 }),
  };
}

const FONT_URL = 'https://fonts.gstatic.com/s/notosanssc/v37/abcdef.woff2';
const UNRELATED_URL = 'https://evil.example/asset.png';
const BARE_RESOURCE_ERROR = '[error] Failed to load resource: net::ERR_CONNECTION_RESET';

// Case C/D deliberately give the font and unrelated failures *different*
// network error codes (both real Chromium net:: codes, both in
// KNOWN_NETWORK_FAILURE_CODES) rather than reusing the same one for both.
// Real Chromium's bare "Failed to load resource" text is identical for any
// two failures sharing the same code, so re-using one code for both would
// make the resulting `consoleErrors` string equal regardless of *which*
// message actually survived — silently defeating exactly the identity
// check these tests exist to make (confirmed by running them against the
// pre-fix global-counter implementation: with one shared code they passed
// vacuously; with distinct codes they correctly fail against it).
const UNRELATED_ERROR_CODE = 'net::ERR_NAME_NOT_RESOLVED';
const UNRELATED_BARE_ERROR = `[error] Failed to load resource: ${UNRELATED_ERROR_CODE}`;

test.describe('watchForErrors() event-sequence correlation (re-review §13)', () => {
  test('Case A: known fonts.gstatic.com requestfailed + its own bare console error -> allowlisted', () => {
    const { page, emit } = createFakePage();
    const watcher = watchForErrors(page);

    emit('requestfailed', fakeRequestFailed(FONT_URL, 'net::ERR_CONNECTION_RESET'));
    emit('console', fakeConsoleMessage('error', 'Failed to load resource: net::ERR_CONNECTION_RESET', FONT_URL));

    expect(watcher.consoleErrors).toEqual([]);
  });

  test('Case B: arbitrary host ERR_CONNECTION_RESET (no font requestfailed at all) -> NOT allowlisted', () => {
    const { page, emit } = createFakePage();
    const watcher = watchForErrors(page);

    emit('requestfailed', fakeRequestFailed(UNRELATED_URL, 'net::ERR_CONNECTION_RESET'));
    emit('console', fakeConsoleMessage('error', 'Failed to load resource: net::ERR_CONNECTION_RESET', UNRELATED_URL));

    expect(watcher.consoleErrors).toEqual([BARE_RESOURCE_ERROR]);
  });

  test('Case C: font requestfailed -> unrelated bare console error -> font\'s own bare console error: unrelated is never swallowed', () => {
    const { page, emit } = createFakePage();
    const watcher = watchForErrors(page);

    // Old (global-counter) behavior: this requestfailed sets a single
    // pending slot with no notion of *which* URL it's for.
    emit('requestfailed', fakeRequestFailed(FONT_URL, 'net::ERR_CONNECTION_RESET'));
    // The unrelated resource's own bare console error arrives first — under
    // the old counter, this consumed the font's pending slot and got
    // silently dropped instead of the font's own message. Must not happen.
    // Note the request for this one was never even a requestfailed the
    // watcher saw as font-related — an unrelated host failing for any
    // reason must never be treated as consuming a font's pending slot.
    emit('console', fakeConsoleMessage('error', `Failed to load resource: ${UNRELATED_ERROR_CODE}`, UNRELATED_URL));
    // The font's own bare console error arrives after.
    emit('console', fakeConsoleMessage('error', 'Failed to load resource: net::ERR_CONNECTION_RESET', FONT_URL));

    // Exactly the unrelated failure must survive — the font one is genuinely
    // known-safe and correlates by its own URL.
    expect(watcher.consoleErrors).toEqual([UNRELATED_BARE_ERROR]);
  });

  test('Case D: both requestfailed events queue first, then console events interleave: unrelated is never swallowed', () => {
    const { page, emit } = createFakePage();
    const watcher = watchForErrors(page);

    emit('requestfailed', fakeRequestFailed(UNRELATED_URL, UNRELATED_ERROR_CODE));
    emit('requestfailed', fakeRequestFailed(FONT_URL, 'net::ERR_CONNECTION_RESET'));
    emit('console', fakeConsoleMessage('error', `Failed to load resource: ${UNRELATED_ERROR_CODE}`, UNRELATED_URL));
    emit('console', fakeConsoleMessage('error', 'Failed to load resource: net::ERR_CONNECTION_RESET', FONT_URL));

    expect(watcher.consoleErrors).toEqual([UNRELATED_BARE_ERROR]);
  });

  test('Case E: a generic, unrelated console.error is captured (would fail a scenario spec)', () => {
    const { page, emit } = createFakePage();
    const watcher = watchForErrors(page);

    emit('console', fakeConsoleMessage('error', "TypeError: Cannot read properties of null (reading 'foo')"));

    expect(watcher.consoleErrors).toEqual(["[error] TypeError: Cannot read properties of null (reading 'foo')"]);
    // This is exactly what founding-first-assignment.spec.ts /
    // failure-recovery.spec.ts assert is empty — a non-empty array here
    // means that scenario would (correctly) fail.
  });

  test('multiple distinct font failures each correlate to their own URL, independently', () => {
    const { page, emit } = createFakePage();
    const watcher = watchForErrors(page);
    const fontUrl2 = 'https://fonts.gstatic.com/s/notosansjp/v52/xyz123.woff2';

    emit('requestfailed', fakeRequestFailed(FONT_URL, 'net::ERR_CONNECTION_RESET'));
    emit('requestfailed', fakeRequestFailed(fontUrl2, 'net::ERR_NAME_NOT_RESOLVED'));
    emit('console', fakeConsoleMessage('error', 'Failed to load resource: net::ERR_NAME_NOT_RESOLVED', fontUrl2));
    emit('console', fakeConsoleMessage('error', 'Failed to load resource: net::ERR_CONNECTION_RESET', FONT_URL));

    expect(watcher.consoleErrors).toEqual([]);
  });

  test('a console error with no location URL is never allowlisted, even with a font failure pending (safe fallback, §12)', () => {
    const { page, emit } = createFakePage();
    const watcher = watchForErrors(page);

    emit('requestfailed', fakeRequestFailed(FONT_URL, 'net::ERR_CONNECTION_RESET'));
    emit('console', fakeConsoleMessage('error', 'Failed to load resource: net::ERR_CONNECTION_RESET', ''));

    expect(watcher.consoleErrors).toEqual([BARE_RESOURCE_ERROR]);
  });

  test('a known font host failing with an app-level (non-network) code never sets a pending slot', () => {
    const { page, emit } = createFakePage();
    const watcher = watchForErrors(page);

    emit('requestfailed', fakeRequestFailed(FONT_URL, 'net::ERR_BLOCKED_BY_CLIENT'));
    emit('console', fakeConsoleMessage('error', 'Failed to load resource: net::ERR_BLOCKED_BY_CLIENT', FONT_URL));

    expect(watcher.consoleErrors).toEqual(['[error] Failed to load resource: net::ERR_BLOCKED_BY_CLIENT']);
  });
});
