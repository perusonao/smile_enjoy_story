// Codex review on PR #10 (P2): "Exclude the future hire from March HUD
// totals". PrologueEngine.decideCandidate materializes a real Engineer the
// moment a March candidate accepts their offer — well before they actually
// join in April (PrologueEngine.enterAprilWeek1) — so nothing should be
// charged for them until then. The real month-end/payroll math already got
// this right (enterAprilWeek1's one lump March close deliberately excludes
// the new hire's own salary), but the *live* HUD/expense-breakdown forecast
// (FinanceEngine.monthlySalaryTotal and everything derived from it —
// projectedMonthlyBurn, expectedOutflowThisMonth, projectedMonthEndCash)
// didn't know that, and quietly overstated March's projected burn by one
// full salary for as long as the Prologue HUD is visible pre-join.
//
// Three cases, matching the request: before any offer is accepted, after
// acceptance but still in March (pre-join), and after the April join.
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'prologue_engine_test.dart' show playThroughPrologue;

void main() {
  group('FinanceEngine.monthlySalaryTotal is prologue-aware of the pre-join hire (Codex review, PR #10 P2)', () {
    test('March, before any candidate has accepted an offer: only the navigator counts', () {
      final state = PrologueEngine.newGame(seed: 5);
      expect(state.engineers, isEmpty);
      expect(state.prologueState.active, isTrue);
      expect(FinanceEngine.monthlySalaryTotal(state), state.generalAffairsStaff!.salary);
    });

    test('March, after the candidate accepts but before April Week 1: their salary is still excluded', () {
      GameState? afterAcceptance;
      final finalState = playThroughPrologue(
        5,
        onTick: (state) {
          afterAcceptance ??= state.engineers.isNotEmpty ? state : null;
        },
      );
      // Sanity: the playthrough actually reached April (case 3 below relies
      // on this same seed/flow), and did materialize the hire.
      expect(finalState.activeAssignments, isNotEmpty);
      expect(afterAcceptance, isNotNull);

      final state = afterAcceptance!;
      expect(state.prologueState.active, isTrue, reason: 'still mid-Prologue, not yet April');
      expect(state.activeAssignments, isEmpty, reason: 'enterAprilWeek1 has not run yet');
      expect(state.engineers, hasLength(1));

      final navigatorSalary = state.generalAffairsStaff!.salary;
      final hireSalary = state.engineers.first.salary;
      expect(hireSalary, greaterThan(0));

      expect(FinanceEngine.monthlySalaryTotal(state), navigatorSalary, reason: 'the not-yet-joined hire must not inflate the live forecast');
      expect(FinanceEngine.projectedMonthlyBurn(state), FinanceEngine.monthlySalaryTotal(state) + FinanceEngine.monthlyRent(state) + otherMonthlyFixedCost);
    });

    test('April Week 1, once enterAprilWeek1 has run: the new engineer counts normally', () {
      final state = playThroughPrologue(5);
      expect(state.activeAssignments, isNotEmpty);
      expect(state.engineers, hasLength(1));
      // prologueState.active is still true here — it only flips once the
      // player taps "経営を始める" (PrologueEngine.completePrologue) — the
      // gate must key off `activeAssignments`, not `prologueState.active`
      // alone, or a genuinely-joined April engineer would be wrongly
      // excluded too.
      expect(state.prologueState.active, isTrue);

      final navigatorSalary = state.generalAffairsStaff!.salary;
      final hireSalary = state.engineers.first.salary;
      expect(FinanceEngine.monthlySalaryTotal(state), navigatorSalary + hireSalary);
    });
  });
}
