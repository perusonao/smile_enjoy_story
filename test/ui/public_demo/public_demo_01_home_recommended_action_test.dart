// HOME-RUNTIME-2C: the Recommended Action, against the real runtime screen.
//
// The pure ranking is proven in
// `test/presentation/home/home_recommended_action_test.dart`. What is left
// — and what actually protects the player — is the owner's half of the
// contract, which only the real screen can demonstrate:
//
//   1. action selection      — HOME shows the one action, not a list
//   2. priority              — the ranking holds on real trajectories
//   3. month gate            — nothing is recommended in a month whose UI
//                              does not render it (the 求人媒体 trap)
//   4. owner eligibility     — a candidate exists iff its button does, and
//                              is enabled iff its button is
//   5. dispatch             — the CTA and the legacy button leave the
//                              authoritative state in the same place
//   6. terminal precedence   — shortage outranks everything; bankruptcy,
//                              March failure and fiscal success suppress
//   7. no eligible action    — the month-goal fallback
//   8. first-view regression — the CTA is where the player can see it
//
// Everything drives the REAL screen and therefore the real
// PublicDemoAggregate trajectory behind it. The terminal cases that this UI
// trajectory cannot reach in a reasonable number of taps go through the
// same real domain (`PublicDemoMonthlyClose`) the screen itself uses, as
// the existing Public Demo suites already do.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_recommended_action.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';

import 'public_demo_project_interview_test_helpers.dart';
import 'public_demo_tab_test_helpers.dart';

PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

PublicDemoWorkflowState currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

Finder get sectionFinder => find.byType(PublicDemoHomeDashboardSection);

/// The slot the owner resolved for the build currently on screen.
HomeRecommendedActionSlot slot(WidgetTester tester) => tester
    .widget<PublicDemoHomeDashboardSection>(sectionFinder)
    .recommendedAction;

/// The action currently recommended, or `null` when the slot is a fallback
/// or suppressed.
HomeRecommendedAction? recommended(WidgetTester tester) {
  final s = slot(tester);
  return s is HomeRecommendedActionAvailable ? s.candidate.action : null;
}

Finder get ctaFinder => find.byKey(const Key('home-recommended-action-cta'));

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
  // CORE-GAMEPLAY Phase 4.5: dismiss whichever SkillSheet sheet a tap may
  // have opened — the employee-side sheet (confirm: '内容を確認') or the
  // candidate-side sheet (close: '閉じる').
  final confirmSkillSheet = find.widgetWithText(FilledButton, '内容を確認');
  if (confirmSkillSheet.evaluate().isNotEmpty) {
    await tester.tap(confirmSkillSheet);
    await tester.pumpAndSettle();
  }
  final closeCandidateSkillSheet = find.widgetWithText(OutlinedButton, '閉じる');
  if (closeCandidateSkillSheet.evaluate().isNotEmpty) {
    await tester.tap(closeCandidateSkillSheet);
    await tester.pumpAndSettle();
  }
  // Issue #119: a month-close tap may now surface the Month Guard's
  // `recommended`-level warning (e.g. an economically-waiting engineer's
  // Recovery step is still outstanding). This suite is not exercising that
  // warning itself, so proceed through it exactly as a player choosing
  // "このまま月末処理を進める" would, preserving every trajectory below.
  final monthGuardProceed = find.byKey(
    const Key('public-demo-month-guard-proceed'),
  );
  if (monthGuardProceed.evaluate().isNotEmpty) {
    await tester.tap(monthGuardProceed);
    // Issue #168: proceeding here resumes the month-close handler
    // (`april()`'s own event dialog, in particular) past the point this
    // clause used to assume was already reached — that handler's own
    // `_precacheEventImage` needs the same real-time wait window `settle`
    // already gives every other tap, not a single fake-clock
    // `pumpAndSettle()`, or its dialog never actually appears.
    await settle(tester);
  }
  // SES ISSUE-232 Phase B: a close path with no further event dialog
  // (June/July/closeOrdinaryMonth) can already show the Monthly Management
  // Report here — a no-op otherwise.
  await dismissMonthlyReportIfPresent(tester);
}

Future<void> tapCta(WidgetTester tester) async {
  await tester.ensureVisible(ctaFinder);
  await tester.pumpAndSettle();
  await tester.tap(ctaFinder);
  await settle(tester);
  final confirm = find.widgetWithText(FilledButton, '内容を確認');
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }
  final closeCandidateSkillSheet = find.widgetWithText(OutlinedButton, '閉じる');
  if (closeCandidateSkillSheet.evaluate().isNotEmpty) {
    await tester.tap(closeCandidateSkillSheet);
    await tester.pumpAndSettle();
  }
  // SES ISSUE-232 Phase B: a no-op unless this exact CTA tap was a month
  // close with nothing further pending.
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

/// Pumps a genuinely fresh Public Demo screen.
///
/// The [UniqueKey] is load-bearing: pumping the same const widget twice in
/// one test reuses the existing element, and with it the [State] that owns
/// `_game` — so a second `pumpDemo` would silently continue the first
/// run's trajectory instead of starting a new one. The dispatch-equivalence
/// test below depends on two independent runs, so this makes "fresh" mean
/// fresh.
Future<void> pumpDemo(WidgetTester tester, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(key: UniqueKey(), debugSeed: 9),
    ),
  );
  await tester.pumpAndSettle();
}

