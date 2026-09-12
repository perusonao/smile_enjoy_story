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
    required this.isFiscalYearCompleted,
    required this.isFinanciallyTerminal,
    required this.nextActionHeadline,
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

  /// Codex Broad Review P2 (PR #237): [PublicDemoState.fiscalYearCompleted]
  /// verbatim, read from the same already-committed aggregate the snapshot
  /// itself was built from — the existing authority
  /// [PublicDemoYearEndResultCard]'s own gate already uses, reused here
  /// verbatim (no new judgment). True only when this close genuinely
  /// completed the fiscal year in success; always false for an ordinary
  /// month, and false for a March close that instead produced
  /// [isFinanciallyTerminal].
  final bool isFiscalYearCompleted;

  /// Codex Broad Review P2 (PR #237): [PublicDemoState.isFinanciallyTerminal]
  /// verbatim — the same existing authority `_bankruptcyTerminalCard`'s own
  /// gate already uses. True for bankruptcy or a March cash-shortage
  /// failure; mutually exclusive with [isFiscalYearCompleted] by
  /// construction ([PublicDemoState.completeFiscalYear]'s own doc).
  final bool isFinanciallyTerminal;

  /// SES ISSUE-250: the single next-month decision to consider, or `null`
  /// when none is currently eligible. This is never a new judgment — the
  /// caller reads it verbatim from its own already-existing
  /// `_recommendedActionSlot` getter (`HomeRecommendedActionAvailable
  /// .candidate.action.headline`), the exact same HOME-RUNTIME-2C authority
  /// that already decides HOME's own recommended-action slot and already
  /// gates on `PublicDemoState.isCloseBlocked` (bankruptcy, a March
  /// cash-shortage failure, or fiscal-year completion) before ever
  /// producing a candidate — so a terminal/year-end close reaches this
  /// report with `null` here for exactly the same reason HOME's own slot is
  /// suppressed then, never a fabricated "no action" sentence. This class
  /// never invokes the action (no button is rendered for it here) — it only
  /// displays the same headline text HOME would show for the same
  /// candidate, so nothing here can mutate any aggregate/state/workflow.
  final String? nextActionHeadline;

  /// Builds this projection from [snapshot] (which must already be
  /// [PublicDemoMonthlyReportSnapshot.isReady] — callers gate on that
  /// before ever constructing this class, exactly like
  /// [PublicDemoYearEndDisplayData] is only ever built once
  /// `fiscalYearCompleted` is confirmed), [applicants] — the same
  /// aggregate's own `workflow.applicants`, used only to resolve
  /// [nextMonthJoinNames] — and [isFiscalYearCompleted]/
  /// [isFinanciallyTerminal], read by the caller from that same
  /// already-committed aggregate's `state` (Codex Broad Review P2, PR
  /// #237): neither is derivable from the snapshot alone, and both are
  /// already-existing authority, never recomputed here.
  factory PublicDemoMonthlyReportDisplayData.fromSnapshot(
    PublicDemoMonthlyReportSnapshot snapshot, {
    required List<PublicDemoApplicant> applicants,
    required bool isFiscalYearCompleted,
    required bool isFinanciallyTerminal,
    required String? nextActionHeadline,
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
      isFiscalYearCompleted: isFiscalYearCompleted,
      isFinanciallyTerminal: isFinanciallyTerminal,
      nextActionHeadline: nextActionHeadline,
    );
  }
}

