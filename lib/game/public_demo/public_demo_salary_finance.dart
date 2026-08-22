import 'public_demo_recruitment.dart';
import 'public_demo_salary.dart';

/// Calculates payroll additions without hiding the founding team's baseline.
class PublicDemoSalaryFinance {
  const PublicDemoSalaryFinance._();

  static int monthlyExpenseAdjustment(
    Iterable<PublicDemoApplicant> hires, {
    int? month,
  }) {
    var adjustment = 0;
    for (final hire in hires) {
      final salary = PublicDemoSalary.currentMonthlySalaryFor(
        hire.id,
        applicants: [hire],
        month: month,
      );
      if (salary == null) continue;
      adjustment += salary;
    }
    return adjustment;
  }

  static int monthlyExpenses({
    required int baselineExpenses,
    required Iterable<PublicDemoApplicant> hires,
    int? month,
  }) => baselineExpenses + monthlyExpenseAdjustment(hires, month: month);
}
