import 'public_demo_recruitment.dart';
import 'public_demo_recruitment_medium.dart';
import 'public_demo_state.dart';

typedef PublicDemoRecruitmentCandidateGenerator =
    List<PublicDemoApplicant> Function({
      required int month,
      required PublicDemoRecruitmentMedium medium,
      required int count,
    });

/// Pure, all-or-nothing recruitment-media purchase for Public Demo 0.1.
///
/// Generated applicants are deliberately returned to the caller only. JOB-3
/// owns appending them to the screen-local recruitment workflow.
class PublicDemoRecruitmentTransaction {
  const PublicDemoRecruitmentTransaction({
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
        .markRecruitmentMediaUsed(state.month);
    return PublicDemoRecruitmentTransactionResult.success(
      state: committed,
      medium: medium,
      generatedApplicants: applicants,
    );
  }

  /// The Public Demo deliberately reuses its two established lightweight
  /// applicant profiles rather than importing the main game's random generator.
  static List<PublicDemoApplicant> _generateApplicants({
    required int month,
    required PublicDemoRecruitmentMedium medium,
    required int count,
  }) => List.generate(count, (index) {
    final template =
        publicDemoMayApplicants[(month + medium.index + index) %
            publicDemoMayApplicants.length];
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
