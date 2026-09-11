import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_month_label.dart';
import '../theme.dart';
import 'public_demo_monthly_report_display_data.dart';

/// One label/value line inside [PublicDemoMonthlyReportDialog] — the exact
/// same stacked (label above, value below) layout
/// [PublicDemoYearEndResultCard]'s own `_YearEndStatRow` uses, for the same
/// reason: a `Row`'s non-flex value `Text` takes its full intrinsic width
/// before the flex label gets any space, so a long formatted value can
/// overflow a `Row` at 360/390px. Stacking vertically cannot overflow at
/// any width this screen supports.
class _ReportStatRow extends StatelessWidget {
  const _ReportStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _ReportSectionHeader extends StatelessWidget {
  const _ReportSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 2),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

/// SES ISSUE-232 Phase B: the Monthly Management Report — a read-only
/// summary shown immediately after a month's close has already committed,
/// before the player sees the next month's HOME. See
/// `PublicDemo01PlaceholderScreen._maybeShowMonthlyReport`'s own doc for
/// the single call site (all five close handlers: april/may/june/july/
/// closeOrdinaryMonth) and why this is always shown *after* the close
/// commits, never before or in place of it.
///
/// A `StatelessWidget` wrapping a plain `AlertDialog` — the exact same
/// architecture [PublicDemoYearEndResultCard] and every other Public Demo
/// result surface already use. This widget calls no aggregate/state/
/// workflow command and holds no callback beyond dismissing itself: the
/// only action available pops this route and lets the caller's own
/// already-existing `_resetMonthScroll()` → HOME flow continue exactly as
/// it does today. [data] is built once by the caller from an already-
/// [PublicDemoMonthlyReportSnapshot.isReady] snapshot — this widget
/// performs no additional gating of its own.
///
/// Codex Broad Review P2 (PR #237): the dismiss button's own label used to
/// read "翌月へ進む" unconditionally, but [data.closedMonth] `== 15`
/// (March, the fiscal year's last internal month —
/// [PublicDemoState.completeFiscalYear]'s own doc) never advances to
/// "next month": dismissing this dialog instead reveals the accounting
/// tab's Year-End result (success) or the HOME bankruptcy-style terminal
/// card (a March cash-shortage failure) — see
/// `PublicDemo01PlaceholderScreen._accountingMonthlyResultSection`/
/// `_bankruptcyTerminalCard`. [_isYearEndClose] reads that single already-
/// exposed field (no new authority) to keep the button's own copy truthful
/// about what happens next; every other month keeps its original label.
class PublicDemoMonthlyReportDialog extends StatelessWidget {
  const PublicDemoMonthlyReportDialog({super.key, required this.data});

  final PublicDemoMonthlyReportDisplayData data;

  /// True only for March's close (internal month 15) — the one month this
  /// dialog's dismiss button never leads to "next month" HOME.
  bool get _isYearEndClose => data.closedMonth == 15;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('public-demo-monthly-report-dialog'),
      title: Text('${publicDemoMonthLabel(data.closedMonth)}の経営結果'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ReportSectionHeader('現金'),
              _ReportStatRow(
                label: '月初 → 月末',
                value:
                    '${formatYen(data.openingCash)} → ${formatYen(data.closingCash)}',
              ),
              _ReportStatRow(
                label: '今月の増減',
                value: data.cashDelta >= 0
                    ? '+${formatYen(data.cashDelta)}'
                    : '-${formatYen(-data.cashDelta)}',
              ),

              const _ReportSectionHeader('売上・入金'),
              _ReportStatRow(label: '売上', value: formatYen(data.revenue)),
              _ReportStatRow(label: '入金', value: formatYen(data.cashReceived)),
              _ReportStatRow(
                label: '売掛金（翌月入金予定）',
                value: formatYen(data.receivables),
              ),

              const _ReportSectionHeader('支出'),
              _ReportStatRow(
                label: '支出合計',
                value: formatYen(data.totalExpenses),
              ),
              _ReportStatRow(label: '給与', value: formatYen(data.salaryPaid)),
              _ReportStatRow(
                label: '固定費',
                value: formatYen(data.fixedCostsPaid),
              ),
              if (data.bonusPaid > 0)
                _ReportStatRow(label: '賞与', value: formatYen(data.bonusPaid)),
              if (data.trainingCost > 0)
                _ReportStatRow(
                  label: '研修費',
                  value: formatYen(data.trainingCost),
                ),
              if (data.recruitmentCost > 0)
                _ReportStatRow(
                  label: '採用費',
                  value: formatYen(data.recruitmentCost),
                ),

              const _ReportSectionHeader('純利益相当'),
              _ReportStatRow(
                label: '売上 − 支出合計',
                value: data.netIncome >= 0
                    ? '+${formatYen(data.netIncome)}'
                    : '-${formatYen(-data.netIncome)}',
              ),

              const _ReportSectionHeader('社員'),
              _ReportStatRow(
                label: '参画人数 / 待機人数',
                value: '${data.assignedCount}名 / ${data.waitingCount}名',
              ),
              if (data.nextMonthJoinNames.isNotEmpty)
                _ReportStatRow(
                  label: '翌月入社予定',
                  value: data.nextMonthJoinNames.join('・'),
                ),

              const _ReportSectionHeader('ひよりから一言'),
              Text(
                key: const Key('public-demo-monthly-report-hiyori-comment'),
                publicDemoMonthlyReportHiyoriComment(data),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          key: const Key('public-demo-monthly-report-dismiss'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_isYearEndClose ? '年度結果を見る' : '翌月へ進む'),
        ),
      ],
    );
  }
}
