import '../../domain/domain.dart';
import '../models/models.dart';
import 'employee_workflow_engine.dart';

/// The single "今やること" (do-this-next) action for the guided founding
/// flow (Playable 0.4C.2 §9-10, §47). Home, the employee-detail banner and
/// the weekly summary all render from this one object instead of each
/// deciding for itself what the player should do next (§48).
class GuidedAction {
  final FoundingStage stage;
  final int stepNumber;
  final int totalSteps;
  final String title;
  final String description;
  final String? ctaLabel;
  final TaskTargetType targetType;
  final String? targetId;

  /// Whether "次の週へ" is itself the right thing to do right now (waiting
  /// on a market response, a selection step, etc.) — Home still always
  /// keeps that button enabled, but this tells the guided card whether to
  /// point at it (§20, §27, §29, §33) or at a more specific CTA.
  final bool canAdvanceWeek;

  /// Small supplementary line, e.g. "現在2社へSkillSheet公開中" (§20).
  final String? secondaryInfo;

  const GuidedAction({
    required this.stage,
    required this.stepNumber,
    required this.totalSteps,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.targetType = TaskTargetType.none,
    this.targetId,
    this.canAdvanceWeek = false,
    this.secondaryInfo,
  });
}

/// Pure-Dart progression/feature-gate logic for the guided-founding
/// tutorial (Playable 0.4C.1 §31-32, 0.4C.2 §47-48).
///
/// Nothing here touches Flutter — widgets read [currentStage],
/// [guidedAction] and the `canUseX` gates to decide what to show, instead of
/// scattering `if (tutorialStage == ...)` checks through the UI layer.
class ProgressionEngine {
  const ProgressionEngine._();

  static const List<FoundingStage> _stageOrder = [
    FoundingStage.employeeIntro,
    FoundingStage.skillSheet,
    FoundingStage.salesStart,
    FoundingStage.awaitingOffer,
    FoundingStage.clientInterview,
    FoundingStage.awaitingAssignment,
    FoundingStage.recruitment,
    FoundingStage.welfare,
    FoundingStage.tutorialComplete,
    FoundingStage.freeManagement,
  ];

  /// The milestone that must complete for [stage] to advance to the next
  /// one. [FoundingStage.freeManagement] has none — it's the terminal stage.
  static FoundingMilestone? _gatingMilestone(FoundingStage stage) =>
      switch (stage) {
        FoundingStage.employeeIntro => FoundingMilestone.inspectEmployee,
        FoundingStage.skillSheet => FoundingMilestone.inspectSkillSheet,
        FoundingStage.salesStart => FoundingMilestone.startSales,
        FoundingStage.awaitingOffer =>
          FoundingMilestone.receiveInterviewOffer,
        FoundingStage.clientInterview =>
          FoundingMilestone.completeClientInterview,
        FoundingStage.awaitingAssignment =>
          FoundingMilestone.firstAssignment,
        FoundingStage.recruitment =>
          FoundingMilestone.firstRecruitmentInterview,
        FoundingStage.welfare => FoundingMilestone.welfareIntroSeen,
        FoundingStage.tutorialComplete => FoundingMilestone.freeManagement,
        FoundingStage.freeManagement => null,
      };

  static FoundingStage currentStage(GameState state) {
    final progress = state.foundingProgress;
    if (progress.tutorialSkipped) return FoundingStage.freeManagement;
    for (final stage in _stageOrder) {
      final gate = _gatingMilestone(stage);
      if (gate == null) return stage;
      if (!progress.has(gate)) return stage;
    }
    return FoundingStage.freeManagement;
  }

  static bool showFoundingMission(GameState state) =>
      currentStage(state) != FoundingStage.freeManagement;

  /// Unlocked once the player has assigned at least one employee to a
  /// project (§20).
  static bool canUseRecruitment(GameState state) =>
      state.foundingProgress.tutorialSkipped ||
      state.foundingProgress.has(FoundingMilestone.firstAssignment);

  /// Unlocked after the first assignment *and* a recruitment interview
  /// experience (§24).
  static bool canUseWelfare(GameState state) =>
      state.foundingProgress.tutorialSkipped ||
      (state.foundingProgress.has(FoundingMilestone.firstAssignment) &&
          state.foundingProgress.has(
            FoundingMilestone.firstRecruitmentInterview,
          ));

