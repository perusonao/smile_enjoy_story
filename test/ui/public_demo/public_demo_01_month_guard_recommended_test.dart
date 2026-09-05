// Issue #119 (PUBLIC-DEMO-MONTH-GUARD-1A) remaining scope, PLAYTHROUGH-
// BLOCKER-1: `closeOrdinaryMonth` (August through March) had no Month Guard
// check of any kind before this change — a player could close any of those
// months with important, already-legal, already-on-screen work left
// untouched, with no warning at all. This suite drives the real screen
// (state built by chaining the same real `PublicDemoAggregate` commands
// production uses, injected via a fixed save-service fake — the same
// technique `public_demo_01_single_month_advance_cta_test.dart` and
// `public_demo_01_bankruptcy_ux_test.dart` already use) to prove:
//
//  * no-task: nothing outstanding closes immediately, no warning at all.
//  * recommended-task: an outstanding action produces a truthful warning
//    naming it, and does not close the month until the player decides.
//  * "タスクを確認" cancels the close and returns to an actionable state —
//    the named action stays directly reachable and completable.
//  * "このまま月末処理を進める" proceeds anyway — a recommended item, unlike
//    a required one, may always be bypassed.
//
// The outstanding action used throughout is a genuine, not synthetic, one:
// an engineer sold through April's real sales pipeline whose July
// continuation was never decided in June, so
// `PublicDemoWorkflowState.assignedEngineerIds(month: 7..14)` genuinely
// never counts them assigned and
// `PublicDemoRecoveryEligibility.isEligible` genuinely holds — the exact
// fact `public_demo_01_home_recommended_action_test.dart`'s own "genuine
// Recovery action outranks the cash-shortage info card" test and
// `public_demo_month_guard_test.dart`'s domain-level tests already pin.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

final _expense = PublicDemoSalary.baselineMonthlyExpenses;

/// Sells the first founding engineer through April's real sales pipeline —
/// the same chain `public_demo_01_home_recommended_action_test.dart`'s own
/// `playApril` drives via the UI, reproduced here at the domain level so
/// this suite can reach August directly.
PublicDemoAggregate _sellFirstEngineerAndCloseApril(PublicDemoAggregate game) {
  final engineerId = game.workflow.engineers[0].id;
  game = game.startSkillSheetReview(engineerId);
  game = game.beginSelling(engineerId);
  game = game.introduceProject(engineerId);
  game = game.recordEngineerInterviewResult(
    engineerId: engineerId,
    type: PublicDemoInterviewType.partner,
  );
  game = game.recordEngineerInterviewResult(
    engineerId: engineerId,
    type: PublicDemoInterviewType.client,
  );
  game = game.recordOrder(engineerId);
  return game.closeApril(monthlyExpenses: _expense);
}

/// Reaches August with the first engineer genuinely Recovery-eligible: sold
/// in April, but June's "次月発注" step is never decided, so no assignment
/// entry is ever marked `accepted`/`ordered`.
PublicDemoAggregate _reachAugustWithOutstandingRecovery() {
  var game = PublicDemoAggregate.initial();
  game = _sellFirstEngineerAndCloseApril(game);
  game = game.closeMay(week: 9, monthlyExpenses: _expense);
  game = game.closeJune(assignedInJuly: 0, monthlyExpenses: _expense);
  game = game.confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none);
  return game.closeJuly(monthlyExpenses: _expense);
}

/// Reaches August with nothing outstanding: the same engineer's July
/// continuation is properly decided and accepted in June, exactly as
/// `public_demo_01_bankruptcy_ux_test.dart`'s own cash-shortage trajectory
/// already does via the UI ('7月分の発注を確認' → '受注する').
PublicDemoAggregate _reachAugustClean() {
  var game = PublicDemoAggregate.initial();
  game = _sellFirstEngineerAndCloseApril(game);
  game = game.closeMay(week: 9, monthlyExpenses: _expense);
  final engineerId = game.workflow.engineers[0].id;
  game = game.withAssignmentUpdate(
    engineerId,
    nextOrderStatus: PublicDemoNextOrderStatus.accepted,
  );
  game = game.closeJune(assignedInJuly: 1, monthlyExpenses: _expense);
  game = game.confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none);
  return game.closeJuly(monthlyExpenses: _expense);
}

