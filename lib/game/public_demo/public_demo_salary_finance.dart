import 'public_demo_recruitment.dart';
import 'public_demo_raise.dart';

/// Keeps the existing Public Demo balance neutral when the candidate is paid
/// their requested salary, while making lower/higher offers affect cash once
/// the hire actually joins.
class PublicDemoSalaryFinance {
  const PublicDemoSalaryFinance._();

  static int monthlyExpenseAdjustment(
    Iterable<PublicDemoApplicant> hires, {
    int? month,
  }) {
    var adjustment = 0;
    for (final hire in hires) {
      if (hire.stage == PublicDemoApplicantStage.offerDeclined) continue;
      final int? salary = month == null
          ? hire.acceptedMonthlySalary
          : hire.salaryForMonth(month);
      if (salary == null) continue;
      adjustment += salary - hire.requestedMonthlySalary;
    }
    return adjustment;
  }

  static int monthlyExpenses({
    required int baselineExpenses,
    required Iterable<PublicDemoApplicant> hires,
    int? month,
  }) => baselineExpenses + monthlyExpenseAdjustment(hires, month: month);
}
