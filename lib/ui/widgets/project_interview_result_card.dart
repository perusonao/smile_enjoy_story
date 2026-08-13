import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';

/// 案件面談結果カード (§14-15): shown on the Interview Results screen and
/// reused wherever a resolved [ProjectProposal] needs the same "did they
/// pass, and why" presentation.
class ProjectInterviewResultCard extends StatelessWidget {
  const ProjectInterviewResultCard({
    super.key,
    required this.engineer,
    required this.proposal,
  });

  final Engineer engineer;
  final ProjectProposal proposal;

  @override
  Widget build(BuildContext context) {
    final passed = proposal.stage == ProposalStage.interviewPassed;
    final color = passed ? Colors.green.shade700 : Colors.red.shade700;
    final project = proposal.project;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.check_circle : Icons.cancel,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                passed ? '合格' : '不合格',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${engineer.profile.name}  ×  ${project.title}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
          const SizedBox(height: 10),
          if (passed) ...[
            const Text('来週から参画します。', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            _Row('案件単価', formatYen(project.monthlyRate)),
            _Row('給与', formatYen(engineer.salary)),
            _Row(
              '想定粗利',
              '${formatYen(MatchingEngine.monthlyProfit(engineer, project))}/月',
              emphasis: true,
            ),
          ] else ...[
            const Text('今回の主な理由:', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 4),
            for (final reason in ProjectInterviewEngine.failureReasons(engineer, project))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('・$reason', style: const TextStyle(fontSize: 13)),
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasis ? 14 : 12.5,
              fontWeight: emphasis ? FontWeight.bold : FontWeight.w600,
              color: emphasis ? Colors.green.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
