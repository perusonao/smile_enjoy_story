import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../widgets/project_interview_result_card.dart';

/// 案件面談結果 (§14-15): every proposal resolved this week, pass or fail.
class InterviewResultsScreen extends StatelessWidget {
  const InterviewResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final results = state.proposals
        .where((p) => p.interviewWeek == state.week)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('案件面談結果')),
      body: results.isEmpty
          ? const Center(child: Text('今週の案件面談結果はありません。'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              itemCount: results.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final proposal = results[i];
                Engineer? engineer;
                for (final e in state.engineers) {
                  if (e.id == proposal.engineerId) {
                    engineer = e;
                    break;
                  }
                }
                if (engineer == null) return const SizedBox.shrink();
                return ProjectInterviewResultCard(engineer: engineer, proposal: proposal);
              },
            ),
    );
  }
}
