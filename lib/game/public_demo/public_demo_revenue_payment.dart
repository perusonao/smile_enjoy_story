import 'public_demo_revenue.dart';
import 'public_demo_state.dart';

/// Pure month-end 30-day-site settlement for Public Demo 0.1.
///
/// Collects last month's billed revenue ([PublicDemoState.pendingRevenue])
/// into cash, then books this month's revenue from
/// [PublicDemoState.engineersAssigned] (via [PublicDemoRevenue]) as the new
/// pending balance — so this month's billing is not collectible until next
/// month's settlement. There is no failure mode: this always succeeds, even
/// when both amounts are 0.
class PublicDemoRevenuePayment {
  const PublicDemoRevenuePayment._();

  static PublicDemoRevenuePaymentResult apply({
    required PublicDemoState state,
  }) {
    final revenueReceived = state.pendingRevenue;
    final revenueRecognized = PublicDemoRevenue.monthlyRevenueForAssignedCount(
      state.engineersAssigned,
    );
    return PublicDemoRevenuePaymentResult._(
      state: state.copyWith(
        cash: state.cash + revenueReceived,
        pendingRevenue: revenueRecognized,
      ),
      revenueReceived: revenueReceived,
      revenueRecognized: revenueRecognized,
    );
  }
}

/// Result of [PublicDemoRevenuePayment.apply]. [revenueReceived] is the
/// amount just settled into cash; [revenueRecognized] is this month's
/// billing, held in [PublicDemoState.pendingRevenue] until next month.
class PublicDemoRevenuePaymentResult {
  const PublicDemoRevenuePaymentResult._({
    required this.state,
    required this.revenueReceived,
    required this.revenueRecognized,
  });

  final PublicDemoState state;
  final int revenueReceived;
  final int revenueRecognized;
}
