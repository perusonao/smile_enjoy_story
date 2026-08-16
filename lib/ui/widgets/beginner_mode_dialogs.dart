import '../../game/game.dart';
import '../theme.dart';
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
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
