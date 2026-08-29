import '../../domain/models/employee_relationship_event.dart';
import '../../domain/models/engineer.dart';
import 'public_demo_binding_offer.dart';
import 'public_demo_fiscal_close_id.dart';
import 'public_demo_state.dart';

enum PublicDemoRaiseDecision { hold, smallRaise, requestedRaise }

/// Authoritative, unforgeable proof that a specific applicant actually
/// completed Public Demo 0.1's interview step.
///
/// Constructor private to this file: only [PublicDemoApplicant.completeInterview]
/// (called exclusively by [PublicDemoAggregate.completeInterview] in
/// public_demo_aggregate.dart — the sales-slot-consuming interview flow) can
/// mint one, bound to that applicant's own id. `stage ==
/// PublicDemoApplicantStage.interviewed` alone is NOT proof: a caller can
/// still set that field via the public [PublicDemoApplicant.copyWith], but
/// doing so does not also produce a genuine [PublicDemoInterviewRecord] —
/// [PublicDemoOfferAcceptance.accept] gates on this record, not the stage
/// field, closing that fabrication path (WORKFLOW-STATE-1AB FIX2 P1-1A/B).
///
/// WORKFLOW-STATE-1AB FIX3 P1-1: FIX2's `PublicDemoApplicant.markInterviewed()`
/// was itself a public, zero-argument, unconditional mint — reachable via
/// `workflow.withApplicant(id, (a) => a.markInterviewed())` on ANY
/// applicant already in the authoritative workflow (including one a caller
/// substituted in via that same `withApplicant` update function), entirely
/// bypassing the real prerequisite: an actually-consumed sales slot on the
/// finance side of the aggregate. `PublicDemoApplicant` alone can never
/// validate that prerequisite (it does not carry [PublicDemoState]), so
/// [PublicDemoApplicant.completeInterview] now requires an unforgeable
/// [PublicDemoSalesSlotConsumptionProof] — mintable only by
/// [PublicDemoState.useSalesSlotForInterview] when it genuinely consumed a
/// slot — as a parameter. There is no longer any zero-argument way to mint
/// this record.
class PublicDemoInterviewRecord {
  const PublicDemoInterviewRecord._({required this.applicantId});

  /// The applicant this interview was actually conducted for. Checked for
  /// identity match, not just presence — a genuine record reused across
  /// applicants via `copyWith` is rejected the same way a reused
  /// [PublicDemoBindingOffer] is (WORKFLOW-STATE-1AB FIX1 P1-1D).
  final String applicantId;
}

/// Authoritative, unforgeable proof that a specific applicant actually
/// joined through [PublicDemoApplicant.join] — the domain command that
/// checks BindingOffer identity, validity, and fiscal-close freshness
/// before minting one.
///
/// Constructor private to this file: no caller can fabricate one by
/// constructing an applicant or calling `copyWith(employeeMorale: ...,
/// employeeCompanyTrust: ...)` directly. [PublicDemoApplicant.hasJoined] —
/// the fact [PublicDemoState.advanceToJune]/`closeMay`'s joined-projection
/// derivation and payroll eligibility both trust — checks this record, not
/// the (separately, publicly settable) morale/trust fields
/// (WORKFLOW-STATE-1AB FIX2 P1-4).
class PublicDemoJoinRecord {
  const PublicDemoJoinRecord._({required this.applicantId});

  final String applicantId;
}

enum PublicDemoApplicantStage {
  applied,
  resumeReviewed,
  interviewed,
  rejected,
  offerAccepted,
  offerDeclined,
  preEntrySkillSheet,
  preEntrySelling,
  preEntryIntroduced,
  preEntryPartnerPassed,
  preEntryPartnerFailed,
  preEntryClientPassed,
  preEntryClientFailed,
  juneOrdered,
}

