// RECOVERY-LOOP-1 — focused E2E spec for the late-year (internal month 7-14)
// waiting-engineer re-entry loop added on top of SES-FULL-YEAR-E2E-PHASE1's
// annual baseline (public-demo-annual-route.spec.ts). This drives the real
// production UI end to end — no Dart domain state is ever mutated directly
// — through `e2e/helpers/public-demo-player.ts`'s own extended helpers
// (`hireAndRunAppOnePreEntryPipeline`, `runWaitingEngineerSalesPipelineToOrdered`,
// `recoverAssignment`, `isCashShortage`), reusing every existing #138
// navigation/actionable helper (`openPublicDemo`, `closeMonthlyPrimaryCta`,
// `assertCalendarMonth`, `clickButton`'s dialog handling, ...) rather than a
// second, separate automation layer.
//
// app-01 (高橋 翔) is this suite's canonical Recovery target (RECOVERY-LOOP-1
// E2E design): app-02 (田中 美咲, interviewScore 58) fails recruitment's own
// >=60 interview gate and can never be offered, and eng-02 (鈴木 葵,
// capability 52) is permanently locked out of field sales for the whole
// fiscal year (public_demo_01_suzuki_sales_lock_test.dart) — app-01 is the
// only hire that can ever reach the `waiting` + `ordered` + Recovery-eligible
// state this loop exists for.
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
  decideNoSummerBonus,
  closeMonthlyPrimaryCta,
  isCashShortage,
  isFinanciallyTerminal,
  readCompactKpiValue,
  scrollToText,
} from '../helpers/public-demo-player';

const VIEWPORTS = [
  { label: '360x800', width: 360, height: 800 },
  { label: '390x800', width: 390, height: 800 },
];

