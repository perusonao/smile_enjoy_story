import 'public_demo_assignment.dart';
import 'public_demo_engineer_runtime.dart';
import 'public_demo_fiscal_close_id.dart';
import 'public_demo_interview.dart';
import 'public_demo_internal_training_transaction.dart';
import 'public_demo_monthly_close.dart';
import 'public_demo_raise_transaction.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_recruitment_medium.dart';
import 'public_demo_sales.dart';
import 'public_demo_salary_offer.dart';
import 'public_demo_state.dart';
import 'public_demo_summer_bonus_plan.dart';
import 'public_demo_workflow_state.dart';

/// The single authoritative Public Demo 0.1 root (WORKFLOW-STATE-1AB
/// FIX3/FIX4): atomically owns both finance/monthly-close facts ([state])
/// and workflow facts ([workflow]) as one unit.
///
/// FIX2 still let a caller obtain [PublicDemoState]/[PublicDemoWorkflowState]
/// as two independently-committable values — a recruitment
/// `onCommitted(state, workflow)` callback that a caller could apply only
/// one half of, a `closeMay(..., joinedApplicants: ...)` caller-chosen
/// iterable, a public `PublicDemoWorkflowState(..., assignments: ...)`
/// factory, and a zero-argument `PublicDemoApplicant.markInterviewed()`.
/// FIX3 closed all four by making this class the only place gameplay code
/// holds workflow/finance state: every authority-significant transition is
/// a method here that takes the current aggregate (`this`) and returns the
/// next one, atomically, or a result whose only way to reach the next
/// aggregate is a single field. [PublicDemo01PlaceholderScreen] keeps
/// exactly one field of this type and only ever replaces it wholesale.
///
/// FIX3's own `.restore(state:, workflow:)` factory and `withState(newState)`
/// method were themselves still public, production-reachable APIs — commenting
/// them "restore-only"/"read-only-ish" did not actually stop a caller from
/// calling them to inject an arbitrary finance state, or an arbitrary
/// (state, workflow) pair, as the authoritative aggregate (independent
/// review FIX4 finding). Both are now gone entirely. There is no
/// constructor, factory, or method anywhere on this class that accepts a
/// caller-supplied [PublicDemoState] or [PublicDemoWorkflowState] value and
/// stores it directly into [state]/[workflow] — [initial] takes no
/// parameters, and every other method computes its result strictly from
/// `this.state`/`this.workflow` plus caller-supplied identifiers/enums/ints
/// (never a whole root value). This is what makes "finance-only commit" and
/// "workflow-only commit" structurally impossible from the Public Domain
/// API, not just absent from `PublicDemo01PlaceholderScreen`'s own call
/// sites: even if a caller directly invokes a lower-level helper like
/// [PublicDemoMonthlyClose.closeMay] or [PublicDemoState.advanceToJune]
/// (both remain public — read their own docs for why that is still safe)
/// and gets back a fabricated [PublicDemoState], there is no longer any API
/// on this class through which that value could be committed as
/// authoritative.
///
/// This class also deliberately does NOT expose a generic
/// `withState(PublicDemoState Function(PublicDemoState) update)` /
/// `withWorkflow(...)`-style combinator: a caller-supplied transform can
/// simply ignore the value it is given and return an arbitrary fabricated
/// one instead (the same structural flaw FIX3 closed for
/// `PublicDemoWorkflowState.withAssignment` — see its doc), which would
/// silently reopen the very "two independently authoritative roots"
/// problem this class exists to close. Every method below is instead a
/// named, specific transition that only ever composes already-safe,
/// already-audited operations on [state]/[workflow] — never a caller
/// closure or a caller-supplied root value.
///
/// Test fixtures needing a specific intermediate aggregate state build it
/// by chaining these same real commands from [initial] — exactly as
/// production code does — never via a reconstruction shortcut this file
/// does not expose.
class PublicDemoAggregate {
  const PublicDemoAggregate._({required this.state, required this.workflow});

  /// Public Demo 0.1's starting aggregate. The ONLY way to obtain a
  /// [PublicDemoAggregate] without already holding one — every other
  /// instance is computed from an existing one via the command methods
  /// below.
  factory PublicDemoAggregate.initial() => PublicDemoAggregate._(
    state: PublicDemoState.aprilStart(),
    workflow: PublicDemoWorkflowState.initial(),
  );

  final PublicDemoState state;
  final PublicDemoWorkflowState workflow;

  /// Complete persistence form for the sole Public Demo authoritative root.
  Map<String, dynamic> toJson() => {
    'state': state.toJson(),
    'workflow': workflow.toJson(),
  };

