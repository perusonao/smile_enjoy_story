import 'public_demo_revenue.dart';
import 'public_demo_state.dart';

/// Pure month-end 30-day-site settlement for Public Demo 0.1.
///
/// Collects last month's billed revenue ([PublicDemoState.pendingRevenue])
/// into cash, then books this month's revenue from
/// [PublicDemoState.engineersAssigned] (via [PublicDemoRevenue]) as the new
/// pending balance — so this month's billing is not collectible until next
/// month's settlement. There is no failure mode: this always succeeds, even
/// when both amounts are 0 — except once [PublicDemoState.fiscalYearCompleted]
/// is true, where [state] is the sole, non-bypassable authority (no
/// caller-supplied flag) and this becomes a no-op returning [state]
/// unchanged (POST-12MONTH-1-FIX1 P1-2).
///
/// Every [PublicDemoMonthlyClose] caller of this (including March's own
/// close) always applies it *before* [PublicDemoState.completeFiscalYear]
/// sets the flag, so this guard cannot suppress March's own Revenue
/// settlement — only a call made *after* completion, direct or otherwise.
class PublicDemoRevenuePayment {
  const PublicDemoRevenuePayment._();

  static PublicDemoRevenuePaymentResult apply({
    required PublicDemoState state,
  }) {
    if (state.fiscalYearCompleted) {
      return PublicDemoRevenuePaymentResult._(
        state: state,
        revenueReceived: 0,
        revenueRecognized: 0,
      );
    }
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