/// A short, fact-based comment attributed to ひより, for the Monthly
/// Management Report — the exact same design precedent as
/// [publicDemoYearEndHiyoriSummary] (SES YEAR-END-PHASE-1): every sentence
/// restates a field already on [data], AI-generated text is never used, and
/// nothing here decides what the dialog shows — this only chooses which
/// already-true sentence fits. Branches only on the safe authorities Issue
/// #232's Phase B scope names: [PublicDemoMonthlyReportDisplayData
/// .cashDelta] (`< 0` / `> 0` / `== 0`, mirroring [PublicDemoState
/// .netCashMovement]'s own sign, not a new threshold),
/// [PublicDemoMonthlyReportDisplayData.waitingCount] `> 0`, and
/// [PublicDemoMonthlyReportDisplayData.assignedCount] `> 0` — plus, since
/// Codex Broad Review P2 (PR #237), [PublicDemoMonthlyReportDisplayData
/// .isFinanciallyTerminal]/[PublicDemoMonthlyReportDisplayData
/// .isFiscalYearCompleted], both already-existing authority (never a new
/// threshold) — plus, since SES ISSUE-250,
/// [PublicDemoMonthlyReportDisplayData.netIncome]'s sign (黒字/赤字) and
/// [PublicDemoMonthlyReportDisplayData.nextMonthJoinNames] (already resolved
/// by the presenter). Never comments on an in-month delta (application/
/// interview/order count, or "参画人数が増えた") — no such history is
/// available (Phase A §6.2/§7.2), so no such claim is made.
///
/// Codex Broad Review P2 (PR #237): once this close made the game terminal
/// (bankruptcy/March cash-shortage failure) or genuinely completed the
/// fiscal year, [PublicDemoState.isCloseBlocked] is true and there is no
/// next month to act in — `_bankruptcyTerminalCard`/`PublicDemoYearEndResultCard`
/// take over immediately after this dialog is dismissed (§7 of this Issue's
/// own Fresh Audit). Recommending "営業タブから案件参画を進めましょう" here
/// would send the player toward a Sales tab whose own next-action slot is
/// itself already suppressed for the same [isCloseBlocked] reason
/// (`HomeRecommendedActionSuppressed`) — so this branch is checked first
/// and replaces that recommendation with a backward-looking, terminal-
/// appropriate line instead. The cash-movement sentence above is left
/// exactly as-is in every case (still a true fact about the month that just
/// closed); only this second sentence's content changes.
/// SES ISSUE-250: two sentences were added to the original ISSUE-232 Phase B
/// branches below (cash delta / terminal-or-roster), both still restating an
/// already-computed fact on [data] rather than any new judgment —
/// [PublicDemoMonthlyReportDisplayData.netIncome]'s own sign (黒字/赤字,
/// already a plain derived getter on [PublicDemoMonthlyCashFlow] per Phase
/// A) and [PublicDemoMonthlyReportDisplayData.nextMonthJoinNames] (already
/// resolved by the presenter, unchanged). Both stay short (one clause each)
/// and both are skipped, not fabricated, when they would have nothing true
/// to say: `netIncome == 0` adds no sentence, and the next-month-join
/// sentence never appears once the game is terminal/year-end complete (the
/// same reason [PublicDemoMonthlyReportDisplayData.nextActionHeadline] is
/// `null` there — "次月" no longer exists).
String publicDemoMonthlyReportHiyoriComment(
  PublicDemoMonthlyReportDisplayData data,
) {
  final sentences = <String>[];

  // SES ISSUE-250: the generic advice clauses this sentence used to carry
  // ("支出とのバランスに注意しましょう。"/"良いペースです。") were dropped in
  // favor of the more concrete 黒字/赤字 sentence directly below — both a
  // One-Screen density saving and less repetitive copy, and no existing
  // assertion (`test/ui/public_demo/public_demo_monthly_report_display_data_test.dart`
  // group 3) named that exact wording.
  if (data.cashDelta < 0) {
    sentences.add('今月は資金が${formatYen(-data.cashDelta)}減りました。');
  } else if (data.cashDelta > 0) {
    sentences.add('今月は資金が${formatYen(data.cashDelta)}増えました。');
  } else {
    sentences.add('今月は資金の増減がありませんでした。');
  }

  if (data.netIncome > 0) {
    sentences.add('今月の収支は黒字（純利益${formatYen(data.netIncome)}）でした。');
  } else if (data.netIncome < 0) {
    sentences.add('今月の収支は赤字（純損失${formatYen(-data.netIncome)}）でした。');
  }

  if (data.isFinanciallyTerminal) {
    sentences.add('今月の結果を振り返り、次の経営に活かしましょう。');
  } else if (data.isFiscalYearCompleted) {
    sentences.add('1年間の経営結果を確認しましょう。');
  } else if (data.waitingCount > 0) {
    sentences.add(
      '待機中のメンバーが${data.waitingCount}名います。営業タブから案件参画を進めましょう。',
    );
  } else if (data.assignedCount > 0) {
    sentences.add('現在、全員が案件に参画しています。');
  }

  if (!data.isFinanciallyTerminal &&
      !data.isFiscalYearCompleted &&
      data.nextMonthJoinNames.isNotEmpty) {
    final names = data.nextMonthJoinNames.map((name) => '$nameさん').join('・');
    sentences.add('来月は$namesが入社予定です。');
  }

  return sentences.join('');
}
