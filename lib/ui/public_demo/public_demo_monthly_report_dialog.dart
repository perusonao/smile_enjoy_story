import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_month_label.dart';
import '../../presentation/home/models/home_navigator_display.dart';
import '../theme.dart';
import 'public_demo_monthly_report_display_data.dart';

/// One label/value line inside [PublicDemoMonthlyReportDialog] — the exact
/// same stacked (label above, value below) layout
/// [PublicDemoYearEndResultCard]'s own `_YearEndStatRow` uses, for the same
/// reason: a `Row`'s non-flex value `Text` takes its full intrinsic width
/// before the flex label gets any space, so a long formatted value can
/// overflow a `Row` at 360/390px. Stacking vertically cannot overflow at
/// any width this screen supports.
///
/// SES ISSUE-250: an optional [caption] renders one small grey line under
/// the value — used only for [PublicDemoMonthlyReportDialog]'s 固定費 row, to
/// name what that single aggregate figure actually covers
/// ([PublicDemoSalary.otherMonthlyFixedCost]'s own documented composition —
/// see that field and `SES_FIRST-FUN-YEAR_Seeded-Balance-Fix_Result.md`'s
/// "rent+utilities+etc. aggregate" note) without inventing a per-category
/// breakdown no authority actually holds.
class _ReportStatRow extends StatelessWidget {
  const _ReportStatRow({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (caption != null)
          Text(
            caption!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
      ],
    ),
  );
}

/// The small ひより portrait shown beside her comment — reusing
/// [HomeNavigatorIdentity]'s existing normal-expression asset, the same
/// asset/pattern `PublicDemoOpeningContextScreen`'s own `_NavigatorIntro`
/// already reuses outside HOME. Sized smaller (36x36) than that screen's own
/// 64x64 introduction portrait to fit this report's tighter One-Screen
/// budget — this dialog never introduces her name/role again (the "ひより
/// から一言" heading above it already does that), only her face beside the
/// short comment. Falls back to a plain icon on a decode failure, the same
/// degrade path every other reuse of this asset already takes.
class _HiyoriPortrait extends StatelessWidget {
  const _HiyoriPortrait();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = HomeNavigatorIdentity.portraitAssetFor(
      NavigatorExpression.normal,
    );
    return SizedBox(
      key: const Key('public-demo-monthly-report-hiyori-portrait'),
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: path == null
              ? Icon(Icons.person, size: 20, color: scheme.onSurfaceVariant)
              : Image.asset(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.person, size: 20, color: scheme.onSurfaceVariant),
                ),
        ),
      ),
    );
  }
}

class _ReportSectionHeader extends StatelessWidget {
  const _ReportSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
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
      // SES ISSUE-250 One-Screen: the same compact `insetPadding` technique
      // `PublicDemoProjectInterviewDialog`/`PublicDemoRecruitmentInterviewDialog`
      // already use, plus tightened title/content/actions padding — reclaims
      // vertical room at 360x800 without shrinking any text.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                label: '月初 → 月末（今月の増減）',
                value:
                    '${formatYen(data.openingCash)} → ${formatYen(data.closingCash)}'
                    '（${data.cashDelta >= 0 ? '+' : '-'}'
                    '${formatYen(data.cashDelta.abs())}）',
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
                caption: '（家賃・水道光熱費など）',
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HiyoriPortrait(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      key: const Key(
                        'public-demo-monthly-report-hiyori-comment',
                      ),
                      publicDemoMonthlyReportHiyoriComment(data),
                    ),
                  ),
                ],
              ),

              // SES ISSUE-250: the single next-month decision to consider —
              // omitted entirely once [PublicDemoMonthlyReportDisplayData
              // .nextActionHeadline] is `null` (bankruptcy, a March
              // cash-shortage failure, or fiscal-year completion; see that
              // field's own doc), so a terminal/year-end close never shows
              // an impossible future action here.
              if (data.nextActionHeadline != null) ...[
                const _ReportSectionHeader('次に考えること'),
                Text(
                  key: const Key('public-demo-monthly-report-next-action'),
                  data.nextActionHeadline!,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          key: const Key('public-demo-monthly-report-dismiss'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_isYearEndClose ? '年度結果を見る' : '翌月へ進む'),
        ),
      ],
    );
  }
}
