import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../app/nav_scope.dart';
import '../../game/game.dart';
import '../engineers/engineer_detail_screen.dart';
import '../main_shell.dart';
import '../projects/interview_results_screen.dart';
import '../theme.dart';
import '../widgets/expense_breakdown_sheet.dart';
import '../widgets/founding_tutorial_dialog.dart';
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
  bool _tutorialShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  void _maybeShowTutorial() {
    if (_tutorialShown || !mounted) return;
    final state = context.game.state;
    if (state.week != 1 || state.waitingEngineerCount == 0) return;
    _tutorialShown = true;
    showFoundingTutorialDialog(context, waitingCount: state.waitingEngineerCount);
  }

  Future<void> _onNextWeek(BuildContext context) async {
    final controller = context.game;
    final critical = RecommendationEngine.recommendedActions(controller.state)
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
    final state = controller.state;

    final closing = state.latestClosing;
    if (closing != null && closing.week == state.week && context.mounted) {
      await showMonthlyClosingDialog(context, closing);
    }
    // Bankruptcy/finished already gets its own full-screen treatment via
    // _GameRoot, so only show the week summary when still playing (§16,
    // §22) — showing a dialog right as the screen is about to be swapped
    // out would fight that transition.
    if (state.status == GameStatus.playing && context.mounted) {
      await showWeekSummaryDialog(context, state);
    }
  }

  void _onTaskTap(BuildContext context, HomeTask task) {
    switch (task.targetType) {
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
      case TaskTargetType.employeeDetail:
        context.switchTab(SesTab.employees);
        final id = task.targetId;
        if (id != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EngineerDetailScreen(engineerId: id)),
          );
        }
      case TaskTargetType.interviewResults:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InterviewResultsScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;
    final company = state.company;
    final allTasks = TaskEngine.generateTasks(state);
    final tasks = RecommendationEngine.recommendedActions(state);
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
          // --- コンパクトな会社指標 (§6, §10-12) --------------------------
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
          const SizedBox(height: 18),

          // --- 今週の経営判断 (§3-§6の主役) ------------------------------
          Row(
            children: [
              Text('今週のおすすめ行動', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 6),
              const Text('今週の経営判断', style: TextStyle(fontSize: 10, color: Colors.black45)),
              const SizedBox(width: 6),
              if (tasks.isNotEmpty)
                Text('(${tasks.length})', style: const TextStyle(color: Colors.black45, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
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
            for (final task in tasks)
              TaskCard(
                task: task,
                onTap: task.targetType == TaskTargetType.none
                    ? null
                    : () => _onTaskTap(context, task),
              ),
          if (allTasks.length > 3)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('その他 ${allTasks.length - 3}件', style: const TextStyle(fontSize: 13)),
              children: [for (final task in allTasks.skip(3)) TaskCard(task: task, onTap: task.targetType == TaskTargetType.none ? null : () => _onTaskTap(context, task))],
            ),
          if (state.listings.where((listing) => listing.isActiveOn(state.week)).isEmpty)
            const Padding(padding: EdgeInsets.only(top: 4), child: Text('求人媒体が掲載されていません', style: TextStyle(fontSize: 11, color: Colors.black54))),

          if (state.week <= 4) ...[
            const SizedBox(height: 12),
            _FoundingMission(state: state),
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

class _FoundingMission extends StatelessWidget {
  const _FoundingMission({required this.state});
  final GameState state;
  @override Widget build(BuildContext context) {
    final proposed = state.proposals.isNotEmpty || state.stats.proposalCount > 0;
    final assigned = state.assignedEngineerCount > 0 || state.stats.assignmentsStarted > 0;
    final selectionAdvanced = state.proposals.any((p) => p.currentStepIndex > 0 || p.stepHistory.isNotEmpty);
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('創業ミッション', style: Theme.of(context).textTheme.titleMedium),
      const Text('まずは会社を軌道に乗せましょう。'), const SizedBox(height: 8),
      const Text('✓ ① 待機社員を確認'),
      Text('${proposed ? '✓' : '○'} ② 社員に案件を提案'),
      Text('${selectionAdvanced ? '✓' : '○'} ③ 選考を進める'),
      Text('${assigned ? '✓' : '○'} ④ 1人以上を案件参画させる'),
      if (proposed && !selectionAdvanced) const Padding(padding: EdgeInsets.only(top: 8), child: Text('次: 選考結果待ちです。次の週へ進めると結果が発生します。', style: TextStyle(fontWeight: FontWeight.bold))),
    ])));
  }
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
          _Metric('提案可', '${state.openProjects.where((e) => state.isProjectOpenForProposal(e.project.id)).length}'),
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
