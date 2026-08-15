// Small formatting helpers — pure, unit-tested. Never fabricate data: an
// unformattable input returns a placeholder, not a guessed value.
export function formatDurationMs(ms) {
  if (typeof ms !== 'number' || !Number.isFinite(ms) || ms < 0) return '--:--';
  const totalSeconds = Math.floor(ms / 1000);
  const m = Math.floor(totalSeconds / 60);
  const s = totalSeconds % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

/** Human label for a Playwright project name. Falls back to the raw name
 * for anything not in this known set — never invents a label for an
 * unrecognized browser project. */
const BROWSER_LABELS = {
  'mobile-chromium': 'Chromium',
  'mobile-webkit': 'WebKit',
};
export function browserLabel(browser) {
  return BROWSER_LABELS[browser] ?? browser;
}

const STATUS_LABELS = {
  passed: '✅ PASS',
  failed: '❌ FAIL',
  skipped: '⏭ SKIP',
};
export function statusLabel(status) {
  return STATUS_LABELS[status] ?? status;
}

/** ActionTraceEntry.elapsedMs is a real measured value (ms since the test
 * started) — formatted here as mm:ss, never treated as a wall-clock
 * timestamp since none exists in the source data. */
export function formatElapsed(elapsedMs) {
  return formatDurationMs(elapsedMs);
}
