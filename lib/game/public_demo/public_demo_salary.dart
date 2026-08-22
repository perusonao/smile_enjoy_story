import 'public_demo_raise.dart';
import 'public_demo_recruitment.dart';

/// Immutable payroll master data for the Public Demo's founding team.
///
/// Hired engineers intentionally remain backed by their accepted/raised
/// applicant salary, which is already the source of truth for that workflow.
class PublicDemoSalary {
  const PublicDemoSalary._();

  static const int satoMonthlySalary = 300000;
  static const int suzukiMonthlySalary = 250000;
  static const int adminMonthlySalary = 200000;
  static const int otherMonthlyFixedCost = 50000;

  static const Map<String, int> _initialEngineerMonthlySalaries = {
    'eng-01': satoMonthlySalary,
    'eng-02': suzukiMonthlySalary,
  };

  static int get initialEngineerMonthlySalaryTotal =>
      _initialEngineerMonthlySalaries.values.fold(
        0,
        (sum, salary) => sum + salary,
      );

  static int get initialTotalMonthlySalary =>
      initialEngineerMonthlySalaryTotal + adminMonthlySalary;

  static int get baselineMonthlyExpenses =>
      initialTotalMonthlySalary + otherMonthlyFixedCost;

  /// Current salary for an initial or joined hired engineer, or null when the
  /// ID does not identify an employee currently on payroll.
  static int? currentMonthlySalaryFor(
    String employeeId, {
    required Iterable<PublicDemoApplicant> applicants,
    int? month,
  }) {
    final initialSalary = _initialEngineerMonthlySalaries[employeeId];
    if (initialSalary != null) return initialSalary;
    for (final applicant in applicants) {
      if (applicant.id == employeeId && applicant.hasJoined) {
        return month == null
            ? applicant.acceptedMonthlySalary
            : applicant.salaryForMonth(month);
      }
    }
    return null;
  }

  /// Salary total used by the future engineer-only bonus calculation.
  /// General affairs is deliberately excluded.
  static int bonusEligibleMonthlySalaryTotal({
    required Iterable<PublicDemoApplicant> applicants,
    int? month,
  }) =>
      initialEngineerMonthlySalaryTotal +
      applicants.fold<int>(
        0,
        (sum, applicant) =>
            sum +
            (currentMonthlySalaryFor(
                  applicant.id,
                  applicants: [applicant],
                  month: month,
                ) ??
                0),
      );
}
