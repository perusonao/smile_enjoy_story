import 'public_demo_interview.dart';
import 'public_demo_recruitment.dart';

enum PublicDemoSalesStage {
  waiting,
  skillSheet,
  selling,
  introduced,
  partnerInterviewFailed,
  partnerInterviewPassed,
  clientInterviewFailed,
  clientInterviewPassed,
  ordered,
}

/// Authoritative, unforgeable proof that a specific engineer actually
/// passed a genuine client interview through
/// [PublicDemoEngineerSales.evaluateInterview] (WORKFLOW-STATE-1AB FIX6 P1,
/// FIX7 P2).
///
/// Constructor private to this file: only [PublicDemoEngineerSales
/// .evaluateInterview] — called exclusively by
/// [PublicDemoWorkflowState.recordEngineerInterviewResult]
/// (public_demo_workflow_state.dart), itself called only by
/// [PublicDemoAggregate.recordEngineerInterviewResult]
/// (public_demo_aggregate.dart) — can mint one, bound to that engineer's
/// own id, and only after [evaluateInterview] has itself verified the
/// required current stage and run a real
/// [PublicDemoInterviewEvaluator.evaluate] pass (WORKFLOW-STATE-1AB FIX7
/// P2: `evaluateInterview` no longer accepts `passed`/`score` as
/// parameters — a caller can request an interview attempt but cannot
/// assert its outcome). `stage == PublicDemoSalesStage.ordered` and
/// `lastInterviewScore != null` are NOT proof by themselves: both fields
/// remain publicly settable via [PublicDemoEngineerSales.copyWith] (a value
/// object needs that for [evaluateInterview] itself to work), but doing so
/// does not also produce a genuine [PublicDemoEngineerInterviewRecord] —
/// [PublicDemoWorkflowState.assignOrderedForMay] gates assignment
/// eligibility on this record's identity, not on
/// `stage`/`lastInterviewScore` alone (mirrors
/// [PublicDemoInterviewRecord]/[PublicDemoApplicant.hasBeenInterviewed] in
/// public_demo_recruitment.dart).
class PublicDemoEngineerInterviewRecord {
  const PublicDemoEngineerInterviewRecord._({
    required this.engineerId,
    this.projectId,
  });

  /// The engineer this client-interview pass was actually recorded for.
  /// Checked for identity match, not just presence — a genuine record
  /// reused across engineers via `copyWith` is rejected the same way a
  /// reused [PublicDemoBindingOffer] is (WORKFLOW-STATE-1AB FIX1 P1-1D).
  final String engineerId;

  /// The real Phase 4/5 [Project] id this pass was actually interviewed
  /// for (Codex P1-2 fix, PR #214) — `null` for a pass minted by the
  /// generic, project-agnostic [PublicDemoEngineerSales.evaluateInterview]
  /// path (which has no project concept at all), non-`null` only for a
  /// genuine [PublicDemoEngineerSales.applyProjectInterviewResult] pass
  /// (CORE-GAMEPLAY Phase 6). This is the single fact that lets
  /// [PublicDemoWorkflowState.withMatchingProposal] refuse to silently
  /// re-bind an already-passed engineer to a different, never-interviewed
  /// project, and lets [PublicDemoSaveCodec] tell a genuinely stochastic
  /// Phase 6 pass (any score in `[5, 95]`) apart from a legacy
  /// threshold-evaluated one (`score >= 60` always) on reload.
  final String? projectId;
}

class PublicDemoEngineerSales {
  const PublicDemoEngineerSales({
    required this.id,
    required this.name,
    required this.summary,
    required this.interviewProfile,
    this.stage = PublicDemoSalesStage.waiting,
    this.lastInterviewScore,
    this.interviewRecord,
    this.mental = 50,
    this.trust = 50,
    this.founderFollowUpMonth,
  });

  final String id;
  final String name;
  final String summary;
  final PublicDemoInterviewProfile interviewProfile;
  final PublicDemoSalesStage stage;
  final int? lastInterviewScore;

