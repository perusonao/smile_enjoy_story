// RECOVERY-LOOP-1: UI-level regression coverage for the "案件へ復帰"
// (Recovery) button and the month 7-14 waiting-engineer card section added
// to `public_demo_01_placeholder_screen.dart`. The 59 existing Recovery
// tests already exhaustively cover `PublicDemoRecoveryEligibility` and
// `PublicDemoAggregate.recoverAssignment` at the domain level (see
// docs/reports/SES_RECOVERY-LOOP-1_Implementation_Result.md's KNOWN
// ISSUES); this file's job is narrower — prove the real, rendered widget
// actually wires those domain facts up: the button only appears when
// genuinely eligible, tapping it visibly converts waiting -> assigned with
// no duplicate, and it never appears when month/terminal/training-selected
// blocks it.
//
// app-01 (高橋 翔) is the only Public Demo 0.1 hire that can ever reach this
// state: app-02 (田中 美咲, interviewScore 58) fails the recruitment
// interview's own >=60 gate and can never be offered at all, and eng-02
// (鈴木 葵, capability 52) is permanently locked out of field sales for the
// whole fiscal year (see public_demo_01_suzuki_sales_lock_test.dart). Every
// scenario below therefore hires app-01 in May, deliberately leaves them
// unrecovered through June (skip their post-join sales pipeline), and drives
// the SAME real production UI used everywhere else in this suite.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

const _appId = 'app-01';

PublicDemoState _currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

PublicDemoWorkflowState _currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

Finder _actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _tapAndSettle(WidgetTester tester, String text) async {
  final finder = _actionButton(text);
  for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets, reason: 'Could not find action button: $text');
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await _settle(tester);
  if (text == 'SkillSheet確認') {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
  // Issue #119: a month-close tap now truthfully names app-01's own
  // outstanding "案件へ復帰" step as a `recommended`-level Month Guard
  // warning whenever this test has deliberately left them un-recovered —
  // exactly what PLAYTHROUGH-BLOCKER-2 exists to surface. This suite's own
  // assertions are about button visibility, not this warning, so proceed
  // through it exactly as "このまま月末処理を進める" would.
  final monthGuardProceed = find.byKey(
    const Key('public-demo-month-guard-proceed'),
  );
  if (monthGuardProceed.evaluate().isNotEmpty) {
    await tester.tap(monthGuardProceed);
    await tester.pumpAndSettle();
  }
}

