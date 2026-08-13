import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import 'project_detail_screen.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final entries = [...state.openProjects]
      ..sort((a, b) => b.postedWeek.compareTo(a.postedWeek));
    final waitingCount = state.waitingEngineerCount;

    return Scaffold(
      appBar: AppBar(title: const Text('案件')),
      body: entries.isEmpty
          ? const Center(child: Text('現在公開中の案件はありません。'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = entries[i];
                final open = state.isProjectOpenForProposal(entry.project.id);
                return _ProjectCard(
                  project: entry.project,
                  open: open,
                  candidateCount: open ? waitingCount : 0,
                );
              },
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.open,
    required this.candidateCount,
  });

  final Project project;
  final bool open;
  final int candidateCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: project.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (!open)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: _StatusTag(text: '選考中/募集終了', color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              clientNameById(project.clientId),
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Bit(Icons.payments_outlined, '${formatYen(project.monthlyRate)}/月'),
                _Bit(
                  Icons.code,
                  project.requiredLanguages.isEmpty
                      ? '言語不問'
                      : project.requiredLanguages
                            .map((l) => languageLabels[l] ?? l.name)
                            .join('/'),
                ),
                _Bit(Icons.star_outline, topRequiredSkillLabel(project)),
                _Bit(Icons.timelapse, '${project.durationWeeks}週間'),
                _Bit(Icons.forum_outlined, '面談${project.interviewCount}回'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 14,
                  color: candidateCount > 0 ? SesTheme.primaryBlue : Colors.black38,
                ),
                const SizedBox(width: 4),
                Text(
                  candidateCount > 0 ? '提案候補 $candidateCount名' : '候補なし',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: candidateCount > 0 ? SesTheme.primaryBlue : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bit extends StatelessWidget {
  const _Bit(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}
