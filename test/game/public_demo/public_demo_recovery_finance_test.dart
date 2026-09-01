import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_revenue.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';

/// RECOVERY-LOOP-1: Finance invariants around
/// [PublicDemoAggregate.recoverAssignment]. No Finance formula is changed
/// by this feature — these tests exist to prove the EXISTING revenue-
/// recognition/AR/30-day-collection contract already picks up a Recovered
/// engineer correctly once [PublicDemoState.engineersAssigned] reflects
/// them, with no bespoke Recovery-only Finance path.
void main() {
  test('Recovery itself does not inject cash: cash is unchanged immediately '
      'after recoverAssignment', () {
    var aggregate = publicDemoAggregateAtMonth(8);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    final cashBefore = aggregate.state.cash;
    final pendingBefore = aggregate.state.pendingRevenue;

    aggregate = aggregate.recoverAssignment('eng-01');

    expect(aggregate.state.cash, cashBefore);
    expect(
      aggregate.state.pendingRevenue,
      pendingBefore,
      reason:
          'Recovery must not recognize revenue itself either — only '
          'the existing month-end close does that',
    );
  });

  test('the next month-end close recognizes revenue (AR) for the Recovered '
      'engineer using the unchanged existing formula', () {
    var aggregate = publicDemoAggregateAtMonth(8);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    aggregate = aggregate.recoverAssignment('eng-01');
    expect(aggregate.state.engineersAssigned, 1);

    aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 800000);

    expect(
      aggregate.state.pendingRevenue,
      PublicDemoRevenue.monthlyRevenueForAssignedCount(1),
      reason:
          'the existing PublicDemoRevenue formula, applied to the '
          're-projected engineersAssigned count, must book the Recovered '
          'engineer\'s revenue as pending AR — not as immediate cash',
    );
  });

  test('cash collection follows the existing 30-day timing: the Recovered '
      'engineer\'s revenue only reaches cash at the CLOSE AFTER the one '
      'that recognized it', () {
    var aggregate = publicDemoAggregateAtMonth(8);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    aggregate = aggregate.recoverAssignment('eng-01');

    // August close: recognizes revenue as pending AR, collects nothing new
    // from the Recovered engineer yet (last month had no such assignment).
    final beforeAugustClose = aggregate;
    aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 800000);
    final pendingAfterAugust = aggregate.state.pendingRevenue;
    expect(pendingAfterAugust, greaterThan(0));
    expect(
      aggregate.state.cash,
      beforeAugustClose.state.cash -
          800000 +
          0, // no prior AR existed to collect this close
    );

    // September close: collects August's pending AR into cash.
    final cashBeforeSeptember = aggregate.state.cash;
    aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 800000);

    expect(
      aggregate.state.cash,
      cashBeforeSeptember - 800000 + pendingAfterAugust,
      reason:
          'the 30-day collection contract is untouched: last month\'s '
          'pending revenue becomes this month\'s cash inflow',
    );
  });

  test('existing non-Recovery revenue behavior for founding assignments is '
      'unaffected by Recovery existing on the same class', () {
    // No engineer is ever Recovered here — this is a pure regression
    // sanity check that PublicDemoRevenue itself is untouched.
    expect(PublicDemoRevenue.monthlyRevenueForAssignedCount(2), 1000000);
    expect(PublicDemoRevenue.ratePerAssignedEngineer, 500000);
  });
}
