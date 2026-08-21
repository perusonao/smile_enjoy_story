import 'public_demo_recruitment.dart';
import '../../domain/models/employee_relationship_event.dart';

enum PublicDemoSalaryOfferLevel { belowRequest, requested, aboveRequest }

/// Salary decision used after a Public Demo recruitment interview.
///
/// Phase 2A keeps the decision calculation separate from the existing May
/// progression. The UI and applicant stage flow can adopt it incrementally
/// without changing the current April-June path in the same change.
class PublicDemoSalaryOffer {
  const PublicDemoSalaryOffer({
    required this.requestedMonthlySalary,
    required this.offeredMonthlySalary,
    required this.acceptanceScore,
    required this.motivationDelta,
    required this.trustDelta,
  });

  final int requestedMonthlySalary;
  final int offeredMonthlySalary;
  final int acceptanceScore;
  final int motivationDelta;
  final int trustDelta;

  /// Public Demo's temporary "motivation" wording maps directly to the
  /// shared employee model's morale. Keep this mapping here so a future
  /// applicant-to-[Engineer] conversion does not recreate salary rules.
  int get moraleDelta => motivationDelta;

  bool get accepted => acceptanceScore >= 60;

  PublicDemoSalaryOfferLevel get level {
    if (offeredMonthlySalary < requestedMonthlySalary) {
      return PublicDemoSalaryOfferLevel.belowRequest;
    }
    if (offeredMonthlySalary > requestedMonthlySalary) {
      return PublicDemoSalaryOfferLevel.aboveRequest;
    }
    return PublicDemoSalaryOfferLevel.requested;
  }

  String get relationshipReason => switch (level) {
        PublicDemoSalaryOfferLevel.belowRequest => '希望給与を下回る条件で入社',
        PublicDemoSalaryOfferLevel.requested => '希望給与どおりの条件で入社',
        PublicDemoSalaryOfferLevel.aboveRequest => '希望給与を上回る条件で入社',
      };

  /// The relationship-history entry to apply through [MoraleEngine.applyDelta]
  /// when this accepted applicant is converted into an Engineer.
  EmployeeRelationshipEvent relationshipEvent({required int week}) =>
      EmployeeRelationshipEvent(
        week: week,
        reason: relationshipReason,
        moraleDelta: moraleDelta,
        trustDelta: trustDelta,
      );

  /// Records this salary decision on the applicant while retaining their
  /// recruitment progression. A declined offer is recorded too; callers
  /// decide whether that applicant has actually become a hire.
  PublicDemoApplicant applyTo(PublicDemoApplicant applicant) => applicant.copyWith(
        acceptedMonthlySalary: offeredMonthlySalary,
        salaryMotivationDelta: motivationDelta,
        salaryTrustDelta: trustDelta,
      );
}

class PublicDemoSalaryOfferEvaluator {
  const PublicDemoSalaryOfferEvaluator._();

  static PublicDemoSalaryOffer evaluate({
    required PublicDemoApplicant applicant,
    required int offeredMonthlySalary,
  }) {
    final requested = applicant.requestedMonthlySalary;
    final difference = offeredMonthlySalary - requested;

    // Keep the existing applicant acceptanceScore as the candidate-specific
    // baseline. Salary changes that score, but does not replace it, so a high
    // salary is helpful rather than an automatic correct answer.
    final scoreAdjustment = difference ~/ 10000 * 4;
    final acceptanceScore =
        (applicant.acceptanceScore + scoreAdjustment).clamp(0, 100).toInt();

    // Meeting the candidate's request is the neutral baseline. Offering less
    // creates an employee-state cost; offering more creates a modest benefit.
    final motivationDelta = difference < 0
        ? -6
        : difference > 0
            ? 4
            : 0;
    final trustDelta = difference < 0
        ? -8
        : difference > 0
            ? 3
            : 0;

    return PublicDemoSalaryOffer(
      requestedMonthlySalary: requested,
      offeredMonthlySalary: offeredMonthlySalary,
      acceptanceScore: acceptanceScore,
      motivationDelta: motivationDelta,
      trustDelta: trustDelta,
    );
  }
}
