import 'public_demo_matching_proposal.dart';
import 'public_demo_sales.dart';

/// Issue #255 FIRST-FUN-YEAR Parallel Sales Phase 1A: per-(engineer,
/// project) Offer Candidate authority, additive to
/// [PublicDemoWorkflowState] (public_demo_workflow_state.dart) and
/// completely independent of [PublicDemoEngineerSales.stage]/
/// [PublicDemoEngineerSales.interviewRecord] (public_demo_sales.dart) — see
/// this repository's
/// `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md` for the
/// audited design this implements, and PR #253's Codex review for the two
/// corrections folded in here: every legacy in-flight stage must migrate
/// (P1), and the client-interview leg must stay zero-sales-slot (P2).
///
/// Phase 1A is domain-only: nothing in `PublicDemoAggregate`
/// (public_demo_aggregate.dart) or any UI screen calls the mutation methods
/// [PublicDemoWorkflowState] exposes for this list yet — the legacy
/// per-engineer scalar pipeline ([PublicDemoEngineerSales.stage]) remains
/// the sole production authority, completely unmodified. This authority
/// exists so it can be safely established and load-time migrated ahead of
/// the Phase 1B caller cutover, without risking the existing large Public
/// Demo test suite, which depends on today's single-candidate-per-engineer
/// behavior.
enum PublicDemoOfferCandidateStage {
  /// The player proposed this engineer for this project (mirrors
  /// [PublicDemoMatchingProposal]) but no partner-interview result exists
  /// yet. Also the legacy-migration target for an engineer already
  /// `introduced` to this project under the old scalar pipeline (see
  /// [PublicDemoOfferCandidate.migrateFromLegacyStage]'s own doc) — there is
  /// no separate "introduced" candidate stage: a proposed-but-not-yet-
  /// interviewed candidate and an introduced-but-not-yet-interviewed legacy
  /// engineer both mean the same thing, nothing decision-relevant has
  /// happened yet besides the player's own selection.
  proposed,
  partnerInterviewPassed,
  partnerInterviewFailed,
  clientInterviewPassed,
  clientInterviewFailed,

  /// The player explicitly chose this candidate to receive the order —
  /// reachable only via
  /// [PublicDemoWorkflowState.recordOfferCandidateOrder], itself reachable
  /// only after this candidate genuinely reached `clientInterviewPassed`
  /// with a genuine [PublicDemoOfferInterviewRecord] (see
  /// [PublicDemoOfferCandidate.hasGenuineInterviewRecord]).
  ordered,

  /// This candidate is closed out — either the player explicitly declined
  /// it ([PublicDemoWorkflowState.declineOfferCandidate]), or it was
  /// auto-declined as a sibling the moment a different candidate for the
  /// same engineer was ordered (see
  /// [PublicDemoWorkflowState.recordOfferCandidateOrder]'s own doc).
  /// Terminal: nothing in this file ever transitions a `declined` candidate
  /// to any other stage.
  declined,
}

/// Authoritative, unforgeable proof that a specific (engineer, project)
/// candidate actually passed a genuine client interview — the
/// per-(engineer, project) generalization of
/// [PublicDemoEngineerInterviewRecord] (public_demo_sales.dart), which
/// proves the same fact for the legacy single-candidate-per-engineer
/// pipeline. Constructor private to this file: only
/// [PublicDemoOfferCandidate.applyClientInterviewResult] (a genuine pass)
/// or [PublicDemoOfferCandidate.migrateFromLegacyStage] (reconstructing
/// exactly the fact the legacy [PublicDemoEngineerInterviewRecord] already
/// proved) can mint one.
class PublicDemoOfferInterviewRecord {
  const PublicDemoOfferInterviewRecord._({
    required this.engineerId,
    required this.projectId,
  });

  /// The engineer this pass was actually recorded for — checked for
  /// identity match against the owning [PublicDemoOfferCandidate], not just
  /// presence (mirrors [PublicDemoEngineerInterviewRecord.engineerId]'s own
  /// doc).
  final String engineerId;

  /// The real project this pass was actually interviewed for — checked for
  /// identity match against the owning [PublicDemoOfferCandidate]. Unlike
  /// the legacy record, this is never `null`: a candidate with no
  /// genuinely resolvable project id still gets one via
  /// [PublicDemoOfferCandidate.legacyCompatibilityProjectId] (the explicit
  /// project-agnostic compatibility path PR #253's Codex review requires),
  /// so a candidate's own `projectId` is always a real value to check
  /// identity against.
  final String projectId;

