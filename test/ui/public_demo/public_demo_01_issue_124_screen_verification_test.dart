// SES ISSUE #124 (PUBLIC-DEMO-HOME-UI-2A) / ISSUE #147
// (PUBLIC-DEMO-HOME-UI-3A): Screen Verification follow-up.
//
// Real-device Screen Verification on PR #145's deploy found that, in the
// initial portrait viewport (360px and 390px wide, no scrolling), a player
// could see the month, cash, participation/waiting counts, sales-remaining,
// headcount, revenue, the pending-deposit figure, Hiyori's next action and
// its CTA, and the Office Stage picture — but NOT each employee's current
// sales/assignment status ("案件状況") or anything about what changed this
// month, because the picture-based "社員の様子" section and the list-based
// "社員ステージ" section duplicated the same two employees across roughly
// twice the vertical space either alone would need. PR for #124 compacted
// both sections to fit the same content budget.
//
// Issue #147 (PUBLIC-DEMO-HOME-UI-3A) rebuilds HOME to the approved
// mobile visual target and DELETES the duplicate "社員ステージ" list
// entirely — HomeOfficeStageSection (home-office-stage) is now the only
// employee-roster presentation on HOME, so the "two sections duplicate the
// same roster" question this suite originally existed to answer no longer
// has two sections to compare. It also adds two new required sections
// ("今月の重要タスク", "クイックアクセス") between the Office Stage and the
// finance detail, which legitimately grow the page taller than the old
// content budget — so the strict "everything fits inside 615/660pt" pixel
// assertion is retired along with the sections it was measuring.
//
// Issue #148 Phase 1B.3 (HOME-COMPACT-1B.3) re-prioritizes the initial
// viewport once more: the monthly progression CTA moves directly under the
// Navigator card so it — not the Office Stage picture — is guaranteed
// visible with no scroll. The Office Stage remains reachable (by scroll,
// quick access, and the bottom nav — see the other suites that pin that),
// but it is no longer required to be painted inside the very first frame;
// "誰が待機/利用可能か" is dropped from the list this test checks and
// replaced with the monthly CTA, which Issue #148 Phase 1B.3's acceptance
// criteria explicitly requires in the initial view.
//
// HOME-COMPACT-1B.4 restores the Office Stage to this required set — the
// 経営ダッシュボード visual target's acceptance criteria ask for 月・KPI・
// ひよりの主CTA・月次CTA・社員概要 to ALL be visible with no scroll, not either
// the monthly CTA or the Office Stage. This is affordable now because the
// phase compacted what sits above it (a bigger Hiyori portrait costs no
// extra height — the text column already decided the card's height — and a
// tighter advice bubble and a slimmed monthly-CTA card give real room
// back), not because the Office Stage itself grew a new budget. What
// survives from #124's original intent — that the core "what do I need to
// know right now" facts are genuinely painted in the unscrolled initial
// viewport, not merely present somewhere on a long scroll — is kept below,
// updated for the current required set.
//
// HOME-COMPACT-1B.4 FIX1 extends this one state further: an ACTUAL cash
// shortage (`financialStatus == cashShortage`) renders the pre-existing
// PublicDemoCashShortageCard above everything else — the correct, unchanged
// priority — but that card alone used to cost ~245pt at 360x800, enough to
// push 社員概要 below the fold even after the trims above. The group at the
// bottom of this file pins the same five-fact requirement for that state
// too, now that PublicDemoCashShortageCard's own display density (never its
// warning, evidence figures, or CTA) is compacted, and the Navigator's
// secondary "他の行動を確認する" route and duplicate advice explanation are
// dropped for this one state only — see PublicDemo01PlaceholderScreen
// ._isActualCashShortage's own doc for why neither of those two omissions
// touches the normal or preventive-caution states this file's other tests
// already cover.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

Future<void> pumpDemoAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  await tester.pumpAndSettle();
}

const _sizes = <Size>[Size(360, 800), Size(390, 844)];

