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

  /// ¥/assigned engineer/month. Originally a provisional balance value from
  /// REVENUE-0's research (§16, 500,000).
  ///
  /// Issue #223 (FIRST-FUN-YEAR Seeded Balance Fix) Fresh Audit tuning:
  /// raised 500,000 -> 600,000 (+20%). At 500,000, margin per assigned
  /// engineer (rate minus salary) was too thin relative to the cash-flow lag
  /// a new hire's own salary/recruitment cost creates before that hire is
  /// ever actually assigned (interview + pre-entry pipeline months) — every
  /// seeded strategy that hired at all (Balanced, Growth) bankrupted more
  /// often than the no-hire Conservative baseline, the opposite of "早期採用
  /// に将来売上を増やす合理的メリットがある" (see the Result report's
  /// authoritative-economy and tuning-rationale sections for the full
  /// before/after seed comparison). Combined with the
  /// [PublicDemoGrowthEngine] internal-training-rate fix, this makes the
  /// Balanced strategy reliably completable while Growth/Poor-decisions stay
  /// genuinely risky — see
  /// `docs/reports/SES_FIRST-FUN-YEAR_Seeded-Balance-Fix_Result.md`.
  static const int ratePerAssignedEngineer = 600000;

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
