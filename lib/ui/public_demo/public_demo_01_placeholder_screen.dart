import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import '../../game/public_demo/public_demo_aggregate.dart';
import '../../game/public_demo/public_demo_assignment.dart';
import '../../game/public_demo/public_demo_cash_advice_selector.dart';
import '../../game/public_demo/public_demo_cash_forecast.dart';
import '../../game/public_demo/public_demo_cash_status_presentation.dart';
import '../../game/public_demo/public_demo_engineer_runtime.dart';
import '../../game/public_demo/public_demo_fiscal_close_id.dart';
import '../../game/public_demo/public_demo_interview.dart';
import '../../game/public_demo/public_demo_internal_training_transaction.dart';
import '../../game/public_demo/public_demo_month_guard.dart';
import '../../game/public_demo/public_demo_month_label.dart';
import '../../game/public_demo/public_demo_recovery.dart';
import '../../game/public_demo/public_demo_recruitment.dart';
import '../../game/public_demo/public_demo_recruitment_medium.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../../game/public_demo/public_demo_salary_finance.dart';
import '../../game/public_demo/public_demo_salary.dart';
import '../../game/public_demo/public_demo_state.dart';
import '../../game/public_demo/public_demo_employee_condition.dart';
import '../../game/public_demo/public_demo_financial_status.dart';
import '../../game/public_demo/public_demo_raise.dart';
import '../../game/public_demo/public_demo_summer_bonus_plan.dart';
import '../../game/public_demo/public_demo_workflow_state.dart';
import '../../game/persistence/public_demo_save_service.dart';
import '../../presentation/home/models/home_dashboard_display_data.dart';
import '../../presentation/home/models/home_office_stage_display.dart';
import '../../presentation/home/models/home_navigator_display.dart';
import '../../presentation/home/models/home_recommended_action.dart';
import '../../presentation/build_info.dart';
import '../../presentation/home/widgets/home_office_stage_section.dart';
import '../asset_paths.dart';
import '../theme.dart';
import 'public_demo_event_dialog.dart';
import 'public_demo_cash_shortage_card.dart';
import 'public_demo_growth_result_card.dart';
import 'public_demo_home_dashboard_section.dart';
import 'public_demo_home_presentation_components.dart';
import 'public_demo_interview_result_dialog.dart';
import 'public_demo_month_guard_warning_dialog.dart';
import 'public_demo_monthly_cash_flow_card.dart';
import 'public_demo_sales_progress.dart';
import 'public_demo_skill_sheet_sheet.dart';
import 'public_demo_salary_offer_dialog.dart';
import 'public_demo_raise_dialog.dart';
import 'public_demo_summer_bonus_dialog.dart';

/// Signature of the local collector the HOME-RUNTIME-2C emit helpers append
/// to. Named rather than inlined so each helper's shape is obvious at a
/// glance, and so no helper can accidentally take a different collector.
typedef _AddCandidate =
    void Function(
      HomeRecommendedActionKind kind,
      VoidCallback invoke, {
      String? subjectName,
      String? targetId,
    });

// ---------------------------------------------------------------------------
// PUBLIC-DEMO-HOME-UI-3A P2 fix (PR #150 review): "今月の重要タスク"'s 営業/採用
// rows used to be unconditional — always rendered, always pointing at
// `_scrollToOtherActions`, regardless of whether anything reachable there
// was actually still legal. In a terminal/completed month (`isCloseBlocked`
// — bankruptcy, March cash-shortage failure, or fiscal-year completion) or a
// month where every sales/recruitment step for that category has already
// been taken, that CTA looked pressable but led to a section with no
// matching eligible action in it: a dead end, not a shortcut.
//
// This does not invent a new eligibility rule. `_recommendedActionCandidates`
// already IS the authority for "is this specific action legal and on screen
// right now" — every kind it emits comes from the exact same predicate that
// gates the corresponding legacy button (see that getter's own doc). These
// two sets are a pure *category* read of that already-legal list: which of
// its kinds are the "営業" (existing-employee sales/assignment pipeline) vs
// "採用" (recruitment/pre-entry pipeline) family the mockup's two rows are
// about. No kind is added to or removed from `_recommendedActionCandidates`
// itself, and no new game rule decides who is eligible for what.

/// The sales-pipeline (existing-employee/assignment) [HomeRecommendedActionKind]s
/// — every kind [_S._recommendedActionCandidates] emits from an engineer or
/// assignment card. Used only to decide whether the "営業活動を進める" task has
/// anywhere left to send the player; see the section doc above.
const Set<HomeRecommendedActionKind> _salesTaskActionKinds = {
  HomeRecommendedActionKind.recoveryAssignment,
  HomeRecommendedActionKind.employeeAcceptOrder,
  HomeRecommendedActionKind.employeeClientInterview,
  HomeRecommendedActionKind.employeePartnerInterview,
  HomeRecommendedActionKind.employeeIntroduceProject,
  HomeRecommendedActionKind.employeeResumeSelling,
  HomeRecommendedActionKind.employeeBeginSelling,
  HomeRecommendedActionKind.employeeSkillSheetReview,
  HomeRecommendedActionKind.assignmentAcceptNextOrder,
  HomeRecommendedActionKind.assignmentAcceptReplacementOrder,
  HomeRecommendedActionKind.assignmentReplacementClientInterview,
  HomeRecommendedActionKind.assignmentReplacementPartnerInterview,
  HomeRecommendedActionKind.assignmentIntroduceReplacementProject,
  HomeRecommendedActionKind.assignmentResumeReplacementSelling,
  HomeRecommendedActionKind.assignmentBeginReplacementSelling,
  HomeRecommendedActionKind.assignmentConfirmNextOrder,
};

/// The recruitment/pre-entry-pipeline [HomeRecommendedActionKind]s — every
/// kind [_S._recommendedActionCandidates] emits from an applicant card or
/// the recruitment-media button. Used only to decide whether the
/// "採用・面談に対応する" task has anywhere left to send the player; see the
/// section doc above.
const Set<HomeRecommendedActionKind> _recruitmentTaskActionKinds = {
  HomeRecommendedActionKind.applicantJuneOrder,
  HomeRecommendedActionKind.applicantClientInterview,
  HomeRecommendedActionKind.applicantPartnerInterview,
  HomeRecommendedActionKind.applicantIntroduceProject,
  HomeRecommendedActionKind.applicantBeginPreEntrySelling,
  HomeRecommendedActionKind.applicantBeginPreEntrySkillSheet,
  HomeRecommendedActionKind.applicantSalaryOffer,
  HomeRecommendedActionKind.applicantInterview,
  HomeRecommendedActionKind.applicantReviewResume,
  HomeRecommendedActionKind.recruitmentMedia,
};

/// Whether an important-task row backed by [kinds] should render at all:
/// not close-blocked (the same terminal/completed gate
/// [_S._recommendedActionSlot] already suppresses on), and at least one
/// already-legal [candidates] entry falls into [kinds]. Top-level and pure
/// so a `test()` can assert it directly against a constructed
/// [PublicDemoState] and a hand-built candidate list, with no widget pump
/// required for the terminal/exhausted cases.
bool homeImportantTaskHasEligibleAction(
  PublicDemoState state,
  Iterable<HomeRecommendedActionCandidate> candidates,
  Set<HomeRecommendedActionKind> kinds,
) =>
    !state.isCloseBlocked &&
    candidates.any((c) => kinds.contains(c.action.kind));

class PublicDemo01PlaceholderScreen extends StatefulWidget {
  const PublicDemo01PlaceholderScreen({
    super.key,
    this.buildInfo,
    this.saveService = const PublicDemoSaveService(),
  });

  final BuildInfo? buildInfo;
  final PublicDemoSaveService saveService;
  @override
  State<PublicDemo01PlaceholderScreen> createState() => _S();
}

class _S extends State<PublicDemo01PlaceholderScreen> {
  static final expense = PublicDemoSalary.baselineMonthlyExpenses;
  final _scrollController = ScrollController();
  final _monthlyCashFlowKey = GlobalKey();

  /// PUBLIC-DEMO-HOME-UI-3A: Public Demo has exactly one screen and no
  /// `Navigator.push` anywhere, so every "destination" the approved visual
  /// target names (quick access, bottom nav, the Navigator card's secondary
  /// route) is truthfully implemented as an on-page scroll-jump to a
  /// section that already exists, via [_scrollToSection] below — never a
  /// fabricated route or a second navigation state. These keys mark exactly
  /// the sections those scroll-jumps target.
  final _officeStageKey = GlobalKey();
  final _financeSummaryKey = GlobalKey();
  final _legacyActionsKey = GlobalKey();
  final _devMenuKey = GlobalKey();

  /// The single authoritative Public Demo 0.1 root (WORKFLOW-STATE-1AB
  /// FIX3): atomically owns both finance/monthly-close facts ([s]) and
  /// workflow facts ([workflow]). This is the ONLY state field this widget
  /// holds — it is replaced wholesale, via `setState(() => _game =
  /// _game.someCommand(...))`, using the domain commands on
  /// [PublicDemoAggregate] (or the dedicated commands in
  /// public_demo_binding_offer.dart / public_demo_join.dart) to compute the
  /// next value. There is no way for this widget to commit a finance change
  /// without the paired workflow change, or vice versa, for any command
  /// that requires both — see [PublicDemoAggregate]'s own class doc.
  PublicDemoAggregate _game = PublicDemoAggregate.initial();
  Future<void> _persistenceTail = Future<void>.value();
  bool _isRestoring = true;
  bool _isRestarting = false;

