import 'public_demo_assignment.dart';
import 'public_demo_engineer_runtime.dart';
import 'public_demo_fiscal_close_id.dart';
import 'public_demo_interview.dart';
import 'public_demo_monthly_close.dart';
import 'public_demo_raise_transaction.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_recruitment_medium.dart';
import 'public_demo_sales.dart';
import 'public_demo_salary_offer.dart';
import 'public_demo_state.dart';
import 'public_demo_summer_bonus_plan.dart';
import 'public_demo_workflow_state.dart';

/// The single authoritative Public Demo 0.1 root (WORKFLOW-STATE-1AB FIX3):
/// atomically owns both finance/monthly-close facts ([state]) and workflow
/// facts ([workflow]) as one unit.
///
/// FIX2 still let a caller obtain [PublicDemoState]/[PublicDemoWorkflowState]
/// as two independently-committable values — a recruitment
/// `onCommitted(state, workflow)` callback that a caller could apply only
/// one half of, a `closeMay(..., joinedApplicants: ...)` caller-chosen
/// iterable, a public `PublicDemoWorkflowState(..., assignments: ...)`
/// factory, and a zero-argument `PublicDemoApplicant.markInterviewed()`.
/// FIX3 closes all four by making this class the only place gameplay code
/// holds workflow/finance state: every authority-significant transition is
/// a method here that takes the current aggregate (`this`) and returns the
/// next one, atomically, or a result whose only way to reach the next
/// aggregate is a single field. [PublicDemo01PlaceholderScreen] keeps
/// exactly one field of this type and only ever replaces it wholesale.
///
/// This class deliberately does NOT expose a generic
/// `withState(PublicDemoState Function(PublicDemoState) update)` /
/// `withWorkflow(...)`-style combinator: a caller-supplied transform can
/// simply ignore the value it is given and return an arbitrary fabricated
/// one instead (the same structural flaw FIX3 closed for
/// `PublicDemoWorkflowState.withAssignment` — see its doc), which would
/// silently reopen the very "two independently authoritative roots"
/// problem this class exists to close. Every method below is instead a
/// named, specific transition that only ever composes already-safe,
/// already-audited operations on [state]/[workflow] — never a caller
/// closure.
class PublicDemoAggregate {
  const PublicDemoAggregate._({required this.state, required this.workflow});

  /// Public Demo 0.1's starting aggregate.
  factory PublicDemoAggregate.initial() => PublicDemoAggregate._(
    state: PublicDemoState.aprilStart(),
    workflow: PublicDemoWorkflowState.initial(),
  );

  /// Restore-only reconstruction boundary: for test fixtures and any future
  /// save/load deserialization, never for a live gameplay transition. Every
  /// other method on this class computes the next aggregate from the
  /// current one via an already-validated domain command; this is the sole
  /// escape hatch that accepts an arbitrary [state]/[workflow] pair
  /// directly, and [PublicDemo01PlaceholderScreen] never calls it.
  factory PublicDemoAggregate.restore({
    required PublicDemoState state,
    required PublicDemoWorkflowState workflow,
  }) => PublicDemoAggregate._(state: state, workflow: workflow);

