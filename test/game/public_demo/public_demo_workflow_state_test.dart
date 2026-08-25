import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_binding_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_offer_test_helpers.dart';
import 'test_support/public_demo_sales_test_helpers.dart';

/// WORKFLOW-STATE-1 §35: proves the domain (PublicDemoWorkflowState) is now
/// authoritative for applicants/engineers/assignments — directly, without
/// going through the widget — and that its mutation methods reproduce the
/// exact pre-cutover widget behavior they replaced.
void main() {
  group('initial state matches the pre-cutover widget defaults', () {
    test(
      'applicants/engineers/assignments start from the established pools',
      () {
        final workflow = PublicDemoWorkflowState.initial();
        expect(workflow.applicants, publicDemoMayApplicants);
        expect(workflow.engineers, publicDemoInitialEngineers);
        expect(workflow.assignments, isEmpty);
      },
    );
  });

  group('applicant/engineer/assignment authority', () {
    test('reviewResume updates only the targeted applicant', () {
      final workflow = PublicDemoWorkflowState.initial();
      final id = workflow.applicants.first.id;
      final next = workflow.reviewResume(id);

      expect(
        next.applicants.firstWhere((a) => a.id == id).stage,
        PublicDemoApplicantStage.resumeReviewed,
      );
      expect(
        next.applicants.where((a) => a.id != id),
        everyElement(
          predicate<PublicDemoApplicant>(
            (a) => a.stage == PublicDemoApplicantStage.applied,
          ),
        ),
      );
    });

    // WORKFLOW-STATE-1AB FIX5 P1: reviewResume (like every other named
    // pre-entry transition) requires the applicant's CURRENT stage to
    // match its own precondition — `applied` here — so calling it on an
    // applicant not at that stage is a no-op, not a way to jump straight
    // to `resumeReviewed` (or, chained, any later stage) regardless of
    // where the applicant actually is. `interviewed` itself is reachable
    // only via PublicDemoAggregate.completeInterview (workflow-significant,
    // requires a genuine sales-slot proof this workflow-only class cannot
    // supply on its own) — see public_demo_binding_offer_test.dart's
    // adversarial group and public_demo_aggregate_test.dart.
    test(
      'reviewResume is a no-op on an applicant not currently at applied',
      () {
        final workflow = PublicDemoWorkflowState.initial();
        final id = workflow.applicants.first.id;
        final reviewed = workflow.reviewResume(id);

        // Calling it again — the applicant is now `resumeReviewed`, not
        // `applied` — must not advance it any further.
        final again = reviewed.reviewResume(id);

        expect(
          again.applicants.firstWhere((a) => a.id == id).stage,
          PublicDemoApplicantStage.resumeReviewed,
        );
      },
    );

    test('beginSelling updates only the targeted engineer', () {
      final workflow = PublicDemoWorkflowState.initial();
      final id = workflow.engineers.first.id;
      final next = workflow.startSkillSheetReview(id).beginSelling(id);

      expect(
        next.engineers.firstWhere((e) => e.id == id).stage,
        PublicDemoSalesStage.selling,
      );
    });

    // WORKFLOW-STATE-1AB FIX5 P1: the sole production API for the engineer
    // sales pipeline is this chain of precondition-gated named
    // transitions — there is no method anywhere that accepts a caller-
    // chosen target PublicDemoSalesStage directly. Calling a later-stage
    // transition out of order (skipping intermediate real events) must be
    // a no-op, not a shortcut to `ordered`.
    test('the engineer sales pipeline cannot be skipped: recordOrder is a '
        'no-op unless the engineer already genuinely reached '
        'clientInterviewPassed', () {
      final workflow = PublicDemoWorkflowState.initial();
      final id = workflow.engineers.first.id;

      final skippedAhead = workflow.recordOrder(id);
      expect(
        skippedAhead.engineers.firstWhere((e) => e.id == id).stage,
        PublicDemoSalesStage.waiting,
      );

      final partiallyAdvanced = workflow
          .startSkillSheetReview(id)
          .beginSelling(id)
          .introduceProject(id)
          .recordOrder(id);
      expect(
        partiallyAdvanced.engineers.firstWhere((e) => e.id == id).stage,
        PublicDemoSalesStage.introduced,
        reason:
            'recordOrder requires clientInterviewPassed — introduced is '
            'not enough, however far the caller got',
      );
    });

    // WORKFLOW-STATE-1AB FIX4 P1-2: PublicDemoWorkflowState.restore is
    // gone — build a genuine assignment through the real
    // assignOrderedForMay authoritative transition (an ordered engineer)
    // instead of fabricating a PublicDemoAssignment and injecting it
    // directly. FIX5/FIX6 P1: assignOrderedForMay also requires a genuine
    // PublicDemoEngineerInterviewRecord (set only by
    // PublicDemoEngineerSales.evaluateInterview — FIX7 P2 — see
    // recordTestClientInterviewPass — when it actually records a passed
    // client interview) — minted here via that real entry point since this
    // group tests assignOrderedForMay's own eligibility logic in isolation,
    // not the full aggregate-level authority chain (already covered in
    // public_demo_aggregate_test.dart).
    PublicDemoWorkflowState workflowWithGenuineAssignment(String engineerId) =>
        PublicDemoWorkflowState(
          applicants: const [],
          engineers: [
            recordTestClientInterviewPass(
              PublicDemoEngineerSales(
                id: engineerId,
                name: 'Test',
                summary: 'summary',
                stage: PublicDemoSalesStage.clientInterviewPassed,
                interviewProfile: const PublicDemoInterviewProfile(
                  skillFit: 70,
                  humanity: 70,
                  morale: 70,
                  clientTrust: 60,
                ),
              ),
            ).copyWith(stage: PublicDemoSalesStage.ordered),
          ],
        ).assignOrderedForMay();

    test('withAssignmentUpdate updates only the targeted assignment', () {
      final workflow = workflowWithGenuineAssignment('eng-01');
      final next = workflow.withAssignmentUpdate(
        'eng-01',
        nextOrderStatus: PublicDemoNextOrderStatus.accepted,
      );

      expect(
        next.assignments.single.nextOrderStatus,
        PublicDemoNextOrderStatus.accepted,
      );
    });

    // WORKFLOW-STATE-1AB FIX3 P1-3: FIX2's `withAssignment` took an update
    // *function*, so a caller-supplied function could ignore the real
    // assignment it was given and return a wholly fabricated
    // `PublicDemoAssignment(...)` instead — substituting fake economic
    // fields (deliveryPressure/budgetHealth/humanity/projectName/
    // engineerName) for a real assignment already on the authoritative
    // roster. `withAssignmentUpdate` takes named parameters instead: there
    // is no argument through which a whole fabricated assignment could
    // pass, so this is a structural (compile-time), not merely behavioral,
    // guarantee.
    test('fake assignment cannot be injected via withAssignmentUpdate: only '
        'nextOrderStatus/replacementStage/fieldEvaluation can ever change', () {
      final workflow = workflowWithGenuineAssignment('eng-01');
      final original = workflow.assignments.single;

      final next = workflow.withAssignmentUpdate(
        'eng-01',
        nextOrderStatus: PublicDemoNextOrderStatus.accepted,
        replacementStage: PublicDemoReplacementStage.ordered,
        fieldEvaluation: 99,
      );
      final updated = next.assignments.single;

      expect(updated.engineerId, original.engineerId);
      expect(updated.engineerName, original.engineerName);
      expect(updated.projectName, original.projectName);
      expect(updated.deliveryPressure, original.deliveryPressure);
      expect(updated.budgetHealth, original.budgetHealth);
      expect(updated.humanity, original.humanity);
      expect(updated.nextOrderStatus, PublicDemoNextOrderStatus.accepted);
      expect(updated.replacementStage, PublicDemoReplacementStage.ordered);
      expect(updated.fieldEvaluation, 99);
    });

    test('withAssignmentUpdate for an unknown engineerId is a no-op: it cannot '
        'be used to append a new (fabricated) assignment to the roster', () {
      final workflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: const [],
      );

      final next = workflow.withAssignmentUpdate(
        'intruder',
        nextOrderStatus: PublicDemoNextOrderStatus.accepted,
      );

      expect(next.assignments, isEmpty);
    });

    test(
      'withGeneratedApplicants appends without duplicating existing ids',
      () {
        final workflow = PublicDemoWorkflowState.initial();
        final existingId = workflow.applicants.first.id;
        const newApplicant = PublicDemoApplicant(
          id: 'new-applicant',
          name: 'New',
          resumeSummary: 'Java 1年',
          interviewScore: 60,
          acceptanceScore: 60,
          salesSkillFit: 60,
        );
        final duplicateOfExisting = workflow.applicants.first;

        final next = workflow.withGeneratedApplicants([
          newApplicant,
          duplicateOfExisting,
        ]);

        expect(next.applicants.length, workflow.applicants.length + 1);
        expect(next.applicants.where((a) => a.id == existingId), hasLength(1));
        expect(next.applicants.any((a) => a.id == 'new-applicant'), isTrue);
      },
    );
  });

  group('assignedEngineerIds matches pre-July vs. post-July semantics', () {
    // WORKFLOW-STATE-1AB FIX4 P1-2: PublicDemoWorkflowState.restore is
    // gone — build genuine assignments for real ordered engineers via
    // assignOrderedForMay, then dial in each one's decision fields through
    // the real withAssignmentUpdate transition.
    PublicDemoWorkflowState orderedEngineersWorkflow(List<String> ids) =>
        PublicDemoWorkflowState(
          applicants: const [],
          engineers: [
            for (final id in ids)
              recordTestClientInterviewPass(
                PublicDemoEngineerSales(
                  id: id,
                  name: id,
                  summary: 'summary',
                  interviewProfile: const PublicDemoInterviewProfile(
                    skillFit: 70,
                    humanity: 70,
                    morale: 70,
                    clientTrust: 60,
                  ),
                ),
              ).copyWith(stage: PublicDemoSalesStage.ordered),
          ],
        ).assignOrderedForMay();

    test('before July, every assignment counts regardless of order status', () {
      final workflow = orderedEngineersWorkflow(['eng-01', 'eng-02'])
          .withAssignmentUpdate(
            'eng-02',
            nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
          );

      expect(workflow.assignedEngineerIds(month: 6), {'eng-01', 'eng-02'});
    });

    test(
      'from July, only accepted/ordered assignments count (12MONTH-3-FIX1 P1-1)',
      () {
        final workflow =
            orderedEngineersWorkflow(['eng-01', 'eng-02', 'eng-03'])
                .withAssignmentUpdate(
                  'eng-01',
                  nextOrderStatus: PublicDemoNextOrderStatus.accepted,
                )
                .withAssignmentUpdate(
                  'eng-02',
                  nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
                  replacementStage: PublicDemoReplacementStage.ordered,
                )
                .withAssignmentUpdate(
                  'eng-03',
                  nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
                );

        expect(workflow.assignedEngineerIds(month: 7), {'eng-01', 'eng-02'});
        expect(workflow.assignedEngineerIds(month: 15), {'eng-01', 'eng-02'});
      },
    );
  });

  group(
    'joinAndKeepOnly reproduces the pre-cutover May join+roster-replace behavior',
    () {
      PublicDemoApplicant accepted(String id, int salary) {
        final template = completeTestInterview(
          PublicDemoApplicant(
            id: id,
            name: 'Hire $id',
            resumeSummary: 'Java 3年',
            interviewScore: 70,
            acceptanceScore: 70,
            salesSkillFit: 70,
            requestedMonthlySalary: 320000,
          ),
        );
        final offer = PublicDemoSalaryOffer(
          requestedMonthlySalary: template.requestedMonthlySalary,
          offeredMonthlySalary: salary,
          acceptanceScore: 100,
          motivationDelta: 0,
          trustDelta: 0,
        );
        return PublicDemoOfferAcceptance.accept(
          applicant: template,
          offer: offer,
          fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
        ).applicant;
      }

      test('joins every listed id and drops everyone else from the roster', () {
        final rejected = const PublicDemoApplicant(
          id: 'rejected',
          name: 'Rejected',
          resumeSummary: 'Java 1年',
          interviewScore: 40,
          acceptanceScore: 40,
          salesSkillFit: 40,
        );
        final workflow = PublicDemoWorkflowState(
          applicants: [accepted('joins', 320000), rejected],
          engineers: const [],
        );

        final next = workflow.joinAndKeepOnly(
          applicantIds: const ['joins'],
          week: 9,
          currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
        );

        expect(next.applicants, hasLength(1));
        expect(next.applicants.single.id, 'joins');
        expect(next.applicants.single.hasJoined, isTrue);
      });

      test(
        'withJoinedEngineers adds newly joined applicants as engineers once',
        () {
          final workflow = PublicDemoWorkflowState(
            applicants: [accepted('joins', 320000)],
            engineers: const [],
          );
          final joined = workflow
              .joinAndKeepOnly(
                applicantIds: const ['joins'],
                week: 9,
                currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
              )
              .applicants;

          final next = workflow.withJoinedEngineers(joined);
          expect(next.engineers, hasLength(1));
          expect(next.engineers.single.id, 'joins');

          // Calling it again with the same already-present applicant must not
          // add a duplicate engineer entry.
          final again = next.withJoinedEngineers(joined);
          expect(again.engineers, hasLength(1));
        },
      );
    },
  );

  group('assignOrderedForMay is the sole assignment authority (P1-3)', () {
    // WORKFLOW-STATE-1AB FIX6 P1: `lastInterviewScore` alone is no longer
    // sufficient (that field is publicly settable via `copyWith` and
    // proves nothing by itself) — a genuine
    // `PublicDemoEngineerInterviewRecord`, minted only by
    // `PublicDemoEngineerSales.evaluateInterview` (FIX7 P2), is required
    // instead. Not `const` any more since minting one is a real method
    // call, not a compile-time literal.
    final orderedEngineer = recordTestClientInterviewPass(
      const PublicDemoEngineerSales(
        id: 'eng-01',
        name: 'Ordered Engineer',
        summary: 'summary',
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 70,
          humanity: 70,
          morale: 70,
          clientTrust: 60,
        ),
      ),
    ).copyWith(stage: PublicDemoSalesStage.ordered);
    const waitingEngineer = PublicDemoEngineerSales(
      id: 'eng-02',
      name: 'Waiting Engineer',
      summary: 'summary',
      interviewProfile: PublicDemoInterviewProfile(
        skillFit: 70,
        humanity: 70,
        morale: 70,
        clientTrust: 60,
      ),
    );

    // WORKFLOW-STATE-1AB FIX5 P1: assignOrderedForMay no longer trusts
    // `stage == juneOrdered` alone — it also requires `hasJoined`, which
    // only a genuine PublicDemoJoinTransaction.join can set
    // (PublicDemoJoinRecord's constructor is private to
    // public_demo_recruitment.dart, so no test/caller outside that file can
    // fabricate one via a raw literal). This builds a genuinely-joined
    // applicant through the real interview/offer/join chain, then sets the
    // final `juneOrdered` stage directly — legitimate here because this
    // group tests assignOrderedForMay's own eligibility logic in isolation
    // (the full aggregate-level chain that also validates every
    // intermediate stage is covered in public_demo_aggregate_test.dart).
    PublicDemoApplicant joinedApplicantAt(
      String id,
      PublicDemoApplicantStage stage,
    ) {
      final interviewed = completeTestInterview(
        PublicDemoApplicant(
          id: id,
          name: 'Applicant $id',
          resumeSummary: 'Java 3年',
          interviewScore: 70,
          acceptanceScore: 70,
          salesSkillFit: 70,
          requestedMonthlySalary: 320000,
        ),
      );
      final offer = PublicDemoSalaryOffer(
        requestedMonthlySalary: interviewed.requestedMonthlySalary,
        offeredMonthlySalary: 320000,
        acceptanceScore: 100,
        motivationDelta: 0,
        trustDelta: 0,
      );
      final accepted = PublicDemoOfferAcceptance.accept(
        applicant: interviewed,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
      ).applicant;
      final joined = accepted.join(
        week: 9,
        currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
      );
      return joined.copyWith(stage: stage);
    }

    final orderedApplicant = joinedApplicantAt(
      'app-ordered',
      PublicDemoApplicantStage.juneOrdered,
    );
    const notOrderedApplicant = PublicDemoApplicant(
      id: 'app-not-ordered',
      name: 'Not Ordered Applicant',
      resumeSummary: 'Java 1年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
      stage: PublicDemoApplicantStage.preEntryClientPassed,
    );

    test('valid assignment path: only ordered engineers/applicants become '
        'an assignment', () {
      final workflow = PublicDemoWorkflowState(
        applicants: [orderedApplicant, notOrderedApplicant],
        engineers: [orderedEngineer, waitingEngineer],
      );

      final next = workflow.assignOrderedForMay();

      expect(
        next.assignments.map((a) => a.engineerId),
        unorderedEquals(['eng-01', 'app-ordered']),
      );
    });

    test('an engineer that never reached the ordered stage is rejected: it '
        'never gets an assignment, however the roster is computed', () {
      final workflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: const [waitingEngineer],
      );

      final next = workflow.assignOrderedForMay();

      expect(next.assignments, isEmpty);
    });

    // WORKFLOW-STATE-1AB FIX5/FIX6 P1 (defense in depth, section 5):
    // `stage` alone is never trusted. An engineer whose stage AND
    // lastInterviewScore were both directly set (via the public
    // constructor/copyWith — the exact shape of FIX5 review's confirmed
    // Attack A: `stage: ordered, lastInterviewScore: 80`) but with no
    // genuine PublicDemoEngineerInterviewRecord, and an applicant at
    // `juneOrdered` who never actually joined, must both be rejected —
    // exactly the shape of FIX4's Attack A / Attack B, now checked here
    // too, not just by removing the generic stage setters/mutators that
    // used to enable them.
    test('stage (and, for engineers, a fabricated lastInterviewScore) alone '
        'is not proof: an ordered engineer with no genuine interview '
        'record, and a juneOrdered applicant who never joined, are both '
        'rejected', () {
      const unprovenEngineer = PublicDemoEngineerSales(
        id: 'eng-unproven',
        name: 'Unproven Engineer',
        summary: 'summary',
        stage: PublicDemoSalesStage.ordered,
        lastInterviewScore: 80,
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 70,
          humanity: 70,
          morale: 70,
          clientTrust: 60,
        ),
      );
      const unjoinedApplicant = PublicDemoApplicant(
        id: 'app-unjoined',
        name: 'Unjoined Applicant',
        resumeSummary: 'Java 1年',
        interviewScore: 70,
        acceptanceScore: 70,
        salesSkillFit: 70,
        stage: PublicDemoApplicantStage.juneOrdered,
      );
      final workflow = PublicDemoWorkflowState(
        applicants: const [unjoinedApplicant],
        engineers: const [unprovenEngineer],
      );

      final next = workflow.assignOrderedForMay();

      expect(next.assignments, isEmpty);
    });

    test('calling assignOrderedForMay again never duplicates an assignment: '
        'the roster is always replaced wholesale from current stage facts, '
        'never appended to', () {
      final workflow = PublicDemoWorkflowState(
        applicants: [orderedApplicant],
        engineers: [orderedEngineer],
      );

      final once = workflow.assignOrderedForMay();
      final twice = once.assignOrderedForMay();

      expect(twice.assignments.length, once.assignments.length);
      expect(
        twice.assignments.map((a) => a.engineerId).toSet(),
        once.assignments.map((a) => a.engineerId).toSet(),
      );
    });

    test('the caller cannot fabricate an arbitrary roster: '
        'PublicDemoWorkflowState exposes no production way to replace '
        'assignments except by deriving them from its own engineer/applicant '
        'stage facts', () {
      // This is a compile-time guarantee, in three layers (WORKFLOW-STATE-
      // 1AB FIX1 P1-3, FIX2 P1-3, FIX3 P1-3), hardened further by FIX4:
      // 1. `_withAssignments` (the former wholesale-replace method) is
      //    private to public_demo_workflow_state.dart.
      // 2. `_copyWith` (the full-field internal version) is private too —
      //    FIX4 removed the public `copyWith(applicants:, engineers:)`
      //    wrapper entirely, since even without an `assignments` parameter
      //    it still let a caller wholesale-replace the applicant/engineer
      //    lists from outside this file.
      // 3. The general-purpose public factory constructor
      //    (`PublicDemoWorkflowState(applicants:, engineers:)`) never
      //    accepted an `assignments` parameter (FIX3), and FIX4 removed
      //    the `.restore(...)` reconstruction factory that used to accept
      //    one — there is no production-reachable way left to inject an
      //    arbitrary fabricated PublicDemoAssignment into an existing
      //    workflow through any of these.
      //    (PublicDemoAssignment itself remains freely publicly
      //    constructible — WORKFLOW-STATE-1AB §6 design rule — that alone
      //    is harmless since it can never reach an existing workflow's
      //    `assignments` this way.)
      // The only way to change the assignment roster on an existing
      // workflow from outside this file is through assignOrderedForMay,
      // which reads only this workflow's own authoritative stage facts.
      final workflow = PublicDemoWorkflowState(
        applicants: [orderedApplicant],
        engineers: [orderedEngineer],
      );
      final next = workflow.assignOrderedForMay();
      expect(next.assignments, isNotEmpty);

      // A caller CAN construct a PublicDemoAssignment value in isolation —
      // that alone is not the vulnerability (see comment above) — but
      // there is no `workflow.copyWith(assignments: ...)` overload to
      // hand it to; only workflow.assignments (read) and
      // workflow.withAssignmentUpdate(id, {nextOrderStatus,
      // replacementStage, fieldEvaluation}) (update an existing entry's
      // three mutable decision fields, never add a new entry or change
      // its identity/economic fields) are reachable.
      const fabricated = PublicDemoAssignment(
        engineerId: 'intruder',
        engineerName: 'Fabricated',
        projectName: 'Fabricated Project',
        deliveryPressure: 0,
        budgetHealth: 100,
        humanity: 100,
      );
      expect(
        next.assignments.any((a) => a.engineerId == fabricated.engineerId),
        isFalse,
      );
    });
  });

  test(
    'moraleByEngineerId combines engineer motivation and joined-applicant morale',
    () {
      const engineer = PublicDemoEngineerSales(
        id: 'eng-01',
        name: 'Engineer',
        summary: 'summary',
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 70,
          humanity: 70,
          morale: 72,
          clientTrust: 60,
        ),
      );
      final template = completeTestInterview(
        const PublicDemoApplicant(
          id: 'hire-01',
          name: 'Hire',
          resumeSummary: 'Java 3年',
          interviewScore: 70,
          acceptanceScore: 70,
          salesSkillFit: 70,
          requestedMonthlySalary: 320000,
        ),
      );
      final offer = PublicDemoSalaryOffer(
        requestedMonthlySalary: template.requestedMonthlySalary,
        offeredMonthlySalary: 320000,
        acceptanceScore: 100,
        motivationDelta: 0,
        trustDelta: 0,
      );
      final accepted = PublicDemoOfferAcceptance.accept(
        applicant: template,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
      ).applicant;
      final joined = accepted.join(
        week: 9,
        currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
      );

      final workflow = PublicDemoWorkflowState(
        applicants: [joined],
        engineers: const [engineer],
      );

      expect(workflow.moraleByEngineerId['eng-01'], 72);
      expect(workflow.moraleByEngineerId['hire-01'], joined.employeeMorale);
    },
  );
}
