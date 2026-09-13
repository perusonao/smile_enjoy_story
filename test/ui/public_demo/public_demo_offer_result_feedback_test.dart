// SES First Fun Quarter AI Replay Audit #2 P1-3 Fresh Audit fix:
//
// Before this fix, accepting a salary offer's outcome (内定承諾/内定辞退) was
// decided entirely inside [PublicDemoOfferAcceptance.accept] the moment the
// player chose a salary, but nothing displayed it. Reaching this action
// through HOME's guided "次にやること" card was completely silent — HOME's
// recommended-action ranking simply moved on to whatever became next, with
// no acknowledgement of what happened to the candidate just decided. A
// player following HOME never saw the outcome unless they separately
// checked 営業, where the card's own status badge already updated.
//
// This suite drives the real production `PublicDemoAggregate`/`offer(i)`
// path (recruit/completeInterview/interactive interview session/
// acceptOffer — no fabricated applicant/stage is ever constructed
// directly, mirroring `public_demo_issue245_recruitment_lifecycle_
// visibility_test.dart`'s own fixture technique) and proves:
//
//  * the same result dialog appears whether `offer(i)` was reached through
//    HOME's CTA or 営業's own button (one authority, one display, no
//    per-entry-point special case)
//  * it names the candidate, the result, the offered salary, and a short
//    explanation, reusing the existing candidate portrait/relationship
//    reason
//  * no further action is reachable until the dialog is dismissed
//  * the action that produced it is never offered again afterward (no way
//    to reach a second judgement through the real UI)
//  * closing the dialog never recomputes anything, and a save/reload round
//    trip leaves the already-decided outcome byte-identical
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/models/recruitment_interview.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_recommended_action.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import 'public_demo_tab_test_helpers.dart';

const _expense = 800000;

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

