import 'public_demo_assignment.dart';
import 'public_demo_binding_offer.dart';
import 'public_demo_fiscal_close_id.dart';
import 'public_demo_interview.dart';
import 'public_demo_join.dart';
import 'public_demo_raise_transaction.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_sales.dart';
import 'public_demo_salary_offer.dart';
import 'public_demo_state.dart';

/// The single authoritative source for Public Demo 0.1 workflow facts:
/// applicants (and their recruitment/pre-entry stage, offer, binding offer,
/// and join state), engineer sales-pipeline state, and project assignments.
///
/// Before WORKFLOW-STATE-1A+B, [PublicDemo01PlaceholderScreen] held these
/// three lists as mutable `State` fields and mutated them directly by list
/// index. That made the widget itself the workflow SSOT, with no
/// invariant enforcement beyond whatever the UI happened to check before
/// calling `setState`. This class now owns that data; since
/// WORKFLOW-STATE-1AB FIX3, the widget holds exactly one
/// `PublicDemoAggregate` field (public_demo_aggregate.dart) that atomically
/// contains this workflow together with the finance side
/// ([PublicDemoState]), and only ever replaces it wholesale — using the
/// domain methods below (or the dedicated commands in
/// public_demo_binding_offer.dart / public_demo_join.dart /
/// public_demo_aggregate.dart) to compute the next value. UI-only concerns
/// (selected tab, dialog visibility, scroll position, the in-progress July
/// summer-bonus confirmation flag) remain widget-local `State` fields —
/// they are not workflow facts.
class PublicDemoWorkflowState {
  /// Safe production construction (WORKFLOW-STATE-1AB FIX3 P1-3):
  /// deliberately has no `assignments` parameter — an arbitrary assignment
  /// roster must never be accepted while constructing an authoritative
  /// workflow root, only produced by [assignOrderedForMay] below, which
  /// computes it from this workflow's own authoritative engineer/applicant
  /// stage facts. Removing `copyWith(assignments:)` alone (FIX1) was
  /// insufficient while this public factory still accepted one directly
  /// (FIX2's residual gap) — it no longer does.
  factory PublicDemoWorkflowState({
    required List<PublicDemoApplicant> applicants,
    required List<PublicDemoEngineerSales> engineers,
  }) => PublicDemoWorkflowState._(
    applicants: List.unmodifiable(applicants),
    engineers: List.unmodifiable(engineers),
    assignments: const [],
  );

  const PublicDemoWorkflowState._({
    required this.applicants,
    required this.engineers,
    required this.assignments,
  });

  /// Public Demo 0.1's starting workflow, matching the founding team and
  /// established applicant pool that predate this class (exactly the values
  /// [PublicDemo01PlaceholderScreen]'s own `State` fields used to default
  /// to).
  factory PublicDemoWorkflowState.initial() => PublicDemoWorkflowState(
    applicants: publicDemoMayApplicants,
    engineers: publicDemoInitialEngineers,
  );

  final List<PublicDemoApplicant> applicants;
  final List<PublicDemoEngineerSales> engineers;
  final List<PublicDemoAssignment> assignments;

  /// Complete workflow persistence representation.  This is intentionally
  /// separate from the production constructor: an assignment roster is only
  /// restored from a validated aggregate save, never supplied by gameplay
  /// callers.
  Map<String, dynamic> toJson() => {
    'applicants': applicants.map((applicant) => applicant.toJson()).toList(),
    'engineers': engineers.map((engineer) => engineer.toJson()).toList(),
    'assignments': assignments.map((assignment) => assignment.toJson()).toList(),
  };

