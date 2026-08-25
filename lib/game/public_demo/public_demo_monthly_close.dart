import 'public_demo_monthly_cash_flow.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_revenue_payment.dart';
import 'public_demo_salary.dart';
import 'public_demo_state.dart';
import 'public_demo_summer_bonus_payment.dart';
import 'public_demo_workflow_state.dart';

/// Common entry point for Public Demo 0.1's month-end transitions.
///
/// Each method below delegates to the existing per-month transition already
/// owned by [PublicDemoState] (or, for July, by [PublicDemoSummerBonusPayment]),
/// so the game behavior for April through August is otherwise exactly what
/// it was before this facade existed. This class unifies the call surface
/// across months and wraps every result in a common shape
/// ([PublicDemoMonthlyCloseResult]); it introduces no new rules for salary,
/// bonus, or growth.
///
/// REVENUE-4: this is also the single connection point between the 30-day
/// Revenue site (REVENUE-1~3) and the common close. Every method below
/// settles [PublicDemoState.pendingRevenue] into cash and books the new
/// month's revenue via [PublicDemoRevenuePayment.apply] *before* delegating
/// to the underlying transition — so the assigned-engineer count Revenue
/// sees is always a snapshot of the month that is closing, taken before
/// that same transition overwrites [PublicDemoState.engineersAssigned] for
/// the next month. Revenue settlement and the underlying transition either
/// both take effect or neither does: see [closeJuly] for the one path with
/// a cash guard.
///
/// 12MONTH-1 scaffolded April-July only; 12MONTH-3 extends the facade
/// through March via [closeOrdinaryMonth], one shared method for every
/// month from August (8) through March (15) rather than a dedicated method
/// per month. See SES_12MONTH-1_Common_Monthly_Close_Result.md,
/// SES_12MONTH-2_REVENUE-4_Close_Integration_Result.md, and
/// SES_12MONTH-3_Fiscal_Year_Extension_Result.md for the full design
/// rationale.
///
/// FINANCE-UX-1: every method that actually closes a month also attaches a
/// [PublicDemoMonthlyCashFlow] to the resulting state (via
/// [PublicDemoState.recordMonthlyCashFlow]), built entirely from values this
/// facade already computed or received — [PublicDemoState.monthOpeningCash]
/// (a fact recorded by the *previous* close/[PublicDemoState.aprilStart]),
/// the [PublicDemoRevenuePaymentResult] this facade already calls, the
/// caller-supplied `monthlyExpenses`/bonus amount, and the actual mid-month
/// training/recruitment spend [PublicDemoState] already accumulated. No
/// salary, revenue, or pendingRevenue value is recomputed for display.
///
/// FIX1: `monthlyExpenses` bundles payroll with
/// [PublicDemoSalary.otherMonthlyFixedCost] — [_cashFlow] splits the two by
/// subtracting that known constant, so the summary's `salaryPaid` no longer
/// misreports fixed costs (rent, utilities) as payroll.
class PublicDemoMonthlyClose {
  const PublicDemoMonthlyClose._();

  /// Closes April, delegating to [PublicDemoState.advanceToMay].
  static PublicDemoMonthlyCloseResult closeApril({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int orderedEngineers,
  }) {
    final closedMonth = state.month;
    final isApril = closedMonth == 4 && !state.isCloseBlocked;
    final revenueResult = isApril
        ? PublicDemoRevenuePayment.apply(state: state)
        : null;
    final revenueApplied = revenueResult?.state ?? state;
    var next = revenueApplied.advanceToMay(
      monthlyExpenses: monthlyExpenses,
      orderedEngineers: orderedEngineers,
    );
    if (isApril) {
      next = next.recordMonthlyCashFlow(
        _cashFlow(
          closedMonth: closedMonth,
          openingCash: state.monthOpeningCash,
          revenueResult: revenueResult!,
          monthlyExpenses: monthlyExpenses,
          bonusPaid: 0,
          trainingCost: state.monthTrainingSpent,
          recruitmentCost: state.monthRecruitmentSpent,
          next: next,
        ),
      );
    }
    return PublicDemoMonthlyCloseResult._(
      state: next,
      status: isApril
          ? PublicDemoMonthlyCloseStatus.closed
          : PublicDemoMonthlyCloseStatus.notApplicable,
      cashBefore: state.cash,
      closedMonth: closedMonth,
    );
  }