  /// Authoritative, unforgeable proof this engineer actually passed a
  /// genuine client interview — see [PublicDemoEngineerInterviewRecord]
  /// (WORKFLOW-STATE-1AB FIX6 P1).
  final PublicDemoEngineerInterviewRecord? interviewRecord;
  final int mental;
  final int trust;

  /// One-time guard for Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1's
  /// founder follow-up decision (`PublicDemoFounderFollowUp` in
  /// public_demo_founder_follow_up.dart): the internal month this engineer's
  /// decision was made, or `null` if it has not happened yet this fiscal
  /// year. Absent on any save written before this field existed —
  /// `fromJson` defaults it to `null`, reproducing exactly the
  /// not-yet-decided state those saves already had.
  final int? founderFollowUpMonth;

  /// Public Demo currently uses the existing morale value as the
  /// Motivation-equivalent, matching the shared Engineer model semantics.
  int get motivation => interviewProfile.morale;

  /// Whether this engineer genuinely passed a client interview — checked by
  /// identity, not just presence (WORKFLOW-STATE-1AB FIX6 P1, mirrors
  /// [PublicDemoApplicant.hasBeenInterviewed]).
  /// [PublicDemoWorkflowState.assignOrderedForMay] requires this before it
  /// will treat `stage == ordered` as eligible for an assignment.
  bool get hasGenuineInterviewRecord => interviewRecord?.engineerId == id;

  /// The real project id a genuine Phase 6 project-interview pass is bound
  /// to (Codex P1-2 fix, PR #214) — `null` when there is no genuine record
  /// at all, or when the genuine record is the generic, project-agnostic
  /// [evaluateInterview] path's own kind (see
  /// [PublicDemoEngineerInterviewRecord.projectId]'s own doc). Only ever
  /// non-`null` via [hasGenuineInterviewRecord] already holding.
  String? get genuineInterviewProjectId =>
      hasGenuineInterviewRecord ? interviewRecord?.projectId : null;

  /// Post-join employees use the same sales flow. Their changing capability
  /// is read from the runtime at evaluation time, not stored here.
  factory PublicDemoEngineerSales.fromApplicant(
    PublicDemoApplicant applicant,
  ) => PublicDemoEngineerSales(
    id: applicant.id,
    name: applicant.name,
    summary: applicant.resumeSummary,
    interviewProfile: PublicDemoInterviewProfile(
      skillFit: applicant.salesSkillFit,
      humanity: 60,
      morale: applicant.employeeMorale ?? 50,
      clientTrust: 50,
    ),
  );

  PublicDemoEngineerSales copyWith({
    PublicDemoSalesStage? stage,
    int? lastInterviewScore,
    PublicDemoEngineerInterviewRecord? interviewRecord,
    int? mental,
    int? trust,
    int? founderFollowUpMonth,
  }) => PublicDemoEngineerSales(
    id: id,
    name: name,
    summary: summary,
    interviewProfile: interviewProfile,
    stage: stage ?? this.stage,
    lastInterviewScore: lastInterviewScore ?? this.lastInterviewScore,
    interviewRecord: interviewRecord ?? this.interviewRecord,
    mental: mental ?? this.mental,
    trust: trust ?? this.trust,
    founderFollowUpMonth: founderFollowUpMonth ?? this.founderFollowUpMonth,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'summary': summary,
    'interviewProfile': {
      'skillFit': interviewProfile.skillFit,
      'humanity': interviewProfile.humanity,
      'morale': interviewProfile.morale,
      'clientTrust': interviewProfile.clientTrust,
    },
    'stage': stage.name,
    'lastInterviewScore': lastInterviewScore,
    'interviewRecordEngineerId': interviewRecord?.engineerId,
    // Additive (Codex P1-2 fix, PR #214): see
    // [PublicDemoEngineerInterviewRecord.projectId]'s own doc. `null` for
    // every record minted before this fix, and for every generic-path
    // record minted since — never fabricated on encode.
    'interviewRecordProjectId': interviewRecord?.projectId,
    'mental': mental,
    'trust': trust,
    'founderFollowUpMonth': founderFollowUpMonth,
  };

