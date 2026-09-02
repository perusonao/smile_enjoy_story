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
  hireAndRunAppOnePreEntryPipeline,
  confirmSatoJulyContinuationOnly,
  runWaitingEngineerSalesPipelineToOrdered,
  recoverAssignment,
  appOneCard,
  confirmJulyContinuation,
  decideNoSummerBonus,
  closeMonthlyPrimaryCta,
  readCashSummaryLine,
  isFinanciallyTerminal,
  scrollToText,
  readCompactKpiValue,
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
      test.setTimeout(240_000);
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

    // RECOVERY-LOOP-1 — Gameplay Complete Route B.
    //
    // The test above (Route A) is this file's own CURRENT BEHAVIOR baseline:
    // one billable founding engineer's revenue can never cover two founding
    // salaries + fixed costs, so even the smallest legitimate route reaches
    // BANKRUPTCY at March's close. Route B below starts from that exact same
    // early poor outcome (eng-02 permanently field-sales-locked — see
    // public_demo_01_suzuki_sales_lock_test.dart) and proves the Late-Year
    // Recovery Loop, once used, changes the fiscal year's outcome: hiring
    // app-01 in May but deliberately leaving them economically waiting
    // through June (an early setback — the July continuation this playthrough
    // is missing a second billable engineer to spread costs over is real, not
    // staged), then Recovering them in July, survives every ordinary month
    // through March WITHOUT bankruptcy — the same fiscal year that, without
    // that one Recovery decision, is Route A's bankruptcy above. Training is
    // deliberately never touched in this route (RECOVERY-LOOP-1's own
    // instruction: "TrainingをRoute Bに混ぜない") — every month's action here
    // is either a sales-pipeline step or a monthly close, nothing else.
    test(`Route B — Gameplay Complete: an early poor outcome (only eng-01 sellable) is turned into a solvent fiscal-year completion by Recovering app-01 in July (${viewport.label})`, async ({
      page,
    }) => {
      test.setTimeout(240_000);
      const errors = watchForErrors(page);

      await test.step('April: the same early poor outcome as Route A — only eng-01 is sellable', async () => {
        await openPublicDemo(page);
        await assertFreshStartInvariants(page);
        await assertCalendarMonth(page, 4);
        await sellFoundingEngineerInApril(page);
      });

      await test.step('April -> May', async () => {
        await closeMonthlyPrimaryCta(page);
        await assertCalendarMonth(page, 5);
      });

      await test.step('May: hire app-01 through the full pre-entry sales pipeline — not yet a fix, just this fiscal year\'s second hire', async () => {
        await hireAndRunAppOnePreEntryPipeline(page);
      });

      await test.step('May -> June', async () => {
        await closeMonthlyPrimaryCta(page);
        await assertCalendarMonth(page, 6);
      });

      await test.step('June: confirm eng-01\'s July continuation; leave app-01\'s own May-era assignment undecided, so they stay economically waiting entering July', async () => {
        await confirmSatoJulyContinuationOnly(page);
      });

      await test.step('June -> July', async () => {
        await closeMonthlyPrimaryCta(page);
        await assertCalendarMonth(page, 7);
      });

      await test.step('July: the Recovery decision — app-01 redoes the sales pipeline and is Recovered into an assignment', async () => {
        const snap = await snapshot(page);
        expect(snap, 'app-01 must still be waiting entering July').toContain('待機');
        await runWaitingEngineerSalesPipelineToOrdered(page, appOneCard(page));
        await recoverAssignment(page);
        // SES-FIRST-FUN-YEAR-UI-PHASE-1 removed July recap's own duplicate
        // 参画/待機 headcount line — read the always-visible compact KPI
        // tile (the surviving authoritative source) instead of a snapshot
        // substring match against the now-removed text.
        expect(await readCompactKpiValue(page, '参画'), 'both eng-01 and app-01 are now assigned').toBe(
          '2名',
        );
      });

      await test.step('July: decide no summer bonus', async () => {
        await decideNoSummerBonus(page);
      });

      await test.step('July -> August', async () => {
        await closeMonthlyPrimaryCta(page);
        await assertCalendarMonth(page, 8);
      });

      // August through February close identically, exactly like Route A's
      // own loop — no Recovery/training action recurs; this is purely
      // whether the ONE July decision above is enough to hold for the rest
      // of the fiscal year.
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

      // THE PROOF: the same early poor outcome Route A cannot recover from
      // reaches March WITHOUT bankruptcy once Recovery is used — one real
      // decision in July changes the fiscal year's outcome, not the
      // underlying economics themselves (Finance production code is
      // untouched; see e2e helper additions' own doc comments).
      const terminal = await isFinanciallyTerminal(page);
      expect(
        terminal,
        `Route B must NOT reach the terminal close Route A does (cash before March close: ${beforeMarchClose})`,
      ).toBe(false);

      // `scrollToText` (not a bare `snapshot()`): the fiscal-year-complete
      // card can render below whatever Flutter Web's accessibility tree
      // currently has built right after a close — the same reachability
      // fact `findMonthlyPrimaryCta`/`readCompactKpiValue` already account
      // for, not a sign the card is actually missing.
      const finalSnap = await scrollToText(page, '第1期終了');
      expect(finalSnap, 'no bankruptcy card once Recovery has been used').not.toContain(
        '倒産',
      );

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
      expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);
    });
  });
}
