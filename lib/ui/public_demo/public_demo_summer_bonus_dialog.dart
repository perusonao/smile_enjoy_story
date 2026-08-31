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

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text('支給総額 ${formatYen(preview.bonusAmount)}'),
                Text('支給後の予想現預金 ${formatYen(preview.projectedCash)}'),
                if (preview.eligibility ==
                    PublicDemoSummerBonusEligibility.insufficientCash)
                  const Text('現預金不足のため選択できません'),
              ],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('夏季賞与'),
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
