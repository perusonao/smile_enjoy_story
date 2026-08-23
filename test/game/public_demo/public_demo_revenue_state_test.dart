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
