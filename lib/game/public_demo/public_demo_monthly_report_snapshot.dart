import 'public_demo_aggregate.dart';
import 'public_demo_monthly_cash_flow.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_sales.dart';

/// Outcome of [PublicDemoMonthlyReportSnapshot.fromAggregate]: whether a
/// safe, current-month result snapshot could actually be produced.
enum PublicDemoMonthlyReportStatus {
  /// [PublicDemoMonthlyReportSnapshot.cashFlow] and the roster fields are
  /// populated — the caller's [PublicDemoMonthlyReportSnapshot.requestedMonth]
  /// matched [PublicDemoState.latestMonthlyCashFlow]'s own `month`.
  ready,

  /// [PublicDemoState.latestMonthlyCashFlow] was `null` — no month has
  /// been closed yet on this aggregate. No snapshot data is produced; this
  /// is a safe no-op, never an error.
  notYetRecorded,

  /// [PublicDemoState.latestMonthlyCashFlow] exists but its `month` does
  /// not match the caller's requested closed month — a no-op close (e.g.
  /// [PublicDemoAggregate.closeApril] called while [PublicDemoState
  /// .isCloseBlocked]) left the *previous* close's figures in place
  /// (Fresh Audit §4/§12). Reading them under the wrong month's label
  /// would misattribute a prior month's result, so no snapshot data is
  /// produced here either.
  staleClosedMonth,
}

/// Read-only, point-in-time capture of one closed month's result, for the
/// Monthly Management Report (SES ISSUE-232 Phase A).
///
/// Every field is read straight from already-authoritative facts
/// [PublicDemoAggregate] already holds:
/// [PublicDemoState.latestMonthlyCashFlow] for finance
/// (Fresh Audit §5.1/§8), and [PublicDemoWorkflowState.assignedEngineerIds]
/// for the current 参画/待機 split (Fresh Audit §7.1). This class never
/// calls an aggregate/state/workflow command, never recomputes a finance,
/// payroll, recruitment, or assignment fact, and never mutates anything —
/// it only reads and re-groups values that already exist. It also never
/// looks at "how many happened this month" (application/interview/order
/// counts) — that information is not derivable from current, non-delta
/// state alone (Fresh Audit §6.2/§7.2) and is explicitly out of scope for
/// Phase A.
class PublicDemoMonthlyReportSnapshot {
  const PublicDemoMonthlyReportSnapshot._({
    required this.status,
    required this.requestedMonth,
    this.cashFlow,
    this.assignedEngineers = const [],
    this.waitingEngineers = const [],
    this.confirmedNextMonthJoinApplicantIds = const {},
  });

