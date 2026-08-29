import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';

void main() {
  const codec = PublicDemoSaveCodec();

  test('round-trips a gameplay-critical aggregate without reinterpretation', () {
    final original = _advancedAggregate();

    final restored = codec.decode(codec.encode(original));

    expect(restored, isNotNull);
    expect(codec.toJson(restored!), codec.toJson(original));
    expect(restored.state.month, 6);
    expect(restored.state.pendingRevenue, original.state.pendingRevenue);
    expect(restored.state.trainingSelections, original.state.trainingSelections);
    expect(restored.workflow.assignments, hasLength(1));
    expect(restored.workflow.applicants.single.hasJoined, isTrue);
    expect(restored.workflow.engineers.first.hasGenuineInterviewRecord, isTrue);
  });

  test('preserves an applicant decline before May roster pruning', () {
    var aggregate = PublicDemoAggregate.initial().closeApril(monthlyExpenses: 0);
    final interviewed = aggregate.completeInterview('app-02');
    aggregate = interviewed.aggregate.acceptOffer(
      applicantId: 'app-02',
      offer: PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: interviewed.aggregate.workflow.applicants[1],
        offeredMonthlySalary: 200000,
      ),
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    );

    final restored = codec.decode(codec.encode(aggregate));

    expect(restored, isNotNull);
    expect(restored!.workflow.applicants[1].stage.name, 'offerDeclined');
  });

  test('rejects corrupt, incompatible, normalized, and inconsistent saves', () {
    final encoded = codec.toJson(_advancedAggregate());
    final incompatible = <String, dynamic>{...encoded, 'schemaVersion': 2};
    final normalized = _copyEnvelope(encoded, state: {'pendingRevenue': -1});
    final inconsistent = _copyEnvelope(encoded, state: {'engineerCount': 99});

    expect(codec.decode('{broken'), isNull);
    expect(codec.fromJson(incompatible), isNull);
    expect(codec.fromJson(normalized), isNull);
    expect(codec.fromJson(inconsistent), isNull);
  });
}

PublicDemoAggregate _advancedAggregate() {
  var aggregate = PublicDemoAggregate.initial()
      .startSkillSheetReview('eng-01')
      .beginSelling('eng-01')
      .introduceProject('eng-01')
      .recordEngineerInterviewResult(
        engineerId: 'eng-01',
        type: PublicDemoInterviewType.partner,
      )
      .recordEngineerInterviewResult(
        engineerId: 'eng-01',
        type: PublicDemoInterviewType.client,
      )
      .recordOrder('eng-01')
      .closeApril(monthlyExpenses: 0);

  final interview = aggregate.completeInterview('app-01');
  aggregate = interview.aggregate.acceptOffer(
    applicantId: 'app-01',
    offer: PublicDemoSalaryOfferEvaluator.evaluate(
      applicant: interview.aggregate.workflow.applicants.first,
      offeredMonthlySalary: 320000,
    ),
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
  );
  aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 0);
  aggregate = aggregate.selectInternalTraining('app-01');
  return aggregate.selectSummerBonus(PublicDemoSummerBonusPlan.none);
}

Map<String, dynamic> _copyEnvelope(
  Map<String, dynamic> source, {
  required Map<String, dynamic> state,
}) {
  final aggregate = (source['aggregate'] as Map<String, dynamic>);
  return {
    ...source,
    'aggregate': {
      ...aggregate,
      'state': {...(aggregate['state'] as Map<String, dynamic>), ...state},
    },
  };
}
