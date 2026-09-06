import 'package:flutter/material.dart';

import '../theme.dart';
import 'public_demo_year_end_display_data.dart';

/// SES YEAR-END-PHASE-1: one label/value line inside [PublicDemoYearEndResultCard].
///
/// Label above, value below (matching the existing
/// `PublicDemoFinanceSummarySection`/`_FinanceRow` pattern) rather than a
/// horizontal `Row` — a `Row`'s non-flex value `Text` takes its full
/// intrinsic width before the flex label gets any space, so a long value
/// (e.g. "¥4,000,000 → ¥5,200,000") genuinely overflowed at 360/390px in
/// that layout. Stacking vertically gives the value the full card width to
/// wrap into instead, which cannot overflow at any width this screen
/// supports.
class _YearEndStatRow extends StatelessWidget {
  const _YearEndStatRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

/// SES YEAR-END-PHASE-1: the accounting tab's existing "第1期終了" area,
/// enhanced to show the year's authoritative facts instead of only the
/// final cash balance — see [PublicDemoYearEndDisplayData]'s own doc for
/// exactly which fields back each line and why nothing here is fabricated.
///
/// [onReplay] is wired by the caller to the SAME canonical restart
/// confirmation flow the existing "開発・テストメニュー" and bankruptcy
/// terminal card already use ([PublicDemo01PlaceholderScreen
/// ._confirmRestartFromApril]/`_restartGame`) — this widget defines no
/// reset behavior of its own, only a button that invokes whatever callback
/// it is given.
class PublicDemoYearEndResultCard extends StatelessWidget {
  const PublicDemoYearEndResultCard({
    super.key,
    required this.data,
    required this.onReplay,
    this.isReplaying = false,
  });

  final PublicDemoYearEndDisplayData data;
  final VoidCallback onReplay;

  /// Mirrors the existing restart buttons' own in-flight guard
  /// (`_isRestarting`) so this CTA cannot be double-tapped while a restart
  /// is already in progress elsewhere on screen.
  final bool isReplaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('public-demo-fiscal-year-complete'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('第1期終了', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('1年間の経営が終了しました。'),
            const SizedBox(height: 12),

            Text(
              '資金',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 12),
            _YearEndStatRow(
              label: '開始時現金 → 終了時現金',
              value:
                  '${formatYen(data.startingCash)} → ${formatYen(data.finalCash)}',
            ),
            _YearEndStatRow(
              label: '年間の増減',
              value: data.cashDelta >= 0
                  ? '+${formatYen(data.cashDelta)}'
                  : '-${formatYen(-data.cashDelta)}',
            ),
            const SizedBox(height: 12),

            Text(
              '人員',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 12),
            _YearEndStatRow(
              label: '最終社員数',
              value: '${data.finalEmployeeCount}名',
            ),
            _YearEndStatRow(
              label: '年間採用数',
              value: '${data.annualHireCount}名',
            ),
            _YearEndStatRow(
              label: '最終参画人数',
              value: '${data.finalParticipatingCount}名',
            ),
            _YearEndStatRow(
              label: '最終待機人数',
              value: '${data.finalWaitingCount}名',
            ),
            const SizedBox(height: 12),

            Text(
              '創業社員の成長',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 12),
            for (final founder in data.founderGrowth)
              _YearEndStatRow(
                key: Key('public-demo-year-end-founder-growth-${founder.engineerId}'),
                label: founder.name,
                value:
                    '${founder.initialCapability} → ${founder.currentCapability}'
                    ' (${founder.capabilityDelta >= 0 ? '+' : ''}${founder.capabilityDelta})',
              ),
            const SizedBox(height: 12),

            Text(
              'ひよりからの年度総括',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 12),
            Text(
              key: const Key('public-demo-year-end-hiyori-summary'),
              publicDemoYearEndHiyoriSummary(data),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('public-demo-year-end-replay-button'),
                onPressed: isReplaying ? null : onReplay,
                child: Text(isReplaying ? '再開準備中…' : '4月からもう一度'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
