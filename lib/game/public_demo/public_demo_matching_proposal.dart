/// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): the minimal explicit
/// record connecting one specific engineer to one specific real Phase 4
/// ([PublicDemoProjectCandidate]) project, once the player decides
/// "提案する" during the matching decision flow
/// (`lib/ui/public_demo/public_demo_matching_decision_sheet.dart`).
///
/// This is deliberately a thin identifier pair, not a new workflow stage
/// machine: it does not touch [PublicDemoEngineerSales.stage] or any of the
/// existing sales-pipeline transitions (`beginSelling`/`introduceProject`/
/// the partner-client interview methods on `public_demo_sales.dart`), all
/// of which remain entirely independent, unmodified authority. Phase 6
/// (Project Interview) is the intended reader of this record; Phase 5 only
/// defines, persists, and lets the player overwrite it.
class PublicDemoMatchingProposal {
  const PublicDemoMatchingProposal({
    required this.engineerId,
    required this.projectId,
    required this.decidedMonth,
  });

  /// The engineer this proposal was made for — always a real
  /// [PublicDemoEngineerSales.id] already present in the workflow at the
  /// time [PublicDemoWorkflowState.proposeMatching] recorded this.
  final String engineerId;

  /// The real Phase 4 project candidate this engineer was proposed for —
  /// a [PublicDemoProjectCandidate.id] (`lib/game/public_demo
  /// /public_demo_project_generator.dart`), re-derivable via
  /// [PublicDemoSeededProjectGenerator.regenerate] from `(runSeed,
  /// projectId)` alone — nothing about the project itself is duplicated or
  /// persisted here.
  final String projectId;

  /// The month the player made this decision — recorded for the same
  /// reason every other Public Demo decision timestamps itself (e.g.
  /// [PublicDemoFounderFollowUp]'s own `decidedMonth`-shaped field):
  /// Phase 6 and any future review UI can show "いつ提案したか" truthfully
  /// instead of only "today's" workflow snapshot.
  final int decidedMonth;

  Map<String, dynamic> toJson() => {
    'engineerId': engineerId,
    'projectId': projectId,
    'decidedMonth': decidedMonth,
  };

  factory PublicDemoMatchingProposal.fromJson(Map<String, dynamic> json) =>
      PublicDemoMatchingProposal(
        engineerId: json['engineerId'] as String,
        projectId: json['projectId'] as String,
        decidedMonth: json['decidedMonth'] as int,
      );
}
