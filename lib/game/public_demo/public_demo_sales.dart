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
  const PublicDemoEngineerInterviewRecord._({required this.engineerId});

  /// The engineer this client-interview pass was actually recorded for.
  /// Checked for identity match, not just presence — a genuine record
  /// reused across engineers via `copyWith` is rejected the same way a
  /// reused [PublicDemoBindingOffer] is (WORKFLOW-STATE-1AB FIX1 P1-1D).
  final String engineerId;
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

  /// Public Demo currently uses the existing morale value as the
  /// Motivation-equivalent, matching the shared Engineer model semantics.
  int get motivation => interviewProfile.morale;

  /// Whether this engineer genuinely passed a client interview — checked by
  /// identity, not just presence (WORKFLOW-STATE-1AB FIX6 P1, mirrors
  /// [PublicDemoApplicant.hasBeenInterviewed]).
  /// [PublicDemoWorkflowState.assignOrderedForMay] requires this before it
  /// will treat `stage == ordered` as eligible for an assignment.
  bool get hasGenuineInterviewRecord => interviewRecord?.engineerId == id;

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
    'mental': mental,
    'trust': trust,
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
    if (stage == null || (recordId != null && recordId is! String) ||
        (recordId != null && recordId != id)) {
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
          : PublicDemoEngineerInterviewRecord._(engineerId: recordId),
      mental: required<int>('mental'),
      trust: required<int>('trust'),
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
