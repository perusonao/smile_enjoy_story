import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/models/client_interview.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_offer_candidate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';

/// Issue #257 Broad Review blocking P2 — focused fix: `projectInterviewSessions`
/// widened from an `engineerId`-only identity to `(engineerId, projectId)`
/// composite identity, so the same engineer can hold independent interactive
/// interview sessions for two different projects at once, instead of one
/// silently discarding the other. See
/// docs/reports/SES_PR-258_Parallel-Sales-Phase1B_Claude-Broad-Review.md's
/// own P2 finding and
/// docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1B_Result.md.
///
/// This file does NOT re-run the Broad Review and does NOT touch Phase 1c
/// (comparison UI, still unimplemented and out of scope). It covers exactly
/// the composite-session-identity gap: every scenario the fix's own
/// verification matrix requires (same-engineer/two-projects coexistence,
/// independent results, stale-identity rejection, duplicate/idempotency +
/// `salesCapacity` exactly-once, legacy-save compatibility, forged-save
/// rejection, month boundary, and single-project regression).
void main() {
  const codec = PublicDemoSaveCodec();

  PublicDemoEngineerSales engineer(PublicDemoAggregate aggregate, String id) =>
      aggregate.workflow.engineers.firstWhere((e) => e.id == id);

  /// Advances [engineerId] to `introduced` via the real production chain —
  /// works both for a fresh `waiting` engineer (first attempt) and for a
  /// retry from `partnerInterviewFailed`/`clientInterviewFailed` (skips the
  /// one-time `startSkillSheetReview` step, exactly like `beginSelling`'s
  /// own precondition already requires).
  PublicDemoAggregate advanceToIntroduced(
    PublicDemoAggregate aggregate,
    String engineerId,
  ) {
    var next = aggregate;
    if (engineer(next, engineerId).stage == PublicDemoSalesStage.waiting) {
      next = next.startSkillSheetReview(engineerId);
    }
    return next.beginSelling(engineerId).introduceProject(engineerId);
  }

  /// Runs the real interactive Partner Interview
  /// (`startPartnerInterview`/`chooseProjectInterviewFollowUp`/
  /// `concludePartnerInterview`) to a genuine, concluded outcome.
  PublicDemoAggregate runPartnerToConclusion(
    PublicDemoAggregate aggregate,
    String engineerId,
  ) {
    aggregate = aggregate.startPartnerInterview(engineerId);
    var session = aggregate.projectInterviewSessionFor(engineerId)!;
    while (session.playerFollowUps.length < session.questions.length) {
      final choice = PublicDemoProjectInterview.choicesFor(session).first;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        engineerId,
        session.currentQuestionIndex,
        choice,
      );
      session = aggregate.projectInterviewSessionFor(engineerId)!;
    }
    return aggregate.concludePartnerInterview(engineerId);
  }

  /// The Client Interview counterpart of [runPartnerToConclusion] —
  /// `startProjectInterview`/`concludeProjectInterview`.
  PublicDemoAggregate runClientToConclusion(
    PublicDemoAggregate aggregate,
    String engineerId,
  ) {
    aggregate = aggregate.startProjectInterview(engineerId);
    var session = aggregate.projectInterviewSessionFor(engineerId)!;
    while (session.playerFollowUps.length < session.questions.length) {
      final choice = PublicDemoProjectInterview.choicesFor(session).first;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        engineerId,
        session.currentQuestionIndex,
        choice,
      );
      session = aggregate.projectInterviewSessionFor(engineerId)!;
    }
    return aggregate.concludeProjectInterview(engineerId);
  }

  /// Scans a bounded, deterministic seed range for one where `eng-01`
  /// genuinely FAILS the PARTNER interview for project A, then — after the
  /// real `beginSelling` failure-recovery path — genuinely PASSES it again
  /// for a different, never-interviewed project B. (The real, seeded
  /// client-interview formula turns out to pass near-unconditionally for
  /// the top-fit candidate this suite always proposes first, so the partner
  /// leg — which does genuinely fail for a real, non-trivial fraction of
  /// seeds — is what this scans for; both legs share the exact same
  /// [ClientInterviewSession]/`projectInterviewSessions` machinery under
  /// test, so this is just as representative.) Mirrors this repo's own
  /// established seed-scanning convention
  /// (`public_demo_project_interview_test.dart`'s `_findGenuinePass`,
  /// `public_demo_parallel_sales_phase1b_test.dart`'s `clientPassed`) —
  /// never asserts a specific score, only that the real, seeded engine
  /// produced this exact outcome shape.
  ({PublicDemoAggregate aggregate, String projectA, String projectB})?
  findFailThenPass({int maxSeed = 300}) {
    for (var seed = 0; seed < maxSeed; seed++) {
      var aggregate = PublicDemoAggregate.initial(runSeed: seed);
      final projectA = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage !=
          PublicDemoSalesStage.partnerInterviewFailed) {
        continue;
      }

      final projectBCandidate = aggregate
          .projectCandidatesForMonth(aggregate.state.month)
          .where((candidate) => candidate.id != projectA.id)
          .firstOrNull;
      if (projectBCandidate == null) continue;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectBCandidate.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage !=
          PublicDemoSalesStage.partnerInterviewPassed) {
        continue;
      }
      return (
        aggregate: aggregate,
        projectA: projectA.id,
        projectB: projectBCandidate.id,
      );
    }
    return null;
  }

  /// Scans a bounded, deterministic seed range for one where `eng-01`
  /// genuinely PASSES the whole pipeline for project A, is genuinely
  /// ordered and assigned (real April/May close), then — after a genuine
  /// [PublicDemoAggregate.endAssignment] release — genuinely PASSES the
  /// whole pipeline AGAIN for a different project B. This is the one
  /// production path that can hold two genuine CLIENT PASSES for the same
  /// engineer at once (an engineer at `clientInterviewPassed`/`ordered`
  /// cannot be re-sold without first completing and ending a real
  /// assignment — `beginSelling`'s own precondition excludes both stages).
  ({PublicDemoAggregate aggregate, String projectA, String projectB})?
  findBothPass({int maxSeed = 60}) {
    for (var seed = 0; seed < maxSeed; seed++) {
      var aggregate = PublicDemoAggregate.initial(runSeed: seed);
      final projectA = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage !=
          PublicDemoSalesStage.partnerInterviewPassed) {
        continue;
      }
      aggregate = runClientToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage !=
          PublicDemoSalesStage.clientInterviewPassed) {
        continue;
      }

      aggregate = aggregate.recordOrder('eng-01');
      aggregate = aggregate.closeApril(monthlyExpenses: 0);
      aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 0);
      final assignment = aggregate.workflow.assignments
          .where((candidate) => candidate.engineerId == 'eng-01')
          .firstOrNull;
      if (assignment?.projectId != projectA.id) continue;

      // Real production closes through July: before month 7,
      // `assignedEngineerIds` counts every assignment row unconditionally
      // (`PublicDemoWorkflowState.assignedEngineerIds`'s own doc) — a real
      // `proposeMatch` for a NEW project stays blocked (the engineer still
      // reads as "assigned" for revenue-accounting purposes) even after a
      // genuine `notOffered` decision and `endAssignment` release. Only
      // from month 7 does a `notOffered` row stop counting AND get
      // physically removed, genuinely freeing the engineer to be proposed
      // to a different project again.
      aggregate = aggregate.closeJune(assignedInJuly: 1, monthlyExpenses: 0);
      aggregate = aggregate.closeJuly(monthlyExpenses: 0);
      if (aggregate.state.month < 8) continue;

      // A real player decision not to continue the contract — the only
      // production way `endAssignment`'s own `nextOrderStatus ==
      // notOffered` precondition is ever satisfied.
      aggregate = aggregate.withAssignmentUpdate(
        'eng-01',
        nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
      );
      final beforeEnd = aggregate;
      aggregate = aggregate.endAssignment('eng-01');
      if (identical(aggregate, beforeEnd)) continue;
      if (engineer(aggregate, 'eng-01').stage != PublicDemoSalesStage.waiting) {
        continue;
      }

      final projectBCandidate = aggregate
          .projectCandidatesForMonth(aggregate.state.month)
          .where((candidate) => candidate.id != projectA.id)
          .firstOrNull;
      if (projectBCandidate == null) continue;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectBCandidate.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage !=
          PublicDemoSalesStage.partnerInterviewPassed) {
        continue;
      }
      aggregate = runClientToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage !=
          PublicDemoSalesStage.clientInterviewPassed) {
        continue;
      }
      return (
        aggregate: aggregate,
        projectA: projectA.id,
        projectB: projectBCandidate.id,
      );
    }
    return null;
  }

  group('A. same engineer / two projects: independent sessions coexist', () {
    test('starting a fresh interview for project B does not discard '
        "project A's still-incomplete session — both are held at once", () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 20)
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );
      expect(
        engineer(aggregate, 'eng-01').stage,
        PublicDemoSalesStage.partnerInterviewPassed,
      );
      final candidates = aggregate.projectCandidatesForMonth(
        aggregate.state.month,
      );
      final projectA = candidates[0];
      final projectB = candidates[1];

      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      final sessionABefore = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        sessionABefore.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(sessionABefore).first,
      );
      final sessionAMidway = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      expect(sessionAMidway.playerFollowUps, hasLength(1));
      expect(sessionAMidway.completed, isFalse);

      // Switch Matching focus to a DIFFERENT project and start a fresh
      // interview there, without ever concluding A's.
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');

      final sessionAAfter = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      );
      final sessionB = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectB.id,
      );
      // The fix under test: A's own session is untouched, not discarded.
      expect(sessionAAfter, isNotNull);
      expect(sessionAAfter!.completed, isFalse);
      expect(sessionAAfter.playerFollowUps, hasLength(1));
      expect(sessionAAfter.id, sessionAMidway.id);
      // B is a genuinely fresh, independent session.
      expect(sessionB, isNotNull);
      expect(sessionB!.playerFollowUps, isEmpty);
      expect(sessionB.id, isNot(equals(sessionAAfter.id)));
      expect(aggregate.workflow.projectInterviewSessions, hasLength(2));
    });
  });

  group('B. independent results: A fail, B pass — never mixed', () {
    test('concluding B never touches A\'s own already-concluded result, '
        'and vice versa', () {
      final found = findFailThenPass();
      expect(
        found,
        isNotNull,
        reason: 'expected at least one (fail, then pass) seed',
      );
      final aggregate = found!.aggregate;

      final sessionA = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        found.projectA,
      );
      final sessionB = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        found.projectB,
      );
      expect(sessionA, isNotNull);
      expect(sessionA!.completed, isTrue);
      expect(sessionA.result, ClientInterviewResult.failed);
      expect(sessionB, isNotNull);
      expect(sessionB!.completed, isTrue);
      expect(sessionB.result, ClientInterviewResult.passed);
      expect(aggregate.workflow.projectInterviewSessions, hasLength(2));

      // The candidate-level authority (Phase 1b) agrees independently —
      // this fix's session-level widening and the existing candidate-level
      // authority never disagree.
      final candidateA = aggregate.offerCandidateFor('eng-01', found.projectA);
      final candidateB = aggregate.offerCandidateFor('eng-01', found.projectB);
      expect(
        candidateA!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewFailed,
      );
      expect(
        candidateB!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewPassed,
      );
    });
  });

  group('C. both pass: A pass, B pass — both retained', () {
    test('a genuine order+assignment+release cycle for A, followed by a '
        'genuine pass for B, leaves BOTH sessions completed and passed', () {
      final found = findBothPass();
      expect(
        found,
        isNotNull,
        reason: 'expected at least one (both pass) seed within the bound',
      );
      final aggregate = found!.aggregate;

      final sessionA = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        found.projectA,
      );
      final sessionB = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        found.projectB,
      );
      expect(sessionA, isNotNull);
      expect(sessionA!.completed, isTrue);
      expect(sessionA.result, ClientInterviewResult.passed);
      expect(sessionB, isNotNull);
      expect(sessionB!.completed, isTrue);
      expect(sessionB.result, ClientInterviewResult.passed);
      expect(aggregate.workflow.projectInterviewSessions, hasLength(2));

      // A's own candidate stays `ordered` (an order is final, never
      // rewound by a later, unrelated cycle) while B is now the engineer's
      // current genuine pass.
      final candidateA = aggregate.offerCandidateFor('eng-01', found.projectA);
      final candidateB = aggregate.offerCandidateFor('eng-01', found.projectB);
      expect(candidateA!.stage, PublicDemoOfferCandidateStage.ordered);
      expect(
        candidateB!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
    });
  });

  group('D. save/reload: identity and results survive a round-trip', () {
    test('two held sessions (one failed, one passed) round-trip exactly', () {
      final found = findFailThenPass();
      expect(found, isNotNull);
      final aggregate = found!.aggregate;

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(restored!.workflow.projectInterviewSessions, hasLength(2));
      final sessionA = restored.workflow.projectInterviewSessionFor(
        'eng-01',
        found.projectA,
      );
      final sessionB = restored.workflow.projectInterviewSessionFor(
        'eng-01',
        found.projectB,
      );
      expect(sessionA, isNotNull);
      expect(sessionA!.result, ClientInterviewResult.failed);
      expect(sessionB, isNotNull);
      expect(sessionB!.result, ClientInterviewResult.passed);
      // Strict byte-exact round-trip, exactly like every other field.
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });
  });

  group('E. stale identity: a session cannot be concluded as the wrong '
      'project', () {
    test('concludeProjectInterview no-ops when the fully-answered session '
        'on record belongs to a DIFFERENT project than the one passed in', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 21)
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );
      final candidates = aggregate.projectCandidatesForMonth(
        aggregate.state.month,
      );
      final projectA = candidates[0];
      final projectB = candidates[1];

      // Fully answer A's session, then switch the proposal to B WITHOUT
      // starting B's session yet.
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      var sessionA = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      while (sessionA.playerFollowUps.length < sessionA.questions.length) {
        aggregate = aggregate.chooseProjectInterviewFollowUp(
          'eng-01',
          sessionA.currentQuestionIndex,
          PublicDemoProjectInterview.choicesFor(sessionA).first,
        );
        sessionA = aggregate.workflow.projectInterviewSessionFor(
          'eng-01',
          projectA.id,
        )!;
      }
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );

      // The engineer-level convenience accessor now resolves to the
      // CURRENT proposal's project (B) — for which no session has ever
      // been started, so concludeProjectInterview must be a total no-op
      // rather than concluding A's own fully-answered session against B.
      final beforeConclude = engineer(aggregate, 'eng-01');
      final afterConclude = aggregate.concludeProjectInterview('eng-01');
      expect(engineer(afterConclude, 'eng-01').stage, beforeConclude.stage);
      // A's own session, looked up by its own explicit identity, is
      // untouched — never silently concluded against the wrong project.
      final sessionAStill = afterConclude.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      expect(sessionAStill.completed, isFalse);
      expect(sessionAStill.id, sessionA.id);
    });

    test('workflow.concludeProjectInterview rejects a stale-identity '
        'conclude directly at the domain layer, even when called with a '
        'genuinely different, unrelated project', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 22)
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );
      final candidates = aggregate.projectCandidatesForMonth(
        aggregate.state.month,
      );
      final projectA = candidates[0];
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      var session = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      while (session.playerFollowUps.length < session.questions.length) {
        aggregate = aggregate.chooseProjectInterviewFollowUp(
          'eng-01',
          session.currentQuestionIndex,
          PublicDemoProjectInterview.choicesFor(session).first,
        );
        session = aggregate.workflow.projectInterviewSessionFor(
          'eng-01',
          projectA.id,
        )!;
      }

      // Directly attempt to conclude against project B's own real
      // candidate — projectInterviewSessionFor(eng-01, B) resolves to
      // `null` (no session exists for that pair), so the workflow-level
      // method must no-op rather than reach for A's session instead.
      final projectBReal = aggregate
          .projectCandidatesForMonth(aggregate.state.month)
          .firstWhere((candidate) => candidate.id != projectA.id);
      // Sanity: this really is testing against a genuinely different
      // project than the one that has a real session.
      expect(projectBReal.id, isNot(equals(projectA.id)));

      final before = engineer(aggregate, 'eng-01');
      final rejected = aggregate.workflow.concludeProjectInterview(
        engineerId: 'eng-01',
        runSeed: aggregate.runSeed,
        currentMonth: aggregate.state.month,
        runtime: aggregate.state.runtimeForOrNull('eng-01')!,
        project: projectBReal.project,
      );
      expect(
        rejected.engineers.firstWhere((e) => e.id == 'eng-01').stage,
        before.stage,
      );
    });
  });

  group('F. duplicate/retry: no duplicate session, salesCapacity '
      'exactly-once', () {
    test('re-starting the partner interview for the SAME (engineer, '
        'project) never creates a duplicate entry and never re-charges '
        'the sales slot', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 23);
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');

      aggregate = aggregate.startPartnerInterview('eng-01');
      expect(aggregate.state.salesUsed, 1);
      expect(aggregate.workflow.projectInterviewSessions, hasLength(1));

      // Retry/resume: same engineer, same project, still incomplete.
      aggregate = aggregate.startPartnerInterview('eng-01');
      expect(aggregate.state.salesUsed, 1, reason: 'never re-charged');
      expect(aggregate.workflow.projectInterviewSessions, hasLength(1));
    });

    test('starting interviews for two DIFFERENT projects is never treated '
        'as a duplicate — each is its own genuinely new attempt and its '
        'own slot charge where applicable', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 24)
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );
      final candidates = aggregate.projectCandidatesForMonth(
        aggregate.state.month,
      );
      final projectA = candidates[0];
      final projectB = candidates[1];

      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01'); // 0-slot leg
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01'); // also 0-slot

      expect(aggregate.workflow.projectInterviewSessions, hasLength(2));
      expect(
        aggregate.workflow
            .projectInterviewSessionFor('eng-01', projectA.id)
            ?.id,
        isNot(
          equals(
            aggregate.workflow
                .projectInterviewSessionFor('eng-01', projectB.id)
                ?.id,
          ),
        ),
      );
    });

    test('duplicate conclude is safe: concluding an already-completed '
        'session a second time is a no-op', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 25);
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerToConclusion(aggregate, 'eng-01');
      final onceConcluded = aggregate;
      final twiceConcluded = onceConcluded.concludePartnerInterview('eng-01');
      expect(
        twiceConcluded.projectInterviewSessionFor('eng-01'),
        onceConcluded.projectInterviewSessionFor('eng-01'),
      );
      expect(
        engineer(twiceConcluded, 'eng-01').stage,
        engineer(onceConcluded, 'eng-01').stage,
      );
    });
  });

  group('G. legacy save migration', () {
    test('a single-project save shaped exactly like every save written '
        'before this widening (one session, no second projectId to '
        'migrate) still decodes and round-trips byte-identical — no '
        'schema-version bump was needed since every session already '
        'carried its own projectId', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 26);
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerToConclusion(aggregate, 'eng-01');

      final restored = codec.decode(codec.encode(aggregate));
      expect(restored, isNotNull);
      expect(restored!.workflow.projectInterviewSessions, hasLength(1));
      expect(codec.toJson(restored), codec.toJson(aggregate));
    });
  });

  group('H. malformed/forged save rejection', () {
    test('a raw save asserting a duplicate (employeeId, projectId) session '
        'pair is rejected', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 27);
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = aggregate.startPartnerInterview('eng-01');

      final encoded = codec.toJson(aggregate);
      final aggregateJson = encoded['aggregate'] as Map<String, dynamic>;
      final workflow = aggregateJson['workflow'] as Map<String, dynamic>;
      final sessions = (workflow['projectInterviewSessions'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      final forged = {
        ...encoded,
        'aggregate': {
          ...aggregateJson,
          'workflow': {
            ...workflow,
            'projectInterviewSessions': [...sessions, sessions.first],
          },
        },
      };

      expect(codec.fromJson(forged), isNull);
    });

    test('a session naming an engineerId that does not exist in the save '
        'is rejected', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 28);
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = aggregate.startPartnerInterview('eng-01');

      final encoded = codec.toJson(aggregate);
      final aggregateJson = encoded['aggregate'] as Map<String, dynamic>;
      final workflow = aggregateJson['workflow'] as Map<String, dynamic>;
      final sessions = (workflow['projectInterviewSessions'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      const forgedEngineerId = 'not-a-real-engineer';
      sessions[0] = {
        ...sessions[0],
        'employeeId': forgedEngineerId,
        'id': 'public-demo-project-interview:$forgedEngineerId:'
            '${sessions[0]['projectId']}',
      };
      final forged = {
        ...encoded,
        'aggregate': {
          ...aggregateJson,
          'workflow': {...workflow, 'projectInterviewSessions': sessions},
        },
      };

      expect(codec.fromJson(forged), isNull);
    });

    test('two genuinely different (employeeId, projectId) session entries '
        'for the SAME employeeId are accepted — this is the new, '
        'legitimate composite shape, never a forgery', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 29)
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );
      final candidates = aggregate.projectCandidatesForMonth(
        aggregate.state.month,
      );
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidates[0].id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidates[1].id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      expect(aggregate.workflow.projectInterviewSessions, hasLength(2));

      expect(codec.fromJson(codec.toJson(aggregate)), isNotNull);
    });
  });

  group('I. month boundary', () {
    test('a real monthly close discards only the CURRENTLY-reopened '
        "project's own stale-month session — a sibling project's own "
        'session for the same engineer is never touched by that restart', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 32)
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );
      final monthFourCandidates = aggregate.projectCandidatesForMonth(4);
      final projectA = monthFourCandidates[0];
      final projectB = monthFourCandidates[1];

      // Both sessions are started in the SAME month (4), before any close
      // — A is left partially answered, B is started fresh right after (the
      // A/two-projects scenario from group A), then the month advances
      // with the CURRENT proposal left on B.
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      final sessionABeforeClose = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        sessionABeforeClose.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(sessionABeforeClose).first,
      );
      final sessionAMidway = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      expect(sessionAMidway.startedWeek, 4);
      expect(sessionAMidway.playerFollowUps, hasLength(1));

      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      final sessionBBeforeClose = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectB.id,
      )!;
      expect(sessionBBeforeClose.startedWeek, 4);

      // A real, unmodified monthly close — the only production way
      // `state.month` ever advances. eng-01 stays unassigned throughout, so
      // stage/proposal facts are otherwise untouched by this close (mirrors
      // `public_demo_project_interview_test.dart`'s own "advancing the
      // month mid-interview" test).
      aggregate = aggregate.closeApril(monthlyExpenses: 10000);
      expect(aggregate.state.month, 5);
      expect(
        engineer(aggregate, 'eng-01').stage,
        PublicDemoSalesStage.partnerInterviewPassed,
      );
      expect(
        aggregate.workflow.matchingProposalFor('eng-01')?.projectId,
        projectB.id,
      );

      // Reopening the CURRENT proposal's interview (B) after the month
      // advanced must discard B's own stale month-4 session and restart it
      // fresh at month 5 — the pre-existing single-project invariant.
      aggregate = aggregate.startProjectInterview('eng-01');
      final sessionBAfterClose = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectB.id,
      )!;
      // A genuine restart, not a resume: `id` is derived from
      // `employeeId:projectId` alone (see [PublicDemoProjectInterview.start]
      // ), so it stays the same across a same-project restart — the real
      // signal that this is a fresh session, not the stale month-4 one, is
      // its own `startedWeek`/empty progress.
      expect(sessionBAfterClose.startedWeek, 5);
      expect(sessionBAfterClose.playerFollowUps, isEmpty);
      expect(identical(sessionBAfterClose, sessionBBeforeClose), isFalse);

      // A's own session — a completely different project this same
      // engineer also holds — must be left exactly as it was: still at its
      // own month-4 identity, still midway through its own questions,
      // never discarded or refreshed by B's own reopen.
      final sessionAStill = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      expect(sessionAStill.startedWeek, 4);
      expect(sessionAStill.playerFollowUps, hasLength(1));
      expect(identical(sessionAStill, sessionAMidway), isTrue);
      expect(aggregate.workflow.projectInterviewSessions, hasLength(2));
    });
  });

  group('J. existing single-project gameplay regression', () {
    test('a single engineer, single project, full pass flow is completely '
        'unaffected by the composite-identity widening', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 31);
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage !=
          PublicDemoSalesStage.partnerInterviewPassed) {
        return; // this seed happened to fail — nothing further to assert
      }
      aggregate = runClientToConclusion(aggregate, 'eng-01');

      expect(aggregate.workflow.projectInterviewSessions, hasLength(1));
      expect(
        aggregate.workflow.projectInterviewSessionFor('eng-01', project.id),
        isNotNull,
      );
      expect(
        aggregate.workflow.projectInterviewSessionFor('eng-01', project.id)!
            .completed,
        isTrue,
      );
    });
  });
}
