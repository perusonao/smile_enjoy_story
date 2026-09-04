import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

PublicDemoWorkflowState currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

Future<void> pumpDemo(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(home: PublicDemo01PlaceholderScreen(key: UniqueKey())),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('PUBLIC-DEMO-UX-1A SkillSheet inspection', () {
    testWidgets(
      'HOME action opens truthful content and back does not advance',
      (tester) async {
        await pumpDemo(tester);
        final engineer = currentWorkflow(tester).engineers.first;
        expect(engineer.name, '佐藤 健');
        expect(engineer.stage, PublicDemoSalesStage.waiting);

        await tapVisible(
          tester,
          find.byKey(const Key('home-recommended-action-cta')),
        );

        expect(
          find.byKey(Key('public-demo-skill-sheet-${engineer.id}')),
          findsOneWidget,
        );
        expect(find.textContaining('営業用SkillSheet'), findsOneWidget);
        expect(find.text('経歴・スキル要約'), findsOneWidget);
        expect(find.text(engineer.summary), findsWidgets);
        expect(find.text('営業・面談プロフィール'), findsOneWidget);
        expect(find.text('案件スキル適合'), findsOneWidget);
        expect(
          find.text('${engineer.interviewProfile.skillFit}'),
          findsWidgets,
        );
        expect(find.text('ヒューマンスキル'), findsOneWidget);
        expect(
          find.text('${engineer.interviewProfile.humanity}'),
          findsWidgets,
        );
        expect(find.text('モチベーション'), findsOneWidget);
        expect(find.text('${engineer.interviewProfile.morale}'), findsWidgets);
        expect(find.text('取引先からの信頼'), findsOneWidget);
        expect(
          find.text('${engineer.interviewProfile.clientTrust}'),
          findsWidgets,
        );

        // Opening the presentation itself is read-only.
        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.waiting,
        );
        expect(find.widgetWithText(FilledButton, '営業開始'), findsNothing);

        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-cancel-${engineer.id}')),
        );

        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.waiting,
        );
        expect(
          find.byKey(const Key('home-recommended-action-cta')),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, '営業開始'), findsNothing);

        await tapVisible(
          tester,
          find.byKey(const Key('home-recommended-action-cta')),
        );
        expect(
          find.byKey(Key('public-demo-skill-sheet-${engineer.id}')),
          findsOneWidget,
        );
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-cancel-${engineer.id}')),
        );
      },
    );

    testWidgets(
      'explicit confirmation advances once and existing sales start continues',
      (tester) async {
        await pumpDemo(tester);
        final engineer = currentWorkflow(tester).engineers.first;

        // Use the employee card entry point to prove both the legacy card and
        // HOME route share the same inspect-before-advance behavior. The
        // employee card now lives on the 社員 tab (PUBLIC-DEMO-HOME-UI-3B).
        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        final skillSheetButton = find.widgetWithText(
          FilledButton,
          'SkillSheet確認',
        );
        await tapVisible(tester, skillSheetButton);
        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.waiting,
        );

        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-confirm-${engineer.id}')),
        );

        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.skillSheet,
        );
        expect(
          find.byKey(Key('public-demo-skill-sheet-${engineer.id}')),
          findsNothing,
        );

        final salesStart = find.widgetWithText(FilledButton, '営業開始');
        expect(salesStart, findsOneWidget);
        await tapVisible(tester, salesStart);
        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.selling,
        );
      },
    );
  });
}
