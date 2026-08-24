import 'public_demo_recruitment_medium.dart';
import 'public_demo_recruitment_transaction.dart';
import 'public_demo_state.dart';
import 'public_demo_workflow_state.dart';

/// Atomically commits a recruitment-media purchase across both authorities
/// it touches: cash/usage on [PublicDemoState] and generated applicants on
/// [PublicDemoWorkflowState] (WORKFLOW-STATE-1 §14/§15).
///
/// [PublicDemoRecruitmentTransaction] already computes cash and generated
/// applicants together as one pure, all-or-nothing result — this wrapper's
/// entire job is to make committing that result to *both* authorities a
/// single operation, so "cash spent, applicants missing" and "applicants
/// created, cash not spent" are both impossible: either
/// [PublicDemoRecruitmentTransactionResult.isSuccess] is true and this
/// returns a result with both [state] and [workflow] updated together, or it
/// is false and this returns both completely unchanged.
class PublicDemoRecruitmentWorkflowTransaction {
  const PublicDemoRecruitmentWorkflowTransaction({
    PublicDemoRecruitmentTransaction? transaction,
  }) : _transaction = transaction ?? const PublicDemoRecruitmentTransaction();

  final PublicDemoRecruitmentTransaction _transaction;

  PublicDemoRecruitmentWorkflowResult execute({
    required PublicDemoState state,
    required PublicDemoWorkflowState workflow,
    required PublicDemoRecruitmentMedium medium,
  }) {
    final result = _transaction.execute(state: state, medium: medium);
    return PublicDemoRecruitmentWorkflowResult._(
      state: result.state,
      workflow: result.isSuccess
          ? workflow.withGeneratedApplicants(result.generatedApplicants)
          : workflow,
      transactionResult: result,
    );
  }
}

class PublicDemoRecruitmentWorkflowResult {
  const PublicDemoRecruitmentWorkflowResult._({
    required this.state,
    required this.workflow,
    required this.transactionResult,
  });

  final PublicDemoState state;
  final PublicDemoWorkflowState workflow;
  final PublicDemoRecruitmentTransactionResult transactionResult;

  bool get isSuccess => transactionResult.isSuccess;
  PublicDemoRecruitmentTransactionStatus get status => transactionResult.status;
}
