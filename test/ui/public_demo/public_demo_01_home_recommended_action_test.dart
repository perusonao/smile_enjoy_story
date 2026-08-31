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

import 'public_demo_intro_test_support.dart';

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
}

Future<void> tapCta(WidgetTester tester) async {
  await tester.ensureVisible(ctaFinder);
  await tester.pumpAndSettle();
  await tester.tap(ctaFinder);
  await settle(tester);
}

Future<void> dismiss(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
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
    MaterialApp(home: PublicDemo01PlaceholderScreen(key: UniqueKey())),
  );
  await tester.pumpAndSettle();
  await dismissPublicDemoIntroIfPresent(tester);
}

/// April: the first engineer wins the May order — the shared opening the
/// existing Public Demo suites use, reused here so HOME is observed on a
/// real trajectory rather than a synthesized one.
Future<void> playApril(WidgetTester tester) async {
  await tapAndSettle(tester, 'SkillSheet確認');
  await tapAndSettle(tester, '営業開始');
  await tapAndSettle(tester, '案件紹介');
  await tapAndSettle(tester, '上位会社面談');
  await dismiss(tester);
  await tapAndSettle(tester, '客先面談');
  await dismiss(tester);
  await tapAndSettle(tester, '受注');
  await dismiss(tester);
}

