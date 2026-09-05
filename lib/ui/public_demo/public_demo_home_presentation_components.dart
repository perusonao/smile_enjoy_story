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
        for (var i = 0; i < items.length; i++) ...[
          // SES HOME Final Polish: restored from Final Density's 1 — Quick
          // Access and the Navigator's secondary CTA freed up real height,
          // and real space between rows is where that height buys back
          // readability best (§I of the Final Polish brief).
          if (i > 0) const Divider(height: 1),
          _ImportantTaskRow(item: items[i]),
        ],
      ],
    ),
  );
}

class _ImportantTaskRow extends StatelessWidget {
  const _ImportantTaskRow({required this.item});
  final PublicDemoImportantTaskItem item;

  @override
  Widget build(BuildContext context) {
    // SES HOME Final Polish: real vertical padding around each row —
    // restored now that Quick Access and the Navigator's secondary CTA no
    // longer spend this card's height budget.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _StatusChip(label: item.category, compact: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.fact,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          // SES HOME Final Density: the CTA used to be a `TextButton` printing
          // [item.ctaLabel] ("対応する"/"確認する") in full. Every one of the
          // (at most three) rows here says the exact same thing — "go to
          // where this fact lives and act on it" — so the label's width was
          // pure repeated chrome, not information: shrinking it to a single
          // "proceed" icon gives the title/fact column real width back
          // (which is what keeps `title` + its category chip on one Wrap run
          // more often, at every text scale) without ever removing the CTA's
          // real meaning. [item.ctaLabel] itself is never dropped — it still
          // reaches an assistive-technology user verbatim via this explicit
          // [Semantics.label], never merely inferred from a generic icon.
          Semantics(
            button: true,
            label: item.ctaLabel,
            child: IconButton(
              key: ValueKey('important-task-cta-${item.title}'),
              // A literal minimum, not the platform default: this keeps the
              // >=48px touch-target requirement true regardless of the
              // ambient IconButton theme.
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: item.onPressed,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
        ],
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
        // SES HOME Final Polish: restored from Final Density's 0 — Quick
        // Access and the Navigator's secondary CTA freed up real height, and
        // this card's own vertical padding is where readability (§I) buys
        // the most back for a card whose whole point is standing out as
        // this month's clear close-out CTA. No text or the button's own
        // 44pt minimum height changed.
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
            const SizedBox(height: 6),
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
      // SES HOME Final Polish: restored from Final Density's 3/2 — Quick
      // Access is deleted and the Navigator's secondary CTA is gone (§B/§D
      // of the Final Polish brief), so the height they used to cost goes
      // back into this card's own padding/title gap instead (§I).
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}
