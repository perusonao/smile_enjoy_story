import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_financial_status.dart';
import '../../game/public_demo/public_demo_state.dart';
import '../theme.dart';

/// Player-facing FINANCE-FAILURE-1C explanation for the one-close grace
/// period. Financial health is read only from [PublicDemoState.financialStatus];
/// this widget never infers authority from the sign of cash.
///
/// HOME-COMPACT-1B.4 FIX1: this card used to spend ~245pt at 360x800 —
/// enough on its own to push 社員の様子 (HomeOfficeStageSection) out of the
/// unscrolled initial view during an actual shortage, the one state the
/// screen-verification acceptance criteria did not yet cover. Every trim
/// below is spacing/typography only: the same three evidence figures
/// ([state.cash], [deficit], [state.pendingRevenue]), the same recovery
/// rule, the same restricted-spend explanation, and the same card identity
/// ([Key], ordering above [MonthHeaderBar]/[PublicDemoHomeDashboardSection])
/// the existing suites already pin. Nothing about *when* this card renders,
/// or what it says, changed — only how much room it spends saying it.
class PublicDemoCashShortageCard extends StatelessWidget {
  const PublicDemoCashShortageCard({super.key, required this.state});

  final PublicDemoState state;

  @override
  Widget build(BuildContext context) {
    if (state.financialStatus != PublicDemoFinancialStatus.cashShortage) {
      return const SizedBox.shrink();
    }

    final deficit = state.cash < 0 ? -state.cash : 0;
    final theme = Theme.of(context);

    return Card(
      key: const Key('public-demo-cash-shortage-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade700,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '資金不足：次回決算が期限です',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Tile('現在の現預金', formatYen(state.cash))),
                const SizedBox(width: 6),
                Expanded(child: _Tile('不足額', formatYen(deficit))),
                const SizedBox(width: 6),
                Expanded(
                  child: _Tile('次回入金予定（売掛金）', formatYen(state.pendingRevenue)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '次回の月次決算で現預金が0円以上になれば回復します。'
              '赤字のままの場合は倒産となります。'
              '営業・案件参画・既存社員の活動は継続できます。'
              '新規採用、給与債務を伴う内定、社内研修、有償賞与などの追加支出は制限されます。',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One evidence figure: its label above its bold value, both single-line —
/// three of these now share one row instead of each taking a full-width
/// row of its own (HOME-COMPACT-1B.4 FIX1's biggest single saving in this
/// card). The label and the value stay two separate [Text] widgets with
/// their original exact strings — `find.text('次回入金予定（売掛金）')` and
/// `find.text('¥500,000')` still match unchanged, since `TextOverflow
/// .ellipsis`/`FittedBox` only affect painting, never the underlying text
/// data — so the existing per-figure assertions in
/// public_demo_cash_shortage_card_test.dart needed no update.
///
/// `FittedBox(scaleDown)` on the value follows the same pattern
/// [KpiSection]'s compact tiles already use: the longest realistic label
/// here ("次回入金予定（売掛金）") now shares roughly a third of a 360pt-wide
/// card with a signed yen figure, and shrinking the value instead of
/// wrapping or clipping it is what keeps both readable at the smaller
/// target width.
class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
        ),
      ),
    ],
  );
}
