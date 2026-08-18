import '../../game/game.dart';
import '../asset_paths.dart';
import '../theme.dart';
import 'expense_breakdown_sheet.dart';
import 'founding_dialogs.dart';

/// Builds the dialog copy for one Phase 3A [BeginnerMilestone] (mirrors
/// `buildFoundingEventDialog` in founding_dialogs.dart, reusing the same
/// [FoundingEventDialog] shape/presentation so Phase 3A's teaching moments
/// look and feel exactly like the March founding tutorial's, not like a
/// second, differently-styled tutorial bolted on top).
///
/// Returns `null` if there's nothing sensible to show yet — defensive only;
/// callers only invoke this for milestones [BeginnerModeEngine.pendingMilestones]
/// already confirmed are true.
FoundingEventDialog? buildBeginnerModeDialog(BeginnerMilestone milestone, GameState state) {
  switch (milestone) {
    case BeginnerMilestone.managementPhaseStarted:
    case BeginnerMilestone.revenueVsCashExplained:
      // Both shown elsewhere (the Prologue completion screen, and the
      // existing first-assignment/first-AR dialogs respectively) — never
      // queued through this path, see
      // [BeginnerModeEngine.weeklyMilestones]'s doc comment.
      return null;

    case BeginnerMilestone.fitReasonViewed:
    case BeginnerMilestone.projectComparisonUsed:
      // Neither is in [BeginnerModeEngine.weeklyMilestones], so this path is
      // never actually invoked for them. [fitReasonViewed] has no
      // celebratory dialog by design — `FitReasonSheet`
      // (fit_reason_sheet.dart) calls [BeginnerModeEngine.markShown]
      // directly from its own open callback instead of queuing through this
      // dialog path, the moment the player opens it. [projectComparisonUsed]
      // has no screen yet (a later Phase 3B-1 PR will do the same for it).
      // Handled here only to keep this switch exhaustive.
      return null;

    case BeginnerMilestone.waitingCostExplained:
      final waitingCount = state.waitingEngineerCount;
      final waitingSalary = BeginnerModeEngine.waitingSalaryTotal(state);
      if (waitingCount == 0) return null;
      return FoundingEventDialog(
        title: '待機社員にも給与が発生しています',
        body:
            '案件に参画していない社員がいても、給与は毎月発生します。\n\n'
            '現在の待機社員: $waitingCount名\n'
            '月間の待機給与: ${formatYen(waitingSalary)}\n\n'
            '参画までの期間が長いほど、会社の現金が減っていきます。営業を優先しましょう。',
      );

    case BeginnerMilestone.firstCollectionCelebrated:
      final closing = state.monthlyClosings.where((c) => c.cashCollected > 0).firstOrNull;
      if (closing == null) return null;
      return FoundingEventDialog(
        title: '🎉 初入金！',
        body:
            '以前発生した売上 ${formatYen(closing.cashCollected)} が入金されました。\n\n'
            '売上が発生してから実際に現金になるまでには、支払サイトぶんの時間差があります。\n'
            'これがSES経営で最初に体感する「売上 ≠ 現金」の瞬間です。',
        celebration: true,
      );

    case BeginnerMilestone.recruitmentTradeoffExplained:
      return const FoundingEventDialog(
        title: '採用のトレードオフ',
        body:
            '社員が増えると、参画できる案件や売上の機会が増えます。\n'
            'その一方で、給与などの固定支出も増え、資金繰りへの負担が大きくなります。\n\n'
            '今の資金状況を見ながら、採用のタイミングを判断しましょう。',
      );

    case BeginnerMilestone.phase3aRecapCelebrated:
      // Real playthrough data only — never a fabricated/hardcoded figure
      // (§ the Phase 3A brief's own instruction on this point). Phase 3B
      // itself is not implemented yet, so this stays a look-back, not a
      // preview of what's next.
      final runwayLevel = FinanceEngine.classifyRunway(FinanceEngine.cashRunwayMonths(state));
      return FoundingEventDialog(
        title: '🎉 初心者経営・前半クリア！',
        body:
            '4月から6月まで、会社を経営してきました。\n\n'
            '累計売上: ${formatYen(state.stats.cumulativeRevenue)}\n'
            '累計入金: ${formatYen(state.stats.cumulativeCashCollected)}\n'
            '月末決算を${state.monthlyClosings.length}回経験しました\n'
            '現在の資金状況: ${RunwayIndicator.qualitativeLabelFor(runwayLevel)}\n\n'
            '売上の発生・入金・月末支払い・資金繰りの基本を、実際に経営しながら経験しました。\n'
            'この感覚を活かして、これからも会社を経営していきましょう。',
        celebration: true,
        imageAssetPath: AssetPaths.eventCompanyManagement,
        category: '会社経営',
      );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
