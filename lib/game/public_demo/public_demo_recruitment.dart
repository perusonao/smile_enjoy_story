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
  final PublicDemoApplicantStage stage;

  PublicDemoApplicant copyWith({
    PublicDemoApplicantStage? stage,
    int? acceptedMonthlySalary,
    int? salaryMotivationDelta,
    int? salaryTrustDelta,
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
        stage: stage ?? this.stage,
      );
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
