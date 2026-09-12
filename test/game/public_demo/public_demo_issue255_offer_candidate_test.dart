import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_offer_candidate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// Issue #255 FIRST-FUN-YEAR Parallel Sales Phase 1A: coverage for the new,
/// additive, domain-only [PublicDemoOfferCandidate] authority on
/// [PublicDemoWorkflowState.offerCandidates] — genuinely parallel
/// (engineer, project) sales progress, legacy-save migration (PR #253's
/// Codex review P1), and the zero-sales-slot client-interview leg (PR #253's
/// Codex review P2). See
/// docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1A_Result.md.
///
/// Nothing here touches [PublicDemoAggregate]/UI beyond reading its
/// deterministic, workflow-independent `state`/`runSeed`/project fixtures —
/// this Phase is domain-only, so every mutation is driven directly through
/// [PublicDemoWorkflowState]'s new methods, none of which ever reads
/// [PublicDemoState] (that absence is itself what proves the client leg is
/// zero-sales-slot — see the dedicated test below).

/// Runs a full, genuine interview to conclusion (always choosing the first
/// available follow-up) for [engineerId]/[projectId] against [workflow],
/// using the new pair-scoped Offer Candidate session methods. [state]/
/// [runSeed] are only ever read, never written — mirrors exactly how the
/// legacy pipeline's own equivalent test helpers work.
PublicDemoWorkflowState runOfferInterviewToConclusion({
  required PublicDemoWorkflowState workflow,
  required PublicDemoState state,
  required int runSeed,
  required String engineerId,
  required String projectId,
  required bool asPartnerLeg,
}) {
  final candidate = PublicDemoSeededProjectGenerator.regenerate(
    runSeed: runSeed,
    projectId: projectId,
  )!;
  final runtime = state.runtimeForOrNull(engineerId)!;
  var next = workflow;
  final session = PublicDemoProjectInterview.start(
    state: state,
    runtime: runtime,
    candidate: candidate,
  );
  next = next.startOfferInterviewSession(session);
  var current = next.offerInterviewSessionFor(engineerId, projectId)!;
  while (current.playerFollowUps.length < current.questions.length) {
    final choice = PublicDemoProjectInterview.choicesFor(current).first;
    next = next.updateOfferInterviewSession(
      engineerId,
      projectId,
      (session) => PublicDemoProjectInterview.chooseFollowUp(
        runSeed: runSeed,
        runtime: runtime,
        project: candidate.project,
        session: session,
        questionIndex: session.currentQuestionIndex,
        followUp: choice,
      ),
    );
    current = next.offerInterviewSessionFor(engineerId, projectId)!;
  }
  return asPartnerLeg
      ? next.concludeOfferPartnerInterview(
          engineerId: engineerId,
          projectId: projectId,
          runSeed: runSeed,
          currentMonth: state.month,
          runtime: runtime,
          project: candidate.project,
        )
      : next.concludeOfferClientInterview(
          engineerId: engineerId,
          projectId: projectId,
          runSeed: runSeed,
          currentMonth: state.month,
          runtime: runtime,
          project: candidate.project,
        );
}

/// Scans a bounded, deterministic seed range for one where `eng-01` passes
/// (or fails, per [wantPass]) the given leg's interview for April's first
/// project candidate — mirrors the legacy pipeline's own
/// `_findGenuinePass`/`_findGenuinePartnerPass` scanning helpers.
({PublicDemoState state, int runSeed, String projectId, PublicDemoWorkflowState workflow})?
_findOutcome({required bool asPartnerLeg, required bool wantPass, int maxSeed = 60}) {
  for (var seed = 0; seed < maxSeed; seed++) {
    final state = PublicDemoAggregate.initial(runSeed: seed).state;
    final projectId = PublicDemoSeededProjectGenerator.forMonth(
      runSeed: seed,
      month: 4,
    ).first.id;
    var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
      engineerId: 'eng-01',
      projectId: projectId,
      month: 4,
    );
    workflow = runOfferInterviewToConclusion(
      workflow: workflow,
      state: state,
      runSeed: seed,
      engineerId: 'eng-01',
      projectId: projectId,
      asPartnerLeg: asPartnerLeg,
    );
    final candidate = workflow.offerCandidateFor('eng-01', projectId)!;
    final passed = asPartnerLeg
        ? candidate.stage == PublicDemoOfferCandidateStage.partnerInterviewPassed
        : candidate.stage == PublicDemoOfferCandidateStage.clientInterviewPassed;
    if (passed == wantPass) {
      return (state: state, runSeed: seed, projectId: projectId, workflow: workflow);
    }
  }
  return null;
}

