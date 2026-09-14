import 'public_demo_sales.dart';
import 'public_demo_state.dart';
import 'public_demo_workflow_state.dart';

// SES First Fun Quarter — Mission System Phase 1 (April Main Mission),
// design docs:
//   docs/reports/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Fresh-Audit.md
//   docs/design/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md
//
// This file is the Mission System's ONLY authority-reading surface — a
// pure, presentation-facing resolver mirroring the established
// [PublicDemoEmployeeStatusResolver] convention (`lib/ui/public_demo/
// public_demo_employee_status_resolver.dart`): it takes only the already-
// authoritative [PublicDemoWorkflowState]/[PublicDemoState] the caller
// already holds, reads no BuildContext, mutates nothing, and mints no new
// domain fact. Mission "locked"/"available"/"completed" is a guidance-layer
// projection on top of existing gameplay authority — it never gates a
// player action the domain itself would otherwise allow (Fresh Audit §5,
// Implementation Plan §3.3).
//
// Authority discipline (Fresh Audit §1.2, §3 — do not weaken when adding a
// mission or touching this file):
//   - A raw [PublicDemoSalesStage] value is trusted only where the domain
//     itself already treats it as trustworthy (every mission below except
//     `passClientInterview`) — never compared via `.index` (the enum's
//     declaration order interleaves the two "Failed" branches with their
//     "Passed" counterparts, so index is not pipeline-progress order; see
//     [PublicDemoSalesStage]'s own declaration). Every "has this engineer
//     reached at least stage X" check below is an explicit, exhaustive
//     `switch` over all 9 [PublicDemoSalesStage] values.
//   - `passClientInterview` reads [PublicDemoEngineerSales
//     .hasGenuineInterviewRecord] — the one unforgeable record — never
//     `stage == clientInterviewPassed` alone (Fresh Audit §3 row 6).
//   - `assignToProject` reads [PublicDemoWorkflowState.assignedEngineerIds]
//     with the caller's OWN current month, never a captured/stale one
//     (Fresh Audit §10.6) — this resolver takes no `month` parameter of its
//     own, using [PublicDemoState.month] at call time instead.
//
// No new persisted field: every mission's completion is derived on demand
// from state the save codec already serializes. A pre-Mission-System save
// that already has an engineer at, say, `stage == ordered` with
// `assignedEngineerIds` membership shows every prerequisite mission as
// `completed` the moment it is loaded into a Mission-System-aware build —
// no re-play required (Fresh Audit §10.5, Implementation Plan §9).
//
// Company-level, not per-engineer: April's headline goal ("技術者1名を案件に
// 参画させる") is phrased as a single company milestone, so each mission
// collapses "does ANY engineer/founder satisfy this" to one status — Public
// Demo's April roster is small (2 founders) and the task's own framing
// treats this as one goal, not a per-engineer scoreboard.
// [PublicDemoMissionStatusEntry.engineerId] still names the (first) engineer
// whose state actually satisfies a `completed` mission, keeping design
// headroom for a future per-engineer view without widening this type.

/// Stable identifiers for every Mission Phase 1 tracks — the April headline
/// chain only (Fresh Audit §5/§12, Implementation Plan §3.1). These are
/// deliberately plain enum values, not persisted anywhere: nothing in the
/// save schema stores a [PublicDemoMissionId], so renaming/reordering this
/// enum cannot corrupt a save — but a future phase that DOES persist
/// something keyed by mission (e.g. an acknowledgement map) will want
/// stable string ids, so avoid casually reordering once shipped.
enum PublicDemoMissionId {
  /// Mission 1 — 技術者のSkillSheetを確認する.
  viewSkillSheet,

  /// Mission 3 — 技術者の営業を行う.
  beginSelling,

  /// Mission 4 — 技術者を案件に提案する.
  proposeToProject,

  /// Mission 5 — 上位会社面談を通過する.
  passPartnerInterview,

  /// Mission 6 — 客先面談を通過する.
  passClientInterview,

  /// Mission 7 — 案件を受注する.
  winOrder,

  /// Mission 8 — 技術者を案件に参画させる。April's headline mission; Mission
  /// 22 (売上が発生する, Fresh Audit §2.3) is folded into this mission's own
  /// completion narration rather than tracked separately.
  assignToProject,
}

