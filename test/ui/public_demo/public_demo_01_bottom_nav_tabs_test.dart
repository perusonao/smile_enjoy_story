// PUBLIC-DEMO-HOME-UI-3B: the bottom navigation (ホーム/社員/営業/会計/メニュー)
// must switch between real logical tab surfaces rather than scroll-jump to
// an anchor inside HOME's own list (the PUBLIC-DEMO-HOME-UI-3A behavior this
// Issue replaces). This suite pins that contract directly, on the real
// screen and the real PublicDemoAggregate behind it:
//
//  * each destination shows its own tab's content, and HOME's content is
//    structurally gone (not merely off-screen) once another tab is
//    selected — the "old anchor-only behavior" this Issue's acceptance
//    criteria ask to prove absent;
//  * NavigationBar.selectedIndex always agrees with which tab is showing;
//  * selecting a tab never mutates game/domain state — only a bound
//    gameplay command may, and no destination is one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';

import 'public_demo_tab_test_helpers.dart';

PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

PublicDemoWorkflowState currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

Future<void> pumpDemo(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PUBLIC-DEMO-HOME-UI-3B: real bottom-navigation tab surfaces', () {
    testWidgets(
      'each destination shows its own tab content, and switching away from '
      'HOME removes HOME\'s own subtree entirely — a real tab switch, not '
      'a scroll-jump that leaves everything mounted',
      (tester) async {
        await pumpDemo(tester);

        // HOME (index 0, the default): its own dashboard section is
        // present, and the content that used to live below it on the same
        // screen (the employee sales-progression card) is not.
        expect(find.byType(PublicDemoHomeDashboardSection), findsOneWidget);
        expect(actionButton('SkillSheet確認'), findsNothing);

        // 社員: the employee card is real content here, and — the actual
        // proof this is a tab switch, not a scroll — HOME's own dashboard
        // section is gone from the tree entirely, not merely scrolled
        // past.
        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(actionButton('SkillSheet確認'), findsOneWidget);
        expect(find.byType(PublicDemoHomeDashboardSection), findsNothing);

        // 営業: the recruiting/assignment pipeline's tab. April renders no
        // card of its own here (nothing to sell yet), but this proves the
        // negative half of the same fact: 社員's content does not leak
        // into 営業 either.
        await switchPublicDemoTab(tester, PublicDemoTab.sales);
        expect(actionButton('SkillSheet確認'), findsNothing);
        expect(find.byType(PublicDemoHomeDashboardSection), findsNothing);

        // 会計: the finance summary is real content here.
        await switchPublicDemoTab(tester, PublicDemoTab.accounting);
        expect(
          find.byKey(const Key('public-demo-finance-summary')),
          findsOneWidget,
        );
        expect(find.byType(PublicDemoHomeDashboardSection), findsNothing);

        // メニュー: the dev/test menu toggle is real content here.
        await switchPublicDemoTab(tester, PublicDemoTab.menu);
        expect(
          find.byKey(const Key('public-demo-dev-menu-toggle')),
          findsOneWidget,
        );
        expect(find.byType(PublicDemoHomeDashboardSection), findsNothing);

        // Back to ホーム: the dashboard section returns, and the employee
        // card is gone again.
        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(find.byType(PublicDemoHomeDashboardSection), findsOneWidget);
        expect(actionButton('SkillSheet確認'), findsNothing);
      },
    );

    testWidgets(
      'NavigationBar.selectedIndex always agrees with which tab is showing',
      (tester) async {
        await pumpDemo(tester);

        NavigationBar navBar() => tester.widget<NavigationBar>(
          find.byKey(const Key('public-demo-bottom-nav')),
        );

        expect(navBar().selectedIndex, 0);

        const order = [
          (PublicDemoTab.employees, 1),
          (PublicDemoTab.sales, 2),
          (PublicDemoTab.accounting, 3),
          (PublicDemoTab.menu, 4),
          (PublicDemoTab.home, 0),
        ];
        for (final (tab, expectedIndex) in order) {
          await switchPublicDemoTab(tester, tab);
          expect(navBar().selectedIndex, expectedIndex, reason: '$tab');
        }
      },
    );

    testWidgets(
      'selecting a tab never mutates game/domain state — only a bound '
      'gameplay command may',
      (tester) async {
        await pumpDemo(tester);
        final beforeState = currentState(tester).toJson();
        final beforeWorkflow = currentWorkflow(tester).toJson();

        for (final tab in PublicDemoTab.values) {
          await switchPublicDemoTab(tester, tab);
        }

        expect(currentState(tester).toJson(), beforeState);
        expect(currentWorkflow(tester).toJson(), beforeWorkflow);
      },
    );

    testWidgets(
      'tapping the already-selected ホーム destination scrolls it to the '
      'top instead of doing nothing — the one convenience carried over '
      'from the retired scroll-jump design, not a second mutation path',
      (tester) async {
        await pumpDemo(tester);

        // Scroll HOME down first.
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        final scrolledOffset = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels;
        expect(scrolledOffset, greaterThan(0));

        // Re-tapping ホーム while already on it scrolls back to the top —
        // it does not merely no-op, and it still never touches domain
        // state.
        final before = currentState(tester).toJson();
        await tester.tap(find.byKey(const Key('public-demo-nav-home')));
        await tester.pumpAndSettle();
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          0,
        );
        expect(currentState(tester).toJson(), before);
      },
    );
  });
}
