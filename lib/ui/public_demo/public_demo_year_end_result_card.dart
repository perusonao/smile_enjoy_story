import 'package:flutter/material.dart';

import '../../presentation/year_end/models/public_demo_year_end_display_data.dart';
import '../theme.dart';

/// Mobile-first result presentation shared by successful fiscal completion
/// and both authoritative terminal financial outcomes.
class PublicDemoYearEndResultCard extends StatelessWidget {
  const PublicDemoYearEndResultCard({
    super.key,
    required this.data,
    required this.onRestart,
    this.isRestarting = false,
  });

  final PublicDemoYearEndDisplayData data;
  final VoidCallback? onRestart;
  final bool isRestarting;

  @override
  Widget build(BuildContext context) {
    final success = data.outcome.isSuccess;
    final accent = success ? Colors.blue.shade700 : Colors.red.shade800;
    final background = success ? Colors.blue.shade50 : Colors.red.shade50;

    return Card(
      key: Key(
        success
            ? 'public-demo-fiscal-year-complete'
            : 'public-demo-bankruptcy-card',
      ),
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const Key('public-demo-year-end-result'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success
                      ? Icons.emoji_events_outlined
                      : Icons.business_outlined,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        success ? '年度終了' : '経営終了',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _title,
                        style: TextStyle(
                          color: accent,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(data.story),
            const SizedBox(height: 18),
            Text('最終現預金', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatYen(data.cash),
                key: const Key('public-demo-year-end-final-cash'),
                style: TextStyle(
                  color: data.cash >= 0 ? Colors.green.shade800 : accent,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('public-demo-restart-button'),
                onPressed: isRestarting ? null : onRestart,
                icon: const Icon(Icons.replay),
                label: Text(isRestarting ? '再開準備中…' : 'もう一度プレイする'),
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('最終会社状態'),
            const SizedBox(height: 6),
            _FactRow('社員数', '${data.employeeCount}名'),
            _FactRow(
              '社員構成',
              '技術 ${data.engineerCount}名 / 管理 ${data.adminCount}名',
            ),
            _FactRow(
              '案件状況',
              '参画 ${data.assignedCount}名 / 待機 ${data.waitingCount}名',
              valueKey: const Key('public-demo-year-end-assignment-counts'),
            ),
            _FactRow('採用結果', '入社 ${data.hiredCount}名'),
            _FactRow('未回収の売掛金', formatYen(data.pendingReceivables)),
            _FactRow('夏季賞与', data.summerBonusDecision),
            if (data.latestMonthLabel != null) ...[
              const SizedBox(height: 14),
              _SectionTitle('${data.latestMonthLabel}の経営結果'),
              const SizedBox(height: 6),
              _FactRow('入金', formatYen(data.latestCashReceived!)),
              _FactRow('支出', formatYen(data.latestOutflow!)),
              _FactRow('現預金増減', _signedYen(data.latestCashMovement!)),
              _FactRow('月末現預金', formatYen(data.latestClosingCash!)),
            ],
          ],
        ),
      ),
    );
  }

  String get _title => switch (data.outcome) {
    PublicDemoYearEndOutcome.completed => '第1期終了',
    PublicDemoYearEndOutcome.bankruptcy => '倒産',
    PublicDemoYearEndOutcome.marchCashShortageFailure => '3月資金不足',
  };

  static String _signedYen(int amount) =>
      amount > 0 ? '+${formatYen(amount)}' : formatYen(amount);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value, {this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            key: valueKey,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
