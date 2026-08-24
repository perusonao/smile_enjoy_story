import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_internal_training_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_cash_flow.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// FINANCE-UX-1: proves [PublicDemoMonthlyClose] records an accurate,
/// non-recomputed [PublicDemoMonthlyCashFlow] on [PublicDemoState] for every
/// month it actually closes — the SSOT the UI's monthly summary card reads
/// from. These tests never recompute salary/revenue math themselves; they
/// only assert the recorded summary agrees with the state transition that
/// produced it (already covered field-by-field by
/// public_demo_monthly_close_test.dart / public_demo_monthly_close_revenue_test.dart).
void main() {
  /// Minimal, fully-controlled fixture mirroring
  /// public_demo_monthly_close_revenue_test.dart's own helper, extended with
  /// the FINANCE-UX-1 bookkeeping fields a real month-in-progress would have
  /// accumulated before this close runs.
  PublicDemoState fixture({
    int month = 4,
    required int cash,
    required int pendingRevenue,
    required int engineersAssigned,
    int? monthOpeningCash,
    int monthTrainingSpent = 0,
    int monthRecruitmentSpent = 0,
    PublicDemoSummerBonusPlan summerBonusSelection =
        PublicDemoSummerBonusPlan.none,
    bool fiscalYearCompleted = false,
  }) => PublicDemoState(
    month: month,
    cash: cash,
    engineerCount: engineersAssigned + 2,
    adminCount: 1,
    salesCapacity: 4,
    salesUsed: 0,
    engineersWaiting: 0,
    engineersAssigned: engineersAssigned,
    pendingRevenue: pendingRevenue,
    summerBonusSelection: summerBonusSelection,
    monthOpeningCash: monthOpeningCash ?? cash,
    monthTrainingSpent: monthTrainingSpent,
    monthRecruitmentSpent: monthRecruitmentSpent,
    fiscalYearCompleted: fiscalYearCompleted,
  );

  group('1. core accounting contract', () {
    test('openingCash + cashReceived - outflows == closingCash (April)', () {
      // cash must reflect monthOpeningCash minus the mid-month training/
      // recruitment spend already accumulated, exactly as a real
      // playthrough would leave it — that relationship is the whole
      // reason those two accumulators exist.
      final start = fixture(
        month: 4,
        cash: 1000000 - 30000 - 100000,
        monthOpeningCash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 1,
        monthTrainingSpent: 30000,
        monthRecruitmentSpent: 100000,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 800000,
        orderedEngineers: 0,
      );
      final flow = result.state.latestMonthlyCashFlow!;
      expect(
        flow.openingCash +
            flow.cashReceived -
            flow.salaryPaid -
            flow.fixedCostsPaid -
            flow.bonusPaid -
            flow.trainingCost -
            flow.recruitmentCost,
        flow.closingCash,
      );
      expect(flow.closingCash, result.state.cash);
    });

    test('holds across an ordinary month (August) too', () {
      final start = fixture(
        month: 8,
        cash: 2000000,
        pendingRevenue: 500000,
        engineersAssigned: 2,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      final flow = result.state.latestMonthlyCashFlow!;
      expect(
        flow.openingCash + flow.cashReceived - flow.totalOutflow,
        flow.closingCash,
      );
    });
  });

  group('2. revenue recognized is not confused with cash received', () {
    test(
      'this month\'s newly recognized revenue is not this month\'s cash',
      () {
        final start = fixture(
          month: 4,
          cash: 1000000,
          pendingRevenue: 0,
          engineersAssigned: 2,
        );
        final result = PublicDemoMonthlyClose.closeApril(
          state: start,
          monthlyExpenses: 800000,
          orderedEngineers: 0,
        );
        final flow = result.state.latestMonthlyCashFlow!;
        expect(flow.revenue, 1000000);
        expect(flow.cashReceived, 0);
        expect(flow.revenue, isNot(flow.cashReceived));
      },
    );
  });

  group('3. previous pendingRevenue becomes this month\'s cashReceived', () {
    test('exact amount, no recomputation', () {
      final start = fixture(
        month: 5,
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 0,
      );
      final result = PublicDemoMonthlyClose.closeMay(
        state: start,
        workflow: PublicDemoWorkflowState.initial(),
        monthlyExpenses: 800000,
        acceptedHires: 0,
        hiredWithOrders: 0,
      );
      expect(result.state.latestMonthlyCashFlow!.cashReceived, 500000);
    });
  });

  group('4. current month revenue becomes next receivable', () {
    test('receivables mirrors the freshly recognized revenue', () {
      final start = fixture(
        month: 6,
        cash: 1000000,
        pendingRevenue: 0,
        engineersAssigned: 3,
      );
      final result = PublicDemoMonthlyClose.closeJune(
        state: start,
        monthlyExpenses: 800000,
        assignedInJuly: 3,
      );
      final flow = result.state.latestMonthlyCashFlow!;
      expect(flow.revenue, 1500000);
      expect(flow.receivables, 1500000);
      expect(result.state.pendingRevenue, flow.receivables);
    });
  });

  group('5. salary and fixed costs are reflected in cash outflow (FIX1)', () {
    test(
      'salaryPaid excludes otherMonthlyFixedCost; fixedCostsPaid carries it',
      () {
        final start = fixture(
          month: 8,
          cash: 2000000,
          pendingRevenue: 0,
          engineersAssigned: 0,
        );
        final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
          state: start,
          monthlyExpenses: 800000,
        );
        final flow = result.state.latestMonthlyCashFlow!;
        // 2. salaryPaid must not have the fixed cost mixed in.
        expect(
          flow.salaryPaid,
          800000 - PublicDemoSalary.otherMonthlyFixedCost,
        );
        expect(flow.salaryPaid, isNot(800000));
        // 3. the fixed cost itself must not disappear from the summary.
        expect(flow.fixedCostsPaid, PublicDemoSalary.otherMonthlyFixedCost);
        // 4. together they still account for the whole cash outflow.
        expect(flow.salaryPaid + flow.fixedCostsPaid, 800000);
        expect(flow.closingCash, start.cash - 800000);
        expect(flow.totalOutflow, 800000);
      },
    );

    test('the April->May regression from the P2 finding', () {
      // The exact figures from the PR #62 review comment: baseline monthly
      // expenses of ¥800,000 split into ¥750,000 salary + ¥50,000 fixed
      // cost, with April's opening cash of ¥3,000,000 closing at
      // ¥2,200,000.
      final start = fixture(
        month: 4,
        cash: 3000000,
        pendingRevenue: 0,
        engineersAssigned: 0,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        orderedEngineers: 0,
      );
      final flow = result.state.latestMonthlyCashFlow!;
      expect(flow.openingCash, 3000000);
      expect(flow.cashReceived, 0);
      expect(flow.salaryPaid, 750000);
      expect(flow.fixedCostsPaid, 50000);
      expect(flow.closingCash, 2200000);
      expect(result.state.cash, 2200000);
    });
  });

  group('6. bonus month (July) display', () {
    test('bonusPaid is recorded separately from salaryPaid', () {
      final start = fixture(
        month: 7,
        cash: 5000000,
        pendingRevenue: 0,
        engineersAssigned: 0,
        summerBonusSelection: PublicDemoSummerBonusPlan.one,
      );
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      final flow = result.state.latestMonthlyCashFlow!;
      expect(flow.salaryPaid, 800000 - PublicDemoSalary.otherMonthlyFixedCost);
      expect(flow.fixedCostsPaid, PublicDemoSalary.otherMonthlyFixedCost);
      expect(flow.bonusPaid, greaterThan(0));
      expect(
        flow.totalOutflow,
        flow.salaryPaid + flow.fixedCostsPaid + flow.bonusPaid,
      );
    });

    test('bonusPaid is 0 when the plan is none', () {
      final start = fixture(
        month: 7,
        cash: 5000000,
        pendingRevenue: 0,
        engineersAssigned: 0,
      );
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(result.state.latestMonthlyCashFlow!.bonusPaid, 0);
    });
  });

  group('7. training/recruitment costs included in the summary', () {
    test('actual charged amounts flow through, not recomputed', () {
      var state = fixture(
        month: 8,
        cash: 2000000,
        pendingRevenue: 0,
        engineersAssigned: 0,
      );
      final trainingResult = const PublicDemoInternalTrainingTransaction()
          .execute(
            state: state,
            engineerId: 'eng-01',
            assignedEngineerIds: const {},
          );
      expect(trainingResult.isSuccess, isTrue);
      state = trainingResult.state;

      final recruitmentResult = PublicDemoAggregate.restore(
        state: state,
        workflow: PublicDemoWorkflowState.initial(),
      ).recruit(PublicDemoRecruitmentMedium.engineer);
      expect(recruitmentResult.isSuccess, isTrue);
      state = recruitmentResult.aggregate!.state;

      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: state,
        monthlyExpenses: 800000,
      );
      final flow = result.state.latestMonthlyCashFlow!;
      expect(flow.trainingCost, PublicDemoInternalTrainingTransaction.cost);
      expect(flow.recruitmentCost, PublicDemoRecruitmentMedium.engineer.cost);
      expect(
        flow.openingCash + flow.cashReceived - flow.totalOutflow,
        flow.closingCash,
      );
    });

    test('a new month resets the accumulators to 0', () {
      var state = fixture(
        month: 8,
        cash: 2000000,
        pendingRevenue: 0,
        engineersAssigned: 0,
      );
      state = const PublicDemoInternalTrainingTransaction()
          .execute(
            state: state,
            engineerId: 'eng-01',
            assignedEngineerIds: const {},
          )
          .state;
      expect(
        state.monthTrainingSpent,
        PublicDemoInternalTrainingTransaction.cost,
      );

      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: state,
        monthlyExpenses: 800000,
      );
      expect(result.state.monthTrainingSpent, 0);
      expect(result.state.monthRecruitmentSpent, 0);
    });
  });

  group('8. negative closing cash is displayed correctly', () {
    test('closingCash can go negative and the contract still holds', () {
      final start = fixture(
        month: 12,
        cash: 100000,
        pendingRevenue: 0,
        engineersAssigned: 0,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      final flow = result.state.latestMonthlyCashFlow!;
      expect(flow.closingCash, lessThan(0));
      expect(result.state.cash, flow.closingCash);
      expect(
        flow.openingCash + flow.cashReceived - flow.totalOutflow,
        flow.closingCash,
      );
    });
  });

  group('9. March close', () {
    test('records a cash flow under the same contract as any other month', () {
      final start = fixture(
        month: 15,
        cash: 500000,
        pendingRevenue: 300000,
        engineersAssigned: 1,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      expect(result.state.fiscalYearCompleted, isTrue);
      final flow = result.state.latestMonthlyCashFlow!;
      expect(flow.month, 15);
      expect(flow.cashReceived, 300000);
      expect(flow.salaryPaid, 800000 - PublicDemoSalary.otherMonthlyFixedCost);
      expect(flow.fixedCostsPaid, PublicDemoSalary.otherMonthlyFixedCost);
      expect(
        flow.openingCash + flow.cashReceived - flow.totalOutflow,
        flow.closingCash,
      );
    });
  });

  group('10. March pendingRevenue is maintained, not collected', () {
    test('March\'s own newly recognized revenue stays pending', () {
      final start = fixture(
        month: 15,
        cash: 500000,
        pendingRevenue: 300000,
        engineersAssigned: 2,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      final flow = result.state.latestMonthlyCashFlow!;
      expect(flow.revenue, 1000000);
      expect(flow.receivables, 1000000);
      expect(result.state.pendingRevenue, 1000000);
    });
  });

  group('11. monthly close idempotency', () {
    test('closing the same month twice does not double-count the summary', () {
      final start = fixture(
        month: 8,
        cash: 2000000,
        pendingRevenue: 500000,
        engineersAssigned: 1,
      );
      final first = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      final firstFlow = first.state.latestMonthlyCashFlow!;
      expect(firstFlow.month, 8);

      // A repeated call against the *same pre-close* state (e.g. a retried
      // command) is exactly what "double apply" would look like.
      final repeated = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      expect(repeated.state.latestMonthlyCashFlow!.month, 8);
      expect(repeated.state.cash, first.state.cash);

      // Calling it again on the *actual new* state (month 9 now) processes
      // September, not a duplicate August — the real production sequence.
      final next = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: first.state,
        monthlyExpenses: 800000,
      );
      expect(next.state.latestMonthlyCashFlow!.month, 9);
      expect(next.state.latestMonthlyCashFlow!.month, isNot(firstFlow.month));
    });
  });

  group('12. fiscalYearCompleted guard regression', () {
    test(
      'closeOrdinaryMonth after completion does not re-record a summary',
      () {
        final completed = fixture(
          month: 15,
          cash: -100000,
          pendingRevenue: 0,
          engineersAssigned: 0,
          fiscalYearCompleted: true,
        );
        final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
          state: completed,
          monthlyExpenses: 800000,
        );
        expect(result.state.cash, completed.cash);
        expect(result.state.latestMonthlyCashFlow, isNull);
      },
    );
  });

  group('13. save compatibility', () {
    test('latestMonthlyCashFlow round trips through JSON', () {
      final start = fixture(
        month: 4,
        cash: 1000000,
        pendingRevenue: 0,
        engineersAssigned: 1,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 800000,
        orderedEngineers: 0,
      );
      final loaded = PublicDemoState.fromJson(result.state.toJson());
      expect(
        loaded.latestMonthlyCashFlow!.toJson(),
        result.state.latestMonthlyCashFlow!.toJson(),
      );
      expect(loaded.monthOpeningCash, result.state.monthOpeningCash);
      expect(loaded.monthTrainingSpent, result.state.monthTrainingSpent);
      expect(loaded.monthRecruitmentSpent, result.state.monthRecruitmentSpent);
    });

    test('an old save with none of the new keys loads without error', () {
      final old = PublicDemoState.aprilStart().toJson()
        ..remove('monthOpeningCash')
        ..remove('monthTrainingSpent')
        ..remove('monthRecruitmentSpent')
        ..remove('latestMonthlyCashFlow');
      final loaded = PublicDemoState.fromJson(old);
      expect(loaded.monthOpeningCash, loaded.cash);
      expect(loaded.monthTrainingSpent, 0);
      expect(loaded.monthRecruitmentSpent, 0);
      expect(loaded.latestMonthlyCashFlow, isNull);
    });
  });
}