  factory PublicDemoWorkflowState.fromJson(Map<String, dynamic> json) {
    List requiredList(String key) {
      final value = json[key];
      if (value is! List) throw FormatException('Invalid workflow $key');
      return value;
    }

    List<T> decodeList<T>(List raw, T Function(Map<String, dynamic>) decode) =>
        raw.map((entry) {
          if (entry is! Map) throw const FormatException('Invalid workflow entry');
          return decode(entry.cast<String, dynamic>());
        }).toList();

    return PublicDemoWorkflowState._(
      applicants: List.unmodifiable(
        decodeList(requiredList('applicants'), PublicDemoApplicant.fromJson),
      ),
      engineers: List.unmodifiable(
        decodeList(requiredList('engineers'), PublicDemoEngineerSales.fromJson),
      ),
      assignments: List.unmodifiable(
        decodeList(requiredList('assignments'), PublicDemoAssignment.fromJson),
      ),
    );
  }

  // WORKFLOW-STATE-1AB FIX4 P1-2: the FIX3 `.restore(...)` reconstruction
  // factory (applicants/engineers/assignments accepted verbatim) was itself
  // still a PUBLIC production-reachable API — commenting it "restore-only"
  // did not actually stop a caller from calling it to inject a fabricated
  // assignment roster. It has been removed entirely, along with the public
  // `copyWith(applicants:, engineers:)` this file used to expose (WORKFLOW-
  // STATE-1AB FIX2 P1-3's own doc comment already noted `assignments` was
  // deliberately absent from it, but the method itself remaining public
  // still let a caller wholesale-replace the applicant/engineer lists,
  // which is enough to omit/duplicate/reorder existing entries). Every
  // caller outside this file must now go through the named, field-specific
  // methods below (`withGeneratedApplicants`, `joinAndKeepOnly`,
  // `withJoinedEngineers`, the named engineer/applicant stage-transition
  // methods (WORKFLOW-STATE-1AB FIX5/FIX6 P1 — see their own section
  // docs), `withAssignmentUpdate`, `assignOrderedForMay`) — [_copyWith] is
  // private, used only by them.
  //
  // WORKFLOW-STATE-1AB FIX6 P1: `withEngineer`/`withApplicant` themselves
  // were PUBLIC generic callback mutators — `workflow.withEngineer(id, (e)
  // => e.copyWith(stage: ordered, lastInterviewScore: 80))` (independent
  // review's confirmed Attack A) could set any authoritative fact on any
  // entity with no precondition check at all, entirely independent of
  // which specific closures this file's own transitions happened to pass
  // it. Both are now private (`_withEngineer`/`_withApplicant`) — every
  // caller outside this file goes through the named transitions below
  // instead, none of which accepts a caller-supplied closure or a whole
  // caller-supplied entity value.
  // There is no test-fixture escape hatch here any more either: test
  // fixtures needing a specific workflow now build it by chaining these
  // same real methods, exactly as production code does.
  PublicDemoWorkflowState _copyWith({
    List<PublicDemoApplicant>? applicants,
    List<PublicDemoEngineerSales>? engineers,
    List<PublicDemoAssignment>? assignments,
  }) => PublicDemoWorkflowState._(
    applicants: List.unmodifiable(applicants ?? this.applicants),
    engineers: List.unmodifiable(engineers ?? this.engineers),
    assignments: List.unmodifiable(assignments ?? this.assignments),
  );

  // ---------------------------------------------------------------------
  // Applicants
  // ---------------------------------------------------------------------

  /// Replaces the applicant identified by [applicantId] using [update].
  /// A missing id is a no-op — every call site already has the applicant's
  /// current record in hand, so a missing id would indicate a caller bug
  /// rather than a real workflow event.
  ///
  /// Private to this file (WORKFLOW-STATE-1AB FIX6 P1): a caller-supplied
  /// [update] closure could set any authoritative fact — `stage`,
  /// `lastInterviewScore`/`interviewRecord` on the engineer side — with no
  /// precondition check at all. Every caller outside this file goes
  /// through the named, precondition-gated transitions below instead.
  PublicDemoWorkflowState _withApplicant(
    String applicantId,
    PublicDemoApplicant Function(PublicDemoApplicant applicant) update,
  ) => _copyWith(
    applicants: [
      for (final applicant in applicants)
        if (applicant.id == applicantId) update(applicant) else applicant,
    ],
  );

