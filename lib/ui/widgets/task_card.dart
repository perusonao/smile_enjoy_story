import 'package:flutter/material.dart';

import '../../game/game.dart';

/// One row of the "今週の経営判断" list (§3-§5): color/icon-coded by
/// [TaskPriority], tappable to navigate to the relevant screen.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});

  final HomeTask task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (task.priority) {
      TaskPriority.critical => (Colors.red, Icons.error_outline),
      TaskPriority.warning => (Colors.orange, Icons.warning_amber_rounded),
      TaskPriority.info => (Colors.blue, Icons.info_outline),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.priorityLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: color.withValues(alpha: 0.95),
                    ),
                  ),
                  if (task.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.subtitle!,
                      style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                    ),
                  ],
                  if (onTap != null) ...[
                    const SizedBox(height: 5),
                    Text('→ ${task.nextActionLabel}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