  /// Closes May, delegating to [PublicDemoState.advanceToJune].
  ///
  /// WORKFLOW-STATE-1AB FIX3 P1-4: takes the whole authoritative [workflow]
  /// rather than a caller-supplied `joinedApplicants` iterable. FIX2 still
  /// accepted that iterable directly — even though each element had to be
  /// genuinely joined (an unforgeable [PublicDemoJoinRecord], see
  /// [PublicDemoApplicant.hasJoined]), the caller still chose *which
  /// subset* of genuinely-joined applicants to pass, so omitting one,
  /// passing none, or passing a stale snapshot could all still make the
  /// payroll/bonus projection diverge from who actually joined. Deriving
  /// [PublicDemoWorkflowState.joinedApplicants] internally, from the
  /// complete authoritative roster, closes that: there is no longer any
  /// parameter through which a caller could shrink, empty, or stale-date
  /// the set.
  static PublicDemoMonthlyCloseResult closeMay({
    required PublicDemoState state,
    required PublicDemoWorkflowState workflow,
    required int monthlyExpenses,
    required int acceptedHires,
    required int hiredWithOrders,
  }) {
    final closedMonth = state.month;
    final isMay = closedMonth == 5 && !state.isCloseBlocked;
    final revenueResult = isMay
        ? PublicDemoRevenuePayment.apply(state: state)
        : null;
    final revenueApplied = revenueResult?.state ?? state;
    var next = revenueApplied.advanceToJune(
      monthlyExpenses: monthlyExpenses,
      acceptedHires: acceptedHires,
      hiredWithOrders: hiredWithOrders,
      joinedApplicants: workflow.joinedApplicants,
    );
    if (isMay) {
      next = next.recordMonthlyCashFlow(
        _cashFlow(
          closedMonth: closedMonth,
          openingCash: state.monthOpeningCash,
          revenueResult: revenueResult!,
          monthlyExpenses: monthlyExpenses,
          bonusPaid: 0,
          trainingCost: state.monthTrainingSpent,
          recruitmentCost: state.monthRecruitmentSpent,
          next: next,
        ),
      );
    }
    return PublicDemoMonthlyCloseResult._(
      state: next,
      status: isMay
          ? PublicDemoMonthlyCloseStatus.closed
          : PublicDemoMonthlyCloseStatus.notApplicable,
      cashBefore: state.cash,
      closedMonth: closedMonth,
    );
  }

  /// Closes June, delegating to [PublicDemoState.advanceToJuly].
  static PublicDemoMonthlyCloseResult closeJune({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int assignedInJuly,
  }) {
    final closedMonth = state.month;
    final isJune = closedMonth == 6 && !state.isCloseBlocked;
    final revenueResult = isJune
        ? PublicDemoRevenuePayment.apply(state: state)
        : null;
    final revenueApplied = revenueResult?.state ?? state;
    var next = revenueApplied.advanceToJuly(
      monthlyExpenses: monthlyExpenses,
      assignedInJuly: assignedInJuly,
    );
    if (isJune) {
      next = next.recordMonthlyCashFlow(
        _cashFlow(
          closedMonth: closedMonth,
          openingCash: state.monthOpeningCash,
          revenueResult: revenueResult!,
          monthlyExpenses: monthlyExpenses,
          bonusPaid: 0,
          trainingCost: state.monthTrainingSpent,
          recruitmentCost: state.monthRecruitmentSpent,
          next: next,
        ),
      );
    }
    return PublicDemoMonthlyCloseResult._(
      state: next,
      status: isJune
          ? PublicDemoMonthlyCloseStatus.closed
          : PublicDemoMonthlyCloseStatus.notApplicable,
      cashBefore: state.cash,
      closedMonth: closedMonth,
    );
  }