  factory PublicDemoEngineerSales.fromJson(Map<String, dynamic> json) {
    T required<T>(String key) {
      final value = json[key];
      if (value is! T) throw FormatException('Invalid engineer $key');
      return value;
    }

    final id = required<String>('id');
    final stageName = required<String>('stage');
    final stage = PublicDemoSalesStage.values.where((value) => value.name == stageName).firstOrNull;
    final profileRaw = required<Map>('interviewProfile');
    final profile = profileRaw.cast<String, dynamic>();
    final recordId = json['interviewRecordEngineerId'];
    // Additive (Codex P1-2 fix, PR #214): absent on any save written before
    // this fix — `null` there, exactly reproducing the generic-path
    // semantics every such record already had (see
    // [PublicDemoEngineerInterviewRecord.projectId]'s own doc).
    final recordProjectId = json['interviewRecordProjectId'];
    if (stage == null || (recordId != null && recordId is! String) ||
        (recordId != null && recordId != id) ||
        (recordProjectId != null && recordProjectId is! String)) {
      throw const FormatException('Invalid engineer persistence data');
    }
    int profileValue(String key) {
      final value = profile[key];
      if (value is! int) throw FormatException('Invalid interview profile $key');
      return value;
    }
    return PublicDemoEngineerSales(
      id: id,
      name: required<String>('name'),
      summary: required<String>('summary'),
      interviewProfile: PublicDemoInterviewProfile(
        skillFit: profileValue('skillFit'),
        humanity: profileValue('humanity'),
        morale: profileValue('morale'),
        clientTrust: profileValue('clientTrust'),
      ),
      stage: stage,
      lastInterviewScore: json['lastInterviewScore'] as int?,
      interviewRecord: recordId == null
          ? null
          : PublicDemoEngineerInterviewRecord._(
              engineerId: recordId,
              projectId: recordProjectId as String?,
            ),
      mental: required<int>('mental'),
      trust: required<int>('trust'),
      founderFollowUpMonth: json['founderFollowUpMonth'] as int?,
    );
  }

  /// The single sanctioned way to attempt a genuine partner/client
  /// interview for this engineer's sales pipeline (WORKFLOW-STATE-1AB FIX7
  /// P2, replacing `recordInterviewOutcome`, which accepted `passed`/
  /// `score` as direct parameters — a production caller could supply
  /// `type: client, passed: true, score: 80` with no actual evaluation
  /// behind them at all, minting a genuine-looking
  /// [PublicDemoEngineerInterviewRecord] with no genuine interview having
  /// occurred).
  ///
  /// [actualCapability] is the only caller-supplied signal — an
  /// interview-time skill reading, not an outcome assertion. Everything
  /// else is derived here, from this engineer's own [stage] and
  /// [interviewProfile]:
  ///
  /// - A no-op unless [stage] already equals the one [type] requires
  ///   (`introduced` for partner, `partnerInterviewPassed` for client) —
  ///   checked here too, defense in depth alongside
  ///   [PublicDemoWorkflowState.recordEngineerInterviewResult] and
  ///   [PublicDemoAggregate.recordEngineerInterviewResult]
  ///   (public_demo_workflow_state.dart / public_demo_aggregate.dart), the
  ///   only production callers — so this cannot be used to skip the
  ///   partner interview and mint a client-interview pass directly.
  /// - The resulting stage/score come from a real
  ///   [PublicDemoInterviewEvaluator.evaluate] call; `passed`/`score` are
  ///   never accepted as parameters, so no caller can assert either
  ///   directly.
  /// - Mints [PublicDemoEngineerInterviewRecord] — bound to this engineer's
  ///   own id — only when [type] is [PublicDemoInterviewType.client] and
  ///   the evaluation genuinely passed; every other outcome updates
  ///   `stage`/`lastInterviewScore` without touching [interviewRecord].
  PublicDemoEngineerSales evaluateInterview({
    required PublicDemoInterviewType type,
    required int actualCapability,
  }) {
    final requiredStage = type == PublicDemoInterviewType.partner
        ? PublicDemoSalesStage.introduced
        : PublicDemoSalesStage.partnerInterviewPassed;
    if (stage != requiredStage) return this;

    final result = PublicDemoInterviewEvaluator.evaluate(
      type: type,
      profile: interviewProfile,
      actualCapability: actualCapability,
    );
    final nextStage = switch ((type, result.passed)) {
      (PublicDemoInterviewType.partner, true) =>
        PublicDemoSalesStage.partnerInterviewPassed,
      (PublicDemoInterviewType.partner, false) =>
        PublicDemoSalesStage.partnerInterviewFailed,
      (PublicDemoInterviewType.client, true) =>
        PublicDemoSalesStage.clientInterviewPassed,
      (PublicDemoInterviewType.client, false) =>
        PublicDemoSalesStage.clientInterviewFailed,
    };
    final passedClientInterview =
        type == PublicDemoInterviewType.client && result.passed;
    return copyWith(
      stage: nextStage,
      lastInterviewScore: result.score,
      interviewRecord: passedClientInterview
          ? PublicDemoEngineerInterviewRecord._(engineerId: id)
          : null,
    );
  }

