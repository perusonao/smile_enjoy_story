import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_recruitment.dart';
import '../../game/public_demo/public_demo_revenue_payment.dart';
import '../../game/public_demo/public_demo_state.dart';
import '../../game/public_demo/public_demo_summer_bonus_payment.dart';
import '../../game/public_demo/public_demo_summer_bonus_plan.dart';

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

  int _amount(PublicDemoSummerBonusPlan plan) =>
      PublicDemoSummerBonusPayment.calculateSummerBonus(
        plan: plan,
        applicants: applicants,
        month: 7,
      );

  String _yen(int amount) =>
      '¥${amount.toString().replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+$)'), (_) => ',')}';

  @override
  Widget build(BuildContext context) {
    // Same-close preview: closeJuly settles pendingRevenue into cash before
    // its own cash guard runs (PublicDemoMonthlyClose.closeJuly), so this
    // reuses the same transaction to keep the preview's affordability basis
    // identical to what the close actually checks.
    final availableCash = PublicDemoRevenuePayment.apply(
      state: state,
    ).state.cash;
    Widget choice(PublicDemoSummerBonusPlan plan, String label) {
      final amount = _amount(plan);
      final projectedCash = availableCash - monthlyExpenses - amount;
      final enabled = projectedCash >= 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FilledButton.tonal(
          key: Key('public-demo-summer-bonus-${plan.name}'),
          onPressed: enabled ? () => Navigator.pop(context, plan) : null,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text('支給総額 ${_yen(amount)}'),
                Text('支給後の予想現預金 ${_yen(projectedCash)}'),
                if (!enabled) const Text('現預金不足のため選択できません'),
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