  /// Restores a previously persisted root only when its cross-domain facts
  /// still agree.  This does not replay, reconcile, or repair gameplay; the
  /// caller must discard the whole save when this factory throws.
  factory PublicDemoAggregate.fromJson(Map<String, dynamic> json) {
    final stateRaw = json['state'];
    final workflowRaw = json['workflow'];
    if (stateRaw is! Map || workflowRaw is! Map) {
      throw const FormatException('Invalid Public Demo aggregate');
    }
    final aggregate = PublicDemoAggregate._(
      state: PublicDemoState.fromJson(stateRaw.cast<String, dynamic>()),
      workflow: PublicDemoWorkflowState.fromJson(
        workflowRaw.cast<String, dynamic>(),
      ),
    );
    aggregate._validateForPersistence();
    return aggregate;
  }

  void _validateForPersistence() {
    if (state.month < 4 ||
        state.month > 15 ||
        state.salesCapacity < 0 ||
        state.salesUsed < 0 ||
        state.salesUsed > state.salesCapacity ||
        state.engineersAssigned < 0 ||
        state.engineersWaiting < 0 ||
        state.engineersAssigned + state.engineersWaiting !=
            state.engineerCount ||
        (state.fiscalYearCompleted && state.month != 15)) {
      throw const FormatException('Invalid Public Demo state invariants');
    }

    final engineerIds = workflow.engineers
        .map((engineer) => engineer.id)
        .toList();
    final applicantIds = workflow.applicants
        .map((applicant) => applicant.id)
        .toList();
    final runtimeIds = state.engineerRuntimes
        .map((runtime) => runtime.engineerId)
        .toList();
    final assignmentIds = workflow.assignments
        .map((assignment) => assignment.engineerId)
        .toList();
    if (!_areUnique(engineerIds) ||
        !_areUnique(applicantIds) ||
        !_areUnique(runtimeIds) ||
        !_areUnique(assignmentIds) ||
        state.engineerCount != engineerIds.length ||
        runtimeIds.toSet().length != engineerIds.length ||
        !runtimeIds.toSet().containsAll(engineerIds) ||
        !engineerIds.toSet().containsAll(assignmentIds)) {
      throw const FormatException('Invalid Public Demo workflow identities');
    }

    final joinedIds = workflow.joinedApplicantIds;
    if (!_sameOrderedStrings(state.joinedApplicantIds, joinedIds)) {
      throw const FormatException('Invalid joined-applicant projection');
    }
    for (final applicant in workflow.applicants) {
      final offer = applicant.bindingOffer;
      if (offer != null && offer.applicantId != applicant.id) {
        throw const FormatException('Invalid applicant binding offer');
      }
    }
    for (final engineer in workflow.engineers) {
      if (engineer.interviewRecord != null &&
          engineer.interviewRecord!.engineerId != engineer.id) {
        throw const FormatException('Invalid engineer interview record');
      }
    }

    final assignedIds = workflow.assignedEngineerIds(month: state.month);
    if (state.month >= 6 &&
        (state.engineersAssigned != assignedIds.length ||
            state.engineersWaiting !=
                state.engineerCount - assignedIds.length)) {
      throw const FormatException('Invalid assignment projection');
    }
    if (!state.trainingSelections.keys.every(
      (engineerId) =>
          engineerIds.contains(engineerId) && !assignedIds.contains(engineerId),
    )) {
      throw const FormatException('Invalid training selection');
    }
  }

  static bool _areUnique(Iterable<String> values) {
    final seen = <String>{};
    return values.every(seen.add);
  }

  static bool _sameOrderedStrings(List<String> left, List<String> right) =>
      left.length == right.length &&
      Iterable<int>.generate(
        left.length,
      ).every((index) => left[index] == right[index]);

  PublicDemoAggregate _copyWith({
    PublicDemoState? state,
    PublicDemoWorkflowState? workflow,
  }) => PublicDemoAggregate._(
    state: state ?? this.state,
    workflow: workflow ?? this.workflow,
  );

  // ---------------------------------------------------------------------
  // P1-1: interview authority
  // ---------------------------------------------------------------------

  /// The single sanctioned way to complete an applicant's interview
  /// (WORKFLOW-STATE-1AB FIX3 P1-1). Validates the applicant exists, has
  /// not already been interviewed, and that a real sales slot is available
  /// — consuming it and minting the applicant's
  /// [PublicDemoInterviewRecord] together, atomically, or changing nothing
  /// at all.
  PublicDemoInterviewCompletionResult completeInterview(String applicantId) {
    final applicant = workflow.applicants
        .where((candidate) => candidate.id == applicantId)
        .firstOrNull;
    if (applicant == null) {
      return PublicDemoInterviewCompletionResult._(
        aggregate: this,
        status: PublicDemoInterviewCompletionStatus.unknownApplicant,
      );
    }
    if (applicant.hasBeenInterviewed) {
      return PublicDemoInterviewCompletionResult._(
        aggregate: this,
        status: PublicDemoInterviewCompletionStatus.alreadyInterviewed,
      );
    }
    final slotResult = state.useSalesSlotForInterview();
    final proof = slotResult.proof;
    if (proof == null) {
      return PublicDemoInterviewCompletionResult._(
        aggregate: this,
        status: state.fiscalYearCompleted
            ? PublicDemoInterviewCompletionStatus.fiscalYearCompleted
            : PublicDemoInterviewCompletionStatus.noSalesSlot,
      );
    }
    final nextWorkflow = workflow.recordInterviewCompletion(applicantId, proof);
    return PublicDemoInterviewCompletionResult._(
      aggregate: _copyWith(state: slotResult.state, workflow: nextWorkflow),
      status: PublicDemoInterviewCompletionStatus.completed,
    );
  }

