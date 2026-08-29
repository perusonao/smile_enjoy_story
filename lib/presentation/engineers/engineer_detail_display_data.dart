import '../../domain/domain.dart';
import '../../game/engine/employee_workflow_engine.dart';
import '../../game/models/game_state.dart';
import '../../game/models/project_proposal.dart';

/// Read-only normal-game projection for the authority-backed top portion of
/// the engineer detail screen.  Widgets consume this instead of reconstructing
/// workflow or sales-facing SkillSheet values from individual state fields.
class EngineerDetailDisplayData {
  const EngineerDetailDisplayData({
    required this.summary,
    required this.currentStatus,
    required this.skillSheet,
    required this.currentAssignment,
  });

  final EngineerSummaryDisplay summary;
  final EngineerCurrentStatusDisplay currentStatus;
  final EngineerSkillSheetDisplay skillSheet;
  final EngineerCurrentAssignmentDisplay? currentAssignment;
}

class EngineerSummaryDisplay {
  const EngineerSummaryDisplay({required this.engineer});

  final Engineer engineer;
}

class EngineerCurrentStatusDisplay {
  const EngineerCurrentStatusDisplay({
    required this.state,
    this.assignment,
    this.scheduledProposal,
    this.pendingOffer,
    this.pendingOfferProposal,
    this.activeProposal,
    this.clientInterviewApplicationId,
    required this.unlockedClientCount,
  });

  /// Sole current-status authority: [EmployeeWorkflowEngine].
  final EmployeeWorkflowState state;
  final ActiveAssignment? assignment;
  final ProjectProposal? scheduledProposal;
  final Offer? pendingOffer;
  final ProjectProposal? pendingOfferProposal;
  final ProjectProposal? activeProposal;
  final String? clientInterviewApplicationId;
  final int unlockedClientCount;
}

class EngineerSkillSheetDisplay {
  const EngineerSkillSheetDisplay({
    required this.sheet,
    required this.actualPrimaryLanguageMonths,
    required this.actualBackend,
    required this.actualLeader,
    required this.companyTrust,
    required this.salesStatus,
    required this.availableFromWeek,
  });

  /// Persisted sales-facing authority. It is intentionally nullable for a
  /// malformed/legacy save; callers must show an unavailable fallback rather
  /// than recreating a sheet from actual skills.
  final SkillSheet? sheet;
  final int actualPrimaryLanguageMonths;
  final int actualBackend;
  final int actualLeader;
  final int companyTrust;
  final SalesStatus salesStatus;
  final int availableFromWeek;
}

class EngineerCurrentAssignmentDisplay {
  const EngineerCurrentAssignmentDisplay({required this.assignment});

  final ActiveAssignment assignment;
}

class EngineerDetailDisplayFactory {
  const EngineerDetailDisplayFactory._();

  /// Returns null when the requested employee is absent. This lets the UI use
  /// its established not-found state without dereferencing an unknown id.
  static EngineerDetailDisplayData? create(GameState state, String engineerId) {
    Engineer? engineer;
    for (final candidate in state.engineers) {
      if (candidate.id == engineerId) {
        engineer = candidate;
        break;
      }
    }
    if (engineer == null) return null;

    SkillSheet? sheet;
    for (final candidate in state.skillSheets) {
      if (candidate.employeeId == engineerId) {
        sheet = candidate;
        break;
      }
    }

    final assignment = state.assignmentForEngineer(engineerId);
    final workflow = EmployeeWorkflowEngine.forEngineer(state, engineerId);
    final scheduledProposal = _firstProposal(
      state,
      engineerId,
      (proposal) => proposal.status == ApplicationStatus.accepted,
    );
    final pendingOffer = _firstOffer(state, engineerId);
    final pendingOfferProposal = pendingOffer == null
        ? null
        : _proposalById(state, pendingOffer.applicationId);
    final firstActiveProposal = _firstProposal(
      state,
      engineerId,
      (proposal) => proposal.status == ApplicationStatus.active,
    );
    final pendingClientInterviewProposal = _pendingClientInterviewProposal(
      state,
      engineerId,
    );
    final primary = engineer.profile.mainLanguage;

    return EngineerDetailDisplayData(
      summary: EngineerSummaryDisplay(engineer: engineer),
      currentStatus: EngineerCurrentStatusDisplay(
        state: workflow,
        assignment: assignment,
        scheduledProposal: scheduledProposal,
        pendingOffer: pendingOffer,
        pendingOfferProposal: pendingOfferProposal,
        activeProposal: pendingClientInterviewProposal ?? firstActiveProposal,
        clientInterviewApplicationId: pendingClientInterviewProposal?.id,
        unlockedClientCount: state.unlockedClientCount,
      ),
      skillSheet: EngineerSkillSheetDisplay(
        sheet: sheet,
        actualPrimaryLanguageMonths: engineer.profile
            .skillFor(primary)
            .actualExperienceMonths,
        actualBackend: engineer.profile.techSkills.backend,
        actualLeader: engineer.profile.techSkills.leader,
        companyTrust: engineer.companyTrust,
        salesStatus: engineer.salesStatus,
        availableFromWeek: engineer.availableFromWeek,
      ),
      currentAssignment: assignment == null
          ? null
          : EngineerCurrentAssignmentDisplay(assignment: assignment),
    );
  }

  static ProjectProposal? _firstProposal(
    GameState state,
    String engineerId,
    bool Function(ProjectProposal) predicate,
  ) {
    for (final proposal in state.proposals) {
      if (proposal.engineerId == engineerId && predicate(proposal)) {
        return proposal;
      }
    }
    return null;
  }

  static Offer? _firstOffer(GameState state, String engineerId) {
    for (final offer in state.offers) {
      if (offer.employeeId == engineerId &&
          offer.status == OfferStatus.pending) {
        return offer;
      }
    }
    return null;
  }

  static ProjectProposal? _proposalById(GameState state, String id) {
    for (final proposal in state.proposals) {
      if (proposal.id == id) return proposal;
    }
    return null;
  }

  static ProjectProposal? _pendingClientInterviewProposal(
    GameState state,
    String engineerId,
  ) {
    for (final proposal in state.proposals) {
      final isPendingClientInterview =
          proposal.engineerId == engineerId &&
          proposal.status == ApplicationStatus.active &&
          proposal.currentStep == SelectionStep.clientInterview &&
          !state.clientInterviews.any(
            (session) =>
                session.applicationId == proposal.id && session.completed,
          );
      if (isPendingClientInterview) return proposal;
    }
    return null;
  }
}
