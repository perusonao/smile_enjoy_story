import 'public_demo_assignment.dart';
import 'public_demo_binding_offer.dart';
import 'public_demo_salary.dart';
import 'public_demo_workflow_state.dart';

/// A read-only, point-in-time capture of the finance-relevant facts
/// [PublicDemoWorkflowState] owns (WORKFLOW-STATE-1 §21).
///
/// This is the immutable boundary future monthly-close/finance work (e.g.
/// FINANCE-FAILURE) can depend on without holding a live, still-mutable
/// [PublicDemoWorkflowState] reference: every collection below is
/// defensively copied and wrapped unmodifiable at capture time, so nothing
/// that happens to the source workflow afterward — or any attempt to
/// mutate a collection exposed here — can change an already-captured
/// snapshot.
class PublicDemoWorkflowSnapshot {
  factory PublicDemoWorkflowSnapshot.capture(
    PublicDemoWorkflowState workflow, {
    required int month,
  }) {
    final joined = workflow.joinedApplicants.toList();
    return PublicDemoWorkflowSnapshot._(
      joinedPayrollIds: [for (final applicant in joined) applicant.id],
      payrollSalaryByEmployeeId: {
        for (final applicant in joined)
          applicant.id:
              PublicDemoSalary.currentMonthlySalaryFor(
                applicant.id,
                applicants: [applicant],
                month: month,
              ) ??
              0,
      },
      bindingOfferByApplicantId: {
        for (final applicant in workflow.applicants)
          if (applicant.bindingOffer case final offer?) applicant.id: offer,
      },
      assignedEngineerIds: workflow.assignedEngineerIds(month: month),
      nextOrderStatusByEngineerId: {
        for (final assignment in workflow.assignments)
          assignment.engineerId: assignment.nextOrderStatus,
      },
      replacementStageByEngineerId: {
        for (final assignment in workflow.assignments)
          assignment.engineerId: assignment.replacementStage,
      },
    );
  }

  PublicDemoWorkflowSnapshot._({
    required List<String> joinedPayrollIds,
    required Map<String, int> payrollSalaryByEmployeeId,
    required Map<String, PublicDemoBindingOffer> bindingOfferByApplicantId,
    required Set<String> assignedEngineerIds,
    required Map<String, PublicDemoNextOrderStatus> nextOrderStatusByEngineerId,
    required Map<String, PublicDemoReplacementStage>
    replacementStageByEngineerId,
  }) : joinedPayrollIds = List.unmodifiable(joinedPayrollIds),
       payrollSalaryByEmployeeId = Map.unmodifiable(payrollSalaryByEmployeeId),
       bindingOfferByApplicantId = Map.unmodifiable(bindingOfferByApplicantId),
       assignedEngineerIds = Set.unmodifiable(assignedEngineerIds),
       nextOrderStatusByEngineerId = Map.unmodifiable(
         nextOrderStatusByEngineerId,
       ),
       replacementStageByEngineerId = Map.unmodifiable(
         replacementStageByEngineerId,
       );

  /// Every applicant/engineer id currently on payroll (joined applicants
  /// only — the founding team is payroll-authoritative via
  /// [PublicDemoSalary]'s own constants, not a workflow fact).
  final List<String> joinedPayrollIds;

  /// Authoritative monthly salary for each id in [joinedPayrollIds], at the
  /// captured month.
  final Map<String, int> payrollSalaryByEmployeeId;

  /// Binding-offer provenance for every applicant that has one, joined or
  /// not.
  final Map<String, PublicDemoBindingOffer> bindingOfferByApplicantId;

  /// The authoritative assigned-engineer identity set for the captured
  /// month — the same set Revenue/Growth/training eligibility must agree
  /// on.
  final Set<String> assignedEngineerIds;

  final Map<String, PublicDemoNextOrderStatus> nextOrderStatusByEngineerId;
  final Map<String, PublicDemoReplacementStage> replacementStageByEngineerId;
}
