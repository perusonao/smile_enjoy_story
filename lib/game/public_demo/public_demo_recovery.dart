import 'public_demo_sales.dart';
import 'public_demo_state.dart';
import 'public_demo_workflow_state.dart';

/// Recovery Loop Phase 1 (RECOVERY-LOOP-1): late-year re-entry into the
/// EXISTING Public Demo sales flow for an engineer who is economically
/// waiting between internal month 7 (July) and internal month 14
/// (February) inclusive.
///
/// Recovery introduces no new sales engine and no new sales-pipeline state
/// of its own: an engineer becomes Recovery-eligible purely by virtue of
/// already having reached [PublicDemoSalesStage.ordered] with a genuine
/// client-interview pass ([PublicDemoEngineerSales.hasGenuineInterviewRecord])
/// through the SAME `startSkillSheetReview` → `beginSelling` →
/// `introduceProject` → partner/client interview → `recordOrder` chain
/// every other engineer already uses (see [PublicDemoWorkflowState]'s
/// "Engineer sales-pipeline transitions" section) — none of those methods
/// are month-gated, so a waiting engineer can walk this same chain again in
/// July or any later month — while still being counted economically
/// waiting (absent from
/// [PublicDemoWorkflowState.assignedEngineerIds] for the current month).
/// [PublicDemoAggregate.recoverAssignment] is the single production caller
/// that turns a Recovery-eligible engineer into an actual assignment.
class PublicDemoRecoveryEligibility {
  const PublicDemoRecoveryEligibility._();

  /// First internal month (July) Recovery may act in.
  static const int firstEligibleMonth = 7;

  /// Last internal month (February) Recovery may act in. March (internal
  /// month 15) is deliberately excluded — Public Demo 0.1's fiscal year
  /// ends there, and [PublicDemoState.completeFiscalYear] never advances
  /// past it.
  static const int lastEligibleMonth = 14;

  static bool isMonthEligible(int month) =>
      month >= firstEligibleMonth && month <= lastEligibleMonth;

  /// Whether [engineerId] may be Recovery-assigned right now. Every check
  /// here mirrors an existing, already-authoritative fact — this class
  /// mints no new fact of its own:
  ///
  /// - [isMonthEligible] and not [PublicDemoState.isCloseBlocked] (the same
  ///   terminal/fiscal-completion guard every other monthly command
  ///   already uses)
  /// - the engineer exists and has genuinely reached
  ///   [PublicDemoSalesStage.ordered] — checked via
  ///   [PublicDemoEngineerSales.hasGenuineInterviewRecord], never `stage`/
  ///   `lastInterviewScore` alone (mirrors
  ///   [PublicDemoWorkflowState.assignOrderedForMay]'s own defense in
  ///   depth)
  /// - not currently selected for training this month
  ///   ([PublicDemoState.trainingSelections])
  /// - runtime-ready for field sales
  ///   ([PublicDemoEngineerRuntime.isReadyForFieldSales])
  /// - not already counted assigned for the current month
  ///   ([PublicDemoWorkflowState.assignedEngineerIds]) — duplicate-
  ///   assignment protection at the eligibility layer itself, ahead of the
  ///   assignment-roster upsert's own defense in depth.
  static bool isEligible({
    required PublicDemoState state,
    required PublicDemoWorkflowState workflow,
    required String engineerId,
  }) {
    if (!isMonthEligible(state.month) || state.isCloseBlocked) return false;
    final engineer = workflow.engineers
        .where((candidate) => candidate.id == engineerId)
        .firstOrNull;
    if (engineer == null ||
        engineer.stage != PublicDemoSalesStage.ordered ||
        !engineer.hasGenuineInterviewRecord) {
      return false;
    }
    if (state.trainingSelections.containsKey(engineerId)) return false;
    if (!(state.runtimeForOrNull(engineerId)?.isReadyForFieldSales ?? false)) {
      return false;
    }
    if (workflow.assignedEngineerIds(month: state.month).contains(engineerId)) {
      return false;
    }
    return true;
  }
}
