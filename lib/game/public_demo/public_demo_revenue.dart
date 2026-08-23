/// Revenue constants and pure calculation for Public Demo 0.1.
///
/// REVENUE-2 deliberately stops at the calculation: booking it onto
/// [PublicDemoState.pendingRevenue] and settling it into cash at month-end
/// belongs to REVENUE-3/REVENUE-4 (see
/// SES_REVENUE-0_Research_ClaudeCode_Report.md). This class exists only so
/// [ratePerAssignedEngineer] and the calculation it drives have a single
/// named source.
class PublicDemoRevenue {
  const PublicDemoRevenue._();

  /// ¥/assigned engineer/month. A provisional balance value from REVENUE-0's
  /// research (§16) — REVENUE-6 owns tuning it, not this constant's callers.
  static const int ratePerAssignedEngineer = 500000;

  /// Revenue booked for one month from [assignedCount] assigned engineers.
  ///
  /// This has no notion of engineer status itself: callers must pass the
  /// count already restricted to the assignment source (see
  /// [PublicDemoState.engineersAssigned]), not waiting or training counts.
  ///
  /// The assert fails fast in debug/test; release builds strip asserts, so
  /// a negative count (e.g. from unnormalized JSON) is also clamped to 0
  /// rather than producing negative revenue.
  static int monthlyRevenueForAssignedCount(int assignedCount) {
    assert(assignedCount >= 0, 'assignedCount must not be negative');
    final normalizedCount = assignedCount < 0 ? 0 : assignedCount;
    return normalizedCount * ratePerAssignedEngineer;
  }
}
