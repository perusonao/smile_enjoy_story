// RECOVERY-LOOP-1 — focused E2E spec for the late-year (internal month 7-14)
// waiting-engineer re-entry loop added on top of SES-FULL-YEAR-E2E-PHASE1's
// annual baseline (public-demo-annual-route.spec.ts). This drives the real
// production UI end to end — no Dart domain state is ever mutated directly
// — through `e2e/helpers/public-demo-player.ts`'s own extended helpers
// (`recruitAndRunSecondHirePreEntryPipeline`,
// `runWaitingEngineerSalesPipelineToOrdered`, `recoverAssignment`,
// `isCashShortage`), reusing every existing #138 navigation/actionable
// helper (`openPublicDemo`, `closeMonthlyPrimaryCta`, `assertCalendarMonth`,
// `clickButton`'s dialog handling, ...) rather than a second, separate
// automation layer.
//
// CORE-GAMEPLAY Phase 4.5 retired the fixed app-01 (高橋 翔)/app-02 (田中
// 美咲) founding-applicant pair this suite used to hire by name as its
// canonical Recovery target (`PublicDemoWorkflowState.initial()` no longer
// pre-seeds any applicant — recruiting is now a real player action on every
// playthrough). This suite's Recovery target is now whichever second hire
// `recruitAndRunSecondHirePreEntryPipeline` successfully recruits and runs
// through the full pre-entry pipeline; eng-02 (鈴木 葵, capability 52)
// remains permanently locked out of field sales for the whole fiscal year
// regardless (public_demo_01_suzuki_sales_lock_test.dart), so the generated
// second hire is still the only OTHER engineer that can ever reach the
// `waiting` + `ordered` + Recovery-eligible state this loop exists for.
import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';
import {
  openPublicDemo,
  assertFreshStartInvariants,
  assertCalendarMonth,
  snapshot,
  sellFoundingEngineerInApril,
  recruitAndRunSecondHirePreEntryPipeline,
  confirmSatoJulyContinuationOnly,
  runWaitingEngineerSalesPipelineToOrdered,
  recoverAssignment,
  namedPersonCard,
  decideNoSummerBonus,
  closeMonthlyPrimaryCta,
  isCashShortage,
  isFinanciallyTerminal,
  readCompactKpiValue,
  scrollToText,
  switchToTab,
} from '../helpers/public-demo-player';

const VIEWPORTS = [
  { label: '360x800', width: 360, height: 800 },
  { label: '390x800', width: 390, height: 800 },
];

