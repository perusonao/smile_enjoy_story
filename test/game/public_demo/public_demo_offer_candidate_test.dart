import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_offer_candidate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';

/// Issue #245 Finding #4, Phase 1a (Domain Foundation): coverage for
/// [PublicDemoOfferCandidate]/[PublicDemoOfferCandidateStage] and
/// [PublicDemoWorkflowState.offerCandidates]' lookup/upsert/lifecycle
/// plumbing. See docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1a_Result.md.
///
/// Phase 1a is purely additive: none of these tests touch
/// [PublicDemoEngineerSales.stage]/`matchingProposals`/
/// `projectInterviewSessions`/`recordOrder`/`assignOrderedForMay` as
/// authority for the new list — where a scenario needs a realistic legacy
/// fixture, it drives those existing, unchanged commands first and then
/// exercises the migration/round-trip path on top.
void main() {
  const strongProfile = PublicDemoInterviewProfile(
    skillFit: 100,
    humanity: 100,
    morale: 100,
    clientTrust: 100,
  );
  const weakProfile = PublicDemoInterviewProfile(
    skillFit: 0,
    humanity: 0,
    morale: 0,
    clientTrust: 0,
  );

  group('PublicDemoOfferCandidate identity', () {
    test('id is always derived from (engineerId, projectId), never an '
        'independently stored/settable field', () {
      final candidate = PublicDemoOfferCandidate.propose(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        proposedMonth: 4,
      );
      expect(candidate.id, 'eng-01::project-4-1');
    });

    test('propose() starts at proposed, no scores, no interview record', () {
      final candidate = PublicDemoOfferCandidate.propose(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        proposedMonth: 4,
      );
      expect(candidate.stage, PublicDemoOfferCandidateStage.proposed);
      expect(candidate.partnerScore, isNull);
      expect(candidate.clientScore, isNull);
      expect(candidate.interviewRecord, isNull);
      expect(candidate.hasGenuineInterviewRecord, isFalse);
      expect(candidate.isTerminal, isFalse);
    });
  });

  group('PublicDemoOfferCandidate lifecycle', () {
    PublicDemoOfferCandidate proposed() => PublicDemoOfferCandidate.propose(
      engineerId: 'eng-01',
      projectId: 'project-4-1',
      proposedMonth: 4,
    );

    test('evaluatePartnerInterview: a strong profile passes and records '
        'partnerScore', () {
      final result = proposed().evaluatePartnerInterview(
        profile: strongProfile,
      );
      expect(result.stage, PublicDemoOfferCandidateStage.partnerInterviewPassed);
      expect(result.partnerScore, 100);
      expect(result.interviewRecord, isNull); // never minted at partner stage
    });

    test('evaluatePartnerInterview: a weak profile fails, then a retry with '
        'a strong profile passes (failed candidates are re-attemptable, '
        'mirroring beginSelling\'s own recovery path)', () {
      final failed = proposed().evaluatePartnerInterview(profile: weakProfile);
      expect(failed.stage, PublicDemoOfferCandidateStage.partnerInterviewFailed);
      expect(failed.partnerScore, 0);

      final retried = failed.evaluatePartnerInterview(profile: strongProfile);
      expect(retried.stage, PublicDemoOfferCandidateStage.partnerInterviewPassed);
      expect(retried.partnerScore, 100);
    });

    test('evaluatePartnerInterview is a no-op (double tap / idempotent) once '
        'already partnerInterviewPassed', () {
      final passed = proposed().evaluatePartnerInterview(profile: strongProfile);
      final retapped = passed.evaluatePartnerInterview(profile: weakProfile);
      expect(retapped.stage, PublicDemoOfferCandidateStage.partnerInterviewPassed);
      expect(retapped.partnerScore, 100); // unchanged, not overwritten to 0
    });

    test('evaluateClientInterview is a no-op while still proposed (partner '
        'interview must happen first)', () {
      final result = proposed().evaluateClientInterview(profile: strongProfile);
      expect(result, proposed());
    });

    test('evaluateClientInterview: pass mints an interview record bound to '
        'this exact candidate identity', () {
      final atClient = proposed().evaluatePartnerInterview(
        profile: strongProfile,
      );
      final passed = atClient.evaluateClientInterview(profile: strongProfile);
      expect(passed.stage, PublicDemoOfferCandidateStage.clientInterviewPassed);
      expect(passed.clientScore, 100);
      expect(passed.hasGenuineInterviewRecord, isTrue);
      expect(passed.interviewRecord!.engineerId, 'eng-01');
      expect(passed.interviewRecord!.projectId, 'project-4-1');
    });

    test('evaluateClientInterview: fail then retry to pass, mirroring the '
        'partner-stage retry contract', () {
      final atClient = proposed().evaluatePartnerInterview(
        profile: strongProfile,
      );
      final failed = atClient.evaluateClientInterview(profile: weakProfile);
      expect(failed.stage, PublicDemoOfferCandidateStage.clientInterviewFailed);
      expect(failed.hasGenuineInterviewRecord, isFalse);

      final retried = failed.evaluateClientInterview(profile: strongProfile);
      expect(retried.stage, PublicDemoOfferCandidateStage.clientInterviewPassed);
      expect(retried.hasGenuineInterviewRecord, isTrue);
    });

    test('evaluateClientInterview is a no-op (double tap) once already '
        'clientInterviewPassed — never re-derives a second, different '
        'record', () {
      final passed = proposed()
          .evaluatePartnerInterview(profile: strongProfile)
          .evaluateClientInterview(profile: strongProfile);
      final retapped = passed.evaluateClientInterview(profile: weakProfile);
      expect(retapped, passed);
    });

    test('markOrdered requires clientInterviewPassed AND a genuine record — '
        'a forged clientInterviewPassed candidate with no record (e.g. from '
        'a malformed but structurally-legal state) cannot be ordered', () {
      // Constructed directly (not via evaluateClientInterview) to simulate
      // data that reached this stage without ever having gone through a
      // genuine evaluation — the exact "deserialized data alone must never
      // be able to forge order/assignment authority" invariant.
      const forged = PublicDemoOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        proposedMonth: 4,
        stage: PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
      expect(forged.hasGenuineInterviewRecord, isFalse);
      final result = forged.markOrdered();
      expect(result, forged); // unchanged — no-op
      expect(result.stage, isNot(PublicDemoOfferCandidateStage.ordered));
    });

    test('markOrdered succeeds only after a genuine client-interview pass, '
        'and is idempotent once ordered', () {
      final passed = proposed()
          .evaluatePartnerInterview(profile: strongProfile)
          .evaluateClientInterview(profile: strongProfile);
      final ordered = passed.markOrdered();
      expect(ordered.stage, PublicDemoOfferCandidateStage.ordered);
      expect(ordered.isTerminal, isTrue);

      final reordered = ordered.markOrdered();
      expect(reordered, ordered); // safe re-entry, not an error
    });

    test('decline is a no-op once ordered — an order is final, never '
        'retroactively declined', () {
      final ordered = proposed()
          .evaluatePartnerInterview(profile: strongProfile)
          .evaluateClientInterview(profile: strongProfile)
          .markOrdered();
      final result = ordered.decline();
      expect(result, ordered);
      expect(result.stage, PublicDemoOfferCandidateStage.ordered);
    });

    test('decline is idempotent once already declined', () {
      final declined = proposed().decline();
      expect(declined.stage, PublicDemoOfferCandidateStage.declined);
      final again = declined.decline();
      expect(again, declined);
    });

    test('decline closes a live candidate at any non-terminal stage', () {
      expect(
        proposed().decline().stage,
        PublicDemoOfferCandidateStage.declined,
      );
      expect(
        proposed()
            .evaluatePartnerInterview(profile: strongProfile)
            .decline()
            .stage,
        PublicDemoOfferCandidateStage.declined,
      );
      expect(
        proposed()
            .evaluatePartnerInterview(profile: strongProfile)
            .evaluateClientInterview(profile: strongProfile)
            .decline()
            .stage,
        PublicDemoOfferCandidateStage.declined,
      );
    });
  });

  group('PublicDemoOfferCandidate serialization', () {
    test('round-trips a proposed candidate', () {
      final candidate = PublicDemoOfferCandidate.propose(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        proposedMonth: 4,
      );
      final restored = PublicDemoOfferCandidate.fromJson(candidate.toJson());
      expect(restored, candidate);
    });

    test('round-trips a candidate with its own partner/client scores and '
        'genuine interview record', () {
      final candidate = PublicDemoOfferCandidate.propose(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            proposedMonth: 4,
          )
          .evaluatePartnerInterview(profile: strongProfile)
          .evaluateClientInterview(profile: strongProfile);
      final restored = PublicDemoOfferCandidate.fromJson(candidate.toJson());
      expect(restored, candidate);
      expect(restored.hasGenuineInterviewRecord, isTrue);
    });

    test('round-trips an ordered and a declined candidate', () {
      final ordered = PublicDemoOfferCandidate.propose(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            proposedMonth: 4,
          )
          .evaluatePartnerInterview(profile: strongProfile)
          .evaluateClientInterview(profile: strongProfile)
          .markOrdered();
      expect(PublicDemoOfferCandidate.fromJson(ordered.toJson()), ordered);

      final declined = PublicDemoOfferCandidate.propose(
        engineerId: 'eng-02',
        projectId: 'project-4-2',
        proposedMonth: 4,
      ).decline();
      expect(PublicDemoOfferCandidate.fromJson(declined.toJson()), declined);
    });

    test('fromJson rejects an empty engineerId/projectId (malformed)', () {
      final base = PublicDemoOfferCandidate.propose(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        proposedMonth: 4,
      ).toJson();
      expect(
        () => PublicDemoOfferCandidate.fromJson({...base, 'engineerId': ''}),
        throwsFormatException,
      );
      expect(
        () => PublicDemoOfferCandidate.fromJson({...base, 'projectId': ''}),
        throwsFormatException,
      );
    });

    test('fromJson rejects an unknown stage name (malformed)', () {
      final base = PublicDemoOfferCandidate.propose(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        proposedMonth: 4,
      ).toJson();
      expect(
        () => PublicDemoOfferCandidate.fromJson({...base, 'stage': 'bogus'}),
        throwsFormatException,
      );
    });

    test('fromJson rejects an interview record bound to a different '
        'engineerId/projectId than this candidate\'s own (identity '
        'mismatch)', () {
      final base = PublicDemoOfferCandidate.propose(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            proposedMonth: 4,
          )
          .evaluatePartnerInterview(profile: strongProfile)
          .evaluateClientInterview(profile: strongProfile)
          .toJson();
      expect(
        () => PublicDemoOfferCandidate.fromJson({
          ...base,
          'interviewRecordEngineerId': 'eng-99',
        }),
        throwsFormatException,
      );
      expect(
        () => PublicDemoOfferCandidate.fromJson({
          ...base,
          'interviewRecordProjectId': 'project-4-99',
        }),
        throwsFormatException,
      );
    });

    test('fromJson rejects a partially-bound interview record (one of '
        'engineerId/projectId present without the other)', () {
      final base = PublicDemoOfferCandidate.propose(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        proposedMonth: 4,
      ).toJson();
      expect(
        () => PublicDemoOfferCandidate.fromJson({
          ...base,
          'interviewRecordEngineerId': 'eng-01',
        }),
        throwsFormatException,
      );
    });
  });

  group('PublicDemoWorkflowState offerCandidates lookup/upsert', () {
    test('offerCandidateFor returns null before any proposal', () {
      final workflow = PublicDemoWorkflowState.initial();
      expect(workflow.offerCandidateFor('eng-01', 'project-4-1'), isNull);
    });

    test('proposeOfferCandidate records a candidate resolvable via '
        'offerCandidateFor', () {
      final workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      final candidate = workflow.offerCandidateFor('eng-01', 'project-4-1');
      expect(candidate, isNotNull);
      expect(candidate!.stage, PublicDemoOfferCandidateStage.proposed);
      expect(candidate.proposedMonth, 4);
    });

    test('proposeOfferCandidate is a no-op for an unknown engineer id', () {
      final workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'not-a-real-engineer',
        projectId: 'project-4-1',
        month: 4,
      );
      expect(workflow.offerCandidates, isEmpty);
    });

    test('duplicate composite key: a second proposeOfferCandidate for the '
        'same (engineerId, projectId) is a no-op, never accumulating and '
        'never resetting existing progress (retry/idempotency)', () {
      var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      workflow = workflow.evaluatePartnerInterviewForCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        profile: strongProfile,
      );
      final beforeRetry = workflow.offerCandidateFor('eng-01', 'project-4-1');
      expect(
        beforeRetry!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewPassed,
      );

      // A later re-propose for the exact same pair must not reset progress.
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 5,
      );
      expect(workflow.offerCandidates, hasLength(1));
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-1'),
        beforeRetry,
      );
    });

    test('1 engineer / 2 projects: both proposed and tracked independently', () {
      var workflow = PublicDemoWorkflowState.initial();
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-2',
        month: 4,
      );
      expect(workflow.offerCandidatesForEngineer('eng-01'), hasLength(2));

      workflow = workflow.evaluatePartnerInterviewForCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        profile: strongProfile,
      );
      // The sibling for project-4-2 is untouched by the project-4-1 result.
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewPassed,
      );
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-2')!.stage,
        PublicDemoOfferCandidateStage.proposed,
      );
    });

    test('2 engineers / same project: independent candidates, one per '
        'engineer', () {
      var workflow = PublicDemoWorkflowState.initial();
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      workflow = workflow.proposeOfferCandidate(
        engineerId: 'eng-02',
        projectId: 'project-4-1',
        month: 4,
      );
      expect(workflow.offerCandidates, hasLength(2));
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-1')!.engineerId,
        'eng-01',
      );
      expect(
        workflow.offerCandidateFor('eng-02', 'project-4-1')!.engineerId,
        'eng-02',
      );
    });

    test('evaluate*ForCandidate is a no-op for a stale/unknown '
        '(engineerId, projectId) pair — a since-declined/replaced or never '
        'proposed identity never gets silently advanced', () {
      var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      // A different projectId for the same engineer: no candidate exists
      // there, so this must not affect the real candidate either.
      final unaffected = workflow.evaluatePartnerInterviewForCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-2',
        profile: strongProfile,
      );
      expect(unaffected, workflow);

      final declineUnknown = workflow.declineOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-2',
      );
      expect(declineUnknown, workflow);
    });

    test('One pass / one fail: independent stage per candidate for the same '
        'engineer', () {
      var workflow = PublicDemoWorkflowState.initial();
      workflow = workflow
          .proposeOfferCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            month: 4,
          )
          .proposeOfferCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-2',
            month: 4,
          );
      workflow = workflow
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            profile: strongProfile,
          )
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-2',
            profile: weakProfile,
          );
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewPassed,
      );
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-2')!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewFailed,
      );
    });

    test('Order one -> others explicitly close (auto-decline every live '
        'sibling for the same engineer; an already-failed sibling is left '
        'alone)', () {
      var workflow = PublicDemoWorkflowState.initial();
      for (final projectId in [
        'project-4-1', // will be ordered
        'project-4-2', // still proposed
        'project-5-1', // partnerInterviewPassed
        'project-5-2', // clientInterviewFailed (already terminal-ish)
      ]) {
        workflow = workflow.proposeOfferCandidate(
          engineerId: 'eng-01',
          projectId: projectId,
          month: 4,
        );
      }
      workflow = workflow
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            profile: strongProfile,
          )
          .evaluateClientInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            profile: strongProfile,
          )
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-5-1',
            profile: strongProfile,
          )
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-5-2',
            profile: strongProfile,
          )
          .evaluateClientInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-5-2',
            profile: weakProfile,
          );

      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );

      workflow = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );

      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-2')!.stage,
        PublicDemoOfferCandidateStage.declined,
        reason: 'a still-proposed sibling is a live competing candidate',
      );
      expect(
        workflow.offerCandidateFor('eng-01', 'project-5-1')!.stage,
        PublicDemoOfferCandidateStage.declined,
        reason: 'a partnerInterviewPassed sibling is a live competing '
            'candidate',
      );
      expect(
        workflow.offerCandidateFor('eng-01', 'project-5-2')!.stage,
        PublicDemoOfferCandidateStage.clientInterviewFailed,
        reason: 'an already-failed sibling is not a live competitor and is '
            'left untouched',
      );
    });

    test('Decline -> order the other later: a previously-declined sibling '
        'never blocks ordering a different candidate for the same '
        'engineer', () {
      var workflow = PublicDemoWorkflowState.initial();
      workflow = workflow
          .proposeOfferCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            month: 4,
          )
          .proposeOfferCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-2',
            month: 4,
          );
      workflow = workflow.declineOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      workflow = workflow
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-2',
            profile: strongProfile,
          )
          .evaluateClientInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-2',
            profile: strongProfile,
          );
      workflow = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-2',
      );
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-2')!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.declined,
      );
    });

    test('recordOfferCandidateOrder is a no-op unless the target is '
        'genuinely clientInterviewPassed with its own record — a duplicate '
        'call after already ordered changes nothing further (terminal '
        're-entry is safe)', () {
      var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      // Too early: still `proposed`.
      final tooEarly = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      expect(
        tooEarly.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.proposed,
      );

      workflow = workflow
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            profile: strongProfile,
          )
          .evaluateClientInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            profile: strongProfile,
          );
      final ordered = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      final orderedAgain = ordered.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      expect(orderedAgain.offerCandidates, ordered.offerCandidates);
    });

    test('a forged clientInterviewPassed candidate with no genuine record '
        '(reachable only through hand-built JSON, never through the real '
        'evaluate*/propose chain) cannot be ordered via '
        'recordOfferCandidateOrder — deserialized data alone can never '
        'forge order authority', () {
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
      final workflow = PublicDemoWorkflowState.fromJson(forgedJson);
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
      final result = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      expect(
        result.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
        reason: 'no genuine interviewRecord -> order is refused',
      );
    });

    test('ordered != assigned: recordOfferCandidateOrder never appends to '
        'assignments — only assignOrderedForMay/recoverLateYearAssignment '
        'may do that, and neither is called here', () {
      var workflow = PublicDemoWorkflowState.initial().proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      workflow = workflow
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            profile: strongProfile,
          )
          .evaluateClientInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            profile: strongProfile,
          );
      expect(workflow.assignments, isEmpty);
      workflow = workflow.recordOfferCandidateOrder(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      expect(
        workflow.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      expect(workflow.assignments, isEmpty);
    });
  });

  group('PublicDemoWorkflowState offerCandidates persistence', () {
    test('toJson/fromJson round-trips several candidates in different '
        'stages, side by side, before any order decision', () {
      var workflow = PublicDemoWorkflowState.initial();
      workflow = workflow
          .proposeOfferCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            month: 4,
          )
          .proposeOfferCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-2',
            month: 4,
          )
          .proposeOfferCandidate(
            engineerId: 'eng-02',
            projectId: 'project-4-1',
            month: 4,
          );
      workflow = workflow
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            profile: strongProfile,
          )
          .evaluateClientInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            profile: strongProfile,
          )
          .evaluatePartnerInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-2',
            profile: strongProfile,
          )
          .evaluateClientInterviewForCandidate(
            engineerId: 'eng-01',
            projectId: 'project-4-2',
            profile: strongProfile,
          );

      // Save/reload before order selection: two clientInterviewPassed
      // candidates for the same engineer persist side by side, neither
      // auto-resolves on load.
      final restored = PublicDemoWorkflowState.fromJson(workflow.toJson());
      expect(restored.offerCandidates, hasLength(3));
      expect(
        restored.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
      expect(
        restored.offerCandidateFor('eng-01', 'project-4-2')!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
      expect(
        restored.offerCandidateFor('eng-02', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.proposed,
      );
      for (final candidate in workflow.offerCandidates) {
        expect(
          restored.offerCandidateFor(candidate.engineerId, candidate.projectId),
          candidate,
        );
      }
    });

    test('a legacy save with no offerCandidates key at all decodes to an '
        'empty list when no engineer is at a relevant stage — never a '
        'rejected save', () {
      final legacyJson = PublicDemoWorkflowState.initial().toJson()
        ..remove('offerCandidates');
      final restored = PublicDemoWorkflowState.fromJson(legacyJson);
      expect(restored.offerCandidates, isEmpty);
    });

    test('fromJson rejects a duplicate (engineerId, projectId) composite '
        'key', () {
      final duplicateEntry = {
        'engineerId': 'eng-01',
        'projectId': 'project-4-1',
        'proposedMonth': 4,
        'stage': 'proposed',
        'partnerScore': null,
        'clientScore': null,
        'interviewRecordEngineerId': null,
        'interviewRecordProjectId': null,
      };
      final json = {
        ...PublicDemoWorkflowState.initial().toJson(),
        'offerCandidates': [duplicateEntry, duplicateEntry],
      };
      expect(
        () => PublicDemoWorkflowState.fromJson(json),
        throwsFormatException,
      );
    });

    test('fromJson rejects an offer candidate referencing an unknown '
        'engineerId', () {
      final json = {
        ...PublicDemoWorkflowState.initial().toJson(),
        'offerCandidates': [
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
        ],
      };
      expect(
        () => PublicDemoWorkflowState.fromJson(json),
        throwsFormatException,
      );
    });

    test('fromJson rejects a malformed candidate entry (missing required '
        'field)', () {
      final json = {
        ...PublicDemoWorkflowState.initial().toJson(),
        'offerCandidates': [
          {
            'engineerId': 'eng-01',
            // 'projectId' missing entirely.
            'proposedMonth': 4,
            'stage': 'proposed',
          },
        ],
      };
      expect(
        () => PublicDemoWorkflowState.fromJson(json),
        throwsFormatException,
      );
    });

    test('month boundary: offerCandidates survive a month close untouched '
        'unless explicitly declined/ordered — no code path in the monthly '
        'close reads or writes this list', () {
      var aggregate = PublicDemoAggregate.initial();
      final candidateProject = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: candidateProject.id,
      );
      final before = aggregate.offerCandidateFor(
        'eng-01',
        candidateProject.id,
      );
      expect(before, isNotNull);

      aggregate = aggregate.closeApril(monthlyExpenses: 10000);
      aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 10000);
      aggregate = aggregate.closeJune(
        assignedInJuly: 0,
        monthlyExpenses: 10000,
      );

      final after = aggregate.offerCandidateFor(
        'eng-01',
        candidateProject.id,
      );
      expect(after, before);
    });
  });

  group('PublicDemoWorkflowState offerCandidates legacy migration', () {
    test('an engineer already at clientInterviewPassed with a matching '
        'proposal on record synthesizes exactly one candidate on load of a '
        'save written before offerCandidates existed', () {
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
          );
      expect(
        aggregate.workflow.engineers
            .firstWhere((e) => e.id == 'eng-01')
            .hasGenuineInterviewRecord,
        isTrue,
      );

      final legacyJson = aggregate.toJson();
      (legacyJson['workflow'] as Map<String, dynamic>).remove(
        'offerCandidates',
      );

      final restored = PublicDemoAggregate.fromJson(legacyJson);
      final synthesized = restored.workflow.offerCandidateFor(
        'eng-01',
        candidateProject.id,
      );
      expect(synthesized, isNotNull);
      expect(
        synthesized!.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
      expect(synthesized.hasGenuineInterviewRecord, isTrue);
      expect(
        restored.workflow.offerCandidatesForEngineer('eng-01'),
        hasLength(1),
      );
    });

    test('an ordered engineer with a matching proposal synthesizes an '
        '`ordered` candidate for the proposal\'s project', () {
      var aggregate = PublicDemoAggregate.initial();
      final candidateProject = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidateProject.id,
      );
      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');

      final legacyJson = aggregate.toJson();
      (legacyJson['workflow'] as Map<String, dynamic>).remove(
        'offerCandidates',
      );
      final restored = PublicDemoAggregate.fromJson(legacyJson);

      final synthesized = restored.workflow.offerCandidateFor(
        'eng-01',
        candidateProject.id,
      );
      expect(synthesized, isNotNull);
      expect(synthesized!.stage, PublicDemoOfferCandidateStage.ordered);
      expect(synthesized.hasGenuineInterviewRecord, isTrue);
    });

    test('an engineer at partnerInterviewPassed (not yet client-passed) '
        'synthesizes a candidate with no interview record — a partner pass '
        'alone is never genuine-record proof, mirroring '
        'PublicDemoEngineerSales itself', () {
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
          );

      final legacyJson = aggregate.toJson();
      (legacyJson['workflow'] as Map<String, dynamic>).remove(
        'offerCandidates',
      );
      final restored = PublicDemoAggregate.fromJson(legacyJson);

      final synthesized = restored.workflow.offerCandidateFor(
        'eng-01',
        candidateProject.id,
      );
      expect(synthesized, isNotNull);
      expect(
        synthesized!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewPassed,
      );
      expect(synthesized.hasGenuineInterviewRecord, isFalse);
    });

    test('an engineer at clientInterviewPassed with NO matching proposal '
        'and no ordered assignment synthesizes no candidate at all — there '
        'is no fabricatable project identity to attach one to (a documented '
        'Phase 1a limitation, not a crash)', () {
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
      expect(aggregate.matchingProposalFor('eng-01'), isNull); // sanity check

      final legacyJson = aggregate.toJson();
      (legacyJson['workflow'] as Map<String, dynamic>).remove(
        'offerCandidates',
      );
      final restored = PublicDemoAggregate.fromJson(legacyJson);
      expect(restored.workflow.offerCandidatesForEngineer('eng-01'), isEmpty);
    });

    test('an engineer still merely `selling`/`waiting` never synthesizes a '
        'candidate, matching proposal or not', () {
      var aggregate = PublicDemoAggregate.initial();
      final candidateProject = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidateProject.id,
      );
      final legacyJson = aggregate.toJson();
      (legacyJson['workflow'] as Map<String, dynamic>).remove(
        'offerCandidates',
      );
      final restored = PublicDemoAggregate.fromJson(legacyJson);
      expect(restored.workflow.offerCandidates, isEmpty);
    });

    test('two engineers ordered for two different proposals both '
        'synthesize, with no duplicate/cross-contaminated identity', () {
      // Built directly at the PublicDemoWorkflowState level (rather than
      // through PublicDemoAggregate's runtime-derived actualCapability) so
      // both founding engineers deterministically pass regardless of their
      // real interviewProfile/runtime stats — eng-02's founding stats
      // legitimately fail the real evaluator's threshold, which is correct
      // production behavior and orthogonal to what this migration test
      // needs to prove.
      var workflow = PublicDemoWorkflowState.initial();
      workflow = workflow
          .withMatchingProposal(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            month: 4,
          )
          .withMatchingProposal(
            engineerId: 'eng-02',
            projectId: 'project-4-2',
            month: 4,
          );
      for (final engineerId in ['eng-01', 'eng-02']) {
        workflow = workflow
            .startSkillSheetReview(engineerId)
            .beginSelling(engineerId)
            .introduceProject(engineerId)
            .recordEngineerInterviewResult(
              engineerId: engineerId,
              type: PublicDemoInterviewType.partner,
              actualCapability: 100,
            )
            .recordEngineerInterviewResult(
              engineerId: engineerId,
              type: PublicDemoInterviewType.client,
              actualCapability: 100,
            )
            .recordOrder(engineerId);
      }

      final legacyJson = workflow.toJson()..remove('offerCandidates');
      final restored = PublicDemoWorkflowState.fromJson(legacyJson);

      expect(restored.offerCandidates, hasLength(2));
      expect(
        restored.offerCandidateFor('eng-01', 'project-4-1')!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
      expect(
        restored.offerCandidateFor('eng-02', 'project-4-2')!.stage,
        PublicDemoOfferCandidateStage.ordered,
      );
    });
  });

  group('PublicDemoAggregate offer candidate plumbing', () {
    test('proposeOfferCandidate succeeds for a project genuinely in the '
        'current month\'s displayed pool', () {
      final aggregate = PublicDemoAggregate.initial();
      for (final candidate in aggregate.projectCandidatesForMonth(4)) {
        final next = aggregate.proposeOfferCandidate(
          engineerId: 'eng-01',
          projectId: candidate.id,
        );
        expect(next.offerCandidateFor('eng-01', candidate.id), isNotNull);
      }
    });

    test('proposeOfferCandidate is a no-op for a fabricated project id '
        '(unknown projectId)', () {
      final aggregate = PublicDemoAggregate.initial();
      final next = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'not-a-real-project-id',
      );
      expect(next.offerCandidates, isEmpty);
    });

    test('proposeOfferCandidate is a no-op for a syntactically valid id '
        'from a different month\'s pool (unknown projectId, Codex P2-style '
        'guard reused from proposeMatch)', () {
      final aggregate = PublicDemoAggregate.initial(); // state.month == 4
      final next = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: 'project-999-1',
      );
      expect(next.offerCandidates, isEmpty);
    });

    test('proposeOfferCandidate is a no-op for an unknown engineer id', () {
      final aggregate = PublicDemoAggregate.initial();
      final candidate = aggregate.projectCandidatesForMonth(4).first;
      final next = aggregate.proposeOfferCandidate(
        engineerId: 'not-a-real-engineer',
        projectId: candidate.id,
      );
      expect(next.offerCandidates, isEmpty);
    });

    test('unlike proposeMatch, proposeOfferCandidate does not require the '
        'engineer to be currently unassigned — several candidates may '
        'coexist for one engineer', () {
      final aggregate = PublicDemoAggregate.initial();
      final candidates = aggregate.projectCandidatesForMonth(4, count: 2);
      final next = aggregate
          .proposeOfferCandidate(
            engineerId: 'eng-01',
            projectId: candidates[0].id,
          )
          .proposeOfferCandidate(
            engineerId: 'eng-01',
            projectId: candidates[1].id,
          );
      expect(next.offerCandidates, hasLength(2));
    });
  });

  group('PublicDemoAggregate candidate interview safe entry points (Codex '
      'review fix, PR #254 P1)', () {
    test('evaluatePartnerInterviewForCandidate derives profile/capability '
        'from the engineer\'s own authoritative state (never a caller-'
        'supplied value — the method takes no such parameter at all) and '
        'consumes one real sales slot per attempt', () {
      var aggregate = PublicDemoAggregate.initial();
      final candidateProject = aggregate.projectCandidatesForMonth(4).first;
      aggregate = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: candidateProject.id,
      );
      final before = aggregate.state.salesRemaining;

      aggregate = aggregate.evaluatePartnerInterviewForCandidate(
        engineerId: 'eng-01',
        projectId: candidateProject.id,
      );

      expect(aggregate.state.salesRemaining, before - 1);
      final candidate = aggregate.offerCandidateFor(
        'eng-01',
        candidateProject.id,
      )!;
      expect(
        candidate.stage,
        PublicDemoOfferCandidateStage.partnerInterviewPassed,
      );
      expect(candidate.partnerScore, isNotNull);
    });

    test('evaluatePartnerInterviewForCandidate is a no-op — consuming no '
        'slot — when no candidate exists for the pair', () {
      final aggregate = PublicDemoAggregate.initial();
      final before = aggregate.state.salesRemaining;
      final next = aggregate.evaluatePartnerInterviewForCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      expect(next.offerCandidates, isEmpty);
      expect(next.state.salesRemaining, before);
    });

    test('evaluatePartnerInterviewForCandidate is a no-op once no sales '
        'slots remain — checked before consumption, so a rejected attempt '
        'never partially consumes the budget', () {
      var aggregate = PublicDemoAggregate.initial();
      final candidates = aggregate.projectCandidatesForMonth(4, count: 5);
      for (final candidate in candidates.take(4)) {
        aggregate = aggregate
            .proposeOfferCandidate(
              engineerId: 'eng-01',
              projectId: candidate.id,
            )
            .evaluatePartnerInterviewForCandidate(
              engineerId: 'eng-01',
              projectId: candidate.id,
            );
      }
      expect(aggregate.state.salesRemaining, 0);

      final fifth = candidates[4];
      aggregate = aggregate.proposeOfferCandidate(
        engineerId: 'eng-01',
        projectId: fifth.id,
      );
      final beforeAttempt = aggregate.offerCandidateFor('eng-01', fifth.id);
      aggregate = aggregate.evaluatePartnerInterviewForCandidate(
        engineerId: 'eng-01',
        projectId: fifth.id,
      );
      expect(aggregate.offerCandidateFor('eng-01', fifth.id), beforeAttempt);
      expect(aggregate.state.salesRemaining, 0);
    });

    test('evaluateClientInterviewForCandidate derives profile/capability '
        'from authoritative state and consumes no sales slot (the existing '
        '0-slot client-interview stage this phase reuses as-is)', () {
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
          );
      expect(
        aggregate.offerCandidateFor('eng-01', candidateProject.id)!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewPassed,
      );
      final before = aggregate.state.salesRemaining;

      aggregate = aggregate.evaluateClientInterviewForCandidate(
        engineerId: 'eng-01',
        projectId: candidateProject.id,
      );

      expect(aggregate.state.salesRemaining, before);
      final candidate = aggregate.offerCandidateFor(
        'eng-01',
        candidateProject.id,
      )!;
      expect(
        candidate.stage,
        PublicDemoOfferCandidateStage.clientInterviewPassed,
      );
      expect(candidate.hasGenuineInterviewRecord, isTrue);
    });

    test('evaluateClientInterviewForCandidate is a no-op when no candidate '
        'exists for the pair', () {
      final aggregate = PublicDemoAggregate.initial();
      final next = aggregate.evaluateClientInterviewForCandidate(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
      );
      expect(next.offerCandidates, isEmpty);
    });
  });
}
