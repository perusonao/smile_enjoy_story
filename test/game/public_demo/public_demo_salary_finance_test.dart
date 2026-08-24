import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_binding_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

import 'test_support/public_demo_offer_test_helpers.dart';

void main() {
  // WORKFLOW-STATE-1AB FIX2 P1-1A, FIX3 P1-1: accept() gates on the
  // unforgeable interview record, not `stage` — completeTestInterview()
  // mints it via the real completeInterview() entry point.
  final applicant = completeTestInterview(
    const PublicDemoApplicant(
      id: 'test',
      name: 'Test',
      resumeSummary: 'Java 3年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
      requestedMonthlySalary: 320000,
    ),
  );

  // WORKFLOW-STATE-1: joining now requires a domain-issued BindingOffer
  // (PublicDemoApplicant.join no longer accepts a bare
  // `copyWith(acceptedMonthlySalary: ...)` bypass), so these cases go
  // through PublicDemoOfferAcceptance.accept exactly as production code
  // does, forcing acceptance via a maximal acceptanceScore so the salary
  // variations below (which would otherwise also move the acceptance
  // decision) still isolate pure payroll math, matching this test's
  // original intent.
  PublicDemoApplicant hireAt(int offeredMonthlySalary) {
    final offer = PublicDemoSalaryOffer(
      requestedMonthlySalary: applicant.requestedMonthlySalary,
      offeredMonthlySalary: offeredMonthlySalary,
      acceptanceScore: 100,
      motivationDelta: 0,
      trustDelta: 0,
    );
    final accepted = PublicDemoOfferAcceptance.accept(
      applicant: applicant,
      offer: offer,
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    ).applicant;
    return accepted.join(
      week: 9,
      currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    );
  }

  test('joined requested salary adds its full monthly cost', () {
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: [hireAt(320000)],
      ),
      1120000,
    );
  });

  test('lower salary adds the accepted salary', () {
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: [hireAt(280000)],
      ),
      1080000,
    );
  });

  test('higher salary adds the accepted salary', () {
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: [hireAt(360000)],
      ),
      1160000,
    );
  });
}
