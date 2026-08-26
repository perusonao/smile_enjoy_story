import 'package:flutter/material.dart';

import '../models/home_recommended_action.dart';

/// HOME-RUNTIME-2C — HOME's single "what to do next" slot.
///
/// This widget **replaces** HOME-RUNTIME-2A's month-goal card rather than
/// stacking a second card above it: the two answered the same player
/// question ("what now?") at different resolutions, and the design's own
/// table makes that explicit by ending with a `none of the above -> fall
/// back to monthGoal()` row. So the slot shows the concrete next action
/// when there is one, and the month's goal when there is not — never both,
/// and never one above the other. That is what keeps the first view the
/// 2A cleanup reclaimed (see the 2C first-view assertions in
/// `public_demo_01_home_consolidation_test.dart`).
///
/// What this widget is allowed to know is deliberately tiny. It receives a
/// [HomeRecommendedActionSlot] the owner already resolved and a month-goal
/// string, and it:
///
///  * does not rank anything — [selectHomeRecommendedAction] already ran,
///  * does not decide eligibility — the owner emitted only what is legal,
///  * does not know *why* a slot is suppressed — it cannot see
///    `financialStatus` or `fiscalYearCompleted`, only the outcome,
///  * does not hold state, and performs no arithmetic of any kind.
///
/// The CTA is the one interactive element HOME gained in this phase. It
/// runs [HomeRecommendedActionCandidate.invoke] — an already-bound owner
/// handler, i.e. the same `PublicDemoAggregate` command the corresponding
/// production button runs — and nothing else. It is never rendered
/// disabled: a candidate only exists where its button is enabled, so an
/// unavailable action is absent from the slot instead of greyed out in it.
class RecommendedActionSection extends StatelessWidget {
  const RecommendedActionSection({
    super.key,
    required this.slot,
    required this.monthGoalText,
  });

  /// What to render, as resolved by the authoritative owner.
  final HomeRecommendedActionSlot slot;

  /// The month's goal line, used only by the [HomeRecommendedActionNone]
  /// fallback. Still the relocated single month-goal table
  /// (`HomeDashboardDisplayData.monthGoalText`) — this widget does not own
  /// or reinterpret it.
  final String monthGoalText;

  @override
  Widget build(BuildContext context) {
    return switch (slot) {
      HomeRecommendedActionSuppressed() => const SizedBox.shrink(),
      HomeRecommendedActionNone() => _MonthGoalCard(goal: monthGoalText),
      HomeRecommendedActionAvailable(:final candidate) => _ActionCard(
        candidate: candidate,
      ),
    };
  }
}

/// The recommended action: an eyebrow, the subject line, and the CTA.
///
/// Three short lines on purpose. The player has to answer "who is this
/// about / what am I doing / where do I tap" in one glance, and every extra
/// element in this card is height taken from the employee cards below it.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.candidate});

  final HomeRecommendedActionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final action = candidate.action;

    return Card(
      key: const Key('home-recommended-action'),
      margin: EdgeInsets.zero,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '次にやること',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              action.headline,
              key: const Key('home-recommended-action-headline'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
              // Two lines is enough for every headline this phase can
              // produce at 360pt; the cap is here so a long name can never
              // grow this card without bound.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('home-recommended-action-cta'),
                // Compact: this button sits in a summary card, so it must
                // not set the height of the first view the way a full-size
                // stage button would.
                style: theme.filledButtonTheme.style?.copyWith(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: candidate.invoke,
                child: Text(action.ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design table's "none of the above" row: no action is eligible, so
/// the slot states the month's goal instead.
///
/// Keeps HOME-RUNTIME-2A's keys and chrome verbatim, because this is the
/// same card 2A introduced — 2C only narrowed when it is the thing to show.
class _MonthGoalCard extends StatelessWidget {
  const _MonthGoalCard({required this.goal});

  final String goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (goal.isEmpty) return const SizedBox.shrink();

    return Card(
      key: const Key('home-month-goal'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今月やること',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              goal,
              key: const Key('home-month-goal-text'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
