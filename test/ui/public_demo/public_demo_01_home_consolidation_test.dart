// HOME-RUNTIME-2A: legacy KPI cleanup + first-view consolidation.
//
// The phase is deliberately subtractive: the runtime screen used to render
// the month twice, cash three ways, and 参画/待機/社員 in two competing
// vocabularies, which pushed April's most important action (佐藤 健's
// SkillSheet確認) roughly a full screen below the fold. This suite pins both
// halves of the fix — that each fact now has exactly one place on screen,
// and that the space this reclaimed actually lands the action inside the
// initial viewport — plus the boundaries the cleanup was not allowed to
// cross.
//
// Everything here drives the REAL screen (and therefore the real
// PublicDemoAggregate trajectory behind it). The exceptions are the two
// March terminal cases, which this UI trajectory cannot reach in a
// reasonable number of taps and which therefore go through the same real
// domain (PublicDemoMonthlyClose) the screen itself uses.
//
// Scope guard: the projection still carries no financialStatus and no
// fiscalYearCompleted — see the "boundaries" group.
//
// HOME-RUNTIME-2C deliberately rewrote the other half of that guard
// (group 15) here, as the integration design's PHASE 2C requires. "HOME has
// no interactive element" became "HOME has exactly one — the whitelisted
// Recommended Action CTA, bound to an existing PublicDemoAggregate
// command". That is stricter, not weaker: it pins which single element may
// exist and what it may do, where the old form only counted to zero.
// 2C also reconciled the `今月やること` slot with the Recommended Action —
// they are one slot showing one of two things, never two stacked cards —
// so the tests that pinned the month goal's presence now pin that role
// split in both directions instead.
//
// HOME-RUNTIME-2B then added the Office Stage between the Recommended
// Action and the legacy content, which pushes the legacy per-employee
// `SkillSheet確認` button below the browser-chrome budget. Group 16-17's
// first-view assertion is therefore re-aimed at the Recommended Action CTA
// — the element that actually carries "the month's top action" after 2C,
// and which sits at roughly half the depth the legacy button ever did — and
// group 18/24 gained an explicit test that the legacy button is relocated
// rather than lost. The assertions themselves (painted viewport,
// browser-chrome budget, genuinely tappable) are unchanged in form and
// strength; only their subject moved, and 16-17 additionally now requires
// the Office Stage itself to be fully painted inside the same budget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/app/app_entry.dart';
import 'package:smile_enjoy_story/app/app_experience.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_internal_training_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_revenue.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/presentation/home/home.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/key_events_section.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/kpi_section.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/month_header_bar.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/recommended_action_section.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_cash_shortage_card.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';

import 'public_demo_intro_test_support.dart';

/// The screen's own authoritative finance state, read straight off its
/// [State] — the same technique the existing Public Demo widget suites use,
/// so every assertion below compares the UI against the real authority
/// rather than against a re-derived expectation.
PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Finder get sectionFinder => find.byType(PublicDemoHomeDashboardSection);

HomeDashboardDisplayData homeData(WidgetTester tester) =>
    tester.widget<PublicDemoHomeDashboardSection>(sectionFinder).data;

Finder inHome(Finder matching) =>
    find.descendant(of: sectionFinder, matching: matching);

/// The value rendered inside one named compact-KPI tile. Keyed rather than
/// matched loosely across the card, so "待機 shows 2名" cannot accidentally
/// be satisfied by the 社員 tile next to it.
Finder kpiTileValue(String tile, String value) => find.descendant(
  of: find.byKey(Key('home-kpi-compact-$tile')),
  matching: find.text(value),
);

/// Mirrors KpiSection's 万-unit formatting — the truncating `~/` semantics
/// HOME-RUNTIME-READ-1 introduced, which the merged KPI keeps (the deleted
/// legacy stat row used `floor()`).
String yen(int amount) => '¥${amount ~/ 10000}万';

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

/// Buttons that open an event dialog first await a real image decode, which
/// this SDK only completes on the wall clock — mirrors the existing Public
/// Demo widget tests' helper.
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

Future<void> pumpDemo(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  await tester.pumpAndSettle();
  await dismissPublicDemoIntroIfPresent(tester);
}

Future<void> pumpDemoAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await pumpDemo(tester);
}

/// April: Sato wins the May order — the shared opening of the existing
/// playthrough suites.
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

