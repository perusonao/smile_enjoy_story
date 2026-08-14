import 'package:flutter/material.dart';

/// A compact label/value tile used on the Home screen's stat grid.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasis;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // FittedBox instead of a fixed style + ellipsis: a 3-column row at
          // 360px leaves each tile ~85px of usable width, and a value like
          // "約3.8か月" at titleLarge silently truncated to "約3.8か…"
          // (Playable 0.4C.3 §52) — shrinking to fit keeps the full string
          // always readable instead of clipping it.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style:
                  (emphasis
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: valueColor ?? theme.colorScheme.onSurface,
                      ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
