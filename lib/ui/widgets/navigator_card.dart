import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../theme.dart';

/// The 総務ナビゲーター's expression (Playable 0.4C.4 §12) — a small nudge
/// away from "無機質なチュートリアルメッセージ" toward "創業期を一緒に進める
/// スタッフとの会話". Deliberately just an icon + tint swap, not new
/// dialogue volume: the card's own [NavigatorCard.message] stays exactly as
/// short as before.
enum NavigatorMood { normal, moneyDanger, firstHire, firstContract }

class _MoodStyle {
  const _MoodStyle({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}

const _moodStyles = <NavigatorMood, _MoodStyle>{
  NavigatorMood.normal: _MoodStyle(icon: Icons.support_agent, color: SesTheme.primaryBlue),
  NavigatorMood.moneyDanger: _MoodStyle(icon: Icons.sentiment_dissatisfied, color: Color(0xFFC62828)),
  NavigatorMood.firstHire: _MoodStyle(icon: Icons.sentiment_satisfied, color: Color(0xFF2E7D32)),
  NavigatorMood.firstContract: _MoodStyle(icon: Icons.celebration, color: Color(0xFFF9A825)),
};

/// `state`'s cash runway overrides any [base] mood (Playable 0.4C.4 §12) —
/// money trouble is the one thing the 総務 should never look upbeat about,
/// even mid-celebration-flavored stage.
NavigatorMood navigatorMoodFor(GameState state, {NavigatorMood base = NavigatorMood.normal}) {
  final level = FinanceEngine.classifyRunway(FinanceEngine.cashRunwayMonths(state));
  return level == RunwayLevel.danger ? NavigatorMood.moneyDanger : base;
}

/// The 総務ナビゲーター card (Playable 0.5A §67): a face icon + name, one
/// short message, and a single primary action — Home During the Prologue
/// is always exactly this one card (§66), never a checklist.
class NavigatorCard extends StatelessWidget {
  const NavigatorCard({
    super.key,
    required this.navigatorName,
    required this.message,
    this.secondaryMessage,
    this.ctaLabel,
    this.onCta,
    this.secondaryCtaLabel,
    this.onSecondaryCta,
    this.mood = NavigatorMood.normal,
  });

  final String navigatorName;
  final String message;
  final String? secondaryMessage;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final String? secondaryCtaLabel;
  final VoidCallback? onSecondaryCta;
  final NavigatorMood mood;

  @override
  Widget build(BuildContext context) {
    final style = _moodStyles[mood]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: style.color, child: Icon(style.icon, color: Colors.white, size: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('総務 $navigatorName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (secondaryMessage != null) ...[
            const SizedBox(height: 8),
            Text(secondaryMessage!, style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4)),
          ],
          if (ctaLabel != null) ...[
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: onCta, child: Text(ctaLabel!))),
          ],
          if (secondaryCtaLabel != null) ...[
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onSecondaryCta, child: Text(secondaryCtaLabel!))),
          ],
        ],
      ),
    );
  }
}
