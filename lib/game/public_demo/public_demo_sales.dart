enum PublicDemoSalesStage {
  waiting,
  skillSheet,
  selling,
  introduced,
  partnerInterviewPassed,
  clientInterviewPassed,
  ordered,
}

class PublicDemoEngineerSales {
  const PublicDemoEngineerSales({
    required this.id,
    required this.name,
    required this.summary,
    this.stage = PublicDemoSalesStage.waiting,
  });

  final String id;
  final String name;
  final String summary;
  final PublicDemoSalesStage stage;

  PublicDemoEngineerSales copyWith({PublicDemoSalesStage? stage}) =>
      PublicDemoEngineerSales(
        id: id,
        name: name,
        summary: summary,
        stage: stage ?? this.stage,
      );
}

const publicDemoInitialEngineers = <PublicDemoEngineerSales>[
  PublicDemoEngineerSales(
    id: 'eng-01',
    name: '佐藤 健',
    summary: 'Java / SQL・開発経験3年',
  ),
  PublicDemoEngineerSales(
    id: 'eng-02',
    name: '鈴木 葵',
    summary: 'JavaScript / Flutter・開発経験2年',
  ),
];
