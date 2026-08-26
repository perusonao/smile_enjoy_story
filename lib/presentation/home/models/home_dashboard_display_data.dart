import 'package:flutter/foundation.dart' show immutable;

import '../../../game/public_demo/public_demo_month_label.dart';
import '../../../game/public_demo/public_demo_revenue.dart';
import '../../../game/public_demo/public_demo_state.dart';

/// The month's single "what to do now" line.
///
/// HOME-RUNTIME-2A: this `switch` **moved** here verbatim from
/// `PublicDemo01PlaceholderScreen.monthGoal()` — it was not copied. The
/// legacy `今月やること` card that used to render it is deleted in the same
/// change, so there is exactly one month-goal table in the app and exactly
/// one place on screen that shows it.
///
/// [month] is the authoritative internal month (4-15), passed straight
/// through from [PublicDemoState.month]; this does not reinterpret or
/// re-map it.
String _monthGoalTextFor(int month) => switch (month) {
  4 => '待機中の技術者を営業し、5月の案件参画を決めましょう',
  5 => '応募者を採用し、入社前から6月の案件獲得を目指しましょう',
  6 => '翌月の発注を確認し、7月も稼働できる状態を作りましょう',
  _ => '今月の経営状況を確認し、翌月への準備をしましょう',
};

/// Read-only presentation projection of the home dashboard's headline
/// figures (HOME-UI-1C), sourced entirely from [PublicDemoState].
///
/// This is a DISPLAY PROJECTION, not authoritative state: every field below
/// is computed once, at construction time, from an already-authoritative
/// [PublicDemoState] snapshot via [fromPublicDemoState]. Nothing here
/// mutates [PublicDemoState], recomputes accounting/workflow rules, or
/// becomes a second source of truth for cash, revenue, or headcount — see
/// each field's own doc for exactly which authoritative field/formula backs
/// it. [fromPublicDemoState] deliberately takes only [PublicDemoState] (not
/// `PublicDemoWorkflowState`), so applicant/pre-entry/workflow facts have no
/// path into this projection at all.
///
/// HOME-RUNTIME-2A widened the projection by exactly three read-only
/// fields ([waitingEmployeeCount], [salesRemaining], [monthGoalText]) so the
/// merged KPI can show everything the deleted legacy stat row showed. The
/// boundary is deliberately unchanged in the other direction:
/// `financialStatus` and `fiscalYearCompleted` are **not** projected. HOME
/// therefore structurally cannot render a financial verdict, and terminal
/// composition (shortage / bankruptcy / March failure / fiscal success)
/// stays with the authoritative owner, `PublicDemo01PlaceholderScreen`.
@immutable
class HomeDashboardDisplayData {
  /// The three HOME-RUNTIME-2A fields default rather than being `required`
  /// on purpose: [fromPublicDemoState] — the only production construction
  /// path — always supplies all three from the authority, while existing
  /// hand-built fixtures that predate them keep compiling and asserting
  /// exactly what they asserted before.
  const HomeDashboardDisplayData({
    required this.year,
    required this.monthLabel,
    required this.cash,
    required this.revenue,
    required this.pendingRevenue,
    required this.employeeCount,
    required this.assignedEmployeeCount,
    this.waitingEmployeeCount = 0,
    this.salesRemaining = 0,
    this.monthGoalText = '',
  });

  /// Fiscal year number. Public Demo 0.1 models exactly one fiscal year
  /// (internal months 4-15: April through the following March) and has no
  /// authoritative multi-year field to read — this is a fixed constant
  /// reflecting that scope, not a value HOME invents or tracks on its own.
  final int year;

  /// Calendar month label (e.g. "4月"), sourced verbatim from the existing
  /// authoritative [publicDemoMonthLabel] conversion. HOME does not
  /// reimplement the internal-month (4-15) -> calendar-month mapping.
  ///
  /// HOME-RUNTIME-2A: `MonthHeaderBar` is now the *only* month display on
  /// the runtime screen — the duplicate `N月` headline it competed with is
  /// deleted.
  final String monthLabel;

  /// Current cash balance — [PublicDemoState.cash] verbatim. Never
  /// recomputed here from opening cash, collections, or expenses.
  final int cash;

