// Issue #168 (FIRST-FUN-YEAR-ONBOARDING-1) Finding A: `april()`/`may()`/
// `june()` never called the existing `_confirmMonthCloseIfRecommendedOutstanding`
// Month Guard check that `closeOrdinaryMonth()` (August-March) already used —
// a player could advance April, May, or June with an outstanding, already-
// legal, already-on-screen action (most importantly: a genuinely
// `readyForFieldSales` founding engineer who never started their sales
// pipeline) and get no warning at all. This suite wires the same, unmodified
// `PublicDemoMonthGuard`/`PublicDemoMonthGuardWarningDialog` authority into
// those three entry points and proves it end to end, mirroring
// `public_demo_01_month_guard_recommended_test.dart`'s own technique (drive
// the real screen via `PublicDemoAggregate` commands production uses,
// injected through a fixed save-service fake) for the August case this suite
// does not touch.
//
// No new guard rule: every candidate here comes from the same
// `_recommendedActionCandidates` HOME's one recommended-action slot already
// uses.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
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

/// Sells the first founding engineer (Sato) through April's real sales
/// pipeline without closing April — the same chain
/// `public_demo_01_month_guard_recommended_test.dart`'s own
/// `_sellFirstEngineerAndCloseApril` uses, stopping one step short so the
/// resulting aggregate is still a fresh, un-closed April.
PublicDemoAggregate _sellFirstEngineerWithoutClosing() {
  var game = PublicDemoAggregate.initial();
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
  return game.recordOrder(engineerId);
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

const _closeCtaKey = Key('public-demo-monthly-primary-cta');
const _dialogKey = Key('public-demo-month-guard-warning-dialog');
const _reviewKey = Key('public-demo-month-guard-review');
const _proceedKey = Key('public-demo-month-guard-proceed');

/// Scrolls the primary list until [finder] exists in the tree, or gives up —
/// the same idiom `public_demo_01_month_guard_recommended_test.dart` uses.
Future<bool> _scrollUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  return finder.evaluate().isNotEmpty;
}

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

