import 'package:flutter/material.dart';

/// A single skill/experience tag (Playable 0.4C.3 §3) — Java 5年, Backend
/// Lv.3, Leader, 金融経験 etc. — for screens that currently only render this
/// as plain prose rows. Purely a visual re-presentation of data the row-list
/// view already shows; never used anywhere the underlying value itself is
/// meant to stay hidden from the player.
class SkillChip extends StatelessWidget {
  const SkillChip(this.label, {super.key, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }
}

/// A `Wrap` of [SkillChip]s — the standard layout for a skill-tag summary
/// row.
class SkillChipRow extends StatelessWidget {
  const SkillChipRow({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}
