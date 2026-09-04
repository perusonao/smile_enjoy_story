import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_cash_forecast.dart';
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
  const PublicDemoCashShortageCard({
    super.key,
    required this.state,
    required this.nextClose,
  });

  final PublicDemoState state;

  /// The next monthly close's forecast entry — [PublicDemoCashForecast
  /// .forecast]'s own first projected month, read-only. This card never
  /// recomputes that projection itself; see
  /// [PublicDemoCashShortageOutlook.fromForecastEntry] for how it turns
  /// this single confirmed-information fact into the truthful headline
  /// below. `null` only when the caller could not produce a forecast entry
  /// (should not happen while [state.financialStatus] is
  /// [PublicDemoFinancialStatus.cashShortage], since that status is never
  /// close-blocked — see [PublicDemoCashShortageOutlook]'s own doc for the
  /// safe fallback this still renders).
  final PublicDemoCashForecastMonth? nextClose;

  @override
  Widget build(BuildContext context) {
    if (state.financialStatus != PublicDemoFinancialStatus.cashShortage) {
      return const SizedBox.shrink();
    }

    final deficit = state.cash < 0 ? -state.cash : 0;
    final outlook = PublicDemoCashShortageOutlook.fromForecastEntry(nextClose);
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
                const SizedBox(width: 6),
                Expanded(
                  child: _Tile(
                    '次回決算後見込み',
                    outlook.projectedClosingCash == null
                        ? '算出不可'
                        : formatYen(outlook.projectedClosingCash!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // HOME-COMPACT-1B.4 FIX1's height budget stays binding: the
            // headline/evidence-line/continuation prose is one continuously
            // wrapping paragraph (a single RichText), not three stacked
            // Text widgets, so an added evidence line never forces a whole
            // extra widget-block worth of vertical space on top of its own
            // wrapped line(s) — exactly the same packing the pre-existing
            // single-Text paragraph this replaces already relied on.
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.2,
                ),
                children: [
                  TextSpan(
                    text: outlook.headline,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: outlook.willRecover ? null : Colors.red.shade700,
                    ),
                  ),
                  if (outlook.expectedLine != null)
                    TextSpan(text: outlook.expectedLine),
                  const TextSpan(
                    text:
                        '営業・案件参画・既存社員の活動は継続できます。'
                        '新規採用、給与債務を伴う内定、社内研修、有償賞与などの追加支出は制限されます。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared, forecast-based outlook text for the resolved next monthly
/// close, built once from [PublicDemoCashForecast.forecast]'s own first
/// projected month and consumed identically by both
/// [PublicDemoCashShortageCard] and the HOME "資金不足を確認" dialog
/// (`PublicDemo01PlaceholderScreen._showCashShortageExplanation`) — so the
/// two surfaces can never disagree about whether the next close recovers.
///
/// This never recomputes a forecast or a shortage/safety threshold of its
/// own: [willRecover] is read directly off
/// [PublicDemoCashForecastMonth.isNegative]/`closingCash`, the exact same
/// fact the real monthly close will use to decide
/// [PublicDemoFinancialStatus.afterClose]. It only ever states what that
/// one confirmed projection already implies — never "回復します" (or any
/// other recovery-implying phrase) while the projected closing cash is
/// still negative.
class PublicDemoCashShortageOutlook {
  const PublicDemoCashShortageOutlook._({
    required this.projectedClosingCash,
    required this.willRecover,
    required this.headline,
    this.expectedLine,
  });

  factory PublicDemoCashShortageOutlook.fromForecastEntry(
    PublicDemoCashForecastMonth? nextClose,
  ) {
    if (nextClose == null) {
      // No forecast entry to read (should not happen while the caller is
      // in an actual, non-close-blocked shortage — see [nextClose]'s own
      // doc on the card). Never guesses a number or implies recovery.
      return const PublicDemoCashShortageOutlook._(
        projectedClosingCash: null,
        willRecover: false,
        headline: '次回決算後の見込みを算出できません。営業・案件参画の状況を確認してください。',
      );
    }
    if (!nextClose.isNegative) {
      return PublicDemoCashShortageOutlook._(
        projectedClosingCash: nextClose.closingCash,
        willRecover: true,
        headline:
            '次回の月次決算で現預金が${formatYen(nextClose.closingCash)}となり、'
            '資金不足から回復する見込みです。',
      );
    }
    final expectedCosts = nextClose.monthlyExpenses + nextClose.bonusPaid;
    return PublicDemoCashShortageOutlook._(
      projectedClosingCash: nextClose.closingCash,
      willRecover: false,
      headline: '次回決算後も資金不足の見込みです。赤字のままの場合は倒産となります。',
      expectedLine:
          '入金予定 ${formatYen(nextClose.cashReceived)} に対し、'
          '見込み費用 ${formatYen(expectedCosts)}。',
    );
  }

  /// [PublicDemoCashForecastMonth.closingCash] verbatim, or `null` when
  /// [fromForecastEntry] received no forecast entry.
  final int? projectedClosingCash;

  /// True only when [projectedClosingCash] is non-negative — never implied
  /// by anything else (a present [PublicDemoState.pendingRevenue] alone
  /// never sets this true; see the class doc).
  final bool willRecover;

  /// The one required-fact sentence: either the exact shortage-continues
  /// wording the P0 spec requires, or a truthful recovery statement — never
  /// both, never neither.
  final String headline;

  /// Present only when [willRecover] is false: the same short "入金予定 /
  /// 見込み費用" comparison the P0 spec asks for, read verbatim from
  /// [nextClose]'s own fields.
  final String? expectedLine;
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