  // ---------------------------------------------------------------------
  // Applicant pre-entry pipeline transitions (WORKFLOW-STATE-1AB FIX5 P1):
  // `withApplicantStage(applicantId, stage)` let the caller pick the
  // resulting stage directly — including `juneOrdered`, the exact stage
  // assignOrderedForMay reads to build an assignment. It is gone. Each
  // method below is a specific, named pre-entry event with its own
  // required current-stage precondition; an applicant not currently at
  // that stage is unchanged. `juneOrdered` is reachable only via
  // [recordJuneOrder], which requires `preEntryClientPassed` — itself
  // reachable only through this same validated chain, starting from a
  // genuine `offerAccepted` (minted only by [PublicDemoOfferAcceptance
  // .accept], which itself requires the genuine [PublicDemoInterviewRecord]
  // only [PublicDemoAggregate.completeInterview] can mint). There is no
  // path from `applied` to `juneOrdered` that skips any of these.
  // ---------------------------------------------------------------------

  PublicDemoWorkflowState reviewResume(String applicantId) =>
      _transitionApplicantStage(
        applicantId,
        from: const {PublicDemoApplicantStage.applied},
        to: PublicDemoApplicantStage.resumeReviewed,
      );

  /// Inexperienced hires (`!canEnterPreJoinSales`) do not participate in
  /// pre-join sales at all (see [PublicDemoApplicant.canEnterPreJoinSales])
  /// — checked here, not just by the widget deciding which button to show.
  PublicDemoWorkflowState beginPreEntrySkillSheet(String applicantId) =>
      _withApplicant(
        applicantId,
        (applicant) =>
            applicant.stage == PublicDemoApplicantStage.offerAccepted &&
                applicant.canEnterPreJoinSales
            ? applicant.copyWith(
                stage: PublicDemoApplicantStage.preEntrySkillSheet,
              )
            : applicant,
      );

  PublicDemoWorkflowState beginPreEntrySelling(String applicantId) =>
      _transitionApplicantStage(
        applicantId,
        from: const {PublicDemoApplicantStage.preEntrySkillSheet},
        to: PublicDemoApplicantStage.preEntrySelling,
      );

  PublicDemoWorkflowState introducePreEntryProject(String applicantId) =>
      _transitionApplicantStage(
        applicantId,
        from: const {PublicDemoApplicantStage.preEntrySelling},
        to: PublicDemoApplicantStage.preEntryIntroduced,
      );

  /// The only production way an applicant reaches `juneOrdered`. See this
  /// section's class doc above for why that makes it unreachable without a
  /// genuine offer/interview/pre-entry-interview chain.
  PublicDemoWorkflowState recordJuneOrder(String applicantId) =>
      _transitionApplicantStage(
        applicantId,
        from: const {PublicDemoApplicantStage.preEntryClientPassed},
        to: PublicDemoApplicantStage.juneOrdered,
      );

  PublicDemoWorkflowState _transitionApplicantStage(
    String applicantId, {
    required Set<PublicDemoApplicantStage> from,
    required PublicDemoApplicantStage to,
  }) => _withApplicant(
    applicantId,
    (applicant) => from.contains(applicant.stage)
        ? applicant.copyWith(stage: to)
        : applicant,
  );

  /// Records a genuine interview completion for [applicantId]
  /// (WORKFLOW-STATE-1AB FIX6 P1, moved out of
  /// `PublicDemoAggregate.completeInterview` so that file no longer needs
  /// the now-private [_withApplicant] directly). [proof] must come from
  /// [PublicDemoState.useSalesSlotForInterview] actually consuming a slot
  /// on this exact call — only [PublicDemoAggregate.completeInterview] can
  /// supply one. Delegates to [PublicDemoApplicant.completeInterview],
  /// which is itself idempotent.
  PublicDemoWorkflowState recordInterviewCompletion(
    String applicantId,
    PublicDemoSalesSlotConsumptionProof proof,
  ) => _withApplicant(
    applicantId,
    (applicant) => applicant.completeInterview(proof),
  );

