// PLAYTEST-BLOCKER-1A regression coverage:
//
// A. September's close may successfully transition into October cash
//    shortage; October's close then commits bankruptcy.
// B. After bankruptcy:
//    - terminal state is visibly communicated (bankruptcy card)
//    - unusable month-close CTA is absent
//    - restart action exists
// C. Cash-shortage Recommended Action produces visible feedback (dialog).
// D. Restart returns Public Demo to its defined initial state.
//
// The domain-level terminal guard (monthly-close is a no-op after
// bankruptcy) is already covered by public_demo_financial_status_test.dart
// (test X) and is not re-derived here.
//
// Issue #223 (FIRST-FUN-YEAR Seeded Balance Fix) tuning
// (`PublicDemoRevenue.ratePerAssignedEngineer` 500,000 -> 600,000) means a
// single continuous Sato assignment carried past June — this file's
// original fixture — no longer reaches cashShortage/bankruptcy by March at
// all (see `public_demo_01_assignment_carryforward_test.dart`'s own class
// doc for that now-successful trajectory). Rather than re-engineer an
// increasingly contrived amount of wasted discretionary spend just to force
// the same March-specific boundary, this file now drives a genuine,
// unmodified zero-revenue trajectory instead (nobody is ever hired or
// assigned — Revenue never books anything) — the exact same trajectory
// `public_demo_seeded_balance_regression_test.dart`'s own "static
// guardrail" test locks: baseline cash survives through August, closing
// September produces cashShortage (entering October), and closing October
// produces bankruptcy (entering November, isCloseBlocked). This is still a
// real, unmodified production trajectory (never a fabricated state) and
// still exercises everything PLAYTEST-BLOCKER-1A actually cares about — an
// actual cashShortage state, then a real close that commits bankruptcy —
// just via an ordinary-month close rather than the March fiscal-year close
// specifically (that distinct code path stays covered by
// public_demo_financial_status_test.dart's own March-specific cases).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

// ---------------------------------------------------------------------------
// Test helpers (same shape as public_demo_01_completion_lock_ui_test.dart)
// ---------------------------------------------------------------------------

PublicDemoState _currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Finder _actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
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
  // SES ISSUE-232 Phase B: a close path with no further event dialog can
  // already show the Monthly Management Report here — a no-op otherwise
  // (dismissed separately via `_dismissAnyMonthCloseDialogs` once its own
  // guard/event dialog is resolved).
  await dismissMonthlyReportIfPresent(tester);
}

/// Dismisses every dialog a month-close attempt can pause on, in whatever
/// order they actually appear, before the caller's next real widget
/// interaction — the real production sequence is: the Month Guard warning
/// (only when a real, already-legal action is genuinely outstanding — see
/// [dismissMonthGuardIfPresent]'s own doc), then, only once that proceeds,
/// whatever real one-time event dialog this exact month-close transition
/// fires (e.g. April->May's own real "採用は求人媒体から始まります" guidance,
/// a genuine `PublicDemoEventDialog`, not a fabricated one) — this zero-
/// engagement fixture (nobody is ever hired, sold, or trained all year)
/// leaves every such recommendation outstanding every month, so both kinds
/// of dialog are real and expected here, in contrast to the
/// `public_demo_01_assignment_carryforward_test.dart` family's engaged
/// fixtures, which mostly only ever see the Month Guard warning.
Future<void> _dismissAnyMonthCloseDialogs(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    final guard = find.byKey(
      const Key('public-demo-month-guard-warning-dialog'),
    );
    if (guard.evaluate().isNotEmpty) {
      await dismissMonthGuardIfPresent(tester);
      continue;
    }
    final confirm = find.widgetWithText(FilledButton, '確認');
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm.first);
      await tester.pumpAndSettle();
      continue;
    }
    // SES ISSUE-232 Phase B: the Monthly Management Report is the last
    // dialog in the chain (shown only once `_commitAggregate` has already
    // run) — dismiss it exactly like the two dialogs above.
    final report = find.byKey(
      const Key('public-demo-monthly-report-dialog'),
    );
    if (report.evaluate().isNotEmpty) {
      await dismissMonthlyReportIfPresent(tester);
      continue;
    }
    break;
  }
}

Future<void> _scrollToTop(WidgetTester tester) async {
  // Scroll back to top so the HOME section is visible.
  for (var i = 0; i < 5; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
  }
}

