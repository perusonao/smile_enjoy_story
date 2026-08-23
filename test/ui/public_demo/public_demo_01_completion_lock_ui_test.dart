import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

// POST-12MONTH-1: once the fiscal year completes, Public Demo 0.1 is a
// read-only terminal state. This walks the same real-widget April->March
// path already proven by public_demo_01_assignment_carryforward_test.dart,
// then checks (E) that a mutation CTA reachable from that terminal state
// (the waiting engineer's internal-training action) is hidden rather than
// tappable, and (F) that read-only content (the "第1期終了" card, employee
// names) is still visible and the page still scrolls.
//
// `s` (unlike the enclosing `_S` state class) is not library-private, so it
// can be read directly off the widget's State for precise assertions
// instead of scraping rendered text.
PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  final finder = actionButton(text);
  for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets, reason: 'Could not find action button: $text');
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await settle(tester);
}

Future<void> dismiss(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

Future<void> scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'after fiscal year completion, the internal-training mutation CTA is '
    'hidden and read-only content (fiscal-year-complete card, cash) is '
    'still visible',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );

      // April: Sato wins the May order (same deterministic path as the
      // carryforward test), leaving Suzuki (eng-02) waiting the whole year
      // so its internal-training card stays reachable in every later month.
      await tapAndSettle(tester, 'SkillSheet確認');
      await tapAndSettle(tester, '営業開始');
      await tapAndSettle(tester, '案件紹介');
      await tapAndSettle(tester, '上位会社面談');
      await dismiss(tester);
      await tapAndSettle(tester, '客先面談');
      await dismiss(tester);
      await tapAndSettle(tester, '受注');
      await dismiss(tester);
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);

      // May: no further hiring.
      await tapAndSettle(tester, '5月終了→6月');

      // June: accept July's continuation for Sato.
      await tapAndSettle(tester, '7月分の発注を確認');
      await tapAndSettle(tester, '受注する');
      await tapAndSettle(tester, '6月終了→7月');

      // F (pre-completion sanity): Suzuki's training card and CTA are
      // present before the fiscal year ends — this is the same CTA E will
      // later check is gone, confirming the guard is what hides it, not
      // some unrelated rendering gap.
      await scrollToEnd(tester);
      expect(
        find.byKey(const Key('public-demo-internal-training-eng-02')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('public-demo-internal-training-action-eng-02')),
        findsOneWidget,
      );

      // Close July (default "no bonus"), then every ordinary month through
      // March.
      await tapAndSettle(tester, '7月終了→8月');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, '7月終了→8月');

      const closes = [
        '8月終了→9月',
        '9月終了→10月',
        '10月終了→11月',
        '11月終了→12月',
        '12月終了→1月',
        '1月終了→2月',
        '2月終了→3月',
      ];
      for (final label in closes) {
        await tapAndSettle(tester, label);
      }

      var state = currentState(tester);
      expect(state.month, 15);
      expect(state.fiscalYearCompleted, isFalse);

      // March close completes the fiscal year.
      await tapAndSettle(tester, '3月終了→第1期終了');
      state = currentState(tester);
      expect(state.fiscalYearCompleted, isTrue);
      final cashBeforeAnyPostCompletionTap = state.cash;
      final trainingSelectionsBefore = state.trainingSelections;

      await scrollToEnd(tester);

      // E: the mutation CTA (internal training) is gone — hidden, not just
      // disabled — while the card itself (read-only: name, cost) remains.
      expect(
        find.byKey(const Key('public-demo-internal-training-eng-02')),
        findsOneWidget,
        reason: 'the training card itself is still visible (read-only info)',
      );
      expect(
        find.byKey(const Key('public-demo-internal-training-action-eng-02')),
        findsNothing,
        reason: 'the mutation CTA must be hidden once the year is complete',
      );

      // No month-close or March-close button remains reachable either.
      expect(actionButton('3月終了→第1期終了'), findsNothing);
      expect(find.textContaining('終了→'), findsNothing);

      // F: read-only navigation still works — the terminal-state card and
      // final cash figure are visible, and the page still scrolls.
      expect(
        find.byKey(const Key('public-demo-fiscal-year-complete')),
        findsOneWidget,
      );
      expect(find.text('第1期終了'), findsOneWidget);
      expect(find.textContaining('最終現預金'), findsOneWidget);

      // State truly did not change from being on this screen post-completion.
      state = currentState(tester);
      expect(state.cash, cashBeforeAnyPostCompletionTap);
      expect(state.trainingSelections, trainingSelectionsBefore);
    },
  );
}
