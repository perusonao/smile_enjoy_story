import 'package:flutter/material.dart';
import '../../game/public_demo/public_demo_aggregate.dart';
import '../../game/public_demo/public_demo_assignment.dart';
import '../../game/public_demo/public_demo_fiscal_close_id.dart';
import '../../game/public_demo/public_demo_interview.dart';
import '../../game/public_demo/public_demo_internal_training_transaction.dart';
import '../../game/public_demo/public_demo_month_label.dart';
import '../../game/public_demo/public_demo_recruitment.dart';
import '../../game/public_demo/public_demo_recruitment_medium.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../../game/public_demo/public_demo_salary_finance.dart';
import '../../game/public_demo/public_demo_salary.dart';
import '../../game/public_demo/public_demo_state.dart';
import '../../game/public_demo/public_demo_employee_condition.dart';
import '../../game/public_demo/public_demo_raise.dart';
import '../../game/public_demo/public_demo_summer_bonus_plan.dart';
import '../../game/public_demo/public_demo_workflow_state.dart';
import '../../presentation/home/models/home_dashboard_display_data.dart';
import '../asset_paths.dart';
import 'public_demo_event_dialog.dart';
import 'public_demo_cash_shortage_card.dart';
import 'public_demo_growth_result_card.dart';
import 'public_demo_home_dashboard_section.dart';
import 'public_demo_interview_result_dialog.dart';
import 'public_demo_monthly_cash_flow_card.dart';
import 'public_demo_sales_progress.dart';
import 'public_demo_salary_offer_dialog.dart';
import 'public_demo_raise_dialog.dart';
import 'public_demo_summer_bonus_dialog.dart';

class PublicDemo01PlaceholderScreen extends StatefulWidget {
  const PublicDemo01PlaceholderScreen({super.key});
  @override
  State<PublicDemo01PlaceholderScreen> createState() => _S();
}

class _S extends State<PublicDemo01PlaceholderScreen> {
  static final expense = PublicDemoSalary.baselineMonthlyExpenses;
  final _scrollController = ScrollController();

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

  /// Read-only view of [_game]'s finance side. Never assigned directly —
  /// see [_game].
  PublicDemoState get s => _game.state;

  /// Read-only view of [_game]'s workflow side. Never assigned directly —
  /// see [_game].
  PublicDemoWorkflowState get workflow => _game.workflow;

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

  bool _summerBonusDecisionConfirmed = false;

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
    setState(() => _game = result.aggregate!);
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
    setState(() => _game = _game.selectInternalTraining(engineerId));
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