class PublicDemoApplicant {
  const PublicDemoApplicant({
    required this.id,
    required this.name,
    required this.resumeSummary,
    required this.interviewScore,
    required this.acceptanceScore,
    required this.salesSkillFit,
    this.experienceMonths = 36,
    this.requestedMonthlySalary = 320000,
    this.acceptedMonthlySalary,
    this.salaryMotivationDelta = 0,
    this.salaryTrustDelta = 0,
    this.salaryRelationshipReason,
    this.employeeMorale,
    this.employeeCompanyTrust,
    this.relationshipHistory = const [],
    this.raiseDecision,
    this.raisedMonthlySalary,
    this.raiseEffectiveMonth,
    this.stage = PublicDemoApplicantStage.applied,
    this.bindingOffer,
    this.interviewRecord,
    this.joinRecord,
  }) : assert(experienceMonths >= 0, 'experienceMonths must not be negative');

  final String id;
  final String name;
  final String resumeSummary;
  final int interviewScore;
  final int acceptanceScore;
  final int salesSkillFit;

  /// IT practical experience at the time of application.
  ///
  /// Public Demo 0.1 treats zero months as genuinely inexperienced. This is
  /// intentionally separate from [salesSkillFit], which still has its
  /// pre-entry interview and post-entry initial-skill responsibilities.
  final int experienceMonths;
  final int requestedMonthlySalary;
  final int? acceptedMonthlySalary;
  final int salaryMotivationDelta;
  final int salaryTrustDelta;
  final String? salaryRelationshipReason;
  final int? employeeMorale;
  final int? employeeCompanyTrust;
  final List<EmployeeRelationshipEvent> relationshipHistory;
  final PublicDemoRaiseDecision? raiseDecision;
  final int? raisedMonthlySalary;
  final int? raiseEffectiveMonth;
  final PublicDemoApplicantStage stage;

  /// Authoritative provenance for this applicant's accepted salary, minted
  /// only by [PublicDemoOfferAcceptance.accept] (WORKFLOW-STATE-1 §9). Once
  /// set it is never cleared or replaced — [copyWith] intentionally has no
  /// way to null it back out.
  final PublicDemoBindingOffer? bindingOffer;

  /// Authoritative, unforgeable proof this applicant was actually
  /// interviewed — see [PublicDemoInterviewRecord] (WORKFLOW-STATE-1AB
  /// FIX2 P1-1A).
  final PublicDemoInterviewRecord? interviewRecord;

  /// Authoritative, unforgeable proof this applicant actually joined
  /// through [join] — see [PublicDemoJoinRecord] (WORKFLOW-STATE-1AB FIX2
  /// P1-4).
  final PublicDemoJoinRecord? joinRecord;

  PublicDemoApplicant copyWith({
    PublicDemoApplicantStage? stage,
    int? acceptedMonthlySalary,
    int? salaryMotivationDelta,
    int? salaryTrustDelta,
    String? salaryRelationshipReason,
    int? employeeMorale,
    int? employeeCompanyTrust,
    List<EmployeeRelationshipEvent>? relationshipHistory,
    PublicDemoRaiseDecision? raiseDecision,
    int? raisedMonthlySalary,
    int? raiseEffectiveMonth,
    PublicDemoBindingOffer? bindingOffer,
    PublicDemoInterviewRecord? interviewRecord,
    PublicDemoJoinRecord? joinRecord,
  }) => PublicDemoApplicant(
    id: id,
    name: name,
    resumeSummary: resumeSummary,
    interviewScore: interviewScore,
    acceptanceScore: acceptanceScore,
    salesSkillFit: salesSkillFit,
    experienceMonths: experienceMonths,
    requestedMonthlySalary: requestedMonthlySalary,
    acceptedMonthlySalary: acceptedMonthlySalary ?? this.acceptedMonthlySalary,
    salaryMotivationDelta: salaryMotivationDelta ?? this.salaryMotivationDelta,
    salaryTrustDelta: salaryTrustDelta ?? this.salaryTrustDelta,
    salaryRelationshipReason:
        salaryRelationshipReason ?? this.salaryRelationshipReason,
    employeeMorale: employeeMorale ?? this.employeeMorale,
    employeeCompanyTrust: employeeCompanyTrust ?? this.employeeCompanyTrust,
    relationshipHistory: relationshipHistory ?? this.relationshipHistory,
    raiseDecision: raiseDecision ?? this.raiseDecision,
    raisedMonthlySalary: raisedMonthlySalary ?? this.raisedMonthlySalary,
    raiseEffectiveMonth: raiseEffectiveMonth ?? this.raiseEffectiveMonth,
    stage: stage ?? this.stage,
    bindingOffer: bindingOffer ?? this.bindingOffer,
    interviewRecord: interviewRecord ?? this.interviewRecord,
    joinRecord: joinRecord ?? this.joinRecord,
  );

