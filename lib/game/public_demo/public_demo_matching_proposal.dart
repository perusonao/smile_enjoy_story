/// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): the minimum explicit
/// record of a player's "提案する" decision — this engineer, for this real
/// Phase 4 [PublicDemoProjectCandidate.id] project — kept only so Phase 6
/// (Project Interview) has something concrete to pick up. Phase 5
/// deliberately does not implement the interview itself, and does not
/// touch [PublicDemoEngineerSales.stage]/`salesCapacity`/`salesUsed` — this
/// is new, additive state, not a change to the existing sales-pipeline
/// authority.
///
/// A "見送る" (pass) decision is intentionally NOT recorded anywhere: it
/// changes nothing about the game state, so persisting it would be exactly
/// the "再生成可能／不要なデータの無意味な重複保存" this initiative's own prior
/// phases have consistently avoided (see Phase 4's Result report,
/// "Persistence decision").
class PublicDemoMatchingProposal {
  const PublicDemoMatchingProposal({
    required this.engineerId,
    required this.projectId,
    required this.decidedMonth,
  });

  /// The employee this proposal is for. At most one proposal exists per
  /// [engineerId] at a time — see [PublicDemoWorkflowState.withMatchingProposal].
  final String engineerId;

  /// The real Phase 4 [PublicDemoProjectCandidate.id] the player selected —
  /// resolvable back to its full [Project]/[Client] content at any time via
  /// [PublicDemoSeededProjectGenerator.regenerate], so nothing about the
  /// project itself needs to be duplicated here.
  final String projectId;

  /// The internal month the player made this decision, for display/ordering
  /// only — not read by any eligibility/authority check in this phase.
  final int decidedMonth;

  Map<String, dynamic> toJson() => {
    'engineerId': engineerId,
    'projectId': projectId,
    'decidedMonth': decidedMonth,
  };

  factory PublicDemoMatchingProposal.fromJson(Map<String, dynamic> json) {
    T required<T>(String key) {
      final value = json[key];
      if (value is! T) {
        throw FormatException('Invalid matching proposal $key');
      }
      return value;
    }

    return PublicDemoMatchingProposal(
      engineerId: required<String>('engineerId'),
      projectId: required<String>('projectId'),
      decidedMonth: required<int>('decidedMonth'),
    );
  }
}
