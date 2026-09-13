import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_recruitment.dart';
import '../../game/public_demo/public_demo_monthly_close.dart';
import '../../game/public_demo/public_demo_state.dart';
import '../../game/public_demo/public_demo_summer_bonus_payment.dart';
import '../../game/public_demo/public_demo_summer_bonus_plan.dart';
import '../theme.dart';

/// July-only decision UI. It previews the same transaction settled at close.
class PublicDemoSummerBonusDialog extends StatelessWidget {
  const PublicDemoSummerBonusDialog({
    super.key,
    required this.state,
    required this.applicants,
    required this.monthlyExpenses,
  });

  final PublicDemoState state;
  final Iterable<PublicDemoApplicant> applicants;
  final int monthlyExpenses;

  /// FIRST-FUN-QUARTER-VISUAL-POLISH P1-E: one icon per plan so the three
  /// choices are visually scannable, not three identically-styled buttons
  /// distinguished only by their numbers. Reuses the exact
  /// `Icons.card_giftcard_outlined` this feature's own entry-point card
  /// already shows (`_accountingDecisionSection` in
  /// `public_demo_01_placeholder_screen.dart`) for the largest, headline
  /// plan, and two related Material icons already used elsewhere in this
  /// app's own icon language — never a new asset, never an emoji.
  static const _planIcons = {
    PublicDemoSummerBonusPlan.none: Icons.money_off_outlined,
    PublicDemoSummerBonusPlan.half: Icons.paid_outlined,
    PublicDemoSummerBonusPlan.one: Icons.card_giftcard_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget choice(PublicDemoSummerBonusPlan plan, String label) {
      final preview = PublicDemoMonthlyClose.previewJuly(
        state: state,
        monthlyExpenses: monthlyExpenses,
        applicants: applicants,
        plan: plan,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FilledButton.tonal(
          key: Key('public-demo-summer-bonus-${plan.name}'),
          onPressed: preview.isEligible
              ? () => Navigator.pop(context, plan)
              : null,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_planIcons[plan], size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('支給総額 ${formatYen(preview.bonusAmount)}'),
                      Text('支給後の予想現預金 ${formatYen(preview.projectedCash)}'),
                      if (preview.eligibility ==
                          PublicDemoSummerBonusEligibility.insufficientCash)
                        const Text('現預金不足のため選択できません'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.card_giftcard_outlined, color: Color(0xFF8A5A00)),
          SizedBox(width: 8),
          Text('夏季賞与'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('在籍技術者へ、現在の月給を基準に7月分の賞与を支給します。'),
            const SizedBox(height: 16),
            choice(PublicDemoSummerBonusPlan.none, 'なし'),
            choice(PublicDemoSummerBonusPlan.half, '0.5か月'),
            choice(PublicDemoSummerBonusPlan.one, '1か月'),
          ],
        ),
      ),
    );
  }
}
