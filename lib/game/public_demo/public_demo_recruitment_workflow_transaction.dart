import 'public_demo_recruitment.dart';
import 'public_demo_recruitment_medium.dart';
import 'public_demo_state.dart';
import 'public_demo_workflow_state.dart';

typedef PublicDemoRecruitmentCandidateGenerator =
    List<PublicDemoApplicant> Function({
      required int month,
      required PublicDemoRecruitmentMedium medium,
      required int count,
    });

/// Atomically commits a recruitment-media purchase across both authorities
/// it touches: cash/usage on [PublicDemoState] and generated applicants on
/// [PublicDemoWorkflowState] (WORKFLOW-STATE-1 §14/§15).
///
/// WORKFLOW-STATE-1AB FIX1 P1-2: the pure cash/applicant calculation
/// ([_PublicDemoRecruitmentTransaction] below) used to be a public class
/// (`PublicDemoRecruitmentTransaction`) that any caller could invoke
/// directly and then choose to commit only `result.state` (cash) while
/// discarding `result.generatedApplicants` — a structural "cash spent,
/// applicants missing" bypass around the atomic contract this file exists
/// to enforce. It is now private to this file, so [_PublicDemoRecruitmentTransaction.execute]
/// can only ever be reached through [PublicDemoRecruitmentWorkflowTransaction.execute]
/// below, which always commits cash and applicants together or neither at
/// all: either [PublicDemoRecruitmentTransactionResult.isSuccess] is true
/// and this returns a result with both [PublicDemoRecruitmentWorkflowResult.state]
/// and [PublicDemoRecruitmentWorkflowResult.workflow] updated together, or
/// it is false and this returns both completely unchanged.
class PublicDemoRecruitmentWorkflowTransaction {
  PublicDemoRecruitmentWorkflowTransaction({
    PublicDemoRecruitmentCandidateGenerator? candidateGenerator,
  }) : _transaction = _PublicDemoRecruitmentTransaction(
         candidateGenerator: candidateGenerator,
       );

  final _PublicDemoRecruitmentTransaction _transaction;

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

/// Pure, all-or-nothing recruitment-media purchase for Public Demo 0.1.
///
/// Private to this file (P1-2, see the class doc above): the only caller
/// permitted to construct or invoke this is
/// [PublicDemoRecruitmentWorkflowTransaction], which always commits both of
/// this class's outputs (cash and generated applicants) together.
class _PublicDemoRecruitmentTransaction {
  const _PublicDemoRecruitmentTransaction({
    PublicDemoRecruitmentCandidateGenerator? candidateGenerator,
  }) : _candidateGenerator = candidateGenerator ?? _generateApplicants;

  final PublicDemoRecruitmentCandidateGenerator _candidateGenerator;

  PublicDemoRecruitmentTransactionResult execute({
    required PublicDemoState state,
    required PublicDemoRecruitmentMedium medium,
  }) {
    if (!state.canUseRecruitmentMediaInMonth(state.month)) {
      return PublicDemoRecruitmentTransactionResult.failure(
        state: state,
        medium: medium,
        status: PublicDemoRecruitmentTransactionStatus.alreadyUsedThisMonth,
      );
    }
    if (state.cash < medium.cost) {
      return PublicDemoRecruitmentTransactionResult.failure(
        state: state,
        medium: medium,
        status: PublicDemoRecruitmentTransactionStatus.insufficientCash,
      );
    }

    final applicants = _candidateGenerator(
      month: state.month,
      medium: medium,
      count: medium.applicantCount,
    );
    if (applicants.length != medium.applicantCount) {
      return PublicDemoRecruitmentTransactionResult.failure(
        state: state,
        medium: medium,
        status: PublicDemoRecruitmentTransactionStatus.generationFailed,
      );
    }

    final committed = state
        .copyWith(cash: state.cash - medium.cost)
        .recordRecruitmentSpend(medium.cost)
        .markRecruitmentMediaUsed(state.month);
    return PublicDemoRecruitmentTransactionResult.success(
      state: committed,
      medium: medium,
      generatedApplicants: applicants,
    );
  }

  /// Selects from media-specific lightweight profiles without importing the
  /// main game's random generator. Keep the established engineer pool separate
  /// so adding free-media templates cannot alter its existing month results.
  static List<PublicDemoApplicant> _generateApplicants({
    required int month,
    required PublicDemoRecruitmentMedium medium,
    required int count,
  }) {
    final pool = switch (medium) {
      PublicDemoRecruitmentMedium.engineer => publicDemoMayApplicants,
      PublicDemoRecruitmentMedium.free => publicDemoFreeApplicants,
    };
    return List.generate(count, (index) {
      final template = pool[(month + medium.index + index) % pool.length];
      return PublicDemoApplicant(
        id: 'recruitment-$month-${medium.name}-${index + 1}',
        name: template.name,
        resumeSummary: template.resumeSummary,
        interviewScore: template.interviewScore,
        acceptanceScore: template.acceptanceScore,
        salesSkillFit: template.salesSkillFit,
        experienceMonths: template.experienceMonths,
        requestedMonthlySalary: template.requestedMonthlySalary,
      );
    });
  }
}

class PublicDemoRecruitmentTransactionResult {
  const PublicDemoRecruitmentTransactionResult._({
    required this.state,
    required this.medium,
    required this.chargedAmount,
    required this.generatedApplicants,
    required this.status,
  });

  factory PublicDemoRecruitmentTransactionResult.success({
    required PublicDemoState state,
    required PublicDemoRecruitmentMedium medium,
    required List<PublicDemoApplicant> generatedApplicants,
  }) => PublicDemoRecruitmentTransactionResult._(
    state: state,
    medium: medium,
    chargedAmount: medium.cost,
    generatedApplicants: List.unmodifiable(generatedApplicants),
    status: PublicDemoRecruitmentTransactionStatus.success,
  );

  factory PublicDemoRecruitmentTransactionResult.failure({
    required PublicDemoState state,
    required PublicDemoRecruitmentMedium medium,
    required PublicDemoRecruitmentTransactionStatus status,
  }) => PublicDemoRecruitmentTransactionResult._(
    state: state,
    medium: medium,
    chargedAmount: 0,
    generatedApplicants: const [],
    status: status,
  );

  final PublicDemoState state;
  final PublicDemoRecruitmentMedium medium;
  final int chargedAmount;
  final List<PublicDemoApplicant> generatedApplicants;
  final PublicDemoRecruitmentTransactionStatus status;

  bool get isSuccess =>
      status == PublicDemoRecruitmentTransactionStatus.success;
}

enum PublicDemoRecruitmentTransactionStatus {
  success,
  alreadyUsedThisMonth,
  insufficientCash,
  generationFailed,
}
