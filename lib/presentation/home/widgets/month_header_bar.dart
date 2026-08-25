import 'package:flutter/material.dart';

/// Static month-display header shown at the top of the home dashboard.
///
/// Phase 1A renders a fixed placeholder turn label only. Wiring this to the
/// company's real `currentWeek` / calendar state is out of scope until a
/// later phase.
class MonthHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const MonthHeaderBar({super.key});

  static const double barHeight = 48;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: barHeight,
      color: colorScheme.primaryContainer,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '1年目 4月',
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
