import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_offer_candidate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// Issue #257, Phase 1b (Production Cutover / Dual Authority
/// Reconciliation): coverage for the actual production caller cutover
/// (`proposeMatch`/interactive Partner+Client Interview/`recordOrder` now
/// synchronizing `PublicDemoWorkflowState.offerCandidates`) and the real,
/// repeatable reconciliation (`_reconcileOfferCandidates`) that replaces
/// Phase 1a's one-shot, key-absence-gated synthesis. See
/// docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1B_Result.md.
///
/// Phase 1a's own `public_demo_offer_candidate_test.dart` already covers
/// the `PublicDemoOfferCandidate` domain model itself and the original
/// migration synthesis exhaustively — this file focuses on what Phase 1b
/// adds: real production callers driving the candidate list, and
/// reconciliation running even when the `offerCandidates` key is already
/// present (the exact Codex PR #254 finding this phase fixes).
void main() {
  const codec = PublicDemoSaveCodec();

  PublicDemoEngineerSales engineer(PublicDemoAggregate aggregate, String id) =>
      aggregate.workflow.engineers.firstWhere((e) => e.id == id);

  /// Advances [engineerId] to `introduced` via the real, unchanged
  /// production chain, WITHOUT ever proposing a project — mirrors this
  /// repo's own established "generic, project-agnostic path" fixtures.
  PublicDemoAggregate advanceToIntroduced(
    PublicDemoAggregate aggregate,
    String engineerId,
  ) => aggregate
      .startSkillSheetReview(engineerId)
      .beginSelling(engineerId)
      .introduceProject(engineerId);

  /// Runs the REAL interactive Partner Interview (Scope B's production
  /// entry point: `startPartnerInterview`/`chooseProjectInterviewFollowUp`/
  /// `concludePartnerInterview`) to a genuine, concluded outcome — pass or
  /// fail, whichever the seeded engine actually produces for this exact
  /// [aggregate]/[engineerId] at the moment it is called. Mirrors the
  /// existing CORE-GAMEPLAY Phase 6 test suite's own interactive-engine
  /// driving pattern (`public_demo_project_interview_test.dart`).
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

  /// The Client Interview counterpart of [runPartnerInterviewToConclusion]
  /// — `startProjectInterview`/`concludeProjectInterview` (Scope C).
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

  /// Searches seeds until a genuine PARTNER pass is found for `eng-01`,
  /// freshly proposed to the first project candidate of the given month —
  /// exactly the search style
  /// `public_demo_project_interview_test.dart` itself already uses for the
  /// same seeded, stochastic interactive engine.
  ({PublicDemoAggregate aggregate, String projectId}) partnerPassed({
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
      if (engineer(aggregate, 'eng-01').stage ==
          PublicDemoSalesStage.partnerInterviewPassed) {
        return (aggregate: aggregate, projectId: project.id);
      }
    }
    fail('expected at least one genuine partner pass across $maxSeed seeds');
  }

  /// [partnerPassed] plus a genuine CLIENT pass, for the same engineer and
  /// project.
  ({PublicDemoAggregate aggregate, String projectId}) clientPassed({
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
    fail('expected at least one genuine client pass across $maxSeed seeds');
  }

  group('Scope A: proposeMatch synchronizes offerCandidates', () {
    test('proposing engineer A to project 1 creates a matching, proposed '
        'offer candidate', () {
      var aggregate = PublicDemoAggregate.initial();
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      final candidate = aggregate.offerCandidateFor('eng-01', project.id);
      expect(candidate, isNotNull);
      expect(candidate!.stage, PublicDemoOfferCandidateStage.proposed);
    });

    test('1 engineer x 2 projects: proposing a SECOND, different project '
        'for the same engineer keeps BOTH candidates coexisting, even '
        'though matchingProposals (legacy, single-slot) only keeps the '
        'latest', () {
      var aggregate = PublicDemoAggregate.initial();
      final projects = aggregate.projectCandidatesForMonth(4);
      final projectA = projects[0];
      final projectB = projects[1];
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );

      expect(aggregate.offerCandidateFor('eng-01', projectA.id), isNotNull);
      expect(aggregate.offerCandidateFor('eng-01', projectB.id), isNotNull);
      expect(
        aggregate.workflow.offerCandidatesForEngineer('eng-01'),
        hasLength(2),
      );
      // Legacy matchingProposals is still single-slot — replaced, not
      // accumulated — exactly as before Phase 1b.
      expect(aggregate.matchingProposalFor('eng-01')!.projectId, projectB.id);
    });

    test('re-proposing the SAME pair twice is idempotent: no duplicate '
        'candidate, existing progress never reset', () {
      var aggregate = PublicDemoAggregate.initial();
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      expect(
        aggregate.workflow.offerCandidatesForEngineer('eng-01'),
        hasLength(1),
      );
    });
  });

  group('Scope B/C: interactive Partner/Client Interview cutover', () {
    test('a genuine partner pass via the interactive engine syncs the '
        'matching candidate to partnerInterviewPassed with its own '
        'partnerScore — reusing the SAME engine/session, no fork', () {
      final result = partnerPassed();
      final candidate = result.aggregate.offerCandidateFor(
        'eng-01',
        result.projectId,
      );
      expect(candidate, isNotNull);
      expect(
        candidate!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewPassed,
      );
      expect(candidate.partnerScore, isNotNull);
      expect(candidate.hasGenuineInterviewRecord, isFalse);
    });

    test('a genuine client pass via the interactive engine syncs the '
        'matching candidate to clientInterviewPassed with a genuine '
        'interviewRecord bound to (engineerId, projectId)', () {
      final result = clientPassed();
      final candidate = result.aggregate.offerCandidateFor(
        'eng-01',
        result.projectId,
      );
      expect(candidate, isNotNull);
      expect(
        candidate!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
      expect(candidate.clientScore, isNotNull);
      expect(candidate.hasGenuineInterviewRecord, isTrue);
      expect(candidate.interviewRecord!.engineerId, 'eng-01');
      expect(candidate.interviewRecord!.projectId, result.projectId);
      // The engineer-level legacy authority is in exact lockstep — the
      // whole point of the cutover.
      expect(
        engineer(result.aggregate, 'eng-01').stage,
        PublicDemoSalesStage.clientInterviewPassed,
      );
    });

    test('partner interview slot semantics: exactly one real sales slot is '
        'consumed for a genuinely NEW attempt, at the aggregate layer — '
        'unaffected by whether a matching candidate exists', () {
      var aggregate = PublicDemoAggregate.initial();
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      expect(aggregate.state.salesUsed, 0);
      aggregate = aggregate.startPartnerInterview('eng-01');
      expect(aggregate.state.salesUsed, 1);
    });

    test('resuming the SAME in-progress partner interview session never '
        'double-consumes a sales slot', () {
      var aggregate = PublicDemoAggregate.initial();
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = aggregate.startPartnerInterview('eng-01');
      expect(aggregate.state.salesUsed, 1);
      // Resume (no answer chosen yet) — same session, must not re-charge.
      aggregate = aggregate.startPartnerInterview('eng-01');
      expect(aggregate.state.salesUsed, 1);
    });

    test('client interview consumes ZERO additional sales slots, even '
        'though it now also syncs the candidate', () {
      var aggregate = PublicDemoAggregate.initial();
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerInterviewToConclusion(aggregate, 'eng-01');
      if (engineer(aggregate, 'eng-01').stage !=
          PublicDemoSalesStage.partnerInterviewPassed) {
        return; // this seed happened to fail partner — nothing to assert
      }
      final salesUsedBeforeClient = aggregate.state.salesUsed;
      aggregate = runClientInterviewToConclusion(aggregate, 'eng-01');
      expect(aggregate.state.salesUsed, salesUsedBeforeClient);
    });

    test('capacity exhausted: a partner interview attempt is a total no-op '
        '(no partial mutation of state OR the candidate) when no sales '
        'slot remains', () {
      var aggregate = PublicDemoAggregate.initial();
      final project = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: project.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      // Drains the whole month's 4-slot budget via repeated genuine
      // partner-interview attempts on eng-02 — eng-02's founding
      // interview profile legitimately, deterministically fails the real
      // evaluator's threshold (established precedent elsewhere in this
      // suite), so `beginSelling`'s own failure-retry path lets each
      // attempt consume a fresh real slot.
      for (var i = 0; i < 4; i++) {
        aggregate = aggregate
            .startSkillSheetReview('eng-02')
            .beginSelling('eng-02')
            .introduceProject('eng-02')
            .recordEngineerInterviewResult(
              engineerId: 'eng-02',
              type: PublicDemoInterviewType.partner,
            );
      }
      expect(
        engineer(aggregate, 'eng-02').stage,
        PublicDemoSalesStage.partnerInterviewFailed,
      );
      expect(aggregate.state.salesRemaining, 0);
      final before = aggregate;
      final after = aggregate.startPartnerInterview('eng-01');
      expect(after.state.salesUsed, before.state.salesUsed);
      expect(
        after.offerCandidateFor('eng-01', project.id)!.stage,
        PublicDemoOfferCandidateStage.proposed,
      );
    });

    test('two projects for the same engineer hold independent partner/'
        'client results — passing/failing one never affects the other', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 7);
      final projects = aggregate.projectCandidatesForMonth(4);
      final projectA = projects[0];
      final projectB = projects[1];
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = runPartnerInterviewToConclusion(aggregate, 'eng-01');

      final candidateA = aggregate.offerCandidateFor('eng-01', projectA.id)!;
      final candidateB = aggregate.offerCandidateFor('eng-01', projectB.id)!;
      // Only A (the currently-proposed project) was interviewed — B is
      // untouched, exactly preserving independent per-project state.
      expect(candidateA.stage, isNot(PublicDemoOfferCandidateStage.proposed));
      expect(candidateB.stage, PublicDemoOfferCandidateStage.proposed);
    });
  });

  group('Scope D: recordOrder is candidate-aware; ordered != assigned', () {
    test('ordering the passed candidate marks THAT candidate ordered and '
        'declines every other live sibling, atomically', () {
      final passed = clientPassed();
      var aggregate = passed.aggregate;
      final otherProject = aggregate.projectCandidatesForMonth(4).firstWhere(
        (candidate) => candidate.id != passed.projectId,
      );
      aggregate = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: otherProject.id,
      );
      expect(
        aggregate.offerCandidateFor('eng-01', otherProject.id)!.stage,
        PublicDemoOfferCandidateStage.proposed,
      );

      aggregate = aggregate.recordOrder('eng-01');

      expect(
        aggregate.offerCandidateFor('eng-01', passed.projectId)!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      expect(
        aggregate.offerCandidateFor('eng-01', otherProject.id)!.stage,
        PublicDemoOfferCandidateStage.declined,
      );
    });

    test('ordered != assigned: recordOrder never appends to assignments '
        'itself — only assignOrderedForMay does', () {
      final passed = clientPassed();
      final ordered = passed.aggregate.recordOrder('eng-01');
      expect(ordered.workflow.assignments, isEmpty);
      expect(
        ordered.offerCandidateFor('eng-01', passed.projectId)!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      final assigned = ordered.closeApril(monthlyExpenses: 10000);
      expect(
        assigned.workflow.assignments.any(
          (assignment) => assignment.engineerId == 'eng-01',
        ),
        isTrue,
      );
    });

    test('double order / retry is safe: calling recordOrder again after '
        'already ordered changes nothing further', () {
      final passed = clientPassed();
      final ordered = passed.aggregate.recordOrder('eng-01');
      final orderedAgain = ordered.recordOrder('eng-01');
      expect(orderedAgain.workflow.offerCandidates, ordered.workflow.offerCandidates);
      expect(
        engineer(orderedAgain, 'eng-01').stage,
        PublicDemoSalesStage.ordered,
      );
    });

    test('the legacy, project-agnostic generic order path (no proposal at '
        'all) still succeeds at the engineer level, leaving the (empty) '
        'candidate list untouched — existing single-project behavior is '
        'not broken', () {
      var aggregate = PublicDemoAggregate.initial();
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
          );
      expect(aggregate.matchingProposalFor('eng-01'), isNull);
      aggregate = aggregate.recordOrder('eng-01');
      expect(engineer(aggregate, 'eng-01').stage, PublicDemoSalesStage.ordered);
      expect(aggregate.workflow.offerCandidates, isEmpty);
    });
  });

  group(
    'Reconciliation: offerCandidates key PRESENT but stale (the Codex '
    'PR #254 finding this phase fixes)',
    () {
      test('a candidate stuck at proposed, while the generic path already '
          'advanced the SAME engineer past it, is upgraded on next load — '
          'key presence is never treated as proof of migration', () {
        var workflow = PublicDemoWorkflowState.initial();
        workflow = workflow.withMatchingProposal(
          engineerId: 'eng-01',
          projectId: 'project-4-1',
          month: 4,
        );
        expect(
          workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.proposed,
        );
        // Generic, non-candidate-aware path advances the engineer without
        // ever touching the candidate.
        workflow = workflow
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01')
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.partner,
              actualCapability: 100,
            );
        expect(
          engineer2(workflow, 'eng-01').stage,
          PublicDemoSalesStage.partnerInterviewPassed,
        );
        // The raw save's offerCandidates key IS present (non-empty) —
        // this is the exact Codex-flagged shape.
        final json = workflow.toJson();
        expect(json['offerCandidates'], isNotEmpty);
        expect(
          (json['offerCandidates'] as List).first['stage'],
          'proposed',
        );

        final restored = PublicDemoWorkflowState.fromJson(json);
        expect(
          restored.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.partnerInterviewPassed,
        );
      });

      test('reconciliation never rewinds a candidate that is already AHEAD '
          'of legacy authority for the same project', () {
        var workflow = PublicDemoWorkflowState.initial();
        workflow = workflow.withMatchingProposal(
          engineerId: 'eng-01',
          projectId: 'project-4-1',
          month: 4,
        );
        // Engineer stays at the coarse `introduced` stage (legacy rank:
        // proposed) while the candidate independently advances ahead via
        // the standalone building block.
        workflow = workflow
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01');
        workflow = workflow.evaluatePartnerInterviewForCandidate(
          engineerId: 'eng-01',
          projectId: 'project-4-1',
          profile: engineer2(workflow, 'eng-01').interviewProfile,
          actualCapability: 100,
        );
        expect(
          workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.partnerInterviewPassed,
        );
        expect(
          engineer2(workflow, 'eng-01').stage,
          PublicDemoSalesStage.introduced,
        );

        final restored = PublicDemoWorkflowState.fromJson(workflow.toJson());
        expect(
          restored.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.partnerInterviewPassed,
        );
      });

      test('reconciliation never resurrects a DECLINED candidate, even '
          'when legacy authority later advances further', () {
        var workflow = PublicDemoWorkflowState.initial();
        workflow = workflow.withMatchingProposal(
          engineerId: 'eng-01',
          projectId: 'project-4-1',
          month: 4,
        );
        workflow = workflow.declineOfferCandidate(
          engineerId: 'eng-01',
          projectId: 'project-4-1',
        );
        expect(
          workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.declined,
        );
        workflow = workflow
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01')
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.partner,
              actualCapability: 100,
            )
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.client,
              actualCapability: 100,
            );

        final restored = PublicDemoWorkflowState.fromJson(workflow.toJson());
        expect(
          restored.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.declined,
        );
      });

      test('an `introduced` engineer with a real proposal but no candidate '
          'yet synthesizes a `proposed` candidate — a genuinely new '
          'migration case beyond Phase 1a\'s original scope (which only '
          'handled partnerInterviewPassed/clientInterviewPassed/ordered)',
          () {
        var workflow = PublicDemoWorkflowState.initial();
        workflow = workflow
            .withMatchingProposal(
              engineerId: 'eng-01',
              projectId: 'project-4-1',
              month: 4,
            )
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01');
        final legacyJson = workflow.toJson()..remove('offerCandidates');
        final restored = PublicDemoWorkflowState.fromJson(legacyJson);
        expect(
          restored.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.proposed,
        );
      });

      test('partnerInterviewFailed and clientInterviewFailed legacy stages '
          'both migrate to their matching candidate stage — also beyond '
          'Phase 1a\'s original relevantStages scope', () {
        var workflow = PublicDemoWorkflowState.initial();
        workflow = workflow
            .withMatchingProposal(
              engineerId: 'eng-01',
              projectId: 'project-4-1',
              month: 4,
            )
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01')
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.partner,
              actualCapability: 0,
            );
        expect(
          engineer2(workflow, 'eng-01').stage,
          PublicDemoSalesStage.partnerInterviewFailed,
        );
        final legacyJson = workflow.toJson()..remove('offerCandidates');
        var restored = PublicDemoWorkflowState.fromJson(legacyJson);
        expect(
          restored.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.partnerInterviewFailed,
        );

        workflow = workflow
            .beginSelling('eng-01')
            .introduceProject('eng-01')
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.partner,
              actualCapability: 100,
            )
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.client,
              actualCapability: 0,
            );
        expect(
          engineer2(workflow, 'eng-01').stage,
          PublicDemoSalesStage.clientInterviewFailed,
        );
        final legacyJson2 = workflow.toJson()..remove('offerCandidates');
        restored = PublicDemoWorkflowState.fromJson(legacyJson2);
        expect(
          restored.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.clientInterviewFailed,
        );
      });

      test('an ordered engineer with a lagging live sibling candidate for '
          'a DIFFERENT project: reconciliation upgrades the ordered '
          'project\'s candidate AND declines the sibling atomically', () {
        var workflow = PublicDemoWorkflowState.initial();
        workflow = workflow.withMatchingProposal(
          engineerId: 'eng-01',
          projectId: 'project-4-1',
          month: 4,
        );
        workflow = workflow.proposeOfferCandidate(
          engineerId: 'eng-01',
          projectId: 'project-4-2',
          month: 4,
        );
        workflow = workflow
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01')
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.partner,
              actualCapability: 100,
            )
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.client,
              actualCapability: 100,
            )
            .recordOrder('eng-01');
        expect(engineer2(workflow, 'eng-01').stage, PublicDemoSalesStage.ordered);
        // The candidate for project-4-1 never got synced by the generic
        // path — still `proposed` right up to save time.
        expect(
          workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.proposed,
        );
        expect(
          workflow.offerCandidateFor('eng-01', 'project-4-2')!.stage,
          PublicDemoOfferCandidateStage.proposed,
        );

        final restored = PublicDemoWorkflowState.fromJson(workflow.toJson());
        expect(
          restored.offerCandidateFor('eng-01', 'project-4-1')!.stage,
          PublicDemoOfferCandidateStage.ordered,
        );
        expect(
          restored.offerCandidateFor('eng-01', 'project-4-2')!.stage,
          PublicDemoOfferCandidateStage.declined,
        );
      });

      test('idempotency: save -> load -> reconcile -> save -> reload is '
          'stable — the first reconciled result never changes again', () {
        var workflow = PublicDemoWorkflowState.initial();
        workflow = workflow.withMatchingProposal(
          engineerId: 'eng-01',
          projectId: 'project-4-1',
          month: 4,
        );
        workflow = workflow
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01')
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.partner,
              actualCapability: 100,
            )
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.client,
              actualCapability: 100,
            )
            .recordOrder('eng-01');

        final firstLoad = PublicDemoWorkflowState.fromJson(workflow.toJson());
        final secondLoad = PublicDemoWorkflowState.fromJson(firstLoad.toJson());
        expect(secondLoad.toJson(), firstLoad.toJson());
      });
    },
  );

  group('Integrity: fake/mismatched proof, duplicate, multiple ordered', () {
    test('a raw save asserting stage: ordered on a candidate whose OWN '
        'engineer is not itself genuinely ordered is rejected', () {
      final passed = clientPassed();
      final json = codec.toJson(passed.aggregate);
      final workflow =
          (json['aggregate'] as Map)['workflow'] as Map<String, dynamic>;
      final candidates = List<Map<String, dynamic>>.from(
        workflow['offerCandidates'] as List,
      );
      final index = candidates.indexWhere(
        (c) => c['engineerId'] == 'eng-01' && c['projectId'] == passed.projectId,
      );
      candidates[index] = {...candidates[index], 'stage': 'ordered'};
      workflow['offerCandidates'] = candidates;
      // engineer.stage is still clientInterviewPassed, not ordered.
      expect(codec.fromJson(json), isNull);
    });

    test('a fake interview proof (clientInterviewPassed with no genuine '
        'interviewRecord) can never be ordered', () {
      var workflow = PublicDemoWorkflowState.initial();
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      // No genuine evaluation ever ran — hand-build a forged JSON shape
      // instead (mirrors the existing Phase 1a anti-forgery test style).
      final forgedJson = {
        'engineerId': 'eng-01',
        'projectId': 'project-4-1',
        'proposedMonth': 4,
        'stage': 'clientInterviewPassed',
        'partnerScore': null,
        'clientScore': 95,
        'interviewRecordEngineerId': null,
        'interviewRecordProjectId': null,
      };
      final forged = PublicDemoOfferCandidate.fromJson(forgedJson);
      expect(forged.hasGenuineInterviewRecord, isFalse);
      final workflowWithForged = PublicDemoWorkflowState.fromJson({
        ...PublicDemoWorkflowState.initial().toJson(),
        'offerCandidates': [forged.toJson()],
      });
      final ordered = workflowWithForged.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      expect(
        ordered.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
    });

    test('duplicate (engineerId, projectId) identity is rejected on load',
        () {
      final duplicateJson = {
        ...PublicDemoWorkflowState.initial().toJson(),
        'offerCandidates': [
          PublicDemoOfferCandidate.propose(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            proposedMonth: 4,
          ).toJson(),
          PublicDemoOfferCandidate.propose(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            proposedMonth: 4,
          ).toJson(),
        ],
      };
      expect(
        () => PublicDemoWorkflowState.fromJson(duplicateJson),
        throwsFormatException,
      );
    });

    test('no real production path can ever produce two SIMULTANEOUSLY-LIVE '
        'candidates ordered for the same engineer: ordering one always '
        'declines every other live sibling in the same atomic step', () {
      final passed = clientPassed();
      var aggregate = passed.aggregate;
      final projects = aggregate.projectCandidatesForMonth(4);
      final siblingProject = projects.firstWhere(
        (candidate) => candidate.id != passed.projectId,
      );
      aggregate = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: siblingProject.id,
      );
      aggregate = aggregate.recordOrder('eng-01');
      final orderedCandidates = aggregate.offerCandidates.where(
        (c) => c.stage == PublicDemoOfferCandidateStage.ordered,
      );
      expect(orderedCandidates, hasLength(1));
    });
  });

  group('Issue #257 PR #256 carry-over: session keying / engine reuse', () {
    test('same engineer x two projects can hold two in-flight partner '
        'interview sessions concurrently, through the real production API '
        '— starting project B\'s session never discards project A\'s '
        'still-incomplete one', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 3);
      final projects = aggregate.projectCandidatesForMonth(4);
      final projectA = projects[0];
      final projectB = projects[1];

      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectA.id,
      );
      aggregate = advanceToIntroduced(aggregate, 'eng-01');
      aggregate = aggregate.startPartnerInterview('eng-01');
      expect(
        aggregate.workflow.projectInterviewSessionFor('eng-01', projectA.id),
        isNotNull,
      );
      // Answer one question (but not all) for A, leaving it genuinely
      // in-flight.
      var sessionA = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      final firstChoice = PublicDemoProjectInterview.choicesFor(
        sessionA,
      ).first;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        sessionA.currentQuestionIndex,
        firstChoice,
      );
      sessionA = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      )!;
      expect(sessionA.completed, isFalse);

      // Engineer is still `introduced` (A's session was never concluded),
      // so a second, genuine proposal + partner-interview attempt for a
      // DIFFERENT project is real, ordinary production gameplay — not a
      // forged/edge scenario.
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );
      final salesUsedBeforeB = aggregate.state.salesUsed;
      aggregate = aggregate.startPartnerInterview('eng-01');
      expect(aggregate.state.salesUsed, salesUsedBeforeB + 1);

      // Both sessions now genuinely coexist — starting B's did not touch
      // A's.
      final sessionAAfter = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectA.id,
      );
      final sessionBAfter = aggregate.workflow.projectInterviewSessionFor(
        'eng-01',
        projectB.id,
      );
      expect(sessionAAfter, isNotNull);
      expect(sessionAAfter!.completed, isFalse);
      expect(sessionAAfter.playerFollowUps, hasLength(1));
      expect(sessionBAfter, isNotNull);
      expect(sessionBAfter!.playerFollowUps, isEmpty);
      expect(
        aggregate.workflow.projectInterviewSessions
            .where((session) => session.employeeId == 'eng-01')
            .length,
        2,
      );

      // Advancing B's session does not touch A's.
      final sessionBChoice = PublicDemoProjectInterview.choicesFor(
        sessionBAfter,
      ).first;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        sessionBAfter.currentQuestionIndex,
        sessionBChoice,
      );
      expect(
        aggregate.workflow
            .projectInterviewSessionFor('eng-01', projectA.id)!
            .playerFollowUps,
        hasLength(1),
      );
      expect(
        aggregate.workflow
            .projectInterviewSessionFor('eng-01', projectB.id)!
            .playerFollowUps,
        hasLength(1),
      );
    });

    test('same (employeeId, projectId) stale/completed session replacement '
        'is deterministic and never touches a sibling project\'s session',
        () {
      // Searches seeds until eng-02's genuine interactive partner interview
      // fails for project A (same seed-search style used elsewhere in this
      // file for the stochastic interactive engine) — the retry branch
      // this test exercises requires a real failure, not an assumed one.
      PublicDemoAggregate? aggregateAfterFailure;
      late PublicDemoProjectCandidate projectA;
      late PublicDemoProjectCandidate projectB;
      for (var seed = 0; seed < 60; seed++) {
        var candidate = PublicDemoAggregate.initial(runSeed: seed);
        final projects = candidate.projectCandidatesForMonth(4);
        projectA = projects[0];
        projectB = projects[1];
        candidate = candidate.proposeMatch(
          engineerId: 'eng-02',
          projectId: projectA.id,
        );
        candidate = advanceToIntroduced(candidate, 'eng-02');
        candidate = runPartnerInterviewToConclusion(candidate, 'eng-02');
        if (engineer(candidate, 'eng-02').stage ==
            PublicDemoSalesStage.partnerInterviewFailed) {
          aggregateAfterFailure = candidate;
          break;
        }
      }
      expect(
        aggregateAfterFailure,
        isNotNull,
        reason: 'expected at least one genuine partner failure across 60 seeds',
      );
      var aggregate = aggregateAfterFailure!;

      // Recover from the failure once (beginSelling -> introduceProject),
      // reaching `introduced` again — the same real recovery cycle any
      // failed partner interview requires, regardless of which project is
      // currently proposed.
      aggregate = aggregate.beginSelling('eng-02').introduceProject('eng-02');

      // A second, independent candidate/project (B) for the SAME engineer,
      // with its own live session, coexists throughout.
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-02',
        projectId: projectB.id,
      );
      aggregate = aggregate.startPartnerInterview('eng-02');
      final sessionBBefore = aggregate.workflow.projectInterviewSessionFor(
        'eng-02',
        projectB.id,
      )!;
      expect(sessionBBefore.completed, isFalse);

      // Retry A: re-propose it (moving the single-slot matchingProposal
      // back to A, mirroring a real player switching Matching focus back)
      // and start a fresh attempt — a fresh session for the SAME
      // (employeeId, projectId) pair replaces the completed one, while B's
      // independent session is untouched.
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-02',
        projectId: projectA.id,
      );
      aggregate = aggregate.startPartnerInterview('eng-02');
      final freshSessionA = aggregate.workflow.projectInterviewSessionFor(
        'eng-02',
        projectA.id,
      )!;
      expect(freshSessionA.completed, isFalse);
      expect(
        aggregate.workflow
            .projectInterviewSessionFor('eng-02', projectB.id)!
            .completed,
        isFalse,
      );
      expect(
        aggregate.workflow.projectInterviewSessions
            .where((session) => session.employeeId == 'eng-02')
            .length,
        2,
      );
    });
  });
}

/// Small local alias avoiding repeated inline lookups — mirrors the private
/// `engineer()` helper other Public Demo test files already use, but at the
/// [PublicDemoWorkflowState] level (several tests above build a workflow
/// directly rather than a whole aggregate).
PublicDemoEngineerSales engineer2(PublicDemoWorkflowState workflow, String id) =>
    workflow.engineers.firstWhere((e) => e.id == id);
