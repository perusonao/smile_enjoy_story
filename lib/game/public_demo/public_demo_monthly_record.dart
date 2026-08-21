import 'public_demo_company_snapshot.dart';

/// Immutable month-end record for Public Demo 0.1.
///
/// This is a historical record, not another source of live gameplay state.
/// Phase 1C deliberately does not wire it into the April-June progression yet.
class PublicDemoMonthlyRecord {
  const PublicDemoMonthlyRecord({
    required this.month,
    required this.cash,
    required this.engineerCount,
    required this.assignedEngineerCount,
    required this.waitingEngineerCount,
    required this.utilizationPercent,
    required this.averageMental,
    required this.averageMotivation,
    required this.averageTrust,
    required this.averageFieldEvaluation,
  });

  final int month;
  final int cash;
  final int engineerCount;
  final int assignedEngineerCount;
  final int waitingEngineerCount;
  final int utilizationPercent;
  final int averageMental;
  final int averageMotivation;
  final int averageTrust;
  final int averageFieldEvaluation;

  factory PublicDemoMonthlyRecord.fromSnapshot({
    required int month,
    required int cash,
    required PublicDemoCompanySnapshot snapshot,
  }) => PublicDemoMonthlyRecord(
    month: month,
    cash: cash,
    engineerCount: snapshot.engineerCount,
    assignedEngineerCount: snapshot.assignedEngineerCount,
    waitingEngineerCount: snapshot.waitingEngineerCount,
    utilizationPercent: snapshot.utilizationPercent,
    averageMental: snapshot.averageMental,
    averageMotivation: snapshot.averageMotivation,
    averageTrust: snapshot.averageTrust,
    averageFieldEvaluation: snapshot.averageFieldEvaluation,
  );

  Map<String, dynamic> toJson() => {
    'month': month,
    'cash': cash,
    'engineerCount': engineerCount,
    'assignedEngineerCount': assignedEngineerCount,
    'waitingEngineerCount': waitingEngineerCount,
    'utilizationPercent': utilizationPercent,
    'averageMental': averageMental,
    'averageMotivation': averageMotivation,
    'averageTrust': averageTrust,
    'averageFieldEvaluation': averageFieldEvaluation,
  };

  factory PublicDemoMonthlyRecord.fromJson(Map<String, dynamic> json) =>
      PublicDemoMonthlyRecord(
        month: json['month'] as int,
        cash: json['cash'] as int,
        engineerCount: json['engineerCount'] as int,
        assignedEngineerCount: json['assignedEngineerCount'] as int,
        waitingEngineerCount: json['waitingEngineerCount'] as int,
        utilizationPercent: json['utilizationPercent'] as int,
        averageMental: json['averageMental'] as int? ?? 50,
        averageMotivation: json['averageMotivation'] as int? ?? 50,
        averageTrust: json['averageTrust'] as int? ?? 50,
        averageFieldEvaluation:
            json['averageFieldEvaluation'] as int? ?? 50,
      );
}