  /// AR / 入金予定 / 稼働率 only make sense to show once there's an actual
  /// assignment generating them (§37).
  static bool canUseAdvancedFinance(GameState state) => canUseRecruitment(
    state,
  );

  static bool canUseFullDashboard(GameState state) =>
      currentStage(state) == FoundingStage.freeManagement;

  // -------------------------------------------------------------------
  // Reconciliation (0.4C.2 §5-8): heal FoundingProgress from what the
  // GameState itself already shows happened, so a milestone that was
  // somehow never explicitly recorded (a missed event, an old/foreign
  // save, a future refactor that forgets a call site) can never leave the
  // tutorial stuck a step behind reality. Pure, idempotent, monotonic —
  // never un-completes a milestone, so it's safe to call after every
  // mutation.
  // -------------------------------------------------------------------

  /// Backfills every milestone that can be derived from [state] alone.
  /// `inspectEmployee`/`inspectSkillSheet`/`welfareIntroSeen`/
  /// `freeManagement` are deliberately *not* derived here — they're facts
  /// about what the player looked at or explicitly confirmed, not about
  /// what the simulation did, so there's nothing in [GameState] to derive
  /// them from (§6).
  static GameState reconcile(GameState state) {
    var progress = state.foundingProgress;
    final week = state.week;
    FoundingProgress backfill(FoundingMilestone m, bool derived) {
      return derived ? progress.withMilestone(m, week) : progress;
    }

    progress = backfill(
      FoundingMilestone.startSales,
      state.engineers.any((e) => e.salesStatus != SalesStatus.notSelling),
    );
    progress = backfill(
      FoundingMilestone.receiveInterviewOffer,
      state.interviewOffers.isNotEmpty,
    );
    progress = backfill(
      FoundingMilestone.completeClientInterview,
      state.clientInterviews.any((s) => s.completed),
    );
    progress = backfill(
      FoundingMilestone.firstAssignment,
      state.activeAssignments.isNotEmpty || state.stats.assignmentsStarted > 0,
    );
    progress = backfill(
      FoundingMilestone.firstRecruitmentInterview,
      state.recruitmentInterviews.any((s) => s.completed),
    );

    if (identical(progress, state.foundingProgress)) return state;
    return state.copyWith(foundingProgress: progress);
  }

  // -------------------------------------------------------------------
  // Tutorial focus employee (§13-15): the two founders are never both
  // pushed through sales/interviews at once during the early stages —
  // guidance concentrates on one, chosen deterministically from the seed
  // without altering anyone's actual ability.
  // -------------------------------------------------------------------

  /// Playable 0.4C.4 §37-41 balance-priority lever 5: a small, tightly
  /// scoped selection-success-rate safety net — active only for the guided
  /// tutorial's focus employee, before their first assignment, and never in
  /// free/skipped mode. Root-cause simulation (tool/simulate_first_assignment.dart)
  /// found the dominant blocker wasn't project mix or Fit (the deterministic
  /// founder roster already has a well-fit initial project) but the flat
  /// -35 `fromInterviewOffer` selection-rate penalty compounding across
  /// 3-4 sequential steps — this narrows that penalty by 10pt in exactly
  /// this scope, never guarantees a pass, and never touches Free Mode.
  static bool guidedSafetyNetActive(GameState state, String engineerId) =>
      !state.foundingProgress.tutorialSkipped &&
      focusEmployeeId(state) == engineerId &&
      !state.foundingProgress.has(FoundingMilestone.firstAssignment);

  static String? focusEmployeeId(GameState state) {
    if (state.engineers.isEmpty) return null;
    final founders = state.engineers.where((e) => e.id.startsWith('engineer-founder-')).toList();
    final candidates = founders.isNotEmpty ? founders : state.engineers;
    int score(Engineer e) {
      final t = e.profile.techSkills;
      return t.backend +
          t.frontend +
          t.database +
          t.network +
          t.infrastructure +
          t.leader +
          t.manager +
          (e.profile.totalItExperienceMonths ~/ 12);
    }

    final sorted = [...candidates]..sort((a, b) {
      final cmp = score(b).compareTo(score(a));
      return cmp != 0 ? cmp : a.id.compareTo(b.id);
    });
    return sorted.first.id;
  }

