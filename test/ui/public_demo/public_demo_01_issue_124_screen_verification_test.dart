// SES ISSUE #124 (PUBLIC-DEMO-HOME-UI-2A) / ISSUE #147
// (PUBLIC-DEMO-HOME-UI-3A): Screen Verification follow-up.
//
// Real-device Screen Verification on PR #145's deploy found that, in the
// initial portrait viewport (360px and 390px wide, no scrolling), a player
// could see the month, cash, participation/waiting counts, sales-remaining,
// headcount, revenue, the pending-deposit figure, Hiyori's next action and
// its CTA, and the Office Stage picture — but NOT each employee's current
// sales/assignment status ("案件状況") or anything about what changed this
// month, because the picture-based "社員の様子" section and the list-based
// "社員ステージ" section duplicated the same two employees across roughly
// twice the vertical space either alone would need. PR for #124 compacted
// both sections to fit the same content budget.
//
// Issue #147 (PUBLIC-DEMO-HOME-UI-3A) rebuilds HOME to the approved
// mobile visual target and DELETES the duplicate "社員ステージ" list
// entirely — HomeOfficeStageSection (home-office-stage) is now the only
// employee-roster presentation on HOME, so the "two sections duplicate the
// same roster" question this suite originally existed to answer no longer
// has two sections to compare. It also adds two new required sections
// ("今月の重要タスク", "クイックアクセス") between the Office Stage and the
// finance detail, which legitimately grow the page taller than the old
// content budget — so the strict "everything fits inside 615/660pt" pixel
// assertion is retired along with the sections it was measuring.
//
// Issue #148 Phase 1B.3 (HOME-COMPACT-1B.3) re-prioritizes the initial
// viewport once more: the monthly progression CTA moves directly under the
// Navigator card so it — not the Office Stage picture — is guaranteed
// visible with no scroll. The Office Stage remains reachable (by scroll,
// quick access, and the bottom nav — see the other suites that pin that),
// but it is no longer required to be painted inside the very first frame;
// "誰が待機/利用可能か" is dropped from the list this test checks and
// replaced with the monthly CTA, which Issue #148 Phase 1B.3's acceptance
// criteria explicitly requires in the initial view. What survives from
// #124's original intent — that the core "what do I need to know right
// now" facts are genuinely painted in the unscrolled initial viewport, not
// merely present somewhere on a long scroll — is kept below, updated for
// the current required set.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

Future<void> pumpDemoAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  await tester.pumpAndSettle();
}

const _sizes = <Size>[Size(360, 800), Size(390, 844)];

void main() {
  for (final size in _sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets(
      'Issue #124/#147/#148 Phase 1B.3: month, cash, next action, and the '
      'monthly progression CTA are all painted in the unscrolled initial '
      'viewport at $label',
      (tester) async {
        await pumpDemoAt(tester, size);

        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          0,
          reason: 'the assertions below must describe the unscrolled screen',
        );

        final viewport = tester.getRect(find.byType(ListView));
        void expectInFirstView(Finder finder, String fact) {
          expect(finder, findsOneWidget, reason: 'missing: $fact');
          final rect = tester.getRect(finder);
          expect(
            rect.top,
            greaterThanOrEqualTo(viewport.top),
            reason: '$fact starts above the viewport',
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(viewport.bottom),
            reason: '$fact is not painted inside the raw viewport',
          );
        }

        // 1: what month is it.
        expectInFirstView(find.text('1年目 4月'), '月 (month)');

        // 2: how much cash is on hand.
        expectInFirstView(
          find.descendant(
            of: find.byKey(const Key('home-kpi-compact-cash')),
            matching: find.text('¥400万'),
          ),
          '現金 (cash)',
        );

        // 3: what to do next — Hiyori's headline plus her CTA.
        expectInFirstView(
          find.byKey(const Key('home-recommended-action-headline')),
          '次にやること (next action headline)',
        );
        expectInFirstView(
          find.byKey(const Key('home-recommended-action-cta')),
          '次にやること CTA',
        );

        // 4: the monthly progression CTA — Issue #148 Phase 1B.3 requires
        // it visible with no scroll, alongside 月/KPI/ひより. It replaces
        // the Office Stage photo strip in this required set: the Office
        // Stage remains reachable (by scroll/quick-access/bottom-nav — see
        // the Office Stage's own suites), but is no longer required inside
        // the very first frame now that the CTA occupies that budget.
        expectInFirstView(
          find.byKey(const Key('public-demo-monthly-primary-cta')),
          '月次進行CTA (monthly close CTA)',
        );

        // The Office Stage (reachable by scroll — see above) still shows
        // both founding engineers somewhere on screen.
        expect(find.text('佐藤 健'), findsWidgets);
        expect(find.text('鈴木 葵'), findsWidgets);
      },
    );

    testWidgets('Issue #147: the Office Stage is the only employee-roster '
        'presentation on HOME at $label — no duplicate full-size roster '
        'section exists any more', (tester) async {
      await pumpDemoAt(tester, size);

      expect(find.byKey(const Key('home-office-stage')), findsOneWidget);
      // The deleted duplicate list used this key; it must not exist in
      // any form, under any name, on the rebuilt screen.
      expect(find.byKey(const Key('public-demo-employee-stage')), findsNothing);
    });
  }

  testWidgets(
    'Issue #124/#147: gameplay is untouched — the Recommended Action CTA '
    'still dispatches the same domain command after the rebuild',
    (tester) async {
      await pumpDemoAt(tester, const Size(390, 844));

      final workflowBefore =
          (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
              .workflow;
      final stageBefore = workflowBefore.engineers.first.stage;

      await tester.tap(find.byKey(const Key('home-recommended-action-cta')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
      await tester.pumpAndSettle();

      final workflowAfter =
          (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
              .workflow;
      expect(workflowAfter.engineers.first.stage, isNot(stageBefore));
    },
  );
}
