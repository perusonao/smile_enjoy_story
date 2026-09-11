import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import '../../game/public_demo/public_demo_aggregate.dart';
import '../../game/public_demo/public_demo_assignment.dart';
import '../../game/public_demo/public_demo_cash_advice_selector.dart';
import '../../game/public_demo/public_demo_cash_forecast.dart';
import '../../game/public_demo/public_demo_cash_status_presentation.dart';
import '../../game/public_demo/public_demo_engineer_runtime.dart';
import '../../game/public_demo/public_demo_fiscal_close_id.dart';
import '../../game/public_demo/public_demo_founder_follow_up.dart';
import '../../game/public_demo/public_demo_interview.dart';
import '../../game/public_demo/public_demo_internal_training_transaction.dart';
import '../../game/public_demo/public_demo_matching_fit.dart';
import '../../game/public_demo/public_demo_month_guard.dart';
import '../../game/public_demo/public_demo_month_label.dart';
import '../../game/public_demo/public_demo_monthly_growth.dart';
import '../../game/public_demo/public_demo_monthly_report_snapshot.dart';
import '../../game/public_demo/public_demo_project_generator.dart';
import '../../game/public_demo/public_demo_recovery.dart';
import '../../game/public_demo/public_demo_recruitment.dart';
import '../../game/public_demo/public_demo_recruitment_medium.dart';
import '../../game/models/recruitment_interview.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../../game/public_demo/public_demo_salary_finance.dart';
import '../../game/public_demo/public_demo_salary.dart';
import '../../game/public_demo/public_demo_state.dart';
import '../../game/public_demo/public_demo_employee_condition.dart';
import '../../game/public_demo/public_demo_financial_status.dart';
import '../../game/public_demo/public_demo_raise.dart';
import '../../game/public_demo/public_demo_summer_bonus_plan.dart';
import '../../game/public_demo/public_demo_workflow_state.dart';
import '../../game/persistence/public_demo_opening_marker.dart';
import '../../game/persistence/public_demo_save_service.dart';
import '../../presentation/home/models/home_dashboard_display_data.dart';
import '../../presentation/home/models/home_office_stage_display.dart';
import '../../presentation/home/models/home_navigator_display.dart';
import '../../presentation/home/models/home_recommended_action.dart';
import '../../presentation/build_info.dart';
import '../../presentation/home/widgets/home_office_stage_section.dart';
import '../asset_paths.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import 'public_demo_event_dialog.dart';
import 'public_demo_opening_context_screen.dart';
import 'public_demo_accounting_visual.dart';
import 'public_demo_candidate_skill_sheet_sheet.dart';
import 'public_demo_cash_shortage_card.dart';
import 'public_demo_employee_status_resolver.dart';
import 'public_demo_employee_visual.dart';
import 'public_demo_founder_follow_up_dialog.dart';
import 'public_demo_growth_result_card.dart';
import 'public_demo_home_dashboard_section.dart';
import 'public_demo_home_presentation_components.dart';
import 'public_demo_interview_result_dialog.dart';
import 'public_demo_matching_screen.dart';
import 'public_demo_menu_visual.dart';
import 'public_demo_month_guard_warning_dialog.dart';
import 'public_demo_monthly_cash_flow_card.dart';
import 'public_demo_monthly_report_dialog.dart';
import 'public_demo_monthly_report_display_data.dart';
import 'public_demo_project_context.dart';
import 'public_demo_project_context_resolver.dart';
import 'public_demo_project_interview_dialog.dart';
import 'public_demo_recruitment_interview_dialog.dart';
import 'public_demo_sales_progress.dart';
import 'public_demo_sales_visual.dart';
import 'public_demo_skill_sheet_sheet.dart';
import 'public_demo_salary_offer_dialog.dart';
import 'public_demo_raise_dialog.dart';
import 'public_demo_summer_bonus_dialog.dart';
import 'public_demo_year_end_display_data.dart';
import 'public_demo_year_end_result_card.dart';

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

/// SES EMPLOYEE-UI-VISUAL-COMPLETE: the 社員一覧 filter's three real buckets
/// — Canonical Visual Reference `01_Employee_LayoutDraft.png`'s 全員/待機中/
/// 参画中 chips (its 4th chip, 休職, has no authoritative Public Demo status
/// and is deliberately not reproduced — Visual SSOT "実在statusのみ"). Maps
/// 1:1 onto the same `_currentlyAssignedEngineerIds` membership the roster's
/// existing 待機/参画中 summary counts already partition every engineer
/// into; no new categorization is computed.
enum _EmployeeStatusFilter { all, waiting, assigned }

// ---------------------------------------------------------------------------
// PUBLIC-DEMO-HOME-UI-3A P2 fix (PR #150 review): "今月の重要タスク"'s 営業/採用
// rows used to be unconditional — always rendered, always pointing at the
// same scroll-jump (now `_switchToEligibleSalesDestination`/`_switchTab`;
// see PR #172's own fix for why the 営業 row's destination itself later
// became kind-aware), regardless of whether anything reachable there was
// actually still legal. In a terminal/completed month (`isCloseBlocked`
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

/// The 社員-tab subset of the sales-pipeline kinds below — every kind
/// [_S._addEngineerStageCandidate] emits, which mirrors `ec(i)` branch for
/// branch (including the `案件へ復帰` Recovery button). PUBLIC-DEMO-HOME-UI-3B
/// moved that whole card to 社員, so this is also the exact set
/// [_S._switchToEligibleSalesDestination] checks first — see its own doc
/// (PR #172 Codex review) for why a kind-aware destination replaced the
/// former unconditional "always 営業" routing.
const Set<HomeRecommendedActionKind> _employeeTabSalesActionKinds = {
  HomeRecommendedActionKind.recoveryAssignment,
  HomeRecommendedActionKind.employeeAcceptOrder,
  HomeRecommendedActionKind.employeeClientInterview,
  HomeRecommendedActionKind.employeePartnerInterview,
  HomeRecommendedActionKind.employeeIntroduceProject,
  HomeRecommendedActionKind.employeeResumeSelling,
  HomeRecommendedActionKind.employeeBeginSelling,
  HomeRecommendedActionKind.employeeSkillSheetReview,
};

/// The 営業-tab subset of the sales-pipeline kinds below — every kind
/// [_S._addAssignmentCandidate] emits, which mirrors `assignmentCard(i)`
/// branch for branch. That card is entirely on 営業.
const Set<HomeRecommendedActionKind> _projectTabSalesActionKinds = {
  HomeRecommendedActionKind.assignmentAcceptNextOrder,
  HomeRecommendedActionKind.assignmentAcceptReplacementOrder,
  HomeRecommendedActionKind.assignmentReplacementClientInterview,
  HomeRecommendedActionKind.assignmentReplacementPartnerInterview,
  HomeRecommendedActionKind.assignmentIntroduceReplacementProject,
  HomeRecommendedActionKind.assignmentResumeReplacementSelling,
  HomeRecommendedActionKind.assignmentBeginReplacementSelling,
  HomeRecommendedActionKind.assignmentConfirmNextOrder,
};

/// The sales-pipeline (existing-employee/assignment) [HomeRecommendedActionKind]s
/// — every kind [_S._recommendedActionCandidates] emits from an engineer or
/// assignment card ([_employeeTabSalesActionKinds] ∪
/// [_projectTabSalesActionKinds]). Used only to decide whether the "営業活動を
/// 進める" task has anywhere left to send the player; see the section doc
/// above. Kept as one union so this eligibility gate is unaffected by which
/// tab a given kind's card actually renders on — only the CTA's own
/// destination ([_S._switchToEligibleSalesDestination]) needs that split.
const Set<HomeRecommendedActionKind> _salesTaskActionKinds = {
  ..._employeeTabSalesActionKinds,
  ..._projectTabSalesActionKinds,
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
  HomeRecommendedActionKind.applicantContinueInterview,
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
    this.openingMarker = const PublicDemoOpeningMarker(),
    this.debugSeed,
  });

  final BuildInfo? buildInfo;
  final PublicDemoSaveService saveService;

  /// FIRST-FUN-YEAR P1 (Issue #229): tracks whether this browser has already
  /// dismissed the Opening Context screen. Defaults to the inert
  /// [PublicDemoOpeningMarker] — see that class's own doc for why every
  /// existing widget test that constructs this screen directly keeps
  /// landing on HOME unchanged; `main.dart` (the real entry point) passes
  /// [PublicDemoOpeningMarker.persistent] explicitly.
  final PublicDemoOpeningMarker openingMarker;

  /// QA/E2E/test-only [PublicDemoState.runSeed] override for a brand-new
  /// playthrough (SEEDED-RNG-REUSE-1), mirroring [GameController
  /// .debugSeed]'s own doc. `null` for every real player, in which case a
  /// fresh new-game/restart still draws its own random seed exactly as
  /// before this field existed. Never read by any gameplay/balance logic —
  /// only threaded into [PublicDemoAggregate.initial]'s `runSeed`
  /// parameter so a reproducible run can be requested on demand.
  final int? debugSeed;
  @override
  State<PublicDemo01PlaceholderScreen> createState() => _S();
}

class _S extends State<PublicDemo01PlaceholderScreen> {
  static final expense = PublicDemoSalary.baselineMonthlyExpenses;
  final _scrollController = ScrollController();
  final _monthlyCashFlowKey = GlobalKey();

  // PUBLIC-DEMO-HOME-UI-3B: real bottom-navigation tab surfaces. HOME
  // stopped being the one screen everything lived on — each destination
  // below now switches which tab body [build] constructs, via
  // [_switchTab]/[_selectedTabIndex], rather than scroll-jumping to an
  // anchor inside a single shared ListView (the former PUBLIC-DEMO-HOME-UI-3A
  // approach, whose rationale is preserved only in git history). Only the
  // selected tab's widget subtree is ever built, so a tab genuinely does not
  // "contain" another tab's content — it is simply not constructed, not
  // merely off-screen.
  static const int _homeTabIndex = 0;
  static const int _employeesTabIndex = 1;
  static const int _salesTabIndex = 2;
  static const int _accountingTabIndex = 3;
  static const int _menuTabIndex = 4;
  int _selectedTabIndex = _homeTabIndex;

  /// SES EMPLOYEE-UI-VISUAL-COMPLETE: which real status bucket the 社員一覧
  /// (`_employeeRosterSection`) shows. Presentation-only — it only ever
  /// hides/shows existing roster rows built from the same authoritative
  /// `_currentlyAssignedEngineerIds` fact the roster's own summary line
  /// already reads; it introduces no new employee status, and does not
  /// affect Section 2/3/4 or any command/eligibility below it. Defaults to
  /// showing everyone, matching this section's pre-filter behavior.
  _EmployeeStatusFilter _employeeStatusFilter = _EmployeeStatusFilter.all;

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
  late PublicDemoAggregate _game;
  Future<void> _persistenceTail = Future<void>.value();
  bool _isRestoring = true;
  bool _isRestarting = false;

  /// FIRST-FUN-YEAR P1 (Issue #229): true while the Opening Context screen
  /// should replace HOME — a brand-new playthrough (no restored save) whose
  /// [widget.openingMarker] has not yet recorded a dismissal. Never true
  /// while [_isRestoring] (see [_restoreAggregate], the only place both are
  /// ever set together) and always resolved through the exact same
  /// [_resolveShowOpening] both the boot path and restart use, so neither
  /// path can disagree about what "not yet seen" means.
  bool _showOpening = false;

  /// Codex P2-2 fix (PR #214): true from the moment [_openProjectInterview]
  /// is entered until its dialog route (however it ends — a genuine
  /// pass/fail commit, the player dismissing it, or this widget being
  /// disposed while it awaits) is fully gone. A second activation of the
  /// `客先面談` action while this is true is a no-op — see
  /// [_openProjectInterview]'s own doc for why the guard must be set before
  /// its first `await`, not after, and why relying only on the button's own
  /// `setState`-driven disable is not enough.
  bool _projectInterviewLaunchInProgress = false;

  /// SES-FIRST-FUN-YEAR-UI-PHASE-2: whether the bottom "開発・テストメニュー"
  /// fold is open. Starts closed so the test-only restart control never
  /// reads as part of the normal monthly game flow — see
  /// [_publicDemoTestControlsCard]'s doc for why it moved here at all.
  bool _isDevMenuExpanded = false;

