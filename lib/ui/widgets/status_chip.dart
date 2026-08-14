import 'package:flutter/material.dart';

import '../../game/game.dart';

/// Small color-coded chip for an [EmployeeWorkflowState] — the single
/// derived "what is this employee doing right now" used by every screen
/// (Playable 0.4C.3 §12-17), not the raw [EngineerStatus] enum, which stays
/// `waiting` through the entire modern sales/selection/offer pipeline and
/// so can't tell "待機中" apart from "参画予定" or "客先面談あり".
class EngineerStatusChip extends StatelessWidget {
  const EngineerStatusChip({super.key, required this.state});

  final EmployeeWorkflowState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      EmployeeWorkflowState.assigned => Colors.blue,
      EmployeeWorkflowState.finalOfferPending => Colors.red,
      EmployeeWorkflowState.assignmentScheduled => Colors.purple,
      EmployeeWorkflowState.clientInterviewActionRequired => Colors.deepOrange,
      EmployeeWorkflowState.waitingSelectionResult => Colors.orange,
      EmployeeWorkflowState.interviewRequestPending => Colors.deepOrange,
      EmployeeWorkflowState.selling => Colors.teal,
      EmployeeWorkflowState.waiting => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        EmployeeWorkflowEngine.labels[state]!,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