  /// Complete persistence form for this workflow entity.  The record IDs are
  /// stored explicitly so save/load keeps the provenance facts that the
  /// gameplay guards rely on, rather than treating a stage alone as proof.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'resumeSummary': resumeSummary,
    'interviewScore': interviewScore,
    'acceptanceScore': acceptanceScore,
    'salesSkillFit': salesSkillFit,
    'experienceMonths': experienceMonths,
    'requestedMonthlySalary': requestedMonthlySalary,
    'acceptedMonthlySalary': acceptedMonthlySalary,
    'salaryMotivationDelta': salaryMotivationDelta,
    'salaryTrustDelta': salaryTrustDelta,
    'salaryRelationshipReason': salaryRelationshipReason,
    'employeeMorale': employeeMorale,
    'employeeCompanyTrust': employeeCompanyTrust,
    'relationshipHistory': relationshipHistory.map((event) => event.toJson()).toList(),
    'raiseDecision': raiseDecision?.name,
    'raisedMonthlySalary': raisedMonthlySalary,
    'raiseEffectiveMonth': raiseEffectiveMonth,
    'stage': stage.name,
    'bindingOffer': bindingOffer?.toJson(),
    'interviewRecordApplicantId': interviewRecord?.applicantId,
    'joinRecordApplicantId': joinRecord?.applicantId,
  };

  factory PublicDemoApplicant.fromJson(Map<String, dynamic> json) {
    T required<T>(String key) {
      final value = json[key];
      if (value is! T) throw FormatException('Invalid applicant $key');
      return value;
    }

    final id = required<String>('id');
    final stageName = required<String>('stage');
    final stage = PublicDemoApplicantStage.values.where((value) => value.name == stageName).firstOrNull;
    if (stage == null) throw const FormatException('Invalid applicant stage');
    final raiseName = json['raiseDecision'];
    final raiseDecision = raiseName == null
        ? null
        : PublicDemoRaiseDecision.values.where((value) => value.name == raiseName).firstOrNull;
    if (raiseName != null && (raiseName is! String || raiseDecision == null)) {
      throw const FormatException('Invalid applicant raise decision');
    }
    final offerRaw = json['bindingOffer'];
    final interviewId = json['interviewRecordApplicantId'];
    final joinId = json['joinRecordApplicantId'];
    if ((offerRaw != null && offerRaw is! Map) ||
        (interviewId != null && interviewId is! String) ||
        (joinId != null && joinId is! String)) {
      throw const FormatException('Invalid applicant provenance');
    }
    if ((interviewId != null && interviewId != id) || (joinId != null && joinId != id)) {
      throw const FormatException('Mismatched applicant provenance');
    }
    final historyRaw = required<List>('relationshipHistory');
    return PublicDemoApplicant(
      id: id,
      name: required<String>('name'),
      resumeSummary: required<String>('resumeSummary'),
      interviewScore: required<int>('interviewScore'),
      acceptanceScore: required<int>('acceptanceScore'),
      salesSkillFit: required<int>('salesSkillFit'),
      experienceMonths: required<int>('experienceMonths'),
      requestedMonthlySalary: required<int>('requestedMonthlySalary'),
      acceptedMonthlySalary: json['acceptedMonthlySalary'] as int?,
      salaryMotivationDelta: required<int>('salaryMotivationDelta'),
      salaryTrustDelta: required<int>('salaryTrustDelta'),
      salaryRelationshipReason: json['salaryRelationshipReason'] as String?,
      employeeMorale: json['employeeMorale'] as int?,
      employeeCompanyTrust: json['employeeCompanyTrust'] as int?,
      relationshipHistory: historyRaw.map((event) {
        if (event is! Map) throw const FormatException('Invalid relationship event');
        return EmployeeRelationshipEvent.fromJson(event.cast<String, dynamic>());
      }).toList(),
      raiseDecision: raiseDecision,
      raisedMonthlySalary: json['raisedMonthlySalary'] as int?,
      raiseEffectiveMonth: json['raiseEffectiveMonth'] as int?,
      stage: stage,
      bindingOffer: offerRaw == null
          ? null
          : PublicDemoBindingOffer.fromJson((offerRaw as Map).cast<String, dynamic>()),
      interviewRecord: interviewId == null
          ? null
          : PublicDemoInterviewRecord._(applicantId: interviewId),
      joinRecord: joinId == null ? null : PublicDemoJoinRecord._(applicantId: joinId),
    );
  }

  /// Whether this applicant has authoritative, domain-issued provenance for
  /// their accepted salary. [PublicDemoJoinTransaction] requires this before
  /// it will join them (WORKFLOW-STATE-1 §12A).
  bool get hasBindingOffer => bindingOffer != null;

  /// Whether this applicant genuinely completed the interview step —
  /// checked by identity, not just presence (WORKFLOW-STATE-1AB FIX2
  /// P1-1A).
  bool get hasBeenInterviewed => interviewRecord?.applicantId == id;

  /// The single sanctioned way to record that this applicant actually went
  /// through Public Demo 0.1's interview step (WORKFLOW-STATE-1AB FIX3
  /// P1-1), called only by [PublicDemoAggregate.completeInterview]
  /// (public_demo_aggregate.dart). Idempotent.
  /// [PublicDemoOfferAcceptance.accept] requires the resulting
  /// [PublicDemoInterviewRecord] — not the separately, publicly settable
  /// [stage] field — before it will mint a [PublicDemoBindingOffer].
  ///
  /// Requires [proof] that a real sales slot was actually consumed on this
  /// exact transition — see [PublicDemoInterviewRecord]'s class doc for why
  /// this replaced FIX2's zero-argument `markInterviewed()`. This applicant
  /// cannot verify that prerequisite itself, so it is required as an
  /// unforgeable parameter instead: only
  /// [PublicDemoState.useSalesSlotForInterview] can mint one, and only when
  /// it actually consumed a slot.
  PublicDemoApplicant completeInterview(
    PublicDemoSalesSlotConsumptionProof proof,
  ) => hasBeenInterviewed
      ? this
      : copyWith(
          stage: PublicDemoApplicantStage.interviewed,
          interviewRecord: PublicDemoInterviewRecord._(applicantId: id),
        );

  /// Whether this applicant genuinely joined through [join] — checked by
  /// identity, not just the presence of morale/trust values (WORKFLOW-
  /// STATE-1AB FIX2 P1-4). [PublicDemoState.advanceToJune]/`closeMay`'s
  /// joined-projection derivation and payroll eligibility both trust this,
  /// not a caller-supplied applicant's `employeeMorale`/`employeeCompanyTrust`
  /// alone.
  bool get hasJoined => joinRecord?.applicantId == id;

  bool get isInexperienced => experienceMonths == 0;

  /// Inexperienced hires enter through the normal monthly join boundary and
  /// begin development after joining; they do not participate in pre-join
  /// sales.
  bool get canEnterPreJoinSales => !isInexperienced;

  /// Applies the accepted salary condition once, at actual entry rather than
  /// at offer time. Public Demo does not yet own an Engineer runtime.
  ///
  /// This intentionally also requires [bindingOffer]: join without a
  /// domain-issued [PublicDemoBindingOffer] is structurally impossible, at
  /// both this model level and [PublicDemoJoinTransaction] (the sanctioned
  /// entry point every caller should use instead of this method directly).
  ///
  /// WORKFLOW-STATE-1AB FIX1 P1-1D/F: also requires the offer's own
  /// [PublicDemoBindingOffer.applicantId] to match [id] — a caller cannot
  /// join by reusing another applicant's genuine offer via
  /// `copyWith(bindingOffer: ...)`, since that offer's identity would not
  /// match. The authoritative salary always comes from the offer itself
  /// (never the separately mutable [acceptedMonthlySalary] field a caller
  /// could otherwise tamper with via `copyWith` before joining).
  ///
  /// WORKFLOW-STATE-1AB FIX2 P1-1E: also requires [currentFiscalCloseId] to
  /// match the offer's own [PublicDemoBindingOffer.fiscalCloseId] — a stale
  /// genuine offer cannot be joined against a later close, even when this
  /// method is called directly instead of through
  /// [PublicDemoJoinTransaction]. FIX2 P1-4: mints an unforgeable
  /// [PublicDemoJoinRecord] bound to [id] — the sole fact
  /// [hasJoined]/downstream payroll projection trust, never the separately,
  /// publicly settable `employeeMorale`/`employeeCompanyTrust` fields alone.
  PublicDemoApplicant join({
    required int week,
    required PublicDemoFiscalCloseId currentFiscalCloseId,
  }) {
    final offer = bindingOffer;
    if (hasJoined ||
        stage == PublicDemoApplicantStage.offerDeclined ||
        offer == null ||
        offer.applicantId != id ||
        offer.fiscalCloseId != currentFiscalCloseId) {
      return this;
    }
    final event = EmployeeRelationshipEvent(
      week: week,
      reason: salaryRelationshipReason ?? '給与条件で入社',
      moraleDelta: salaryMotivationDelta,
      trustDelta: salaryTrustDelta,
    );
    return copyWith(
      acceptedMonthlySalary: offer.acceptedMonthlySalary,
      employeeMorale: (defaultEmployeeMorale + event.moraleDelta).clamp(0, 100),
      employeeCompanyTrust: (defaultEmployeeCompanyTrust + event.trustDelta)
          .clamp(0, 100),
      relationshipHistory: [...relationshipHistory, event],
      joinRecord: PublicDemoJoinRecord._(applicantId: id),
    );
  }
}

