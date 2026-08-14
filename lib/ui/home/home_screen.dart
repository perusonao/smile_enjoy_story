import 'package:flutter/material.dart';

import '../../app/game_controller.dart';
import '../../app/game_scope.dart';
import '../../app/nav_scope.dart';
import '../../game/game.dart';
import '../engineers/engineer_detail_screen.dart';
import '../main_shell.dart';
import '../projects/interview_results_screen.dart';
import '../theme.dart';
import '../widgets/expense_breakdown_sheet.dart';
import '../widgets/founding_dialogs.dart';
import '../widgets/monthly_closing_dialog.dart';
import '../widgets/stat_tile.dart';
import '../widgets/task_card.dart';
import '../widgets/week_summary_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _onNextWeek(BuildContext context) async {
    final controller = context.game;
    // Every Critical task, not just the top-3 "おすすめ行動" summary — a
    // player must never be able to accidentally skip past one (§34).
    final critical = TaskEngine.generateTasks(controller.state)
        .where((task) => task.priority == TaskPriority.critical)
        .toList();
    if (critical.isNotEmpty) {
      final proceed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('重要事項が残っています'),
        content: Text('まだ今週対応できる重要事項があります。\n・${critical.map((e) => e.title).join('\n・')}\n\nこのまま次の週へ進みますか？'),
        actions: [TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('戻る')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('それでも進む'))],
      ));
      if (proceed != true || !context.mounted) return;
    }
    controller.advanceWeek();
    var state = controller.state;

    final closing = state.latestClosing;
    if (closing != null && closing.week == state.week && context.mounted) {
      await showMonthlyClosingDialog(context, closing);
    }

    if (context.mounted) {
      await _showPendingFoundingEvents(context, controller, ProgressionEngine.weeklyEvents);
    }

    // Bankruptcy/finished already gets its own full-screen treatment via
    // _GameRoot, so only show the week summary when still playing (§16,
    // §22) — showing a dialog right as the screen is about to be swapped
    // out would fight that transition.
    state = controller.state;
    if (state.status == GameStatus.playing && context.mounted) {
      await showWeekSummaryDialog(context, state);
    }
  }

  /// Shows every not-yet-seen [OneTimeEvent] among [candidates] whose
  /// condition currently holds (celebrations + contextual tutorials,
  /// §13-14, §19-20, §25, §37, §39, §47), one at a time.
  Future<void> _showPendingFoundingEvents(
    BuildContext context,
    GameController controller,
    List<OneTimeEvent> candidates,
  ) async {
    for (final event in ProgressionEngine.pendingEvents(controller.state, candidates)) {
      if (!context.mounted) break;
      final dialog = buildFoundingEventDialog(event, controller.state);
      controller.markTutorialSeen(event);
      if (dialog == null) continue;
      final tapped = await showFoundingEventDialog(context, dialog);
      if (tapped && context.mounted) _navigateForEvent(context, event, controller.state);
    }
  }

  void _navigateForEvent(BuildContext context, OneTimeEvent event, GameState state) {
    switch (event) {
      case OneTimeEvent.interviewOfferCelebration:
        final offer = state.interviewOffers
            .where((o) => o.status == InterviewOfferStatus.pending)
            .toList();
        context.switchTab(SesTab.employees);
        if (offer.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EngineerDetailScreen(engineerId: offer.first.employeeId)),
          );
        }
      case OneTimeEvent.firstAssignmentCelebration:
        context.switchTab(SesTab.employees);
      case OneTimeEvent.recruitmentUnlockCelebration:
        context.switchTab(SesTab.recruitment);
      case OneTimeEvent.welfareUnlockCelebration:
        context.switchTab(SesTab.others);
      case OneTimeEvent.clientInterviewCelebration:
      case OneTimeEvent.recruitmentInterviewCelebration:
      case OneTimeEvent.firstOfferTutorial:
      case OneTimeEvent.firstArTutorial:
      case OneTimeEvent.fieldLeadTutorial:
      case OneTimeEvent.contractRenewalTutorial:
      case OneTimeEvent.clientUnlockTutorial:
        break;
    }
  }

  void _onTaskTap(BuildContext context, TaskTargetType targetType, String? targetId) {
    switch (targetType) {
      case TaskTargetType.none:
        break;
      case TaskTargetType.cashBreakdown:
        showExpenseBreakdownSheet(context, context.game.state);
      case TaskTargetType.recruitmentTab:
        context.switchTab(SesTab.recruitment);
      case TaskTargetType.employeesTab:
        context.switchTab(SesTab.employees);
      case TaskTargetType.projectsTab:
        context.switchTab(SesTab.projects);
      case TaskTargetType.othersTab:
        context.switchTab(SesTab.others);
      case TaskTargetType.employeeDetail:
        context.switchTab(SesTab.employees);
        if (targetId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EngineerDetailScreen(engineerId: targetId)),
          );
        }
      case TaskTargetType.interviewResults:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InterviewResultsScreen()),
        );
    }
  }

  Future<void> _onMissionCta(BuildContext context, FoundingMissionStep step) async {
    if (step.stage == FoundingStage.welfare) {
      // Final step: "経営を続ける" finishes the tutorial instead of
      // navigating anywhere (§27-28).
      context.game.completeFoundingTutorial();
      return;
    }
    _onTaskTap(context, step.targetType, step.targetId);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;
    final company = state.company;
    final tutorialActive = ProgressionEngine.showFoundingMission(state);
    final missionStep = ProgressionEngine.missionStep(state);
    final allTasks = TaskEngine.generateTasks(state);
    final criticalTasks = allTasks.where((t) => t.priority == TaskPriority.critical).toList();
    // During the tutorial, only Critical ever appears in the primary list —
    // everything else collapses under "その他" so the Founding Mission card
    // stays the single obvious next step (§33-34).
    final primaryTasks = tutorialActive ? criticalTasks : RecommendationEngine.recommendedActions(state);
    final primaryIds = primaryTasks.map((t) => t.id).toSet();
    final collapsedTasks = allTasks.where((t) => !primaryIds.contains(t.id)).toList();
    final showAdvancedFinance = ProgressionEngine.canUseAdvancedFinance(state);
    final runway = FinanceEngine.cashRunwayMonths(state);
    final runwayColor = RunwayIndicator.colorFor(FinanceEngine.classifyRunway(runway));

    return Scaffold(
      appBar: AppBar(
        title: const Text('S.E.S.'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Week ${state.displayWeek} / $totalGameWeeks',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    GameCalendar.displayLabel(state.week),
                    style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
        children: [
          // --- 会社指標: Stage 1 は最小限、初参画後は現行のフルダッシュボード
          // (§35-37) ---------------------------------------------------
          if (showAdvancedFinance) ...[
            Row(
              children: [
                Expanded(
                  child: StatTile(label: '現預金', value: formatCompactYen(company.cash), emphasis: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => showExpenseBreakdownSheet(context, state),
                    child: StatTile(
                      label: '資金余命',
                      value: RunwayIndicator.labelFor(runway).replaceAll('で資金枯渇', ''),
                      emphasis: true,
                      valueColor: runwayColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(label: '稼働率', value: '${state.utilizationPercent}%', emphasis: true),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showExpenseBreakdownSheet(context, state),
              child: _FinanceLine(state: state),
            ),
            const SizedBox(height: 6),
            _HeadcountLine(state: state),
          ] else
            _SimplifiedDashboard(state: state),
          const SizedBox(height: 18),

          // --- 今週の経営判断 (チュートリアル中はCriticalのみ、§33-34) -------
          Row(
            children: [
              Text('今週のおすすめ行動', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 6),
              const Text('今週の経営判断', style: TextStyle(fontSize: 10, color: Colors.black45)),
              const SizedBox(width: 6),
              if (primaryTasks.isNotEmpty)
                Text('(${primaryTasks.length})', style: const TextStyle(color: Colors.black45, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          if (primaryTasks.isEmpty && !tutorialActive)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: const Text('今週やることは特にありません。「次の週へ」進めましょう。'),
            )
          else
            for (final task in primaryTasks)
              TaskCard(
                task: task,
                onTap: task.targetType == TaskTargetType.none
                    ? null
                    : () => _onTaskTap(context, task.targetType, task.targetId),
              ),
          if (collapsedTasks.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('その他 ${collapsedTasks.length}件', style: const TextStyle(fontSize: 13)),
              children: [for (final task in collapsedTasks) TaskCard(task: task, onTap: task.targetType == TaskTargetType.none ? null : () => _onTaskTap(context, task.targetType, task.targetId))],
            ),
          if (state.listings.where((listing) => listing.isActiveOn(state.week)).isEmpty)
            const Padding(padding: EdgeInsets.only(top: 4), child: Text('求人媒体が掲載されていません', style: TextStyle(fontSize: 11, color: Colors.black54))),

          if (missionStep != null) ...[
            const SizedBox(height: 12),
            _FoundingMissionCard(
              state: state,
              step: missionStep,
              onCta: missionStep.ctaLabel == null ? null : () => _onMissionCta(context, missionStep),
            ),
          ],

          const SizedBox(height: 10),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('最近の出来事', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              childrenPadding: EdgeInsets.zero,
              children: [_RecentEvents(events: state.events)],
            ),
          ),
        ],
      ),
      bottomSheet: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _onNextWeek(context),
            icon: const Icon(Icons.arrow_forward),
            label: Text('次の週へ (Week ${state.displayWeek} → ${state.displayWeek + 1})'),
          ),
        ),
      ),
    );
  }
}

/// Stage 1's Home (§35): only cash, this month's expected outflow, and the
/// waiting headcount — the full dashboard grows in once there's an actual
/// assignment to show revenue/AR/utilization for.
class _SimplifiedDashboard extends StatelessWidget {
  const _SimplifiedDashboard({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final outflow = FinanceEngine.expectedOutflowThisMonth(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Metric('現預金', formatCompactYen(state.company.cash)),
          Container(width: 1, height: 24, color: Colors.black12),
          _Metric('今月支払予定', formatCompactYen(outflow)),
          Container(width: 1, height: 24, color: Colors.black12),
          _Metric('待機人数', '${state.waitingEngineerCount}名', color: state.waitingEngineerCount > 0 ? Colors.red : null),
        ],
      ),
    );
  }
}

/// Home最上部の「創業ミッション」カード (§45-46): 現在のステップだけを見せ、
/// 全体進捗はコンパクトなドット表示にとどめる。
class _FoundingMissionCard extends StatelessWidget {
  const _FoundingMissionCard({required this.state, required this.step, required this.onCta});

  final GameState state;
  final FoundingMissionStep step;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: Colors.indigo, size: 18),
              const SizedBox(width: 6),
              Text('創業ミッション', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.indigo.shade900)),
              const Spacer(),
              Text(
                'STEP ${step.stepNumber} / ${step.totalSteps}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(step.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(step.description, style: const TextStyle(fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 10),
          _MissionProgressDots(state: state),
          if (step.ctaLabel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onCta, child: Text(step.ctaLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}

const Map<FoundingStage, String> _stageShortLabels = {
  FoundingStage.employeeIntro: '社員確認',
  FoundingStage.skillSheet: 'Sheet',
  FoundingStage.salesStart: '営業開始',
  FoundingStage.awaitingOffer: '面談Offer',
  FoundingStage.clientInterview: '客先面談',
  FoundingStage.awaitingAssignment: '初参画',
  FoundingStage.recruitment: '採用',
  FoundingStage.welfare: '福利厚生',
};

class _MissionProgressDots extends StatelessWidget {
  const _MissionProgressDots({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final current = ProgressionEngine.currentStage(state);
    final stages = _stageShortLabels.keys.toList();
    final currentIndex = stages.indexOf(current);
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (var i = 0; i < stages.length; i++)
          Text(
            '${i < currentIndex
                ? '✓'
                : i == currentIndex
                    ? '●'
                    : '○'} ${_stageShortLabels[stages[i]]}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: i == currentIndex ? FontWeight.bold : FontWeight.normal,
              color: i < currentIndex
                  ? Colors.green.shade700
                  : i == currentIndex
                      ? Colors.indigo.shade700
                      : Colors.black45,
            ),
          ),
      ],
    );
  }
}