/// `runSeed` 1's real free-medium May candidate (山本智子, `interviewScore`
/// 61 — clears the real 60 offer threshold, confirmed below, never
/// asserted to) driven to a genuine "採用候補として進める" decision, exactly
/// like `public_demo_issue245_recruitment_lifecycle_visibility_test.dart`'s
/// own `_mayWithOneDecidedHiredAboveThresholdApplicant` fixture.
PublicDemoAggregate _mayWithOneInterviewedHiredApplicant() {
  const seed = 1;
  var aggregate = PublicDemoAggregate.initial(
    runSeed: seed,
  ).closeApril(monthlyExpenses: _expense);

  // Recruit and complete this applicant's own interview (`completeInterview`
  // consumes one sales slot) BEFORE the founding engineers below spend the
  // rest of this month's budget -- ordering only, no different commands.
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  aggregate = recruited.aggregate!;
  final id = aggregate.workflow.applicants.first.id;
  final interviewScore = aggregate.workflow.applicants.first.interviewScore;
  expect(
    interviewScore,
    greaterThanOrEqualTo(60),
    reason: 'fixture sanity: runSeed $seed must genuinely clear the real '
        'offer threshold, not be asserted to',
  );
  aggregate = aggregate.completeInterview(id).aggregate;
  final afterInterviewCompletion = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == id,
  );
  expect(
    afterInterviewCompletion.stage.name,
    'interviewed',
    reason: 'fixture sanity',
  );

  // HOME shows only its single top-priority recommended action, and every
  // engineer sales-pipeline stage outranks `applicantSalaryOffer`
  // (priority 46) except `ordered` (which stops emitting) and `introduced`
  // with the month's sales-slot budget exhausted (also stops emitting --
  // see `_addEngineerStageCandidate`'s own `introduced` case, gated on
  // `s.salesRemaining > 0`). Both founding engineers are driven there
  // through the same real, sanctioned commands their own ec(i) buttons use
  // -- no fabricated stage -- so the fixture's own recruited applicant is
  // genuinely HOME's top recommendation below, exactly like a player who
  // already handled the two founding engineers before recruiting.
  for (final engineer in aggregate.workflow.engineers) {
    aggregate = aggregate.startSkillSheetReview(engineer.id);
    aggregate = aggregate.beginSelling(engineer.id);
    aggregate = aggregate.introduceProject(engineer.id);
    aggregate = aggregate.recordEngineerInterviewResult(
      engineerId: engineer.id,
      type: PublicDemoInterviewType.partner,
    );
    for (var attempt = 0; attempt < 4; attempt++) {
      final stage = aggregate.workflow.engineers
          .firstWhere((e) => e.id == engineer.id)
          .stage;
      if (stage == PublicDemoSalesStage.ordered) break;
      if (stage == PublicDemoSalesStage.introduced &&
          aggregate.state.salesRemaining <= 0) {
        break;
      }
      if (stage == PublicDemoSalesStage.partnerInterviewPassed) {
        aggregate = aggregate.recordEngineerInterviewResult(
          engineerId: engineer.id,
          type: PublicDemoInterviewType.client,
        );
        continue;
      }
      if (stage == PublicDemoSalesStage.clientInterviewPassed) {
        aggregate = aggregate.recordOrder(engineer.id);
        continue;
      }
      aggregate = aggregate.beginSelling(engineer.id);
      aggregate = aggregate.introduceProject(engineer.id);
      aggregate = aggregate.recordEngineerInterviewResult(
        engineerId: engineer.id,
        type: PublicDemoInterviewType.partner,
      );
    }
    final settled = aggregate.workflow.engineers.firstWhere(
      (e) => e.id == engineer.id,
    );
    expect(
      settled.stage == PublicDemoSalesStage.ordered ||
          (settled.stage == PublicDemoSalesStage.introduced &&
              aggregate.state.salesRemaining <= 0),
      isTrue,
      reason:
          'fixture sanity: ${engineer.name} must settle into a stage that '
          'stops emitting a HOME recommended action ($settled, '
          'salesRemaining=${aggregate.state.salesRemaining})',
    );
  }

  aggregate = aggregate
      .startInterviewSession(id)
      .askInterviewQuestion(id, InterviewQuestionCategory.technical)
      .askInterviewQuestion(id, InterviewQuestionCategory.career)
      .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
      .answerInterviewReverseQuestion(id, 0);
  aggregate = aggregate.concludeInterviewSession(id, InterviewOutcome.hired);

  final decided = aggregate.workflow.applicants.firstWhere((a) => a.id == id);
  expect(decided.stage.name, 'interviewed', reason: 'fixture sanity');
  expect(decided.interviewScore, greaterThanOrEqualTo(60), reason: 'fixture sanity');
  return aggregate;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
) async {
  const size = Size(390, 844);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _ctaFinder => find.byKey(const Key('home-recommended-action-cta'));
Finder get _resultCloseFinder =>
    find.byKey(const Key('public-demo-offer-result-close'));

HomeRecommendedAction? _recommended(WidgetTester tester) {
  final slot = tester
      .widget<PublicDemoHomeDashboardSection>(
        find.byType(PublicDemoHomeDashboardSection),
      )
      .recommendedAction;
  return slot is HomeRecommendedActionAvailable ? slot.candidate.action : null;
}

void main() {
  testWidgets(
    'HOME経由 acceptance: the result dialog names the candidate, states '
    '内定承諾, the offered salary and a short reason, and only afterward does '
    'HOME stop recommending this candidate\'s offer action',
    (tester) async {
      await _pumpScreen(tester, _mayWithOneInterviewedHiredApplicant());

      expect(_recommended(tester)?.kind, HomeRecommendedActionKind.applicantSalaryOffer);
      await tester.tap(_ctaFinder);
      await tester.pumpAndSettle();
      expect(find.text('給与を提示'), findsOneWidget);

      // requested 270,000 + 40,000 = above-request offer -> accepted.
      await tester.tap(find.byKey(const Key('public-demo-salary-offer-310000')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public-demo-offer-result-dialog-山本 智子')),
        findsOneWidget,
      );
      expect(find.text('内定承諾'), findsOneWidget);
      expect(find.text('山本 智子'), findsWidgets);
      expect(find.text('提示給与 ${formatYen(310000)}'), findsOneWidget);
      expect(find.text('希望給与を上回る条件で入社'), findsOneWidget);
      // Still modal -- the barrier blocks any tap from reaching whatever
      // HOME renders underneath, so the guided flow cannot have moved on.
      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(_resultCloseFinder);
      await tester.pumpAndSettle();

      expect(find.text('内定承諾'), findsNothing);
      expect(
        _recommended(tester)?.kind,
        isNot(HomeRecommendedActionKind.applicantSalaryOffer),
        reason: 'the decided candidate must never be recommended again',
      );
    },
  );

  testWidgets(
    'HOME経由 decline: the result dialog states 内定辞退 with the same shape '
    'as an acceptance, and this same (last remaining) candidate is never '
    'recommended again afterward',
    (tester) async {
      await _pumpScreen(tester, _mayWithOneInterviewedHiredApplicant());

      await tester.tap(_ctaFinder);
      await tester.pumpAndSettle();

      // requested 270,000 - 40,000 = below-request offer -> declined
      // (acceptanceScore 70 - 16 = 54, confirmed by construction).
      await tester.tap(find.byKey(const Key('public-demo-salary-offer-230000')));
      await tester.pumpAndSettle();

      expect(find.text('内定辞退'), findsOneWidget);
      expect(find.text('山本 智子'), findsWidgets);
      expect(find.text('提示給与 ${formatYen(230000)}'), findsOneWidget);
      expect(find.text('希望給与を下回る条件で入社'), findsOneWidget);

      await tester.tap(_resultCloseFinder);
      await tester.pumpAndSettle();

      expect(find.text('内定辞退'), findsNothing);
      // This was the only candidate in the game -- 最後の候補 case: HOME
      // must fall back cleanly (no crash, no stale/dangling recommendation)
      // rather than recommend a now-decided candidate again.
      expect(
        _recommended(tester)?.kind,
        isNot(HomeRecommendedActionKind.applicantSalaryOffer),
      );
    },
  );

  testWidgets(
    'Sales直接経由: tapping 合格・給与提示 straight from 営業 (never through '
    'HOME) shows the exact same result dialog, and the card\'s own status '
    'badge already agrees once it is dismissed',
    (tester) async {
      await _pumpScreen(tester, _mayWithOneInterviewedHiredApplicant());

      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      await tester.tap(find.widgetWithText(FilledButton, '合格・給与提示'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('public-demo-salary-offer-310000')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public-demo-offer-result-dialog-山本 智子')),
        findsOneWidget,
      );
      await tester.tap(_resultCloseFinder);
      await tester.pumpAndSettle();

      // applicantStatus(a)'s own badge -- already the single source of
      // truth this dialog never duplicates or re-derives.
      expect(find.text('内定承諾'), findsOneWidget);
      // 合格・給与提示 is a stage=interviewed-only button; once decided it
      // can never be tapped again through this same card.
      expect(find.widgetWithText(FilledButton, '合格・給与提示'), findsNothing);
    },
  );

  testWidgets(
    '二重判定防止: after a decision and its result dialog are dismissed, '
    'nothing on screen can reach `offer(i)` for this candidate again -- '
    'the underlying decision is a one-shot the UI cannot replay',
    (tester) async {
      await _pumpScreen(tester, _mayWithOneInterviewedHiredApplicant());

      await tester.tap(_ctaFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('public-demo-salary-offer-310000')));
      await tester.pumpAndSettle();
      await tester.tap(_resultCloseFinder);
      await tester.pumpAndSettle();

      // Neither HOME's CTA nor 営業's own button can reach `offer(i)` again.
      expect(
        _recommended(tester)?.kind,
        isNot(HomeRecommendedActionKind.applicantSalaryOffer),
      );
      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      expect(find.widgetWithText(FilledButton, '合格・給与提示'), findsNothing);
      expect(find.byKey(const Key('public-demo-offer-result-close')), findsNothing);
    },
  );

  test(
    'save/reload: a declined offer\'s recorded stage/salary/reason survive '
    'a toJson/fromJson round trip byte-identical -- the exact fields this '
    'dialog reads back are never recomputed on reload',
    () {
      var aggregate = _mayWithOneInterviewedHiredApplicant();
      final id = aggregate.workflow.applicants.first.id;
      final requested = aggregate.workflow.applicants
          .firstWhere((a) => a.id == id)
          .requestedMonthlySalary;
      final applicantBefore = aggregate.workflow.applicants.first;
      final offer = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicantBefore,
        offeredMonthlySalary: requested - 40000,
      );
      expect(offer.accepted, isFalse, reason: 'fixture sanity: must decline');
      aggregate = aggregate.acceptOffer(
        applicantId: id,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
      );

      final decided = aggregate.workflow.applicants.firstWhere(
        (a) => a.id == id,
      );
      expect(decided.stage.name, 'offerDeclined');

      final reloaded = PublicDemoAggregate.fromJson(aggregate.toJson());
      final reloadedApplicant = reloaded.workflow.applicants.firstWhere(
        (a) => a.id == id,
      );
      expect(reloadedApplicant.stage, decided.stage);
      expect(
        reloadedApplicant.acceptedMonthlySalary,
        decided.acceptedMonthlySalary,
      );
      expect(
        reloadedApplicant.salaryRelationshipReason,
        decided.salaryRelationshipReason,
      );
    },
  );
}
