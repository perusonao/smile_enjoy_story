import 'public_demo_assignment.dart';
import 'public_demo_sales.dart';

/// Read-only monthly company metrics for Public Demo gameplay.
///
/// This is intentionally derived from the existing Public Demo state/models
/// instead of becoming another source of truth. April-June progression remains
/// unchanged while later gameplay can consume a stable company snapshot.
class PublicDemoCompanySnapshot {
  const PublicDemoCompanySnapshot({
    required this.engineerCount,
    required this.assignedEngineerCount,
    required this.waitingEngineerCount,
    required this.averageMental,
    required this.averageMotivation,
    required this.averageTrust,
    required this.averageFieldEvaluation,
  });

  final int engineerCount;
  final int assignedEngineerCount;
  final int waitingEngineerCount;
  final int averageMental;
  final int averageMotivation;
  final int averageTrust;
  final int averageFieldEvaluation;

  int get utilizationPercent => engineerCount == 0
      ? 0
      : (assignedEngineerCount * 100 / engineerCount).round();

  factory PublicDemoCompanySnapshot.from({
    required List<PublicDemoEngineerSales> engineers,
    required List<PublicDemoAssignment> assignments,
  }) {
    final assignedIds = assignments.map((e) => e.engineerId).toSet();
    final assigned = engineers.where((e) => assignedIds.contains(e.id)).length;
    final waiting = engineers.length - assigned;

    int average(Iterable<int> values, {int fallback = 0}) {
      if (values.isEmpty) return fallback;
      return (values.reduce((a, b) => a + b) / values.length).round();
    }

    return PublicDemoCompanySnapshot(
      engineerCount: engineers.length,
      assignedEngineerCount: assigned,
      waitingEngineerCount: waiting,
      averageMental: average(engineers.map((e) => e.mental), fallback: 50),
      averageMotivation: average(
        engineers.map((e) => e.motivation),
        fallback: 50,
      ),
      averageTrust: average(engineers.map((e) => e.trust), fallback: 50),
      averageFieldEvaluation: average(
        assignments.map((e) => e.fieldEvaluation),
        fallback: 50,
      ),
    );
  }
}
