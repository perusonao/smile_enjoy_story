enum PublicDemoNextOrderStatus { undecided, offered, accepted, notOffered }

enum PublicDemoReplacementStage {
  none,
  selling,
  introduced,
  partnerPassed,
  partnerFailed,
  clientPassed,
  clientFailed,
  ordered,
}

class PublicDemoAssignment {
  const PublicDemoAssignment({
    required this.engineerId,
    required this.engineerName,
    required this.projectName,
    required this.deliveryPressure,
    required this.budgetHealth,
    required this.humanity,
    this.nextOrderStatus = PublicDemoNextOrderStatus.undecided,
    this.replacementStage = PublicDemoReplacementStage.none,
    this.fieldEvaluation = 50,
  });
  final String engineerId, engineerName, projectName;
  final int deliveryPressure, budgetHealth, humanity;
  final PublicDemoNextOrderStatus nextOrderStatus;
  final PublicDemoReplacementStage replacementStage;
  final int fieldEvaluation;
  bool willOfferNextMonthFor(int actualCapability) =>
      (actualCapability * 35 +
              humanity * 20 +
              budgetHealth * 30 +
              (100 - deliveryPressure) * 15) ~/
          100 >=
      60;
  int replacementPartnerScoreFor(int actualCapability) =>
      (actualCapability * 55 + humanity * 25 + budgetHealth * 20) ~/ 100;
  int replacementClientScoreFor(int actualCapability) =>
      (actualCapability * 60 + humanity * 25 + budgetHealth * 15) ~/ 100;
  PublicDemoAssignment copyWith({
    PublicDemoNextOrderStatus? nextOrderStatus,
    PublicDemoReplacementStage? replacementStage,
    int? fieldEvaluation,
  }) => PublicDemoAssignment(
    engineerId: engineerId,
    engineerName: engineerName,
    projectName: projectName,
    deliveryPressure: deliveryPressure,
    budgetHealth: budgetHealth,
    humanity: humanity,
    nextOrderStatus: nextOrderStatus ?? this.nextOrderStatus,
    replacementStage: replacementStage ?? this.replacementStage,
    fieldEvaluation: fieldEvaluation ?? this.fieldEvaluation,
  );

  /// Assignment fallback for any ordered employee, including a post-join hire.
  factory PublicDemoAssignment.forOrderedEngineer({
    required String engineerId,
    required String engineerName,
    required int humanity,
  }) => PublicDemoAssignment(
    engineerId: engineerId,
    engineerName: engineerName,
    projectName: '新規開発支援',
    deliveryPressure: 50,
    budgetHealth: 70,
    humanity: humanity,
  );
}

const publicDemoInitialAssignments = <PublicDemoAssignment>[
  PublicDemoAssignment(
    engineerId: 'eng-01',
    engineerName: '佐藤 健',
    projectName: '販売管理システム開発',
    deliveryPressure: 45,
    budgetHealth: 75,
    humanity: 70,
  ),
  PublicDemoAssignment(
    engineerId: 'eng-02',
    engineerName: '鈴木 葵',
    projectName: '業務アプリ改修',
    deliveryPressure: 72,
    budgetHealth: 48,
    humanity: 66,
  ),
];
