import 'public_demo_interview.dart';

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

class PublicDemoEngineerSales {
  const PublicDemoEngineerSales({
    required this.id,
    required this.name,
    required this.summary,
    required this.interviewProfile,
    this.stage = PublicDemoSalesStage.waiting,
    this.lastInterviewScore,
  });

  final String id;
  final String name;
  final String summary;
  final PublicDemoInterviewProfile interviewProfile;
  final PublicDemoSalesStage stage;
  final int? lastInterviewScore;

  PublicDemoEngineerSales copyWith({
    PublicDemoSalesStage? stage,
    int? lastInterviewScore,
  }) =>
      PublicDemoEngineerSales(
        id: id,
        name: name,
        summary: summary,
        interviewProfile: interviewProfile,
        stage: stage ?? this.stage,
        lastInterviewScore: lastInterviewScore ?? this.lastInterviewScore,
      );
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
