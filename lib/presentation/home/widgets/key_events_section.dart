import 'package:flutter/material.dart';

import '../models/home_dashboard_display_data.dart';
import 'dashboard_section_card.dart';

/// Important-events area of the home dashboard.
///
/// Phase 1A renders a static empty state only. Event selection and P1/P2/P3
/// prioritization are Phase 1C's job, not this one's.
///
/// HOME-RUNTIME-2A: when [data] is supplied this becomes the runtime
/// screen's single "今月やること" slot, rendering
/// [HomeDashboardDisplayData.monthGoalText]. That is the same card the
/// legacy Public Demo dashboard used to render — the label moved here, it
/// did not disappear, and it is not duplicated: the legacy card and its
/// month-goal `switch` are deleted in the same change.
///
/// Deliberately **text only** in this phase. No button, no `InkWell`, no
/// `ListTile` — nothing that could become a command entry point — so the
/// runtime HOME subtree stays structurally free of any mutation path.
/// [data] stays optional and defaults to `null`, which keeps rendering the
/// original Phase 1A empty state for `HomeShellPage`.
class KeyEventsSection extends StatelessWidget {
  const KeyEventsSection({super.key, this.data});

  final HomeDashboardDisplayData? data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final goal = data?.monthGoalText;

    if (goal != null && goal.isNotEmpty) {
      // Deliberately not DashboardSectionCard here: this variant shares the
      // compact KPI's denser chrome so the two together stay inside the
      // first-view budget the phase exists to reclaim. The default variant
      // below keeps the Phase 1A section card unchanged.
      return Card(
        key: const Key('home-month-goal'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今月やること',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                goal,
                key: const Key('home-month-goal-text'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

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