const publicDemoMayApplicants = <PublicDemoApplicant>[
  PublicDemoApplicant(
    id: 'app-01',
    name: '高橋 翔',
    resumeSummary: 'Java 4年 / Spring 3年 / 基本設計〜テスト',
    interviewScore: 74,
    acceptanceScore: 68,
    salesSkillFit: 76,
    experienceMonths: 48,
    requestedMonthlySalary: 320000,
  ),
  PublicDemoApplicant(
    id: 'app-02',
    name: '田中 美咲',
    resumeSummary: 'Flutter 2年 / JavaScript 3年 / 製造〜テスト',
    interviewScore: 58,
    acceptanceScore: 82,
    salesSkillFit: 62,
    experienceMonths: 36,
    requestedMonthlySalary: 300000,
  ),
];

/// Free recruitment deliberately has a mixed-quality candidate pool.
///
/// This remains separate from [publicDemoMayApplicants] because that pool is
/// the established engineer-media pair and its order participates in the
/// deterministic generation contract.
const publicDemoFreeApplicants = <PublicDemoApplicant>[
  PublicDemoApplicant(
    id: 'free-template-inexperienced-01',
    name: '山本 陽菜',
    resumeSummary: 'ITスクール修了 / Java・SQLを学習中（実務未経験）',
    interviewScore: 64,
    acceptanceScore: 76,
    salesSkillFit: 26,
    experienceMonths: 0,
    requestedMonthlySalary: 220000,
  ),
  PublicDemoApplicant(
    id: 'free-template-experienced-01',
    name: '鈴木 恒一',
    resumeSummary: 'Java 2年 / SQL 1年 / 詳細設計〜テスト',
    interviewScore: 66,
    acceptanceScore: 74,
    salesSkillFit: 58,
    experienceMonths: 24,
    requestedMonthlySalary: 250000,
  ),
];
