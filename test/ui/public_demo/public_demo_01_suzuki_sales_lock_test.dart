import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

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

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  final finder = actionButton(text);
  final list = find.byType(ListView);
  for (var i = 0; i < 6; i++) {
    final buttonRect = tester.getRect(finder);
    if (buttonRect.bottom <= tester.view.physicalSize.height) break;
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Suzuki explains her sales lock, capability, and training path without changing Sato or finance',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );
      await tester.pumpAndSettle();

      final stateBefore = currentState(tester);
      final workflowBefore = currentWorkflow(tester);
      final suzuki = workflowBefore.engineers.singleWhere(
        (engineer) => engineer.id == 'eng-02',
      );
      final sato = workflowBefore.engineers.singleWhere(
        (engineer) => engineer.id == 'eng-01',
      );
      final suzukiRuntime = stateBefore.runtimeFor(suzuki.id);
      final lock = find.byKey(const Key('public-demo-field-sales-lock-eng-02'));

      // Fresh Public Demo state shows Suzuki and her state is derived from the
      // same runtime and readiness rule that gate the real sales command.
      expect(suzuki.name, '鈴木 葵');
      expect(find.text(suzuki.name), findsWidgets);
      expect(suzukiRuntime.actualCapability, 52);
      expect(suzukiRuntime.isReadyForFieldSales, isFalse);
      expect(lock, findsOneWidget);
      expect(
        find.descendant(of: lock, matching: find.textContaining('営業開始には実力')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: lock,
          matching: find.textContaining('現在 ${suzukiRuntime.actualCapability}'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: lock,
          matching: find.textContaining(
            '${PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement} 以上',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: lock,
          matching: find.textContaining('まだ営業を始められません'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lock, matching: find.textContaining('社内研修')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: lock,
          matching: find.textContaining('SkillSheet確認'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('public-demo-internal-training-action-eng-02')),
        findsOneWidget,
      );

      // The ready engineer keeps the established SkillSheet -> sales route;
      // opening it remains a workflow-only transition and does not alter
      // cash, capacity, or either runtime capability.
      expect(
        find.byKey(const Key('public-demo-field-sales-lock-eng-01')),
        findsNothing,
      );
      final cashBefore = stateBefore.cash;
      final salesCapacityBefore = stateBefore.salesCapacity;
      final satoCapabilityBefore = stateBefore
          .runtimeFor(sato.id)
          .actualCapability;
      await tapAndSettle(tester, 'SkillSheet確認');

      final stateAfter = currentState(tester);
      final satoAfter = currentWorkflow(
        tester,
      ).engineers.singleWhere((engineer) => engineer.id == sato.id);
      expect(satoAfter.stage, PublicDemoSalesStage.skillSheet);
      expect(actionButton('営業開始'), findsOneWidget);
      expect(stateAfter.cash, cashBefore);
      expect(stateAfter.salesCapacity, salesCapacityBefore);
      expect(
        stateAfter.runtimeFor(sato.id).actualCapability,
        satoCapabilityBefore,
      );
      expect(
        stateAfter.runtimeFor(suzuki.id).actualCapability,
        suzukiRuntime.actualCapability,
      );

      // The compact local explanation has no 360px overflow.
      final lockRect = tester.getRect(lock);
      expect(lockRect.left, greaterThanOrEqualTo(0));
      expect(lockRect.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    },
  );
}