  /// Records the pre-entry partner-interview outcome for one applicant
  /// (WORKFLOW-STATE-1AB FIX6 P1, moved out of
  /// `PublicDemoAggregate.recordPreEntryPartnerInterviewResult`). A no-op
  /// unless the applicant is currently at `preEntryIntroduced`. Derives
  /// pass/fail itself from the applicant's own
  /// [PublicDemoApplicant.salesSkillFit] — never from a caller-supplied
  /// stage. Sales-slot consumption is decided by the caller
  /// (`PublicDemoAggregate`, which owns [PublicDemoState]); this method
  /// only ever changes [applicants].
  PublicDemoWorkflowState recordPreEntryPartnerInterviewResult(
    String applicantId,
  ) {
    final applicant = applicants
        .where((candidate) => candidate.id == applicantId)
        .firstOrNull;
    if (applicant == null ||
        applicant.stage != PublicDemoApplicantStage.preEntryIntroduced) {
      return this;
    }
    final nextStage = applicant.salesSkillFit >= 60
        ? PublicDemoApplicantStage.preEntryPartnerPassed
        : PublicDemoApplicantStage.preEntryPartnerFailed;
    return _withApplicant(
      applicantId,
      (candidate) => candidate.copyWith(stage: nextStage),
    );
  }

  /// Records the pre-entry client-interview outcome for one applicant
  /// (WORKFLOW-STATE-1AB FIX6 P1, moved out of
  /// `PublicDemoAggregate.recordPreEntryClientInterviewResult`). A no-op
  /// unless the applicant is currently at `preEntryPartnerPassed`. Derives
  /// pass/fail itself from the applicant's own
  /// [PublicDemoApplicant.salesSkillFit] — never from a caller-supplied
  /// stage. Matches the pre-cutover widget's own `ci()` handler: no sales
  /// slot is consumed for this interview.
  PublicDemoWorkflowState recordPreEntryClientInterviewResult(
    String applicantId,
  ) {
    final applicant = applicants
        .where((candidate) => candidate.id == applicantId)
        .firstOrNull;
    if (applicant == null ||
        applicant.stage != PublicDemoApplicantStage.preEntryPartnerPassed) {
      return this;
    }
    final nextStage = applicant.salesSkillFit >= 65
        ? PublicDemoApplicantStage.preEntryClientPassed
        : PublicDemoApplicantStage.preEntryClientFailed;
    return _withApplicant(
      applicantId,
      (candidate) => candidate.copyWith(stage: nextStage),
    );
  }

  /// The single sanctioned way to decide a raise for [applicantId]
  /// (POST-12MONTH-1-FIX1 P1-1, moved out of
  /// `PublicDemoAggregate.applyRaiseDecision`), via
  /// [PublicDemoRaiseTransaction]. [state] is read-only context (the
  /// fiscal-year-completion guard) — a value, not an identity, so passing
  /// it does not let a caller fabricate applicant identity/facts; the
  /// applicant transformed is always the genuine current one this
  /// workflow already holds for [applicantId], read internally, never a
  /// caller-supplied entity.
  PublicDemoWorkflowState applyRaiseDecision(
    String applicantId, {
    required PublicDemoState state,
    required int decisionMonth,
    required int week,
    required PublicDemoRaiseDecision decision,
  }) => _withApplicant(
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
  );

  /// Appends newly generated applicants (JOB-2/3, now atomic via
  /// `PublicDemoAggregate.recruit` in public_demo_aggregate.dart), skipping
  /// any id already present — mirrors the dedup the widget used to do
  /// inline.
  PublicDemoWorkflowState withGeneratedApplicants(
    List<PublicDemoApplicant> generated,
  ) {
    final existingIds = applicants.map((applicant) => applicant.id).toSet();
    return _copyWith(
      applicants: [
        ...applicants,
        for (final applicant in generated)
          if (existingIds.add(applicant.id)) applicant,
      ],
    );
  }

