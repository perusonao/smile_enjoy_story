// PLAYTEST-BLOCKER-1A regression coverage:
//
// A. February close may successfully transition into March cash shortage.
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

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
  if (text == 'SkillSheet確認') {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
}

Future<void> _dismiss(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

Future<void> _scrollToTop(WidgetTester tester) async {
  // Scroll back to top so the HOME section is visible.
  for (var i = 0; i < 5; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
  }
}

/// Drives a no-hire playthrough from April to the point just before
/// the first ordinary-month close that would produce bankruptcy.
///
/// Path: April → May (no hire) → June (Sato continues) → July (no bonus)
/// → ordinary closes through February → March close (cashShortage) →
/// fiscal-year close (bankruptcy).
///
/// Returns after the March close has committed and the tester is
/// settled on the post-bankruptcy screen.
Future<void> _driveToNovemberBankruptcy(WidgetTester tester) async {
  // April: advance Sato to receive the May order.
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

  // May: no additional hiring.
  await _tapAndSettle(tester, '5月を終了して6月へ');

  // June: accept July continuation for Sato (only assignment).
  await _tapAndSettle(tester, '7月分の発注を確認');
  await _tapAndSettle(tester, '受注する');
  await _tapAndSettle(tester, '6月を終了して7月へ');

  // July: choose no bonus.
  await _tapAndSettle(tester, '7月を終了して8月へ');
  await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, '7月を終了して8月へ');

  // Close August through January; February closes into March shortage.
  for (final label in [
    '8月を終了して翌月へ',
    '9月を終了して翌月へ',
    '10月を終了して翌月へ',
    '11月を終了して翌月へ',
    '12月を終了して翌月へ',
    '1月を終了して翌月へ',
    '2月を終了して翌月へ',
  ]) {
    await _tapAndSettle(tester, label);
  }
  // After '2月を終了して翌月へ', state.month == 15, financialStatus == cashShortage.

  // March's fiscal-year close produces bankruptcy.
  await _tapAndSettle(tester, '3月を終了して第1期を完了');
  // After this close: state.month == 15, financialStatus == bankruptcy.
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PLAYTEST-BLOCKER-1A', () {
    testWidgets('A. February close (→March) transitions into cashShortage; '
        'the March fiscal-year close commits bankruptcy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );

      // Drive to just before the November close.
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
      await _tapAndSettle(tester, '5月を終了して6月へ');
      await _tapAndSettle(tester, '7月分の発注を確認');
      await _tapAndSettle(tester, '受注する');
      await _tapAndSettle(tester, '6月を終了して7月へ');
      await _tapAndSettle(tester, '7月を終了して8月へ');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await _tapAndSettle(tester, '7月を終了して8月へ');
      for (final label in [
        '8月を終了して翌月へ',
        '9月を終了して翌月へ',
        '10月を終了して翌月へ',
        '11月を終了して翌月へ',
        '12月を終了して翌月へ',
        '1月を終了して翌月へ',
      ]) {
        await _tapAndSettle(tester, label);
      }

      // February close → March: cashShortage.
      await _tapAndSettle(tester, '2月を終了して翌月へ');
      var state = _currentState(tester);
      expect(state.month, 15);
      expect(
        state.financialStatus,
        PublicDemoFinancialStatus.cashShortage,
        reason:
            'February close with deficit produces cashShortage entering March',
      );
      expect(state.isCloseBlocked, isFalse);
      expect(state.cash, isNegative);

      // March fiscal-year close: bankruptcy.
      await _tapAndSettle(tester, '3月を終了して第1期を完了');
      state = _currentState(tester);
      expect(state.month, 15);
      expect(
        state.financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
        reason:
            'March close while in cashShortage with negative result → bankruptcy',
      );
      expect(state.isCloseBlocked, isTrue);
      expect(state.isFinanciallyTerminal, isTrue);
    });

    testWidgets('B. After bankruptcy: terminal state communicated, '
        'no-op close button absent, restart action exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );
      await _driveToNovemberBankruptcy(tester);

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
        find.text('3月を終了して第1期を完了'),
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
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );

      // Drive to cashShortage state (after February close → March).
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
      await _tapAndSettle(tester, '5月を終了して6月へ');
      await _tapAndSettle(tester, '7月分の発注を確認');
      await _tapAndSettle(tester, '受注する');
      await _tapAndSettle(tester, '6月を終了して7月へ');
      await _tapAndSettle(tester, '7月を終了して8月へ');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await _tapAndSettle(tester, '7月を終了して8月へ');
      for (final label in [
        '8月を終了して翌月へ',
        '9月を終了して翌月へ',
        '10月を終了して翌月へ',
        '11月を終了して翌月へ',
        '12月を終了して翌月へ',
        '1月を終了して翌月へ',
      ]) {
        await _tapAndSettle(tester, label);
      }
      await _tapAndSettle(tester, '2月を終了して翌月へ');

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
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );
      await _driveToNovemberBankruptcy(tester);

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