  /// SES-FIRST-FUN-YEAR-UI-PHASE-2: whether the bottom "開発・テストメニュー"
  /// fold is open. Starts closed so the test-only restart control never
  /// reads as part of the normal monthly game flow — see
  /// [_publicDemoTestControlsCard]'s doc for why it moved here at all.
  bool _isDevMenuExpanded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreAggregate());
  }

  /// Restores only a complete aggregate accepted by the persistence boundary.
  Future<void> _restoreAggregate() async {
    PublicDemoAggregate? restored;
    try {
      // Browser localStorage-backed SharedPreferences is available
      // immediately in the supported runtime. Treat an unavailable bridge as
      // the same safe fallback as an I/O failure rather than leaving the
      // Public Demo permanently non-interactive.
      restored = await widget.saveService.load().timeout(
        const Duration(milliseconds: 100),
        onTimeout: () => null,
      );
    } catch (_) {
      restored = null;
    }
    if (!mounted) return;
    setState(() {
      _game = restored ?? PublicDemoAggregate.initial();
      _isRestoring = false;
    });
  }

  /// Serializes all storage operations in aggregate commit order. Capturing
  /// [next] before enqueueing means a delayed callback can never read a newer
  /// or older screen value by accident.
  Future<T> _enqueuePersistence<T>(Future<T> Function() operation) {
    final result = _persistenceTail.then<T>((_) => operation());
    _persistenceTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  /// The sole authoritative mutation boundary for this screen. A successful
  /// command replaces the complete aggregate, then queues that exact result.
  void _commitAggregate(PublicDemoAggregate next) {
    if (identical(next, _game)) return;
    setState(() => _game = next);
    final captured = next;
    unawaited(
      _enqueuePersistence<void>(() => widget.saveService.save(captured)),
    );
  }

  /// Read-only view of [_game]'s finance side. Never assigned directly —
  /// see [_game].
  PublicDemoState get s => _game.state;

  /// Read-only view of [_game]'s workflow side. Never assigned directly —
  /// see [_game].
  PublicDemoWorkflowState get workflow => _game.workflow;

  /// FIRST-FUN-YEAR P0 (cash-shortage truth): the next monthly close's
  /// forecast entry — [PublicDemoCashForecast.forecast]'s own first
  /// projected month, read-only. This is the single fact
  /// [PublicDemoCashShortageCard] and the "資金不足を確認" dialog
  /// ([_showCashShortageExplanation]) both read to state whether the next
  /// close actually recovers; neither recomputes a forecast of its own, so
  /// the two surfaces can never disagree.
  ///
  /// `null` only when [s.isCloseBlocked] — there genuinely is no further
  /// close ahead (fiscal year completed, or an already-terminal financial
  /// status); [PublicDemoFinancialStatus.cashShortage] itself is never
  /// close-blocked, so this is always non-null while the shortage card and
  /// dialog can actually render.
  PublicDemoCashForecastMonth? get _nextCloseForecastEntry =>
      PublicDemoCashForecast.forecast(
        state: s,
        workflow: workflow,
      ).months.firstOrNull;

  /// HOME-RUNTIME-READ-1: the read-only HOME dashboard projection, derived
  /// on demand from the authoritative aggregate this widget owns ([_game],
  /// via its finance-side view [s]).
  ///
  /// Deliberately a getter and never a [State] field: it is evaluated only
  /// while [build] is constructing the tree, so what HOME renders is always
  /// a projection of the state of *that* build. The existing
  /// `setState(() => _game = ...)` -> rebuild path is therefore also the
  /// entire refresh mechanism — no snapshot is stored anywhere to go stale,
  /// nothing has to be kept in sync, and this cannot become a second source
  /// of truth for cash, revenue, or headcount.
  ///
  /// [HomeDashboardDisplayData.fromPublicDemoState] takes only
  /// [PublicDemoState]: [workflow] (and with it applicants/pre-entry facts)
  /// is never passed to it, and neither [_game] nor any command on it ever
  /// leaves this widget.
  HomeDashboardDisplayData get _homeDashboardData =>
      HomeDashboardDisplayData.fromPublicDemoState(s);

  /// HOME-RUNTIME-2B — the Office Stage's read-only projection.
  ///
  /// Deliberately a *separate* projection from [_homeDashboardData] rather
  /// than three more fields on it. `HomeDashboardDisplayData
  /// .fromPublicDemoState` takes only a [PublicDemoState] by design, and
  /// that narrowness is load-bearing: it is why HOME structurally cannot
  /// see an applicant, a pre-entry stage, or a financial verdict. Employee
  /// *names* are a workflow fact, so folding them into that projection
  /// would have meant widening its input to the whole workflow — paying
  /// for a picture with the boundary HOME-RUNTIME-2A and 2C both rest on.
  ///
  /// So this follows the shape 2C already established for
  /// [_recommendedActionSlot] instead: the owner, which legitimately holds
  /// both halves of the aggregate, resolves the display here while [build]
  /// runs and injects the finished value. Read-only in both directions —
  /// it reads authoritative state and returns a value object, and nothing
  /// it produces is written back to [_game], persisted, or ranked.
  ///
  /// The roster is [PublicDemoWorkflowState.engineers] verbatim, in its own
  /// order. That list *is* the company's employees: `withJoinedEngineers`
  /// appends each applicant to it as they join, so reading it needs no
  /// union with the applicant pool and cannot disagree with the headcount
  /// the KPI above already shows.
  ///
  /// No assignment status is read, deliberately — see the note at the top
  /// of `home_office_stage_display.dart` for why a per-employee
  /// 参画/待機 claim cannot be made from this layer without either
  /// contradicting the KPI or reconciling three authorities that are
  /// Assignment/Domain's to reconcile.
  ///
  /// HOME-COMPACT-1B.4: [employeeCount]/[waitingCount] are the exact same
  /// figures [_homeDashboardData]'s KPI already reads
  /// (`state.engineerCount`/`.engineersWaiting`) — passed straight through,
  /// never recomputed here — so the Office Stage's own aggregate summary
  /// line cannot disagree with the KPI row above it.
  HomeOfficeStageDisplay get _officeStageDisplay => HomeOfficeStageDisplay(
    members: [
      for (final engineer in workflow.engineers)
        HomeOfficeStageMember(
          id: engineer.id,
          name: engineer.name,
          portraitAssetPath: homeOfficeStagePortraitFor(engineer.id),
        ),
    ],
    employeeCount: s.engineerCount,
    waitingCount: s.engineersWaiting,
  );

  /// Issue #148 Phase 1B.3 — connects the existing confirmed-information
  /// cash forecast ([PublicDemoCashForecast], PR #153) through the existing
  /// presentation/advice layer ([PublicDemoCashStatusPresentation],
  /// [PublicDemoCashAdviceSelector], both PR #154) into the one guidance
  /// slot HOME already has: the Navigator card. This never recomputes a
  /// forecast, a safety threshold, or an advice eligibility rule of its own
  /// — every fact below is read verbatim from those three already-tested
  /// pure models. This getter's only job is turning their already-decided
  /// output into the `HomeNavigatorAdvice` HOME already knows how to
  /// render, and deciding *when* it should take that slot over the normal
  /// next-action guidance.
  ///
  /// Deliberately suppressed whenever [PublicDemoState.financialStatus] is
  /// not [PublicDemoFinancialStatus.normal]: once an actual shortage,
  /// bankruptcy, or March cash-shortage failure has happened, it already has
  /// its own strong, pre-existing lead — [PublicDemoCashShortageCard], the
  /// bankruptcy terminal card, and (inside this very Navigator) the
  /// existing `cashShortageResponse` recommended-action candidate emitted
  /// in [_recommendedActionCandidates]'s own P0 block. Showing this
  /// forecast-based advice on top of any of those would be exactly the
  /// duplicate strong cash lead Issue #148 Phase 1B.3 forbids. This getter
  /// exists for the *preventive* window before any of that happens, while
  /// [PublicDemoState.financialStatus] is still `normal` — the one case
  /// none of those existing leads cover.
  HomeNavigatorAdvice? get _cashForecastAdvice {
    if (s.financialStatus != PublicDemoFinancialStatus.normal) return null;
    final forecast = PublicDemoCashForecast.forecast(
      state: s,
      workflow: workflow,
    );
    final cashStatus = PublicDemoCashStatusPresentation.fromForecast(forecast);
    if (cashStatus.status != PublicDemoCashStatus.shortage) return null;
    final shortageMonth = cashStatus.shortageMonth;
    if (shortageMonth == null) return null;

    final shortageEntry = forecast.months
        .where((month) => month.month == shortageMonth)
        .firstOrNull;
    // "根拠となる短い数値" (Issue #148 Phase 1B.3 acceptance criteria): the
    // forecast's own projected closing cash for the shortage month, never a
    // separately recomputed figure.
    final evidence = shortageEntry == null
        ? null
        : '${publicDemoMonthLabel(shortageMonth)}末の現預金見込み '
              '${formatYen(shortageEntry.closingCash)}';
    final message = '${publicDemoMonthLabel(shortageMonth)}に資金がマイナスになる見込みです。';

    // Codex review (PR #159, P2): an applicant who won a pre-entry order
    // joins as an engineer at [PublicDemoSalesStage.waiting]
    // (`withJoinedEngineers`) in the very same close that
    // `assignOrderedForMay` also adds them to the assignment roster — so
    // `stage == waiting` alone does not mean "not currently on a project".
    // [PublicDemoCashAdviceSelector.select] only reads `stage`, so passing
    // it the raw [workflow] could surface an already-assigned engineer as
    // the advice target: confirming their SkillSheet or starting their
    // training would either be a silent no-op (the aggregate's own guards
    // reject re-advancing an assigned engineer) or push them back into the
    // sales pipeline for a project they are already on.
    //
    // [workflow.assignedEngineerIds] is the existing SSOT for "currently on
    // a project" (already used the same way by this screen's own training
    // card and P2-fix month-6/Recovery filters — see
    // `_currentlyAssignedEngineerIds`'s own doc). Excluding those engineers
    // from the pool the selector sees — rather than discarding whatever
    // single candidate it happens to return — lets it fall through to the
    // next genuinely eligible waiting/skillSheet engineer on its own, with
    // no change to its selection logic or order. If none remain, it
    // returns `null` exactly as it already does when no candidate exists,
    // which the existing `candidate == null` branch below already renders
    // safely (no CTA bound to a fabricated action).
    final assignedEngineerIds = workflow.assignedEngineerIds(month: s.month);
    final adviceWorkflow = assignedEngineerIds.isEmpty
        ? workflow
        : PublicDemoWorkflowState(
            applicants: workflow.applicants,
            engineers: [
              for (final engineer in workflow.engineers)
                if (!assignedEngineerIds.contains(engineer.id)) engineer,
            ],
          );
    final candidate = PublicDemoCashAdviceSelector.select(
      cashStatus: cashStatus,
      workflow: adviceWorkflow,
      state: s,
    );
    if (candidate == null) {
      // A forecasted shortage with no currently valid next action (see
      // PublicDemoCashAdviceSelector's own doc for when this happens) still
      // states the reason; its only safe CTA is the existing finance-detail
      // scroll-jump, never a fabricated command.
      return HomeNavigatorAdvice(
        title: 'ひよりからのご案内',
        message: message,
        explanation: evidence == null
            ? '資金計画を確認し、支出や営業状況を見直しましょう。'
            : '$evidence。資金計画を確認し、支出や営業状況を見直しましょう。',
        semantic: HomeNavigatorAdviceSemantic.caution,
        ctaLabel: '資金計画を確認する',
        onCtaPressed: () => _scrollToSection(_financeSummaryKey),
      );
    }

    final name = _engineerName(candidate.employeeId);
    // Only [confirmSkillSheet] needs the full engineer object (to open the
    // SkillSheet sheet the same way the production button does); the other
    // two existing bound handlers already take a bare id.
    final skillSheetEngineer =
        candidate.actionType == PublicDemoAdviceActionType.confirmSkillSheet
        ? _engineerById(candidate.employeeId)
        : null;
    final (ctaLabel, headline, onPressed) = switch (candidate.actionType) {
      PublicDemoAdviceActionType.confirmSkillSheet => (
        'SkillSheetを確認',
        '$nameのSkillSheetを確認',
        skillSheetEngineer == null
            ? null
            : () => unawaited(_openSkillSheetReview(skillSheetEngineer)),
      ),
      PublicDemoAdviceActionType.startInternalTraining => (
        '研修する',
        '$nameの社内研修',
        () => _selectInternalTraining(candidate.employeeId),
      ),
      PublicDemoAdviceActionType.beginSelling => (
        '営業を開始',
        '$nameの営業を開始',
        () => _beginSelling(candidate.employeeId),
      ),
    };
    // The engineer backing a confirmSkillSheet candidate could not be
    // resolved (should not happen — see the doc above — but this never
    // renders a CTA with no bound action rather than assume it cannot).
    if (onPressed == null) {
      return HomeNavigatorAdvice(
        title: 'ひよりからのご案内',
        message: message,
        explanation: evidence,
        semantic: HomeNavigatorAdviceSemantic.caution,
      );
    }

    return HomeNavigatorAdvice(
      title: 'ひよりからのご案内',
      headline: headline,
      message: message,
      explanation: evidence == null
          ? null
          : '$evidence。次の一手として$nameの対応を進めましょう。',
      semantic: HomeNavigatorAdviceSemantic.caution,
      ctaLabel: ctaLabel,
      onCtaPressed: onPressed,
    );
  }

  /// Looks up an engineer by id in [workflow.engineers], or `null` if none
  /// matches. Mirrors [_assignmentForOrNull]'s own loop-based shape.
  PublicDemoEngineerSales? _engineerById(String engineerId) {
    for (final engineer in workflow.engineers) {
      if (engineer.id == engineerId) return engineer;
    }
    return null;
  }

  /// Section 6 ("今月の重要タスク") — up to the three fixed, truthful items
  /// specified for PUBLIC-DEMO-HOME-UI-3A, each built only from an
  /// already-authoritative, always-defined int this screen already reads
  /// for the compact KPI / finance summary. No priority, deadline, or
  /// progress percentage is invented for any of them (see
  /// [PublicDemoImportantTaskItem]'s own doc for why the category chip is
  /// neutral rather than a priority claim).
  ///
  /// PUBLIC-DEMO-HOME-UI-3A P2 fix (PR #150 review): the 営業/採用 rows are
  /// now each gated on [homeImportantTaskHasEligibleAction] — the same
  /// [_recommendedActionCandidates] authority the Recommended Action slot
  /// itself uses — so HOME never advertises a "対応する" CTA into a section
  /// with no matching eligible action left in it (a terminal/completed
  /// month, or a month where that pipeline is genuinely exhausted). 資金計画
  /// is never gated the same way: viewing the finance summary is not an
  /// action that becomes illegal, only a scroll to a section that always
  /// renders (see [_financeSummaryKey]'s own site).
  List<PublicDemoImportantTaskItem> get _importantTasks {
    final data = _homeDashboardData;
    final candidates = _recommendedActionCandidates;
    return [
      if (homeImportantTaskHasEligibleAction(
        s,
        candidates,
        _salesTaskActionKinds,
      ))
        PublicDemoImportantTaskItem(
          title: '営業活動を進める',
          fact: '営業残: ${data.salesRemaining}回',
          category: '営業',
          ctaLabel: '対応する',
          onPressed: _scrollToOtherActions,
        ),
      if (homeImportantTaskHasEligibleAction(
        s,
        candidates,
        _recruitmentTaskActionKinds,
      ))
        PublicDemoImportantTaskItem(
          title: '採用・面談に対応する',
          fact: '待機: ${data.waitingEmployeeCount}名',
          category: '採用',
          ctaLabel: '対応する',
          onPressed: _scrollToOtherActions,
        ),
      PublicDemoImportantTaskItem(
        title: '資金計画を確認する',
        fact: '固定費: ${formatYen(_financeSummary.fixedCosts)}',
        category: '資金',
        ctaLabel: '確認する',
        onPressed: () => _scrollToSection(_financeSummaryKey),
      ),
    ];
  }

  /// Section 7 ("クイックアクセス") — four real on-page destinations, each a
  /// scroll-jump to a section that already exists (see the class doc above
  /// [_officeStageKey]). No fabricated route.
  List<PublicDemoQuickAccessItem> get _quickAccessItems => [
    PublicDemoQuickAccessItem(
      itemKey: const Key('public-demo-quick-access-office'),
      icon: Icons.groups_outlined,
      label: '社員の様子',
      onPressed: () => _scrollToSection(_officeStageKey),
    ),
    PublicDemoQuickAccessItem(
      itemKey: const Key('public-demo-quick-access-finance'),
      icon: Icons.account_balance_wallet_outlined,
      label: '収支・会計',
      onPressed: () => _scrollToSection(_financeSummaryKey),
    ),
    PublicDemoQuickAccessItem(
      itemKey: const Key('public-demo-quick-access-actions'),
      icon: Icons.storefront_outlined,
      label: '案件・営業',
      onPressed: _scrollToOtherActions,
    ),
    PublicDemoQuickAccessItem(
      itemKey: const Key('public-demo-quick-access-dev'),
      icon: Icons.build_outlined,
      label: '開発・テスト',
      onPressed: _openDevMenuSection,
    ),
  ];

  /// The finance summary is a display of values the existing finance and
  /// payroll authorities already produced. The latest close owns the
  /// historical payroll/fixed-cost figures; before the first close, the
  /// established baseline constants are the only figures available.
  ///
  /// SES-FIRST-FUN-YEAR-UI-PHASE-1: this used to also carry cash, revenue,
  /// pendingRevenue, and a shortage/bankruptcy `warning` string — all three
  /// figures already render every build in the compact KPI
  /// (`PublicDemoHomeDashboardSection` -> `KpiSection.compact`), and the
  /// warning duplicated `PublicDemoCashShortageCard`/the bankruptcy
  /// terminal card, both composed above this section. Trimmed to
  /// payroll/fixedCosts, the two figures the KPI does not carry.
  PublicDemoFinanceSummaryModel get _financeSummary {
    final latest = s.latestMonthlyCashFlow;
    return PublicDemoFinanceSummaryModel(
      payroll: latest?.salaryPaid ?? PublicDemoSalary.initialTotalMonthlySalary,
      fixedCosts:
          latest?.fixedCostsPaid ?? PublicDemoSalary.otherMonthlyFixedCost,
    );
  }

  /// The month-end shortcut is a second mount of the existing, already-bound
  /// month-close handler. It never enters Recommended Action selection and
  /// disappears when the existing finance authority blocks further closes.
  PublicDemoMonthlyPrimaryCtaModel? get _monthlyPrimaryAction {
    if (s.isCloseBlocked) return null;
    return switch (s.month) {
      4 => PublicDemoMonthlyPrimaryCtaModel(
        label: '4月を終了して5月へ',
        description: '今月の対応を終えたら、月末処理へ進みます。',
        enabled: true,
        onPressed: () => unawaited(april()),
      ),
      5 => PublicDemoMonthlyPrimaryCtaModel(
        label: '5月を終了して6月へ',
        description: '今月の対応を終えたら、月末処理へ進みます。',
        enabled: true,
        onPressed: () => unawaited(may()),
      ),
      6 => PublicDemoMonthlyPrimaryCtaModel(
        label: '6月を終了して7月へ',
        description: '今月の対応を終えたら、月末処理へ進みます。',
        enabled: true,
        onPressed: june,
      ),
      7 => PublicDemoMonthlyPrimaryCtaModel(
        label: '7月を終了して8月へ',
        description: _summerBonusDecisionRequired
            ? '夏季賞与が未決定です。タップすると決定画面が開きます。'
            : '夏季賞与の決定が完了しました。月末処理へ進みます。',
        enabled: true,
        onPressed: () => unawaited(july()),
      ),
      >= 8 && <= 14 => PublicDemoMonthlyPrimaryCtaModel(
        label: '${publicDemoMonthLabel(s.month)}を終了して翌月へ',
        description: '今月の収支を確定し、翌月へ進みます。',
        enabled: true,
        onPressed: () => unawaited(closeOrdinaryMonth()),
      ),
      15 => PublicDemoMonthlyPrimaryCtaModel(
        label: '3月を終了して第1期を完了',
        description: '今期最後の収支を確定します。',
        enabled: true,
        onPressed: () => unawaited(closeOrdinaryMonth()),
      ),
      _ => null,
    };
  }

  /// Generalized form of the pre-existing `_scrollToLatestCashFlow`: jumps
  /// to whichever already-on-page section [key] marks. This is the single
  /// mechanism behind every quick-access item, every bottom-nav
  /// destination, and the Navigator card's secondary route — see the class
  /// doc on the `_officeStageKey` field group for why a scroll-jump, not a
  /// route, is the truthful implementation here.
  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _scrollToOtherActions() => _scrollToSection(_legacyActionsKey);

  void _openDevMenuSection() {
    if (!_isDevMenuExpanded) setState(() => _isDevMenuExpanded = true);
    // The toggle above only takes effect on the next build, so the section
    // key isn't mounted yet this frame — scroll to it once it is.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSection(_devMenuKey);
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    unawaited(
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  /// Bottom nav (section 8) `onDestinationSelected`. There is no second
  /// screen to switch to, so every index is a real scroll-jump rather than
  /// a route change — see the class doc above [_officeStageKey]. Tapping
  /// any destination therefore never changes [_bottomNavIndex]; only ホーム
  /// (index 0) is ever shown selected, because there genuinely is no other
  /// "current tab" to track without inventing one. This is stated plainly
  /// in the result report as a truthful reduction.
  void _handleBottomNavSelection(int index) {
    switch (index) {
      case 0:
        _scrollToTop();
      case 1:
        _scrollToSection(_officeStageKey);
      case 2:
        _scrollToOtherActions();
      case 3:
        _scrollToSection(_financeSummaryKey);
      case 4:
        _openDevMenuSection();
    }
  }

  Future<void> _showNotifications() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('public-demo-notifications-dialog'),
        title: const Text('お知らせ'),
        content: const Text('現在お知らせはありません。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _openRecruitmentMedia() async {
    final selected = await showModalBottomSheet<PublicDemoRecruitmentMedium>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecruitmentMediaSheet(state: s),
    );
    if (!mounted || selected == null) return;

    // WORKFLOW-STATE-1 §14/§15, WORKFLOW-STATE-1AB FIX3 P1-2: cash and the
    // generated applicants commit together as one atomic aggregate — "cash
    // spent, applicants missing" and "applicants created, cash not spent"
    // are both impossible outcomes of this call. `result.aggregate` is the
    // only way to obtain the committed outcome, and it is one root, not a
    // separately-committable state/workflow pair.
    final result = _game.recruit(selected);
    if (!result.isSuccess) {
      final message = switch (result.status) {
        PublicDemoRecruitmentTransactionStatus.insufficientCash =>
          '現預金が不足しているため利用できません。',
        PublicDemoRecruitmentTransactionStatus.alreadyUsedThisMonth =>
          '今月はすでに求人媒体を利用しています。',
        PublicDemoRecruitmentTransactionStatus.generationFailed =>
          '応募者を用意できませんでした。もう一度お試しください。',
        PublicDemoRecruitmentTransactionStatus.blockedByFinancialShortage =>
          '資金繰りが悪化しているため、求人媒体を利用できません。',
        PublicDemoRecruitmentTransactionStatus.success => '',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    _commitAggregate(result.aggregate!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('応募者${result.generatedApplicants.length}名を追加しました。'),
      ),
    );
  }

  int capabilityFor(String engineerId) =>
      s.runtimeForOrNull(engineerId)?.actualCapability ?? 0;

  bool readyForFieldSales(String engineerId) =>
      s.runtimeForOrNull(engineerId)?.isReadyForFieldSales ?? false;

  /// The engineer IDs currently backing [PublicDemoState.engineersAssigned]
  /// — the single SSOT [Revenue], [Growth], and training eligibility must
  /// all agree on (12MONTH-3-FIX1 P1-1). WORKFLOW-STATE-1 moved the actual
  /// computation onto [PublicDemoWorkflowState.assignedEngineerIds]; see its
  /// doc comment for why this differs before/from July.
  Set<String> get _currentlyAssignedEngineerIds =>
      workflow.assignedEngineerIds(month: s.month);

  void _selectInternalTraining(String engineerId) {
    _commitAggregate(_game.selectInternalTraining(engineerId));
  }

  /// RECOVERY-LOOP-1: the single entry point for committing a late-year
  /// Recovery order into an assignment. The button this is bound to
  /// (`ec(i)`'s `ordered`-stage branch) only ever renders when
  /// [PublicDemoRecoveryEligibility.isEligible] already holds, but
  /// [PublicDemoAggregate.recoverAssignment] re-checks the same
  /// eligibility itself — never relying on the UI alone, exactly like
  /// every other command on this screen.
  void _recoverAssignment(String engineerId) {
    _commitAggregate(_game.recoverAssignment(engineerId));
  }

  // HOME-RUNTIME-2C: the engineer/applicant stage commands below were
  // inline `onPressed:` closures until this phase. They are named methods
  // now for exactly one reason: the HOME Recommended Action CTA and the
  // employee card's own button must be the *same* binding, not two closures
  // that happen to call the same command today. Each is bound once, at the
  // single site that emits the candidate and renders the button together,
  // so the two can never drift apart. No command, guard, or key changed.
  void _startSkillSheetReview(String engineerId) =>
      _commitAggregate(_game.startSkillSheetReview(engineerId));

  /// SKILLSHEET-UX-2A Phase A: the mobile-first SkillSheet sheet
  /// ([PublicDemoSkillSheetSheet]) that replaced PUBLIC-DEMO-UX-1A's
  /// AlertDialog. Still deliberately read-only: it only displays facts the
  /// Public Demo already owns (via [PublicDemoSkillSheetDisplayFactory]),
  /// and the existing authoritative stage transition is committed only
  /// after an explicit confirmation. Back/cancel/dismiss therefore leaves
  /// the workflow untouched — see [PublicDemoSkillSheetSheet]'s doc comment
  /// for the preserved key/return-value contract.
  Future<void> _openSkillSheetReview(PublicDemoEngineerSales engineer) async {
    final confirmed = await PublicDemoSkillSheetSheet.show(
      context,
      engineer: engineer,
      statusLabel: engineerStatus(engineer),
      runtime: s.runtimeForOrNull(engineer.id),
      currentAssignment: _assignmentForOrNull(engineer.id),
    );
    if (!mounted || confirmed != true) return;
    _startSkillSheetReview(engineer.id);
  }

  /// Mirrors [_engineerName]'s lookup shape. Deliberately loop-based rather
  /// than a `firstWhereOrNull` helper — no assumption made about which
  /// collection-extension packages/imports are already in scope elsewhere
  /// in this file.
  PublicDemoAssignment? _assignmentForOrNull(String engineerId) {
    for (final assignment in workflow.assignments) {
      if (assignment.engineerId == engineerId) return assignment;
    }
    return null;
  }

  void _beginSelling(String engineerId) =>
      _commitAggregate(_game.beginSelling(engineerId));

  void _introduceProject(String engineerId) =>
      _commitAggregate(_game.introduceProject(engineerId));

  void _reviewResume(String applicantId) =>
      _commitAggregate(_game.reviewResume(applicantId));

  void _beginPreEntrySkillSheet(String applicantId) =>
      _commitAggregate(_game.beginPreEntrySkillSheet(applicantId));

  void _beginPreEntrySelling(String applicantId) =>
      _commitAggregate(_game.beginPreEntrySelling(applicantId));

  void _introducePreEntryProject(String applicantId) =>
      _commitAggregate(_game.introducePreEntryProject(applicantId));

  /// Records the engineer's order, then shows the order event. Extracted
  /// verbatim from the `受注` button's own closure.
  Future<void> _recordEngineerOrder(PublicDemoEngineerSales e) async {
    _commitAggregate(_game.recordOrder(e.id));
    if (!mounted) return;
    await _precacheEventImage(AssetPaths.eventOrderDecision);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => PublicDemoEventDialog(
        title: '案件を受注しました',
        imageAsset: AssetPaths.eventOrderDecision,
        imageKey: const Key('public-demo-order-decision-image'),
        message: '${e.name}さんの5月分案件を受注しました。',
        nextAction: '翌月からの参画に備え、残りの営業状況も確認しましょう。',
      ),
    );
  }

  /// Records the applicant's June order, then shows the order event.
  /// Extracted verbatim from the `6月受注` button's own closure.
  Future<void> _recordApplicantJuneOrder(PublicDemoApplicant a) async {
    _commitAggregate(_game.recordJuneOrder(a.id));
    if (!mounted) return;
    await _precacheEventImage(AssetPaths.eventOrderDecision);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => PublicDemoEventDialog(
        title: '案件を受注しました',
        imageAsset: AssetPaths.eventOrderDecision,
        imageKey: const Key('public-demo-order-decision-image'),
        message: '${a.name}さんの6月分案件を受注しました。',
        nextAction: '入社と初参画に向けて6月へ進みましょう。',
      ),
    );
  }

  /// PLAYTEST-BLOCKER-1A: shows a compact dialog that always produces
  /// perceptible feedback regardless of scroll position. The player sees
  /// the current cash, the shortage amount, the pending AR, the next
  /// close's forecasted cash, and a plain explanation of what the next
  /// monthly close decides and what to review.
  ///
  /// This replaces the former inert scroll-to-zero behaviour that appeared
  /// completely inert when the player was already at the top of the screen.
  /// No finance authority moves into this path — it reads [s] read-only and
  /// shows the same values already on the shortage card.
  ///
  /// FIRST-FUN-YEAR P0 (cash-shortage truth): the recovery/continues-in-
  /// shortage wording is now [PublicDemoCashShortageOutlook
  /// .fromForecastEntry] applied to the exact same [_nextCloseForecastEntry]
  /// the shortage card reads — never a separate "0円以上になれば回復します"
  /// claim computed from [s.pendingRevenue] alone. The card and this dialog
  /// therefore always state the identical number and conclusion.
  Future<void> _showCashShortageExplanation() async {
    if (!mounted) return;
    final deficit = s.cash < 0 ? -s.cash : 0;
    final outlook = PublicDemoCashShortageOutlook.fromForecastEntry(
      _nextCloseForecastEntry,
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('public-demo-cash-shortage-dialog'),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Flexible(child: Text('資金不足')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogRow('現在の現預金', formatYen(s.cash)),
              _dialogRow('不足額', formatYen(deficit)),
              _dialogRow('次回入金予定（売掛金）', formatYen(s.pendingRevenue)),
              _dialogRow(
                '次回決算後見込み',
                outlook.projectedClosingCash == null
                    ? '算出不可'
                    : formatYen(outlook.projectedClosingCash!),
              ),
              const SizedBox(height: 12),
              Text(
                outlook.headline,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: outlook.willRecover ? null : Colors.red.shade700,
                ),
              ),
              if (outlook.expectedLine != null) ...[
                const SizedBox(height: 4),
                Text(outlook.expectedLine!),
              ],
              const SizedBox(height: 8),
              Text(
                '営業・案件参画を強化して翌月の収益を増やしましょう。',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: const Key('public-demo-cash-shortage-dialog-dismiss'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  /// Shared label/value row used inside [_showCashShortageExplanation].
  Widget _dialogRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  /// PLAYTEST-BLOCKER-1A: a prominent card that communicates the terminal
  /// financial state (bankruptcy or March cash-shortage failure) and
  /// provides the only safe exit — restarting the playthrough.
  ///
  /// Reads [s] read-only. Does not infer the terminal condition from cash
  /// sign; the authoritative [PublicDemoFinancialStatus.isTerminal] check
  /// is the entry guard on [PublicDemoState.isFinanciallyTerminal].
  Widget _bankruptcyTerminalCard() {
    final isBankruptcy =
        s.financialStatus == PublicDemoFinancialStatus.bankruptcy;
    final title = isBankruptcy ? '倒産' : '3月資金不足';
    final reason = isBankruptcy
        ? '資金不足の状態で月次決算を迎え、再度赤字となったため倒産が確定しました。'
        : '3月の月次決算が赤字となり、今期は終了しました。';

    return Card(
      key: const Key('public-demo-bankruptcy-card'),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business_outlined, color: Colors.red.shade800),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'このプレイスルーは終了しました。',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(reason),
            const SizedBox(height: 10),
            Text(
              '最終現預金: ${formatYen(s.cash)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (s.latestMonthlyCashFlow != null)
              Text(
                '最終決算月: ${publicDemoMonthLabel(s.latestMonthlyCashFlow!.month)}',
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('public-demo-restart-button'),
                onPressed: _isRestarting ? null : _restartGame,
                child: Text(_isRestarting ? '再開準備中…' : '最初からやり直す'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// SES-FIRST-FUN-YEAR-UI-PHASE-2: the collapsed home for
  /// [_publicDemoTestControlsCard]. Real-device testing found the test-only
  /// restart control sitting in the middle of the normal monthly game flow
  /// (between the Recommended Action and the Office Stage), where it read
  /// as if it were part of ordinary play. It is moved to the very bottom of
  /// the screen, folded behind an explicit "開発・テストメニュー" toggle that
  /// starts closed, so a normal player scrolling through a month's cards
  /// never sees it unless they deliberately open this section. Nothing
  /// about the control itself — its key, its confirmation dialog, or what
  /// it does — changed; only where it is mounted did.
  Widget _publicDemoDevMenuSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 24),
      TextButton.icon(
        key: const Key('public-demo-dev-menu-toggle'),
        onPressed: () =>
            setState(() => _isDevMenuExpanded = !_isDevMenuExpanded),
        icon: Icon(_isDevMenuExpanded ? Icons.expand_less : Icons.expand_more),
        label: const Text('開発・テストメニュー'),
      ),
      if (_isDevMenuExpanded) _publicDemoTestControlsCard(),
    ],
  );

  /// Public Demo-only test control for repeatable human QA. The destructive
  /// confirmation is intentionally separate from [_restartGame], which also
  /// serves the already-terminal recovery card.
  ///
  /// PUBLIC-DEMO-HOME-UI-3A: also the new home for [BuildInfoLabel], moved
  /// out of the AppBar title. This card is exactly the "compact
  /// developer/test surface" the issue asks the deploy/build identity be
  /// kept available in without visually dominating the gameplay header —
  /// it is already collapsed behind "開発・テストメニュー" by default.
  Widget _publicDemoTestControlsCard() => Card(
    key: const Key('public-demo-test-controls'),
    color: Colors.amber.shade50,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, size: 20),
              SizedBox(width: 8),
              Text('テスト用操作', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Public Demo 0.1の進行だけを初期状態へ戻します。'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('public-demo-restart-april-button'),
            onPressed: _isRestarting ? null : _confirmRestartFromApril,
            icon: const Icon(Icons.restart_alt),
            label: Text(_isRestarting ? '再開準備中…' : '4月からやり直す'),
          ),
          const SizedBox(height: 8),
          BuildInfoLabel(
            buildInfo: widget.buildInfo ?? BuildInfo.fromEnvironment(),
          ),
        ],
      ),
    ),
  );

  Future<void> _confirmRestartFromApril() async {
    if (_isRestoring || _isRestarting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('public-demo-restart-april-dialog'),
        title: const Text('Public Demoを4月からやり直しますか？'),
        content: const Text(
          '現在のPublic Demo 0.1の進行と保存データを削除し、'
          '1年目4月の初期状態へ戻します。通常ゲームの保存データは変更しません。',
        ),
        actions: [
          TextButton(
            key: const Key('public-demo-restart-april-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('public-demo-restart-april-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('4月からやり直す'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _restartGame();
  }

  /// Clears Public Demo storage only after every earlier queued save. The
  /// terminal aggregate remains visible until clear succeeds; otherwise a
  /// failed browser write cannot silently turn into a pretend fresh session.
  Future<void> _restartGame() async {
    if (_isRestoring || _isRestarting) return;
    setState(() => _isRestarting = true);
    var cleared = false;
    try {
      cleared = await _enqueuePersistence<bool>(widget.saveService.clear);
    } catch (_) {
      cleared = false;
    }
    if (!mounted) return;
    if (!cleared) {
      setState(() => _isRestarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存データを削除できませんでした。現在のプレイを続けます。')),
      );
      return;
    }
    setState(() {
      _game = PublicDemoAggregate.initial();
      _isRestarting = false;
    });
    _resetMonthScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetMonthScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void ars(int i, PublicDemoReplacementStage x) => _commitAggregate(
    _game.withAssignmentUpdate(
      workflow.assignments[i].engineerId,
      replacementStage: x,
    ),
  );
  // Best-effort decode of an event-modal image before its dialog opens, so
  // the first painted frame already has pixels instead of a blank
  // AspectRatio box that pops in and shifts the dialog's layout once decode
  // finishes (investigation report §3C). A decode/network failure (e.g. a
  // corrupt asset) must never block game progression — each dialog's own
  // Image.errorBuilder is the only place that handles the visual fallback,
  // so failures here are swallowed silently.
  // precacheImage() catches its own decode/network errors internally and
  // never rejects the returned Future for them (it resolves the Future
  // regardless, then reports the error via FlutterError.reportError) — a
  // bare try/catch around the await does not see a corrupt asset like
  // order_decision.jpg. Passing `onError` intercepts it at the source
  // instead, so a broken image never surfaces as an unhandled framework
  // error. The outer try/catch only guards truly unexpected synchronous
  // failures (e.g. a bad BuildContext), keeping this best-effort no matter
  // what goes wrong.
  Future<void> _precacheEventImage(String asset) async {
    if (!mounted) return;
    try {
      await precacheImage(
        AssetImage(asset),
        context,
        onError: (exception, stackTrace) {},
      );
    } catch (_) {}
  }

  Future<void> ei(int i, PublicDemoInterviewType t) async {
    if (t == PublicDemoInterviewType.partner && s.salesRemaining <= 0) return;
    final e = workflow.engineers[i],
        r = PublicDemoInterviewEvaluator.evaluate(
          type: t,
          profile: e.interviewProfile,
          actualCapability: capabilityFor(e.id),
        );
    // WORKFLOW-STATE-1AB FIX5 P1: the domain derives the resulting stage
    // (and score) itself, from this engineer's own authoritative
    // interview profile/capability — `r` above is computed identically,
    // from the same (unchanged-in-between) `state`, purely for this
    // dialog's own display text; it is never passed in as the outcome.
    _commitAggregate(
      _game.recordEngineerInterviewResult(engineerId: e.id, type: t),
    );
    if (!mounted) return;
    final partner = t == PublicDemoInterviewType.partner;
    await _precacheEventImage(AssetPaths.eventClientInterview);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => PublicDemoInterviewResultDialog(
        interviewName: partner ? '上位会社面談' : '客先面談',
        personName: e.name,
        score: r.score,
        passed: r.passed,
        points: [
          partner ? '経歴・スキルの案件適合度を確認' : '技術力と現場での適合度を確認',
          r.passed ? '基準点60点をクリア' : '基準点60点に届かず',
        ],
        nextAction: r.passed
            ? (partner ? '次は客先面談へ進みます' : '面談通過。案件を受注できます')
            : '別案件へ再営業しましょう',
      ),
    );
  }

  // april()/may() used to setState the month advance *before* awaiting the
  // event dialog. showDialog's fade-in transition runs for Material's
  // default 150ms, so for that whole window the ListView behind the modal
  // barrier was already rebuilt for the next month (new cards, new button
  // labels) while the dialog itself was still fading in on top of it — two
  // unrelated text changes animating at once, which on iPhone Safari reads
  // as a momentary garbled/overlapping frame. Reordered so the month
  // (and any state it gates, e.g. `assignments`) is only committed via
  // setState *after* `await showDialog(...)` returns, i.e. after the user
  // has taken the confirm action and the dialog has fully closed — the
  // background never repaints while a dialog transition is in flight.
  // `workflow` never changes during the (non-interactive) awaited dialog, so
  // `_game.closeApril` computing `orderedEngineers` from it at commit time
  // (below) is identical to a pre-dialog snapshot — this only changes when
  // the transition is committed, not what is computed or in what order
  // events fire.
  Future<void> april() async {
    await _precacheEventImage(AssetPaths.eventRecruitmentApplication);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => const PublicDemoEventDialog(
        title: '新しい応募が届きました',
        imageAsset: AssetPaths.eventRecruitmentApplication,
        imageKey: Key('public-demo-recruitment-application-image'),
        message: '採用候補者から応募が届いています。',
        nextAction: '候補者の経歴書を確認しましょう。',
      ),
    );
    if (!mounted) return;
    _commitAggregate(_game.closeApril(monthlyExpenses: expense));
    _resetMonthScroll();
  }

  void recruit(int i) {
    // WORKFLOW-STATE-1AB FIX3 P1-1: completeInterview validates and
    // consumes the real sales-slot prerequisite and mints the applicant's
    // genuine interview record atomically — there is no longer a
    // zero-argument `markInterviewed`/`markApplicantInterviewed` a caller
    // could reach independently of that check.
    final result = _game.completeInterview(workflow.applicants[i].id);
    if (!result.isCompleted) return;
    _commitAggregate(result.aggregate);
  }

  Future<void> offer(int i) async {
    final a = workflow.applicants[i];
    final result = await showDialog(
      context: context,
      builder: (context) => PublicDemoSalaryOfferDialog(applicant: a),
    );
    if (!mounted || result == null) return;
    // WORKFLOW-STATE-1 §11: the UI only chose which candidate salary to
    // evaluate (`result` is already a pure PublicDemoSalaryOffer). Whether
    // it becomes authoritative — and whether a BindingOffer is minted at
    // all — is decided entirely inside PublicDemoOfferAcceptance.accept.
    _commitAggregate(
      _game.acceptOffer(
        applicantId: a.id,
        offer: result,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(s.month),
      ),
    );
  }

  Future<void> pi(int i) async {
    if (s.salesRemaining <= 0) return;
    final a = workflow.applicants[i];
    final score = a.salesSkillFit;
    final passed = score >= 60;
    // WORKFLOW-STATE-1AB FIX5 P1: the domain derives pass/fail itself from
    // this applicant's own authoritative salesSkillFit — `passed` above is
    // computed identically, purely for this dialog's own display text.
    _commitAggregate(_game.recordPreEntryPartnerInterviewResult(a.id));
    if (!mounted) return;
    await _precacheEventImage(AssetPaths.eventClientInterview);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => PublicDemoInterviewResultDialog(
        interviewName: '上位会社面談',
        personName: a.name,
        score: score,
        passed: passed,
        points: [
          '入社前SkillSheetと案件要件の適合度を確認',
          passed ? '基準点60点をクリア' : '基準点60点に届かず',
        ],
        nextAction: passed ? '次は客先面談へ進みます' : '別案件へ再営業しましょう',
      ),
    );
  }

  Future<void> ci(int i) async {
    final a = workflow.applicants[i];
    final score = a.salesSkillFit;
    final passed = score >= 65;
    // WORKFLOW-STATE-1AB FIX5 P1: the domain derives pass/fail itself from
    // this applicant's own authoritative salesSkillFit — `passed` above is
    // computed identically, purely for this dialog's own display text.
    _commitAggregate(_game.recordPreEntryClientInterviewResult(a.id));
    if (!mounted) return;
    await _precacheEventImage(AssetPaths.eventClientInterview);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => PublicDemoInterviewResultDialog(
        interviewName: '客先面談',
        personName: a.name,
        score: score,
        passed: passed,
        points: [
          '入社前の技術力と案件適合度を確認',
          passed ? '入社前営業の通過基準65点をクリア' : '入社前営業の通過基準65点に届かず',
        ],
        nextAction: passed ? '面談通過。6月受注へ進めます' : '別案件へ再営業しましょう',
      ),
    );
  }

  bool accepted(PublicDemoApplicant a) => {
    PublicDemoApplicantStage.offerAccepted,
    PublicDemoApplicantStage.preEntrySkillSheet,
    PublicDemoApplicantStage.preEntrySelling,
    PublicDemoApplicantStage.preEntryIntroduced,
    PublicDemoApplicantStage.preEntryPartnerPassed,
    PublicDemoApplicantStage.preEntryPartnerFailed,
    PublicDemoApplicantStage.preEntryClientPassed,
    PublicDemoApplicantStage.preEntryClientFailed,
    PublicDemoApplicantStage.juneOrdered,
  }.contains(a.stage);
  Future<void> may() async {
    final first = workflow.applicants
        .where((a) => a.stage == PublicDemoApplicantStage.juneOrdered)
        .toList();
    if (!mounted) return;
    if (first.isNotEmpty) {
      await _precacheEventImage(AssetPaths.eventFirstAssignment);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => PublicDemoEventDialog(
          title: '入社・初参画！',
          imageAsset: AssetPaths.eventFirstAssignment,
          imageKey: const Key('public-demo-first-assignment-image'),
          message: '${first.first.name}さんが入社し、案件への参画を開始しました。',
          nextAction: '参画中メンバーの翌月発注を確認しましょう。',
        ),
      );
      if (!mounted) return;
    }
    // WORKFLOW-STATE-1 §12, WORKFLOW-STATE-1AB FIX3 P1-3/P1-4: join,
    // engineer creation, assignment-roster computation, growth, and the
    // finance close all happen inside one atomic `closeMay` aggregate
    // command — there is no `assignments`/`joinedApplicants` parameter for
    // this widget to supply; both are derived entirely from the
    // aggregate's own authoritative facts.
    _commitAggregate(_game.closeMay(week: 9, monthlyExpenses: expense));
    _resetMonthScroll();
  }

  void decideOrder(int i) {
    final a = workflow.assignments[i];
    _commitAggregate(
      _game.withAssignmentUpdate(
        a.engineerId,
        nextOrderStatus: a.willOfferNextMonthFor(capabilityFor(a.engineerId))
            ? PublicDemoNextOrderStatus.offered
            : PublicDemoNextOrderStatus.notOffered,
      ),
    );
  }

  void acceptOrder(int i) {
    _commitAggregate(
      _game.withAssignmentUpdate(
        workflow.assignments[i].engineerId,
        nextOrderStatus: PublicDemoNextOrderStatus.accepted,
      ),
    );
  }

  void replacementPartner(int i) {
    if (s.salesRemaining <= 0) return;
    final a = workflow.assignments[i];
    _commitAggregate(
      _game.consumeSlotAndSetReplacementStage(
        a.engineerId,
        a.replacementPartnerScoreFor(capabilityFor(a.engineerId)) >= 60
            ? PublicDemoReplacementStage.partnerPassed
            : PublicDemoReplacementStage.partnerFailed,
      ),
    );
  }

  void replacementClient(int i) {
    final a = workflow.assignments[i];
    ars(
      i,
      a.replacementClientScoreFor(capabilityFor(a.engineerId)) >= 60
          ? PublicDemoReplacementStage.clientPassed
          : PublicDemoReplacementStage.clientFailed,
    );
  }

  void june() {
    final assigned = workflow.assignments
        .where(
          (a) =>
              a.nextOrderStatus == PublicDemoNextOrderStatus.accepted ||
              a.replacementStage == PublicDemoReplacementStage.ordered,
        )
        .length;
    final joinedHires = workflow.applicants.where(accepted);
    _commitAggregate(
      _game.closeJune(
        assignedInJuly: assigned,
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: expense,
          hires: joinedHires,
        ),
      ),
    );
    _resetMonthScroll();
  }

  Future<void> raise(int i) async {
    final a = workflow.applicants[i];
    final decision = await showDialog<PublicDemoRaiseDecision>(
      context: context,
      builder: (context) => PublicDemoRaiseDialog(applicant: a),
    );
    if (!mounted || decision == null) return;
    _commitAggregate(
      _game.applyRaiseDecision(
        a.id,
        decisionMonth: s.month,
        week: s.month * 4,
        decision: decision,
      ),
    );
  }

  int get _julyMonthlyExpenses => PublicDemoSalaryFinance.monthlyExpenses(
    baselineExpenses: expense,
    hires: workflow.joinedApplicants,
    month: 7,
  );

  /// The outstanding actions the Month Guard should warn about for the
  /// current month-close attempt (Issue #119), built from the SAME
  /// `_recommendedActionCandidates` HOME's one recommended-action slot
  /// already uses — never a second, widget-local re-derivation of which
  /// actions are outstanding.
  ///
  /// Two kinds are deliberately excluded before the guard ever sees them:
  ///
  ///  * [HomeRecommendedActionKind.cashShortageResponse] — purely
  ///    informational (`HomeRecommendedActionKind.isInformational`); an
  ///    informational item must never produce a warning.
  ///  * [HomeRecommendedActionKind.summerBonusDecision] — already owned
  ///    exclusively by the `required` rule above; `july()` never reaches
  ///    this getter while it is outstanding (it returns from
  ///    `decideSummerBonus` first), so this exclusion is defense in depth,
  ///    not load-bearing.
  List<PublicDemoMonthGuardCandidate> get _monthGuardRecommendedCandidates => [
    for (final candidate in _recommendedActionCandidates)
      if (!candidate.action.kind.isInformational &&
          candidate.action.kind !=
              HomeRecommendedActionKind.summerBonusDecision)
        PublicDemoMonthGuardCandidate(
          id: candidate.action.targetId == null
              ? candidate.action.kind.name
              : '${candidate.action.kind.name}:${candidate.action.targetId}',
          actionName: candidate.action.headline,
        ),
  ];

  /// The Domain-owned Month Guard's outstanding items for the current
  /// month-close attempt (Issue #119). This is the single source of truth
  /// for "is a required decision still outstanding" and "which recommended
  /// actions remain" — callers must consult it instead of independently
  /// re-deriving either condition (e.g. reading
  /// `s.summerBonusDecisionConfirmed` directly).
  List<PublicDemoMonthGuardItem> get _monthGuardItems =>
      PublicDemoMonthGuard.evaluate(
        month: s.month,
        monthCloseApplicable: !s.isCloseBlocked,
        summerBonusDecisionConfirmed: s.summerBonusDecisionConfirmed,
        outstandingRecommendedActions: _monthGuardRecommendedCandidates,
      );

  bool get _summerBonusDecisionRequired => _monthGuardItems.any(
    (item) => item.id == PublicDemoMonthGuard.summerBonusDecisionItemId,
  );

  Future<void> decideSummerBonus() async {
    final decision = await showDialog<PublicDemoSummerBonusPlan>(
      context: context,
      builder: (context) => PublicDemoSummerBonusDialog(
        state: s,
        applicants: workflow.joinedApplicants,
        monthlyExpenses: _julyMonthlyExpenses,
      ),
    );
    if (!mounted || decision == null) return;
    _commitAggregate(_game.confirmSummerBonusDecision(decision));
  }

  /// Issue #119 PLAYTHROUGH-BLOCKER-1: asks before a month-close attempt
  /// proceeds while `recommended`-level items are outstanding. Returns
  /// `true` when the caller may close the month — either nothing is
  /// outstanding, or the player chose to proceed anyway. A `required` item
  /// is never passed to this: the caller (`july()`) resolves it first and
  /// never reaches this check while one remains.
  Future<bool> _confirmMonthCloseIfRecommendedOutstanding() async {
    final recommended = _monthGuardItems
        .where((item) => item.level == PublicDemoMonthGuardLevel.recommended)
        .toList();
    if (recommended.isEmpty) return true;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          PublicDemoMonthGuardWarningDialog(items: recommended),
    );
    if (!mounted) return false;
    return proceed ?? false;
  }

  Future<void> july() async {
    // Month Guard enforcement lives here, above `closeJuly` — the aggregate
    // entry point itself stays ungated (Issue #119 PR1).
    //
    // Issue #119 PLAYTHROUGH-BLOCKER-1 deliberately does NOT add the new
    // `recommended`-level confirmation here: July already has its own
    // required decision gate above, and July's canonical CTA closing into
    // August on a single, unconditional tap (once that decision is made)
    // is an existing, heavily-pinned contract across this suite (#118's
    // single-CTA guarantee, #133's "none" route, and every trajectory
    // helper that closes July as one atomic step). The gap this issue
    // names ("7月以外でも…警告なしで月末処理できる") is `closeOrdinaryMonth`
    // below, which had no Month Guard check of any kind before this change
    // — that is where the new `recommended` confirmation lives.
    if (_summerBonusDecisionRequired) {
      await decideSummerBonus();
      return;
    }
    _commitAggregate(_game.closeJuly(monthlyExpenses: _julyMonthlyExpenses));
    _resetMonthScroll();
  }

  int get _ordinaryMonthlyExpenses => PublicDemoSalaryFinance.monthlyExpenses(
    baselineExpenses: expense,
    hires: workflow.joinedApplicants,
    month: s.month,
  );

  /// Closes any ordinary month from August through March (12MONTH-3). It
  /// mirrors [june]/[july]'s shape (grow, then close) but delegates to the
  /// common `PublicDemoAggregate.closeOrdinaryMonth` entry point instead of
  /// a dedicated per-month handler, since September onward has no
  /// month-specific event the way July's bonus does.
  ///
  /// Issue #119 PLAYTHROUGH-BLOCKER-1: unlike July, August-March never had
  /// any Month Guard check at all before this — this is the extension that
  /// closes that gap, at the `recommended` level only (there is no required
  /// rule outside July).
  Future<void> closeOrdinaryMonth() async {
    if (!await _confirmMonthCloseIfRecommendedOutstanding()) return;
    _commitAggregate(
      _game.closeOrdinaryMonth(monthlyExpenses: _ordinaryMonthlyExpenses),
    );
    _resetMonthScroll();
  }

  String julyResult(PublicDemoAssignment a) {
    if (a.nextOrderStatus == PublicDemoNextOrderStatus.accepted) {
      return '現案件を継続';
    }
    if (a.replacementStage == PublicDemoReplacementStage.ordered) {
      return '新案件へ切替';
    }
    return '待機（営業が必要）';
  }

  String engineerStatus(PublicDemoEngineerSales e) => switch (e.stage) {
    PublicDemoSalesStage.waiting => '待機',
    PublicDemoSalesStage.skillSheet => '営業準備',
    PublicDemoSalesStage.selling => '営業中',
    PublicDemoSalesStage.introduced => '案件紹介済',
    PublicDemoSalesStage.partnerInterviewPassed => '上位面談通過',
    PublicDemoSalesStage.partnerInterviewFailed => '上位面談不合格',
    PublicDemoSalesStage.clientInterviewPassed => '客先面談通過',
    PublicDemoSalesStage.clientInterviewFailed => '客先面談不合格',
    PublicDemoSalesStage.ordered => '翌月参画予定',
  };
  int engineerStep(PublicDemoEngineerSales e) => switch (e.stage) {
    PublicDemoSalesStage.waiting || PublicDemoSalesStage.skillSheet => 0,
    PublicDemoSalesStage.selling => 1,
    PublicDemoSalesStage.introduced => 2,
    PublicDemoSalesStage.partnerInterviewPassed ||
    PublicDemoSalesStage.partnerInterviewFailed => 3,
    PublicDemoSalesStage.clientInterviewPassed ||
    PublicDemoSalesStage.clientInterviewFailed => 4,
    PublicDemoSalesStage.ordered => 5,
  };
  String applicantStatus(PublicDemoApplicant a) => switch (a.stage) {
    PublicDemoApplicantStage.applied => '応募',
    PublicDemoApplicantStage.resumeReviewed => '書類確認済',
    PublicDemoApplicantStage.interviewed => '採用面談済',
    PublicDemoApplicantStage.rejected => '不採用',
    PublicDemoApplicantStage.offerAccepted => '内定承諾',
    PublicDemoApplicantStage.offerDeclined => '内定辞退',
    PublicDemoApplicantStage.preEntrySkillSheet => '入社前営業準備',
    PublicDemoApplicantStage.preEntrySelling => '入社前営業中',
    PublicDemoApplicantStage.preEntryIntroduced => '案件紹介済',
    PublicDemoApplicantStage.preEntryPartnerPassed => '上位面談通過',
    PublicDemoApplicantStage.preEntryPartnerFailed => '上位面談不合格',
    PublicDemoApplicantStage.preEntryClientPassed => '客先面談通過',
    PublicDemoApplicantStage.preEntryClientFailed => '客先面談不合格',
    PublicDemoApplicantStage.juneOrdered => '入社・参画予定',
  };
  int applicantStep(PublicDemoApplicant a) => switch (a.stage) {
    PublicDemoApplicantStage.applied ||
    PublicDemoApplicantStage.resumeReviewed ||
    PublicDemoApplicantStage.interviewed ||
    PublicDemoApplicantStage.rejected ||
    PublicDemoApplicantStage.offerAccepted ||
    PublicDemoApplicantStage.offerDeclined ||
    PublicDemoApplicantStage.preEntrySkillSheet => 0,
    PublicDemoApplicantStage.preEntrySelling => 1,
    PublicDemoApplicantStage.preEntryIntroduced => 2,
    PublicDemoApplicantStage.preEntryPartnerPassed ||
    PublicDemoApplicantStage.preEntryPartnerFailed => 3,
    PublicDemoApplicantStage.preEntryClientPassed ||
    PublicDemoApplicantStage.preEntryClientFailed => 4,
    PublicDemoApplicantStage.juneOrdered => 5,
  };
  // HOME-RUNTIME-2A: `monthGoal()` and `stat()` are gone from this screen.
  //
  //  * The month-goal `switch` MOVED to
  //    `HomeDashboardDisplayData.monthGoalText` and is rendered once, by the
  //    HOME section's `今月やること` slot. It was not copied — there is still
  //    exactly one month-goal table in the app.
  //  * The 現預金/参画/待機/営業残 stat row is deleted: all four values are in
  //    the merged compact KPI, which reads them from the same authoritative
  //    fields. Note the cash tile keeps HOME-RUNTIME-READ-1's truncating
  //    `~/` semantics rather than this row's old `floor()`.
  //
  // What is left here is the post-close detail this phase does not touch.
  Widget dashboard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (s.latestMonthlyCashFlow != null) ...[
        KeyedSubtree(
          key: _monthlyCashFlowKey,
          child: PublicDemoMonthlyCashFlowCard(flow: s.latestMonthlyCashFlow!),
        ),
        const SizedBox(height: 8),
      ],
      if (s.latestGrowthResults.isNotEmpty) ...[
        const Text('今月の成長', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        for (final result in s.latestGrowthResults)
          PublicDemoGrowthResultCard(
            engineerName: _engineerName(result.engineerId),
            result: result,
          ),
      ],
    ],
  );

  String _engineerName(String engineerId) {
    for (final engineer in workflow.engineers) {
      if (engineer.id == engineerId) return engineer.name;
    }
    for (final applicant in workflow.applicants) {
      if (applicant.id == engineerId) return applicant.name;
    }
    return '社員';
  }

  Widget badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
  Widget employeeConditionCard(PublicDemoApplicant a) {
    final morale = a.employeeMorale!, trust = a.employeeCompanyTrust!;
    final reason = a.relationshipHistory.last.reason;
    return Card(
      key: Key('public-demo-employee-condition-${a.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '社員コンディション',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('モチベーション：${PublicDemoEmployeeCondition.label(morale)}'),
            Text('会社への信頼：${PublicDemoEmployeeCondition.label(trust)}'),
            const SizedBox(height: 4),
            Text(reason, style: Theme.of(context).textTheme.bodySmall),
            if (!s.isCloseBlocked && a.canRequestRaiseIn(s.month)) ...const [
              SizedBox(height: 8),
            ],
            if (!s.isCloseBlocked && a.canRequestRaiseIn(s.month))
              FilledButton(
                key: Key('public-demo-raise-request-${a.id}'),
                onPressed: () =>
                    raise(workflow.applicants.indexWhere((x) => x.id == a.id)),
                child: const Text('昇給要求を確認'),
              ),
          ],
        ),
      ),
    );
  }

  Widget internalTrainingCard({
    required String engineerId,
    required String engineerName,
    bool showEngineerName = true,
  }) {
    final selected = s.trainingSelections.containsKey(engineerId);
    final assigned = _currentlyAssignedEngineerIds.contains(engineerId);
    final affordable = s.cash >= PublicDemoInternalTrainingTransaction.cost;
    if (assigned) return const SizedBox.shrink();
    // POST-12MONTH-1 / FINANCE-FAILURE-1A+1B: once the fiscal year is
    // completed, or a terminal financial status (BANKRUPTCY / MARCH
    // CASH-SHORTAGE FAILURE) is reached, Public Demo 0.1 is a read-only
    // terminal state — the training action is hidden rather than shown
    // disabled, while the card itself stays visible as read-only info. This
    // mirrors the domain-level guard already enforced by
    // PublicDemoInternalTrainingTransaction regardless of this UI check
    // (WORKFLOW-STATE-1's "never rely on UI alone" contract).
    final showAction = !selected && !s.isCloseBlocked;
    return Card(
      key: Key('public-demo-internal-training-$engineerId'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Whose card this is only needs saying when the card
                  // stands on its own (the month >= 6 list). Nested inside
                  // an employee card the name is already the line above,
                  // and repeating it is what made this a full-height card.
                  if (showEngineerName)
                    Text(
                      '$engineerName（待機）',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  Text(
                    selected ? '社内研修 ¥30,000（今月は社内研修）' : '社内研修 ¥30,000',
                    style: const TextStyle(fontSize: 13),
                  ),
                  // The training action's own affordability guard is
                  // unchanged (`s.cash >= PublicDemoInternalTrainingTransaction.cost`);
                  // only the ¥-preview line that restated cash a fourth
                  // time on this screen is gone.
                  if (showAction && !affordable)
                    const Text('現預金が不足しています。', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            if (showAction) ...[
              const SizedBox(width: 8),
              FilledButton(
                key: Key('public-demo-internal-training-action-$engineerId'),
                style: _publicDemoCompactFilledButtonStyle(context),
                onPressed: affordable
                    ? () => _selectInternalTraining(engineerId)
                    : null,
                child: const Text('研修する'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The Public Demo screen widens every FilledButton's padding (see
  /// [_publicDemoFilledButtonStyle]); the one-line training action opts back
  /// out of that so a secondary action does not set the height of the row
  /// it sits in. Purely visual — it changes no command, guard, or key.
  ButtonStyle? _publicDemoCompactFilledButtonStyle(BuildContext c) =>
      Theme.of(c).filledButtonTheme.style?.copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  // =====================================================================
  // HOME-RUNTIME-2C — Recommended Action: eligibility emission
  // =====================================================================
  //
  // This screen is the eligibility authority, and this is the only place
  // that decides *which* actions are recommendable. HOME ranks and renders
  // what it is given; it never asks a question of its own.
  //
  // The rule every emit site below follows, without exception:
  //
  //   A candidate is emitted only from the same `if (s.month == N)` branch,
  //   under the same predicate, as the production button it triggers.
  //
  // That is not a stylistic preference — it is the whole correctness
  // argument. Action availability in Public Demo is not expressible as a
  // per-action predicate: it is a predicate *inside a month-gated UI
  // branch*. `canUseRecruitmentMediaInMonth(month)` is the standing example
  // — it is satisfied in months where no 求人媒体 card is rendered at all, so
  // a recommendation engine that consulted the predicate alone would offer
  // the player a button that does not exist. Reading the predicate at the
  // render site instead makes that class of bug unrepresentable.
  //
  // Consequences worth stating explicitly:
  //
  //  * Nothing here re-implements a game rule. Every predicate below is
  //    read verbatim off the authority (`s`, `workflow`, the same getters
  //    the buttons already use); none is recombined into a new one.
  //  * Nothing disabled is ever emitted. Where a button has an enablement
  //    condition (`salesRemaining > 0`, affordability, interview score),
  //    the candidate carries that same condition, so the CTA is never a
  //    dead affordance.
  //  * Every domain guard still runs anyway. `invoke` enters
  //    `PublicDemoAggregate` through the same command, so the UI check
  //    below is a second line of defence, never the only one.
  //  * The month close is deliberately never a candidate: MONTH END CTA
  //    PLAN keeps it at the bottom of the scroll, and it belongs to
  //    HOME-RUNTIME-2D.

  /// The recommended-action slot for this build.
  ///
  /// A getter, never a [State] field, for exactly the reason
  /// [_homeDashboardData] is one: it is evaluated while [build] runs, so it
  /// always describes the state of *that* build and can never go stale.
  /// Presentation ranking is not persisted and not authoritative (SAVE
  /// AUTHORITY) — nothing here is written back to [_game].
  HomeRecommendedActionSlot get _recommendedActionSlot {
    // TERMINAL PLAN: bankruptcy, the March cash-shortage failure and fiscal
    // completion all mean the same thing for this slot — there is no next
    // action. `isCloseBlocked` is the authority's own name for exactly that
    // set, so the check reads it rather than restating its three cases.
    //
    // This decision is made here, by the owner that can see
    // `financialStatus` and `fiscalYearCompleted`, and only its *outcome*
    // crosses into HOME. The projection still carries no financial verdict,
    // so HOME remains structurally unable to render one.
    if (s.isCloseBlocked) return const HomeRecommendedActionSuppressed();

    final selected = selectHomeRecommendedAction(_recommendedActionCandidates);
    return selected == null
        ? const HomeRecommendedActionNone()
        : HomeRecommendedActionAvailable(selected);
  }

  /// Every action that is legal *and* on screen right now, in the order
  /// [build] renders it. Ordering matters only as the selector's tie-break
  /// (`workflow.engineers` / `.applicants` / `.assignments` order, per the
  /// design); which one wins is decided by presentation priority.
  List<HomeRecommendedActionCandidate> get _recommendedActionCandidates {
    final candidates = <HomeRecommendedActionCandidate>[];

    void add(
      HomeRecommendedActionKind kind,
      VoidCallback invoke, {
      String? subjectName,
      String? targetId,
    }) {
      candidates.add(
        HomeRecommendedActionCandidate(
          action: HomeRecommendedAction(
            kind: kind,
            subjectName: subjectName,
            targetId: targetId,
          ),
          invoke: invoke,
        ),
      );
    }

    // ---- P0: the shortage card, which build() renders above HOME in
    // every month while this status holds. FINANCE AUTHORITY is untouched:
    // this reads the authoritative status to decide what to show the
    // player. PLAYTEST-BLOCKER-1A: the CTA now opens a dialog that
    // produces visible feedback regardless of scroll position — the former
    // scroll-to-zero was inert when the player was already at the top.
    if (s.financialStatus == PublicDemoFinancialStatus.cashShortage) {
      add(
        HomeRecommendedActionKind.cashShortageResponse,
        () => unawaited(_showCashShortageExplanation()),
      );
    }

    // ---- month 4: `for (...) ec(i)` ----------------------------------
    if (s.month == 4) {
      for (final e in workflow.engineers) {
        _addEngineerStageCandidate(add, e);
      }
    }

    // ---- month 5: recruitment media, then `for (...) ac(i)` ----------
    if (s.month == 5) {
      _addRecruitmentMediaCandidate(add);
      for (final a in workflow.applicants) {
        _addApplicantStageCandidate(add, a);
      }
    }

    // ---- month 6: condition cards, the still-selling engineers, then
    // the assignment cards — the same three loops, with the same filters.
    if (s.month == 6) {
      for (final a in _joinedEmployees) {
        _addRaiseCandidate(add, a);
      }
      for (final e in workflow.engineers) {
        if (!s.joinedApplicantIds.contains(e.id)) continue;
        if (e.stage == PublicDemoSalesStage.ordered) continue;
        if (workflow.assignments.any((x) => x.engineerId == e.id)) continue;
        _addEngineerStageCandidate(add, e);
      }
      for (final a in workflow.assignments) {
        _addAssignmentCandidate(add, a);
      }
    }

    // ---- month 7: the summer-bonus decision --------------------------
    //
    if (s.month == 7) {
      // The bonus button is rendered (and enabled) all month and doubles
      // as `夏季賞与を変更` once decided. Only the *undecided* case is
      // recommendable — re-deciding is not the next thing to do.
      if (!s.summerBonusDecisionConfirmed) {
        add(
          HomeRecommendedActionKind.summerBonusDecision,
          () => unawaited(decideSummerBonus()),
        );
      }
    }

    // ---- month >= 7: the standalone condition cards ------------------
    if (s.month >= 7) {
      for (final a in _joinedEmployees) {
        _addRaiseCandidate(add, a);
      }
    }

    // ---- months 7-14: every economically-waiting engineer's sales-flow
    // card (RECOVERY-LOOP-1's own window), verbatim the same filter the
    // `ec(i, showTrainingCard: false)` render site further down uses
    // (Issue #119 PLAYTHROUGH-BLOCKER-2). Before this, nothing in this
    // window — including the `案件へ復帰` Recovery button once an engineer
    // reaches `ordered` — was ever visible to the recommended-action
    // authority at all, regardless of cash shortage.
    if (s.month >= 7 && s.month <= 14) {
      for (final e in workflow.engineers) {
        if (workflow.assignedEngineerIds(month: s.month).contains(e.id)) {
          continue;
        }
        _addEngineerStageCandidate(add, e);
      }
    }

    return candidates;
  }

  /// The joined employees `employeeConditionCard` is rendered for — the
  /// same `where` clause, read once so months 6 and 7+ cannot drift.
  Iterable<PublicDemoApplicant> get _joinedEmployees => workflow.applicants
      .where((a) => s.joinedApplicantIds.contains(a.id) && a.hasJoined);

  /// Mirrors `ec(i)`'s stage buttons, branch for branch. The two `Ready`
  /// stages emit nothing when `readyForFieldSales` is false, exactly as the
  /// card renders no button there.
  void _addEngineerStageCandidate(
    _AddCandidate add,
    PublicDemoEngineerSales e,
  ) {
    void emit(HomeRecommendedActionKind kind, VoidCallback invoke) =>
        add(kind, invoke, subjectName: e.name, targetId: e.id);

    switch (e.stage) {
      case PublicDemoSalesStage.waiting:
        if (readyForFieldSales(e.id)) {
          emit(
            HomeRecommendedActionKind.employeeSkillSheetReview,
            () => unawaited(_openSkillSheetReview(e)),
          );
        }
      case PublicDemoSalesStage.skillSheet:
        if (readyForFieldSales(e.id)) {
          emit(
            HomeRecommendedActionKind.employeeBeginSelling,
            () => _beginSelling(e.id),
          );
        }
      case PublicDemoSalesStage.selling:
        emit(
          HomeRecommendedActionKind.employeeIntroduceProject,
          () => _introduceProject(e.id),
        );
      case PublicDemoSalesStage.introduced:
        // `上位会社面談` is the one engineer button with an enablement
        // condition; an exhausted sales slot means no candidate, not a
        // disabled CTA.
        if (s.salesRemaining > 0) {
          emit(
            HomeRecommendedActionKind.employeePartnerInterview,
            () => unawaited(
              ei(
                workflow.engineers.indexWhere((x) => x.id == e.id),
                PublicDemoInterviewType.partner,
              ),
            ),
          );
        }
      case PublicDemoSalesStage.partnerInterviewPassed:
        emit(
          HomeRecommendedActionKind.employeeClientInterview,
          () => unawaited(
            ei(
              workflow.engineers.indexWhere((x) => x.id == e.id),
              PublicDemoInterviewType.client,
            ),
          ),
        );
      case PublicDemoSalesStage.clientInterviewPassed:
        emit(
          HomeRecommendedActionKind.employeeAcceptOrder,
          () => unawaited(_recordEngineerOrder(e)),
        );
      case PublicDemoSalesStage.partnerInterviewFailed:
      case PublicDemoSalesStage.clientInterviewFailed:
        emit(
          HomeRecommendedActionKind.employeeResumeSelling,
          () => _beginSelling(e.id),
        );
      case PublicDemoSalesStage.ordered:
        // Issue #119 PLAYTHROUGH-BLOCKER-2: the same `案件へ復帰` button
        // `ec()` renders (WORKFLOW months 7-14) once
        // `PublicDemoRecoveryEligibility.isEligible` holds — the exact
        // authority the button itself already re-checks before acting.
        // Calling it here for month 4/6 emissions too is safe: it always
        // returns false outside its own month window
        // (`PublicDemoRecoveryEligibility.isMonthEligible`), matching the
        // fact that no such button is rendered there either.
        if (PublicDemoRecoveryEligibility.isEligible(
          state: s,
          workflow: workflow,
          engineerId: e.id,
        )) {
          emit(
            HomeRecommendedActionKind.recoveryAssignment,
            () => _recoverAssignment(e.id),
          );
        }
    }
  }

  /// Mirrors `ac(i)`'s stage buttons, branch for branch.
  void _addApplicantStageCandidate(_AddCandidate add, PublicDemoApplicant a) {
    void emit(HomeRecommendedActionKind kind, VoidCallback invoke) =>
        add(kind, invoke, subjectName: a.name, targetId: a.id);

    final index = workflow.applicants.indexWhere((x) => x.id == a.id);

    switch (a.stage) {
      case PublicDemoApplicantStage.applied:
        emit(
          HomeRecommendedActionKind.applicantReviewResume,
          () => _reviewResume(a.id),
        );
      case PublicDemoApplicantStage.resumeReviewed:
        if (s.salesRemaining > 0) {
          emit(
            HomeRecommendedActionKind.applicantInterview,
            () => recruit(index),
          );
        }
      case PublicDemoApplicantStage.interviewed:
        if (a.interviewScore >= 60) {
          emit(
            HomeRecommendedActionKind.applicantSalaryOffer,
            () => unawaited(offer(index)),
          );
        }
      case PublicDemoApplicantStage.offerAccepted:
        // The card renders a button only for the pre-join sales path; the
        // other branch is the read-only `入社後、研修で育成します` line.
        if (a.canEnterPreJoinSales) {
          emit(
            HomeRecommendedActionKind.applicantBeginPreEntrySkillSheet,
            () => _beginPreEntrySkillSheet(a.id),
          );
        }
      case PublicDemoApplicantStage.preEntrySkillSheet:
        emit(
          HomeRecommendedActionKind.applicantBeginPreEntrySelling,
          () => _beginPreEntrySelling(a.id),
        );
      case PublicDemoApplicantStage.preEntrySelling:
        emit(
          HomeRecommendedActionKind.applicantIntroduceProject,
          () => _introducePreEntryProject(a.id),
        );
      case PublicDemoApplicantStage.preEntryIntroduced:
        if (s.salesRemaining > 0) {
          emit(
            HomeRecommendedActionKind.applicantPartnerInterview,
            () => unawaited(pi(index)),
          );
        }
      case PublicDemoApplicantStage.preEntryPartnerPassed:
        emit(
          HomeRecommendedActionKind.applicantClientInterview,
          () => unawaited(ci(index)),
        );
      case PublicDemoApplicantStage.preEntryClientPassed:
        emit(
          HomeRecommendedActionKind.applicantJuneOrder,
          () => unawaited(_recordApplicantJuneOrder(a)),
        );
      case PublicDemoApplicantStage.rejected:
      case PublicDemoApplicantStage.offerDeclined:
      case PublicDemoApplicantStage.preEntryPartnerFailed:
      case PublicDemoApplicantStage.preEntryClientFailed:
      case PublicDemoApplicantStage.juneOrdered:
        // No button on the card at these stages, so no candidate.
        break;
    }
  }

  /// Mirrors `assignmentCard(i)`, branch for branch — including the fact
  /// that the whole replacement chain only exists under `notOffered`.
  void _addAssignmentCandidate(_AddCandidate add, PublicDemoAssignment a) {
    final index = workflow.assignments.indexWhere(
      (x) => x.engineerId == a.engineerId,
    );
    void emit(HomeRecommendedActionKind kind, VoidCallback invoke) =>
        add(kind, invoke, subjectName: a.engineerName, targetId: a.engineerId);

    switch (a.nextOrderStatus) {
      case PublicDemoNextOrderStatus.undecided:
        emit(
          HomeRecommendedActionKind.assignmentConfirmNextOrder,
          () => decideOrder(index),
        );
      case PublicDemoNextOrderStatus.offered:
        emit(
          HomeRecommendedActionKind.assignmentAcceptNextOrder,
          () => acceptOrder(index),
        );
      case PublicDemoNextOrderStatus.accepted:
        // `7月：現案件継続予定` — nothing left to do for this engineer.
        break;
      case PublicDemoNextOrderStatus.notOffered:
        switch (a.replacementStage) {
          case PublicDemoReplacementStage.none:
            emit(
              HomeRecommendedActionKind.assignmentBeginReplacementSelling,
              () => ars(index, PublicDemoReplacementStage.selling),
            );
          case PublicDemoReplacementStage.selling:
            emit(
              HomeRecommendedActionKind.assignmentIntroduceReplacementProject,
              () => ars(index, PublicDemoReplacementStage.introduced),
            );
          case PublicDemoReplacementStage.introduced:
            if (s.salesRemaining > 0) {
              emit(
                HomeRecommendedActionKind.assignmentReplacementPartnerInterview,
                () => replacementPartner(index),
              );
            }
          case PublicDemoReplacementStage.partnerPassed:
            emit(
              HomeRecommendedActionKind.assignmentReplacementClientInterview,
              () => replacementClient(index),
            );
          case PublicDemoReplacementStage.partnerFailed:
          case PublicDemoReplacementStage.clientFailed:
            emit(
              HomeRecommendedActionKind.assignmentResumeReplacementSelling,
              () => ars(index, PublicDemoReplacementStage.selling),
            );
          case PublicDemoReplacementStage.clientPassed:
            emit(
              HomeRecommendedActionKind.assignmentAcceptReplacementOrder,
              () => ars(index, PublicDemoReplacementStage.ordered),
            );
          case PublicDemoReplacementStage.ordered:
            // `7月：新案件参画予定` — nothing left to do.
            break;
        }
    }
  }

  /// Mirrors `employeeConditionCard`'s raise button. `isCloseBlocked` is
  /// already excluded upstream; `canRequestRaiseIn` stays the authority.
  void _addRaiseCandidate(_AddCandidate add, PublicDemoApplicant a) {
    if (!a.canRequestRaiseIn(s.month)) return;
    add(
      HomeRecommendedActionKind.raiseRequest,
      () =>
          unawaited(raise(workflow.applicants.indexWhere((x) => x.id == a.id))),
      subjectName: a.name,
      targetId: a.id,
    );
  }

  /// Mirrors `_RecruitmentMediaCard`'s enablement: the card is rendered all
  /// month, but its button is disabled once the month's single use is
  /// spent, so only the usable case is a candidate.
  ///
  /// Called from the month-5 branch only, where `_RecruitmentMediaCard` and
  /// `ac(i)` are rendered together. This keeps recruitment's user-visible
  /// entry point on the only month that renders its applicant pipeline.
  void _addRecruitmentMediaCandidate(_AddCandidate add) {
    if (!s.canUseRecruitmentMediaInMonth(s.month)) return;
    add(
      HomeRecommendedActionKind.recruitmentMedia,
      () => unawaited(_openRecruitmentMedia()),
    );
  }

  // Internal training is deliberately not emitted — see
  // HomeRecommendedActionKind's "deliberate absences".

  Widget assignmentCard(int i) {
    final a = workflow.assignments[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  a.engineerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                badge(
                  a.nextOrderStatus == PublicDemoNextOrderStatus.accepted
                      ? '継続予定'
                      : '参画中',
                ),
              ],
            ),
            Text(a.projectName),
            if (a.nextOrderStatus == PublicDemoNextOrderStatus.undecided)
              FilledButton.tonal(
                onPressed: () => decideOrder(i),
                child: const Text('7月分の発注を確認'),
              ),
            if (a.nextOrderStatus == PublicDemoNextOrderStatus.offered) ...[
              const Text('7月分発注あり'),
              FilledButton(
                onPressed: () => acceptOrder(i),
                child: const Text('受注する'),
              ),
            ],
            if (a.nextOrderStatus == PublicDemoNextOrderStatus.accepted)
              const Text('7月：現案件継続予定'),
            if (a.nextOrderStatus == PublicDemoNextOrderStatus.notOffered) ...[
              const Text('7月分発注なし'),
              if (a.replacementStage == PublicDemoReplacementStage.none)
                FilledButton(
                  onPressed: () => ars(i, PublicDemoReplacementStage.selling),
                  child: const Text('次案件の営業開始'),
                ),
              if (a.replacementStage == PublicDemoReplacementStage.selling)
                FilledButton.tonal(
                  onPressed: () =>
                      ars(i, PublicDemoReplacementStage.introduced),
                  child: const Text('案件紹介'),
                ),
              if (a.replacementStage == PublicDemoReplacementStage.introduced)
                FilledButton(
                  onPressed: s.salesRemaining > 0
                      ? () => replacementPartner(i)
                      : null,
                  child: const Text('上位会社面談（1枠）'),
                ),
              if (a.replacementStage ==
                  PublicDemoReplacementStage.partnerPassed)
                FilledButton.tonal(
                  onPressed: () => replacementClient(i),
                  child: const Text('客先面談（0枠）'),
                ),
              if (a.replacementStage ==
                      PublicDemoReplacementStage.partnerFailed ||
                  a.replacementStage == PublicDemoReplacementStage.clientFailed)
                FilledButton.tonal(
                  onPressed: () => ars(i, PublicDemoReplacementStage.selling),
                  child: const Text('別案件へ'),
                ),
              if (a.replacementStage == PublicDemoReplacementStage.clientPassed)
                FilledButton(
                  onPressed: () => ars(i, PublicDemoReplacementStage.ordered),
                  child: const Text('7月分を受注'),
                ),
              if (a.replacementStage == PublicDemoReplacementStage.ordered)
                const Text('7月：新案件参画予定'),
            ],
          ],
        ),
      ),
    );
  }

  Widget ec(int i, {bool showTrainingCard = true}) {
    final e = workflow.engineers[i];
    final capability = capabilityFor(e.id);
    final fieldSalesRequirement =
        PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                badge(engineerStatus(e)),
              ],
            ),
            const SizedBox(height: 4),
            Text(e.summary),
            PublicDemoSalesProgress(currentStep: engineerStep(e)),
            const SizedBox(height: 8),
            if (!readyForFieldSales(e.id) &&
                (e.stage == PublicDemoSalesStage.waiting ||
                    e.stage == PublicDemoSalesStage.skillSheet))
              Container(
                key: Key('public-demo-field-sales-lock-${e.id}'),
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '営業開始には実力 $fieldSalesRequirement 以上が必要です（現在 $capability）。',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // P1 (PR #115 review): this used to promise that
                    // training would eventually unlock 営業準備
                    // （SkillSheet確認） here. It doesn't — this card, and the
                    // stage buttons above, only render in the specific
                    // month(s) each engineer's sales stage is worked (April
                    // for founding engineers, the join month for hires); once
                    // that month closes without meeting
                    // fieldSalesCapabilityRequirement, no later month offers
                    // this action again, no matter how much further capability
                    // training raises. State the lock plainly instead of
                    // implying a path back to it that this build cannot
                    // actually provide.
                    const Text('まだ営業を始められません。', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            if (e.stage == PublicDemoSalesStage.waiting &&
                readyForFieldSales(e.id)) ...[
              const Text('営業準備OK', style: TextStyle(fontSize: 12)),
              FilledButton(
                onPressed: () => unawaited(_openSkillSheetReview(e)),
                child: const Text('SkillSheet確認'),
              ),
            ],
            if (e.stage == PublicDemoSalesStage.skillSheet &&
                readyForFieldSales(e.id))
              FilledButton(
                onPressed: () => _beginSelling(e.id),
                child: const Text('営業開始'),
              ),
            if (e.stage == PublicDemoSalesStage.selling)
              FilledButton(
                onPressed: () => _introduceProject(e.id),
                child: const Text('案件紹介'),
              ),
            if (e.stage == PublicDemoSalesStage.introduced)
              FilledButton(
                onPressed: s.salesRemaining > 0
                    ? () => ei(i, PublicDemoInterviewType.partner)
                    : null,
                child: const Text('上位会社面談'),
              ),
            if (e.stage == PublicDemoSalesStage.partnerInterviewPassed)
              FilledButton(
                onPressed: () => ei(i, PublicDemoInterviewType.client),
                child: const Text('客先面談'),
              ),
            if (e.stage == PublicDemoSalesStage.clientInterviewPassed)
              FilledButton(
                onPressed: () => _recordEngineerOrder(e),
                child: const Text('受注'),
              ),
            // RECOVERY-LOOP-1: the same `ordered` stage
            // `assignOrderedForMay` already harvests every May — from July
            // (internal month 7) through February (14), this is instead
            // the only entry point that turns it into an actual
            // assignment, since no month past June re-runs
            // `assignOrderedForMay`'s wholesale roster rebuild. The button
            // itself only ever renders when
            // `PublicDemoRecoveryEligibility.isEligible` already holds
            // (economically waiting, training-unselected, runtime-ready,
            // non-terminal, within the Recovery month window); the
            // eligibility check is still re-run by
            // `PublicDemoAggregate.recoverAssignment` before it does
            // anything.
            if (e.stage == PublicDemoSalesStage.ordered &&
                PublicDemoRecoveryEligibility.isEligible(
                  state: s,
                  workflow: workflow,
                  engineerId: e.id,
                ))
              FilledButton(
                key: Key('public-demo-recovery-assignment-${e.id}'),
                onPressed: () => _recoverAssignment(e.id),
                child: const Text('案件へ復帰'),
              ),
            if (e.stage == PublicDemoSalesStage.partnerInterviewFailed ||
                e.stage == PublicDemoSalesStage.clientInterviewFailed)
              FilledButton(
                onPressed: () => _beginSelling(e.id),
                child: const Text('再営業'),
              ),
            // HOME-RUNTIME-2A: internal training is this employee's
            // *secondary* action, so it now sits after their sales action
            // instead of between their identity and it. Same command, same
            // eligibility, same keys — only the position and the row height
            // changed, and the point of both is that the sales action can no
            // longer be pushed below the fold by a card that outranks it on
            // screen without outranking it in importance.
            // RECOVERY-LOOP-1: from month 7 on, internal training already
            // has its own unconditional, dedicated card for every engineer
            // runtime (the `s.month >= 6` block further down in build()) —
            // rendering this embedded one too would duplicate the same
            // `public-demo-internal-training-<id>` key on screen at once.
            // Months 4/6 are unaffected: [showTrainingCard] stays true
            // there, exactly as before this parameter existed.
            if (showTrainingCard)
              internalTrainingCard(
                engineerId: e.id,
                engineerName: e.name,
                showEngineerName: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget ac(int i) {
    final a = workflow.applicants[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  a.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                badge(applicantStatus(a)),
              ],
            ),
            const SizedBox(height: 4),
            Text(a.resumeSummary),
            if (accepted(a))
              PublicDemoSalesProgress(
                currentStep: applicantStep(a),
                preEntry: true,
              ),
            const SizedBox(height: 8),
            if (a.stage == PublicDemoApplicantStage.applied)
              FilledButton(
                onPressed: () => _reviewResume(a.id),
                child: const Text('経歴書確認'),
              ),
            if (a.stage == PublicDemoApplicantStage.resumeReviewed)
              FilledButton(
                onPressed: s.salesRemaining > 0 ? () => recruit(i) : null,
                child: const Text('採用面談'),
              ),
            if (a.stage == PublicDemoApplicantStage.interviewed) ...[
              Text('評価 ${a.interviewScore}'),
              Text('希望給与 ${a.requestedMonthlySalary ~/ 10000}万円'),
              FilledButton(
                onPressed: a.interviewScore >= 60 ? () => offer(i) : null,
                child: const Text('合格・給与提示'),
              ),
            ],
            if (a.stage == PublicDemoApplicantStage.offerAccepted &&
                a.canEnterPreJoinSales)
              FilledButton(
                onPressed: () => _beginPreEntrySkillSheet(a.id),
                child: const Text('入社前SkillSheet'),
              ),
            if (a.stage == PublicDemoApplicantStage.offerAccepted &&
                !a.canEnterPreJoinSales)
              const Text('入社後、研修で育成します'),
            if (a.stage == PublicDemoApplicantStage.preEntrySkillSheet)
              FilledButton(
                onPressed: () => _beginPreEntrySelling(a.id),
                child: const Text('入社前営業'),
              ),
            if (a.stage == PublicDemoApplicantStage.preEntrySelling)
              FilledButton(
                onPressed: () => _introducePreEntryProject(a.id),
                child: const Text('案件紹介'),
              ),
            if (a.stage == PublicDemoApplicantStage.preEntryIntroduced)
              FilledButton(
                onPressed: s.salesRemaining > 0 ? () => pi(i) : null,
                child: const Text('上位会社面談'),
              ),
            if (a.stage == PublicDemoApplicantStage.preEntryPartnerPassed)
              FilledButton(onPressed: () => ci(i), child: const Text('客先面談')),
            if (a.stage == PublicDemoApplicantStage.preEntryClientPassed)
              FilledButton(
                onPressed: () => _recordApplicantJuneOrder(a),
                child: const Text('6月受注'),
              ),
          ],
        ),
      ),
    );
  }

  // The app-wide FilledButton theme (lib/ui/theme.dart) sets only
  // `vertical: 14` padding, which zeroes out the horizontal padding
  // (EdgeInsets.symmetric defaults an omitted side to 0) instead of leaving
  // Material 3's own default (24) in place. Every stage-action button in
  // Public Demo (SkillSheet確認, 営業開始, 上位会社面談, 客先面談（0枠）, ...)
  // is a FilledButton/FilledButton.tonal that shrink-wraps its content, so
  // that theme bug reads as cramped, edge-to-edge label text rather than an
  // actual clip — worst on the longer Japanese labels. Fixed locally here
  // (rather than in the shared theme) to keep this change scoped to Public
  // Demo, as requested, instead of restyling every button in the app.
  // Vertical padding (and with it the >=48dp tap target) is left untouched.
  ButtonStyle? _publicDemoFilledButtonStyle(BuildContext c) =>
      Theme.of(c).filledButtonTheme.style?.copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      );

  /// HOME-COMPACT-1B.4 FIX1: whether this is the one state the fix targets
  /// — an actual, already-realized cash shortage, not the preventive
  /// caution window ([_cashForecastAdvice] covers that, and is unaffected
  /// by this flag: it already returns `null` once [PublicDemoState
  /// .financialStatus] leaves `normal`, i.e. exactly when this is `true`).
  /// Read straight from the same authoritative field
  /// [PublicDemoCashShortageCard] itself gates on — never a second,
  /// independently-derived notion of "shortage".
  bool get _isActualCashShortage =>
      s.financialStatus == PublicDemoFinancialStatus.cashShortage;

  /// The Navigator card's advice, compacted for [_isActualCashShortage]
  /// only. [PublicDemoCashShortageCard] — rendered immediately above the
  /// Navigator whenever this is true — already states the full reason
  /// (the same evidence figures, the recovery rule, what stays usable and
  /// what is restricted); the "ひよりからのアドバイス" bubble's generic
  /// "確認してから進めましょう" explanation would only restate that a second
  /// time while costing real height the acceptance criteria need back for
  /// 社員概要. Every other field (title/headline/message/semantic/CTA/
  /// secondary — the actual guidance and its dispatch) is passed through
  /// unchanged; only [HomeNavigatorAdvice.explanation] is dropped, and only
  /// for this one state.
  HomeNavigatorAdvice? _compactedForShortage(HomeNavigatorAdvice? advice) {
    if (!_isActualCashShortage || advice == null) return advice;
    return HomeNavigatorAdvice(
      title: advice.title,
      headline: advice.headline,
      message: advice.message,
      semantic: advice.semantic,
      ctaLabel: advice.ctaLabel,
      onCtaPressed: advice.onCtaPressed,
      secondaryLabel: advice.secondaryLabel,
      onSecondaryPressed: advice.onSecondaryPressed,
    );
  }

  @override
  Widget build(BuildContext c) {
    final navigatorAdvice = _compactedForShortage(
      navigatorAdviceFor(_recommendedActionSlot),
    );
    return Theme(
      data: Theme.of(c).copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: _publicDemoFilledButtonStyle(c),
        ),
      ),
      child: Scaffold(
        // Section 1: menu affordance + centered title + notification
        // affordance. PUBLIC-DEMO-HOME-UI-3A relocates the build/deploy
        // identity (BuildInfoLabel) out of the header — it now lives inside
        // the collapsed "開発・テストメニュー" card
        // (_publicDemoTestControlsCard), the compact developer/test surface
        // the issue asks for, so it no longer visually competes with the
        // gameplay header.
        appBar: AppBar(
          leading: IconButton(
            key: const Key('public-demo-app-bar-menu'),
            icon: const Icon(Icons.menu),
            tooltip: '開発・テストメニュー',
            onPressed: _openDevMenuSection,
          ),
          title: const Text('S.E.S. Public Demo 0.1'),
          actions: [
            IconButton(
              key: const Key('public-demo-app-bar-notifications'),
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'お知らせ',
              onPressed: () => unawaited(_showNotifications()),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          key: const Key('public-demo-bottom-nav'),
          // Section 8: preserves existing navigation authority — Public
          // Demo has exactly one screen, so every destination below is a
          // real scroll-jump (see _handleBottomNavSelection), never a route
          // change. There is genuinely no second "current tab" to track
          // without inventing one, so this stays fixed at ホーム (0) rather
          // than simulating a selection that does not exist — documented as
          // a truthful reduction in the Issue #147 result report.
          selectedIndex: 0,
          onDestinationSelected: _handleBottomNavSelection,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'ホーム',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: '社員',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: '営業',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance),
              label: '会計',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_outlined),
              selectedIcon: Icon(Icons.menu),
              label: 'メニュー',
            ),
          ],
        ),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isRestoring || _isRestarting,
              child: SafeArea(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  // The monthly cash-flow card (FINANCE-UX-1) made this screen's
                  // total content large enough to trip a Flutter SliverList layout
                  // quirk in this SDK: past a certain child height, ListView's
                  // sliver-based children stop being mounted at all beyond that
                  // point (not just scrolled off-screen — genuinely absent from the
                  // widget tree), independent of cacheExtent (confirmed up to
                  // 20000px, no effect). Wrapping everything in one Column keeps
                  // this a ListView (existing tests still find/scroll it by type)
                  // but gives the sliver exactly one child to lay out, which
                  // Flutter always builds in full regardless of height.
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HOME-RUNTIME-2A: the FINANCE-FAILURE-1C shortage
                        // explanation is hoisted above everything else. Its
                        // authority is unchanged and still lives entirely in the
                        // card itself — it renders only when
                        // `state.financialStatus == cashShortage` and never infers
                        // that from the sign of cash. This screen decides where the
                        // card goes, not whether it applies, which is why
                        // `financialStatus` is still not projected into HOME.
                        PublicDemoCashShortageCard(
                          state: s,
                          nextClose: _nextCloseForecastEntry,
                        ),
                        // PLAYTEST-BLOCKER-1A: when a terminal financial state is
                        // reached (bankruptcy or March cash-shortage failure),
                        // show a prominent card that communicates the game-over
                        // reason, the final cash, and a safe restart action.
                        // This card is the player's primary signal that the
                        // playthrough has ended — without it the only cue was a
                        // month-close button that silently became a no-op.
                        if (s.isFinanciallyTerminal) _bankruptcyTerminalCard(),
                        // HOME-RUNTIME-READ-1: the new HOME read-only display,
                        // added alongside (never in place of) the existing Public
                        // Demo UI below. It receives only the projection — no
                        // aggregate, no state, no commands, no callbacks.
                        //
                        // HOME-RUNTIME-2A: its MonthHeaderBar is now the only month
                        // display on the screen — the `N月` headline that used to
                        // restate it here is deleted.
                        // Sections 1-4 (header band/KPI grid/Navigator card):
                        // the header band and KPI grid are composed inside
                        // this section (MonthHeaderBar + KpiSection.compact);
                        // the Navigator card is HomeNavigatorSection. Its
                        // secondary route ("他の行動を確認する") is the same
                        // truthful scroll-jump every other "destination" on
                        // this screen uses — never a second mutation path.
                        //
                        // HOME-COMPACT-1B.4 FIX1: the secondary route is
                        // dropped (`null`) during an actual cash shortage
                        // only — see `_isActualCashShortage`'s own doc.
                        // Every other action on this screen (including the
                        // legacy section it scroll-jumps to) stays reachable
                        // exactly as before; only this one extra 48pt
                        // button, whose destination duplicates what
                        // quick-access/bottom-nav already reach, is not
                        // re-offered while the height it costs is what the
                        // acceptance criteria need back for 社員概要.
                        PublicDemoHomeDashboardSection(
                          data: _homeDashboardData,
                          recommendedAction: _recommendedActionSlot,
                          navigatorAdvice: navigatorAdvice,
                          cashAdvice: _cashForecastAdvice,
                          onShowOtherActions: _isActualCashShortage
                              ? null
                              : _scrollToOtherActions,
                        ),
                        // HOME-COMPACT-1B.3: the monthly progression CTA
                        // moves directly under the Navigator card — the
                        // acceptance requirement is that it is visible in
                        // the initial 390px-wide view with no scroll, next
                        // to 月/KPI/ひより. It is bound exactly once on this
                        // screen (see `_monthlyPrimaryAction`'s own site);
                        // moving where that one binding renders does not
                        // create a second CTA. The summary sections below
                        // (社員の様子/重要タスク/クイックアクセス/収支) stay reachable by
                        // scroll, quick access, and the bottom nav exactly
                        // as before.
                        //
                        // HOME-COMPACT-1B.4: 社員の様子 (社員概要) joins the
                        // required initial-view set too — see this class's
                        // own doc on `_officeStageKey` — which is why the
                        // small gap below is explicit rather than relying on
                        // a trailing spacer inside
                        // PublicDemoHomeDashboardSection: every pixel
                        // between here and the Office Stage now matters for
                        // fitting the 360x800 target with no scroll.
                        if (_monthlyPrimaryAction
                            case final monthlyAction?) ...[
                          const SizedBox(height: 2),
                          PublicDemoMonthlyPrimaryCtaSection(
                            action: monthlyAction,
                          ),
                        ],
                        // HOME-COMPACT-1B.4: trimmed from 8 — 社員概要 must
                        // now also fit inside the unscrolled initial view
                        // alongside 月/KPI/ひより/月次CTA (see this class's
                        // own doc on `_officeStageKey`), so every pixel
                        // between the two cards above it and this one is
                        // spent deliberately.
                        const SizedBox(height: 2),
                        // Section 5: employee summary. This office-scene
                        // card is now the ONLY roster-like presentation on
                        // HOME — the former `PublicDemoEmployeeStageSection`
                        // duplicate list is deleted (Issue #147 requires
                        // employee information not be repeated across
                        // adjacent HOME sections). Wrapped so quick access /
                        // bottom nav / "社員" can scroll-jump to it.
                        KeyedSubtree(
                          key: _officeStageKey,
                          child: HomeOfficeStageSection(
                            display: _officeStageDisplay,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Section 6: "今月の重要タスク" — up to three truthful
                        // tasks built only from existing authoritative facts
                        // (see _importantTasks's own doc).
                        PublicDemoImportantTasksSection(items: _importantTasks),
                        const SizedBox(height: 8),
                        // Section 7: クイックアクセス — real on-page
                        // scroll-jumps only, no dead buttons.
                        PublicDemoQuickAccessSection(items: _quickAccessItems),
                        const SizedBox(height: 8),
                        // Supplementary finance detail, kept from the prior
                        // structure and wrapped so it is reachable from
                        // quick access / bottom nav even in April, before
                        // the first monthly close (unlike
                        // `_monthlyCashFlowKey`'s card, this always renders
                        // — see the field's own doc).
                        KeyedSubtree(
                          key: _financeSummaryKey,
                          child: PublicDemoFinanceSummarySection(
                            summary: _financeSummary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // The real, interactive per-person gameplay action
                        // surface (SkillSheet review, selling, interviews,
                        // orders, recovery, ...) — unchanged content, only
                        // repositioned after the new required top-of-screen
                        // sections, and wrapped as the "案件・営業"/other-
                        // actions scroll-jump target every quick-access,
                        // bottom-nav, and Navigator-secondary-route
                        // affordance on this screen points to.
                        KeyedSubtree(
                          key: _legacyActionsKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              dashboard(),
                              if (s.month == 4) ...[
                                for (
                                  var i = 0;
                                  i < workflow.engineers.length;
                                  i++
                                )
                                  ec(i),
                              ],
                              if (s.month == 5) ...[
                                _RecruitmentMediaCard(
                                  state: s,
                                  onPressed: _openRecruitmentMedia,
                                ),
                                for (
                                  var i = 0;
                                  i < workflow.applicants.length;
                                  i++
                                )
                                  ac(i),
                              ],
                              if (s.month == 6)
                                for (final a in workflow.applicants.where(
                                  (a) =>
                                      s.joinedApplicantIds.contains(a.id) &&
                                      a.hasJoined,
                                ))
                                  employeeConditionCard(a),
                              if (s.month == 6) ...[
                                for (
                                  var i = 0;
                                  i < workflow.engineers.length;
                                  i++
                                )
                                  if (s.joinedApplicantIds.contains(
                                        workflow.engineers[i].id,
                                      ) &&
                                      workflow.engineers[i].stage !=
                                          PublicDemoSalesStage.ordered &&
                                      !workflow.assignments.any(
                                        (assignment) =>
                                            assignment.engineerId ==
                                            workflow.engineers[i].id,
                                      ))
                                    ec(i),
                                for (
                                  var i = 0;
                                  i < workflow.assignments.length;
                                  i++
                                )
                                  assignmentCard(i),
                              ],
                              // RECOVERY-LOOP-1: from July (7) through February
                              // (14) — the same window
                              // `PublicDemoRecoveryEligibility` enforces — every
                              // economically-waiting engineer's card is rendered
                              // here, mirroring month 6's own filter
                              // (`!assignedEngineerIds.contains(...)`) so the
                              // existing sales-flow buttons (`ec(i)`'s own
                              // `waiting` → `ordered` branches, plus the new
                              // Recovery button once `ordered`) are reachable at
                              // all past June — no month past June otherwise
                              // renders an engineer card for anyone still
                              // waiting. `showTrainingCard: false` because the
                              // `s.month >= 6` block below already renders every
                              // engineer runtime's training card unconditionally
                              // — rendering it a second time here would duplicate
                              // that same card's key.
                              if (s.month >= 7 && s.month <= 14)
                                for (
                                  var i = 0;
                                  i < workflow.engineers.length;
                                  i++
                                )
                                  if (!workflow
                                      .assignedEngineerIds(month: s.month)
                                      .contains(workflow.engineers[i].id))
                                    ec(i, showTrainingCard: false),
                              if (s.month == 7) ...[
                                Text(
                                  '7月開始結果',
                                  style: Theme.of(c).textTheme.titleLarge,
                                ),
                                // SES-FIRST-FUN-YEAR-UI-PHASE-1: the 参画/待機
                                // headcount line that used to render here is
                                // removed — it duplicated the always-visible
                                // compact KPI's 参画/待機 tiles verbatim.
                                for (final a in workflow.assignments)
                                  ListTile(
                                    title: Text(a.engineerName),
                                    subtitle: Text(julyResult(a)),
                                  ),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '夏季賞与',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _summerBonusDecisionRequired
                                              ? '7月終了前に支給内容を選びましょう。'
                                              : '選択済み：${switch (s.summerBonusSelection) {
                                                  PublicDemoSummerBonusPlan.none => 'なし',
                                                  PublicDemoSummerBonusPlan.half => '0.5か月',
                                                  PublicDemoSummerBonusPlan.one => '1か月',
                                                }}',
                                        ),
                                        const SizedBox(height: 8),
                                        FilledButton(
                                          key: const Key(
                                            'public-demo-summer-bonus-decision',
                                          ),
                                          onPressed: decideSummerBonus,
                                          child: Text(
                                            _summerBonusDecisionRequired
                                                ? '夏季賞与を決める'
                                                : '夏季賞与を変更',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (s.month >= 8 && s.month <= 14) ...[
                                Text(
                                  '${publicDemoMonthLabel(s.month)}開始結果',
                                  style: Theme.of(c).textTheme.titleLarge,
                                ),
                                if (s.month == 8) ...[
                                  const Text('7月分の給与を反映しました'),
                                  Text(
                                    s.summerBonusPaidAmount == 0
                                        ? '夏季賞与 なし'
                                        : '夏季賞与 ¥${s.summerBonusPaidAmount}',
                                  ),
                                ],
                              ],
                              if (s.month == 15 && !s.fiscalYearCompleted) ...[
                                Text(
                                  '${publicDemoMonthLabel(s.month)}開始結果',
                                  style: Theme.of(c).textTheme.titleLarge,
                                ),
                              ],
                              if (s.fiscalYearCompleted) ...[
                                Card(
                                  key: const Key(
                                    'public-demo-fiscal-year-complete',
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '第1期終了',
                                          style: Theme.of(
                                            c,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text('1年間の経営が終了しました。'),
                                        const SizedBox(height: 8),
                                        Text('最終現預金 ¥${s.cash}'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (s.month >= 7)
                                for (final a in workflow.applicants.where(
                                  (a) =>
                                      s.joinedApplicantIds.contains(a.id) &&
                                      a.hasJoined,
                                ))
                                  employeeConditionCard(a),
                              if (s.month >= 6)
                                for (final runtime in s.engineerRuntimes)
                                  internalTrainingCard(
                                    engineerId: runtime.engineerId,
                                    engineerName: _engineerName(
                                      runtime.engineerId,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        KeyedSubtree(
                          key: _devMenuKey,
                          child: _publicDemoDevMenuSection(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_isRestoring)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xDFFFFFFF),
                  child: Center(
                    child: Column(
                      key: Key('public-demo-restoring'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('セーブデータを確認中…'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecruitmentMediaCard extends StatelessWidget {
  const _RecruitmentMediaCard({required this.state, required this.onPressed});

  final PublicDemoState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final used = !state.canUseRecruitmentMediaInMonth(state.month);
    return Card(
      key: const Key('public-demo-recruitment-media-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '候補者を追加募集',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('現預金 ¥${state.cash}'),
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: const Key('public-demo-open-recruitment-media'),
              onPressed: used ? null : onPressed,
              child: Text(used ? '今月は利用済み' : '求人媒体を選ぶ'),
            ),
            if (used)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('求人媒体は月に1回までです。', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecruitmentMediaSheet extends StatelessWidget {
  const _RecruitmentMediaSheet({required this.state});

  final PublicDemoState state;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('求人媒体を選ぶ', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('現在の現預金 ¥${state.cash}'),
            const SizedBox(height: 12),
            for (final medium in PublicDemoRecruitmentMedium.values)
              _RecruitmentMediumOption(state: state, medium: medium),
          ],
        ),
      ),
    ),
  );
}

class _RecruitmentMediumOption extends StatelessWidget {
  const _RecruitmentMediumOption({required this.state, required this.medium});

  final PublicDemoState state;
  final PublicDemoRecruitmentMedium medium;

  @override
  Widget build(BuildContext context) {
    final affordable = state.cash >= medium.cost;
    final label = medium == PublicDemoRecruitmentMedium.free
        ? '無料求人'
        : 'エンジニア求人';
    final description = medium == PublicDemoRecruitmentMedium.free
        ? '費用をかけずに募集'
        : '費用をかけて候補を増やす';
    final unavailable = !affordable ? '現預金が不足しています。' : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('費用: ¥${medium.cost} / 応募: ${medium.applicantCount}名'),
            Text(description),
            if (medium.cost > 0) Text('利用後の現預金: ¥${state.cash - medium.cost}'),
            if (unavailable != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(unavailable, style: const TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: Key('public-demo-recruitment-medium-${medium.name}'),
              onPressed: affordable
                  ? () => Navigator.pop(context, medium)
                  : null,
              child: const Text('この方法で募集する'),
            ),
          ],
        ),
      ),
    );
  }
}
