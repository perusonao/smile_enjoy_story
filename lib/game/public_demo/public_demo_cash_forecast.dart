import 'public_demo_recruitment.dart';
import 'public_demo_revenue.dart';
import 'public_demo_salary.dart';
import 'public_demo_salary_finance.dart';
import 'public_demo_state.dart';
import 'public_demo_summer_bonus_payment.dart';

/// Pure, confirmed-information-only cash forecast for Public Demo 0.1
/// (Issue #148 Phase 1A).
///
/// This projects future monthly closes using only facts [PublicDemoState]
/// (plus the currently joined applicants) already carries as SSOT:
///
///  * current cash and [PublicDemoState.pendingRevenue] (the existing
///    fixed 30-day collection lag — see [PublicDemoRevenuePayment]),
///  * revenue for the currently assigned engineer count (held constant —
///    a future assignment change is a recruitment/sales outcome this
///    forecast never predicts),
///  * payroll and fixed costs for the currently joined roster, computed
///    with the exact same [PublicDemoSalaryFinance.monthlyExpenses] the
///    real monthly close uses (including any already-decided, month-dated
///    raise — [PublicDemoApplicant.salaryForMonth] — since that is a fixed
///    future obligation, not an uncertain success),
///  * the currently selected July summer bonus
///    ([PublicDemoState.summerBonusSelection]), calculated with the exact
///    same [PublicDemoSummerBonusPayment.calculateSummerBonus] the real
///    July close uses.
///
/// Deliberately excluded: any future recruitment, interview, offer, or
/// sales-success outcome, and any hire not already joined. Those are
/// uncertain future player/game outcomes, not confirmed information, and
/// mixing them in would make this a probability model rather than a
/// confirmed-information projection (see Issue #148 Phase 1 design
/// principle).
///
/// This model never reads or writes any UI state and never mutates
/// [state] — [forecast] is a pure function over its arguments. It also
/// never re-derives monthly expense/revenue/bonus formulas of its own: it
/// calls the exact same pure helpers [PublicDemoMonthlyClose] and
/// [PublicDemoSummerBonusPayment] already call, so a forecast can never
/// diverge from what the real monthly close would charge for the same
/// confirmed facts.
class PublicDemoCashForecast {
  const PublicDemoCashForecast._();

  /// "当月末から次の3回の月次精算" (Issue #148 Phase 1A minimum scope).
  static const int defaultMonthsAhead = 3;

  /// Public Demo 0.1's last fiscal month (March); no close ever targets a
  /// month past this.
  static const int _lastFiscalMonth = 15;

  static PublicDemoCashForecastResult forecast({
    required PublicDemoState state,
    required Iterable<PublicDemoApplicant> joinedApplicants,
    int monthsAhead = defaultMonthsAhead,
  }) {
    assert(monthsAhead > 0, 'monthsAhead must be positive');
    final applicants = joinedApplicants.toList(growable: false);
    final months = <PublicDemoCashForecastMonth>[];

    // A close-blocked state (fiscal year completed, or a terminal financial
    // status already reached) has no further monthly close ahead of it —
    // an empty, safe forecast is the correct, honest answer, not a
    // recomputation of a close that will never run (mirrors
    // PublicDemoState.isCloseBlocked, the same guard every real close
    // checks first).
    if (!state.isCloseBlocked) {
      final remainingMonths = _lastFiscalMonth - state.month + 1;
      final steps = monthsAhead < remainingMonths
          ? monthsAhead
          : remainingMonths;

      var cash = state.cash;
      var pendingRevenue = state.pendingRevenue;
      var bonusSettled = state.summerBonusPaid;

      for (var step = 0; step < steps; step++) {
        final closedMonth = state.month + step;
        final openingCash = cash;
        final cashReceived = pendingRevenue;
        final revenueRecognized = PublicDemoRevenue.monthlyRevenueForAssignedCount(
          state.engineersAssigned,
        );
        final monthlyExpenses = PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: applicants,
          month: closedMonth,
        );
        final bonusPaid = closedMonth == 7 && !bonusSettled
            ? PublicDemoSummerBonusPayment.calculateSummerBonus(
                plan: state.summerBonusSelection,
                applicants: applicants,
                month: 7,
              )
            : 0;
        final closingCash = openingCash + cashReceived - monthlyExpenses - bonusPaid;

        months.add(
          PublicDemoCashForecastMonth(
            month: closedMonth,
            openingCash: openingCash,
            cashReceived: cashReceived,
            revenueRecognized: revenueRecognized,
            monthlyExpenses: monthlyExpenses,
            bonusPaid: bonusPaid,
            closingCash: closingCash,
          ),
        );

        cash = closingCash;
        pendingRevenue = revenueRecognized;
        if (closedMonth == 7) bonusSettled = true;
      }
    }

