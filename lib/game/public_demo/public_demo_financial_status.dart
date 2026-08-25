/// Authoritative financial-health status for Public Demo 0.1
/// (FINANCE-FAILURE-1A+1B, approved Candidate B'.1 contract).
///
/// [PublicDemoState.financialStatus] is the single authoritative source for
/// this fact — no caller may infer financial health from cash sign,
/// [PublicDemoState.fiscalYearCompleted] alone, or any UI-local
/// recomputation. [bankruptcy] and [marchCashShortageFailure] are TERMINAL
/// (see [isTerminal]): once either is reached, every monthly-close command
/// on [PublicDemoAggregate] becomes a no-op
/// (`PublicDemoState.isCloseBlocked`), and every optional obligation-
/// creating action (recruitment media, offer acceptance, paid training, a
/// bonus above [PublicDemoSummerBonusPlan.none]) is rejected while either
/// terminal status or [cashShortage] holds
/// (`PublicDemoState.isFinanciallyRestricted`).
enum PublicDemoFinancialStatus {
  /// No open shortage and no terminal failure.
  normal,

  /// The one-close grace period after the first non-March monthly close
  /// that ended with negative cash. The negative cash is real and stays
  /// committed; the very next monthly close decides recovery or
  /// bankruptcy.
  cashShortage,

  /// Terminal: a monthly close that began already in [cashShortage] still
  /// ended with negative cash. The close itself still committed exactly
  /// once — bankruptcy is the *result* of that completed transaction, not a
  /// rollback of it.
  bankruptcy,

  /// Terminal: March (the fiscal year's last month) closed with negative
  /// cash while the company entered March in [normal] status. Distinct
  /// from [bankruptcy] (which requires entering March already in
  /// [cashShortage]) and from successful fiscal completion.
  marchCashShortageFailure;

  bool get isTerminal =>
      this == PublicDemoFinancialStatus.bankruptcy ||
      this == PublicDemoFinancialStatus.marchCashShortageFailure;

  /// Computes the financial status after one completed monthly close
  /// (Candidate B'.1's shortage/recovery/bankruptcy/March-failure
  /// contract). [previous] is the status entering the close — every
  /// production call site is guarded so this is never already
  /// [isTerminal] (a terminal status blocks the close entirely before this
  /// is ever reached). [isMarch] is whether the month being closed is the
  /// fiscal year's last (internal month 15). [closingCash] is the cash
  /// balance the close actually produced — the same value committed to
  /// [PublicDemoState.cash] and to that close's
  /// [PublicDemoMonthlyCashFlow.closingCash].
  static PublicDemoFinancialStatus afterClose({
    required PublicDemoFinancialStatus previous,
    required bool isMarch,
    required int closingCash,
  }) {
    final negative = closingCash < 0;
    if (previous == PublicDemoFinancialStatus.cashShortage) {
      // Already in the one-close grace period: this close decides recovery
      // or bankruptcy, in every month including March.
      return negative
          ? PublicDemoFinancialStatus.bankruptcy
          : PublicDemoFinancialStatus.normal;
    }
    if (!negative) return PublicDemoFinancialStatus.normal;
    return isMarch
        ? PublicDemoFinancialStatus.marchCashShortageFailure
        : PublicDemoFinancialStatus.cashShortage;
  }

  static PublicDemoFinancialStatus fromJson(Object? raw) {
    if (raw is! String) return PublicDemoFinancialStatus.normal;
    return PublicDemoFinancialStatus.values
            .where((status) => status.name == raw)
            .firstOrNull ??
        PublicDemoFinancialStatus.normal;
  }
}
