// Unit-level checks for the console-error allowlist's AND-conditions
// (Codex follow-up §11) — pure-function tests, no browser needed. Runs via
// the same `npx playwright test` command as everything else (no new
// dependency), Playwright's own TS transform handles this file like any
// other test.
import { test, expect } from '@playwright/test';
import { isFontMessageWithHost, isKnownFontHost, isKnownNetworkFailureCode } from '../helpers/artifacts';

test.describe('font allowlist conditions (never a single wide OR-regex)', () => {
  test('isKnownFontHost: fonts.gstatic.com is known', () => {
    expect(isKnownFontHost('https://fonts.gstatic.com/s/roboto/v32/foo.woff2')).toBe(true);
  });

  test('isKnownFontHost: an unrelated host is NOT known', () => {
    expect(isKnownFontHost('https://example.com/foo.woff2')).toBe(false);
    expect(isKnownFontHost('https://evil-fonts.gstatic.com.attacker.example/x')).toBe(false);
    expect(isKnownFontHost('not a url at all')).toBe(false);
  });

  test('isKnownNetworkFailureCode: recognizes known network-level codes', () => {
    expect(isKnownNetworkFailureCode('net::ERR_CONNECTION_RESET')).toBe(true);
    expect(isKnownNetworkFailureCode('net::ERR_NAME_NOT_RESOLVED')).toBe(true);
  });

  test('isKnownNetworkFailureCode: rejects an unrelated/app-level failure', () => {
    expect(isKnownNetworkFailureCode('net::ERR_BLOCKED_BY_CLIENT')).toBe(false);
    expect(isKnownNetworkFailureCode('some generic Flutter error')).toBe(false);
  });

  test('isFontMessageWithHost: known font-fetch message shape + known host → allowlisted', () => {
    expect(isFontMessageWithHost('[warning] Failed to load font Roboto at https://fonts.gstatic.com/s/roboto/v32/foo.woff2')).toBe(true);
    expect(
      isFontMessageWithHost(
        '[warning] Flutter Web engine failed to complete HTTP request to fetch "https://fonts.gstatic.com/s/notosanssc/v37/foo.woff2": TypeError: Failed to fetch',
      ),
    ).toBe(true);
  });

  test('isFontMessageWithHost: same message shape against an unrelated host → NOT allowlisted', () => {
    expect(isFontMessageWithHost('[warning] Failed to load font Roboto at https://evil.example/foo.woff2')).toBe(false);
  });

  test('isFontMessageWithHost: a generic Flutter error is NOT allowlisted', () => {
    expect(isFontMessageWithHost('[error] TypeError: Cannot read properties of null (reading \'a\')')).toBe(false);
  });

  test('isFontMessageWithHost: a bare resource-load failure (no URL in text) is NOT allowlisted by text alone', () => {
    // This exact shape carries no host info — watchForErrors only
    // allowlists it via requestfailed correlation, never from this text.
    expect(isFontMessageWithHost('[error] Failed to load resource: net::ERR_CONNECTION_RESET')).toBe(false);
  });
});
