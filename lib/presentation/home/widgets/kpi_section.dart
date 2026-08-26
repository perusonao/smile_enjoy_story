import 'package:flutter/material.dart';

import '../models/home_dashboard_display_data.dart';
import 'dashboard_section_card.dart';

/// One KPI tile's label plus its resolved display value.
class _KpiTileData {
  const _KpiTileData({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;

  /// Resolved display text, or `null` to render the Phase 1A placeholder
  /// dash. Formatting (yen/万-units, "名" suffix, ...) happens here in the
  /// presentation layer only — the underlying value itself is never
  /// recomputed (see [HomeDashboardDisplayData]'s own class doc).
  final String? value;
}

// `floor()` rounds toward negative infinity, so a small negative amount
// (e.g. -5,000) would floor to -1万 instead of the correct 0万 — overstating
// a shortfall that hasn't actually reached ¥1万 yet. `~/` (Dart's
// truncating integer division) rounds toward zero instead, which matches
// how the positive case already read and keeps -10,000 correctly at -1万.
String _yen(int amount) => '¥${amount ~/ 10000}万';

List<_KpiTileData> _tilesFor(HomeDashboardDisplayData? data) => [
  _KpiTileData(
    icon: Icons.payments_outlined,
    label: '現金',
    value: data == null ? null : _yen(data.cash),
  ),
  _KpiTileData(
    icon: Icons.groups_outlined,
    label: '社員数',
    value: data == null ? null : '${data.employeeCount}名',
  ),
  _KpiTileData(
    icon: Icons.handshake_outlined,
    label: '参画中',
    value: data == null ? null : '${data.assignedEmployeeCount}名',
  ),
  _KpiTileData(
    icon: Icons.trending_up_outlined,
    label: '売上',
    value: data == null ? null : _yen(data.revenue),
  ),
  _KpiTileData(
    icon: Icons.schedule_outlined,
    label: '入金予定',
    value: data == null ? null : _yen(data.pendingRevenue),
  ),
  // 稼働案件 (active projects) / 信用 (credit) have no HOME-UI-1C candidate
  // field yet — kept as Phase 1A placeholders until a later phase defines
  // their authoritative source.
  const _KpiTileData(icon: Icons.assignment_outlined, label: '稼働案件'),
  const _KpiTileData(icon: Icons.verified_outlined, label: '信用'),
];

/// KPI area of the home dashboard.
///
/// Renders a static 2-column grid of KPI tiles. HOME-UI-1C: when [data] is
/// supplied, 現金/社員数/参画中/売上/入金予定 show real read-only values
/// projected from the authoritative Public Demo finance state; 稼働案件/信用
/// remain placeholders. [data] stays optional and defaults to `null`, which
/// renders every tile as the original Phase 1A placeholder dash.
class KpiSection extends StatelessWidget {
  const KpiSection({super.key, this.data});

  final HomeDashboardDisplayData? data;

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
        children: [for (final tile in _tilesFor(data)) _KpiTile(data: tile)],
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
                  data.value ?? '—',
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