/// April: the first engineer wins the May order — the shared opening the
/// existing Public Demo suites use, reused here so HOME is observed on a
/// real trajectory rather than a synthesized one.
Future<void> playApril(WidgetTester tester) async {
  // The employee sales-progression card is on 社員 now
  // (PUBLIC-DEMO-HOME-UI-3B); switch back to HOME before returning so
  // callers can keep reading the Recommended Action slot (a HOME-only
  // section) without having to know this detail themselves.
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
  await tapAndSettle(tester, 'スキルシート確認');
  await tapAndSettle(tester, '営業開始');
  await tapAndSettle(tester, '案件紹介');
  await tapAndSettle(tester, '上位会社面談');
  await dismiss(tester);
  await tapAndSettle(tester, '客先面談');
  await dismissClientInterview(tester);
  await tapAndSettle(tester, '受注');
  await dismiss(tester);
  await switchPublicDemoTab(tester, PublicDemoTab.home);
}

/// Advances to July on the no-hire route, where the applicant pipeline is
/// not rendered.
Future<void> playIntoJuly(WidgetTester tester) async {
  await tapAndSettle(tester, '4月を終了して5月へ');
  await dismiss(tester);
  await tapAndSettle(tester, '5月を終了して6月へ');
  await settle(tester);
  await tapAndSettle(tester, '6月を終了して7月へ');
  await settle(tester);
}

/// Drives the structurally-insolvent trajectory the existing suites pin —
/// CASH SHORTAGE closing October — using nothing but the real screen and
/// the real domain commands behind it. `PublicDemoAggregate` deliberately
/// exposes no reconstruction shortcut ("test fixtures needing a specific
/// intermediate aggregate state build it by chaining these same real
/// commands from initial"), and this suite honours that rather than
/// reaching past it.
Future<void> playIntoCashShortage(WidgetTester tester) async {
  await playApril(tester);
  await tapAndSettle(tester, '4月を終了して5月へ');
  await dismiss(tester);
  await tapAndSettle(tester, '5月を終了して6月へ');
  await settle(tester);
  await tapAndSettle(tester, '6月を終了して7月へ');
  await settle(tester);
  await tapAndSettle(tester, '7月を終了して8月へ');
  await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
  await tester.pumpAndSettle();
  await tapAndSettle(tester, '7月を終了して8月へ');
  await settle(tester);
  await tapAndSettle(tester, '8月を終了して翌月へ');
  await settle(tester);
  await tapAndSettle(tester, '9月を終了して翌月へ');
  await settle(tester);
  await tapAndSettle(tester, '10月を終了して翌月へ');
  await settle(tester);
}