  /// Builds a snapshot of [aggregate]'s current, already-committed state,
  /// for the month the caller believes it just closed ([closedMonth]).
  ///
  /// [aggregate] must already be post-close (i.e. the same aggregate a
  /// caller obtained from `_commitAggregate(_game.closeX(...))`-equivalent
  /// code, per Fresh Audit §10) — this factory itself never calls any
  /// close/command method. [closedMonth] is compared against
  /// [PublicDemoState.latestMonthlyCashFlow]'s own `month` so a stale
  /// (no-op close) flow is never misread as [closedMonth]'s result
  /// (Fresh Audit §4/§12) — see [PublicDemoMonthlyReportStatus].
  factory PublicDemoMonthlyReportSnapshot.fromAggregate(
    PublicDemoAggregate aggregate, {
    required int closedMonth,
  }) {
    final flow = aggregate.state.latestMonthlyCashFlow;
    if (flow == null) {
      return PublicDemoMonthlyReportSnapshot._(
        status: PublicDemoMonthlyReportStatus.notYetRecorded,
        requestedMonth: closedMonth,
      );
    }
    if (flow.month != closedMonth) {
      return PublicDemoMonthlyReportSnapshot._(
        status: PublicDemoMonthlyReportStatus.staleClosedMonth,
        requestedMonth: closedMonth,
      );
    }

    final workflow = aggregate.workflow;
    // The company's *current* roster and 参画/待機 split — read exactly as
    // HOME's own Office Stage / 社員タブ already do
    // (`workflow.assignedEngineerIds(month: s.month)` against
    // `workflow.engineers`, which already contains every joined applicant
    // via `withJoinedEngineers` — Fresh Audit §7.1). Deliberately keyed by
    // [PublicDemoAggregate.state]'s own current month, not [closedMonth]:
    // a monthly-close call already advances `state.month` to the month
    // after the one it just closed (Fresh Audit §3), so this reports who
    // is assigned/waiting *now*, at report time — not a recomputation of
    // the closed month's own historical roster.
    final assignedIds = workflow.assignedEngineerIds(
      month: aggregate.state.month,
    );
    final assigned = <PublicDemoEngineerSales>[];
    final waiting = <PublicDemoEngineerSales>[];
    for (final engineer in workflow.engineers) {
      (assignedIds.contains(engineer.id) ? assigned : waiting).add(engineer);
    }

    // "受注済み・翌月入社予定" (Fresh Audit §6.1): the exact single-stage
    // read [may()]'s own existing production handler already uses
    // (`workflow.applicants.where((a) => a.stage ==
    // PublicDemoApplicantStage.juneOrdered)`,
    // public_demo_01_placeholder_screen.dart) — reused verbatim here as a
    // pure filter, not a newly invented pipeline grouping. Broader
    // "内定済み・入社待ち" pre-entry categorization is deliberately left
    // out of Phase A: reproducing it here would duplicate the currently
    // UI/aggregate-local `accepted(applicant)` stage set instead of
    // reading a single already-named authority, which Issue #232's
    // authority rules ("UI/adapter独自の gameplay threshold/判定を作らな
    // い") rule out for this phase.
    final confirmedJoins = <String>{
      for (final applicant in workflow.applicants)
        if (applicant.stage == PublicDemoApplicantStage.juneOrdered)
          applicant.id,
    };

    return PublicDemoMonthlyReportSnapshot._(
      status: PublicDemoMonthlyReportStatus.ready,
      requestedMonth: closedMonth,
      cashFlow: flow,
      assignedEngineers: List.unmodifiable(assigned),
      waitingEngineers: List.unmodifiable(waiting),
      confirmedNextMonthJoinApplicantIds: Set.unmodifiable(confirmedJoins),
    );
  }

  final PublicDemoMonthlyReportStatus status;

  /// The closed month the caller asked for a snapshot of — always set,
  /// even when [status] is not [PublicDemoMonthlyReportStatus.ready].
  final int requestedMonth;

  /// [PublicDemoState.latestMonthlyCashFlow] verbatim, only when [status]
  /// is [PublicDemoMonthlyReportStatus.ready]; `null` otherwise (Fresh
  /// Audit §4: a stale flow is never exposed under the wrong month's
  /// label).
  final PublicDemoMonthlyCashFlow? cashFlow;

  /// Currently participating engineers/employees (`workflow.engineers`
  /// filtered by [PublicDemoWorkflowState.assignedEngineerIds] at the
  /// aggregate's current month). Empty when [status] is not
  /// [PublicDemoMonthlyReportStatus.ready].
  final List<PublicDemoEngineerSales> assignedEngineers;

  /// Currently waiting engineers/employees — the complement of
  /// [assignedEngineers] within `workflow.engineers`. Empty when [status]
  /// is not [PublicDemoMonthlyReportStatus.ready].
  final List<PublicDemoEngineerSales> waitingEngineers;

  /// Applicant ids currently at
  /// [PublicDemoApplicantStage.juneOrdered] — confirmed to join next
  /// month. Empty when [status] is not
  /// [PublicDemoMonthlyReportStatus.ready].
  final Set<String> confirmedNextMonthJoinApplicantIds;

  /// True only when [status] is [PublicDemoMonthlyReportStatus.ready] —
  /// every other field carries real data only in that case.
  bool get isReady => status == PublicDemoMonthlyReportStatus.ready;
}
