import 'public_demo_recruitment.dart';
import 'public_demo_salary.dart';
import 'public_demo_state.dart';
import 'public_demo_summer_bonus_plan.dart';

/// Pure July-only summer-bonus calculation and month-end payment transaction.
class PublicDemoSummerBonusPayment {
  const PublicDemoSummerBonusPayment._();

  static int calculateSummerBonus({
    required PublicDemoSummerBonusPlan plan,
    required Iterable<PublicDemoApplicant> applicants,
    required int month,
  }) =>
      (PublicDemoSalary.bonusEligibleMonthlySalaryTotal(
                applicants: applicants,
                month: month,
              ) *
              plan.months)
          .round();

  /// Returns an unchanged state when this is not July, has already closed its
  /// bonus decision, or cannot pay both ordinary monthly costs and the bonus.
  static PublicDemoSummerBonusPaymentResult closeJuly({
    required PublicDemoState state,
    required int monthlyExpenses,
    required Iterable<PublicDemoApplicant> applicants,
  }) {
    if (state.month != 7 || state.summerBonusPaid) {
      return PublicDemoSummerBonusPaymentResult.notApplicable(
        state: state,
        monthlyExpenses: monthlyExpenses,
      );
    }
    final bonusAmount = calculateSummerBonus(
      plan: state.summerBonusSelection,
      applicants: applicants,
      month: 7,
    );
    final totalOutflow = monthlyExpenses + bonusAmount;
    if (state.cash < totalOutflow) {
      return PublicDemoSummerBonusPaymentResult.insufficientCash(
        state: state,
        monthlyExpenses: monthlyExpenses,
        bonusAmount: bonusAmount,
      );
    }
    final nextCash = state.cash - totalOutflow;
    final paid = state
        .copyWith(cash: nextCash, salesUsed: 0)
        .markSummerBonusPaid(month: 7, amount: bonusAmount)
        .copyWith(
          month: 8,
          monthOpeningCash: nextCash,
          monthTrainingSpent: 0,
          monthRecruitmentSpent: 0,
        );
    return PublicDemoSummerBonusPaymentResult.paid(
      state: paid,
      cashBefore: state.cash,
      monthlyExpenses: monthlyExpenses,
      bonusAmount: bonusAmount,
    );
  }
}

/// Accounting-shaped result for the July close.  BONUS-3 can use
/// [bonusAmount] directly without recomputing payroll or cash movement.
class PublicDemoSummerBonusPaymentResult {
  const PublicDemoSummerBonusPaymentResult._({
    required this.state,
    required this.cashBefore,
    required this.monthlyExpenses,
    required this.bonusAmount,
    required this.status,
  });

  factory PublicDemoSummerBonusPaymentResult.paid({
    required PublicDemoState state,
    required int cashBefore,
    required int monthlyExpenses,
    required int bonusAmount,
  }) => PublicDemoSummerBonusPaymentResult._(
    state: state,
    cashBefore: cashBefore,
    monthlyExpenses: monthlyExpenses,
    bonusAmount: bonusAmount,
    status: PublicDemoSummerBonusPaymentStatus.paid,
  );

  factory PublicDemoSummerBonusPaymentResult.insufficientCash({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int bonusAmount,
  }) => PublicDemoSummerBonusPaymentResult._(
    state: state,
    cashBefore: state.cash,
    monthlyExpenses: monthlyExpenses,
    bonusAmount: bonusAmount,
    status: PublicDemoSummerBonusPaymentStatus.insufficientCash,
  );

  factory PublicDemoSummerBonusPaymentResult.notApplicable({
    required PublicDemoState state,
    required int monthlyExpenses,
  }) => PublicDemoSummerBonusPaymentResult._(
    state: state,
    cashBefore: state.cash,
    monthlyExpenses: monthlyExpenses,
    bonusAmount: 0,
    status: PublicDemoSummerBonusPaymentStatus.notApplicable,
  );

  final PublicDemoState state;
  final int cashBefore;
  final int monthlyExpenses;
  final int bonusAmount;
  final PublicDemoSummerBonusPaymentStatus status;

  bool get isPaid => status == PublicDemoSummerBonusPaymentStatus.paid;
  bool get isInsufficientCash =>
      status == PublicDemoSummerBonusPaymentStatus.insufficientCash;
  int get totalOutflow => monthlyExpenses + bonusAmount;
  int get cashAfter => state.cash;
  int get cashMovement => cashAfter - cashBefore;
}

enum PublicDemoSummerBonusPaymentStatus {
  paid,
  insufficientCash,
  notApplicable,
}
