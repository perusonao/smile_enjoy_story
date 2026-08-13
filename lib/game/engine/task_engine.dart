import '../models/models.dart';

/// Generates the "今週の経営判断" task list shown at the top of Home
/// (Playable 0.2 §3-§4). Pure function of [GameState] — no randomness, no
/// side effects, safe to call on every rebuild.
class TaskEngine {
  const TaskEngine._();

  /// Below this cash cushion (relative to last week's burn) a "資金残高が
  /// 危険" task fires.
  static const int _minSafeCash = 300000;

  /// A contract with this many weeks left (or fewer) counts as "間近".
  static const int _contractEndingSoonWeeks = 1;

  static const int _maxIndividualWaitingTasks = 3;

  static List<HomeTask> generateTasks(GameState state) {
    final tasks = <HomeTask>[];

    // --- Critical -----------------------------------------------------
    final dangerCash = state.lastWeekExpense * 2 > _minSafeCash
        ? state.lastWeekExpense * 2
        : _minSafeCash;
    if (state.company.cash < dangerCash) {
      tasks.add(
        const HomeTask(
          id: 'cash-danger',
          priority: TaskPriority.critical,
          title: '資金残高が危険水準です',
          subtitle: 'このままだと資金がショートする可能性があります',
          targetType: TaskTargetType.cashBreakdown,
        ),
      );
    }

    for (final a in state.activeAssignments) {
      if (a.remainingWeeks > _contractEndingSoonWeeks) continue;
      final engineer = state.engineers
          .where((e) => e.id == a.engineerId)
          .firstOrNull;
      if (engineer == null) continue;
      tasks.add(
        HomeTask(
          id: 'contract-ending-${a.engineerId}',
          priority: TaskPriority.critical,
          title: '${engineer.profile.name} の契約がまもなく終了します',
          subtitle: '「${a.project.title}」残り${a.remainingWeeks}週・次の案件は未定です',
          targetType: TaskTargetType.employeeDetail,
          targetId: engineer.id,
        ),
      );
    }

    final longWaiters =
        state.waitingStreak.entries.where((e) => e.value >= 3).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in longWaiters.take(_maxIndividualWaitingTasks)) {
      final engineer = state.engineers
          .where((e) => e.id == entry.key)
          .firstOrNull;
      if (engineer == null) continue;
      tasks.add(
        HomeTask(
          id: 'waiting-critical-${entry.key}',
          priority: TaskPriority.critical,
          title: '${engineer.profile.name} が待機${entry.value}週目です',
          subtitle: '長期化しています。案件への提案を検討してください',
          targetType: TaskTargetType.employeeDetail,
          targetId: engineer.id,
        ),
      );
    }
    if (longWaiters.length > _maxIndividualWaitingTasks) {
      tasks.add(
        HomeTask(
          id: 'waiting-critical-more',
          priority: TaskPriority.critical,
          title: 'ほかにも待機3週目以上の社員が${longWaiters.length - _maxIndividualWaitingTasks}名います',
          targetType: TaskTargetType.employeesTab,
        ),
      );
    }

    // --- Warning --------------------------------------------------------
    final twoWeekWaiters =
        state.waitingStreak.entries.where((e) => e.value == 2).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in twoWeekWaiters.take(_maxIndividualWaitingTasks)) {
      final engineer = state.engineers
          .where((e) => e.id == entry.key)
          .firstOrNull;
      if (engineer == null) continue;
      tasks.add(
        HomeTask(
          id: 'waiting-warning-${entry.key}',
          priority: TaskPriority.warning,
          title: '${engineer.profile.name} が待機2週目です',
          targetType: TaskTargetType.employeeDetail,
          targetId: engineer.id,
        ),
      );
    }

    final freshWaiters = state.waitingStreak.entries
        .where((e) => e.value == 1)
        .length;
    if (freshWaiters > 0) {
      tasks.add(
        HomeTask(
          id: 'waiting-fresh',
          priority: TaskPriority.warning,
          title: '待機社員が$freshWaiters名います',
          targetType: TaskTargetType.employeesTab,
        ),
      );
    }

    final uninterviewed = state.applicants
        .where((e) => !state.interviewedApplicantIds.contains(e.applicant.id))
        .length;
    if (uninterviewed > 0) {
      tasks.add(
        HomeTask(
          id: 'interview-pending',
          priority: TaskPriority.warning,
          title: '面接待ちの応募者が$uninterviewed名います',
          targetType: TaskTargetType.recruitmentTab,
        ),
      );
    }

    final scheduledInterviews = state.proposals
        .where((p) => p.stage == ProposalStage.proposed)
        .length;
    if (scheduledInterviews > 0) {
      tasks.add(
        HomeTask(
          id: 'project-interview-scheduled',
          priority: TaskPriority.warning,
          title: '来週、案件面談が$scheduledInterviews件予定されています',
          targetType: TaskTargetType.projectsTab,
        ),
      );
    }

    final freshResults = state.proposals
        .where((p) => p.interviewWeek == state.week)
        .length;
    if (freshResults > 0) {
      tasks.add(
        HomeTask(
          id: 'project-interview-results',
          priority: TaskPriority.warning,
          title: '案件面談結果が$freshResults件届いています',
          targetType: TaskTargetType.interviewResults,
        ),
      );
    }

    // --- Info -------------------------------------------------------------
    final newApplicants = state.applicants
        .where((e) => e.appearedWeek == state.week)
        .length;
    if (newApplicants > 0) {
      tasks.add(
        HomeTask(
          id: 'new-applicants',
          priority: TaskPriority.info,
          title: '新着応募者が$newApplicants名います',
          targetType: TaskTargetType.recruitmentTab,
        ),
      );
    }

    final newProjects = state.openProjects
        .where((e) => e.postedWeek == state.week)
        .length;
    if (newProjects > 0) {
      tasks.add(
        HomeTask(
          id: 'new-projects',
          priority: TaskPriority.info,
          title: '新着案件が$newProjects件あります',
          targetType: TaskTargetType.projectsTab,
        ),
      );
    }

    final proposable = state.openProjects
        .where((e) => state.isProjectOpenForProposal(e.project.id))
        .length;
    if (proposable > 0) {
      tasks.add(
        HomeTask(
          id: 'proposable-projects',
          priority: TaskPriority.info,
          title: '提案可能な案件が$proposable件あります',
          targetType: TaskTargetType.projectsTab,
        ),
      );
    }

    if (state.listings.where((l) => l.isActiveOn(state.week)).isEmpty) {
      tasks.add(
        const HomeTask(
          id: 'no-active-listing',
          priority: TaskPriority.info,
          title: '求人媒体が掲載されていません',
          targetType: TaskTargetType.recruitmentTab,
        ),
      );
    }

    final expiredListings = state.events.where(
      (e) => e.week == state.week && e.category == GameLogCategory.listingExpired,
    );
    for (final e in expiredListings) {
      tasks.add(
        HomeTask(
          id: 'listing-expired-${e.message}',
          priority: TaskPriority.info,
          title: e.message,
          targetType: TaskTargetType.recruitmentTab,
        ),
      );
    }

    if (state.pendingHires.isNotEmpty) {
      final next = state.pendingHires.reduce(
        (a, b) => a.joinWeek <= b.joinWeek ? a : b,
      );
      tasks.add(
        HomeTask(
          id: 'pending-hires',
          priority: TaskPriority.info,
          title: '内定者が入社を待っています(${state.pendingHires.length}名)',
          subtitle: '次は Week ${next.joinWeek} に ${next.applicant.name} が入社予定',
          targetType: TaskTargetType.employeesTab,
        ),
      );
    }

    return tasks;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
