import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.preferredEmployeeId,
  });

  final String projectId;
  final String? preferredEmployeeId;

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
              _Row('支払サイト', '${paymentTermDaysById(project.clientId)}日'),
              _Row('契約期間', '${project.durationWeeks}週間'),
              _Row('応募締切', 'Week ${project.applicationDeadlineWeek}'),
              _Row('面談回数', '${project.interviewCount}回'),
              _Row('競争度', '★' * project.competitionLevel),
              _Row(
                '選考フロー',
                project.selectionFlow.steps
                    .map((step) => selectionStepLabels[step]!)
                    .join(' → '),
              ),
              _Row(
                '自社応募',
                '${state.proposals.where((p) => p.project.id == project.id && p.isActive).length}名',
              ),
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
          Text('市場情報', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _InfoBox(text: 'この画面は取引先の需要を知るための市場情報です。\n社員のスキルシートを整え、社員詳細から営業を開始すると、条件に合う案件から面談オファーが届きます。'),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(text),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: SesTheme.primaryBlue,
            ),
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
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
