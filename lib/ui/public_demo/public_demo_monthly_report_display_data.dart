import '../../game/public_demo/public_demo_monthly_report_snapshot.dart';
import '../../game/public_demo/public_demo_recruitment.dart';
import '../theme.dart' show formatYen;

/// SES ISSUE-232 Phase B: a pure, read-only presentation projection of one
/// [PublicDemoMonthlyReportSnapshot] (Phase A's authority), built once
/// [PublicDemoMonthlyReportSnapshot.isReady] is confirmed by the caller —
/// see [PublicDemoMonthlyReportDialog]'s own doc for the call site that
/// gates this.
///
/// Every field here is either read verbatim from
/// [PublicDemoMonthlyReportSnapshot.cashFlow] (itself
/// [PublicDemoState.latestMonthlyCashFlow] verbatim, per Phase A) or is a
/// plain, already-existing derived getter on that same class
/// ([PublicDemoMonthlyCashFlow.netCashMovement],
/// [PublicDemoMonthlyCashFlow.totalOutflow],
/// [PublicDemoMonthlyCashFlow.netIncome]) — nothing here recomputes
/// Finance/Payroll/Recruitment/Assignment facts, and nothing here invents a
/// new economic threshold. [assignedCount]/[waitingCount] are plain list
/// lengths of [PublicDemoMonthlyReportSnapshot.assignedEngineers]/
/// [PublicDemoMonthlyReportSnapshot.waitingEngineers].
/// [nextMonthJoinNames] is a display-only join between
/// [PublicDemoMonthlyReportSnapshot.confirmedNextMonthJoinApplicantIds] and
/// the same already-authoritative applicant records the snapshot itself
/// read those ids from ([applicants], the caller's own
/// `workflow.applicants` on the same post-close aggregate) — no new
/// judgment, purely a name lookup for already-decided ids.
///
/// Deliberately excludes every field Issue #232's Fresh Audit/Phase B scope
/// names as unsafe: no in-month application/interview/order count, no
/// "今月の新規参画人数", no month-over-month participation delta. See this
/// class's own Phase B Result Report for the full excluded-field list.
class PublicDemoMonthlyReportDisplayData {
  const PublicDemoMonthlyReportDisplayData({
    required this.closedMonth,
    required this.openingCash,
    required this.closingCash,
    required this.cashDelta,
    required this.revenue,
    required this.cashReceived,
    required this.receivables,
    required this.totalExpenses,
    required this.salaryPaid,
    required this.fixedCostsPaid,
    required this.bonusPaid,
    required this.trainingCost,
    required this.recruitmentCost,
    required this.netIncome,
    required this.assignedCount,
    required this.waitingCount,
    required this.nextMonthJoinNames,
  });

  /// The internal month number (4-15) this report describes — always the
  /// same value the caller passed as
  /// [PublicDemoMonthlyReportSnapshot.requestedMonth].
  final int closedMonth;

  final int openingCash;
  final int closingCash;

  /// [closingCash] - [openingCash] — [PublicDemoMonthlyCashFlow
  /// .netCashMovement] verbatim.
  final int cashDelta;

  final int revenue;
  final int cashReceived;
  final int receivables;

  /// [PublicDemoMonthlyCashFlow.totalOutflow] verbatim — the sum of every
  /// field below it.
  final int totalExpenses;
  final int salaryPaid;
  final int fixedCostsPaid;
  final int bonusPaid;
  final int trainingCost;
  final int recruitmentCost;

  /// [PublicDemoMonthlyCashFlow.netIncome] verbatim (`revenue -
  /// totalOutflow`) — an accounting-style result, deliberately distinct
  /// from [cashDelta] (see that getter's own doc for why the two figures
  /// legitimately diverge).
  final int netIncome;

  /// [PublicDemoMonthlyReportSnapshot.assignedEngineers]'s length.
  final int assignedCount;

  /// [PublicDemoMonthlyReportSnapshot.waitingEngineers]'s length.
  final int waitingCount;

