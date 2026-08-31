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

  /// Domain-owned preview used by both the July close and its decision UI.
  ///
  /// [state] is the same state the payment transaction will settle. The
  /// common monthly-close facade passes the post-AR state, so pending revenue
  /// is included exactly once before this calculation. A zero bonus is always
  /// an eligible management decision, even when mandatory monthly expenses
  /// make the projected cash negative. Paid plans retain the existing rule:
  /// they are eligible only when the complete close can fund them without
  /// producing a negative balance.
  static PublicDemoSummerBonusSettlementPreview preview({
    required PublicDemoState state,
    required int monthlyExpenses,
    required Iterable<PublicDemoApplicant> applicants,
    required PublicDemoSummerBonusPlan plan,
  }) {
    final bonusAmount = calculateSummerBonus(
      plan: plan,
      applicants: applicants,
      month: 7,
    );
    final projectedCash = state.cash - monthlyExpenses - bonusAmount;
    final isApplicable =
        state.month == 7 && !state.summerBonusPaid && !state.isCloseBlocked;
    final eligibility = !isApplicable
        ? PublicDemoSummerBonusEligibility.notApplicable
        : plan == PublicDemoSummerBonusPlan.none || projectedCash >= 0
        ? PublicDemoSummerBonusEligibility.eligible
        : PublicDemoSummerBonusEligibility.insufficientCash;
    return PublicDemoSummerBonusSettlementPreview(
      plan: plan,
      availableCash: state.cash,
      monthlyExpenses: monthlyExpenses,
      bonusAmount: bonusAmount,
      projectedCash: projectedCash,
      eligibility: eligibility,
    );
  }

  /// Returns an unchanged state when this is not July, has already closed
  /// its bonus decision, or the aggregate's financial state already blocks
  /// any further monthly close ([PublicDemoState.isCloseBlocked]).
  ///
  /// A confirmed zero-bonus decision always lets the mandatory close commit,
  /// including when monthly expenses produce negative cash. An unaffordable
  /// paid plan is rejected without changing state; the player must explicitly
  /// choose an eligible plan rather than having a paid decision silently
  /// rewritten to zero during settlement.
  static PublicDemoSummerBonusPaymentResult closeJuly({
    required PublicDemoState state,
    required int monthlyExpenses,
    required Iterable<PublicDemoApplicant> applicants,
  }) {
    final settlement = preview(
      state: state,
      monthlyExpenses: monthlyExpenses,
      applicants: applicants,
      plan: state.summerBonusSelection,
    );
    if (settlement.eligibility ==
        PublicDemoSummerBonusEligibility.notApplicable) {
      return PublicDemoSummerBonusPaymentResult.notApplicable(
        state: state,
        monthlyExpenses: monthlyExpenses,
      );
    }
    if (!settlement.isEligible) {
      return PublicDemoSummerBonusPaymentResult.rejected(
        state: state,
        monthlyExpenses: monthlyExpenses,
        bonusAmount: settlement.bonusAmount,
      );
    }
    final bonusAmount = settlement.bonusAmount;
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

  factory PublicDemoSummerBonusPaymentResult.rejected({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int bonusAmount,
  }) => PublicDemoSummerBonusPaymentResult._(
    state: state,
    cashBefore: state.cash,
    monthlyExpenses: monthlyExpenses,
    bonusAmount: bonusAmount,
    status: PublicDemoSummerBonusPaymentStatus.rejected,
  );

  final PublicDemoState state;
  final int cashBefore;
  final int monthlyExpenses;
  final int bonusAmount;
  final PublicDemoSummerBonusPaymentStatus status;

  bool get isPaid => status == PublicDemoSummerBonusPaymentStatus.paid;
  bool get isRejected =>
      status == PublicDemoSummerBonusPaymentStatus.rejected;
  int get totalOutflow => monthlyExpenses + bonusAmount;
  int get cashAfter => state.cash;
  int get cashMovement => cashAfter - cashBefore;
}

enum PublicDemoSummerBonusPaymentStatus { paid, rejected, notApplicable }

/// A pure settlement projection. It contains every value the July decision
/// UI needs, while keeping the eligibility rule in the payment domain.
class PublicDemoSummerBonusSettlementPreview {
  const PublicDemoSummerBonusSettlementPreview({
    required this.plan,
    required this.availableCash,
    required this.monthlyExpenses,
    required this.bonusAmount,
    required this.projectedCash,
    required this.eligibility,
  });

  final PublicDemoSummerBonusPlan plan;
  final int availableCash;
  final int monthlyExpenses;
  final int bonusAmount;
  final int projectedCash;
  final PublicDemoSummerBonusEligibility eligibility;

  bool get isEligible => eligibility == PublicDemoSummerBonusEligibility.eligible;
  bool get isApplicable =>
      eligibility != PublicDemoSummerBonusEligibility.notApplicable;
}

enum PublicDemoSummerBonusEligibility {
  eligible,
  insufficientCash,
  notApplicable,
}