Future<void> _pump(WidgetTester tester, PublicDemoAggregate aggregate) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PublicDemoState _currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

String _firstEngineerId(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
            .engineers[0]
            .id
        as String;

const _closeCtaKey = Key('public-demo-monthly-primary-cta');
const _dialogKey = Key('public-demo-month-guard-warning-dialog');
const _reviewKey = Key('public-demo-month-guard-review');
const _proceedKey = Key('public-demo-month-guard-proceed');

/// Scrolls the primary list until [finder] exists in the tree, or gives up.
/// Mirrors the scroll-until-found idiom every other Public Demo widget
/// suite uses (e.g. `public_demo_01_recovery_ui_test.dart`'s own
/// `_tapKeyAndSettle`).
Future<bool> _scrollUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  return finder.evaluate().isNotEmpty;
}

/// Scrolls [key] into view (existing in the tree is not the same as
/// on-screen — the 600px test viewport is shorter than this scrollable
/// list) and taps it.
Future<void> _tapKeyAndSettle(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  expect(
    await _scrollUntilFound(tester, finder),
    isTrue,
    reason: 'could not find $key',
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Month Guard recommended level at closeOrdinaryMonth (Issue #119)', () {
    testWidgets(
      'no-task: nothing outstanding closes August immediately, no warning',
      (tester) async {
        await _pump(tester, _reachAugustClean());
        expect(_currentState(tester).month, 8);

        await _tapKeyAndSettle(tester, _closeCtaKey);

        expect(find.byKey(_dialogKey), findsNothing);
        expect(_currentState(tester).month, 9);
      },
    );

    testWidgets(
      'recommended-task: an outstanding action shows a warning naming it, '
      'and does not close the month yet',
      (tester) async {
        await _pump(tester, _reachAugustWithOutstandingRecovery());
        expect(_currentState(tester).month, 8);

        await _tapKeyAndSettle(tester, _closeCtaKey);

        final dialog = find.byKey(_dialogKey);
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining('案件へ復帰させる'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.textContaining('が未対応です')),
          findsOneWidget,
        );
        // The month has NOT advanced while the warning is open.
        expect(_currentState(tester).month, 8);
      },
    );

    testWidgets('"タスクを確認" cancels the close and returns to an actionable state '
        '— the named action is directly reachable and completable', (
      tester,
    ) async {
      await _pump(tester, _reachAugustWithOutstandingRecovery());
      await _tapKeyAndSettle(tester, _closeCtaKey);
      await _tapKeyAndSettle(tester, _reviewKey);

      expect(find.byKey(_dialogKey), findsNothing);
      expect(
        _currentState(tester).month,
        8,
        reason: 'the month must not advance on review',
      );

      final engineerId = _firstEngineerId(tester);
      final recoveryKey = Key('public-demo-recovery-assignment-$engineerId');
      // 案件へ復帰 is on the employee's own sales-progression card, on 社員
      // now (PUBLIC-DEMO-HOME-UI-3B).
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(
        await _scrollUntilFound(tester, find.byKey(recoveryKey)),
        isTrue,
        reason: '案件へ復帰 must be directly reachable after review',
      );

      await _tapKeyAndSettle(tester, recoveryKey);

      expect(_currentState(tester).engineersAssigned, 1);
      expect(find.byKey(recoveryKey), findsNothing);
    });

    testWidgets('"このまま月末処理を進める" proceeds and closes the month anyway — a '
        'recommended item, unlike a required one, may be bypassed', (
      tester,
    ) async {
      await _pump(tester, _reachAugustWithOutstandingRecovery());
      await _tapKeyAndSettle(tester, _closeCtaKey);
      await _tapKeyAndSettle(tester, _proceedKey);

      expect(find.byKey(_dialogKey), findsNothing);
      expect(_currentState(tester).month, 9);
    });
  });
}