  // ---------------------------------------------------------------------
  // P1-2: recruitment atomicity
  // ---------------------------------------------------------------------

  /// Purchases recruitment media for the current month
  /// (WORKFLOW-STATE-1AB FIX3 P1-2). Cash/usage
  /// ([PublicDemoState]) and the generated applicants
  /// ([PublicDemoWorkflowState]) commit together in the returned
  /// [PublicDemoRecruitmentTransactionResult.aggregate] — the single new
  /// authoritative root — or [aggregate] is null and neither changes.
  ///
  /// FINANCE-FAILURE-1A+1B §13/15: rejected by domain authority — before
  /// any cash mutation, usage mutation, or applicant generation — while
  /// [PublicDemoState.isFinanciallyRestricted]. This applies to every
  /// medium, including [PublicDemoRecruitmentMedium.free]: B'.1 finalized
  /// that a zero-cost medium still creates recruitment activity Public
  /// Demo 0.1 must not allow during a cash shortfall, not just a cash
  /// mutation to gate.
  PublicDemoRecruitmentTransactionResult recruit(
    PublicDemoRecruitmentMedium medium, {
    PublicDemoRecruitmentCandidateGenerator? candidateGenerator,
  }) {
    if (state.isFinanciallyRestricted) {
      return PublicDemoRecruitmentTransactionResult._(
        aggregate: null,
        medium: medium,
        chargedAmount: 0,
        generatedApplicants: const [],
        status:
            PublicDemoRecruitmentTransactionStatus.blockedByFinancialShortage,
      );
    }
    final calculation = PublicDemoRecruitmentCalculation(
      candidateGenerator: candidateGenerator,
    ).execute(state: state, medium: medium);
    if (!calculation.isSuccess) {
      return PublicDemoRecruitmentTransactionResult._(
        aggregate: null,
        medium: calculation.medium,
        chargedAmount: calculation.chargedAmount,
        generatedApplicants: calculation.generatedApplicants,
        status: calculation.status,
      );
    }
    final nextWorkflow = workflow.withGeneratedApplicants(
      calculation.generatedApplicants,
    );
    return PublicDemoRecruitmentTransactionResult._(
      aggregate: _copyWith(state: calculation.state, workflow: nextWorkflow),
      medium: calculation.medium,
      chargedAmount: calculation.chargedAmount,
      generatedApplicants: calculation.generatedApplicants,
      status: calculation.status,
    );
  }

  /// The single sanctioned way to purchase internal training for one
  /// waiting engineer (WORKFLOW-STATE-1AB FIX4 P1-1). Computes the
  /// engineer's currently-assigned eligibility from this aggregate's own
  /// [workflow] internally via [PublicDemoInternalTrainingTransaction] —
  /// the caller supplies only [engineerId], never a [PublicDemoState] value
  /// to commit. Silently unchanged on any failure (unknown engineer,
  /// already assigned, already selected, insufficient cash, fiscal year
  /// completed), mirroring every other simple no-op-on-failure command on
  /// this class.
  PublicDemoAggregate selectInternalTraining(String engineerId) {
    final result = const PublicDemoInternalTrainingTransaction().execute(
      state: state,
      engineerId: engineerId,
      assignedEngineerIds: workflow.assignedEngineerIds(month: state.month),
    );
    if (!result.isSuccess) return this;
    return _copyWith(state: result.state);
  }

  // ---------------------------------------------------------------------
  // Offer / applicant / engineer / assignment value transitions
  // (safe, single-root passthroughs — see class doc for why these remain
  // named methods rather than a generic combinator)
  // ---------------------------------------------------------------------

