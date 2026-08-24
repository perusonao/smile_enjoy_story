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
/// to enforce. It is now private to this file, so
/// [_PublicDemoRecruitmentTransaction.execute] can only ever be reached
/// through [PublicDemoRecruitmentWorkflowTransaction.execute] below.
///
/// FIX2 P1-2: FIX1's own [execute] still returned a result object exposing
/// the committed [PublicDemoState] and [PublicDemoWorkflowState] as two
/// separate public fields (`result.state` / `result.workflow`) — computed
/// atomically together, but nothing stopped a caller from applying only one
/// of them (e.g. `s = result.state;` and never `workflow = result.workflow;`),
/// a "cash spent, applicants missing" bypass at the *caller* rather than the
/// *calculation*. [execute] no longer returns the committed
/// [PublicDemoState] (the value that carries the cash charge) as a directly
/// readable field of anything it returns at all: the only way to obtain it
/// — and it is always paired with the committed [PublicDemoWorkflowState] —
/// is [onCommitted], invoked exactly once, synchronously, and only when the
/// purchase succeeds. [execute]'s own return value
/// ([PublicDemoRecruitmentTransactionResult]) carries only read-only facts
/// (status, medium, charged amount, the generated applicants — data about
/// what happened, not the authoritative cash-bearing state itself), so
/// inspecting it can never substitute for going through [onCommitted].
class PublicDemoRecruitmentWorkflowTransaction {
  PublicDemoRecruitmentWorkflowTransaction({
    PublicDemoRecruitmentCandidateGenerator? candidateGenerator,
  }) : _transaction = _PublicDemoRecruitmentTransaction(
         candidateGenerator: candidateGenerator,
       );

  final _PublicDemoRecruitmentTransaction _transaction;

  /// Runs the purchase against [state]/[workflow] and, only on success,
  /// invokes [onCommitted] once with the committed state and the committed
  /// workflow (already carrying the generated applicants) together. Always
  /// returns the read-only [PublicDemoRecruitmentTransactionResult]
  /// describing what happened — callers that only need the failure message
  /// never have to supply [onCommitted].
  PublicDemoRecruitmentTransactionResult execute({
    required PublicDemoState state,
    required PublicDemoWorkflowState workflow,
    required PublicDemoRecruitmentMedium medium,
    void Function(
      PublicDemoState committedState,
      PublicDemoWorkflowState committedWorkflow,
    )?
    onCommitted,
  }) {
    final result = _transaction.execute(state: state, medium: medium);
    if (result.isSuccess) {
      onCommitted?.call(
        result.state,
        workflow.withGeneratedApplicants(result.generatedApplicants),
      );
    }
    return PublicDemoRecruitmentTransactionResult._(
      medium: result.medium,
      chargedAmount: result.chargedAmount,
      generatedApplicants: result.generatedApplicants,
      status: result.status,
    );
  }
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

  _PublicDemoRecruitmentCalculationResult execute({
    required PublicDemoState state,
    required PublicDemoRecruitmentMedium medium,
  }) {
    if (!state.canUseRecruitmentMediaInMonth(state.month)) {
      return _PublicDemoRecruitmentCalculationResult.failure(
        state: state,
        medium: medium,
        status: PublicDemoRecruitmentTransactionStatus.alreadyUsedThisMonth,
      );
    }
    if (state.cash < medium.cost) {
      return _PublicDemoRecruitmentCalculationResult.failure(
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
      return _PublicDemoRecruitmentCalculationResult.failure(
        state: state,
        medium: medium,
        status: PublicDemoRecruitmentTransactionStatus.generationFailed,
      );
    }

    final committed = state
        .copyWith(cash: state.cash - medium.cost)
        .recordRecruitmentSpend(medium.cost)
        .markRecruitmentMediaUsed(state.month);
    return _PublicDemoRecruitmentCalculationResult.success(
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

/// Internal-only calculation output — carries the committed
/// [PublicDemoState] (the cash charge). Private to this file: unlike the
/// public [PublicDemoRecruitmentTransactionResult] below, nothing outside
/// this file can read [state] directly, so nothing outside this file can
/// obtain the committed cash-bearing state without going through
/// [PublicDemoRecruitmentWorkflowTransaction.execute]'s `onCommitted`
/// (WORKFLOW-STATE-1AB FIX2 P1-2).
class _PublicDemoRecruitmentCalculationResult {
  const _PublicDemoRecruitmentCalculationResult._({
    required this.state,
    required this.medium,
    required this.chargedAmount,
    required this.generatedApplicants,
    required this.status,
  });

  factory _PublicDemoRecruitmentCalculationResult.success({
    required PublicDemoState state,
    required PublicDemoRecruitmentMedium medium,
    required List<PublicDemoApplicant> generatedApplicants,
  }) => _PublicDemoRecruitmentCalculationResult._(
    state: state,
    medium: medium,
    chargedAmount: medium.cost,
    generatedApplicants: List.unmodifiable(generatedApplicants),
    status: PublicDemoRecruitmentTransactionStatus.success,
  );

  factory _PublicDemoRecruitmentCalculationResult.failure({
    required PublicDemoState state,
    required PublicDemoRecruitmentMedium medium,
    required PublicDemoRecruitmentTransactionStatus status,
  }) => _PublicDemoRecruitmentCalculationResult._(
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

/// Read-only facts about a recruitment-media purchase attempt
/// (WORKFLOW-STATE-1AB FIX2 P1-2). Deliberately does NOT carry the
/// committed [PublicDemoState] or [PublicDemoWorkflowState] — see the class
/// doc on [PublicDemoRecruitmentWorkflowTransaction] for why. Use this for
/// status/messaging only; use `onCommitted` to actually apply the purchase.
class PublicDemoRecruitmentTransactionResult {
  const PublicDemoRecruitmentTransactionResult._({
    required this.medium,
    required this.chargedAmount,
    required this.generatedApplicants,
    required this.status,
  });

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
