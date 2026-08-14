import 'package:flutter/material.dart';

import '../theme.dart';

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
  });

  final String navigatorName;
  final String message;
  final String? secondaryMessage;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final String? secondaryCtaLabel;
  final VoidCallback? onSecondaryCta;

  @override
  Widget build(BuildContext context) {
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
              const CircleAvatar(radius: 16, backgroundColor: SesTheme.primaryBlue, child: Icon(Icons.support_agent, color: Colors.white, size: 18)),
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
