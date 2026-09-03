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
///
/// SES-FIRST-FUN-YEAR-P0-1 (Issue #125): this line is a fallback — HOME's
/// one recommended-action slot only ever shows it via
/// `HomeRecommendedActionNone` (`recommended_action_section.dart`), i.e.
/// exactly when the owner found no higher-priority actionable candidate
/// (see `HomeRecommendedActionKind`'s presentation-priority bands). A
/// month whose only truthfully-describable "watch this" fact is already an
/// existing Recommended Action candidate — July's `summerBonusDecision`,
/// the `raiseRequest` available from month 6, or a genuinely-eligible
/// Recovery reassignment — therefore never needs restating here: whenever
/// one of those is actually eligible, this fallback simply does not
/// render.
///
/// July-March's entries below instead point at each month's own
/// *secondary* watch-point, grounded only in facts already visible
/// elsewhere on HOME (cash, waiting/assigned headcount, sales slots) plus
/// one existing, always-true mechanic boundary:
/// `PublicDemoRecoveryEligibility.isMonthEligible` genuinely spans July
/// (7) through February (14) — no later than that, since March closes the
/// fiscal year (`PublicDemoState.completeFiscalYear`, month 15).
///
/// Deliberately absent: any mention of recruitment media or of renewing an
/// assignment. Recruitment media's own UI never re-appears after May, and
/// `PublicDemoState.engineerCount` is never increased by any transition
/// past `advanceToJune` (month 5 -> 6) — so telling a July-September
/// player to "finish hiring" would point at a structurally unreachable
/// path (the exact thing Issue #125 says not to reopen). Likewise, an
/// assigned engineer stays on the same project through fiscal year end
/// (`PublicDemoWorkflowState`'s "一度案件参画が成立した社員は、第1期終了まで同じ案件へ継続参画する"
/// decision) — Public Demo 0.1 has no per-month renewal choice to point at.
String _monthGoalTextFor(int month) => switch (month) {
  4 => '待機中の技術者を営業し、5月の案件参画を決めましょう',
  5 => '応募者を採用し、入社前から6月の案件獲得を目指しましょう',
  6 => '翌月の発注を確認し、7月も稼働できる状態を作りましょう',
  7 => '夏季賞与の対応を終えたら、待機中の技術者がいれば案件復帰できないか確認しましょう',
  8 => '今月の営業活動の状況と、待機中の技術者がいないか確認しましょう',
  9 => '下半期に入りました。資金の増減と案件の稼働状況を見直しましょう',
  10 => '案件の稼働状況を確認し、待機中の技術者がいれば案件復帰を検討しましょう',
  11 => '資金の増減を確認し、年度末までの運転資金を意識しましょう',
  12 => '年内最後の月です。ここまでの稼働状況と資金の推移を振り返りましょう',
  13 => '年度末まで残り3か月。案件と待機中の技術者の状況を点検しましょう',
  14 => '待機中の技術者を案件へ戻せる最後の月です。復帰できないか確認しましょう',
  15 => '年度末の月です。今月の締めで一年間の経営結果が確定します',
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
