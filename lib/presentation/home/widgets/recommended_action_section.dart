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
/// The visual priority is intentional: this is HOME's one resolved next
/// action, not another equal-weight summary card.  The card answers "what
/// should I do now?" with a visible headline and a full-width, touch-safe
/// CTA while leaving the decision itself entirely with its owner.
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '次にやること',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              action.headline,
              key: const Key('home-recommended-action-headline'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
              // Two lines is enough for every headline this phase can
              // produce at 360pt; the cap is here so a long name can never
              // grow this card without bound.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('home-recommended-action-cta'),
                style: theme.filledButtonTheme.style?.copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                onPressed: candidate.invoke,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  action.ctaLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
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
