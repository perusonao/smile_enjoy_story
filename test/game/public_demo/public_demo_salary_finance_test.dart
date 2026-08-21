import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';

void main() {
  const baselineExpenses = 800000;
  const applicant = PublicDemoApplicant(
    id: 'test',
    name: 'Test',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
    requestedMonthlySalary: 320000,
  );

  test('requested salary preserves the existing Public Demo balance', () {
    final hire = applicant.copyWith(acceptedMonthlySalary: 320000);
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: baselineExpenses,
        hires: [hire],
      ),
      baselineExpenses,
    );
  });

  test('lower salary reduces monthly expenses by the salary difference', () {
    final hire = applicant.copyWith(acceptedMonthlySalary: 280000);
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: baselineExpenses,
        hires: [hire],
      ),
      760000,
    );
  });

  test('higher salary increases monthly expenses by the salary difference', () {
    final hire = applicant.copyWith(acceptedMonthlySalary: 360000);
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: baselineExpenses,
        hires: [hire],
      ),
      840000,
    );
  });
}