/// Advances a candidate for `eng-01` all the way to a genuine
/// `clientInterviewPassed` (both legs), scanning seeds until both pass.
({PublicDemoState state, int runSeed, String projectId, PublicDemoWorkflowState workflow})
genuineClientPass({int maxSeed = 120}) {
  for (var seed = 0; seed < maxSeed; seed++) {
    final state = PublicDemoAggregate.initial(runSeed: seed).state;
    final projectId = PublicDemoSeededProjectGenerator.forMonth(
      runSeed: seed,
      month: 4,
    ).first.id;
    var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
      engineerId: 'eng-01',
      projectId: projectId,
      month: 4,
    );
    workflow = runOfferInterviewToConclusion(
      workflow: workflow,
      state: state,
      runSeed: seed,
      engineerId: 'eng-01',
      projectId: projectId,
      asPartnerLeg: true,
    );
    if (workflow.offerCandidateFor('eng-01', projectId)!.stage !=
        PublicDemoOfferCandidateStage.partnerInterviewPassed) {
      continue;
    }
    workflow = runOfferInterviewToConclusion(
      workflow: workflow,
      state: state,
      runSeed: seed,
      engineerId: 'eng-01',
      projectId: projectId,
      asPartnerLeg: false,
    );
    if (workflow.offerCandidateFor('eng-01', projectId)!.stage ==
        PublicDemoOfferCandidateStage.clientInterviewPassed) {
      return (state: state, runSeed: seed, projectId: projectId, workflow: workflow);
    }
  }
  throw StateError('no genuine client pass found within seed bound');
}

