import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_revenue.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_revenue_payment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  group('PublicDemoRevenuePayment.apply', () {
    test('collects pending revenue into cash', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 1000000,
        pendingRevenue: 500000,
      );
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(result.state.cash, 1500000);
    });

    test('1 assigned engineer books 500,000 as the new pending revenue', () {
      final state = PublicDemoState.aprilStart().copyWith(engineersAssigned: 1);
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(result.state.pendingRevenue, 500000);
    });

    test('2 assigned engineers books 1,000,000 as the new pending revenue', () {
      final state = PublicDemoState.aprilStart().copyWith(engineersAssigned: 2);
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(result.state.pendingRevenue, 1000000);
    });

    test(
      'old pending 500,000 with 2 assigned: cash +500,000, pending 1,000,000',
      () {
        final state = PublicDemoState.aprilStart().copyWith(
          cash: 1000000,
          pendingRevenue: 500000,
          engineersAssigned: 2,
        );
        final result = PublicDemoRevenuePayment.apply(state: state);
        expect(result.state.cash, 1500000);
        expect(result.state.pendingRevenue, 1000000);
      },
    );

    test('0 pending revenue leaves cash unchanged', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 1000000,
        pendingRevenue: 0,
      );
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(result.state.cash, 1000000);
    });

    test('0 assigned engineers books 0 as the new pending revenue', () {
      final state = PublicDemoState.aprilStart().copyWith(engineersAssigned: 0);
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(result.state.pendingRevenue, 0);
    });

    test(
      'both 0 (no pending revenue, no assigned engineers) succeeds cleanly',
      () {
        final state = PublicDemoState.aprilStart().copyWith(
          cash: 1000000,
          pendingRevenue: 0,
          engineersAssigned: 0,
        );
        final result = PublicDemoRevenuePayment.apply(state: state);
        expect(result.state.cash, 1000000);
        expect(result.state.pendingRevenue, 0);
      },
    );

    test('does not mutate the original state', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 2,
      );
      PublicDemoRevenuePayment.apply(state: state);
      expect(state.cash, 1000000);
      expect(state.pendingRevenue, 500000);
      expect(state.engineersAssigned, 2);
    });

    test("this month's newly recognized revenue does not enter cash in the "
        'same settlement (30-day site is preserved)', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 1000000,
        pendingRevenue: 0,
        engineersAssigned: 2,
      );
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(result.state.cash, 1000000);
      expect(result.state.pendingRevenue, 1000000);
      expect(result.revenueReceived, 0);
      expect(result.revenueRecognized, 1000000);
    });

    test('salary state fields are unaffected', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 2,
      );
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(result.state.engineerCount, state.engineerCount);
      expect(result.state.adminCount, state.adminCount);
      expect(result.state.engineersWaiting, state.engineersWaiting);
      expect(result.state.engineersAssigned, state.engineersAssigned);
    });

    test('summer bonus (BONUS) state fields are unaffected', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 2,
      );
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(result.state.summerBonusSelection, state.summerBonusSelection);
      expect(result.state.summerBonusPaid, state.summerBonusPaid);
      expect(result.state.summerBonusPaidMonth, state.summerBonusPaidMonth);
      expect(result.state.summerBonusPaidAmount, state.summerBonusPaidAmount);
    });

    test('training selections are unaffected', () {
      final state = PublicDemoState.aprilStart().selectInternalTraining(
        'eng-01',
      );
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(result.state.trainingSelections, state.trainingSelections);
    });

    test('recruitment media usage is unaffected', () {
      final state = PublicDemoState.aprilStart().markRecruitmentMediaUsed(4);
      final result = PublicDemoRevenuePayment.apply(state: state);
      expect(
        result.state.recruitmentMediumUsedMonth,
        state.recruitmentMediumUsedMonth,
      );
    });

    test('REVENUE-1 pendingRevenue JSON round trip still works after this '
        'transaction', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 2,
      );
      final result = PublicDemoRevenuePayment.apply(state: state);
      final roundTripped = PublicDemoState.fromJson(result.state.toJson());
      expect(roundTripped.pendingRevenue, result.state.pendingRevenue);
      expect(roundTripped.cash, result.state.cash);
    });

    test('reuses PublicDemoRevenue.monthlyRevenueForAssignedCount instead of '
        'duplicating the rate', () {
      for (final assignedCount in [0, 1, 2, 3, 5]) {
        final state = PublicDemoState.aprilStart().copyWith(
          engineersAssigned: assignedCount,
        );
        final result = PublicDemoRevenuePayment.apply(state: state);
        expect(
          result.revenueRecognized,
          PublicDemoRevenue.monthlyRevenueForAssignedCount(assignedCount),
        );
      }
    });

    // POST-12MONTH-1-FIX1 P1-2: apply() reads state.fiscalYearCompleted
    // directly off the required [state] parameter — there is no separate
    // flag a caller could omit or override, so this cannot be bypassed the
    // way the pre-FIX1 raise API could.
    group('terminal state guard (POST-12MONTH-1-FIX1 P1-2)', () {
      test('a direct call once completed leaves cash and pendingRevenue '
          'unchanged, even with pending revenue and assigned engineers '
          'that would otherwise move both', () {
        final state = PublicDemoState.aprilStart().copyWith(
          month: 15,
          cash: 4000000,
          pendingRevenue: 1000000,
          engineersAssigned: 2,
          fiscalYearCompleted: true,
        );
        final result = PublicDemoRevenuePayment.apply(state: state);
        expect(identical(result.state, state), isTrue);
        expect(result.state.cash, state.cash);
        expect(result.state.pendingRevenue, state.pendingRevenue);
        expect(result.revenueReceived, 0);
        expect(result.revenueRecognized, 0);
      });

      test('an otherwise-identical not-completed state still settles '
          'normally — proving the guard above is fiscalYearCompleted, not '
          'some other condition', () {
        final state = PublicDemoState.aprilStart().copyWith(
          month: 15,
          cash: 4000000,
          pendingRevenue: 1000000,
          engineersAssigned: 2,
        );
        final result = PublicDemoRevenuePayment.apply(state: state);
        expect(result.state.cash, 5000000);
        expect(result.state.pendingRevenue, 1000000);
      });

      test('March close still settles Revenue: previous pendingRevenue becomes '
          'cash and March books its own new pendingRevenue, because '
          'PublicDemoMonthlyClose.closeOrdinaryMonth always applies Revenue '
          'while fiscalYearCompleted is still false, before '
          'completeFiscalYear sets it', () {
        // This directly exercises PublicDemoRevenuePayment.apply the same
        // way PublicDemoMonthlyClose.closeOrdinaryMonth does for March,
        // to pin the ordering this guard depends on without duplicating
        // the full closeOrdinaryMonth test suite already in
        // public_demo_monthly_close_ordinary_month_test.dart.
        final march = PublicDemoState.aprilStart().copyWith(
          month: 15,
          cash: 4000000,
          pendingRevenue: 1000000,
          engineersAssigned: 2,
        );
        expect(march.fiscalYearCompleted, isFalse);
        final result = PublicDemoRevenuePayment.apply(state: march);
        expect(result.state.cash, 4000000 + 1000000);
        expect(result.state.pendingRevenue, 1000000);
        final completed = result.state.completeFiscalYear(
          monthlyExpenses: 800000,
        );
        expect(completed.fiscalYearCompleted, isTrue);
        expect(completed.pendingRevenue, 1000000);
      });
    });
  });
}
