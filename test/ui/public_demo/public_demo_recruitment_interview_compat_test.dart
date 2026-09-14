// PR #264 Codex Broad Review P1-1 (Preserve eligibility for in-flight saved
// interviews): see `test/game/public_demo/public_demo_recruitment_interview_
// compat_test.dart`'s own header for the full root-cause explanation. This
// file proves the same fix against the real UI, both entry points: HOME's
// guided "次にやること" CTA, and 営業's own card button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/models/recruitment_interview.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
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

/// Codex's own cited example (`runSeed` 1's free-medium May candidate,
/// `interviewScore` 61), driven through the real interactive Q&A to a
/// genuine "採用候補として進める" decision, then re-serialized with
/// [PublicDemoApplicant.qaEvaluationApplies] stripped out -- reproducing
/// exactly what a save written before this field existed looks like. Also
/// drives both founding engineers out of HOME's recommendation ranking
/// (mirroring `public_demo_offer_result_feedback_test.dart`'s own fixture
/// technique) so the applicant's salary-offer action is genuinely HOME's
/// top recommendation, not merely present.
({PublicDemoAggregate aggregate, String applicantId})
_preUpdateSaveWithDecidedHiredApplicant() {
  var aggregate = PublicDemoAggregate.initial(
    runSeed: 1,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  aggregate = recruited.aggregate!;
  final id = aggregate.workflow.applicants.first.id;
  expect(
    aggregate.workflow.applicants.first.interviewScore,
    61,
    reason: 'fixture sanity: matches the reviewer\'s own cited example',
  );
  aggregate = aggregate.completeInterview(id).aggregate;

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
  }

  aggregate = aggregate
      .startInterviewSession(id)
      .askInterviewQuestion(id, InterviewQuestionCategory.technical)
      .askInterviewQuestion(id, InterviewQuestionCategory.career)
      .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
      .answerInterviewReverseQuestion(id, 0);
  aggregate = aggregate.concludeInterviewSession(id, InterviewOutcome.hired);

  final decidedApplicant = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == id,
  );
  expect(decidedApplicant.qaEvaluationApplies, isTrue, reason: 'fixture sanity');

  final json = aggregate.toJson();
  final workflow = Map<String, dynamic>.from(json['workflow'] as Map);
  final applicants = (workflow['applicants'] as List)
      .map(
        (a) => Map<String, dynamic>.from(a as Map)..remove('qaEvaluationApplies'),
      )
      .toList();
  workflow['applicants'] = applicants;
  final legacy = PublicDemoAggregate.fromJson({...json, 'workflow': workflow});

  final legacyApplicant = legacy.workflow.applicants.firstWhere(
    (a) => a.id == id,
  );
  expect(
    legacyApplicant.qaEvaluationApplies,
    isFalse,
    reason: 'fixture sanity: this is the pre-update-save simulation',
  );
  return (aggregate: legacy, applicantId: id);
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
    '3. HOME guided route: a pre-update-save candidate whose raw '
    'interviewScore (61) still clears 60 keeps offering 給与を提示 through '
    'HOME\'s CTA',
    (tester) async {
      final fixture = _preUpdateSaveWithDecidedHiredApplicant();
      await _pumpScreen(tester, fixture.aggregate);

      expect(
        _recommended(tester)?.kind,
        HomeRecommendedActionKind.applicantSalaryOffer,
        reason: 'HOME must still recommend the offer for a grandfathered '
            'candidate',
      );
      await tester.tap(_ctaFinder);
      await tester.pumpAndSettle();
      expect(find.text('給与を提示'), findsOneWidget);
    },
  );

  testWidgets(
    '4. Sales direct route: the same pre-update-save candidate\'s own '
    '合格・給与提示 button stays enabled on 営業',
    (tester) async {
      final fixture = _preUpdateSaveWithDecidedHiredApplicant();
      await _pumpScreen(tester, fixture.aggregate);

      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      final offerButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '合格・給与提示'),
      );
      expect(
        offerButton.onPressed,
        isNotNull,
        reason: 'the grandfathered candidate\'s offer button must stay '
            'legally pressable',
      );
      await tester.tap(find.widgetWithText(FilledButton, '合格・給与提示'));
      await tester.pumpAndSettle();
      expect(find.text('給与を提示'), findsOneWidget);
    },
  );
}