  void ars(int i, PublicDemoReplacementStage x) => setState(() {
    _game = _game.withAssignmentUpdate(
      workflow.assignments[i].engineerId,
      replacementStage: x,
    );
  });
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
    setState(() {
      _game = _game.recordEngineerInterviewResult(engineerId: e.id, type: t);
    });
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
    setState(() => _game = _game.closeApril(monthlyExpenses: expense));
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
    setState(() => _game = result.aggregate);
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
    setState(() {
      _game = _game.acceptOffer(
        applicantId: a.id,
        offer: result,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(s.month),
      );
    });
  }

  Future<void> pi(int i) async {
    if (s.salesRemaining <= 0) return;
    final a = workflow.applicants[i];
    final score = a.salesSkillFit;
    final passed = score >= 60;
    // WORKFLOW-STATE-1AB FIX5 P1: the domain derives pass/fail itself from
    // this applicant's own authoritative salesSkillFit — `passed` above is
    // computed identically, purely for this dialog's own display text.
    setState(() {
      _game = _game.recordPreEntryPartnerInterviewResult(a.id);
    });
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
    setState(() {
      _game = _game.recordPreEntryClientInterviewResult(a.id);
    });
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
    setState(() => _game = _game.closeMay(week: 9, monthlyExpenses: expense));
    _resetMonthScroll();
  }

  void decideOrder(int i) {
    final a = workflow.assignments[i];
    setState(() {
      _game = _game.withAssignmentUpdate(
        a.engineerId,
        nextOrderStatus: a.willOfferNextMonthFor(capabilityFor(a.engineerId))
            ? PublicDemoNextOrderStatus.offered
            : PublicDemoNextOrderStatus.notOffered,
      );
    });
  }

  void acceptOrder(int i) {
    setState(() {
      _game = _game.withAssignmentUpdate(
        workflow.assignments[i].engineerId,
        nextOrderStatus: PublicDemoNextOrderStatus.accepted,
      );
    });
  }

  void replacementPartner(int i) {
    if (s.salesRemaining <= 0) return;
    final a = workflow.assignments[i];
    setState(() {
      _game = _game.consumeSlotAndSetReplacementStage(
        a.engineerId,
        a.replacementPartnerScoreFor(capabilityFor(a.engineerId)) >= 60
            ? PublicDemoReplacementStage.partnerPassed
            : PublicDemoReplacementStage.partnerFailed,
      );
    });
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
    setState(
      () => _game = _game.closeJune(
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
    setState(() {
      _game = _game.applyRaiseDecision(
        a.id,
        decisionMonth: s.month,
        week: s.month * 4,
        decision: decision,
      );
    });
  }

  int get _julyMonthlyExpenses => PublicDemoSalaryFinance.monthlyExpenses(
    baselineExpenses: expense,
    hires: workflow.joinedApplicants,
    month: 7,
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
    setState(() {
      _game = _game.selectSummerBonus(decision);
      _summerBonusDecisionConfirmed = true;
    });
  }

  Future<void> july() async {
    if (!_summerBonusDecisionConfirmed) {
      await decideSummerBonus();
      return;
    }
    setState(
      () => _game = _game.closeJuly(monthlyExpenses: _julyMonthlyExpenses),
    );
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
  void closeOrdinaryMonth() {
    setState(
      () => _game = _game.closeOrdinaryMonth(
        monthlyExpenses: _ordinaryMonthlyExpenses,
      ),
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
  String monthGoal() => switch (s.month) {
    4 => '待機中の技術者を営業し、5月の案件参画を決めましょう',
    5 => '応募者を採用し、入社前から6月の案件獲得を目指しましょう',
    6 => '翌月の発注を確認し、7月も稼働できる状態を作りましょう',
    _ => '今月の経営状況を確認し、翌月への準備をしましょう',
  };
  Widget stat(String label, String value) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
  Widget dashboard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '今月やること',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(monthGoal()),
            ],
          ),
        ),
      ),
      Row(
        children: [
          stat('現預金', '¥${(s.cash / 10000).floor()}万'),
          stat('参画', '${s.engineersAssigned}名'),
          stat('待機', '${s.engineersWaiting}名'),
          stat('営業残', '${s.salesRemaining}回'),
        ],
      ),
      const SizedBox(height: 8),
      if (s.latestMonthlyCashFlow != null) ...[
        PublicDemoMonthlyCashFlowCard(flow: s.latestMonthlyCashFlow!),
        const SizedBox(height: 8),
      ],
      PublicDemoCashShortageCard(state: s),
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
  }) {
    final selected = s.trainingSelections.containsKey(engineerId);
    final assigned = _currentlyAssignedEngineerIds.contains(engineerId);
    final affordable = s.cash >= PublicDemoInternalTrainingTransaction.cost;
    if (assigned) return const SizedBox.shrink();
    return Card(
      key: Key('public-demo-internal-training-$engineerId'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$engineerName（待機）',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('社内研修'),
            const Text('¥30,000'),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('今月は社内研修'),
              )
            // POST-12MONTH-1 / FINANCE-FAILURE-1A+1B: once the fiscal year
            // is completed, or a terminal financial status (BANKRUPTCY /
            // MARCH CASH-SHORTAGE FAILURE) is reached, Public Demo 0.1 is a
            // read-only terminal state — the training action (and its cash
            // preview) is hidden rather than shown disabled. This mirrors
            // the domain-level guard already enforced by
            // PublicDemoInternalTrainingTransaction regardless of this UI
            // check (WORKFLOW-STATE-1's "never rely on UI alone" contract).
            else if (!s.isCloseBlocked) ...[
              Text(
                '研修後の現預金 ¥${s.cash - PublicDemoInternalTrainingTransaction.cost}',
              ),
              if (!affordable)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('現預金が不足しています。', style: TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 8),
              FilledButton(
                key: Key('public-demo-internal-training-action-$engineerId'),
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

  Widget ec(int i) {
    final e = workflow.engineers[i];
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
            internalTrainingCard(engineerId: e.id, engineerName: e.name),
            PublicDemoSalesProgress(currentStep: engineerStep(e)),
            const SizedBox(height: 8),
            if (e.stage == PublicDemoSalesStage.waiting &&
                readyForFieldSales(e.id)) ...[
              const Text('営業準備OK', style: TextStyle(fontSize: 12)),
              FilledButton(
                onPressed: () =>
                    setState(() => _game = _game.startSkillSheetReview(e.id)),
                child: const Text('SkillSheet確認'),
              ),
            ],
            if (e.stage == PublicDemoSalesStage.skillSheet &&
                readyForFieldSales(e.id))
              FilledButton(
                onPressed: () =>
                    setState(() => _game = _game.beginSelling(e.id)),
                child: const Text('営業開始'),
              ),
            if (e.stage == PublicDemoSalesStage.selling)
              FilledButton(
                onPressed: () =>
                    setState(() => _game = _game.introduceProject(e.id)),
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
                onPressed: () async {
                  setState(() => _game = _game.recordOrder(e.id));
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
                },
                child: const Text('受注'),
              ),
            if (e.stage == PublicDemoSalesStage.partnerInterviewFailed ||
                e.stage == PublicDemoSalesStage.clientInterviewFailed)
              FilledButton(
                onPressed: () =>
                    setState(() => _game = _game.beginSelling(e.id)),
                child: const Text('再営業'),
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
                onPressed: () =>
                    setState(() => _game = _game.reviewResume(a.id)),
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
                onPressed: () =>
                    setState(() => _game = _game.beginPreEntrySkillSheet(a.id)),
                child: const Text('入社前SkillSheet'),
              ),
            if (a.stage == PublicDemoApplicantStage.offerAccepted &&
                !a.canEnterPreJoinSales)
              const Text('入社後、研修で育成します'),
            if (a.stage == PublicDemoApplicantStage.preEntrySkillSheet)
              FilledButton(
                onPressed: () =>
                    setState(() => _game = _game.beginPreEntrySelling(a.id)),
                child: const Text('入社前営業'),
              ),
            if (a.stage == PublicDemoApplicantStage.preEntrySelling)
              FilledButton(
                onPressed: () => setState(
                  () => _game = _game.introducePreEntryProject(a.id),
                ),
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
                onPressed: () async {
                  setState(() => _game = _game.recordJuneOrder(a.id));
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
                },
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
  @override
  Widget build(BuildContext c) => Theme(
    data: Theme.of(c).copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: _publicDemoFilledButtonStyle(c),
      ),
    ),
    child: Scaffold(
      appBar: AppBar(title: const Text('S.E.S. Public Demo 0.1')),
      body: SafeArea(
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
                // HOME-RUNTIME-READ-1: the new HOME read-only display,
                // added alongside (never in place of) the existing Public
                // Demo UI below. It receives only the projection — no
                // aggregate, no state, no commands, no callbacks.
                PublicDemoHomeDashboardSection(data: _homeDashboardData),
                Text(
                  publicDemoMonthLabel(s.month),
                  style: Theme.of(c).textTheme.headlineMedium,
                ),
                dashboard(),
                if (s.month == 4) ...[
                  for (var i = 0; i < workflow.engineers.length; i++) ec(i),
                  OutlinedButton(
                    onPressed: april,
                    child: const Text('4月終了→5月'),
                  ),
                ],
                if (s.month == 5) ...[
                  _RecruitmentMediaCard(
                    state: s,
                    onPressed: _openRecruitmentMedia,
                  ),
                  for (var i = 0; i < workflow.applicants.length; i++) ac(i),
                  OutlinedButton(onPressed: may, child: const Text('5月終了→6月')),
                ],
                if (s.month == 6)
                  for (final a in workflow.applicants.where(
                    (a) => s.joinedApplicantIds.contains(a.id) && a.hasJoined,
                  ))
                    employeeConditionCard(a),
                if (s.month == 6) ...[
                  for (var i = 0; i < workflow.engineers.length; i++)
                    if (s.joinedApplicantIds.contains(
                          workflow.engineers[i].id,
                        ) &&
                        workflow.engineers[i].stage !=
                            PublicDemoSalesStage.ordered &&
                        !workflow.assignments.any(
                          (assignment) =>
                              assignment.engineerId == workflow.engineers[i].id,
                        ))
                      ec(i),
                  for (var i = 0; i < workflow.assignments.length; i++)
                    assignmentCard(i),
                  OutlinedButton(onPressed: june, child: const Text('6月終了→7月')),
                ],
                if (s.month == 7) ...[
                  _RecruitmentMediaCard(
                    state: s,
                    onPressed: _openRecruitmentMedia,
                  ),
                  Text('7月開始結果', style: Theme.of(c).textTheme.titleLarge),
                  Text(
                    '参画 ${s.engineersAssigned}名 / 待機 ${s.engineersWaiting}名',
                  ),
                  for (final a in workflow.assignments)
                    ListTile(
                      title: Text(a.engineerName),
                      subtitle: Text(julyResult(a)),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '夏季賞与',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _summerBonusDecisionConfirmed
                                ? '選択済み：${switch (s.summerBonusSelection) {
                                    PublicDemoSummerBonusPlan.none => 'なし',
                                    PublicDemoSummerBonusPlan.half => '0.5か月',
                                    PublicDemoSummerBonusPlan.one => '1か月',
                                  }}'
                                : '7月終了前に支給内容を選びましょう。',
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            key: const Key('public-demo-summer-bonus-decision'),
                            onPressed: decideSummerBonus,
                            child: Text(
                              _summerBonusDecisionConfirmed
                                  ? '夏季賞与を変更'
                                  : '夏季賞与を決める',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  OutlinedButton(onPressed: july, child: const Text('7月終了→8月')),
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
                  OutlinedButton(
                    onPressed: closeOrdinaryMonth,
                    child: Text(
                      '${publicDemoMonthLabel(s.month)}終了→'
                      '${publicDemoMonthLabel(s.month + 1)}',
                    ),
                  ),
                ],
                if (s.month == 15 && !s.fiscalYearCompleted) ...[
                  Text(
                    '${publicDemoMonthLabel(s.month)}開始結果',
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  OutlinedButton(
                    key: const Key('public-demo-march-close'),
                    onPressed: closeOrdinaryMonth,
                    child: const Text('3月終了→第1期終了'),
                  ),
                ],
                if (s.fiscalYearCompleted) ...[
                  Card(
                    key: const Key('public-demo-fiscal-year-complete'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '第1期終了',
                            style: Theme.of(c).textTheme.titleLarge,
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
                    (a) => s.joinedApplicantIds.contains(a.id) && a.hasJoined,
                  ))
                    employeeConditionCard(a),
                if (s.month >= 6)
                  for (final runtime in s.engineerRuntimes)
                    internalTrainingCard(
                      engineerId: runtime.engineerId,
                      engineerName: _engineerName(runtime.engineerId),
                    ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
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
