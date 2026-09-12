import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/engine/client_interview_engine.dart';
import 'package:smile_enjoy_story/game/models/client_interview.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_matching_fit.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_rng.dart';
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
      final withLowScorePass = _withMatchingProposal(
        _withEngineerZero(encoded, {
          'stage': 'clientInterviewPassed',
          'lastInterviewScore': 45,
          'interviewRecordEngineerId': 'eng-01',
          'interviewRecordProjectId': 'project-4-1',
        }),
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );

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
      // A matching proposal for the same project is included so this test
      // isolates the score-ceiling violation specifically — without it, the
      // Codex P2 authority-chain cross-check below would also reject this
      // envelope (no proposal at all for a project-bound pass), masking
      // whether the score check itself still does its own job.
      final withOutOfRangeScore = _withMatchingProposal(
        _withEngineerZero(encoded, {
          'stage': 'clientInterviewPassed',
          'lastInterviewScore': 96,
          'interviewRecordEngineerId': 'eng-01',
          'interviewRecordProjectId': 'project-4-1',
        }),
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );

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

  group('Codex P2 fix (PR #214) "Validate restored passes against their '
      'proposals": a project-bound pass must agree with its (locked) '
      'proposal and, when present, its completed session', () {
    test('record A + proposal B: restore is rejected — a corrupted save '
        'cannot assert a pass on a project the proposal never actually '
        'named', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final mismatched = _withMatchingProposal(
        _withEngineerZero(encoded, {
          'stage': 'clientInterviewPassed',
          'lastInterviewScore': 80,
          'interviewRecordEngineerId': 'eng-01',
          'interviewRecordProjectId': 'project-A',
        }),
        engineerId: 'eng-01',
        projectId: 'project-B',
      );

      expect(codec.fromJson(mismatched), isNull);
    });

    test('record A + proposal A: restore succeeds — the normal, '
        'internally-consistent case', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final consistent = _withMatchingProposal(
        _withEngineerZero(encoded, {
          'stage': 'clientInterviewPassed',
          'lastInterviewScore': 80,
          'interviewRecordEngineerId': 'eng-01',
          'interviewRecordProjectId': 'project-A',
        }),
        engineerId: 'eng-01',
        projectId: 'project-A',
      );

      final restored = codec.fromJson(consistent);

      expect(restored, isNotNull);
      expect(
        restored!.workflow.engineers
            .firstWhere((e) => e.id == 'eng-01')
            .genuineInterviewProjectId,
        'project-A',
      );
    });

    test('a project-bound pass with NO matching proposal at all is '
        'rejected — starting a project interview itself requires a real '
        'proposal, so a genuine pass can never exist without one', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final noProposal = _withEngineerZero(encoded, {
        'stage': 'clientInterviewPassed',
        'lastInterviewScore': 80,
        'interviewRecordEngineerId': 'eng-01',
        'interviewRecordProjectId': 'project-A',
      });

      expect(codec.fromJson(noProposal), isNull);
    });

    test('record A + completed session for project B (proposal otherwise '
        'consistently A): restore is still rejected — the completed '
        'session is the other real, derived fact of which project this '
        'engineer actually interviewed for', () {
      final withProposal = _withMatchingProposal(
        _withEngineerZero(codec.toJson(PublicDemoAggregate.initial()), {
          'stage': 'clientInterviewPassed',
          'lastInterviewScore': 80,
          'interviewRecordEngineerId': 'eng-01',
          'interviewRecordProjectId': 'project-A',
        }),
        engineerId: 'eng-01',
        projectId: 'project-A',
      );
      final aggregate = withProposal['aggregate'] as Map<String, dynamic>;
      final workflow = aggregate['workflow'] as Map<String, dynamic>;
      final withStaleSession = {
        ...withProposal,
        'aggregate': {
          ...aggregate,
          'workflow': {
            ...workflow,
            'projectInterviewSessions': [_completedSessionJson('project-B')],
          },
        },
      };

      expect(codec.fromJson(withStaleSession), isNull);
    });

    test('legacy generic-path pass (interviewRecordProjectId == null) '
        'still round-trips with no matching proposal at all — this '
        'cross-check applies only to project-bound (Phase 6) passes', () {
      var aggregate =
          withLegacyFoundingApplicants(PublicDemoAggregate.initial())
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
              );
      expect(aggregate.workflow.matchingProposals, isEmpty);
      expect(
        aggregate.workflow.engineers.first.genuineInterviewProjectId,
        isNull,
      );

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(
        restored!.workflow.engineers.first.genuineInterviewProjectId,
        isNull,
      );
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });

    test('a genuine end-to-end Phase 6 pass (real proposeMatch + '
        'interview) round-trips normally — nothing a real command path '
        'produces is ever rejected by this cross-check', () {
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
      expect(codec.toJson(restored!), codec.toJson(aggregate));
    });
  });

  group('Codex P2 fix (PR #214) "Reject duplicate proposals before '
      'validating pass bindings": at most one matchingProposals entry per '
      'engineerId', () {
    test('engineer A: a duplicate (project B, then project A) is '
        'rejected — not resolved by either last-write-wins (this lookup) '
        'or first-match-wins (matchingProposalFor, what production code '
        'actually calls)', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final duplicated = _withMatchingProposal(
        _withMatchingProposal(
          encoded,
          engineerId: 'eng-01',
          projectId: 'project-B',
        ),
        engineerId: 'eng-01',
        projectId: 'project-A',
      );

      expect(codec.fromJson(duplicated), isNull);
    });

    test('a duplicate entry for the same engineerId naming the SAME '
        'project is rejected too — a second entry at all is unreachable '
        'from withMatchingProposal, regardless of whether its project '
        'happens to already match', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final duplicated = _withMatchingProposal(
        _withMatchingProposal(
          encoded,
          engineerId: 'eng-01',
          projectId: 'project-A',
        ),
        engineerId: 'eng-01',
        projectId: 'project-A',
      );

      expect(codec.fromJson(duplicated), isNull);
    });

    test('one proposal each for two different engineers restores '
        'normally — the rejection is scoped to a genuine duplicate '
        'engineerId, never to having more than one proposal in the save', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final twoProposals = _withMatchingProposal(
        _withMatchingProposal(
          encoded,
          engineerId: 'eng-01',
          projectId: 'project-A',
        ),
        engineerId: 'eng-02',
        projectId: 'project-B',
      );

      final restored = codec.fromJson(twoProposals);

      expect(restored, isNotNull);
      expect(restored!.matchingProposalFor('eng-01')?.projectId, 'project-A');
      expect(restored.matchingProposalFor('eng-02')?.projectId, 'project-B');
    });

    test('a valid, genuine project-bound pass (single proposal, no '
        'duplicate) still round-trips exactly', () {
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
      expect(codec.toJson(restored!), codec.toJson(aggregate));
    });

    test('a legacy save with no matchingProposals key at all still '
        'decodes — this fix only ever rejects a genuine DUPLICATE entry, '
        'never an absent list', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final aggregate = encoded['aggregate'] as Map<String, dynamic>;
      final workflow = Map<String, dynamic>.from(aggregate['workflow'] as Map)
        ..remove('matchingProposals');
      final legacy = {
        ...encoded,
        'aggregate': {...aggregate, 'workflow': workflow},
      };

      final restored = codec.fromJson(legacy);

      expect(restored, isNotNull);
      expect(restored!.workflow.matchingProposals, isEmpty);
    });
  });

  group('Codex P2 fix (PR #214) "Validate restored accumulated interview '
      'evaluation": recomputed via ClientInterviewEngine.evaluate, never '
      'trusted as-stored', () {
    PublicDemoAggregate readyInProgressAggregate({int runSeed = 1}) {
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
      final session = aggregate.projectInterviewSessionFor('eng-01')!;
      // Answers just the FIRST question, leaving the session genuinely
      // in-progress (not completed) with a real, non-zero
      // accumulatedEvaluation to tamper with below.
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        session.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(session).first,
      );
      return aggregate;
    }

    Map<String, dynamic> withAccumulatedEvaluationPatch(
      Map<String, dynamic> envelope,
      Map<String, dynamic> evaluationPatch,
    ) {
      final aggregate = envelope['aggregate'] as Map<String, dynamic>;
      final workflow = aggregate['workflow'] as Map<String, dynamic>;
      final sessions = (workflow['projectInterviewSessions'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      sessions[0] = {
        ...sessions[0],
        'accumulatedEvaluation': {
          ...Map<String, dynamic>.from(
            sessions[0]['accumulatedEvaluation'] as Map,
          ),
          ...evaluationPatch,
        },
      };
      return {
        ...envelope,
        'aggregate': {
          ...aggregate,
          'workflow': {...workflow, 'projectInterviewSessions': sessions},
        },
      };
    }

    test('a tampered accumulatedEvaluation (an added POSITIVE delta) is '
        'rejected', () {
      final aggregate = readyInProgressAggregate();
      final session = aggregate.projectInterviewSessionFor('eng-01')!;
      final encoded = codec.toJson(aggregate);
      final tampered = withAccumulatedEvaluationPatch(encoded, {
        'technical': session.accumulatedEvaluation.technical + 5,
      });

      expect(codec.fromJson(tampered), isNull);
    });

    test('a tampered accumulatedEvaluation (a subtracted NEGATIVE delta) '
        'is rejected', () {
      final aggregate = readyInProgressAggregate();
      final session = aggregate.projectInterviewSessionFor('eng-01')!;
      final encoded = codec.toJson(aggregate);
      final tampered = withAccumulatedEvaluationPatch(encoded, {
        'credibility': session.accumulatedEvaluation.credibility - 5,
      });

      expect(codec.fromJson(tampered), isNull);
    });

    test('a genuine in-progress session (real, untampered '
        'accumulatedEvaluation) round-trips exactly', () {
      final aggregate = readyInProgressAggregate();

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(codec.toJson(restored!), codec.toJson(aggregate));
    });

    test('a genuine completed (concluded) session round-trips exactly', () {
      var aggregate = readyInProgressAggregate();
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
      expect(codec.toJson(restored!), codec.toJson(aggregate));
    });

    test('seeded interview outcome regression: a genuine pass/fail '
        'derived through the normal chooseFollowUp/conclude path is '
        'unaffected by this recomputation check', () {
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
      final beforeEngineer = aggregate.workflow.engineers.firstWhere(
        (e) => e.id == 'eng-01',
      );

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      final afterEngineer = restored!.workflow.engineers.firstWhere(
        (e) => e.id == 'eng-01',
      );
      expect(afterEngineer.stage, beforeEngineer.stage);
      expect(afterEngineer.lastInterviewScore, beforeEngineer.lastInterviewScore);
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });
  });

  group('Codex P2 fix (PR #214) "Reject restored follow-ups that were '
      'never offered": a recorded playerFollowUps entry must be one of '
      'ClientInterviewEngine.choices for its own question', () {
    PublicDemoAggregate readyInProgressAggregate({int runSeed = 1}) {
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
      final session = aggregate.projectInterviewSessionFor('eng-01')!;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        session.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(session).first,
      );
      return aggregate;
    }

    test('a playerFollowUps entry not among the question\'s offered '
        'choices is rejected even when accumulatedEvaluation is doctored '
        'to exactly match what ClientInterviewEngine.evaluate would '
        'produce for it — the live chooseFollowUp path can never produce '
        'this combination, since it validates choice membership before '
        'ever calling evaluate', () {
      final aggregate = readyInProgressAggregate();
      final session = aggregate.projectInterviewSessionFor('eng-01')!;
      final question = session.questions[0];
      final offered = ClientInterviewEngine.choices(question);
      final notOffered = ClientInterviewFollowUp.values.firstWhere(
        (choice) => !offered.contains(choice),
      );
      final runtime = aggregate.state.runtimeForOrNull('eng-01')!;
      final engineer = PublicDemoEngineerProjectFit.engineerFor(runtime);
      final seed = PublicDemoRng.derivedSeed(
        runSeed: aggregate.state.runSeed,
        month: session.startedWeek,
        namespace: PublicDemoRngNamespace.projectInterview,
        identifier: 'eng-01:${session.projectId}',
      );
      // Recompute what evaluate() would produce for the substituted,
      // never-offered choice, so accumulatedEvaluation is internally
      // "consistent" with playerFollowUps — isolating this test from the
      // separate accumulatedEvaluation-tamper check above; only the new
      // choice-membership check should be what rejects this envelope.
      final outcome = ClientInterviewEngine.evaluate(
        engineer,
        question,
        session.employeeAnswers[0],
        notOffered,
        seed,
        session.id,
      );

      final encoded = codec.toJson(aggregate);
      final aggregateJson = encoded['aggregate'] as Map<String, dynamic>;
      final workflow = aggregateJson['workflow'] as Map<String, dynamic>;
      final sessions = (workflow['projectInterviewSessions'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      sessions[0] = {
        ...sessions[0],
        'playerFollowUps': [notOffered.name],
        'accumulatedEvaluation': {
          'technical': outcome.evaluation.technical,
          'experience': outcome.evaluation.experience,
          'communication': outcome.evaluation.communication,
          'credibility': outcome.evaluation.credibility,
          'clientFit': outcome.evaluation.clientFit,
        },
      };
      final tampered = {
        ...encoded,
        'aggregate': {
          ...aggregateJson,
          'workflow': {...workflow, 'projectInterviewSessions': sessions},
        },
      };

      expect(codec.fromJson(tampered), isNull);
    });

    test('a genuine in-progress session (a genuinely offered follow-up) '
        'round-trips exactly — this check rejects nothing a real command '
        'path produces', () {
      final aggregate = readyInProgressAggregate();

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(codec.toJson(restored!), codec.toJson(aggregate));
    });

    test('a genuine completed session (every follow-up genuinely offered) '
        'round-trips exactly', () {
      var aggregate = readyInProgressAggregate();
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
      expect(codec.toJson(restored!), codec.toJson(aggregate));
    });
  });

  group('Issue #245 Finding #4, Phase 1a: legacy saves survive the strict '
      'round-trip despite the new additive offerCandidates field', () {
    test('a save missing the offerCandidates key entirely (written before '
        'Phase 1a) still decodes rather than being wholesale rejected, when '
        'no engineer is at a relevant legacy stage', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final aggregate = (encoded['aggregate'] as Map<String, dynamic>);
      final workflow = Map<String, dynamic>.from(
        aggregate['workflow'] as Map,
      )..remove('offerCandidates');
      final legacy = {
        ...encoded,
        'aggregate': {...aggregate, 'workflow': workflow},
      };

      final restored = codec.fromJson(legacy);

      expect(restored, isNotNull);
      expect(restored!.workflow.offerCandidates, isEmpty);
    });

    test('a save missing offerCandidates, with an engineer already ordered '
        'via a real matching proposal (the exact class of pre-Phase-1a save '
        'this migration exists for), still decodes — AND the synthesized '
        'candidate this codec never wrote itself still round-trips through '
        'the strict comparison', () {
      var aggregate = PublicDemoAggregate.initial();
      final candidateProject = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidateProject.id,
      );
      aggregate = aggregate
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
          .recordOrder('eng-01');

      final encoded = codec.toJson(aggregate);
      final rawAggregate = (encoded['aggregate'] as Map<String, dynamic>);
      final workflow = Map<String, dynamic>.from(
        rawAggregate['workflow'] as Map,
      )..remove('offerCandidates');
      final legacy = {
        ...encoded,
        'aggregate': {...rawAggregate, 'workflow': workflow},
      };

      final restored = codec.fromJson(legacy);

      expect(restored, isNotNull);
      final synthesized = restored!.workflow.offerCandidateFor(
        'eng-01',
        candidateProject.id,
      );
      expect(synthesized, isNotNull);
      expect(synthesized!.stage.name, 'ordered');
      expect(synthesized.hasGenuineInterviewRecord, isTrue);
      // The migration only ever fires for an ABSENT key: a second decode of
      // this now-current-format save must reproduce byte-identical JSON.
      expect(codec.toJson(restored), codec.toJson(restored));
    });

    test('a save that already carries a real offerCandidates list '
        'round-trips it exactly — the migration only ever fires for an '
        'ABSENT key, never overriding a genuinely-present one', () {
      var aggregate = PublicDemoAggregate.initial();
      final candidateProject = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: candidateProject.id,
      );

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(restored!.workflow.offerCandidates, hasLength(1));
      expect(
        restored.offerCandidateFor('eng-01', candidateProject.id)?.stage.name,
        'proposed',
      );
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });

    test('a forged offerCandidates entry that disagrees with what '
        'PublicDemoAggregate.fromJson itself would validate is rejected '
        'outright, exactly like any other authority-significant field this '
        'codec already guards', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final aggregate = (encoded['aggregate'] as Map<String, dynamic>);
      final workflow = Map<String, dynamic>.from(
        aggregate['workflow'] as Map,
      );
      workflow['offerCandidates'] = [
        {
          'engineerId': 'not-a-real-engineer',
          'projectId': 'project-4-1',
          'proposedMonth': 4,
          'stage': 'proposed',
          'partnerScore': null,
          'clientScore': null,
          'interviewRecordEngineerId': null,
          'interviewRecordProjectId': null,
        },
      ];
      final forged = {
        ...encoded,
        'aggregate': {...aggregate, 'workflow': workflow},
      };

      expect(codec.fromJson(forged), isNull);
    });

    test('Codex review fix (PR #254 P2): an offerCandidates entry claiming '
        'a genuine interviewRecord (identity matches its own engineerId/'
        'projectId) with an implausible clientScore below '
        'PublicDemoInterviewEvaluator\'s real pass floor is rejected — a '
        'hand-edited save cannot fabricate a passing client interview that '
        'never actually happened merely by matching the identity fields', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final aggregate = (encoded['aggregate'] as Map<String, dynamic>);
      final workflow = Map<String, dynamic>.from(
        aggregate['workflow'] as Map,
      );
      workflow['offerCandidates'] = [
        {
          'engineerId': 'eng-01',
          'projectId': 'project-4-1',
          'proposedMonth': 4,
          'stage': 'clientInterviewPassed',
          'partnerScore': 80,
          // Implausible: PublicDemoInterviewEvaluator never mints a genuine
          // pass below 60 — this score could only ever come from a real
          // fail, which never mints an interviewRecord.
          'clientScore': 10,
          'interviewRecordEngineerId': 'eng-01',
          'interviewRecordProjectId': 'project-4-1',
        },
      ];
      final forged = {
        ...encoded,
        'aggregate': {...aggregate, 'workflow': workflow},
      };

      expect(codec.fromJson(forged), isNull);
    });

    test('a duplicate offerCandidates entry for the same '
        '(engineerId, projectId) is rejected at the raw-envelope '
        'pre-check', () {
      final encoded = codec.toJson(PublicDemoAggregate.initial());
      final aggregate = (encoded['aggregate'] as Map<String, dynamic>);
      final workflow = Map<String, dynamic>.from(
        aggregate['workflow'] as Map,
      );
      final entry = {
        'engineerId': 'eng-01',
        'projectId': 'project-4-1',
        'proposedMonth': 4,
        'stage': 'proposed',
        'partnerScore': null,
        'clientScore': null,
        'interviewRecordEngineerId': null,
        'interviewRecordProjectId': null,
      };
      workflow['offerCandidates'] = [entry, entry];
      final forged = {
        ...encoded,
        'aggregate': {...aggregate, 'workflow': workflow},
      };

      expect(codec.fromJson(forged), isNull);
    });

    test('a genuine end-to-end offer-candidate client pass (real evaluator, '
        'score >= 60, minted only via '
        'PublicDemoAggregate.evaluateClientInterviewForCandidate) round-'
        'trips normally — this check rejects nothing a real command path '
        'produces', () {
      var aggregate = PublicDemoAggregate.initial();
      final candidateProject = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate
          .proposeOfferCandidate(
            engineerId: 'eng-01',
            projectId: candidateProject.id,
          )
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: candidateProject.id,
          )
          .evaluateClientInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: candidateProject.id,
          );
      expect(
        aggregate.offerCandidateFor('eng-01', candidateProject.id)?.stage.name,
        'clientInterviewPassed',
      );

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(codec.toJson(restored!), codec.toJson(aggregate));
    });
  });
}

