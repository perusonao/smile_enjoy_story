// Boundary coverage for parseSeeds() (Codex review on PR #3, item 1):
// SES_E2E_SEEDS must never silently resolve to an empty, "everything
// filtered out" seed list — that previously let founding-first-assignment.spec.ts
// register zero scenario tests and pass green without running anything.
import { test, expect } from '@playwright/test';
import { parseSeeds } from '../helpers/seeds';

const DEFAULTS = [100001, 100002, 100003];

test.describe('parseSeeds()', () => {
  test('unset env var -> falls back to the provided defaults', () => {
    const result = parseSeeds(undefined, DEFAULTS);
    expect(result).toEqual({ seeds: DEFAULTS, error: null });
  });

  test('a valid comma-separated list -> parsed, in order, no error', () => {
    const result = parseSeeds('100001,100002,100003', DEFAULTS);
    expect(result).toEqual({ seeds: [100001, 100002, 100003], error: null });
  });

  test('whitespace around entries is trimmed', () => {
    const result = parseSeeds(' 100001 , 100002 ', DEFAULTS);
    expect(result).toEqual({ seeds: [100001, 100002], error: null });
  });

  test('a single valid seed -> a one-element list', () => {
    const result = parseSeeds('42', DEFAULTS);
    expect(result).toEqual({ seeds: [42], error: null });
  });

  test('SES_E2E_SEEDS=abc (single invalid entry) -> error, not an empty silent success', () => {
    const result = parseSeeds('abc', DEFAULTS);
    expect(result.seeds).toEqual([]);
    expect(result.error).not.toBeNull();
  });

  test('SES_E2E_SEEDS=,,, (empty after filtering) -> error, not an empty silent success', () => {
    const result = parseSeeds(',,,', DEFAULTS);
    expect(result.seeds).toEqual([]);
    expect(result.error).not.toBeNull();
  });

  test('SES_E2E_SEEDS="" (empty string) -> falls back to defaults, same as unset', () => {
    // CI (.github/workflows/e2e.yml) sets SES_E2E_SEEDS: ${{ github.event.inputs.seeds }}
    // unconditionally, which is a present-but-empty string on every normal
    // `pull_request` run — must behave exactly like "not specified", or
    // every ordinary PR run fails immediately.
    const result = parseSeeds('', DEFAULTS);
    expect(result).toEqual({ seeds: DEFAULTS, error: null });
  });

  test('SES_E2E_SEEDS=whitespace-only -> falls back to defaults, same as unset', () => {
    const result = parseSeeds('   ', DEFAULTS);
    expect(result).toEqual({ seeds: DEFAULTS, error: null });
  });

  test('SES_E2E_SEEDS=abc,xyz (all invalid) -> error', () => {
    const result = parseSeeds('abc,xyz', DEFAULTS);
    expect(result.seeds).toEqual([]);
    expect(result.error).not.toBeNull();
  });

  test('a mixed valid+invalid list -> error for the WHOLE input, not silently reduced to the valid entries', () => {
    const result = parseSeeds('100001,abc', DEFAULTS);
    expect(result.seeds).toEqual([]);
    expect(result.error).not.toBeNull();
    // The exact bug this guards: a naive `.filter(Number.isFinite)` would
    // have quietly returned [100001] here instead of failing.
    expect(result.seeds).not.toEqual([100001]);
  });

  test('error messages name the invalid entries', () => {
    const result = parseSeeds('100001,abc,xyz', DEFAULTS);
    expect(result.error).toContain('abc');
    expect(result.error).toContain('xyz');
  });
});
