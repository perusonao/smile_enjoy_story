// SES-FULL-YEAR-E2E-PHASE1 — Public Demo annual baseline.
//
// Phase 1 goal: establish a maintainable, CURRENT-behavior baseline
// answering "can the currently implemented Public Demo traverse its
// intended annual lifecycle (April through March) without an unintended
// dead end?" — BEFORE the Late-Year Recovery Loop exists. This describes
// what the game actually does today; it does not assert any future
// feature (Late-Year Recovery Loop, Jul-Feb waiting-engineer re-sales,
// enhanced year-end results, future Sep-Feb management events, a future
// HOME redesign — none of those exist in `main` yet).
//
// Current Annual Route (see docs/reports/SES_FULL-YEAR_E2E_Phase1_Result.md
// for the full investigation): of the two founding engineers, only 佐藤 健
// (eng-01, April `actualCapability` 78) clears
// `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement` (60) in
// April — 鈴木 葵 (eng-02, capability 52) cannot begin field sales at all
// this fiscal year (the founding engineers' sales-stage buttons render only
// in their April join month; see `public_demo_01_placeholder_screen.dart`'s
// own comment on `readyForFieldSales`). That caps this fiscal year's
// revenue capacity at one assigned engineer (¥500,000/month) against fixed
// monthly costs of ¥800,000 (two founding salaries + admin + fixed costs) —
// so the smallest legitimate current route (sell eng-01, confirm his July
// contract continuation in June, decline the summer bonus, then close every
// ordinary month) genuinely reaches March and completes the fiscal year's
// final close, but that close currently resolves to BANKRUPTCY, not
// success. That is a real, deterministic, current fact this baseline
// records — not a false "success" and not a falsified route.
import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';
import {
  openPublicDemo,
  assertFreshStartInvariants,
  assertCalendarMonth,
  snapshot,
  sellFoundingEngineerInApril,
  confirmJulyContinuation,
  decideNoSummerBonus,
  closeMonthlyPrimaryCta,
  readCashSummaryLine,
  isFinanciallyTerminal,
} from '../helpers/public-demo-player';

const VIEWPORTS = [
  { label: '360x800', width: 360, height: 800 },
  { label: '390x800', width: 390, height: 800 },
];

for (const viewport of VIEWPORTS) {
  test.describe(`Public Demo annual baseline at ${viewport.label}`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test(`April: the only fiscal-year-sellable founding engineer reaches an order (${viewport.label})`, async ({
      page,
    }) => {
      const errors = watchForErrors(page);

      await openPublicDemo(page);
      await assertFreshStartInvariants(page);
      await assertCalendarMonth(page, 4);

      await sellFoundingEngineerInApril(page);

      const snap = await snapshot(page);
      expect(snap, '佐藤 健 must reach the ordered sales stage in April').toContain(
        '翌月参画予定',
      );
      expect(snap, 'the still-locked founding engineer must stay waiting').toContain(
        '営業開始には実力 60 以上が必要です（現在 52）。',
      );

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
      expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);
    });

    test(`June: confirming July contract continuation starts revenue recognition (${viewport.label})`, async ({
      page,
    }) => {
      const errors = watchForErrors(page);

      await openPublicDemo(page);
      await assertFreshStartInvariants(page);
      await assertCalendarMonth(page, 4);
      await sellFoundingEngineerInApril(page);

      await closeMonthlyPrimaryCta(page); // April -> May
      await assertCalendarMonth(page, 5);
      await closeMonthlyPrimaryCta(page); // May -> June
      await assertCalendarMonth(page, 6);

      await confirmJulyContinuation(page);

      const snap = await snapshot(page);
      expect(snap, 'May close must recognize eng-01 assignment revenue').toContain('売上 ¥500,000');

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
      expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);
    });

    test(`April-March: the current annual route traverses every month to the fiscal year's terminal close (${viewport.label})`, async ({
      page,
    }) => {
      test.setTimeout(180_000);
      const errors = watchForErrors(page);

      await test.step('April: open and sell eng-01', async () => {
        await openPublicDemo(page);
        await assertFreshStartInvariants(page);
        await assertCalendarMonth(page, 4);
        await sellFoundingEngineerInApril(page);
      });

      await test.step('April -> May', async () => {
        await closeMonthlyPrimaryCta(page);
        await assertCalendarMonth(page, 5);
      });

      await test.step('May -> June', async () => {
        await closeMonthlyPrimaryCta(page);
        await assertCalendarMonth(page, 6);
      });

      await test.step('June: confirm July contract continuation', async () => {
        await confirmJulyContinuation(page);
      });

      await test.step('June -> July', async () => {
        await closeMonthlyPrimaryCta(page);
        await assertCalendarMonth(page, 7);
      });

      await test.step('July: decide no summer bonus', async () => {
        await decideNoSummerBonus(page);
      });

      await test.step('July -> August', async () => {
        await closeMonthlyPrimaryCta(page);
        await assertCalendarMonth(page, 8);
      });

      // August through February close identically (`closeOrdinaryMonth`) —
      // one shared loop, but each iteration is still its own `test.step` so
      // a failure names the exact month/calendar-label it happened at.
      const ordinaryMonths = [9, 10, 11, 12, 1, 2, 3];
      for (const calendarMonth of ordinaryMonths) {
        await test.step(`-> ${calendarMonth}月`, async () => {
          await closeMonthlyPrimaryCta(page);
          await assertCalendarMonth(page, calendarMonth);
        });
      }

      const beforeMarchClose = await readCashSummaryLine(page);

      await test.step('March: close the fiscal year', async () => {
        await closeMonthlyPrimaryCta(page);
      });

      // CURRENT BEHAVIOR, not a future-feature assertion: this route's cash
      // position never recovers, so March's close resolves to bankruptcy —
      // see this file's header doc and the Phase 1 result report. A future
      // Late-Year Recovery Loop changing this outcome is exactly what
      // Phase 2 should re-run this same baseline against.
      const terminal = await isFinanciallyTerminal(page);
      expect(
        terminal,
        `current annual route must reach the fiscal year's terminal close (cash before March close: ${beforeMarchClose})`,
      ).toBe(true);

      const finalSnap = await snapshot(page);
      expect(finalSnap, 'terminal card must record bankruptcy at March').toContain(
        '最終決算月: 3月',
      );
      expect(finalSnap, 'the reset control must remain available after the terminal close').toContain(
        '4月からやり直す',
      );

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
      expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);
    });
  });
}
