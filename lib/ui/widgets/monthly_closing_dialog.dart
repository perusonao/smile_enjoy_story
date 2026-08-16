import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../theme.dart';

/// 月次決算モーダル (Playable 0.3A §20): shown every 4th week, right after
/// the month's accounting has closed. Deliberately keeps 会計上利益 (an
/// accrual number) and 現金増減 (the actual cash change) as two separate
/// lines so "利益は黒字でも現金は減った" is visible at a glance (§21).
Future<void> showMonthlyClosingDialog(BuildContext context, MonthlyClosing closing) {
  final profitColor =
      closing.accountingProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700;
  final cashColor = closing.monthCashMovement >= 0 ? Colors.green.shade700 : Colors.red.shade700;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('${closing.label} 月次決算'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row('案件売上', closing.projectRevenue),
            _Row('売掛金発生', closing.accountsReceivableGenerated),
            _Row('今月入金', closing.cashCollected),
            const Divider(height: 20),
            _Row('給与', -closing.salaryPaid),
            _Row('家賃', -closing.rentPaid),
            _Row('固定費', -closing.otherFixedCost),
            if (closing.recruitmentCost > 0) _Row('求人費', -closing.recruitmentCost),
            const Divider(height: 20),
            _SummaryRow(
              label: '会計上利益',
              value: closing.accountingProfit,
              color: profitColor,
            ),
            const SizedBox(height: 4),
            _SummaryRow(
              label: '現金増減',
              value: closing.monthCashMovement,
              color: cashColor,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: SesTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatYen(closing.cashBefore), style: const TextStyle(fontSize: 13)),
                  const Icon(Icons.arrow_forward, size: 14, color: Colors.black45),
                  Text(
                    formatYen(closing.cashAfter),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (closing.accountingProfit >= 0 && closing.monthCashMovement < 0) ...[
              const SizedBox(height: 10),
              const Text(
                '利益は黒字ですが、売掛金の入金が翌月以降のため現金は減っています。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            '${value >= 0 ? '+' : ''}${formatYen(value)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
        ),
        Text(
          '${value >= 0 ? '+' : ''}${formatYen(value)}',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
