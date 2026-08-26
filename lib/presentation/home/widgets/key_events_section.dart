import 'package:flutter/material.dart';

import 'dashboard_section_card.dart';

/// Important-events area of the home dashboard.
///
/// Phase 1A renders a static empty state only. Event selection and P1/P2/P3
/// prioritization are Phase 1C's job, not this one's.
///
/// HOME-RUNTIME-2A briefly gave this widget a second job: rendering the
/// runtime screen's `今月やること` slot. HOME-RUNTIME-2C moved that slot —
/// and the month-goal fallback presentation with it — to
/// [RecommendedActionSection], which now owns the whole "what to do next"
/// area of the runtime HOME. It moved rather than being copied, so there is
/// still exactly one place on screen showing the month goal, and this
/// widget is back to being exactly what Phase 1A defined: the placeholder
/// `重要イベント` empty state used by `HomeShellPage`.
class KeyEventsSection extends StatelessWidget {
  const KeyEventsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DashboardSectionCard(
      title: '重要イベント',
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, color: colorScheme.outline, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '表示できるイベントはありません',
              style: theme.textTheme.bodyMedium?.copyWith(
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
