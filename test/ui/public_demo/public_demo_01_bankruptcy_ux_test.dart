// PLAYTEST-BLOCKER-1A regression coverage:
//
// A. October close may successfully transition into November bankruptcy.
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
/// → August close (cashShortage) → October close (cashShortage) →
/// November close (bankruptcy).
///
/// Returns after the November close has committed and the tester is
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
  await _tapAndSettle(tester, '4月終了→5月');
  await _dismiss(tester);

  // May: no additional hiring.
  await _tapAndSettle(tester, '5月終了→6月');

  // June: accept July continuation for Sato (only assignment).
  await _tapAndSettle(tester, '7月分の発注を確認');
  await _tapAndSettle(tester, '受注する');
  await _tapAndSettle(tester, '6月終了→7月');

  // July: choose no bonus.
  await _tapAndSettle(tester, '7月終了→8月');
  await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, '7月終了→8月');

  // Close August through October (entering cashShortage on closing August).
  for (final label in ['8月終了→9月', '9月終了→10月', '10月終了→11月']) {
    await _tapAndSettle(tester, label);
  }
  // After '10月終了→11月', state.month == 11, financialStatus == cashShortage.

  // A. October close (→ November) successfully transitions into cashShortage.
  // That happens already above. The November close below produces bankruptcy.
  await _tapAndSettle(tester, '11月終了→12月');
  // After this close: state.month == 12, financialStatus == bankruptcy.
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PLAYTEST-BLOCKER-1A', () {
    testWidgets(
      'A. October close (→November) may transition into cashShortage; '
      'the following November close (→December) commits bankruptcy',
      (tester) async {
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
        await _tapAndSettle(tester, '4月終了→5月');
        await _dismiss(tester);
        await _tapAndSettle(tester, '5月終了→6月');
        await _tapAndSettle(tester, '7月分の発注を確認');
        await _tapAndSettle(tester, '受注する');
        await _tapAndSettle(tester, '6月終了→7月');
        await _tapAndSettle(tester, '7月終了→8月');
        await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
        await tester.pumpAndSettle();
        await _tapAndSettle(tester, '7月終了→8月');
        for (final label in ['8月終了→9月', '9月終了→10月']) {
          await _tapAndSettle(tester, label);
        }

        // October close → November: cashShortage.
        await _tapAndSettle(tester, '10月終了→11月');
        var state = _currentState(tester);
        expect(state.month, 11);
        expect(
          state.financialStatus,
          PublicDemoFinancialStatus.cashShortage,
          reason: 'October close with deficit produces cashShortage entering November',
        );
        expect(state.isCloseBlocked, isFalse);
        expect(state.cash, isNegative);

        // November close → December: bankruptcy.
        await _tapAndSettle(tester, '11月終了→12月');
        state = _currentState(tester);
        expect(state.month, 12);
        expect(
          state.financialStatus,
          PublicDemoFinancialStatus.bankruptcy,
          reason: 'November close while in cashShortage with negative result → bankruptcy',
        );
        expect(state.isCloseBlocked, isTrue);
        expect(state.isFinanciallyTerminal, isTrue);
      },
    );

    testWidgets(
      'B. After bankruptcy: terminal state communicated, '
      'no-op close button absent, restart action exists',
      (tester) async {
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
          find.text('12月終了→1月'),
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
      },
    );

    testWidgets(
      'C. Cash-shortage Recommended Action shows a dialog with '
      'cash, shortage amount, pending AR and explanatory text',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: PublicDemo01PlaceholderScreen()),
        );

        // Drive to cashShortage state (after October close → November).
        await _tapAndSettle(tester, 'SkillSheet確認');
        await _tapAndSettle(tester, '営業開始');
        await _tapAndSettle(tester, '案件紹介');
        await _tapAndSettle(tester, '上位会社面談');
        await _dismiss(tester);
        await _tapAndSettle(tester, '客先面談');
        await _dismiss(tester);
        await _tapAndSettle(tester, '受注');
        await _dismiss(tester);
        await _tapAndSettle(tester, '4月終了→5月');
        await _dismiss(tester);
        await _tapAndSettle(tester, '5月終了→6月');
        await _tapAndSettle(tester, '7月分の発注を確認');
        await _tapAndSettle(tester, '受注する');
        await _tapAndSettle(tester, '6月終了→7月');
        await _tapAndSettle(tester, '7月終了→8月');
        await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
        await tester.pumpAndSettle();
        await _tapAndSettle(tester, '7月終了→8月');
        for (final label in ['8月終了→9月', '9月終了→10月']) {
          await _tapAndSettle(tester, label);
        }
        await _tapAndSettle(tester, '10月終了→11月');

        final state = _currentState(tester);
        expect(state.financialStatus, PublicDemoFinancialStatus.cashShortage);

        // Scroll back to top so the HOME Recommended Action is visible.
        await _scrollToTop(tester);

        // The Recommended Action CTA for cashShortage should be visible.
        // Its label comes from HomeRecommendedActionKind.cashShortageResponse.
        final ctaFinder = find.byKey(const Key('public-demo-monthly-primary-cta'));
        // The cash shortage CTA is in HOME's recommended action section.
        // Look for the '資金不足を確認' label (the action button text).
        final cashShortageCtaFinder = find.text('資金不足を確認');
        expect(cashShortageCtaFinder, findsOneWidget,
            reason: 'cash shortage recommended action must be visible');

        // C: tap the Recommended Action — it must open a dialog with
        // perceptible feedback (not just a potentially-inert scroll).
        await tester.tap(cashShortageCtaFinder);
        await tester.pumpAndSettle();

        // Dialog is open.
        expect(
          find.byKey(const Key('public-demo-cash-shortage-dialog')),
          findsOneWidget,
          reason: 'cash shortage dialog must appear on tap',
        );

        // Dialog contains key information:
        // - cash is negative (label '現在の現預金' is present)
        expect(find.text('現在の現預金'), findsOneWidget);
        // - shortage amount shown
        expect(find.text('不足額'), findsOneWidget);
        // - pending AR shown
        expect(find.text('次回入金予定（売掛金）'), findsOneWidget);
        // - bankruptcy warning text
        expect(find.textContaining('倒産'), findsWidgets);

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
      },
    );

    testWidgets(
      'D. Restart returns Public Demo to its defined initial state',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: PublicDemo01PlaceholderScreen()),
        );
        await _driveToNovemberBankruptcy(tester);

        final bankruptState = _currentState(tester);
        expect(bankruptState.financialStatus, PublicDemoFinancialStatus.bankruptcy);

        // Tap restart.
        await _scrollToTop(tester);
        final restartButton = find.byKey(const Key('public-demo-restart-button'));
        expect(restartButton, findsOneWidget);
        await tester.tap(restartButton);
        await tester.pumpAndSettle();

        // D1: state matches PublicDemoAggregate.initial().state exactly.
        final restoredState = _currentState(tester);
        final expectedInitial = PublicDemoAggregate.initial().state;
        expect(restoredState.month, expectedInitial.month,
            reason: 'month resets to initial');
        expect(restoredState.cash, expectedInitial.cash,
            reason: 'cash resets to initial');
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
        final aprilButton = find.text('4月終了→5月');
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
      },
    );
  });
}
