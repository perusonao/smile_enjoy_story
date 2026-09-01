import 'package:flutter/material.dart';

import '../theme.dart';

/// Resolved, display-only data for one employee on the Public Demo HOME.
///
/// The HOME/controller decides both who appears here and which status label is
/// appropriate. This model deliberately contains no game-state reference.
class PublicDemoEmployeeStageItem {
  const PublicDemoEmployeeStageItem({required this.name, required this.status});

  final String name;
  final String status;
}

/// Presentation data for an important event. [onPressed] remains owned by
/// the caller so this widget never decides a route or event outcome.
class PublicDemoImportantEventItem {
  const PublicDemoImportantEventItem({
    required this.title,
    required this.summary,
    required this.category,
    required this.ctaLabel,
    required this.onPressed,
    this.isHighPriority = false,
  });

  final String title;
  final String summary;
  final String category;
  final String ctaLabel;
  final VoidCallback onPressed;
  final bool isHighPriority;
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

class PublicDemoEmployeeStageSection extends StatelessWidget {
  const PublicDemoEmployeeStageSection({super.key, required this.employees});

  final List<PublicDemoEmployeeStageItem> employees;

  /// SES-FIRST-FUN-YEAR-UI-PHASE-1: this HOME summary used to render every
  /// employee unconditionally, so the card's height grew without bound as
  /// the roster grew across the fiscal year — the "大型employee card" the
  /// First Fun Year UI review named as HOME bloat. Capped at the same
  /// overflow idiom the Office Stage above it already uses ("+N名"), so the
  /// card stays a bounded summary rather than a second full roster list;
  /// the always-reachable per-employee cards further down the screen are
  /// still where every individual employee's detail and actions live.
  static const int _maxVisible = 4;

  @override
  Widget build(BuildContext context) {
    final visible = employees.take(_maxVisible).toList(growable: false);
    final hidden = employees.length - visible.length;
    return _HomeSectionCard(
      title: '社員ステージ',
      child: employees.isEmpty
          ? const Text('表示できる社員はいません')
          : Column(
              children: [
                for (final employee in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                employee.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: _StatusChip(label: employee.status),
                        ),
                      ],
                    ),
                  ),
                if (hidden > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '他$hidden名',
                      key: const Key('public-demo-employee-stage-more'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
    );
  }
}

class PublicDemoImportantEventsSection extends StatelessWidget {
  const PublicDemoImportantEventsSection({super.key, required this.events});

  final List<PublicDemoImportantEventItem> events;

  @override
  Widget build(BuildContext context) {
    // An absence of meaningful events is not dashboard content. Keep a
    // keyed, zero-footprint marker for tests/accessibility tooling without
    // spending a full card on an empty state.
    if (events.isEmpty) {
      return const SizedBox(key: Key('public-demo-important-events-empty'));
    }

    return _HomeSectionCard(
      cardKey: const Key('public-demo-important-events'),
      title: '重要イベント',
      accent: true,
      child: Column(
        children: [
          for (final event in events.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ImportantEventCard(event: event),
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

class PublicDemoMonthlyPrimaryCtaSection extends StatelessWidget {
  const PublicDemoMonthlyPrimaryCtaSection({super.key, required this.action});

  final PublicDemoMonthlyPrimaryCtaModel action;

  @override
  Widget build(BuildContext context) => _HomeSectionCard(
    title: '今月の主要行動',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(action.description),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('public-demo-monthly-primary-cta'),
            onPressed: action.enabled ? action.onPressed : null,
            child: Text(action.label, textAlign: TextAlign.center),
          ),
        ),
      ],
    ),
  );
}

class _ImportantEventCard extends StatelessWidget {
  const _ImportantEventCard({required this.event});
  final PublicDemoImportantEventItem event;

  @override
  Widget build(BuildContext context) {
    final color = event.isHighPriority
        ? Colors.red.shade700
        : SesTheme.primaryBlue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusChip(label: event.category, color: color),
          const SizedBox(height: 6),
          Text(
            event.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(event.summary),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: event.onPressed,
              child: Text(event.ctaLabel),
            ),
          ),
        ],
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (color ?? SesTheme.primaryBlue).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
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
    child: Padding(
      padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
