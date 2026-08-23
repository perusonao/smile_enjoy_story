import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

// 12MONTH-3: proves the real widget can be driven from August through the
// March close via the new common ordinary-month button, that internal
// months 13/14/15 always render as "1月"/"2月"/"3月" (never "13月" etc.),
// and that the minimal year-end card appears afterward.
//
// April orders one engineer (Sato) via the same deterministic interview
// steps public_demo_01_success_playthrough_test.dart already exercises,
// since a "zero orders the whole way" route runs out of cash exactly at
// July's fixed bonus-close cash guard (a pre-existing, unrelated contract)
// and never reaches August at all. May and June are then driven with no
// further hiring/order-renewal interaction: neither is needed for July's
// cash guard to pass, since that guard depends only on the Revenue already
// booked from April's single order, not on any later decision.
// Matches public_demo_01_success_playthrough_test.dart's helper (ancestor
// button lookup + drag-until-visible + ensureVisible), since this test also
// taps real interactive stage buttons (SkillSheet確認, 上位会社面談, ...), not
// just the always-present month-close buttons.
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
  await _settleAfterPossiblePrecache(tester);
}

Future<void> dismissDialog(WidgetTester tester, String confirmLabel) async {
  await tester.tap(find.widgetWithText(FilledButton, confirmLabel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Public Demo can be operated from August through the March close, with '
    'correct calendar labels at every internal month 8-15',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );

      // April: Sato wins the May order (deterministic interview scores),
      // matching public_demo_01_success_playthrough_test.dart's route.
      await tapAndSettle(tester, 'SkillSheet確認');
      await tapAndSettle(tester, '営業開始');
      await tapAndSettle(tester, '案件紹介');
      await tapAndSettle(tester, '上位会社面談');
      await dismissDialog(tester, '確認');
      await tapAndSettle(tester, '客先面談');
      await dismissDialog(tester, '確認');
      await tapAndSettle(tester, '受注');
      await dismissDialog(tester, '確認');
      await tapAndSettle(tester, '4月終了→5月');
      await dismissDialog(tester, '確認');
      expect(find.text('5月'), findsOneWidget);

      // May and June: no further hiring or order-renewal interaction. Sato's
      // April order alone is enough Revenue for July's cash guard to pass.
      await tapAndSettle(tester, '5月終了→6月');
      await tapAndSettle(tester, '6月終了→7月');

      // July requires confirming the (default "none") summer bonus decision
      // before the close button actually closes the month.
      await tapAndSettle(tester, '7月終了→8月');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, '7月終了→8月');
      expect(find.text('8月'), findsOneWidget);
      // 12MONTH-3-FIX1 P1-2: no month past May can process a generated
      // applicant, so the paid recruitment-media CTA must not render for
      // any ordinary month (it did briefly, for 8-15, before this fix).
      expect(
        find.byKey(const Key('public-demo-recruitment-media-card')),
        findsNothing,
      );

      // August through February: each closes via the new shared ordinary
      // month button and lands on the next calendar label.
      const closes = [
        ('8月終了→9月', '9月'),
        ('9月終了→10月', '10月'),
        ('10月終了→11月', '11月'),
        ('11月終了→12月', '12月'),
        ('12月終了→1月', '1月'),
        ('1月終了→2月', '2月'),
        ('2月終了→3月', '3月'),
      ];
      for (final (buttonLabel, nextMonthLabel) in closes) {
        await tapAndSettle(tester, buttonLabel);
        expect(find.text(nextMonthLabel), findsOneWidget);
        expect(find.text('13月'), findsNothing);
        expect(find.text('14月'), findsNothing);
        expect(find.text('15月'), findsNothing);
        expect(
          find.byKey(const Key('public-demo-recruitment-media-card')),
          findsNothing,
          reason: 'month $nextMonthLabel',
        );
      }
      expect(find.text('3月'), findsOneWidget);
      expect(find.text('13月'), findsNothing);
      expect(find.text('14月'), findsNothing);
      expect(find.text('15月'), findsNothing);

      // March closes the fiscal year instead of advancing to a 13th month.
      await tapAndSettle(tester, '3月終了→第1期終了');
      expect(
        find.byKey(const Key('public-demo-fiscal-year-complete')),
        findsOneWidget,
      );
      expect(find.text('第1期終了'), findsOneWidget);
      expect(find.text('1年間の経営が終了しました。'), findsOneWidget);
      expect(find.text('3月終了→第1期終了'), findsNothing);
    },
  );
}
