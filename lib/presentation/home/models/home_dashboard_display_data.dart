import 'package:flutter/foundation.dart' show immutable;

import '../../../game/public_demo/public_demo_month_label.dart';
import '../../../game/public_demo/public_demo_revenue.dart';
import '../../../game/public_demo/public_demo_state.dart';

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
@immutable
class HomeDashboardDisplayData {
  const HomeDashboardDisplayData({
    required this.year,
    required this.monthLabel,
    required this.cash,
    required this.revenue,
    required this.pendingRevenue,
    required this.employeeCount,
    required this.assignedEmployeeCount,
  });

  /// Fiscal year number. Public Demo 0.1 models exactly one fiscal year
  /// (internal months 4-15: April through the following March) and has no
  /// authoritative multi-year field to read — this is a fixed constant
  /// reflecting that scope, not a value HOME invents or tracks on its own.
  final int year;

  /// Calendar month label (e.g. "4月"), sourced verbatim from the existing
  /// authoritative [publicDemoMonthLabel] conversion. HOME does not
  /// reimplement the internal-month (4-15) -> calendar-month mapping.
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
      other.assignedEmployeeCount == assignedEmployeeCount;

  @override
  int get hashCode => Object.hash(
    year,
    monthLabel,
    cash,
    revenue,
    pendingRevenue,
    employeeCount,
    assignedEmployeeCount,
  );
}
