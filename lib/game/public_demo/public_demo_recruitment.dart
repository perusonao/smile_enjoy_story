import '../../domain/models/employee_relationship_event.dart';
import '../../domain/models/engineer.dart';
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
  });

  final String id;
  final String name;
  final String resumeSummary;
  final int interviewScore;
  final int acceptanceScore;
  final int salesSkillFit;
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
  }) =>
      PublicDemoApplicant(
        id: id,
        name: name,
        resumeSummary: resumeSummary,
        interviewScore: interviewScore,
        acceptanceScore: acceptanceScore,
        salesSkillFit: salesSkillFit,
        requestedMonthlySalary: requestedMonthlySalary,
        acceptedMonthlySalary: acceptedMonthlySalary ?? this.acceptedMonthlySalary,
        salaryMotivationDelta: salaryMotivationDelta ?? this.salaryMotivationDelta,
        salaryTrustDelta: salaryTrustDelta ?? this.salaryTrustDelta,
        salaryRelationshipReason: salaryRelationshipReason ?? this.salaryRelationshipReason,
        employeeMorale: employeeMorale ?? this.employeeMorale,
        employeeCompanyTrust: employeeCompanyTrust ?? this.employeeCompanyTrust,
        relationshipHistory: relationshipHistory ?? this.relationshipHistory,
        raiseDecision: raiseDecision ?? this.raiseDecision,
        raisedMonthlySalary: raisedMonthlySalary ?? this.raisedMonthlySalary,
        raiseEffectiveMonth: raiseEffectiveMonth ?? this.raiseEffectiveMonth,
        stage: stage ?? this.stage,
      );

  bool get hasJoined => employeeMorale != null && employeeCompanyTrust != null;

  /// Applies the accepted salary condition once, at actual entry rather than
  /// at offer time. Public Demo does not yet own an Engineer runtime.
  PublicDemoApplicant join({required int week}) {
    if (hasJoined ||
        stage == PublicDemoApplicantStage.offerDeclined ||
        acceptedMonthlySalary == null) {
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
      employeeCompanyTrust: (defaultEmployeeCompanyTrust + event.trustDelta).clamp(0, 100),
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
    requestedMonthlySalary: 320000,
  ),
  PublicDemoApplicant(
    id: 'app-02',
    name: '田中 美咲',
    resumeSummary: 'Flutter 2年 / JavaScript 3年 / 製造〜テスト',
    interviewScore: 58,
    acceptanceScore: 82,
    salesSkillFit: 62,
    requestedMonthlySalary: 300000,
  ),
];
