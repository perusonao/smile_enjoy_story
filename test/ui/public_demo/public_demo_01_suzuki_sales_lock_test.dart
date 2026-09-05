import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

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
  testWidgets('Suzuki explains her sales lock truthfully, one month of April '
      'training is not enough to reopen her SkillSheet route by July, and '
      'the banner never names a specific month; Sato and finance are '
      'unaffected (see public_demo_01_suzuki_sales_reentry_test.dart for the '
      'full train-to-threshold path that does reopen it)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: PublicDemo01PlaceholderScreen()),
    );
    await tester.pumpAndSettle();
    // PUBLIC-DEMO-HOME-UI-3B: the founding-engineer sales card (and its
    // field-sales lock banner) is employee detail now reachable from 社員,
    // not HOME.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);

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
    // Issue #168 Finding B: the lock banner states the threshold gap, that
    // she has not started, and the truthful, month-agnostic causal fact —
    // reaching the threshold reopens sales "from around that point on" —
    // without ever naming a specific month, which this build cannot
    // promise (see public_demo_01_suzuki_sales_reentry_test.dart for the
    // full path that empirically proves the fact this line states). Assert
    // the banner is exactly these three lines and contains neither the
    // training-action reference nor the SkillSheet-review label.
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
      '実力が基準に達すれば、その月以降に営業を再開できます。',
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

    // ---- Empirical proof of the (now truthful, non-promising) claim ---
    // Train Suzuki in April only, then drive real production months
    // forward without training her again. One month of +1 growth cannot
    // reach the threshold on its own, so no later month in this fixture
    // renders a SkillSheet確認 action for her — consistent with the banner's
    // new copy, which never claims a specific month, only that reaching the
    // threshold (which this single training does not do) reopens sales.
    // public_demo_01_suzuki_sales_reentry_test.dart trains her every month
    // instead and proves the other half of that same sentence: once she
    // does reach the threshold, the existing (unmodified) July-February
    // window puts the SkillSheet route back.
    await tapFinder(
      tester,
      find.byKey(const Key('public-demo-internal-training-action-eng-02')),
    );
    expect(
      currentState(tester).cash,
      cashBefore - 30000,
      reason: 'selecting training charges its ¥30,000 cost immediately',
    );

    // The month-close CTA is HOME's own monthly primary action.
    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await tapAndSettle(tester, '4月を終了して5月へ');
    // Issue #168: Sato is genuinely outstanding here (skillSheet stage,
    // ready, 営業開始 never tapped) — a real Month Guard warning, dismissed
    // by proceeding; it does not change anything this test asserts below.
    await dismissMonthGuardIfPresent(tester);
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
    // May renders no founding-engineer *sales* card (SkillSheet確認 stays
    // gated to April/June/July-February, unchanged by Finding B) — checked
    // on 社員, the tab that would render it. Finding B does add May's
    // training card (see public_demo_01_suzuki_sales_reentry_test.dart),
    // which this fixture simply does not use again after April.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(actionButton('SkillSheet確認'), findsNothing);
    expect(
      find.byKey(const Key('public-demo-internal-training-eng-02')),
      findsOneWidget,
      reason: 'Finding B: May now offers the training card too',
    );

    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await tapAndSettle(tester, '5月を終了して6月へ');
    // Issue #168: neither pre-seeded applicant's résumé was reviewed and
    // recruitment media was never used this month — genuine outstanding
    // candidates, dismissed the same way.
    await dismissMonthGuardIfPresent(tester);
    expect(find.text('1年目 6月'), findsOneWidget);
    // June's founding-engineer sales card is scoped to newly joined
    // applicants (joinedApplicantIds), which excludes Suzuki by design —
    // she gets no SkillSheet action here either, only the standalone
    // training card the month>=5 loop renders for every runtime.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(actionButton('SkillSheet確認'), findsNothing);
    expect(
      find.byKey(const Key('public-demo-internal-training-eng-02')),
      findsOneWidget,
    );

    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await tapAndSettle(tester, '6月を終了して7月へ');
    expect(find.text('1年目 7月'), findsOneWidget);
    // Month 7 re-renders Suzuki's sales-flow card (RECOVERY-LOOP-1's own
    // July-February window — see public_demo_01_suzuki_sales_reentry_test
    // .dart), but a single month of April training left her well short of
    // the threshold, so it still shows the lock banner, not SkillSheet確認.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(actionButton('SkillSheet確認'), findsNothing);
    expect(
      find.byKey(const Key('public-demo-field-sales-lock-eng-02')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
