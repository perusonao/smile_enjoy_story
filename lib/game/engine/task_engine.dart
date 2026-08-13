import '../../domain/domain.dart';
import '../models/models.dart';
import 'finance_engine.dart';

/// Generates the "今週の経営判断" task list shown at the top of Home
/// (Playable 0.2 §3-§4, extended for 0.3A's monthly cash flow §11). Pure
/// function of [GameState] — no randomness, no side effects, safe to call
/// on every rebuild.
class TaskEngine {
  const TaskEngine._();

  /// A contract with this many weeks left (or fewer) counts as "間近".
  static const int _contractEndingSoonWeeks = 4;

  static const int _maxIndividualWaitingTasks = 3;

  static List<HomeTask> generateTasks(GameState state) {
    final tasks = <HomeTask>[];
    for(final p in state.proposals.where((p)=>p.status==ApplicationStatus.active&&p.currentStep==SelectionStep.clientInterview&&!state.clientInterviews.any((s)=>s.applicationId==p.id&&s.completed))){final employee=state.engineerById(p.engineerId);tasks.add(HomeTask(id:'client-interview-${p.id}',priority:TaskPriority.critical,title:'${employee.profile.name}さんの客先面談があります',subtitle:'今週中に面談をプレイするか、社員に任せてください',targetType:TaskTargetType.employeeDetail,targetId:employee.id));}

    for(final offer in state.interviewOffers.where((o)=>o.status==InterviewOfferStatus.pending)){
      final employee=state.engineerById(offer.employeeId);
      tasks.add(HomeTask(id:'interview-offer-${offer.id}',priority:TaskPriority.critical,title:'${employee.profile.name}さんに面談オファーがあります',subtitle:'受けるか断るか判断してください',targetType:TaskTargetType.employeeDetail,targetId:employee.id));
    }
    final salesCandidate=state.engineers.where((e)=>e.status==EngineerStatus.waiting && e.salesStatus==SalesStatus.notSelling).firstOrNull;
    if(salesCandidate!=null && state.week!=1) tasks.add(HomeTask(id:'sales-start-${salesCandidate.id}',priority:TaskPriority.warning,title:'${salesCandidate.profile.name}さんが待機中です',subtitle:'スキルシートを確認して営業開始しましょう',targetType:TaskTargetType.employeeDetail,targetId:salesCandidate.id));

    // --- Critical -----------------------------------------------------

    for (final offer in state.offers.where(
      (offer) =>
          offer.status == OfferStatus.pending &&
          offer.responseDeadlineWeek <= state.week,
    )) {
      final engineer = state.engineers
          .where((e) => e.id == offer.employeeId)
          .firstOrNull;
      if (engineer == null) continue;
      tasks.add(
        HomeTask(
          id: 'offer-deadline-${offer.id}',
          priority: TaskPriority.critical,
          title: '${engineer.profile.name}さんの案件オファー回答期限が今週です',
          subtitle: '何もしないで週を送ると期限切れになります',
          targetType: TaskTargetType.employeeDetail,
          targetId: engineer.id,
        ),
      );
    }

    // Week 1 founding guidance (§17-18): the game opens with everyone
    // waiting, so make the very first task list point straight at the
    // fix instead of letting the player discover it on their own.
    if (state.week == 1 && state.waitingEngineerCount > 0) {
      tasks.add(
        HomeTask(
          id: 'sales-start-founding-guidance',
          priority: TaskPriority.warning,
          title: '社員${state.waitingEngineerCount}名が待機中です',
          subtitle: '案件を決めない限り、月末に給与だけが発生します',
          targetType: TaskTargetType.projectsTab,
        ),
      );
    }

    // Predictive bankruptcy warning (§16): a heads-up before the month-end
    // close actually determines game over.
    if (FinanceEngine.projectedMonthEndCash(state) < 0) {
      tasks.add(
        const HomeTask(
          id: 'cash-danger',
          priority: TaskPriority.critical,
          title: 'このままだと月末に資金がショートします',
          subtitle: '今月の支払い予定が入金予定を上回っています',
          targetType: TaskTargetType.cashBreakdown,
        ),
      );
    } else {
      final runway = FinanceEngine.cashRunwayMonths(state);
      switch (FinanceEngine.classifyRunway(runway)) {
        case RunwayLevel.danger:
          tasks.add(
            const HomeTask(
              id: 'cash-runway-danger',
              priority: TaskPriority.critical,
              title: '資金余命が3か月を切っています',
              subtitle: '早めに案件を決めて収入を確保しましょう',
              targetType: TaskTargetType.cashBreakdown,
            ),
          );
        case RunwayLevel.caution:
          tasks.add(
            const HomeTask(
              id: 'cash-runway-caution',
              priority: TaskPriority.warning,
              title: '資金余命が6か月を切っています',
              targetType: TaskTargetType.cashBreakdown,
            ),
          );
        case RunwayLevel.safe:
          break;
      }
    }

    for (final a in state.activeAssignments) {
      if (a.remainingWeeks > _contractEndingSoonWeeks || a.contractDecision != ContractDecision.undecided) continue;
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
          subtitle: '長期化しています。スキルシートを確認して営業を開始してください',
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
          title:
              'ほかにも待機3週目以上の社員が${longWaiters.length - _maxIndividualWaitingTasks}名います',
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
        .where(
          (p) =>
              p.status == ApplicationStatus.active &&
              p.currentStep != SelectionStep.documentScreening &&
              p.currentStep != SelectionStep.offer,
        )
        .length;
    if (scheduledInterviews > 0) {
      tasks.add(
        HomeTask(
          id: 'project-interview-scheduled',
          priority: TaskPriority.warning,
          title: '現在、面談結果待ちが$scheduledInterviews件あります。次週へ進めましょう',
          targetType: TaskTargetType.employeesTab,
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

    final unlockedIds=state.clientRelations.where((r)=>r.unlocked).map((r)=>r.clientId).toSet();
    final marketCount=state.openProjects.where((e)=>state.clientRelations.isEmpty||unlockedIds.contains(e.project.clientId)).length;
    if(marketCount>0)tasks.add(HomeTask(id:'market-demand',priority:TaskPriority.info,title:'取引先市場に案件情報が$marketCount件あります',subtitle:'需要のある技術をスキルシート作成の参考にできます',targetType:TaskTargetType.projectsTab));

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
      (e) =>
          e.week == state.week && e.category == GameLogCategory.listingExpired,
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