  /// CORE-GAMEPLAY Phase 6 (Project Interview Gameplay): applies the
  /// genuine outcome of the interactive project interview
  /// (`public_demo_project_interview.dart`) to this engineer's sales
  /// pipeline — the richer, real-[Project]-driven replacement for
  /// [evaluateInterview]'s generic [PublicDemoInterviewEvaluator] formula
  /// at this same `partnerInterviewPassed` → client-interview stage.
  /// Structurally mirrors [evaluateInterview]: the same stage precondition
  /// gate, and [interviewRecord] is minted only on a genuine pass, never on
  /// [stage]/`lastInterviewScore` alone (see [hasGenuineInterviewRecord]'s
  /// own doc).
  ///
  /// [passed]/[score] are never caller-asserted outcomes with no real
  /// interview behind them: this method's only production call site is
  /// [PublicDemoWorkflowState.concludeProjectInterview], which computes
  /// both from a fresh [PublicDemoProjectInterview.conclude] call —
  /// [ClientInterviewEngine.finalRate] (fit + choices + trust/track record)
  /// rolled through [ProjectInterviewEngine.roll]'s seeded RNG — made
  /// immediately before calling this, and only after verifying a genuine,
  /// fully-answered session exists. A no-op unless [stage] already equals
  /// [PublicDemoSalesStage.partnerInterviewPassed].
  ///
  /// [projectId] (Codex P1-2 fix, PR #214) is the real Phase 4/5 project
  /// this interview was actually conducted for — always
  /// `session.projectId`/`project.id` at the one call site, never a
  /// caller-chosen label — and is minted onto [interviewRecord] verbatim on
  /// a pass, so a later re-proposal can never silently detach the pass from
  /// the project it was genuinely earned for (see
  /// [PublicDemoEngineerInterviewRecord.projectId]'s own doc).
  PublicDemoEngineerSales applyProjectInterviewResult({
    required bool passed,
    required int score,
    required String projectId,
  }) {
    if (stage != PublicDemoSalesStage.partnerInterviewPassed) return this;
    return copyWith(
      stage: passed
          ? PublicDemoSalesStage.clientInterviewPassed
          : PublicDemoSalesStage.clientInterviewFailed,
      lastInterviewScore: score,
      interviewRecord: passed
          ? PublicDemoEngineerInterviewRecord._(
              engineerId: id,
              projectId: projectId,
            )
          : null,
    );
  }

