// Pure filtering logic for the card list — kept separate from app.js's DOM
// wiring so it's directly unit-testable.
export function filterTests(tests, { browser = 'all', status = 'all' } = {}) {
  return (tests ?? []).filter((t) => {
    if (browser !== 'all' && t.browser !== browser) return false;
    if (status !== 'all' && t.status !== status) return false;
    return true;
  });
}

/** Distinct browser project names present in the manifest, in first-seen
 * order — drives the dynamically-built browser filter buttons instead of
 * hardcoding "mobile-chromium"/"mobile-webkit". */
export function distinctBrowsers(tests) {
  const seen = [];
  for (const t of tests ?? []) {
    if (t && typeof t.browser === 'string' && !seen.includes(t.browser)) seen.push(t.browser);
  }
  return seen;
}
