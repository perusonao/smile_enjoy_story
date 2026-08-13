import 'package:flutter/material.dart';

import '../../domain/domain.dart';

/// Small color-coded chip for an [EngineerStatus]. Sales activity is shown
/// separately; employees remain waiting until they actually join a project.
class EngineerStatusChip extends StatelessWidget {
  const EngineerStatusChip({super.key, required this.status});

  final EngineerStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EngineerStatus.assigned => ('参画中', Colors.blue),
      EngineerStatus.waiting => ('待機中', Colors.red),
      EngineerStatus.proposed => ('待機中', Colors.red),
      EngineerStatus.interviewScheduled => ('面談合格・参画予定', Colors.purple),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
