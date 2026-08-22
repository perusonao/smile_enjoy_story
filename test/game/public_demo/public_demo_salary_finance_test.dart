import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';

void main() {
  const applicant = PublicDemoApplicant(
    id: 'test',
    name: 'Test',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
    requestedMonthlySalary: 320000,
  );

  test('joined requested salary adds its full monthly cost', () {
    final hire = applicant
        .copyWith(acceptedMonthlySalary: 320000)
        .join(week: 9);
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: [hire],
      ),
      1120000,
    );
  });

  test('lower salary adds the accepted salary', () {
    final hire = applicant
        .copyWith(acceptedMonthlySalary: 280000)
        .join(week: 9);
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: [hire],
      ),
      1080000,
    );
  });

  test('higher salary adds the accepted salary', () {
    final hire = applicant
        .copyWith(acceptedMonthlySalary: 360000)
        .join(week: 9);
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: [hire],
      ),
      1160000,
    );
  });
}