/// A minimal, hand-crafted completed `ClientInterviewSession` JSON entry for
/// [projectId] — satisfies every structural invariant the Codex P2-1 fix's
/// own validation block checks (non-empty questions, matching lengths, a
/// genuine `result`), so a test using this exercises ONLY the P2
/// authority-chain cross-check this group is about, never the unrelated
/// P2-1 structural checks.
Map<String, dynamic> _completedSessionJson(String projectId) => {
  'id': 'public-demo-project-interview:eng-01:$projectId',
  'applicationId': projectId,
  'employeeId': 'eng-01',
  'projectId': projectId,
  'clientId': 'client-for-$projectId',
  'startedWeek': 4,
  'currentQuestionIndex': 0,
  'questions': [
    {
      'category': 'technicalExperience',
      'text': 'q',
      'target': 't',
      'mismatch': 0,
    },
  ],
  'employeeAnswers': [
    {'text': 'a', 'quality': 3, 'vague': false},
  ],
  'playerFollowUps': ['emphasizeTechnical'],
  'interviewerReactions': ['reaction'],
  'accumulatedEvaluation': {
    'technical': 0,
    'experience': 0,
    'communication': 0,
    'credibility': 0,
    'clientFit': 0,
  },
  'completed': true,
  'deepDiveOccurred': false,
  'mismatchFailure': false,
  'deepDiveText': null,
  'result': 'passed',
  'step': 'clientInterview',
};

/// Adds a `PublicDemoMatchingProposal` entry for `(engineerId, projectId)`
/// to an already-encoded envelope's `workflow.matchingProposals` — mirrors
/// [_withEngineerZero]'s own "shallow patch a nested map" shape.
Map<String, dynamic> _withMatchingProposal(
  Map<String, dynamic> source, {
  required String engineerId,
  required String projectId,
  int decidedMonth = 1,
}) {
  final aggregate = source['aggregate'] as Map<String, dynamic>;
  final workflow = aggregate['workflow'] as Map<String, dynamic>;
  final proposals = ((workflow['matchingProposals'] as List?) ?? [])
      .map((entry) => Map<String, dynamic>.from(entry as Map))
      .toList()
    ..add({
      'engineerId': engineerId,
      'projectId': projectId,
      'decidedMonth': decidedMonth,
    });
  return {
    ...source,
    'aggregate': {
      ...aggregate,
      'workflow': {...workflow, 'matchingProposals': proposals},
    },
  };
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
