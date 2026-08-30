import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';

void main() {
  group('PublicDemoState summer bonus', () {
    test('April starts with no unpaid bonus', () {
      final state = PublicDemoState.aprilStart();
      expect(state.summerBonusSelection, PublicDemoSummerBonusPlan.none);
      expect(state.summerBonusDecisionConfirmed, isFalse);
      expect(state.summerBonusPaid, isFalse);
      expect(state.summerBonusPaidMonth, isNull);
      expect(state.summerBonusPaidAmount, isNull);
    });

    test('plans expose only Demo 0.1 month choices', () {
      expect(PublicDemoSummerBonusPlan.none.months, 0);
      expect(PublicDemoSummerBonusPlan.half.months, 0.5);
      expect(PublicDemoSummerBonusPlan.one.months, 1.0);
    });

    test('selects, replaces, and cancels bonus selection', () {
      final half = PublicDemoState.aprilStart().selectSummerBonus(
        PublicDemoSummerBonusPlan.half,
      );
      final one = half.selectSummerBonus(PublicDemoSummerBonusPlan.one);
      final none = one.selectSummerBonus(PublicDemoSummerBonusPlan.none);
      expect(half.summerBonusSelection, PublicDemoSummerBonusPlan.half);
      expect(one.summerBonusSelection, PublicDemoSummerBonusPlan.one);
      expect(none.summerBonusSelection, PublicDemoSummerBonusPlan.none);
    });

    test('confirms a selected plan and explicit none independently', () {
      final july = PublicDemoState.aprilStart().copyWith(month: 7);
      final one = july.confirmSummerBonusDecision(
        PublicDemoSummerBonusPlan.one,
      );
      final none = july.confirmSummerBonusDecision(
        PublicDemoSummerBonusPlan.none,
      );

      expect(one.summerBonusSelection, PublicDemoSummerBonusPlan.one);
      expect(one.summerBonusDecisionConfirmed, isTrue);
      expect(none.summerBonusSelection, PublicDemoSummerBonusPlan.none);
      expect(none.summerBonusDecisionConfirmed, isTrue);
    });

    test(
      'selection changes neither financial nor runtime and growth state',
      () {
        final before = PublicDemoState.aprilStart().copyWith(
          growthAppliedMonths: const [4],
          trainingSelections: const {
            'eng-01': PublicDemoGrowthSource.internalTraining,
          },
        );
        final after = before.selectSummerBonus(PublicDemoSummerBonusPlan.one);
        expect(after.cash, before.cash);
        expect(after.engineerRuntimes, same(before.engineerRuntimes));
        expect(after.growthAppliedMonths, before.growthAppliedMonths);
        expect(after.trainingSelections, before.trainingSelections);
      },
    );

    test('records a July payment only once without changing cash', () {
      final before = PublicDemoState.aprilStart();
      final paid = before.markSummerBonusPaid(month: 7, amount: 150000);
      expect(paid.summerBonusPaid, isTrue);
      expect(paid.summerBonusPaidMonth, 7);
      expect(paid.summerBonusPaidAmount, 150000);
      expect(paid.cash, before.cash);
      expect(paid.markSummerBonusPaid(month: 7, amount: 1), same(paid));
    });

    test('rejects non-July and negative payment attempts', () {
      final state = PublicDemoState.aprilStart();
      expect(state.markSummerBonusPaid(month: 6, amount: 1), same(state));
      expect(state.markSummerBonusPaid(month: 7, amount: -1), same(state));
    });

    test('selection is immutable after payment', () {
      final paid = PublicDemoState.aprilStart()
          .selectSummerBonus(PublicDemoSummerBonusPlan.half)
          .markSummerBonusPaid(month: 7, amount: 1);
      expect(paid.selectSummerBonus(PublicDemoSummerBonusPlan.one), same(paid));
    });

    test('old JSON and malformed selection safely fall back', () {
      final old = PublicDemoState.aprilStart().toJson()
        ..remove('summerBonusSelection')
        ..remove('summerBonusDecisionConfirmed')
        ..remove('summerBonusPaid')
        ..remove('summerBonusPaidMonth')
        ..remove('summerBonusPaidAmount');
      expect(
        PublicDemoState.fromJson(old).summerBonusSelection,
        PublicDemoSummerBonusPlan.none,
      );
      expect(
        PublicDemoState.fromJson(old).summerBonusDecisionConfirmed,
        isFalse,
      );

      for (final raw in ['two', 'unknown', 1, null]) {
        final malformed = PublicDemoState.aprilStart().toJson()
          ..['summerBonusSelection'] = raw;
        expect(
          PublicDemoState.fromJson(malformed).summerBonusSelection,
          PublicDemoSummerBonusPlan.none,
        );
      }
    });

    test('new JSON round trips and normalizes stale or malformed payments', () {
      final paid = PublicDemoState.aprilStart()
          .copyWith(month: 7)
          .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.one)
          .markSummerBonusPaid(month: 7, amount: 200000);
      final restored = PublicDemoState.fromJson(paid.toJson());
      expect(restored.summerBonusSelection, PublicDemoSummerBonusPlan.one);
      expect(restored.summerBonusDecisionConfirmed, isTrue);
      expect(restored.summerBonusPaid, isTrue);
      expect(restored.summerBonusPaidAmount, 200000);

      final stale = PublicDemoState.aprilStart().toJson()
        ..['summerBonusPaid'] = false
        ..['summerBonusPaidMonth'] = 7
        ..['summerBonusPaidAmount'] = 1;
      expect(PublicDemoState.fromJson(stale).summerBonusPaidMonth, isNull);
      expect(PublicDemoState.fromJson(stale).summerBonusPaidAmount, isNull);

      for (final patch in [
        {'summerBonusPaidMonth': 6, 'summerBonusPaidAmount': 1},
        {'summerBonusPaidMonth': 7, 'summerBonusPaidAmount': -1},
        {'summerBonusPaidMonth': '7', 'summerBonusPaidAmount': 1},
        {'summerBonusPaidMonth': 7, 'summerBonusPaidAmount': null},
      ]) {
        final malformed = PublicDemoState.aprilStart().toJson()
          ..['summerBonusPaid'] = true
          ..addAll(patch);
        final normalized = PublicDemoState.fromJson(malformed);
        expect(normalized.summerBonusPaid, isFalse);
        expect(normalized.summerBonusPaidMonth, isNull);
        expect(normalized.summerBonusPaidAmount, isNull);
      }
    });

    test('copyWith can preserve and explicitly clear payment fields', () {
      final paid = PublicDemoState.aprilStart().markSummerBonusPaid(
        month: 7,
        amount: 1,
      );
      expect(paid.copyWith().summerBonusPaidAmount, 1);
      final cleared = paid.copyWith(
        summerBonusPaid: false,
        summerBonusPaidMonth: null,
        summerBonusPaidAmount: null,
      );
      expect(cleared.summerBonusPaid, isFalse);
      expect(cleared.summerBonusPaidMonth, isNull);
    });
  });
}