  /// The single sanctioned way to accept a salary offer for one applicant
  /// (WORKFLOW-STATE-1 §11). Delegates to [PublicDemoOfferAcceptance.accept]
  /// so the [PublicDemoBindingOffer] it may mint stays this file's only
  /// caller of that command.
  PublicDemoWorkflowState acceptOffer({
    required String applicantId,
    required PublicDemoSalaryOffer offer,
    required PublicDemoFiscalCloseId fiscalCloseId,
  }) => _withApplicant(
    applicantId,
    (applicant) => PublicDemoOfferAcceptance.accept(
      applicant: applicant,
      offer: offer,
      fiscalCloseId: fiscalCloseId,
    ).applicant,
  );

  /// Joins every applicant in [applicantIds] (WORKFLOW-STATE-1 §12) via
  /// [PublicDemoJoinTransaction], then replaces the applicant list with
  /// exactly that (now-joined-where-eligible) subset, in [applicantIds]
  /// order. This intentionally reproduces the pre-cutover May behavior,
  /// where only applicants who had accepted an offer remained visible past
  /// the May-to-June transition — applicants who were rejected, declined, or
  /// never made it past interview are dropped from the roster at that point,
  /// exactly as before.
  ///
  /// WORKFLOW-STATE-1AB FIX5 P1: [PublicDemoJoinTransaction.join] returns
  /// the *unchanged* applicant on failure (no BindingOffer, wrong
  /// applicant, stale fiscal close, ...) — so a join failure here
  /// deliberately does not clear whatever `stage` the applicant already
  /// carried (e.g. `juneOrdered`). That is safe only because
  /// [assignOrderedForMay] no longer trusts `stage` alone either: it also
  /// requires [PublicDemoApplicant.hasJoined], which a failed join here
  /// never sets. A join failure therefore can never reach an assignment,
  /// regardless of which `stage` employment authority left behind.
  PublicDemoWorkflowState joinAndKeepOnly({
    required List<String> applicantIds,
    required int week,
    required PublicDemoFiscalCloseId currentFiscalCloseId,
  }) {
    final byId = {for (final applicant in applicants) applicant.id: applicant};
    const transaction = PublicDemoJoinTransaction();
    final kept = <PublicDemoApplicant>[
      for (final id in applicantIds)
        if (byId[id] case final applicant?)
          transaction
              .join(
                applicant: applicant,
                week: week,
                currentFiscalCloseId: currentFiscalCloseId,
              )
              .applicant,
    ];
    return _copyWith(applicants: kept);
  }

  Iterable<PublicDemoApplicant> get joinedApplicants =>
      applicants.where((applicant) => applicant.hasJoined);

  /// Derived projection — SOURCE OF TRUTH: [applicants] (specifically
  /// [PublicDemoApplicant.hasJoined]). Kept for compatibility with
  /// [PublicDemoState.joinedApplicantIds] (WORKFLOW-STATE-1 §24); nothing
  /// may write back through this getter into [applicants].
  List<String> get joinedApplicantIds =>
      joinedApplicants.map((applicant) => applicant.id).toList();

  // ---------------------------------------------------------------------
  // Engineers (sales pipeline)
  // ---------------------------------------------------------------------

  /// Private to this file (WORKFLOW-STATE-1AB FIX6 P1) for the same reason
  /// [_withApplicant] is — see its doc.
  PublicDemoWorkflowState _withEngineer(
    String engineerId,
    PublicDemoEngineerSales Function(PublicDemoEngineerSales engineer) update,
  ) => _copyWith(
    engineers: [
      for (final engineer in engineers)
        if (engineer.id == engineerId) update(engineer) else engineer,
    ],
  );

