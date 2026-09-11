import 'public_demo_project_context.dart' show PublicDemoProjectContext;
import '../../game/public_demo/public_demo_project_generator.dart';
import '../../game/public_demo/public_demo_sales.dart';

// SES FIRST-FUN-YEAR P1: Project / Order / Assignment Continuous Visibility
// (Fresh Audit,
// docs/reports/SES_FIRST-FUN-YEAR_Project-Order-Assignment-Visibility_Fresh-Audit.md):
// the single, pure place that decides which real Phase 4/5/6 project id is
// the truthful "current" one for an engineer right now, and a stage-
// appropriate label to show it under — mirroring
// `public_demo_employee_status_resolver.dart`'s own convention (a pure,
// presentation-layer-only function fed facts the caller already computed
// from existing authoritative state).
//
// The Fresh Audit found three independent, already-authoritative project-id
// sources, each read ad hoc at its own single call site with no shared
// resolution:
//  * [PublicDemoAssignment.projectId] — the frozen identity of a
//    materialized assignment (`_currentUnitPriceDisplayFor`,
//    `PublicDemoAggregate._careerHistoryEntryFor`).
//  * [PublicDemoEngineerSales.genuineInterviewProjectId] — the real project
//    a genuine Phase 6 client-interview pass was actually conducted for,
//    available from the moment that interview passes, well before
//    `assignOrderedForMay`/`recoverLateYearAssignment` ever materializes an
//    assignment row for it.
//  * [PublicDemoMatchingProposal.projectId] — the player's still-open "提案
//    する" decision (Phase 5), before any interview has run at all.
//
// None of those three was ever surfaced on the per-engineer sales-pipeline
// card (`ec(i)` in `public_demo_01_placeholder_screen.dart`) — a player who
// left the Matching screen after proposing, or who used `案件紹介`'s
// auto-pick fallback, had no way to see which real project they were
// pursuing until the assignment card appeared, months later. This resolver
// reads whichever of the three is most authoritative for the given
// stage/assignment state, so every card that shows "which project" (the
// Sales-pipeline card, the roster row, the active-project card, June's
// assignment-decision card) agrees, exactly the way
// [PublicDemoEmployeeStatusResolver] already unified the status label/tone.
//
// Never invents a project id: every branch below reads only a field already
// persisted by a genuine domain command — no new domain authority, enum, or
// persisted field. A `null` result always means "no real project fact
// exists yet for this stage", which every call site falls back on its own
// existing generic text/dash for, never a guess.
class PublicDemoProjectContextResolver {
  const PublicDemoProjectContextResolver._();

  /// The real project id most authoritative for [stage] right now.
  ///
  /// * Currently assigned (`isCurrentlyAssigned`): only
  ///   [assignmentProjectId] — the identity frozen at assignment creation —
  ///   is ever authoritative once participation has actually started, even
  ///   if a proposal for a different project happens to still be recorded
  ///   (Phase 5 proposals never re-target an already-passed engineer — see
  ///   [PublicDemoWorkflowState.withMatchingProposal]'s own doc — but this
  ///   resolver does not depend on that holding to stay correct).
  /// * `ordered` but not yet assigned (参画予定 — a real order won this month,
  ///   materializing into an assignment only at the next month-end close):
  ///   [genuineInterviewProjectId] — the project Phase 6 already proved this
  ///   engineer was actually interviewed for — falling back to
  ///   [assignmentProjectId] only for the edge case where an assignment row
  ///   already exists (a prior cycle's) but this month's [isCurrentlyAssigned]
  ///   check does not yet count it.
  /// * Still mid-pipeline (`introduced` through the client-interview
  ///   pass/fail stages): the same [genuineInterviewProjectId] once a
  ///   client-interview pass exists, else the still-open
  ///   [matchingProposalProjectId] — the player's current "提案する" target,
  ///   which is all that exists before any interview has run.
  /// * `waiting`/`skillSheet`/`selling`: always `null` — no project has been
  ///   introduced yet at these stages (`案件紹介` is the introduction event
  ///   itself), so there is nothing truthful to resolve.
  static String? projectIdFor({
    required PublicDemoSalesStage stage,
    required bool isCurrentlyAssigned,
    String? assignmentProjectId,
    String? genuineInterviewProjectId,
    String? matchingProposalProjectId,
  }) {
    if (isCurrentlyAssigned) return assignmentProjectId;
    switch (stage) {
      case PublicDemoSalesStage.ordered:
        return genuineInterviewProjectId ?? assignmentProjectId;
      case PublicDemoSalesStage.introduced:
      case PublicDemoSalesStage.partnerInterviewPassed:
      case PublicDemoSalesStage.partnerInterviewFailed:
      case PublicDemoSalesStage.clientInterviewPassed:
      case PublicDemoSalesStage.clientInterviewFailed:
        return genuineInterviewProjectId ?? matchingProposalProjectId;
      case PublicDemoSalesStage.waiting:
      case PublicDemoSalesStage.skillSheet:
      case PublicDemoSalesStage.selling:
        return null;
    }
  }

  /// The stage-appropriate prefix for whatever [projectIdFor] resolves —
  /// never itself a claim about ordered/assigned identity (that remains
  /// [PublicDemoEmployeeStatusResolver]'s job): purely which noun phrase
  /// truthfully describes *this* project reference at this stage.
  static String labelFor({
    required PublicDemoSalesStage stage,
    required bool isCurrentlyAssigned,
  }) {
    if (isCurrentlyAssigned) return '参画中案件';
    if (stage == PublicDemoSalesStage.ordered) return '受注案件';
    return '提案中の案件';
  }

  /// Resolves the full display context, via [resolveCandidate] — injected so
  /// this stays a pure function of its own inputs rather than a direct
  /// [PublicDemoSeededProjectGenerator] caller; production callers pass
  /// `(id) => PublicDemoSeededProjectGenerator.regenerate(runSeed: ...,
  /// projectId: id)`. `null` for every stage [projectIdFor] itself returns
  /// `null` for, and for a `projectId` [resolveCandidate] cannot resolve
  /// (should not happen for a genuine id — see
  /// [PublicDemoSeededProjectGenerator.regenerate]'s own doc — but never
  /// assumed here either).
  static PublicDemoProjectContext? resolve({
    required PublicDemoSalesStage stage,
    required bool isCurrentlyAssigned,
    String? assignmentProjectId,
    String? genuineInterviewProjectId,
    String? matchingProposalProjectId,
    required PublicDemoProjectCandidate? Function(String projectId)
    resolveCandidate,
  }) {
    final projectId = projectIdFor(
      stage: stage,
      isCurrentlyAssigned: isCurrentlyAssigned,
      assignmentProjectId: assignmentProjectId,
      genuineInterviewProjectId: genuineInterviewProjectId,
      matchingProposalProjectId: matchingProposalProjectId,
    );
    if (projectId == null) return null;
    final candidate = resolveCandidate(projectId);
    if (candidate == null) return null;
    return PublicDemoProjectContext(
      label: labelFor(stage: stage, isCurrentlyAssigned: isCurrentlyAssigned),
      title: candidate.title,
      clientName: candidate.clientName,
      monthlyRate: candidate.monthlyRate,
    );
  }
}