  /// Closes July, delegating to [PublicDemoSummerBonusPayment.closeJuly]
  /// (which itself is called by [PublicDemoState.advanceToAugust]). Ordinary
  /// monthly expenses always settle — this is the single monthly-close
  /// authority for July, and (FINANCE-FAILURE-1A+1B §11, P0) there is no
  /// insufficient-cash rollback path any more: prior AR collection, salary,
  /// and fixed costs are never undone merely because the resulting cash
  /// would go negative. [PublicDemoFinancialStatus]'s shortage/bankruptcy
  /// rules (applied inside [PublicDemoState.advanceToAugust] via
  /// [PublicDemoSummerBonusPayment.closeJuly]) decide the outcome instead.
  ///
  /// Revenue settles into cash *before* the bonus affordability check runs,
  /// so last month's collected revenue is part of the funds available to
  /// pay salary, fixed costs, and bonus — matching the 30-day site's
  /// payment timing. Affordability gating remains scoped to the *optional*
  /// bonus itself: [PublicDemoSummerBonusPayment.closeJuly] pays 0 bonus
  /// (never less than the requested amount, never partial) when the
  /// company cannot afford both mandatory monthly expenses and the
  /// selected bonus together — it never converts that into a rollback of
  /// the mandatory close.
  static PublicDemoMonthlyCloseResult closeJuly({
    required PublicDemoState state,
    required int monthlyExpenses,
    required Iterable<PublicDemoApplicant> applicants,
  }) {
    final closedMonth = state.month;
    final revenueEligible =
        closedMonth == 7 && !state.summerBonusPaid && !state.isCloseBlocked;
    final revenueResult = revenueEligible
        ? PublicDemoRevenuePayment.apply(state: state)
        : null;
    final revenueApplied = revenueResult?.state ?? state;
    final result = PublicDemoSummerBonusPayment.closeJuly(
      state: revenueApplied,
      monthlyExpenses: monthlyExpenses,
      applicants: applicants,
    );
    var next = result.state;
    if (result.isPaid) {
      next = next.recordMonthlyCashFlow(
        _cashFlow(
          closedMonth: closedMonth,
          openingCash: state.monthOpeningCash,
          revenueResult: revenueResult!,
          monthlyExpenses: monthlyExpenses,
          bonusPaid: result.bonusAmount,
          trainingCost: state.monthTrainingSpent,
          recruitmentCost: state.monthRecruitmentSpent,
          next: next,
        ),
      );
    }
    return PublicDemoMonthlyCloseResult._(
      state: next,
      status: result.isPaid
          ? PublicDemoMonthlyCloseStatus.closed
          : PublicDemoMonthlyCloseStatus.notApplicable,
      cashBefore: state.cash,
      closedMonth: closedMonth,
    );
  }

