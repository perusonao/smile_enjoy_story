import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';

import 'test_support/public_demo_legacy_applicant_test_helpers.dart';

void main() {
  const codec = PublicDemoSaveCodec();

  test(
    'round-trips a gameplay-critical aggregate without reinterpretation',
    () {
      final original = _advancedAggregate();

      final restored = codec.decode(codec.encode(original));

      expect(restored, isNotNull);
      expect(codec.toJson(restored!), codec.toJson(original));
      expect(restored.state.month, 7);
      expect(restored.state.pendingRevenue, original.state.pendingRevenue);
      expect(restored.state.summerBonusDecisionConfirmed, isTrue);
      expect(
        restored.state.trainingSelections,
        original.state.trainingSelections,
      );
      expect(restored.workflow.assignments, hasLength(1));
      expect(restored.workflow.applicants.single.hasJoined, isTrue);
      expect(
        restored.workflow.engineers.first.hasGenuineInterviewRecord,
        isTrue,
      );
    },
  );

  test('preserves an applicant decline before May roster pruning', () {
    // CORE-GAMEPLAY Phase 4.5: `PublicDemoWorkflowState.initial()` no
    // longer pre-seeds `app-01`/`app-02` — this simulates a save created
    // before that fix, where both really were persisted (legacy save
    // compatibility), matching this test's own hardcoded `app-02` /
    // `applicants[1]` indexing.
    var aggregate = withLegacyFoundingApplicants(
      PublicDemoAggregate.initial().closeApril(monthlyExpenses: 0),
    );
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

  test('rejects negative cash paired with normal financial authority', () {
    final encoded = codec.toJson(PublicDemoAggregate.initial());
    final contradictory = _copyEnvelope(
      encoded,
      state: {'cash': -1, 'monthOpeningCash': -1, 'financialStatus': 'normal'},
    );

    expect(codec.fromJson(contradictory), isNull);
  });

  test(
    'rejects an interview record that was not backed by pass outcome facts',
    () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final aggregate = (encoded['aggregate'] as Map<String, dynamic>);
      final workflow = (aggregate['workflow'] as Map<String, dynamic>);
      final engineers = (workflow['engineers'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      engineers[0] = {
        ...engineers[0],
        'stage': 'ordered',
        'interviewRecordEngineerId': engineers[0]['id'],
        // Deliberately leave lastInterviewScore null: a matching id alone must
        // never mint genuine interview authority during restoration.
      };
      final contradictory = {
        ...encoded,
        'aggregate': {
          ...aggregate,
          'workflow': {...workflow, 'engineers': engineers},
        },
      };

      expect(codec.fromJson(contradictory), isNull);
    },
  );

  group('Codex P1 fix (PR #212): legacy saves survive the strict round-trip '
      'despite new additive fields', () {
    test('a save missing matchingProposals AND every engineerRuntime\'s '
        'totalItExperienceMonths (a save written before CORE-GAMEPLAY '
        'Phase 5) still decodes, rather than being wholesale rejected', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final aggregate = (encoded['aggregate'] as Map<String, dynamic>);
      final workflow = Map<String, dynamic>.from(
        aggregate['workflow'] as Map,
      )..remove('matchingProposals');
      final state = Map<String, dynamic>.from(aggregate['state'] as Map);
      state['engineerRuntimes'] = (state['engineerRuntimes'] as List)
          .map(
            (entry) =>
                Map<String, dynamic>.from(entry as Map)
                  ..remove('totalItExperienceMonths'),
          )
          .toList();
      final legacy = {
        ...encoded,
        'aggregate': {...aggregate, 'workflow': workflow, 'state': state},
      };

      final restored = codec.fromJson(legacy);

      expect(restored, isNotNull);
      expect(restored!.workflow.matchingProposals, isEmpty);
      for (final runtime in restored.state.engineerRuntimes) {
        // The exact same fallback PublicDemoEngineerRuntime.fromJson itself
        // already uses for a missing key — never a fabricated new number.
        expect(
          runtime.totalItExperienceMonths,
          runtime.confirmedLanguages.contains(runtime.primaryLanguage)
              ? (runtime.languageSkills[runtime.primaryLanguage]
                        ?.actualExperienceMonths ??
                    0)
              : 0,
        );
      }
    });

    test('a save that already carries a real matchingProposal round-trips '
        'it exactly — the migration only ever fires for an ABSENT key, '
        'never overriding a genuinely-present one', () {
      final base = PublicDemoAggregate.initial();
      final candidate = base.projectCandidatesForMonth(4).first;
      final withProposal = base.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidate.id,
      );

      final restored = codec.decode(codec.encode(withProposal));

      expect(restored, isNotNull);
      expect(restored!.workflow.matchingProposals, hasLength(1));
      expect(
        restored.matchingProposalFor('eng-01')?.projectId,
        candidate.id,
      );
      expect(codec.toJson(restored), codec.toJson(withProposal));
    });
  });
}

PublicDemoAggregate _advancedAggregate() {
  // CORE-GAMEPLAY Phase 4.5: `PublicDemoWorkflowState.initial()` no longer
  // pre-seeds `app-01` — this simulates a save created before that fix,
  // where it really was persisted (legacy save compatibility), matching
  // this helper's own hardcoded `app-01` id below.
  var aggregate = withLegacyFoundingApplicants(PublicDemoAggregate.initial())
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
  return aggregate
      .closeJune(assignedInJuly: 0, monthlyExpenses: 0)
      .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none);
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
