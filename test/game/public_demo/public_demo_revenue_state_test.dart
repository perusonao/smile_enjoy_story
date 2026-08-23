import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_revenue.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';

void main() {
  group('PublicDemoRevenue domain', () {
    test('defines the provisional per-assigned-engineer monthly rate', () {
      expect(PublicDemoRevenue.ratePerAssignedEngineer, 500000);
    });
  });

  group('PublicDemoRevenue.monthlyRevenueForAssignedCount', () {
    test('0 assigned engineers books no revenue', () {
      expect(PublicDemoRevenue.monthlyRevenueForAssignedCount(0), 0);
    });

    test('1 assigned engineer books the per-engineer rate', () {
      expect(PublicDemoRevenue.monthlyRevenueForAssignedCount(1), 500000);
    });

    test('2 assigned engineers books double the per-engineer rate', () {
      expect(PublicDemoRevenue.monthlyRevenueForAssignedCount(2), 1000000);
    });

    test('scales linearly with assigned count', () {
      for (final assignedCount in [3, 5, 10]) {
        expect(
          PublicDemoRevenue.monthlyRevenueForAssignedCount(assignedCount),
          assignedCount * PublicDemoRevenue.ratePerAssignedEngineer,
        );
      }
    });

    test('always multiplies by ratePerAssignedEngineer, not a copy of it', () {
      expect(PublicDemoRevenue.ratePerAssignedEngineer, 500000);
      expect(PublicDemoRevenue.monthlyRevenueForAssignedCount(4), 2000000);
    });

    test('negative assigned count is rejected', () {
      expect(
        () => PublicDemoRevenue.monthlyRevenueForAssignedCount(-1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('does not change PublicDemoState.cash', () {
      final state = PublicDemoState.aprilStart();
      PublicDemoRevenue.monthlyRevenueForAssignedCount(state.engineersAssigned);
      expect(state.cash, PublicDemoState.aprilStart().cash);
    });

    test('does not change PublicDemoState.pendingRevenue', () {
      final state = PublicDemoState.aprilStart();
      PublicDemoRevenue.monthlyRevenueForAssignedCount(state.engineersAssigned);
      expect(state.pendingRevenue, PublicDemoState.aprilStart().pendingRevenue);
    });

    test('counts only PublicDemoState.engineersAssigned, excluding waiting '
        'engineers from the same engineerCount', () {
      final state = PublicDemoState.aprilStart()
          .advanceToMay(monthlyExpenses: 0, orderedEngineers: 0)
          .advanceToJune(
            monthlyExpenses: 0,
            acceptedHires: 3,
            hiredWithOrders: 1,
          );
      expect(state.engineerCount, 5);
      expect(state.engineersAssigned, 1);
      expect(state.engineersWaiting, 4);
      expect(
        PublicDemoRevenue.monthlyRevenueForAssignedCount(
          state.engineersAssigned,
        ),
        500000,
      );
    });
  });

  group('PublicDemoState pendingRevenue', () {
    test('April starts with no pending revenue', () {
      expect(PublicDemoState.aprilStart().pendingRevenue, 0);
    });

    test('copyWith with no argument preserves pendingRevenue', () {
      final withRevenue = PublicDemoState.aprilStart().copyWith(
        pendingRevenue: 500000,
      );
      expect(withRevenue.copyWith().pendingRevenue, 500000);
    });

    test('copyWith can change pendingRevenue', () {
      final state = PublicDemoState.aprilStart().copyWith(
        pendingRevenue: 500000,
      );
      expect(state.pendingRevenue, 500000);
      expect(state.copyWith(pendingRevenue: 1000000).pendingRevenue, 1000000);
    });

    test('toJson/fromJson round trips a positive value', () {
      final state = PublicDemoState.aprilStart().copyWith(
        pendingRevenue: 750000,
      );
      expect(PublicDemoState.fromJson(state.toJson()).pendingRevenue, 750000);
    });

    test('old JSON missing the field normalizes to 0', () {
      final old = PublicDemoState.aprilStart().toJson()
        ..remove('pendingRevenue');
      expect(PublicDemoState.fromJson(old).pendingRevenue, 0);
    });

    test('wrong-type JSON values normalize to 0', () {
      for (final raw in ['500000', 500000.0, true, null, <String, int>{}]) {
        final malformed = PublicDemoState.aprilStart().toJson()
          ..['pendingRevenue'] = raw;
        expect(PublicDemoState.fromJson(malformed).pendingRevenue, 0);
      }
    });

    test('negative values normalize to 0, via constructor and JSON alike', () {
      expect(
        PublicDemoState.aprilStart()
            .copyWith(pendingRevenue: -1)
            .pendingRevenue,
        0,
      );
      final negative = PublicDemoState.aprilStart().toJson()
        ..['pendingRevenue'] = -500000;
      expect(PublicDemoState.fromJson(negative).pendingRevenue, 0);
    });

    test('a valid non-negative value is preserved as-is', () {
      expect(
        PublicDemoState.aprilStart().copyWith(pendingRevenue: 0).pendingRevenue,
        0,
      );
      expect(
        PublicDemoState.aprilStart()
            .copyWith(pendingRevenue: 500000)
            .pendingRevenue,
        500000,
      );
    });

    test('does not change cash', () {
      final before = PublicDemoState.aprilStart();
      final after = before.copyWith(pendingRevenue: 500000);
      expect(after.cash, before.cash);
    });

    test('does not change summer bonus fields', () {
      final before = PublicDemoState.aprilStart()
          .copyWith(month: 7)
          .selectSummerBonus(PublicDemoSummerBonusPlan.half);
      final after = before.copyWith(pendingRevenue: 500000);
      expect(after.summerBonusSelection, before.summerBonusSelection);
      expect(after.summerBonusPaid, before.summerBonusPaid);
      expect(after.summerBonusPaidMonth, before.summerBonusPaidMonth);
      expect(after.summerBonusPaidAmount, before.summerBonusPaidAmount);
    });

    test('does not change training selections', () {
      final before = PublicDemoState.aprilStart().copyWith(
        trainingSelections: const {
          'eng-01': PublicDemoGrowthSource.internalTraining,
        },
      );
      final after = before.copyWith(pendingRevenue: 500000);
      expect(after.trainingSelections, before.trainingSelections);
    });

    test('does not change recruitment media usage', () {
      final before = PublicDemoState.aprilStart().markRecruitmentMediaUsed(4);
      final after = before.copyWith(pendingRevenue: 500000);
      expect(
        after.recruitmentMediumUsedMonth,
        before.recruitmentMediumUsedMonth,
      );
    });
  });
}