Future<void> _tapKeyAndSettle(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget, reason: 'Could not find widget with key: $key');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _dismiss(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

/// April: sells eng-01 (佐藤 健) through the normal founding-engineer
/// pipeline — the only fiscal-year-sellable founding engineer (see
/// `e2e/tests/public-demo-annual-route.spec.ts`'s own header doc) — then
/// closes into May.
Future<void> _sellFoundingEngineerAndCloseApril(WidgetTester tester) async {
  await _tapAndSettle(tester, 'SkillSheet確認');
  await _tapAndSettle(tester, '営業開始');
  await _tapAndSettle(tester, '案件紹介');
  await _tapAndSettle(tester, '上位会社面談');
  await _dismiss(tester);
  await _tapAndSettle(tester, '客先面談');
  await _dismiss(tester);
  await _tapAndSettle(tester, '受注');
  await _dismiss(tester);
  await _tapAndSettle(tester, '4月を終了して5月へ');
  await _dismiss(tester);
}

/// May: interviews and offers app-01 (高橋 翔) but deliberately stops right
/// after the offer — no pre-entry SkillSheet/selling/interview/order — so
/// app-01 joins in May's close purely on the accepted offer
/// (`closeMay`'s own `accepted()` set already includes `offerAccepted`) and
/// enters June/July as a genuinely economically-waiting engineer, not one
/// whose pre-entry sales progress silently carried them straight to
/// `ordered`.
Future<void> _hireAppOneWithoutPreEntrySales(WidgetTester tester) async {
  await _tapAndSettle(tester, '経歴書確認');
  await _tapAndSettle(tester, '採用面談');
  expect(find.textContaining('評価 74'), findsOneWidget);
  await _tapAndSettle(tester, '合格・給与提示');
  await tester.tap(find.byKey(const Key('public-demo-salary-offer-320000')));
  await tester.pumpAndSettle();
}

/// Runs app-01's full post-join sales pipeline (identical shape to a
/// founding engineer's own `ec(i)` buttons) from `waiting` to `ordered` —
/// the walk `PublicDemoRecoveryEligibility`'s own class doc describes as
/// reachable in July "or any later month" since none of these transitions
/// are month-gated.
Future<void> _runAppOneSalesPipelineToOrdered(WidgetTester tester) async {
  await _tapAndSettle(tester, 'SkillSheet確認');
  await _tapAndSettle(tester, '営業開始');
  await _tapAndSettle(tester, '案件紹介');
  await _tapAndSettle(tester, '上位会社面談');
  await _dismiss(tester);
  await _tapAndSettle(tester, '客先面談');
  await _dismiss(tester);
  await _tapAndSettle(tester, '受注');
  await _dismiss(tester);
}

void main() {
  testWidgets(
    'a Recovery-eligible waiting engineer shows the sales-pipeline UI in '
    'July, 案件へ復帰 appears only once ordered, and tapping it converts '
    'waiting -> assigned exactly once (no duplicate assignment)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );

      await _sellFoundingEngineerAndCloseApril(tester);
      await _hireAppOneWithoutPreEntrySales(tester);
      // No pre-entry order was ever recorded for app-01 (deliberately — see
      // `_hireAppOneWithoutPreEntrySales`'s own doc), so May's close mints
      // no "入社・初参画！" first-assignment event to dismiss here, unlike
      // public_demo_01_success_playthrough_test.dart's own hire flow.
      await _tapAndSettle(tester, '5月を終了して6月へ');

      // June: accept eng-01's July continuation but deliberately leave
      // app-01 completely untouched — they must still be `waiting`.
      await _tapAndSettle(tester, '7月分の発注を確認');
      await _tapAndSettle(tester, '受注する');
      await _tapAndSettle(tester, '6月を終了して7月へ');

      var state = _currentState(tester);
      expect(state.month, 7);
      expect(
        state.engineersWaiting,
        2,
        reason: 'app-01 (unrecovered) and the permanently field-sales-locked '
            'eng-02 (see public_demo_01_suzuki_sales_lock_test.dart) must '
            'both still be economically waiting entering July',
      );

      // July: app-01's waiting-engineer card is reachable with the same
      // sales-pipeline entry point as April/June (STEP 1: "Recovery eligible
      // waiting engineerにRecovery sales UIが表示される").
      expect(
        find.byKey(const Key('public-demo-recovery-assignment-$_appId')),
        findsNothing,
        reason: '案件へ復帰 must not render before app-01 reaches `ordered`',
      );
      await _runAppOneSalesPipelineToOrdered(tester);

      // Once ordered, the Recovery button appears (STEP 1: "sales pipeline
      // ordered後: 「案件へ復帰」が表示される").
      final recoveryButtonKey = Key('public-demo-recovery-assignment-$_appId');
      expect(find.byKey(recoveryButtonKey), findsOneWidget);

      final beforeAssigned = _currentState(tester).engineersAssigned;
      final beforeWaiting = _currentState(tester).engineersWaiting;

      await _tapKeyAndSettle(tester, recoveryButtonKey);

      // Tap converts waiting -> assigned; the button disappears (STEP 1:
      // "tap後: waiting → assigned「案件へ復帰」が消える").
      state = _currentState(tester);
      expect(state.engineersAssigned, beforeAssigned + 1);
      expect(state.engineersWaiting, beforeWaiting - 1);
      expect(find.byKey(recoveryButtonKey), findsNothing);

      final workflow = _currentWorkflow(tester);
      final appOneAssignments = workflow.assignments
          .where((assignment) => assignment.engineerId == _appId)
          .toList();
      expect(
        appOneAssignments,
        hasLength(1),
        reason: 'STEP 1: duplicate assignmentなし',
      );
      expect(
        appOneAssignments.single.nextOrderStatus,
        PublicDemoNextOrderStatus.accepted,
      );
      expect(
        appOneAssignments.single.replacementStage,
        PublicDemoReplacementStage.ordered,
      );

      // Advancing another month re-confirms the recovered assignment stays
      // single and the button never reappears (production defense in depth
      // — see `recoverLateYearAssignment`'s own doc — mirrored here as an
      // observable UI fact, not just a domain one).
      await _tapAndSettle(tester, '7月を終了して8月へ');
      await _tapKeyAndSettle(
        tester,
        const Key('public-demo-summer-bonus-none'),
      );
      await _tapAndSettle(tester, '7月を終了して8月へ');
      expect(find.byKey(recoveryButtonKey), findsNothing);
      expect(
        _currentWorkflow(tester).assignments
            .where((assignment) => assignment.engineerId == _appId)
            .length,
        1,
      );
    },
  );

  testWidgets(
    'a training-selected engineer never shows 案件へ復帰 even once genuinely '
    'ordered, and March (month 15) renders no Recovery entry point at all '
    'for the same never-recovered engineer',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );

      await _sellFoundingEngineerAndCloseApril(tester);
      await _hireAppOneWithoutPreEntrySales(tester);
      await _tapAndSettle(tester, '5月を終了して6月へ');
      await _tapAndSettle(tester, '7月分の発注を確認');
      await _tapAndSettle(tester, '受注する');
      await _tapAndSettle(tester, '6月を終了して7月へ');

      await _runAppOneSalesPipelineToOrdered(tester);
      final recoveryButtonKey = Key('public-demo-recovery-assignment-$_appId');
      expect(
        find.byKey(recoveryButtonKey),
        findsOneWidget,
        reason: 'app-01 must be genuinely eligible before training exclusion '
            'is a meaningful assertion',
      );

      // Selecting internal training for app-01 this month must hide 案件へ
      // 復帰 even though every other eligibility fact still holds (STEP 1:
      // "training-selectedではRecovery不可").
      await _tapKeyAndSettle(
        tester,
        const Key('public-demo-internal-training-action-$_appId'),
      );
      expect(
        _currentState(tester).trainingSelections.containsKey(_appId),
        isTrue,
      );
      expect(find.byKey(recoveryButtonKey), findsNothing);

      // A training selection is a single month's decision, not a permanent
      // exclusion: closing July clears it, and app-01 (still `ordered`,
      // still unassigned, still non-terminal, still inside the window) must
      // become Recovery-eligible again in August — proving the training
      // guard is exactly as month-scoped as `selectInternalTraining` itself,
      // not a wider, accidental lockout.
      await _tapAndSettle(tester, '7月を終了して8月へ');
      await _tapKeyAndSettle(tester, const Key('public-demo-summer-bonus-none'));
      await _tapAndSettle(tester, '7月を終了して8月へ');
      expect(_currentState(tester).month, 8);
      expect(
        _currentState(tester).trainingSelections.containsKey(_appId),
        isFalse,
        reason: 'a training selection does not persist past its own month',
      );
      expect(
        find.byKey(recoveryButtonKey),
        findsOneWidget,
        reason: '案件へ復帰 must reappear once training is no longer selected',
      );

      // From here, close every remaining ordinary month, without ever
      // recovering app-01, through month 15 (March). Financial status is
      // left to fall out of real production economics (one billable
      // founding engineer against a second, indefinitely-waiting hire's
      // salary) rather than forced — whichever guard first removes the
      // still-eligible-except-for-that-one-fact 案件へ復帰 entry point (the
      // terminal guard, if reached, or the month guard at 15) is asserted
      // as it actually occurs, so this is one real playthrough proving
      // whichever of "terminalではRecovery不可" / "MarchではRecovery entry
      // pointなし" actually applies first, not a staged one.
      const closeLabels = [
        '8月を終了して翌月へ',
        '9月を終了して翌月へ',
        '10月を終了して翌月へ',
        '11月を終了して翌月へ',
        '12月を終了して翌月へ',
        '1月を終了して翌月へ',
        '2月を終了して翌月へ',
      ];
      var sawTerminalBeforeMarch = false;
      for (final label in closeLabels) {
        final closeButton = _actionButton(label);
        for (var i = 0; closeButton.evaluate().isEmpty && i < 20; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pumpAndSettle();
        }
        if (closeButton.evaluate().isEmpty) {
          // The month-close CTA is hidden once bankruptcy is reached
          // (PLAYTEST-BLOCKER-1A) — a terminal state was reached before
          // March, and Recovery is necessarily unreachable from here on.
          sawTerminalBeforeMarch = true;
          break;
        }
        await _tapAndSettle(tester, label);
        if (_currentState(tester).isFinanciallyTerminal) {
          sawTerminalBeforeMarch = true;
          break;
        }
      }

      // In practice this playthrough's real economics (one billable founding
      // engineer's ¥500,000/month against two salaried-but-idle employees'
      // full fixed costs) reach BANKRUPTCY around internal month 11 — well
      // inside the Recovery window — so the assertions below exercise the
      // terminal guard specifically, not the month guard; `sawTerminalBeforeMarch`
      // is still checked explicitly rather than assumed, so a future balance
      // change that lets this same playthrough survive to March intact
      // still gets a correct, non-vacuous "MarchではRecovery entry pointなし"
      // assertion instead of silently passing on the wrong branch.
      final finalState = _currentState(tester);
      if (!sawTerminalBeforeMarch) {
        expect(finalState.month, 15, reason: 'March is internal month 15');
      }
      expect(
        find.byKey(recoveryButtonKey),
        findsNothing,
        reason: 'no Recovery entry point remains, terminal or March alike',
      );
      expect(
        find.text('案件へ復帰'),
        findsNothing,
        reason: 'STEP 1: no Recovery entry point anywhere on screen',
      );
    },
  );
}
