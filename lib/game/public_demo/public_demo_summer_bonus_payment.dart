import 'public_demo_financial_status.dart';
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

  /// Returns an unchanged state when this is not July, has already closed
  /// its bonus decision, or the aggregate's financial state already blocks
  /// any further monthly close ([PublicDemoState.isCloseBlocked]).
  ///
  /// FINANCE-FAILURE-1A+1B §11 (P0): the mandatory monthly close (prior AR
  /// settlement, salary, fixed costs) always commits — there is no
  /// insufficient-cash rollback of this close any more. Affordability
  /// gating is instead scoped to the *optional* summer bonus alone: when
  /// the company cannot afford both `monthlyExpenses` and the selected
  /// bonus together, the bonus paid is 0 (as if
  /// [PublicDemoSummerBonusPlan.none] had been selected) and the mandatory
  /// close still proceeds — including with a negative resulting cash,
  /// which [PublicDemoState.advanceToAugust]'s own financial-status
  /// transition (via [PublicDemoState.copyWith]'s `financialStatus`) turns
  /// into shortage/bankruptcy exactly like any other month.
  static PublicDemoSummerBonusPaymentResult closeJuly({
    required PublicDemoState state,
    required int monthlyExpenses,
    required Iterable<PublicDemoApplicant> applicants,
  }) {
    if (state.month != 7 || state.summerBonusPaid || state.isCloseBlocked) {
      return PublicDemoSummerBonusPaymentResult.notApplicable(
        state: state,
        monthlyExpenses: monthlyExpenses,
      );
    }
    final requestedBonus = calculateSummerBonus(
      plan: state.summerBonusSelection,
      applicants: applicants,
      month: 7,
    );
    final canAffordBonus = state.cash >= monthlyExpenses + requestedBonus;
    final bonusAmount = canAffordBonus ? requestedBonus : 0;
    final nextCash = state.cash - monthlyExpenses - bonusAmount;
    final paid = state
        .copyWith(
          cash: nextCash,
          salesUsed: 0,
          financialStatus: PublicDemoFinancialStatus.afterClose(
            previous: state.financialStatus,
            isMarch: false,
            closingCash: nextCash,
          ),
        )
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
  int get totalOutflow => monthlyExpenses + bonusAmount;
  int get cashAfter => state.cash;
  int get cashMovement => cashAfter - cashBefore;
}

enum PublicDemoSummerBonusPaymentStatus { paid, notApplicable }
