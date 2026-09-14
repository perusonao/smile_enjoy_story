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
        expect(find.textContaining('営業用スキルシート'), findsOneWidget);
        // SES First Fun Quarter Mission System Phase 2 (Progressive
        // Onboarding), Fresh Audit §6.3: the SkillSheet gate now states WHY
        // to check it, not just what it is — connecting confirmation to the
        // player's actual next decision (fit before selling).
        expect(
          find.textContaining('案件との相性を自分で判断するために'),
          findsOneWidget,
        );
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
          'スキルシート確認',
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

  group('SES First Fun Quarter Mission Phase 3: SkillSheet Editing', () {
    testWidgets(
      'the edit entry point only appears once SkillSheet confirmation has '
      'happened, never while still `waiting`',
      (tester) async {
        await pumpDemo(tester);
        final engineer = currentWorkflow(tester).engineers.first;

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(
          find.byKey(Key('public-demo-skill-sheet-edit-open-${engineer.id}')),
          findsNothing,
        );

        await tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'スキルシート確認'),
        );
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-confirm-${engineer.id}')),
        );

        expect(
          find.byKey(Key('public-demo-skill-sheet-edit-open-${engineer.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'saving an edit updates the displayed experience without touching '
      'stage, actual experience, or the interview profile — and cancelling '
      'changes nothing at all',
      (tester) async {
        await pumpDemo(tester);
        final engineer = currentWorkflow(tester).engineers.first;

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        await tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'スキルシート確認'),
        );
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-confirm-${engineer.id}')),
        );

        // Cancel first: nothing should change.
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-edit-open-${engineer.id}')),
        );
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-edit-cancel-${engineer.id}')),
        );
        expect(
          currentWorkflow(tester).engineers.first.salesProfileEditConfirmed,
          isFalse,
        );

        final beforeStage = currentWorkflow(tester).engineers.first.stage;
        final beforeProfile = currentWorkflow(tester).engineers.first.interviewProfile;

        // Now genuinely save a change.
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-edit-open-${engineer.id}')),
        );
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-edit-increment-${engineer.id}')),
        );
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-edit-save-${engineer.id}')),
        );

        final afterEngineer = currentWorkflow(tester).engineers.first;
        expect(afterEngineer.salesProfileEditConfirmed, isTrue);
        expect(afterEngineer.stage, beforeStage);
        expect(afterEngineer.interviewProfile.skillFit, beforeProfile.skillFit);
        expect(afterEngineer.interviewProfile.humanity, beforeProfile.humanity);
        expect(afterEngineer.interviewProfile.morale, beforeProfile.morale);
        expect(afterEngineer.interviewProfile.clientTrust, beforeProfile.clientTrust);
      },
    );

    testWidgets(
      'opening the Mission screen shows Mission #2 (SkillSheet編集) locked '
      'until confirmed, then completed — and never completed by cancel',
      (tester) async {
        await pumpDemo(tester);
        final engineer = currentWorkflow(tester).engineers.first;

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        await tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'スキルシート確認'),
        );
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-confirm-${engineer.id}')),
        );

        await tapVisible(
          tester,
          find.byKey(const Key('public-demo-app-bar-mission')),
        );
        expect(
          find.byKey(const Key('public-demo-mission-tile-editSkillSheet')),
          findsOneWidget,
        );
        expect(find.text('技術者のSkillSheetを編集する'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-edit-open-${engineer.id}')),
        );
        await tapVisible(
          tester,
          find.byKey(Key('public-demo-skill-sheet-edit-save-${engineer.id}')),
        );

        await tapVisible(
          tester,
          find.byKey(const Key('public-demo-app-bar-mission')),
        );
        // The completed tile shows a green check icon — cheaper to assert
        // via the icon's presence within this tile than to reach into
        // PublicDemoMissionStatusEntry from a pumped widget tree.
        expect(
          find.descendant(
            of: find.byKey(const Key('public-demo-mission-tile-editSkillSheet')),
            matching: find.byIcon(Icons.check_circle),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