/// The April headline chain, in its fixed narrative order (Fresh Audit §5).
/// [PublicDemoMissionResolver.resolve] returns entries in this same order.
const List<PublicDemoMissionId> publicDemoAprilMissionChain = [
  PublicDemoMissionId.viewSkillSheet,
  PublicDemoMissionId.beginSelling,
  PublicDemoMissionId.proposeToProject,
  PublicDemoMissionId.passPartnerInterview,
  PublicDemoMissionId.passClientInterview,
  PublicDemoMissionId.winOrder,
  PublicDemoMissionId.assignToProject,
];

/// A Mission's player-facing progress state. Advisory/UI-only — see this
/// file's own top-of-file doc: `locked` never disables a real domain
/// action, it only changes how the Mission screen presents the step.
enum PublicDemoMissionStatus { locked, available, completed }

/// One Mission's resolved status, paired with the (optional) engineer this
/// particular completion is keyed to. Always produced together so a caller
/// can never see a `completed` status without knowing which engineer earned
/// it (when the underlying check has a natural single-engineer witness).
class PublicDemoMissionStatusEntry {
  const PublicDemoMissionStatusEntry({
    required this.id,
    required this.status,
    this.engineerId,
  });

  final PublicDemoMissionId id;
  final PublicDemoMissionStatus status;

  /// The first engineer id whose own state satisfies this mission's
  /// completion check, or `null` when the mission is not `completed` (or
  /// satisfied by no specific engineer). Company-level completion does not
  /// depend on this field — it exists purely as design headroom for a
  /// future per-engineer Mission view (see this file's top-of-file doc).
  final String? engineerId;
}

/// Pure resolver for the April Mission chain — see this file's top-of-file
/// doc for the authorities it reads and the discipline it follows.
class PublicDemoMissionResolver {
  const PublicDemoMissionResolver._();

  /// Resolves every mission in [publicDemoAprilMissionChain] against
  /// [workflow]/[state]. Always returns exactly one entry per chain id, in
  /// chain order.
  static List<PublicDemoMissionStatusEntry> resolve({
    required PublicDemoWorkflowState workflow,
    required PublicDemoState state,
  }) {
    final month = state.month;
    final assignedIds = workflow.assignedEngineerIds(month: month);

    String? firstEngineerWhere(bool Function(PublicDemoEngineerSales) test) {
      for (final engineer in workflow.engineers) {
        if (test(engineer)) return engineer.id;
      }
      return null;
    }

    bool anyEngineer(bool Function(PublicDemoEngineerSales) test) =>
        workflow.engineers.any(test);

    final completedById = <PublicDemoMissionId, bool>{
      PublicDemoMissionId.viewSkillSheet: anyEngineer(
        (e) => e.stage != PublicDemoSalesStage.waiting,
      ),
      PublicDemoMissionId.beginSelling: anyEngineer(
        (e) => _hasReachedSelling(e.stage),
      ),
      PublicDemoMissionId.proposeToProject: anyEngineer(
        (e) => _hasReachedIntroduced(e.stage),
      ),
      PublicDemoMissionId.passPartnerInterview: anyEngineer(
        (e) => _hasPassedPartnerInterview(e.stage),
      ),
      // Fresh Audit §3 row 6: the one mission that must read the
      // unforgeable record, never the raw stage.
      PublicDemoMissionId.passClientInterview: anyEngineer(
        (e) => e.hasGenuineInterviewRecord,
      ),
      PublicDemoMissionId.winOrder: anyEngineer(
        (e) => e.stage == PublicDemoSalesStage.ordered,
      ),
      // Fresh Audit §3 row 8 / §10.6: current membership in the one shared
      // SSOT every other reader (Revenue, roster, HOME) already agrees on —
      // never a cached month, never "row exists in assignments" alone.
      PublicDemoMissionId.assignToProject: assignedIds.isNotEmpty,
    };

    final engineerIdById = <PublicDemoMissionId, String?>{
      PublicDemoMissionId.viewSkillSheet: firstEngineerWhere(
        (e) => e.stage != PublicDemoSalesStage.waiting,
      ),
      PublicDemoMissionId.beginSelling: firstEngineerWhere(
        (e) => _hasReachedSelling(e.stage),
      ),
      PublicDemoMissionId.proposeToProject: firstEngineerWhere(
        (e) => _hasReachedIntroduced(e.stage),
      ),
      PublicDemoMissionId.passPartnerInterview: firstEngineerWhere(
        (e) => _hasPassedPartnerInterview(e.stage),
      ),
      PublicDemoMissionId.passClientInterview: firstEngineerWhere(
        (e) => e.hasGenuineInterviewRecord,
      ),
      PublicDemoMissionId.winOrder: firstEngineerWhere(
        (e) => e.stage == PublicDemoSalesStage.ordered,
      ),
      PublicDemoMissionId.assignToProject: workflow.engineers
          .where((e) => assignedIds.contains(e.id))
          .map((e) => e.id)
          .firstOrNull,
    };

    var previousCompleted = true; // Mission 1 is always at least available.
    final entries = <PublicDemoMissionStatusEntry>[];
    for (final id in publicDemoAprilMissionChain) {
      final completed = completedById[id] ?? false;
      final status = completed
          ? PublicDemoMissionStatus.completed
          : (previousCompleted
                ? PublicDemoMissionStatus.available
                : PublicDemoMissionStatus.locked);
      entries.add(
        PublicDemoMissionStatusEntry(
          id: id,
          status: status,
          engineerId: completed ? engineerIdById[id] : null,
        ),
      );
      previousCompleted = completed;
    }
    return entries;
  }

