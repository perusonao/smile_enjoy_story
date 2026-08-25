import 'package:flutter/material.dart';

import 'dashboard_section_card.dart';

/// Placeholder data for a single KPI tile.
///
/// Phase 1A ships fixed placeholder labels only; real values (cash,
/// headcount, active projects, credit, ...) are wired in a later phase.
class _KpiTileData {
  const _KpiTileData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const _kpiTiles = [
  _KpiTileData(icon: Icons.payments_outlined, label: '現金'),
  _KpiTileData(icon: Icons.groups_outlined, label: '社員数'),
  _KpiTileData(icon: Icons.assignment_outlined, label: '稼働案件'),
  _KpiTileData(icon: Icons.verified_outlined, label: '信用'),
];

/// KPI area of the home dashboard.
///
/// Renders a static 2-column grid of placeholder KPI tiles. No values are
/// computed here — that is the responsibility of a later phase.
class KpiSection extends StatelessWidget {
  const KpiSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      title: 'KPI',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.1,
        children: [for (final tile in _kpiTiles) _KpiTile(data: tile)],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.data});

  final _KpiTileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(data.icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '—',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