void main() {
  for (final size in _sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets(
      'Issue #124/#147/#148 Phase 1B.3: month, cash, next action, and the '
      'monthly progression CTA are all painted in the unscrolled initial '
      'viewport at $label',
      (tester) async {
        await pumpDemoAt(tester, size);

        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          0,
          reason: 'the assertions below must describe the unscrolled screen',
        );

        final viewport = tester.getRect(find.byType(ListView));
        void expectInFirstView(Finder finder, String fact) {
          expect(finder, findsOneWidget, reason: 'missing: $fact');
          final rect = tester.getRect(finder);
          expect(
            rect.top,
            greaterThanOrEqualTo(viewport.top),
            reason: '$fact starts above the viewport',
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(viewport.bottom),
            reason: '$fact is not painted inside the raw viewport',
          );
        }

        // 1: what month is it.
        expectInFirstView(find.text('1年目 4月'), '月 (month)');

        // 2: how much cash is on hand.
        expectInFirstView(
          find.descendant(
            of: find.byKey(const Key('home-kpi-compact-cash')),
            matching: find.text('¥400万'),
          ),
          '現金 (cash)',
        );

        // 3: what to do next — Hiyori's headline plus her CTA.
        expectInFirstView(
          find.byKey(const Key('home-recommended-action-headline')),
          '次にやること (next action headline)',
        );
        expectInFirstView(
          find.byKey(const Key('home-recommended-action-cta')),
          '次にやること CTA',
        );

        // 4: the monthly progression CTA — Issue #148 Phase 1B.3 requires
        // it visible with no scroll, alongside 月/KPI/ひより.
        expectInFirstView(
          find.byKey(const Key('public-demo-monthly-primary-cta')),
          '月次進行CTA (monthly close CTA)',
        );

        // 5: HOME-COMPACT-1B.4 — the "社員の様子" employee-overview card
        // itself, not merely a name somewhere further down the page. Its
        // aggregate headcount/waiting summary is part of the same required
        // fact — see the class doc above for what it does and does not
        // claim.
        expectInFirstView(
          find.byKey(const Key('home-office-stage')),
          '社員概要 (employee overview)',
        );
        expectInFirstView(
          find.byKey(const Key('home-office-stage-headcount-summary')),
          '社員概要の人数・待機状況 (employee overview headcount/waiting summary)',
        );

        // The Office Stage still shows both founding engineers.
        expect(find.text('佐藤 健'), findsWidgets);
        expect(find.text('鈴木 葵'), findsWidgets);
      },
    );

    testWidgets('Issue #147: the Office Stage is the only employee-roster '
        'presentation on HOME at $label — no duplicate full-size roster '
        'section exists any more', (tester) async {
      await pumpDemoAt(tester, size);

      expect(find.byKey(const Key('home-office-stage')), findsOneWidget);
      // The deleted duplicate list used this key; it must not exist in
      // any form, under any name, on the rebuilt screen.
      expect(find.byKey(const Key('public-demo-employee-stage')), findsNothing);
    });
  }

  testWidgets(
    'Issue #124/#147: gameplay is untouched — the Recommended Action CTA '
    'still dispatches the same domain command after the rebuild',
    (tester) async {
      await pumpDemoAt(tester, const Size(390, 844));

      final workflowBefore =
          (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
              .workflow;
      final stageBefore = workflowBefore.engineers.first.stage;

      await tester.tap(find.byKey(const Key('home-recommended-action-cta')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
      await tester.pumpAndSettle();

      final workflowAfter =
          (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
              .workflow;
      expect(workflowAfter.engineers.first.stage, isNot(stageBefore));
    },
  );

  group('HOME-COMPACT-1B.4 FIX1: actual cash shortage', () {
    for (final size in _sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets(
        'month, KPI, the shortage-response lead, the monthly CTA, and 社員概要 '
        'are all painted in the unscrolled initial viewport during an actual '
        'cash shortage at $label',
        (tester) async {
          await pumpDemoAt(tester, size);
          await _driveToActualCashShortage(tester);

          final state =
              (tester.state(find.byType(PublicDemo01PlaceholderScreen))
                      as dynamic)
                  .s;
          expect(
            state.financialStatus,
            PublicDemoFinancialStatus.cashShortage,
            reason:
                'the driven trajectory must actually reach an actual '
                '(not merely preventive) shortage',
          );
          expect(
            state.isCloseBlocked,
            isFalse,
            reason: 'still mid-game, not the terminal March close',
          );

          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .pixels,
            0,
            reason: 'the assertions below must describe the unscrolled screen',
          );

          final viewport = tester.getRect(find.byType(ListView));
          void expectInFirstView(Finder finder, String fact) {
            expect(finder, findsOneWidget, reason: 'missing: $fact');
            final rect = tester.getRect(finder);
            expect(
              rect.top,
              greaterThanOrEqualTo(viewport.top),
              reason: '$fact starts above the viewport',
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(viewport.bottom),
              reason: '$fact is not painted inside the raw viewport',
            );
          }

          // 1: the existing strong lead — unchanged priority, only its own
          // display density is compacted.
          expectInFirstView(
            find.byKey(const Key('public-demo-cash-shortage-card')),
            '資金不足の既存優先導線 (the pre-existing strong lead)',
          );

          // 2: what month is it.
          expectInFirstView(find.text('1年目 3月'), '月 (month)');

          // 3: the priority lead's own CTA — the shortage-response action,
          // not a fabricated second one.
          expectInFirstView(
            find.byKey(const Key('home-recommended-action-cta')),
            '資金不足を確認 CTA (the shortage-response action)',
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('home-recommended-action-cta')),
              matching: find.text('資金不足を確認'),
            ),
            findsOneWidget,
          );

          // 4: the monthly progression CTA — still exactly one on screen.
          expectInFirstView(
            find.byKey(const Key('public-demo-monthly-primary-cta')),
            '月次進行CTA (monthly close CTA)',
          );
          expect(
            find.byKey(const Key('public-demo-monthly-primary-cta')),
            findsOneWidget,
            reason: '月次CTAは画面内に1つだけ',
          );

          // 5: 社員概要 — the fact this fix restores to the initial view for
          // this state specifically.
          expectInFirstView(
            find.byKey(const Key('home-office-stage')),
            '社員概要 (employee overview)',
          );
          expectInFirstView(
            find.byKey(const Key('home-office-stage-headcount-summary')),
            '社員概要の人数・待機状況',
          );

          // No new/duplicate CTA: the Navigator's secondary route is
          // deliberately dropped for this one state (see
          // PublicDemo01PlaceholderScreen._isActualCashShortage), never
          // replaced by a second primary-looking control.
          expect(
            find.byKey(const Key('home-navigator-secondary-cta')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

/// Drives the real screen from April to an actual (not merely preventive)
/// cash shortage — month 15 (3月), `financialStatus == cashShortage`,
/// `isCloseBlocked == false` — mirroring the same real trajectory
/// public_demo_01_bankruptcy_ux_test.dart's `_driveToNovemberBankruptcy`
/// pins, stopped one close earlier (right after February's close, before
/// the March fiscal-year close that would commit bankruptcy).
Future<void> _driveToActualCashShortage(WidgetTester tester) async {
  Finder actionButton(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(String text) async {
    final finder = actionButton(text);
    for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(finder, findsWidgets, reason: 'Could not find action button: $text');
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await settle();
    if (text == 'SkillSheet確認') {
      await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> dismiss() async {
    await tester.tap(find.widgetWithText(FilledButton, '確認'));
    await tester.pumpAndSettle();
  }

  // April: advance Sato to receive the May order. The employee
  // sales-progression card is on 社員 now (PUBLIC-DEMO-HOME-UI-3B).
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
  await tapAndSettle('SkillSheet確認');
  await tapAndSettle('営業開始');
  await tapAndSettle('案件紹介');
  await tapAndSettle('上位会社面談');
  await dismiss();
  await tapAndSettle('客先面談');
  await dismiss();
  await tapAndSettle('受注');
  await dismiss();
  // The month-close CTA is HOME's own monthly primary action.
  await switchPublicDemoTab(tester, PublicDemoTab.home);
  await tapAndSettle('4月を終了して5月へ');
  await dismiss();

  // May: no additional hiring.
  await tapAndSettle('5月を終了して6月へ');

  // June: accept July continuation for Sato (only assignment) — the
  // assignment (project continuation) pipeline is on 営業.
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
  await tapAndSettle('7月分の発注を確認');
  await tapAndSettle('受注する');
  await switchPublicDemoTab(tester, PublicDemoTab.home);
  await tapAndSettle('6月を終了して7月へ');

  // July: choose no bonus.
  await tapAndSettle('7月を終了して8月へ');
  await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
  await tester.pumpAndSettle();
  await tapAndSettle('7月を終了して8月へ');

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
    await tapAndSettle(label);
  }
}
