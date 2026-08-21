import 'public_demo_recruitment.dart';

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

    final motivationDelta = difference < 0
        ? -6
        : difference > 0
            ? 4
            : 1;
    final trustDelta = difference < 0
        ? -8
        : difference > 0
            ? 3
            : 1;

    return PublicDemoSalaryOffer(
      requestedMonthlySalary: requested,
      offeredMonthlySalary: offeredMonthlySalary,
      acceptanceScore: acceptanceScore,
      motivationDelta: motivationDelta,
      trustDelta: trustDelta,
    );
  }
}