class _FinanceLine extends StatelessWidget {
  const _FinanceLine({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final ar = FinanceEngine.totalPendingAr(state);
    final inflow = FinanceEngine.expectedInflowThisMonth(state);
    final outflow = FinanceEngine.expectedOutflowThisMonth(state);
    final projected = FinanceEngine.projectedMonthEndCash(state);
    final projectedColor = projected >= 0 ? Colors.green.shade700 : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Metric('売掛金', formatCompactYen(ar)),
          _divider(),
          _Metric('今月入金予定', formatCompactYen(inflow)),
          _divider(),
          _Metric('今月支払予定', formatCompactYen(outflow)),
          _divider(),
          _Metric('月末予想現金', formatCompactYen(projected), color: projectedColor),
        ],
      ),
    );
  }

  static Widget _divider() => Container(width: 1, height: 24, color: Colors.black12);
}

class _HeadcountLine extends StatelessWidget {
  const _HeadcountLine({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Metric('社員', '${state.engineers.length}'),
          _divider(),
          _Metric('稼働', '${state.assignedEngineerCount}'),
          _divider(),
          _Metric('待機', '${state.waitingEngineerCount}', color: state.waitingEngineerCount > 0 ? Colors.red : null),
          _divider(),
          _Metric('応募', '${state.applicants.where((e) => e.appearedWeek == state.week).length}'),
          _divider(),
          _Metric('市場案件', '${state.openProjects.where((e) => state.relationFor(e.project.clientId).unlocked).length}'),
        ],
      ),
    );
  }

  static Widget _divider() => Container(width: 1, height: 20, color: Colors.black12);
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}

class _RecentEvents extends StatelessWidget {
  const _RecentEvents({required this.events});

  final List<GameLogEntry> events;

  @override
  Widget build(BuildContext context) {
    final recent = events.reversed.take(8).toList();
    if (recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('まだ出来事はありません。', style: TextStyle(color: Colors.black45, fontSize: 13)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (final e in recent)
            ListTile(
              dense: true,
              leading: Text('W${e.week}', style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text(e.message, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
