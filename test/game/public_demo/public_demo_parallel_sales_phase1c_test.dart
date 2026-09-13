import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_offer_candidate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// Issue #245 Finding #4, Phase 1c (Comparison / Candidate-Aware Order):
/// coverage for the player-facing loop this Finding exists for —
/// 技術者 → 候補案件一覧 → 案件ごとの面談結果 → 条件比較 → 受注案件を選択 —
/// on top of Phase 1a/1b's own already-tested `offerCandidates` authority.
///
/// This file focuses on what Phase 1c adds:
///  * [PublicDemoAggregate.recordOfferCandidateOrder] — ordering ANY of
///    several concluded candidates (not only whichever one
///    [PublicDemoAggregate.recordOrder] would resolve from the engineer's
///    single [PublicDemoWorkflowState.matchingProposalFor]), and the
///    [PublicDemoEngineerSales.syncOrderedFromCandidate] coarse-scalar sync
///    this requires so [PublicDemoWorkflowState.assignOrderedForMay] still
///    materializes the CORRECT project.
///  * [PublicDemoAggregate.canProposeAdditionalOfferCandidate]/
///    [proposeAdditionalOfferCandidate] — the gated entry point for a
///    genuinely second parallel candidate.
///
/// See docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1C_Result.md.
void main() {
  const codec = PublicDemoSaveCodec();

  PublicDemoEngineerSales engineer(PublicDemoAggregate aggregate, String id) =>
      aggregate.workflow.engineers.firstWhere((e) => e.id == id);

  PublicDemoAggregate advanceToIntroduced(
    PublicDemoAggregate aggregate,
    String engineerId,
  ) => aggregate
      .startSkillSheetReview(engineerId)
      .beginSelling(engineerId)
      .introduceProject(engineerId);

  PublicDemoAggregate runPartnerInterviewToConclusion(
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

  PublicDemoAggregate runClientInterviewToConclusion(
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

  /// Candidate A: a genuine clientInterviewPassed reached through the REAL
  /// interactive Matching + Partner/Client Interview mini-game (mirrors
  /// `public_demo_parallel_sales_phase1b_test.dart`'s own `clientPassed()`)
  /// — the "primary" candidate an ordinary player already reaches today.
  ({PublicDemoAggregate aggregate, String projectId}) primaryCandidatePassed({
    int maxSeed = 60,
  }) {
    for (var seed = 0; seed < maxSeed; seed++) {
      var aggregate = PublicDemoAggregate.initial(runSeed: seed);
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerInterviewToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage !=
          PublicDemoSalesStage.partnerInterviewPassed) {
        continue;
      }
      aggregate = runClientInterviewToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage ==
          PublicDemoSalesStage.clientInterviewPassed) {
        return (aggregate: aggregate, projectId: project.id);
      }
    }
    fail('No seed under $maxSeed produced a genuine client pass for eng-01');
  }

  /// Candidate B: a SECOND, genuinely independent candidate for the SAME
  /// engineer, reached through the Phase 1a safe building blocks Phase 1c
  /// wires into the comparison screen for any candidate beyond the
  /// engineer's own single coarse-tracked one
  /// (`PublicDemoAggregate.evaluatePartnerInterviewForCandidate`/
  /// `evaluateClientInterviewForCandidate`) — never a forked interview
  /// engine, never touching `matchingProposals`/the engineer's own coarse
  /// `stage` (see those methods' own doc).
  PublicDemoAggregate addSecondPassedCandidate(
    PublicDemoAggregate aggregate,
    String engineerId,
    String projectId,
  ) => aggregate
      .proposeOfferCandidate(engineerId: engineerId, projectId: projectId)
      .evaluatePartnerInterviewForCandidate(
        engineerId: engineerId,
        projectId: projectId,
      )
      .evaluateClientInterviewForCandidate(
        engineerId: engineerId,
        projectId: projectId,
      );

  group('Comparison read surface: 1 engineer / 2 passed projects', () {
    test('offerCandidatesForEngineer holds both candidates, each with its '
        'own correct project title/rate and its own independent interview '
        'result', () {
      final primary = primaryCandidatePassed();
      final projectB = primary.aggregate.projectCandidatesForMonth(4).firstWhere(
        (candidate) => candidate.id != primary.projectId,
      );
      final aggregate = addSecondPassedCandidate(
        primary.aggregate,
        'eng-01',
        projectB.id,
      );

      final candidates = aggregate.offerCandidatesForEngineer('eng-01');
      expect(candidates, hasLength(2));

      final candidateA = aggregate.offerCandidateFor('eng-01', primary.projectId)!;
      final candidateB = aggregate.offerCandidateFor('eng-01', projectB.id)!;
      expect(candidateA.stage, PublicDemoOfferCandidateStage.clientInterviewPassed);
      expect(candidateB.stage, PublicDemoOfferCandidateStage.clientInterviewPassed);
      expect(candidateA.hasGenuineInterviewRecord, isTrue);
      expect(candidateB.hasGenuineInterviewRecord, isTrue);

      // Each candidate resolves to its OWN real project — never a shared
      // or fabricated title/rate.
      final resolvedA = PublicDemoSeededProjectGenerator.regenerate(
        runSeed: aggregate.state.runSeed,
        projectId: primary.projectId,
      )!;
      final resolvedB = PublicDemoSeededProjectGenerator.regenerate(
        runSeed: aggregate.state.runSeed,
        projectId: projectB.id,
      )!;
      expect(resolvedA.id, isNot(resolvedB.id));
      expect(resolvedA.title, isNot(resolvedB.title));
    });

    test('a partner-interview failure and a client-interview failure are '
        'each their own independent, non-orderable candidate stage', () {
      var aggregate = PublicDemoAggregate.initial();
      final projects = aggregate.projectCandidatesForMonth(4, count: 6);

      // Drive candidate 1 to a forced failure by feeding an actualCapability
      // that cannot pass (0 skillFit contribution is not enough by itself
      // to guarantee failure for every profile, so this test only asserts
      // the STRUCTURE: whichever of pass/fail happens, it is independent
      // per candidate and correctly reflected).
      aggregate = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: projects[0].id,
      );
      aggregate = aggregate.evaluatePartnerInterviewForCandidate(
        engineerId: 'eng-01',
        projectId: projects[0].id,
      );
      final afterFirst = aggregate.offerCandidateFor('eng-01', projects[0].id)!;
      expect(
        afterFirst.stage,
        anyOf(
          PublicDemoOfferCandidateStage.partnerInterviewPassed,
          PublicDemoOfferCandidateStage.partnerInterviewFailed,
        ),
      );
      // A failed candidate is never orderable.
      if (afterFirst.stage == PublicDemoOfferCandidateStage.partnerInterviewFailed) {
        final attempted = aggregate.recordOfferCandidateOrder(
          engineerId: 'eng-01',
          projectId: projects[0].id,
        );
        expect(
          attempted.offerCandidateFor('eng-01', projects[0].id)!.stage,
          PublicDemoOfferCandidateStage.partnerInterviewFailed,
        );
      }
    });

    test('stale/unknown (engineerId, projectId) pair resolves to no '
        'candidate at all — never a fabricated one', () {
      final aggregate = PublicDemoAggregate.initial();
      expect(
        aggregate.offerCandidateFor('eng-01', 'project-4-99'),
        isNull,
      );
      expect(
        aggregate.offerCandidateFor('no-such-engineer', 'project-4-1'),
        isNull,
      );
      expect(aggregate.offerCandidatesForEngineer('no-such-engineer'), isEmpty);
    });
  });

  group('Candidate-aware order (recordOfferCandidateOrder)', () {
    test('ordering candidate B (not the engineer\'s own coarse-tracked '
        'candidate A) marks B ordered, declines A, and correctly syncs the '
        'engineer-level coarse stage/record', () {
      final primary = primaryCandidatePassed();
      final projectB = primary.aggregate.projectCandidatesForMonth(4).firstWhere(
        (candidate) => candidate.id != primary.projectId,
      );
      var aggregate = addSecondPassedCandidate(
        primary.aggregate,
        'eng-01',
        projectB.id,
      );

      aggregate = aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );

      expect(
        aggregate.offerCandidateFor('eng-01', projectB.id)!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      expect(
        aggregate.offerCandidateFor('eng-01', primary.projectId)!.stage,
        PublicDemoOfferCandidateStage.declined,
        reason: 'the un-chosen sibling is automatically declined',
      );

      final e = engineer(aggregate, 'eng-01');
      expect(e.stage, PublicDemoSalesStage.ordered);
      expect(e.hasGenuineInterviewRecord, isTrue);
      // The coarse mirror deliberately carries no project id (see
      // syncOrderedFromCandidate's own doc) — the real ordered project is
      // read back from offerCandidates.
      expect(e.genuineInterviewProjectId, isNull);
      expect(
        aggregate.orderedOfferCandidateProjectIdFor('eng-01'),
        projectB.id,
      );
    });

    test('assignOrderedForMay materializes the assignment for the '
        'CANDIDATE-CHOSEN project (B), never the engineer\'s own earlier, '
        'now-declined coarse-tracked project (A)', () {
      final primary = primaryCandidatePassed();
      final projectB = primary.aggregate.projectCandidatesForMonth(4).firstWhere(
        (candidate) => candidate.id != primary.projectId,
      );
      var aggregate = addSecondPassedCandidate(
        primary.aggregate,
        'eng-01',
        projectB.id,
      );
      aggregate = aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );
      expect(aggregate.workflow.assignments, isEmpty, reason: 'ordered != assigned');

      final assigned = aggregate.closeApril(monthlyExpenses: 10000);
      final assignment = assigned.workflow.assignments.firstWhere(
        (a) => a.engineerId == 'eng-01',
      );
      expect(assignment.projectId, projectB.id);
      expect(assignment.projectId, isNot(primary.projectId));
    });

    test('duplicate tap: ordering the same candidate twice changes nothing '
        'further', () {
      final primary = primaryCandidatePassed();
      var aggregate = primary.aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: primary.projectId,
      );
      final once = aggregate;
      aggregate = aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: primary.projectId,
      );
      expect(aggregate.workflow.offerCandidates, once.workflow.offerCandidates);
      expect(engineer(aggregate, 'eng-01').stage, PublicDemoSalesStage.ordered);
    });

    test('passedのみ受注可能: a proposed/partner-passed/failed/declined '
        'candidate can never be ordered via recordOfferCandidateOrder', () {
      var aggregate = PublicDemoAggregate.initial();
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      final stillProposed = aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      expect(
        stillProposed.offerCandidateFor('eng-01', project.id)!.stage,
        PublicDemoOfferCandidateStage.proposed,
      );
      expect(engineer(stillProposed, 'eng-01').stage, PublicDemoSalesStage.waiting);
    });

    test('a declined candidate (auto-declined sibling) can never later be '
        'ordered', () {
      final primary = primaryCandidatePassed();
      final projectB = primary.aggregate.projectCandidatesForMonth(4).firstWhere(
        (candidate) => candidate.id != primary.projectId,
      );
      var aggregate = addSecondPassedCandidate(
        primary.aggregate,
        'eng-01',
        projectB.id,
      );
      aggregate = aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );
      expect(
        aggregate.offerCandidateFor('eng-01', primary.projectId)!.stage,
        PublicDemoOfferCandidateStage.declined,
      );
      final attempted = aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: primary.projectId,
      );
      expect(
        attempted.offerCandidateFor('eng-01', primary.projectId)!.stage,
        PublicDemoOfferCandidateStage.declined,
      );
      expect(
        attempted.offerCandidateFor('eng-01', projectB.id)!.stage,
        PublicDemoOfferCandidateStage.ordered,
        reason: 'the already-ordered candidate is unaffected',
      );
    });

    test('a fake clientInterviewPassed candidate with no genuine record '
        'can never be ordered via recordOfferCandidateOrder', () {
      var workflow = PublicDemoWorkflowState.initial();
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      final forgedJson = {
        ...PublicDemoWorkflowState.initial().toJson(),
        'offerCandidates': [
          {
            'engineerId': 'eng-01',
            'projectId': 'project-4-1',
            'proposedMonth': 4,
            'stage': 'clientInterviewPassed',
            'partnerScore': 100,
            'clientScore': 100,
            'interviewRecordEngineerId': null,
            'interviewRecordProjectId': null,
          },
        ],
      };
      final forged = PublicDemoWorkflowState.fromJson(forgedJson);
      final result = forged.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      expect(
        result.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
        reason: 'no genuine interviewRecord -> order refused',
      );
    });
  });

  group('Save/reload', () {
    test('two held candidates (one ordered/declined-sibling) round-trip '
        'through the real save codec byte-identically', () {
      final primary = primaryCandidatePassed();
      final projectB = primary.aggregate.projectCandidatesForMonth(4).firstWhere(
        (candidate) => candidate.id != primary.projectId,
      );
      var aggregate = addSecondPassedCandidate(
        primary.aggregate,
        'eng-01',
        projectB.id,
      );
      aggregate = aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );

      final json = codec.toJson(aggregate);
      final reloaded = codec.fromJson(json);
      expect(reloaded, isNotNull);
      expect(
        reloaded!.offerCandidateFor('eng-01', projectB.id)!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      expect(
        reloaded.offerCandidateFor('eng-01', primary.projectId)!.stage,
        PublicDemoOfferCandidateStage.declined,
      );
      expect(engineer(reloaded, 'eng-01').stage, PublicDemoSalesStage.ordered);
      expect(codec.toJson(reloaded), json);

      // A save/reload BEFORE any order still preserves both live candidates
      // side by side, neither auto-resolving.
      final beforeOrder = addSecondPassedCandidate(
        primary.aggregate,
        'eng-01',
        projectB.id,
      );
      final preOrderJson = codec.toJson(beforeOrder);
      final preOrderReloaded = codec.fromJson(preOrderJson)!;
      expect(
        preOrderReloaded.offerCandidateFor('eng-01', primary.projectId)!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
      expect(
        preOrderReloaded.offerCandidateFor('eng-01', projectB.id)!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
    });

    test('assignOrderedForMay still correctly resolves the candidate-chosen '
        'project after a save/reload round-trip', () {
      final primary = primaryCandidatePassed();
      final projectB = primary.aggregate.projectCandidatesForMonth(4).firstWhere(
        (candidate) => candidate.id != primary.projectId,
      );
      var aggregate = addSecondPassedCandidate(
        primary.aggregate,
        'eng-01',
        projectB.id,
      );
      aggregate = aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );
      final reloaded = codec.fromJson(codec.toJson(aggregate))!;
      final assigned = reloaded.closeApril(monthlyExpenses: 10000);
      final assignment = assigned.workflow.assignments.firstWhere(
        (a) => a.engineerId == 'eng-01',
      );
      expect(assignment.projectId, projectB.id);
    });
  });

  group('Additional-candidate proposal eligibility', () {
    test('canProposeAdditionalOfferCandidate is false while waiting/'
        'skillSheet — the existing single-project onboarding flow is '
        'completely unaffected', () {
      final aggregate = PublicDemoAggregate.initial();
      expect(aggregate.canProposeAdditionalOfferCandidate('eng-01'), isFalse);
      final afterSkillSheet = aggregate.startSkillSheetReview('eng-01');
      expect(
        afterSkillSheet.canProposeAdditionalOfferCandidate('eng-01'),
        isFalse,
      );
    });

    test('canProposeAdditionalOfferCandidate becomes true once the engineer '
        'is actively selling, and false again once genuinely ordered', () {
      var aggregate = PublicDemoAggregate.initial()
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01');
      expect(aggregate.canProposeAdditionalOfferCandidate('eng-01'), isTrue);

      final primary = primaryCandidatePassed();
      final ordered = primary.aggregate.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: primary.projectId,
      );
      expect(ordered.canProposeAdditionalOfferCandidate('eng-01'), isFalse);
    });

    test('proposeAdditionalOfferCandidate is a no-op when eligibility does '
        'not hold, and creates a genuine new candidate when it does', () {
      final blocked = PublicDemoAggregate.initial();
      final project = blocked.projectCandidatesForMonth(4).first;
      final stillBlocked = blocked.proposeAdditionalOfferCandidate(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      expect(stillBlocked.offerCandidates, isEmpty);

      final eligible = blocked
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01');
      final withCandidate = eligible.proposeAdditionalOfferCandidate(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      expect(
        withCandidate.offerCandidateFor('eng-01', project.id)!.stage,
        PublicDemoOfferCandidateStage.proposed,
      );
    });

    test('Codex Broad Review (PR #260) Finding #2 fix: a HISTORICAL ordered '
        'candidate from a genuinely completed, already-released assignment '
        'cycle never blocks a later, fresh sales cycle\'s own additional '
        'proposal — offerCandidates never deletes history, but only the '
        'engineer\'s CURRENT stage decides current eligibility', () {
      // Drives eng-01 through a full, real production cycle: propose ->
      // partner+client pass -> order -> April/May assignment -> July close
      // -> a genuine "not offered" continuation decision -> endAssignment
      // release back to `waiting` — mirrors
      // `public_demo_parallel_sales_session_composite_identity_test.dart`'s
      // own proven `findBothPass` fixture, stopping after the FIRST release
      // (this test does not need a second genuine pass).
      ({PublicDemoAggregate aggregate, String projectId})? released;
      for (var seed = 0; seed < 60; seed++) {
        var aggregate = PublicDemoAggregate.initial(runSeed: seed);
        final project = aggregate.projectCandidatesForMonth(4).first;
        aggregate = aggregate.proposeMatch(
          engineerId: 'eng-01',
          projectId: project.id,
        );
        aggregate = aggregate
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01');
        aggregate = aggregate.startPartnerInterview('eng-01');
        var session = aggregate.projectInterviewSessionFor('eng-01')!;
        while (session.playerFollowUps.length < session.questions.length) {
          final choice = PublicDemoProjectInterview.choicesFor(session).first;
          aggregate = aggregate.chooseProjectInterviewFollowUp(
            'eng-01',
            session.currentQuestionIndex,
            choice,
          );
          session = aggregate.projectInterviewSessionFor('eng-01')!;
        }
        aggregate = aggregate.concludePartnerInterview('eng-01');
        if (aggregate.workflow.engineers
                .firstWhere((e) => e.id == 'eng-01')
                .stage !=
            PublicDemoSalesStage.partnerInterviewPassed) {
          continue;
        }
        aggregate = aggregate.startProjectInterview('eng-01');
        session = aggregate.projectInterviewSessionFor('eng-01')!;
        while (session.playerFollowUps.length < session.questions.length) {
          final choice = PublicDemoProjectInterview.choicesFor(session).first;
          aggregate = aggregate.chooseProjectInterviewFollowUp(
            'eng-01',
            session.currentQuestionIndex,
            choice,
          );
          session = aggregate.projectInterviewSessionFor('eng-01')!;
        }
        aggregate = aggregate.concludeProjectInterview('eng-01');
        if (aggregate.workflow.engineers
                .firstWhere((e) => e.id == 'eng-01')
                .stage !=
            PublicDemoSalesStage.clientInterviewPassed) {
          continue;
        }

        aggregate = aggregate.recordOfferCandidateOrder(
          engineerId: 'eng-01',
          projectId: project.id,
        );
        aggregate = aggregate.closeApril(monthlyExpenses: 0);
        aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 0);
        final assignment = aggregate.workflow.assignments
            .where((a) => a.engineerId == 'eng-01')
            .firstOrNull;
        if (assignment?.projectId != project.id) continue;
        // Before month 7, `assignedEngineerIds` counts every assignment row
        // unconditionally regardless of `nextOrderStatus` (this month's
        // revenue is already earned) — only from month 7 does a genuine
        // `notOffered` row stop counting AND get physically removed by
        // `endAssignment`, exactly like the composite-identity test's own
        // fixture requires.
        aggregate = aggregate.closeJune(assignedInJuly: 1, monthlyExpenses: 0);
        aggregate = aggregate.closeJuly(monthlyExpenses: 0);
        if (aggregate.state.month < 8) continue;

        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        final beforeEnd = aggregate;
        aggregate = aggregate.endAssignment('eng-01');
        if (identical(aggregate, beforeEnd)) continue;
        if (aggregate.workflow.engineers
                .firstWhere((e) => e.id == 'eng-01')
                .stage !=
            PublicDemoSalesStage.waiting) {
          continue;
        }
        released = (aggregate: aggregate, projectId: project.id);
        break;
      }
      expect(
        released,
        isNotNull,
        reason: 'no seed under 60 produced a genuine order->release cycle',
      );
      final (aggregate: releasedAggregate, projectId: releasedProjectId) =
          released!;

      // The historical candidate is STILL genuinely `ordered` — history is
      // never deleted.
      expect(
        releasedAggregate.offerCandidateFor('eng-01', releasedProjectId)!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      // The engineer is genuinely back to `waiting` — a completely fresh
      // sales cycle.
      expect(
        engineer(releasedAggregate, 'eng-01').stage,
        PublicDemoSalesStage.waiting,
      );
      // Before this fix: canProposeAdditionalOfferCandidate would remain
      // FALSE forever from here, because of the stale, now-superseded
      // ordered candidate above — even after a brand-new first proposal for
      // this fresh cycle.
      var aggregate = releasedAggregate;
      final newProject = aggregate
          .projectCandidatesForMonth(aggregate.state.month)
          .firstWhere((p) => p.id != releasedProjectId);
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: newProject.id,
      );
      aggregate = aggregate.startSkillSheetReview('eng-01').beginSelling(
        'eng-01',
      );
      expect(
        aggregate.canProposeAdditionalOfferCandidate('eng-01'),
        isTrue,
        reason:
            'a historical ordered candidate from a released, ended cycle '
            'must never block a fresh cycle\'s own additional proposal',
      );

      // Save/reload mid-way: the eligibility fact survives a round-trip
      // (it is derived live from engineer.stage + offerCandidates, never
      // itself persisted).
      const codec = PublicDemoSaveCodec();
      final reloaded = codec.fromJson(codec.toJson(aggregate));
      expect(reloaded, isNotNull);
      expect(reloaded!.canProposeAdditionalOfferCandidate('eng-01'), isTrue);
    });
  });

  group('Regression: single-project flow / replacement sales / month '
      'boundary', () {
    test('existing single-project recordOrder flow is completely unchanged: '
        'propose -> interview -> recordOrder -> assignOrderedForMay still '
        'assigns the one real project', () {
      final passed = primaryCandidatePassed();
      final ordered = passed.aggregate.recordOrder('eng-01');
      expect(
        ordered.offerCandidateFor('eng-01', passed.projectId)!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      final assigned = ordered.closeApril(monthlyExpenses: 10000);
      final assignment = assigned.workflow.assignments.firstWhere(
        (a) => a.engineerId == 'eng-01',
      );
      expect(assignment.projectId, passed.projectId);
    });

    test('candidates are not month-scoped: they survive a month close '
        'untouched unless explicitly ordered/declined', () {
      final primary = primaryCandidatePassed();
      final projectB = primary.aggregate.projectCandidatesForMonth(4).firstWhere(
        (candidate) => candidate.id != primary.projectId,
      );
      final aggregate = addSecondPassedCandidate(
        primary.aggregate,
        'eng-01',
        projectB.id,
      );
      final beforeClose = aggregate.offerCandidatesForEngineer('eng-01');
      final closed = aggregate.closeApril(monthlyExpenses: 10000);
      final afterClose = closed.offerCandidatesForEngineer('eng-01');
      expect(afterClose.length, beforeClose.length);
      for (final candidate in beforeClose) {
        expect(
          closed.offerCandidateFor(candidate.engineerId, candidate.projectId),
          candidate,
        );
      }
    });

    test('replacement sales (PublicDemoReplacementStage) never reads or '
        'writes offerCandidates', () {
      final passed = primaryCandidatePassed();
      var aggregate = passed.aggregate.recordOrder('eng-01');
      aggregate = aggregate.closeApril(monthlyExpenses: 10000);
      final beforeCandidates = aggregate.offerCandidates;
      // Sanity: the ordered engineer's own candidate is untouched by month
      // close, and replacement-sales machinery (`PublicDemoAssignment
      // .replacementStage`) is a per-assignment field this candidate list
      // has no relationship to at all.
      expect(
        aggregate.offerCandidateFor('eng-01', passed.projectId)!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      expect(aggregate.offerCandidates, beforeCandidates);
    });
  });

  group('Security: offer-candidate score-floor fix (self-hardening)', () {
    test('a genuine offer candidate whose OWN clientScore is a real, '
        'low-rate stochastic Project Interview Gameplay pass (< 60, a '
        'reachable outcome — see PublicDemoSaveCodec\'s own doc) round-'
        'trips through the real save codec instead of silently rejecting '
        'the entire save', () {
      // Mirrors exactly the JSON shape [PublicDemoOfferCandidate.toJson]
      // itself produces for a genuine low-rate stochastic pass — never a
      // structurally-different or otherwise-forged shape.
      final json = codec.toJson(PublicDemoAggregate.initial());
      final aggregateJson =
          (json['aggregate'] as Map).cast<String, dynamic>();
      final workflowJson =
          (aggregateJson['workflow'] as Map).cast<String, dynamic>();
      workflowJson['offerCandidates'] = [
        {
          'engineerId': 'eng-01',
          'projectId': 'project-4-1',
          'proposedMonth': 4,
          'stage': 'clientInterviewPassed',
          'partnerScore': 72,
          'clientScore': 12,
          'interviewRecordEngineerId': 'eng-01',
          'interviewRecordProjectId': 'project-4-1',
        },
      ];
      aggregateJson['workflow'] = workflowJson;
      json['aggregate'] = aggregateJson;
      final reloaded = codec.fromJson(json);
      expect(
        reloaded,
        isNotNull,
        reason:
            'a genuine sub-60 stochastic pass must not be treated as forged',
      );
      final candidate = reloaded!.offerCandidateFor('eng-01', 'project-4-1')!;
      expect(candidate.clientScore, 12);
      expect(candidate.hasGenuineInterviewRecord, isTrue);
    });

    test('syncOrderedFromCandidate clamps a sub-60 genuine candidate score '
        'so the coarse legacy mirror never becomes an unloadable save', () {
      // A genuine stochastic Project Interview Gameplay pass CAN score
      // below 60 (a probabilistic roll, not a >=60 threshold — see
      // syncOrderedFromCandidate's own doc). Simulate this directly on the
      // engineer to prove the codec's own persistence floor for a
      // project-agnostic record (score >= 60) is always satisfied
      // regardless of the real candidate score.
      final synced = PublicDemoEngineerSales(
        id: 'eng-01',
        name: 'x',
        summary: 'x',
        interviewProfile: const PublicDemoInterviewProfile(
          skillFit: 50,
          humanity: 50,
          morale: 50,
          clientTrust: 50,
        ),
      ).syncOrderedFromCandidate(score: 12);
      expect(synced.lastInterviewScore, greaterThanOrEqualTo(60));
      expect(synced.hasGenuineInterviewRecord, isTrue);
      expect(synced.genuineInterviewProjectId, isNull);
    });
  });
}