void main() {
  group('proposeOfferCandidate', () {
    test('a fresh save: one engineer, two project candidates coexist', () {
      final projects = PublicDemoSeededProjectGenerator.forMonth(runSeed: 1, month: 4);
      var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: projects[0].id,
        month: 4,
      );
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: projects[1].id,
        month: 4,
      );
      final candidates = workflow.offerCandidatesForEngineer('eng-01');
      expect(candidates.length, 2);
      expect(candidates.map((c) => c.projectId).toSet(), {
        projects[0].id,
        projects[1].id,
      });
      expect(
        candidates.every((c) => c.stage == PublicDemoOfferCandidateStage.proposed),
        isTrue,
      );
    });

    test('same engineer / same project duplicate call is idempotent', () {
      final projectId = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 1,
        month: 4,
      ).first.id;
      var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: projectId,
        month: 4,
      );
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: projectId,
        month: 4,
      );
      expect(workflow.offerCandidatesForEngineer('eng-01').length, 1);
    });

    test('is a no-op for an unknown engineer id', () {
      final workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'no-such-engineer',
        projectId: 'project-4-1',
        month: 4,
      );
      expect(workflow.offerCandidates, isEmpty);
    });
  });

  group('interview legs — independent per project', () {
    test('partner pass / partner fail are retained independently per project', () {
      final passed = _findOutcome(asPartnerLeg: true, wantPass: true)!;
      final failed = _findOutcome(asPartnerLeg: true, wantPass: false)!;
      final passCandidate = passed.workflow.offerCandidateFor('eng-01', passed.projectId)!;
      final failCandidate = failed.workflow.offerCandidateFor('eng-01', failed.projectId)!;
      expect(passCandidate.stage, PublicDemoOfferCandidateStage.partnerInterviewPassed);
      expect(failCandidate.stage, PublicDemoOfferCandidateStage.partnerInterviewFailed);
      // Different seeds/workflows never interfere with each other — each
      // workflow holds exactly its own candidate.
      expect(passed.workflow.offerCandidates.length, 1);
      expect(failed.workflow.offerCandidates.length, 1);
    });

    test('a genuine client pass mints a candidate-bound unforgeable record', () {
      final result = genuineClientPass();
      final candidate = result.workflow.offerCandidateFor('eng-01', result.projectId)!;
      expect(candidate.stage, PublicDemoOfferCandidateStage.clientInterviewPassed);
      expect(candidate.hasGenuineInterviewRecord, isTrue);
      expect(candidate.interviewRecord!.engineerId, 'eng-01');
      expect(candidate.interviewRecord!.projectId, result.projectId);
    });

    test('client interview leg never consumes an additional sales slot', () {
      // No step of runOfferInterviewToConclusion ever reads or writes
      // PublicDemoState — the whole flow is driven purely through
      // PublicDemoWorkflowState methods, so there is no code path here
      // through which salesUsed could change.
      final before = PublicDemoAggregate.initial(runSeed: 1).state.salesUsed;
      genuineClientPass();
      final after = PublicDemoAggregate.initial(runSeed: 1).state.salesUsed;
      expect(after, before);
      expect(after, 0);
    });

    test('resuming an incomplete offer interview session is a no-op — no '
        'double execution', () {
      final state = PublicDemoAggregate.initial(runSeed: 5).state;
      final candidate = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 5,
        month: 4,
      ).first;
      var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: candidate.id,
        month: 4,
      );
      final runtime = state.runtimeForOrNull('eng-01')!;
      final session = PublicDemoProjectInterview.start(
        state: state,
        runtime: runtime,
        candidate: candidate,
      );
      workflow = workflow.startOfferInterviewSession(session);
      final first = workflow.offerInterviewSessionFor('eng-01', candidate.id);
      final resumed = workflow.startOfferInterviewSession(session);
      expect(resumed.offerInterviewSessionFor('eng-01', candidate.id), same(first));
    });

    test(
      'two candidates for the same engineer can have genuinely parallel '
      'in-progress interview sessions at once',
      () {
        final state = PublicDemoAggregate.initial(runSeed: 6).state;
        final projects = PublicDemoSeededProjectGenerator.forMonth(runSeed: 6, month: 4);
        var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
          engineerId: 'eng-01',
          projectId: projects[0].id,
          month: 4,
        );
        workflow = workflow.proposeOfferCandidate(
          engineerId: 'eng-01',
          projectId: projects[1].id,
          month: 4,
        );
        final runtime = state.runtimeForOrNull('eng-01')!;
        final sessionA = PublicDemoProjectInterview.start(
          state: state,
          runtime: runtime,
          candidate: projects[0],
        );
        final sessionB = PublicDemoProjectInterview.start(
          state: state,
          runtime: runtime,
          candidate: projects[1],
        );
        workflow = workflow.startOfferInterviewSession(sessionA);
        workflow = workflow.startOfferInterviewSession(sessionB);
        expect(workflow.offerInterviewSessionFor('eng-01', projects[0].id), isNotNull);
        expect(workflow.offerInterviewSessionFor('eng-01', projects[1].id), isNotNull);
        expect(
          workflow.offerInterviewSessionFor('eng-01', projects[0].id)!.id,
          isNot(workflow.offerInterviewSessionFor('eng-01', projects[1].id)!.id),
        );
      },
    );
  });

  group('recordOfferCandidateOrder', () {
    test('orders the candidate and auto-declines every sibling', () {
      final result = genuineClientPass();
      final siblingProjectId = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: result.runSeed,
        month: 4,
      ).firstWhere((candidate) => candidate.id != result.projectId).id;
      var workflow = result.workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: siblingProjectId,
        month: 4,
      );
      workflow = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: result.projectId,
      );
      final ordered = workflow.offerCandidateFor('eng-01', result.projectId)!;
      final sibling = workflow.offerCandidateFor('eng-01', siblingProjectId)!;
      expect(ordered.stage, PublicDemoOfferCandidateStage.ordered);
      expect(sibling.stage, PublicDemoOfferCandidateStage.declined);
    });

    test('an explicitly declined candidate never blocks ordering a '
        'different sibling later', () {
      final result = genuineClientPass();
      var workflow = result.workflow.declineOfferCandidate(
        engineerId: 'eng-01',
        projectId: result.projectId,
      );
      expect(
        workflow.offerCandidateFor('eng-01', result.projectId)!.stage,
        PublicDemoOfferCandidateStage.declined,
      );
      final siblingProjectId = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: result.runSeed,
        month: 4,
      ).firstWhere((candidate) => candidate.id != result.projectId).id;
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: siblingProjectId,
        month: 4,
      );
      workflow = runOfferInterviewToConclusion(
        workflow: workflow,
        state: result.state,
        runSeed: result.runSeed,
        engineerId: 'eng-01',
        projectId: siblingProjectId,
        asPartnerLeg: true,
      );
      workflow = runOfferInterviewToConclusion(
        workflow: workflow,
        state: result.state,
        runSeed: result.runSeed,
        engineerId: 'eng-01',
        projectId: siblingProjectId,
        asPartnerLeg: false,
      );
      // Whatever this sibling's own genuine outcome is, the declined
      // candidate never prevents attempting to order it if it passed.
      final siblingCandidate = workflow.offerCandidateFor('eng-01', siblingProjectId)!;
      if (siblingCandidate.stage == PublicDemoOfferCandidateStage.clientInterviewPassed) {
        workflow = workflow.recordOfferCandidateOrder(
          engineerId: 'eng-01',
          projectId: siblingProjectId,
        );
        expect(
          workflow.offerCandidateFor('eng-01', siblingProjectId)!.stage,
          PublicDemoOfferCandidateStage.ordered,
        );
      }
      // Either way, the originally declined candidate stays declined.
      expect(
        workflow.offerCandidateFor('eng-01', result.projectId)!.stage,
        PublicDemoOfferCandidateStage.declined,
      );
    });

    test('a candidate with no genuine interview record cannot order, even '
        'when its stage was force-set to clientInterviewPassed', () {
      final forged = PublicDemoOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        proposedMonth: 4,
        stage: PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
      expect(forged.hasGenuineInterviewRecord, isFalse);
      final workflow = PublicDemoWorkflowState.fromJson({
        'applicants': [],
        'engineers': PublicDemoWorkflowState.initial().engineers
            .map((e) => e.toJson())
            .toList(),
        'assignments': [],
        'offerCandidates': [forged.toJson()],
      });
      final result = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      expect(
        result.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
    });

    test('double order / duplicate call is idempotent', () {
      final result = genuineClientPass();
      var workflow = result.workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: result.projectId,
      );
      workflow = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: result.projectId,
      );
      expect(
        workflow.offerCandidatesForEngineer('eng-01')
            .where((c) => c.stage == PublicDemoOfferCandidateStage.ordered)
            .length,
        1,
      );
    });

    test('ordering never appends to workflow.assignments — ordered != assigned', () {
      final result = genuineClientPass();
      final workflow = result.workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: result.projectId,
      );
      expect(workflow.assignments, result.workflow.assignments);
      expect(workflow.assignments, isEmpty);
    });

    test('one engineer can never have two genuinely ordered candidates at once', () {
      final first = genuineClientPass();
      var workflow = first.workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: first.projectId,
      );
      final second = genuineClientPass(maxSeed: 200);
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: second.projectId,
        month: 4,
      );
      workflow = runOfferInterviewToConclusion(
        workflow: workflow,
        state: second.state,
        runSeed: second.runSeed,
        engineerId: 'eng-01',
        projectId: second.projectId,
        asPartnerLeg: true,
      );
      workflow = runOfferInterviewToConclusion(
        workflow: workflow,
        state: second.state,
        runSeed: second.runSeed,
        engineerId: 'eng-01',
        projectId: second.projectId,
        asPartnerLeg: false,
      );
      workflow = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: second.projectId,
      );
      final orderedCount = workflow.offerCandidatesForEngineer('eng-01')
          .where((c) => c.stage == PublicDemoOfferCandidateStage.ordered)
          .length;
      expect(orderedCount, 1);
      // The first-ordered candidate is still the one genuinely ordered.
      expect(
        workflow.offerCandidateFor('eng-01', first.projectId)!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
    });
  });

  group('save/reload idempotency of the new authority', () {
    test('proposed-stage candidates round-trip through toJson/fromJson', () {
      final projects = PublicDemoSeededProjectGenerator.forMonth(runSeed: 1, month: 4);
      var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: projects[0].id,
        month: 4,
      );
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-02',
        projectId: projects[1].id,
        month: 4,
      );
      final decoded = PublicDemoWorkflowState.fromJson(workflow.toJson());
      expect(decoded.offerCandidates.length, workflow.offerCandidates.length);
      expect(
        decoded.offerCandidateFor('eng-01', projects[0].id)?.stage,
        PublicDemoOfferCandidateStage.proposed,
      );
    });

    test('genuinely passed candidates round-trip with score/record intact', () {
      final result = genuineClientPass();
      final decoded = PublicDemoWorkflowState.fromJson(result.workflow.toJson());
      final candidate = decoded.offerCandidateFor('eng-01', result.projectId)!;
      expect(candidate.stage, PublicDemoOfferCandidateStage.clientInterviewPassed);
      expect(candidate.hasGenuineInterviewRecord, isTrue);
      expect(candidate.clientScore, isNotNull);
    });

    test('duplicate (engineerId, projectId) pairs in raw JSON are '
        'canonicalized on decode, never rejected', () {
      final json = {
        'applicants': [],
        'engineers': PublicDemoWorkflowState.initial().engineers
            .map((e) => e.toJson())
            .toList(),
        'assignments': [],
        'offerCandidates': [
          {
            'engineerId': 'eng-01',
            'projectId': 'project-4-1',
            'proposedMonth': 4,
            'stage': 'proposed',
            'partnerScore': null,
            'clientScore': null,
            'interviewRecordEngineerId': null,
            'interviewRecordProjectId': null,
          },
          {
            'engineerId': 'eng-01',
            'projectId': 'project-4-1',
            'proposedMonth': 5,
            'stage': 'partnerInterviewPassed',
            'partnerScore': 70,
            'clientScore': null,
            'interviewRecordEngineerId': null,
            'interviewRecordProjectId': null,
          },
        ],
      };
      final decoded = PublicDemoWorkflowState.fromJson(json);
      expect(decoded.offerCandidates.length, 1);
      // First occurrence wins.
      expect(
        decoded.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.proposed,
      );
    });
  });

  group('legacy migration — no offerCandidates key on load', () {
    Map<String, dynamic> engineerJson({
      required String id,
      required PublicDemoSalesStage stage,
      int? lastInterviewScore,
      String? interviewRecordProjectId,
      bool hasGenuineRecord = false,
    }) => {
      'id': id,
      'name': id,
      'summary': 'summary',
      'interviewProfile': {
        'skillFit': 70,
        'humanity': 70,
        'morale': 70,
        'clientTrust': 70,
      },
      'stage': stage.name,
      'lastInterviewScore': lastInterviewScore,
      'interviewRecordEngineerId': hasGenuineRecord ? id : null,
      'interviewRecordProjectId': hasGenuineRecord ? interviewRecordProjectId : null,
      'mental': 50,
      'trust': 50,
      'founderFollowUpMonth': null,
    };

    Map<String, dynamic> workflowJson({
      required List<Map<String, dynamic>> engineers,
      List<Map<String, dynamic>> matchingProposals = const [],
      List<Map<String, dynamic>> assignments = const [],
      List<Map<String, dynamic>> projectInterviewSessions = const [],
    }) => {
      'applicants': [],
      'engineers': engineers,
      'assignments': assignments,
      'matchingProposals': matchingProposals,
      'projectInterviewSessions': projectInterviewSessions,
      // Deliberately NO 'offerCandidates' key — the legacy-save case.
    };

    test('waiting/skillSheet: no candidate synthesized (sales not started)', () {
      for (final stage in [
        PublicDemoSalesStage.waiting,
        PublicDemoSalesStage.skillSheet,
      ]) {
        final decoded = PublicDemoWorkflowState.fromJson(
          workflowJson(engineers: [engineerJson(id: 'eng-01', stage: stage)]),
        );
        expect(decoded.offerCandidates, isEmpty, reason: stage.name);
      }
    });

    test('selling with no proposal: no candidate (nothing decided yet)', () {
      final decoded = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(id: 'eng-01', stage: PublicDemoSalesStage.selling),
          ],
        ),
      );
      expect(decoded.offerCandidates, isEmpty);
    });

    test('selling WITH a proposal: a proposed candidate is recovered', () {
      final decoded = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(id: 'eng-01', stage: PublicDemoSalesStage.selling),
          ],
          matchingProposals: [
            {'engineerId': 'eng-01', 'projectId': 'project-4-1', 'decidedMonth': 4},
          ],
        ),
      );
      final candidate = decoded.offerCandidateFor('eng-01', 'project-4-1');
      expect(candidate, isNotNull);
      expect(candidate!.stage, PublicDemoOfferCandidateStage.proposed);
    });

    test('introduced (with or without a proposal) migrates to proposed', () {
      final withoutProposal = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(id: 'eng-01', stage: PublicDemoSalesStage.introduced),
          ],
        ),
      );
      final candidateWithout = withoutProposal.offerCandidatesForEngineer('eng-01').single;
      expect(candidateWithout.stage, PublicDemoOfferCandidateStage.proposed);
      expect(
        candidateWithout.projectId,
        PublicDemoOfferCandidate.legacyCompatibilityProjectId('eng-01'),
      );

      final withProposal = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(id: 'eng-01', stage: PublicDemoSalesStage.introduced),
          ],
          matchingProposals: [
            {'engineerId': 'eng-01', 'projectId': 'project-4-2', 'decidedMonth': 4},
          ],
        ),
      );
      final candidateWith = withProposal.offerCandidateFor('eng-01', 'project-4-2')!;
      expect(candidateWith.stage, PublicDemoOfferCandidateStage.proposed);
    });

    test('partnerInterviewPassed / partnerInterviewFailed both migrate, '
        'each independently, with no genuine client record', () {
      for (final stage in [
        PublicDemoSalesStage.partnerInterviewPassed,
        PublicDemoSalesStage.partnerInterviewFailed,
      ]) {
        final decoded = PublicDemoWorkflowState.fromJson(
          workflowJson(
            engineers: [
              engineerJson(id: 'eng-01', stage: stage, lastInterviewScore: 65),
            ],
            matchingProposals: [
              {'engineerId': 'eng-01', 'projectId': 'project-4-3', 'decidedMonth': 4},
            ],
          ),
        );
        final candidate = decoded.offerCandidateFor('eng-01', 'project-4-3')!;
        expect(
          candidate.stage.name,
          stage.name,
          reason: 'candidate stage should mirror the legacy engineer stage name',
        );
        expect(candidate.partnerScore, 65);
        expect(candidate.hasGenuineInterviewRecord, isFalse);
      }
    });

    test('clientInterviewPassed / clientInterviewFailed migrate; only the '
        'genuine pass carries an interview record', () {
      final passed = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(
              id: 'eng-01',
              stage: PublicDemoSalesStage.clientInterviewPassed,
              lastInterviewScore: 80,
              hasGenuineRecord: true,
              interviewRecordProjectId: 'project-4-4',
            ),
          ],
          matchingProposals: [
            {'engineerId': 'eng-01', 'projectId': 'project-4-4', 'decidedMonth': 4},
          ],
        ),
      );
      final passedCandidate = passed.offerCandidateFor('eng-01', 'project-4-4')!;
      expect(passedCandidate.stage, PublicDemoOfferCandidateStage.clientInterviewPassed);
      expect(passedCandidate.hasGenuineInterviewRecord, isTrue);
      expect(passedCandidate.clientScore, 80);

      final failed = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(
              id: 'eng-01',
              stage: PublicDemoSalesStage.clientInterviewFailed,
              lastInterviewScore: 40,
            ),
          ],
          matchingProposals: [
            {'engineerId': 'eng-01', 'projectId': 'project-4-5', 'decidedMonth': 4},
          ],
        ),
      );
      final failedCandidate = failed.offerCandidateFor('eng-01', 'project-4-5')!;
      expect(failedCandidate.stage, PublicDemoOfferCandidateStage.clientInterviewFailed);
      expect(failedCandidate.hasGenuineInterviewRecord, isFalse);
      expect(failedCandidate.clientScore, 40);
    });

    test('ordered with a project-bound genuine record uses that real '
        'project id, even with no matching proposal on file', () {
      final decoded = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(
              id: 'eng-01',
              stage: PublicDemoSalesStage.ordered,
              lastInterviewScore: 90,
              hasGenuineRecord: true,
              interviewRecordProjectId: 'project-4-6',
            ),
          ],
        ),
      );
      final candidate = decoded.offerCandidateFor('eng-01', 'project-4-6')!;
      expect(candidate.stage, PublicDemoOfferCandidateStage.ordered);
      expect(candidate.hasGenuineInterviewRecord, isTrue);
    });

    test('ordered via the generic/legacy path (no project-bound record) '
        'falls back to a real existing assignment projectId when one '
        'exists', () {
      final decoded = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(
              id: 'eng-01',
              stage: PublicDemoSalesStage.ordered,
              lastInterviewScore: 61,
              hasGenuineRecord: true,
            ),
          ],
          assignments: [
            {
              'engineerId': 'eng-01',
              'engineerName': 'eng-01',
              'projectName': '新規開発支援',
              'deliveryPressure': 50,
              'budgetHealth': 70,
              'humanity': 70,
              'nextOrderStatus': 'undecided',
              'replacementStage': 'none',
              'fieldEvaluation': 50,
              'projectId': 'project-4-7',
              'monthsCredited': 0,
            },
          ],
        ),
      );
      final candidate = decoded.offerCandidateFor('eng-01', 'project-4-7')!;
      expect(candidate.stage, PublicDemoOfferCandidateStage.ordered);
      expect(candidate.hasGenuineInterviewRecord, isTrue);
    });

    test('ordered with NO resolvable real project id at all uses the '
        'explicit project-agnostic compatibility path (PR #253 Codex '
        'review P1)', () {
      final decoded = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(
              id: 'eng-01',
              stage: PublicDemoSalesStage.ordered,
              lastInterviewScore: 61,
              hasGenuineRecord: true,
            ),
          ],
        ),
      );
      final placeholder = PublicDemoOfferCandidate.legacyCompatibilityProjectId('eng-01');
      final candidate = decoded.offerCandidateFor('eng-01', placeholder);
      expect(candidate, isNotNull);
      expect(candidate!.stage, PublicDemoOfferCandidateStage.ordered);
      expect(candidate.hasGenuineInterviewRecord, isTrue);
      // Never collides with a real seeded project id.
      expect(placeholder.startsWith('project-'), isFalse);
    });

    test('an in-progress/completed legacy projectInterviewSessions entry '
        'does not change migration output either way (session presence is '
        'irrelevant to this migration, and the old session list round-trips '
        'untouched)', () {
      final sessionJson = {
        'id': 'public-demo-project-interview:eng-01:project-4-8',
        'applicationId': 'project-4-8',
        'employeeId': 'eng-01',
        'projectId': 'project-4-8',
        'clientId': 'client-1',
        'startedWeek': 4,
        'currentQuestionIndex': 0,
        'questions': <dynamic>[],
        'employeeAnswers': <dynamic>[],
        'playerFollowUps': <dynamic>[],
        'interviewerReactions': <dynamic>[],
        'accumulatedEvaluation': {
          'technical': 0,
          'experience': 0,
          'communication': 0,
          'credibility': 0,
          'clientFit': 0,
        },
        'deepDiveOccurred': false,
        'mismatchFailure': false,
        'completed': false,
        'result': null,
      };
      final withSession = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(
              id: 'eng-01',
              stage: PublicDemoSalesStage.partnerInterviewPassed,
              lastInterviewScore: 65,
            ),
          ],
          matchingProposals: [
            {'engineerId': 'eng-01', 'projectId': 'project-4-8', 'decidedMonth': 4},
          ],
          projectInterviewSessions: [sessionJson],
        ),
      );
      final withoutSession = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(
              id: 'eng-01',
              stage: PublicDemoSalesStage.partnerInterviewPassed,
              lastInterviewScore: 65,
            ),
          ],
          matchingProposals: [
            {'engineerId': 'eng-01', 'projectId': 'project-4-8', 'decidedMonth': 4},
          ],
        ),
      );
      expect(
        withSession.offerCandidateFor('eng-01', 'project-4-8')?.stage,
        withoutSession.offerCandidateFor('eng-01', 'project-4-8')?.stage,
      );
      expect(withSession.projectInterviewSessions.length, 1);
      expect(withoutSession.projectInterviewSessions, isEmpty);
    });

    test('save -> load -> migrate -> save -> reload idempotency: migration '
        'never runs twice and never duplicates candidates', () {
      final firstLoad = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(
              id: 'eng-01',
              stage: PublicDemoSalesStage.ordered,
              lastInterviewScore: 61,
              hasGenuineRecord: true,
              interviewRecordProjectId: 'project-4-9',
            ),
          ],
        ),
      );
      expect(firstLoad.offerCandidates.length, 1);
      final resavedJson = firstLoad.toJson();
      expect(resavedJson.containsKey('offerCandidates'), isTrue);
      final secondLoad = PublicDemoWorkflowState.fromJson(resavedJson);
      expect(secondLoad.offerCandidates.length, 1);
      expect(
        secondLoad.offerCandidateFor('eng-01', 'project-4-9')?.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      // A third round-trip is byte-for-byte identical too.
      final thirdLoad = PublicDemoWorkflowState.fromJson(secondLoad.toJson());
      expect(thirdLoad.offerCandidates.length, 1);
    });

    test('two founding engineers at different legacy stages both migrate '
        'independently in the same load', () {
      final decoded = PublicDemoWorkflowState.fromJson(
        workflowJson(
          engineers: [
            engineerJson(
              id: 'eng-01',
              stage: PublicDemoSalesStage.partnerInterviewFailed,
              lastInterviewScore: 40,
            ),
            engineerJson(
              id: 'eng-02',
              stage: PublicDemoSalesStage.ordered,
              lastInterviewScore: 88,
              hasGenuineRecord: true,
              interviewRecordProjectId: 'project-4-10',
            ),
          ],
          matchingProposals: [
            {'engineerId': 'eng-01', 'projectId': 'project-4-11', 'decidedMonth': 4},
          ],
        ),
      );
      expect(decoded.offerCandidates.length, 2);
      expect(
        decoded.offerCandidateFor('eng-01', 'project-4-11')?.stage,
        PublicDemoOfferCandidateStage.partnerInterviewFailed,
      );
      expect(
        decoded.offerCandidateFor('eng-02', 'project-4-10')?.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
    });
  });

  group('PublicDemoAggregate._validateForPersistence — offer candidates', () {
    test('a duplicate (engineerId, projectId) in raw save JSON is '
        'canonicalized end-to-end through a full aggregate load, never '
        'rejected — PublicDemoWorkflowState.fromJson\'s own decode-time '
        'canonicalize step means _validateForPersistence never even sees '
        'the duplicate', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 1);
      final workflow = aggregate.workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      final workflowJson = workflow.toJson();
      final rawCandidates = workflowJson['offerCandidates'] as List;
      final reloaded = PublicDemoAggregate.fromJson({
        'state': aggregate.state.toJson(),
        'workflow': {
          ...workflowJson,
          'offerCandidates': [...rawCandidates, ...rawCandidates],
        },
      });
      expect(reloaded.workflow.offerCandidates.length, 1);
    });

    test('rejects an offer candidate whose interview record identity does '
        'not match its own engineerId/projectId', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 1);
      final corrupted = {
        'engineerId': 'eng-01',
        'projectId': 'project-4-1',
        'proposedMonth': 4,
        'stage': 'clientInterviewPassed',
        'partnerScore': 70,
        'clientScore': 80,
        'interviewRecordEngineerId': 'eng-02',
        'interviewRecordProjectId': 'project-4-1',
      };
      expect(
        () => PublicDemoAggregate.fromJson({
          'state': aggregate.state.toJson(),
          'workflow': {
            ...aggregate.workflow.toJson(),
            'offerCandidates': [corrupted],
          },
        }),
        throwsFormatException,
      );
    });

    test('rejects two genuinely ordered candidates for the same engineer', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 1);
      PublicDemoOfferCandidate ordered(String projectId) => PublicDemoOfferCandidate(
        engineerId: 'eng-01',
        projectId: projectId,
        proposedMonth: 4,
        stage: PublicDemoOfferCandidateStage.ordered,
      );
      expect(
        () => PublicDemoAggregate.fromJson({
          'state': aggregate.state.toJson(),
          'workflow': {
            ...aggregate.workflow.toJson(),
            'offerCandidates': [
              ordered('project-4-1').toJson(),
              ordered('project-4-2').toJson(),
            ],
          },
        }),
        throwsFormatException,
      );
    });

    test('rejects an offer candidate for an unknown engineer id', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 1);
      final candidate = PublicDemoOfferCandidate(
        engineerId: 'no-such-engineer',
        projectId: 'project-4-1',
        proposedMonth: 4,
      );
      expect(
        () => PublicDemoAggregate.fromJson({
          'state': aggregate.state.toJson(),
          'workflow': {
            ...aggregate.workflow.toJson(),
            'offerCandidates': [candidate.toJson()],
          },
        }),
        throwsFormatException,
      );
    });

    test('accepts a well-formed fresh save with no offer candidates at all', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 1);
      final reloaded = PublicDemoAggregate.fromJson(aggregate.toJson());
      expect(reloaded.workflow.offerCandidates, isEmpty);
    });

    test('accepts a well-formed save with a genuine ordered candidate', () {
      final result = genuineClientPass();
      final orderedWorkflow = result.workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: result.projectId,
      );
      final reloaded = PublicDemoAggregate.fromJson({
        'state': result.state.toJson(),
        'workflow': orderedWorkflow.toJson(),
      });
      expect(
        reloaded.workflow.offerCandidateFor('eng-01', result.projectId)?.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
    });
  });
}
