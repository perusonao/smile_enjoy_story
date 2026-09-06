import 'package:flutter/material.dart';

import '../theme.dart';

/// PUBLIC-DEMO-HOME-UI-3A: replaces the former `PublicDemoImportantEventItem`
/// / `PublicDemoImportantEventsSection` ("重要イベント" — at most the latest
/// month-close event) with the approved visual target's "今月の重要タスク"
/// list. Every field here is display-only data the caller already owns; this
/// model invents no priority ranking, deadline, or progress value — see
/// [PublicDemoImportantTasksSection]'s own doc for exactly which three
/// truthful facts back the fixed three items.
class PublicDemoImportantTaskItem {
  const PublicDemoImportantTaskItem({
    required this.title,
    required this.fact,
    required this.category,
    required this.ctaLabel,
    required this.onPressed,
  });

  final String title;

  /// The one already-authoritative fact this task is about (e.g.
  /// "営業残: 4回"), never a fabricated priority/deadline/percentage.
  final String fact;

  /// A neutral category label ("営業"/"採用"/"資金") — not a priority claim.
  /// The approved mockup's "High Priority"/"重要" chips have no ranking
  /// authority behind them in Public Demo's current model, so every task
  /// here renders the same neutral chip style instead of inventing one.
  final String category;
  final String ctaLabel;
  final VoidCallback onPressed;
}

/// Finance values already calculated by the finance/state authority.
///
/// SES-FIRST-FUN-YEAR-UI-PHASE-1: this model used to also carry `cash`,
/// `revenue`, `nextMonthEstimate`, and a `warning` banner, all of which
/// duplicated figures the compact KPI (`KpiSection.compact`,
/// `PublicDemoHomeDashboardSection`) already shows on every build, and a
/// warning already shown above HOME by `PublicDemoCashShortageCard` /
/// the bankruptcy terminal card. Trimmed to the two figures the KPI does
/// not carry — this section's remaining, non-duplicate reason to exist.
class PublicDemoFinanceSummaryModel {
  const PublicDemoFinanceSummaryModel({
    required this.payroll,
    required this.fixedCosts,
  });

  final int payroll;
  final int fixedCosts;
}

/// The already-resolved primary action for this month.
class PublicDemoMonthlyPrimaryCtaModel {
  const PublicDemoMonthlyPrimaryCtaModel({
    required this.label,
    required this.description,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final String description;
  final bool enabled;
  final VoidCallback onPressed;
}

/// Section 6 of the approved PUBLIC-DEMO-HOME-UI-3A target: "今月の重要タスク".
///
/// Replaces the former `PublicDemoImportantEventsSection` ("重要イベント" —
/// at most one item, the latest month-close event, or an empty-state line).
/// This renders exactly [items] (in practice up to the fixed three the
/// owning screen builds from `salesRemaining`/`waitingEmployeeCount`/
/// `fixedCosts` — see `_S._importantTasks`'s own doc for why the 営業/採用
/// rows are each omitted, not disabled, once nothing eligible backs them;
/// 資金計画 always renders). No priority/deadline/percentage is invented for
/// any item that does render.
///
/// SES HOME Final Visual Match: lays [items] out as a 2-column grid (the
/// Visual SSOT's side-by-side task tiles) instead of the former single
/// vertical list separated by `Divider`s. Items are chunked two per row in
/// their existing order — never reordered, never re-prioritized — so April's
/// usual two eligible tasks (営業活動を進める / 資金計画を確認する) sit side
/// by side exactly as the SSOT shows; a third item (when 採用 is also
/// eligible) starts a second row rather than forcing a 3-wide row that would
/// cramp every tile's text at 360px.
///
/// PR #182 Codex P2: a row with only one item (an odd-length [items], most
/// often a lone 資金計画 tile once 営業/採用 are both exhausted) used to still
/// reserve its unused half with an empty `Expanded`, halving that tile's own
/// width for no reason. That lone tile now spans the full row instead.
class PublicDemoImportantTasksSection extends StatelessWidget {
  const PublicDemoImportantTasksSection({super.key, required this.items});

  final List<PublicDemoImportantTaskItem> items;

  @override
  Widget build(BuildContext context) => _HomeSectionCard(
    cardKey: const Key('public-demo-important-tasks'),
    title: '今月の重要タスク',
    accent: true,
    child: Column(
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 6),
          if (i + 1 < items.length)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ImportantTaskCell(item: items[i])),
                const SizedBox(width: 6),
                Expanded(child: _ImportantTaskCell(item: items[i + 1])),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: _ImportantTaskCell(item: items[i]),
            ),
        ],
      ],
    ),
  );
}