  /// Whether [stage] represents having reached [PublicDemoSalesStage
  /// .selling] or any later stage in the pipeline (Mission 3). Exhaustive
  /// `switch`, never `.index` — see this file's top-of-file doc.
  static bool _hasReachedSelling(PublicDemoSalesStage stage) {
    switch (stage) {
      case PublicDemoSalesStage.waiting:
      case PublicDemoSalesStage.skillSheet:
        return false;
      case PublicDemoSalesStage.selling:
      case PublicDemoSalesStage.introduced:
      case PublicDemoSalesStage.partnerInterviewFailed:
      case PublicDemoSalesStage.partnerInterviewPassed:
      case PublicDemoSalesStage.clientInterviewFailed:
      case PublicDemoSalesStage.clientInterviewPassed:
      case PublicDemoSalesStage.ordered:
        return true;
    }
  }

  /// Whether [stage] represents having reached [PublicDemoSalesStage
  /// .introduced] or any later stage (Mission 4).
  static bool _hasReachedIntroduced(PublicDemoSalesStage stage) {
    switch (stage) {
      case PublicDemoSalesStage.waiting:
      case PublicDemoSalesStage.skillSheet:
      case PublicDemoSalesStage.selling:
        return false;
      case PublicDemoSalesStage.introduced:
      case PublicDemoSalesStage.partnerInterviewFailed:
      case PublicDemoSalesStage.partnerInterviewPassed:
      case PublicDemoSalesStage.clientInterviewFailed:
      case PublicDemoSalesStage.clientInterviewPassed:
      case PublicDemoSalesStage.ordered:
        return true;
    }
  }

  /// Whether [stage] represents having genuinely passed the partner
  /// interview at least once (Mission 5) — `partnerInterviewFailed` alone
  /// does NOT count (a later stage supersedes the literal `passed` value,
  /// per Fresh Audit §3 row 5, so every stage reachable only AFTER a
  /// genuine partner pass is included here too).
  static bool _hasPassedPartnerInterview(PublicDemoSalesStage stage) {
    switch (stage) {
      case PublicDemoSalesStage.waiting:
      case PublicDemoSalesStage.skillSheet:
      case PublicDemoSalesStage.selling:
      case PublicDemoSalesStage.introduced:
      case PublicDemoSalesStage.partnerInterviewFailed:
        return false;
      case PublicDemoSalesStage.partnerInterviewPassed:
      case PublicDemoSalesStage.clientInterviewFailed:
      case PublicDemoSalesStage.clientInterviewPassed:
      case PublicDemoSalesStage.ordered:
        return true;
    }
  }
}
