import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_monthly_cash_flow.dart';
import '../../game/public_demo/public_demo_month_label.dart';
import '../theme.dart';

/// A compact, player-facing explanation of a completed Public Demo month's
/// cash movement (FINANCE-UX-1).
///
/// This renders only [PublicDemoMonthlyCashFlow]'s recorded facts — it does
/// not recompute salary, revenue, or receivables. The always-visible rows
/// satisfy the core accounting contract (openingCash + inflow - outflow =
/// closingCash) at a glance; the itemized breakdown and the 30-day
/// receivable explanation live behind an [ExpansionTile] so the card stays
/// short on a phone screen.
class PublicDemoMonthlyCashFlowCard extends StatelessWidget {
  const PublicDemoMonthlyCashFlowCard({super.key, required this.flow});

  final PublicDemoMonthlyCashFlow flow;

  @override
  Widget build(BuildContext context) {
    final monthLabel = publicDemoMonthLabel(flow.month);
    return Card(
      key: const Key('public-demo-monthly-cash-flow-card'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$monthLabel 月次決算：現預金の内訳',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _Row('月初現預金', formatYen(flow.openingCash)),
            _Row('入金', '+${formatYen(flow.cashReceived)}'),
            _Row('支出合計', '-${formatYen(flow.totalOutflow)}'),
            const Divider(height: 16),
            _Row(
              '月末現預金',
              formatYen(flow.closingCash),
              emphasis: true,
              color: flow.closingCash >= 0
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
            const SizedBox(height: 10),
            _Row('売上', formatYen(flow.revenue)),
            _Row('売掛金（来月入金予定）', formatYen(flow.receivables)),
            if (flow.revenue > 0) ...[
              const SizedBox(height: 4),
              Text(
                '今月の売上は来月に入金されます',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const Key('public-demo-monthly-cash-flow-details'),
                tilePadding: EdgeInsets.zero,
                title: const Text('支出の内訳を見る', style: TextStyle(fontSize: 13)),
                childrenPadding: const EdgeInsets.only(bottom: 4),
                children: [
                  _Row('給与', '-${formatYen(flow.salaryPaid)}'),
                  _Row('固定費', '-${formatYen(flow.fixedCostsPaid)}'),
                  if (flow.bonusPaid > 0)
                    _Row('賞与', '-${formatYen(flow.bonusPaid)}'),
                  if (flow.trainingCost > 0)
                    _Row('研修費', '-${formatYen(flow.trainingCost)}'),
                  if (flow.recruitmentCost > 0)
                    _Row('採用費', '-${formatYen(flow.recruitmentCost)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasis = false, this.color});

  final String label;
  final String value;
  final bool emphasis;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasis ? 15 : 13.5,
              fontWeight: emphasis ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasis ? 15 : 13.5,
            fontWeight: emphasis ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}
