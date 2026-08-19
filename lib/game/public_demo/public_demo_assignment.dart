enum PublicDemoNextOrderStatus { undecided, offered, accepted, notOffered }

class PublicDemoAssignment {
  const PublicDemoAssignment({
    required this.engineerId,
    required this.engineerName,
    required this.projectName,
    required this.deliveryPressure,
    required this.budgetHealth,
    required this.skill,
    required this.humanity,
    this.nextOrderStatus = PublicDemoNextOrderStatus.undecided,
  });

  final String engineerId;
  final String engineerName;
  final String projectName;
  final int deliveryPressure;
  final int budgetHealth;
  final int skill;
  final int humanity;
  final PublicDemoNextOrderStatus nextOrderStatus;

  bool get willOfferNextMonth {
    final score = skill * 35 + humanity * 20 + budgetHealth * 30 + (100 - deliveryPressure) * 15;
    return score ~/ 100 >= 60;
  }

  PublicDemoAssignment copyWith({PublicDemoNextOrderStatus? nextOrderStatus}) => PublicDemoAssignment(
    engineerId: engineerId,
    engineerName: engineerName,
    projectName: projectName,
    deliveryPressure: deliveryPressure,
    budgetHealth: budgetHealth,
    skill: skill,
    humanity: humanity,
    nextOrderStatus: nextOrderStatus ?? this.nextOrderStatus,
  );
}

const publicDemoInitialAssignments = <PublicDemoAssignment>[
  PublicDemoAssignment(engineerId:'eng-01',engineerName:'佐藤 健',projectName:'販売管理システム開発',deliveryPressure:45,budgetHealth:75,skill:78,humanity:70),
  PublicDemoAssignment(engineerId:'eng-02',engineerName:'鈴木 葵',projectName:'業務アプリ改修',deliveryPressure:72,budgetHealth:48,skill:52,humanity:66),
];
