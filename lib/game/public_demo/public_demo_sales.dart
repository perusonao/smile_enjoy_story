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
/// [PublicDemoEngineerSales.recordInterviewOutcome] (WORKFLOW-STATE-1AB
/// FIX6 P1).
///
/// Constructor private to this file: only [PublicDemoEngineerSales
/// .recordInterviewOutcome] — called exclusively by
/// [PublicDemoWorkflowState.recordEngineerInterviewResult]
/// (public_demo_workflow_state.dart), itself called only by
/// [PublicDemoAggregate.recordEngineerInterviewResult]
/// (public_demo_aggregate.dart), after a real
/// [PublicDemoInterviewEvaluator.evaluate] pass — can mint one, bound to
/// that engineer's own id. `stage == PublicDemoSalesStage.ordered` and
/// `lastInterviewScore != null` are NOT proof by themselves: both fields
/// remain publicly settable via [PublicDemoEngineerSales.copyWith] (a value
/// object needs that for [recordInterviewOutcome] itself to work), but
/// doing so does not also produce a genuine
/// [PublicDemoEngineerInterviewRecord] — [PublicDemoWorkflowState
/// .assignOrderedForMay] gates assignment eligibility on this record's
/// identity, not on `stage`/`lastInterviewScore` alone (mirrors
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

  /// The single sanctioned way to record a genuine partner/client interview
  /// outcome for this engineer's sales pipeline (WORKFLOW-STATE-1AB FIX6
  /// P1, replacing the raw `copyWith(stage:, lastInterviewScore:)` call
  /// that used to live in `PublicDemoAggregate.recordEngineerInterviewResult`).
  /// [type]/[passed]/[score] must come from an actual
  /// [PublicDemoInterviewEvaluator.evaluate] call against this engineer's
  /// own [interviewProfile] — called only by
  /// [PublicDemoWorkflowState.recordEngineerInterviewResult]
  /// (public_demo_workflow_state.dart). Mints
  /// [PublicDemoEngineerInterviewRecord] — bound to this engineer's own id
  /// — only when [type] is [PublicDemoInterviewType.client] and [passed] is
  /// true; every other outcome updates `stage`/`lastInterviewScore` without
  /// touching [interviewRecord].
  PublicDemoEngineerSales recordInterviewOutcome({
    required PublicDemoInterviewType type,
    required bool passed,
    required int score,
  }) {
    final nextStage = switch ((type, passed)) {
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
        type == PublicDemoInterviewType.client && passed;
    return copyWith(
      stage: nextStage,
      lastInterviewScore: score,
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