  /// The next single thing a new player should do (§9-10, §47). `null` once
  /// the tutorial is finished/skipped.
  static GuidedAction? guidedAction(GameState state) {
    final stage = currentStage(state);
    if (stage == FoundingStage.freeManagement) return null;
    final stepNumber = _stageOrder.indexOf(stage) + 1;
    final totalSteps = _stageOrder.length - 1; // exclude freeManagement

    final focusId = focusEmployeeId(state);
    final focus = focusId == null ? null : state.engineerById(focusId);

    switch (stage) {
      case FoundingStage.employeeIntro:
        return GuidedAction(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: 'まず社員を確認しましょう',
          description:
              'あなたの会社には${state.waitingEngineerCount}名の待機社員がいます。\n'
              '待機中でも給与は発生します。',
          ctaLabel: focus == null ? null : '${focus.profile.name}さんを見る',
          targetType: TaskTargetType.employeeDetail,
          targetId: focusId,
        );
      case FoundingStage.skillSheet:
        return GuidedAction(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: 'SkillSheetを確認しましょう',
          description:
              '客先はこのSkillSheetを見て、面談するか判断します。\n'
              '編集は任意です。今のままでも先に進めます。',
          ctaLabel: 'SkillSheetを開く',
          targetType: TaskTargetType.employeeDetail,
          targetId: focusId,
        );
      case FoundingStage.salesStart:
        return GuidedAction(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '営業を開始しましょう',
          description:
              'このSkillSheetで営業を開始します。\n'
              '条件に合う案件があると、取引先から面談依頼が届きます。',
          ctaLabel: '営業を開始する',
          targetType: TaskTargetType.employeeDetail,
          targetId: focusId,
        );
      case FoundingStage.awaitingOffer:
        // Fallback (§8): if sales somehow isn't actually running for the
        // focus employee anymore (e.g. an older save reconciled `startSales`
        // from a different, no-longer-selling engineer), guide back to
        // restarting it instead of describing a wait that will never end.
        if (focus == null || focus.salesStatus == SalesStatus.notSelling) {
          return GuidedAction(
            stage: stage,
            stepNumber: stepNumber,
            totalSteps: totalSteps,
            title: '営業を再開しましょう',
            description: '営業が停止しています。営業を再開すると、また面談依頼が届くようになります。',
            ctaLabel: '営業を再開する',
            targetType: TaskTargetType.employeeDetail,
            targetId: focusId,
          );
        }
        return GuidedAction(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '取引先からの反応を待っています',
          description: '今週行う必須操作はありません。次の週へ進めましょう。',
          secondaryInfo: '現在 ${state.unlockedClientCount}社へSkillSheet公開中',
          canAdvanceWeek: true,
        );
      case FoundingStage.clientInterview:
        // Playable 0.4C.4 §15-19: the sub-message is derived from
        // EmployeeWorkflowEngine's *current* state, not from ad-hoc
        // pending-list checks — so it immediately reflects reality after a
        // selection/client-interview failure or a declined interview
        // request (the employee reverts to `selling`, not to some stuck
        // "選考が進行中" limbo) instead of going stale.
        if (focusId == null) {
          return GuidedAction(
            stage: stage,
            stepNumber: stepNumber,
            totalSteps: totalSteps,
            title: '選考結果を待っています',
            description: '次の週へ進めましょう。',
            canAdvanceWeek: true,
          );
        }
        switch (EmployeeWorkflowEngine.forEngineer(state, focusId)) {
          case EmployeeWorkflowState.clientInterviewActionRequired:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '初めての客先面談です',
              description:
                  '${focus?.profile.name ?? '社員'}さんが客先から質問を受けます。\n'
                  'あなたは営業として、必要に応じてフォローします。',
              ctaLabel: '面談をプレイ',
              targetType: TaskTargetType.employeeDetail,
              targetId: focusId,
            );
          case EmployeeWorkflowState.interviewRequestPending:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '面談依頼が届きました',
              description: 'まずは面談を経験することをおすすめします（断ることもできます）。',
              ctaLabel: '面談依頼を見る',
              targetType: TaskTargetType.employeeDetail,
              targetId: focusId,
            );
          case EmployeeWorkflowState.finalOfferPending:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '参画オファーが届きました',
              description: '${focus?.profile.name ?? '社員'}さんに参画オファーが届いています。受けるか判断してください。',
              ctaLabel: '参画オファーを確認',
              targetType: TaskTargetType.employeeDetail,
              targetId: focusId,
            );
          case EmployeeWorkflowState.waitingSelectionResult:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '選考結果を待っています',
              description: '次の週へ進めると、選考が進みます。',
              canAdvanceWeek: true,
            );
          case EmployeeWorkflowState.assignmentScheduled:
          case EmployeeWorkflowState.assigned:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '次の週へ進めましょう',
              description: '選考が進んでいます。',
              canAdvanceWeek: true,
            );
          case EmployeeWorkflowState.selling:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '営業を続けています',
              description: '次の面談依頼を待ちましょう。次の週へ進めても大丈夫です。',
              secondaryInfo: '現在 ${state.unlockedClientCount}社へSkillSheet公開中',
              canAdvanceWeek: true,
            );
          case EmployeeWorkflowState.waiting:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '営業を再開しましょう',
              description: '営業が停止しています。営業を再開すると、選考の続きが進むようになります。',
              ctaLabel: '営業を再開する',
              targetType: TaskTargetType.employeeDetail,
              targetId: focusId,
            );
        }
      case FoundingStage.awaitingAssignment:
        // Playable 0.4C.4 §15-19: same EmployeeWorkflowEngine-driven
        // derivation as the clientInterview stage above — "選考が進行中で
        // す" is only ever shown when a selection is genuinely active.
        if (focusId == null) {
          return GuidedAction(
            stage: stage,
            stepNumber: stepNumber,
            totalSteps: totalSteps,
            title: '次の目標: 1人目の案件参画',
            description: '次の週へ進めましょう。',
            canAdvanceWeek: true,
          );
        }
        switch (EmployeeWorkflowEngine.forEngineer(state, focusId)) {
          case EmployeeWorkflowState.finalOfferPending:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '参画オファーが届きました',
              description: '${focus?.profile.name ?? '社員'}さんに参画オファーが届いています。受けるか判断してください。',
              ctaLabel: '参画オファーを確認',
              targetType: TaskTargetType.employeeDetail,
              targetId: focusId,
            );
          case EmployeeWorkflowState.assignmentScheduled:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '参画開始を待っています',
              description: '${focus?.profile.name ?? '社員'}さんは来週から案件に参画予定です。',
              canAdvanceWeek: true,
            );
          case EmployeeWorkflowState.assigned:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '次の週へ進めましょう',
              description: '参画が始まっています。',
              canAdvanceWeek: true,
            );
          case EmployeeWorkflowState.clientInterviewActionRequired:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '客先面談があります',
              description: '${focus?.profile.name ?? '社員'}さんの客先面談です。今週中にプレイするか、社員に任せてください。',
              ctaLabel: '面談を確認',
              targetType: TaskTargetType.employeeDetail,
              targetId: focusId,
            );
          case EmployeeWorkflowState.interviewRequestPending:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '面談依頼が届きました',
              description: '受けるか断るか判断してください。',
              ctaLabel: '面談依頼を見る',
              targetType: TaskTargetType.employeeDetail,
              targetId: focusId,
            );
          case EmployeeWorkflowState.waitingSelectionResult:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '次の目標: 1人目の案件参画',
              description: '選考が進行中です。次の週へ進めましょう。',
              canAdvanceWeek: true,
            );
          case EmployeeWorkflowState.selling:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '次の目標: 1人目の案件参画',
              description: '営業を続けています。次の面談依頼を待ちましょう。',
              canAdvanceWeek: true,
            );
          case EmployeeWorkflowState.waiting:
            return GuidedAction(
              stage: stage,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              title: '営業を再開しましょう',
              description: '営業が停止しています。1人目の案件参画を目指し、営業を再開しましょう。',
              ctaLabel: '営業を再開する',
              targetType: TaskTargetType.employeeDetail,
              targetId: focusId,
            );
        }
      case FoundingStage.recruitment:
        final activeListing = state.listings.any((l) => l.isActiveOn(state.week));
        final uninterviewed = state.applicants
            .where((e) => !state.interviewedApplicantIds.contains(e.applicant.id))
            .toList();
        if (!activeListing && state.applicants.isEmpty) {
          return GuidedAction(
            stage: stage,
            stepNumber: stepNumber,
            totalSteps: totalSteps,
            title: '求人を掲載してみましょう',
            description: '求人媒体を選ぶと、応募者が届くようになります。',
            ctaLabel: '採用を見る',
            targetType: TaskTargetType.recruitmentTab,
          );
        }
        if (uninterviewed.isNotEmpty) {
          return GuidedAction(
            stage: stage,
            stepNumber: stepNumber,
            totalSteps: totalSteps,
            title: '応募者を確認しましょう',
            description: '${uninterviewed.first.applicant.name}さんから応募がありました。採用面接に進めます。',
            ctaLabel: '応募者を確認',
            targetType: TaskTargetType.applicantDetail,
            targetId: uninterviewed.first.applicant.id,
          );
        }
        return GuidedAction(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '応募者を待っています',
          description: '求人を掲載中です。次の週へ進めましょう。',
          canAdvanceWeek: true,
        );
      case FoundingStage.welfare:
        return GuidedAction(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '社員コンディションを確認してみましょう',
          description:
              '社員のMoraleとTrustを管理できるようになりました。\n'
              'まずは社員の状態を見てみましょう。',
          ctaLabel: '社員を見る',
          targetType: TaskTargetType.employeeDetail,
          targetId: focusId,
        );
      case FoundingStage.tutorialComplete:
        return GuidedAction(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '創業ガイド完了',
          description: '基本的な経営を一通り経験しました。\nここからは自由に会社を経営できます。',
          ctaLabel: '自由経営を始める',
        );
      case FoundingStage.freeManagement:
        return null;
    }
  }

  // -------------------------------------------------------------------
  // One-time events: celebrations (§13-14, §19-20, §25, §47) and
  // contextual tutorials (§39-40). Both are just "has this fact become
  // true, and have we shown it yet" — no need to diff before/after state,
  // since [FoundingProgress.seenTutorials] already makes each one fire only
  // once per playthrough regardless of when it's checked.
  // -------------------------------------------------------------------

  static bool _isTrue(GameState state, OneTimeEvent event) => switch (event) {
    OneTimeEvent.interviewOfferCelebration => state.foundingProgress.has(
      FoundingMilestone.receiveInterviewOffer,
    ),
    OneTimeEvent.firstAssignmentCelebration => state.foundingProgress.has(
      FoundingMilestone.firstAssignment,
    ),
    OneTimeEvent.recruitmentUnlockCelebration => canUseRecruitment(state),
    OneTimeEvent.clientInterviewCelebration => state.foundingProgress.has(
      FoundingMilestone.completeClientInterview,
    ),
    OneTimeEvent.recruitmentInterviewCelebration => state.foundingProgress
        .has(FoundingMilestone.firstRecruitmentInterview),
    OneTimeEvent.welfareUnlockCelebration => canUseWelfare(state),
    OneTimeEvent.firstOfferTutorial => state.offers.isNotEmpty,
    OneTimeEvent.firstArTutorial => state.accountsReceivable.isNotEmpty,
    OneTimeEvent.fieldLeadTutorial => state.events.any(
      (e) => e.category == GameLogCategory.fieldLead,
    ),
    OneTimeEvent.contractRenewalTutorial => state.activeAssignments.any(
      (a) =>
          a.remainingWeeks <= 4 &&
          a.contractDecision == ContractDecision.undecided,
    ),
    OneTimeEvent.clientUnlockTutorial =>
      state.clientRelations.where((r) => r.unlocked).length > 2,
  };

  /// Every [OneTimeEvent] among [candidates] whose condition currently
  /// holds and hasn't been shown yet, in declaration order. Always empty
  /// once "自由に開始" was chosen (§42) — an experienced/testing player
  /// shouldn't see tutorial popups just because the underlying milestones
  /// happen to complete during normal play.
  static List<OneTimeEvent> pendingEvents(
    GameState state,
    List<OneTimeEvent> candidates,
  ) {
    if (state.foundingProgress.tutorialSkipped) return const [];
    return [
      for (final event in candidates)
        if (!state.foundingProgress.hasSeen(event) && _isTrue(state, event))
          event,
    ];
  }

  /// The subset of [OneTimeEvent]s that can only be resolved as a result of
  /// [GameEngine.advanceWeek] — checked centrally from Home after each week
  /// advance (§12, §37-39).
  static const List<OneTimeEvent> weeklyEvents = [
    OneTimeEvent.interviewOfferCelebration,
    OneTimeEvent.firstAssignmentCelebration,
    OneTimeEvent.recruitmentUnlockCelebration,
    OneTimeEvent.firstOfferTutorial,
    OneTimeEvent.firstArTutorial,
    OneTimeEvent.fieldLeadTutorial,
    OneTimeEvent.contractRenewalTutorial,
    OneTimeEvent.clientUnlockTutorial,
  ];
}