  // ---------------------------------------------------------------------
  // Engineer sales-pipeline transitions (WORKFLOW-STATE-1AB FIX5 P1):
  // `withEngineerStage(engineerId, stage)` let the caller pick the
  // resulting stage directly — including `ordered`, the exact stage
  // assignOrderedForMay reads to build an assignment. It is gone. Each
  // method below is a specific, named sales-pipeline event with its own
  // required current-stage precondition, checked before advancing; an
  // engineer not currently at the required stage is unchanged. `ordered`
  // is reachable only via [recordOrder], which requires
  // `clientInterviewPassed` — itself set only by
  // [PublicDemoAggregate.recordEngineerInterviewResult], which derives the
  // pass/fail outcome itself (from the engineer's own interview profile),
  // never from a caller-supplied stage or score. There is no path from
  // `waiting` to `ordered` that skips either interview.
  // ---------------------------------------------------------------------

  PublicDemoWorkflowState startSkillSheetReview(String engineerId) =>
      _transitionEngineerStage(
        engineerId,
        from: const {PublicDemoSalesStage.waiting},
        to: PublicDemoSalesStage.skillSheet,
      );

  PublicDemoWorkflowState beginSelling(String engineerId) =>
      _transitionEngineerStage(
        engineerId,
        from: const {
          PublicDemoSalesStage.skillSheet,
          PublicDemoSalesStage.partnerInterviewFailed,
          PublicDemoSalesStage.clientInterviewFailed,
        },
        to: PublicDemoSalesStage.selling,
      );

  PublicDemoWorkflowState introduceProject(String engineerId) =>
      _transitionEngineerStage(
        engineerId,
        from: const {PublicDemoSalesStage.selling},
        to: PublicDemoSalesStage.introduced,
      );

  /// The only production way an engineer reaches `ordered`. See this
  /// section's class doc above for why that makes it unreachable without a
  /// genuine partner+client interview pass.
  PublicDemoWorkflowState recordOrder(String engineerId) =>
      _transitionEngineerStage(
        engineerId,
        from: const {PublicDemoSalesStage.clientInterviewPassed},
        to: PublicDemoSalesStage.ordered,
      );

  PublicDemoWorkflowState _transitionEngineerStage(
    String engineerId, {
    required Set<PublicDemoSalesStage> from,
    required PublicDemoSalesStage to,
  }) => _withEngineer(
    engineerId,
    (engineer) =>
        from.contains(engineer.stage) ? engineer.copyWith(stage: to) : engineer,
  );

  /// Records a partner/client interview outcome for [engineerId]
  /// (WORKFLOW-STATE-1AB FIX6 P1, moved out of
  /// `PublicDemoAggregate.recordEngineerInterviewResult` so that file no
  /// longer needs the now-private [_withEngineer] directly; WORKFLOW-STATE-
  /// 1AB FIX7 P2: the stage precondition, [PublicDemoInterviewEvaluator]
  /// call, and record minting all now live inside
  /// [PublicDemoEngineerSales.evaluateInterview] itself, so this method is a
  /// thin, purely id-routing delegation — [actualCapability] is passed
  /// through unchanged, never inspected here). A no-op for an unknown
  /// [engineerId], or when the engineer is not already at the stage [type]
  /// demands (`introduced` for partner, `partnerInterviewPassed` for
  /// client) — both checked inside [PublicDemoEngineerSales
  /// .evaluateInterview].
  PublicDemoWorkflowState recordEngineerInterviewResult({
    required String engineerId,
    required PublicDemoInterviewType type,
    required int actualCapability,
  }) => _withEngineer(
    engineerId,
    (candidate) => candidate.evaluateInterview(
      type: type,
      actualCapability: actualCapability,
    ),
  );

  /// Adds newly joined applicants as engineers (May's join step), skipping
  /// anyone already present by id — mirrors the widget's former inline
  /// dedup exactly.
  PublicDemoWorkflowState withJoinedEngineers(
    Iterable<PublicDemoApplicant> joined,
  ) => _copyWith(
    engineers: [
      ...engineers,
      for (final applicant in joined)
        if (applicant.hasJoined &&
            !engineers.any((engineer) => engineer.id == applicant.id))
          PublicDemoEngineerSales.fromApplicant(applicant),
    ],
  );