for (const viewport of VIEWPORTS) {
  test.describe(`Public Demo Recovery loop at ${viewport.label}`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test(`app-01 walks waiting -> SkillSheet -> 営業開始 -> 案件紹介 -> interviews -> ordered -> 案件へ復帰 -> assigned, and revenue/AR/collection follow the normal causal chain (${viewport.label})`, async ({
      page,
    }) => {
      test.setTimeout(180_000);
      const errors = watchForErrors(page);

      await test.step('April: sell eng-01 (healthy baseline revenue)', async () => {
        await openPublicDemo(page);
        await assertFreshStartInvariants(page);
        await assertCalendarMonth(page, 4);
        await sellFoundingEngineerInApril(page);
        await closeMonthlyPrimaryCta(page); // April -> May
        await assertCalendarMonth(page, 5);
      });

      await test.step('May: hire app-01 through the full pre-entry sales pipeline (they join and are picked up by assignOrderedForMay, same as any other June hire)', async () => {
        await hireAndRunAppOnePreEntryPipeline(page);
        await closeMonthlyPrimaryCta(page); // May -> June
        await assertCalendarMonth(page, 6);
      });

      await test.step('June: accept eng-01\'s July continuation; leave app-01\'s own May-era assignment undecided, so they are NOT counted assigned entering July (economically waiting)', async () => {
        await confirmSatoJulyContinuationOnly(page);
        await closeMonthlyPrimaryCta(page); // June -> July
        await assertCalendarMonth(page, 7);
      });

      await test.step('July: app-01 (still waiting) redoes the SkillSheet -> 営業開始 -> 案件紹介 -> interviews -> 受注 pipeline', async () => {
        const snapBefore = await snapshot(page);
        expect(
          snapBefore,
          '案件へ復帰 must not render before app-01 reaches `ordered`',
        ).not.toContain('案件へ復帰');
        await runWaitingEngineerSalesPipelineToOrdered(page, appOneCard(page));
      });

      const cashBeforeRecovery = await readCompactKpiValue(page, '現金');
      expect(cashBeforeRecovery, '現金 KPI must be on screen before recovering').toBeDefined();
      await test.step('案件へ復帰 commits the assignment (waiting -> assigned) without moving cash immediately', async () => {
        // `scrollToText` (not a bare `snapshot()`): the order-result dialog
        // `受注` just closed can leave the accessibility tree only built
        // near wherever that dialog was, not necessarily still covering
        // this exact card the instant it reappears.
        await scrollToText(page, '案件へ復帰');
        await recoverAssignment(page);
        const snapAfter = await snapshot(page);
        expect(snapAfter, '案件へ復帰 must disappear once app-01 is assigned').not.toContain(
          '案件へ復帰',
        );
        expect(
          await readCompactKpiValue(page, '現金'),
          'recoverAssignment touches no Finance field — cash must be unchanged the instant it commits',
        ).toBe(cashBeforeRecovery);
        // assigned/waiting delta: the compact KPI updates immediately,
        // before any month close.
        // eng-02 (permanently field-sales-locked — see
        // public_demo_01_suzuki_sales_lock_test.dart) always remains
        // waiting regardless of app-01's own outcome, so 参画=2/待機=1 here
        // (eng-01 + app-01 assigned, eng-02 alone still waiting), not 0名.
        expect(await readCompactKpiValue(page, '参画'), 'ASSIGNMENT RESULT').toBe('2名');
        expect(await readCompactKpiValue(page, '待機'), 'ASSIGNMENT RESULT').toBe('1名');
      });

      await test.step('closing July recognizes BOTH engineers\' combined revenue as AR (pending), not cash', async () => {
        await decideNoSummerBonus(page);
        await closeMonthlyPrimaryCta(page); // July -> August
        await assertCalendarMonth(page, 8);
        // Read from PublicDemoMonthlyCashFlowCard's own labelled rows (exact
        // yen, not the compact KPI's ¥-in-万 rounding) — `scrollToText`
        // scrolls to find each one, since a virtualized `ListView` does not
        // keep this card built once enough content (Recovery's own
        // per-engineer cards included) exists above it on the page.
        // (HOME UI Phase 1 removed the finance-summary card's own duplicate
        // 今月売上/次回入金予定 rows — the monthly cash-flow card's 売上/
        // 売掛金 rows are the same authoritative figures, unduplicated.)
        // Both engineers' combined ¥500,000/each revenue this close.
        await scrollToText(page, '売上 ¥1,000,000');
        // The same amount is booked as AR, awaiting next month's
        // collection — not cash.
        await scrollToText(page, '売掛金（来月入金予定） ¥1,000,000');
      });

      await test.step('closing August collects that AR into cash (the 30-day contract)', async () => {
        await closeMonthlyPrimaryCta(page); // August -> September
        await assertCalendarMonth(page, 9);
        // PublicDemoMonthlyCashFlowCard's own `入金` row is August's close
        // actually receiving July's ¥1,000,000 AR in cash — the collection
        // leg of the causal chain, read from production's own accounting
        // record rather than a hand-derived final-cash figure.
        await scrollToText(page, '入金 +¥1,000,000');
      });

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
      expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);
    });

    test(`CRITICAL ACCEPTANCE GATE: Recovery's own sales pipeline (営業開始 -> 案件紹介 -> 面談 -> 受注 -> 案件へ復帰) is not blocked by cashShortage / isFinanciallyRestricted (${viewport.label})`, async ({
      page,
    }) => {
      test.setTimeout(300_000);
      const errors = watchForErrors(page);

      // eng-01 IS sold here (unlike an earlier version of this scenario) —
      // once their own July continuation is confirmed they collapse into a
      // compact "継続予定" text line rather than staying a full multi-button
      // waiting-engineer card for the rest of the fiscal year (see
      // `hireAndRunAppOnePreEntryPipeline`'s own doc for why a full card
      // that never changes for many consecutive months is avoided here).
      // app-01 (hired but never Recovered) is the sole deficit source: one
      // idle salaried hire's cost against eng-01's lone ¥500,000/month
      // revenue is still a genuine, deterministic structural deficit (no
      // RNG anywhere in Public Demo's finance) — reaching real cashShortage
      // from real production economics, not an artificially forced one.
      await test.step('drive to a real, non-terminal cashShortage with app-01 the only unproductive hire', async () => {
        await openPublicDemo(page);
        await assertFreshStartInvariants(page);
        await assertCalendarMonth(page, 4);
        await sellFoundingEngineerInApril(page);
        await closeMonthlyPrimaryCta(page); // April -> May
        await assertCalendarMonth(page, 5);
        await hireAndRunAppOnePreEntryPipeline(page);
        await closeMonthlyPrimaryCta(page); // May -> June
        await assertCalendarMonth(page, 6);
        // Confirm eng-01's own July continuation only; app-01's own
        // May-era assignment (from assignOrderedForMay) is deliberately
        // left undecided, so they alone stay economically waiting.
        await confirmSatoJulyContinuationOnly(page);
        await closeMonthlyPrimaryCta(page); // June -> July
        await assertCalendarMonth(page, 7);

        let month = 7;
        while (!(await isCashShortage(page))) {
          expect(
            month,
            'must reach cashShortage inside the Recovery window (month <= 14), ' +
              'not by exhausting it — a failure here is a scenario-setup ' +
              'problem, not evidence about the gate itself',
          ).toBeLessThan(14);
          // July's close specifically requires the summer bonus decision
          // first (`_monthlyPrimaryAction`'s own July description) — every
          // other month in this loop closes directly.
          if (month === 7) await decideNoSummerBonus(page);
          await closeMonthlyPrimaryCta(page);
          month += 1;
          await assertCalendarMonth(page, month);
        }
        expect(await isCashShortage(page)).toBe(true);
        expect(
          await isFinanciallyTerminal(page),
          'this must be the cashShortage WARNING state, not bankruptcy — ' +
            'the gate is about restriction, not a terminal playthrough',
        ).toBe(false);
      });

      // eng-02 (permanently field-sales-locked) remains genuinely `待機`
      // for the rest of this test regardless of app-01's own outcome, so
      // the ASSIGNMENT RESULT proof below is a delta against this captured
      // baseline, not a claim that nobody at all remains waiting.
      const assignedBefore = await readCompactKpiValue(page, '参画');
      const waitingBefore = await readCompactKpiValue(page, '待機');
      expect(waitingBefore, 'app-01 must still be economically waiting').not.toBe('0名');

      await test.step('the entire sales pipeline runs to completion while cashShortage holds', async () => {
        expect(await isCashShortage(page)).toBe(true);
        await runWaitingEngineerSalesPipelineToOrdered(page, appOneCard(page));
        expect(
          await isCashShortage(page),
          'still restricted — this proves the pipeline above ran under ' +
            'the restriction, not before/after it',
        ).toBe(true);
        await scrollToText(page, '案件へ復帰');
      });

      await test.step('案件へ復帰 itself commits waiting -> assigned while still restricted', async () => {
        await recoverAssignment(page);
        expect(await isCashShortage(page)).toBe(true);
        const snap = await snapshot(page);
        expect(snap, 'the button is gone once assigned').not.toContain('案件へ復帰');
        // ASSIGNMENT RESULT — RECOVERY DEAD TURN would leave these counts
        // unchanged from the baseline captured above; this is the gate's
        // actual pass condition.
        expect(await readCompactKpiValue(page, '参画')).not.toBe(assignedBefore);
        expect(await readCompactKpiValue(page, '待機')).not.toBe(waitingBefore);
      });

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
      expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);
    });
  });
}
