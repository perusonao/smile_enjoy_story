import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_month_guard.dart';

void main() {
  group('PublicDemoMonthGuard (Issue #119 PR1)', () {
    test('July with no bonus decision returns REQUIRED summer-bonus-decision', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 7,
        monthCloseApplicable: true,
        summerBonusDecisionConfirmed: false,
      );
      expect(items, hasLength(1));
      expect(
        items.single.id,
        PublicDemoMonthGuard.summerBonusDecisionItemId,
      );
      expect(items.single.level, PublicDemoMonthGuardLevel.required);
    });

    test('July with bonus decision confirmed returns no required item', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 7,
        monthCloseApplicable: true,
        summerBonusDecisionConfirmed: true,
      );
      expect(items, isEmpty);
    });

    test('non-July months never return a summer-bonus required item', () {
      for (final month in [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15]) {
        final items = PublicDemoMonthGuard.evaluate(
          month: month,
          monthCloseApplicable: true,
          summerBonusDecisionConfirmed: false,
        );
        expect(items, isEmpty, reason: 'month $month must not require it');
      }
    });

    test('month close not applicable (e.g. blocked) yields no items even '
        'in July with an unconfirmed decision', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 7,
        monthCloseApplicable: false,
        summerBonusDecisionConfirmed: false,
      );
      expect(items, isEmpty);
    });

    test(
      'the guard is a pure function of month/applicability/decision-'
      'confirmed only — it takes no success-state parameters (cash, '
      'sales, recruiting, assignment), so it structurally cannot inspect '
      'or require unrelated success state',
      () {
        // This is enforced by the API shape itself: `evaluate` only accepts
        // `month`, `monthCloseApplicable`, and `summerBonusDecisionConfirmed`.
        // Exercise the full boolean matrix to pin that contract down.
        for (final applicable in [true, false]) {
          for (final confirmed in [true, false]) {
            final items = PublicDemoMonthGuard.evaluate(
              month: 7,
              monthCloseApplicable: applicable,
              summerBonusDecisionConfirmed: confirmed,
            );
            final expectRequired = applicable && !confirmed;
            expect(items.isNotEmpty, expectRequired);
          }
        }
      },
    );
  });
}
