import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_raise.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';

import 'test_support/public_demo_offer_test_helpers.dart';

void main() {
  const applicant = PublicDemoApplicant(
    id: 'hire-01',
    name: 'Hire',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
    requestedMonthlySalary: 320000,
  );

  test(
    'founding payroll master explicitly preserves the 800,000 yen baseline',
    () {
      expect(
        PublicDemoSalary.currentMonthlySalaryFor('eng-01', applicants: []),
        300000,
      );
      expect(
        PublicDemoSalary.currentMonthlySalaryFor('eng-02', applicants: []),
        250000,
      );
      expect(PublicDemoSalary.adminMonthlySalary, 200000);
      expect(PublicDemoSalary.initialTotalMonthlySalary, 750000);
      expect(PublicDemoSalary.initialEngineerMonthlySalaryTotal, 550000);
      expect(PublicDemoSalary.otherMonthlyFixedCost, 50000);
      expect(PublicDemoSalary.baselineMonthlyExpenses, 800000);
      expect(
        PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: [],
        ),
        800000,
      );
    },
  );

  test(
    'only joined hired engineers have a salary and enter bonus eligibility',
    () {
      expect(
        PublicDemoSalary.currentMonthlySalaryFor(
          applicant.id,
          applicants: [applicant],
        ),
        isNull,
      );
      expect(
        PublicDemoSalary.bonusEligibleMonthlySalaryTotal(
          applicants: [applicant],
        ),
        550000,
      );

      final joined = acceptTestOffer(applicant, offeredMonthlySalary: 320000)
          .join(
            week: 9,
            currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
          );
      expect(
        PublicDemoSalary.currentMonthlySalaryFor(
          joined.id,
          applicants: [joined],
        ),
        320000,
      );
      expect(
        PublicDemoSalary.bonusEligibleMonthlySalaryTotal(applicants: [joined]),
        870000,
      );
    },
  );

  test(
    'a raise is visible through the same lookup from its effective month',
    () {
      final raised = acceptTestOffer(applicant, offeredMonthlySalary: 320000)
          .join(
            week: 9,
            currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
          )
          .decideRaise(
            decisionMonth: 6,
            week: 24,
            decision: PublicDemoRaiseDecision.requestedRaise,
          );
      expect(
        PublicDemoSalary.currentMonthlySalaryFor(
          raised.id,
          applicants: [raised],
          month: 6,
        ),
        320000,
      );
      expect(
        PublicDemoSalary.currentMonthlySalaryFor(
          raised.id,
          applicants: [raised],
          month: 7,
        ),
        380000,
      );
      expect(
        PublicDemoSalary.bonusEligibleMonthlySalaryTotal(
          applicants: [raised],
          month: 7,
        ),
        930000,
      );
    },
  );
}
