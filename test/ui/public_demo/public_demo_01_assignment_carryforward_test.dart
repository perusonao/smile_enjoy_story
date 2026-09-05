import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

// 12MONTH-3-FIX1 P1-1: Public Demo 0.1's formally-adopted design decision is
// that an engineer whose assignment is accepted for July continues on the
// same assignment, with no further monthly renewal decision — see
// SES_12MONTH-3_P1_Fixes_Result.md. This test exercises that *specific*
// contract end-to-end through the real widget, and proves Revenue's
// engineersAssigned count and Growth's assignment-source identity set stay
// the single source of truth for each other every month (the P1-1 SSOT bug:
// before this fix, Growth kept crediting "assignment" growth to an engineer
// Revenue had already stopped counting as assigned). That agreement is a
// pure workflow/employment fact, independent of financial status, so it
// still holds all the way through the close that produces BANKRUPTCY below.
//
// FINANCE-FAILURE-1A+1B: with only Sato billable (500,000/month Revenue)
// against the founding team's fixed 800,000/month payroll+overhead, this
// playthrough has a real structural deficit and — under the approved
// contract — reaches CASH SHORTAGE (closing February) and then BANKRUPTCY
// (closing March). See public_demo_01_completion_lock_ui_test.dart's own class doc
// for the identical trajectory (same setup: one order, carried forward once
// in June).
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
  if (text == 'SkillSheet確認') {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
}

Future<void> dismiss(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

bool grewByAssignment(PublicDemoState state, String engineerId) => state
    .latestGrowthResults
    .where((result) => result.engineerId == engineerId)
    .any((result) => result.source == PublicDemoGrowthSource.assignment);

void main() {
  testWidgets(
    'a July-accepted assignment carries forward with Revenue and Growth '
    'agreeing on the same assigned headcount every ordinary month '
    '(12MONTH-3-FIX1 P1-1 contract), through the close that reaches '
    'bankruptcy and the terminal guard afterward (FINANCE-FAILURE-1A+1B)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );

      // April: Sato wins the May order (deterministic interview scores).
      // The employee sales-progression card is on 社員 now.
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      await tapAndSettle(tester, 'SkillSheet確認');
      await tapAndSettle(tester, '営業開始');
      await tapAndSettle(tester, '案件紹介');
      await tapAndSettle(tester, '上位会社面談');
      await dismiss(tester);
      await tapAndSettle(tester, '客先面談');
      await dismiss(tester);
      await tapAndSettle(tester, '受注');
      await dismiss(tester);
      // The month-close CTA is HOME's own monthly primary action.
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismiss(tester);

      // May: no further hiring. Issue #168: neither pre-seeded applicant's
      // résumé is reviewed and recruitment media is never used this month —
      // a genuine outstanding Month Guard candidate, dismissed the same way
      // every other Public Demo suite that skips May's applicant pipeline
      // now does; it does not change this test's own trajectory.
      await tapAndSettle(tester, '5月を終了して6月へ');
      await dismissMonthGuardIfPresent(tester);

      // June: explicitly accept July's continuation — the one real decision
      // this contract is built on. The assignment (project continuation)
      // pipeline is on 営業.
      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      await tapAndSettle(tester, '7月分の発注を確認');
      expect(find.text('7月分発注あり'), findsOneWidget);
      await tapAndSettle(tester, '受注する');
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '6月を終了して7月へ');

      // A. July: the assignment is established, and Revenue/Growth already
      // agree at the very first month this contract can exist for.
      var state = currentState(tester);
      expect(state.month, 7);
      expect(state.engineersAssigned, 1);

      // Close July (confirm the default "no bonus" decision first).
      await tapAndSettle(tester, '7月を終了して8月へ');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, '7月を終了して8月へ');

      // B. August: still assigned, one real month past the June decision —
      // Growth grew Sato via "assignment", matching Revenue's count.
      state = currentState(tester);
      expect(state.month, 8);
      expect(state.engineersAssigned, 1, reason: 'B: still assigned in August');
      expect(grewByAssignment(state, 'eng-01'), isTrue, reason: 'E (August)');
      // F: Revenue's count and Growth's assignment-source identity set are
      // the same size — the exact bug this fix closes.
      expect(
        state.latestGrowthResults
            .where((r) => r.source == PublicDemoGrowthSource.assignment)
            .length,
        state.engineersAssigned,
        reason: 'F (August): Revenue count == Growth assignment-source count',
      );

      // D: Revenue settled once for July's assignment (500,000/assigned
      // engineer), carried as this month's pending balance.
      expect(state.pendingRevenue, 500000, reason: 'D (August)');

      await tapAndSettle(tester, '8月を終了して翌月へ');

      // C. September: still assigned, now several months past the one
      // June decision — proving the carry-forward is not just a 1-month
      // grace period.
      state = currentState(tester);
      expect(state.month, 9);
      expect(
        state.engineersAssigned,
        1,
        reason: 'C: still assigned in September',
      );
      expect(
        grewByAssignment(state, 'eng-01'),
        isTrue,
        reason: 'E (September)',
      );
      expect(
        state.latestGrowthResults
            .where((r) => r.source == PublicDemoGrowthSource.assignment)
            .length,
        state.engineersAssigned,
        reason: 'F (September)',
      );
      expect(state.pendingRevenue, 500000, reason: 'D (September)');

      // Close the remaining ordinary months up through the close that
      // produces BANKRUPTCY (closing March) — see this file's class doc.
      // The carry-forward/Revenue-Growth-agreement contract under test holds
      // through every one of these, including the bankruptcy-producing close
      // itself: it is a real, committed transaction (AR/expenses/cash all
      // settle, month still advances), not a rollback.
      const remainingCloses = [
        '9月を終了して翌月へ',
        '10月を終了して翌月へ',
        '11月を終了して翌月へ',
        '12月を終了して翌月へ',
        '1月を終了して翌月へ',
        '2月を終了して翌月へ',
        '3月を終了して第1期を完了',
      ];
      for (final label in remainingCloses) {
        await tapAndSettle(tester, label);
        state = currentState(tester);
        expect(
          state.engineersAssigned,
          1,
          reason: 'carry-forward holds through ${state.month}',
        );
        expect(
          state.latestGrowthResults
              .where((r) => r.source == PublicDemoGrowthSource.assignment)
              .length,
          state.engineersAssigned,
          reason: 'F holds through month ${state.month}',
        );
      }
      expect(state.month, 15);
      expect(state.fiscalYearCompleted, isFalse);
      expect(
        state.financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
        reason:
            'closing March is the second consecutive negative-cash '
            'close, so this fiscal year is already bankrupt',
      );

      // G (PLAYTEST-BLOCKER-1A + FINANCE-FAILURE-1A+1B): once bankrupt the
      // month-close button is hidden, not a silent no-op — the player sees
      // the terminal card and restart, not an inert button. The domain-level
      // guard (§22/23 test X — no duplicate AR, no duplicate expenses, no
      // false fiscal success) is proven by public_demo_financial_status_test
      // .dart and is not re-derived here.
      expect(
        find.text('3月を終了して第1期を完了'),
        findsNothing,
        reason:
            'month-close CTA must be hidden after bankruptcy '
            '(PLAYTEST-BLOCKER-1A)',
      );
    },
  );
}
