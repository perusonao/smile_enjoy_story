import 'public_demo_cash_status_presentation.dart';
import 'public_demo_sales.dart';
import 'public_demo_state.dart';
import 'public_demo_workflow_state.dart';

/// Pure selection of at most one advice candidate for Issue #148 Phase 1B.2
/// ("ひよりの助言候補"), for a shortage cash status only.
///
/// This never predicts future recruitment, sales, or interview success —
/// it only reads already-confirmed [PublicDemoWorkflowState] sales-pipeline
/// stages (see [PublicDemoSalesStage]) and already-confirmed
/// [PublicDemoState.engineerRuntimes]/[PublicDemoState.trainingSelections]
/// facts, and only ever recommends an action already reachable through the
/// existing domain API:
///
///  * [PublicDemoAdviceActionType.startInternalTraining] — an existing,
///    already-selectable next step (see
///    `PublicDemoInternalTrainingTransaction`) for a waiting engineer whose
///    already-measured runtime capability
///    ([PublicDemoEngineerRuntime.isReadyForFieldSales]) has not yet
///    reached the field-sales threshold and has not already been given a
///    training selection this month.
///  * [PublicDemoAdviceActionType.confirmSkillSheet] — the existing
///    [PublicDemoWorkflowState.startSkillSheetReview] transition, for any
///    other waiting engineer (already field-sales ready, or already has a
///    training selection recorded).
///  * [PublicDemoAdviceActionType.beginSelling] — the existing
///    [PublicDemoWorkflowState.beginSelling] transition, for an engineer
///    who has completed SkillSheet review
///    ([PublicDemoSalesStage.skillSheet]) but has never yet been put up
///    for sale.
///
/// Deliberately excluded: any engineer currently selling, in interview
/// screening, or already ordered (assigned to a project) — never re-offered
/// as a "start selling again" candidate — and any engineer whose most
/// recent sales attempt already failed (`partnerInterviewFailed`/
/// `clientInterviewFailed`): restarting that engineer's sales attempt is a
/// legitimate existing transition, but recommending it here would read as
/// betting on a retry succeeding, which this Phase does not do. Those
/// engineers, like every other non-waiting/non-skillSheet stage, simply
/// contribute no candidate — [select] returns `null` when nobody currently
/// waiting or skillSheet-ready exists.
///
/// [select] never mutates [workflow] or [state]; candidate selection over
/// [workflow.engineers] is in that list's own order, so the same inputs
/// always produce the same candidate.
class PublicDemoCashAdviceSelector {
  const PublicDemoCashAdviceSelector._();

  static PublicDemoCashAdviceCandidate? select({
    required PublicDemoCashStatusPresentation cashStatus,
    required PublicDemoWorkflowState workflow,
    required PublicDemoState state,
  }) {
    if (cashStatus.status != PublicDemoCashStatus.shortage) return null;
    final shortageMonth = cashStatus.shortageMonth;
    if (shortageMonth == null) return null;

    for (final engineer in workflow.engineers) {
      if (engineer.stage != PublicDemoSalesStage.waiting) continue;
      final runtime = state.engineerRuntimes
          .where((candidate) => candidate.engineerId == engineer.id)
          .firstOrNull;
      final needsTraining =
          runtime != null &&
          !runtime.isReadyForFieldSales &&
          !state.trainingSelections.containsKey(engineer.id);
      return PublicDemoCashAdviceCandidate._(
        employeeId: engineer.id,
        actionType: needsTraining
            ? PublicDemoAdviceActionType.startInternalTraining
            : PublicDemoAdviceActionType.confirmSkillSheet,
        shortageMonth: shortageMonth,
        reason: needsTraining
            ? PublicDemoAdviceReason.waitingBelowFieldSalesReadiness
            : PublicDemoAdviceReason.waitingReadyForSkillSheet,
      );
    }

    for (final engineer in workflow.engineers) {
      if (engineer.stage != PublicDemoSalesStage.skillSheet) continue;
      return PublicDemoCashAdviceCandidate._(
        employeeId: engineer.id,
        actionType: PublicDemoAdviceActionType.beginSelling,
        shortageMonth: shortageMonth,
        reason: PublicDemoAdviceReason.skillSheetReadyToBeginSelling,
      );
    }

    return null;
  }
}

/// One advice candidate: the target employee, the existing action type
/// recommended for them, the shortage month it responds to, and a reason
/// code a later UI can use to phrase this without recomputing eligibility
/// itself.
class PublicDemoCashAdviceCandidate {
  const PublicDemoCashAdviceCandidate._({
    required this.employeeId,
    required this.actionType,
    required this.shortageMonth,
    required this.reason,
  });

  /// The [PublicDemoEngineerSales.id] this advice targets.
  final String employeeId;

  final PublicDemoAdviceActionType actionType;

  /// Held exactly as reported by the [PublicDemoCashStatusPresentation]
  /// this candidate was selected for — never recomputed.
  final int shortageMonth;

  final PublicDemoAdviceReason reason;
}

/// Recommended action types [PublicDemoCashAdviceSelector.select] may
/// return. Every value maps to an action already reachable through the
/// existing domain API — no new screen or action is introduced here.
enum PublicDemoAdviceActionType {
  /// Existing paid internal-training selection
  /// (`PublicDemoInternalTrainingTransaction`).
  startInternalTraining,

  /// [PublicDemoWorkflowState.startSkillSheetReview].
  confirmSkillSheet,

  /// [PublicDemoWorkflowState.beginSelling].
  beginSelling,
}

/// Why [PublicDemoCashAdviceSelector.select] chose a given candidate —
/// lets a later UI phrase the advice without re-deriving eligibility.
enum PublicDemoAdviceReason {
  /// A waiting engineer whose measured runtime capability has not yet
  /// reached [PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement].
  waitingBelowFieldSalesReadiness,

  /// A waiting engineer already field-sales ready (or already has a
  /// training selection recorded) — SkillSheet review is the next existing
  /// step.
  waitingReadyForSkillSheet,

  /// An engineer who has completed SkillSheet review and has never yet
  /// been put up for sale.
  skillSheetReadyToBeginSelling,
}
