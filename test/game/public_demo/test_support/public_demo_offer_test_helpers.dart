import 'package:smile_enjoy_story/game/public_demo/public_demo_binding_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

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
  // WORKFLOW-STATE-1AB FIX1 P1-1B, FIX2 P1-1A, FIX3 P1-1: accept() now
  // requires the applicant to carry a genuine (unforgeable) interview
  // record, not just `stage == interviewed`. Test fixtures across this
  // suite construct applicants at the default `applied` stage since only
  // salary/join math is under test here, not the interview gate itself —
  // so this helper calls the real [PublicDemoApplicant.completeInterview]
  // (with a genuine proof obtained from a throwaway [PublicDemoState]'s own
  // real slot consumption — the sole sanctioned way to mint one) rather
  // than every call site repeating it.
  final interviewed = applicant.hasBeenInterviewed
      ? applicant
      : applicant.completeInterview(
          PublicDemoState.aprilStart().useSalesSlotForInterview().proof!,
        );
  return PublicDemoOfferAcceptance.accept(
    applicant: interviewed,
    offer: offer,
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(fiscalCloseMonth),
  ).applicant;
}

/// Test-only helper that mints [applicant]'s genuine interview record
/// through the real, sanctioned [PublicDemoApplicant.completeInterview]
/// entry point (WORKFLOW-STATE-1AB FIX3 P1-1) — with a genuine
/// [PublicDemoSalesSlotConsumptionProof] obtained from a throwaway
/// [PublicDemoState]'s own real sales-slot consumption, the only way to
/// mint one. Idempotent, mirroring `completeInterview` itself.
///
/// FIX3 replaced FIX2's zero-argument `PublicDemoApplicant.markInterviewed()`
/// (which many fixtures across this suite used directly) — that public,
/// unconditional mint was itself the P1-1 bypass this fix closed. This
/// helper is the test-suite's equivalent of
/// `PublicDemoAggregate.completeInterview`, so fixtures can still get a
/// genuinely-interviewed applicant in one call without duplicating the
/// proof plumbing at every call site.
PublicDemoApplicant completeTestInterview(PublicDemoApplicant applicant) =>
    applicant.hasBeenInterviewed
    ? applicant
    : applicant.completeInterview(
        PublicDemoState.aprilStart().useSalesSlotForInterview().proof!,
      );