/// Some month-close paths (`april()`'s own event dialog) await
/// `_precacheEventImage(...)` before opening a dialog (iOS rendering fix:
/// decode the image before first paint instead of after). In this Flutter
/// SDK, `MultiFrameImageStreamCompleter` only resolves via real wall-clock
/// scheduling — the fake clock `tester.pump()`/`pumpAndSettle()` drives never
/// completes it on its own — so give the decode a real-time window via
/// `runAsync`, the same idiom every other Public Demo suite that closes
/// April already uses. Harmless when nothing is precaching.
Future<void> _settleAfterPossiblePrecache(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  group('Month Guard recommended level at April close (Issue #168)', () {
    testWidgets(
      'fresh April: Sato (ready, untouched) produces a truthful warning '
      'naming his SkillSheet review, and does not close the month yet',
      (tester) async {
        await _pump(tester, PublicDemoAggregate.initial());
        expect(_currentState(tester).month, 4);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        await _tapKeyAndSettle(tester, _closeCtaKey);

        final dialog = find.byKey(_dialogKey);
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining('佐藤 健のスキルシートを確認'),
          ),
          findsOneWidget,
        );
        expect(_currentState(tester).month, 4);
      },
    );

    testWidgets(
      '"タスクを確認" cancels the April close and Sato\'s SkillSheet review '
      'stays directly reachable on 社員',
      (tester) async {
        await _pump(tester, PublicDemoAggregate.initial());
        await switchPublicDemoTab(tester, PublicDemoTab.home);
        await _tapKeyAndSettle(tester, _closeCtaKey);
        await _tapKeyAndSettle(tester, _reviewKey);

        expect(find.byKey(_dialogKey), findsNothing);
        expect(_currentState(tester).month, 4);

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(
          await _scrollUntilFound(
            tester,
            find.widgetWithText(FilledButton, 'SkillSheet確認'),
          ),
          isTrue,
          reason: 'SkillSheet確認 must be directly reachable after review',
        );
      },
    );

    testWidgets(
      '"このまま月末処理を進める" proceeds and closes April anyway',
      (tester) async {
        await _pump(tester, PublicDemoAggregate.initial());
        await switchPublicDemoTab(tester, PublicDemoTab.home);
        await _tapKeyAndSettle(tester, _closeCtaKey);
        await _tapKeyAndSettle(tester, _proceedKey);
        await _settleAfterPossiblePrecache(tester);

        expect(find.byKey(_dialogKey), findsNothing);
        // april() continues past the guard into its own event dialog
        // (unaffected by this Issue) before the month actually advances;
        // dismiss it the same way every other April-closing test does.
        final confirm = find.widgetWithText(FilledButton, '確認');
        if (confirm.evaluate().isNotEmpty) {
          await tester.tap(confirm);
          await tester.pumpAndSettle();
        }
        expect(_currentState(tester).month, 5);
      },
    );

    testWidgets(
      'Suzuki alone outstanding (below the field-sales threshold) produces '
      'NO warning — she is never a genuinely legal, on-screen candidate',
      (tester) async {
        await _pump(tester, _sellFirstEngineerWithoutClosing());
        expect(_currentState(tester).month, 4);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        await _tapKeyAndSettle(tester, _closeCtaKey);
        await _settleAfterPossiblePrecache(tester);

        expect(find.byKey(_dialogKey), findsNothing);
        // april() still runs its own (unrelated) event dialog; dismiss it.
        final confirm = find.widgetWithText(FilledButton, '確認');
        if (confirm.evaluate().isNotEmpty) {
          await tester.tap(confirm);
          await tester.pumpAndSettle();
        }
        expect(_currentState(tester).month, 5);
      },
    );
  });

  group('Month Guard recommended level at May close (Issue #168)', () {
    testWidgets(
      'fresh May: both pre-seeded applicants unreviewed and recruitment '
      'media unused produce a truthful warning, and May does not close yet',
      (tester) async {
        final april = _sellFirstEngineerWithoutClosing().closeApril(
          monthlyExpenses: _expense,
        );
        await _pump(tester, april);
        expect(_currentState(tester).month, 5);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        await _tapKeyAndSettle(tester, _closeCtaKey);

        final dialog = find.byKey(_dialogKey);
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining('が未対応です'),
          ),
          findsWidgets,
        );
        expect(_currentState(tester).month, 5);

        await _tapKeyAndSettle(tester, _proceedKey);
        expect(find.byKey(_dialogKey), findsNothing);
        expect(_currentState(tester).month, 6);
      },
    );
  });

  group('Month Guard recommended level at June close (Issue #168)', () {
    testWidgets(
      'no-task: a June with nothing outstanding closes immediately, no '
      'warning at all (june() becoming async to await the guard changes '
      'nothing about its own commit/reset behavior)',
      (tester) async {
        var game = _sellFirstEngineerWithoutClosing().closeApril(
          monthlyExpenses: _expense,
        );
        game = game.closeMay(week: 9, monthlyExpenses: _expense);
        // closeMay turns Sato's April order into a real assignment — its
        // own "翌月発注を確認" decision would otherwise be a genuine
        // outstanding June candidate (`_addAssignmentCandidate`), so resolve
        // it first, the same way `_reachAugustClean` does for August's own
        // no-task case.
        final engineerId = game.workflow.engineers[0].id;
        game = game.withAssignmentUpdate(
          engineerId,
          nextOrderStatus: PublicDemoNextOrderStatus.accepted,
        );
        await _pump(tester, game);
        expect(_currentState(tester).month, 6);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        await _tapKeyAndSettle(tester, _closeCtaKey);

        expect(find.byKey(_dialogKey), findsNothing);
        expect(_currentState(tester).month, 7);
      },
    );
  });
}
