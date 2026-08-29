import '../../domain/domain.dart';
import '../models/general_affairs_staff.dart';

/// Immutable legacy payroll facts for one normal-game monthly calculation.
///
/// This deliberately contains only the facts required to reproduce the
/// current rules.  It is not an employment-contract model and is not saved.
class PayrollInput {
  final Iterable<Engineer> engineers;
  final GeneralAffairsStaff? generalAffairsStaff;

  /// During the March founding prologue, an accepted candidate already exists
  /// as an [Engineer] before actually joining.  They enter payroll only when
  /// the first assignment has started in April.
  final bool isPrologueActive;
  final bool hasStartedPrologueAssignment;

  const PayrollInput({
    required this.engineers,
    required this.generalAffairsStaff,
    required this.isPrologueActive,
    required this.hasStartedPrologueAssignment,
  });
}

/// Immutable breakdown of one legacy monthly payroll calculation.
class PayrollResult {
  final int engineerSalaryTotal;
  final int generalAffairsSalaryTotal;

  int get totalSalary => engineerSalaryTotal + generalAffairsSalaryTotal;

  const PayrollResult({
    required this.engineerSalaryTotal,
    required this.generalAffairsSalaryTotal,
  });
}

/// Pure legacy payroll calculation for the normal game.
///
/// This establishes a single location for the existing salary formula without
/// changing FinanceEngine or GameEngine callers in PAYROLL-1A.  Future phases
/// may replace these legacy facts with employment terms, but must preserve the
/// historical settlement records already stored in MonthlyClosing.
class PayrollEngine {
  const PayrollEngine._();

  static PayrollResult calculateMonthly(PayrollInput input) {
    final engineerSalaryTotal = input.engineers
        .where((_) => _isPayrollEligible(input))
        .fold<int>(0, (sum, engineer) => sum + engineer.salary);
    return PayrollResult(
      engineerSalaryTotal: engineerSalaryTotal,
      generalAffairsSalaryTotal: input.generalAffairsStaff?.salary ?? 0,
    );
  }

  /// Legacy rule: every Engineer receives their full stored monthly salary,
  /// irrespective of assignment/sales status.  The sole exception is the
  /// materialized-but-not-yet-joined Engineer in the active March prologue.
  static bool _isPayrollEligible(PayrollInput input) {
    if (!input.isPrologueActive) return true;
    return input.hasStartedPrologueAssignment;
  }
}
