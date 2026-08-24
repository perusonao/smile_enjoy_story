import '../../domain/models/employee_relationship_event.dart';
import '../../domain/models/engineer.dart';
import 'public_demo_binding_offer.dart';

enum PublicDemoRaiseDecision { hold, smallRaise, requestedRaise }

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
  );

  /// Whether this applicant has authoritative, domain-issued provenance for
  /// their accepted salary. [PublicDemoJoinTransaction] requires this before
  /// it will join them (WORKFLOW-STATE-1 §12A).
  bool get hasBindingOffer => bindingOffer != null;

  bool get hasJoined => employeeMorale != null && employeeCompanyTrust != null;

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
  PublicDemoApplicant join({required int week}) {
    if (hasJoined ||
        stage == PublicDemoApplicantStage.offerDeclined ||
        acceptedMonthlySalary == null ||
        bindingOffer == null) {
      return this;
    }
    final event = EmployeeRelationshipEvent(
      week: week,
      reason: salaryRelationshipReason ?? '給与条件で入社',
      moraleDelta: salaryMotivationDelta,
      trustDelta: salaryTrustDelta,
    );
    return copyWith(
      employeeMorale: (defaultEmployeeMorale + event.moraleDelta).clamp(0, 100),
      employeeCompanyTrust: (defaultEmployeeCompanyTrust + event.trustDelta)
          .clamp(0, 100),
      relationshipHistory: [...relationshipHistory, event],
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