void main() {
  // =====================================================================
  // 1 + 2: action selection and priority on a real trajectory
  // =====================================================================
  group('1-2: HOME states exactly one action, and it is the ranked one', () {
    testWidgets('April opens on the first engineer\'s SkillSheet review', (
      tester,
    ) async {
      await pumpDemo(tester);

      final action = recommended(tester);
      expect(action, isNotNull);
      expect(action!.kind, HomeRecommendedActionKind.employeeSkillSheetReview);
      expect(action.targetId, currentWorkflow(tester).engineers.first.id);
      expect(action.subjectName, currentWorkflow(tester).engineers.first.name);

      // Exactly one action is offered — HOME is not a task list.
      expect(ctaFinder, findsOneWidget);
      expect(
        find.byKey(const Key('home-recommended-action-headline')),
        findsOneWidget,
      );
      expect(find.text('次にやること'), findsOneWidget);
      expect(find.text('佐藤 健のスキルシートを確認'), findsOneWidget);
    });

    testWidgets('an already-started pipeline outranks an untouched engineer', (
      tester,
    ) async {
      await pumpDemo(tester);
      final engineers = currentWorkflow(tester).engineers;
      expect(
        engineers.length,
        greaterThan(1),
        reason: 'this test needs a second, untouched engineer to lose to',
      );
      final first = engineers.first.id;

      // Advance ONLY the first engineer, one stage at a time. At every
      // step the recommendation must stay on them — the second engineer is
      // still sitting at `waiting`, which ranks below every later stage.
      const expected = <HomeRecommendedActionKind>[
        HomeRecommendedActionKind.employeeBeginSelling,
        HomeRecommendedActionKind.employeeIntroduceProject,
        HomeRecommendedActionKind.employeePartnerInterview,
      ];
      const taps = ['スキルシート確認', '営業開始', '案件紹介'];

      // The employee sales-progression card is on 社員 now
      // (PUBLIC-DEMO-HOME-UI-3B); the Recommended Action slot it feeds is
      // read back on HOME after each tap.
      for (var i = 0; i < taps.length; i++) {
        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        await tapAndSettle(tester, taps[i]);
        await switchPublicDemoTab(tester, PublicDemoTab.home);
        final action = recommended(tester);
        expect(action!.kind, expected[i]);
        expect(
          action.targetId,
          first,
          reason: 'the started pipeline must keep the slot',
        );
      }
    });

    testWidgets('an engineer with no button left stops holding the slot', (
      tester,
    ) async {
      await pumpDemo(tester);
      final first = currentWorkflow(tester).engineers.first.id;

      // The employee sales-progression card is on 社員 now.
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      await tapAndSettle(tester, 'スキルシート確認');
      await tapAndSettle(tester, '営業開始');
      await tapAndSettle(tester, '案件紹介');
      await tapAndSettle(tester, '上位会社面談');
      await dismiss(tester);
      if (actionButton('客先面談').evaluate().isNotEmpty) {
        await tapAndSettle(tester, '客先面談');
        await dismissClientInterview(tester);
      }
      if (actionButton('受注').evaluate().isNotEmpty) {
        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(
          recommended(tester)!.kind,
          HomeRecommendedActionKind.employeeAcceptOrder,
        );
        expect(recommended(tester)!.targetId, first);
        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        await tapAndSettle(tester, '受注');
        await dismiss(tester);

        // `ordered` renders no button on the card, so the engineer is no
        // longer a candidate at all. April's other founding engineer is not
        // field-sales ready (`readyForFieldSales` is false), so its card
        // renders no button either — the engineer genuinely stops holding
        // the slot, and nothing else picks it up: CORE-GAMEPLAY Phase 4.5's
        // merge-blocker fix widened 求人媒体 to May-August
        // (`_S._recruitmentMediaCardVisible`), deliberately still excluding
        // April so this exact HOME view keeps the layout budget SES HOME
        // One-Screen Final Fit already locked in (no Recommended Action
        // card at all in April) — see that getter's own doc. So this really
        // is "none of the above" in April, same as before the fix: the slot
        // falls back to the month goal text, not a recommendation.
        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.ordered,
        );
        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(
          recommended(tester),
          isNull,
          reason: 'April has no eligible candidate left; falls back to the '
              'month goal text',
        );
      }
    });

    testWidgets('an engineer who is not field-sales ready is never '
        'recommended, even while sitting at the top-ranked stage', (
      tester,
    ) async {
      await pumpDemo(tester);
      final screen =
          tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic;
      final engineers = currentWorkflow(tester).engineers;

      // Both founding engineers are at `waiting`, the stage whose
      // SkillSheet action is April's top pick...
      for (final e in engineers) {
        expect(e.stage, PublicDemoSalesStage.waiting);
      }
      // ...but only the ready one has a button, and only the ready one is
      // recommended. This is the eligibility half of the contract: the
      // stage alone never makes an action available.
      // ignore: avoid_dynamic_calls
      final ready = engineers
          .where((e) => screen.readyForFieldSales(e.id) as bool)
          .toList();
      // ignore: avoid_dynamic_calls
      final notReady = engineers
          .where((e) => !(screen.readyForFieldSales(e.id) as bool))
          .toList();
      expect(ready, isNotEmpty);
      expect(notReady, isNotEmpty);

      expect(recommended(tester)!.targetId, ready.first.id);
      for (final e in notReady) {
        expect(recommended(tester)!.targetId, isNot(e.id));
      }
      // The screen agrees: exactly one スキルシート確認 button exists — on
      // 社員, its own tab now.
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(actionButton('スキルシート確認'), findsOneWidget);
    });
  });

  // =====================================================================
  // 3: month gate — the reason HOME may not own eligibility
  // =====================================================================
  group('3: month gates are respected, not reconstructed from predicates', () {
    testWidgets('求人媒体 is never recommended in April, even though the '
        'domain predicate that gates it is satisfied', (tester) async {
      await pumpDemo(tester);

      // The standing trap: the predicate says yes...
      final state = currentState(tester);
      expect(state.month, 4);
      expect(state.canUseRecruitmentMediaInMonth(state.month), isTrue);
      // ...but April renders no 求人媒体 card at all.
      expect(
        find.byKey(const Key('public-demo-recruitment-media-card')),
        findsNothing,
      );
      // ...so it must not be recommended, at any rank.
      expect(
        recommended(tester)!.kind,
        isNot(HomeRecommendedActionKind.recruitmentMedia),
      );
    });

    testWidgets('求人媒体 becomes recommendable in May, where its card exists', (
      tester,
    ) async {
      await pumpDemo(tester);
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismiss(tester);
      expect(currentState(tester).month, 5);

      // The recruiting/applicant pipeline is on 営業 now
      // (PUBLIC-DEMO-HOME-UI-3B).
      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      expect(
        find.byKey(const Key('public-demo-recruitment-media-card')),
        findsOneWidget,
      );
      // CORE-GAMEPLAY Phase 4.5: a new game starts with zero applicants —
      // there is no `applied`-stage candidate to outrank 求人媒体 with
      // anymore until the player actually recruits, so 求人媒体 itself is
      // the top-ranked recommendation the moment its card exists (May). The
      // Recommended Action slot itself is HOME's own.
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      expect(
        recommended(tester)!.kind,
        HomeRecommendedActionKind.recruitmentMedia,
      );
    });

    testWidgets('July DOES expose recruitment media — CORE-GAMEPLAY Phase '
        '4.5\'s merge-blocker fix widened the Sales tab\'s own gate to the '
        'domain\'s real month 4-8 window, retiring the fixed-month trap this '
        'test used to document', (tester) async {
      await pumpDemo(tester);
      await playApril(tester);
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismiss(tester);
      await tapAndSettle(tester, '5月を終了して6月へ');
      await settle(tester);
      // `playIntoJuly` deliberately leaves eng-01's own June order decision
      // undecided (needed elsewhere, e.g. the cash-shortage/Recovery
      // trajectory above), but that same fact makes them genuinely
      // `PublicDemoRecoveryEligibility.isEligible` from July on — see this
      // file's own "6: terminal and financial precedence" group doc for the
      // identical mechanism. Confirming the order here instead keeps this
      // test's July build genuinely candidate-free apart from
      // recruitmentMedia, which is the one fact under test.
      await tapAndSettle(tester, '発注を確認する');
      await tapAndSettle(tester, '発注を受注する');
      await tapAndSettle(tester, '6月を終了して7月へ');
      await settle(tester);
      expect(currentState(tester).month, 7);

      // The UI now exposes the card in July too — checked on 営業, the tab
      // that renders it (PUBLIC-DEMO-HOME-UI-3B) — because the render
      // condition IS `canUseRecruitmentMediaInMonth` now, not a fixed month.
      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      expect(
        find.byKey(const Key('public-demo-recruitment-media-card')),
        findsOneWidget,
      );
      expect(find.text('求人媒体を選ぶ'), findsOneWidget);

      expect(
        currentState(tester).canUseRecruitmentMediaInMonth(7),
        isTrue,
        reason: 'the domain month 4–8 range remains unchanged',
      );

      // No applicant has been recruited on this trajectory yet, so the
      // funnel — gated on `workflow.applicants.isNotEmpty`, not on month —
      // still renders nothing.
      expect(actionButton('スキルシート確認'), findsNothing);
      expect(actionButton('採用面談'), findsNothing);

      // Settle the bonus so nothing else can outrank the media action. The
      // summer bonus decision is finance detail — on 会計 now.
      await switchPublicDemoTab(tester, PublicDemoTab.accounting);
      await tapAndSettle(tester, '夏季賞与を決める');
      final noBonus = find.byKey(const Key('public-demo-summer-bonus-none'));
      expect(tester.widget<FilledButton>(noBonus).onPressed, isNotNull);
      await tester.ensureVisible(noBonus);
      await tester.tap(noBonus);
      await tester.pumpAndSettle();
      expect(find.text('選択済み：なし'), findsOneWidget);

      // Recommended Action now DOES suggest recruitment: with eng-01
      // `ordered` (no button) and eng-02 never field-sales-ready, and the
      // summer bonus already decided, 求人媒体 is the only remaining
      // candidate — and, per HOME-RUNTIME-2C's own rule, it is only ever
      // emitted here because the Sales tab genuinely renders its button
      // right now (checked above).
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      expect(
        recommended(tester)!.kind,
        HomeRecommendedActionKind.recruitmentMedia,
      );

      // July's summer-bonus confirmation and ordinary progression are
      // unchanged by widening the recruitment entry point.
      await tapAndSettle(tester, '7月を終了して8月へ');
      expect(currentState(tester).month, 8);
    });

    testWidgets('no candidate ever names a button that is not on screen', (
      tester,
    ) async {
      // Walks the demo month by month and, at every build, checks the
      // recommended action against the screen: whatever HOME offers, the
      // corresponding legacy control must exist in the tree.
      await pumpDemo(tester);

      Future<void> checkCurrentBuild() async {
        final action = recommended(tester);
        if (action == null) return;
        // The CTA is rendered and enabled...
        expect(ctaFinder, findsOneWidget);
        expect(tester.widget<FilledButton>(ctaFinder).onPressed, isNotNull);
        // ...and it is never a month-close, which 2D owns.
        expect(action.headline, isNot(contains('終了→')));
      }

      await checkCurrentBuild();
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismiss(tester);
      await checkCurrentBuild();
      await tapAndSettle(tester, '5月を終了して6月へ');
      await settle(tester);
      await checkCurrentBuild();
      await tapAndSettle(tester, '6月を終了して7月へ');
      await settle(tester);
      await checkCurrentBuild();
    });
  });

  // =====================================================================
  // 4: owner eligibility — enabled iff the button is enabled
  // =====================================================================
  group('4: eligibility comes from the owner, never from HOME', () {
    testWidgets('an exhausted sales slot removes the interview action '
        'instead of offering it disabled', (tester) async {
      await pumpDemo(tester);
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismiss(tester);
      expect(currentState(tester).month, 5);

      // May's 採用面談 is gated on `salesRemaining > 0` and consumes a slot
      // per applicant. Drain the month's capacity with the legacy buttons,
      // topping up the applicant pool from the (free) recruitment medium
      // when the pool runs dry. The recruiting/applicant pipeline is on
      // 営業 now (PUBLIC-DEMO-HOME-UI-3B).
      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      var guard = 0;
      while (currentState(tester).salesRemaining > 0 && guard++ < 25) {
        if (actionButton('スキルシート確認').evaluate().isNotEmpty) {
          await tapAndSettle(tester, 'スキルシート確認');
          continue;
        }
        final interview = actionButton('採用面談');
        if (interview.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(interview.first).onPressed != null) {
          await tapAndSettle(tester, '採用面談');
          continue;
        }
        final media = find.byKey(
          const Key('public-demo-open-recruitment-media'),
        );
        if (media.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(media).onPressed != null) {
          await tester.ensureVisible(media);
          await tester.pumpAndSettle();
          await tester.tap(media);
          await tester.pumpAndSettle();
          // The engineer medium yields two applicants (the free one yields
          // one).
          await tester.tap(
            find.byKey(const Key('public-demo-recruitment-medium-engineer')),
          );
          await settle(tester);
          continue;
        }
        break;
      }

      // CORE-GAMEPLAY Phase 4.5: 求人媒体 can only be used once per month
      // (`recruitmentMediumUsedMonth`), so at most 2 applicants ever exist
      // this May — `salesCapacity` (4) can no longer be driven to exactly 0
      // within a single month through real production actions alone.
      // eng-01's own sales pipeline (`ec(i)`'s `waiting` branch) is not even
      // rendered in May — `_employeeNextActionsSection` only renders it in
      // April or the July-February Recovery window — so it offers no
      // additional slot-consuming route here either. 2 applicant interviews
      // spent, 2 remaining, is the genuine floor. What actually matters is
      // checked below regardless of the exact remaining count: no applicant
      // is left eligible for 採用面談, so neither the legacy button nor
      // HOME's own recommendation can offer it.
      expect(currentState(tester).salesRemaining, 2);
      expect(
        actionButton('採用面談'),
        findsNothing,
        reason: 'no applicant remains at resumeReviewed to interview',
      );
      // ...and HOME does not offer it. Whatever it offers instead — if
      // anything — is enabled. A disabled CTA is never acceptable. The
      // Recommended Action slot itself is HOME's own.
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      final action = recommended(tester);
      if (action != null) {
        expect(
          action.kind,
          isNot(HomeRecommendedActionKind.applicantInterview),
        );
        expect(
          action.kind,
          isNot(HomeRecommendedActionKind.applicantPartnerInterview),
        );
        expect(tester.widget<FilledButton>(ctaFinder).onPressed, isNotNull);
      }
    });

    testWidgets('the CTA is enabled on every build that offers one, across '
        'a real April-to-July trajectory', (tester) async {
      await pumpDemo(tester);

      void checkBuild() {
        if (ctaFinder.evaluate().isEmpty) return;
        expect(
          tester.widget<FilledButton>(ctaFinder).onPressed,
          isNotNull,
          reason: 'HOME must never present a disabled recommendation',
        );
        // And an offered action always has a rendered CTA to press.
        expect(recommended(tester), isNotNull);
      }

      checkBuild();
      // The employee sales-progression card is on 社員 now; checkBuild
      // reads HOME's own Recommended Action slot, so switch back after
      // each tap.
      for (final tap in ['スキルシート確認', '営業開始', '案件紹介']) {
        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        await tapAndSettle(tester, tap);
        await switchPublicDemoTab(tester, PublicDemoTab.home);
        checkBuild();
      }
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismiss(tester);
      checkBuild();
      await tapAndSettle(tester, '5月を終了して6月へ');
      await settle(tester);
      checkBuild();
      await tapAndSettle(tester, '6月を終了して7月へ');
      await settle(tester);
      checkBuild();
    });
  });

  // =====================================================================
  // 5: dispatch — the CTA and the legacy button are the same command
  // =====================================================================
  group('5: the CTA dispatches to the owner handler, identically', () {
    testWidgets('tapping the CTA leaves the authoritative state exactly '
        'where tapping the legacy button leaves it', (tester) async {
      // Control run: drive April's first two stages with the legacy
      // buttons and record the authoritative outcome. The employee
      // sales-progression card is on 社員 now.
      await pumpDemo(tester);
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      await tapAndSettle(tester, 'スキルシート確認');
      await tapAndSettle(tester, '営業開始');
      final controlState = currentState(tester);
      final controlStages = currentWorkflow(
        tester,
      ).engineers.map((e) => '${e.id}:${e.stage.name}').toList();
      final controlCash = controlState.cash;
      final controlSales = controlState.salesRemaining;

      // Experiment run: a fresh screen, same two stages, driven only from
      // the HOME CTA.
      await pumpDemo(tester);
      expect(
        recommended(tester)!.kind,
        HomeRecommendedActionKind.employeeSkillSheetReview,
      );
      await tapCta(tester);
      expect(
        recommended(tester)!.kind,
        HomeRecommendedActionKind.employeeBeginSelling,
      );
      await tapCta(tester);

      final viaCta = currentState(tester);
      expect(
        currentWorkflow(
          tester,
        ).engineers.map((e) => '${e.id}:${e.stage.name}').toList(),
        controlStages,
        reason: 'the CTA must run the same commands, in the same order',
      );
      expect(viaCta.cash, controlCash);
      expect(viaCta.salesRemaining, controlSales);
      expect(viaCta.month, controlState.month);
    });

    testWidgets('a CTA that opens a dialog opens the same dialog', (
      tester,
    ) async {
      await pumpDemo(tester);
      await tapCta(tester); // SkillSheet
      await tapCta(tester); // 営業開始
      await tapCta(tester); // 案件紹介
      expect(
        recommended(tester)!.kind,
        HomeRecommendedActionKind.employeePartnerInterview,
      );

      await tapCta(tester);
      // The same interview-result dialog the legacy button opens — the
      // dialog titles itself '<interview> 結果'.
      expect(find.text('上位会社面談 結果'), findsOneWidget);
      await dismiss(tester);
      expect(
        currentWorkflow(tester).engineers.first.stage,
        anyOf(
          PublicDemoSalesStage.partnerInterviewPassed,
          PublicDemoSalesStage.partnerInterviewFailed,
        ),
      );
    });

    testWidgets('the domain guard still runs even though the CTA ran', (
      tester,
    ) async {
      // Slot consumption is enforced inside the aggregate, not by the CTA
      // being present: driving the interview from HOME consumes exactly one
      // sales slot, the same as the legacy button.
      await pumpDemo(tester);
      await tapCta(tester);
      await tapCta(tester);
      await tapCta(tester);
      final before = currentState(tester).salesRemaining;
      await tapCta(tester);
      await dismiss(tester);
      expect(currentState(tester).salesRemaining, before - 1);
    });
  });

  // =====================================================================
  // 6: terminal / finance precedence
  // =====================================================================
  group('6: terminal and financial precedence stay with the authority', () {
    // Issue #119 PLAYTHROUGH-BLOCKER-2: `playIntoCashShortage` never taps
    // eng-01's June "次月発注" decision (`_addRaiseCandidate`'s sibling
    // assignment flow), so `assignedEngineerIds(month >= 7)` genuinely
    // never counts them assigned from July on — the same fact that makes
    // them genuinely `PublicDemoRecoveryEligibility.isEligible` throughout
    // this trajectory's August-October closes (verified independently at
    // the domain level in
    // `test/game/public_demo/public_demo_month_guard_test.dart`). Deciding
    // that order here instead (as `public_demo_01_bankruptcy_ux_test.dart`'s
    // own cash-shortage trajectory does) would let eng-01 keep billing
    // revenue and never reach cash shortage by October at all — this
    // trajectory's cash-shortage timing is calibrated on the gap, not
    // incidental to it. So this is exactly the truthful state Issue #119
    // exists to surface: a real, reachable, mutating Recovery step is
    // outstanding, and it must not stay permanently hidden behind the
    // purely-informational shortage card — see `recoveryAssignment`'s own
    // doc in `home_recommended_action.dart`.
    testWidgets(
      'a genuine Recovery action outranks the cash-shortage info card, and '
      'both stay reachable',
      (tester) async {
        await pumpDemo(tester);
        await playIntoCashShortage(tester);

        expect(
          currentState(tester).financialStatus,
          PublicDemoFinancialStatus.cashShortage,
        );
        // The informational card still owns its own authority, above HOME...
        expect(
          find.byKey(const Key('public-demo-cash-shortage-card')),
          findsOneWidget,
        );
        // ...but the recommendation points at the real, mutating action a
        // player can take, not the card that merely explains the situation.
        expect(
          recommended(tester)!.kind,
          HomeRecommendedActionKind.recoveryAssignment,
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('home-recommended-action-headline')),
              )
              .data,
          contains('を案件へ復帰させる'),
        );
        // The plain "資金不足を確認" recommendation text must NOT be what is
        // offered here — the whole point is that it no longer permanently
        // covers the real action.
        expect(find.text('資金不足の対応を確認'), findsNothing);
        // §13's Failure-Recovery rule: not a dead end. The KPI and the
        // month-close CTA are both still there.
        expect(find.byKey(const Key('home-kpi-compact')), findsOneWidget);
        expect(actionButton('11月を終了して翌月へ'), findsWidgets);
      },
    );

    testWidgets(
      'the reachable Recovery CTA performs the real recovery, while the '
      'cash-shortage card stays purely informational beside it',
      (tester) async {
        await pumpDemo(tester);
        await playIntoCashShortage(tester);

        final before = currentState(tester);
        final beforeWaiting = before.engineersWaiting;
        final beforeAssigned = before.engineersAssigned;
        await tapCta(tester);

        final after = currentState(tester);
        // The Recovery command only ever moves one engineer from waiting to
        // assigned (`PublicDemoAggregate.recoverAssignment`'s own contract)
        // — it does not touch Finance, month, or sales-slot state.
        expect(after.engineersWaiting, beforeWaiting - 1);
        expect(after.engineersAssigned, beforeAssigned + 1);
        expect(after.cash, before.cash);
        expect(after.month, before.month);
        expect(after.financialStatus, before.financialStatus);
        expect(after.salesRemaining, before.salesRemaining);
        expect(after.pendingRevenue, before.pendingRevenue);
        // Recovering the engineer removes them from the recommended-action
        // slot's own outstanding-work set: the CTA no longer offers the
        // same Recovery step a second time.
        expect(
          recommended(tester)?.kind,
          isNot(HomeRecommendedActionKind.recoveryAssignment),
        );
      },
    );

    testWidgets('bankruptcy suppresses the slot entirely — there is no next '
        'action, and no consolation month goal either', (tester) async {
      await pumpDemo(tester);
      await playIntoCashShortage(tester);
      await tapAndSettle(tester, '11月を終了して翌月へ');
      await settle(tester);

      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );
      expect(currentState(tester).isCloseBlocked, isTrue);

      expect(slot(tester), isA<HomeRecommendedActionSuppressed>());
      expect(recommended(tester), isNull);
      expect(ctaFinder, findsNothing);
      expect(find.text('今月やること'), findsNothing);
      expect(find.text('次にやること'), findsNothing);

      // Read-only content survives, per POST-12MONTH-1 /
      // FINANCE-FAILURE-1A+1B: the KPI and the employees are still there.
      expect(find.byKey(const Key('home-kpi-compact')), findsOneWidget);
      expect(find.text('佐藤 健'), findsWidgets);
    });

    testWidgets('HOME still cannot see a financial verdict: the suppressed '
        'slot names an outcome, never its reason', (tester) async {
      await pumpDemo(tester);
      await playIntoCashShortage(tester);
      await tapAndSettle(tester, '11月を終了して翌月へ');
      await settle(tester);
      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );

      // The slot type carries no status, and the projection alongside it
      // still has no field a financial verdict could ride in on.
      expect(slot(tester), isA<HomeRecommendedActionSuppressed>());
      final data = tester
          .widget<PublicDemoHomeDashboardSection>(sectionFinder)
          .data;
      expect(data.toString(), isNot(contains('bankruptcy')));
      expect(
        const HomeRecommendedActionSuppressed().toString(),
        isNot(contains('bankruptcy')),
      );
    });

    test('every terminal status the design names resolves to the same '
        'suppression key the screen switches on', () {
      // The screen suppresses on `isCloseBlocked`. TERMINAL PLAN names
      // three states that must suppress; this pins that all three actually
      // reach that one predicate, including the two the UI trajectory
      // above cannot reach in a reasonable number of taps.
      final bankruptcy = PublicDemoState.aprilStart().copyWith(
        financialStatus: PublicDemoFinancialStatus.bankruptcy,
      );
      final marchFailure = PublicDemoState.aprilStart().copyWith(
        financialStatus: PublicDemoFinancialStatus.marchCashShortageFailure,
      );
      final fiscalSuccess = PublicDemoState.aprilStart().copyWith(
        fiscalYearCompleted: true,
      );
      for (final state in [bankruptcy, marchFailure, fiscalSuccess]) {
        expect(state.isCloseBlocked, isTrue);
      }

      // ...and a cash shortage does NOT suppress: it is a live state with a
      // real next action, which is the whole point of the P0 row.
      final shortage = PublicDemoState.aprilStart().copyWith(
        financialStatus: PublicDemoFinancialStatus.cashShortage,
      );
      expect(shortage.isCloseBlocked, isFalse);

      // The March failure really is produced by the real close rule, and is
      // distinct from bankruptcy.
      expect(
        PublicDemoFinancialStatus.afterClose(
          previous: PublicDemoFinancialStatus.normal,
          isMarch: true,
          closingCash: -1,
        ),
        PublicDemoFinancialStatus.marchCashShortageFailure,
      );
      expect(
        PublicDemoFinancialStatus.afterClose(
          previous: PublicDemoFinancialStatus.cashShortage,
          isMarch: false,
          closingCash: -1,
        ),
        PublicDemoFinancialStatus.bankruptcy,
      );
      expect(PublicDemoMonthlyClose, isNotNull);
    });
  });

  // =====================================================================
  // 7: no eligible action
  // =====================================================================
  group('7: with nothing eligible the slot states the month goal', () {
    testWidgets('June on the no-hire route recommends recruitment media, '
        'not a fallback — CORE-GAMEPLAY Phase 4.5\'s merge-blocker fix means '
        'an unused recruiting window is always a real "nothing eligible" '
        'escape hatch now', (tester) async {
      await pumpDemo(tester);
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismiss(tester);
      await tapAndSettle(tester, '5月を終了して6月へ');
      await settle(tester);

      expect(currentState(tester).month, 6);
      // Neither founding engineer holds the slot on the no-hire route
      // (eng-01 untouched and out of `ec(i)`'s April/July-February render
      // window; eng-02 never field-sales-ready) — but June is still inside
      // the domain's recruiting window and it has not been used yet, so
      // 求人媒体 is recommended instead of the true "nothing eligible"
      // fallback this test used to document.
      expect(
        currentState(tester).canUseRecruitmentMediaInMonth(6),
        isTrue,
      );
      expect(
        recommended(tester)!.kind,
        HomeRecommendedActionKind.recruitmentMedia,
      );
      expect(ctaFinder, findsOneWidget);
    });

    testWidgets('June on the no-hire route: using up the recruiting window '
        'surfaces the newly-recruited applicant as the next recommendation '
        '— recruiting is never a true dead end, it always leaves a real '
        'candidate behind for the slot to pick up next', (tester) async {
      await pumpDemo(tester);
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismiss(tester);
      await tapAndSettle(tester, '5月を終了して6月へ');
      await settle(tester);
      expect(currentState(tester).month, 6);

      // Use up June's own recruiting window via the real production
      // command (never a reconstructed state). The free medium is picked
      // by its own unique key: the sheet's "この方法で募集する" button text
      // repeats once per medium option.
      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      await tapAndSettle(tester, '求人媒体を選ぶ');
      await tester.tap(
        find.byKey(const Key('public-demo-recruitment-medium-free')),
      );
      await settle(tester);
      await switchPublicDemoTab(tester, PublicDemoTab.home);

      expect(currentState(tester).canUseRecruitmentMediaInMonth(6), isFalse);
      // Recruiting always generates at least one applicant
      // (`medium.applicantCount`), so the slot now recommends reviewing
      // them — this is not the true "nothing eligible" fallback case this
      // group's own first test above already covers.
      expect(currentWorkflow(tester).applicants, isNotEmpty);
      expect(
        recommended(tester)!.kind,
        HomeRecommendedActionKind.applicantReviewResume,
      );
      expect(ctaFinder, findsOneWidget);
    });
  });

  // =====================================================================
  // 8: first-view regression
  // =====================================================================
  group('8: the recommendation is visible without scrolling', () {
    for (final (:size, :budget) in <({Size size, double budget})>[
      (size: Size(360, 800), budget: 615),
      (size: Size(390, 844), budget: 660),
    ]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('at $label the headline and CTA are both in the first '
          'view, and the CTA works from there', (tester) async {
        await pumpDemo(tester, size: size);

        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          0,
        );

        final viewport = tester.getRect(find.byType(ListView));
        final headline = tester.getRect(
          find.byKey(const Key('home-recommended-action-headline')),
        );
        final cta = tester.getRect(ctaFinder);

        expect(headline.top, greaterThanOrEqualTo(viewport.top));
        expect(cta.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(
          cta.bottom - viewport.top,
          lessThanOrEqualTo(budget),
          reason:
              'the CTA ends ${cta.bottom - viewport.top}pt below the AppBar, '
              'past the ${budget}pt browser-chrome budget at $label',
        );
        expect(cta.left, greaterThanOrEqualTo(0.0));
        expect(cta.right, lessThanOrEqualTo(size.width));

        // Usable exactly where it sits — no scroll, no ensureVisible.
        await tester.tap(ctaFinder);
        await settle(tester);
        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.waiting,
        );
        await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
        await tester.pumpAndSettle();
        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.skillSheet,
        );
      });

      testWidgets('at $label nothing overflows on the 2C slot', (tester) async {
        await pumpDemo(tester, size: size);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  // =====================================================================
  // 9: PUBLIC-DEMO-HOME-UI-3A P2 fix (PR #150 review) — the important-
  // tasks section's 営業/採用 rows must never invite the player into a
  // section with nothing eligible left in it.
  // =====================================================================
  group('9: important-task rows never invite the player into a dead end', () {
    test(
      'homeImportantTaskHasEligibleAction is false for every terminal/'
      'completed state the design names, regardless of the candidate list',
      () {
        // Same three states public_demo_01_home_recommended_action_test's
        // own group 6 already pins as isCloseBlocked — reused here rather
        // than re-derived, so this test and that one cannot silently
        // disagree about which states are terminal/completed.
        final bankruptcy = PublicDemoState.aprilStart().copyWith(
          financialStatus: PublicDemoFinancialStatus.bankruptcy,
        );
        final marchFailure = PublicDemoState.aprilStart().copyWith(
          financialStatus: PublicDemoFinancialStatus.marchCashShortageFailure,
        );
        final fiscalSuccess = PublicDemoState.aprilStart().copyWith(
          fiscalYearCompleted: true,
        );
        final eligibleCandidate = [
          HomeRecommendedActionCandidate(
            action: const HomeRecommendedAction(
              kind: HomeRecommendedActionKind.employeeAcceptOrder,
            ),
            invoke: () {},
          ),
        ];
        for (final state in [bankruptcy, marchFailure, fiscalSuccess]) {
          expect(state.isCloseBlocked, isTrue);
          expect(
            homeImportantTaskHasEligibleAction(state, eligibleCandidate, {
              HomeRecommendedActionKind.employeeAcceptOrder,
            }),
            isFalse,
            reason:
                '${state.financialStatus}/'
                'fiscalYearCompleted=${state.fiscalYearCompleted} must '
                'suppress the row even though an eligible candidate '
                'exists',
          );
        }
      },
    );

    test('homeImportantTaskHasEligibleAction is false once the requested '
        'category is exhausted — no matching candidate, or none at all', () {
      final notBlocked = PublicDemoState.aprilStart();
      expect(notBlocked.isCloseBlocked, isFalse);
      final unrelatedCandidate = [
        HomeRecommendedActionCandidate(
          action: const HomeRecommendedAction(
            kind: HomeRecommendedActionKind.raiseRequest,
          ),
          invoke: () {},
        ),
      ];
      expect(
        homeImportantTaskHasEligibleAction(notBlocked, unrelatedCandidate, {
          HomeRecommendedActionKind.employeeAcceptOrder,
        }),
        isFalse,
      );
      expect(
        homeImportantTaskHasEligibleAction(
          notBlocked,
          const <HomeRecommendedActionCandidate>[],
          {HomeRecommendedActionKind.employeeAcceptOrder},
        ),
        isFalse,
      );
    });

    test('homeImportantTaskHasEligibleAction is true only once both '
        'conditions hold: not blocked, and a matching candidate exists', () {
      final notBlocked = PublicDemoState.aprilStart();
      final matching = [
        HomeRecommendedActionCandidate(
          action: const HomeRecommendedAction(
            kind: HomeRecommendedActionKind.employeeAcceptOrder,
          ),
          invoke: () {},
        ),
      ];
      expect(
        homeImportantTaskHasEligibleAction(notBlocked, matching, {
          HomeRecommendedActionKind.employeeAcceptOrder,
        }),
        isTrue,
      );
    });

    testWidgets('after bankruptcy, the important-tasks section drops the 営業/採用 '
        'rows instead of offering a CTA into a section with nothing left '
        'to do', (tester) async {
      await pumpDemo(tester);
      await playIntoCashShortage(tester);
      await tapAndSettle(tester, '11月を終了して翌月へ');
      await settle(tester);
      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );
      expect(currentState(tester).isCloseBlocked, isTrue);

      final tasks = find.byKey(const Key('public-demo-important-tasks'));
      await tester.ensureVisible(tasks);
      await tester.pumpAndSettle();
      expect(tasks, findsOneWidget);

      // 資金計画 is never gated — viewing the finance summary never
      // becomes illegal. SES HOME Final Visual Match (structural pass):
      // the category is now an icon, reachable via its Semantics label.
      expect(
        find.descendant(of: tasks, matching: find.bySemanticsLabel('資金')),
        findsOneWidget,
      );
      // '営業' is also the bottom nav's own destination label (section
      // 8) — scoped strictly to the important-tasks section so this
      // cannot pass by matching that unrelated, always-present label
      // instead. Checked via Semantics label (not visible text) so this
      // still proves the 営業/採用 tiles themselves are absent, not merely
      // that their category text was never painted.
      expect(
        find.descendant(of: tasks, matching: find.bySemanticsLabel('営業')),
        findsNothing,
      );
      expect(
        find.descendant(of: tasks, matching: find.bySemanticsLabel('採用')),
        findsNothing,
      );
    });
  });
}