    int? firstShortageMonth;
    for (final monthResult in months) {
      if (monthResult.isNegative) {
        firstShortageMonth = monthResult.month;
        break;
      }
    }

    return PublicDemoCashForecastResult(
      startMonth: state.month,
      months: List.unmodifiable(months),
      firstShortageMonth: firstShortageMonth,
    );
  }
}

/// One forecasted month-end close, shaped like
/// [PublicDemoMonthlyCashFlow]'s already-established fields so a later UI
/// can reuse the same rendering it uses for a historical closed month.
class PublicDemoCashForecastMonth {
  const PublicDemoCashForecastMonth({
    required this.month,
    required this.openingCash,
    required this.cashReceived,
    required this.revenueRecognized,
    required this.monthlyExpenses,
    required this.bonusPaid,
    required this.closingCash,
  });

  /// The internal month number (4-15) this projected close targets.
  final int month;
  final int openingCash;
  final int cashReceived;
  final int revenueRecognized;
  final int monthlyExpenses;
  final int bonusPaid;
  final int closingCash;

  bool get isNegative => closingCash < 0;
}

/// Result of [PublicDemoCashForecast.forecast]: a confirmed-information-only
/// projection, never a recomputation of uncertain future success.
///
/// [basis] is a stable, explicit marker later UI can read to label this
/// data as confirmed-information-based, without inferring that fact from
/// the shape of the result.
class PublicDemoCashForecastResult {
  const PublicDemoCashForecastResult({
    required this.startMonth,
    required this.months,
    required this.firstShortageMonth,
  });

  /// The month the forecast was generated from (the first projected close
  /// targets this exact month).
  final int startMonth;

  /// One entry per projected monthly close, in chronological order.
  final List<PublicDemoCashForecastMonth> months;

  /// The first projected month whose closing cash is negative, or `null`
  /// when every projected month in [months] stays non-negative.
  final int? firstShortageMonth;

  /// Every projected month in this result is derived only from confirmed
  /// current-state facts (see [PublicDemoCashForecast]'s class doc) —
  /// never a projected recruitment, interview, or sales success.
  PublicDemoCashForecastBasis get basis =>
      PublicDemoCashForecastBasis.confirmedOnly;

  bool get hasShortage => firstShortageMonth != null;

  /// True when no projected month in [months] goes cash-negative. This is
  /// the forecast's own explicit safety signal — it never depends on
  /// whether [months] happens to be non-empty (an empty forecast, from an
  /// already close-blocked state, is also safe: there is no further close
  /// left to run out of cash).
  bool get isSafe => !hasShortage;
}

/// The information basis a [PublicDemoCashForecastResult] was computed
/// from. Public Demo 0.1 Phase 1A only ever produces [confirmedOnly].
enum PublicDemoCashForecastBasis {
  /// Cash, accounts-receivable collection, payroll, fixed costs, and any
  /// already-decided bonus/raise — never a projected recruitment,
  /// interview, or sales outcome.
  confirmedOnly,
}
