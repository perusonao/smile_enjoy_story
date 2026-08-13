import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/fit_badge.dart';
import '../widgets/labels.dart';
import '../widgets/proposal_confirm_dialog.dart';
import 'project_detail_screen.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key, this.employeeId});

  final String? employeeId;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    Engineer? employee;
    if (employeeId != null) {
      employee = state.engineerById(employeeId!);
    }
    final unlockedClientIds = state.clientRelations.where((r) => r.unlocked).map((r) => r.clientId).toSet();
    final entries = state.openProjects.where((e) => unlockedClientIds.contains(e.project.clientId)).toList();
    if (employee != null) {
      entries.sort((a, b) {
        final fitA = MatchingEngine.computeFit(employee!, a.project).total;
        final fitB = MatchingEngine.computeFit(employee, b.project).total;
        if (fitA != fitB) return fitB.compareTo(fitA);
        final profitA = MatchingEngine.monthlyProfit(employee, a.project);
        final profitB = MatchingEngine.monthlyProfit(employee, b.project);
        if (profitA != profitB) return profitB.compareTo(profitA);
        final termA = paymentTermDaysById(a.project.clientId);
        final termB = paymentTermDaysById(b.project.clientId);
        if (termA != termB) return termA.compareTo(termB);
        return a.project.competitionLevel.compareTo(b.project.competitionLevel);
      });
    } else {
      entries.sort((a, b) => b.postedWeek.compareTo(a.postedWeek));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          employee == null ? '案件' : '${employee.profile.name}に提案する案件',
        ),
      ),
      body: entries.isEmpty
          ? const Center(child: Text('現在公開中の案件はありません。'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = entries[i];
                final open = state.isProjectOpenForProposal(entry.project.id);
                final candidateCount = open
                    ? state.engineers
                          .where(
                            (engineer) =>
                                engineer.status != EngineerStatus.assigned &&
                                state.canPropose(engineer.id, entry.project.id),
                          )
                          .length
                    : 0;
                final activeCount = state.proposals
                    .where(
                      (application) =>
                          application.project.id == entry.project.id &&
                          (application.status == ApplicationStatus.active ||
                              application.status == ApplicationStatus.offered),
                    )
                    .length;
                return _ProjectCard(
                  project: entry.project,
                  open: open,
                  candidateCount: candidateCount,
                  activeCount: activeCount,
                  employee: employee,
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
    required this.activeCount,
    this.employee,
  });

  final Project project;
  final bool open;
  final int candidateCount;
  final int activeCount;
  final Engineer? employee;

  Future<void> _propose(BuildContext context) async {
    final confirmed = await showProposalConfirmDialog(
      context,
      engineer: employee!,
      project: project,
    );
    if (!confirmed || !context.mounted) return;
    context.game.proposeEngineer(employee!.id, project.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${employee!.profile.name} を提案しました。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(
            projectId: project.id,
            preferredEmployeeId: employee?.id,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                _Bit(
                  Icons.payments_outlined,
                  '${formatYen(project.monthlyRate)}/月',
                ),
                _Bit(
                  Icons.event_outlined,
                  '支払${paymentTermDaysById(project.clientId)}日',
                ),
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
            const SizedBox(height: 7),
            Text(
              '選考 ${project.selectionFlow.steps.length - 1}段階  ${project.selectionFlow.steps.map((step) => selectionStepShortLabels[step]!).join(' → ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: SesTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _CountLabel(
                  icon: Icons.person_add_alt_1,
                  text: '提案可能 $candidateCount名',
                  active: candidateCount > 0,
                ),
                _CountLabel(
                  icon: Icons.work_outline,
                  text: '営業中 $activeCount名',
                  active: activeCount > 0,
                ),
              ],
            ),
            if (employee != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  FitBadge(fit: MatchingEngine.visibleFit(employee!, project)),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed:
                        context.game.state.canPropose(employee!.id, project.id)
                        ? () => _propose(context)
                        : null,
                    child: const Text('提案する'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({
    required this.icon,
    required this.text,
    required this.active,
  });
  final IconData icon;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 14,
        color: active ? SesTheme.primaryBlue : Colors.black38,
      ),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: active ? SesTheme.primaryBlue : Colors.black38,
        ),
      ),
    ],
  );
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
