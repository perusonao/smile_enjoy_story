import 'package:flutter/material.dart';

import '../../game/game.dart';

/// The ◎○△× fit rating shown to the player instead of a raw score (§15).
class FitBadge extends StatelessWidget {
  const FitBadge({super.key, required this.fit});

  final PlayerVisibleFit fit;

  @override
  Widget build(BuildContext context) {
    final color = switch (fit) {
      PlayerVisibleFit.excellent => Colors.blue,
      PlayerVisibleFit.good => Colors.teal,
      PlayerVisibleFit.fair => Colors.orange,
      PlayerVisibleFit.poor => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fit.symbol,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 4),
          Text(
            fit.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
