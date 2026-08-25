import 'package:flutter/material.dart';

import 'dashboard_section_card.dart';

/// Office / employee "stage" area of the home dashboard.
///
/// Phase 1A renders empty placeholder slots only. The logic that selects up
/// to 3 employees to feature here is Phase 1B's job, not this one's.
class OfficeStageSection extends StatelessWidget {
  const OfficeStageSection({super.key});

  static const int _slotCount = 3;

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      title: 'オフィス',
      child: Row(
        children: [
          for (var i = 0; i < _slotCount; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            const Expanded(child: _EmptyEmployeeSlot()),
          ],
        ],
      ),
    );
  }
}

class _EmptyEmployeeSlot extends StatelessWidget {
  const _EmptyEmployeeSlot();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.person_outline,
          color: colorScheme.outlineVariant,
          size: 28,
        ),
      ),
    );
  }
}
