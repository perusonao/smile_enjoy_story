import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

/// 12MONTH-3: [PublicDemoState.advanceToNextOrdinaryMonth] and
/// [PublicDemoState.completeFiscalYear] are the two new generic transitions
/// that extend the fiscal year from August (8) through March (15) without a
/// dedicated advanceToSeptember/advanceToOctober/... method per month.
void main() {
  PublicDemoState augustState({int cash = 3000000}) =>
      PublicDemoState.aprilStart().copyWith(
        month: 8,
        cash: cash,
        engineerCount: 3,
        engineersAssigned: 2,
        engineersWaiting: 1,
        salesUsed: 3,
      );

  group('PublicDemoState.advanceToNextOrdinaryMonth', () {
    test('August (8) advances to September (9): expenses settle, sales '
        'reset, engineersAssigned/Waiting carry forward unchanged', () {
      final august = augustState();
      final september = august.advanceToNextOrdinaryMonth(
        monthlyExpenses: 800000,
      );
      expect(september.month, 9);
      expect(september.cash, august.cash - 800000);
      expect(september.salesUsed, 0);
      expect(september.engineersAssigned, august.engineersAssigned);
      expect(september.engineersWaiting, august.engineersWaiting);
      expect(september.engineerCount, august.engineerCount);
    });

    test('every ordinary month from 8 through 14 advances by exactly one', () {
      for (var month = 8; month <= 14; month++) {
        final state = PublicDemoState.aprilStart().copyWith(month: month);
        final next = state.advanceToNextOrdinaryMonth(monthlyExpenses: 0);
        expect(next.month, month + 1, reason: 'closing month $month');
      }
    });

    test('February (14) advances to March (15)', () {
      final february = PublicDemoState.aprilStart().copyWith(
        month: 14,
        cash: 1000000,
      );
      final march = february.advanceToNextOrdinaryMonth(
        monthlyExpenses: 800000,
      );
      expect(march.month, 15);
      expect(march.cash, 200000);
    });

    test('is a no-op below August (still owned by the per-month methods)', () {
      final state = PublicDemoState.aprilStart().copyWith(month: 7);
      final result = state.advanceToNextOrdinaryMonth(monthlyExpenses: 800000);
      expect(result, same(state));
    });

    test('is a no-op at March (15): completeFiscalYear owns that close', () {
      final march = PublicDemoState.aprilStart().copyWith(month: 15);
      final result = march.advanceToNextOrdinaryMonth(monthlyExpenses: 800000);
      expect(result, same(march));
    });

    test('is a no-op past March (guards against a 16th internal month)', () {
      final state = PublicDemoState.aprilStart().copyWith(month: 16);
      final result = state.advanceToNextOrdinaryMonth(monthlyExpenses: 800000);
      expect(result, same(state));
    });
  });

  group('PublicDemoState.completeFiscalYear', () {
    test('March (15) settles expenses and sets fiscalYearCompleted without '
        'advancing to a 16th month', () {
      final march = PublicDemoState.aprilStart().copyWith(
        month: 15,
        cash: 1000000,
        salesUsed: 2,
      );
      expect(march.fiscalYearCompleted, isFalse);
      final completed = march.completeFiscalYear(monthlyExpenses: 800000);
      expect(completed.month, 15);
      expect(completed.cash, 200000);
      expect(completed.salesUsed, 0);
      expect(completed.fiscalYearCompleted, isTrue);
    });

    test('is a no-op outside March', () {
      final state = PublicDemoState.aprilStart().copyWith(month: 14);
      final result = state.completeFiscalYear(monthlyExpenses: 800000);
      expect(result, same(state));
    });

    test('is idempotent once already completed', () {
      final completed = PublicDemoState.aprilStart()
          .copyWith(month: 15, cash: 1000000)
          .completeFiscalYear(monthlyExpenses: 800000);
      final again = completed.completeFiscalYear(monthlyExpenses: 800000);
      expect(again, same(completed));
    });

    test('defaults to false for a freshly started game and round trips '
        'through copyWith', () {
      final start = PublicDemoState.aprilStart();
      expect(start.fiscalYearCompleted, isFalse);
      expect(start.copyWith().fiscalYearCompleted, isFalse);
      expect(
        start.copyWith(fiscalYearCompleted: true).fiscalYearCompleted,
        isTrue,
      );
    });
  });
}
