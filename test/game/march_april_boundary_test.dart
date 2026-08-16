// Playable 0.4C.2 Phase 2: March week 4 -> April week 1 accounting
// correctness (docs/DEVELOPMENT_PLAN.md Phase 2). Locks in the boundary
// conditions the audit found:
//
//  - March week 4's one-time PrologueEngine.enterAprilWeek1 lump sum charges
//    exactly rent + otherMonthlyFixedCost + the navigator's salary — never
//    the not-yet-joined hire's own salary (that invariant was already
//    covered by finance_engine_prologue_test.dart's HUD-side assertions;
//    Test A/B here lock in the *actual cash* side of the same invariant).
//  - Once real payroll starts (the hire's first ordinary month-end after
//    joining), both the live HUD forecast and the actual settlement include
//    their salary consistently (Test C).
//  - FinanceEngine.projectedMonthEndCash (the HUD's "月末予想現金") must
//    always equal the cash GameEngine.advanceWeek's month-end close actually
//    produces (Test D) — this is the specific bug this phase fixes: a
//    recruitment-media listing's cost was being deducted from cash twice
//    (once immediately at posting, once again at month-end close), which
//    made the HUD forecast one thing and the real settlement land on
//    another. Test E locks in the single-charge fix directly.
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'prologue_engine_test.dart' show playThroughPrologue;
import 'test_helpers.dart';

GameState _emptyState({int seed = 7}) {
  final base = GameEngine.newGame(seed: seed);
  return base.copyWith(
    engineers: const [],
    activeAssignments: const [],
    applicants: const [],
    openProjects: const [],
    listings: const [],
    proposals: const [],
    pendingHires: const [],
  );
}