  // ---------------------------------------------------------------------
  // Assignments
  // ---------------------------------------------------------------------

  /// Updates only the mutable per-month decision fields of the assignment
  /// matching [engineerId] — [PublicDemoAssignment.copyWith]'s own three
  /// parameters — leaving every other assignment, and every other field of
  /// this one (identity, project, and economic fields:
  /// `engineerId`/`engineerName`/`projectName`/`deliveryPressure`/
  /// `budgetHealth`/`humanity`), untouched.
  ///
  /// WORKFLOW-STATE-1AB FIX3 P1-3: FIX2's `withAssignment` took an update
  /// *function* (`PublicDemoAssignment Function(PublicDemoAssignment)`) —
  /// since a caller-supplied function can simply ignore the real assignment
  /// it is given and return an entirely fabricated
  /// `PublicDemoAssignment(...)` instead (that constructor remains public,
  /// as a value object — see [PublicDemoAssignment]'s own doc), that shape
  /// let a caller substitute a fully fake assignment — including its
  /// economic fields — for a real one already on the authoritative roster,
  /// bypassing [assignOrderedForMay] entirely. Named parameters instead of
  /// a function make that structurally impossible: there is no argument
  /// through which a whole fabricated [PublicDemoAssignment] could pass.
  PublicDemoWorkflowState withAssignmentUpdate(
    String engineerId, {
    PublicDemoNextOrderStatus? nextOrderStatus,
    PublicDemoReplacementStage? replacementStage,
    int? fieldEvaluation,
  }) => _copyWith(
    assignments: [
      for (final assignment in assignments)
        if (assignment.engineerId == engineerId)
          assignment.copyWith(
            nextOrderStatus: nextOrderStatus,
            replacementStage: replacementStage,
            fieldEvaluation: fieldEvaluation,
          )
        else
          assignment,
    ],
  );

  /// Replaces the assignment roster wholesale. Private to this file
  /// (WORKFLOW-STATE-1AB FIX1 P1-3): arbitrary roster replacement is not a
  /// production-sanctioned capability — only [assignOrderedForMay] below,
  /// which computes the replacement roster itself from this workflow's own
  /// authoritative engineer/applicant stage facts, may call it. No UI or
  /// other caller can supply its own roster.
  PublicDemoWorkflowState _withAssignments(
    List<PublicDemoAssignment> assignments,
  ) => _copyWith(assignments: assignments);

