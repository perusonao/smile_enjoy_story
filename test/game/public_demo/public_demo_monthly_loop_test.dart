import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';

void main() {
  test('Public Demo can advance from April through July', () {
    var state = PublicDemoState.aprilStart();

    // April: one of two engineers wins a May order.
    state = state.advanceToMay(monthlyExpenses: 800000, orderedEngineers: 1);
    expect(state.month, 5);
    expect(state.engineersAssigned, 1);
    expect(state.engineersWaiting, 1);

    // May: one applicant accepts and also wins a June order before joining.
    state = state.advanceToJune(
      monthlyExpenses: 800000,
      acceptedHires: 1,
      hiredWithOrders: 1,
    );
    expect(state.month, 6);
    expect(state.engineerCount, 3);
    expect(state.engineersAssigned, 2);
    expect(state.engineersWaiting, 1);

    // June: only one engineer has a July assignment; the others become waiting.
    state = state.advanceToJuly(monthlyExpenses: 800000, assignedInJuly: 1);
    expect(state.month, 7);
    expect(state.cash, 600000);
    expect(state.engineerCount, 3);
    expect(state.engineersAssigned, 1);
    expect(state.engineersWaiting, 2);
    expect(state.salesRemaining, 4);
  });

  test('salary offer affects cash only after the hire joins in July', () {
    const applicant = PublicDemoApplicant(
      id: 'salary-hire',
      name: 'Salary Hire',
      resumeSummary: 'Java 3年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
      requestedMonthlySalary: 320000,
    );

    PublicDemoState throughJune(int salary) => PublicDemoState.aprilStart()
        .advanceToMay(monthlyExpenses: 800000, orderedEngineers: 1)
        .advanceToJune(
          monthlyExpenses: 800000,
          acceptedHires: 1,
          hiredWithOrders: 1,
        );

    PublicDemoState throughJuly(int salary) {
      final hire = applicant
          .copyWith(acceptedMonthlySalary: salary)
          .join(week: 9);
      return throughJune(salary).advanceToJuly(
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: 800000,
          hires: [hire],
        ),
        assignedInJuly: 1,
      );
    }

    final lowJune = throughJune(280000);
    final standardJune = throughJune(320000);
    final highJune = throughJune(360000);
    expect(lowJune.cash, standardJune.cash);
    expect(highJune.cash, standardJune.cash);

    final lowJuly = throughJuly(280000);
    final standardJuly = throughJuly(320000);
    final highJuly = throughJuly(360000);
    expect(standardJuly.cash, 280000);
    expect(lowJuly.cash, standardJuly.cash + 40000);
    expect(highJuly.cash, standardJuly.cash - 40000);
  });

  test('declined applicants are excluded from the salary finance input', () {
    const applicant = PublicDemoApplicant(
      id: 'declined',
      name: 'Declined',
      resumeSummary: 'Java 3年',
      interviewScore: 70,
      acceptanceScore: 40,
      salesSkillFit: 70,
      requestedMonthlySalary: 320000,
    );
    final declined = applicant.copyWith(
      acceptedMonthlySalary: 280000,
      stage: PublicDemoApplicantStage.offerDeclined,
    );

    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: 800000,
        hires: [declined],
      ),
      800000,
    );
  });
}
