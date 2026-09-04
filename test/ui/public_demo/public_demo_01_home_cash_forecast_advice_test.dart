// Issue #148 Phase 1B.3 (HOME-COMPACT-1B.3): connects the existing
// confirmed-information cash forecast (PublicDemoCashForecast, PR #153)
// through the existing presentation/advice layer
// (PublicDemoCashStatusPresentation, PublicDemoCashAdviceSelector, both
// PR #154) into the Navigator card on the real HOME screen.
//
// This suite never touches the forecast/status/advice models' own logic —
// it drives the real screen through a real gameplay trajectory and asserts
// only what the Navigator card shows as a result, per Issue #148 Phase
// 1B.3's own scope:
//
//  * a preventive window (financialStatus still `normal`, but the forecast
//    already sees a future month go cash-negative) surfaces the forecast's
//    reason and a next action inside the Navigator — no separate, large
//    standalone card;
//  * once an actual cashShortage/bankruptcy is reached, the existing strong
//    leads (PublicDemoCashShortageCard, the bankruptcy terminal card, and
//    the existing `cashShortageResponse` recommended-action candidate) are
//    not duplicated by this new forecast-based advice;
//  * a healthy month (April start) shows no cash warning at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

/// Mirrors the existing Public Demo widget suites' own helper: buttons that
/// open an event dialog first await a real image decode, which this SDK
/// only completes on the wall clock.
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
  final monthGuardProceed = find.byKey(
    const Key('public-demo-month-guard-proceed'),
  );
  if (monthGuardProceed.evaluate().isNotEmpty) {
    await tester.tap(monthGuardProceed);
    await tester.pumpAndSettle();
  }
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
}

/// April: Sato wins the May order — the shared opening of the existing
/// playthrough suites (verbatim from public_demo_01_home_consolidation_test
/// .dart), reused here so this suite drives the exact same, already-pinned
/// structurally-insolvent trajectory.
Future<void> playApril(WidgetTester tester) async {
  // The employee sales-progression card is on 社員 now
  // (PUBLIC-DEMO-HOME-UI-3B).
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
}

/// Drives the same CASH SHORTAGE-closing-September trajectory
/// public_demo_01_home_consolidation_test.dart's group 19 pins, but stops
/// one close earlier — right after September closes (state.month == 10,
/// financialStatus still `normal`) instead of after October closes (where
/// that suite's own trajectory reaches financialStatus == cashShortage).
/// This is Issue #148 Phase 1B.3's preventive window: the real close that
/// will go cash-negative has not happened yet, but the confirmed-
/// information forecast already sees it coming.
Future<void> playToPreShortageWindow(WidgetTester tester) async {
  await playApril(tester);
  // The month-close CTA is HOME's own monthly primary action.
  await switchPublicDemoTab(tester, PublicDemoTab.home);
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
}

/// Injects a pre-built [PublicDemoAggregate] as the "restored save", the
/// same technique `public_demo_01_single_month_advance_cta_test.dart` and
/// other existing suites already use to reach a specific state without
/// re-driving every UI step.
class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

