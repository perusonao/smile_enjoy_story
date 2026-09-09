import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
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

  group('PR #214 main-integration fix: legacy saves survive the strict '
      'round-trip despite the interviewSessions/projectInterviewSessions '
      'additive fields', () {
    test('a save missing BOTH interviewSessions and '
        'projectInterviewSessions (a save written before CORE-GAMEPLAY '
        'Phase 3) still decodes, rather than being wholesale rejected', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final aggregate = (encoded['aggregate'] as Map<String, dynamic>);
      final workflow = Map<String, dynamic>.from(aggregate['workflow'] as Map)
        ..remove('interviewSessions')
        ..remove('projectInterviewSessions');
      final legacy = {
        ...encoded,
        'aggregate': {...aggregate, 'workflow': workflow},
      };

      final restored = codec.fromJson(legacy);

      expect(restored, isNotNull);
      expect(restored!.workflow.interviewSessions, isEmpty);
      expect(restored.workflow.projectInterviewSessions, isEmpty);
    });

    test('a save that already carries a real recruitment interviewSession '
        'round-trips it exactly — the migration only ever fires for an '
        'ABSENT key, never overriding a genuinely-present one', () {
      var aggregate = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: 0,
      );
      final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
      expect(recruited.isSuccess, isTrue);
      aggregate = recruited.aggregate!;
      final applicantId = aggregate.workflow.applicants.first.id;
      aggregate = aggregate.completeInterview(applicantId).aggregate;
      aggregate = aggregate.startInterviewSession(applicantId);
      expect(aggregate.workflow.interviewSessions, hasLength(1));

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(restored!.workflow.interviewSessions, hasLength(1));
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });

    test('a save that already carries a real projectInterviewSession '
        'round-trips it exactly — the migration only ever fires for an '
        'ABSENT key, never overriding a genuinely-present one', () {
      var aggregate = PublicDemoAggregate.initial()
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );
      final candidate = aggregate
          .projectCandidatesForMonth(aggregate.state.month)
          .first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidate.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      expect(aggregate.workflow.projectInterviewSessions, hasLength(1));

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(restored!.workflow.projectInterviewSessions, hasLength(1));
      expect(
        restored.projectInterviewSessionFor('eng-01')?.projectId,
        candidate.id,
      );
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });
  });

  group('Codex P1-1 fix (PR #214): a genuine Phase 6 stochastic pass is '
      'never conflated with the legacy threshold-evaluated one', () {
    test('1. a genuine Phase 6 pass with finalRate (lastInterviewScore) < '
        '60 still decodes — a stochastic pass is legitimately possible at '
        'any rate in ClientInterviewEngine.finalRate\'s own [5, 95] range, '
        'never only >= 60', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final withLowScorePass = _withEngineerZero(encoded, {
        'stage': 'clientInterviewPassed',
        'lastInterviewScore': 45,
        'interviewRecordEngineerId': 'eng-01',
        'interviewRecordProjectId': 'project-4-1',
      });

      final restored = codec.fromJson(withLowScorePass);

      expect(restored, isNotNull);
      final engineer = restored!.workflow.engineers.firstWhere(
        (e) => e.id == 'eng-01',
      );
      expect(engineer.stage.name, 'clientInterviewPassed');
      expect(engineer.lastInterviewScore, 45);
      expect(engineer.genuineInterviewProjectId, 'project-4-1');
    });

    test('2. the exact same low score WITHOUT a project binding (the '
        'legacy, project-agnostic PublicDemoInterviewEvaluator path) is '
        'still rejected — the >= 60 floor is not unconditionally weakened', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final withLowScoreLegacy = _withEngineerZero(encoded, {
        'stage': 'clientInterviewPassed',
        'lastInterviewScore': 45,
        'interviewRecordEngineerId': 'eng-01',
        'interviewRecordProjectId': null,
      });

      expect(codec.fromJson(withLowScoreLegacy), isNull);
    });

    test('a genuine Phase 6 pass score above the [5, 95] clamp ceiling is '
        'rejected — the new stochastic path still has a real, bounded '
        'validity range, not an unconditional pass-through', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final withOutOfRangeScore = _withEngineerZero(encoded, {
        'stage': 'clientInterviewPassed',
        'lastInterviewScore': 96,
        'interviewRecordEngineerId': 'eng-01',
        'interviewRecordProjectId': 'project-4-1',
      });

      expect(codec.fromJson(withOutOfRangeScore), isNull);
    });

    test('a legacy save with no interviewRecordProjectId key at all (a save '
        'written before this fix) still decodes, rather than being '
        'wholesale rejected', () {
      var aggregate = _advancedAggregate();
      expect(
        aggregate.workflow.engineers.first.hasGenuineInterviewRecord,
        isTrue,
      );
      final encoded = codec.toJson(aggregate);
      final workflow = Map<String, dynamic>.from(
        (encoded['aggregate'] as Map)['workflow'] as Map,
      );
      final engineers = (workflow['engineers'] as List)
          .map(
            (entry) => Map<String, dynamic>.from(entry as Map)
              ..remove('interviewRecordProjectId'),
          )
          .toList();
      final legacy = {
        ...encoded,
        'aggregate': {
          ...(encoded['aggregate'] as Map<String, dynamic>),
          'workflow': {...workflow, 'engineers': engineers},
        },
      };

      final restored = codec.fromJson(legacy);

      expect(restored, isNotNull);
      // The generic pre-Phase-6 path this fixture actually used — never
      // fabricated as project-bound just because the key was absent.
      expect(
        restored!.workflow.engineers.first.genuineInterviewProjectId,
        isNull,
      );
    });

    test('7. a genuine end-to-end Phase 6 pass (real interview, real seeded '
        'roll) round-trips its project binding exactly', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 1)
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );
      final project = aggregate
          .projectCandidatesForMonth(aggregate.state.month)
          .first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      var session = aggregate.projectInterviewSessionFor('eng-01')!;
      while (session.playerFollowUps.length < session.questions.length) {
        aggregate = aggregate.chooseProjectInterviewFollowUp(
          'eng-01',
          session.currentQuestionIndex,
          PublicDemoProjectInterview.choicesFor(session).first,
        );
        session = aggregate.projectInterviewSessionFor('eng-01')!;
      }
      aggregate = aggregate.concludeProjectInterview('eng-01');

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      final beforeEngineer = aggregate.workflow.engineers.firstWhere(
        (e) => e.id == 'eng-01',
      );
      final afterEngineer = restored!.workflow.engineers.firstWhere(
        (e) => e.id == 'eng-01',
      );
      expect(afterEngineer.stage, beforeEngineer.stage);
      expect(afterEngineer.lastInterviewScore, beforeEngineer.lastInterviewScore);
      expect(
        afterEngineer.genuineInterviewProjectId,
        beforeEngineer.genuineInterviewProjectId,
      );
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });
  });

  group('Codex P2-1 fix (PR #214): malformed project-interview sessions are '
      'rejected during restore, not left to crash the dialog later', () {
    PublicDemoAggregate readySessionAggregate({int runSeed = 1}) {
      var aggregate = PublicDemoAggregate.initial(runSeed: runSeed)
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );
      final project = aggregate
          .projectCandidatesForMonth(aggregate.state.month)
          .first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      expect(aggregate.workflow.projectInterviewSessions, hasLength(1));
      return aggregate;
    }

    Map<String, dynamic> withSessionZero(
      Map<String, dynamic> envelope,
      Map<String, dynamic> patch,
    ) {
      final aggregate = envelope['aggregate'] as Map<String, dynamic>;
      final workflow = aggregate['workflow'] as Map<String, dynamic>;
      final sessions = (workflow['projectInterviewSessions'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      sessions[0] = {...sessions[0], ...patch};
      return {
        ...envelope,
        'aggregate': {
          ...aggregate,
          'workflow': {...workflow, 'projectInterviewSessions': sessions},
        },
      };
    }

    test('1. an empty questions list is rejected — ClientInterviewSession'
        '.fromJson itself never throws on it, but the dialog\'s own '
        'questions[currentQuestionIndex] indexing would crash on reopen', () {
      final encoded = codec.toJson(readySessionAggregate());
      final malformed = withSessionZero(encoded, {'questions': <dynamic>[]});

      expect(codec.fromJson(malformed), isNull);
    });

    test('2. an out-of-range currentQuestionIndex is rejected', () {
      final aggregate = readySessionAggregate();
      final questionCount = aggregate
          .projectInterviewSessionFor('eng-01')!
          .questions
          .length;
      final encoded = codec.toJson(aggregate);
      final malformed = withSessionZero(encoded, {
        'currentQuestionIndex': questionCount,
      });

      expect(codec.fromJson(malformed), isNull);
    });

    test('3. employeeAnswers falling out of lockstep with '
        'currentQuestionIndex (too few answers for the current question) '
        'is rejected', () {
      final encoded = codec.toJson(readySessionAggregate());
      final malformed = withSessionZero(encoded, {
        'employeeAnswers': <dynamic>[],
      });

      expect(codec.fromJson(malformed), isNull);
    });

    test('4. a playerFollowUps count that violates the progression '
        'invariant (an answer recorded for the current question without '
        'the session having advanced past it) is rejected — this is not a '
        'state chooseFollowUp can ever produce', () {
      final aggregate = readySessionAggregate();
      final session = aggregate.projectInterviewSessionFor('eng-01')!;
      final followUpName = PublicDemoProjectInterview.choicesFor(
        session,
      ).first.name;
      final encoded = codec.toJson(aggregate);
      final malformed = withSessionZero(encoded, {
        'playerFollowUps': [followUpName],
      });

      expect(codec.fromJson(malformed), isNull);
    });

    test('5. a duplicate session for the same employeeId is rejected — '
        'startProjectInterviewSession/projectInterviewSessionFor both '
        'assume at most one session per engineer', () {
      final encoded = codec.toJson(readySessionAggregate());
      final aggregateJson = encoded['aggregate'] as Map<String, dynamic>;
      final workflow = aggregateJson['workflow'] as Map<String, dynamic>;
      final sessions = (workflow['projectInterviewSessions'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      final duplicated = {
        ...encoded,
        'aggregate': {
          ...aggregateJson,
          'workflow': {
            ...workflow,
            'projectInterviewSessions': [...sessions, sessions.first],
          },
        },
      };

      expect(codec.fromJson(duplicated), isNull);
    });

    test('6. a session for an unknown employeeId is rejected', () {
      final aggregate = readySessionAggregate();
      final session = aggregate.projectInterviewSessionFor('eng-01')!;
      const fakeEmployeeId = 'not-a-real-engineer';
      final encoded = codec.toJson(aggregate);
      final malformed = withSessionZero(encoded, {
        'employeeId': fakeEmployeeId,
        'id':
            'public-demo-project-interview:$fakeEmployeeId:'
            '${session.projectId}',
      });

      expect(codec.fromJson(malformed), isNull);
    });

    test('7. a valid, genuine project-interview session round-trips exactly '
        '— this validation rejects nothing a real command path produces', () {
      final aggregate = readySessionAggregate();

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(restored!.workflow.projectInterviewSessions, hasLength(1));
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });

    test('8. a completed (passed) session — playerFollowUps filling every '
        'question while currentQuestionIndex stays pinned at the final '
        'index — still round-trips, proving the progression invariant '
        'correctly accepts the one case where the two lengths legitimately '
        'differ', () {
      var aggregate = readySessionAggregate();
      var session = aggregate.projectInterviewSessionFor('eng-01')!;
      while (session.playerFollowUps.length < session.questions.length) {
        aggregate = aggregate.chooseProjectInterviewFollowUp(
          'eng-01',
          session.currentQuestionIndex,
          PublicDemoProjectInterview.choicesFor(session).first,
        );
        session = aggregate.projectInterviewSessionFor('eng-01')!;
      }
      aggregate = aggregate.concludeProjectInterview('eng-01');
      expect(
        aggregate.projectInterviewSessionFor('eng-01')!.completed,
        isTrue,
      );

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(
        restored!.projectInterviewSessionFor('eng-01')!.completed,
        isTrue,
      );
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });
  });
}

/// Replaces fields on `workflow.engineers[0]` in an already-encoded
/// envelope — mirrors [_copyEnvelope]'s "shallow patch a nested map" shape,
/// one level deeper.
Map<String, dynamic> _withEngineerZero(
  Map<String, dynamic> source,
  Map<String, dynamic> engineerPatch,
) {
  final aggregate = source['aggregate'] as Map<String, dynamic>;
  final workflow = aggregate['workflow'] as Map<String, dynamic>;
  final engineers = (workflow['engineers'] as List)
      .map((entry) => Map<String, dynamic>.from(entry as Map))
      .toList();
  engineers[0] = {...engineers[0], ...engineerPatch};
  return {
    ...source,
    'aggregate': {
      ...aggregate,
      'workflow': {...workflow, 'engineers': engineers},
    },
  };
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
