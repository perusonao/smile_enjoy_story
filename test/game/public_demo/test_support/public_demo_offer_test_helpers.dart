import 'package:smile_enjoy_story/game/public_demo/public_demo_binding_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

/// Test-only helper that accepts [applicant]'s offer through the real,
/// sanctioned [PublicDemoOfferAcceptance.accept] entry point.
///
/// WORKFLOW-STATE-1 closed the legacy
/// `applicant.copyWith(acceptedMonthlySalary: ...).join(...)` bypass:
/// [PublicDemoApplicant.join] now requires a domain-issued
/// [PublicDemoBindingOffer], and that offer can only be minted here. This
/// forces `acceptanceScore: 100` by default so tests that only care about
/// salary or delta math don't also have to satisfy the real evaluator's
/// accept/decline score threshold; pass [motivationDelta]/[trustDelta] to
/// drive specific relationship-event deltas the same way.
PublicDemoApplicant acceptTestOffer(
  PublicDemoApplicant applicant, {
  required int offeredMonthlySalary,
  int motivationDelta = 0,
  int trustDelta = 0,
  int fiscalCloseMonth = 5,
}) {
  final offer = PublicDemoSalaryOffer(
    requestedMonthlySalary: applicant.requestedMonthlySalary,
    offeredMonthlySalary: offeredMonthlySalary,
    acceptanceScore: 100,
    motivationDelta: motivationDelta,
    trustDelta: trustDelta,
  );
  // WORKFLOW-STATE-1AB FIX1 P1-1B: accept() now requires the applicant to
  // be at the real pre-offer stage. Test fixtures across this suite
  // construct applicants at the default `applied` stage since only salary/
  // join math is under test here, not the interview gate itself — so this
  // helper forces the realistic precondition rather than every call site
  // repeating it.
  final interviewed = applicant.stage == PublicDemoApplicantStage.interviewed
      ? applicant
      : applicant.copyWith(stage: PublicDemoApplicantStage.interviewed);
  return PublicDemoOfferAcceptance.accept(
    applicant: interviewed,
    offer: offer,
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(fiscalCloseMonth),
  ).applicant;
}