Future<void> pumpDemoWith(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Joins [applicantId] as an engineer via the real accept-offer/join chain,
/// with no further pre-entry steps: a genuinely idle engineer at
/// [PublicDemoSalesStage.waiting] with no assignment.
PublicDemoAggregate _acceptOfferOnly(
  PublicDemoAggregate aggregate,
  String applicantId,
) {
  var next = aggregate.completeInterview(applicantId).aggregate;
  final applicant = next.workflow.applicants.firstWhere(
    (a) => a.id == applicantId,
  );
  return next.acceptOffer(
    applicantId: applicantId,
    offer: PublicDemoSalaryOffer(
      requestedMonthlySalary: applicant.requestedMonthlySalary,
      offeredMonthlySalary: applicant.requestedMonthlySalary,
      acceptanceScore: 100,
      motivationDelta: 0,
      trustDelta: 0,
    ),
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(next.state.month),
  );
}

/// Walks [applicantId] through the full real pre-entry pipeline to
/// `juneOrdered` — every stage precondition genuinely satisfied, exactly
/// the chain `public_demo_aggregate_test.dart`'s own "TEST E: genuine
/// applicant happy path" and `public_demo_workflow_state_test.dart` use.
PublicDemoAggregate _orderApplicant(
  PublicDemoAggregate aggregate,
  String applicantId,
) => _acceptOfferOnly(aggregate, applicantId)
    .beginPreEntrySkillSheet(applicantId)
    .beginPreEntrySelling(applicantId)
    .introducePreEntryProject(applicantId)
    .recordPreEntryPartnerInterviewResult(applicantId)
    .recordPreEntryClientInterviewResult(applicantId)
    .recordJuneOrder(applicantId);

/// Reproduces the exact real-command scenario the Codex review on PR #159
/// (https://github.com/perusonao/smile_enjoy_story/pull/159#discussion_r3924337236)
/// found: an applicant (`app-01`, 高橋 翔) who wins a June pre-entry order
/// joins as an engineer at [PublicDemoSalesStage.waiting]
/// (`withJoinedEngineers`) in the exact same `closeMay` that also adds them
/// to the assignment roster (`assignOrderedForMay`) — so `stage == waiting`
/// alone no longer means "not currently on a project" for this engineer.
///
/// Both founding engineers are advanced to `selling` (a real, in-progress
/// stage `PublicDemoCashAdviceSelector` already excludes on its own) so
/// they never compete with `app-01`/[secondApplicantId] for the one
/// advice slot — this keeps the fixture a clean, minimal reproduction of
/// the June-join mismatch alone, not a coincidental ordering effect.
///
/// [secondApplicantId], when supplied, joins via [_acceptOfferOnly] (no
/// further pre-entry steps) — a genuinely idle, un-assigned `waiting`
/// engineer appended to the roster *after* `app-01`, so the pre-fix
/// selector (which returns the first `waiting`-stage match in
/// `workflow.engineers` order) reaches `app-01` before it, letting the
/// fixture also prove the fallback behaviour Issue #148's fix instructions
/// require: excluding `app-01` must not just suppress the CTA outright —
/// it must fall through to this genuinely-eligible engineer.
///
/// The `+100000` on April's `monthlyExpenses` is a caller-supplied number
/// (this parameter is never cross-checked against the real formula — every
/// existing aggregate-level test fixture picks its own), chosen only so
/// the real, unmodified `PublicDemoCashForecast` genuinely projects a
/// shortage a few months out while `financialStatus` is still confirmed
/// `normal` — asserted explicitly below rather than assumed.
PublicDemoAggregate _buildJuneJoinMismatchAggregate({
  String? secondApplicantId,
}) {
  var aggregate = PublicDemoAggregate.initial();
  aggregate = aggregate
      .startSkillSheetReview('eng-01')
      .beginSelling('eng-01')
      .startSkillSheetReview('eng-02')
      .beginSelling('eng-02');
  aggregate = aggregate.closeApril(
    monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses + 100000,
  );

  aggregate = _orderApplicant(aggregate, 'app-01');
  if (secondApplicantId != null) {
    aggregate = _acceptOfferOnly(aggregate, secondApplicantId);
  }

  // Matches production's own may() call exactly (public_demo_01_placeholder
  // _screen.dart): the baseline constant, unadjusted for the newly-joined
  // hire(s) — closeMay's own join/assignment step runs inside this same
  // call, so their salary is not yet a settled fact when this number is
  // computed, exactly like the real screen.
  return aggregate.closeMay(
    week: 9,
    monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
  );
}

void main() {
  group('preventive window: financialStatus is still normal', () {
    testWidgets('the Navigator shows the forecasted shortage month, a caution '
        'expression, and a next action — with no duplicate large card', (
      tester,
    ) async {
      await pumpDemo(tester);
      await playToPreShortageWindow(tester);

      // The real trajectory this mirrors (group 19 in
      // public_demo_01_home_consolidation_test.dart) reaches
      // financialStatus == cashShortage only after October's close — one
      // step past where this test stops. Confirms the scenario is
      // genuinely the preventive window, not an already-realized shortage.
      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.normal,
      );
      expect(currentState(tester).month, 10);

      // No duplicate strong lead: the real shortage/bankruptcy cards are
      // for an already-realized financialStatus, which this state is not.
      expect(
        find.byKey(const Key('public-demo-cash-shortage-card')),
        findsNothing,
      );

      // The forecast's own reason (which month) is stated verbatim.
      expect(find.textContaining('10月に資金がマイナスになる見込みです'), findsOneWidget);

      // A caution expression — the same artwork the existing
      // cashShortageResponse/caution path already uses.
      final portrait = tester.widget<Image>(
        find.byKey(const Key('home-navigator-portrait')),
      );
      expect(
        (portrait.image as AssetImage).assetName,
        AssetPaths.navigatorCaution,
      );

      // A next action is offered — either the resolved advice candidate's
      // CTA, or (when none is currently valid) the finance-detail
      // fallback. Either way there is exactly one CTA in the slot, and it
      // is tappable without throwing.
      final cta = find.byKey(const Key('home-recommended-action-cta'));
      expect(cta, findsOneWidget);
      expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
    });

    testWidgets('a healthy April start shows no cash warning at all', (
      tester,
    ) async {
      await pumpDemo(tester);

      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.normal,
      );
      expect(find.textContaining('資金がマイナスになる見込みです'), findsNothing);
      expect(
        find.byKey(const Key('public-demo-cash-shortage-card')),
        findsNothing,
      );
      // The ordinary next action (April's SkillSheet confirmation) still
      // owns the slot, unchanged.
      expect(
        find.byKey(const Key('home-recommended-action-headline')),
        findsOneWidget,
      );
    });
  });

  group('an already-realized shortage is never duplicated', () {
    testWidgets(
      'once financialStatus flips to cashShortage, the forecast-based '
      'caution message is suppressed — the existing shortage card is the '
      'sole strong lead',
      (tester) async {
        await pumpDemo(tester);
        await playToPreShortageWindow(tester);
        await tapAndSettle(tester, '10月を終了して翌月へ');
        await settle(tester);

        expect(
          currentState(tester).financialStatus,
          PublicDemoFinancialStatus.cashShortage,
        );

        // The existing strong lead renders exactly once...
        expect(
          find.byKey(const Key('public-demo-cash-shortage-card')),
          findsOneWidget,
        );
        // ...and this feature's own forecast-based message never appears
        // alongside it — no duplicate cash lead.
        expect(find.textContaining('資金がマイナスになる見込みです'), findsNothing);
      },
    );
  });

  group('P2 fix (Codex review on PR #159): an already-assigned engineer is '
      'never the cash-advice CTA target', () {
    testWidgets(
      'the sole "candidate" is an engineer who already joined via a June '
      'order and is already on the assignment roster: the CTA falls back '
      'to the safe finance-detail action, never to that engineer',
      (tester) async {
        final aggregate = _buildJuneJoinMismatchAggregate();

        // Sanity checks on the fixture itself, independent of the
        // screen: a genuine preventive-caution window (financialStatus
        // still normal, the forecast already sees a shortage), and the
        // one engineer who could satisfy `PublicDemoCashAdviceSelector`'s
        // own `stage == waiting` check is already on the assignment
        // roster — the exact mismatch the Codex review describes.
        expect(
          aggregate.state.financialStatus,
          PublicDemoFinancialStatus.normal,
        );
        expect(
          aggregate.workflow.engineers
              .where((e) => e.stage == PublicDemoSalesStage.waiting)
              .map((e) => e.id),
          ['app-01'],
        );
        expect(
          aggregate.workflow.assignedEngineerIds(month: aggregate.state.month),
          contains('app-01'),
        );

        await pumpDemoWith(tester, aggregate);

        // A caution advice is genuinely showing (the preventive window
        // this fixture targets)...
        expect(find.textContaining('資金がマイナスになる見込みです'), findsOneWidget);
        // ...but it is never bound to 高橋 翔 (app-01) anywhere inside
        // the Navigator card — not as the headline, not as a name inside
        // the advice bubble's own explanation text.
        final navigator = find.byKey(const Key('home-navigator'));
        expect(
          find.descendant(of: navigator, matching: find.textContaining('高橋 翔')),
          findsNothing,
        );
        // No CTA at all is also an acceptable outcome (the doc-mandated
        // "無効なCTAを表示しない"), but this fixture's forecast has no
        // other candidate either, so it must be the safe finance-detail
        // fallback specifically — never a fabricated action bound to the
        // assigned engineer. Scoped to the Navigator card itself: the
        // important-tasks section below has its own, unrelated row
        // titled with the same words.
        expect(
          find.descendant(of: navigator, matching: find.text('資金計画を確認する')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('home-recommended-action-headline')),
          findsNothing,
        );

        // The CTA is genuinely safe to press — a scroll-jump, not a
        // command against the already-assigned engineer.
        await tester.tap(find.byKey(const Key('home-recommended-action-cta')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a second, genuinely idle waiting engineer exists after excluding '
      'the assigned one: the CTA targets that engineer instead',
      (tester) async {
        final aggregate = _buildJuneJoinMismatchAggregate(
          secondApplicantId: 'app-02',
        );

        expect(
          aggregate.state.financialStatus,
          PublicDemoFinancialStatus.normal,
        );
        // Both app-01 (already assigned) and app-02 (genuinely idle) are
        // `waiting`, in that order — the exact ordering that would let a
        // naive "first waiting engineer" scan pick the wrong one.
        expect(
          aggregate.workflow.engineers
              .where((e) => e.stage == PublicDemoSalesStage.waiting)
              .map((e) => e.id),
          ['app-01', 'app-02'],
        );
        final assignedIds = aggregate.workflow.assignedEngineerIds(
          month: aggregate.state.month,
        );
        expect(assignedIds, contains('app-01'));
        expect(assignedIds, isNot(contains('app-02')));

        await pumpDemoWith(tester, aggregate);

        expect(find.textContaining('資金がマイナスになる見込みです'), findsOneWidget);
        final navigator = find.byKey(const Key('home-navigator'));
        // The genuinely eligible engineer is the one actually offered —
        // named in both the headline and the advice bubble's own
        // explanation, hence "at least one" rather than exactly one.
        expect(
          find.descendant(
            of: navigator,
            matching: find.textContaining('田中 美咲'),
          ),
          findsWidgets,
        );
        // ...and the already-assigned one is never named here instead.
        expect(
          find.descendant(of: navigator, matching: find.textContaining('高橋 翔')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('home-recommended-action-cta')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('home-recommended-action-cta')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
