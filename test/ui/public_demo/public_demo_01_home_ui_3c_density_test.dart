// PUBLIC-DEMO-HOME-UI-3C (Issue #173): finish HOME's one-screen density and
// add a truthful empty state to 営業 for the months it has no card of its
// own to show.
//
// This suite pins the two acceptance criteria this phase adds:
//
//  * 今月の重要タスク now starts inside the unscrolled 360x800 initial
//    viewport (it used to start entirely below the fold — see the Issue
//    #173 result report for the measured before/after top position).
//  * 営業 shows a truthful, non-action empty state — never a fabricated
//    sales/recruiting action — whenever [_S._salesTabItems] has nothing to
//    render: before May's recruitment media exists (fresh April, the case
//    the Issue names explicitly) and again from August on, once the
//    funnel/assignment cards this tab owns have nothing left to show. May,
//    June, and July (which always have a real card) must never show it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

final _expense = PublicDemoSalary.baselineMonthlyExpenses;

/// Sells the first founding engineer through April's real sales pipeline and
/// closes it — the same chain `public_demo_01_month_guard_recommended_test
/// .dart` already uses to reach later months at the domain level.
PublicDemoAggregate _sellFirstEngineerAndCloseApril(PublicDemoAggregate game) {
  final engineerId = game.workflow.engineers[0].id;
  game = game.startSkillSheetReview(engineerId);
  game = game.beginSelling(engineerId);
  game = game.introduceProject(engineerId);
  game = game.recordEngineerInterviewResult(
    engineerId: engineerId,
    type: PublicDemoInterviewType.partner,
  );
  game = game.recordEngineerInterviewResult(
    engineerId: engineerId,
    type: PublicDemoInterviewType.client,
  );
  game = game.recordOrder(engineerId);
  return game.closeApril(monthlyExpenses: _expense);
}

/// Reaches August with the one engineer's July continuation properly
/// decided and accepted in June — nothing outstanding, so this is purely
/// about what 営業 has left to show, not a Month Guard warning.
PublicDemoAggregate _reachAugustClean() {
  var game = PublicDemoAggregate.initial();
  game = _sellFirstEngineerAndCloseApril(game);
  game = game.closeMay(week: 9, monthlyExpenses: _expense);
  final engineerId = game.workflow.engineers[0].id;
  game = game.withAssignmentUpdate(
    engineerId,
    nextOrderStatus: PublicDemoNextOrderStatus.accepted,
  );
  game = game.closeJune(assignedInJuly: 1, monthlyExpenses: _expense);
  game = game.confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none);
  return game.closeJuly(monthlyExpenses: _expense);
}

Future<void> _pump(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PublicDemoState _currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

const _emptyStateKey = Key('public-demo-sales-empty-state');
const _emptyStateCtaKey = Key('public-demo-sales-empty-state-cta');

void main() {
  group('Issue #173: 今月の重要タスク is closer to the unscrolled initial view', () {
    testWidgets(
      '今月の重要タスク starts inside the raw ListView viewport at 360x800 '
      '(it used to start entirely below the fold)',
      (tester) async {
        await _pump(
          tester,
          PublicDemoAggregate.initial(),
          size: const Size(360, 800),
        );

        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          0,
          reason: 'the assertion below must describe the unscrolled screen',
        );

        final viewport = tester.getRect(find.byType(ListView).first);
        final tasks = tester.getRect(
          find.byKey(const Key('public-demo-important-tasks')),
        );
        expect(
          tasks.top,
          lessThan(viewport.bottom),
          reason:
              '今月の重要タスク must begin inside the initial viewport, not '
              'entirely below it',
        );
      },
    );
  });

  group('Issue #173: 営業 shows a truthful empty state instead of a blank '
      'body', () {
    testWidgets(
      'fresh April (before the recruiting funnel exists): the '
      'before-funnel empty state renders, names no fabricated action, and '
      'its CTA switches to 社員',
      (tester) async {
        await _pump(tester, PublicDemoAggregate.initial());
        expect(_currentState(tester).month, 4);

        await switchPublicDemoTab(tester, PublicDemoTab.sales);

        expect(find.byKey(_emptyStateKey), findsOneWidget);
        expect(
          find.textContaining('SkillSheet確認'),
          findsWidgets,
          reason: 'the truthful April reason (SkillSheet confirmation first) '
              'must be stated',
        );
        expect(find.byKey(_emptyStateCtaKey), findsOneWidget);
        expect(
          tester.getRect(find.byKey(_emptyStateCtaKey)).height,
          greaterThanOrEqualTo(48),
        );

        await tester.tap(find.byKey(_emptyStateCtaKey));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('public-demo-bottom-nav')),
          findsOneWidget,
        );
        final nav = tester.widget<NavigationBar>(
          find.byKey(const Key('public-demo-bottom-nav')),
        );
        expect(nav.selectedIndex, 1, reason: '社員 is tab index 1');
        expect(actionButton('SkillSheet確認'), findsOneWidget);
      },
    );

    testWidgets(
      'August, with nothing outstanding: the after-funnel empty state '
      'renders (a genuinely different, still-truthful message) and its CTA '
      'switches to 社員',
      (tester) async {
        await _pump(tester, _reachAugustClean());
        expect(_currentState(tester).month, 8);

        await switchPublicDemoTab(tester, PublicDemoTab.sales);

        expect(find.byKey(_emptyStateKey), findsOneWidget);
        expect(
          find.textContaining('社員'),
          findsWidgets,
          reason: 'the after-funnel copy must point at where real '
              'per-employee status actually lives',
        );
        // No fabricated recruiting/assignment card either.
        expect(find.byKey(const Key('public-demo-recruitment-media-card')),
            findsNothing);

        await tester.tap(find.byKey(_emptyStateCtaKey));
        await tester.pumpAndSettle();
        final nav = tester.widget<NavigationBar>(
          find.byKey(const Key('public-demo-bottom-nav')),
        );
        expect(nav.selectedIndex, 1, reason: '社員 is tab index 1');
      },
    );

    testWidgets(
      'May: the recruitment-media card always renders — the empty state '
      'must not',
      (tester) async {
        var game = PublicDemoAggregate.initial();
        game = _sellFirstEngineerAndCloseApril(game);
        await _pump(tester, game);
        await switchPublicDemoTab(tester, PublicDemoTab.sales);

        expect(_currentState(tester).month, 5);
        expect(
          find.byKey(const Key('public-demo-recruitment-media-card')),
          findsOneWidget,
        );
        expect(find.byKey(_emptyStateKey), findsNothing);
      },
    );

    testWidgets(
      'July: the closing narrative always renders — the empty state must '
      'not',
      (tester) async {
        var game = PublicDemoAggregate.initial();
        game = _sellFirstEngineerAndCloseApril(game);
        game = game.closeMay(week: 9, monthlyExpenses: _expense);
        final engineerId = game.workflow.engineers[0].id;
        game = game.withAssignmentUpdate(
          engineerId,
          nextOrderStatus: PublicDemoNextOrderStatus.accepted,
        );
        game = game.closeJune(assignedInJuly: 1, monthlyExpenses: _expense);
        await _pump(tester, game);
        await switchPublicDemoTab(tester, PublicDemoTab.sales);

        expect(_currentState(tester).month, 7);
        expect(find.byKey(_emptyStateKey), findsNothing);
      },
    );
  });
}

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);
