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
    this.emphasis = _KpiEmphasis.neutral,
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

  /// HOME-COMPACT-1B.4: which color/priority family this tile paints with
  /// in [_CompactKpi] — presentation-only, see [_KpiEmphasis]'s own doc.
  /// Unused by the default (non-compact) grid, which keeps its original
  /// uniform styling.
  final _KpiEmphasis emphasis;
}

/// HOME-COMPACT-1B.4: the compact runtime KPI's four/three-tile split reads
/// as one uniform gray grid today, which is exactly what the経営ダッシュボード
/// visual target asks this phase to fix — 現金・参画・待機・営業残 (row A, this
/// month's operating picture) should read as distinct, prioritized facts at
/// a glance, not four identical tiles a player has to read one by one.
///
/// This enum is the only thing that changes: it picks which accent color
/// family [_CompactKpiTile] paints a tile's icon badge and background tint
/// with. No value, icon, label, or computed figure changes — every number
/// still comes from [HomeDashboardDisplayData] exactly as before, and row B
/// (社員/売上/入金予定 — slower-moving context, not this month's decision)
/// deliberately keeps the original neutral tile styling so the contrast
/// itself reads as "these four matter most right now".
enum _KpiEmphasis {
  /// 現金 — the headline figure.
  cash,

  /// 参画 — filled capacity, good news.
  positive,

  /// 待機 — idle capacity, the figure most likely to need action.
  caution,

  /// 営業残 — an opportunity still open this month.
  action,

