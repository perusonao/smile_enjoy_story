import 'public_demo_recruitment.dart';
import 'public_demo_state.dart';
import 'public_demo_summer_bonus_payment.dart';

/// Common entry point for Public Demo 0.1's month-end transitions.
///
/// Each method below delegates unchanged to the existing per-month
/// transition already owned by [PublicDemoState] (or, for July, by
/// [PublicDemoSummerBonusPayment]), so the game behavior for April through
/// August is exactly what it was before this facade existed. This class
/// only unifies the call surface across months and wraps every result in a
/// common shape ([PublicDemoMonthlyCloseResult]); it introduces no new
/// rules for cash, salary, bonus, or growth.
///
/// 12MONTH-1 scaffold only: September onward, Revenue, and a merged
/// month-specific request type are deliberately out of scope. See
/// SES_12MONTH-1_Common_Monthly_Close_Result.md for the full design
/// rationale.
class PublicDemoMonthlyClose {
  const PublicDemoMonthlyClose._();

  /// Closes April, delegating to [PublicDemoState.advanceToMay].
  static PublicDemoMonthlyCloseResult closeApril({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int orderedEngineers,
  }) {
    final closedMonth = state.month;
    final next = state.advanceToMay(
      monthlyExpenses: monthlyExpenses,
      orderedEngineers: orderedEngineers,
    );
    return PublicDemoMonthlyCloseResult._(
      state: next,
      status: closedMonth == 4
          ? PublicDemoMonthlyCloseStatus.closed
          : PublicDemoMonthlyCloseStatus.notApplicable,
      cashBefore: state.cash,
      closedMonth: closedMonth,
    );
  }

  /// Closes May, delegating to [PublicDemoState.advanceToJune].
  static PublicDemoMonthlyCloseResult closeMay({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int acceptedHires,
    required int hiredWithOrders,
    List<String> joinedApplicantIds = const [],
  }) {
    final closedMonth = state.month;
    final next = state.advanceToJune(
      monthlyExpenses: monthlyExpenses,
      acceptedHires: acceptedHires,
      hiredWithOrders: hiredWithOrders,
      joinedApplicantIds: joinedApplicantIds,
    );
    return PublicDemoMonthlyCloseResult._(
      state: next,
      status: closedMonth == 5
          ? PublicDemoMonthlyCloseStatus.closed
          : PublicDemoMonthlyCloseStatus.notApplicable,
      cashBefore: state.cash,
      closedMonth: closedMonth,
    );
  }

  /// Closes June, delegating to [PublicDemoState.advanceToJuly].
  static PublicDemoMonthlyCloseResult closeJune({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int assignedInJuly,
  }) {
    final closedMonth = state.month;
    final next = state.advanceToJuly(
      monthlyExpenses: monthlyExpenses,
      assignedInJuly: assignedInJuly,
    );
    return PublicDemoMonthlyCloseResult._(
      state: next,
      status: closedMonth == 6
          ? PublicDemoMonthlyCloseStatus.closed
          : PublicDemoMonthlyCloseStatus.notApplicable,
      cashBefore: state.cash,
      closedMonth: closedMonth,
    );
  }

  /// Closes July, delegating to [PublicDemoSummerBonusPayment.closeJuly]
  /// (which itself is called by [PublicDemoState.advanceToAugust]). Ordinary
  /// monthly expenses and the selected summer bonus still settle atomically.
  static PublicDemoMonthlyCloseResult closeJuly({
    required PublicDemoState state,
    required int monthlyExpenses,
    required Iterable<PublicDemoApplicant> applicants,
  }) {
    final closedMonth = state.month;
    final result = PublicDemoSummerBonusPayment.closeJuly(
      state: state,
      monthlyExpenses: monthlyExpenses,
      applicants: applicants,
    );
    return PublicDemoMonthlyCloseResult._(
      state: result.state,
      status: result.isPaid
          ? PublicDemoMonthlyCloseStatus.closed
          : result.isInsufficientCash
          ? PublicDemoMonthlyCloseStatus.insufficientCash
          : PublicDemoMonthlyCloseStatus.notApplicable,
      cashBefore: state.cash,
      closedMonth: closedMonth,
    );
  }
}

/// Common result shape for every [PublicDemoMonthlyClose] transition.
///
/// [closedMonth] is the month that was targeted for closing, regardless of
/// [status]. [cashBefore]/[cashAfter] mirror the accounting-shaped results
/// already used by [PublicDemoSummerBonusPayment].
class PublicDemoMonthlyCloseResult {
  const PublicDemoMonthlyCloseResult._({
    required this.state,
    required this.status,
    required this.cashBefore,
    required this.closedMonth,
  });

  final PublicDemoState state;
  final PublicDemoMonthlyCloseStatus status;
  final int cashBefore;
  final int closedMonth;

  bool get isClosed => status == PublicDemoMonthlyCloseStatus.closed;
  bool get isInsufficientCash =>
      status == PublicDemoMonthlyCloseStatus.insufficientCash;
  int get cashAfter => state.cash;
  int get cashMovement => cashAfter - cashBefore;
}

enum PublicDemoMonthlyCloseStatus { closed, insufficientCash, notApplicable }
