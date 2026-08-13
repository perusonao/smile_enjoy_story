import '../../domain/domain.dart';
import '../models/models.dart';
import 'finance_engine.dart';
import 'matching_engine.dart';
import 'task_engine.dart';

enum AssessmentLevel { attention, candidate, cautious, lowPriority }

class Assessment {
  final AssessmentLevel level;
  final List<String> good;
  final List<String> cautions;
  const Assessment(this.level, {this.good = const [], this.cautions = const []});
}

class RecommendationEngine {
  const RecommendationEngine._();

  static List<HomeTask> recommendedActions(GameState state) {
    final tasks = [...TaskEngine.generateTasks(state)];
    const rank = {TaskPriority.critical: 0, TaskPriority.warning: 1, TaskPriority.info: 2};
    const destinationRank = {
      TaskTargetType.employeeDetail: 0,
      TaskTargetType.cashBreakdown: 1,
      TaskTargetType.recruitmentTab: 2,
      TaskTargetType.employeesTab: 3,
      TaskTargetType.interviewResults: 4,
      TaskTargetType.projectsTab: 5,
      TaskTargetType.othersTab: 6,
      TaskTargetType.none: 7,
    };
    tasks.sort((a, b) {
      final priority = rank[a.priority]!.compareTo(rank[b.priority]!);
      return priority != 0 ? priority : destinationRank[a.targetType]!.compareTo(destinationRank[b.targetType]!);
    });
    return tasks.take(3).toList();
  }

  /// Resume-only assessment: intentionally never reads personality, hidden,
  /// actual experience or actual skill.
  static Assessment candidateAssessment(Applicant applicant, GameState state) {
    final good = <String>[];
    final cautions = <String>[];
    final displayed = applicant.skillFor(applicant.mainLanguage).displayedExperienceMonths;
    if (displayed >= 36) good.add('主言語の経歴が3年以上');
    if (applicant.techSkills.backend >= 3 || applicant.techSkills.frontend >= 3) {
      good.add('現在の案件で使いやすい開発経歴');
    }
    if (applicant.desiredMonthlySalary <= 450000) good.add('希望給与が比較的抑えめ');
    if (applicant.desiredMonthlySalary > 550000) cautions.add('希望給与が高め');
    if (!FinanceEngine.hasOfficeCapacity(state)) cautions.add('現在のオフィス定員に空きなし');
    final level = cautions.length >= 2 ? AssessmentLevel.cautious : good.length >= 2 ? AssessmentLevel.attention : good.isNotEmpty ? AssessmentLevel.candidate : AssessmentLevel.lowPriority;
    return Assessment(level, good: good.take(2).toList(), cautions: cautions.take(2).toList());
  }

  /// Adds only observations produced by questions the player actually asked.
  static Assessment postInterviewAssessment(RecruitmentInterviewSession session) {
    final good = session.observations.where((o) => o.confidence == ObservationConfidence.high).map((o) => o.text).take(2).toList();
    final cautions = session.observations.where((o) => o.confidence != ObservationConfidence.high).map((o) => o.text).take(2).toList();
    return Assessment(good.isNotEmpty ? AssessmentLevel.candidate : AssessmentLevel.cautious, good: good, cautions: cautions);
  }

  static Assessment projectAssessment(Engineer engineer, Project project, GameState state) {
    final fit = MatchingEngine.visibleFit(engineer, project);
    final profit = MatchingEngine.monthlyProfit(engineer, project);
    final good = <String>[]; final cautions = <String>[];
    if (fit == PlayerVisibleFit.excellent || fit == PlayerVisibleFit.good) good.add('Fitが高い');
    if (profit >= 250000) good.add('月間想定粗利が大きい');
    if (project.competitionLevel >= 4) cautions.add('競争度が高い');
    if (project.selectionFlow.steps.length >= 5) cautions.add('選考が長い');
    if (state.activeProposalCountFor(engineer.id) >= 2) cautions.add('営業枠の残りが少ない');
    return Assessment(good.length >= 2 ? AssessmentLevel.attention : good.isNotEmpty ? AssessmentLevel.candidate : AssessmentLevel.cautious, good: good.take(2).toList(), cautions: cautions.take(2).toList());
  }
}