void main() {
  group('Test A/B: March week 4 close (PrologueEngine.enterAprilWeek1)', () {
    test('charges exactly rent + otherMonthlyFixedCost + navigator salary, and never the not-yet-joined hire', () {
      GameState? beforeJoin;
      final state = playThroughPrologue(5, onTick: (s) {
        beforeJoin ??= s.engineers.isNotEmpty ? s : null;
      });
      expect(state.activeAssignments, isNotEmpty, reason: 'sanity: this seed reaches April Week 1');
      expect(beforeJoin, isNotNull);

      final cashBefore = beforeJoin!.company.cash;
      final cashAfter = state.company.cash;
      final rent = FinanceEngine.monthlyRent(state);
      final navigatorSalary = state.generalAffairsStaff!.salary;
      final hireSalary = state.engineers.first.salary;
      expect(hireSalary, greaterThan(0), reason: 'sanity: the hire really does have a salary');

      // Test A: the lump sum is exactly rent + fixed cost + navigator salary.
      expect(cashBefore - cashAfter, rent + otherMonthlyFixedCost + navigatorSalary);

      // Test B: the not-yet-joined hire's own salary is not part of it —
      // i.e. the lump sum is strictly smaller than "everyone's salary".
      expect(cashBefore - cashAfter, lessThan(rent + otherMonthlyFixedCost + navigatorSalary + hireSalary));
    });
  });

  group('Test C: payroll boundary — before vs. after the hire actually joins', () {
    test('once April Week 1 has run, the next ordinary month-end pays the hire\'s salary and the live HUD forecast agrees', () {
      var state = playThroughPrologue(5);
      expect(state.activeAssignments, isNotEmpty);
      final hireSalary = state.engineers.first.salary;
      final navigatorSalary = state.generalAffairsStaff!.salary;

      // Live forecast, taken right after joining (still week 1 of the real
      // calendar): both the navigator and the now-joined hire are payroll.
      expect(FinanceEngine.monthlySalaryTotal(state), navigatorSalary + hireSalary);

      // Advance to April's own month-end (real week 4) and confirm the
      // actual settlement agrees with that forecast.
      for (var i = 0; i < 3; i++) {
        state = GameEngine.advanceWeek(state);
      }
      final closing = state.latestClosing!;
      expect(closing.salaryPaid, navigatorSalary + hireSalary);
    });
  });

  group('Test D/E: HUD forecast must equal the real month-end settlement', () {
    test('projectedMonthEndCash matches the actual cash produced by the month-end close, with no active assignments', () {
      final engineer = buildEngineer(id: 'e1', salary: 400000, status: EngineerStatus.waiting);
      var state = _emptyState().copyWith(
        engineers: [engineer],
        generalAffairsStaff: const GeneralAffairsStaff(id: 'ga-1', name: 'テスト総務', salary: 280000, flavor: ''),
      );

      final forecast = FinanceEngine.projectedMonthEndCash(state);
      for (var i = 0; i < 3; i++) {
        state = GameEngine.advanceWeek(state);
      }
      expect(state.company.cash, forecast);
    });

    test('a posted recruitment listing is charged exactly once, and the HUD forecast matches the real settlement', () {
      var state = _emptyState();
      final cashAtPosting = state.company.cash;
      state = GameEngine.postRecruitmentMedia(state, RecruitmentMediaType.engineerCareer);
      final mediaCost = recruitmentMediaConfigs[RecruitmentMediaType.engineerCareer]!.cost;
      expect(state.company.cash, cashAtPosting - mediaCost, reason: 'cash drops immediately when the listing is posted');

      final forecast = FinanceEngine.projectedMonthEndCash(state);
      for (var i = 0; i < 3; i++) {
        state = GameEngine.advanceWeek(state);
      }
      final rent = FinanceEngine.monthlyRent(state);

      // The single, correct charge: starting cash minus the listing cost
      // (paid once, at posting) minus rent and the fixed cost (paid once,
      // at month-end) — never a second deduction of mediaCost.
      expect(state.company.cash, cashAtPosting - mediaCost - rent - otherMonthlyFixedCost);
      expect(state.latestClosing!.recruitmentCost, mediaCost);
      // The live HUD forecast (taken right after posting, before month-end)
      // must have predicted this same ending cash.
      expect(state.company.cash, forecast);
    });

    test('March recruitment spend does not leak into April\'s own month-end recruitmentCost line', () {
      GameState? rightAfterPosting;
      final joined = playThroughPrologue(
        9,
        mediaType: RecruitmentMediaType.engineerCareer,
        onTick: (s) {
          rightAfterPosting ??= s.pendingMiscExpense > 0 ? s : null;
        },
      );
      expect(rightAfterPosting, isNotNull, reason: 'sanity: the paid March listing did accrue a recruitment-cost line');
      expect(joined.activeAssignments, isNotEmpty);
      expect(joined.pendingMiscExpense, 0, reason: 'March\'s recruitment cost is fully settled at the March->April boundary, not carried into April\'s books');

      var next = joined;
      for (var i = 0; i < 3; i++) {
        next = GameEngine.advanceWeek(next);
      }
      expect(next.latestClosing!.recruitmentCost, 0);
    });
  });

  group('Issue #12 P1: March recruitment expense is preserved in cumulative accounting', () {
    test('a paid March recruitment medium is recognized exactly once in GameStats.cumulativeRecruitmentCost, at the March->April boundary', () {
      final mediaCost = recruitmentMediaConfigs[RecruitmentMediaType.engineerCareer]!.cost;

      GameState? rightBeforeJoining;
      final joined = playThroughPrologue(
        9,
        mediaType: RecruitmentMediaType.engineerCareer,
        onTick: (s) {
          rightBeforeJoining ??= s.pendingMiscExpense > 0 ? s : null;
        },
      );
      expect(rightBeforeJoining, isNotNull, reason: 'sanity: the paid March listing did accrue a recruitment-cost line');

      // Before enterAprilWeek1 clears pendingMiscExpense, nothing has yet
      // folded it into cumulative accounting.
      expect(rightBeforeJoining!.stats.cumulativeRecruitmentCost, 0);

      // enterAprilWeek1 fired (contract secured) — the March expense must
      // now be preserved in cumulative recruitment accounting / annual
      // profit, even though March never runs through GameEngine.advanceWeek's
      // own month-end close.
      expect(joined.stats.cumulativeRecruitmentCost, mediaCost);

      // March's rent/navigator-salary/other-fixed-cost lump sum
      // (marchFixedCost) must be preserved the same way, not just the
      // recruitment line — otherwise annual profit still doesn't reconcile
      // with March's real founding costs (user follow-up on Issue #12).
      final rent = FinanceEngine.monthlyRent(joined);
      final navigatorSalary = joined.generalAffairsStaff!.salary;
      final marchFixedCost = rent + otherMonthlyFixedCost + navigatorSalary;
      expect(joined.stats.cumulativeRent, rent);
      expect(joined.stats.cumulativeSalary, navigatorSalary);
      expect(joined.stats.cumulativeFixedCost, otherMonthlyFixedCost);
      expect(
        joined.stats.cumulativeProfit,
        -(mediaCost + marchFixedCost),
        reason: 'no revenue has been recognized yet, so cumulative profit is exactly the negative of every March cost recognized so far (recruitment + rent + navigator salary + other fixed cost)',
      );

      // Cash was deducted exactly once, at posting time — enterAprilWeek1
      // must not deduct it again.
      final cashRightBeforeJoining = rightBeforeJoining!.company.cash;
      expect(joined.company.cash, cashRightBeforeJoining - marchFixedCost);

      // April's first real month-end close must measure its own cash
      // movement from the cash balance right after March's lump-sum close,
      // not from the game's starting cash (which would misattribute all of
      // March's spend to April) — Issue #12 P2 follow-up.
      expect(joined.monthStartCash, joined.company.cash);

      // April's own month-end must not count the March expense a second
      // time, in either cash or cumulative accounting.
      var next = joined;
      for (var i = 0; i < 3; i++) {
        next = GameEngine.advanceWeek(next);
      }
      expect(next.latestClosing!.recruitmentCost, 0);
      expect(next.stats.cumulativeRecruitmentCost, mediaCost);
      expect(next.stats.cumulativeRent, rent * 2, reason: 'March + April');
      // April's own close pays the navigator AND the now-joined hire — only
      // March's contribution is navigator-only.
      final hireSalary = next.engineers.first.salary;
      expect(next.stats.cumulativeSalary, navigatorSalary * 2 + hireSalary, reason: 'March (navigator only) + April (navigator + the joined hire)');
      expect(next.stats.cumulativeFixedCost, otherMonthlyFixedCost * 2, reason: 'March + April');

      // The whole-month cash movement invariant must hold for April's own
      // close too, measured from the March-close cash baseline.
      final closing = next.latestClosing!;
      expect(closing.cashAfter - closing.cashBefore, closing.monthCashMovement);
      expect(closing.cashBefore, joined.company.cash);
    });
  });
}
