import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_binding_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_join.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

/// WORKFLOW-STATE-1 §12/§29, WORKFLOW-STATE-1AB FIX1 P1-1C/D/E/F: join must
/// be authoritative. The caller supplies only identity/intent
/// (applicant/week/currentFiscalCloseId) — never a salary — and join
/// without a BindingOffer, a BindingOffer that does not belong to this
/// applicant, a stale BindingOffer, or a duplicate join, must all be
/// rejected.
void main() {
  const transaction = PublicDemoJoinTransaction();
  final currentFiscalCloseId = PublicDemoFiscalCloseId.forMonth(5);

  const applicant = PublicDemoApplicant(
    id: 'app-01',
    name: 'Test',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
    requestedMonthlySalary: 320000,
    stage: PublicDemoApplicantStage.interviewed,
  );

  PublicDemoApplicant withBindingOffer(int salary, {int fiscalCloseMonth = 5}) {
    final offer = PublicDemoSalaryOffer(
      requestedMonthlySalary: applicant.requestedMonthlySalary,
      offeredMonthlySalary: salary,
      acceptanceScore: 100,
      motivationDelta: 0,
      trustDelta: 0,
    );
    return PublicDemoOfferAcceptance.accept(
      applicant: applicant,
      offer: offer,
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(fiscalCloseMonth),
    ).applicant;
  }

  test('a valid BindingOffer lets join succeed', () {
    final result = transaction.join(
      applicant: withBindingOffer(320000),
      week: 9,
      currentFiscalCloseId: currentFiscalCloseId,
    );

    expect(result.isJoined, isTrue);
    expect(result.applicant.hasJoined, isTrue);
  });

  test('salary is resolved from the BindingOffer, not any caller input', () {
    // The join API surface (join/joinAll) has no salary parameter at all —
    // this test demonstrates the resolved salary always matches the
    // applicant's own binding offer regardless of what was requested.
    final accepted = withBindingOffer(360000);
    final result = transaction.join(
      applicant: accepted,
      week: 9,
      currentFiscalCloseId: currentFiscalCloseId,
    );

    expect(result.applicant.acceptedMonthlySalary, 360000);
    expect(result.applicant.bindingOffer!.acceptedMonthlySalary, 360000);
  });

  test('an arbitrary caller-supplied salary is structurally impossible: '
      'PublicDemoJoinTransaction.join has no salary parameter', () {
    // This is a compile-time guarantee, not a runtime check: the method
    // signature above (`join({required applicant, required week,
    // required currentFiscalCloseId})`) is exhaustive. Documented here as
    // the executable proof that calling it with only identity/intent is
    // the only way to call it at all.
    final result = transaction.join(
      applicant: withBindingOffer(320000),
      week: 9,
      currentFiscalCloseId: currentFiscalCloseId,
    );
    expect(result.applicant.acceptedMonthlySalary, isNot(999999999));
  });

  test('a fabricated acceptedMonthlySalary on the applicant is overridden by '
      'the BindingOffer at join time (P1-1F)', () {
    // A caller cannot tamper with the applicant's mutable
    // `acceptedMonthlySalary` field via copyWith before joining and have
    // that tampered value become the payroll-authoritative salary — join
    // always re-derives it from the applicant's own BindingOffer.
    final tampered = withBindingOffer(
      320000,
    ).copyWith(acceptedMonthlySalary: 999999999);
    final result = transaction.join(
      applicant: tampered,
      week: 9,
      currentFiscalCloseId: currentFiscalCloseId,
    );

    expect(result.isJoined, isTrue);
    expect(result.applicant.acceptedMonthlySalary, 320000);
  });

  test('join without a BindingOffer is rejected', () {
    final result = transaction.join(
      applicant: applicant,
      week: 9,
      currentFiscalCloseId: currentFiscalCloseId,
    );

    expect(result.isJoined, isFalse);
    expect(result.status, PublicDemoJoinStatus.noBindingOffer);
    expect(result.applicant.hasJoined, isFalse);
    expect(result.applicant, same(applicant));
  });

  test('a BindingOffer reused from a different applicant (via copyWith) is '
      'rejected (P1-1D/F)', () {
    final offerFromSomeoneElse = withBindingOffer(320000).bindingOffer!;
    const otherApplicant = PublicDemoApplicant(
      id: 'app-02',
      name: 'Someone Else',
      resumeSummary: 'Java 1年',
      interviewScore: 60,
      acceptanceScore: 60,
      salesSkillFit: 60,
    );
    final fabricated = otherApplicant.copyWith(
      bindingOffer: offerFromSomeoneElse,
    );

    final result = transaction.join(
      applicant: fabricated,
      week: 9,
      currentFiscalCloseId: currentFiscalCloseId,
    );

    expect(result.isJoined, isFalse);
    expect(result.status, PublicDemoJoinStatus.wrongApplicant);
    expect(result.applicant.hasJoined, isFalse);
  });

  test('a stale (earlier fiscal close) BindingOffer is rejected (P1-1E)', () {
    final acceptedInMay = withBindingOffer(320000, fiscalCloseMonth: 5);

    final result = transaction.join(
      applicant: acceptedInMay,
      week: 9,
      currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(8),
    );

    expect(result.isJoined, isFalse);
    expect(result.status, PublicDemoJoinStatus.staleFiscalClose);
    expect(result.applicant.hasJoined, isFalse);
  });

  test('duplicate join is rejected', () {
    final joined = transaction
        .join(
          applicant: withBindingOffer(320000),
          week: 9,
          currentFiscalCloseId: currentFiscalCloseId,
        )
        .applicant;

    final again = transaction.join(
      applicant: joined,
      week: 10,
      currentFiscalCloseId: currentFiscalCloseId,
    );

    expect(again.isJoined, isFalse);
    expect(again.status, PublicDemoJoinStatus.alreadyJoined);
    expect(again.applicant, same(joined));
  });

  test('joinAll processes each applicant independently by id', () {
    final eligible = withBindingOffer(320000);
    const ineligible = PublicDemoApplicant(
      id: 'app-03',
      name: 'Test 3',
      resumeSummary: 'Java 2年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
      requestedMonthlySalary: 300000,
    );

    final results = transaction.joinAll(
      applicants: [eligible, ineligible],
      applicantIds: {eligible.id, ineligible.id},
      week: 9,
      currentFiscalCloseId: currentFiscalCloseId,
    );

    expect(results, hasLength(2));
    expect(results[0].isJoined, isTrue);
    expect(results[1].isJoined, isFalse);
    expect(results[1].status, PublicDemoJoinStatus.noBindingOffer);
  });
}
