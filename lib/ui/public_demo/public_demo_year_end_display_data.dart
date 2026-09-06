import '../../game/public_demo/public_demo_engineer_runtime.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../../game/public_demo/public_demo_state.dart';
import '../theme.dart' show formatYen;

/// SES YEAR-END-PHASE-1: one founding engineer's capability at company
/// founding vs. at fiscal-year end.
///
/// [engineerId] and [name] come from [publicDemoInitialEngineers] — the same
/// founding roster Issue #167's founder follow-up already treats as
/// authoritative (`publicDemoFounderEngineerIds`). [initialCapability] comes
/// from [publicDemoInitialEngineerRuntimes] (this founder's capability the
/// moment the company was founded); [currentCapability] is read from the
/// live [PublicDemoState.engineerRuntimes] at fiscal-year end. Neither value
/// is recomputed or estimated here — both are the same
/// `actualCapability` getter every other Public Demo screen already reads.
class PublicDemoFounderGrowthDisplay {
  const PublicDemoFounderGrowthDisplay({
    required this.engineerId,
    required this.name,
    required this.initialCapability,
    required this.currentCapability,
  });

  final String engineerId;
  final String name;
  final int initialCapability;
  final int currentCapability;

  /// Positive: grew since founding. Zero: unchanged. Never negative under
  /// current growth rules, but this does not assume that — it is a plain
  /// subtraction of two authoritative snapshots.
  int get capabilityDelta => currentCapability - initialCapability;
}

/// SES YEAR-END-PHASE-1 (accounting tab's existing "第1期終了" area): a
/// read-only presentation projection of the facts a completed fiscal year
/// already makes available, built once from an authoritative
/// [PublicDemoState] snapshot.
///
/// Every field here is either read verbatim from [PublicDemoState] (or the
/// existing founding-roster constants [publicDemoInitialEngineers] /
/// [publicDemoInitialEngineerRuntimes]) or is a plain arithmetic difference
/// between two such values ([cashDelta], [PublicDemoFounderGrowthDisplay
/// .capabilityDelta]). Nothing here is estimated, aggregated across months
/// the state does not retain, or otherwise fabricated — see the Year-End
/// Phase 1 implementation result report for the full authority audit this
/// class deliberately stays inside of. In particular, this class carries no
/// annual revenue, sales-activity count, crisis count, or recovery count:
/// [PublicDemoState] does not retain any of those as a year-spanning total,
/// so none of them appear here.
class PublicDemoYearEndDisplayData {
  const PublicDemoYearEndDisplayData({
    required this.startingCash,
    required this.finalCash,
    required this.finalEmployeeCount,
    required this.annualHireCount,
    required this.finalParticipatingCount,
    required this.finalWaitingCount,
    required this.founderGrowth,
  });

  /// Cash at company founding — [PublicDemoState.aprilStart]'s own `cash`,
  /// the exact same canonical constant [PublicDemoAggregate.initial] (and
  /// therefore every fresh/replayed playthrough, including the "4月から
  /// もう一度" CTA this screen offers) starts from. Not a separately tracked
  /// field: Public Demo 0.1 has exactly one starting cash value, so reading
  /// it directly here can never drift from what a replay would show.
  final int startingCash;

  /// Cash at fiscal-year end — [PublicDemoState.cash] verbatim.
  final int finalCash;

  /// Net change in cash across the fiscal year, computed for display only —
  /// [finalCash] minus [startingCash]. Never itself stored or reused as a
  /// finance authority.
  int get cashDelta => finalCash - startingCash;

  /// The company's total headcount at fiscal-year end —
  /// [PublicDemoState.engineerCount] **plus** [PublicDemoState.adminCount],
  /// the same "社員" (whole-company, not engineer-only) composition
  /// [HomeDashboardDisplayData.totalEmployeeCount] already uses (Issue
  /// #122's own distinction between 社員/total and 技術者/engineer-only).
  final int finalEmployeeCount;

