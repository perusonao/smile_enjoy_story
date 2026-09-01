import '../../../game/public_demo/public_demo_financial_status.dart';
import '../../../game/public_demo/public_demo_month_label.dart';
import '../../../game/public_demo/public_demo_state.dart';
import '../../../game/public_demo/public_demo_summer_bonus_plan.dart';

/// Read-only presentation projection for the Public Demo Year-End result.
///
/// Every value is copied from a fact the current state already owns. This
/// deliberately carries no annual revenue, profit, expense total, score, or
/// milestone timing because Public Demo 0.1 does not retain the history needed
/// to state those values truthfully.
class PublicDemoYearEndDisplayData {
  const PublicDemoYearEndDisplayData({
    required this.outcome,
    required this.story,
    required this.cash,
    required this.engineerCount,
    required this.adminCount,
    required this.assignedCount,
    required this.waitingCount,
    required this.hiredCount,
    required this.pendingReceivables,
    required this.summerBonusDecision,
    this.latestMonthLabel,
    this.latestCashReceived,
    this.latestOutflow,
    this.latestCashMovement,
    this.latestClosingCash,
  });

  factory PublicDemoYearEndDisplayData.fromState(PublicDemoState state) {
    assert(state.fiscalYearCompleted || state.isFinanciallyTerminal);

    final outcome = switch (state.financialStatus) {
      PublicDemoFinancialStatus.bankruptcy =>
        PublicDemoYearEndOutcome.bankruptcy,
      PublicDemoFinancialStatus.marchCashShortageFailure =>
        PublicDemoYearEndOutcome.marchCashShortageFailure,
      _ => PublicDemoYearEndOutcome.completed,
    };
    final latest = state.latestMonthlyCashFlow;

    return PublicDemoYearEndDisplayData(
      outcome: outcome,
      story: _storyFor(state, outcome),
      cash: state.cash,
      engineerCount: state.engineerCount,
      adminCount: state.adminCount,
      assignedCount: state.engineersAssigned,
      waitingCount: state.engineersWaiting,
      hiredCount: state.joinedApplicantIds.length,
      pendingReceivables: state.pendingRevenue,
      summerBonusDecision: _summerBonusLabel(state),
      latestMonthLabel: latest == null
          ? null
          : publicDemoMonthLabel(latest.month),
      latestCashReceived: latest?.cashReceived,
      latestOutflow: latest?.totalOutflow,
      latestCashMovement: latest?.netCashMovement,
      latestClosingCash: latest?.closingCash,
    );
  }

  final PublicDemoYearEndOutcome outcome;
  final String story;
  final int cash;
  final int engineerCount;
  final int adminCount;
  final int assignedCount;
  final int waitingCount;
  final int hiredCount;
  final int pendingReceivables;
  final String summerBonusDecision;
  final String? latestMonthLabel;
  final int? latestCashReceived;
  final int? latestOutflow;
  final int? latestCashMovement;
  final int? latestClosingCash;

  int get employeeCount => engineerCount + adminCount;

  static String _storyFor(
    PublicDemoState state,
    PublicDemoYearEndOutcome outcome,
  ) => switch (outcome) {
    PublicDemoYearEndOutcome.bankruptcy =>
      state.month == 15
          ? '資金不足から回復できず、第1期は倒産で終了しました。'
          : '資金不足から回復できず、会社は倒産しました。',
    PublicDemoYearEndOutcome.marchCashShortageFailure =>
      '3月決算後の現預金がマイナスとなり、第1期は資金不足で終了しました。',
    PublicDemoYearEndOutcome.completed =>
      state.engineersWaiting > 0
          ? '待機社員を抱えながらも、第1期を完走しました。'
          : state.engineerCount > 0 &&
                state.engineersAssigned == state.engineerCount
          ? '全技術社員が案件に参画した状態で、第1期を終えました。'
          : '1年間の会社経営を終え、第1期を完走しました。',
  };

  static String _summerBonusLabel(PublicDemoState state) {
    if (!state.summerBonusDecisionConfirmed) return '未決定';
    final plan = switch (state.summerBonusSelection) {
      PublicDemoSummerBonusPlan.none => '支給なし',
      PublicDemoSummerBonusPlan.half => '0.5か月',
      PublicDemoSummerBonusPlan.one => '1か月',
    };
    return state.summerBonusPaid ? '$plan（支給済み）' : plan;
  }
}

enum PublicDemoYearEndOutcome {
  completed,
  bankruptcy,
  marchCashShortageFailure;

  bool get isSuccess => this == PublicDemoYearEndOutcome.completed;
}
