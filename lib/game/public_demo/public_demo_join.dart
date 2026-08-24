import 'public_demo_fiscal_close_id.dart';
import 'public_demo_recruitment.dart';

/// The single sanctioned entry point for joining a Public Demo 0.1 applicant
/// (WORKFLOW-STATE-1 §12, WORKFLOW-STATE-1AB FIX1 P1-1C).
///
/// The caller supplies only identity and intent —
/// [applicant]/[week]/[currentFiscalCloseId] — and never a salary:
/// [PublicDemoApplicant.join] resolves salary entirely from the applicant's
/// own authoritative [PublicDemoBindingOffer], so an arbitrary
/// caller-supplied salary is not just rejected, it is structurally
/// impossible (there is no parameter for it). Every other required fact —
/// offer existence, offer identity (the offer must actually belong to this
/// applicant, not one fabricated/reused via `copyWith`), offer validity, and
/// fiscal-close freshness — is checked here before delegating to the model.
class PublicDemoJoinTransaction {
  const PublicDemoJoinTransaction();

  PublicDemoJoinResult join({
    required PublicDemoApplicant applicant,
    required int week,
    required PublicDemoFiscalCloseId currentFiscalCloseId,
  }) {
    if (applicant.hasJoined) {
      return PublicDemoJoinResult._(
        applicant: applicant,
        status: PublicDemoJoinStatus.alreadyJoined,
      );
    }
    final offer = applicant.bindingOffer;
    if (offer == null) {
      return PublicDemoJoinResult._(
        applicant: applicant,
        status: PublicDemoJoinStatus.noBindingOffer,
      );
    }
    // P1-1D/F: rejects a BindingOffer reused/attached across applicants —
    // e.g. via `applicantB.copyWith(bindingOffer: offerMintedForApplicantA)`
    // — even though the offer object itself is a genuine, domain-issued
    // instance. Provenance must match identity, not just existence.
    if (offer.applicantId != applicant.id) {
      return PublicDemoJoinResult._(
        applicant: applicant,
        status: PublicDemoJoinStatus.wrongApplicant,
      );
    }
    if (applicant.stage == PublicDemoApplicantStage.offerDeclined) {
      return PublicDemoJoinResult._(
        applicant: applicant,
        status: PublicDemoJoinStatus.notEligible,
      );
    }
    // P1-1E: an offer minted at one fiscal close is not valid to join
    // against a later one — join must happen within the same close the
    // offer was accepted at.
    if (offer.fiscalCloseId != currentFiscalCloseId) {
      return PublicDemoJoinResult._(
        applicant: applicant,
        status: PublicDemoJoinStatus.staleFiscalClose,
      );
    }
    return PublicDemoJoinResult._(
      applicant: applicant.join(week: week),
      status: PublicDemoJoinStatus.joined,
    );
  }

  /// Joins every applicant in [applicants] whose id is in [applicantIds],
  /// each independently (one applicant's rejection never affects another's).
  List<PublicDemoJoinResult> joinAll({
    required Iterable<PublicDemoApplicant> applicants,
    required Set<String> applicantIds,
    required int week,
    required PublicDemoFiscalCloseId currentFiscalCloseId,
  }) => [
    for (final applicant in applicants)
      if (applicantIds.contains(applicant.id))
        join(
          applicant: applicant,
          week: week,
          currentFiscalCloseId: currentFiscalCloseId,
        ),
  ];
}

class PublicDemoJoinResult {
  const PublicDemoJoinResult._({required this.applicant, required this.status});

  final PublicDemoApplicant applicant;
  final PublicDemoJoinStatus status;

  bool get isJoined => status == PublicDemoJoinStatus.joined;
}

enum PublicDemoJoinStatus {
  joined,
  alreadyJoined,
  noBindingOffer,
  notEligible,
  wrongApplicant,
  staleFiscalClose,
}
