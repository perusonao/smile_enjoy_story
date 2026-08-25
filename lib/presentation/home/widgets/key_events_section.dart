import 'package:flutter/material.dart';

import 'dashboard_section_card.dart';

/// Important-events area of the home dashboard.
///
/// Phase 1A renders a static empty state only. Event selection and P1/P2/P3
/// prioritization are Phase 1C's job, not this one's.
class KeyEventsSection extends StatelessWidget {
  const KeyEventsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DashboardSectionCard(
      title: '重要イベント',
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, color: colorScheme.outline, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '表示できるイベントはありません',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
