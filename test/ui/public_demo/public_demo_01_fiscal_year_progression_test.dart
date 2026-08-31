import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';

// `s` (unlike the enclosing `_S` state class) is not library-private, so it
// can be read directly off the widget's State for precise assertions
// instead of scraping rendered text (mirrors
// public_demo_01_completion_lock_ui_test.dart's own helper).
PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

// 12MONTH-3: proves the real widget can be driven from August onward via the
// new common ordinary-month button. Calendar-label correctness for internal
// months 13/14/15 ("1月"/"2月"/"3月", never "13月" etc.) is covered
// unconditionally at the pure-domain level by public_demo_month_label_test
// .dart; this widget test's own remaining concern is that the real UI wires
// that shared button/label through August-October, and that the
// FINANCE-FAILURE-1A+1B terminal guard (a bankrupt aggregate cannot mutate
// again) holds for the widget's own still-rendered close button too — see
// the FINANCE-FAILURE-1A+1B comment at this test's tail for why this
// playthrough does not reach March any more.
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
  if (text == 'SkillSheet確認') {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
}

Future<void> dismissDialog(WidgetTester tester, String confirmLabel) async {
  await tester.tap(find.widgetWithText(FilledButton, confirmLabel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Public Demo can be operated from August with correct calendar labels, '
    'and the terminal financial guard holds once this playthrough reaches '
    'bankruptcy (FINANCE-FAILURE-1A+1B)',
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
      expect(find.text('1年目 5月'), findsOneWidget);

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
      expect(find.text('1年目 8月'), findsOneWidget);
      // 12MONTH-3-FIX1 P1-2: no month past May can process a generated
      // applicant, so the paid recruitment-media CTA must not render for
      // any ordinary month (it did briefly, for 8-15, before this fix).
      expect(
        find.byKey(const Key('public-demo-recruitment-media-card')),
        findsNothing,
      );

      // August through November: each still closes via the new shared
      // ordinary month button and lands on the next calendar label.
      //
      // FINANCE-FAILURE-1A+1B: this playthrough deliberately never renews
      // Sato's assignment past June (see the class doc above) and never
      // orders a second engineer, so Revenue (0-500,000/month) never covers
      // the founding team's fixed 800,000/month payroll+overhead — a real
      // structural deficit, not a bug. Under the pre-FINANCE-FAILURE
      // contract that deficit accumulated as unlimited free debt all the
      // way to a false fiscal "success"; the approved contract instead
      // enters CASH SHORTAGE (closing October) and then BANKRUPTCY
      // (closing November) — see public_demo_monthly_close_ordinary_month_
      // test.dart's own fiscal-year test for the same trajectory verified
      // at the pure-domain level with a solvent fixture, and
      // public_demo_financial_status_test.dart for the shortage/bankruptcy
      // contract itself. Calendar-label correctness for internal months
      // 13/14/15 ("1月"/"2月"/"3月", never "13月" etc.) remains covered
      // unconditionally by public_demo_month_label_test.dart.
      const closes = [
        ('8月終了→9月', '9月'),
        ('9月終了→10月', '10月'),
        ('10月終了→11月', '11月'),
        ('11月終了→12月', '12月'),
      ];
      for (final (buttonLabel, nextMonthLabel) in closes) {
        await tapAndSettle(tester, buttonLabel);
        expect(find.text('1年目 $nextMonthLabel'), findsOneWidget);
        expect(
          find.byKey(const Key('public-demo-recruitment-media-card')),
          findsNothing,
          reason: 'month $nextMonthLabel',
        );
        if (nextMonthLabel == '11月') {
          expect(
            currentState(tester).financialStatus,
            PublicDemoFinancialStatus.cashShortage,
          );
          final flow = find.byKey(
            const Key('public-demo-monthly-cash-flow-card'),
          );
          final shortage = find.byKey(
            const Key('public-demo-cash-shortage-card'),
          );
          expect(flow, findsOneWidget);
          expect(shortage, findsOneWidget);
          // HOME-RUNTIME-2A inverted this ordering deliberately: the
          // shortage warning is hoisted to the very top of the screen, above
          // the HOME summary and therefore above the post-close cash-flow
          // detail. Same two cards, same cardinality, same single ordering
          // assertion — it now pins the order the phase established, and the
          // added HOME-relative check makes it stronger than a bare pairwise
          // comparison could be.
          expect(
            tester.getTopLeft(shortage).dy,
            lessThan(tester.getTopLeft(flow).dy),
          );
          expect(
            tester.getTopLeft(shortage).dy,
            lessThan(
              tester.getTopLeft(find.byType(PublicDemoHomeDashboardSection)).dy,
            ),
          );
        }
      }
      expect(find.text('1年目 12月'), findsOneWidget);
      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
        reason:
            'closing November (12月終了) is the second consecutive '
            'negative-cash close, so this fiscal year is already bankrupt',
      );

      // PLAYTEST-BLOCKER-1A: once bankrupt the month-close button is hidden,
      // not a silent no-op. The domain-level terminal guard (§22/23 test X)
      // is proven by public_demo_financial_status_test.dart.
      expect(
        find.text('12月終了→1月'),
        findsNothing,
        reason:
            'month-close CTA must be hidden after bankruptcy '
            '(PLAYTEST-BLOCKER-1A)',
      );
    },
  );
}
