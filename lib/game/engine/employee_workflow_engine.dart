import '../../domain/domain.dart';
import '../models/models.dart';

/// What an employee is *currently doing*, derived once from [GameState] and
/// used everywhere a screen would otherwise have invented its own label
/// (Playable 0.4C.3 §12-17). Home, the employee list, the employee detail
/// header, and Recommendation all render the same word for the same
/// employee at the same moment — that consistency is the entire point.
///
/// Ordered by display priority: a state earlier in this list always wins
/// over one later in it when both would technically apply (§15).
enum EmployeeWorkflowState {
  assigned,
  finalOfferPending,
  assignmentScheduled,
  clientInterviewActionRequired,
  waitingSelectionResult,
  interviewRequestPending,
  selling,
  waiting,
}

/// Derives [EmployeeWorkflowState] for one employee — pure, no Flutter, no
/// randomness. This is the *only* place that logic should live (§14, §48).
class EmployeeWorkflowEngine {
  const EmployeeWorkflowEngine._();

  static EmployeeWorkflowState forEngineer(GameState state, String engineerId) {
    final engineer = state.engineerById(engineerId);

    if (state.assignmentForEngineer(engineerId) != null) {
      return EmployeeWorkflowState.assigned;
    }

    final hasPendingOffer = state.offers.any(
      (o) => o.employeeId == engineerId && o.status == OfferStatus.pending,
    );
    if (hasPendingOffer) return EmployeeWorkflowState.finalOfferPending;

    // A proposal whose final Offer was already accepted — the employee is
    // waiting for `assignWeek` to arrive, not for a selection result
    // (Playable 0.4C.3 §3-9, the "参画予定" state the original bug report
    // was about). Covers both the multi-step flow (Offer accepted
    // explicitly) and the legacy single-interview flow (interview passed,
    // `assignWeek` already set).
    final scheduled = state.proposals.any(
      (p) => p.engineerId == engineerId && p.status == ApplicationStatus.accepted,
    );
    if (scheduled) return EmployeeWorkflowState.assignmentScheduled;

    final clientInterviewPending = state.proposals.any(
      (p) =>
          p.engineerId == engineerId &&
          p.status == ApplicationStatus.active &&
          p.currentStep == SelectionStep.clientInterview &&
          !state.clientInterviews.any((s) => s.applicationId == p.id && s.completed),
    );
    if (clientInterviewPending) return EmployeeWorkflowState.clientInterviewActionRequired;

    final inSelection = state.proposals.any(
      (p) => p.engineerId == engineerId && p.status == ApplicationStatus.active,
    );
    if (inSelection) return EmployeeWorkflowState.waitingSelectionResult;

    final hasInterviewRequest = state.interviewOffers.any(
      (o) => o.employeeId == engineerId && o.status == InterviewOfferStatus.pending,
    );
    if (hasInterviewRequest) return EmployeeWorkflowState.interviewRequestPending;

    if (engineer.salesStatus != SalesStatus.notSelling) {
      return EmployeeWorkflowState.selling;
    }

    return EmployeeWorkflowState.waiting;
  }

  static const Map<EmployeeWorkflowState, String> labels = {
    EmployeeWorkflowState.waiting: '待機中',
    EmployeeWorkflowState.selling: '待機・営業中',
    EmployeeWorkflowState.interviewRequestPending: '面談依頼あり',
    EmployeeWorkflowState.waitingSelectionResult: '選考結果待ち',
    EmployeeWorkflowState.clientInterviewActionRequired: '客先面談あり',
    EmployeeWorkflowState.finalOfferPending: '参画オファーあり',
    EmployeeWorkflowState.assignmentScheduled: '参画予定',
    EmployeeWorkflowState.assigned: '参画中',
  };

  /// Whether this state means "the player has something to do right now"
  /// (§18, §21) as opposed to "nothing to do until next week" — used so
  /// screens never show an action-required state next to "次週へ進めましょ
  /// う" for the same employee.
  static bool requiresAction(EmployeeWorkflowState state) => switch (state) {
    EmployeeWorkflowState.finalOfferPending => true,
    EmployeeWorkflowState.clientInterviewActionRequired => true,
    EmployeeWorkflowState.interviewRequestPending => true,
    _ => false,
  };
}