  /// Row B and every Phase 1A placeholder tile: unchanged neutral styling.
  neutral,
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
      emphasis: _KpiEmphasis.cash,
    ),
    _KpiTileData(
      icon: Icons.handshake_outlined,
      label: '参画',
      value: '${data.assignedEmployeeCount}名',
      tileKey: const Key('home-kpi-compact-assigned'),
      emphasis: _KpiEmphasis.positive,
    ),
    _KpiTileData(
      icon: Icons.chair_outlined,
      label: '待機',
      value: '${data.waitingEmployeeCount}名',
      tileKey: const Key('home-kpi-compact-waiting'),
      emphasis: _KpiEmphasis.caution,
    ),
    _KpiTileData(
      icon: Icons.campaign_outlined,
      label: '営業残',
      value: '${data.salesRemaining}回',
      tileKey: const Key('home-kpi-compact-sales-remaining'),
      emphasis: _KpiEmphasis.action,
    ),
  ],
  [
    _KpiTileData(
      icon: Icons.groups_outlined,
      label: '社員',
      // Issue #122: this tile is labeled 社員 (the whole company), so it
      // must read totalEmployeeCount (engineers + the 総務/general-affairs
      // employee), never employeeCount alone — that field is engineer-only
      // and already backs the separate "技術者数" tile above.
      value: '${data.totalEmployeeCount}名',
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

/// Above this ambient [TextScaler] factor, [_CompactKpi] stops packing
/// [_compactRowsFor]'s 4-and-3 tiles into two single rows and instead wraps
/// them into narrower sub-rows of [_wideColumnsPerRow] (then
/// [_narrowColumnsPerRow] past [_veryLargeTextScaleThreshold]) — see
/// [_CompactKpiTile]'s own doc for why the *value* text stops being wrapped
/// in `FittedBox(scaleDown)` at the very same threshold. The two changes
/// are one fix: extra column width is what keeps an enlarged value fitting
/// once the tile is no longer allowed to shrink it back down.
const double _largeTextScaleThreshold = 1.3;

/// Past this factor, tiles drop to one per sub-row instead of two — 2.0x
/// (Issue #147's own upper accessibility target) needs the full row width,
/// not just double, to keep the longest realistic value on one line.
const double _veryLargeTextScaleThreshold = 1.7;

const int _wideColumnsPerRow = 2;
const int _narrowColumnsPerRow = 1;

/// A practical linear scale factor for ambient [TextScaler] — used only to
/// choose a column count / whether to fit-shrink, never to resize text
/// ourselves (actual sizing stays the framework's job via the ambient
/// [TextScaler] every [Text] widget already honors).
double _effectiveTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(100) / 100;

class _CompactKpi extends StatelessWidget {
  const _CompactKpi({required this.data});

  final HomeDashboardDisplayData data;

  @override
  Widget build(BuildContext context) {
    final rows = _compactRowsFor(data);
    final scale = _effectiveTextScale(context);
    final columnsPerRow = scale >= _veryLargeTextScaleThreshold
        ? _narrowColumnsPerRow
        : scale >= _largeTextScaleThreshold
        ? _wideColumnsPerRow
        : null; // null: each row keeps its own natural width (4, then 3).
    return Card(
      key: const Key('home-kpi-compact'),
      margin: EdgeInsets.zero,
      child: Padding(
        // SES HOME Final Density: trimmed from 6 to 2 — real card padding,
        // not a text-height floor.
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              // SES HOME Final Density: trimmed from 4 to 2 — real gap
              // between the two KPI rows.
              if (i > 0) const SizedBox(height: 2),
              _CompactKpiRow(
                tiles: rows[i],
                columnsPerRow: columnsPerRow ?? rows[i].length,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One logical KPI row (4 tiles, or 3), chunked into [columnsPerRow]-wide
/// sub-rows stacked vertically. [columnsPerRow] equal to the tile count
/// renders exactly the original single Row; a smaller value is how
/// [_CompactKpi] gives each tile more width at a large text scale, per its
/// own doc.
class _CompactKpiRow extends StatelessWidget {
  const _CompactKpiRow({required this.tiles, required this.columnsPerRow});

  final List<_KpiTileData> tiles;
  final int columnsPerRow;

  @override
  Widget build(BuildContext context) {
    final chunks = <List<_KpiTileData>>[
      for (var i = 0; i < tiles.length; i += columnsPerRow)
        tiles.sublist(
          i,
          i + columnsPerRow > tiles.length ? tiles.length : i + columnsPerRow,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var c = 0; c < chunks.length; c++) ...[
          if (c > 0) const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < chunks[c].length; j++) ...[
                if (j > 0) const SizedBox(width: 6),
                Expanded(child: _CompactKpiTile(data: chunks[c][j])),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Icon-led label row, with the value on its own full-width line below:
/// the densest readable form of a KPI figure that still reads as icon-led,
/// per the approved PUBLIC-DEMO-HOME-UI-3A visual target. The label always
/// keeps `maxLines: 1` + ellipsis. Below [_largeTextScaleThreshold] the
/// value does too (wrapped in a shrink-to-fit `FittedBox`, since four tiles
/// share ~328pt of inner width at 360x800 at the default scale); at or
/// above it, the value is allowed to wrap onto a second line instead — see
/// the `Builder` in [build] for why.
///
/// PUBLIC-DEMO-HOME-UI-3A: adds the icon badge [_KpiTileData.icon] already
/// carried but never painted before this change. No `Key`, value format, or
/// label text changed — existing finders for `home-kpi-compact-*` keep
/// working unmodified.
///
/// The icon sits beside the LABEL, not the value: an earlier iteration put
/// it beside the value instead, which left too little width for a figure
/// like "¥400万" at 390pt and silently ellipsized it (caught by a dedicated
/// TextPainter-based regression test, since `find.text` alone cannot detect
/// paint-time ellipsis truncation). The value keeps the tile's full
/// content width instead — every label here ("現金","参画","待機",...) is
/// short enough to share its own line with a small badge without doing the
/// same.
/// HOME-COMPACT-1B.4: [_KpiEmphasis]'s accent color, resolved against the
/// live [ColorScheme] rather than a hard-coded literal so the tile still
/// reads correctly against the app's actual seeded theme. `neutral` returns
/// the same [ColorScheme.primary] the icon badge always used before this
/// phase, so a Row B tile paints pixel-identically to before.
Color _kpiAccentColor(_KpiEmphasis emphasis, ColorScheme colorScheme) =>
    switch (emphasis) {
      _KpiEmphasis.cash => colorScheme.primary,
      _KpiEmphasis.positive => const Color(0xFF2E7D32), // 参画: filled, good
      _KpiEmphasis.caution => const Color(0xFFEF6C00), // 待機: needs a look
      _KpiEmphasis.action => const Color(0xFF00838F), // 営業残: still open
      _KpiEmphasis.neutral => colorScheme.primary,
    };

class _CompactKpiTile extends StatelessWidget {
  const _CompactKpiTile({required this.data});

  final _KpiTileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // HOME-COMPACT-1B.4: row A (現金/参画/待機/営業残) reads as this month's
    // prioritized operating picture — a light accent tint plus a matching
    // border, instead of the same flat gray every tile used before. Row B
    // (emphasis stays `neutral`) is pixel-identical to the pre-1B.4 tile.
    final isEmphasized = data.emphasis != _KpiEmphasis.neutral;
    final accent = _kpiAccentColor(data.emphasis, colorScheme);
    return Container(
      key: data.tileKey,
      // SES HOME Final Density: vertical padding trimmed from 5 to 2 — real
      // tile padding, not a text-height floor.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isEmphasized
            ? accent.withValues(alpha: 0.09)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: isEmphasized
            ? Border.all(color: accent.withValues(alpha: 0.30))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: Icon(data.icon, size: 10, color: accent),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  data.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Builder(
            builder: (context) {
              final valueText = Text(
                data.value ?? '—',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isEmphasized ? accent : null,
                ),
                // A P2 fix (Issue #147 PR #150 review): at an enlarged
                // ambient TextScaler, this used to stay wrapped in
                // `FittedBox(scaleDown)` below, which measured the
                // enlarged value and then shrank it straight back down to
                // fit the same ~60pt tile — silently cancelling most or
                // all of the requested accessibility scale. Past
                // [_largeTextScaleThreshold], `_CompactKpiRow` above
                // already gives this tile a wider column (and, past
                // [_veryLargeTextScaleThreshold], the full row) instead,
                // so the enlarged value fits on its own — the value text
                // is left unshrunk and allowed to wrap to a second line
                // rather than being measured against a box no longer
                // guaranteed to hold it on one.
                maxLines:
                    _effectiveTextScale(context) >= _largeTextScaleThreshold
                    ? 2
                    : 1,
              );
              if (_effectiveTextScale(context) >= _largeTextScaleThreshold) {
                return valueText;
              }
              // Below the threshold: unchanged from before this fix — the
              // four/three-across row leaves as little as ~60pt for a
              // value like "¥400万", comfortable most months but tight
              // enough at the widest figures that a fixed font size
              // ellipsized real digits instead of a rare rounding
              // artifact (see this tile's own regression test in
              // public_demo_01_home_consolidation_test.dart). Scaling
              // down keeps every digit visible at the *default* scale,
              // where there is no wider column to grow into instead.
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: valueText,
              );
            },
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