  /// Applicants hired at any point during the fiscal year —
  /// [PublicDemoState.joinedApplicantIds]'s length. That field is itself a
  /// derived projection of [PublicDemoWorkflowState]'s own
  /// `hasJoined`-applicant list (see that field's own doc), and Public Demo
  /// 0.1 only ever accepts hires once, during the May-to-June close — so
  /// this count is exactly this year's hiring total, not a running total
  /// across years.
  final int annualHireCount;

  /// Engineers assigned to a project at fiscal-year end —
  /// [PublicDemoState.engineersAssigned] verbatim.
  final int finalParticipatingCount;

  /// Engineers not on a project at fiscal-year end —
  /// [PublicDemoState.engineersWaiting] verbatim.
  final int finalWaitingCount;

  /// Founding-engineer growth, one entry per [publicDemoInitialEngineers]
  /// roster member (currently the two founders, `eng-01`/`eng-02`), in that
  /// roster's own order.
  final List<PublicDemoFounderGrowthDisplay> founderGrowth;

  /// Builds this projection from the authoritative fiscal-year-end
  /// [state]. Pure and read-only — [state] is never mutated.
  factory PublicDemoYearEndDisplayData.fromPublicDemoState(
    PublicDemoState state,
  ) {
    final nameById = {
      for (final engineer in publicDemoInitialEngineers)
        engineer.id: engineer.name,
    };
    return PublicDemoYearEndDisplayData(
      startingCash: PublicDemoState.aprilStart().cash,
      finalCash: state.cash,
      finalEmployeeCount: state.engineerCount + state.adminCount,
      annualHireCount: state.joinedApplicantIds.length,
      finalParticipatingCount: state.engineersAssigned,
      finalWaitingCount: state.engineersWaiting,
      founderGrowth: [
        for (final baseline in publicDemoInitialEngineerRuntimes)
          PublicDemoFounderGrowthDisplay(
            engineerId: baseline.engineerId,
            name: nameById[baseline.engineerId] ?? baseline.engineerId,
            initialCapability: baseline.actualCapability,
            currentCapability:
                state.runtimeForOrNull(baseline.engineerId)?.actualCapability ??
                baseline.actualCapability,
          ),
      ],
    );
  }
}

/// A short, fact-based year-end line attributed to ひより (the existing
/// navigator character's voice already used elsewhere in Public Demo, e.g.
/// "ひよりからのご案内" dialogs) — never the HOME navigator widget/state
/// itself, which stays untouched (HOME is frozen). Every sentence here is a
/// direct restatement of a field already on [data]; nothing is invented
/// (no revenue, no sales-activity count, no crisis/recovery count) and
/// nothing here decides what shows — this only chooses which already-true
/// sentence fits.
String publicDemoYearEndHiyoriSummary(PublicDemoYearEndDisplayData data) {
  final sentences = <String>[];

  final delta = data.cashDelta;
  if (delta > 0) {
    sentences.add(
      '資金は${formatYen(data.startingCash)}から${formatYen(data.finalCash)}に、'
      '${formatYen(delta)}増えて一年を終えました。',
    );
  } else if (delta < 0) {
    sentences.add(
      '資金は${formatYen(data.startingCash)}から${formatYen(data.finalCash)}に、'
      '${formatYen(-delta)}減って一年を終えました。',
    );
  } else {
    sentences.add(
      '資金は${formatYen(data.startingCash)}のまま、増減なく一年を終えました。',
    );
  }

  sentences.add(
    data.annualHireCount > 0
        ? 'この一年で${data.annualHireCount}名を新たに採用しました。'
        : 'この一年、新規採用はありませんでした。',
  );

  sentences.add(
    '現在、${data.finalParticipatingCount}名が案件に参画し、'
    '${data.finalWaitingCount}名が待機中です。',
  );

  final grown = data.founderGrowth.where((f) => f.capabilityDelta > 0).toList();
  if (grown.isNotEmpty) {
    final names = grown.map((f) => f.name).join('・');
    sentences.add('創業メンバーの$namesは、入社時から着実に力をつけています。');
  } else {
    sentences.add('創業メンバーの実力は、入社時からまだ大きくは変わっていません。');
  }

  return sentences.join('');
}
