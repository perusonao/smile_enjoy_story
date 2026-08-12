import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/fit_badge.dart';
import '../widgets/labels.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;

    ProjectEntry? entry;
    for (final e in state.openProjects) {
      if (e.project.id == projectId) {
        entry = e;
        break;
      }
    }
    if (entry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final project = entry.project;
    final open = state.isProjectOpenForProposal(project.id);
    final waitingEngineers = state.engineers
        .where((e) => e.status == EngineerStatus.waiting)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(project.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _SectionCard(
            title: '案件概要',
            children: [
              _Row('取引先', clientNameById(project.clientId)),
              _Row('種別', projectTypeLabels[project.type] ?? project.type.name),
              _Row('ランク', projectRankLabels[project.rank] ?? project.rank.name),
              _Row('月単価', formatYen(project.monthlyRate)),
              _Row('契約期間', '${project.durationWeeks}週間'),
              _Row('応募締切', 'Week ${project.applicationDeadlineWeek}'),
              _Row('面談回数', '${project.interviewCount}回'),
              _Row('勤務形態', remotePolicyLabels[project.remotePolicy] ?? ''),
              _Row('難易度', '★' * project.difficulty),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '求めるスキル',
            children: [
              _Row(
                '必要言語',
                project.requiredLanguages.isEmpty
                    ? '不問'
                    : project.requiredLanguages
                          .map((l) => languageLabels[l] ?? l.name)
                          .join(' / '),
              ),
              _Row('DB', 'Lv.${project.requiredDatabase}'),
              _Row('Network', 'Lv.${project.requiredNetwork}'),
              _Row('Infrastructure', 'Lv.${project.requiredInfrastructure}'),
              _Row('Frontend', 'Lv.${project.requiredFrontend}'),
              _Row('Backend', 'Lv.${project.requiredBackend}'),
              _Row('Leader', 'Lv.${project.requiredLeader}'),
              _Row('Manager', 'Lv.${project.requiredManager}'),
              _Row('日本語レベル', 'Lv.${project.requiredJapaneseLevel}'),
            ],
          ),
          const SizedBox(height: 20),
          Text('待機社員から提案', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!open)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: const Text('この案件は現在提案できません(選考中、または募集終了)。'),
            )
          else if (waitingEngineers.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: const Text('待機中の社員がいません。'),
            )
          else
            for (final engineer in waitingEngineers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CandidateRow(engineer: engineer, project: project),
              ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.engineer, required this.project});

  final Engineer engineer;
  final Project project;

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final fit = MatchingEngine.visibleFit(engineer, project);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(engineer.profile.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                FitBadge(fit: fit),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              controller.proposeEngineer(engineer.id, project.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${engineer.profile.name} を提案しました。')),
              );
              Navigator.of(context).pop();
            },
            child: const Text('提案する'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: SesTheme.primaryBlue),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
