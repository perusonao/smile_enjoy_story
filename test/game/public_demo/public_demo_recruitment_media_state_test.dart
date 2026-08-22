import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';

void main() {
  group('Public Demo recruitment media domain', () {
    test('defines free and engineer media costs and applicant counts', () {
      expect(PublicDemoRecruitmentMedium.free.cost, 0);
      expect(PublicDemoRecruitmentMedium.free.applicantCount, 1);
      expect(PublicDemoRecruitmentMedium.engineer.cost, 100000);
      expect(PublicDemoRecruitmentMedium.engineer.applicantCount, 2);
    });
  });

  group('PublicDemoState recruitment media usage', () {
    test('April starts unused and an unused valid month can be used', () {
      final state = PublicDemoState.aprilStart();
      expect(state.recruitmentMediumUsedMonth, isNull);
      expect(state.canUseRecruitmentMediaInMonth(4), isTrue);
    });

    test('marks once per month, safely ignores duplicate use, and resets next month', () {
      final used = PublicDemoState.aprilStart().markRecruitmentMediaUsed(4);
      expect(used.recruitmentMediumUsedMonth, 4);
      expect(used.canUseRecruitmentMediaInMonth(4), isFalse);
      expect(used.markRecruitmentMediaUsed(4), same(used));
      expect(used.canUseRecruitmentMediaInMonth(5), isTrue);
    });

    test('rejects invalid months without changing state', () {
      final state = PublicDemoState.aprilStart();
      for (final month in [0, -1, 3, 9]) {
        expect(state.canUseRecruitmentMediaInMonth(month), isFalse);
        expect(state.markRecruitmentMediaUsed(month), same(state));
      }
    });

    test('mark changes no cash, bonus, training, or growth state', () {
      final before = PublicDemoState.aprilStart()
          .selectSummerBonus(PublicDemoSummerBonusPlan.half)
          .copyWith(
            growthAppliedMonths: const [4],
            trainingSelections: const {
              'eng-01': PublicDemoGrowthSource.internalTraining,
            },
          );
      final after = before.markRecruitmentMediaUsed(4);
      expect(after.cash, before.cash);
      expect(after.summerBonusSelection, before.summerBonusSelection);
      expect(after.trainingSelections, before.trainingSelections);
      expect(after.growthAppliedMonths, before.growthAppliedMonths);
      expect(after.engineerRuntimes, same(before.engineerRuntimes));
    });

    test('old JSON, malformed values, and invalid months normalize to null', () {
      final old = PublicDemoState.aprilStart().toJson()
        ..remove('recruitmentMediumUsedMonth');
      expect(PublicDemoState.fromJson(old).recruitmentMediumUsedMonth, isNull);

      for (final raw in ['4', 0, -1, 3, 9, null]) {
        final malformed = PublicDemoState.aprilStart().toJson()
          ..['recruitmentMediumUsedMonth'] = raw;
        expect(
          PublicDemoState.fromJson(malformed).recruitmentMediumUsedMonth,
          isNull,
        );
      }
    });

    test('new JSON round trips and copyWith can preserve or clear usage', () {
      final used = PublicDemoState.aprilStart().markRecruitmentMediaUsed(5);
      expect(
        PublicDemoState.fromJson(used.toJson()).recruitmentMediumUsedMonth,
        5,
      );
      expect(used.copyWith().recruitmentMediumUsedMonth, 5);
      expect(
        used.copyWith(recruitmentMediumUsedMonth: null).recruitmentMediumUsedMonth,
        isNull,
      );
    });
  });
}