  Map<String, dynamic> toJson() => {
    'engineerId': engineerId,
    'projectId': projectId,
  };
}

/// A single per-(engineer, project) offer, additive on
/// [PublicDemoWorkflowState.offerCandidates]. See this file's own class doc
/// above for why this exists alongside, not instead of,
/// [PublicDemoEngineerSales] this phase.
class PublicDemoOfferCandidate {
  const PublicDemoOfferCandidate({
    required this.engineerId,
    required this.projectId,
    required this.proposedMonth,
    this.stage = PublicDemoOfferCandidateStage.proposed,
    this.partnerScore,
    this.clientScore,
    this.interviewRecord,
  });

  /// Stable, derived identity — never persisted as its own field: it is
  /// fully reconstructible from [engineerId]/[projectId], and persisting it
  /// separately would only create a second copy that could drift out of
  /// sync with them.
  String get id => idFor(engineerId: engineerId, projectId: projectId);

  static String idFor({required String engineerId, required String projectId}) =>
      '$engineerId::$projectId';

  /// The explicit, stable compatibility placeholder for a legacy engineer
  /// whose in-flight sales progress names no real project at all — PR
  /// #253's Codex review P1 finding: "projectIdのない/一致proposalのない
  /// legacy interview recordにも明示的なcompatibility pathを持つこと". Never
  /// collides with a real
  /// `PublicDemoSeededProjectGenerator`-minted id (always
  /// `project-<month>-<slot>`; this never starts with `project-`).
  static String legacyCompatibilityProjectId(String engineerId) =>
      'legacy-project-for-$engineerId';

  final String engineerId;
  final String projectId;

  /// The internal month the player proposed this candidate — display/
  /// ordering only, mirrors [PublicDemoMatchingProposal.decidedMonth]'s own
  /// doc: never read by any eligibility/authority check in this phase. `0`
  /// for a candidate synthesized by [migrateFromLegacyStage] with no
  /// [PublicDemoMatchingProposal] on file to recover a real month from.
  final int proposedMonth;
  final PublicDemoOfferCandidateStage stage;
  final int? partnerScore;
  final int? clientScore;

  /// Authoritative, unforgeable proof this candidate actually passed a
  /// genuine client interview — see [PublicDemoOfferInterviewRecord].
  final PublicDemoOfferInterviewRecord? interviewRecord;

  /// Whether this candidate genuinely passed a client interview — checked
  /// by identity against BOTH [engineerId] AND [projectId] (unlike the
  /// legacy per-engineer [PublicDemoEngineerSales.hasGenuineInterviewRecord],
  /// which only ever had one project to check against), never `stage`/
  /// [clientScore] alone.
  /// [PublicDemoWorkflowState.recordOfferCandidateOrder] requires this
  /// before treating `stage == clientInterviewPassed` as order-eligible.
  bool get hasGenuineInterviewRecord =>
      interviewRecord?.engineerId == engineerId &&
      interviewRecord?.projectId == projectId;

  PublicDemoOfferCandidate copyWith({
    PublicDemoOfferCandidateStage? stage,
    int? partnerScore,
    int? clientScore,
    PublicDemoOfferInterviewRecord? interviewRecord,
  }) => PublicDemoOfferCandidate(
    engineerId: engineerId,
    projectId: projectId,
    proposedMonth: proposedMonth,
    stage: stage ?? this.stage,
    partnerScore: partnerScore ?? this.partnerScore,
    clientScore: clientScore ?? this.clientScore,
    interviewRecord: interviewRecord ?? this.interviewRecord,
  );

  /// Applies the genuine outcome of a partner-interview attempt for this
  /// exact candidate — mirrors
  /// [PublicDemoEngineerSales.applyPartnerProjectInterviewResult] one
  /// authority level down (per candidate instead of per engineer). A no-op
  /// unless [stage] is currently [PublicDemoOfferCandidateStage.proposed].
  /// Never mints [interviewRecord] — reserved for a genuine CLIENT-
  /// interview pass only (see [hasGenuineInterviewRecord]'s own doc),
  /// mirroring the legacy pipeline's own partner/client asymmetry exactly.
  PublicDemoOfferCandidate applyPartnerInterviewResult({
    required bool passed,
    required int score,
  }) {
    if (stage != PublicDemoOfferCandidateStage.proposed) return this;
    return copyWith(
      stage: passed
          ? PublicDemoOfferCandidateStage.partnerInterviewPassed
          : PublicDemoOfferCandidateStage.partnerInterviewFailed,
      partnerScore: score,
    );
  }