  /// This month's billing from currently assigned engineers, computed via
  /// the same [PublicDemoRevenue.monthlyRevenueForAssignedCount] formula
  /// production uses to book revenue at month-end (see
  /// `PublicDemoRevenuePayment.apply`), applied to the current
  /// [PublicDemoState.engineersAssigned] snapshot. This calls the existing
  /// authoritative formula for display — it does not define a new one.
  final int revenue;

  /// Revenue already recognized but not yet collected —
  /// [PublicDemoState.pendingRevenue] verbatim. Never folded into [cash]:
  /// under the existing 30-day AR contract this becomes cash only at a
  /// future month-end close, which this projection does not simulate.
  final int pendingRevenue;

  /// Current employee headcount — [PublicDemoState.engineerCount] verbatim.
  /// This is the same finance-side authoritative count already used to
  /// derive [PublicDemoState.engineersWaiting]/[PublicDemoState.engineersAssigned].
  /// Applicants/candidates live only in `PublicDemoWorkflowState.applicants`,
  /// which this projection never reads, so they cannot leak into this count.
  final int employeeCount;

  /// Employees currently assigned to a project —
  /// [PublicDemoState.engineersAssigned] verbatim, the same field
  /// `PublicDemoWorkflowState.assignedEngineerIds`'s own doc names as the
  /// single SSOT Revenue/Growth/training eligibility must all agree on.
  /// Waiting employees ([PublicDemoState.engineersWaiting]) are never
  /// included.
  final int assignedEmployeeCount;

  /// Employees not on a project — [PublicDemoState.engineersWaiting]
  /// verbatim (HOME-RUNTIME-2A). Deliberately read, never derived as
  /// `employeeCount - assignedEmployeeCount`: the authority owns the
  /// relationship between the three counts, and a projection that
  /// recomputed one of them could quietly disagree with it.
  final int waitingEmployeeCount;

  /// Sales slots still available this month — [PublicDemoState.salesRemaining]
  /// verbatim (HOME-RUNTIME-2A). That is an existing authoritative getter
  /// over the `salesCapacity`/`salesUsed` pair, not a formula this
  /// projection defines. Displaying the number is all HOME does with it:
  /// the `salesRemaining > 0` guards that actually gate the interview
  /// commands stay exactly where they already are, at their call sites.
  final int salesRemaining;

  /// The month's goal line (HOME-RUNTIME-2A), from the relocated
  /// [_monthGoalTextFor] table — see that function's doc for why this is a
  /// move rather than a copy. Text only: this projection carries no action,
  /// no ranking, and no callback, so HOME can state the goal but cannot act
  /// on it.
  final String monthGoalText;

  /// Builds the display projection from the current authoritative Public
  /// Demo finance state. Pure and read-only: [state] is only ever read,
  /// never mutated or copied-with.
  factory HomeDashboardDisplayData.fromPublicDemoState(PublicDemoState state) {
    return HomeDashboardDisplayData(
      year: 1,
      monthLabel: publicDemoMonthLabel(state.month),
      cash: state.cash,
      revenue: PublicDemoRevenue.monthlyRevenueForAssignedCount(
        state.engineersAssigned,
      ),
      pendingRevenue: state.pendingRevenue,
      employeeCount: state.engineerCount,
      assignedEmployeeCount: state.engineersAssigned,
      waitingEmployeeCount: state.engineersWaiting,
      salesRemaining: state.salesRemaining,
      monthGoalText: _monthGoalTextFor(state.month),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeDashboardDisplayData &&
      other.year == year &&
      other.monthLabel == monthLabel &&
      other.cash == cash &&
      other.revenue == revenue &&
      other.pendingRevenue == pendingRevenue &&
      other.employeeCount == employeeCount &&
      other.assignedEmployeeCount == assignedEmployeeCount &&
      other.waitingEmployeeCount == waitingEmployeeCount &&
      other.salesRemaining == salesRemaining &&
      other.monthGoalText == monthGoalText;

  @override
  int get hashCode => Object.hash(
    year,
    monthLabel,
    cash,
    revenue,
    pendingRevenue,
    employeeCount,
    assignedEmployeeCount,
    waitingEmployeeCount,
    salesRemaining,
    monthGoalText,
  );
}
