import 'package:flutter/material.dart';

import '../../presentation/home/models/home_dashboard_display_data.dart';
import '../../presentation/home/models/home_navigator_display.dart';
import '../../presentation/home/models/home_recommended_action.dart';
import '../../presentation/home/widgets/home_navigator_section.dart';
import '../../presentation/home/widgets/kpi_section.dart';
import '../../presentation/home/widgets/month_header_bar.dart';

/// The Public Demo screen's read-only mount point for the new HOME
/// dashboard display (HOME-RUNTIME-READ-1).
///
/// This is the whole integration surface between the Public Demo runtime
/// and the new HOME presentation, and it is deliberately one-directional:
///
///  * It accepts an already-built [HomeDashboardDisplayData] — never a
///    `PublicDemoState`, never a `PublicDemoAggregate`. The projection is
///    derived by the authoritative owner
///    (`PublicDemo01PlaceholderScreen`) while it builds, from the
///    aggregate it owns, and injected here through the constructor. So no
///    raw authoritative state reaches HOME at all, and HOME cannot reach
///    back for more than the projected fields.
///  * HOME-RUNTIME-2C narrows — but does not remove — the second bullet
///    this section used to carry ("it passes no callbacks"). It now also
///    accepts a [HomeRecommendedActionSlot], which in its
///    `HomeRecommendedActionAvailable` form carries exactly one bound
///    callback: the same already-bound owner handler the corresponding
///    production button runs. That is the single, whitelisted command entry
///    point the integration design's PHASE 2C plans for, and it is still
///    resolved entirely by the owner — no aggregate, no `PublicDemoState`,
///    no command API and no eligibility predicate crosses this boundary,
///    and there is no other path from anything rendered here back into
///    `PublicDemoAggregate`.
///  * It holds no state of its own. Every rebuild of the owning screen
///    (i.e. every `setState` after a domain command) produces a freshly
///    projected [data], so nothing here can go stale or become a second
///    source of truth.
///
/// HOME-RUNTIME-2A composed three read-only display widgets here — the
/// month header, the compact KPI, and the month-goal slot — and they are
/// the *only* place each of those things is shown. The legacy duplicates
/// (the `N月` headline, the 現預金/参画/待機/営業残 stat row, and the
/// `今月やること` card) are deleted from the owning screen rather than left
/// rendering the same facts a second time.
///
/// HOME-RUNTIME-2C replaced the third of those with a separate
/// `RecommendedActionSection` card, which showed the single next action
/// when one was eligible and fell back to the month goal when none was.
///
/// SES-FIRST-FUN-YEAR-UI-PHASE-2 goes one step further and removes that
/// second card outright: real-device testing found "ひよりのアドバイス" and
/// "次にやること" reading as two overlapping cards answering the same
/// question. [HomeNavigatorSection] now renders the resolved guidance *and*
/// its CTA (or the month-goal fallback) itself, via [_effectiveAdvice] —
/// there is exactly one guidance component on HOME again, not a
/// `RecommendedActionSection` stacked under the navigator.
///
/// Everything above still holds unchanged for the widened projection: the
/// three fields HOME-RUNTIME-2A added (`waitingEmployeeCount`,
/// `salesRemaining`, `monthGoalText`) are read-only projected values like
/// the rest. In particular no financial verdict (`financialStatus`,
/// `fiscalYearCompleted`) is projected, so the shortage/terminal cards stay
/// composed by the owning screen, outside this subtree.
///
/// The Public Demo screen keeps every one of its actions — this section
/// replaces duplicated *display*, never an action, and `HomeShellPage`
/// itself remains unwired from the app's navigation.
class PublicDemoHomeDashboardSection extends StatelessWidget {
  const PublicDemoHomeDashboardSection({
    super.key,
    required this.data,
    required this.recommendedAction,
    required this.navigatorAdvice,
  });

  /// The read-only projection to display. Rebuilt from authoritative state
  /// by the owning screen on every build — see the class doc.
  final HomeDashboardDisplayData data;

  /// What the recommended-action slot must render, already resolved by the
  /// owning screen from the candidates it emitted (HOME-RUNTIME-2C).
  /// Rebuilt on every build for the same reason [data] is.
  final HomeRecommendedActionSlot recommendedAction;

  /// Hiyori's already-resolved presentation advice. Its optional CTA is the
  /// same owner-bound callback carried by [recommendedAction]; [_effectiveAdvice]
  /// is what actually reaches [HomeNavigatorSection].
  final HomeNavigatorAdvice? navigatorAdvice;

  /// What [HomeNavigatorSection] renders — [navigatorAdvice] as resolved by
  /// [navigatorAdviceFor], except when [recommendedAction] is
  /// [HomeRecommendedActionNone]: there [navigatorAdviceFor] returns the
  /// generic [HomeNavigatorAdvice.neutral] ("今すぐ必須の操作はありません。"), and
  /// this substitutes the month's own, more specific goal
  /// ([HomeDashboardDisplayData.monthGoalText]) for that generic line
  /// instead. Both are already-projected, read-only text this section
  /// already receives; this only picks which one a single guidance line
  /// states; it ranks nothing and invents no new copy.
  HomeNavigatorAdvice? get _effectiveAdvice {
    final advice = navigatorAdvice;
    if (advice == null || recommendedAction is! HomeRecommendedActionNone) {
      return advice;
    }
    if (data.monthGoalText.isEmpty) return advice;
    return HomeNavigatorAdvice(
      title: advice.title,
      message: data.monthGoalText,
      explanation: advice.explanation,
      semantic: advice.semantic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('public-demo-home-dashboard-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthHeaderBar(data: data),
        const SizedBox(height: 8),
        KpiSection.compact(data: data),
        const SizedBox(height: 8),
        HomeNavigatorSection(
          expression: navigatorExpressionFor(navigatorAdvice?.semantic),
          advice: _effectiveAdvice,
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
