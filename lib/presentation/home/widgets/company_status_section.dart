import 'package:flutter/material.dart';

import 'dashboard_section_card.dart';

/// A single label/value row inside the company-status area.
class _StatusRow {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;
}

const _statusRows = [
  _StatusRow(label: '会社名', value: '—'),
  _StatusRow(label: '経過週', value: '—'),
  _StatusRow(label: '状態', value: '—'),
];

/// Company-status area of the home dashboard.
///
/// Phase 1A renders static placeholder rows only; wiring these to the real
/// `Company` domain model happens in a later phase.
class CompanyStatusSection extends StatelessWidget {
  const CompanyStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DashboardSectionCard(
      title: '会社状況',
      child: Column(
        children: [
          for (final row in _statusRows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  row.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (row != _statusRows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
