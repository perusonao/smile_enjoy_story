import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../theme.dart';

/// 今月の資金状況 モーダル (Playable 0.3A §10-12): live projection of this
/// month's expected in/outflow plus the last closed month's actuals, so the
/// player can see both "where things stand now" and "what just happened".
void showExpenseBreakdownSheet(BuildContext context, GameState state) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _FinanceSheet(state: state),
  );
}

class _FinanceSheet extends StatelessWidget {
  const _FinanceSheet({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final cash = state.company.cash;
    final arBalance = FinanceEngine.totalPendingAr(state);
    final inflow = FinanceEngine.expectedInflowThisMonth(state);
    final outflow = FinanceEngine.expectedOutflowThisMonth(state);
    final projected = FinanceEngine.projectedMonthEndCash(state);
    final projectedColor = projected >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    final runway = FinanceEngine.cashRunwayMonths(state);
    final closing = state.latestClosing;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('今月の資金状況', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _Row(label: '現預金', value: cash, emphasis: true),
            _Row(label: '売掛金', value: arBalance),
            const Divider(height: 20),
            _Row(label: '今月入金予定', value: inflow, positive: true),
            _Row(label: '今月支払予定', value: -outflow, positive: false),
            const Divider(height: 20),
            _Row(label: '月末予想現金', value: projected, positive: projected >= 0, emphasis: true, color: projectedColor),
            const SizedBox(height: 10),
            RunwayIndicator(months: runway),
            if (closing != null) ...[
              const SizedBox(height: 18),
              Text('${closing.label} の実績', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              _Row(label: '会計上利益', value: closing.accountingProfit, positive: closing.accountingProfit >= 0),
              _Row(label: '現金増減', value: closing.monthCashMovement, positive: closing.monthCashMovement >= 0),
            ],
          ],
        ),
      ),
    );
  }
}

/// 資金余命 (§12): green ≥6 months, yellow 3-6 months, red <3 months.
class RunwayIndicator extends StatelessWidget {
  const RunwayIndicator({super.key, required this.months, this.compact = false});

  final double months;
  final bool compact;

  static Color colorFor(RunwayLevel level) => switch (level) {
    RunwayLevel.safe => Colors.green.shade700,
    RunwayLevel.caution => Colors.orange.shade800,
    RunwayLevel.danger => Colors.red.shade700,
  };

  static String labelFor(double months) {
    if (!months.isFinite) return '資金は減少していません';
    return '約${months.toStringAsFixed(1)}か月で資金枯渇';
  }

  @override
  Widget build(BuildContext context) {
    final level = FinanceEngine.classifyRunway(months);
    final color = colorFor(level);
    final label = labelFor(months);
    if (compact) {
      return Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom, color: color, size: 18),
          const SizedBox(width: 8),
          Text('資金余命: $label', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.positive = true,
    this.emphasis = false,
    this.color,
  });

  final String label;
  final int value;
  final bool positive;
  final bool emphasis;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ??
        (emphasis ? (positive ? Colors.green.shade700 : Colors.red.shade700) : Colors.black87);
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
              color: resolvedColor,
            ),
          ),
        ],
      ),
    );
  }
}
