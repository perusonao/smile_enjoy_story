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

class PublicDemoEngineerSales {
  const PublicDemoEngineerSales({
    required this.id,
    required this.name,
    required this.summary,
    required this.interviewProfile,
    this.stage = PublicDemoSalesStage.waiting,
    this.lastInterviewScore,
    this.mental = 50,
    this.trust = 50,
  });

  final String id;
  final String name;
  final String summary;
  final PublicDemoInterviewProfile interviewProfile;
  final PublicDemoSalesStage stage;
  final int? lastInterviewScore;
  final int mental;
  final int trust;

  /// Public Demo currently uses the existing morale value as the
  /// Motivation-equivalent, matching the shared Engineer model semantics.
  int get motivation => interviewProfile.morale;

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
    int? mental,
    int? trust,
  }) => PublicDemoEngineerSales(
    id: id,
    name: name,
    summary: summary,
    interviewProfile: interviewProfile,
    stage: stage ?? this.stage,
    lastInterviewScore: lastInterviewScore ?? this.lastInterviewScore,
    mental: mental ?? this.mental,
    trust: trust ?? this.trust,
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