  @override
  void initState() {
    super.initState();
    // Applies widget.debugSeed (QA/E2E/test-only) before _restoreAggregate
    // can possibly replace this with a save's own persisted runSeed —
    // matching every other new-game/restart call site's `_game =
    // PublicDemoAggregate.initial(runSeed: widget.debugSeed)` below.
    _game = PublicDemoAggregate.initial(runSeed: widget.debugSeed);
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
      // SES-FIRST-FUN-YEAR-RELOAD-1 (P0): kept in step with
      // PublicDemoSaveService.load()'s own now-1000ms boot-time budget —
      // this outer wrapper must not be tighter than the inner one it wraps,
      // or it truncates the same call before it can finish. See that
      // method's doc for why the tighter 100ms budget was unsafe.
      restored = await widget.saveService.load().timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () => null,
      );
    } catch (_) {
      restored = null;
    }
    final showOpening = await _resolveShowOpening(hasRestoredSave: restored != null);
    if (!mounted) return;
    setState(() {
      _game =
          restored ?? PublicDemoAggregate.initial(runSeed: widget.debugSeed);
      _isRestoring = false;
      _showOpening = showOpening;
    });
  }

  /// Dismisses the Opening Context and records the dismissal
  /// (best-effort — see [PublicDemoOpeningMarker.markSeen]) so a later
  /// reload of this same fresh session does not show it again.
  void _acknowledgeOpeningContext() {
    if (!mounted) return;
    setState(() => _showOpening = false);
    unawaited(widget.openingMarker.markSeen());
  }

  /// The single place [_showOpening] is ever computed — both
  /// [_restoreAggregate] (boot) and [_restartGame] resolve it through this
  /// exact method, so neither path can disagree about what "not yet seen"
  /// means. A restored save ([hasRestoredSave]) always means this browser
  /// has real prior progress — the Opening Context never shows for it, even
  /// if [widget.openingMarker] itself has no record (e.g. a save from before
  /// this screen existed). Only a genuinely fresh state (no restored save)
  /// ever consults the marker.
  Future<bool> _resolveShowOpening({required bool hasRestoredSave}) async {
    if (hasRestoredSave) return false;
    return !(await widget.openingMarker.hasSeenOpening());
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

  /// SES ISSUE-232 Phase B: shows the read-only Monthly Management Report
  /// immediately after [closedMonth]'s own close has already committed via
  /// [_commitAggregate] — the sole call site for
  /// [PublicDemoMonthlyReportDialog], wired identically from all five
  /// monthly-close handlers ([april], [may], [june], [july],
  /// [closeOrdinaryMonth]).
  ///
  /// Reads [PublicDemoMonthlyReportSnapshot.fromAggregate] against the
  /// **already-committed** [_game] — this method itself never calls
  /// `closeX(...)` or any other aggregate/state/workflow command, and the
  /// snapshot factory it calls is documented as never doing so either
  /// (Phase A). The report is shown only when
  /// [PublicDemoMonthlyReportSnapshot.isReady]: a blocked/no-op close
  /// (Month Guard cancel, an outstanding required decision) never reaches
  /// this method at all — every caller only calls this after its own
  /// commit, and every close handler already returns early, before ever
  /// reaching its commit, when the close itself did not happen. A stale
  /// snapshot (`flow.month != closedMonth`) is a defense-in-depth case that
  /// should not occur from these five call sites either, but is still
  /// silently skipped rather than ever shown under the wrong month's label
  /// (Fresh Audit §4/§12, carried from Phase A).
  ///
  /// Never calls `closeX(...)` again — [closedMonth] is used only to ask
  /// the snapshot "is this the month you just recorded", never to redrive
  /// a close.
  Future<void> _maybeShowMonthlyReport(int closedMonth) async {
    final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
      _game,
      closedMonth: closedMonth,
    );
    if (!snapshot.isReady) return;
    if (!mounted) return;
    final data = PublicDemoMonthlyReportDisplayData.fromSnapshot(
      snapshot,
      applicants: workflow.applicants,
      // Codex Broad Review P2 (PR #237): read straight off the same
      // already-committed aggregate's state — never recomputed, never a
      // new judgment — so the report's own CTA copy and Hiyori comment
      // can tell a terminal/year-end close apart from an ordinary one.
      isFiscalYearCompleted: s.fiscalYearCompleted,
      isFinanciallyTerminal: s.isFinanciallyTerminal,
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PublicDemoMonthlyReportDialog(data: data),
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
  /// (`.totalEmployeeCount`/`.waitingEmployeeCount`) — passed straight
  /// through, never recomputed here — so the Office Stage's own aggregate
  /// summary line cannot disagree with the KPI row above it.
  ///
  /// Issue #122: [employeeCount] reads [HomeDashboardDisplayData
  /// .totalEmployeeCount] (engineers + the one 総務/general-affairs
  /// employee), not `state.engineerCount` alone — this chip is labeled 社員
  /// (the whole company), the same label the KPI's totalEmployeeCount tile
  /// uses, so it must state the same real total rather than an
  /// engineer-only count under that label. [waitingCount] is unaffected:
  /// the 総務 employee is not part of the assigned/waiting engineer
  /// concept, so `engineersWaiting` still names exactly who it always did.
  ///
  /// SES HOME Final Visual Match (structural pass): each member's [status]
  /// is [_officeStageStatusFor], which reads `engineer.stage` — the same
  /// single authority the 社員 tab's own `engineerStatus(engineer)` badge
  /// reads — except for the one case (POST-HOME-FREEZE Small-UX-Fix) where
  /// an `ordered` engineer already appears in [_currentlyAssignedEngineerIds]
  /// and would otherwise show a stale '翌月参画予定' for a project they have
  /// already joined. See [_officeStageStatusFor]'s own doc, and
  /// [HomeOfficeStageMember.status]'s own doc for why this is a different,
  /// safe fact from the 参画/待機 aggregate this getter's own doc above
  /// already explains the Office Stage must never restate.
  HomeOfficeStageDisplay get _officeStageDisplay => HomeOfficeStageDisplay(
    members: [
      for (final engineer in workflow.engineers)
        HomeOfficeStageMember(
          id: engineer.id,
          name: engineer.name,
          portraitAssetPath: homeOfficeStagePortraitFor(engineer.id),
          status: _officeStageStatusFor(engineer),
        ),
    ],
    employeeCount: _homeDashboardData.totalEmployeeCount,
    waitingCount: s.engineersWaiting,
  );

  /// SES POST-HOME-FREEZE Small-UX-Fix: an `ordered` engineer already
  /// counted into [_currentlyAssignedEngineerIds] — the existing SSOT for
  /// "currently on a project", the same one the cash-forecast advice filter
  /// above and the training card already read — has actually joined their
  /// project. [engineerStatus]'s '翌月参画予定' is stale for that one case,
  /// so the Office Stage reports the truthful '参画中' instead.
  ///
  /// Deliberately local to the Office Stage, not a change to [engineerStatus]
  /// itself: the 社員 tab's own badge (`ec`'s `badge(engineerStatus(e))`) and
  /// the SkillSheet sheet keep showing the raw pipeline stage untouched, and
  /// no new domain authority is introduced — this only re-reads the same
  /// [workflow.assignedEngineerIds] fact [_currentlyAssignedEngineerIds]
  /// already exposes.
  String _officeStageStatusFor(PublicDemoEngineerSales engineer) {
    if (engineer.stage == PublicDemoSalesStage.ordered &&
        _currentlyAssignedEngineerIds.contains(engineer.id)) {
      return '参画中';
    }
    return engineerStatus(engineer);
  }

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
      // tab switch, never a fabricated command.
      return HomeNavigatorAdvice(
        title: 'ひよりからのご案内',
        message: message,
        explanation: evidence == null
            ? '資金計画を確認し、支出や営業状況を見直しましょう。'
            : '$evidence。資金計画を確認し、支出や営業状況を見直しましょう。',
        semantic: HomeNavigatorAdviceSemantic.caution,
        ctaLabel: '資金計画を確認する',
        onCtaPressed: () => _switchTab(_accountingTabIndex),
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
        'スキルシートを確認',
        '$nameのスキルシートを確認',
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
  /// action that becomes illegal, only a tab switch to a surface that
  /// always renders (会計).
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
          // PR #172 Codex review: this row's own eligible kind can be an
          // existing employee's own card (社員) or an assignment's (営業) —
          // see [_switchToEligibleSalesDestination]'s own doc.
          onPressed: _switchToEligibleSalesDestination,
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
          // _recruitmentTaskActionKinds is entirely the applicant funnel
          // (`ac(i)`) plus the recruitment-media button — both always on
          // 営業 — so this destination is never ambiguous, unlike the 営業
          // row above.
          onPressed: () => _switchTab(_salesTabIndex),
        ),
      PublicDemoImportantTaskItem(
        title: '資金計画を確認する',
        fact: '今月の固定費: ${formatYen(_financeSummary.fixedCosts)}',
        category: '資金',
        ctaLabel: '確認する',
        onPressed: () => _switchTab(_accountingTabIndex),
      ),
    ];
  }

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
      // SES ACCOUNTING-UI-PHASE-1 (Fresh Audit label-truthfulness fix): see
      // PublicDemoFinanceSummaryModel.isSettled's own doc — this is the same
      // null-check this getter already made to choose the baseline
      // fallback, not a new fact.
      isSettled: latest != null,
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
        onPressed: () => unawaited(june()),
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

  /// PUBLIC-DEMO-HOME-UI-3B: switches which tab body [build] constructs.
  /// This is the single mechanism behind the bottom-navigation destinations,
  /// every quick-access item, the Navigator card's secondary route, and the
  /// 営業/採用/資金計画 important-task rows — none of them scroll an anchor
  /// inside a shared list any more; each genuinely changes which tab surface
  /// is current. A no-op when [index] is already selected, so re-tapping the
  /// current tab never triggers an extra rebuild.
  void _switchTab(int index) {
    if (_selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
  }

  /// PUBLIC-DEMO-HOME-UI-3B FIX (PR #172 Codex review): the 営業 important-
  /// task row, quick access's 案件・営業 icon, and the Navigator card's
  /// secondary "他の行動を確認する" route used to switch to 営業
  /// unconditionally. That is wrong whenever the only eligible
  /// sales-pipeline candidate is an existing employee's own card — e.g. a
  /// fresh April game, where Sato's SkillSheet確認 is the sole eligible
  /// action and lives on 社員 (`ec(i)`, see [_employeeTabSalesActionKinds]'s
  /// own doc) — because 営業 renders no card at all until May/June, so the
  /// player lands on a blank tab despite an action being genuinely
  /// available.
  ///
  /// This reads the same real, already-legal candidates
  /// [_recommendedActionCandidates] already computes (never a new
  /// eligibility rule) and switches to 社員 whenever any of them is an
  /// employee-pipeline action, falling back to 営業 otherwise (assignment/
  /// project continuation, the applicant funnel, recruitment media).
  /// Preferring 社員 when both a 社員-side and a 営業-side action are
  /// simultaneously eligible is a deliberate, simple tie-break — it matches
  /// the review's own suggested fix ("route employee-pipeline actions to
  /// 社員") and never sends the player to an empty tab in either case.
  void _switchToEligibleSalesDestination() {
    final hasEmployeeTabAction = _recommendedActionCandidates.any(
      (candidate) =>
          _employeeTabSalesActionKinds.contains(candidate.action.kind),
    );
    _switchTab(hasEmployeeTabAction ? _employeesTabIndex : _salesTabIndex);
  }

  void _openDevMenuSection() {
    if (!_isDevMenuExpanded) setState(() => _isDevMenuExpanded = true);
    _switchTab(_menuTabIndex);
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

  /// Bottom nav (section 8) `onDestinationSelected`. PUBLIC-DEMO-HOME-UI-3B:
  /// each index now switches to a real tab surface via [_switchTab] — no
  /// index scrolls a HOME anchor any more. Re-tapping ホーム while it is
  /// already the selected tab scrolls that tab back to its top instead
  /// (the same convenience the old index-0 behavior gave), rather than
  /// being a no-op.
  void _handleBottomNavSelection(int index) {
    if (index == _homeTabIndex && _selectedTabIndex == _homeTabIndex) {
      _scrollToTop();
      return;
    }
    _switchTab(index);
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
      // SES Employee Status Unified Display: the same resolved display the
      // roster badge shows, not raw `engineerStatus` — see
      // [_employeeStatusDisplayFor]'s own doc for why (Fresh Audit §3).
      statusLabel: _employeeStatusDisplayFor(engineer).label,
      runtime: s.runtimeForOrNull(engineer.id),
      currentAssignment: _assignmentForOrNull(engineer.id),
    );
    if (!mounted || confirmed != true) return;
    _startSkillSheetReview(engineer.id);
  }

  /// CORE-GAMEPLAY Phase 4.5: a pure, always-available view of an already-
  /// joined employee's SkillSheet — unlike [_openSkillSheetReview] (bound to
  /// the one-time `waiting`-stage gate that also commits
  /// [_startSkillSheetReview] on confirm), this never commits anything
  /// regardless of the returned value, so it is safe to call for an employee
  /// at *any* [PublicDemoSalesStage] ("社員タブから在籍社員のスキルシートを
  /// 常時確認できること"). Same underlying [PublicDemoSkillSheetSheet]/
  /// [PublicDemoSkillSheetDisplayFactory] as the gated flow — same
  /// authoritative data, same widget — so this is also the one call this
  /// screen's Sales tab or a future Phase 5 (Matching) surface needs to
  /// reuse the identical SkillSheet presentation for an employee, from
  /// anywhere else in this same State class.
  Future<void> _viewEmployeeSkillSheet(PublicDemoEngineerSales engineer) async {
    await PublicDemoSkillSheetSheet.show(
      context,
      engineer: engineer,
      // SES Employee Status Unified Display (Fresh Audit §3): this is the
      // exact call site the audit found showing a stale '翌月参画予定' for an
      // already-`ordered`+currently-assigned engineer while the roster/HOME
      // already said '参画中' — reading the same resolved display the
      // roster badge shows fixes it by construction (see
      // [_employeeStatusDisplayFor]'s own doc).
      statusLabel: _employeeStatusDisplayFor(engineer).label,
      runtime: s.runtimeForOrNull(engineer.id),
      currentAssignment: _assignmentForOrNull(engineer.id),
    );
  }

  /// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): opens the
  /// `案件を見る → 社員を選ぶ → スキルシートを見る → 強み/不足を見る →
  /// 提案する/見送る` flow. Every project/engineer/fit value the pushed
  /// screens read comes from this screen's own already-authoritative
  /// sources ([PublicDemoAggregate.projectCandidatesForMonth]/
  /// [PublicDemoAggregate.availableEngineersForMatching]/
  /// [PublicDemoEngineerProjectFit.compute]/[_viewEmployeeSkillSheet]) —
  /// this method only wires them together, it computes nothing itself.
  void _openProjectMatching() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicDemoProjectMatchingScreen(
          candidates: _game.projectCandidatesForMonth(s.month),
          availableEngineers: _game.availableEngineersForMatching,
          runtimeFor: (engineerId) => s.runtimeForOrNull(engineerId),
          proposalFor: (engineerId) => _game.matchingProposalFor(engineerId),
          fitFor: (runtime, candidate) => PublicDemoEngineerProjectFit.compute(
            runtime: runtime,
            project: candidate.project,
          ),
          onViewSkillSheet: _viewEmployeeSkillSheet,
          onPropose: (engineerId, projectId) => _commitAggregate(
            _game.proposeMatch(engineerId: engineerId, projectId: projectId),
          ),
        ),
      ),
    );
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

  /// Issue #219 (Fresh Audit / Fix: 案件面談の通常プレイ到達性): before this
  /// fix, `案件紹介` was a pure stage flip with no real project behind it —
  /// [PublicDemoAggregate.projectInterviewCandidateFor] (the switch
  /// `_startClientInterview` uses to decide whether `客先面談` opens the
  /// real interactive Phase 6 mini-game, [PublicDemoProjectInterviewDialog],
  /// or falls back to the pre-Phase-6 generic pass/fail dialog) only ever
  /// resolves when a [PublicDemoMatchingProposal] already exists for this
  /// engineer, and the only way to create one was to separately discover
  /// and use the "案件を見る" Matching entry on 営業 — never part of the
  /// game's own guided per-engineer flow (`スキルシート確認 → 営業開始 →
  /// 案件紹介 → 上位会社面談 → 客先面談`) or any HOME recommended action. A
  /// player who only ever follows that guided flow (exactly what
  /// `public_demo_01_success_playthrough_test.dart` exercises) therefore
  /// never sees the mini-game at all, even after genuinely passing both
  /// interviews.
  ///
  /// `案件紹介` now genuinely introduces one of this month's real Phase 4
  /// project candidates — [_bestFitProjectIdFor] picks the one this
  /// engineer's own visible fit prospect (◎○△×, the exact same
  /// [PublicDemoEngineerProjectFit] the Matching screen itself shows the
  /// player) already ranks highest — via the same production
  /// [PublicDemoAggregate.proposeMatch] authority the Matching screen's own
  /// "提案する" button calls; no new formula, no fabricated result. A
  /// player who never opens Matching now still has a real proposal by the
  /// time they reach `partnerInterviewPassed`, so `客先面談` naturally opens
  /// the real mini-game. This never overrides an existing proposal
  /// ([matchingProposalFor] guard below), so a player who *did* use
  /// Matching first keeps their own conscious pick untouched, and a
  /// proposal [PublicDemoWorkflowState.withMatchingProposal] has already
  /// locked (a genuine `clientInterviewPassed`) is never reachable here in
  /// the first place ([introduceProject] itself requires `selling`, long
  /// before that stage). A month with no real candidates at all (should not
  /// happen — [PublicDemoSeededProjectGenerator] always offers a full slate
  /// from April on) leaves this a no-op propose, exactly matching the old
  /// pure-stage-flip behavior.
  void _introduceProject(String engineerId) {
    var next = _game;
    if (next.matchingProposalFor(engineerId) == null) {
      final bestProjectId = _bestFitProjectIdFor(engineerId);
      if (bestProjectId != null) {
        next = next.proposeMatch(
          engineerId: engineerId,
          projectId: bestProjectId,
        );
      }
    }
    _commitAggregate(next.introduceProject(engineerId));
  }

  /// The id of this month's real project candidate ([PublicDemoAggregate
  /// .projectCandidatesForMonth]) whose visible fit prospect for
  /// [engineerId] is highest — the same [PublicDemoEngineerProjectFit
  /// .prospect] tier the Matching screen already renders per candidate, so
  /// this picks nothing the player could not have picked themselves. `null`
  /// only when [engineerId] has no runtime yet or this month genuinely
  /// offers no candidates.
  String? _bestFitProjectIdFor(String engineerId) {
    final runtime = s.runtimeForOrNull(engineerId);
    if (runtime == null) return null;
    final candidates = _game.projectCandidatesForMonth(s.month);
    if (candidates.isEmpty) return null;
    var best = candidates.first;
    var bestProspect = PublicDemoEngineerProjectFit.compute(
      runtime: runtime,
      project: best.project,
    ).prospect;
    for (final candidate in candidates.skip(1)) {
      final prospect = PublicDemoEngineerProjectFit.compute(
        runtime: runtime,
        project: candidate.project,
      ).prospect;
      if (prospect.index < bestProspect.index) {
        best = candidate;
        bestProspect = prospect;
      }
    }
    return best.id;
  }

  void _reviewResume(String applicantId) =>
      _commitAggregate(_game.reviewResume(applicantId));

  void _beginPreEntrySkillSheet(String applicantId) =>
      _commitAggregate(_game.beginPreEntrySkillSheet(applicantId));

  /// CORE-GAMEPLAY Phase 4.5: "スキルシートを確認" must actually show the
  /// candidate's own SkillSheet content, not merely flip an internal stage —
  /// see [PublicDemoCandidateSkillSheetSheet]'s own doc for what it does and
  /// does not include. The stage transition itself ([_reviewResume]) commits
  /// first, unchanged from before this phase; the sheet is a read-only
  /// addition on top, using the pre-commit [a] snapshot (every field the
  /// sheet reads — name/résumé/experience/requested salary — is stage-
  /// independent, so this is not stale).
  Future<void> _reviewResumeAndOpenSkillSheet(PublicDemoApplicant a) async {
    _reviewResume(a.id);
    if (!mounted) return;
    await PublicDemoCandidateSkillSheetSheet.show(context, applicant: a);
  }

  /// Same reasoning as [_reviewResumeAndOpenSkillSheet], for the
  /// "入社前スキルシートを確認" button.
  Future<void> _beginPreEntrySkillSheetAndOpen(PublicDemoApplicant a) async {
    _beginPreEntrySkillSheet(a.id);
    if (!mounted) return;
    await PublicDemoCandidateSkillSheetSheet.show(context, applicant: a);
  }

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
  ///
  /// SES MENU VISUAL COMPLETE: the toggle itself is now
  /// [PublicDemoMenuListRow] — an icon-led, bordered list-row matching the
  /// Canonical Visual Reference's list-item treatment instead of a plain
  /// [TextButton.icon] — but it keeps the exact same key and the exact same
  /// [onTap] callback, so [_isDevMenuExpanded] and every existing regression
  /// test that taps `public-demo-dev-menu-toggle` are unaffected.
  Widget _publicDemoDevMenuSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader('開発・テスト', icon: Icons.build_outlined),
      PublicDemoMenuListRow(
        key: const Key('public-demo-dev-menu-toggle'),
        icon: Icons.science_outlined,
        label: '開発・テストメニュー',
        expanded: _isDevMenuExpanded,
        onTap: () => setState(() => _isDevMenuExpanded = !_isDevMenuExpanded),
      ),
      if (_isDevMenuExpanded) ...[
        const SizedBox(height: 10),
        _publicDemoTestControlsCard(),
      ],
    ],
  );

  /// Public Demo-only test control for repeatable human QA. The destructive
  /// confirmation is intentionally separate from [_restartGame], which also
  /// serves the already-terminal recovery card.
  ///
  /// PUBLIC-DEMO-HOME-UI-3A moved [BuildInfoLabel] here, out of the AppBar
  /// title. QA-MICRO-FIX (post-#173/#174) moved it again, out of this
  /// collapsed card and up to [_buildMenuTab]'s always-visible header —
  /// deployed Screen Verification needs the deploy SHA without expanding
  /// "開発・テストメニュー" first — so only the destructive restart/test
  /// controls remain collapsed here.
  ///
  /// SES MENU VISUAL COMPLETE: re-shelled as [PublicDemoMenuWarningCard] (a
  /// warning-toned card matching the amber "caution" treatment
  /// Accounting Visual Complete already established) instead of a plain
  /// amber [Card] — same key, same text, same restart button/key/handler.
  Widget _publicDemoTestControlsCard() => PublicDemoMenuWarningCard(
    key: const Key('public-demo-test-controls'),
    icon: Icons.warning_amber_outlined,
    title: 'テスト用操作',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Public Demo 0.1の進行だけを初期状態へ戻します。'),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('public-demo-restart-april-button'),
            onPressed: _isRestarting ? null : _confirmRestartFromApril,
            icon: const Icon(Icons.restart_alt),
            label: Text(_isRestarting ? '再開準備中…' : '4月からやり直す'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
              side: const BorderSide(color: Color(0xFFB3261E)),
            ),
          ),
        ),
      ],
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
    // FIRST-FUN-YEAR P1 (Issue #229): a restart is a brand-new playthrough,
    // so it clears any recorded Opening Context dismissal too — for the
    // inert default [PublicDemoOpeningMarker] both calls are no-ops and
    // `hasSeenOpening` still resolves `true`, so `_showOpening` stays false
    // exactly as before this screen existed (every existing restart test
    // keeps passing unmodified); the real persisted marker instead shows the
    // Opening Context again on the next fresh playthrough.
    await widget.openingMarker.clear();
    final showOpening = await _resolveShowOpening(hasRestoredSave: false);
    if (!mounted) return;
    setState(() {
      // A fresh runSeed every time (SEEDED-RNG-REUSE-1): "4月からもう一度"
      // is a brand-new playthrough, never a replay of the abandoned one's
      // seed — matches [PublicDemoState.aprilStart]'s own doc.
      _game = PublicDemoAggregate.initial(runSeed: widget.debugSeed);
      _isRestarting = false;
      // A fresh playthrough starts back on HOME, whether restart was
      // triggered from the bankruptcy terminal card (already on HOME) or
      // from the Menu tab's test-only restart control.
      _selectedTabIndex = _homeTabIndex;
      _showOpening = showOpening;
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

  /// CORE-GAMEPLAY Phase 6 (Project Interview Gameplay): the `客先面談`
  /// entry point. When [engineer] has a real Phase 5
  /// [PublicDemoMatchingProposal] — [PublicDemoAggregate
  /// .projectInterviewCandidateFor] resolves it back to a genuine Phase 4
  /// project — this opens the interactive project interview instead of the
  /// pre-Phase-6 generic [ei] evaluation. An engineer who reached
  /// `partnerInterviewPassed` without ever using Matching (including every
  /// pre-Phase-6 save) has no proposal at all and keeps the exact existing
  /// [ei] behavior unchanged.
  Future<void> _startClientInterview(int i) async {
    final engineer = workflow.engineers[i];
    if (_game.projectInterviewCandidateFor(engineer.id) != null) {
      await _openProjectInterview(engineer.id);
    } else {
      await ei(i, PublicDemoInterviewType.client);
    }
  }

  /// Codex P2-2 fix (PR #214): activating `客先面談` twice in quick
  /// succession — before this method's first `await` yields and any
  /// `setState`-driven button disable could even repaint — used to be able
  /// to push [PublicDemoProjectInterviewDialog] twice. Each pushed dialog
  /// captures its own `aggregate: _game` snapshot at build time and only
  /// ever writes back through [_commitAggregate] when it closes; with two
  /// independent dialogs alive at once, closing the top one commits its
  /// result, but the still-open dialog underneath still holds the *older*
  /// pre-result snapshot — interacting with it (or it simply also
  /// completing) then commits that stale snapshot over the first result,
  /// silently undoing it and replacing it with a second, independently
  /// chosen outcome for the same interview.
  ///
  /// [_projectInterviewLaunchInProgress] closes this by making a second
  /// activation a no-op for as long as any one project-interview route is
  /// in flight, from the moment this method is entered — set **before** the
  /// `await _precacheEventImage(...)` below, since that await is exactly
  /// the window the race above exploited, not after it returns — until the
  /// route is fully gone, via `try`/`finally` so the guard is released
  /// whether the dialog resolves normally (pass or fail), the player
  /// dismisses/backs out of it, or this widget is disposed while the
  /// `await`s here are still pending (a `finally` block still runs after
  /// disposal; it only ever mutates this plain field, never calls
  /// `setState`, so that is safe). This does not depend on, or replace, any
  /// button-level `setState` disable — the field is checked and set
  /// synchronously, before any such disable could even take visual effect.
  Future<void> _openProjectInterview(String engineerId) async {
    if (_projectInterviewLaunchInProgress) return;
    _projectInterviewLaunchInProgress = true;
    try {
      await _precacheEventImage(AssetPaths.eventClientInterview);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PublicDemoProjectInterviewDialog(
          engineerId: engineerId,
          aggregate: _game,
          onCommit: _commitAggregate,
        ),
      );
    } finally {
      _projectInterviewLaunchInProgress = false;
    }
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
    // Issue #168 FIRST-FUN-YEAR-ONBOARDING-1: April is the first month this
    // guard fires for — mirrors `closeOrdinaryMonth()`'s own check (August-
    // March) and `july()`'s required-only check, wiring the same existing
    // `PublicDemoMonthGuard`/`PublicDemoMonthGuardWarningDialog` authority
    // into the one remaining ungated close path this Issue names. No new
    // guard rule: `_monthGuardRecommendedCandidates` already reads from the
    // same `_recommendedActionCandidates` HOME's own recommended-action slot
    // uses, so April only warns about an engineer who is genuinely
    // `readyForFieldSales` and has not yet started (see
    // `_addEngineerStageCandidate`'s own `waiting`/`skillSheet` branches).
    if (!await _confirmMonthCloseIfRecommendedOutstanding()) return;
    await _precacheEventImage(AssetPaths.eventRecruitmentApplication);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => const PublicDemoEventDialog(
        // CORE-GAMEPLAY Phase 4.5: superseded Issue #168 Finding C's
        // "既存の候補者プールが確認できる" copy. That copy was itself already
        // a truthfulness fix over the original ("新しい応募が届きました") for
        // the applicants `publicDemoMayApplicants` used to pre-seed into
        // `PublicDemoWorkflowState.initial()` from game start — but Phase
        // 4.5 removes that pre-seed entirely (a new game now starts with
        // zero applicants), so there is no longer any candidate pool of any
        // kind to "確認できます" the moment April closes. This copy states
        // the one thing that stays true on every playthrough regardless of
        // what the player did in April: recruiting is a real action
        // (求人媒体) the player takes on 営業, not something that happens on
        // its own.
        title: '採用は求人媒体から始まります',
        imageAsset: AssetPaths.eventRecruitmentApplication,
        imageKey: Key('public-demo-recruitment-application-image'),
        message: '採用候補者は求人媒体を使うと集まります。',
        nextAction: '営業タブから求人媒体を使いましょう。',
      ),
    );
    if (!mounted) return;
    final closedMonth = s.month;
    _commitAggregate(_game.closeApril(monthlyExpenses: expense));
    await _maybeShowMonthlyReport(closedMonth);
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

  /// The active (not yet decided) interactive interview session for
  /// [applicantId], if one has been started (CORE-GAMEPLAY Phase 3).
  RecruitmentInterviewSession? _activeInterviewSession(String applicantId) =>
      workflow.interviewSessions
          .where(
            (session) =>
                session.applicantId == applicantId && !session.completed,
          )
          .firstOrNull;

  /// Whether [applicantId]'s interview was decided "採用候補として進める" —
  /// the point at which the pre-existing 合格・給与提示 offer flow becomes
  /// this card's action again, exactly as it always has been. A session
  /// decided "見送る" never reaches this: [PublicDemoAggregate
  /// .concludeInterviewSession] moves that applicant to
  /// `PublicDemoApplicantStage.rejected` in the same commit, so this
  /// `interviewed`-stage branch never renders for them again.
  bool _interviewDecidedHired(String applicantId) =>
      workflow.interviewSessions.any(
        (session) =>
            session.applicantId == applicantId &&
            session.completed &&
            session.outcome == InterviewOutcome.hired,
      );

  Future<void> _openInterview(String applicantId) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => PublicDemoRecruitmentInterviewDialog(
        applicantId: applicantId,
        aggregate: _game,
        onCommit: _commitAggregate,
      ),
    );
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
        points: ['入社前スキルシートと案件要件の適合度を確認', passed ? '基準点60点をクリア' : '基準点60点に届かず'],
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
    // Issue #168 FIRST-FUN-YEAR-ONBOARDING-1: same Month Guard wiring as
    // `april()` above — checked before this handler's own event dialog and
    // `closeMay` commit, exactly mirroring `closeOrdinaryMonth()`'s ordering.
    if (!await _confirmMonthCloseIfRecommendedOutstanding()) return;
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
    final closedMonth = s.month;
    _commitAggregate(_game.closeMay(week: 9, monthlyExpenses: expense));
    await _maybeShowMonthlyReport(closedMonth);
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

  /// CORE-GAMEPLAY Phase 7A (Assignment Lifecycle): ends the current
  /// project's assignment and releases the engineer back to the real Sales
  /// pipeline (`PublicDemoSalesStage.waiting`) — see
  /// [PublicDemoWorkflowState.endAssignment]'s own doc for the full
  /// precondition/atomicity contract. `_commitAggregate` here is a true
  /// no-op unless [PublicDemoAggregate.endAssignment]'s own precondition
  /// holds, so a stray double-tap (or a resend after an already-processed
  /// press) can never end the same assignment twice.
  void endAssignment(int i) {
    final a = workflow.assignments[i];
    _commitAggregate(_game.endAssignment(a.engineerId));
  }

  Future<void> june() async {
    // Issue #168 FIRST-FUN-YEAR-ONBOARDING-1: same Month Guard wiring as
    // `april()`/`may()` above. `june()` was synchronous before this change
    // (no event dialog of its own); it becomes `Future<void> async` solely
    // to await this check, mirroring `closeOrdinaryMonth()`'s ordering — its
    // own commit/reset logic below is otherwise unchanged.
    if (!await _confirmMonthCloseIfRecommendedOutstanding()) return;
    final assigned = workflow.assignments
        .where(
          (a) =>
              a.nextOrderStatus == PublicDemoNextOrderStatus.accepted ||
              a.replacementStage == PublicDemoReplacementStage.ordered,
        )
        .length;
    final joinedHires = workflow.applicants.where(accepted);
    final closedMonth = s.month;
    _commitAggregate(
      _game.closeJune(
        assignedInJuly: assigned,
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: expense,
          hires: joinedHires,
        ),
      ),
    );
    await _maybeShowMonthlyReport(closedMonth);
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

  /// Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1: the single entry point
  /// for the founder follow-up decision, bound identically from the
  /// employees-tab card and the HOME recommended-action CTA (see
  /// [_addFounderFollowUpCandidate]). Mirrors [raise]'s shape: a dialog
  /// collects the decision, [PublicDemoAggregate
  /// .applyFounderFollowUpDecision] commits it, then a result dialog
  /// explains exactly what changed — never shown when the commit was
  /// silently rejected (`identical(next, _game)`), so the player is never
  /// told an effect happened when it did not.
  Future<void> founderFollowUp(PublicDemoEngineerSales e) async {
    final canAffordInvestSupport =
        s.cash >= PublicDemoFounderFollowUp.investSupportCost &&
        !s.isFinanciallyRestricted;
    final decision = await showDialog<PublicDemoFounderFollowUpDecision>(
      context: context,
      builder: (context) => PublicDemoFounderFollowUpDialog(
        engineer: e,
        canAffordInvestSupport: canAffordInvestSupport,
      ),
    );
    if (!mounted || decision == null) return;
    final next = _game.applyFounderFollowUpDecision(
      engineerId: e.id,
      decision: decision,
    );
    final applied = !identical(next, _game);
    _commitAggregate(next);
    if (!applied || !mounted) return;
    await _precacheEventImage(AssetPaths.eventCompanyManagement);
    if (!mounted) return;
    final mentalDelta = PublicDemoFounderFollowUp.mentalDeltaFor(decision);
    final trustDelta = PublicDemoFounderFollowUp.trustDeltaFor(decision);
    final cost = PublicDemoFounderFollowUp.costFor(decision);
    String signed(int delta) => delta >= 0 ? '+$delta' : '$delta';
    await showDialog<void>(
      context: context,
      builder: (context) => PublicDemoEventDialog(
        title: '${e.name}へのフォローを実施しました',
        imageAsset: AssetPaths.eventCompanyManagement,
        imageKey: Key('public-demo-founder-follow-up-result-image-${e.id}'),
        message: PublicDemoFounderFollowUp.reasonFor(decision),
        nextAction:
            'メンタル${signed(mentalDelta)} / 信頼${signed(trustDelta)}'
            '${cost > 0 ? ' / 費用 ¥$cost' : ''}',
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
  ///  * [HomeRecommendedActionKind.founderFollowUp] — Issue #167
  ///    FIRST-FUN-YEAR-LATE-GAME-1 Phase 1's design principle #1 is
  ///    explicit that this decision "does not need to be a forced modal
  ///    every month": it stays eligible across the whole August-February
  ///    window (`PublicDemoFounderFollowUp.isEligible`), so warning on
  ///    every single month-close attempt during that stretch would turn an
  ///    optional, player-paced decision into exactly the nag this feature
  ///    exists to avoid. The card and HOME CTA remain visible and available
  ///    the whole window regardless of this exclusion.
  ///  * [HomeRecommendedActionKind.recruitmentMedia] — CORE-GAMEPLAY Phase
  ///    4.5's merge-blocker fix widened this from a one-time May card to
  ///    every month the domain's own `canUseRecruitmentMediaInMonth` allows
  ///    and this month has not yet used it (April-August). Recruiting is a
  ///    discretionary, costed economic choice, not an outstanding decision
  ///    the player forgot — the same "does not need to be a forced modal
  ///    every month" principle [founderFollowUp] states above applies
  ///    identically here, and without this exclusion the guard would nag on
  ///    literally every close in that window, including a run where the
  ///    player has genuinely finished everything else. The card and HOME
  ///    CTA remain visible and available regardless of this exclusion.
  List<PublicDemoMonthGuardCandidate> get _monthGuardRecommendedCandidates => [
    for (final candidate in _recommendedActionCandidates)
      if (!candidate.action.kind.isInformational &&
          candidate.action.kind !=
              HomeRecommendedActionKind.summerBonusDecision &&
          candidate.action.kind != HomeRecommendedActionKind.founderFollowUp &&
          candidate.action.kind != HomeRecommendedActionKind.recruitmentMedia)
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
    final closedMonth = s.month;
    _commitAggregate(_game.closeJuly(monthlyExpenses: _julyMonthlyExpenses));
    await _maybeShowMonthlyReport(closedMonth);
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
    final closedMonth = s.month;
    _commitAggregate(
      _game.closeOrdinaryMonth(monthlyExpenses: _ordinaryMonthlyExpenses),
    );
    await _maybeShowMonthlyReport(closedMonth);
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

  /// SES SALES Visual Complete: the badge color for [julyResult]'s own
  /// verbatim string — a staffed outcome (継続/切替) reads positive; the
  /// truthful "not yet staffed" outcome reads caution (never negative — it
  /// is not a failure, just a still-open action on 社員/営業).
  PublicDemoSalesStatusTone _julyResultTone(PublicDemoAssignment a) =>
      a.nextOrderStatus == PublicDemoNextOrderStatus.accepted ||
          a.replacementStage == PublicDemoReplacementStage.ordered
      ? PublicDemoSalesStatusTone.positive
      : PublicDemoSalesStatusTone.caution;

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

  /// SES EMPLOYEE STATUS UNIFIED DISPLAY (Fresh Audit,
  /// docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Fresh-Audit.md):
  /// the single place this screen resolves an engineer's player-facing
  /// status (label + badge tone together), delegating to the pure
  /// [PublicDemoEmployeeStatusResolver]. Replaces the three independently
  /// hand-maintained functions the Fresh Audit found: the former
  /// `_currentEmployeeStatusLabel` (社員タブ label), the former
  /// `_employeeStatusTone` (社員タブ badge color), and each SkillSheet call
  /// site ([_openSkillSheetReview]/[_viewEmployeeSkillSheet]) passing raw
  /// `engineerStatus(engineer)` straight through as `statusLabel`.
  ///
  /// This fixes both inconsistencies the Fresh Audit confirmed by tracing
  /// the code (§3), plus the PR #238 review follow-up below:
  ///  * An already-`ordered`+currently-assigned engineer's SkillSheet used
  ///    to keep showing the stale '翌月参画予定' while the roster/HOME
  ///    already said '参画中' for the same person — SkillSheet now reads
  ///    this same resolved display, so it cannot disagree.
  ///  * A field-sales-ready `waiting` engineer (or any other non-training
  ///    status) with this month's training also selected
  ///    (`PublicDemoState.trainingSelections`) used to show the correct
  ///    '営業可能' text painted in the training (red) tone — the resolver
  ///    never lets `trainingSelections` override label or tone at all (see
  ///    [PublicDemoEmployeeStatusResolver.resolve]'s own doc), so text and
  ///    color can no longer disagree.
  ///  * (found during this consolidation, not by the original audit) the
  ///    former `_employeeStatusTone` treated *any* currently-assigned
  ///    engineer as the 参画中 tone, without the label's own
  ///    `stage == ordered` requirement — an engineer whose assignment was
  ///    just ended mid-month while this month's revenue still counts them
  ///    (`PublicDemoWorkflowState.endAssignment`'s documented pre-July
  ///    "row kept, stage reset to waiting" case) is genuinely back at
  ///    `waiting` and could show a green 参画中 tone next to a
  ///    研修が必要/営業可能 label. One shared condition for both label and
  ///    tone closes this too.
  ///  * PR #238 review follow-up (P1): the first version of this resolver
  ///    still fell back to the caller-supplied raw `engineerStatus` label
  ///    for every sales-pipeline sub-stage and for an `ordered`-but-not-yet-
  ///    assigned engineer, so the roster/SkillSheet kept showing the
  ///    un-collapsed raw text (営業準備/案件紹介済/各面談通過・不合格/翌月参画予定)
  ///    instead of Fresh Audit §4's actual six-value taxonomy. Fixed inside
  ///    [PublicDemoEmployeeStatusResolver.resolve] itself — see that
  ///    method's own doc — with no change needed here beyond dropping the
  ///    now-removed `rawStageLabel` argument below.
  ///
  /// Reads only existing authoritative facts already used elsewhere on this
  /// screen ([_currentlyAssignedEngineerIds], [readyForFieldSales],
  /// [_fieldSalesActionReachableThisMonth]) — no new domain authority, enum,
  /// or persisted field. `engineerStatus`'s own raw 9-stage switch is
  /// unchanged and still backs the sales-pipeline detail views that
  /// legitimately keep showing it verbatim ([engineerStep]'s
  /// `PublicDemoSalesProgress` stepper, the Sales tab) — only the
  /// card-level player-facing status this resolver computes now differs
  /// from it on purpose.
  ///
  /// HOME Freeze: HOME's own [_officeStageStatusFor] is deliberately NOT
  /// routed through this resolver in this change. Every prior consolidation
  /// touching this same status logic (#231, Employee UI Phase 1; #235/#236)
  /// explicitly left `_officeStageStatusFor` byte-for-byte untouched rather
  /// than share even logically-equivalent code with it, treating any diff
  /// inside HOME-owned code as HOME Freeze risk regardless of behavior
  /// preservation. This change follows that same established precedent:
  /// HOME's Office Stage keeps its own separate, unchanged implementation,
  /// still built on the raw `engineerStatus` switch. On the 参画中/参画予定
  /// split, HOME reads the exact same underlying fact this resolver does
  /// (`stage == ordered && isCurrentlyAssigned`) and shows the same '参画中'
  /// text, so the two cannot disagree there. On every sales-pipeline
  /// sub-stage (and on the exact wording of an `ordered`-but-not-yet-
  /// assigned engineer — HOME still says '翌月参画予定', the roster/SkillSheet
  /// now say '参画予定'), HOME intentionally still shows the raw, un-
  /// collapsed `engineerStatus` label rather than this resolver's unified
  /// 営業中/参画予定 buckets — a known, tracked cross-surface wording gap
  /// (see the governing plan's own Update history entry for this Issue),
  /// not a regression this PR introduced. Routing HOME through this
  /// resolver is a safe, ready-to-do follow-up once HOME Freeze is lifted or
  /// explicitly confirmed to allow a behavior-preserving internal refactor.
  PublicDemoEmployeeStatusDisplay _employeeStatusDisplayFor(
    PublicDemoEngineerSales engineer,
  ) => PublicDemoEmployeeStatusResolver.resolve(
    stage: engineer.stage,
    isCurrentlyAssigned: _currentlyAssignedEngineerIds.contains(engineer.id),
    isReadyForFieldSales: readyForFieldSales(engineer.id),
    fieldSalesActionReachableThisMonth: _fieldSalesActionReachableThisMonth(
      engineer,
    ),
  );

  /// PR #233 Codex review (P2): [_employeeStatusDisplayFor]'s '営業可能'
  /// must only be shown in a month where `_employeeNextActionsSection`'s
  /// `ec(i)` card — the only control that can actually start selling
  /// (スキルシート確認/営業開始) — is reachable for THIS engineer; otherwise the
  /// roster would name an action with no control anywhere on screen to take
  /// it (a new dead end this Issue explicitly forbids). Mirrors `ec(i)`'s
  /// own render conditions in `_employeeNextActionsSection` exactly,
  /// simplified using the facts already established by the `waiting`-stage
  /// caller (never `ordered`, never currently assigned):
  ///  * April (4) through February (14): `ec(i)` renders every month in
  ///    this range for every not-yet-`ordered`, not-currently-assigned
  ///    engineer — April unconditionally, May-June per Issue #243
  ///    FIRST-FUN-YEAR P1 (Fresh Audit Finding 1: previously May rendered
  ///    `ec(i)` for nobody and June only for a later-joined hire, leaving
  ///    a founding engineer stuck mid-pipeline with no reachable action for
  ///    two months), and July-February via RECOVERY-LOOP-1.
  ///  * March (15): `ec(i)` is never rendered at all this screen, in any
  ///    branch — so '営業可能' falls back to the plain, pre-existing
  ///    [engineerStatus] label there instead (the fiscal year's final,
  ///    no-recovery month).
  /// '研修が必要' needs no such gating: `_employeeGrowthSection`'s internal-
  /// training card is unconditionally reachable every month from May
  /// through March (`s.month >= 5`), independently of `ec(i)`.
  bool _fieldSalesActionReachableThisMonth(PublicDemoEngineerSales engineer) {
    return s.month >= 4 && s.month <= 14;
  }

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

  /// SES SALES Visual Complete: the badge color for [applicantStatus]'s own
  /// verbatim label — a closed/won stage (内定承諾, 各面談通過,
  /// 入社・参画予定) reads positive, a closed/lost stage (不採用, 内定辞退,
  /// 各面談不合格) reads negative, and everything still moving through the
  /// pipeline reads inProgress. Reads only [a.stage] — the same fact
  /// [applicantStatus] itself switches on — so the two can never disagree.
  PublicDemoSalesStatusTone _applicantStatusTone(PublicDemoApplicant a) =>
      switch (a.stage) {
        PublicDemoApplicantStage.rejected ||
        PublicDemoApplicantStage.offerDeclined ||
        PublicDemoApplicantStage.preEntryPartnerFailed ||
        PublicDemoApplicantStage.preEntryClientFailed =>
          PublicDemoSalesStatusTone.negative,
        PublicDemoApplicantStage.offerAccepted ||
        PublicDemoApplicantStage.preEntryPartnerPassed ||
        PublicDemoApplicantStage.preEntryClientPassed ||
        PublicDemoApplicantStage.juneOrdered =>
          PublicDemoSalesStatusTone.positive,
        _ => PublicDemoSalesStatusTone.inProgress,
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
  /// PUBLIC-DEMO-HOME-UI-3B: the former `dashboard()` split in two along the
  /// tab boundary — the monthly cash-flow card is finance detail (会計), the
  /// growth results are per-employee status (社員). Splitting only changed
  /// which Column a widget renders inside; neither widget's own content,
  /// key, or authority changed.
  Widget _monthlyCashFlowSection() => s.latestMonthlyCashFlow == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: KeyedSubtree(
            key: _monthlyCashFlowKey,
            child: PublicDemoMonthlyCashFlowCard(
              flow: s.latestMonthlyCashFlow!,
            ),
          ),
        );

  Widget _growthResultsSection() {
    if (s.latestGrowthResults.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('今月の成長', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        for (final result in s.latestGrowthResults)
          PublicDemoGrowthResultCard(
            engineerName: _engineerName(result.engineerId),
            result: result,
          ),
      ],
    );
  }

  String _engineerName(String engineerId) {
    for (final engineer in workflow.engineers) {
      if (engineer.id == engineerId) return engineer.name;
    }
    for (final applicant in workflow.applicants) {
      if (applicant.id == engineerId) return applicant.name;
    }
    return '社員';
  }

  Widget employeeConditionCard(PublicDemoApplicant a) {
    final morale = a.employeeMorale!, trust = a.employeeCompanyTrust!;
    final reason = a.relationshipHistory.last.reason;
    return Card(
      key: Key('public-demo-employee-condition-${a.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SES HUMAN-REPLAY PRE-FIX P1-1/P1-3: same duplicate-name
            // demotion as `ec(i)` above — this employee's name is already
            // shown, at full weight, in Section 1's roster row.
            Text(
              a.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
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

  /// Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1: the card for a
  /// currently-assigned founding engineer whose follow-up decision is still
  /// outstanding. Rendered only where [PublicDemoFounderFollowUp.isEligible]
  /// already holds (see the call site in `_buildEmployeesTab`); the button
  /// re-runs the exact same check via [PublicDemoAggregate
  /// .applyFounderFollowUpDecision] before it does anything, never relying
  /// on the UI alone.
  Widget founderFollowUpCard(PublicDemoEngineerSales e) => Card(
    key: Key('public-demo-founder-follow-up-card-${e.id}'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SES HUMAN-REPLAY PRE-FIX P1-1/P1-3: same duplicate-name
          // demotion as `ec(i)` above — this employee's name is already
          // shown, at full weight, in Section 1's roster row.
          Text(
            e.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '案件への参画が続いています。しばらくフォローの機会がありません。',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: Key('public-demo-founder-follow-up-${e.id}'),
            onPressed: () => unawaited(founderFollowUp(e)),
            child: const Text('フォローする'),
          ),
        ],
      ),
    ),
  );

  /// SES ACTIVE-PROJECT-VISIBILITY Phase 1: a read-only per-engineer card
  /// showing which project a currently-assigned engineer is in and its
  /// state, using only [PublicDemoAssignment]'s existing
  /// `engineerName`/`projectName`/`deliveryPressure`/`budgetHealth` fields
  /// — the authoritative facts [PublicDemoWorkflowState.assignments] /
  /// [PublicDemoWorkflowState.assignedEngineerIds] already hold. No new
  /// domain field, persisted value, or client/company/pricing/contract
  /// data is introduced. `fieldEvaluation` is deliberately not shown here:
  /// today it is always its constructed default (50) for every assignment
  /// in every reachable game state, so surfacing it would present a
  /// constant as a meaningful evaluation.
  ///
  /// SES FIRST-FUN-YEAR P1 (Project/Order/Assignment Continuous Visibility):
  /// the project line now reads [_realProjectNameFor] instead of `a
  /// .projectName` verbatim — the real [Project.title] when this assignment
  /// carries a genuine Phase 6 `projectId`, else `a.projectName` itself
  /// unchanged (still the exact same generic placeholder this card always
  /// showed before). No new fact: this is the identical `project?.title ??
  /// assignment.projectName` resolution [PublicDemoAggregate
  /// ._careerHistoryEntryFor] already performs for the same assignment when
  /// it ends, now also read here so a still-active, genuinely project-bound
  /// assignment shows its real project's name instead of the generic
  /// template a fresh order always starts with (see
  /// [PublicDemoAssignment.forOrderedEngineer]'s own doc).
  Widget activeProjectStatusCard(PublicDemoAssignment a) => Card(
    key: Key('public-demo-active-project-status-${a.engineerId}'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.work_outline,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  a.engineerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const PublicDemoEmployeeStatusBadge(
                label: '参画中',
                tone: PublicDemoEmployeeStatusTone.assigned,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '参画中案件：${_realProjectNameFor(a)}',
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _assignmentMetricBar(label: '納期プレッシャー', value: a.deliveryPressure),
          const SizedBox(height: 6),
          _assignmentMetricBar(label: '予算健全度', value: a.budgetHealth),
        ],
      ),
    ),
  );

  /// A compact 0-100 metric bar for [activeProjectStatusCard] —
  /// [value] is read verbatim from [PublicDemoAssignment]; a fixed 0-100
  /// rendering scale is not a fabricated number, only a display choice.
  Widget _assignmentMetricBar({required String label, required int value}) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = (value / 100).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$value', style: const TextStyle(fontSize: 11)),
      ],
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
                  // Issue #168 FIRST-FUN-YEAR-ONBOARDING-1 Finding D: states
                  // only facts already true and authoritative elsewhere in
                  // this file/class — who it's for (this card only ever
                  // renders for a waiting, unassigned engineer; see the
                  // `assigned` check above), when the cost is charged
                  // (`PublicDemoInternalTrainingTransaction.execute` deducts
                  // cash the same transaction that records the selection,
                  // immediately on tapping 研修する), when the effect lands
                  // (`PublicDemoGrowthEngine`'s `internalTraining` source is
                  // applied at month-end close, not immediately), and that
                  // `trainingSelections` is a per-month map (re-chosen, not
                  // persisted forward). Deliberately makes no claim about a
                  // specific capability gain, success rate, or sales
                  // eligibility outcome — none of those are safe to state as
                  // a fixed number, and Finding B's own lock-banner copy
                  // already states the truthful, month-agnostic version of
                  // this: reaching the threshold reopens sales from around
                  // that point on, but this card promises neither how many
                  // months of training that takes nor which month it lands
                  // in.
                  const Text(
                    '待機中の社員が対象です。費用は選択時に発生し、効果は月末に反映されます'
                    '（毎月選び直しが必要です）。',
                    style: TextStyle(fontSize: 11),
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
  //   A candidate is emitted only under the exact same condition — a
  //   month `if`, an authority predicate, or both together — as the
  //   production button it triggers.
  //
  // That is not a stylistic preference — it is the whole correctness
  // argument. Most action availability in Public Demo is a predicate
  // *inside a month-gated UI branch*, so a recommendation engine that
  // consulted only the domain predicate would offer the player a button
  // that does not exist in the month's own UI. CORE-GAMEPLAY Phase 4.5's
  // merge-blocker fix retired the standing example of this trap —
  // `canUseRecruitmentMediaInMonth(month)` used to be satisfied across
  // months 4-8 while the 求人媒体 card rendered only in month 5 — by
  // widening the card's own render condition to `_recruitmentMediaCardVisible`
  // (see `_salesNextActionCards` and that getter's own doc), a UI-owned
  // May-August window: a deliberate narrowing of the domain's wider 4-8
  // window, not a re-derivation of it — April is excluded on purpose to
  // keep HOME's existing April layout budget untouched (out of scope for
  // this fix), not because the domain forbids recruiting there.
  // `_addRecruitmentMediaCandidate`'s own emit gate,
  // `_recruitmentMediaCandidateEligible`, is a strict subset of
  // `_recruitmentMediaCardVisible` (visible AND not yet used this month),
  // so wherever the candidate is legal the card is always already
  // rendered *and* enabled — a recommendation can never outrun its own
  // button — while the reverse (card visible, candidate absent because
  // already used) is exactly "nothing disabled is ever emitted" below, not
  // a gap in this invariant. A single shared predicate cannot express both
  // "should the card exist" and "should the CTA be recommended" at once:
  // collapsing them back to one (as this fix originally did) is what
  // regressed the card from a visible-but-disabled "今月は利用済み" state
  // to disappearing outright the instant it was used.
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

    // ---- recruitment media: CORE-GAMEPLAY Phase 4.5 — mirrors
    // `_salesNextActionCards`'s own (no longer month-fixed) render
    // condition, `s.canUseRecruitmentMediaInMonth(s.month)`, the same
    // authority `_addRecruitmentMediaCandidate` itself already reads. Not
    // wrapped in a month `if` here for the same reason the render site no
    // longer is: the domain's real recruiting window is months 4-8, not a
    // single fixed month, and a candidate gated to less than its own
    // button's real availability would under-recommend, not over-recommend.
    _addRecruitmentMediaCandidate(add);

    // ---- applicant funnel: mirrors `_salesApplicantProgressCards`'s own
    // render condition (whenever there is an applicant to act on) — not
    // fixed to May, so a candidate recruited in a later month (June-August,
    // via the same widened recruitment window) is still recommendable.
    //
    // Issue #241: also mirrors that same section's `!a.hasJoined` filter —
    // an already-joined applicant's own pre-entry-pipeline domain
    // transitions now no-op (see `PublicDemoWorkflowState`'s own doc), but
    // without this filter HOME could still surface a stale recommended
    // action (e.g. "入社前スキルシートを確認") pointing at an already-employed
    // person the Sales tab's own funnel no longer shows at all.
    for (final a in workflow.applicants.where((a) => !a.hasJoined)) {
      _addApplicantStageCandidate(add, a);
    }

    // ---- month 6: condition cards, then the assignment cards — unchanged.
    if (s.month == 6) {
      for (final a in _joinedEmployees) {
        _addRaiseCandidate(add, a);
      }
    }

    // ---- months 5-6: Issue #243 FIRST-FUN-YEAR P1 (Fresh Audit Finding
    // 1) — mirrors `_employeeNextActionsSection`'s own widened `ec(i)`
    // render-site loop exactly (same month window, same filter): any
    // engineer not yet `ordered` and not currently assigned, not just a
    // later-joined hire. Kept in the same emission position this single
    // engineer-stage loop already held at month 6 (between the raise
    // candidates above and the assignment candidates below) so tie-break
    // order among same-priority candidates is unchanged for June.
    if (s.month == 5 || s.month == 6) {
      for (final e in workflow.engineers) {
        if (e.stage == PublicDemoSalesStage.ordered) continue;
        if (workflow.assignments.any((x) => x.engineerId == e.id)) continue;
        _addEngineerStageCandidate(add, e);
      }
    }

    if (s.month == 6) {
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

    // ---- months 8-14: founder follow-up (Issue #167
    // FIRST-FUN-YEAR-LATE-GAME-1 Phase 1) — the same
    // `founderFollowUpCard(e)` render site further down in
    // `_buildEmployeesTab` uses this exact eligibility check and binds the
    // exact same handler.
    if (s.month >= publicDemoFounderFollowUpWindowStart &&
        s.month <= publicDemoFounderFollowUpWindowEnd) {
      for (final e in workflow.engineers) {
        _addFounderFollowUpCandidate(add, e);
      }
    }

    return candidates;
  }

  /// Mirrors `founderFollowUpCard`'s button. `PublicDemoFounderFollowUp
  /// .isEligible` is the same authority the card itself re-checks before
  /// rendering.
  void _addFounderFollowUpCandidate(
    _AddCandidate add,
    PublicDemoEngineerSales e,
  ) {
    if (!PublicDemoFounderFollowUp.isEligible(
      engineer: e,
      month: s.month,
      assignedEngineerIds: workflow.assignedEngineerIds(month: s.month),
    )) {
      return;
    }
    add(
      HomeRecommendedActionKind.founderFollowUp,
      () => unawaited(founderFollowUp(e)),
      subjectName: e.name,
      targetId: e.id,
    );
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
            _startClientInterview(
              workflow.engineers.indexWhere((x) => x.id == e.id),
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
          () => unawaited(_reviewResumeAndOpenSkillSheet(a)),
        );
      case PublicDemoApplicantStage.resumeReviewed:
        if (s.salesRemaining > 0) {
          emit(
            HomeRecommendedActionKind.applicantInterview,
            () => recruit(index),
          );
        }
      case PublicDemoApplicantStage.interviewed:
        if (_interviewDecidedHired(a.id)) {
          if (a.interviewScore >= 60) {
            emit(
              HomeRecommendedActionKind.applicantSalaryOffer,
              () => unawaited(offer(index)),
            );
          }
        } else {
          emit(
            HomeRecommendedActionKind.applicantContinueInterview,
            () => unawaited(_openInterview(a.id)),
          );
        }
      case PublicDemoApplicantStage.offerAccepted:
        // The card renders a button only for the pre-join sales path; the
        // other branch is the read-only `入社後、研修で育成します` line.
        if (a.canEnterPreJoinSales) {
          emit(
            HomeRecommendedActionKind.applicantBeginPreEntrySkillSheet,
            () => unawaited(_beginPreEntrySkillSheetAndOpen(a)),
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

  /// Whether the Sales tab's 求人媒体 card is visible this month at all.
  ///
  /// PR #210 merge-blocker follow-up: [PublicDemoState
  /// .isRecruitmentMediaWindowMonth] is the domain's real recruiting window
  /// (April-August, [PublicDemoState._normalizedRecruitmentMediaMonth]) —
  /// but this UI deliberately narrows it to May-August, not April. The
  /// merge blocker's own ask was "do not keep the entry point artificially
  /// limited to May if domain authority allows *later* recruitment" — a
  /// forward extension past the original one-shot May card, not a backward
  /// one into April. April already has its own truthful "no card yet"
  /// state (`_salesTabEmptyState`) and, more importantly, HOME's own
  /// One-Screen Final Fit layout budget for the initial April view was
  /// authored and verified against April never having a Recommended Action
  /// card at all; the top-level merge-blocker instructions explicitly rule
  /// out HOME layout changes in this fix, so this bound is what keeps that
  /// budget untouched rather than widening into a change nobody asked for.
  /// Domain authority itself is unchanged (`recruit()` still succeeds in
  /// April, exactly as it always could) — only this UI's own entry point
  /// stays narrower than the domain would allow, the same already-accepted
  /// shape [PublicDemoState._normalizedRecruitmentMediaMonth]'s own doc
  /// describes for the domain's 8-15 side of this same window.
  bool get _recruitmentMediaCardVisible =>
      s.month >= 5 && s.isRecruitmentMediaWindowMonth(s.month);

  /// Whether recruitment media is both visible ([_recruitmentMediaCardVisible])
  /// and this month's single use is still unspent
  /// ([PublicDemoState.canUseRecruitmentMediaInMonth]) — the HOME
  /// Recommended Action candidate's own eligibility, since a candidate must
  /// never point at a hidden or disabled button (see this file's own
  /// "Nothing disabled is ever recommended" rule).
  bool get _recruitmentMediaCandidateEligible =>
      _recruitmentMediaCardVisible && s.canUseRecruitmentMediaInMonth(s.month);

  /// Mirrors `_RecruitmentMediaCard`'s enablement via
  /// [_recruitmentMediaCandidateEligible] — the card is rendered for every
  /// month [_recruitmentMediaCardVisible] allows, but its own button is
  /// disabled once that month's single use is spent, so only the usable
  /// case is a candidate.
  ///
  /// PR #210 merge-blocker follow-up: called unconditionally (not from a
  /// month-5 branch) — see the call site's own doc — since the card itself
  /// is no longer fixed to May alone either.
  void _addRecruitmentMediaCandidate(_AddCandidate add) {
    if (!_recruitmentMediaCandidateEligible) return;
    add(
      HomeRecommendedActionKind.recruitmentMedia,
      () => unawaited(_openRecruitmentMedia()),
    );
  }

  // Internal training is deliberately not emitted — see
  // HomeRecommendedActionKind's "deliberate absences".

  Widget assignmentCard(int i) {
    final a = workflow.assignments[i];
    return PublicDemoSalesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PublicDemoSalesAvatar(
                assetPath: homeOfficeStagePortraitFor(a.engineerId),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.engineerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: PublicDemoSalesStatusBadge(
                  label: a.nextOrderStatus == PublicDemoNextOrderStatus.accepted
                      ? '継続予定'
                      : '参画中',
                  tone: PublicDemoSalesStatusTone.positive,
                ),
              ),
              // CORE-GAMEPLAY Phase 4.5: reuses the exact same
              // [_viewEmployeeSkillSheet]/[PublicDemoSkillSheetSheet] the
              // 社員 tab's roster row uses — proving the SkillSheet display
              // is genuinely reusable from 営業's own案件 view, the concrete
              // hook point a future Phase 5 (Matching) surface can follow.
              if (_engineerById(a.engineerId) case final engineer?)
                IconButton(
                  key: Key('public-demo-sales-assignment-skill-sheet-${a.engineerId}'),
                  tooltip: 'スキルシートを見る',
                  icon: const Icon(Icons.description_outlined, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => unawaited(_viewEmployeeSkillSheet(engineer)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.business_center_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _realProjectNameFor(a),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
            // CORE-GAMEPLAY Phase 7A (Assignment Lifecycle): the real
            // end-of-contract path, alongside the existing 別案件探し
            // (replacementStage) mini-cycle below — once a replacement is
            // actually secured (`ordered`) this button no longer appears,
            // matching [PublicDemoWorkflowState.endAssignment]'s own
            // precondition exactly. Also gated on the engineer's own stage
            // still being `ordered`: before month 7,
            // [PublicDemoWorkflowState.endAssignment] deliberately leaves
            // this row in place (to protect this month's Finance
            // projection — see its own doc) after already releasing the
            // engineer, so without this check the button would keep
            // rendering, now a silent no-op, after a press already
            // succeeded.
            if (a.replacementStage != PublicDemoReplacementStage.ordered &&
                _engineerById(a.engineerId)?.stage ==
                    PublicDemoSalesStage.ordered)
              OutlinedButton(
                key: Key('public-demo-assignment-end-${a.engineerId}'),
                onPressed: () => endAssignment(i),
                child: const Text('契約終了して営業へ戻す'),
              ),
            if (a.replacementStage == PublicDemoReplacementStage.none)
              FilledButton(
                onPressed: () => ars(i, PublicDemoReplacementStage.selling),
                child: const Text('次案件の営業開始'),
              ),
            if (a.replacementStage == PublicDemoReplacementStage.selling)
              FilledButton.tonal(
                onPressed: () => ars(i, PublicDemoReplacementStage.introduced),
                child: const Text('案件紹介'),
              ),
            if (a.replacementStage == PublicDemoReplacementStage.introduced)
              FilledButton(
                onPressed: s.salesRemaining > 0
                    ? () => replacementPartner(i)
                    : null,
                child: const Text('上位会社面談（1枠）'),
              ),
            if (a.replacementStage == PublicDemoReplacementStage.partnerPassed)
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
    );
  }

  Widget ec(int i, {bool showTrainingCard = true}) {
    final e = workflow.engineers[i];
    final capability = capabilityFor(e.id);
    final fieldSalesRequirement =
        PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement;
    // Issue #168 Finding B (Codex P2, PR #177): the lock banner's
    // month-agnostic "reaching the threshold reopens sales from around
    // that point on" line is only truthful while a later month can still
    // render this same waiting/skillSheet card at all.
    // `PublicDemoRecoveryEligibility.lastEligibleMonth` (February, 14) is
    // the existing, authoritative last month `_buildEmployeesTab`'s
    // `s.month >= 7 && s.month <= 14` loop ever renders it — training
    // selected in February applies its growth at month-end, entering
    // March (15), which that loop never covers and this fix does not
    // extend into. From February on, the forward-looking line would
    // promise a route this build cannot actually offer, so it is replaced
    // with the truthful, equally month-agnostic fact instead: this is the
    // fiscal year's last chance.
    final isLastEligibleMonth =
        s.month >= PublicDemoRecoveryEligibility.lastEligibleMonth;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SES EMPLOYEE-UI-PHASE-1: the name-plus-status badge header
            // moved to Section 1 (`_employeeRosterSection`), which now
            // shows every employee's truthful current status in one place
            // — this card kept its own copy of the same badge would be the
            // exact "重複情報" the phase's own scope calls out to reduce.
            // This card (Section 2, 今やるべき社員アクション) states the
            // employee's name once and focuses on the action itself; the
            // sales-stage step is still visible via
            // [PublicDemoSalesProgress] below.
            //
            // SES HUMAN-REPLAY PRE-FIX P1-1/P1-3: this same name is also
            // shown, at full weight, in Section 1's roster row directly
            // above this section — a second full-size bold repeat here
            // was exactly the "重複" the audit flagged. Kept (never
            // removed — with 2+ employees, Section 2's cards no longer sit
            // next to a single unambiguous roster row) but demoted to a
            // small, muted caption so the action below it, not the name,
            // reads as this card's primary content.
            Text(
              e.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(e.summary),
            PublicDemoSalesProgress(currentStep: engineerStep(e)),
            // SES FIRST-FUN-YEAR P1 (Project/Order/Assignment Continuous
            // Visibility): states which real project this stepper's stage
            // is actually for — before this, an engineer at 案件紹介済/各面談
            // showed only the raw pipeline step, with no way to see which
            // of this month's real Phase 4 projects (`_introduceProject`'s
            // own auto-pick fallback, or the player's own "案件を見る"
            // choice) they were actually proposed for/interviewing for
            // until an order/assignment appeared, months later. `null` for
            // `waiting`/`skillSheet`/`selling` (nothing introduced yet) and
            // for `partnerInterviewFailed`/`clientInterviewFailed` (PR #240
            // Codex Broad Review P1 fix: that interview already concluded in
            // failure, so labeling it 提案中の案件 — "currently proposing" —
            // would misstate an already-decided outcome as still in
            // progress; see [PublicDemoProjectContextResolver.projectIdFor]'s
            // own doc). The raw stepper above still shows the failed step,
            // and 再営業 remains the one existing recovery action.
            if (_projectContextFor(e) case final projectContext?)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Text(
                  '${projectContext.label}：${projectContext.title}'
                  '（${projectContext.clientName}・月額'
                  '${projectContext.monthlyRate ~/ 10000}万円）',
                  key: Key('public-demo-employee-project-context-${e.id}'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 6),
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
                    const Text('まだ営業を始められません。', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 2),
                    // Issue #168 Finding B: P1 (PR #115 review) had this line
                    // say nothing at all after "まだ営業を始められません。",
                    // because — at the time — no later month actually
                    // reopened this card for a founding engineer once April
                    // closed without meeting fieldSalesCapabilityRequirement.
                    // That gap is what Finding B fixes: `_buildEmployeesTab`'s
                    // own July-February `ec(i, showTrainingCard: false)` loop
                    // (RECOVERY-LOOP-1) already re-renders every still-
                    // `waiting`/`skillSheet`, unassigned engineer's card —
                    // `readyForFieldSales` included — so an engineer who
                    // reaches the threshold through repeated training does
                    // get 営業準備（SkillSheet確認） back, just not necessarily in
                    // the same month training last ran. This line states
                    // that causal fact without naming a specific month, which
                    // this build cannot promise (it depends on how many
                    // months of training the player chooses to buy).
                    //
                    // Codex P2 (PR #177): that promise stops being true at
                    // [isLastEligibleMonth] — training selected there only
                    // takes effect entering March, which no later `ec(...)`
                    // render ever covers — so this branches to a second,
                    // equally month-agnostic truthful line instead of
                    // dangling a route this build cannot offer.
                    if (isLastEligibleMonth)
                      const Text(
                        '実力が基準に達しても、今年度中の営業再開はもう見込めません。',
                        style: TextStyle(fontSize: 12),
                      )
                    else
                      const Text(
                        '実力が基準に達すれば、その月以降に営業を再開できます。',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            if (e.stage == PublicDemoSalesStage.waiting &&
                readyForFieldSales(e.id)) ...[
              const Text('営業準備OK', style: TextStyle(fontSize: 12)),
              FilledButton(
                onPressed: () => unawaited(_openSkillSheetReview(e)),
                // Deliberately not "スキルシートを確認" (HOME's own
                // `employeeSkillSheetReview` recommended-action CTA label) —
                // `home_recommended_action_test.dart`'s "no CTA label is
                // byte-identical to a legacy Public Demo control" rule
                // requires the HOME shortcut and the screen control it
                // triggers to read as visibly distinct text.
                child: const Text('スキルシート確認'),
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
                onPressed: () => unawaited(_startClientInterview(i)),
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
            // runtime (`_employeeGrowthSection`'s `s.month >= 5` block
            // further down in build()) — rendering this embedded one too
            // would duplicate the same `public-demo-internal-training-<id>`
            // key on screen at once. Only April (month 4, before that
            // unconditional block's own `>= 5` window starts) is unaffected:
            // [showTrainingCard] stays true there, exactly as before this
            // parameter existed. Issue #243 FIRST-FUN-YEAR P1 (Fresh Audit
            // Finding 1) widened May/June's own `ec(i)` render site to the
            // same `>= 5` window, so they now pass `false` here too, for the
            // same reason RECOVERY-LOOP-1 already does.
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
    return PublicDemoSalesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PublicDemoSalesAvatar(
                assetPath: homeOfficeStagePortraitFor(a.id),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: PublicDemoSalesStatusBadge(
                  label: applicantStatus(a),
                  tone: _applicantStatusTone(a),
                ),
              ),
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
              onPressed: () => unawaited(_reviewResumeAndOpenSkillSheet(a)),
              // Deliberately not "スキルシートを確認" — see the employee-tab
              // gating button's own comment above (`ec(i)`) for why this
              // stays visibly distinct from HOME's `employeeSkillSheetReview`
              // CTA label.
              child: const Text('スキルシート確認'),
            ),
          if (a.stage == PublicDemoApplicantStage.resumeReviewed)
            FilledButton(
              onPressed: s.salesRemaining > 0 ? () => recruit(i) : null,
              child: const Text('採用面談'),
            ),
          if (a.stage == PublicDemoApplicantStage.interviewed) ...[
            Text('評価 ${a.interviewScore}'),
            Text('希望給与 ${a.requestedMonthlySalary ~/ 10000}万円'),
            if (_interviewDecidedHired(a.id))
              FilledButton(
                onPressed: a.interviewScore >= 60 ? () => offer(i) : null,
                child: const Text('合格・給与提示'),
              )
            else
              FilledButton(
                key: ValueKey('public-demo-interview-open-${a.id}'),
                onPressed: () => _openInterview(a.id),
                child: Text(
                  _activeInterviewSession(a.id) == null ? '面談を行う' : '面談を続ける',
                ),
              ),
          ],
          if (a.stage == PublicDemoApplicantStage.offerAccepted &&
              a.canEnterPreJoinSales)
            FilledButton(
              onPressed: () => unawaited(_beginPreEntrySkillSheetAndOpen(a)),
              child: const Text('入社前スキルシートを確認'),
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

  /// HOME (index 0) — summary/decision surface only. PUBLIC-DEMO-HOME-UI-3B:
  /// this used to be the single screen everything lived on; the full
  /// employee roster/training list and the full finance detail that used to
  /// render below these sections are gone from here — they are real content
  /// on the 社員 and 会計 tabs now (see [_buildEmployeesTab] /
  /// [_buildAccountingTab]), not merely scrolled past. Every widget below
  /// is unchanged from PUBLIC-DEMO-HOME-UI-3A/HOME-COMPACT-1B — only the
  /// legacy detail sections that used to follow them in the same ListView
  /// are gone from this method.
  Widget _buildHomeTab(BuildContext c, HomeNavigatorAdvice? navigatorAdvice) =>
      ListView(
        key: const PageStorageKey('public-demo-home-tab'),
        controller: _scrollController,
        // SES HOME One-Screen Final Fit: top/bottom trimmed again, from
        // 4/16 — the initial 360x800/390x844 April view must fit with no
        // scroll at all (see the result report's before/after overflow
        // measurement), and this outer padding is real slack, never text
        // or touch-target room. Left/right stay 16 so every card keeps its
        // existing horizontal margin.
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HOME-RUNTIME-2A: the FINANCE-FAILURE-1C shortage
              // explanation is hoisted above everything else. Its
              // authority is unchanged and still lives entirely in the
              // card itself — it renders only when
              // `state.financialStatus == cashShortage` and never infers
              // that from the sign of cash.
              PublicDemoCashShortageCard(
                state: s,
                nextClose: _nextCloseForecastEntry,
              ),
              // PLAYTEST-BLOCKER-1A: when a terminal financial state is
              // reached (bankruptcy or March cash-shortage failure),
              // show a prominent card that communicates the game-over
              // reason, the final cash, and a safe restart action.
              if (s.isFinanciallyTerminal) _bankruptcyTerminalCard(),
              // HOME-RUNTIME-READ-1: the HOME read-only display. It
              // receives only the projection — no aggregate, no state, no
              // commands, no callbacks beyond the bound handlers below.
              //
              // SES HOME Final Polish: the former "他の行動を確認する"
              // secondary route is gone — every other action is now reached
              // from "今月の重要タスク" or Bottom Navigation only (see
              // PublicDemoHomeDashboardSection's own doc).
              PublicDemoHomeDashboardSection(
                data: _homeDashboardData,
                recommendedAction: _recommendedActionSlot,
                navigatorAdvice: navigatorAdvice,
                cashAdvice: _cashForecastAdvice,
              ),
              // HOME-COMPACT-1B.3: the monthly progression CTA sits
              // directly under the Navigator card, visible in the initial
              // 390px-wide view with no scroll. Bound exactly once on
              // this screen (see `_monthlyPrimaryAction`'s own site).
              if (_monthlyPrimaryAction case final monthlyAction?) ...[
                // SES HOME One-Screen Final Fit: trimmed from 6 — this and
                // the two gaps below are real inter-section slack, not
                // text/touch-target room, and are the phase's primary
                // lever for closing the remaining 360x800 overflow (see
                // the result report's before/after gap measurements).
                const SizedBox(height: 3),
                PublicDemoMonthlyPrimaryCtaSection(action: monthlyAction),
              ],
              const SizedBox(height: 2),
              // Section 5: employee summary/office card only — the full
              // employee roster/detail lives on the 社員 tab (see
              // [_buildEmployeesTab]), not here. Bottom nav "社員" now
              // switches to that tab instead of scrolling to this same
              // summary.
              HomeOfficeStageSection(display: _officeStageDisplay),
              // SES HOME One-Screen Final Fit: trimmed again, from 6 — see
              // the gap above this block for why.
              //
              // SES HOME Final Visual Match (structural pass): trimmed once
              // more, from 3, to buy back safety margin for the enlarged
              // employee cards this pass adds — real inter-section slack,
              // not a touch target.
              const SizedBox(height: 2),
              // Section 6: "今月の重要タスク" — up to three truthful
              // tasks built only from existing authoritative facts
              // (see _importantTasks's own doc). This is now the sole
              // in-page entry point to the other tabs; Bottom Navigation
              // is the other (§H/§I of the Final Polish brief).
              PublicDemoImportantTasksSection(items: _importantTasks),
            ],
          ),
        ],
      );

  /// 社員 (index 1) — the full employee roster/detail this Issue moves off
  /// HOME: identity, current sales-preparation stage, SkillSheet, the
  /// existing training action, and employee condition. Every card below is
  /// the exact same widget/method/key PUBLIC-DEMO-HOME-UI-3A rendered in
  /// the single shared list — only which tab constructs them changed; no
  /// employee authority or state is duplicated (each renders from exactly
  /// the same [workflow]/[s] read this screen has always held).
  /// SES EMPLOYEE-UI-PHASE-1: the 社員タブ is re-organized into four
  /// information-hierarchy sections (roster/current-state → next actions →
  /// active projects → growth/SkillSheet/training) instead of one flat
  /// stack of cards. Every card, key, month gate, and eligibility check
  /// below is moved verbatim from the prior single-`Column` build — see
  /// each section method's own doc for exactly which prior block it
  /// carries. No domain rule, save field, or command changes; this is a
  /// pure layout/grouping pass plus one new read-only overview
  /// (`_employeeRosterSection`) built from the same authoritative fields
  /// HOME's own KPI already reads.
  Widget _buildEmployeesTab(BuildContext c) => ListView(
    key: const PageStorageKey('public-demo-employees-tab'),
    padding: const EdgeInsets.all(16),
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _employeeRosterSection(),
          _employeeNextActionsSection(),
          _employeeActiveProjectsSection(),
          _employeeGrowthSection(),
        ],
      ),
    ],
  );

  /// Section 1 — 社員一覧 / 現在状態: a lightweight, read-only overview of
  /// every current employee (`workflow.engineers` — founding engineers
  /// plus every joined applicant, the same roster [_officeStageDisplay]'s
  /// own doc already establishes as "the company's employees") and their
  /// truthful current status ([_employeeStatusDisplayFor]), plus the
  /// same 待機/参画中 counts HOME's KPI already shows
  /// ([PublicDemoState.engineersWaiting]/[engineersAssigned]) — no new
  /// aggregate is computed. This did not exist before Phase 1: previously
  /// the only place to see "who works here and what are they doing right
  /// now" was to scan every conditionally-rendered action card below.
  /// Deliberately not a `Card` (unlike the action/status cards below it)
  /// to keep this overview visually light rather than one more large box.
  Widget _employeeRosterSection() {
    final engineers = workflow.engineers;
    if (engineers.isEmpty) return const SizedBox.shrink();
    final visibleEngineers = engineers.where(_matchesEmployeeStatusFilter);
    return Padding(
      key: const Key('public-demo-employee-roster-section'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('社員一覧・現在状態', icon: Icons.groups_outlined),
          _employeeStatusFilterChips(engineers.length),
          const SizedBox(height: 6),
          Text(
            '待機 ${s.engineersWaiting}・参画中 ${s.engineersAssigned}'
            '・合計 ${engineers.length}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          for (final e in visibleEngineers) _employeeRosterCard(e),
        ],
      ),
    );
  }

  /// Whether [e] belongs in the currently selected [_employeeStatusFilter]
  /// bucket — reads the same `_currentlyAssignedEngineerIds` membership the
  /// roster's own 待機/参画中 summary counts already partition every
  /// engineer by.
  bool _matchesEmployeeStatusFilter(PublicDemoEngineerSales e) =>
      switch (_employeeStatusFilter) {
        _EmployeeStatusFilter.all => true,
        _EmployeeStatusFilter.assigned =>
          _currentlyAssignedEngineerIds.contains(e.id),
        _EmployeeStatusFilter.waiting =>
          !_currentlyAssignedEngineerIds.contains(e.id),
      };

  /// The 全員/待機中/参画中 filter chip row (Canonical Visual Reference
  /// `01_Employee_LayoutDraft.png`). Purely a client-side display filter on
  /// [_employeeRosterSection]'s own row list — it does not touch Section
  /// 2/3/4, any command, or any eligibility check below it.
  ///
  /// SES HUMAN-REPLAY PRE-FIX P1: the prior compact pill (12/6 padding
  /// only) measured under 48dp tall — a widget test now pins the real
  /// `InkWell` hit-test box at >=48dp on both axes via the
  /// [BoxConstraints.minHeight]/[BoxConstraints.minWidth] below (the
  /// standard Material "practical tap target" fix); the tap handler, key,
  /// and filter logic are unchanged.
  Widget _employeeStatusFilterChips(int total) {
    final chips = <(_EmployeeStatusFilter, String, int)>[
      (_EmployeeStatusFilter.all, '全員', total),
      (_EmployeeStatusFilter.waiting, '待機中', s.engineersWaiting),
      (_EmployeeStatusFilter.assigned, '参画中', s.engineersAssigned),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      key: const Key('public-demo-employee-status-filter'),
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final (filter, label, count) in chips)
          Material(
            key: Key('public-demo-employee-status-filter-${filter.name}'),
            color: _employeeStatusFilter == filter
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _employeeStatusFilter = filter),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                // `widthFactor`/`heightFactor: 1` keep this shrink-wrapped
                // to the padded text's own size (then clamped up to the
                // 48dp minimum above) — a bare `Center`/`Align` here would
                // instead size to the *biggest* size these loose `Wrap`
                // constraints allow, stretching every chip to the full row
                // width.
                child: Align(
                  alignment: Alignment.center,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '$label $count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _employeeStatusFilter == filter
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// One Reference-style employee card: portrait, name, a real-status badge
  /// ([_employeeStatusDisplayFor] — the text is still the exact label every
  /// existing roster test already asserts), and — when a runtime exists —
  /// a capability progress bar for the employee's confirmed primary skill,
  /// plus a compensation line (経験年数・月給・単金).
  ///
  /// SES ISSUE-235 PHASE B-1: adds the 経験年数/月給/単金 line below the
  /// existing skill bar so the card compares "人材価値・コスト・現在状態" at a
  /// glance, per the Fresh Audit
  /// (`docs/reports/SES_FIRST-FUN-YEAR_Employee-Roster-Management-Data_Fresh-Audit.md`).
  /// Every value here is read verbatim from existing authority — nothing is
  /// computed or invented:
  ///  * 経験年数 — [PublicDemoEngineerRuntime.totalItExperienceMonths] via the
  ///    same [_primarySkillDisplayFor] runtime lookup the skill bar already
  ///    uses, formatted with the app's existing [formatExperience].
  ///  * 月給 — [PublicDemoSalary.currentMonthlySalaryFor], the same accessor
  ///    the payroll total is built from; `null` (should not occur for any
  ///    engineer already in [PublicDemoWorkflowState.engineers], but never
  ///    assumed) renders as '—' rather than a fabricated amount.
  ///  * 単金 (current-assignment unit price) — PR #236 Codex Broad Review P2
  ///    fix: a genuinely currently-assigned engineer's real project unit
  ///    price, resolved by [_currentUnitPriceDisplayFor] from
  ///    [PublicDemoAssignment.projectId] through
  ///    [PublicDemoSeededProjectGenerator.regenerate] — the exact same
  ///    `(runSeed, projectId)` resolution
  ///    [PublicDemoAggregate]'s own `_industryByEngineerId`/`endAssignment`
  ///    already use for this same assignment→project lookup, never a
  ///    second, independently-derived one. A waiting employee, a
  ///    legacy/generic assignment with no `projectId`, or an id that
  ///    (should not happen, but never assumed) fails to resolve all render
  ///    `—` — never [PublicDemoRevenue.ratePerAssignedEngineer]'s flat
  ///    company-wide constant, never a fabricated/derived number.
  Widget _employeeRosterCard(PublicDemoEngineerSales e) {
    final skill = _primarySkillDisplayFor(e.id);
    final experienceMonths = s.runtimeForOrNull(e.id)?.totalItExperienceMonths;
    final monthlySalary = PublicDemoSalary.currentMonthlySalaryFor(
      e.id,
      applicants: workflow.applicants,
      month: s.month,
    );
    final unitPriceDisplay = _currentUnitPriceDisplayFor(e.id);
    final statusDisplay = _employeeStatusDisplayFor(e);
    return Container(
      key: Key('public-demo-employee-roster-row-${e.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PublicDemoEmployeeAvatar(
            assetPath: homeOfficeStagePortraitFor(e.id),
            radius: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PublicDemoEmployeeStatusBadge(
                      label: statusDisplay.label,
                      tone: statusDisplay.tone,
                    ),
                  ],
                ),
                if (skill != null) ...[
                  const SizedBox(height: 4),
                  PublicDemoEmployeeSkillBar(
                    languageLabel: skill.languageLabel,
                    capability: skill.capability,
                    beforeCapability: skill.beforeCapability,
                  ),
                ],
                // Issue #231 FIRST-FUN-YEAR P1 Fresh Audit: states the same
                // reason [ec]'s own field-sales lock banner already gives
                // (`実力 $threshold 以上が必要です（現在 $capability）`) right in
                // the roster row, so "why does this employee need training"
                // is visible without scrolling to Section 2 — reads only
                // the same existing authority
                // (`PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement`
                // / [capabilityFor]), never a new or duplicated threshold.
                if (e.stage == PublicDemoSalesStage.waiting &&
                    !readyForFieldSales(e.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '営業には実力'
                      '${PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement}'
                      '以上が必要（現在${capabilityFor(e.id)}）',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (experienceMonths != null)
                      '経験 ${formatExperience(experienceMonths)}',
                    '月給 ${monthlySalary == null ? '—' : '${monthlySalary ~/ 10000}万円'}',
                    '単金 ${unitPriceDisplay ?? '—'}',
                    if (_orderedProjectRosterSegment(e, unitPriceDisplay)
                        case final segment?)
                      segment,
                  ].join(' ｜ '),
                  key: Key('public-demo-employee-roster-compensation-${e.id}'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // CORE-GAMEPLAY Phase 4.5: every roster row gets this regardless
          // of [e.stage] — unlike the `waiting`-stage-gated
          // "スキルシートを確認" button elsewhere on this tab (`ec(i)`), this
          // never commits [_startSkillSheetReview] and is always present, so
          // an already-selling/assigned employee's SkillSheet stays
          // reachable for the whole game, not only during the one-time
          // pre-selling review step.
          IconButton(
            key: Key('public-demo-employee-roster-skill-sheet-${e.id}'),
            tooltip: 'スキルシートを見る',
            icon: const Icon(Icons.description_outlined, size: 20),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => unawaited(_viewEmployeeSkillSheet(e)),
          ),
        ],
      ),
    );
  }

  /// PR #236 Codex Broad Review P2 fix: the real per-project 単金 for
  /// [engineerId]'s *current* assignment, or `null` (rendered as `—`,
  /// never a guessed number) when none can be safely resolved.
  ///
  /// Deliberately gated on [_currentlyAssignedEngineerIds] first — not on
  /// [_assignmentForOrNull] alone — because
  /// [PublicDemoWorkflowState.endAssignment]'s own doc records that an
  /// ended assignment row is sometimes deliberately LEFT IN PLACE rather
  /// than removed (never revenue-affecting, but still visible to a plain
  /// `workflow.assignments` scan); without this gate, a no-longer-assigned
  /// engineer could show a stale project's rate as if they were still
  /// earning it. Once genuinely currently assigned, resolves
  /// [PublicDemoAssignment.projectId] through
  /// [PublicDemoSeededProjectGenerator.regenerate] — the exact same
  /// `(runSeed, projectId)` derivation
  /// [PublicDemoAggregate._industryByEngineerId] and `.endAssignment`'s own
  /// [CareerHistoryEntry] already use for this identical lookup, so this
  /// never becomes a second, independently-derived resolution that could
  /// drift from theirs. `projectId == null` (the legacy/generic,
  /// project-agnostic assignment path) and a `regenerate` miss (should not
  /// happen for a real projectId, but never assumed) both fall through to
  /// `null` — never [PublicDemoRevenue.ratePerAssignedEngineer]'s flat
  /// company-wide constant, and never a recomputed/derived substitute.
  String? _currentUnitPriceDisplayFor(String engineerId) {
    if (!_currentlyAssignedEngineerIds.contains(engineerId)) return null;
    final projectId = _assignmentForOrNull(engineerId)?.projectId;
    if (projectId == null) return null;
    final candidate = PublicDemoSeededProjectGenerator.regenerate(
      runSeed: s.runSeed,
      projectId: projectId,
    );
    if (candidate == null) return null;
    return '${candidate.monthlyRate ~/ 10000}万円';
  }

  /// SES FIRST-FUN-YEAR P1 (Project/Order/Assignment Continuous Visibility):
  /// the resolved real-project context for [engineer] right now, via
  /// [PublicDemoProjectContextResolver] — the single place every card on
  /// this screen (Sales-pipeline card, roster row, active-project card)
  /// reads which real project an engineer is proposed for / interviewing
  /// for / has ordered / is participating in, so none of them can disagree.
  /// `null` for `waiting`/`skillSheet`/`selling` (nothing has been
  /// introduced yet), for `partnerInterviewFailed`/`clientInterviewFailed`
  /// (PR #240 Codex Broad Review P1 fix: that interview already concluded —
  /// see [PublicDemoProjectContextResolver.projectIdFor]'s own doc), and for
  /// any stage where none of the resolver's three project-id sources
  /// resolves — never a fabricated project reference.
  PublicDemoProjectContext? _projectContextFor(
    PublicDemoEngineerSales engineer,
  ) {
    final assignment = _assignmentForOrNull(engineer.id);
    return PublicDemoProjectContextResolver.resolve(
      stage: engineer.stage,
      isCurrentlyAssigned: _currentlyAssignedEngineerIds.contains(engineer.id),
      assignmentProjectId: assignment == null
          ? null
          : _authoritativeProjectIdFor(assignment),
      genuineInterviewProjectId: engineer.genuineInterviewProjectId,
      matchingProposalProjectId: workflow
          .matchingProposalFor(engineer.id)
          ?.projectId,
      resolveCandidate: (projectId) =>
          PublicDemoSeededProjectGenerator.regenerate(
            runSeed: s.runSeed,
            projectId: projectId,
          ),
    );
  }

  /// The roster row's own minimal "案件名" addition for an `ordered`
  /// engineer (Issue #239: 参画予定/参画中 truthful project context) — `null`
  /// for every other stage, so the roster row is unchanged for anyone still
  /// mid-pipeline (that detail already lives on the Sales-pipeline card via
  /// [_projectContextFor] directly). Shows only the title when
  /// [unitPriceDisplay] already carries this same project's real rate
  /// (参画中) — repeating the same number twice on one line would not add
  /// information — and adds the rate itself only when [unitPriceDisplay] is
  /// `null` (参画予定, not yet earning — see [_currentUnitPriceDisplayFor]'s
  /// own doc for why that field deliberately stays a dash until
  /// participation actually starts), since that is the one `ordered` case
  /// with no rate shown anywhere else on this row.
  String? _orderedProjectRosterSegment(
    PublicDemoEngineerSales engineer,
    String? unitPriceDisplay,
  ) {
    if (engineer.stage != PublicDemoSalesStage.ordered) return null;
    final context = _projectContextFor(engineer);
    if (context == null) return null;
    return unitPriceDisplay == null
        ? '案件 ${context.title}（月額${context.monthlyRate ~/ 10000}万円）'
        : '案件 ${context.title}';
  }

  /// PR #240 Codex Broad Review P2 fix: [PublicDemoAssignment.projectId] is
  /// identity fixed at creation (see that field's own doc) — it never
  /// changes, even after the July+ replacement mini-cycle
  /// (`replacementStage`) secures a nominally different client for the SAME
  /// assignment slot, because that mini-cycle has no real Phase 4/5/6
  /// [Project] identity of its own to mint (see the Fresh Audit/Result
  /// Report's own "July+ replacement mini-cycle" Known Limitation — this
  /// mini-cycle is a separate, generic state machine, not a Matching/
  /// Interview-backed one). Once [PublicDemoAssignment.replacementStage] is
  /// [PublicDemoReplacementStage.ordered] — the exact point `7月：新案件参画予定`
  /// already declares a new project for next month — [assignment.projectId]
  /// therefore identifies only the ENDING project, never the new one, and is
  /// no longer a truthful "current project" fact: resolving it as if it
  /// were would show the old project's real title directly beside/above
  /// text that already says a different, new project was won. This returns
  /// `null` in exactly that one case so every caller's own generic fallback
  /// renders instead — never fabricating a name for a project with no real
  /// identity to resolve. Every other `replacementStage` (including `none`,
  /// the normal — non-replacement — case, and every earlier in-progress
  /// replacement search stage, where the engineer is still genuinely
  /// working the ORIGINAL project while searching) is unaffected: the
  /// assignment's own identity is still genuinely authoritative there.
  String? _authoritativeProjectIdFor(PublicDemoAssignment assignment) =>
      assignment.replacementStage == PublicDemoReplacementStage.ordered
      ? null
      : assignment.projectId;

  /// The real [Project.title] for [assignment] when it carries a genuine
  /// Phase 6 project-bound, still-authoritative `projectId`
  /// ([_authoritativeProjectIdFor]), else its own already-persisted
  /// [PublicDemoAssignment.projectName] (the generic placeholder, e.g.
  /// '新規開発支援') — the exact same `project?.title ?? assignment
  /// .projectName` convention [PublicDemoAggregate._careerHistoryEntryFor]
  /// already established for the identical lookup, reused here rather than
  /// a second, independently-derived resolution. Never a guessed/invented
  /// name: a `projectId` that fails to resolve (should not happen, but
  /// never assumed) also falls back to [assignment]'s own generic name.
  String _realProjectNameFor(PublicDemoAssignment assignment) {
    final projectId = _authoritativeProjectIdFor(assignment);
    if (projectId == null) return assignment.projectName;
    final candidate = PublicDemoSeededProjectGenerator.regenerate(
      runSeed: s.runSeed,
      projectId: projectId,
    );
    return candidate?.title ?? assignment.projectName;
  }

  /// The confirmed primary-skill display for [engineerId], or `null` when
  /// there is no runtime to read (should not happen post-join, but never
  /// assumed). [beforeCapability] is populated only when
  /// [PublicDemoState.latestGrowthResults] genuinely carries a growth event
  /// for this engineer this month — never a fabricated "no change" delta.
  ({String languageLabel, int capability, int? beforeCapability})?
  _primarySkillDisplayFor(String engineerId) {
    final runtime = s.runtimeForOrNull(engineerId);
    if (runtime == null) return null;
    final languageLabel =
        languageLabels[runtime.primaryLanguage] ?? runtime.primaryLanguage.name;
    PublicDemoMonthlyGrowth? growth;
    for (final result in s.latestGrowthResults) {
      if (result.engineerId == engineerId) {
        growth = result;
        break;
      }
    }
    return (
      languageLabel: languageLabel,
      capability: growth?.capabilityAfter ?? runtime.actualCapability,
      beforeCapability: growth?.capabilityBefore,
    );
  }

  /// Section 2 — 今やるべき社員アクション: every card that carries (or may
  /// carry, depending on state) a next action for the player — `ec(i)`'s
  /// three prior render sites (April, June's still-selling joined
  /// applicants, and RECOVERY-LOOP-1's July-February window),
  /// `employeeConditionCard` (June onward, the raise flow), and
  /// `founderFollowUpCard` (Issue #167's August-February window) — moved
  /// verbatim, in the same order, under the same predicates as the prior
  /// single `Column`. The header itself is suppressed when no card is
  /// eligible this month, matching the existing "no empty heading"
  /// precedent (POST-HOME-FREEZE Small-UX-Fix).
  Widget _employeeNextActionsSection() {
    final cards = <Widget>[
      if (s.month == 4)
        for (var i = 0; i < workflow.engineers.length; i++) ec(i),
      if (s.month == 6)
        for (final a in workflow.applicants.where(
          (a) => s.joinedApplicantIds.contains(a.id) && a.hasJoined,
        ))
          employeeConditionCard(a),
      // Issue #243 FIRST-FUN-YEAR P1 (Fresh Audit Finding 1): a founding
      // engineer who does not reach `ordered` inside April previously had
      // no `ec(i)` render site at all in May, and June only rendered it
      // for a later-joined hire (`s.joinedApplicantIds`) — leaving every
      // founding engineer stuck mid-pipeline with zero interactive control
      // for two full months, resurfacing only once RECOVERY-LOOP-1's July
      // window opened. Widened from "June, joined-applicant only" to "May
      // and June, any engineer not yet ordered and not currently assigned"
      // — the same filter shape the July-February loop below already uses
      // — covering both populations (founding and joined-applicant) under
      // one condition instead of two near-duplicate loops.
      // `showTrainingCard: false` for the same reason RECOVERY-LOOP-1's own
      // loop below already sets it: `_employeeGrowthSection`'s `s.month >=
      // 5` block already renders this same engineer runtime's training
      // card unconditionally, and May/June are both `>= 5` — embedding a
      // second one here would duplicate that card's own key.
      if (s.month == 5 || s.month == 6)
        for (var i = 0; i < workflow.engineers.length; i++)
          if (workflow.engineers[i].stage != PublicDemoSalesStage.ordered &&
              !workflow.assignments.any(
                (assignment) =>
                    assignment.engineerId == workflow.engineers[i].id,
              ))
            ec(i, showTrainingCard: false),
      // RECOVERY-LOOP-1: from July (7) through February (14) — the same
      // window `PublicDemoRecoveryEligibility` enforces — every
      // economically-waiting engineer's card is rendered here, mirroring
      // month 6's own filter (`!assignedEngineerIds.contains(...)`) so the
      // existing sales-flow buttons (`ec(i)`'s own `waiting` → `ordered`
      // branches, plus the Recovery button once `ordered`) are reachable
      // at all past June. `showTrainingCard: false` because
      // `_employeeGrowthSection`'s `s.month >= 5` block already renders
      // every engineer runtime's training card unconditionally —
      // rendering it a second time here would duplicate that same card's
      // key.
      if (s.month >= 7 && s.month <= 14)
        for (var i = 0; i < workflow.engineers.length; i++)
          if (!workflow
              .assignedEngineerIds(month: s.month)
              .contains(workflow.engineers[i].id))
            ec(i, showTrainingCard: false),
      if (s.month >= 7)
        for (final a in workflow.applicants.where(
          (a) => s.joinedApplicantIds.contains(a.id) && a.hasJoined,
        ))
          employeeConditionCard(a),
      // Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1: the only card a
      // currently-assigned founding engineer gets during August-February —
      // the RECOVERY-LOOP-1 loop above only renders `ec(i)` for
      // economically-waiting engineers in this window, so a still-assigned
      // founding engineer would otherwise have no card at all here (HOME's
      // recommended-action slot binds this exact same `founderFollowUp(e)`
      // handler; see `_addFounderFollowUpCandidate` — no candidate is ever
      // emitted for a button that is not also rendered here).
      if (s.month >= publicDemoFounderFollowUpWindowStart &&
          s.month <= publicDemoFounderFollowUpWindowEnd)
        for (final e in workflow.engineers)
          if (PublicDemoFounderFollowUp.isEligible(
            engineer: e,
            month: s.month,
            assignedEngineerIds: workflow.assignedEngineerIds(month: s.month),
          ))
            founderFollowUpCard(e),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('今やるべき社員アクション', icon: Icons.checklist_outlined),
          ...cards,
        ],
      ),
    );
  }

  /// Section 3 — 参画中案件: SES ACTIVE-PROJECT-VISIBILITY Phase 1's own
  /// render loop, moved verbatim (same filter, same card, same key) — read-
  /// only project status for every currently-assigned engineer
  /// (`assignedEngineerIds` already differs by month; see that getter's
  /// own doc for why). Unconditional on month so an engineer who is still
  /// assigned in August-March keeps a card here even in the window where
  /// Section 2's RECOVERY-LOOP-1 loop stops rendering `ec(i)` for them.
  Widget _employeeActiveProjectsSection() {
    final cards = <Widget>[
      for (final a in workflow.assignments)
        if (workflow.assignedEngineerIds(month: s.month).contains(a.engineerId))
          activeProjectStatusCard(a),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('参画中案件', icon: Icons.work_outline),
          ...cards,
        ],
      ),
    );
  }

  /// Section 4 — 成長・SkillSheet・研修: `_growthResultsSection` (今月の成長,
  /// its own internal sub-heading unchanged) and the internal-training
  /// loop, moved verbatim. Issue #168 Finding B: May used to be the one gap
  /// in the training loop — April's `ec(i)` embeds its own training card
  /// (`showTrainingCard` defaults true) and this unconditional block
  /// covered June onward, but nothing rendered a training card in May at
  /// all. That silently cost every founding engineer one month of
  /// `PublicDemoGrowthEngine`'s `internalTraining` growth on the way to
  /// `fieldSalesCapabilityRequirement`, with no rule change needed to fix
  /// it — `PublicDemoInternalTrainingTransaction` was never month-gated to
  /// begin with (see its own doc). Starting the unconditional block in May
  /// instead of June closes that gap. SkillSheet has no standalone card in
  /// this tab — its existing entry point (SkillSheet確認 inside `ec(i)`) is
  /// already reachable from Section 2, unchanged.
  ///
  /// `hasVisibleTrainingCard` mirrors `internalTrainingCard`'s own
  /// `assigned` guard so the header is suppressed on a month where every
  /// runtime would render as `SizedBox.shrink()` (currently assigned) —
  /// matching the existing "no empty heading" precedent (POST-HOME-FREEZE
  /// Small-UX-Fix) rather than introducing a new rule about who gets a
  /// training card.
  Widget _employeeGrowthSection() {
    final hasGrowth = s.latestGrowthResults.isNotEmpty;
    final hasVisibleTrainingCard =
        s.month >= 5 &&
        s.engineerRuntimes.any(
          (r) => !_currentlyAssignedEngineerIds.contains(r.engineerId),
        );
    if (!hasGrowth && !hasVisibleTrainingCard) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('成長・スキルシート・研修', icon: Icons.trending_up),
          if (hasGrowth) _growthResultsSection(),
          if (s.month >= 5)
            for (final runtime in s.engineerRuntimes)
              internalTrainingCard(
                engineerId: runtime.engineerId,
                engineerName: _engineerName(runtime.engineerId),
              ),
        ],
      ),
    );
  }

  /// [icon] is purely decorative and optional — every existing call site
  /// (Sales/Accounting/Year-End) omits it and renders exactly as before;
  /// only the 社員タブ's own 4 section headers pass one, matching the
  /// Canonical Visual Reference's iconography.
  Widget _sectionHeader(String title, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    ),
  );

  /// 営業 (index 2) — the existing sales/project/recruiting pipeline: the
  /// recruitment-media flow and applicant funnel, and the assignment
  /// (project continuation/replacement) pipeline with its July results
  /// narrative. Reuses every existing widget/method/key verbatim — no new
  /// project/sales authority is invented here.
  ///
  /// SES SALES-UI-PHASE-1: the flat "one card list, else empty state" body
  /// is re-organized into the same information-hierarchy pattern Employee UI
  /// Phase 1 established for 社員 — four sections read top-to-bottom: 1)
  /// 現在の営業・採用状況 ([_salesOverviewSection], new — a read-only snapshot
  /// built only from fields this screen already reads elsewhere:
  /// [PublicDemoState.salesRemaining]/`salesCapacity`, the in-pipeline
  /// applicant count (`workflow.applicants` not yet [PublicDemoApplicant.
  /// hasJoined]), and the assignment/case count with how many still await a
  /// decision this month), 2) 今やるべき営業アクション
  /// ([_salesNextActionCards] — the recruitment-media card, May's own
  /// company-level lever to start the funnel), 3) 採用・候補者進捗
  /// ([_salesApplicantProgressCards] — the applicant funnel, `ac(i)`), and
  /// 4) 案件・参画/継続状況 ([_salesProjectStatusCards] — June's assignment
  /// decision cards and July's closing narrative). Every card, key, and
  /// eligibility check below is moved verbatim from the prior single flat
  /// list — only which section groups it changed (and, per the CORE-
  /// GAMEPLAY Phase 4.5 merge-blocker fix, the recruitment-media/applicant-
  /// funnel gates themselves — see their own doc comments). No domain rule,
  /// save field, or command changes.
  ///
  /// PUBLIC-DEMO-HOME-UI-3C: before any recruitment media exists (April —
  /// see `_recruitmentMediaCardVisible`'s own doc for why April stays
  /// excluded even though the domain's recruiting window starts there) and
  /// once there is neither an unused recruiting window nor anything left in
  /// the funnel/assignment cards above to show (any further per-employee
  /// sales progress renders on 社員, not here), this tab used to render a
  /// fully blank body with no explanation.
  /// [_salesTabEmptyState] replaces that with a truthful, non-interactive
  /// (beyond real navigation) empty state — unchanged by Phase 1 — built
  /// only when all three section card lists below are genuinely empty
  /// (the same condition the prior flat [_salesTabItems] used), never a
  /// fabricated sales/recruiting action. [_salesOverviewSection] still
  /// renders above it even on a no-action month, since it is itself never
  /// empty — see the goal's "4月〜3月を通して意味のある画面構造にする".
  Widget _buildSalesTab(BuildContext c) {
    final actionCards = _salesNextActionCards();
    final applicantCards = _salesApplicantProgressCards();
    final projectCards = _salesProjectStatusCards(c);
    final hasAnyContent =
        actionCards.isNotEmpty ||
        applicantCards.isNotEmpty ||
        projectCards.isNotEmpty;
    return ListView(
      key: const PageStorageKey('public-demo-sales-tab'),
      padding: const EdgeInsets.all(16),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _salesOverviewSection(),
            if (!hasAnyContent) _salesTabEmptyState(),
            if (actionCards.isNotEmpty)
              _salesSection(
                key: 'public-demo-sales-next-actions-section',
                title: '今やるべき営業アクション',
                icon: Icons.campaign_outlined,
                cards: actionCards,
              ),
            if (applicantCards.isNotEmpty)
              _salesSection(
                key: 'public-demo-sales-applicant-progress-section',
                title: '採用・候補者進捗',
                icon: Icons.groups_outlined,
                cards: applicantCards,
              ),
            if (projectCards.isNotEmpty)
              _salesSection(
                key: 'public-demo-sales-project-status-section',
                title: '案件・参画/継続状況',
                icon: Icons.handshake_outlined,
                cards: projectCards,
              ),
            _salesSection(
              key: 'public-demo-sales-matching-section',
              title: '案件マッチング',
              icon: Icons.travel_explore_outlined,
              cards: [_matchingEntryCard()],
            ),
          ],
        ),
      ],
    );
  }

  /// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): always-available
  /// entry point into [_openProjectMatching] — unlike the sections above,
  /// deliberately not month-gated, since Phase 4's seeded project pool
  /// ([PublicDemoAggregate.projectCandidatesForMonth]) exists for every
  /// month from April onward.
  Widget _matchingEntryCard() => PublicDemoSalesCard(
    key: const Key('public-demo-open-project-matching-card'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '実在する案件を見て、社員のFitを確認できます。',
          style: TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          key: const Key('public-demo-open-project-matching'),
          onPressed: _openProjectMatching,
          child: const Text('案件を見る'),
        ),
      ],
    ),
  );

  /// Section 1 — 現在の営業・採用状況: a lightweight, always-rendered,
  /// read-only snapshot — mirrors [_employeeRosterSection]'s role on 社員.
  /// [PublicDemoState.salesRemaining]/`salesCapacity` are the same fields
  /// HOME's own recommended-action fact ("営業残: N回") already reads; the
  /// in-pipeline applicant count filters out anyone with
  /// [PublicDemoApplicant.hasJoined] true so a candidate who joined months
  /// ago is never miscounted as still "applying"; the assignment/case count
  /// and its "うち検討中" qualifier read only [PublicDemoAssignment.
  /// nextOrderStatus] — no new aggregate field is computed or persisted.
  /// Deliberately omits the 待機/参画中 employee headcount HOME's KPI and
  /// [_employeeRosterSection] already show verbatim, to avoid the exact
  /// "不要なカード重複" the phase's own scope calls out to reduce.
  ///
  /// The candidate count reads `workflow.applicants` directly — the same
  /// authoritative list [_salesApplicantProgressCards]'s own funnel counts
  /// — rather than a month gate. CORE-GAMEPLAY Phase 4.5:
  /// [PublicDemoWorkflowState.initial] no longer pre-seeds any applicant, so
  /// this is genuinely 0 before the player's first
  /// [PublicDemoAggregate.recruit] call; the merge-blocker follow-up that
  /// widened recruiting to the domain's real months 4-8 window (see
  /// [_salesNextActionCards]) means that first call is no longer
  /// necessarily in May, so a month-based gate here would under-count.
  Widget _salesOverviewSection() {
    final pipelineApplicantCount = workflow.applicants
        .where((a) => !a.hasJoined)
        .length;
    final pendingAssignmentCount = workflow.assignments
        .where(
          (a) =>
              a.nextOrderStatus == PublicDemoNextOrderStatus.undecided ||
              a.nextOrderStatus == PublicDemoNextOrderStatus.offered,
        )
        .length;
    // SES SALES Visual Complete: the same 3 facts as before (営業残/上限,
    // 候補者, 案件+検討中) — now rendered as a row of compact stat tiles
    // (`PublicDemoSalesStatTile`) instead of two lines of plain text, so
    // "the current state you can recognize at a glance" (Reference's
    // "ひと目でわかる、次の一手" design principle) reads as an actual
    // information-dense header row instead of prose, per the Visual SSOT's
    // "current state → next action → detail" hierarchy. Every tile's
    // `primaryText`/`secondaryText` keeps the exact wording (down to the
    // full-width unit characters) the prior two `Text` lines rendered, so
    // `public_demo_sales_ui_phase1_test.dart`'s existing
    // `find.textContaining('営業残 N回')`/`'候補者 N名'`/`'案件 N件'`/
    // `'うち検討中 N件'` assertions keep matching byte-for-byte — only the
    // layout (icon + tile shape) changed, not one character of the text
    // itself.
    return Padding(
      key: const Key('public-demo-sales-overview-section'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('現在の営業・採用状況', icon: Icons.insights_outlined),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PublicDemoSalesStatTile(
                  icon: Icons.event_available_outlined,
                  primaryText: '営業残 ${s.salesRemaining}回',
                  secondaryText: '上限${s.salesCapacity}回',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PublicDemoSalesStatTile(
                  icon: Icons.person_search_outlined,
                  primaryText: '候補者 $pipelineApplicantCount名',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PublicDemoSalesStatTile(
                  icon: Icons.business_center_outlined,
                  primaryText: '案件 ${workflow.assignments.length}件',
                  secondaryText: pendingAssignmentCount > 0
                      ? 'うち検討中 $pendingAssignmentCount件'
                      : null,
                  emphasize: pendingAssignmentCount > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section 2 — 今やるべき営業アクション: the recruitment-media card (same
  /// widget, same key, same [_openRecruitmentMedia] handler as the prior
  /// flat [_salesTabItems]). CORE-GAMEPLAY Phase 4.5 (merge-blocker fix):
  /// this used to be fixed to `s.month == 5`, which dead-ended recruiting
  /// for the rest of the run the moment May's single seeded candidate
  /// turned out unhireable (no fallback, no retry) — even though the
  /// domain's own recruiting window, [PublicDemoState
  /// .isRecruitmentMediaWindowMonth], already spans months 4-8. The gate
  /// now reads [_recruitmentMediaCardVisible] (see its own doc for exactly
  /// how that relates to, and deliberately narrows, the domain's window;
  /// notably it does NOT reuse [PublicDemoState.canUseRecruitmentMediaInMonth]
  /// directly: that predicate also folds in this month's own usage, and
  /// gating *visibility* on it made the whole card — including its
  /// always-informational 現預金 line — disappear the instant the player
  /// recruited, instead of staying visible with its button disabled
  /// ["今月は利用済み"] the way the old `month == 5` gate displayed it for
  /// the rest of May regardless of use; caught by the merge-blocker
  /// follow-up's own review pass), so the card is available May-August
  /// (never April — see [_recruitmentMediaCardVisible]), with no new
  /// recruiting authority, cost, or generator behavior invented here.
  List<Widget> _salesNextActionCards() => [
    if (_recruitmentMediaCardVisible)
      _RecruitmentMediaCard(state: s, onPressed: _openRecruitmentMedia),
  ];

  /// Section 3 — 採用・候補者進捗: the applicant funnel (same `ac(i)`
  /// widget/key/eligibility as the prior flat [_salesTabItems]).
  /// CORE-GAMEPLAY Phase 4.5 (merge-blocker fix): previously fixed to
  /// `s.month == 5`, so a candidate recruited in any later month (now
  /// reachable via [_salesNextActionCards]'s widened gate above) would
  /// never have a funnel to act through. Gated on the same authoritative
  /// fact the funnel itself is about — whether there is an applicant to
  /// show — rather than on which month it is.
  ///
  /// Issue #241 FIRST-FUN-YEAR Recruitment Flow / Next Action Clarity
  /// (Fresh Audit finding): [PublicDemoApplicant.stage] never advances (or
  /// resets) once an applicant actually joins — [PublicDemoApplicant.join]
  /// only mints a [PublicDemoApplicant.hasJoined]-backing record, exactly
  /// as [PublicDemoMonthlyReportSnapshot.confirmedNextMonthJoinApplicantIds]'s
  /// own doc already explains for the identical `stage == juneOrdered`
  /// case (Issue #232/#234). Without this filter, a joined applicant kept
  /// rendering here forever with a stale pre-join badge (e.g. "入社・参画予定"
  /// or "内定承諾") even after they were already an active employee on the
  /// 社員 tab — misleading the player into thinking a real hire was still
  /// only "入社待ち" (mixing up 入社待ち/入社済み, which Issue #241 explicitly
  /// requires stay distinct). [_salesOverviewSection]'s own `候補者` count
  /// already excludes [PublicDemoApplicant.hasJoined] applicants for the
  /// same reason (see its own doc); this reuses the exact same predicate
  /// so the funnel list and its own headline count never disagree. No new
  /// authority: once joined, the applicant's story continues via the
  /// existing `workflow.engineers`-based 社員/SkillSheet/営業 tabs, exactly
  /// as [_salesOverviewSection] already documents.
  List<Widget> _salesApplicantProgressCards() => [
    for (var i = 0; i < workflow.applicants.length; i++)
      if (!workflow.applicants[i].hasJoined) ac(i),
  ];

  /// Section 4 — 案件・参画/継続状況: June's assignment decision cards and
  /// July's closing narrative, moved verbatim (same `assignmentCard(i)`/
  /// [julyResult] widgets/keys/eligibility, same `s.month == 6`/`== 7`
  /// gates) from the prior flat [_salesTabItems].
  List<Widget> _salesProjectStatusCards(BuildContext c) => [
    if (s.month == 6)
      for (var i = 0; i < workflow.assignments.length; i++) assignmentCard(i),
    if (s.month == 7) ...[
      Text('7月開始結果', style: Theme.of(c).textTheme.titleLarge),
      const SizedBox(height: 4),
      // SES-FIRST-FUN-YEAR-UI-PHASE-1: the 参画/待機 headcount line
      // that used to render here is removed — it duplicated the
      // always-visible compact KPI's 参画/待機 tiles verbatim.
      // SES SALES Visual Complete: the plain ListTile row is now the same
      // card shape/avatar every other 営業タブ pipeline row uses, with
      // [julyResult]'s own verbatim outcome string colored by
      // [_julyResultTone] — no new fact beyond the two already shown.
      for (final a in workflow.assignments)
        PublicDemoSalesCard(
          child: Row(
            children: [
              PublicDemoSalesAvatar(
                assetPath: homeOfficeStagePortraitFor(a.engineerId),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.engineerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: PublicDemoSalesStatusBadge(
                  label: julyResult(a),
                  tone: _julyResultTone(a),
                ),
              ),
            ],
          ),
        ),
    ],
  ];

  /// Shared section wrapper for Sections 2-4 above — same suppressed-header-
  /// when-empty precedent [_employeeNextActionsSection] etc. already
  /// established (POST-HOME-FREEZE Small-UX-Fix); callers only invoke this
  /// once their own card list is already known non-empty.
  Widget _salesSection({
    required String key,
    required String title,
    required List<Widget> cards,
    IconData? icon,
  }) => Padding(
    key: Key(key),
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, icon: icon),
        ...cards,
      ],
    ),
  );

  /// PUBLIC-DEMO-HOME-UI-3C: the truthful non-action empty state for 営業
  /// when [_buildSalesTab]'s three section card lists built nothing —
  /// structurally correct (there is genuinely no recruiting/assignment card
  /// to show yet, or any longer),
  /// but previously a large unexplained blank body, most visibly on a
  /// fresh April playthrough (Issue #173). States only two already-true
  /// facts (no eligible request card exists yet/any more here; a real
  /// employee-facing action, when one exists, is on 社員) and offers a
  /// real navigation shortcut to that tab — never a new sales/recruiting
  /// action, deadline, or count.
  ///
  /// PR #174 Codex review (P2): the "starts after SkillSheet確認" copy used
  /// to key off `s.month < 5` alone, so it kept claiming SkillSheet確認 was
  /// the still-outstanding blocker even after the player had already
  /// completed it for every engineer (April, but the real next step —
  /// 営業開始 — is already sitting on 社員). This now reads the same
  /// authoritative [workflow] stage `ec(i)`/[engineerStatus] already read
  /// elsewhere on this screen: [PublicDemoSalesStage.waiting] is the one
  /// stage SkillSheet確認 has not yet cleared, so only *that* fact decides
  /// which copy renders — never the month alone, and never a new gameplay
  /// signal invented for this card.
  Widget _salesTabEmptyState() {
    final anyEngineerAwaitingSkillSheet = workflow.engineers.any(
      (engineer) => engineer.stage == PublicDemoSalesStage.waiting,
    );
    return Card(
      key: const Key('public-demo-sales-empty-state'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                // PR #174 Codex review (P2): a non-flexible Text here
                // overflowed horizontally at 360px width once TextScaler
                // 1.3/2.0 grew this heading past one line's intrinsic
                // width. Expanded gives it the Row's remaining width to
                // wrap into instead — no font-size reduction, and the
                // heading still reads as one bold line at the default
                // scale (see the new regression test's own scaled-size
                // coverage).
                const Expanded(
                  child: Text(
                    '営業・採用のアクションは現在ありません',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              anyEngineerAwaitingSkillSheet
                  ? '案件情報の収集や採用の募集は、社員のスキルシート確認が完了してから始まります。'
                  : '案件の募集・採用の対応は現在ありません。社員ごとの営業状況は「社員」タブで確認できます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                key: const Key('public-demo-sales-empty-state-cta'),
                onPressed: () => _switchTab(_employeesTabIndex),
                child: const Text('社員の状況を見る'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 会計 (index 3) — finance detail this Issue moves off HOME: the latest
  /// monthly cash-flow card, the payroll/fixed-cost summary, the summer
  /// bonus decision, and the monthly/fiscal-year-close narrative. No
  /// finance figure is recomputed here — every value is read from the same
  /// authoritative [s]/[_financeSummary] this screen has always held.
  ///
  /// SES ACCOUNTING-UI-PHASE-1: re-organized into five information-
  /// hierarchy sections, read top-to-bottom the way a player actually needs
  /// them — 1) 現在の資金状態 ([_accountingFundStatusSection], new — a
  /// read-only snapshot of [PublicDemoState.cash]/[financialStatus], both
  /// already-authoritative fields this screen reads elsewhere, e.g.
  /// [PublicDemoCashShortageCard] on HOME), 2) 今月の収支
  /// ([_accountingMonthlyBalanceSection] — [_monthlyCashFlowSection] plus
  /// [PublicDemoFinanceSummarySection], moved verbatim), 3)
  /// 将来の資金予測・リスク ([_accountingForecastSection], new — the existing
  /// [PublicDemoCashForecast]/[PublicDemoCashStatusPresentation] pure models
  /// HOME's own Navigator cash advice, [_cashForecastAdvice], already reuses
  /// for its own guidance, read here directly as a short table instead of
  /// only surfacing indirectly once a shortage has already hit), 4)
  /// 今月必要な経営判断 ([_accountingDecisionSection] — the July summer-bonus
  /// decision card, moved verbatim), 5) 月次結果 / Year-End
  /// ([_accountingMonthlyResultSection] — the August start-result narrative
  /// and [PublicDemoYearEndResultCard], moved verbatim). Every card, key,
  /// month gate, and figure below is moved from the prior single flat
  /// `Column` — no new domain rule, save field, or Finance/Balance/Month
  /// transition/Year-End authority is introduced.
  ///
  /// The one presentation fix this phase makes (Fresh Audit): the finance
  /// summary's title now truthfully distinguishes a pre-close baseline from
  /// a settled actual instead of always claiming a same-month forecast —
  /// see [PublicDemoFinanceSummaryModel.isSettled]'s own doc. No
  /// payroll/fixedCosts figure changes.
  Widget _buildAccountingTab(BuildContext c) => ListView(
    key: const PageStorageKey('public-demo-accounting-tab'),
    padding: const EdgeInsets.all(16),
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _accountingFundStatusSection(),
          _accountingMonthlyBalanceSection(),
          _accountingForecastSection(),
          _accountingDecisionSection(),
          _accountingMonthlyResultSection(c),
        ],
      ),
    ],
  );

  /// Section 1 — 現在の資金状態: the tab's Visual Hero. A lightweight,
  /// always-rendered, read-only snapshot of
  /// [PublicDemoState.cash]/[financialStatus] — the same two authoritative
  /// fields [PublicDemoCashShortageCard] and the bankruptcy terminal card
  /// (both HOME-only) already read, given the large-cash-figure + status
  /// badge treatment the Canonical Visual Reference's own サマリー screen
  /// gives 現在の現金 (SES ACCOUNTING VISUAL COMPLETE). No new fact,
  /// threshold, or aggregate; [_financialStatusLabel]/[_financialStatusTone]
  /// only name/color the four states [PublicDemoFinancialStatus] already
  /// recognizes, and the hero keeps rendering the exact
  /// `'現在の現預金 ${formatYen(s.cash)}'` label the pre-existing regression
  /// suite (`public_demo_accounting_ui_phase1_test.dart`) already matches
  /// with `find.textContaining('現在の現預金')` — split across a caption
  /// `Text` and the large value `Text` rather than one line, but still a
  /// single `Text` carrying that exact substring.
  ///
  /// 前回決算の収支 (SES HUMAN-REPLAY PRE-FIX P1): only shown once a real
  /// monthly close exists ([PublicDemoState.latestMonthlyCashFlow]
  /// non-null) — before the first close (April) there is no prior close to
  /// show, so the line is omitted entirely rather than showing a fabricated
  /// "no change". [PublicDemoMonthlyCashFlow.netCashMovement] is an
  /// existing getter (`closingCash - openingCash`, FINANCE-UX-1) — no new
  /// calculation is introduced here.
  ///
  /// Wording: this value is the *previous settled month's own* net cash
  /// movement (that month's closingCash minus its openingCash) — it is not
  /// a comparison between two different months' totals. The prior label
  /// ("前月比", "vs. previous month") read as a month-over-month comparison
  /// and was misleading; "前回決算の収支" (the previous settlement's net
  /// cash flow) states the same authoritative figure without implying a
  /// comparison that was never computed. This matches the existing
  /// "最終決算月" ([latestMonthlyCashFlow]'s own month label, used
  /// elsewhere on this screen) terminology already established for this
  /// same record.
  ///
  /// 今月の売上 / 今月の支出 tiles (P0 goal 4): the same [flow.revenue] /
  /// [flow.totalOutflow] facts [PublicDemoMonthlyCashFlowCard] (Section 2)
  /// already displays, surfaced again here as an at-a-glance pair — matching
  /// the Reference's サマリー screen, which shows the same two figures
  /// prominently above its own 収支詳細 breakdown. Hidden before the first
  /// close for the same reason the delta line is.
  Widget _accountingFundStatusSection() {
    final flow = s.latestMonthlyCashFlow;
    final tone = _financialStatusTone(s.financialStatus);
    String? deltaText;
    bool? deltaPositive;
    if (flow != null) {
      final delta = flow.netCashMovement;
      deltaPositive = delta >= 0;
      deltaText = '前回決算の収支 ${delta >= 0 ? '+' : '-'}${formatYen(delta.abs())}';
    }
    return Padding(
      key: const Key('public-demo-accounting-fund-status-section'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            '現在の資金状態',
            icon: Icons.account_balance_wallet_outlined,
          ),
          PublicDemoAccountingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PublicDemoAccountingCashHero(
                  label: '現在の現預金',
                  cashText: formatYen(s.cash),
                  deltaText: deltaText,
                  deltaPositive: deltaPositive,
                ),
                const SizedBox(height: 10),
                PublicDemoAccountingStatusBadge(
                  label: _financialStatusLabel(s.financialStatus),
                  tone: tone,
                ),
                if (flow != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: PublicDemoAccountingStatTile(
                          icon: Icons.arrow_upward,
                          iconColor: const Color(0xFF1B7A3B),
                          label: '今月の売上',
                          primaryText: formatYen(flow.revenue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PublicDemoAccountingStatTile(
                          icon: Icons.arrow_downward,
                          iconColor: const Color(0xFFB3261E),
                          label: '今月の支出',
                          primaryText: formatYen(flow.totalOutflow),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _financialStatusLabel(PublicDemoFinancialStatus status) =>
      switch (status) {
        PublicDemoFinancialStatus.normal => '健全',
        PublicDemoFinancialStatus.cashShortage => '資金不足（猶予期間中）',
        PublicDemoFinancialStatus.bankruptcy => '倒産（第1期終了）',
        PublicDemoFinancialStatus.marchCashShortageFailure => '年度末資金不足（第1期終了）',
      };

  PublicDemoAccountingTone _financialStatusTone(
    PublicDemoFinancialStatus status,
  ) => switch (status) {
    PublicDemoFinancialStatus.normal => PublicDemoAccountingTone.positive,
    PublicDemoFinancialStatus.cashShortage => PublicDemoAccountingTone.caution,
    PublicDemoFinancialStatus.bankruptcy => PublicDemoAccountingTone.negative,
    PublicDemoFinancialStatus.marchCashShortageFailure =>
      PublicDemoAccountingTone.negative,
  };

  /// Section 2 — 今月の収支: [_monthlyCashFlowSection] (the latest closed
  /// month's full cash-flow breakdown) and [PublicDemoFinanceSummarySection]
  /// (the payroll/fixed-cost at-a-glance figures), moved verbatim from the
  /// prior flat body — same widgets, same keys, same [_financeSummary]
  /// read. Always non-empty: [PublicDemoFinanceSummarySection] itself never
  /// shrinks to nothing (unlike [_monthlyCashFlowSection], which shows
  /// nothing before the first close), so this section's own header never
  /// needs a "no empty heading" guard.
  Widget _accountingMonthlyBalanceSection() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('今月の収支', icon: Icons.receipt_long_outlined),
        _monthlyCashFlowSection(),
        PublicDemoFinanceSummarySection(summary: _financeSummary),
      ],
    ),
  );

  /// Section 3 — 将来の資金予測・リスク: [PublicDemoCashForecast.forecast], the
  /// exact same pure, confirmed-information-only projection
  /// [_cashForecastAdvice] (HOME's own Navigator cash guidance) already
  /// reads, rendered here directly as a short table so a player can see the
  /// company's near-term cash risk without a shortage having actually hit
  /// yet — [PublicDemoCashShortageCard] (HOME only) still owns the reactive
  /// warning once [PublicDemoState.financialStatus] actually becomes
  /// [PublicDemoFinancialStatus.cashShortage]; this section never restates
  /// that card's own headline/evidence text. [PublicDemoCashStatusPresentation
  /// .fromForecast] supplies the same three-state safe/shortage/unavailable
  /// verdict [_cashForecastAdvice] already derives — no new threshold,
  /// forecast horizon, or recomputation of its own.
  ///
  /// Hidden entirely once the forecast window is empty
  /// ([PublicDemoCashForecastResult.months] — close-blocked: fiscal year
  /// completed or an already-terminal financial status): there is no
  /// further close ahead to project, matching this tab's existing
  /// "no empty heading" precedent (POST-HOME-FREEZE Small-UX-Fix).
  ///
  /// SES ACCOUNTING VISUAL COMPLETE (P1): the plain month-by-month text list
  /// gains a truthful simple bar visualization
  /// ([PublicDemoAccountingForecastBar]) alongside — never instead of — the
  /// exact existing headline/per-month `Text` a pre-existing regression
  /// suite (`public_demo_accounting_ui_phase1_test.dart`) already matches
  /// verbatim with `find.textContaining`. Each bar's fraction is a pure
  /// rendering-scale choice (`closingCash / scaleMax`, [_forecastScaleMax])
  /// derived only from the same [PublicDemoCashForecastMonth.closingCash]
  /// figures already shown as text — it introduces no new financial
  /// calculation or threshold. The headline is also wrapped in
  /// [PublicDemoAccountingAlertCard] (アラート・アドバイス, Reference goal 5) —
  /// same tone semantics as [_financialStatusTone] (caution for a forecasted
  /// shortage, positive when safe) — and 入金予定 ([PublicDemoState
  /// .pendingRevenue], the exact same authoritative field/label HOME's own
  /// compact KPI already shows) is surfaced once as a concise fact tile,
  /// since it directly explains next month's [PublicDemoCashForecastMonth
  /// .cashReceived].
  Widget _accountingForecastSection() {
    final forecast = PublicDemoCashForecast.forecast(
      state: s,
      workflow: workflow,
    );
    if (forecast.months.isEmpty) return const SizedBox.shrink();
    final status = PublicDemoCashStatusPresentation.fromForecast(forecast);
    final isShortage = status.status == PublicDemoCashStatus.shortage;
    final scaleMax = _forecastScaleMax(forecast);
    return Padding(
      key: const Key('public-demo-accounting-forecast-section'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('将来の資金予測・リスク', icon: Icons.query_stats_outlined),
          PublicDemoAccountingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PublicDemoAccountingAlertCard(
                  tone: isShortage
                      ? PublicDemoAccountingTone.caution
                      : PublicDemoAccountingTone.positive,
                  icon: isShortage
                      ? Icons.warning_amber_outlined
                      : Icons.check_circle_outline,
                  child: Text(
                    isShortage
                        ? '${publicDemoMonthLabel(status.shortageMonth!)}に資金がマイナスになる見込みです。'
                        : '今後${forecast.months.length}回の決算見込みでは資金不足はありません。',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                PublicDemoAccountingStatTile(
                  icon: Icons.schedule_outlined,
                  label: '入金予定',
                  primaryText: formatYen(s.pendingRevenue),
                ),
                const SizedBox(height: 10),
                for (final month in forecast.months)
                  Padding(
                    key: Key(
                      'public-demo-accounting-forecast-month-${month.month}',
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${publicDemoMonthLabel(month.month)}末 現預金見込み '
                          '${formatYen(month.closingCash)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: month.isNegative
                                ? Colors.red.shade700
                                : null,
                            fontWeight: month.isNegative
                                ? FontWeight.w600
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        PublicDemoAccountingForecastBar(
                          fraction: month.isNegative
                              ? 0
                              : month.closingCash / scaleMax,
                          isNegative: month.isNegative,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pure rendering-scale helper for [_accountingForecastSection]'s bars: the
  /// largest non-negative cash figure across the current balance and every
  /// projected closing cash, so every bar's fraction stays comparable and
  /// within 0..1. Never less than 1 (avoids a division by zero when every
  /// figure in view happens to be zero or negative) — this is a display
  /// scale only, never a financial threshold.
  int _forecastScaleMax(PublicDemoCashForecastResult forecast) {
    var maxValue = s.cash > 0 ? s.cash : 0;
    for (final month in forecast.months) {
      if (month.closingCash > maxValue) maxValue = month.closingCash;
    }
    return maxValue > 0 ? maxValue : 1;
  }

  /// Section 4 — 今月必要な経営判断: the July summer-bonus decision card,
  /// moved verbatim (same `s.month == 7` gate, same
  /// [_summerBonusDecisionRequired] check, same [decideSummerBonus] handler,
  /// same [Key]) from the prior flat body. Suppressed outside July —
  /// matching this tab's existing "no empty heading" precedent — since no
  /// other month currently has an active finance decision of its own.
  Widget _accountingDecisionSection() {
    if (s.month != 7) return const SizedBox.shrink();
    return Padding(
      key: const Key('public-demo-accounting-decision-section'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('今月必要な経営判断', icon: Icons.fact_check_outlined),
          PublicDemoAccountingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.card_giftcard_outlined,
                      size: 16,
                      color: Color(0xFF8A5A00),
                    ),
                    SizedBox(width: 6),
                    Text('夏季賞与', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
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
                  key: const Key('public-demo-summer-bonus-decision'),
                  onPressed: decideSummerBonus,
                  child: Text(
                    _summerBonusDecisionRequired ? '夏季賞与を決める' : '夏季賞与を変更',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section 5 — 月次結果 / Year-End: the August start-result narrative
  /// (SES POST-HOME-FREEZE Small-UX-Fix; only August in this range has a
  /// body — see that fix's own note, carried verbatim) and, once the fiscal
  /// year completes, [PublicDemoYearEndResultCard] (SES YEAR-END-PHASE-1,
  /// carried verbatim including its own `public-demo-fiscal-year-complete`
  /// key and restart wiring — [_confirmRestartFromApril] ->
  /// [_restartGame], the same canonical restart the dev-menu and bankruptcy
  /// terminal cards already use). Suppressed entirely when neither applies,
  /// matching this tab's existing "no empty heading" precedent — the
  /// pre-existing regression
  /// (public_demo_01_accounting_tab_empty_heading_test.dart) keeps
  /// asserting `findsNothing` on months this section also has nothing to
  /// show for.
  Widget _accountingMonthlyResultSection(BuildContext c) {
    final hasAugustResult = s.month == 8;
    if (!hasAugustResult && !s.fiscalYearCompleted) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('public-demo-accounting-monthly-result-section'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('月次結果 / Year-End', icon: Icons.flag_outlined),
          if (hasAugustResult)
            PublicDemoAccountingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${publicDemoMonthLabel(s.month)}開始結果',
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  const Text('7月分の給与を反映しました'),
                  Text(
                    s.summerBonusPaidAmount == 0
                        ? '夏季賞与 なし'
                        : '夏季賞与 ¥${s.summerBonusPaidAmount}',
                  ),
                ],
              ),
            ),
          if (s.fiscalYearCompleted)
            PublicDemoYearEndResultCard(
              data: PublicDemoYearEndDisplayData.fromPublicDemoState(s),
              isReplaying: _isRestarting,
              onReplay: _confirmRestartFromApril,
            ),
        ],
      ),
    );
  }

  /// メニュー (index 4) — secondary/development/test content that does not
  /// belong on HOME. Reuses [_publicDemoDevMenuSection] verbatim in
  /// behavior (the same collapsed-by-default toggle and test-only restart
  /// control PUBLIC-DEMO-HOME-UI-3A/3B already built).
  ///
  /// QA-MICRO-FIX (post-#173/#174): [BuildInfoLabel] itself sits here,
  /// always visible near the top of this tab, above the collapsed
  /// "開発・テストメニュー" section — so deployed Screen Verification can read
  /// the running deploy SHA/PR without expanding anything destructive. This
  /// is the label's only mount point; it is not duplicated inside the
  /// collapsed card.
  ///
  /// SES MENU VISUAL COMPLETE: adopts the icon-led section-header +
  /// bordered-card visual language every other NON-HOME tab's Visual
  /// Complete already established
  /// (`docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`), using the new
  /// メニュータブ-local widgets in `public_demo_menu_visual.dart`. The build
  /// identity moves into [PublicDemoMenuBuildInfoRow] — a low-emphasis row
  /// that renders nothing (no empty bordered card) when
  /// `BuildInfo.isAvailable` is false, matching this tab's own long-standing
  /// "no empty content" precedent. Only actual production Menu content
  /// (build identity + the existing dev/test menu) is Visual Complete here —
  /// every Reference-only feature absent from production (manual save/load,
  /// difficulty/display/sound settings, tutorial, help/FAQ/contact, About,
  /// Credits, a Menu-local ひよりのアドバイス card) is intentionally not
  /// implemented; see
  /// `docs/reports/SES_NON-HOME-UI_MENU_Visual-Complete_Result.md`.
  Widget _buildMenuTab(BuildContext c) {
    final buildInfo = widget.buildInfo ?? BuildInfo.fromEnvironment();
    return ListView(
      key: const PageStorageKey('public-demo-menu-tab'),
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('メニュー', icon: Icons.menu_outlined),
        if (buildInfo.isAvailable) ...[
          PublicDemoMenuCard(
            child: PublicDemoMenuBuildInfoRow(
              isAvailable: buildInfo.isAvailable,
              buildInfoLabel: BuildInfoLabel(buildInfo: buildInfo),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _publicDemoDevMenuSection(),
      ],
    );
  }

  @override
  Widget build(BuildContext c) {
    // FIRST-FUN-YEAR P1 (Issue #229): the Opening Context replaces HOME
    // entirely (no AppBar/bottom nav) until dismissed — never true while
    // [_isRestoring] (both are only ever set together, in
    // [_restoreAggregate]/[_restartGame]), so this never races the restore
    // spinner above.
    if (_showOpening) {
      return PublicDemoOpeningContextScreen(
        startingCash: PublicDemoState.aprilStart().cash,
        monthlyFixedCost: PublicDemoSalary.baselineMonthlyExpenses,
        onStart: _acknowledgeOpeningContext,
      );
    }
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
          // Section 8: PUBLIC-DEMO-HOME-UI-3B — real logical tab surfaces.
          // [selectedIndex] now tracks [_selectedTabIndex], the same field
          // [build] reads below to decide which tab body to construct, so
          // the highlighted destination and the rendered content can never
          // disagree. Tapping a destination only ever calls [_switchTab]
          // (via [_handleBottomNavSelection]) — never a gameplay command —
          // so selecting a tab cannot itself mutate [_game].
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: _handleBottomNavSelection,
          destinations: const [
            NavigationDestination(
              key: Key('public-demo-nav-home'),
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'ホーム',
            ),
            NavigationDestination(
              key: Key('public-demo-nav-employees'),
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: '社員',
            ),
            NavigationDestination(
              key: Key('public-demo-nav-sales'),
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: '営業',
            ),
            NavigationDestination(
              key: Key('public-demo-nav-accounting'),
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance),
              label: '会計',
            ),
            NavigationDestination(
              key: Key('public-demo-nav-menu'),
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
                // PUBLIC-DEMO-HOME-UI-3B: only the selected tab's widget
                // subtree is ever constructed — a tab that is not selected
                // is not merely painted-over or excluded from hit-testing,
                // it is simply not built. This is what makes "HOME no
                // longer contains the full employee detail/training list"
                // (etc.) a structural fact rather than a visual one.
                child: switch (_selectedTabIndex) {
                  _employeesTabIndex => _buildEmployeesTab(c),
                  _salesTabIndex => _buildSalesTab(c),
                  _accountingTabIndex => _buildAccountingTab(c),
                  _menuTabIndex => _buildMenuTab(c),
                  _ => _buildHomeTab(c, navigatorAdvice),
                },
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
    return PublicDemoSalesCard(
      key: const Key('public-demo-recruitment-media-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '候補者を追加募集',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
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
