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

Future<void> _settleAfterPossiblePrecache(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView);
  for (var i = 0; i < 10; i++) {
    final rect = tester.getRect(finder);
    if (rect.top >= 0 && rect.bottom <= tester.view.physicalSize.height) {
      break;
    }
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settleAfterPossiblePrecache(tester);
}

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  await tapFinder(tester, actionButton(text));
  if (text == 'SkillSheet確認') {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
}

Future<void> dismissDialog(WidgetTester tester, String confirmLabel) async {
  final confirm = find.widgetWithText(FilledButton, confirmLabel);
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('Suzuki explains her sales lock truthfully and never offers the '
      'SkillSheet route once April closes, no matter how much later training '
      'raises her capability; Sato and finance are unaffected', (tester) async {
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
      find.descendant(of: lock, matching: find.textContaining('まだ営業を始められません')),
      findsOneWidget,
    );
    // P1 (PR #115 review): the lock banner must not promise that training
    // will eventually unlock 営業準備（SkillSheet確認） — this build's month
    // gating (founding-engineer sales card in April only) never gives her
    // that action again once April closes, however high later training
    // raises her capability. Assert the banner is exactly the truthful,
    // non-promising two lines and contains neither the training reference
    // nor the SkillSheet-review label the old copy used to dangle.
    final lockTexts = tester
        .widgetList<Text>(
          find.descendant(of: lock, matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .toList();
    expect(lockTexts, [
      '営業開始には実力 ${PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement} '
          '以上が必要です（現在 ${suzukiRuntime.actualCapability}）。',
      'まだ営業を始められません。',
    ]);
    expect(
      find.descendant(of: lock, matching: find.textContaining('社内研修')),
      findsNothing,
    );
    expect(
      find.descendant(of: lock, matching: find.textContaining('SkillSheet確認')),
      findsNothing,
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

    // ---- Empirical proof of the fixed claim ---------------------------
    // Train Suzuki in April (her only chance this month), then drive
    // real production months forward. If the old copy's promise had been
    // true, some later month would render a SkillSheet確認 action for her.
    // It never does — this is exactly the gap the corrected copy no
    // longer claims doesn't exist.
    await tapFinder(
      tester,
      find.byKey(const Key('public-demo-internal-training-action-eng-02')),
    );
    expect(
      currentState(tester).cash,
      cashBefore - 30000,
      reason: 'selecting training charges its ¥30,000 cost immediately',
    );

    await tapAndSettle(tester, '4月終了→5月');
    await dismissDialog(tester, '確認');
    expect(find.text('1年目 5月'), findsOneWidget);
    final capabilityAfterApril = currentState(
      tester,
    ).runtimeFor(suzuki.id).actualCapability;
    expect(
      capabilityAfterApril,
      greaterThan(52),
      reason: 'April training must actually raise her capability',
    );
    expect(
      capabilityAfterApril,
      lessThan(PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement),
      reason: 'one month of training cannot reach the field-sales threshold',
    );
    // May renders no founding-engineer sales card at all.
    expect(actionButton('SkillSheet確認'), findsNothing);

    await tapAndSettle(tester, '5月終了→6月');
    expect(find.text('1年目 6月'), findsOneWidget);
    // June's founding-engineer sales card is scoped to newly joined
    // applicants (joinedApplicantIds), which excludes Suzuki by design —
    // she gets no SkillSheet action here either, only the standalone
    // training card the month>=6 loop renders for every runtime.
    expect(actionButton('SkillSheet確認'), findsNothing);
    expect(
      find.byKey(const Key('public-demo-internal-training-eng-02')),
      findsOneWidget,
    );

    await tapAndSettle(tester, '6月終了→7月');
    expect(find.text('1年目 7月'), findsOneWidget);
    // Month 7 onward never renders a founding-engineer sales card again —
    // the corrected banner's "まだ営業を始められません。" is still true here,
    // and no button anywhere on screen contradicts it.
    expect(actionButton('SkillSheet確認'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
