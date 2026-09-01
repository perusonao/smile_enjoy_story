import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recovery.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';

/// RECOVERY-LOOP-1: month/terminal boundary matrix at the full
/// [PublicDemoAggregate] integration level (the pure eligibility-predicate
/// matrix already lives in public_demo_recovery_eligibility_test.dart) —
/// these prove [PublicDemoAggregate.recoverAssignment] itself refuses
/// outside the window and once terminal, using real month-close commands
/// rather than a hand-built [PublicDemoState].
void main() {
  group('before the Recovery window', () {
    for (final month in [4, 5, 6]) {
      test('recoverAssignment is a no-op at internal month $month', () {
        var aggregate = publicDemoAggregateAtMonth(month);
        aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
        final before = aggregate;

        final after = aggregate.recoverAssignment('eng-01');

        expect(after, same(before));
      });
    }
  });

  group('inside the Recovery window', () {
    for (final month in [7, 8, 9, 10, 11, 12, 13, 14]) {
      test('recoverAssignment succeeds at internal month $month', () {
        var aggregate = publicDemoAggregateAtMonth(month);
        aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');

        final after = aggregate.recoverAssignment('eng-01');

        expect(after.workflow.assignments, hasLength(1));
        expect(after.state.engineersAssigned, 1);
      });
    }
  });

  group('March / fiscal-year end', () {
    test('recoverAssignment is a no-op at internal month 15 (March)', () {
      var aggregate = publicDemoAggregateAtMonth(14);
      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 800000);
      expect(aggregate.state.month, 15);
      final before = aggregate;

      final after = aggregate.recoverAssignment('eng-01');

      expect(after, same(before));
    });

    test('recoverAssignment is a no-op once the fiscal year is completed', () {
      var aggregate = publicDemoAggregateAtMonth(14);
      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 800000);
      aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 800000);
      expect(aggregate.state.fiscalYearCompleted, isTrue);
      final before = aggregate;

      final after = aggregate.recoverAssignment('eng-01');

      expect(after, same(before));
    });
  });

  group('terminal financial status', () {
    test('recoverAssignment is a no-op once bankruptcy is reached, even '
        'while the internal month is otherwise inside the Recovery window', () {
      // Two consecutive negative closes (already in cashShortage on the
      // second) reach bankruptcy while state.month lands on 8 — squarely
      // inside Recovery's window, proving this is the terminal guard doing
      // the work, not the month guard.
      var aggregate = publicDemoAggregateAtMonth(
        7,
      ).closeJuly(monthlyExpenses: 800000); // month 7 -> 8, still normal
      expect(aggregate.state.financialStatus, PublicDemoFinancialStatus.normal);
      aggregate = aggregate.closeOrdinaryMonth(
        monthlyExpenses: 50000000,
      ); // month 8 -> 9, huge expense -> cashShortage
      expect(
        aggregate.state.financialStatus,
        PublicDemoFinancialStatus.cashShortage,
      );
      aggregate = aggregate.closeOrdinaryMonth(
        monthlyExpenses: 50000000,
      ); // month 9 -> 10, still negative while already cashShortage -> bankruptcy
      expect(
        aggregate.state.financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );
      expect(aggregate.state.isFinanciallyTerminal, isTrue);
      expect(
        PublicDemoRecoveryEligibility.isMonthEligible(aggregate.state.month),
        isTrue,
        reason:
            'the month itself is still inside the window — only the '
            'terminal status must block Recovery here',
      );

      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      final before = aggregate;
      final after = aggregate.recoverAssignment('eng-01');

      expect(after, same(before));
    });
  });
}
