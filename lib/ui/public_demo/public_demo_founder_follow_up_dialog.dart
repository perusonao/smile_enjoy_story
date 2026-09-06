import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_founder_follow_up.dart';
import '../../game/public_demo/public_demo_sales.dart';

/// Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1's decision dialog — mirrors
/// [PublicDemoRaiseDialog]'s shape (public_demo_raise_dialog.dart): a short
/// explanation of the trade-off, then one button per
/// [PublicDemoFounderFollowUpDecision]. [canAffordInvestSupport] disables
/// the paid choice rather than ever letting the player pick a choice
/// [PublicDemoAggregate.applyFounderFollowUpDecision] would silently reject
/// as unaffordable — no dead CTA, matching every other Public Demo command.
class PublicDemoFounderFollowUpDialog extends StatelessWidget {
  const PublicDemoFounderFollowUpDialog({
    super.key,
    required this.engineer,
    required this.canAffordInvestSupport,
  });

  final PublicDemoEngineerSales engineer;
  final bool canAffordInvestSupport;

  @override
  Widget build(BuildContext context) {
    final cost = PublicDemoFounderFollowUp.investSupportCost;
    Widget choice(
      PublicDemoFounderFollowUpDecision decision,
      String label, {
      bool enabled = true,
    }) => FilledButton.tonal(
      key: Key('public-demo-founder-follow-up-${decision.name}'),
      onPressed: enabled ? () => Navigator.pop(context, decision) : null,
      child: Text(label),
    );
    return AlertDialog(
      title: Text('${engineer.name}のフォロー'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('現場への参画が続き、しばらく声をかけていません。どう対応しますか？'),
          const SizedBox(height: 12),
          const Text(
            '・そのまま任せる：費用なし。メンタル・信頼はやや下がります。',
            style: TextStyle(fontSize: 12),
          ),
          const Text(
            '・声をかける：費用なし。メンタル・信頼が少し上がります。',
            style: TextStyle(fontSize: 12),
          ),
          Text(
            '・支援に投資する：¥$cost。メンタル・信頼が大きく上がります。'
            '${canAffordInvestSupport ? '' : '（資金不足のため選択できません）'}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        choice(PublicDemoFounderFollowUpDecision.holdBack, 'そのまま任せる'),
        choice(PublicDemoFounderFollowUpDecision.checkIn, '声をかける'),
        choice(
          PublicDemoFounderFollowUpDecision.investSupport,
          '支援に投資する',
          enabled: canAffordInvestSupport,
        ),
      ],
    );
  }
}
