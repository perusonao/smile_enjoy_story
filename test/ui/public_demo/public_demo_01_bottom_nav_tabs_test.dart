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

/// The CTA button belonging to a specific "今月の重要タスク" row, found by
/// that row's own title text rather than by its (shared, ambiguous)
/// "対応する" label — 営業 and 採用 can both render that same label at once.
Finder importantTaskCta(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
  matching: find.byType(TextButton),
);

/// Advances one month via the real monthly-close CTA and its confirmation
/// dialog — the same path every other suite in this directory uses (see
/// `public_demo_01_home3_integration_test.dart`'s `tapAndDismissMonthEnd`).
/// Used only to reach a month where a different [_recruitmentTaskActionKinds]
/// action becomes eligible than in fresh April, so the 採用 regression test
/// below is not confounded by 営業's own row being eligible at the same time.
Future<void> tapAndDismissMonthEnd(WidgetTester tester) async {
  final cta = find.byKey(const Key('public-demo-monthly-primary-cta'));
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

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

  group(
    'PR #172 Codex review fix: shared cross-cutting CTAs route to the tab '
    'that actually owns the eligible action, not blindly to 営業',
    () {
      // Fresh April: the starting engineer (佐藤 健) is `waiting`, which is
      // only ever offered as an action on 社員 (`_employeeTabSalesActionKinds`
      // → `ec(i)`/SkillSheet確認). 営業 renders no card of its own this
      // early — no assignment or applicant has reached a sellable stage yet.
      // Before the fix, every one of these three shared entry points sent
      // the player to that blank 営業 tab anyway; each of the following
      // proves the destination is now 社員, where SkillSheet確認 actually is.
      testWidgets(
        'important-task 営業 row: fresh April sends the player to 社員, not '
        'blank 営業',
        (tester) async {
          await pumpDemo(tester);
          final engineer = currentWorkflow(tester).engineers.first;
          expect(engineer.name, '佐藤 健');

          final cta = importantTaskCta('営業活動を進める');
          await tester.ensureVisible(cta);
          await tester.pumpAndSettle();
          await tester.tap(cta);
          await tester.pumpAndSettle();

          final navBar = tester.widget<NavigationBar>(
            find.byKey(const Key('public-demo-bottom-nav')),
          );
          expect(
            navBar.selectedIndex,
            1,
            reason: '社員 is index 1 — see PublicDemoTab.employees.navKey',
          );
          expect(actionButton('SkillSheet確認'), findsOneWidget);
          expect(find.byType(PublicDemoHomeDashboardSection), findsNothing);
        },
      );

      testWidgets(
        'quick-access 案件・営業: fresh April sends the player to 社員, not '
        'blank 営業',
        (tester) async {
          await pumpDemo(tester);

          final icon = find.byKey(
            const Key('public-demo-quick-access-actions'),
          );
          await tester.ensureVisible(icon);
          await tester.pumpAndSettle();
          await tester.tap(icon);
          await tester.pumpAndSettle();

          final navBar = tester.widget<NavigationBar>(
            find.byKey(const Key('public-demo-bottom-nav')),
          );
          expect(navBar.selectedIndex, 1);
          expect(actionButton('SkillSheet確認'), findsOneWidget);
        },
      );

      testWidgets(
        'Navigator\'s 「他の行動を確認する」 secondary CTA: fresh April sends the '
        'player to 社員, not blank 営業',
        (tester) async {
          await pumpDemo(tester);

          final secondaryCta = find.byKey(
            const Key('home-navigator-secondary-cta'),
          );
          expect(secondaryCta, findsOneWidget);
          await tester.tap(secondaryCta);
          await tester.pumpAndSettle();

          final navBar = tester.widget<NavigationBar>(
            find.byKey(const Key('public-demo-bottom-nav')),
          );
          expect(navBar.selectedIndex, 1);
          expect(actionButton('SkillSheet確認'), findsOneWidget);
        },
      );

      testWidgets(
        'important-task 採用 row is unaffected by the fix: it still always '
        'routes to 営業, its own unambiguous home',
        (tester) async {
          await pumpDemo(tester);
          // Advance to May: fresh April has no 採用 row at all
          // (recruitment media only unlocks from month 5), and May is where
          // that row becomes eligible while 営業's own row is not — an
          // unambiguous scenario for proving 採用 keeps its own destination.
          await tapAndDismissMonthEnd(tester);
          expect(currentState(tester).month, 5);
          expect(find.text('営業活動を進める'), findsNothing);

          final cta = importantTaskCta('採用・面談に対応する');
          await tester.ensureVisible(cta);
          await tester.pumpAndSettle();
          await tester.tap(cta);
          await tester.pumpAndSettle();

          final navBar = tester.widget<NavigationBar>(
            find.byKey(const Key('public-demo-bottom-nav')),
          );
          expect(
            navBar.selectedIndex,
            2,
            reason: '営業 is index 2 — see PublicDemoTab.sales.navKey',
          );
        },
      );
    },
  );
}
