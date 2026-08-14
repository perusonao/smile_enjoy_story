import '../../domain/domain.dart';
import '../models/models.dart';

/// One row of the Home "創業ミッション" card (§45-46): the single next thing
/// a new player should do, plus where tapping its CTA should take them.
///
/// Reuses [TaskTargetType] so navigation goes through the same dispatch
/// Home already has for [HomeTask] — no parallel routing table to keep in
/// sync (§31).
class FoundingMissionStep {
  final FoundingStage stage;
  final int stepNumber;
  final int totalSteps;
  final String title;
  final String description;
  final String? ctaLabel;
  final TaskTargetType targetType;
  final String? targetId;

  const FoundingMissionStep({
    required this.stage,
    required this.stepNumber,
    required this.totalSteps,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.targetType = TaskTargetType.none,
    this.targetId,
  });
}

/// Pure-Dart progression/feature-gate logic for the guided-founding
/// tutorial (Playable 0.4C.1 §31-32).
///
/// Nothing here touches Flutter — widgets read [currentStage],
/// [missionStep] and the `canUseX` gates to decide what to show, instead of
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
        FoundingStage.welfare => FoundingMilestone.freeManagement,
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

  /// The next single thing a new player should do, for the Home "創業ミッシ
  /// ョン" card. `null` once the tutorial is finished/skipped.
  static FoundingMissionStep? missionStep(GameState state) {
    final stage = currentStage(state);
    if (stage == FoundingStage.freeManagement) return null;
    final stepNumber = _stageOrder.indexOf(stage) + 1;
    final totalSteps = _stageOrder.length - 1; // exclude freeManagement

    final waitingEngineer = state.engineers
        .where((e) => e.status == EngineerStatus.waiting)
        .toList();
    final firstEngineerId = state.engineers.isEmpty
        ? null
        : state.engineers.first.id;
    final notSellingEngineer = state.engineers
        .where((e) => e.salesStatus == SalesStatus.notSelling)
        .toList();

    switch (stage) {
      case FoundingStage.employeeIntro:
        return FoundingMissionStep(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: 'まず社員を確認しましょう',
          description:
              '現在${state.waitingEngineerCount}名の社員が待機中です。\n'
              '案件が決まっていなくても、月末には給与が発生します。',
          ctaLabel: '社員を見る',
          targetType: TaskTargetType.employeeDetail,
          targetId: waitingEngineer.isNotEmpty
              ? waitingEngineer.first.id
              : firstEngineerId,
        );
      case FoundingStage.skillSheet:
        return FoundingMissionStep(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '営業用SkillSheetを確認する',
          description:
              '客先はこのSkillSheetを見て、面談するか判断します。\n'
              '実態より強く記載することもできますが、社員の信頼や面談結果に影響します。',
          ctaLabel: 'SkillSheetを見る',
          targetType: TaskTargetType.employeeDetail,
          targetId: firstEngineerId,
        );
      case FoundingStage.salesStart:
        return FoundingMissionStep(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '営業を開始しましょう',
          description:
              'SkillSheetを取引可能な会社へ公開します。\n'
              '条件に合う案件があると、取引先から面談オファーが届きます。',
          ctaLabel: '営業を開始する',
          targetType: TaskTargetType.employeeDetail,
          targetId: notSellingEngineer.isNotEmpty
              ? notSellingEngineer.first.id
              : firstEngineerId,
        );
      case FoundingStage.awaitingOffer:
        return FoundingMissionStep(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '取引先からの反応を待ちましょう',
          description:
              '営業中です。次週へ進むと、取引先から面談オファーが届く可能性があります。',
        );
      case FoundingStage.clientInterview:
        final pendingInterviewOffer = state.interviewOffers
            .where((o) => o.status == InterviewOfferStatus.pending)
            .toList();
        final pendingClientInterview = state.proposals
            .where(
              (p) =>
                  p.status == ApplicationStatus.active &&
                  p.currentStep == SelectionStep.clientInterview &&
                  !state.clientInterviews.any(
                    (s) => s.applicationId == p.id && s.completed,
                  ),
            )
            .toList();
        if (pendingClientInterview.isNotEmpty) {
          return FoundingMissionStep(
            stage: stage,
            stepNumber: stepNumber,
            totalSteps: totalSteps,
            title: '初めての客先面談',
            description:
                '社員が質問に答えます。あなたは社長兼営業として、必要なときにフォローしてください。\n'
                '押しすぎると深掘りされることもあります。',
            ctaLabel: '面談を見る',
            targetType: TaskTargetType.employeeDetail,
            targetId: pendingClientInterview.first.engineerId,
          );
        }
        if (pendingInterviewOffer.isNotEmpty) {
          return FoundingMissionStep(
            stage: stage,
            stepNumber: stepNumber,
            totalSteps: totalSteps,
            title: '面談オファーが届きました',
            description: 'まずは面談を経験してみましょう（受けるのがおすすめです）。',
            ctaLabel: '面談オファーを見る',
            targetType: TaskTargetType.employeeDetail,
            targetId: pendingInterviewOffer.first.employeeId,
          );
        }
        return FoundingMissionStep(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '選考の続きを待ちましょう',
          description: '次週へ進めると、選考が進みます。',
        );
      case FoundingStage.awaitingAssignment:
        return FoundingMissionStep(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '次の目標: 社員1名を案件へ参画させる',
          description:
              '営業中: ${state.engineers.where((e) => e.salesStatus == SalesStatus.selling).length}名 / '
              '面談中: ${state.engineers.where((e) => e.salesStatus == SalesStatus.interviewing).length}名 / '
              'Offer: ${state.offers.where((o) => o.status == OfferStatus.pending).length}件',
          targetType: TaskTargetType.employeesTab,
        );
      case FoundingStage.recruitment:
        return FoundingMissionStep(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '新しい社員を採用してみましょう',
          description:
              '会社を拡大するため、新しいエンジニアを採用できるようになりました。\n'
              '求人媒体を選ぶ → 応募者を確認 → 採用面接 → 内定、という流れです。',
          ctaLabel: '採用を見る',
          targetType: TaskTargetType.recruitmentTab,
        );
      case FoundingStage.welfare:
        return FoundingMissionStep(
          stage: stage,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          title: '社員環境 / 福利厚生',
          description:
              '会社は社員に案件を用意するだけではありません。\n'
              'PC、健康診断、賞与などへ投資すると、Moraleや会社へのTrustに影響します。\n\n'
              'ここまでで創業チュートリアルは完了です。',
          ctaLabel: '経営を続ける',
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
