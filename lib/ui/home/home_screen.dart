import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;
    final company = state.company;

    final unInterviewedCount = state.applicants
        .where((e) => !state.interviewedApplicantIds.contains(e.applicant.id))
        .length;
    final waitingCount = state.waitingEngineerCount;
    final newProjectsThisWeek = state.openProjects
        .where((e) => e.postedWeek == state.week)
        .length;
    final proposableProjects = state.openProjects
        .where((e) => state.isProjectOpenForProposal(e.project.id))
        .length;
    final interviewResultsThisWeek = state.proposals
        .where((p) => p.interviewWeek == state.week)
        .length;
    final newApplicantsThisWeek = state.applicants
        .where((e) => e.appearedWeek == state.week)
        .length;

    final todos = <String>[
      if (unInterviewedCount > 0) '面接可能 $unInterviewedCount名',
      if (waitingCount > 0) '待機社員 $waitingCount名',
      if (newProjectsThisWeek > 0) '新着案件 $newProjectsThisWeek件',
      if (interviewResultsThisWeek > 0) '案件面談結果 $interviewResultsThisWeek件',
    ];

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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          _TitleBanner(companyName: company.name),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: [
              StatTile(label: '資金', value: formatYen(company.cash), emphasis: true),
              StatTile(
                label: '稼働率',
                value: '${state.utilizationPercent}%',
                emphasis: true,
              ),
              StatTile(
                label: '今週売上',
                value: formatYen(state.lastWeekRevenue),
                valueColor: Colors.green.shade700,
              ),
              StatTile(
                label: '今週支出',
                value: formatYen(state.lastWeekExpense),
                valueColor: Colors.red.shade700,
              ),
              StatTile(label: 'エンジニア人数', value: '${state.engineers.length}名'),
              StatTile(label: '稼働人数', value: '${state.assignedEngineerCount}名'),
              StatTile(label: '待機人数', value: '$waitingCount名'),
              StatTile(label: '今週の応募者数', value: '$newApplicantsThisWeek名'),
              StatTile(label: '提案可能案件数', value: '$proposableProjects件'),
            ],
          ),
          const SizedBox(height: 20),
          Text('今週やること', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (todos.isEmpty)
            const _EmptyTodoCard()
          else
            ...todos.map((t) => _TodoRow(text: t)),
          const SizedBox(height: 20),
          Text('最近の出来事', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _RecentEvents(events: state.events),
        ],
      ),
      bottomSheet: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: controller.advanceWeek,
            icon: const Icon(Icons.arrow_forward),
            label: Text('次の週へ (Week ${state.displayWeek} → ${state.displayWeek + 1})'),
          ),
        ),
      ),
    );
  }
}

class _TitleBanner extends StatelessWidget {
  const _TitleBanner({required this.companyName});

  final String companyName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [SesTheme.primaryBlue, SesTheme.accentCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'S.E.S.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const Text(
            'Smile. Enjoy. Story.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(companyName, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: SesTheme.accentCyan),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyTodoCard extends StatelessWidget {
  const _EmptyTodoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Text('今週やることは特にありません。「次の週へ」進めましょう。'),
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
      return const _EmptyTodoCard();
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