  /// The single sanctioned way to accept a salary offer for one applicant
  /// (WORKFLOW-STATE-1 §11).
  ///
  /// FINANCE-FAILURE-1A+1B §13/14: rejected by domain authority — not just
  /// a disabled UI control — while
  /// [PublicDemoState.isFinanciallyRestricted], since an accepted offer
  /// mints the [PublicDemoBindingOffer] that is this game's salary-
  /// obligation boundary. A [PublicDemoBindingOffer] already minted before
  /// the shortage began is unaffected: this only ever guards a NEW
  /// acceptance call, never an applicant's already-authoritative offer.
  PublicDemoAggregate acceptOffer({
    required String applicantId,
    required PublicDemoSalaryOffer offer,
    required PublicDemoFiscalCloseId fiscalCloseId,
  }) {
    if (state.isFinanciallyRestricted) return this;
    return _copyWith(
      workflow: workflow.acceptOffer(
        applicantId: applicantId,
        offer: offer,
        fiscalCloseId: fiscalCloseId,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // WORKFLOW-STATE-1AB FIX5 P1: `withEngineerStage(engineerId, stage)` and
  // `withApplicantStage(applicantId, stage)` — a caller-chosen target
  // stage, with no precondition check at all — used to live here as
  // public passthroughs to the (also now-removed)
  // PublicDemoWorkflowState methods of the same name. Independent review
  // found both directly reachable: `withEngineerStage(id,
  // PublicDemoSalesStage.ordered)` followed by `closeMay()` minted an
  // assignment for an engineer whose sales pipeline never ran at all
  // (Attack A), and `withApplicantStage(id,
  // PublicDemoApplicantStage.juneOrdered)` did the same for an applicant
  // with no BindingOffer/join eligibility (Attack B). Both are gone —
  // along with `consumeSlotAndSetApplicantStage`/
  // `applyEngineerInterviewResult`, which had the identical shape one
  // level down (a caller-suppliable `stage`/`score` parameter, not
  // gated on any precondition). Every command below instead names one
  // real sales/pre-entry event; the domain derives the next stage (and,
  // for interview outcomes, the score) itself from already-authoritative
  // facts — this workflow's own current stage, the engineer's interview
  // profile, and (for partner interviews) this aggregate's own sales-slot
  // budget — and changes nothing when the required precondition isn't
  // met. See PublicDemoWorkflowState's own "Engineer sales-pipeline
  // transitions" / "Applicant pre-entry pipeline transitions" sections for
  // the full precondition chain each of these sits on top of.
  // ---------------------------------------------------------------------

  PublicDemoAggregate startSkillSheetReview(String engineerId) =>
      _copyWith(workflow: workflow.startSkillSheetReview(engineerId));

  PublicDemoAggregate beginSelling(String engineerId) =>
      _copyWith(workflow: workflow.beginSelling(engineerId));

  PublicDemoAggregate introduceProject(String engineerId) =>
      _copyWith(workflow: workflow.introduceProject(engineerId));

  PublicDemoAggregate recordOrder(String engineerId) =>
      _copyWith(workflow: workflow.recordOrder(engineerId));

  PublicDemoAggregate reviewResume(String applicantId) =>
      _copyWith(workflow: workflow.reviewResume(applicantId));

  PublicDemoAggregate beginPreEntrySkillSheet(String applicantId) =>
      _copyWith(workflow: workflow.beginPreEntrySkillSheet(applicantId));

  PublicDemoAggregate beginPreEntrySelling(String applicantId) =>
      _copyWith(workflow: workflow.beginPreEntrySelling(applicantId));

  PublicDemoAggregate introducePreEntryProject(String applicantId) =>
      _copyWith(workflow: workflow.introducePreEntryProject(applicantId));

  PublicDemoAggregate recordJuneOrder(String applicantId) =>
      _copyWith(workflow: workflow.recordJuneOrder(applicantId));

  /// Records a partner or client interview outcome for an engineer's sales
  /// pipeline (WORKFLOW-STATE-1AB FIX5 P1, replacing
  /// `applyEngineerInterviewResult`; FIX6 P1 moved the actual stage/record
  /// derivation into [PublicDemoWorkflowState.recordEngineerInterviewResult]
  /// so this file no longer needs the now-private `workflow._withEngineer`
  /// directly). [type] selects which real event happened; the resulting
  /// stage, score, and (on a genuine client-interview pass) unforgeable
  /// [PublicDemoEngineerInterviewRecord] are always derived from the
  /// engineer's own [PublicDemoEngineerSales.interviewProfile] and
  /// [PublicDemoEngineerRuntime.actualCapability] (via
  /// [PublicDemoInterviewEvaluator]) — never accepted as a parameter. A
  /// no-op unless [engineerId] is currently at the stage that interview
  /// type requires (`introduced` for partner, `partnerInterviewPassed` for
  /// client) — and, for a partner interview, only if a real sales slot is
  /// actually available (checked before it is consumed, so a rejected
  /// attempt never partially consumes the budget).
  PublicDemoAggregate recordEngineerInterviewResult({
    required String engineerId,
    required PublicDemoInterviewType type,
  }) {
    final engineer = workflow.engineers
        .where((candidate) => candidate.id == engineerId)
        .firstOrNull;
    if (engineer == null) return this;
    final requiredStage = type == PublicDemoInterviewType.partner
        ? PublicDemoSalesStage.introduced
        : PublicDemoSalesStage.partnerInterviewPassed;
    if (engineer.stage != requiredStage) return this;
    if (type == PublicDemoInterviewType.partner &&
        (state.fiscalYearCompleted || state.salesRemaining <= 0)) {
      return this;
    }

    return _copyWith(
      state: type == PublicDemoInterviewType.partner
          ? state.useSalesSlot()
          : state,
      workflow: workflow.recordEngineerInterviewResult(
        engineerId: engineerId,
        type: type,
        actualCapability:
            state.runtimeForOrNull(engineerId)?.actualCapability ?? 0,
      ),
    );
  }

  /// Records the pre-entry partner-interview outcome for one applicant
  /// (WORKFLOW-STATE-1AB FIX5 P1, replacing
  /// `consumeSlotAndSetApplicantStage`). Consumes one sales slot (a no-op
  /// past budget/fiscal completion) only when the applicant is genuinely
  /// eligible — currently at `preEntryIntroduced` — and derives pass/fail
  /// itself from the applicant's own [PublicDemoApplicant.salesSkillFit],
  /// never from a caller-supplied stage. FIX6 P1 moved the actual stage
  /// derivation into
  /// [PublicDemoWorkflowState.recordPreEntryPartnerInterviewResult] so this
  /// file no longer needs the now-private `workflow._withApplicant`
  /// directly; this method still owns deciding whether a sales slot is
  /// genuinely available, since only it has [state].
  PublicDemoAggregate recordPreEntryPartnerInterviewResult(String applicantId) {
    final applicant = workflow.applicants
        .where((candidate) => candidate.id == applicantId)
        .firstOrNull;
    if (applicant == null) return this;
    if (applicant.stage != PublicDemoApplicantStage.preEntryIntroduced) {
      return this;
    }
    if (state.fiscalYearCompleted || state.salesRemaining <= 0) return this;

    return _copyWith(
      state: state.useSalesSlot(),
      workflow: workflow.recordPreEntryPartnerInterviewResult(applicantId),
    );
  }

  /// Records the pre-entry client-interview outcome for one applicant
  /// (WORKFLOW-STATE-1AB FIX5 P1) — mirrors
  /// [recordPreEntryPartnerInterviewResult] but, matching the pre-cutover
  /// widget's own `ci()` handler, consumes no sales slot. A no-op unless
  /// the applicant is currently at `preEntryPartnerPassed` — enforced by
  /// [PublicDemoWorkflowState.recordPreEntryClientInterviewResult]
  /// (FIX6 P1), which this is now a thin passthrough to.
  PublicDemoAggregate recordPreEntryClientInterviewResult(String applicantId) =>
      _copyWith(
        workflow: workflow.recordPreEntryClientInterviewResult(applicantId),
      );

  PublicDemoAggregate withAssignmentUpdate(
    String engineerId, {
    PublicDemoNextOrderStatus? nextOrderStatus,
    PublicDemoReplacementStage? replacementStage,
    int? fieldEvaluation,
  }) => _copyWith(
    workflow: workflow.withAssignmentUpdate(
      engineerId,
      nextOrderStatus: nextOrderStatus,
      replacementStage: replacementStage,
      fieldEvaluation: fieldEvaluation,
    ),
  );

  /// Consumes one sales slot and records a replacement-partner-interview
  /// outcome on the matching assignment together (mirrors the pre-cutover
  /// widget's own `replacementPartner()` handler).
  PublicDemoAggregate consumeSlotAndSetReplacementStage(
    String engineerId,
    PublicDemoReplacementStage replacementStage,
  ) => _copyWith(
    state: state.useSalesSlot(),
    workflow: workflow.withAssignmentUpdate(
      engineerId,
      replacementStage: replacementStage,
    ),
  );

  /// The single sanctioned way to decide a raise for [applicantId]
  /// (POST-12MONTH-1-FIX1 P1-1), via [PublicDemoRaiseTransaction] — reads
  /// [state] for the fiscal-year-completion guard, mutates only [workflow].
  /// FIX6 P1 moved the actual transaction call into
  /// [PublicDemoWorkflowState.applyRaiseDecision] so this file no longer
  /// needs the now-private `workflow._withApplicant` directly.
  PublicDemoAggregate applyRaiseDecision(
    String applicantId, {
    required int decisionMonth,
    required int week,
    required PublicDemoRaiseDecision decision,
  }) => _copyWith(
    workflow: workflow.applyRaiseDecision(
      applicantId,
      state: state,
      decisionMonth: decisionMonth,
      week: week,
      decision: decision,
    ),
  );

  PublicDemoAggregate selectSummerBonus(PublicDemoSummerBonusPlan plan) =>
      _copyWith(state: state.selectSummerBonus(plan));

  /// Commits the player's explicit July bonus decision into the authoritative
  /// aggregate.  The decision fact is separate from the selected plan so a
  /// confirmed `none` survives persistence just like a paid bonus plan.
  PublicDemoAggregate confirmSummerBonusDecision(
    PublicDemoSummerBonusPlan plan,
  ) => _copyWith(state: state.confirmSummerBonusDecision(plan));

  // ---------------------------------------------------------------------
  // Month-end transitions
  // ---------------------------------------------------------------------

  /// Closes April (state-only; workflow is not part of April's transition).
  ///
  /// FINANCE-FAILURE-1A+1B §5: the pre-AR-idempotency guard below runs
  /// before Growth, AR, salary, or cash are touched at all — a retry once
  /// [state.month] is no longer 4, or once [PublicDemoState.isCloseBlocked]
  /// (fiscal year completed or a terminal financial status reached), is a
  /// complete no-op returning this exact aggregate, never a partial
  /// mutation. Every other month-end command below follows the same shape.
  PublicDemoAggregate closeApril({required int monthlyExpenses}) {
    if (state.month != 4 || state.isCloseBlocked) return this;
    return _copyWith(
      state: PublicDemoMonthlyClose.closeApril(
        state: _closeGrowth(const {}),
        monthlyExpenses: monthlyExpenses,
        orderedEngineers: workflow.engineers
            .where((engineer) => engineer.stage == PublicDemoSalesStage.ordered)
            .length,
      ).state,
    );
  }

  /// Closes May: joins eligible applicants, adds them as engineers, builds
  /// the domain-computed assignment roster, then closes the finance month
  /// — all as one atomic aggregate transition (WORKFLOW-STATE-1AB FIX3
  /// P1-3, P1-4). There is no `assignments`/`joinedApplicants` parameter
  /// the caller could supply: the roster and the joined-applicant
  /// projection are both derived entirely from this aggregate's own
  /// authoritative facts.
  PublicDemoAggregate closeMay({
    required int week,
    required int monthlyExpenses,
  }) {
    if (state.month != 5 || state.isCloseBlocked) return this;
    bool accepted(PublicDemoApplicant applicant) => const {
      PublicDemoApplicantStage.offerAccepted,
      PublicDemoApplicantStage.preEntrySkillSheet,
      PublicDemoApplicantStage.preEntrySelling,
      PublicDemoApplicantStage.preEntryIntroduced,
      PublicDemoApplicantStage.preEntryPartnerPassed,
      PublicDemoApplicantStage.preEntryPartnerFailed,
      PublicDemoApplicantStage.preEntryClientPassed,
      PublicDemoApplicantStage.preEntryClientFailed,
      PublicDemoApplicantStage.juneOrdered,
    }.contains(applicant.stage);

    final hires = workflow.applicants.where(accepted).length;
    final ordered = workflow.applicants
        .where(
          (applicant) =>
              applicant.stage == PublicDemoApplicantStage.juneOrdered,
        )
        .length;
    final joinIds = workflow.applicants
        .where(accepted)
        .map((applicant) => applicant.id)
        .toList();
    var nextWorkflow = workflow.joinAndKeepOnly(
      applicantIds: joinIds,
      week: week,
      currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(state.month),
    );
    final joinedNow = nextWorkflow.applicants
        .where((applicant) => applicant.hasJoined)
        .toList();
    nextWorkflow = nextWorkflow
        .withJoinedEngineers(joinedNow)
        .assignOrderedForMay();

    // Matches the pre-cutover widget exactly: assignedEngineerIds comes
    // from the post-join/post-assignment workflow, while moraleByEngineerId
    // is read from THIS aggregate's own pre-transition workflow — see
    // `_closeGrowth` below and its call site here.
    final grownState = state.applyMonthlyGrowth(
      assignedEngineerIds: nextWorkflow.engineers
          .where((engineer) => engineer.stage == PublicDemoSalesStage.ordered)
          .map((engineer) => engineer.id)
          .toSet(),
      moraleByEngineerId: workflow.moraleByEngineerId,
    );
    final closedState = PublicDemoMonthlyClose.closeMay(
      state: grownState,
      workflow: nextWorkflow,
      monthlyExpenses: monthlyExpenses,
      acceptedHires: hires,
      hiredWithOrders: ordered,
    ).state;
    final finalState = closedState.copyWith(
      engineerRuntimes: [
        ...closedState.engineerRuntimes,
        for (final applicant in joinedNow)
          PublicDemoEngineerRuntime.fromApplicant(applicant),
      ],
    );
    return _copyWith(state: finalState, workflow: nextWorkflow);
  }

  /// Closes June (state-only; workflow is read-only here).
  PublicDemoAggregate closeJune({
    required int assignedInJuly,
    required int monthlyExpenses,
  }) {
    if (state.month != 6 || state.isCloseBlocked) return this;
    return _copyWith(
      state: PublicDemoMonthlyClose.closeJune(
        state: _closeGrowth(
          workflow.assignments
              .map((assignment) => assignment.engineerId)
              .toSet(),
        ),
        monthlyExpenses: monthlyExpenses,
        assignedInJuly: assignedInJuly,
      ).state,
    );
  }

  /// Closes July (state-only; reads `workflow.joinedApplicants` — the full
  /// authoritative derived set, never a caller-chosen subset).
  ///
  /// The zero plan always permits the mandatory close, including a negative
  /// result. An unaffordable paid plan is rejected before Growth, AR, or any
  /// expense is applied — see [PublicDemoMonthlyClose.closeJuly].
  PublicDemoAggregate closeJuly({required int monthlyExpenses}) {
    if (state.month != 7 || state.isCloseBlocked) return this;
    final preview = PublicDemoMonthlyClose.previewJuly(
      state: state,
      monthlyExpenses: monthlyExpenses,
      applicants: workflow.joinedApplicants,
      plan: state.summerBonusSelection,
    );
    if (!preview.isEligible) return this;
    return _copyWith(
      state: PublicDemoMonthlyClose.closeJuly(
        state: _closeGrowth(
          workflow.assignments
              .where(
                (assignment) =>
                    assignment.nextOrderStatus ==
                        PublicDemoNextOrderStatus.accepted ||
                    assignment.replacementStage ==
                        PublicDemoReplacementStage.ordered,
              )
              .map((assignment) => assignment.engineerId)
              .toSet(),
        ),
        monthlyExpenses: monthlyExpenses,
        applicants: workflow.joinedApplicants,
      ).state,
    );
  }

  /// Closes any ordinary month from August through March (state-only).
  PublicDemoAggregate closeOrdinaryMonth({required int monthlyExpenses}) {
    if (state.month < 8 || state.month > 15 || state.isCloseBlocked) {
      return this;
    }
    return _copyWith(
      state: PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: _closeGrowth(workflow.assignedEngineerIds(month: state.month)),
        monthlyExpenses: monthlyExpenses,
      ).state,
    );
  }

  /// This is called only by the month-end commands above, after all
  /// current-month work/contract decisions and before the next month
  /// transition — mirrors the pre-cutover widget's own `_closeGrowth`
  /// helper exactly, including reading `moraleByEngineerId` from this
  /// aggregate's own (pre-transition) [workflow].
  PublicDemoState _closeGrowth(Set<String> assignedEngineerIds) =>
      state.applyMonthlyGrowth(
        assignedEngineerIds: assignedEngineerIds,
        moraleByEngineerId: workflow.moraleByEngineerId,
      );
}

/// Result of [PublicDemoAggregate.completeInterview] (WORKFLOW-STATE-1AB
/// FIX3 P1-1). [aggregate] is the new authoritative aggregate on
/// [PublicDemoInterviewCompletionStatus.completed], or the unchanged
/// original aggregate for any other status.
class PublicDemoInterviewCompletionResult {
  const PublicDemoInterviewCompletionResult._({
    required this.aggregate,
    required this.status,
  });

  final PublicDemoAggregate aggregate;
  final PublicDemoInterviewCompletionStatus status;

  bool get isCompleted =>
      status == PublicDemoInterviewCompletionStatus.completed;
}

enum PublicDemoInterviewCompletionStatus {
  completed,
  alreadyInterviewed,
  noSalesSlot,
  fiscalYearCompleted,
  unknownApplicant,
}

/// Generator hook for [PublicDemoAggregate.recruit] — tests substitute a
/// deterministic/failing generator; production uses the default pool-based
/// generator.
typedef PublicDemoRecruitmentCandidateGenerator =
    List<PublicDemoApplicant> Function({
      required int month,
      required PublicDemoRecruitmentMedium medium,
      required int count,
    });

/// Read-only facts about a recruitment-media purchase attempt
/// (WORKFLOW-STATE-1AB FIX3 P1-2). [aggregate] is the single new
/// authoritative root on success — cash and generated applicants always
/// arrive together — or null on failure, when neither changed. There is no
/// way to read a committed [PublicDemoState] or [PublicDemoWorkflowState]
/// independently of the other from this result.
class PublicDemoRecruitmentTransactionResult {
  const PublicDemoRecruitmentTransactionResult._({
    required this.aggregate,
    required this.medium,
    required this.chargedAmount,
    required this.generatedApplicants,
    required this.status,
  });

  final PublicDemoAggregate? aggregate;
  final PublicDemoRecruitmentMedium medium;
  final int chargedAmount;
  final List<PublicDemoApplicant> generatedApplicants;
  final PublicDemoRecruitmentTransactionStatus status;

  bool get isSuccess =>
      status == PublicDemoRecruitmentTransactionStatus.success;
}

enum PublicDemoRecruitmentTransactionStatus {
  success,
  alreadyUsedThisMonth,
  insufficientCash,
  generationFailed,
  blockedByFinancialShortage,
}

/// Pure, all-or-nothing recruitment-media purchase calculation — INTERNAL
/// HELPER tier (WORKFLOW-STATE-1AB FIX4): takes and returns only
/// [PublicDemoState] values (never a [PublicDemoWorkflowState] or a
/// [PublicDemoAggregate]), so it cannot itself commit anything as
/// authoritative. It is public, and directly testable, for the same reason
/// [PublicDemoMonthlyClose] and [PublicDemoState.advanceToJune] are public:
/// exercising pure month/cash/generation validation logic in isolation does
/// not require, and must not require, fabricating a whole authoritative
/// aggregate. [PublicDemoAggregate.recruit] is the sole production caller
/// that actually commits this calculation's output (cash) together with
/// the generated applicants (workflow) into one new aggregate — nothing
/// about this class alone lets a caller retain only one half.
class PublicDemoRecruitmentCalculation {
  const PublicDemoRecruitmentCalculation({
    PublicDemoRecruitmentCandidateGenerator? candidateGenerator,
  }) : _candidateGenerator = candidateGenerator ?? _generateApplicants;

  final PublicDemoRecruitmentCandidateGenerator _candidateGenerator;

  PublicDemoRecruitmentCalculationResult execute({
    required PublicDemoState state,
    required PublicDemoRecruitmentMedium medium,
  }) {
    if (!state.canUseRecruitmentMediaInMonth(state.month)) {
      return PublicDemoRecruitmentCalculationResult._(
        state: state,
        medium: medium,
        chargedAmount: 0,
        generatedApplicants: const [],
        status: PublicDemoRecruitmentTransactionStatus.alreadyUsedThisMonth,
      );
    }
    if (state.cash < medium.cost) {
      return PublicDemoRecruitmentCalculationResult._(
        state: state,
        medium: medium,
        chargedAmount: 0,
        generatedApplicants: const [],
        status: PublicDemoRecruitmentTransactionStatus.insufficientCash,
      );
    }

    final applicants = _candidateGenerator(
      month: state.month,
      medium: medium,
      count: medium.applicantCount,
    );
    if (applicants.length != medium.applicantCount) {
      return PublicDemoRecruitmentCalculationResult._(
        state: state,
        medium: medium,
        chargedAmount: 0,
        generatedApplicants: const [],
        status: PublicDemoRecruitmentTransactionStatus.generationFailed,
      );
    }

    final committed = state
        .copyWith(cash: state.cash - medium.cost)
        .recordRecruitmentSpend(medium.cost)
        .markRecruitmentMediaUsed(state.month);
    return PublicDemoRecruitmentCalculationResult._(
      state: committed,
      medium: medium,
      chargedAmount: medium.cost,
      generatedApplicants: List.unmodifiable(applicants),
      status: PublicDemoRecruitmentTransactionStatus.success,
    );
  }

  /// Selects from media-specific lightweight profiles without importing the
  /// main game's random generator. Keeps the established engineer pool
  /// separate so adding free-media templates cannot alter its existing
  /// month results.
  static List<PublicDemoApplicant> _generateApplicants({
    required int month,
    required PublicDemoRecruitmentMedium medium,
    required int count,
  }) {
    final pool = switch (medium) {
      PublicDemoRecruitmentMedium.engineer => publicDemoMayApplicants,
      PublicDemoRecruitmentMedium.free => publicDemoFreeApplicants,
    };
    return List.generate(count, (index) {
      final template = pool[(month + medium.index + index) % pool.length];
      return PublicDemoApplicant(
        id: 'recruitment-$month-${medium.name}-${index + 1}',
        name: template.name,
        resumeSummary: template.resumeSummary,
        interviewScore: template.interviewScore,
        acceptanceScore: template.acceptanceScore,
        salesSkillFit: template.salesSkillFit,
        experienceMonths: template.experienceMonths,
        requestedMonthlySalary: template.requestedMonthlySalary,
      );
    });
  }
}

/// Read-only result of [PublicDemoRecruitmentCalculation.execute] — a pure
/// [PublicDemoState] value, not connected to any [PublicDemoAggregate].
class PublicDemoRecruitmentCalculationResult {
  const PublicDemoRecruitmentCalculationResult._({
    required this.state,
    required this.medium,
    required this.chargedAmount,
    required this.generatedApplicants,
    required this.status,
  });

  final PublicDemoState state;
  final PublicDemoRecruitmentMedium medium;
  final int chargedAmount;
  final List<PublicDemoApplicant> generatedApplicants;
  final PublicDemoRecruitmentTransactionStatus status;

  bool get isSuccess =>
      status == PublicDemoRecruitmentTransactionStatus.success;
}