  /// Closes any ordinary month from August (8) through March (15) —
  /// everything beyond July's fixed bonus event — through one shared entry
  /// point rather than a dedicated method per month (12MONTH-3).
  ///
  /// Revenue settles into cash before the underlying transition runs,
  /// exactly as every earlier month in this facade does: old
  /// [PublicDemoState.pendingRevenue] becomes cash, and the current
  /// [PublicDemoState.engineersAssigned] snapshot books the new pending
  /// balance, before that same [monthlyExpenses] settlement can change
  /// anything else. March (closedMonth 15) does not advance to a new
  /// month; it instead completes the fiscal year via
  /// [PublicDemoState.completeFiscalYear], so any revenue booked in March
  /// deliberately stays pending — Public Demo 0.1 ends before its 30-day
  /// site would collect it. March's cash-flow summary is still recorded
  /// under the exact same contract as every other month.
  ///
  /// Unlike closeApril/closeMay/closeJune/closeJuly, this single method
  /// legitimately fires again and again as the fiscal year progresses
  /// (August, then September, ...), since there is no dedicated method per
  /// month to guard on an exact value. The one case this method itself
  /// must still refuse is calling it again once the fiscal year is already
  /// completed (state.month stays 15 after that close) — otherwise Revenue
  /// would settle a second time against the same March snapshot, in
  /// violation of the "settle exactly once" contract every other month in
  /// this facade upholds. The same guard also keeps this method from
  /// recording a second, double-counted cash-flow summary for March.
  static PublicDemoMonthlyCloseResult closeOrdinaryMonth({
    required PublicDemoState state,
    required int monthlyExpenses,
  }) {
    final closedMonth = state.month;
    final isOrdinaryMonth =
        closedMonth >= 8 && closedMonth <= 15 && !state.isCloseBlocked;
    final revenueResult = isOrdinaryMonth
        ? PublicDemoRevenuePayment.apply(state: state)
        : null;
    final revenueApplied = revenueResult?.state ?? state;
    var next = closedMonth == 15
        ? revenueApplied.completeFiscalYear(monthlyExpenses: monthlyExpenses)
        : revenueApplied.advanceToNextOrdinaryMonth(
            monthlyExpenses: monthlyExpenses,
          );
    if (isOrdinaryMonth) {
      next = next.recordMonthlyCashFlow(
        _cashFlow(
          closedMonth: closedMonth,
          openingCash: state.monthOpeningCash,
          revenueResult: revenueResult!,
          monthlyExpenses: monthlyExpenses,
          bonusPaid: 0,
          trainingCost: state.monthTrainingSpent,
          recruitmentCost: state.monthRecruitmentSpent,
          next: next,
        ),
      );
    }
    return PublicDemoMonthlyCloseResult._(
      state: next,
      status: isOrdinaryMonth
          ? PublicDemoMonthlyCloseStatus.closed
          : PublicDemoMonthlyCloseStatus.notApplicable,
      cashBefore: state.cash,
      closedMonth: closedMonth,
    );
  }

  static PublicDemoMonthlyCashFlow _cashFlow({
    required int closedMonth,
    required int openingCash,
    required PublicDemoRevenuePaymentResult revenueResult,
    required int monthlyExpenses,
    required int bonusPaid,
    required int trainingCost,
    required int recruitmentCost,
    required PublicDemoState next,
  }) => PublicDemoMonthlyCashFlow(
    month: closedMonth,
    openingCash: openingCash,
    cashReceived: revenueResult.revenueReceived,
    // Every real caller's monthlyExpenses is payroll plus exactly
    // PublicDemoSalary.otherMonthlyFixedCost (FIX1 P2: the whole amount was
    // previously shown to the player as "給与", misclassifying the fixed
    // cost as payroll). Subtracting that known constant splits the two
    // without recomputing payroll from employee data.
    salaryPaid: monthlyExpenses - PublicDemoSalary.otherMonthlyFixedCost,
    fixedCostsPaid: PublicDemoSalary.otherMonthlyFixedCost,
    bonusPaid: bonusPaid,
    trainingCost: trainingCost,
    recruitmentCost: recruitmentCost,
    closingCash: next.cash,
    revenue: revenueResult.revenueRecognized,
    receivables: next.pendingRevenue,
  );
}

/// Common result shape for every [PublicDemoMonthlyClose] transition.
///
/// [closedMonth] is the month that was targeted for closing, regardless of
/// [status]. [cashBefore]/[cashAfter] mirror the accounting-shaped results
/// already used by [PublicDemoSummerBonusPayment].
class PublicDemoMonthlyCloseResult {
  const PublicDemoMonthlyCloseResult._({
    required this.state,
    required this.status,
    required this.cashBefore,
    required this.closedMonth,
  });

  final PublicDemoState state;
  final PublicDemoMonthlyCloseStatus status;
  final int cashBefore;
  final int closedMonth;

  bool get isClosed => status == PublicDemoMonthlyCloseStatus.closed;
  int get cashAfter => state.cash;
  int get cashMovement => cashAfter - cashBefore;
}

enum PublicDemoMonthlyCloseStatus { closed, notApplicable }
