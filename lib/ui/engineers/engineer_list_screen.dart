import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import '../widgets/status_chip.dart';

String _topTechSkillLabel(TechSkillLevels t) {
  final entries = <String, int>{
    'DB': t.database,
    'Network': t.network,
    'Infra': t.infrastructure,
    'Frontend': t.frontend,
    'Backend': t.backend,
    'Leader': t.leader,
    'Manager': t.manager,
  };
  final best = entries.entries.reduce((a, b) => a.value >= b.value ? a : b);
  if (best.value <= 0) return '-';
  return '${best.key} Lv.${best.value}';
}

class EngineerListScreen extends StatelessWidget {
  const EngineerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final engineers = [...state.engineers]..sort((a, b) {
      int rank(EngineerStatus s) => switch (s) {
        EngineerStatus.waiting => 0,
        EngineerStatus.interviewScheduled => 1,
        EngineerStatus.proposed => 2,
        EngineerStatus.assigned => 3,
      };
      return rank(a.status).compareTo(rank(b.status));
    });

    return Scaffold(
      appBar: AppBar(title: const Text('社員')),
      body: engineers.isEmpty
          ? const Center(child: Text('社員がいません。'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              itemCount: engineers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _EngineerCard(engineer: engineers[i]),
            ),
    );
  }
}

class _EngineerCard extends StatelessWidget {
  const _EngineerCard({required this.engineer});

  final Engineer engineer;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final profile = engineer.profile;
    final isWaiting = engineer.status == EngineerStatus.waiting;

    String currentProjectLabel = '-';
    final assignment = state.assignmentForEngineer(engineer.id);
    if (assignment != null) {
      currentProjectLabel = '${assignment.project.title} (残${assignment.remainingWeeks}週)';
    } else {
      final proposal = state.proposalForEngineer(engineer.id);
      if (proposal != null) {
        currentProjectLabel = proposal.stage == ProposalStage.interviewPassed
            ? '${proposal.project.title} (参画予定)'
            : '${proposal.project.title} (面談中)';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWaiting ? Colors.red.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWaiting
              ? Colors.red.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.outlineVariant,
          width: isWaiting ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              EngineerStatusChip(status: engineer.status),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _InfoBit(icon: Icons.payments_outlined, text: formatYen(engineer.salary)),
              _InfoBit(
                icon: Icons.code,
                text: languageLabels[profile.mainLanguage] ?? profile.mainLanguage.name,
              ),
              _InfoBit(icon: Icons.star_outline, text: _topTechSkillLabel(profile.techSkills)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.work_outline, size: 15, color: Colors.black45),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  currentProjectLabel,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBit extends StatelessWidget {
  const _InfoBit({required this.icon, required this.text});

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