  final PublicDemoState state;
  final PublicDemoWorkflowState workflow;

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
    final nextWorkflow = workflow.withApplicant(
      applicantId,
      (candidate) => candidate.completeInterview(proof),
    );
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
  PublicDemoRecruitmentTransactionResult recruit(
    PublicDemoRecruitmentMedium medium, {
    PublicDemoRecruitmentCandidateGenerator? candidateGenerator,
  }) {
    final calculation = _PublicDemoRecruitmentCalculation(
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

  /// Replaces [state] with an already-computed value from a trusted,
  /// single-root finance transaction (e.g.
  /// [PublicDemoInternalTrainingTransaction]) — [workflow] is untouched.
  /// Unlike a generic `withWorkflow`, this does not reopen any of FIX3's
  /// four closed gaps: none of P1-1/2/3/4 concerned finance-only field
  /// values, only whether a recruitment/interview/month-close command
  /// paired cash and workflow atomically, or whether the workflow's own
  /// applicant/assignment membership could be truncated or substituted —
  /// this method touches neither, so it is safe as a raw-value passthrough
  /// where the analogous `withWorkflow` deliberately does not exist (see
  /// class doc).
  PublicDemoAggregate withState(PublicDemoState newState) =>
      _copyWith(state: newState);

  // ---------------------------------------------------------------------
  // Offer / applicant / engineer / assignment value transitions
  // (safe, single-root passthroughs — see class doc for why these remain
  // named methods rather than a generic combinator)
  // ---------------------------------------------------------------------

  /// The single sanctioned way to accept a salary offer for one applicant
  /// (WORKFLOW-STATE-1 §11).
  PublicDemoAggregate acceptOffer({
    required String applicantId,
    required PublicDemoSalaryOffer offer,
    required PublicDemoFiscalCloseId fiscalCloseId,
  }) => _copyWith(
    workflow: workflow.acceptOffer(
      applicantId: applicantId,
      offer: offer,
      fiscalCloseId: fiscalCloseId,
    ),
  );

  PublicDemoAggregate withEngineerStage(
    String engineerId,
    PublicDemoSalesStage stage,
  ) => _copyWith(workflow: workflow.withEngineerStage(engineerId, stage));

  PublicDemoAggregate withApplicantStage(
    String applicantId,
    PublicDemoApplicantStage stage,
  ) => _copyWith(workflow: workflow.withApplicantStage(applicantId, stage));

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

  /// Consumes one sales slot (a no-op past budget/fiscal completion, same
  /// as [PublicDemoState.useSalesSlot]) and sets [applicantId]'s pre-entry
  /// stage together — the shape the pre-entry partner-interview flow needs.
  /// Not authority-significant: unlike interview completion (P1-1), no
  /// downstream command gates on this stage transition alone.
  PublicDemoAggregate consumeSlotAndSetApplicantStage(
    String applicantId,
    PublicDemoApplicantStage stage,
  ) => _copyWith(
    state: state.useSalesSlot(),
    workflow: workflow.withApplicantStage(applicantId, stage),
  );

  /// Consumes one sales slot only for [PublicDemoInterviewType.partner]
  /// (mirroring the pre-cutover widget's own `ei()` handler exactly) and
  /// records the engineer sales-pipeline interview outcome together.
  PublicDemoAggregate applyEngineerInterviewResult({
    required String engineerId,
    required PublicDemoInterviewType type,
    required PublicDemoSalesStage stage,
    required int score,
  }) => _copyWith(
    state: type == PublicDemoInterviewType.partner
        ? state.useSalesSlot()
        : state,
    workflow: workflow.withEngineer(
      engineerId,
      (engineer) => engineer.copyWith(stage: stage, lastInterviewScore: score),
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
  PublicDemoAggregate applyRaiseDecision(
    String applicantId, {
    required int decisionMonth,
    required int week,
    required PublicDemoRaiseDecision decision,
  }) => _copyWith(
    workflow: workflow.withApplicant(
      applicantId,
      (applicant) => const PublicDemoRaiseTransaction()
          .execute(
            state: state,
            applicant: applicant,
            decisionMonth: decisionMonth,
            week: week,
            decision: decision,
          )
          .applicant,
    ),
  );

  PublicDemoAggregate selectSummerBonus(PublicDemoSummerBonusPlan plan) =>
      _copyWith(state: state.selectSummerBonus(plan));

  // ---------------------------------------------------------------------
  // Month-end transitions
  // ---------------------------------------------------------------------

  /// Closes April (state-only; workflow is not part of April's transition).
  PublicDemoAggregate closeApril({required int monthlyExpenses}) => _copyWith(
    state: PublicDemoMonthlyClose.closeApril(
      state: _closeGrowth(const {}),
      monthlyExpenses: monthlyExpenses,
      orderedEngineers: workflow.engineers
          .where((engineer) => engineer.stage == PublicDemoSalesStage.ordered)
          .length,
    ).state,
  );

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
  }) => _copyWith(
    state: PublicDemoMonthlyClose.closeJune(
      state: _closeGrowth(
        workflow.assignments.map((assignment) => assignment.engineerId).toSet(),
      ),
      monthlyExpenses: monthlyExpenses,
      assignedInJuly: assignedInJuly,
    ).state,
  );

  /// Closes July (state-only; reads `workflow.joinedApplicants` — the full
  /// authoritative derived set, never a caller-chosen subset).
  PublicDemoAggregate closeJuly({required int monthlyExpenses}) => _copyWith(
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

  /// Closes any ordinary month from August through March (state-only).
  PublicDemoAggregate closeOrdinaryMonth({required int monthlyExpenses}) =>
      _copyWith(
        state: PublicDemoMonthlyClose.closeOrdinaryMonth(
          state: _closeGrowth(workflow.assignedEngineerIds(month: state.month)),
          monthlyExpenses: monthlyExpenses,
        ).state,
      );

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
}

/// Pure, all-or-nothing recruitment-media purchase calculation. Private to
/// this file: the only caller is [PublicDemoAggregate.recruit], which always
/// commits both of this class's outputs (cash and generated applicants)
/// together into one new aggregate.
class _PublicDemoRecruitmentCalculation {
  const _PublicDemoRecruitmentCalculation({
    PublicDemoRecruitmentCandidateGenerator? candidateGenerator,
  }) : _candidateGenerator = candidateGenerator ?? _generateApplicants;

  final PublicDemoRecruitmentCandidateGenerator _candidateGenerator;

  _PublicDemoRecruitmentCalculationResult execute({
    required PublicDemoState state,
    required PublicDemoRecruitmentMedium medium,
  }) {
    if (!state.canUseRecruitmentMediaInMonth(state.month)) {
      return _PublicDemoRecruitmentCalculationResult._(
        state: state,
        medium: medium,
        chargedAmount: 0,
        generatedApplicants: const [],
        status: PublicDemoRecruitmentTransactionStatus.alreadyUsedThisMonth,
      );
    }
    if (state.cash < medium.cost) {
      return _PublicDemoRecruitmentCalculationResult._(
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
      return _PublicDemoRecruitmentCalculationResult._(
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
    return _PublicDemoRecruitmentCalculationResult._(
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

class _PublicDemoRecruitmentCalculationResult {
  const _PublicDemoRecruitmentCalculationResult._({
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
