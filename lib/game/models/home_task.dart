/// How urgently a [HomeTask] needs the player's attention (§4).
enum TaskPriority {
  critical, // 赤
  warning, // 黄
  info; // 青/緑
}

/// Where tapping a [HomeTask] should take the player (§5).
enum TaskTargetType {
  /// Nothing to navigate to — informational only.
  none,

  /// Opens the 今週収支 breakdown sheet right on Home.
  cashBreakdown,
  recruitmentTab,
  employeesTab,
  projectsTab,
  othersTab,

  /// Requires [HomeTask.targetId] to be an engineer id.
  employeeDetail,

  /// Shows this week's resolved project-interview results.
  interviewResults,
}

/// One row of the "今週の経営判断" list (§3).
class HomeTask {
  final String id;
  final TaskPriority priority;
  final String title;
  final String? subtitle;
  final TaskTargetType targetType;
  final String? targetId;

  const HomeTask({
    required this.id,
    required this.priority,
    required this.title,
    this.subtitle,
    this.targetType = TaskTargetType.none,
    this.targetId,
  });

  String get priorityLabel => switch (priority) {
    TaskPriority.critical => '最優先',
    TaskPriority.warning => 'おすすめ',
    TaskPriority.info => '余裕があれば',
  };

  String get nextActionLabel => switch (targetType) {
    TaskTargetType.cashBreakdown => '資金詳細を見る',
    TaskTargetType.recruitmentTab => '採用を見る',
    TaskTargetType.employeesTab => '社員を見る',
    TaskTargetType.projectsTab => 'おすすめ案件を見る',
    TaskTargetType.othersTab => '福利厚生を見る',
    TaskTargetType.employeeDetail => '社員とOfferを確認',
    TaskTargetType.interviewResults => '選考結果を見る',
    TaskTargetType.none => '確認する',
  };
}
