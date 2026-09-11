import '../../domain/models/career_history_entry.dart';
import '../../domain/models/project.dart';
import '../../domain/models/sales_profile.dart' show Industry;
import '../models/client_interview.dart';
import '../models/recruitment_interview.dart';
import 'public_demo_assignment.dart';
import 'public_demo_engineer_runtime.dart';
import 'public_demo_fiscal_close_id.dart';
import 'public_demo_founder_follow_up.dart';
import 'public_demo_interview.dart';
import 'public_demo_internal_training_transaction.dart';
import 'public_demo_matching_proposal.dart';
import 'public_demo_monthly_close.dart';
import 'public_demo_project_generator.dart';
import 'public_demo_project_interview.dart';
import 'public_demo_raise_transaction.dart';
import 'public_demo_recovery.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_recruitment_candidate_generator.dart';
import 'public_demo_recruitment_interview.dart';
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
  /// below. [runSeed] threads straight through to [PublicDemoState
  /// .aprilStart] (SEEDED-RNG-REUSE-1): omitted for every real player, in
  /// which case a fresh seed is drawn there; a test may inject a fixed
  /// value instead so a reproducible run doesn't depend on wall-clock time.
  factory PublicDemoAggregate.initial({int? runSeed}) => PublicDemoAggregate._(
    state: PublicDemoState.aprilStart(runSeed: runSeed),
    workflow: PublicDemoWorkflowState.initial(),
  );

  final PublicDemoState state;
  final PublicDemoWorkflowState workflow;

  /// The stable per-playthrough seed (SEEDED-RNG-REUSE-1). Lives on [state]
  /// (not a third stored field here — this class's own doc above is
  /// explicit about atomically owning exactly [state] and [workflow], never
  /// a caller-suppliable third value) because it is itself just another
  /// already-authoritative, already-persisted fact about the current
  /// playthrough. Future independently-reproducible content streams
  /// (recruitment candidates, interviews, project generation) derive their
  /// own per-stream seed from this via `PublicDemoRng`
  /// (`public_demo_rng.dart`).
  int get runSeed => state.runSeed;

  /// CORE-GAMEPLAY Phase 4 (Random Projects): Phase 5 (Matching)'s query
  /// entry point for seeded project candidates. Purely derived from
  /// [runSeed]/[month] via [PublicDemoSeededProjectGenerator] — never
  /// stored, never read by [_validateForPersistence] (nothing here is
  /// persisted; the same call after a save/reload reproduces the exact same
  /// candidates).
  List<PublicDemoProjectCandidate> projectCandidatesForMonth(
    int month, {
    int count = PublicDemoSeededProjectGenerator.defaultSlotsPerMonth,
  }) => PublicDemoSeededProjectGenerator.forMonth(
    runSeed: runSeed,
    month: month,
    count: count,
  );

  /// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): every engineer
  /// currently eligible for the matching decision flow — every engineer
  /// this workflow knows about, minus whoever [PublicDemoWorkflowState
  /// .assignedEngineerIds] already reports as actively staffed this month,
  /// and minus anyone who has already reached `clientInterviewPassed`/
  /// `ordered` (Codex P1-2 fix, PR #214): such an engineer is done with
  /// Matching for this cycle — their proposal is now permanently locked to
  /// the project they were genuinely interviewed/passed for (see
  /// [PublicDemoWorkflowState.withMatchingProposal]'s own doc), so offering
  /// them here would only ever show a "提案する" that silently does nothing.
  /// Reuses the exact same SSOT sets rather than a second "is this engineer
  /// busy" definition.
  List<PublicDemoEngineerSales> get availableEngineersForMatching {
    final assignedIds = workflow.assignedEngineerIds(month: state.month);
    return [
      for (final engineer in workflow.engineers)
        if (!assignedIds.contains(engineer.id) &&
            engineer.stage != PublicDemoSalesStage.clientInterviewPassed &&
            engineer.stage != PublicDemoSalesStage.ordered)
          engineer,
    ];
  }

  /// The current proposal for [engineerId] (see
  /// [PublicDemoWorkflowState.matchingProposalFor]), or `null`.
  PublicDemoMatchingProposal? matchingProposalFor(String engineerId) =>
      workflow.matchingProposalFor(engineerId);

  /// Records the player's "提案する" decision for Phase 6 to pick up later
  /// (see [PublicDemoWorkflowState.withMatchingProposal]'s own doc for what
  /// this does and deliberately does not do). A no-op unless [engineerId]
  /// is currently available (per [availableEngineersForMatching]) and
  /// [projectId] actually names one of the candidates currently displayed
  /// for [PublicDemoState.month] (Codex P2 fix, PR #212: checking only that
  /// [PublicDemoSeededProjectGenerator.regenerate] returns non-`null` was
  /// insufficient — `regenerate` happily reconstructs a project for *any*
  /// syntactically valid `project-<month>-<slot>` id, including one from a
  /// different month or a slot index never actually offered this month, so
  /// that alone did not guarantee the id was ever something the player
  /// could have seen/selected). A caller cannot record a proposal for a
  /// fabricated project id, a different month's project, an out-of-range
  /// slot, or for an engineer already staffed elsewhere this month.
  PublicDemoAggregate proposeMatch({
    required String engineerId,
    required String projectId,
  }) {
    final assignedIds = workflow.assignedEngineerIds(month: state.month);
    if (assignedIds.contains(engineerId)) return this;
    if (workflow.engineers.every((engineer) => engineer.id != engineerId)) {
      return this;
    }
    final currentPoolIds = projectCandidatesForMonth(
      state.month,
    ).map((candidate) => candidate.id).toSet();
    if (!currentPoolIds.contains(projectId)) return this;
    return _copyWith(
      workflow: workflow.withMatchingProposal(
        engineerId: engineerId,
        projectId: projectId,
        month: state.month,
      ),
    );
  }

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
        (state.fiscalYearCompleted && state.month != 15) ||
        state.runSeed < 0) {
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
    final interviewSessionApplicantIds = workflow.interviewSessions
        .map((session) => session.applicantId)
        .toList();
    if (!_areUnique(engineerIds) ||
        !_areUnique(applicantIds) ||
        !_areUnique(runtimeIds) ||
        !_areUnique(assignmentIds) ||
        !_areUnique(interviewSessionApplicantIds) ||
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
  // CORE-GAMEPLAY Phase 3: interactive recruitment-interview session
  //
  // These commands run entirely AFTER [completeInterview] has already
  // consumed the real sales slot and minted the applicant's genuine
  // [PublicDemoInterviewRecord] above — they never consume another slot and
  // never re-decide `hasBeenInterviewed`. This is the interactive
  // question/answer step a player experiences before deciding whether to
  // actually extend an offer (existing [acceptOffer]/[PublicDemoSalaryOffer]
  // authority, untouched) or decline the candidate outright ([rejectApplicant]
  // wiring the same-named [PublicDemoApplicantStage.rejected] value below).
  // Every draw is reused verbatim from the main game's own
  // [RecruitmentInterviewEngine] via [PublicDemoRecruitmentInterview] —
  // see that file's own doc for the candidate-identity/legacy-fixture and
  // RNG-derivation contracts.
  // ---------------------------------------------------------------------

  /// Starts (or, if one already exists, leaves untouched) the interactive
  /// interview session for [applicantId]. A no-op unless the applicant
  /// genuinely completed the [completeInterview] paperwork step already
  /// (`hasBeenInterviewed`) — there is no way to reach the interactive
  /// question step without first paying its sales-slot cost.
  PublicDemoAggregate startInterviewSession(String applicantId) {
    final applicant = workflow.applicants
        .where((candidate) => candidate.id == applicantId)
        .firstOrNull;
    if (applicant == null || !applicant.hasBeenInterviewed) return this;
    if (workflow.interviewSessions.any(
      (session) => session.applicantId == applicantId,
    )) {
      return this;
    }
    final domainApplicant = PublicDemoRecruitmentInterview.domainApplicantFor(
      runSeed: runSeed,
      applicant: applicant,
    );
    final session = PublicDemoRecruitmentInterview.start(
      state: state,
      applicant: domainApplicant,
      companySize: workflow.engineers.length,
    );
    return _copyWith(workflow: workflow.startInterviewSession(session));
  }

  /// Asks [category] of [applicantId]'s active interview session — a no-op
  /// if that category was already asked, if the 3-question budget is
  /// already spent, or if no active session exists at all (mirrors
  /// [RecruitmentInterviewEngine.ask]'s own guards, applied by
  /// [PublicDemoWorkflowState.updateInterviewSession]'s "no active session"
  /// no-op).
  PublicDemoAggregate askInterviewQuestion(
    String applicantId,
    InterviewQuestionCategory category,
  ) {
    final applicant = workflow.applicants
        .where((candidate) => candidate.id == applicantId)
        .firstOrNull;
    if (applicant == null) return this;
    final domainApplicant = PublicDemoRecruitmentInterview.domainApplicantFor(
      runSeed: runSeed,
      applicant: applicant,
    );
    return _copyWith(
      workflow: workflow.updateInterviewSession(
        applicantId,
        (session) => PublicDemoRecruitmentInterview.ask(
          state: state,
          session: session,
          applicant: domainApplicant,
          category: category,
        ),
      ),
    );
  }

  /// Answers the applicant's own reverse question once all 3 forward
  /// questions have been asked — a no-op otherwise (mirrors
  /// [RecruitmentInterviewEngine.answerReverse]'s own guards).
  PublicDemoAggregate answerInterviewReverseQuestion(
    String applicantId,
    int choiceIndex,
  ) => _copyWith(
    workflow: workflow.updateInterviewSession(
      applicantId,
      (session) =>
          PublicDemoRecruitmentInterview.answerReverse(session, choiceIndex),
    ),
  );

  /// Concludes [applicantId]'s interview session with the player's own
  /// hire/reject read on the conversation — a no-op unless the session is
  /// genuinely conversation-complete (3 questions asked and the reverse
  /// question answered), mirroring the main game's own
  /// `GameEngine.completeRecruitmentInterview` guard.
  ///
  /// [InterviewOutcome.hired] only marks the session decided; the actual
  /// hire is still the existing, untouched [acceptOffer] flow — this phase
  /// does not add a second hiring calculation. [InterviewOutcome.rejected]
  /// additionally moves the applicant to [PublicDemoApplicantStage.rejected]
  /// via [PublicDemoWorkflowState.rejectApplicant], since a rejected
  /// candidate has no further pipeline step to reach on their own.
  PublicDemoAggregate concludeInterviewSession(
    String applicantId,
    InterviewOutcome outcome,
  ) {
    final index = workflow.interviewSessions.indexWhere(
      (session) => session.applicantId == applicantId && !session.completed,
    );
    if (index < 0 || !workflow.interviewSessions[index].conversationComplete) {
      return this;
    }
    final decided = workflow.updateInterviewSession(
      applicantId,
      (session) => session.copyWith(completed: true, outcome: outcome),
    );
    return _copyWith(
      workflow: outcome == InterviewOutcome.rejected
          ? decided.rejectApplicant(applicantId)
          : decided,
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

  // ---------------------------------------------------------------------
  // CORE-GAMEPLAY Phase 6 (Project Interview Gameplay): the interactive
  // 案件面談 entered from Phase 5's real matching-proposal handoff. Reuses
  // the existing `partnerInterviewPassed` → client-interview 0-slot stage
  // as-is (no new sales capacity, no double slot consumption) — see
  // `public_demo_workflow_state.dart`'s own section doc.
  // ---------------------------------------------------------------------

  /// Resolves [engineerId]'s current Phase 5 [PublicDemoMatchingProposal]
  /// back to its full [PublicDemoProjectCandidate] — `null` when no
  /// proposal has been made yet (or, in principle, an id this generator did
  /// not mint, which never happens for a genuine proposal). Every Phase 6
  /// screen reads the real project through this single accessor rather than
  /// re-deriving it.
  PublicDemoProjectCandidate? projectInterviewCandidateFor(String engineerId) {
    final proposal = workflow.matchingProposalFor(engineerId);
    if (proposal == null) return null;
    return PublicDemoSeededProjectGenerator.regenerate(
      runSeed: runSeed,
      projectId: proposal.projectId,
    );
  }

  /// The current in-progress/completed project-interview session for
  /// [engineerId], if any.
  ClientInterviewSession? projectInterviewSessionFor(String engineerId) =>
      workflow.projectInterviewSessionFor(engineerId);

  /// Starts (or resumes) the interactive project interview for
  /// [engineerId] — Phase 6's entry point from Phase 5's matching-proposal
  /// handoff. A no-op unless the engineer is genuinely at
  /// `partnerInterviewPassed` and a real Phase 5 proposal/project/runtime
  /// all resolve (an engineer who reached this stage without ever using
  /// Matching has no proposal at all, and stays on the existing generic
  /// [recordEngineerInterviewResult] path the UI falls back to).
  PublicDemoAggregate startProjectInterview(String engineerId) {
    final engineer = workflow.engineers
        .where((candidate) => candidate.id == engineerId)
        .firstOrNull;
    if (engineer == null ||
        engineer.stage != PublicDemoSalesStage.partnerInterviewPassed) {
      return this;
    }
    final candidate = projectInterviewCandidateFor(engineerId);
    final runtime = state.runtimeForOrNull(engineerId);
    if (candidate == null || runtime == null) return this;
    final session = PublicDemoProjectInterview.start(
      state: state,
      runtime: runtime,
      candidate: candidate,
    );
    return _copyWith(workflow: workflow.startProjectInterviewSession(session));
  }

  /// The player's follow-up choices for [engineerId]'s current interview
  /// question — `const []` if no session/candidate/runtime resolves.
  List<ClientInterviewFollowUp> projectInterviewChoicesFor(String engineerId) {
    final session = projectInterviewSessionFor(engineerId);
    if (session == null || session.completed) return const [];
    return PublicDemoProjectInterview.choicesFor(session);
  }

  /// Applies [followUp] to [engineerId]'s question at [questionIndex] and
  /// advances the session — see [PublicDemoProjectInterview.chooseFollowUp].
  /// A no-op unless a real proposal/project/runtime/in-progress session all
  /// resolve **for this exact [candidate]** (Codex P1 fix, PR #214):
  /// [candidate] always names the engineer's *current*
  /// [PublicDemoMatchingProposal] project, and is passed through as the
  /// [PublicDemoWorkflowState.updateProjectInterviewSession] `projectId`
  /// match — a session left over for a since-replaced proposal (a
  /// different project) is never advanced here.
  ///
  /// [questionIndex] (Codex P2 fix, PR #214) must be the index of the
  /// question the caller actually rendered/answered — the UI is required
  /// to capture this from the specific [ClientInterviewSession] snapshot it
  /// built the follow-up buttons from, never re-derive it from whatever the
  /// session's *current* state happens to be when the tap is finally
  /// processed. [PublicDemoProjectInterview.chooseFollowUp] rejects the
  /// call outright once that no longer matches the session's actual current
  /// question — see its own doc for exactly which duplicate/stale-
  /// submission shapes this closes, and why a UI-only disabled-button guard
  /// is insufficient on its own.
  PublicDemoAggregate chooseProjectInterviewFollowUp(
    String engineerId,
    int questionIndex,
    ClientInterviewFollowUp followUp,
  ) {
    final candidate = projectInterviewCandidateFor(engineerId);
    final runtime = state.runtimeForOrNull(engineerId);
    if (candidate == null || runtime == null) return this;
    return _copyWith(
      workflow: workflow.updateProjectInterviewSession(
        engineerId,
        candidate.id,
        (session) => PublicDemoProjectInterview.chooseFollowUp(
          runSeed: runSeed,
          runtime: runtime,
          project: candidate.project,
          session: session,
          questionIndex: questionIndex,
          followUp: followUp,
        ),
      ),
    );
  }

  /// Concludes [engineerId]'s fully-answered project interview and applies
  /// its genuine pass/fail to the sales pipeline — see
  /// [PublicDemoWorkflowState.concludeProjectInterview] for the actual
  /// derivation/precondition contract. A no-op unless a real
  /// proposal/project/runtime resolve.
  PublicDemoAggregate concludeProjectInterview(String engineerId) {
    final candidate = projectInterviewCandidateFor(engineerId);
    final runtime = state.runtimeForOrNull(engineerId);
    if (candidate == null || runtime == null) return this;
    return _copyWith(
      workflow: workflow.concludeProjectInterview(
        engineerId: engineerId,
        runSeed: runSeed,
        currentMonth: state.month,
        runtime: runtime,
        project: candidate.project,
      ),
    );
  }

  /// Issue #245 Phase B2 (Partner Interview Gameplay): starts (or resumes)
  /// the interactive partner interview for [engineerId] — the same real
  /// Phase 5 matching-proposal handoff Phase 6 uses, one stage earlier. A
  /// no-op unless the engineer is genuinely at `introduced` and a real
  /// Phase 5 proposal/project/runtime all resolve (an engineer who reached
  /// this stage without ever using Matching, or in a month with no real
  /// candidates, has no proposal at all and stays on the existing generic
  /// [recordEngineerInterviewResult] path the UI falls back to — mirrors
  /// [startProjectInterview]'s own fallback contract).
  ///
  /// Unlike Phase 6's client leg (an existing 0-slot step reusing
  /// `partnerInterviewPassed`), the partner leg still consumes exactly one
  /// real sales slot — the same [PublicDemoState.useSalesSlot] budget the
  /// pre-B2 generic [recordEngineerInterviewResult] partner path always
  /// consumed, never a new/second budget. Charged only on a genuinely NEW
  /// attempt (`workflow.startProjectInterviewSession` actually changed the
  /// session list — a fresh session, or replacing a stale *completed* one
  /// for a retry) — resuming the SAME still-incomplete session (identical
  /// `employeeId`/`projectId`/`startedWeek`, [startProjectInterviewSession]'s
  /// own no-op-resume rule) returns an unchanged `workflow` reference, which
  /// this detects via `identical` and never re-charges. A no-op with no
  /// slot spent when [state.salesRemaining] is already exhausted — mirrors
  /// the existing `上位会社面談` button's own enablement gate.
  PublicDemoAggregate startPartnerInterview(String engineerId) {
    final engineer = workflow.engineers
        .where((candidate) => candidate.id == engineerId)
        .firstOrNull;
    if (engineer == null || engineer.stage != PublicDemoSalesStage.introduced) {
      return this;
    }
    if (state.fiscalYearCompleted || state.salesRemaining <= 0) return this;
    final candidate = projectInterviewCandidateFor(engineerId);
    final runtime = state.runtimeForOrNull(engineerId);
    if (candidate == null || runtime == null) return this;
    final session = PublicDemoProjectInterview.start(
      state: state,
      runtime: runtime,
      candidate: candidate,
    );
    final nextWorkflow = workflow.startProjectInterviewSession(session);
    if (identical(nextWorkflow, workflow)) {
      // A genuine resume of the same in-progress session — no new attempt,
      // no new slot spent.
      return this;
    }
    return _copyWith(state: state.useSalesSlot(), workflow: nextWorkflow);
  }

  /// Issue #245 Phase B2 (Partner Interview Gameplay): concludes
  /// [engineerId]'s fully-answered partner interview and applies its
  /// genuine pass/fail to the sales pipeline — see [PublicDemoWorkflowState
  /// .concludePartnerProjectInterview] for the actual derivation/
  /// precondition contract. A no-op unless a real proposal/runtime resolve.
  PublicDemoAggregate concludePartnerInterview(String engineerId) {
    final candidate = projectInterviewCandidateFor(engineerId);
    final runtime = state.runtimeForOrNull(engineerId);
    if (candidate == null || runtime == null) return this;
    return _copyWith(
      workflow: workflow.concludePartnerProjectInterview(
        engineerId: engineerId,
        runSeed: runSeed,
        currentMonth: state.month,
        runtime: runtime,
        project: candidate.project,
      ),
    );
  }

  /// The 1-2 truthful reasons [engineerId]'s failed project interview did
  /// not pass, for the real project their [PublicDemoMatchingProposal]
  /// names — `const []` if no proposal/runtime resolves (should not happen
  /// once a session has actually completed).
  List<String> projectInterviewFailureReasonsFor(String engineerId) {
    final candidate = projectInterviewCandidateFor(engineerId);
    final runtime = state.runtimeForOrNull(engineerId);
    if (candidate == null || runtime == null) return const [];
    return PublicDemoProjectInterview.failureReasons(
      runtime,
      candidate.project,
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
  ///
  /// Issue #241 PR #242 review fix (P1): also requires
  /// `!applicant.hasJoined` here, at the [state]-mutating boundary — not
  /// only inside [PublicDemoWorkflowState.recordPreEntryPartnerInterviewResult].
  /// Without this, an applicant who genuinely joined mid-pipeline (see
  /// that method's own doc: `join` only requires a fiscal-close-matching
  /// offer, never a completed pre-entry chain, so `stage` can still read
  /// `preEntryIntroduced` after a real join) would still pass this method's
  /// `stage`/`salesRemaining` checks, consuming a real sales slot
  /// ([state.useSalesSlot]) even though the workflow-side call is already a
  /// no-op — a non-atomic partial mutation (state changes, workflow does
  /// not) for someone who is already a real employee.
  PublicDemoAggregate recordPreEntryPartnerInterviewResult(String applicantId) {
    final applicant = workflow.applicants
        .where((candidate) => candidate.id == applicantId)
        .firstOrNull;
    if (applicant == null) return this;
    if (applicant.stage != PublicDemoApplicantStage.preEntryIntroduced ||
        applicant.hasJoined) {
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

  /// The single sanctioned way to commit a late-year (internal month 7–14)
  /// Recovery order for one economically-waiting engineer
  /// (RECOVERY-LOOP-1 Final Spec). A no-op unless
  /// [PublicDemoRecoveryEligibility.isEligible] holds for [engineerId] —
  /// see its own doc for the full eligibility chain (month window,
  /// non-terminal, genuinely `ordered`, training-unselected, runtime-ready,
  /// not already assigned).
  ///
  /// On success, atomically:
  /// - appends/upserts ONLY [engineerId]'s own assignment via
  ///   [PublicDemoWorkflowState.recoverLateYearAssignment] — every other
  ///   engineer's assignment is carried forward untouched, never rebuilt
  ///   the way [PublicDemoWorkflowState.assignOrderedForMay] rebuilds
  ///   May's whole roster
  /// - sets that assignment's `nextOrderStatus: accepted` /
  ///   `replacementStage: ordered` explicitly, never relying on
  ///   [PublicDemoAssignment]'s own constructor defaults
  /// - re-projects [PublicDemoState.engineersAssigned]/[engineersWaiting]
  ///   from the resulting canonical
  ///   [PublicDemoWorkflowState.assignedEngineerIds] — the same projection
  ///   [_validateForPersistence] already requires to hold for month ≥ 6 —
  ///   rather than a bare +1/-1 delta, so HOME/UI never has to re-derive
  ///   these counts independently
  ///
  /// Finance is untouched by this method itself: [PublicDemoState.cash] and
  /// [PublicDemoState.pendingRevenue] do not change here. The existing
  /// month-end [PublicDemoMonthlyClose]/[PublicDemoRevenuePayment] path
  /// (reached through [closeOrdinaryMonth]/[closeJuly]) picks this engineer
  /// up naturally at the next month-end close, from the now-updated
  /// [PublicDemoState.engineersAssigned] — exactly like every other
  /// assigned engineer — preserving the existing revenue-recognition/AR/
  /// 30-day-collection contract without any Finance-formula change.
  PublicDemoAggregate recoverAssignment(String engineerId) {
    if (!PublicDemoRecoveryEligibility.isEligible(
      state: state,
      workflow: workflow,
      engineerId: engineerId,
    )) {
      return this;
    }
    final nextWorkflow = workflow.recoverLateYearAssignment(
      engineerId,
      month: state.month,
    );
    if (identical(nextWorkflow, workflow)) return this;
    final assignedIds = nextWorkflow.assignedEngineerIds(month: state.month);
    return _copyWith(
      state: state.copyWith(
        engineersAssigned: assignedIds.length,
        engineersWaiting: state.engineerCount - assignedIds.length,
      ),
      workflow: nextWorkflow,
    );
  }

  /// The single sanctioned way to end an assignment and release its
  /// engineer back to the real Sales pipeline (CORE-GAMEPLAY Phase 7A —
  /// see [PublicDemoWorkflowState.endAssignment]'s own doc for the full
  /// precondition/atomicity contract this delegates to). Mirrors
  /// [recoverAssignment]'s own re-projection pattern exactly: on success,
  /// atomically re-projects [PublicDemoState.engineersAssigned]/
  /// [engineersWaiting] from the resulting canonical
  /// [PublicDemoWorkflowState.assignedEngineerIds] (never a bare -1 delta),
  /// so [_validateForPersistence]'s month-≥-6 projection invariant always
  /// holds immediately after this call, exactly like every other
  /// assignment-roster-changing command. Finance is untouched (`cash`/
  /// `pendingRevenue` never change here): [PublicDemoWorkflowState
  /// .endAssignment] itself already guarantees `assignedEngineerIds(month:
  /// state.month)` — the exact set [PublicDemoRevenue
  /// .monthlyRevenueForAssignedCount] is keyed on — reports identically
  /// before and after this call (see that method's own doc for the
  /// month-aware deferred-removal contract this depends on), so
  /// re-projecting the count here can only ever confirm the same number,
  /// never book or drop revenue.
  ///
  /// CORE-GAMEPLAY Phase 7B (Career History / SkillSheet Growth): this is
  /// also the single production writer for [CareerHistoryEntry] — the
  /// "案件終了→案件経歴を記録" step of the growth loop. It fires exactly
  /// once per genuine assignment end: [ended] is captured BEFORE
  /// [PublicDemoWorkflowState.endAssignment] runs, and the write only
  /// happens in the same `!identical(nextWorkflow, workflow)` branch this
  /// method already requires to do anything — the exact guard that already
  /// makes a repeated call for the same ended assignment a structural
  /// no-op (see this method's own doc above), so a second, independent
  /// "already recorded" flag is not needed here.
  ///
  /// Records ONLY facts already authoritative elsewhere: [ended]'s own
  /// [PublicDemoAssignment.monthsCredited] (see its own doc — never a
  /// calendar span, never a lump-sum re-application of growth already
  /// applied monthly by [PublicDemoGrowthEngine]), and, when [ended]
  /// genuinely resolves to a real Phase 4/5 [Project]/[Client] via
  /// [PublicDemoSeededProjectGenerator.regenerate] (the exact same
  /// resolution [_industryByEngineerId] uses), that project's real title/
  /// industry/required-domain footprint and its client's real name. A
  /// `projectId`-less (generic/legacy) assignment still records its own
  /// real [PublicDemoAssignment.projectName] rather than nothing — a
  /// genuine domain fact, never fabricated here — but with no
  /// industry/client/technologies, exactly matching what is actually
  /// known. Skips writing an entry entirely when the recorded
  /// `experienceMonths` (below) is `0`: an assignment that never earned a
  /// single month of real, Growth-credited participation has no truthful
  /// "months of experience" to record, and a `0か月` placeholder would only
  /// be clutter, never a fact worth keeping.
  ///
  /// Codex P1 fix (PR #216): before month 7, [PublicDemoWorkflowState
  /// .endAssignment] deliberately LEAVES the ended row in place (see that
  /// method's own doc) because every assignment still counts toward the
  /// CURRENT month's revenue/Growth regardless of `nextOrderStatus` —
  /// meaning the very next month-end close (`closeApril`/`closeMay`/
  /// `closeJune`) will still credit this same, still-present row one more
  /// time before anything ever removes or supersedes it. Reading
  /// `ended.monthsCredited` alone at this point would freeze the recorded
  /// entry one month short of the truth the moment that close runs. So
  /// [experienceMonths] adds that one still-pending month whenever the
  /// row genuinely survives this call (`nextWorkflow.assignments` still
  /// names [engineerId] — the exact same fact that branch's own atomic
  /// `_copyWith` just decided) and this month's Growth has not already
  /// been applied (`state.growthAppliedMonths` — defensive: in every real
  /// production sequence a surviving row implies month < 7, which always
  /// precedes its own close). From month 7 on the row is always removed
  /// immediately instead (this method's own precondition already excludes
  /// `notOffered` from that month's filtered `assignedEngineerIds`), so
  /// `ended.monthsCredited` is already final there — no adjustment needed.
  PublicDemoAggregate endAssignment(String engineerId) {
    final ended = workflow.assignments
        .where((assignment) => assignment.engineerId == engineerId)
        .firstOrNull;
    final nextWorkflow = workflow.endAssignment(engineerId, month: state.month);
    if (identical(nextWorkflow, workflow)) return this;
    final assignedIds = nextWorkflow.assignedEngineerIds(month: state.month);
    final rowSurvives = nextWorkflow.assignments.any(
      (assignment) => assignment.engineerId == engineerId,
    );
    final hasPendingMonthCredit =
        rowSurvives &&
        !state.fiscalYearCompleted &&
        !state.growthAppliedMonths.contains(state.month);
    final experienceMonths =
        (ended?.monthsCredited ?? 0) + (hasPendingMonthCredit ? 1 : 0);
    final runtimes = ended == null || experienceMonths <= 0
        ? state.engineerRuntimes
        : [
            for (final runtime in state.engineerRuntimes)
              if (runtime.engineerId == engineerId)
                runtime.copyWith(
                  careerHistory: [
                    ...runtime.careerHistory,
                    _careerHistoryEntryFor(ended, runtime, experienceMonths),
                  ],
                )
              else
                runtime,
          ];
    return _copyWith(
      state: state.copyWith(
        engineerRuntimes: runtimes,
        engineersAssigned: assignedIds.length,
        engineersWaiting: state.engineerCount - assignedIds.length,
      ),
      workflow: nextWorkflow,
    );
  }

  /// See [endAssignment]'s own doc for exactly which facts this may/may not
  /// record. [assignment] is the just-ended [PublicDemoAssignment]
  /// (captured before [PublicDemoWorkflowState.endAssignment] removed or
  /// superseded it); [runtime] is that same engineer's current, pre-write
  /// [PublicDemoEngineerRuntime]. [experienceMonths] is [endAssignment]'s
  /// own already-adjusted figure — [assignment.monthsCredited] plus one
  /// still-pending month when the row survives this call (see
  /// [endAssignment]'s own doc for why `assignment.monthsCredited` alone
  /// can be one short) — never re-derived here. [CareerHistoryEntry
  /// .languages] is always exactly `[runtime.primaryLanguage]` — the one
  /// language [PublicDemoGrowthEngine] actually grew during this
  /// assignment (see its own doc), never [Project.requiredLanguages]
  /// verbatim, which can list a language this engineer never personally
  /// worked in.
  CareerHistoryEntry _careerHistoryEntryFor(
    PublicDemoAssignment assignment,
    PublicDemoEngineerRuntime runtime,
    int experienceMonths,
  ) {
    final projectId = assignment.projectId;
    final candidate = projectId == null
        ? null
        : PublicDemoSeededProjectGenerator.regenerate(
            runSeed: state.runSeed,
            projectId: projectId,
          );
    final project = candidate?.project;
    final projectName = project?.title ?? assignment.projectName;
    return CareerHistoryEntry(
      id: 'career-${assignment.engineerId}-${projectId ?? 'generic'}-m${state.month}',
      projectName: projectName,
      experienceMonths: experienceMonths,
      languages: [runtime.primaryLanguage],
      technologies: project == null ? const [] : _technologiesFor(project),
      industry: project?.industry,
      clientNameSnapshot: candidate?.client.name,
      summary: '$projectNameに$experienceMonthsか月間参画し、実務経験を積んだ。',
    );
  }

  /// Real, non-fabricated technology chips for [_careerHistoryEntryFor]:
  /// every skill domain [project] genuinely required at a non-zero level,
  /// under the exact same domain labels the SkillSheet's own tech-skill
  /// section already uses — never a free-text list [Project] has no field
  /// for.
  static List<String> _technologiesFor(Project project) => [
    if (project.requiredDatabase > 0) 'DB',
    if (project.requiredNetwork > 0) 'Network',
    if (project.requiredInfrastructure > 0) 'Infra',
    if (project.requiredFrontend > 0) 'Frontend',
    if (project.requiredBackend > 0) 'Backend',
    if (project.requiredLeader > 0) 'Leader',
    if (project.requiredManager > 0) 'Manager',
  ];

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

  /// The single sanctioned way to decide a founder follow-up for
  /// [engineerId] (Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1). A no-op
  /// unless [PublicDemoFounderFollowUp.isEligible] already holds for this
  /// engineer at the current month, the fiscal year is not completed, and —
  /// for [PublicDemoFounderFollowUpDecision.investSupport] specifically —
  /// [PublicDemoFounderFollowUp.investSupportCost] is actually affordable
  /// and not blocked by [PublicDemoState.isFinanciallyRestricted]
  /// (FINANCE-FAILURE-1A+1B), checked before cash is ever deducted, exactly
  /// like [selectInternalTraining] above. This is the only place cash is
  /// touched for this decision — [PublicDemoWorkflowState
  /// .applyFounderFollowUpDecision] only ever mutates the engineer's
  /// mental/trust/guard fields.
  PublicDemoAggregate applyFounderFollowUpDecision({
    required String engineerId,
    required PublicDemoFounderFollowUpDecision decision,
  }) {
    if (state.fiscalYearCompleted) return this;
    final engineer = workflow.engineers
        .where((candidate) => candidate.id == engineerId)
        .firstOrNull;
    if (engineer == null) return this;
    if (!PublicDemoFounderFollowUp.isEligible(
      engineer: engineer,
      month: state.month,
      assignedEngineerIds: workflow.assignedEngineerIds(month: state.month),
    )) {
      return this;
    }
    final cost = PublicDemoFounderFollowUp.costFor(decision);
    if (cost > 0 && (state.cash < cost || state.isFinanciallyRestricted)) {
      return this;
    }
    return _copyWith(
      // Booked as training spend — the same monthly bucket
      // [PublicDemoInternalTrainingTransaction] already uses — rather than a
      // new tracked-spend category: `PublicDemoSaveCodec`'s consistency
      // check requires every discretionary cash deduction to reconcile
      // against `monthOpeningCash - monthTrainingSpent -
      // monthRecruitmentSpent`, and this spend is conceptually the same
      // kind of optional employee-support cost internal training already
      // represents.
      state: cost > 0
          ? state.copyWith(cash: state.cash - cost).recordTrainingSpend(cost)
          : state,
      workflow: workflow.applyFounderFollowUpDecision(
        engineerId,
        month: state.month,
        decision: decision,
      ),
    );
  }

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

  /// Closes April (finance side; see below for the one workflow write this
  /// now also makes).
  ///
  /// FINANCE-FAILURE-1A+1B §5: the pre-AR-idempotency guard below runs
  /// before Growth, AR, salary, or cash are touched at all — a retry once
  /// [state.month] is no longer 4, or once [PublicDemoState.isCloseBlocked]
  /// (fiscal year completed or a terminal financial status reached), is a
  /// complete no-op returning this exact aggregate, never a partial
  /// mutation. Every other month-end command below follows the same shape.
  ///
  /// Issue #227 P1: also materializes a genuine April order's assignment
  /// here, via [PublicDemoWorkflowState.assignOrderedForMay] — the same
  /// domain authority [closeMay] already used, never a second assignment
  /// formula. Before this fix that call ran only inside [closeMay], so an
  /// engineer who genuinely won an April order (real `ordered` stage plus a
  /// genuine interview record) sat with no [PublicDemoAssignment] at all
  /// through the whole of May: Employee/Office status, training
  /// eligibility, and the active-project view all read
  /// [PublicDemoWorkflowState.assignments]/`assignedEngineerIds` — none of
  /// them agreed with the separate `engineersAssigned` revenue counter,
  /// which already counted this engineer correctly. Calling it here instead
  /// means May opens with that assignment already in place — no separate
  /// revenue/growth/payroll effect, since [orderedEngineers] below (and
  /// therefore [PublicDemoState.advanceToMay]'s own revenue projection)
  /// already read the identical `ordered`-stage fact before this fix, and
  /// [assignOrderedForMay] itself only ever reads engineer/applicant stage
  /// facts to decide the roster — it does not touch cash, growth, or
  /// payroll. [assignOrderedForMay]'s own doc covers why a later call in
  /// [closeMay] no longer discards this one's work.
  PublicDemoAggregate closeApril({required int monthlyExpenses}) {
    if (state.month != 4 || state.isCloseBlocked) return this;
    final grown = _closeGrowth(const {});
    return _copyWith(
      state: PublicDemoMonthlyClose.closeApril(
        state: grown.state,
        monthlyExpenses: monthlyExpenses,
        orderedEngineers: workflow.orderedEngineerCount,
      ).state,
      workflow: grown.workflow.assignOrderedForMay(),
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
    final grown = _closeGrowth(
      nextWorkflow.engineers
          .where((engineer) => engineer.stage == PublicDemoSalesStage.ordered)
          .map((engineer) => engineer.id)
          .toSet(),
      workflow: nextWorkflow,
    );
    final closedState = PublicDemoMonthlyClose.closeMay(
      state: grown.state,
      workflow: grown.workflow,
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
    return _copyWith(state: finalState, workflow: grown.workflow);
  }

  /// Closes June: also joins any applicant hired this month (Issue #221
  /// FIRST-FUN-YEAR — see [_joinAcceptedApplicants]) before Growth and the
  /// finance close run.
  PublicDemoAggregate closeJune({
    required int assignedInJuly,
    required int monthlyExpenses,
  }) {
    if (state.month != 6 || state.isCloseBlocked) return this;
    final joined = _joinAcceptedApplicants();
    final grown = _closeGrowth(
      joined.workflow.assignments
          .map((assignment) => assignment.engineerId)
          .toSet(),
      workflow: joined.workflow,
    );
    final closedState = PublicDemoMonthlyClose.closeJune(
      state: grown.state.recordNewJoins(
        joined.newlyJoined,
        joinedWithOrders: joined.newlyJoinedWithOrders,
      ),
      monthlyExpenses: monthlyExpenses,
      // [advanceToJuly] (via this facade) overwrites engineersAssigned
      // outright from this param — it never sees state.recordNewJoins's
      // own additive engineersAssigned above — so a newly joined
      // juneOrdered hire's assignment must be folded in here too, on top
      // of the caller's own (pre-join) continuation-decision count, or
      // they would be counted as waiting for this one month despite
      // already having a real assignment on [joined.workflow.assignments].
      assignedInJuly: assignedInJuly + joined.newlyJoinedWithOrders,
    ).state;
    return _copyWith(
      state: _withNewEngineerRuntimes(closedState, joined.newlyJoined),
      workflow: grown.workflow,
    );
  }

  /// Closes July (reads `workflow.joinedApplicants` — the full
  /// authoritative derived set, never a caller-chosen subset — for the
  /// summer bonus itself; an applicant hired this same July joins
  /// alongside it, exactly like [closeJune], but starts payroll/bonus
  /// eligibility next month, matching how a new hire never back-dates into
  /// the very month they joined).
  ///
  /// The zero plan always permits the mandatory close, including a negative
  /// result. An unaffordable paid plan is rejected before Growth, AR, or any
  /// expense — or this month's join — is applied: see
  /// [PublicDemoMonthlyClose.closeJuly].
  PublicDemoAggregate closeJuly({required int monthlyExpenses}) {
    if (state.month != 7 || state.isCloseBlocked) return this;
    final preview = PublicDemoMonthlyClose.previewJuly(
      state: state,
      monthlyExpenses: monthlyExpenses,
      applicants: workflow.joinedApplicants,
      plan: state.summerBonusSelection,
    );
    if (!preview.isEligible) return this;
    final joined = _joinAcceptedApplicants();
    final grown = _closeGrowth(
      joined.workflow.assignments
          .where(
            (assignment) =>
                assignment.nextOrderStatus ==
                    PublicDemoNextOrderStatus.accepted ||
                assignment.replacementStage ==
                    PublicDemoReplacementStage.ordered,
          )
          .map((assignment) => assignment.engineerId)
          .toSet(),
      workflow: joined.workflow,
    );
    final closedState = PublicDemoMonthlyClose.closeJuly(
      state: grown.state.recordNewJoins(
        joined.newlyJoined,
        joinedWithOrders: joined.newlyJoinedWithOrders,
      ),
      monthlyExpenses: monthlyExpenses,
      applicants: workflow.joinedApplicants,
    ).state;
    return _copyWith(
      state: _withNewEngineerRuntimes(closedState, joined.newlyJoined),
      workflow: grown.workflow,
    );
  }

  /// Closes any ordinary month from August through March: also joins any
  /// applicant hired this month (Issue #221 FIRST-FUN-YEAR), exactly like
  /// [closeJune]/[closeJuly] — recruitment media stays legal through month 8
  /// ([PublicDemoState.canUseRecruitmentMediaInMonth]), so an August hire
  /// joins here at month 8's own close; later months keep this generalized
  /// too, since nothing prevents an already-accepted offer from a prior
  /// month reaching this close instead (e.g. a retried/delayed close).
  PublicDemoAggregate closeOrdinaryMonth({required int monthlyExpenses}) {
    if (state.month < 8 || state.month > 15 || state.isCloseBlocked) {
      return this;
    }
    final joined = _joinAcceptedApplicants();
    final grown = _closeGrowth(
      joined.workflow.assignedEngineerIds(month: state.month),
      workflow: joined.workflow,
    );
    final closedState = PublicDemoMonthlyClose.closeOrdinaryMonth(
      state: grown.state.recordNewJoins(
        joined.newlyJoined,
        joinedWithOrders: joined.newlyJoinedWithOrders,
      ),
      monthlyExpenses: monthlyExpenses,
    ).state;
    return _copyWith(
      state: _withNewEngineerRuntimes(closedState, joined.newlyJoined),
      workflow: grown.workflow,
    );
  }

  /// Joins every applicant with a genuinely accepted offer for this
  /// aggregate's current month and folds them into the authoritative
  /// engineer roster (Issue #221 FIRST-FUN-YEAR: generalizes [closeMay]'s
  /// founding-cohort join step — previously the only month-end close that
  /// ever joined anyone — to every later month-end close, so a June-or-later
  /// hire actually becomes an employee too, not just May's cohort).
  ///
  /// Unlike [closeMay]'s `joinAndKeepOnly`, this never prunes
  /// [PublicDemoWorkflowState.applicants] down to the accepted subset: that
  /// pruning was a one-time founding-cohort cutoff specific to May, and
  /// recruitment keeps running every month after that — see
  /// [PublicDemoWorkflowState.joinAcceptedForFiscalClose]'s own doc.
  ///
  /// A newly joined applicant who also already won a pre-entry order
  /// ([PublicDemoWorkflowState.appendPreEntryOrderAssignments]) gets a real
  /// assignment here too — PR #222 review finding: without this, that
  /// already-earned order was silently discarded, downgrading them to a
  /// plain waiting engineer forced to redo Sales/Matching from scratch.
  /// [newlyJoinedWithOrders] reports how many, so callers can fold them
  /// into the headcount/assigned projection ([PublicDemoState
  /// .recordNewJoins]) exactly like May's own `juneOrdered` cohort.
  ///
  /// Callers below still finish the headcount/roster projection themselves
  /// — via [PublicDemoState.recordNewJoins] and [_withNewEngineerRuntimes]
  /// — using [newlyJoined]/[newlyJoinedWithOrders], because each caller
  /// commits its own [PublicDemoState] at a different point (before/after
  /// Growth, before/after the summer-bonus preview gate).
  ({
    PublicDemoWorkflowState workflow,
    List<PublicDemoApplicant> newlyJoined,
    int newlyJoinedWithOrders,
  })
  _joinAcceptedApplicants() {
    final nextWorkflow = workflow.joinAcceptedForFiscalClose(
      week: state.month * 4,
      currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(state.month),
    );
    final newlyJoined = nextWorkflow.applicants
        .where(
          (applicant) =>
              applicant.hasJoined &&
              !state.joinedApplicantIds.contains(applicant.id),
        )
        .toList();
    if (newlyJoined.isEmpty) {
      return (
        workflow: nextWorkflow,
        newlyJoined: newlyJoined,
        newlyJoinedWithOrders: 0,
      );
    }
    final newlyJoinedWithOrders = newlyJoined
        .where(
          (applicant) =>
              applicant.stage == PublicDemoApplicantStage.juneOrdered,
        )
        .length;
    return (
      workflow: nextWorkflow
          .withJoinedEngineers(newlyJoined)
          .appendPreEntryOrderAssignments(newlyJoined),
      newlyJoined: newlyJoined,
      newlyJoinedWithOrders: newlyJoinedWithOrders,
    );
  }

  /// Appends an engineer runtime for each of [newlyJoined] to [state]'s own
  /// (already up to date) [PublicDemoEngineerRuntime] list — the same
  /// append [closeMay] already performs for May's cohort, reused here for
  /// every later month-end close.
  PublicDemoState _withNewEngineerRuntimes(
    PublicDemoState state,
    List<PublicDemoApplicant> newlyJoined,
  ) => newlyJoined.isEmpty
      ? state
      : state.copyWith(
          engineerRuntimes: [
            ...state.engineerRuntimes,
            for (final applicant in newlyJoined)
              PublicDemoEngineerRuntime.fromApplicant(applicant),
          ],
        );

  /// This is called only by the month-end commands above, after all
  /// current-month work/contract decisions and before the next month
  /// transition — mirrors the pre-cutover widget's own `_closeGrowth`
  /// helper exactly, including reading `moraleByEngineerId` from THIS
  /// aggregate's own (pre-transition) [workflow], never [workflow]'s
  /// [workflow] parameter override below.
  ///
  /// CORE-GAMEPLAY Phase 7B: also feeds each currently-assigned engineer's
  /// genuine project [Industry] (via [_industryByEngineerId]) into the same
  /// Growth call — see [PublicDemoState.applyMonthlyGrowth]'s own doc — and,
  /// only when Growth actually changed something this month (never on a
  /// fiscalYearCompleted/already-applied-month no-op), credits
  /// [PublicDemoWorkflowState.creditAssignmentMonths] with the exact same
  /// [assignedEngineerIds] set, so [PublicDemoAssignment.monthsCredited]
  /// stays in lockstep with Growth's own once-per-month application — never
  /// a second, independently-gated counter. [workflow] lets [closeMay]
  /// resolve/credit against its own post-join/post-assignment roster
  /// (`nextWorkflow`) rather than this aggregate's pre-transition one, the
  /// same split the pre-existing `moraleByEngineerId` comment above already
  /// documents; every other caller omits it and gets [this.workflow].
  /// Returns both halves atomically — no caller may apply the state half
  /// without the workflow half, or vice versa.
  ({PublicDemoState state, PublicDemoWorkflowState workflow}) _closeGrowth(
    Set<String> assignedEngineerIds, {
    PublicDemoWorkflowState? workflow,
  }) {
    final effectiveWorkflow = workflow ?? this.workflow;
    final grownState = state.applyMonthlyGrowth(
      assignedEngineerIds: assignedEngineerIds,
      moraleByEngineerId: this.workflow.moraleByEngineerId,
      industryByEngineerId: _industryByEngineerId(
        assignedEngineerIds,
        workflow: effectiveWorkflow,
      ),
    );
    return (
      state: grownState,
      workflow: identical(grownState, state)
          ? effectiveWorkflow
          : effectiveWorkflow.creditAssignmentMonths(assignedEngineerIds),
    );
  }

  /// CORE-GAMEPLAY Phase 7B: the real [Industry] of every currently-assigned
  /// engineer's genuine Phase 6 project-bound assignment, resolved purely
  /// from `(state.runSeed, PublicDemoAssignment.projectId)` via
  /// [PublicDemoSeededProjectGenerator.regenerate] — the exact same
  /// resolution [PublicDemoAggregate.endAssignment] uses for its
  /// [CareerHistoryEntry], so both share one derivation instead of two that
  /// could quietly drift apart. Omits any engineer whose assignment has no
  /// `projectId` (the generic, project-agnostic path — see that field's own
  /// doc) or whose id resolves to nothing: never a fabricated industry.
  Map<String, Industry> _industryByEngineerId(
    Set<String> assignedEngineerIds, {
    required PublicDemoWorkflowState workflow,
  }) {
    final result = <String, Industry>{};
    for (final assignment in workflow.assignments) {
      if (!assignedEngineerIds.contains(assignment.engineerId)) continue;
      final projectId = assignment.projectId;
      if (projectId == null) continue;
      final candidate = PublicDemoSeededProjectGenerator.regenerate(
        runSeed: state.runSeed,
        projectId: projectId,
      );
      if (candidate != null) {
        result[assignment.engineerId] = candidate.project.industry;
      }
    }
    return result;
  }
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
  }) : _candidateGenerator = candidateGenerator;

  /// Null means "use the production default" -- resolved inside [execute],
  /// not at construction time, because the default (CORE-GAMEPLAY Phase 2:
  /// seeded recruitment) needs [PublicDemoState.runSeed], which is only
  /// available once a [state] is actually supplied to [execute]. This
  /// keeps the public [PublicDemoRecruitmentCandidateGenerator] typedef
  /// itself unchanged (still just `(month, medium, count)`), so every
  /// existing test/caller that substitutes its own generator is unaffected.
  final PublicDemoRecruitmentCandidateGenerator? _candidateGenerator;

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

    final generator = _candidateGenerator ?? _defaultGenerator(state.runSeed);
    final applicants = generator(
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

  /// Production default (CORE-GAMEPLAY Phase 2): reuses the main engine's
  /// [ApplicantGenerator] via [PublicDemoSeededRecruitmentGenerator], seeded
  /// from this playthrough's own [PublicDemoState.runSeed], instead of the
  /// fixed/cyclic template pool this generator replaced (see
  /// `docs/reports/SES_CORE-GAMEPLAY_Phase2_Random-Recruitment_Result.md`).
  static PublicDemoRecruitmentCandidateGenerator _defaultGenerator(
    int runSeed,
  ) =>
      ({required month, required medium, required count}) =>
          PublicDemoSeededRecruitmentGenerator.generate(
            runSeed: runSeed,
            month: month,
            medium: medium,
            count: count,
          );
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
