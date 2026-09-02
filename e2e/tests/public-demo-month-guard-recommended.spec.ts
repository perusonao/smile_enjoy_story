// Issue #119 (PUBLIC-DEMO-MONTH-GUARD-1A) remaining scope, PLAYTHROUGH-
// BLOCKER-1: before this change, `closeOrdinaryMonth` (August through
// March) had no Month Guard check of any kind — a player could close any
// of those months with important, already-legal, already-on-screen work
// left untouched, with no warning at all. This spec drives the real
// production UI (no Dart domain state mutated directly) to prove the
// canonical monthly CTA now warns before doing that, using the same
// helpers `public-demo-recovery.spec.ts` already established:
//
//  * an outstanding action (here: eng-01's own late-year Recovery step,
//    left genuinely un-decided in June exactly as
//    `confirmJulyContinuation`'s own doc describes as "a legitimate
//    current route") produces a warning naming it, and does not close the
//    month until the player decides;
//  * "タスクを確認" cancels the close — the month stays put, and the named
//    action (「案件へ復帰」) is directly reachable and completable right
//    there, no dead end;
//  * "このまま月末処理を進める" proceeds anyway — a recommended item, unlike
//    a required one (Issue #119 PR1's July summer-bonus decision), can
//    always be bypassed.
import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';
import {
  openPublicDemo,
  assertFreshStartInvariants,
  assertCalendarMonth,
  sellFoundingEngineerInApril,
  runWaitingEngineerSalesPipelineToOrdered,
  recoverAssignment,
  decideNoSummerBonus,
  closeMonthlyPrimaryCta,
  findMonthlyPrimaryCta,
  scrollToText,
} from '../helpers/public-demo-player';

const VIEWPORTS = [{ label: '360x800', width: 360, height: 800 }];

for (const viewport of VIEWPORTS) {
  test.describe(`Public Demo Month Guard recommended-level warning at ${viewport.label}`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test(`August close warns about eng-01's outstanding Recovery step, "タスクを確認" leaves it reachable, and "このまま月末処理を進める" proceeds anyway (${viewport.label})`, async ({
      page,
    }) => {
      test.setTimeout(180_000);
      const errors = watchForErrors(page);

      await test.step('April: sell eng-01', async () => {
        await openPublicDemo(page);
        await assertFreshStartInvariants(page);
        await assertCalendarMonth(page, 4);
        await sellFoundingEngineerInApril(page);
        await closeMonthlyPrimaryCta(page); // April -> May
        await assertCalendarMonth(page, 5);
      });

      await test.step('May, June: no hire, and deliberately never decide eng-01\'s July continuation — the same genuinely-waiting route confirmJulyContinuation\'s own doc describes', async () => {
        await closeMonthlyPrimaryCta(page); // May -> June
        await assertCalendarMonth(page, 6);
        await closeMonthlyPrimaryCta(page); // June -> July
        await assertCalendarMonth(page, 7);
      });

      await test.step('July: eng-01 (still waiting) redoes the sales pipeline to `ordered`, but is NOT recovered before July closes — the outstanding action carries into August', async () => {
        await runWaitingEngineerSalesPipelineToOrdered(page);
        await decideNoSummerBonus(page);
        await closeMonthlyPrimaryCta(page); // July -> August (no Month Guard on July itself — PR1's required-only gate is unaffected)
        await assertCalendarMonth(page, 8);
      });

      await test.step('August: tapping the canonical CTA opens the recommended-level warning instead of closing the month', async () => {
        const cta = await findMonthlyPrimaryCta(page);
        await cta.click();
        const dialog = page.getByRole('alertdialog');
        await expect(dialog).toBeVisible({ timeout: 15_000 });
        expect(await dialog.ariaSnapshot()).toContain('案件へ復帰させる');
        await assertCalendarMonth(page, 8);
      });

      await test.step('"タスクを確認" cancels the close, and 案件へ復帰 is directly reachable and completable', async () => {
        const dialog = page.getByRole('alertdialog');
        await dialog.getByRole('button', { name: 'タスクを確認', exact: true }).click();
        await expect(dialog).toBeHidden();
        await assertCalendarMonth(page, 8);

        await scrollToText(page, '案件へ復帰');
        await recoverAssignment(page);
      });

      await test.step('August now closes cleanly (nothing outstanding), and the CTA is still the single canonical control', async () => {
        await closeMonthlyPrimaryCta(page); // August -> September
        await assertCalendarMonth(page, 9);
      });

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    });

    test(`"このまま月末処理を進める" proceeds past the warning and closes the month anyway (${viewport.label})`, async ({
      page,
    }) => {
      test.setTimeout(180_000);
      const errors = watchForErrors(page);

      await openPublicDemo(page);
      await assertFreshStartInvariants(page);
      await sellFoundingEngineerInApril(page);
      await closeMonthlyPrimaryCta(page); // April -> May
      await closeMonthlyPrimaryCta(page); // May -> June
      await closeMonthlyPrimaryCta(page); // June -> July (eng-01's July continuation deliberately never decided)
      await runWaitingEngineerSalesPipelineToOrdered(page);
      await decideNoSummerBonus(page);
      await closeMonthlyPrimaryCta(page); // July -> August
      await assertCalendarMonth(page, 8);

      const cta = await findMonthlyPrimaryCta(page);
      await cta.click();
      const dialog = page.getByRole('alertdialog');
      await expect(dialog).toBeVisible({ timeout: 15_000 });
      await dialog
        .getByRole('button', { name: 'このまま月末処理を進める', exact: true })
        .click();
      await expect(dialog).toBeHidden();
      await assertCalendarMonth(page, 9);

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    });
  });
}
