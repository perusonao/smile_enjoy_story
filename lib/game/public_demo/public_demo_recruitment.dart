enum PublicDemoApplicantStage {
  applied,
  resumeReviewed,
  interviewed,
  rejected,
  offerAccepted,
  offerDeclined,
}

class PublicDemoApplicant {
  const PublicDemoApplicant({
    required this.id,
    required this.name,
    required this.resumeSummary,
    required this.interviewScore,
    required this.acceptanceScore,
    this.stage = PublicDemoApplicantStage.applied,
  });

  final String id;
  final String name;
  final String resumeSummary;
  final int interviewScore;
  final int acceptanceScore;
  final PublicDemoApplicantStage stage;

  PublicDemoApplicant copyWith({PublicDemoApplicantStage? stage}) => PublicDemoApplicant(
        id: id,
        name: name,
        resumeSummary: resumeSummary,
        interviewScore: interviewScore,
        acceptanceScore: acceptanceScore,
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
  ),
  PublicDemoApplicant(
    id: 'app-02',
    name: '田中 美咲',
    resumeSummary: 'Flutter 2年 / JavaScript 3年 / 製造〜テスト',
    interviewScore: 58,
    acceptanceScore: 82,
  ),
];
