import 'public_demo_interview.dart';

/// Issue #245 Finding #4, Phase 1a (Domain Foundation): the lifecycle a
/// single (engineerId, projectId) offer candidate moves through.
///
/// Deliberately mirrors [PublicDemoSalesStage]'s own naming
/// (`public_demo_sales.dart`) one-for-one for the partner/client interview
/// steps — this is the same real gameplay meaning, just kept per-candidate
/// instead of per-engineer — plus one new terminal value, [declined], that
/// has no per-engineer equivalent today because today's authority never
/// needed to represent "one of several concluded candidates was not
/// chosen".
enum PublicDemoOfferCandidateStage {
  /// The player proposed this engineer for this project. Entry stage for
  /// every candidate — see [PublicDemoOfferCandidate.propose].
  proposed,
  partnerInterviewPassed,
  partnerInterviewFailed,
  clientInterviewPassed,
  clientInterviewFailed,

  /// The player explicitly chose this candidate to receive the order. See
  /// [PublicDemoOfferCandidate.markOrdered]'s own doc for why this is
  /// intentionally a fact about the *candidate* only, never about
  /// [PublicDemoWorkflowState.assignments] — `ordered != assigned` is
  /// preserved exactly as it is for [PublicDemoSalesStage.ordered] today.
  ordered,

  /// This candidate was closed without an order — either the player
  /// declined it directly, or a sibling candidate for the same engineer was
  /// ordered instead (see
  /// [PublicDemoWorkflowState.recordOfferCandidateOrder]). Terminal: once
  /// declined, a candidate never re-opens under this same
  /// (engineerId, projectId) identity (see [PublicDemoOfferCandidate.decline]).
  declined,
}

/// Authoritative, unforgeable proof that a specific
/// (engineerId, projectId) candidate actually passed a genuine client
/// interview — the exact same "mint only from a real evaluation, never
/// from a caller-asserted outcome" contract as
/// [PublicDemoEngineerInterviewRecord] (`public_demo_sales.dart`),
/// generalized from a single `engineerId` key to the
/// (engineerId, projectId) composite key this Finding #4 design needs.
///
/// Constructor private to this file: only
/// [PublicDemoOfferCandidate.evaluateClientInterview] (a genuine pass) and
/// [PublicDemoOfferCandidate.fromLegacyEngineerState] (the one-time,
/// load-time migration path — never a live gameplay path, see its own doc)
/// can mint one, and always bound to that exact candidate's own
/// `(engineerId, projectId)` pair.
class PublicDemoOfferInterviewRecord {
  const PublicDemoOfferInterviewRecord._({
    required this.engineerId,
    required this.projectId,
  });

  /// The engineer this client-interview pass was actually recorded for.
  final String engineerId;

  /// The project this client-interview pass was actually recorded for.
  final String projectId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PublicDemoOfferInterviewRecord &&
          other.engineerId == engineerId &&
          other.projectId == projectId);

  @override
  int get hashCode => Object.hash(engineerId, projectId);
}

