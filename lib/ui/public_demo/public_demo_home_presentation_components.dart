import 'package:flutter/material.dart';

import '../theme.dart';

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
/// HOME UI Phase 1 trimmed this to the two figures the compact HOME KPI does
/// not already carry (payroll, fixed costs). It used to also repeat
/// cash/revenue/next-month-estimate and a financial-status warning, all of
/// which duplicated the KPI and the cash-shortage/bankruptcy cards HOME
/// already shows above this section.
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
        _FinanceRow('給与', summary.payroll, emphasis: true, expense: true),
        _FinanceRow('固定費', summary.fixedCosts, emphasis: true, expense: true),
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

class _FinanceRow extends StatelessWidget {
  const _FinanceRow(
    this.label,
    this.amount, {
    this.emphasis = false,
    this.expense = false,
  });
  final String label;
  final int amount;
  final bool emphasis;
  final bool expense;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: emphasis ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${expense ? '-' : ''}${formatYen(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: emphasis ? SesTheme.primaryBlue : null,
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
