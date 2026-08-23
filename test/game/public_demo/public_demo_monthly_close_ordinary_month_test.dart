import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_month_label.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

/// 12MONTH-3: [PublicDemoMonthlyClose.closeOrdinaryMonth] is the single
/// shared entry point that extends the Common Monthly Close (12MONTH-1) and
/// its Revenue wiring (12MONTH-2/REVENUE-4) from August (8) through March
/// (15) — one method for the whole back half of the fiscal year instead of
/// a dedicated advanceToSeptember/advanceToOctober/... method per month.
void main() {
  /// Minimal, fully-controlled fixture, matching the style already used by
  /// public_demo_monthly_close_revenue_test.dart.
  PublicDemoState fixture({
    required int month,
    required int cash,
    required int pendingRevenue,
    required int engineersAssigned,
    bool fiscalYearCompleted = false,
  }) => PublicDemoState(
    month: month,
    cash: cash,
    engineerCount: engineersAssigned + 1,
    adminCount: 1,
    salesCapacity: 4,
    salesUsed: 2,
    engineersWaiting: 1,
    engineersAssigned: engineersAssigned,
    pendingRevenue: pendingRevenue,
    fiscalYearCompleted: fiscalYearCompleted,
  );

  group('August -> September (first focused ordinary-month close)', () {
    test('old pending settles into cash, current assigned books new '
        'pending, expenses settle, month advances, sales resets', () {
      final august = fixture(
        month: 8,
        cash: 2000000,
        pendingRevenue: 500000,
        engineersAssigned: 1,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: august,
        monthlyExpenses: 800000,
      );
      expect(result.isClosed, isTrue);
      expect(result.closedMonth, 8);
      // cash: +500,000 (old pending) - 800,000 (expenses) = -300,000
      expect(result.cashAfter, 2000000 + 500000 - 800000);
      // new pending: 1 assigned x 500,000
      expect(result.state.pendingRevenue, 500000);
      expect(result.state.month, 9);
      expect(result.state.salesUsed, 0);
    });

    test('calling it again right after processes the new current month '
        '(September), not a duplicate August close: Revenue books once '
        'per real month, never twice for the same one', () {
      final august = fixture(
        month: 8,
        cash: 2000000,
        pendingRevenue: 500000,
        engineersAssigned: 1,
      );
      final afterAugust = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: august,
        monthlyExpenses: 800000,
      );
      expect(afterAugust.state.month, 9);
      final afterSeptember = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: afterAugust.state,
        monthlyExpenses: 800000,
      );
      expect(afterSeptember.isClosed, isTrue);
      expect(afterSeptember.closedMonth, 9);
      expect(afterSeptember.state.month, 10);
      // September's old pending (August's just-booked 500,000) settles once;
      // September's own 1-assigned revenue (500,000) books as new pending.
      expect(
        afterSeptember.cashAfter,
        afterAugust.state.cash + 500000 - 800000,
      );
      expect(afterSeptember.state.pendingRevenue, 500000);
    });
  });

  group('September -> March, one shared method per ordinary month', () {
    test('9->10, 10->11, 11->12, 12->1, 1->2, 2->3 all close via '
        'closeOrdinaryMonth with the internal month advancing by one', () {
      var state = fixture(
        month: 9,
        cash: 5000000,
        pendingRevenue: 0,
        engineersAssigned: 1,
      );
      const expectedNextMonths = [10, 11, 12, 13, 14, 15];
      const expectedLabels = ['10月', '11月', '12月', '1月', '2月', '3月'];
      for (var i = 0; i < expectedNextMonths.length; i++) {
        final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
          state: state,
          monthlyExpenses: 100000,
        );
        expect(result.isClosed, isTrue);
        expect(result.state.month, expectedNextMonths[i]);
        expect(publicDemoMonthLabel(result.state.month), expectedLabels[i]);
        state = result.state;
      }
      expect(state.fiscalYearCompleted, isFalse);
    });
  });

  group('Revenue across the year boundary (December -> January)', () {
    test('December close settles old pending into January cash and books '
        'January\'s own pending; Revenue is not reset at the boundary', () {
      final december = fixture(
        month: 12,
        cash: 3000000,
        pendingRevenue: 500000,
        engineersAssigned: 2,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: december,
        monthlyExpenses: 800000,
      );
      expect(result.state.month, 13);
      expect(publicDemoMonthLabel(result.state.month), '1月');
      // cash: +500,000 (December's old pending) - 800,000 (expenses)
      expect(result.cashAfter, 3000000 + 500000 - 800000);
      // January's new pending: 2 assigned x 500,000
      expect(result.state.pendingRevenue, 1000000);
    });
  });

  group('March close (15)', () {
    test('old pending settles into cash, March revenue becomes new '
        'pending (not collected), fiscalYearCompleted becomes true, and '
        'the month does not advance to a 16th value', () {
      final march = fixture(
        month: 15,
        cash: 4000000,
        pendingRevenue: 1000000,
        engineersAssigned: 2,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: march,
        monthlyExpenses: 800000,
      );
      expect(result.isClosed, isTrue);
      expect(result.closedMonth, 15);
      // cash: +1,000,000 (old pending) - 800,000 (expenses)
      expect(result.cashAfter, 4000000 + 1000000 - 800000);
      // March's own revenue (2 assigned x 500,000) stays pending: Public
      // Demo ends before the 30-day site would collect it.
      expect(result.state.pendingRevenue, 1000000);
      expect(result.state.month, 15);
      expect(result.state.fiscalYearCompleted, isTrue);
    });

    test('closing March a second time is a no-op', () {
      final march = fixture(
        month: 15,
        cash: 4000000,
        pendingRevenue: 1000000,
        engineersAssigned: 2,
      );
      final first = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: march,
        monthlyExpenses: 800000,
      );
      final second = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: first.state,
        monthlyExpenses: 800000,
      );
      expect(second.status, PublicDemoMonthlyCloseStatus.notApplicable);
      expect(second.state, same(first.state));
    });
  });

  group('Guard: closeOrdinaryMonth is a no-op outside 8-15', () {
    test('does nothing for April through July (owned by the dedicated '
        'closeApril/closeMay/closeJune/closeJuly methods)', () {
      for (var month = 4; month <= 7; month++) {
        final state = fixture(
          month: month,
          cash: 1000000,
          pendingRevenue: 0,
          engineersAssigned: 0,
        );
        final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
          state: state,
          monthlyExpenses: 800000,
        );
        expect(
          result.status,
          PublicDemoMonthlyCloseStatus.notApplicable,
          reason: 'month $month',
        );
        expect(result.state, same(state));
      }
    });
  });

  group('Full fiscal year: April start through March close', () {
    test('4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 1 -> 2 -> 3 -> '
        'fiscal year complete', () {
      // One April order (matching the existing per-domain-file "ordered
      // engineers win a May assignment" fixture) is enough to carry Revenue
      // through June and make July's fixed bonus-close cash guard payable —
      // a "zero orders the whole way" route runs out of cash exactly at
      // July's guard and is not this test's concern (that pre-existing
      // guard is exercised on its own in public_demo_monthly_close_test.dart
      // and public_demo_monthly_close_revenue_test.dart).
      var state = PublicDemoState.aprilStart();

      state = PublicDemoMonthlyClose.closeApril(
        state: state,
        monthlyExpenses: 800000,
        orderedEngineers: 1,
      ).state;
      expect(state.month, 5);

      state = PublicDemoMonthlyClose.closeMay(
        state: state,
        monthlyExpenses: 800000,
        acceptedHires: 0,
        hiredWithOrders: 0,
      ).state;
      expect(state.month, 6);

      state = PublicDemoMonthlyClose.closeJune(
        state: state,
        monthlyExpenses: 800000,
        assignedInJuly: 0,
      ).state;
      expect(state.month, 7);

      final julyResult = PublicDemoMonthlyClose.closeJuly(
        state: state,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(julyResult.isClosed, isTrue);
      state = julyResult.state;
      expect(state.month, 8);

      // Closes August (8) through February (14): each advances the month by
      // exactly one, landing on March (15).
      for (
        var expectedNextMonth = 9;
        expectedNextMonth <= 15;
        expectedNextMonth++
      ) {
        final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
          state: state,
          monthlyExpenses: 800000,
        );
        expect(result.isClosed, isTrue);
        expect(result.state.month, expectedNextMonth);
        state = result.state;
      }
      expect(state.month, 15);
      expect(publicDemoMonthLabel(state.month), '3月');
      expect(state.fiscalYearCompleted, isFalse);

      // Closing March itself completes the fiscal year without a 16th month.
      final marchClose = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: state,
        monthlyExpenses: 800000,
      );
      expect(marchClose.isClosed, isTrue);
      expect(marchClose.state.month, 15);
      expect(marchClose.state.fiscalYearCompleted, isTrue);
    });
  });
}
