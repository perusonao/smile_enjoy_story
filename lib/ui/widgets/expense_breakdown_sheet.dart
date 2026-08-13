import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../theme.dart';

/// 今週収支 の内訳モーダル (§7): 案件売上 / 給与 / 求人費 / 固定費.
void showExpenseBreakdownSheet(BuildContext context, GameState state) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _ExpenseBreakdownSheet(state: state),
  );
}

class _ExpenseBreakdownSheet extends StatelessWidget {
  const _ExpenseBreakdownSheet({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final profit = state.lastWeekProfit;
    final profitColor = profit >= 0 ? Colors.green.shade700 : Colors.red.shade700;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Week ${state.displayWeek} の収支内訳', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${profit >= 0 ? '+' : ''}${formatYen(profit)}',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: profitColor),
          ),
          const SizedBox(height: 16),
          _Row(label: '案件売上', value: state.lastWeekRevenue, positive: true),
          _Row(label: '給与', value: -state.lastWeekSalary, positive: false),
          if (state.lastWeekRecruitmentCost > 0)
            _Row(label: '求人費', value: -state.lastWeekRecruitmentCost, positive: false),
          _Row(label: '固定費', value: -weeklyFixedCost, positive: false),
          const Divider(height: 24),
          _Row(label: '今週収支', value: profit, positive: profit >= 0, emphasis: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.positive,
    this.emphasis = false,
  });

  final String label;
  final int value;
  final bool positive;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final color = emphasis
        ? (positive ? Colors.green.shade700 : Colors.red.shade700)
        : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            '${value >= 0 ? '+' : ''}${formatYen(value)}',
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
}
