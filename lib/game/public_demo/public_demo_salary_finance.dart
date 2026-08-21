import 'public_demo_recruitment.dart';

/// Keeps the existing Public Demo balance neutral when the candidate is paid
/// their requested salary, while making lower/higher offers affect cash once
/// the hire actually joins.
class PublicDemoSalaryFinance {
  const PublicDemoSalaryFinance._();

  static int monthlyExpenseAdjustment(Iterable<PublicDemoApplicant> hires) {
    var adjustment = 0;
    for (final hire in hires) {
      if (hire.stage == PublicDemoApplicantStage.offerDeclined) continue;
      final salary = hire.acceptedMonthlySalary;
      if (salary == null) continue;
      adjustment += salary - hire.requestedMonthlySalary;
    }
    return adjustment;
  }

  static int monthlyExpenses({
    required int baselineExpenses,
    required Iterable<PublicDemoApplicant> hires,
  }) =>
      baselineExpenses + monthlyExpenseAdjustment(hires);
}
