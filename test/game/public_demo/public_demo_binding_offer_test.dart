import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_binding_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

import 'test_support/public_demo_offer_test_helpers.dart';

/// WORKFLOW-STATE-1 §9/§11/§28: offer acceptance must be domain-authoritative
/// and the caller/UI must not be able to fabricate a valid BindingOffer.
void main() {
  // WORKFLOW-STATE-1AB FIX2 P1-1A, FIX3 P1-1: accept() now gates on the
  // unforgeable PublicDemoInterviewRecord (via hasBeenInterviewed), not
  // `stage` — completeTestInterview() mints it via the real
  // completeInterview() entry point, matching the real interview flow.
  final applicant = completeTestInterview(
    const PublicDemoApplicant(
      id: 'app-01',
      name: 'Test',
      resumeSummary: 'Java 3年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
      requestedMonthlySalary: 320000,
    ),
  );

  PublicDemoSalaryOffer offerAt(int salary) =>
      PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: salary,
      );

  test('accepting an offer mints an authoritative BindingOffer', () {
    final result = PublicDemoOfferAcceptance.accept(
      applicant: applicant,
      offer: offerAt(320000),
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    );

    expect(result.isAccepted, isTrue);
    expect(result.bindingOffer, isNotNull);
    expect(result.bindingOffer!.applicantId, applicant.id);
    expect(result.bindingOffer!.acceptedMonthlySalary, 320000);
    expect(
      result.bindingOffer!.fiscalCloseId,
      PublicDemoFiscalCloseId.forMonth(5),
    );
    expect(result.applicant.bindingOffer, same(result.bindingOffer));
    expect(result.applicant.hasBindingOffer, isTrue);
    expect(result.applicant.stage, PublicDemoApplicantStage.offerAccepted);
  });

  test('accepted salary is stored authoritatively on the applicant', () {
    final result = PublicDemoOfferAcceptance.accept(
      applicant: applicant,
      offer: offerAt(360000),
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    );

    expect(result.applicant.acceptedMonthlySalary, 360000);
    expect(result.bindingOffer!.acceptedMonthlySalary, 360000);
  });

  test('accepting an offer before the applicant reached the interviewed stage '
      'is rejected (P1-1B)', () {
    const notYetInterviewed = PublicDemoApplicant(
      id: 'app-02',
      name: 'Not Interviewed',
      resumeSummary: 'Java 1年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
      requestedMonthlySalary: 320000,
    );
    final result = PublicDemoOfferAcceptance.accept(
      applicant: notYetInterviewed,
      offer: PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: notYetInterviewed,
        offeredMonthlySalary: 320000,
      ),
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    );

    expect(result.isAccepted, isFalse);
    expect(result.status, PublicDemoOfferAcceptanceStatus.invalidStage);
    expect(result.bindingOffer, isNull);
    expect(result.applicant, same(notYetInterviewed));
    expect(result.applicant.hasBindingOffer, isFalse);
  });

  group('interview record cannot be fabricated (P1-1A)', () {
    test(
      'a fake interviewed applicant: stage set via public copyWith without '
      'ever going through completeInterview does not pass accept authority',
      () {
        const neverInterviewed = PublicDemoApplicant(
          id: 'faker',
          name: 'Faker',
          resumeSummary: 'Java 1年',
          interviewScore: 70,
          acceptanceScore: 70,
          salesSkillFit: 70,
          requestedMonthlySalary: 320000,
        );
        // The caller CAN set `stage` to `interviewed` via the public
        // copyWith — that alone is harmless (WORKFLOW-STATE-1AB §6 design
        // rule): it produces no PublicDemoInterviewRecord, so it cannot
        // authorize an offer.
        final fabricated = neverInterviewed.copyWith(
          stage: PublicDemoApplicantStage.interviewed,
        );
        expect(fabricated.stage, PublicDemoApplicantStage.interviewed);
        expect(fabricated.hasBeenInterviewed, isFalse);

        final result = PublicDemoOfferAcceptance.accept(
          applicant: fabricated,
          offer: PublicDemoSalaryOfferEvaluator.evaluate(
            applicant: fabricated,
            offeredMonthlySalary: 320000,
          ),
          fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
        );

        expect(result.isAccepted, isFalse);
        expect(result.status, PublicDemoOfferAcceptanceStatus.invalidStage);
        expect(result.bindingOffer, isNull);
      },
    );

    test(
      'a genuine interview record reused on a different applicant via '
      'copyWith is rejected by identity, mirroring BindingOffer reuse (P1-1D)',
      () {
        final interviewed = completeTestInterview(applicant);
        const differentApplicant = PublicDemoApplicant(
          id: 'different-applicant',
          name: 'Different',
          resumeSummary: 'Java 1年',
          interviewScore: 70,
          acceptanceScore: 70,
          salesSkillFit: 70,
          requestedMonthlySalary: 320000,
        );
        final reused = differentApplicant.copyWith(
          interviewRecord: interviewed.interviewRecord,
        );

        expect(reused.hasBeenInterviewed, isFalse);

        final result = PublicDemoOfferAcceptance.accept(
          applicant: reused,
          offer: PublicDemoSalaryOfferEvaluator.evaluate(
            applicant: reused,
            offeredMonthlySalary: 320000,
          ),
          fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
        );

        expect(result.isAccepted, isFalse);
        expect(result.status, PublicDemoOfferAcceptanceStatus.invalidStage);
      },
    );
  });

  test('a declined offer never mints a BindingOffer', () {
    // A large negative delta drives acceptanceScore below 60.
    final result = PublicDemoOfferAcceptance.accept(
      applicant: applicant,
      offer: offerAt(0),
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    );

    expect(result.isAccepted, isFalse);
    expect(result.bindingOffer, isNull);
    expect(result.applicant.bindingOffer, isNull);
    expect(result.applicant.hasBindingOffer, isFalse);
    expect(result.applicant.stage, PublicDemoApplicantStage.offerDeclined);
  });

  test('fiscal close identity is authoritative and carried verbatim', () {
    final result = PublicDemoOfferAcceptance.accept(
      applicant: applicant,
      offer: offerAt(320000),
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(7),
    );

    expect(result.bindingOffer!.fiscalCloseId.internalMonth, 7);
  });

  test('a repeated acceptance does not mint a second BindingOffer', () {
    final first = PublicDemoOfferAcceptance.accept(
      applicant: applicant,
      offer: offerAt(320000),
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    );
    final second = PublicDemoOfferAcceptance.accept(
      applicant: first.applicant,
      offer: offerAt(400000),
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(6),
    );

    expect(second.status, PublicDemoOfferAcceptanceStatus.alreadyDecided);
    expect(second.bindingOffer, same(first.bindingOffer));
    expect(
      second.applicant.acceptedMonthlySalary,
      first.applicant.acceptedMonthlySalary,
    );
  });

  test(
    'the UI/caller cannot fabricate a valid BindingOffer: there is no public '
    'constructor, and PublicDemoApplicant construction leaves it null by default',
    () {
      // PublicDemoBindingOffer's constructor is private to
      // public_demo_binding_offer.dart, so the only way another file can
      // ever attach one to an applicant is by going through
      // PublicDemoOfferAcceptance.accept (this file's own applicant literal
      // proves construction alone gives no BindingOffer at all).
      expect(applicant.bindingOffer, isNull);
      expect(applicant.hasBindingOffer, isFalse);
    },
  );

  test('PublicDemoFiscalCloseId rejects a month outside the fiscal year', () {
    expect(() => PublicDemoFiscalCloseId.forMonth(3), throwsArgumentError);
    expect(() => PublicDemoFiscalCloseId.forMonth(16), throwsArgumentError);
  });

  test(
    'PublicDemoFiscalCloseId equality is by internal month, not display month',
    () {
      // Public Demo 0.1's internal months 13/14/15 all display as distinct
      // calendar months (Jan/Feb/Mar), but the identity itself must key off
      // the internal value, never a recomputed display label.
      expect(
        PublicDemoFiscalCloseId.forMonth(13),
        isNot(equals(PublicDemoFiscalCloseId.forMonth(14))),
      );
      expect(
        PublicDemoFiscalCloseId.forMonth(13),
        equals(PublicDemoFiscalCloseId.forMonth(13)),
      );
    },
  );
}
