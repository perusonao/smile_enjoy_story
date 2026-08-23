/// Revenue constants for Public Demo 0.1.
///
/// REVENUE-1 deliberately stops at the constant: assigned-count → revenue
/// calculation belongs to REVENUE-2, and cash/month-end wiring belongs to
/// REVENUE-4 (see SES_REVENUE-0_Research_ClaudeCode_Report.md). This class
/// exists only so [ratePerAssignedEngineer] has a single named source.
class PublicDemoRevenue {
  const PublicDemoRevenue._();

  /// ¥/assigned engineer/month. A provisional balance value from REVENUE-0's
  /// research (§16) — REVENUE-6 owns tuning it, not this constant's callers.
  static const int ratePerAssignedEngineer = 500000;
}
