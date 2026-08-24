import 'public_demo_fiscal_close_id.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_salary_offer.dart';

/// Authoritative, immutable proof that a specific applicant's salary offer
/// was accepted through the domain, at a specific fiscal close.
///
/// [PublicDemoBindingOffer]'s constructor is private to this file, so it can
/// only ever be produced by [PublicDemoOfferAcceptance.accept] below — no UI
/// or other caller can fabricate one by constructing it directly or by
/// setting arbitrary fields (WORKFLOW-STATE-1 §9). [PublicDemoJoinTransaction]
/// (public_demo_join.dart) requires an applicant to carry one of these before
/// it will join them.
class PublicDemoBindingOffer {
  const PublicDemoBindingOffer._({
    required this.applicantId,
    required this.acceptedMonthlySalary,
    required this.fiscalCloseId,
  });

  /// The applicant this offer was accepted for. Provenance, not a live
  /// lookup key — callers still address applicants by id elsewhere.
  final String applicantId;

  /// The salary the domain actually accepted, at the moment of acceptance.
  /// This is the sole authoritative source [PublicDemoJoinTransaction] and
  /// payroll callers may treat as this applicant's binding salary.
  final int acceptedMonthlySalary;

  /// Which fiscal close produced this binding offer.
  final PublicDemoFiscalCloseId fiscalCloseId;

  @override
  String toString() =>
      'PublicDemoBindingOffer(applicantId: $applicantId, '
      'acceptedMonthlySalary: $acceptedMonthlySalary, '
      'fiscalCloseId: $fiscalCloseId)';
}

/// The single sanctioned entry point for accepting a Public Demo 0.1 salary
/// offer (WORKFLOW-STATE-1 §11).
///
/// [offer] is already a pure domain calculation
/// ([PublicDemoSalaryOfferEvaluator.evaluate]) — the UI only chooses *which*
/// candidate salary to evaluate, it never supplies acceptance, salary, or
/// binding-offer state directly. This command is what actually commits that
/// decision onto the applicant and, only when the offer is accepted, mints
/// the [PublicDemoBindingOffer] that later join/payroll authority depends on.
class PublicDemoOfferAcceptance {
  const PublicDemoOfferAcceptance._();

  static PublicDemoOfferAcceptanceResult accept({
    required PublicDemoApplicant applicant,
    required PublicDemoSalaryOffer offer,
    required PublicDemoFiscalCloseId fiscalCloseId,
  }) {
    // Idempotent: an applicant only ever gets one binding offer. A repeated
    // call (there is currently no UI path that makes one, but this is the
    // sole authority so it must hold regardless) leaves the existing
    // provenance untouched rather than minting a second one.
    if (applicant.bindingOffer != null) {
      return PublicDemoOfferAcceptanceResult._(
        applicant: applicant,
        bindingOffer: applicant.bindingOffer,
        status: PublicDemoOfferAcceptanceStatus.alreadyDecided,
      );
    }

    // WORKFLOW-STATE-1AB FIX1 P1-1B: an offer can only be minted for an
    // applicant who has actually reached the post-interview selection
    // stage. Without this, a caller could invoke this command on an
    // applicant still at `applied`/`resumeReviewed` (or any other stage)
    // and mint a valid BindingOffer for someone who was never evaluated —
    // an authority bypass around the interview gate the UI otherwise
    // enforces only cosmetically.
    if (applicant.stage != PublicDemoApplicantStage.interviewed) {
      return PublicDemoOfferAcceptanceResult._(
        applicant: applicant,
        bindingOffer: null,
        status: PublicDemoOfferAcceptanceStatus.invalidStage,
      );
    }

    final decided = offer
        .applyTo(applicant)
        .copyWith(
          stage: offer.accepted
              ? PublicDemoApplicantStage.offerAccepted
              : PublicDemoApplicantStage.offerDeclined,
        );

    if (!offer.accepted) {
      return PublicDemoOfferAcceptanceResult._(
        applicant: decided,
        bindingOffer: null,
        status: PublicDemoOfferAcceptanceStatus.declined,
      );
    }

    final bindingOffer = PublicDemoBindingOffer._(
      applicantId: applicant.id,
      acceptedMonthlySalary: offer.offeredMonthlySalary,
      fiscalCloseId: fiscalCloseId,
    );
    return PublicDemoOfferAcceptanceResult._(
      applicant: decided.copyWith(bindingOffer: bindingOffer),
      bindingOffer: bindingOffer,
      status: PublicDemoOfferAcceptanceStatus.accepted,
    );
  }
}

class PublicDemoOfferAcceptanceResult {
  const PublicDemoOfferAcceptanceResult._({
    required this.applicant,
    required this.bindingOffer,
    required this.status,
  });

  final PublicDemoApplicant applicant;
  final PublicDemoBindingOffer? bindingOffer;
  final PublicDemoOfferAcceptanceStatus status;

  bool get isAccepted => status == PublicDemoOfferAcceptanceStatus.accepted;
}

enum PublicDemoOfferAcceptanceStatus {
  accepted,
  declined,
  alreadyDecided,
  invalidStage,
}
