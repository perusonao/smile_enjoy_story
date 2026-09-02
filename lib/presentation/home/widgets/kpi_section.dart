import 'package:flutter/material.dart';

import '../models/home_dashboard_display_data.dart';
import 'dashboard_section_card.dart';

/// One KPI tile's label plus its resolved display value.
class _KpiTileData {
  const _KpiTileData({
    required this.icon,
    required this.label,
    this.value,
    this.tileKey,
  });

  final IconData icon;
  final String label;

  /// Resolved display text, or `null` to render the Phase 1A placeholder
  /// dash. Formatting (yen/万-units, "名" suffix, ...) happens here in the
  /// presentation layer only — the underlying value itself is never
  /// recomputed (see [HomeDashboardDisplayData]'s own class doc).
  final String? value;

  /// Stable per-tile key, used by the compact runtime variant so a test can
  /// assert *which* tile carries a value instead of matching a bare "2名"
  /// anywhere in the card.
  final Key? tileKey;
}

// `floor()` rounds toward negative infinity, so a small negative amount
// (e.g. -5,000) would floor to -1万 instead of the correct 0万 — overstating
// a shortfall that hasn't actually reached ¥1万 yet. `~/` (Dart's
// truncating integer division) rounds toward zero instead, which matches
// how the positive case already read and keeps -10,000 correctly at -1万.
//
// HOME-RUNTIME-2A keeps this exact function for the compact runtime
// variant too. The legacy stat row it replaced used `floor()`; merging the
// two surfaces deliberately keeps the corrected (HOME-RUNTIME-READ-1)
// semantics rather than reintroducing the old rounding.
String _yen(int amount) => '¥${amount ~/ 10000}万';

List<_KpiTileData> _tilesFor(HomeDashboardDisplayData? data) => [
  _KpiTileData(
    icon: Icons.payments_outlined,
    label: '現金',
    value: data == null ? null : _yen(data.cash),
  ),
  _KpiTileData(
    icon: Icons.groups_outlined,
    label: '技術者数',
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
  // their authoritative source. HOME-RUNTIME-2A drops them from the
  // *runtime* (compact) variant only: a tile that can only ever render "—"
  // reads as broken on a live screen. This default variant, and with it
  // HomeShellPage's Phase 1A presentation, is unchanged.
  const _KpiTileData(icon: Icons.assignment_outlined, label: '稼働案件'),
  const _KpiTileData(icon: Icons.verified_outlined, label: '信用'),
];

/// The compact runtime KPI: the seven figures that actually have an
/// authoritative source, in two rows, with no icons and no placeholder
/// tiles.
///
/// Row A is the month's operating picture (現金 / 参画 / 待機 / 営業残) —
/// the four values the deleted legacy stat row used to carry. Row B is the
/// slower-moving context (社員 / 売上 / 入金予定).
List<List<_KpiTileData>> _compactRowsFor(HomeDashboardDisplayData data) => [
  [
    _KpiTileData(
      icon: Icons.payments_outlined,
      label: '現金',
      value: _yen(data.cash),
      tileKey: const Key('home-kpi-compact-cash'),
    ),
    _KpiTileData(
      icon: Icons.handshake_outlined,
      label: '参画',
      value: '${data.assignedEmployeeCount}名',
      tileKey: const Key('home-kpi-compact-assigned'),
    ),
    _KpiTileData(
      icon: Icons.chair_outlined,
      label: '待機',
      value: '${data.waitingEmployeeCount}名',
      tileKey: const Key('home-kpi-compact-waiting'),
    ),
    _KpiTileData(
      icon: Icons.campaign_outlined,
      label: '営業残',
      value: '${data.salesRemaining}回',
      tileKey: const Key('home-kpi-compact-sales-remaining'),
    ),
  ],
  [
    _KpiTileData(
      icon: Icons.groups_outlined,
      label: '社員',
      value: '${data.employeeCount}名',
      tileKey: const Key('home-kpi-compact-employees'),
    ),
    _KpiTileData(
      icon: Icons.trending_up_outlined,
      label: '売上',
      value: _yen(data.revenue),
      tileKey: const Key('home-kpi-compact-revenue'),
    ),
    _KpiTileData(
      icon: Icons.schedule_outlined,
      label: '入金予定',
      value: _yen(data.pendingRevenue),
      tileKey: const Key('home-kpi-compact-pending-revenue'),
    ),
  ],
];

/// KPI area of the home dashboard.
///
/// The default constructor renders the original static 2-column grid.
/// HOME-UI-1C: when [data] is supplied, 現金/社員数/参画中/売上/入金予定 show
/// real read-only values projected from the authoritative Public Demo
/// finance state; 稼働案件/信用 remain placeholders. [data] stays optional
/// and defaults to `null`, which renders every tile as the original Phase
/// 1A placeholder dash.
///
/// [KpiSection.compact] is the HOME-RUNTIME-2A runtime variant: the same
/// projected values (plus 待機/営業残, which the deleted legacy stat row
/// used to own) in two dense rows, without the two placeholder tiles.
/// It is a second *presentation* of the same projection — it reads no extra
/// state, and adds no interactive element.
class KpiSection extends StatelessWidget {
  const KpiSection({super.key, this.data}) : compact = false;

  /// The compact runtime variant. Takes [data] non-nullably: unlike the
  /// default grid there is no placeholder presentation to fall back to,
  /// because the whole point of this variant is that every tile it renders
  /// has a real value.
  const KpiSection.compact({
    super.key,
    required HomeDashboardDisplayData this.data,
  }) : compact = true;

  final HomeDashboardDisplayData? data;

  /// Whether to render the dense two-row runtime form instead of the
  /// original placeholder grid. `false` for every pre-HOME-RUNTIME-2A
  /// caller, including `HomeShellPage`.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return _CompactKpi(data: data!);

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

class _CompactKpi extends StatelessWidget {
  const _CompactKpi({required this.data});

  final HomeDashboardDisplayData data;

  @override
  Widget build(BuildContext context) {
    final rows = _compactRowsFor(data);
    return Card(
      key: const Key('home-kpi-compact'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = 0; j < rows[i].length; j++) ...[
                    if (j > 0) const SizedBox(width: 6),
                    Expanded(child: _CompactKpiTile(data: rows[i][j])),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Value-over-label with a small leading icon badge: the densest readable
/// form of a KPI figure that still reads as icon-led, per the approved
/// PUBLIC-DEMO-HOME-UI-3A visual target. Both text lines keep `maxLines: 1`
/// + ellipsis so a long value can never wrap a tile taller than its
/// row-mates (four tiles share ~328pt of inner width at 360x800).
///
/// PUBLIC-DEMO-HOME-UI-3A: adds the icon badge [_KpiTileData.icon] already
/// carried but never painted before this change. No `Key`, value format, or
/// label text changed — existing finders for `home-kpi-compact-*` keep
/// working unmodified.
class _CompactKpiTile extends StatelessWidget {
  const _CompactKpiTile({required this.data});

  final _KpiTileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: data.tileKey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(data.icon, size: 12, color: colorScheme.primary),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value ?? '—',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  data.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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
