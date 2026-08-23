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
  });
}