  /// Applies the genuine outcome of a client-interview attempt for this
  /// exact candidate — mirrors
  /// [PublicDemoEngineerSales.applyProjectInterviewResult] one authority
  /// level down. A no-op unless [stage] is currently
  /// [PublicDemoOfferCandidateStage.partnerInterviewPassed]. Mints
  /// [interviewRecord] — bound to this candidate's own [engineerId]/
  /// [projectId] — only on a genuine pass; every other outcome updates
  /// [stage]/[clientScore] without touching it (this method's precondition
  /// already guarantees [interviewRecord] is `null` beforehand, since a
  /// candidate can reach `partnerInterviewPassed` only once per genuine
  /// client-interview attempt in this phase).
  PublicDemoOfferCandidate applyClientInterviewResult({
    required bool passed,
    required int score,
  }) {
    if (stage != PublicDemoOfferCandidateStage.partnerInterviewPassed) {
      return this;
    }
    return PublicDemoOfferCandidate(
      engineerId: engineerId,
      projectId: projectId,
      proposedMonth: proposedMonth,
      stage: passed
          ? PublicDemoOfferCandidateStage.clientInterviewPassed
          : PublicDemoOfferCandidateStage.clientInterviewFailed,
      partnerScore: partnerScore,
      clientScore: score,
      interviewRecord: passed
          ? PublicDemoOfferInterviewRecord._(
              engineerId: engineerId,
              projectId: projectId,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'engineerId': engineerId,
    'projectId': projectId,
    'proposedMonth': proposedMonth,
    'stage': stage.name,
    'partnerScore': partnerScore,
    'clientScore': clientScore,
    'interviewRecordEngineerId': interviewRecord?.engineerId,
    'interviewRecordProjectId': interviewRecord?.projectId,
  };

  factory PublicDemoOfferCandidate.fromJson(Map<String, dynamic> json) {
    T required<T>(String key) {
      final value = json[key];
      if (value is! T) throw FormatException('Invalid offer candidate $key');
      return value;
    }

    final engineerId = required<String>('engineerId');
    final projectId = required<String>('projectId');
    final stageName = required<String>('stage');
    final stage = PublicDemoOfferCandidateStage.values
        .where((value) => value.name == stageName)
        .firstOrNull;
    if (stage == null) {
      throw const FormatException('Invalid offer candidate stage');
    }
    final recordEngineerId = json['interviewRecordEngineerId'];
    final recordProjectId = json['interviewRecordProjectId'];
    if ((recordEngineerId == null) != (recordProjectId == null)) {
      throw const FormatException('Invalid offer candidate interview record');
    }
    if (recordEngineerId != null &&
        (recordEngineerId is! String || recordEngineerId != engineerId)) {
      throw const FormatException(
        'Invalid offer candidate interview record engineer',
      );
    }
    if (recordProjectId != null &&
        (recordProjectId is! String || recordProjectId != projectId)) {
      throw const FormatException(
        'Invalid offer candidate interview record project',
      );
    }
    return PublicDemoOfferCandidate(
      engineerId: engineerId,
      projectId: projectId,
      proposedMonth: required<int>('proposedMonth'),
      stage: stage,
      partnerScore: json['partnerScore'] as int?,
      clientScore: json['clientScore'] as int?,
      interviewRecord: recordEngineerId == null
          ? null
          : PublicDemoOfferInterviewRecord._(
              engineerId: recordEngineerId as String,
              projectId: recordProjectId as String,
            ),
    );
  }

  /// Legacy-save, load-time migration (PR #253's Codex review, P1):
  /// reconstructs the [PublicDemoOfferCandidate] genuinely implied by
  /// [engineer]'s own legacy [PublicDemoSalesStage] — see
  /// `PublicDemoWorkflowState._migrateLegacyOfferCandidates`'s own call-site
  /// doc (public_demo_workflow_state.dart) for exactly when this runs.
  /// Returns `null` when [engineer] has no project-specific in-flight state
  /// to recover: `waiting`/`skillSheet` (sales has not even started), or
  /// `selling` with no [proposal] on file (no project has been decided yet
  /// — see [PublicDemoOfferCandidateStage.proposed]'s own doc for why "no
  /// target picked" is not itself a candidate).
  ///
  /// Project id resolution priority — every branch is a REAL fact already
  /// on [engineer]/[proposal]/[orderedAssignmentProjectId], never
  /// fabricated, falling back only to the explicit compatibility path when
  /// none resolves:
  /// 1. [engineer]'s own genuine Phase 6/7 project-bound
  ///    `PublicDemoEngineerInterviewRecord.projectId` (the single most
  ///    specific real fact available — a project this engineer was
  ///    actually interviewed for).
  /// 2. The current [proposal]'s [PublicDemoMatchingProposal.projectId]
  ///    (Phase 5's own real record of what the player selected).
  /// 3. [orderedAssignmentProjectId] — an already-`ordered` engineer's own
  ///    real `PublicDemoAssignment.projectId`, when one exists (the caller
  ///    only ever supplies this for a genuinely `ordered` engineer).
  /// 4. [legacyCompatibilityProjectId] — PR #253's Codex review P1 finding:
  ///    a legacy in-flight/ordered engineer with no resolvable real project
  ///    (the fully generic, project-agnostic
  ///    `PublicDemoEngineerSales.evaluateInterview` path) still gets a
  ///    stable, non-colliding placeholder candidate rather than being
  ///    silently dropped.
  static PublicDemoOfferCandidate? migrateFromLegacyStage({
    required PublicDemoEngineerSales engineer,
    required PublicDemoMatchingProposal? proposal,
    required String? orderedAssignmentProjectId,
  }) {
    if (engineer.stage == PublicDemoSalesStage.waiting ||
        engineer.stage == PublicDemoSalesStage.skillSheet) {
      return null;
    }
    if (engineer.stage == PublicDemoSalesStage.selling && proposal == null) {
      return null;
    }

    final genuineProjectId = engineer.genuineInterviewProjectId;
    final projectId =
        genuineProjectId ??
        proposal?.projectId ??
        orderedAssignmentProjectId ??
        legacyCompatibilityProjectId(engineer.id);

    final PublicDemoOfferCandidateStage stage;
    switch (engineer.stage) {
      case PublicDemoSalesStage.selling:
      case PublicDemoSalesStage.introduced:
        stage = PublicDemoOfferCandidateStage.proposed;
      case PublicDemoSalesStage.partnerInterviewPassed:
        stage = PublicDemoOfferCandidateStage.partnerInterviewPassed;
      case PublicDemoSalesStage.partnerInterviewFailed:
        stage = PublicDemoOfferCandidateStage.partnerInterviewFailed;
      case PublicDemoSalesStage.clientInterviewPassed:
        stage = PublicDemoOfferCandidateStage.clientInterviewPassed;
      case PublicDemoSalesStage.clientInterviewFailed:
        stage = PublicDemoOfferCandidateStage.clientInterviewFailed;
      case PublicDemoSalesStage.ordered:
        stage = PublicDemoOfferCandidateStage.ordered;
      case PublicDemoSalesStage.waiting:
      case PublicDemoSalesStage.skillSheet:
        // Excluded by the early-return above.
        throw StateError('unreachable public demo sales stage');
    }

    final isGenuineClientPassOrOrdered =
        engineer.stage == PublicDemoSalesStage.clientInterviewPassed ||
        engineer.stage == PublicDemoSalesStage.ordered;
    final interviewRecord =
        engineer.hasGenuineInterviewRecord && isGenuineClientPassOrOrdered
        ? PublicDemoOfferInterviewRecord._(
            engineerId: engineer.id,
            projectId: projectId,
          )
        : null;

    final partnerScore =
        engineer.stage == PublicDemoSalesStage.partnerInterviewPassed ||
            engineer.stage == PublicDemoSalesStage.partnerInterviewFailed
        ? engineer.lastInterviewScore
        : null;
    final clientScore =
        engineer.stage == PublicDemoSalesStage.clientInterviewPassed ||
            engineer.stage == PublicDemoSalesStage.clientInterviewFailed ||
            engineer.stage == PublicDemoSalesStage.ordered
        ? engineer.lastInterviewScore
        : null;

    return PublicDemoOfferCandidate(
      engineerId: engineer.id,
      projectId: projectId,
      proposedMonth: proposal?.decidedMonth ?? 0,
      stage: stage,
      partnerScore: partnerScore,
      clientScore: clientScore,
      interviewRecord: interviewRecord,
    );
  }
}
