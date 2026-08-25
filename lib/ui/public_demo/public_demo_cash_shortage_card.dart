import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_financial_status.dart';
import '../../game/public_demo/public_demo_state.dart';
import '../theme.dart';

/// Player-facing FINANCE-FAILURE-1C explanation for the one-close grace
/// period. Financial health is read only from [PublicDemoState.financialStatus];
/// this widget never infers authority from the sign of cash.
class PublicDemoCashShortageCard extends StatelessWidget {
  const PublicDemoCashShortageCard({super.key, required this.state});

  final PublicDemoState state;

  @override
  Widget build(BuildContext context) {
    if (state.financialStatus != PublicDemoFinancialStatus.cashShortage) {
      return const SizedBox.shrink();
    }

    final deficit = state.cash < 0 ? -state.cash : 0;

    return Card(
      key: const Key('public-demo-cash-shortage-card'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  '資金不足：次回決算が期限です',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Row('現在の現預金', formatYen(state.cash)),
            _Row('不足額', formatYen(deficit)),
            _Row('次回入金予定（売掛金）', formatYen(state.pendingRevenue)),
            const Divider(height: 18),
            const Text(
              '次回の月次決算で現預金が0円以上になれば回復します。'
              '赤字のままの場合は倒産となります。',
            ),
            const SizedBox(height: 8),
            Text(
              '営業・案件参画・既存社員の活動は継続できます。'
              '新規採用、給与債務を伴う内定、社内研修、有償賞与などの追加支出は制限されます。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
