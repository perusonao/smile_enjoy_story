import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_binding_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_join.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_snapshot.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// WORKFLOW-STATE-1 §21/§32: the snapshot must be genuinely immutable —
/// mutating the source workflow (or attempting to mutate an exposed
/// collection) afterward must never change an already-captured snapshot.
void main() {
  PublicDemoApplicant joinedApplicant(String id, int salary) {
    const template = PublicDemoApplicant(
      id: 'template',
      name: 'Snapshot Hire',
      resumeSummary: 'Java 3年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
      requestedMonthlySalary: 320000,
    );
    final offer = PublicDemoSalaryOffer(
      requestedMonthlySalary: template.requestedMonthlySalary,
      offeredMonthlySalary: salary,
      acceptanceScore: 100,
      motivationDelta: 0,
      trustDelta: 0,
    );
    final accepted = PublicDemoOfferAcceptance.accept(
      applicant: PublicDemoApplicant(
        id: id,
        name: template.name,
        resumeSummary: template.resumeSummary,
        interviewScore: template.interviewScore,
        acceptanceScore: template.acceptanceScore,
        salesSkillFit: template.salesSkillFit,
        requestedMonthlySalary: template.requestedMonthlySalary,
      ).markInterviewed(),
      offer: offer,
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    ).applicant;
    return const PublicDemoJoinTransaction()
        .join(
          applicant: accepted,
          week: 9,
          currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
        )
        .applicant;
  }

  PublicDemoWorkflowState workflowWithOneJoinedHire() =>
      PublicDemoWorkflowState(
        applicants: [joinedApplicant('hire-01', 320000)],
        engineers: const [],
        assignments: const [
          PublicDemoAssignment(
            engineerId: 'hire-01',
            engineerName: 'Snapshot Hire',
            projectName: 'Test Project',
            deliveryPressure: 50,
            budgetHealth: 70,
            humanity: 70,
            nextOrderStatus: PublicDemoNextOrderStatus.accepted,
          ),
        ],
      );

  test(
    'captures joined payroll identities, salary, and BindingOffer provenance',
    () {
      final workflow = workflowWithOneJoinedHire();
      final snapshot = PublicDemoWorkflowSnapshot.capture(workflow, month: 7);

      expect(snapshot.joinedPayrollIds, ['hire-01']);
      expect(snapshot.payrollSalaryByEmployeeId['hire-01'], 320000);
      expect(
        snapshot.bindingOfferByApplicantId['hire-01']!.acceptedMonthlySalary,
        320000,
      );
      expect(snapshot.assignedEngineerIds, {'hire-01'});
      expect(
        snapshot.nextOrderStatusByEngineerId['hire-01'],
        PublicDemoNextOrderStatus.accepted,
      );
    },
  );

  test(
    'mutating the source workflow afterward does not change the snapshot',
    () {
      final workflow = workflowWithOneJoinedHire();
      final snapshot = PublicDemoWorkflowSnapshot.capture(workflow, month: 7);

      // Build an entirely different workflow (as production code would via
      // setState) and confirm the already-captured snapshot is unaffected.
      final mutated = PublicDemoWorkflowState(
        applicants: workflow.applicants,
        engineers: workflow.engineers,
        assignments: const [],
      );
      expect(mutated.assignments, isEmpty);
      expect(snapshot.assignedEngineerIds, {'hire-01'});
      expect(snapshot.joinedPayrollIds, ['hire-01']);
    },
  );

  test('exposed collections cannot be mutated', () {
    final snapshot = PublicDemoWorkflowSnapshot.capture(
      workflowWithOneJoinedHire(),
      month: 7,
    );

    expect(
      () => snapshot.joinedPayrollIds.add('intruder'),
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.payrollSalaryByEmployeeId['intruder'] = 1,
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.assignedEngineerIds.add('intruder'),
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.nextOrderStatusByEngineerId['intruder'] =
          PublicDemoNextOrderStatus.accepted,
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.replacementStageByEngineerId['intruder'] =
          PublicDemoReplacementStage.none,
      throwsUnsupportedError,
    );
  });

  test(
    'an applicant with no BindingOffer is simply absent from provenance',
    () {
      final workflow = PublicDemoWorkflowState(
        applicants: const [
          PublicDemoApplicant(
            id: 'no-offer',
            name: 'No Offer',
            resumeSummary: 'Java 1年',
            interviewScore: 60,
            acceptanceScore: 60,
            salesSkillFit: 60,
          ),
        ],
        engineers: const [],
        assignments: const [],
      );
      final snapshot = PublicDemoWorkflowSnapshot.capture(workflow, month: 5);

      expect(
        snapshot.bindingOfferByApplicantId.containsKey('no-offer'),
        isFalse,
      );
      expect(snapshot.joinedPayrollIds, isEmpty);
    },
  );
}
