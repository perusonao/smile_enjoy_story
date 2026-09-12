import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_project_interview_test_helpers.dart';
import 'public_demo_tab_test_helpers.dart';

// POST-12MONTH-1 / FINANCE-FAILURE-1A+1B: once a terminal state is reached
// (fiscal year completed, or — B'.1 — BANKRUPTCY/marchCashShortageFailure),
// Public Demo 0.1 is a read-only terminal state. This walks the same
// real-widget April onward path already proven by
// public_demo_01_assignment_carryforward_test.dart, then checks (E) that a
// mutation CTA reachable from that terminal state (the waiting engineer's
// internal-training action) is hidden rather than tappable, and (F) that
// read-only content (cash, employee names) is still visible and the page
// still scrolls.
//
// FINANCE-FAILURE-1A+1B: this playthrough carries only Sato's single
// assignment forward past June (see the June `受注する` step below), so
// Revenue (600,000/month, Issue #223 FIRST-FUN-YEAR Seeded Balance Fix
// tuning) never fully covers the founding team's fixed 800,000/month
// payroll+overhead — a real structural deficit, though at the tuned rate a
// single continuous assignment alone no longer closes it by March on its
// own (see `public_demo_01_assignment_carryforward_test.dart`'s own class
// doc for that now-successful trajectory). To still reach a genuine
// terminal state by March, this fixture also spends real discretionary cash
// nobody ever recoups: every one of April-August's legal engineer-medium
// recruitment-media purchases (`recruitOnce`, ¥100,000 x 4 — April itself
// never renders the recruitment-media card, see `recruitOnce`'s own doc)
// plus three real (`selectInternalTraining`, ¥30,000 each) training
// purchases on Suzuki (eng-02) in April/May/June, stopped well short of her
// 60-point field-sales threshold (52 -> 58) so her waiting/untrained-this-
// month training card and mutation CTA stay genuinely reachable through
// this file's own (F) pre-completion sanity check and are never confused
// with the terminal-state guard this file actually tests. That combined
// ¥490,000 of otherwise-real, otherwise-legal spend is what tips March's
// own close negative for the first time — entering March still `normal`
// (February's own close stays non-negative) — producing
// PublicDemoFinancialStatus.marchCashShortageFailure, not bankruptcy (which
// requires entering March already in cashShortage). That terminal state is
// exactly as good a fixture for (E)/(F)'s actual concern — is a mutation CTA
// hidden, and is read-only content still reachable, once Public Demo 0.1 is
// terminal — as bankruptcy or fiscal success would have been, and
// additionally exercises the terminal guard for a path fiscal-success-only
// coverage never reached.
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
  if (text == 'スキルシート確認') {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
  // SES ISSUE-232 Phase B: a close path with no further event dialog can
  // already show the Monthly Management Report here — a no-op otherwise.
  await dismissMonthlyReportIfPresent(tester);
}

Future<void> dismiss(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
  // SES ISSUE-232 Phase B: this exact confirm can be the tap that lets
  // `_commitAggregate` run and the Monthly Management Report appear — a
  // no-op when it dismissed some other, unrelated dialog.
  await dismissMonthlyReportIfPresent(tester);
}

/// Spends this month's one legal engineer-medium recruitment-media purchase
/// (¥100,000, real production `_openRecruitmentMedia`/`recruit()` path) and
/// leaves the generated applicants completely unprocessed — a real, wasted
/// discretionary spend, never a fabricated cash deduction. Recruitment media
/// stays legal every month 4-8 ([PublicDemoState
/// .canUseRecruitmentMediaInMonth]), but the Sales tab's own recruitment-
/// media card only renders from May onward
/// (`_recruitmentMediaCardVisible`'s own doc: "never April") — so this is
/// only ever called for May through August in this file, four purchases,
/// ¥400,000 total.
Future<void> recruitOnce(WidgetTester tester) async {
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
  final openButton = find.byKey(
    const Key('public-demo-open-recruitment-media'),
  );
  await tester.ensureVisible(openButton);
  await tester.pumpAndSettle();
  await tester.tap(openButton);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const Key('public-demo-recruitment-medium-engineer')),
  );
  await tester.pumpAndSettle();
}

