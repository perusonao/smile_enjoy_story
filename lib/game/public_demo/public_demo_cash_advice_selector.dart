import 'public_demo_cash_status_presentation.dart';
import 'public_demo_internal_training_transaction.dart';
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
///  * [PublicDemoAdviceActionType.confirmSkillSheet] — the existing
///    [PublicDemoWorkflowState.startSkillSheetReview] transition, for a
///    waiting engineer whose already-measured runtime capability
///    ([PublicDemoEngineerRuntime.isReadyForFieldSales]) has already
///    reached the field-sales threshold.
///  * [PublicDemoAdviceActionType.startInternalTraining] — an existing,
///    already-selectable next step (see
///    `PublicDemoInternalTrainingTransaction`) for a waiting engineer whose
///    capability has not yet reached that threshold, has not already been
///    given a training selection this month, and for whom the transaction's
///    own financial preconditions ([PublicDemoState.isFinanciallyRestricted]
///    and an affordable [PublicDemoInternalTrainingTransaction.cost]) are
///    both currently satisfied — so this is never recommended when the
///    domain would reject it outright.
///  * [PublicDemoAdviceActionType.beginSelling] — the existing
///    [PublicDemoWorkflowState.beginSelling] transition, for an engineer
///    who has completed SkillSheet review
///    ([PublicDemoSalesStage.skillSheet]) but has never yet been put up
///    for sale.
///
/// A waiting engineer who is not yet field-sales ready AND for whom
/// training is currently unavailable (already selected this month —
/// growth from it has not been applied yet, so capability has not actually
/// risen — or currently unaffordable/financially restricted) has no
/// currently valid direct action at all: [select] never falls back to
/// recommending SkillSheet review for such an engineer (that button does
/// not even render for a not-yet-ready engineer in the existing employee
/// screen), it simply moves on to the next waiting engineer.
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
/// waiting-with-a-valid-action or skillSheet-ready exists.
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
      final ready = runtime != null && runtime.isReadyForFieldSales;
      if (ready) {
        return PublicDemoCashAdviceCandidate._(
          employeeId: engineer.id,
          actionType: PublicDemoAdviceActionType.confirmSkillSheet,
          shortageMonth: shortageMonth,
          reason: PublicDemoAdviceReason.waitingReadyForSkillSheet,
        );
      }

      // Not yet field-sales ready: the only other currently valid action is
      // starting training, and only when the domain would actually accept
      // it — mirroring PublicDemoInternalTrainingTransaction.execute's own
      // preconditions (already-selected, financially-restricted,
      // insufficient cash) rather than recommending an action it would
      // reject. A training selection already recorded this month does not
      // make this engineer ready either — growth from it is applied at
      // monthly close, not immediately — so this never falls back to
      // confirmSkillSheet: it simply tries the next waiting engineer.
      final alreadyTraining = state.trainingSelections.containsKey(engineer.id);
      final canAffordTraining =
          !state.isFinanciallyRestricted &&
          state.cash >= PublicDemoInternalTrainingTransaction.cost;
      if (!alreadyTraining && canAffordTraining) {
        return PublicDemoCashAdviceCandidate._(
          employeeId: engineer.id,
          actionType: PublicDemoAdviceActionType.startInternalTraining,
          shortageMonth: shortageMonth,
          reason: PublicDemoAdviceReason.waitingBelowFieldSalesReadiness,
        );
      }
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

  /// A waiting engineer already field-sales ready — SkillSheet review is
  /// the next existing step.
  waitingReadyForSkillSheet,

  /// An engineer who has completed SkillSheet review and has never yet
  /// been put up for sale.
  skillSheetReadyToBeginSelling,
}