/// The content height a mobile browser actually leaves below the AppBar at
/// each target size, per the integration design's FIRST VIEW budget: iOS
/// Safari's chrome eats ~185pt at 360x800 and ~184pt at 390x844, so
/// asserting against the raw logical height is exactly the mistake that
/// produced the regression this phase fixes. These are the design's own
/// estimates, and the assertions below keep a wide margin under them
/// precisely because they are estimates.
const _targets = <({Size size, double contentBudget})>[
  (size: Size(360, 800), contentBudget: 615),
  (size: Size(390, 844), contentBudget: 660),
];

/// How far below the AppBar the HOME block itself may end at 360x800.
///
/// HOME-RUNTIME-2A's block measured 282pt (month header + compact KPI +
/// month-goal card). HOME-RUNTIME-2C swaps the last of those for the
/// recommended-action card, whose only structural addition is one CTA row.
/// 320pt is that block plus that row: enough for the phase, and not enough
/// for a second card to reappear in the slot. It is still barely half of
/// the 615pt browser-chrome content budget, so the screen's own content
/// keeps the rest.
const double _homeBlockCeiling = 500;

void main() {
  group('1-2: the Public Demo entry point is preserved', () {
    test('1: the Public Demo 0.1 route still resolves', () {
      expect(
        resolveAppExperience(
          Uri.parse('https://example.test/#/public-demo-01'),
        ),
        AppExperience.publicDemo01,
      );
    });

    testWidgets('2: the screen still starts normally on the consolidated '
        'HOME, and is still the Public Demo root', (tester) async {
      await pumpDemo(tester);

      expect(find.byType(PublicDemo01PlaceholderScreen), findsOneWidget);
      expect(find.byType(HomeShellPage), findsNothing);
      expect(find.text('S.E.S. Public Demo 0.1'), findsOneWidget);
      expect(sectionFinder, findsOneWidget);
      expect(inHome(find.byType(MonthHeaderBar)), findsOneWidget);
      expect(inHome(find.byType(KpiSection)), findsOneWidget);
      expect(inHome(find.byType(RecommendedActionSection)), findsOneWidget);
      // The Phase 1A `重要イベント` placeholder is not part of the runtime
      // HOME: 2C moved the slot's whole presentation to
      // RecommendedActionSection.
      expect(inHome(find.byType(KeyEventsSection)), findsNothing);
    });
  });

  group('3-7, 14: every fact has exactly one place on screen', () {
    testWidgets('3: the month is displayed by exactly one runtime authority', (
      tester,
    ) async {
      await pumpDemo(tester);

      // MonthHeaderBar owns it...
      expect(inHome(find.text('1年目 4月')), findsOneWidget);
      expect(find.text('1年目 4月'), findsOneWidget);
      // ...and the headline that used to restate it is gone. (Composite
      // labels like "4月終了→5月" or "7月開始結果" are different strings and
      // are unaffected — this asserts the bare duplicate specifically.)
      expect(find.text('4月'), findsNothing);
    });

    testWidgets('4: the legacy KPI row is gone, not duplicated', (
      tester,
    ) async {
      await pumpDemo(tester);

      // The legacy vocabulary is gone outright.
      expect(find.text('現預金'), findsNothing);
      expect(find.text('参画中'), findsNothing);
      expect(find.text('社員数'), findsNothing);

      // The merged KPI carries every label exactly once, inside HOME.
      for (final label in ['現金', '参画', '営業残', '社員', '売上', '入金予定']) {
        expect(find.text(label), findsOneWidget, reason: label);
        expect(inHome(find.text(label)), findsOneWidget, reason: label);
      }

      // 待機 is the one label that legitimately appears outside HOME: it is
      // also each waiting engineer's own status badge, which is a different
      // statement (this employee is waiting) from the KPI's (two employees
      // are waiting). Pinned exactly rather than loosened to findsWidgets —
      // one KPI tile plus April's two waiting engineers, and no third.
      expect(inHome(find.text('待機')), findsOneWidget);
      expect(kpiTileValue('waiting', '2名'), findsOneWidget);
      expect(
        find.text('待機'),
        findsNWidgets(3),
        reason: 'one KPI tile plus April\'s two waiting engineers',
      );
    });

    testWidgets('5: cash is rendered once in the top summary', (tester) async {
      await pumpDemo(tester);
      final state = currentState(tester);

      expect(state.cash, 4000000);
      expect(find.text(yen(state.cash)), findsOneWidget);
      expect(kpiTileValue('cash', yen(state.cash)), findsOneWidget);
      // The training row's raw-yen "研修後の現預金 ¥2970000" preview — the
      // third rendering of cash on this screen — is gone with the
      // compaction; the action it belonged to is not (see test 18).
      expect(find.textContaining('研修後の現預金'), findsNothing);
    });

    testWidgets('6-7: the placeholder 稼働案件/信用 tiles are gone from the '
        'runtime KPI, and the Phase 1A shell still has them', (tester) async {
      await pumpDemo(tester);

      // A tile that can only ever render "—" reads as broken on a live
      // screen, so the runtime variant drops both.
      expect(find.text('稼働案件'), findsNothing);
      expect(find.text('信用'), findsNothing);
      expect(inHome(find.text('—')), findsNothing);

      // The default (Phase 1A / HOME-UI-1A) presentation is untouched.
      await tester.pumpWidget(const MaterialApp(home: HomeShellPage()));
      await tester.pumpAndSettle();
      expect(find.text('稼働案件'), findsOneWidget);
      expect(find.text('信用'), findsOneWidget);
    });

    testWidgets('14: the month-goal table still has exactly one home, and '
        'the slot shows it exactly when no action is eligible', (tester) async {
      await pumpDemo(tester);

      const aprilGoal = '待機中の技術者を営業し、5月の案件参画を決めましょう';

      // The table itself did not move again and was not copied: the screen
      // still has no month-goal switch of its own, and the projection is
      // still the single place the text comes from.
      expect(homeData(tester).monthGoalText, aprilGoal);
      expect(
        () =>
            (tester.state(find.byType(PublicDemo01PlaceholderScreen))
                    as dynamic)
                .monthGoal(),
        throwsNoSuchMethodError,
      );

      // HOME-RUNTIME-2C: April HAS an eligible action, so the one slot
      // states that action rather than the month's general goal. The two
      // never appear together — that is what keeps this a slot and not a
      // second card stacked above the first.
      expect(find.byKey(const Key('home-recommended-action')), findsOneWidget);
      expect(find.text('今月やること'), findsNothing);
      expect(find.text(aprilGoal), findsNothing);
      expect(find.byKey(const Key('home-month-goal')), findsNothing);

      // And it follows the authoritative month.
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      expect(currentState(tester).month, 5);
      expect(homeData(tester).monthGoalText, '応募者を採用し、入社前から6月の案件獲得を目指しましょう');
    });

    testWidgets('14b: with no eligible action the same slot falls back to '
        'the month goal, in HOME, as text', (tester) async {
      // June on the no-hire route: nothing is assigned, nobody joined, and
      // no engineer is in a sellable stage — the design table's "none of
      // the above" row.
      await pumpDemo(tester);
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      await tapAndSettle(tester, '5月終了→6月');
      await settle(tester);
      expect(currentState(tester).month, 6);

      const juneGoal = '翌月の発注を確認し、7月も稼働できる状態を作りましょう';
      expect(find.byKey(const Key('home-recommended-action')), findsNothing);
      expect(find.text('今月やること'), findsOneWidget);
      expect(inHome(find.text('今月やること')), findsOneWidget);
      expect(find.text(juneGoal), findsOneWidget);
      expect(inHome(find.text(juneGoal)), findsOneWidget);
    });
  });

  group('8-13: every merged value still comes from the authority', () {
    testWidgets('the seven KPI figures equal the authoritative state, and '
        'the counts stay distinct from one another', (tester) async {
      await pumpDemo(tester);

      final state = currentState(tester);
      final home = homeData(tester);

      // 8. 待機 — read, never derived as employeeCount - assignedCount.
      expect(home.waitingEmployeeCount, state.engineersWaiting);
      expect(home.waitingEmployeeCount, 2);
      expect(kpiTileValue('waiting', '2名'), findsOneWidget);

      // 9. 営業残 — the existing salesRemaining getter, verbatim.
      expect(home.salesRemaining, state.salesRemaining);
      expect(home.salesRemaining, 4);
      expect(kpiTileValue('sales-remaining', '4回'), findsOneWidget);

      // 10. 社員 — the finance-side headcount, not applicants.
      expect(home.employeeCount, state.engineerCount);
      expect(home.employeeCount, 2);
      expect(kpiTileValue('employees', '2名'), findsOneWidget);

      // 11. 参画 — engineersAssigned, never the waiting or total headcount.
      expect(home.assignedEmployeeCount, state.engineersAssigned);
      expect(home.assignedEmployeeCount, 0);
      expect(kpiTileValue('assigned', '0名'), findsOneWidget);
      expect(
        home.assignedEmployeeCount,
        isNot(home.waitingEmployeeCount),
        reason:
            'April has 2 waiting and 0 assigned — merging must not mix '
            'the two counts into one tile',
      );

      // 12. 売上 — the production formula, applied to the authoritative
      //     assigned count.
      expect(
        home.revenue,
        PublicDemoRevenue.monthlyRevenueForAssignedCount(
          state.engineersAssigned,
        ),
      );
      expect(kpiTileValue('revenue', yen(home.revenue)), findsOneWidget);

      // 13. 入金予定 — verbatim, and never folded into cash.
      expect(home.pendingRevenue, state.pendingRevenue);
      expect(
        kpiTileValue('pending-revenue', yen(home.pendingRevenue)),
        findsOneWidget,
      );

      expect(home, HomeDashboardDisplayData.fromPublicDemoState(state));
    });

    testWidgets('the merged values keep following the authority across a '
        'close, and cash keeps its truncating format', (tester) async {
      await pumpDemo(tester);
      await playApril(tester);
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);

      final state = currentState(tester);
      expect(state.month, 5);
      expect(
        homeData(tester),
        HomeDashboardDisplayData.fromPublicDemoState(state),
      );
      expect(
        kpiTileValue('waiting', '${state.engineersWaiting}名'),
        findsOneWidget,
      );
      expect(
        kpiTileValue('assigned', '${state.engineersAssigned}名'),
        findsOneWidget,
      );
      expect(
        kpiTileValue('sales-remaining', '${state.salesRemaining}回'),
        findsOneWidget,
      );

      // FIX from HOME-RUNTIME-READ-1 that the merge must not undo: `~/`
      // truncates toward zero, where the deleted stat row's `floor()`
      // rounded toward negative infinity and overstated a sub-¥1万
      // shortfall as -1万.
      expect(yen(-5000), '¥0万');
      expect(yen(-10000), '¥-1万');
      expect(
        (-5000 / 10000).floor(),
        -1,
        reason: 'the old behaviour, for contrast',
      );
    });
  });

  group('15: HOME\'s only gameplay mutation path is the resolved action', () {
    testWidgets('the HOME subtree has the resolved action plus Hiyori\'s '
        'local advice control, with no new gameplay entry point', (
      tester,
    ) async {
      await pumpDemo(tester);

      final cta = find.byKey(const Key('home-recommended-action-cta'));
      expect(inHome(cta), findsOneWidget);
      final openAdvice = find.byKey(const Key('home-navigator-open-advice'));
      expect(inHome(openAdvice), findsOneWidget);
      expect(
        inHome(find.byWidgetPredicate((w) => w is ButtonStyleButton)),
        findsNWidgets(2),
        reason: 'HOME has one action CTA and Hiyori\'s local detail control',
      );

      // The non-CTA parts of HOME remain completely inert.
      final before = currentState(tester);
      for (final target in <Finder>[
        inHome(find.byType(KpiSection)),
        inHome(find.byType(MonthHeaderBar)),
        find.byKey(const Key('home-navigator-rationale')),
        find.byKey(const Key('home-recommended-action-headline')),
      ]) {
        await tester.tap(target, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      final after = currentState(tester);
      expect(after.month, before.month);
      expect(after.cash, before.cash);
      expect(after.pendingRevenue, before.pendingRevenue);
      expect(after.engineerCount, before.engineerCount);
      expect(after.engineersAssigned, before.engineersAssigned);
      expect(after.engineersWaiting, before.engineersWaiting);
      expect(after.salesRemaining, before.salesRemaining);
      expect(after.financialStatus, before.financialStatus);
      expect(after.fiscalYearCompleted, before.fiscalYearCompleted);
      expect(after.trainingSelections, before.trainingSelections);
    });
  });

  group('16-17: the month\'s top action is inside the first view', () {
    for (final (:size, :contentBudget) in _targets) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('the month\'s top action is reachable with no scrolling, '
          'and the Employee Status office strip is fully visible, at $label', (
        tester,
      ) async {
        await pumpDemoAt(tester, size);

        // Nothing below is allowed to scroll first: this asserts what a
        // player sees when the screen opens.
        final scrollable = tester.widget<ListView>(find.byType(ListView));
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          0,
          reason: 'the assertions below must describe the unscrolled screen',
        );
        expect(scrollable.controller?.offset ?? 0, 0);

        // HOME-RUNTIME-2B changed WHICH widget this assertion is made
        // about, deliberately and once. It used to name the legacy
        // per-employee `SkillSheet確認` button, because before
        // HOME-RUNTIME-2C that button *was* the only way to take April's
        // top action, and landing it above the fold was the whole point of
        // 2A. 2C then put the same action behind the Recommended Action
        // CTA at 302pt — half the depth — and 2B spends the space that
        // freed up on the Office Stage, which pushes the now-redundant
        // second copy of the action below the browser-chrome budget.
        //
        // So the property this group exists to protect ("the month's top
        // action is in the first view") is asserted here against the
        // element that actually carries it, and it holds by a far wider
        // margin than it ever did against the legacy button. What is NOT
        // relaxed: the action is still pinned to the painted viewport, to
        // the browser-chrome budget, and to being genuinely tappable from
        // where it sits — all three assertions below are the originals,
        // re-aimed. The legacy button's continued existence, enablement
        // and reachability are asserted further down, in group 18/24.
        final cta = find.byKey(const Key('home-recommended-action-cta'));
        expect(cta, findsOneWidget);

        final ctaRect = tester.getRect(cta);
        final viewport = tester.getRect(find.byType(ListView));

        // (a) It is genuinely inside the painted viewport, top and bottom —
        //     not merely present in the widget tree below the fold.
        expect(
          ctaRect.top,
          greaterThanOrEqualTo(viewport.top),
          reason: 'CTA top $ctaRect vs viewport $viewport',
        );
        expect(
          ctaRect.bottom,
          lessThanOrEqualTo(viewport.bottom),
          reason: 'CTA bottom $ctaRect vs viewport $viewport',
        );

        // (b) ...and inside the *effective* content height a mobile browser
        //     leaves once its chrome is showing, which is the height the
        //     screenshots were taken at.
        expect(
          ctaRect.bottom - viewport.top,
          lessThanOrEqualTo(contentBudget),
          reason:
              'the CTA ends ${ctaRect.bottom - viewport.top}pt below the '
              'AppBar; the browser-chrome content budget at $label is '
              '${contentBudget}pt',
        );

        // (c) Employee Status follows the primary decision. It remains
        // reachable immediately beneath the action, but it no longer claims
        // the rest of the first-view budget as a competing hero section.
        final stage = tester.getRect(
          find.byKey(const Key('home-office-stage')),
        );
        expect(stage.top, greaterThan(ctaRect.bottom));

        // The action is genuinely usable from where it sits, not just
        // laid out there — and it still runs April's real first step.
        await tester.tap(cta);
        await settle(tester);
        expect(actionButton('営業開始'), findsWidgets);
      });
    }

    testWidgets('the whole HOME block above the employees stays well inside '
        'the first view at the smaller target size', (tester) async {
      await pumpDemoAt(tester, const Size(360, 800));

      final viewport = tester.getRect(find.byType(ListView));
      final home = tester.getRect(sectionFinder);
      expect(home.top, greaterThanOrEqualTo(viewport.top));
      // The HOME block is a summary plus one CTA, not the screen: it must
      // still leave room for real content underneath it inside the
      // browser-chrome budget.
      //
      // HOME-RUNTIME-2C raised this ceiling from `_smallestBudget / 2`
      // (307.5pt) to _homeBlockCeiling, once and deliberately. 2A's HOME
      // measured 282pt; 2C replaces its month-goal card with the
      // recommended-action card, which costs the height of one CTA row.
      // The ceiling is the 2A block plus that row and nothing more, so it
      // still fails the moment the slot grows into a second card — which
      // is the regression this assertion exists to catch. What the number
      // may NOT be traded against is the CTA's tap target: the budget was
      // raised rather than the button shrunk below 48pt.
      expect(home.bottom - viewport.top, lessThanOrEqualTo(_homeBlockCeiling));
    });

    for (final (:size, :contentBudget) in _targets) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('2C: the Recommended Action CTA is itself inside the '
          'first view, above where the legacy button sits, at $label', (
        tester,
      ) async {
        await pumpDemoAt(tester, size);

        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          0,
          reason: 'this must describe the unscrolled screen',
        );

        final viewport = tester.getRect(find.byType(ListView));
        final cta = tester.getRect(
          find.byKey(const Key('home-recommended-action-cta')),
        );
        final headline = tester.getRect(
          find.byKey(const Key('home-recommended-action-headline')),
        );
        final legacy = tester.getRect(actionButton('SkillSheet確認'));

        // Both halves of the message — who/what, and where to tap — are
        // painted inside the viewport and inside the browser-chrome budget.
        expect(headline.top, greaterThanOrEqualTo(viewport.top));
        expect(cta.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(
          cta.bottom - viewport.top,
          lessThanOrEqualTo(contentBudget),
          reason:
              'the CTA ends ${cta.bottom - viewport.top}pt below the AppBar; '
              'the browser-chrome content budget at $label is '
              '${contentBudget}pt',
        );

        // The whole point of the phase: the next action is now reachable
        // far higher than the per-employee button it shortcuts to.
        expect(
          cta.bottom,
          lessThan(legacy.top),
          reason:
              'the Recommended Action must sit above the employee card '
              'action it leads to',
        );

        // A 48pt tap target was not sacrificed to fit.
        expect(cta.height, greaterThanOrEqualTo(44.0));
      });
    }
  });

  group('18, 24: every action the cleanup touched is still reachable', () {
    testWidgets('Employee Status, Finance Summary, and the month-close '
        'control remain reachable', (tester) async {
      await pumpDemoAt(tester, const Size(360, 800));

      for (final finder in <Finder>[
        find.text('社員ステージ'),
        find.byKey(const Key('public-demo-finance-summary')),
        find.byKey(const Key('public-demo-monthly-primary-cta')),
      ]) {
        await tester.ensureVisible(finder.first);
        await tester.pumpAndSettle();
        final rect = tester.getRect(finder.first);
        final viewport = tester.getRect(find.byType(ListView));
        expect(rect.bottom, greaterThanOrEqualTo(viewport.top));
        expect(rect.top, lessThanOrEqualTo(viewport.bottom));
      }
    });

    testWidgets('a populated Important Events section remains reachable', (
      tester,
    ) async {
      await pumpDemoAt(tester, const Size(390, 844));
      await playApril(tester);
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);

      final events = find.byKey(const Key('public-demo-important-events'));
      await tester.ensureVisible(events.first);
      await tester.pumpAndSettle();
      expect(events, findsOneWidget);
      expect(find.text('月次'), findsOneWidget);
      expect(find.text('収支を見る'), findsOneWidget);
    });

    testWidgets('2B: the legacy SkillSheet確認 button still exists, still '
        'sits below the Office Stage, and still works after scrolling', (
      tester,
    ) async {
      await pumpDemoAt(tester, const Size(360, 800));

      // HOME-RUNTIME-2B moved this button below the browser-chrome budget
      // (see group 16-17) — it did NOT remove it, disable it, or change
      // what it does. Nothing about the legacy per-employee cards is 2B's
      // to delete; that is 2D/2E's scope. This pins the difference between
      // "relocated" and "lost".
      final button = actionButton('SkillSheet確認');
      expect(button, findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);

      final stage = tester.getRect(find.byKey(const Key('home-office-stage')));
      expect(
        tester.getRect(button).top,
        greaterThan(stage.bottom),
        reason: 'the legacy employee action belongs below the Office Stage',
      );

      // Reachable and functional by ordinary scrolling.
      await tapAndSettle(tester, 'SkillSheet確認');
      expect(actionButton('営業開始'), findsWidgets);
    });

    testWidgets('18: the internal-training action still runs the same '
        'command, with the same key and the same eligibility', (tester) async {
      await pumpDemoAt(tester, const Size(390, 844));

      final card = find.byKey(
        const Key('public-demo-internal-training-eng-01'),
      );
      final action = find.byKey(
        const Key('public-demo-internal-training-action-eng-01'),
      );
      expect(card, findsOneWidget);
      expect(action, findsOneWidget);
      expect(find.text('社内研修 ¥30,000'), findsWidgets);

      final before = currentState(tester);
      expect(before.trainingSelections.containsKey('eng-01'), isFalse);

      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();

      final after = currentState(tester);
      expect(after.trainingSelections.containsKey('eng-01'), isTrue);
      // The cost authority is untouched: the domain transaction still
      // prices the selection, at the same ¥30,000 the compacted row names,
      // and the compaction changed neither the amount nor who charges it.
      expect(PublicDemoInternalTrainingTransaction.cost, 30000);
      expect(
        after.cash,
        before.cash - PublicDemoInternalTrainingTransaction.cost,
        reason: 'the same command charges the same authoritative cost',
      );

      // Once selected the row states that and stops offering the action —
      // the pre-2A behaviour, in one line instead of a full card.
      expect(find.text('社内研修 ¥30,000（今月は社内研修）'), findsWidgets);
      expect(action, findsNothing);
      expect(card, findsOneWidget);
    });

    testWidgets('24: the month close is still reachable and still closes, '
        'with a byte-identical label', (tester) async {
      await pumpDemo(tester);
      expect(currentState(tester).month, 4);

      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);

      expect(currentState(tester).month, 5);
      expect(inHome(find.text('1年目 5月')), findsOneWidget);
    });
  });

  group('19-20: the shortage card owns its own authority, above HOME', () {
    testWidgets('19: at cashShortage the card renders above the HOME block', (
      tester,
    ) async {
      await pumpDemo(tester);

      // The structurally-insolvent trajectory the existing suites pin:
      // CASH SHORTAGE closing September.
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

      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.cashShortage,
      );

      final shortage = find.byKey(const Key('public-demo-cash-shortage-card'));
      expect(shortage, findsOneWidget);
      // The warning outranks the summary: in a shortage state the shortage
      // explanation IS the recommended action.
      expect(
        tester.getTopLeft(shortage).dy,
        lessThan(tester.getTopLeft(sectionFinder).dy),
      );
      expect(
        tester.getTopLeft(shortage).dy,
        lessThan(tester.getTopLeft(find.byType(MonthHeaderBar)).dy),
      );

      // 21: bankruptcy is still reached, and is still terminal.
      await tapAndSettle(tester, '11月終了→12月');
      await settle(tester);
      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );
      // PLAYTEST-BLOCKER-1A: the month-close button is hidden once bankrupt,
      // not a silent no-op. Domain-level terminal guard is proven by
      // public_demo_financial_status_test.dart.
      expect(
        find.text('12月終了→1月'),
        findsNothing,
        reason:
            'month-close CTA must be hidden after bankruptcy '
            '(PLAYTEST-BLOCKER-1A)',
      );
    });

    testWidgets('20: negative cash alone never produces the shortage UI', (
      tester,
    ) async {
      // Hoisting the card did not move its authority: it still renders on
      // financialStatus == cashShortage and nothing else. A deeply negative
      // balance carrying a non-shortage status renders no card at all.
      final negativeButNormal = PublicDemoState(
        month: 8,
        cash: -1500000,
        engineerCount: 2,
        adminCount: 1,
        salesCapacity: 4,
        salesUsed: 0,
        engineersWaiting: 2,
        engineersAssigned: 0,
      );
      expect(
        negativeButNormal.financialStatus,
        PublicDemoFinancialStatus.normal,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicDemoCashShortageCard(state: negativeButNormal),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public-demo-cash-shortage-card')),
        findsNothing,
      );
      expect(find.text('資金不足：次回決算が期限です'), findsNothing);

      // And the projection HOME receives from that same state carries no
      // verdict either — see the boundaries group.
      final projection = HomeDashboardDisplayData.fromPublicDemoState(
        negativeButNormal,
      );
      expect(projection.cash, -1500000);
    });
  });

  group('22-23: the March terminal outcomes stay domain-owned', () {
    PublicDemoState march({required int cash}) => PublicDemoState(
      month: 15,
      cash: cash,
      engineerCount: 1,
      adminCount: 1,
      salesCapacity: 4,
      salesUsed: 0,
      engineersWaiting: 1,
      engineersAssigned: 0,
    );

    test('22: March cash-shortage failure is unchanged by the widened '
        'projection', () {
      final failure = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: march(cash: 500000),
        monthlyExpenses: 800000,
      ).state;

      expect(
        failure.financialStatus,
        PublicDemoFinancialStatus.marchCashShortageFailure,
      );
      expect(failure.fiscalYearCompleted, isFalse);

      final projection = HomeDashboardDisplayData.fromPublicDemoState(failure);
      expect(failure.cash, -300000, reason: 'projecting must not mutate');
      expect(
        failure.financialStatus,
        PublicDemoFinancialStatus.marchCashShortageFailure,
      );
      expect(projection.cash, failure.cash);
      expect(projection.monthLabel, '3月');
      expect(projection.waitingEmployeeCount, failure.engineersWaiting);
      expect(projection.salesRemaining, failure.salesRemaining);
    });

    test('23: fiscal success is unchanged by the widened projection', () {
      final success = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: march(cash: 900000),
        monthlyExpenses: 800000,
      ).state;

      expect(success.fiscalYearCompleted, isTrue);
      expect(success.financialStatus, PublicDemoFinancialStatus.normal);

      final projection = HomeDashboardDisplayData.fromPublicDemoState(success);
      expect(success.fiscalYearCompleted, isTrue, reason: 'still unmutated');
      expect(projection.cash, success.cash);
    });
  });

  group('boundaries the cleanup was not allowed to cross', () {
    test('the projection still carries no financial verdict: two states that '
        'differ ONLY in financialStatus project equal data', () {
      PublicDemoState base({required PublicDemoFinancialStatus status}) =>
          PublicDemoState(
            month: 10,
            cash: -200000,
            engineerCount: 2,
            adminCount: 1,
            salesCapacity: 4,
            salesUsed: 1,
            engineersWaiting: 1,
            engineersAssigned: 1,
            financialStatus: status,
          );

      final normal = HomeDashboardDisplayData.fromPublicDemoState(
        base(status: PublicDemoFinancialStatus.normal),
      );
      final bankrupt = HomeDashboardDisplayData.fromPublicDemoState(
        base(status: PublicDemoFinancialStatus.bankruptcy),
      );

      // HOME structurally cannot contradict — or pre-empt — the terminal
      // composition the owning screen performs.
      expect(normal, bankrupt);
      expect(normal.hashCode, bankrupt.hashCode);
    });

    test('the three fields HOME-RUNTIME-2A added are read verbatim, never '
        'derived from one another', () {
      // A state whose counts deliberately do NOT satisfy
      // waiting == total - assigned: the projection must report what the
      // authority says, not quietly repair it.
      final inconsistent = PublicDemoState(
        month: 6,
        cash: 1000000,
        engineerCount: 5,
        adminCount: 1,
        salesCapacity: 4,
        salesUsed: 3,
        engineersWaiting: 1,
        engineersAssigned: 1,
      );

      final projection = HomeDashboardDisplayData.fromPublicDemoState(
        inconsistent,
      );
      expect(projection.waitingEmployeeCount, 1);
      expect(projection.employeeCount, 5);
      expect(projection.assignedEmployeeCount, 1);
      expect(
        projection.waitingEmployeeCount,
        isNot(projection.employeeCount - projection.assignedEmployeeCount),
        reason: 'engineersWaiting is read, not recomputed',
      );
      expect(projection.salesRemaining, inconsistent.salesRemaining);
      expect(projection.salesRemaining, 1);
    });

    testWidgets('the Phase 1A shell keeps its own defaults: no data means no '
        'month goal and the original empty state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: KeyEventsSection())),
      );
      await tester.pumpAndSettle();

      expect(find.text('重要イベント'), findsOneWidget);
      expect(find.text('表示できるイベントはありません'), findsOneWidget);
      expect(find.text('今月やること'), findsNothing);
    });
  });

  group('responsive layout', () {
    for (final (:size, contentBudget: _) in _targets) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('the consolidated screen lays out without overflow at '
          '$label', (tester) async {
        await pumpDemoAt(tester, size);

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(sectionFinder).width,
          lessThanOrEqualTo(size.width),
        );
        // The compact KPI's four-across row is the tightest thing on the
        // screen — it must fit horizontally, and stay readable (no tile
        // collapsed to nothing).
        for (final tile in const [
          'cash',
          'assigned',
          'waiting',
          'sales-remaining',
          'employees',
          'revenue',
          'pending-revenue',
        ]) {
          final rect = tester.getRect(
            find.byKey(Key('home-kpi-compact-$tile')),
          );
          expect(rect.left, greaterThanOrEqualTo(0.0), reason: tile);
          expect(rect.right, lessThanOrEqualTo(size.width), reason: tile);
          expect(rect.width, greaterThan(40.0), reason: tile);
          expect(rect.height, greaterThan(20.0), reason: tile);
        }
        expect(
          tester
              .getRect(
                find.byKey(const Key('home-recommended-action-headline')),
              )
              .right,
          lessThanOrEqualTo(size.width),
        );
        expect(
          tester
              .getRect(find.byKey(const Key('home-recommended-action-cta')))
              .right,
          lessThanOrEqualTo(size.width),
        );

        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
