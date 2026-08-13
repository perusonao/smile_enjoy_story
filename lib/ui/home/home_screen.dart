import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../app/nav_scope.dart';
import '../../game/game.dart';
import '../engineers/engineer_detail_screen.dart';
import '../main_shell.dart';
import '../projects/interview_results_screen.dart';
import '../theme.dart';
import '../widgets/expense_breakdown_sheet.dart';
import '../widgets/stat_tile.dart';
import '../widgets/task_card.dart';
import '../widgets/week_summary_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _onNextWeek(BuildContext context) async {
    final controller = context.game;
    controller.advanceWeek();
    final state = controller.state;
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
    final tasks = TaskEngine.generateTasks(state);
    final profit = state.lastWeekProfit;
    final profitColor = profit >= 0 ? Colors.green.shade700 : Colors.red.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('S.E.S.'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Week ${state.displayWeek} / $totalGameWeeks',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
        children: [
          // --- コンパクトな会社指標 (§6) ---------------------------------
          Row(
            children: [
              Expanded(
                child: StatTile(label: '資金', value: formatYen(company.cash), emphasis: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showExpenseBreakdownSheet(context, state),
                  child: StatTile(
                    label: '今週収支',
                    value: '${profit >= 0 ? '+' : ''}${formatYen(profit)}',
                    emphasis: true,
                    valueColor: profitColor,
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
          _HeadcountLine(state: state),
          const SizedBox(height: 18),

          // --- 今週の経営判断 (§3-§6の主役) ------------------------------
          Row(
            children: [
              Text('今週の経営判断', style: Theme.of(context).textTheme.titleMedium),
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
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
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