  /// Names of applicants in
  /// [PublicDemoMonthlyReportSnapshot.confirmedNextMonthJoinApplicantIds],
  /// in that set's iteration order. Never a new pipeline judgment — see
  /// this class's own doc.
  final List<String> nextMonthJoinNames;

  /// Builds this projection from [snapshot] (which must already be
  /// [PublicDemoMonthlyReportSnapshot.isReady] — callers gate on that
  /// before ever constructing this class, exactly like
  /// [PublicDemoYearEndDisplayData] is only ever built once
  /// `fiscalYearCompleted` is confirmed) and [applicants] — the same
  /// aggregate's own `workflow.applicants`, used only to resolve
  /// [nextMonthJoinNames].
  factory PublicDemoMonthlyReportDisplayData.fromSnapshot(
    PublicDemoMonthlyReportSnapshot snapshot, {
    required List<PublicDemoApplicant> applicants,
  }) {
    final flow = snapshot.cashFlow!;
    final nameById = {
      for (final applicant in applicants) applicant.id: applicant.name,
    };
    return PublicDemoMonthlyReportDisplayData(
      closedMonth: snapshot.requestedMonth,
      openingCash: flow.openingCash,
      closingCash: flow.closingCash,
      cashDelta: flow.netCashMovement,
      revenue: flow.revenue,
      cashReceived: flow.cashReceived,
      receivables: flow.receivables,
      totalExpenses: flow.totalOutflow,
      salaryPaid: flow.salaryPaid,
      fixedCostsPaid: flow.fixedCostsPaid,
      bonusPaid: flow.bonusPaid,
      trainingCost: flow.trainingCost,
      recruitmentCost: flow.recruitmentCost,
      netIncome: flow.netIncome,
      assignedCount: snapshot.assignedEngineers.length,
      waitingCount: snapshot.waitingEngineers.length,
      nextMonthJoinNames: [
        for (final id in snapshot.confirmedNextMonthJoinApplicantIds)
          nameById[id] ?? id,
      ],
    );
  }
}

/// A short (1-2 sentence), fact-based comment attributed to ひより, for the
/// Monthly Management Report — the exact same design precedent as
/// [publicDemoYearEndHiyoriSummary] (SES YEAR-END-PHASE-1): every sentence
/// restates a field already on [data], AI-generated text is never used, and
/// nothing here decides what the dialog shows — this only chooses which
/// already-true sentence fits. Branches only on the safe authorities Issue
/// #232's Phase B scope names: [PublicDemoMonthlyReportDisplayData
/// .cashDelta] (`< 0` / `> 0` / `== 0`, mirroring [PublicDemoState
/// .netCashMovement]'s own sign, not a new threshold),
/// [PublicDemoMonthlyReportDisplayData.waitingCount] `> 0`, and
/// [PublicDemoMonthlyReportDisplayData.assignedCount] `> 0`. Never
/// comments on an in-month delta (application/interview/order count, or
/// "参画人数が増えた") — no such history is available (Phase A §6.2/§7.2),
/// so no such claim is made.
String publicDemoMonthlyReportHiyoriComment(
  PublicDemoMonthlyReportDisplayData data,
) {
  final sentences = <String>[];

  if (data.cashDelta < 0) {
    sentences.add(
      '今月は資金が${formatYen(-data.cashDelta)}減りました。支出とのバランスに注意しましょう。',
    );
  } else if (data.cashDelta > 0) {
    sentences.add('今月は資金が${formatYen(data.cashDelta)}増えました。良いペースです。');
  } else {
    sentences.add('今月は資金の増減がありませんでした。');
  }

  if (data.waitingCount > 0) {
    sentences.add(
      '待機中のメンバーが${data.waitingCount}名います。営業タブから案件参画を進めましょう。',
    );
  } else if (data.assignedCount > 0) {
    sentences.add('現在、全員が案件に参画しています。');
  }

  return sentences.join('');
}
