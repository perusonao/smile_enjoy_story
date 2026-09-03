import 'package:flutter/material.dart';

import '../models/home_dashboard_display_data.dart';

/// Month-display header shown at the top of the home dashboard.
///
/// HOME-UI-1C: when [data] is supplied, renders the real current year/month
/// from [HomeDashboardDisplayData] (a read-only presentation projection of
/// the authoritative Public Demo finance state — see its own class doc).
/// [data] stays optional and defaults to `null`, which keeps rendering the
/// original Phase 1A fixed placeholder label — this widget has no
/// unconnected-caller behavior change.
class MonthHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const MonthHeaderBar({super.key, this.data});

  final HomeDashboardDisplayData? data;

  // HOME-COMPACT-1B.4: trimmed from 48 — this bar states a single short
  // line ("1年目 4月"), and the acceptance criteria for the
  // 経営ダッシュボード visual target need the room more than this bar's
  // original vertical padding did. `alignment: Alignment.center` still
  // centers the label inside whatever height this is, so nothing about the
  // label itself changed, only how much empty space surrounds it.
  static const double barHeight = 36;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = data == null
        ? '1年目 4月'
        : '${data!.year}年目 ${data!.monthLabel}';
    return Container(
      height: barHeight,
      color: colorScheme.primaryContainer,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);
}