/// Drives a genuine, unmodified zero-revenue playthrough (nobody is ever
/// hired or assigned) from April through the close that commits bankruptcy
/// — see this file's own class doc for the exact trajectory and why this
/// replaced the pre-Issue-#223 "single continuous Sato assignment" fixture.
///
/// Returns after October's close has committed and the tester is settled on
/// the post-bankruptcy screen.
Future<void> _driveToBankruptcy(WidgetTester tester) async {
  for (final label in [
    '4月を終了して5月へ',
    '5月を終了して6月へ',
    '6月を終了して7月へ',
  ]) {
    await _tapAndSettle(tester, label);
    await _dismissAnyMonthCloseDialogs(tester);
  }

  // July: choose no bonus.
  await _tapAndSettle(tester, '7月を終了して8月へ');
  await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, '7月を終了して8月へ');
  await _dismissAnyMonthCloseDialogs(tester);

  // August (cash reaches exactly 0, still normal), September (cashShortage),
  // October (bankruptcy).
  for (final label in [
    '8月を終了して翌月へ',
    '9月を終了して翌月へ',
    '10月を終了して翌月へ',
  ]) {
    await _tapAndSettle(tester, label);
    await _dismissAnyMonthCloseDialogs(tester);
  }
  // After '10月を終了して翌月へ': state.month == 11, financialStatus == bankruptcy.
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PLAYTEST-BLOCKER-1A', () {
    testWidgets('A. September close (→October) transitions into '
        'cashShortage; the October close commits bankruptcy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen(debugSeed: 9)),
      );

      for (final label in [
        '4月を終了して5月へ',
        '5月を終了して6月へ',
        '6月を終了して7月へ',
      ]) {
        await _tapAndSettle(tester, label);
        await _dismissAnyMonthCloseDialogs(tester);
      }
      await _tapAndSettle(tester, '7月を終了して8月へ');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await _tapAndSettle(tester, '7月を終了して8月へ');
      await _dismissAnyMonthCloseDialogs(tester);
      await _tapAndSettle(tester, '8月を終了して翌月へ');
      await _dismissAnyMonthCloseDialogs(tester);

      // September close → October: cashShortage.
      await _tapAndSettle(tester, '9月を終了して翌月へ');
      await _dismissAnyMonthCloseDialogs(tester);
      var state = _currentState(tester);
      expect(state.month, 10);
      expect(
        state.financialStatus,
        PublicDemoFinancialStatus.cashShortage,
        reason:
            'September close with deficit produces cashShortage entering October',
      );
      expect(state.isCloseBlocked, isFalse);
      expect(state.cash, isNegative);

      // October close: bankruptcy.
      await _tapAndSettle(tester, '10月を終了して翌月へ');
      await _dismissAnyMonthCloseDialogs(tester);
      state = _currentState(tester);
      expect(state.month, 11);
      expect(
        state.financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
        reason:
            'October close while in cashShortage with negative result → bankruptcy',
      );
      expect(state.isCloseBlocked, isTrue);
      expect(state.isFinanciallyTerminal, isTrue);
    });

    testWidgets('B. After bankruptcy: terminal state communicated, '
        'no-op close button absent, restart action exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen(debugSeed: 9)),
      );
      await _driveToBankruptcy(tester);

      final state = _currentState(tester);
      expect(state.financialStatus, PublicDemoFinancialStatus.bankruptcy);

      // Scroll back to top so the bankruptcy card is visible.
      await _scrollToTop(tester);

      // B1: bankruptcy terminal card is visible — player understands
      // the game ended because of bankruptcy, not a broken button.
      expect(
        find.byKey(const Key('public-demo-bankruptcy-card')),
        findsOneWidget,
        reason: 'bankruptcy card must communicate the terminal state',
      );

      // B2: the legacy no-op close button is absent.
      expect(
        find.text('10月を終了して翌月へ'),
        findsNothing,
        reason:
            'month-close CTA must not be shown when it cannot execute '
            '(PLAYTEST-BLOCKER-1A)',
      );

      // B3: restart action exists.
      expect(
        find.byKey(const Key('public-demo-restart-button')),
        findsOneWidget,
        reason: 'restart button must give the player a safe exit',
      );
    });

    testWidgets('C. Cash-shortage Recommended Action shows a dialog with '
        'cash, shortage amount, pending AR and explanatory text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen(debugSeed: 9)),
      );

      for (final label in [
        '4月を終了して5月へ',
        '5月を終了して6月へ',
        '6月を終了して7月へ',
      ]) {
        await _tapAndSettle(tester, label);
        await _dismissAnyMonthCloseDialogs(tester);
      }
      await _tapAndSettle(tester, '7月を終了して8月へ');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await _tapAndSettle(tester, '7月を終了して8月へ');
      await _dismissAnyMonthCloseDialogs(tester);
      await _tapAndSettle(tester, '8月を終了して翌月へ');
      await _dismissAnyMonthCloseDialogs(tester);
      await _tapAndSettle(tester, '9月を終了して翌月へ');
      await _dismissAnyMonthCloseDialogs(tester);

      final state = _currentState(tester);
      expect(state.financialStatus, PublicDemoFinancialStatus.cashShortage);

      // Scroll back to top so the HOME Recommended Action is visible.
      await _scrollToTop(tester);

      // The Recommended Action CTA for cashShortage should be visible.
      // Its label comes from HomeRecommendedActionKind.cashShortageResponse.
      // Look for the '資金不足を確認' label (the action button text).
      final cashShortageCtaFinder = find.text('資金不足を確認');
      expect(
        cashShortageCtaFinder,
        findsOneWidget,
        reason: 'cash shortage recommended action must be visible',
      );

      // C: tap the Recommended Action — it must open a dialog with
      // perceptible feedback (not just a potentially-inert scroll).
      // ensureVisible first: the button may sit below the 600px test
      // viewport even after _scrollToTop, so the tap must land inside
      // the visible area for the callback to fire.
      await tester.ensureVisible(cashShortageCtaFinder);
      await tester.pumpAndSettle();
      await tester.tap(cashShortageCtaFinder);
      await tester.pumpAndSettle();

      // Dialog is open.
      final dialogFinder = find.byKey(
        const Key('public-demo-cash-shortage-dialog'),
      );
      expect(
        dialogFinder,
        findsOneWidget,
        reason: 'cash shortage dialog must appear on tap',
      );

      // Dialog contains key information — scoped to the dialog so that
      // labels shared with the background PublicDemoCashShortageCard
      // (which remains in the widget tree while the dialog is open) do
      // not produce false "too many" failures.
      expect(
        find.descendant(of: dialogFinder, matching: find.text('現在の現預金')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialogFinder, matching: find.text('不足額')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialogFinder, matching: find.text('次回入金予定（売掛金）')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialogFinder, matching: find.textContaining('倒産')),
        findsWidgets,
      );

      // Dismiss the dialog.
      await tester.tap(
        find.byKey(const Key('public-demo-cash-shortage-dialog-dismiss')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('public-demo-cash-shortage-dialog')),
        findsNothing,
        reason: 'dialog must close on dismiss',
      );

      // Finance state is unchanged after viewing the dialog.
      final stateAfter = _currentState(tester);
      expect(stateAfter.cash, state.cash);
      expect(stateAfter.financialStatus, state.financialStatus);
    });

    testWidgets('D. Restart returns Public Demo to its defined initial state', (
      tester,
    ) async {
      // Restart requires its isolated persistent clear to succeed. Supply the
      // normal in-memory store here; clear-failure preservation is covered by
      // public_demo_01_persistence_test.dart.
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen(debugSeed: 9)),
      );
      await _driveToBankruptcy(tester);

      final bankruptState = _currentState(tester);
      expect(
        bankruptState.financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );

      // Tap restart.
      await _scrollToTop(tester);
      final restartButton = find.byKey(const Key('public-demo-restart-button'));
      expect(restartButton, findsOneWidget);
      await tester.tap(restartButton);
      await tester.pumpAndSettle();

      // D1: state matches PublicDemoAggregate.initial().state exactly.
      final restoredState = _currentState(tester);
      final expectedInitial = PublicDemoAggregate.initial().state;
      expect(
        restoredState.month,
        expectedInitial.month,
        reason: 'month resets to initial',
      );
      expect(
        restoredState.cash,
        expectedInitial.cash,
        reason: 'cash resets to initial',
      );
      expect(
        restoredState.financialStatus,
        PublicDemoFinancialStatus.normal,
        reason: 'financial status resets to normal',
      );
      expect(restoredState.isCloseBlocked, isFalse);
      expect(restoredState.isFinanciallyTerminal, isFalse);
      expect(restoredState.fiscalYearCompleted, isFalse);

      // D2: bankruptcy card is gone; month-close button is back.
      expect(
        find.byKey(const Key('public-demo-bankruptcy-card')),
        findsNothing,
        reason: 'bankruptcy card must disappear after restart',
      );
      // After restart we're in April; the April close button should be
      // reachable somewhere on screen.
      final aprilButton = find.text('4月を終了して5月へ');
      // Scroll down to find it if needed.
      for (var i = 0; aprilButton.evaluate().isEmpty && i < 10; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(
        aprilButton,
        findsOneWidget,
        reason: 'April close button is available again after restart',
      );
    });
  });
}
