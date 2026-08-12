/// Cumulative statistics tracked across the whole playthrough, used by the
/// week-26 result screen, the bankruptcy screen and the playtest JSON log.
class GameStats {
  final int cumulativeRevenue;
  final int cumulativeSalary;
  final int cumulativeFixedCost;
  final int cumulativeRecruitmentCost;
  final int hires;
  final int proposalCount;
  final int projectInterviewCount;
  final int projectInterviewSuccess;
  final int assignmentsStarted;

  /// Sum, over every simulated week, of the number of engineers who were
  /// `waiting` that week (待機延べ週).
  final int waitingWeeks;

  const GameStats({
    required this.cumulativeRevenue,
    required this.cumulativeSalary,
    required this.cumulativeFixedCost,
    required this.cumulativeRecruitmentCost,
    required this.hires,
    required this.proposalCount,
    required this.projectInterviewCount,
    required this.projectInterviewSuccess,
    required this.assignmentsStarted,
    required this.waitingWeeks,
  });

  const GameStats.zero()
    : cumulativeRevenue = 0,
      cumulativeSalary = 0,
      cumulativeFixedCost = 0,
      cumulativeRecruitmentCost = 0,
      hires = 0,
      proposalCount = 0,
      projectInterviewCount = 0,
      projectInterviewSuccess = 0,
      assignmentsStarted = 0,
      waitingWeeks = 0;

  int get cumulativeExpense =>
      cumulativeSalary + cumulativeFixedCost + cumulativeRecruitmentCost;

  int get cumulativeProfit => cumulativeRevenue - cumulativeExpense;

  GameStats copyWith({
    int? cumulativeRevenue,
    int? cumulativeSalary,
    int? cumulativeFixedCost,
    int? cumulativeRecruitmentCost,
    int? hires,
    int? proposalCount,
    int? projectInterviewCount,
    int? projectInterviewSuccess,
    int? assignmentsStarted,
    int? waitingWeeks,
  }) {
    return GameStats(
      cumulativeRevenue: cumulativeRevenue ?? this.cumulativeRevenue,
      cumulativeSalary: cumulativeSalary ?? this.cumulativeSalary,
      cumulativeFixedCost: cumulativeFixedCost ?? this.cumulativeFixedCost,
      cumulativeRecruitmentCost:
          cumulativeRecruitmentCost ?? this.cumulativeRecruitmentCost,
      hires: hires ?? this.hires,
      proposalCount: proposalCount ?? this.proposalCount,
      projectInterviewCount:
          projectInterviewCount ?? this.projectInterviewCount,
      projectInterviewSuccess:
          projectInterviewSuccess ?? this.projectInterviewSuccess,
      assignmentsStarted: assignmentsStarted ?? this.assignmentsStarted,
      waitingWeeks: waitingWeeks ?? this.waitingWeeks,
    );
  }

  Map<String, dynamic> toJson() => {
    'cumulativeRevenue': cumulativeRevenue,
    'cumulativeSalary': cumulativeSalary,
    'cumulativeFixedCost': cumulativeFixedCost,
    'cumulativeRecruitmentCost': cumulativeRecruitmentCost,
    'hires': hires,
    'proposalCount': proposalCount,
    'projectInterviewCount': projectInterviewCount,
    'projectInterviewSuccess': projectInterviewSuccess,
    'assignmentsStarted': assignmentsStarted,
    'waitingWeeks': waitingWeeks,
  };

  factory GameStats.fromJson(Map<String, dynamic> json) => GameStats(
    cumulativeRevenue: json['cumulativeRevenue'] as int,
    cumulativeSalary: json['cumulativeSalary'] as int,
    cumulativeFixedCost: json['cumulativeFixedCost'] as int,
    cumulativeRecruitmentCost: json['cumulativeRecruitmentCost'] as int,
    hires: json['hires'] as int,
    proposalCount: json['proposalCount'] as int,
    projectInterviewCount: json['projectInterviewCount'] as int,
    projectInterviewSuccess: json['projectInterviewSuccess'] as int,
    assignmentsStarted: json['assignmentsStarted'] as int,
    waitingWeeks: json['waitingWeeks'] as int,
  );
}