  /// Issue #245 Phase B2 (Partner Interview Gameplay): applies the genuine
  /// outcome of the interactive partner interview
  /// (`public_demo_project_interview.dart`) to this engineer's sales
  /// pipeline — the richer, real-[Project]-driven replacement for
  /// [evaluateInterview]'s generic [PublicDemoInterviewEvaluator] formula at
  /// this same `introduced` → partner-interview stage. Structurally mirrors
  /// [applyProjectInterviewResult] one stage earlier: same "derive, never
  /// accept, the outcome" contract, same no-op-unless-required-stage guard.
  ///
  /// Deliberately never mints [interviewRecord] — that field is reserved as
  /// unforgeable proof of a genuine CLIENT-interview pass only (see
  /// [hasGenuineInterviewRecord]'s own doc; [PublicDemoWorkflowState
  /// .assignOrderedForMay] gates assignment eligibility on it). A partner
  /// pass is a necessary step toward that, not the fact itself — this
  /// mirrors [evaluateInterview]'s own partner branch, which never touches
  /// [interviewRecord] either.
  ///
  /// [passed]/[score] are never caller-asserted outcomes with no real
  /// interview behind them: this method's only production call site is
  /// [PublicDemoWorkflowState.concludePartnerProjectInterview], which
  /// computes both from a fresh [PublicDemoProjectInterview.conclude] call,
  /// made only after verifying a genuine, fully-answered session exists. A
  /// no-op unless [stage] already equals [PublicDemoSalesStage.introduced].
  PublicDemoEngineerSales applyPartnerProjectInterviewResult({
    required bool passed,
    required int score,
  }) {
    if (stage != PublicDemoSalesStage.introduced) return this;
    return copyWith(
      stage: passed
          ? PublicDemoSalesStage.partnerInterviewPassed
          : PublicDemoSalesStage.partnerInterviewFailed,
      lastInterviewScore: score,
    );
  }

  /// CORE-GAMEPLAY Phase 7A (Assignment Lifecycle): releases this engineer
  /// back to the real Sales pipeline after their assignment genuinely ends
  /// (the sole production caller is
  /// [PublicDemoWorkflowState.endAssignment]). A no-op unless [stage] is
  /// currently [PublicDemoSalesStage.ordered] — the only stage a real
  /// assignment is ever created from — mirroring every other transition in
  /// this class's own "required current stage" precondition style.
  ///
  /// Resets [stage] to `waiting` AND clears [interviewRecord] — unlike
  /// [copyWith], which can never null a field it already carries (its own
  /// `?? this.field` convention), leaving [interviewRecord] behind here
  /// left a genuine client-interview-pass record sitting on an engineer no
  /// longer at `clientInterviewPassed`/`ordered`, a combination
  /// [PublicDemoSaveCodec._hasConsistentAuthorityFacts] correctly refuses
  /// to restore (it can never come from any real interview command) — so a
  /// save/reload immediately after ending an assignment was silently
  /// discarded as corrupt (Codex P1, PR #215). The stale record is safe to
  /// drop: it already served its one purpose (proving the now-ended
  /// assignment's real project identity), and a later genuine re-interview
  /// through [evaluateInterview]/[applyProjectInterviewResult] mints a
  /// fresh one regardless.
  PublicDemoEngineerSales releaseFromAssignment() {
    if (stage != PublicDemoSalesStage.ordered) return this;
    return PublicDemoEngineerSales(
      id: id,
      name: name,
      summary: summary,
      interviewProfile: interviewProfile,
      stage: PublicDemoSalesStage.waiting,
      lastInterviewScore: lastInterviewScore,
      interviewRecord: null,
      mental: mental,
      trust: trust,
      founderFollowUpMonth: founderFollowUpMonth,
    );
  }
}

const publicDemoInitialEngineers = <PublicDemoEngineerSales>[
  PublicDemoEngineerSales(
    id: 'eng-01',
    name: '佐藤 健',
    summary: 'Java / SQL・開発経験3年',
    interviewProfile: PublicDemoInterviewProfile(
      skillFit: 78,
      humanity: 70,
      morale: 72,
      clientTrust: 60,
    ),
  ),
  PublicDemoEngineerSales(
    id: 'eng-02',
    name: '鈴木 葵',
    summary: 'JavaScript / Flutter・開発経験2年',
    interviewProfile: PublicDemoInterviewProfile(
      skillFit: 52,
      humanity: 66,
      morale: 64,
      clientTrust: 55,
    ),
  ),
];