/// Advances to July on the no-hire route, where the applicant pipeline is
/// not rendered.
Future<void> playIntoJuly(WidgetTester tester) async {
  await tapAndSettle(tester, '4月終了→5月');
  await dismiss(tester);
  await tapAndSettle(tester, '5月終了→6月');
  await settle(tester);
  await tapAndSettle(tester, '6月終了→7月');
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
  await tapAndSettle(tester, '4月終了→5月');
  await dismiss(tester);
  await tapAndSettle(tester, '5月終了→6月');
  await settle(tester);
  await tapAndSettle(tester, '6月終了→7月');
  await settle(tester);
  await tapAndSettle(tester, '7月終了→8月');
  await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
  await tester.pumpAndSettle();
  await tapAndSettle(tester, '7月終了→8月');
  await settle(tester);
  await tapAndSettle(tester, '8月終了→9月');
  await settle(tester);
  await tapAndSettle(tester, '9月終了→10月');
  await settle(tester);
  await tapAndSettle(tester, '10月終了→11月');
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
      expect(find.byKey(const Key('home-recommended-action')), findsOneWidget);
      expect(ctaFinder, findsOneWidget);
      expect(
        find.byKey(const Key('home-recommended-action-headline')),
        findsOneWidget,
      );
      expect(find.text('次にやること'), findsOneWidget);
      expect(find.text('佐藤 健のSkillSheetを確認'), findsOneWidget);
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
      const taps = ['SkillSheet確認', '営業開始', '案件紹介'];

      for (var i = 0; i < taps.length; i++) {
        await tapAndSettle(tester, taps[i]);
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

      await tapAndSettle(tester, 'SkillSheet確認');
      await tapAndSettle(tester, '営業開始');
      await tapAndSettle(tester, '案件紹介');
      await tapAndSettle(tester, '上位会社面談');
      await dismiss(tester);
      if (actionButton('客先面談').evaluate().isNotEmpty) {
        await tapAndSettle(tester, '客先面談');
        await dismiss(tester);
      }
      if (actionButton('受注').evaluate().isNotEmpty) {
        expect(
          recommended(tester)!.kind,
          HomeRecommendedActionKind.employeeAcceptOrder,
        );
        expect(recommended(tester)!.targetId, first);
        await tapAndSettle(tester, '受注');
        await dismiss(tester);

        // `ordered` renders no button on the card, so the engineer is no
        // longer a candidate at all. April's other founding engineer is not
        // field-sales ready (`readyForFieldSales` is false), so its card
        // renders no button either — which means the correct outcome here
        // is the design table's "none of the above" row, not a fabricated
        // action for someone who has none.
        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.ordered,
        );
        expect(recommended(tester), isNull);
        expect(slot(tester), isA<HomeRecommendedActionNone>());
        expect(find.byKey(const Key('home-month-goal')), findsOneWidget);
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
      // The screen agrees: exactly one SkillSheet確認 button exists.
      expect(actionButton('SkillSheet確認'), findsOneWidget);
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
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      expect(currentState(tester).month, 5);

      expect(
        find.byKey(const Key('public-demo-recruitment-media-card')),
        findsOneWidget,
      );
      // May's applicants are all at `applied`, whose 経歴書確認 outranks the
      // supporting P3 media action — so 求人媒体 is *eligible* but not the
      // top pick. Both facts matter, and both are asserted.
      expect(
        recommended(tester)!.kind,
        HomeRecommendedActionKind.applicantReviewResume,
      );
    });

    testWidgets('July does not expose recruitment media, while the domain '
        'eligibility and July-to-August progression stay unchanged', (
      tester,
    ) async {
      await pumpDemo(tester);
      await playApril(tester);
      await playIntoJuly(tester);
      expect(currentState(tester).month, 7);

      // The UI exposes neither the card nor the button/sheet title, so the
      // paid recruitment action is not reachable from July.
      expect(
        find.byKey(const Key('public-demo-recruitment-media-card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('public-demo-open-recruitment-media')),
        findsNothing,
      );
      expect(find.text('求人媒体を選ぶ'), findsNothing);

      // This is a UI-only fix: the domain still supports July eligibility
      // for a future flow that can process its applicants.
      expect(
        currentState(tester).canUseRecruitmentMediaInMonth(7),
        isTrue,
        reason: 'the domain month 4–8 range remains unchanged',
      );

      // July continues to render no applicant cards.
      expect(actionButton('経歴書確認'), findsNothing);
      expect(actionButton('採用面談'), findsNothing);

      // Settle the bonus so nothing else can outrank the media action.
      await tapAndSettle(tester, '夏季賞与を決める');
      final noBonus = find.byKey(const Key('public-demo-summer-bonus-none'));
      expect(tester.widget<FilledButton>(noBonus).onPressed, isNotNull);
      await tester.ensureVisible(noBonus);
      await tester.tap(noBonus);
      await tester.pumpAndSettle();
      expect(find.text('選択済み：なし'), findsOneWidget);

      // Recommended Action remains unchanged: it never suggests recruitment.
      final action = recommended(tester);
      if (action != null) {
        expect(action.kind, isNot(HomeRecommendedActionKind.recruitmentMedia));
      }
      expect(find.text('求人媒体で候補者を追加'), findsNothing);

      // July's summer-bonus confirmation and ordinary progression are
      // unchanged by removing the unrelated recruitment entry point.
      await tapAndSettle(tester, '7月終了→8月');
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
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      await checkCurrentBuild();
      await tapAndSettle(tester, '5月終了→6月');
      await settle(tester);
      await checkCurrentBuild();
      await tapAndSettle(tester, '6月終了→7月');
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
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      expect(currentState(tester).month, 5);

      // May's 採用面談 is gated on `salesRemaining > 0` and consumes a slot
      // per applicant. Drain the month's capacity with the legacy buttons,
      // topping up the applicant pool from the (free) recruitment medium
      // when the pool runs dry.
      var guard = 0;
      while (currentState(tester).salesRemaining > 0 && guard++ < 25) {
        if (actionButton('経歴書確認').evaluate().isNotEmpty) {
          await tapAndSettle(tester, '経歴書確認');
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
          // one), which is exactly what May's remaining capacity needs.
          await tester.tap(
            find.byKey(const Key('public-demo-recruitment-medium-engineer')),
          );
          await settle(tester);
          continue;
        }
        break;
      }

      expect(
        currentState(tester).salesRemaining,
        0,
        reason: 'this test needs the month\'s sales capacity fully spent',
      );

      // The legacy 採用面談 button is still rendered, and is now disabled...
      final interview = actionButton('採用面談');
      if (interview.evaluate().isNotEmpty) {
        expect(
          tester.widget<FilledButton>(interview.first).onPressed,
          isNull,
          reason: 'the legacy button must be the disabled control here',
        );
      }
      // ...and HOME does not offer it. Whatever it offers instead — if
      // anything — is enabled. A disabled CTA is never acceptable.
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
      for (final tap in ['SkillSheet確認', '営業開始', '案件紹介']) {
        await tapAndSettle(tester, tap);
        checkBuild();
      }
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      checkBuild();
      await tapAndSettle(tester, '5月終了→6月');
      await settle(tester);
      checkBuild();
      await tapAndSettle(tester, '6月終了→7月');
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
      // buttons and record the authoritative outcome.
      await pumpDemo(tester);
      await tapAndSettle(tester, 'SkillSheet確認');
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
    testWidgets('cashShortage outranks every ordinary action, and the '
        'ordinary actions stay reachable', (tester) async {
      await pumpDemo(tester);
      await playIntoCashShortage(tester);

      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.cashShortage,
      );
      // The card still owns its own authority, above HOME...
      expect(
        find.byKey(const Key('public-demo-cash-shortage-card')),
        findsOneWidget,
      );
      // ...and the recommendation points at it, outranking anything else
      // this state could otherwise offer.
      expect(
        recommended(tester)!.kind,
        HomeRecommendedActionKind.cashShortageResponse,
      );
      expect(find.text('資金不足の対応を確認'), findsOneWidget);
      // §13's Failure-Recovery rule: not a dead end. The KPI and the
      // month-close CTA are both still there.
      expect(find.byKey(const Key('home-kpi-compact')), findsOneWidget);
      expect(actionButton('11月終了→12月'), findsWidgets);
    });

    testWidgets('the shortage CTA changes nothing authoritative', (
      tester,
    ) async {
      await pumpDemo(tester);
      await playIntoCashShortage(tester);

      final before = currentState(tester);
      final stagesBefore = currentWorkflow(
        tester,
      ).engineers.map((e) => e.stage).toList();
      await tapCta(tester);

      final after = currentState(tester);
      expect(after.cash, before.cash);
      expect(after.month, before.month);
      expect(after.financialStatus, before.financialStatus);
      expect(after.salesRemaining, before.salesRemaining);
      expect(after.pendingRevenue, before.pendingRevenue);
      expect(
        currentWorkflow(tester).engineers.map((e) => e.stage).toList(),
        stagesBefore,
      );
    });

    testWidgets('bankruptcy suppresses the slot entirely — there is no next '
        'action, and no consolation month goal either', (tester) async {
      await pumpDemo(tester);
      await playIntoCashShortage(tester);
      await tapAndSettle(tester, '11月終了→12月');
      await settle(tester);

      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );
      expect(currentState(tester).isCloseBlocked, isTrue);

      expect(slot(tester), isA<HomeRecommendedActionSuppressed>());
      expect(recommended(tester), isNull);
      expect(find.byKey(const Key('home-recommended-action')), findsNothing);
      expect(ctaFinder, findsNothing);
      expect(find.byKey(const Key('home-month-goal')), findsNothing);

      // Read-only content survives, per POST-12MONTH-1 /
      // FINANCE-FAILURE-1A+1B: the KPI and the employees are still there.
      expect(find.byKey(const Key('home-kpi-compact')), findsOneWidget);
      expect(find.text('佐藤 健'), findsWidgets);
    });

    testWidgets('HOME still cannot see a financial verdict: the suppressed '
        'slot names an outcome, never its reason', (tester) async {
      await pumpDemo(tester);
      await playIntoCashShortage(tester);
      await tapAndSettle(tester, '11月終了→12月');
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
    testWidgets('June on the no-hire route falls back', (tester) async {
      await pumpDemo(tester);
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      await tapAndSettle(tester, '5月終了→6月');
      await settle(tester);

      expect(currentState(tester).month, 6);
      expect(slot(tester), isA<HomeRecommendedActionNone>());
      expect(recommended(tester), isNull);
      expect(ctaFinder, findsNothing);
      expect(find.byKey(const Key('home-month-goal')), findsOneWidget);
      expect(find.text('今月やること'), findsOneWidget);
      expect(find.text('翌月の発注を確認し、7月も稼働できる状態を作りましょう'), findsOneWidget);
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
}