/// Issue #245 Finding #4, Phase 1a (Domain Foundation): one candidate offer
/// — a single (engineerId, projectId) pair, tracked independently of every
/// other candidate for the same engineer or the same project.
///
/// This is the domain model the SSOT design
/// (`docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md`, "Recommended
/// design") calls for so that, in a later phase, one engineer can hold
/// concluded interview results for several projects at once, compare them,
/// and order exactly one while the others are explicitly declined.
///
/// Phase 1a scope only: this class and
/// [PublicDemoWorkflowState.offerCandidates] are purely additive. Nothing
/// in production code reads or writes this list yet —
/// [PublicDemoEngineerSales.stage]/`matchingProposals`/
/// `projectInterviewSessions`/`assignOrderedForMay`/`recordOrder` remain the
/// sole authority for actual gameplay in this phase, completely unchanged.
/// A later phase (Phase 1b, per the SSOT's own phase split) is what cuts
/// those callers over to read this list instead.
///
/// Identity is deliberately never a caller-supplied or independently
/// stored field: [id] is *always* derived from [engineerId]/[projectId],
/// so an (engineerId, projectId) mismatch against a stored identity string
/// simply cannot be represented — there is no field to forge or desync.
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

  /// The engineer this candidate is for. Immutable — there is no rebinding
  /// of an existing candidate to a different engineer; a caller wanting a
  /// different engineer creates a different candidate (a different
  /// (engineerId, projectId) pair, and therefore a different [id]).
  final String engineerId;

  /// The real Phase 4/5 project id this candidate is for. Immutable, same
  /// rationale as [engineerId].
  final String projectId;

  /// The internal month the player first proposed this candidate, for
  /// display/ordering only — not read by any eligibility/authority check,
  /// exactly like [PublicDemoMatchingProposal.decidedMonth]
  /// (`public_demo_matching_proposal.dart`).
  final int proposedMonth;

  final PublicDemoOfferCandidateStage stage;

  /// The most recent partner-interview score for this candidate, or `null`
  /// if a partner interview has never concluded for it. Not authoritative
  /// proof of anything by itself (mirrors
  /// [PublicDemoEngineerSales.lastInterviewScore]'s own doc) — [stage] is
  /// the source of truth for where this candidate currently stands.
  final int? partnerScore;

  /// The most recent client-interview score for this candidate, or `null`.
  /// Same caveat as [partnerScore].
  final int? clientScore;

  /// Authoritative, unforgeable proof this exact (engineerId, projectId)
  /// candidate genuinely passed a client interview — see
  /// [PublicDemoOfferInterviewRecord]'s own doc. A future Phase 1b's
  /// order/assignment cutover must gate eligibility on this identity check
  /// (`hasGenuineInterviewRecord`), never on [stage] alone, exactly as
  /// [PublicDemoEngineerSales.hasGenuineInterviewRecord] already does today.
  final PublicDemoOfferInterviewRecord? interviewRecord;

  /// Stable composite identity, always derived — never independently
  /// stored, and therefore never settable to a value that disagrees with
  /// [engineerId]/[projectId] (see this class's own doc on why "identity
  /// mismatch" is structurally impossible here rather than merely
  /// validated).
  String get id => '$engineerId::$projectId';

  /// Whether this candidate genuinely passed its own client interview —
  /// checked by identity, not just presence, mirroring
  /// [PublicDemoEngineerSales.hasGenuineInterviewRecord] exactly, one level
  /// more specific (engineer AND project, not engineer alone).
  bool get hasGenuineInterviewRecord =>
      interviewRecord != null &&
      interviewRecord!.engineerId == engineerId &&
      interviewRecord!.projectId == projectId;

  /// A terminal state never revisited by this class's own transitions: once
  /// [ordered], nothing here changes it again ([markOrdered] and [decline]
  /// are both no-ops); once [declined], only re-proposing a *new* candidate
  /// (a fresh [propose] call, e.g. after
  /// [PublicDemoWorkflowState.recordOfferCandidateOrder] closes a sibling)
  /// creates further history for this (engineerId, projectId) pair.
  bool get isTerminal =>
      stage == PublicDemoOfferCandidateStage.ordered ||
      stage == PublicDemoOfferCandidateStage.declined;

  /// The entry point for a brand-new candidate — the domain analogue of
  /// [PublicDemoMatchingProposal]'s own "提案する" decision, generalized to
  /// coexist with sibling candidates for other projects.
  factory PublicDemoOfferCandidate.propose({
    required String engineerId,
    required String projectId,
    required int proposedMonth,
  }) => PublicDemoOfferCandidate(
    engineerId: engineerId,
    projectId: projectId,
    proposedMonth: proposedMonth,
  );

  /// Builds a candidate directly from legacy authority's own current
  /// [PublicDemoEngineerSales.stage]/`interviewRecord` facts — originally a
  /// one-time, load-time-only migration path for a save written before
  /// [PublicDemoWorkflowState.offerCandidates] existed (see the SSOT
  /// design's own "Backward compatibility / migration plan" section), now
  /// also used, via [PublicDemoWorkflowState._offerCandidateFromLegacy], by
  /// [PublicDemoWorkflowState._reconcileOfferCandidates] (Phase 1b's own
  /// real, repeatable reconciliation — replacing the one-shot version this
  /// factory originally served) AND by
  /// [PublicDemoWorkflowState.withMatchingProposal] itself (Phase 1b
  /// Production Cutover): a brand-new candidate is seeded at legacy
  /// authority's CURRENT stage rather than always the bare `proposed` entry
  /// point, so a freshly-visible candidate for an engineer whose coarse
  /// stage already outranks `proposed` (a partner pass/fail minted through
  /// the legacy, project-agnostic path before this exact project was ever
  /// proposed) is never left transiently behind the engineer it belongs to.
  /// Deliberately mints a fresh [PublicDemoOfferInterviewRecord] bound to this
  /// candidate's own (engineerId, projectId) whenever
  /// [hasGenuineInterviewRecord] is true, rather than attempting to reuse
  /// the legacy record's own (possibly project-`null`, generic-path)
  /// identity verbatim — [hasGenuineInterviewRecord] is the ground truth
  /// signal a genuine pass occurred at all; which real project it is
  /// attributed to comes from the caller's own already-authoritative
  /// resolution (the engineer's matching proposal, or its assignment's
  /// project id for an already-ordered engineer), exactly as the SSOT
  /// design specifies.
  factory PublicDemoOfferCandidate.fromLegacyEngineerState({
    required String engineerId,
    required String projectId,
    required int proposedMonth,
    required PublicDemoOfferCandidateStage stage,
    int? partnerScore,
    int? clientScore,
    required bool hasGenuineInterviewRecord,
  }) => PublicDemoOfferCandidate(
    engineerId: engineerId,
    projectId: projectId,
    proposedMonth: proposedMonth,
    stage: stage,
    partnerScore: partnerScore,
    clientScore: clientScore,
    interviewRecord: hasGenuineInterviewRecord
        ? PublicDemoOfferInterviewRecord._(
            engineerId: engineerId,
            projectId: projectId,
          )
        : null,
  );

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

  /// Attempts (or retries, after a prior failure) this candidate's own
  /// partner interview — reuses [PublicDemoInterviewEvaluator] verbatim (no
  /// formula change, per this Finding's own "Matching式変更禁止" guardrail).
  /// A no-op unless [stage] is currently [PublicDemoOfferCandidateStage
  /// .proposed] or [PublicDemoOfferCandidateStage.partnerInterviewFailed] —
  /// mirrors [PublicDemoEngineerSales.evaluateInterview]'s own
  /// "derive, never accept, the outcome" contract: [actualCapability] is the
  /// only caller-supplied signal, never `passed`/`score` directly.
  PublicDemoOfferCandidate evaluatePartnerInterview({
    required PublicDemoInterviewProfile profile,
    int? actualCapability,
  }) {
    if (stage != PublicDemoOfferCandidateStage.proposed &&
        stage != PublicDemoOfferCandidateStage.partnerInterviewFailed) {
      return this;
    }
    final result = PublicDemoInterviewEvaluator.evaluate(
      type: PublicDemoInterviewType.partner,
      profile: profile,
      actualCapability: actualCapability,
    );
    return copyWith(
      stage: result.passed
          ? PublicDemoOfferCandidateStage.partnerInterviewPassed
          : PublicDemoOfferCandidateStage.partnerInterviewFailed,
      partnerScore: result.score,
    );
  }

  /// Attempts (or retries, after a prior failure) this candidate's own
  /// client interview. Same contract as [evaluatePartnerInterview] one
  /// stage later; mints [interviewRecord] only on a genuine pass, exactly
  /// mirroring [PublicDemoEngineerSales.evaluateInterview]'s own client
  /// branch. A no-op unless [stage] is currently
  /// [PublicDemoOfferCandidateStage.partnerInterviewPassed] or
  /// [PublicDemoOfferCandidateStage.clientInterviewFailed].
  PublicDemoOfferCandidate evaluateClientInterview({
    required PublicDemoInterviewProfile profile,
    int? actualCapability,
  }) {
    if (stage != PublicDemoOfferCandidateStage.partnerInterviewPassed &&
        stage != PublicDemoOfferCandidateStage.clientInterviewFailed) {
      return this;
    }
    final result = PublicDemoInterviewEvaluator.evaluate(
      type: PublicDemoInterviewType.client,
      profile: profile,
      actualCapability: actualCapability,
    );
    return copyWith(
      stage: result.passed
          ? PublicDemoOfferCandidateStage.clientInterviewPassed
          : PublicDemoOfferCandidateStage.clientInterviewFailed,
      clientScore: result.score,
      interviewRecord: result.passed
          ? PublicDemoOfferInterviewRecord._(
              engineerId: engineerId,
              projectId: projectId,
            )
          : null,
    );
  }

  /// The only way a candidate reaches [PublicDemoOfferCandidateStage
  /// .ordered]. A no-op unless [stage] is currently
  /// [PublicDemoOfferCandidateStage.clientInterviewPassed] AND
  /// [hasGenuineInterviewRecord] holds — the same defense-in-depth pairing
  /// [PublicDemoWorkflowState.recordOrder] already uses today (required
  /// stage, checked here too, never trusted from a caller-supplied stage
  /// alone). Deliberately does not touch
  /// [PublicDemoWorkflowState.assignments] — `ordered != assigned` is
  /// preserved exactly: materializing an actual assignment remains solely
  /// [PublicDemoWorkflowState.assignOrderedForMay]/
  /// [PublicDemoWorkflowState.recoverLateYearAssignment]'s job, in whichever
  /// later phase wires this candidate list into that eligibility check.
  /// Safe to call again once already [PublicDemoOfferCandidateStage
  /// .ordered] — a no-op, not an error (idempotent terminal re-entry).
  PublicDemoOfferCandidate markOrdered() {
    if (stage != PublicDemoOfferCandidateStage.clientInterviewPassed ||
        !hasGenuineInterviewRecord) {
      return this;
    }
    return copyWith(stage: PublicDemoOfferCandidateStage.ordered);
  }

  /// Closes this candidate without an order — either a direct player
  /// decision, or the automatic sibling-close
  /// [PublicDemoWorkflowState.recordOfferCandidateOrder] performs when a
  /// *different* candidate for the same engineer is ordered instead. A
  /// no-op once already [PublicDemoOfferCandidateStage.ordered] (an order is
  /// final; it is never retroactively declined) — safe to call again once
  /// already [PublicDemoOfferCandidateStage.declined] too (idempotent
  /// terminal re-entry, mirroring [markOrdered]'s own contract).
  PublicDemoOfferCandidate decline() {
    if (stage == PublicDemoOfferCandidateStage.ordered ||
        stage == PublicDemoOfferCandidateStage.declined) {
      return this;
    }
    return copyWith(stage: PublicDemoOfferCandidateStage.declined);
  }

  /// Phase 1b (Production Cutover): applies an ALREADY-COMPUTED partner
  /// interview outcome to this candidate — never a second, independent
  /// evaluation. The sole production caller is
  /// [PublicDemoWorkflowState.concludePartnerProjectInterview] (the
  /// interactive Partner Interview engine), which derives [passed]/[score]
  /// from one real [PublicDemoProjectInterview.conclude] call already made
  /// for the engineer-level pipeline in that same method — mirrors
  /// [PublicDemoEngineerSales.applyPartnerProjectInterviewResult] exactly
  /// (same "reuse, never fork, the interview engine" contract), one level
  /// down. The legacy, project-agnostic
  /// [PublicDemoWorkflowState.recordEngineerInterviewResult] path has no
  /// project identity to sync a candidate against, and deliberately does
  /// not call this. A no-op unless [stage] is currently
  /// [PublicDemoOfferCandidateStage.proposed] or [PublicDemoOfferCandidateStage
  /// .partnerInterviewFailed] — same precondition as
  /// [evaluatePartnerInterview].
  PublicDemoOfferCandidate applyPartnerInterviewResult({
    required bool passed,
    required int score,
  }) {
    if (stage != PublicDemoOfferCandidateStage.proposed &&
        stage != PublicDemoOfferCandidateStage.partnerInterviewFailed) {
      return this;
    }
    return copyWith(
      stage: passed
          ? PublicDemoOfferCandidateStage.partnerInterviewPassed
          : PublicDemoOfferCandidateStage.partnerInterviewFailed,
      partnerScore: score,
    );
  }

  /// The client-interview counterpart of [applyPartnerInterviewResult] — see
  /// its own doc for the "apply an already-computed outcome, never
  /// re-evaluate" contract. Mints [interviewRecord] only on a genuine pass,
  /// mirroring [PublicDemoEngineerSales.applyProjectInterviewResult] exactly.
  /// A no-op unless [stage] is currently [PublicDemoOfferCandidateStage
  /// .partnerInterviewPassed] or [PublicDemoOfferCandidateStage
  /// .clientInterviewFailed] — same precondition as [evaluateClientInterview].
  PublicDemoOfferCandidate applyClientInterviewResult({
    required bool passed,
    required int score,
  }) {
    if (stage != PublicDemoOfferCandidateStage.partnerInterviewPassed &&
        stage != PublicDemoOfferCandidateStage.clientInterviewFailed) {
      return this;
    }
    return copyWith(
      stage: passed
          ? PublicDemoOfferCandidateStage.clientInterviewPassed
          : PublicDemoOfferCandidateStage.clientInterviewFailed,
      clientScore: score,
      interviewRecord: passed
          ? PublicDemoOfferInterviewRecord._(
              engineerId: engineerId,
              projectId: projectId,
            )
          : null,
    );
  }

  /// Phase 1b (Production Cutover) one-time reconciliation upgrade: brings
  /// this ALREADY-EXISTING candidate's own stage/score/record up to date
  /// with legacy authority's own facts for this exact (engineerId,
  /// projectId) pair, for the one case legacy authority has genuinely
  /// progressed further than this candidate's own stage. Unlike
  /// [fromLegacyEngineerState] (which builds a brand-new candidate from
  /// scratch when none exists yet), this starts from this candidate's own
  /// existing [partnerScore]/[clientScore] (preserved via `?? this.field`
  /// when the legacy value passed is `null`) and mints a fresh
  /// [interviewRecord] bound to this exact identity only when
  /// [hasGenuineInterviewRecord] is true — exactly like
  /// [fromLegacyEngineerState]'s own record-minting contract.
  ///
  /// Callers (see
  /// [PublicDemoWorkflowState._reconcileOfferCandidates]) are responsible
  /// for only ever calling this when legacy authority's stage genuinely
  /// outranks this candidate's own current stage — this method itself does
  /// not re-check that ordering, so it must never be called to rewind a
  /// candidate that is already ahead of (or terminal relative to) legacy
  /// authority.
  PublicDemoOfferCandidate upgradeFromLegacy({
    required PublicDemoOfferCandidateStage stage,
    int? partnerScore,
    int? clientScore,
    required bool hasGenuineInterviewRecord,
  }) => copyWith(
    stage: stage,
    partnerScore: partnerScore,
    clientScore: clientScore,
    interviewRecord: hasGenuineInterviewRecord
        ? PublicDemoOfferInterviewRecord._(
            engineerId: engineerId,
            projectId: projectId,
          )
        : interviewRecord,
  );

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
    if (engineerId.isEmpty || projectId.isEmpty) {
      throw const FormatException('Invalid offer candidate identity');
    }
    final stageName = required<String>('stage');
    final stage = PublicDemoOfferCandidateStage.values
        .where((value) => value.name == stageName)
        .firstOrNull;
    if (stage == null) {
      throw const FormatException('Invalid offer candidate stage');
    }
    final recordEngineerId = json['interviewRecordEngineerId'];
    final recordProjectId = json['interviewRecordProjectId'];
    if ((recordEngineerId != null && recordEngineerId is! String) ||
        (recordProjectId != null && recordProjectId is! String)) {
      throw const FormatException('Invalid offer candidate interview record');
    }
    // Unforgeable identity, enforced on load (mirrors
    // PublicDemoEngineerSales.fromJson's own `recordId != id` guard,
    // generalized to the composite key): a record for this candidate must
    // be bound to this exact (engineerId, projectId) pair, both present or
    // both absent — never partially bound, never bound to a different pair.
    final hasRecordEngineerId = recordEngineerId != null;
    final hasRecordProjectId = recordProjectId != null;
    if (hasRecordEngineerId != hasRecordProjectId) {
      throw const FormatException(
        'Invalid offer candidate interview record identity',
      );
    }
    if (hasRecordEngineerId &&
        (recordEngineerId != engineerId || recordProjectId != projectId)) {
      throw const FormatException(
        'Invalid offer candidate interview record identity',
      );
    }
    return PublicDemoOfferCandidate(
      engineerId: engineerId,
      projectId: projectId,
      proposedMonth: required<int>('proposedMonth'),
      stage: stage,
      partnerScore: json['partnerScore'] as int?,
      clientScore: json['clientScore'] as int?,
      interviewRecord: hasRecordEngineerId
          ? PublicDemoOfferInterviewRecord._(
              engineerId: recordEngineerId as String,
              projectId: recordProjectId as String,
            )
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PublicDemoOfferCandidate &&
          other.engineerId == engineerId &&
          other.projectId == projectId &&
          other.proposedMonth == proposedMonth &&
          other.stage == stage &&
          other.partnerScore == partnerScore &&
          other.clientScore == clientScore &&
          other.interviewRecord == interviewRecord);

  @override
  int get hashCode => Object.hash(
    engineerId,
    projectId,
    proposedMonth,
    stage,
    partnerScore,
    clientScore,
    interviewRecord,
  );
}