  /// The single domain-owned way to build May's assignment roster
  /// (WORKFLOW-STATE-1AB FIX1 P1-3). Reads only the authoritative engineer/
  /// applicant facts already on this workflow, so the caller (the widget)
  /// supplies no roster of its own and cannot fabricate one.
  ///
  /// WORKFLOW-STATE-1AB FIX5/FIX6 P1 (defense in depth): does not trust
  /// `stage` alone, even though FIX5/FIX6 also closed every production path
  /// that could set it without going through a genuine transition —
  /// [PublicDemoSalesStage.ordered]/[PublicDemoApplicantStage.juneOrdered]
  /// are corroborated against a second, independently-authoritative fact
  /// each: an engineer additionally needs
  /// [PublicDemoEngineerSales.hasGenuineInterviewRecord] — the unforgeable
  /// [PublicDemoEngineerInterviewRecord] only a genuine client-interview
  /// pass through [PublicDemoAggregate.recordEngineerInterviewResult] can
  /// mint (WORKFLOW-STATE-1AB FIX6 P1: `lastInterviewScore != null` alone,
  /// FIX5's original check, was insufficient — that field remains publicly
  /// settable via [PublicDemoEngineerSales.copyWith] and proves nothing by
  /// itself) — and an applicant additionally needs
  /// [PublicDemoApplicant.hasJoined] — the unforgeable [PublicDemoJoinRecord]
  /// only a genuine [PublicDemoJoinTransaction.join] can mint. This means a
  /// future bug that lets `stage` alone drift out of sync (e.g. a stage set
  /// before join is attempted, or a join that fails), or even a caller
  /// constructing a whole fabricated engineer/applicant directly via the
  /// public [PublicDemoWorkflowState] factory constructor, still cannot
  /// produce an assignment for a non-eligible engineer or non-joined
  /// applicant — see `joinAndKeepOnly`'s own doc for exactly the
  /// join-failure case.
  /// Reproduces exactly the roster the pre-cutover widget computed inline.
  PublicDemoWorkflowState assignOrderedForMay() {
    final nextAssignments = [
      for (final engineer in engineers)
        if (engineer.stage == PublicDemoSalesStage.ordered &&
            engineer.hasGenuineInterviewRecord)
          publicDemoInitialAssignments
                  .where((assignment) => assignment.engineerId == engineer.id)
                  .firstOrNull ??
              PublicDemoAssignment.forOrderedEngineer(
                engineerId: engineer.id,
                engineerName: engineer.name,
                humanity: engineer.interviewProfile.humanity,
              ),
      for (final applicant in applicants)
        if (applicant.stage == PublicDemoApplicantStage.juneOrdered &&
            applicant.hasJoined)
          PublicDemoAssignment(
            engineerId: applicant.id,
            engineerName: applicant.name,
            projectName: '新規開発支援',
            deliveryPressure: 50,
            budgetHealth: 70,
            humanity: 70,
          ),
    ];
    return _withAssignments(nextAssignments);
  }

  // ---------------------------------------------------------------------
  // Cross-cutting projections consumed by monthly close / Growth / Revenue
  // ---------------------------------------------------------------------

  /// Every engineer id [assignments] currently names, regardless of
  /// `nextOrderStatus`/`replacementStage`. Correct through June (see
  /// [assignedEngineerIds] for why this differs from July onward).
  Set<String> get assignedEngineerIdsUnfiltered =>
      assignments.map((assignment) => assignment.engineerId).toSet();

  /// The engineer IDs currently backing [PublicDemoState.engineersAssigned]
  /// — the single SSOT Revenue, Growth, and training eligibility must all
  /// agree on (12MONTH-3-FIX1 P1-1, preserved verbatim by WORKFLOW-STATE-1).
  ///
  /// `assignments` means two different things depending on when it is read.
  /// Through June it is this month's live roster: every entry is currently
  /// assigned regardless of `nextOrderStatus` (June's own decision, about
  /// *next* month, is still pending at that point) —
  /// [assignedEngineerIdsUnfiltered] is correct there. From July onward,
  /// this reflects only whichever entries June's
  /// `decideOrder`/`acceptOrder`/`replacementPartner`/`replacementClient`
  /// flow actually marked `accepted`/`ordered` — exactly what July already
  /// computed inline for Growth — and Public Demo 0.1 formally carries that
  /// same roster forward through the rest of the fiscal year (P1-1 DESIGN
  /// DECISION: "一度案件参画が成立した社員は、第1期終了まで同じ案件へ継続参画する"),
  /// so the filtered subset stays the correct identity set for every month
  /// 7-15, not just July itself.
  Set<String> assignedEngineerIds({required int month}) => month >= 7
      ? assignments
            .where(
              (assignment) =>
                  assignment.nextOrderStatus ==
                      PublicDemoNextOrderStatus.accepted ||
                  assignment.replacementStage ==
                      PublicDemoReplacementStage.ordered,
            )
            .map((assignment) => assignment.engineerId)
            .toSet()
      : assignedEngineerIdsUnfiltered;

  /// Morale-equivalent per engineer/joined-applicant id, the shape
  /// [PublicDemoState.applyMonthlyGrowth] requires.
  Map<String, int> get moraleByEngineerId => {
    for (final engineer in engineers) engineer.id: engineer.motivation,
    for (final applicant in joinedApplicants)
      applicant.id: applicant.employeeMorale!,
  };
}