for (const viewport of VIEWPORTS) {
  test.describe(`Public Demo Recovery loop at ${viewport.label}`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test(`a generated second hire walks waiting -> SkillSheet -> 営業開始 -> 案件紹介 -> interviews -> ordered -> 案件へ復帰 -> assigned, and revenue/AR/collection follow the normal causal chain (${viewport.label})`, async ({
      page,
    }) => {
      test.setTimeout(180_000);
      const errors = watchForErrors(page);
      let secondHireName = '';

      await test.step('April: sell eng-01 (healthy baseline revenue)', async () => {
        await openPublicDemo(page);
        await assertFreshStartInvariants(page);
        await assertCalendarMonth(page, 4);
        await sellFoundingEngineerInApril(page);
        await closeMonthlyPrimaryCta(page); // April -> May
        await assertCalendarMonth(page, 5);
      });

      await test.step('May: recruit and hire a second, generated engineer through the full pre-entry sales pipeline (they join and are picked up by assignOrderedForMay, same as any other June hire)', async () => {
        secondHireName = await recruitAndRunSecondHirePreEntryPipeline(page);
        await closeMonthlyPrimaryCta(page); // May -> June
        await assertCalendarMonth(page, 6);
      });

      await test.step('June: accept eng-01\'s July continuation; leave the second hire\'s own May-era assignment undecided, so they are NOT counted assigned entering July (economically waiting)', async () => {
        await confirmSatoJulyContinuationOnly(page);
        await closeMonthlyPrimaryCta(page); // June -> July
        await assertCalendarMonth(page, 7);
      });

      await test.step('July: the second hire (still waiting) redoes the SkillSheet -> 営業開始 -> 案件紹介 -> interviews -> 受注 pipeline', async () => {
        const snapBefore = await snapshot(page);
        expect(
          snapBefore,
          '案件へ復帰 must not render before the second hire reaches `ordered`',
        ).not.toContain('案件へ復帰');
        await runWaitingEngineerSalesPipelineToOrdered(
          page,
          namedPersonCard(page, secondHireName),
        );
      });

      const cashBeforeRecovery = await readCompactKpiValue(page, '現金');
      expect(cashBeforeRecovery, '現金 KPI must be on screen before recovering').toBeDefined();
      await test.step('案件へ復帰 commits the assignment (waiting -> assigned) without moving cash immediately', async () => {
        // `scrollToText` (not a bare `snapshot()`): the order-result dialog
        // `受注` just closed can leave the accessibility tree only built
        // near wherever that dialog was, not necessarily still covering
        // this exact card the instant it reappears. `案件へ復帰` is 社員-tab
        // (`ec(i)`) content — the preceding `readCompactKpiValue` call left
        // the page on ホーム.
        await switchToTab(page, '社員');
        await scrollToText(page, '案件へ復帰');
        await recoverAssignment(page);
        const snapAfter = await snapshot(page);
        expect(
          snapAfter,
          '案件へ復帰 must disappear once the second hire is assigned',
        ).not.toContain('案件へ復帰');
        expect(
          await readCompactKpiValue(page, '現金'),
          'recoverAssignment touches no Finance field — cash must be unchanged the instant it commits',
        ).toBe(cashBeforeRecovery);
        // assigned/waiting delta: the compact KPI updates immediately,
        // before any month close.
        // eng-02 (permanently field-sales-locked — see
        // public_demo_01_suzuki_sales_lock_test.dart) always remains
        // waiting regardless of the second hire's own outcome, so 参画=2/
        // 待機=1 here (eng-01 + the second hire assigned, eng-02 alone
        // still waiting), not 0名.
        expect(await readCompactKpiValue(page, '参画'), 'ASSIGNMENT RESULT').toBe('2名');
        expect(await readCompactKpiValue(page, '待機'), 'ASSIGNMENT RESULT').toBe('1名');
      });

      await test.step('closing July recognizes BOTH engineers\' combined revenue as AR (pending), not cash', async () => {
        await decideNoSummerBonus(page);
        await closeMonthlyPrimaryCta(page); // July -> August
        await assertCalendarMonth(page, 8);
        // Read from PublicDemoMonthlyCashFlowCard's own labelled rows
        // (exact yen, not the compact KPI's ¥-in-万 rounding) — the
        // authoritative source; SES-FIRST-FUN-YEAR-UI-PHASE-1 removed the
        // finance summary card's own duplicate 今月売上/次回入金予定 compact
        // display that used to carry this same fact under different
        // labels. `scrollToText` scrolls to find each one, since a
        // virtualized `ListView` does not keep this card built once enough
        // content (Recovery's own per-engineer cards included) exists
        // above it on the page. Both engineers' combined ¥500,000/each
        // revenue this close. `PublicDemoMonthlyCashFlowCard` is 会計-tab
        // content.
        await switchToTab(page, '会計');
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
        await switchToTab(page, '会計');
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
      let secondHireName = '';

      // eng-01 IS sold here (unlike an earlier version of this scenario) —
      // once their own July continuation is confirmed they collapse into a
      // compact "継続予定" text line rather than staying a full multi-button
      // waiting-engineer card for the rest of the fiscal year (see
      // `recruitAndRunSecondHirePreEntryPipeline`'s own doc for why a full
      // card that never changes for many consecutive months is avoided
      // here). The second hire (recruited but never Recovered) is the sole
      // deficit source: one idle salaried hire's cost against eng-01's lone
      // ¥500,000/month revenue is still a genuine, deterministic structural
      // deficit (no RNG anywhere in Public Demo's finance) — reaching real
      // cashShortage from real production economics, not an artificially
      // forced one.
      await test.step('drive to a real, non-terminal cashShortage with the second hire the only unproductive one', async () => {
        await openPublicDemo(page);
        await assertFreshStartInvariants(page);
        await assertCalendarMonth(page, 4);
        await sellFoundingEngineerInApril(page);
        await closeMonthlyPrimaryCta(page); // April -> May
        await assertCalendarMonth(page, 5);
        secondHireName = await recruitAndRunSecondHirePreEntryPipeline(page);
        await closeMonthlyPrimaryCta(page); // May -> June
        await assertCalendarMonth(page, 6);
        // Confirm eng-01's own July continuation only; the second hire's
        // own May-era assignment (from assignOrderedForMay) is deliberately
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
      // for the rest of this test regardless of the second hire's own
      // outcome, so the ASSIGNMENT RESULT proof below is a delta against
      // this captured baseline, not a claim that nobody at all remains
      // waiting.
      const assignedBefore = await readCompactKpiValue(page, '参画');
      const waitingBefore = await readCompactKpiValue(page, '待機');
      expect(waitingBefore, 'the second hire must still be economically waiting').not.toBe('0名');

      await test.step('the entire sales pipeline runs to completion while cashShortage holds', async () => {
        expect(await isCashShortage(page)).toBe(true);
        await runWaitingEngineerSalesPipelineToOrdered(
          page,
          namedPersonCard(page, secondHireName),
        );
        expect(
          await isCashShortage(page),
          'still restricted — this proves the pipeline above ran under ' +
            'the restriction, not before/after it',
        ).toBe(true);
        // `案件へ復帰` is 社員-tab content — the preceding `isCashShortage`
        // call left the page on ホーム.
        await switchToTab(page, '社員');
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