/// One task tile in the 2-column grid: category chip, title, the one
/// truthful supporting fact, and the same icon-only "proceed" CTA the
/// former vertical row used.
class _ImportantTaskCell extends StatelessWidget {
  const _ImportantTaskCell({required this.item});
  final PublicDemoImportantTaskItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        // PR #182 Codex P2: trimmed vertical from 6/6 to 4/4 — real card
        // padding, not text/touch-target room — to buy back headroom for
        // [item.fact] now genuinely needing a 2nd line (see below) without
        // reopening the 360x800 no-scroll overflow One-Screen Final Fit
        // (PR #181) closed.
        padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusChip(label: item.category, compact: true),
                  const SizedBox(height: 3),
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // PR #182 Codex P2: this used to be `maxLines: 1`, which
                  // ellipsized real amounts (e.g. "今月の固定費: ¥50,000")
                  // at the half-width column this grid gives each tile —
                  // [item.fact] is the task's only supporting financial
                  // value, so it must stay fully readable. Two lines is
                  // real wrap room, not a truncation: every real production
                  // fact fits within it at both 360px and 390px (checked in
                  // the focused test), and the `overflow` fallback only
                  // guards a fact genuinely too long for that, which never
                  // happens with today's real content.
                  Text(
                    item.fact,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // SES HOME Final Density: the CTA used to be a `TextButton`
            // printing [item.ctaLabel] ("対応する"/"確認する") in full. Every
            // tile here says the exact same thing — "go to where this fact
            // lives and act on it" — so the label's width was pure repeated
            // chrome, not information: shrinking it to a single "proceed"
            // icon gives the title/fact column real width back without
            // ever removing the CTA's real meaning. [item.ctaLabel] itself
            // is never dropped — it still reaches an assistive-technology
            // user verbatim via this explicit [Semantics.label], never
            // merely inferred from a generic icon.
            Semantics(
              button: true,
              label: item.ctaLabel,
              child: IconButton(
                key: ValueKey('important-task-cta-${item.title}'),
                // A literal minimum, not the platform default: this keeps
                // the >=48px touch-target requirement true regardless of
                // the ambient IconButton theme.
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.zero,
                onPressed: item.onPressed,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PublicDemoFinanceSummarySection extends StatelessWidget {
  const PublicDemoFinanceSummarySection({super.key, required this.summary});

  final PublicDemoFinanceSummaryModel summary;

  @override
  Widget build(BuildContext context) => _HomeSectionCard(
    cardKey: const Key('public-demo-finance-summary'),
    title: '今月の支出予定',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FinanceRow('給与', summary.payroll),
        _FinanceRow('固定費', summary.fixedCosts),
      ],
    ),
  );
}

/// HOME-COMPACT-1B.4: replaces the former `_HomeSectionCard`-based card
/// (a full "今月の主要行動" title, generous padding, and a plain description
/// line) with a slim bar sized to sit directly under Hiyori's own card
/// without pressing the initial view — see the acceptance criteria in the
/// HOME-COMPACT-1B.4 result report for the measured before/after height.
///
/// It still shows exactly the same three facts ([action.description],
/// [action.label], [action.enabled]) through the same key — nothing about
/// what this CTA means or does changed, only how much room it spends. The
/// amber accent (never the blue Hiyori's own CTA uses) and the small "月次
/// 処理" eyebrow are deliberate: this sits one card below her recommended
/// action, and the acceptance criteria require a player scanning both not
/// to mistake this month-end control for her primary next step.
class PublicDemoMonthlyPrimaryCtaSection extends StatelessWidget {
  const PublicDemoMonthlyPrimaryCtaSection({super.key, required this.action});

  final PublicDemoMonthlyPrimaryCtaModel action;

  /// Distinct from [SesTheme.primaryBlue] (Hiyori's own CTA color) on
  /// purpose — see the class doc.
  ///
  /// HOME-COMPACT-1B.4 FIX2 (Codex P2): darkened from `0xFFEF6C00` (Material
  /// Orange 800), whose ~3.08:1 contrast against the enabled button's
  /// inherited white foreground fell short of WCAG AA's 4.5:1 for
  /// normal-size text. This is Material Deep Orange 900 — still squarely
  /// the same amber/orange family the class doc's "never the blue" contract
  /// asks for, but at ~5.6:1 with white (see the HOME-COMPACT-1B.4 result
  /// report's contrast-ratio table for the measured value and the
  /// alternatives it was checked against). Only this token changed — the
  /// icon, the "月次処理" label, and the card's own border/background tint
  /// all read it too, so the whole card's accent stays one consistent color
  /// rather than the button alone drifting from its own chrome.
  static const Color _accent = Color(0xFFBF360C);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('public-demo-monthly-primary-cta-card'),
      margin: EdgeInsets.zero,
      color: _accent.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        // SES HOME One-Screen Final Fit: trimmed again, from 8 — this
        // card's own vertical padding is real slack, not text/touch-target
        // room, and part of closing the 360x800 unscrolled-viewport
        // overflow (see the result report). No text or the button's own
        // 44pt minimum height changed.
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, size: 14, color: _accent),
                const SizedBox(width: 5),
                Text(
                  '月次処理',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              action.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('public-demo-monthly-primary-cta'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed: action.enabled ? action.onPressed : null,
                child: Text(action.label, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One "支出" (expense) line: a bold label and its bold, negatively-signed
/// yen amount. Both remaining callers (給与, 固定費) are expense rows, so
/// SES-FIRST-FUN-YEAR-UI-PHASE-1 dropped the `emphasis`/`expense`/`subdued`
/// flags this used to take — they only ever varied between the deleted
/// cash/revenue/nextMonthEstimate rows, never between these two.
class _FinanceRow extends StatelessWidget {
  const _FinanceRow(this.label, this.amount);

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '-${formatYen(amount)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: SesTheme.primaryBlue,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A small neutral category chip. Deliberately styled identically for every
/// caller (PUBLIC-DEMO-HOME-UI-3A): the approved mockup's "High Priority" /
/// "重要" chip color implies a priority ranking Public Demo's current model
/// has no authority for, so this never varies its color as a priority
/// signal — see [PublicDemoImportantTaskItem]'s own doc.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.compact = false});
  final String label;

  /// A slightly smaller variant used by dense inline rows (the important
  /// task list). The default size is used elsewhere.
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 1 : 3),
    decoration: BoxDecoration(
      color: SesTheme.primaryBlue.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: compact ? 11 : 12,
        fontWeight: FontWeight.w600,
        color: SesTheme.primaryBlue,
      ),
    ),
  );
}

class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({
    this.cardKey,
    required this.title,
    required this.child,
    this.accent = false,
  });
  final Key? cardKey;
  final String title;
  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) => Card(
    key: cardKey,
    margin: EdgeInsets.zero,
    child: Padding(
      // SES HOME One-Screen Final Fit: trimmed again, from 12 — real card
      // padding, not text/touch-target room, and part of closing the
      // 360x800 unscrolled-viewport overflow (see the result report).
      //
      // PR #182 Codex P2: trimmed once more, from 6 — real card padding,
      // buying back headroom for the important-tasks grid's finance fact
      // now genuinely needing a 2nd line (see `_ImportantTaskCell`).
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: accent ? SesTheme.primaryBlue : null,
            ),
          ),
          // PR #182 Codex P2: trimmed from 4 — real gap, same headroom
          // reasoning as this card's own padding above.
          const SizedBox(height: 2),
          child,
        ],
      ),
    ),
  );
}
