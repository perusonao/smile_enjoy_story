// SES ISSUE #124 (PUBLIC-DEMO-HOME-UI-2A): Screen Verification follow-up.
//
// Real-device Screen Verification on PR #145's deploy found that, in the
// initial portrait viewport (360px and 390px wide, no scrolling), a player
// could see the month, cash, participation/waiting counts, sales-remaining,
// headcount, revenue, the pending-deposit figure, Hiyori's next action and
// its CTA, and the Office Stage picture — but NOT each employee's current
// sales/assignment status ("案件状況") or anything about what changed this
// month, because the picture-based "社員の様子" section and the list-based
// "社員ステージ" section duplicated the same two employees across roughly
// twice the vertical space either alone would need.
//
// This suite pins the fix: the two sections stay two components (their own
// suites — home_office_stage_section_test.dart,
// public_demo_home_presentation_components_test.dart — still cover them
// individually) but are compacted enough that a real per-employee status
// line, not just a photo, is genuinely painted inside the same
// browser-chrome content budget the existing HOME-RUNTIME-2A/2C suite
// (public_demo_01_home_consolidation_test.dart) already asserts the
// Recommended Action CTA against. Nothing about game state, Finance,
// Persistence, the Month Guard, or Recovery is exercised or asserted here —
// this is a pure layout/read suite over the same real screen those suites
// already drive.

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

/// Mirrors the browser-chrome content budget
/// public_demo_01_home_consolidation_test.dart already pins the Recommended
/// Action CTA against — the same real constraint a mobile browser leaves
/// below the AppBar once its own chrome is showing.
const _targets = <({Size size, double contentBudget})>[
  (size: Size(360, 800), contentBudget: 615),
  (size: Size(390, 844), contentBudget: 660),
];

void main() {
  for (final (:size, :contentBudget) in _targets) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets(
      'Issue #124: the six Screen Verification facts are all painted in the '
      'unscrolled initial viewport at $label',
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
          expect(
            rect.bottom - viewport.top,
            lessThanOrEqualTo(contentBudget),
            reason:
                '$fact ends ${rect.bottom - viewport.top}pt below the '
                'AppBar; the browser-chrome content budget at $label is '
                '${contentBudget}pt',
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

        // 4: who is on staff and available — the Office Stage photo strip.
        expectInFirstView(
          find.byKey(const Key('home-office-stage')),
          '誰が待機/利用可能か (Office Stage)',
        );
        expect(find.text('佐藤 健'), findsWidgets);
        expect(find.text('鈴木 葵'), findsWidgets);

        // 5: each employee's current sales/assignment status — the fact
        // real-device verification found missing from the first view. Both
        // April founding employees are 待機 engineers, i.e. "営業準備前".
        final stageCard = find.byKey(const Key('public-demo-employee-stage'));
        expectInFirstView(stageCard, '案件状況 (per-employee stage card)');
        expect(
          find.descendant(
            of: stageCard,
            matching: find.text('営業準備前'),
          ),
          findsNWidgets(2),
          reason: 'both April engineers\' current stage must be legible '
              'without scrolling',
        );

        // 6: what changed this month. April is turn one — nothing has
        // closed yet, so the Important Events slot correctly has no real
        // event to show (see
        // public_demo_home_presentation_components_test.dart for its
        // populated-state coverage). P1 fix: that "nothing yet" answer
        // must itself be genuine, readable text a player sees — not just
        // an invisible marker present in the tree — so this asserts the
        // actual visible string, not merely the key.
        final importantEventsEmpty = find.byKey(
          const Key('public-demo-important-events-empty'),
        );
        expectInFirstView(
          importantEventsEmpty,
          '今月何が変わったか (Important Events slot, empty in April)',
        );
        expect(
          find.text('今月の変化：まだありません'),
          findsOneWidget,
          reason: 'the empty-month answer must be real, visible text, not '
              'an invisible marker',
        );
        expect(
          tester.widget<Text>(importantEventsEmpty).data,
          isNotEmpty,
          reason: 'the empty-state widget itself must carry visible text',
        );
      },
    );

    testWidgets(
      'Issue #124: the Office Stage and the per-employee stage card no '
      'longer duplicate the same roster at full size, at $label',
      (tester) async {
        await pumpDemoAt(tester, size);

        // The photo strip is presentation-only summary, not a second full
        // roster: verified sizing budget stays with
        // home_office_stage_section_test.dart's own metrics assertions.
        // Here we only pin the outcome PublicDemo01 owns — that the two
        // sections TOGETHER, plus the gaps between them, cost meaningfully
        // less height than the pre-#124 two-full-size-cards layout did.
        final office = tester.getRect(
          find.byKey(const Key('home-office-stage')),
        );
        final stage = tester.getRect(
          find.byKey(const Key('public-demo-employee-stage')),
        );
        expect(stage.top, greaterThan(office.bottom));

        final combinedHeight = stage.bottom - office.top;
        // Pre-#124 this combined block measured roughly 340pt at 360x800
        // (Office Stage ~156pt + a two-line-per-employee 社員ステージ card
        // ~174pt, plus gaps). 200pt leaves real margin while still failing
        // the moment either section regresses back toward its old size.
        expect(
          combinedHeight,
          lessThan(200),
          reason:
              'the consolidated Office Stage + per-employee stage card '
              'measured ${combinedHeight}pt at $label — regression toward '
              'the pre-#124 duplicated layout',
        );
      },
    );
  }

  testWidgets(
    'Issue #124: gameplay is untouched — the Recommended Action CTA still '
    'dispatches the same domain command after the compaction',
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