/// Spends this month's real, cheap (¥30,000) internal-training purchase on
/// Suzuki (eng-02) via the production `selectInternalTraining` action —
/// never a fabricated cash deduction.
Future<void> trainSuzukiOnce(WidgetTester tester) async {
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
  await scrollToEnd(tester);
  await tester.tap(
    find.byKey(const Key('public-demo-internal-training-action-eng-02')),
  );
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
    'after reaching a terminal financial state (marchCashShortageFailure), '
    'the internal-training mutation CTA is hidden and read-only content '
    '(cash, employee names) is still visible (FINANCE-FAILURE-1A+1B)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen(debugSeed: 9)),
      );

      // April: Sato wins the May order (same deterministic path as the
      // carryforward test). Suzuki (eng-02) also gets her first (of three)
      // training purchase this month — see this file's class doc for why
      // three, stopped well short of her field-sales threshold. The
      // employee sales-progression card is on 社員 now.
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      await tapAndSettle(tester, 'スキルシート確認');
      await tapAndSettle(tester, '営業開始');
      await tapAndSettle(tester, '案件紹介');
      await tapAndSettle(tester, '上位会社面談');
      await dismissPartnerInterview(tester);
      await tapAndSettle(tester, '客先面談');
      await dismissClientInterview(tester);
      await tapAndSettle(tester, '受注');
      await dismiss(tester);
      await trainSuzukiOnce(tester);
      // The month-close CTA is HOME's own monthly primary action.
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismiss(tester);

      // May: no further hiring — neither pre-seeded applicant's résumé is
      // reviewed. Recruitment media and Suzuki's second training purchase
      // are both used this month (Issue #223 tuning, wasted-spend purpose
      // — see this file's class doc), a genuine outstanding Month Guard
      // candidate the fixture dismisses the same way as any other
      // unprocessed applicant.
      await recruitOnce(tester);
      await trainSuzukiOnce(tester);
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '5月を終了して6月へ');
      await dismissMonthGuardIfPresent(tester);

      // June: accept July's continuation for Sato — the assignment
      // (project continuation) pipeline is on 営業. Also spends June's
      // recruitment-media purchase and Suzuki's third and final training
      // purchase (52 + 3 x (+2/month) = 58, still below the 60 threshold).
      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      await tapAndSettle(tester, '7月分の発注を確認');
      await tapAndSettle(tester, '受注する');
      await recruitOnce(tester);
      await trainSuzukiOnce(tester);
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '6月を終了して7月へ');
      await dismissMonthGuardIfPresent(tester);

      // F (pre-completion sanity): Suzuki's training card and CTA are
      // present before the fiscal year ends — this is the same CTA E will
      // later check is gone, confirming the guard is what hides it, not
      // some unrelated rendering gap. Training is employee detail, on 社員.
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      await scrollToEnd(tester);
      expect(
        find.byKey(const Key('public-demo-internal-training-eng-02')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('public-demo-internal-training-action-eng-02')),
        findsOneWidget,
      );

      // Spends July's recruitment-media purchase (Issue #223 tuning). No
      // more Suzuki training from here on — three purchases is the fixture's
      // own deliberate stopping point (see this file's class doc).
      await recruitOnce(tester);

      // Close July (default "no bonus"), then every ordinary month through
      // March. The month-close CTA is HOME's own monthly primary action.
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '7月を終了して8月へ');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, '7月を終了して8月へ');
      await dismissMonthGuardIfPresent(tester);

      // Spends August's recruitment-media purchase — the last month
      // recruitment media stays legal
      // ([PublicDemoState.canUseRecruitmentMediaInMonth]) — completing the
      // four-purchase, ¥400,000 total wasted recruitment spend this file's
      // class doc describes.
      await recruitOnce(tester);
      await switchPublicDemoTab(tester, PublicDemoTab.home);

      // FINANCE-FAILURE-1A+1B: closing August through March reaches a
      // genuine terminal state (marchCashShortageFailure) — see this file's
      // class doc for the exact trajectory. Closing March
      // (3月を終了して第1期を完了) is the close that actually produces it: a
      // real, committed transaction (cash/AR/expenses all settle, month
      // still advances to 12月), not a rollback.
      const closes = [
        '8月を終了して翌月へ',
        '9月を終了して翌月へ',
        '10月を終了して翌月へ',
        '11月を終了して翌月へ',
        '12月を終了して翌月へ',
        '1月を終了して翌月へ',
        '2月を終了して翌月へ',
        '3月を終了して第1期を完了',
      ];
      for (final label in closes) {
        await tapAndSettle(tester, label);
        await dismissMonthGuardIfPresent(tester);
      }

      var state = currentState(tester);
      expect(state.month, 15);
      expect(state.fiscalYearCompleted, isFalse);
      expect(
        state.financialStatus,
        PublicDemoFinancialStatus.marchCashShortageFailure,
      );
      final cashBeforeAnyPostTerminalTap = state.cash;
      final trainingSelectionsBefore = state.trainingSelections;

      // E: the mutation CTA (internal training) is gone — hidden, not just
      // disabled — while the card itself (read-only: name, cost) remains.
      // Training is employee detail, on 社員.
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      await scrollToEnd(tester);
      expect(
        find.byKey(const Key('public-demo-internal-training-eng-02')),
        findsOneWidget,
        reason: 'the training card itself is still visible (read-only info)',
      );
      expect(
        find.byKey(const Key('public-demo-internal-training-action-eng-02')),
        findsNothing,
        reason: 'the mutation CTA must be hidden once terminal',
      );
      // Employee names remain visible on 社員's own read-only cards.
      expect(find.text('佐藤 健'), findsWidgets);

      // F: read-only navigation still works — cash remains visible on
      // HOME's own terminal card, and the page still scrolls.
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      expect(find.textContaining('現預金'), findsWidgets);

      // PLAYTEST-BLOCKER-1A: the terminal card is shown so the player
      // understands the game ended, not because a button stopped working.
      expect(
        find.byKey(const Key('public-demo-bankruptcy-card')),
        findsOneWidget,
        reason: 'the terminal card must be visible',
      );

      // PLAYTEST-BLOCKER-1A: the month-close button is absent — hidden,
      // not a silent no-op — once the terminal state is reached.
      // Domain-level terminal guard (§22/23 test X) remains proven by
      // public_demo_financial_status_test.dart.
      expect(
        find.text('3月を終了して第1期を完了'),
        findsNothing,
        reason:
            'legacy no-op close button must not be visible once terminal',
      );

      // Restart action is present (tested in depth in
      // public_demo_01_bankruptcy_ux_test.dart).
      expect(
        find.byKey(const Key('public-demo-restart-button')),
        findsOneWidget,
        reason: 'restart button must be visible for the player to continue',
      );

      // Finance state is stable and was not mutated by reaching the
      // terminal state (matches domain-level test X contract).
      expect(state.cash, cashBeforeAnyPostTerminalTap);
      expect(
        state.financialStatus,
        PublicDemoFinancialStatus.marchCashShortageFailure,
      );
      expect(state.trainingSelections, trainingSelectionsBefore);
    },
  );
}
