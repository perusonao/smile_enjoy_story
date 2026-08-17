// Phase 3A UX review (P1-3): "応募者がが見つかりません"-style doubled-particle
// text and empty-state phrasing. Investigation (this session) found no
// reproducible doubled-particle string across the founding flow, a forced
// recruitment rejection, or Beginner Mode's own dialogs/cards — this spec
// keeps that verified-clean baseline as a permanent regression guard rather
// than a one-off manual check, and also locks in the companion fix: the
// interview/judgment screens' transient "not found" flash (a real, if
// narrow, UX rough edge grouped with this finding — see
// prologue_interview_screen.dart / recruitment_interview_screen.dart /
// client_interview_screen.dart) now reads as a loading state, not an error.
import { test, expect } from '@playwright/test';
import { playFoundingToFirstAssignment } from '../helpers/ses-player';
import { findDoubledParticles, hasText } from '../helpers/game-state';
import { watchForErrors } from '../helpers/artifacts';

test('no doubled-particle text and no alarming "not found" flash through founding + a forced rejection', async ({ page }) => {
  test.setTimeout(5 * 60 * 1000);
  const errors = watchForErrors(page);
  const offenders: string[] = [];
  const notFoundFlashes: string[] = [];

  await page.goto('/?e2e=1&seed=300001');
  const result = await playFoundingToFirstAssignment(page, {
    maxWeeks: 12,
    maxActions: 100,
    idleTimeoutMs: 30_000,
    stallRepeatThreshold: 5,
    // Exercises the recruitment-interview decision path this finding
    // specifically called out ("判定/応募者画面").
    forceRejectFirstCandidate: true,
    onScreen: async (_screen, snap) => {
      offenders.push(...findDoubledParticles(snap));
      // P1-3 companion fix: these three screens' "not found" states are
      // transient-by-construction (see the source comments), so the old
      // alarming error text must never appear again.
      if (hasText(snap, '応募者が見つかりません') || hasText(snap, '案件が見つかりません')) {
        notFoundFlashes.push(JSON.stringify(snap.texts));
      }
    },
  });

  expect(result.stallDetected, `dead-end/stall: ${result.stallReason}`).toBe(false);
  expect(result.completed, 'did not reach first assignment').toBe(true);
  expect(errors.pageErrors).toEqual([]);
  expect(errors.consoleErrors).toEqual([]);
  expect(offenders, `doubled-particle text observed: ${JSON.stringify(offenders)}`).toEqual([]);
  expect(notFoundFlashes, `alarming "not found" text should now be a loading spinner instead`).toEqual([]);
});
