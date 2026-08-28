import { test, expect } from '@playwright/test';
import { assertScrollWasEffective, type ScrollEffectEvidence } from '../helpers/artifacts';

// SES_WEBKIT-SCROLL-1 Phase 4.2. The guard is a pure function precisely so it
// can be tested without a browser or a full playthrough — the same reason
// `parseAriaSnapshot` was split out of `snapshotScreen` (see game-state.ts).
const evidence = (over: Partial<ScrollEffectEvidence> = {}): ScrollEffectEvidence => ({
  steps: 15,
  fingerprintChanged: false,
  wheelInvocations: 15,
  wheelMoved: 0,
  ...over,
});

test.describe('assertScrollWasEffective() — inert-scroll guard', () => {
  test('the exact SES_WEBKIT-SCROLL-1 failure shape throws: steps ran, nothing moved, snapshot never changed', () => {
    expect(() => assertScrollWasEffective(evidence(), 'scrolling to "面談へ進む"')).toThrow(/inert scroll/);
  });

  test('the thrown message names the context, so a CI log says which scroll broke', () => {
    expect(() => assertScrollWasEffective(evidence(), 'scrolling to "面談へ進む"')).toThrow(/面談へ進む/);
  });

  test('a scroll that changed the accessibility snapshot is never flagged', () => {
    expect(() => assertScrollWasEffective(evidence({ fingerprintChanged: true }), 'ctx')).not.toThrow();
  });

  test('a scroll where the fallback did move something is never flagged, even with an unchanged snapshot', () => {
    // Real case: the list scrolled but the target genuinely is not on this
    // screen. That is an ordinary "not found", not a harness defect.
    expect(() => assertScrollWasEffective(evidence({ wheelMoved: 3 }), 'ctx')).not.toThrow();
  });

  test("Chromium's native wheel path reports no measurements and is never flagged", () => {
    // wheelInvocations === 0 means the fallback never ran, so inertness
    // cannot be proven — the guard must stay silent rather than guess.
    expect(() => assertScrollWasEffective(evidence({ wheelInvocations: 0 }), 'ctx')).not.toThrow();
  });

  test('a loop that never attempted a scroll is never flagged', () => {
    expect(() => assertScrollWasEffective(evidence({ steps: 0, wheelInvocations: 0 }), 'ctx')).not.toThrow();
  });
});
