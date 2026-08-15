// Parses SES_E2E_SEEDS (Codex review on PR #3, item 1). Kept as a small,
// independently-testable pure function rather than inline in the spec file
// — the bug it fixes was exactly the inline `filter((n) => Number.isFinite(n))`
// silently dropping every invalid entry, which for an all-invalid or
// all-empty env value left an empty seed array. That registered zero
// `Founding First Assignment` tests, so the scenario workflow could report
// green without ever exercising its primary scenario.

export interface ParsedSeeds {
  /** Empty exactly when `error` is set. */
  seeds: number[];
  /** Non-null means: env var was set, but no valid seed list could be
   * derived from it — callers must surface this as a real failure, never
   * as "zero tests, nothing to run". */
  error: string | null;
}

/** `envValue === undefined` (the env var isn't set at all) is the only case
 * that falls back to `defaultSeeds` — every other input must yield at
 * least one seed or an explicit `error`. In particular: a value that is
 * set but entirely empty/whitespace/commas (e.g. `""`, `",,,"`), or that
 * contains *any* non-numeric entry (e.g. `"abc"`, `"100001,abc"`), is
 * rejected outright rather than silently filtered down to whatever valid
 * entries happen to remain — a typo in one seed of a list should fail
 * loudly, not quietly run a shorter list. */
export function parseSeeds(envValue: string | undefined, defaultSeeds: number[]): ParsedSeeds {
  if (envValue === undefined) {
    return { seeds: defaultSeeds, error: null };
  }

  const entries = envValue
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  if (entries.length === 0) {
    return { seeds: [], error: `SES_E2E_SEEDS is set but contains no seed values: ${JSON.stringify(envValue)}` };
  }

  const seeds: number[] = [];
  const invalid: string[] = [];
  for (const entry of entries) {
    const n = Number(entry);
    if (Number.isFinite(n)) {
      seeds.push(n);
    } else {
      invalid.push(entry);
    }
  }

  if (invalid.length > 0) {
    return {
      seeds: [],
      error: `SES_E2E_SEEDS contains invalid (non-numeric) seed value(s): ${invalid.map((e) => JSON.stringify(e)).join(', ')} (full value: ${JSON.stringify(envValue)})`,
    };
  }

  return { seeds, error: null };
}
