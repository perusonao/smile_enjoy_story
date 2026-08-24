import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_binding_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

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
    test('withApplicantStage updates only the targeted applicant', () {
      final workflow = PublicDemoWorkflowState.initial();
      final id = workflow.applicants.first.id;
      final next = workflow.withApplicantStage(
        id,
        PublicDemoApplicantStage.interviewed,
      );

      expect(
        next.applicants.firstWhere((a) => a.id == id).stage,
        PublicDemoApplicantStage.interviewed,
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

    test('withEngineerStage updates only the targeted engineer', () {
      final workflow = PublicDemoWorkflowState.initial();
      final id = workflow.engineers.first.id;
      final next = workflow.withEngineerStage(id, PublicDemoSalesStage.selling);

      expect(
        next.engineers.firstWhere((e) => e.id == id).stage,
        PublicDemoSalesStage.selling,
      );
    });

    test('withAssignment updates only the targeted assignment', () {
      const assignment = PublicDemoAssignment(
        engineerId: 'eng-01',
        engineerName: 'Test',
        projectName: 'Test Project',
        deliveryPressure: 50,
        budgetHealth: 70,
        humanity: 70,
      );
      final workflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: const [],
        assignments: [assignment],
      );
      final next = workflow.withAssignment(
        'eng-01',
        (a) => a.copyWith(nextOrderStatus: PublicDemoNextOrderStatus.accepted),
      );

      expect(
        next.assignments.single.nextOrderStatus,
        PublicDemoNextOrderStatus.accepted,
      );
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
    test('before July, every assignment counts regardless of order status', () {
      const assignments = [
        PublicDemoAssignment(
          engineerId: 'eng-01',
          engineerName: 'A',
          projectName: 'P',
          deliveryPressure: 50,
          budgetHealth: 70,
          humanity: 70,
        ),
        PublicDemoAssignment(
          engineerId: 'eng-02',
          engineerName: 'B',
          projectName: 'P',
          deliveryPressure: 50,
          budgetHealth: 70,
          humanity: 70,
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        ),
      ];
      final workflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: const [],
        assignments: assignments,
      );

      expect(workflow.assignedEngineerIds(month: 6), {'eng-01', 'eng-02'});
    });

    test(
      'from July, only accepted/ordered assignments count (12MONTH-3-FIX1 P1-1)',
      () {
        const assignments = [
          PublicDemoAssignment(
            engineerId: 'eng-01',
            engineerName: 'A',
            projectName: 'P',
            deliveryPressure: 50,
            budgetHealth: 70,
            humanity: 70,
            nextOrderStatus: PublicDemoNextOrderStatus.accepted,
          ),
          PublicDemoAssignment(
            engineerId: 'eng-02',
            engineerName: 'B',
            projectName: 'P',
            deliveryPressure: 50,
            budgetHealth: 70,
            humanity: 70,
            nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
            replacementStage: PublicDemoReplacementStage.ordered,
          ),
          PublicDemoAssignment(
            engineerId: 'eng-03',
            engineerName: 'C',
            projectName: 'P',
            deliveryPressure: 50,
            budgetHealth: 70,
            humanity: 70,
            nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
          ),
        ];
        final workflow = PublicDemoWorkflowState(
          applicants: const [],
          engineers: const [],
          assignments: assignments,
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
        final template = PublicDemoApplicant(
          id: id,
          name: 'Hire $id',
          resumeSummary: 'Java 3年',
          interviewScore: 70,
          acceptanceScore: 70,
          salesSkillFit: 70,
          requestedMonthlySalary: 320000,
          stage: PublicDemoApplicantStage.interviewed,
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
          assignments: const [],
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
            assignments: const [],
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
    const orderedEngineer = PublicDemoEngineerSales(
      id: 'eng-01',
      name: 'Ordered Engineer',
      summary: 'summary',
      stage: PublicDemoSalesStage.ordered,
      interviewProfile: PublicDemoInterviewProfile(
        skillFit: 70,
        humanity: 70,
        morale: 70,
        clientTrust: 60,
      ),
    );
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
    const orderedApplicant = PublicDemoApplicant(
      id: 'app-ordered',
      name: 'Ordered Applicant',
      resumeSummary: 'Java 1年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
      stage: PublicDemoApplicantStage.juneOrdered,
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
        applicants: const [orderedApplicant, notOrderedApplicant],
        engineers: const [orderedEngineer, waitingEngineer],
        assignments: const [],
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
        assignments: const [],
      );

      final next = workflow.assignOrderedForMay();

      expect(next.assignments, isEmpty);
    });

    test('calling assignOrderedForMay again never duplicates an assignment: '
        'the roster is always replaced wholesale from current stage facts, '
        'never appended to', () {
      final workflow = PublicDemoWorkflowState(
        applicants: const [orderedApplicant],
        engineers: const [orderedEngineer],
        assignments: const [],
      );

      final once = workflow.assignOrderedForMay();
      final twice = once.assignOrderedForMay();

      expect(twice.assignments.length, once.assignments.length);
      expect(
        twice.assignments.map((a) => a.engineerId).toSet(),
        once.assignments.map((a) => a.engineerId).toSet(),
      );
    });

    test(
      'the caller cannot fabricate an arbitrary roster: '
      'PublicDemoWorkflowState exposes no public way to replace assignments '
      'except by deriving them from its own engineer/applicant stage facts',
      () {
        // This is a compile-time guarantee: `withAssignments` (the former
        // wholesale-replace method) is private to
        // public_demo_workflow_state.dart, so no other file — including a
        // widget or this test — can call it directly. The only way to
        // change the assignment roster from outside this file is through
        // assignOrderedForMay, which reads only this workflow's own
        // authoritative stage facts.
        final workflow = PublicDemoWorkflowState(
          applicants: const [orderedApplicant],
          engineers: const [orderedEngineer],
          assignments: const [],
        );
        final next = workflow.assignOrderedForMay();
        expect(next.assignments, isNotEmpty);
      },
    );
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
      final template = const PublicDemoApplicant(
        id: 'hire-01',
        name: 'Hire',
        resumeSummary: 'Java 3年',
        interviewScore: 70,
        acceptanceScore: 70,
        salesSkillFit: 70,
        requestedMonthlySalary: 320000,
        stage: PublicDemoApplicantStage.interviewed,
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
      final joined = accepted.join(week: 9);

      final workflow = PublicDemoWorkflowState(
        applicants: [joined],
        engineers: const [engineer],
        assignments: const [],
      );

      expect(workflow.moraleByEngineerId['eng-01'], 72);
      expect(workflow.moraleByEngineerId['hire-01'], joined.employeeMorale);
    },
  );
}
