import 'package:flutter/material.dart';

import '../../game/game.dart';

/// One row of the "今週の経営判断" list (§3-§5): color/icon-coded by
/// [TaskPriority], tappable to navigate to the relevant screen.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});

  final HomeTask task;
  final VoidCallback? onTap;

  /// Cash-runway/short-fall warnings (Phase 3A UX review, P2-3) — visually
  /// distinct from an equal-priority but otherwise-routine task (e.g. "面接
  /// 待ちの応募者がいます") so a resource-critical warning doesn't blend into
  /// the same orange/red as everything else at that priority.
  bool get _isCashWarning => task.id.startsWith('cash-');

  @override
  Widget build(BuildContext context) {
    final (color, defaultIcon) = switch (task.priority) {
      TaskPriority.critical => (Colors.red, Icons.error_outline),
      TaskPriority.warning => (Colors.orange, Icons.warning_amber_rounded),
      TaskPriority.info => (Colors.blue, Icons.info_outline),
    };
    final icon = _isCashWarning ? Icons.savings_outlined : defaultIcon;
    // Severity is never color-only (§ the review's own instruction): a
    // Critical card also gets a visibly heavier background/border than a
    // same-hue Warning/Info one, on top of the existing color+icon+label
    // difference — so severity still reads even for someone who can't rely
    // on color (contrast, color-blindness).
    final (bgAlpha, borderAlpha, borderWidth) = switch (task.priority) {
      TaskPriority.critical => (0.12, 0.55, _isCashWarning ? 2.0 : 1.4),
      TaskPriority.warning => (0.08, 0.4, _isCashWarning ? 1.6 : 1.0),
      TaskPriority.info => (0.05, 0.3, 1.0),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: borderAlpha), width: borderWidth),
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
