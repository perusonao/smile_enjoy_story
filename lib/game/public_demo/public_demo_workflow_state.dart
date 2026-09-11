import '../../domain/domain.dart';
import '../models/client_interview.dart';
import '../models/recruitment_interview.dart';
import 'public_demo_assignment.dart';
import 'public_demo_binding_offer.dart';
import 'public_demo_engineer_runtime.dart';
import 'public_demo_fiscal_close_id.dart';
import 'public_demo_founder_follow_up.dart';
import 'public_demo_interview.dart';
import 'public_demo_join.dart';
import 'public_demo_matching_proposal.dart';
import 'public_demo_project_interview.dart';
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
    interviewSessions: const [],
    matchingProposals: const [],
    projectInterviewSessions: const [],
  );

  const PublicDemoWorkflowState._({
    required this.applicants,
    required this.engineers,
    required this.assignments,
    required this.interviewSessions,
    required this.matchingProposals,
    required this.projectInterviewSessions,
  });

  /// Public Demo 0.1's starting workflow: the founding engineer team
  /// (unchanged), and **no** pre-seeded applicants.
  ///
  /// CORE-GAMEPLAY Phase 4.5: before this fix, a new game started with
  /// [publicDemoMayApplicants] (`app-01`/`app-02`) already present from
  /// month 4 — an applicant pool the player never generated, merely hidden
  /// from the Sales-tab pipeline UI until `s.month >= 5` (a UI-only gate,
  /// not a generation event). A player who had genuinely not used any
  /// recruitment medium would still see two ready-to-interview candidates
  /// appear the moment May began, with no action of their own behind it.
  /// Recruitment now has exactly one production source of applicants:
  /// [PublicDemoAggregate.recruit] (CORE-GAMEPLAY Phase 2's
  /// [PublicDemoSeededRecruitmentGenerator]) — "使う求人媒体 → 応募者生成" is
  /// the sole normal-play route, and a bare month transition alone can never
  /// add an applicant. [publicDemoMayApplicants]/[publicDemoFreeApplicants]
  /// remain in `public_demo_recruitment.dart`, but only for legacy-save
  /// `fromJson` round-tripping of a save created before this fix, and for
  /// [PublicDemoRecruitmentInterview]'s pre-existing id-only fallback for
  /// those legacy ids — never as a game-start seed.
  factory PublicDemoWorkflowState.initial() => PublicDemoWorkflowState(
    applicants: const [],
    engineers: publicDemoInitialEngineers,
  );

  final List<PublicDemoApplicant> applicants;
  final List<PublicDemoEngineerSales> engineers;
  final List<PublicDemoAssignment> assignments;

  /// In-progress/completed interactive recruitment-interview sessions
  /// (CORE-GAMEPLAY Phase 3), one per applicant who has started the
  /// question-selection step reused from the main game's own
  /// `RecruitmentInterviewSession`/`RecruitmentInterviewEngine`
  /// (`lib/game/models/recruitment_interview.dart`,
  /// `lib/game/engine/recruitment_interview_engine.dart`). This is
  /// deliberately a separate top-level list rather than a field on
  /// [PublicDemoApplicant] itself: that class is locked down to only
  /// unforgeable terminal facts (see its own class doc), never in-progress,
  /// freely-overwritable session state. Additive to the save schema — see
  /// [fromJson]'s backward-compatible default below.
  final List<RecruitmentInterviewSession> interviewSessions;

  /// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): at most one
  /// [PublicDemoMatchingProposal] per `engineerId` — see
  /// [withMatchingProposal]. Additive to the save schema, exactly like
  /// [interviewSessions] above — see [fromJson]'s backward-compatible
  /// default.
  final List<PublicDemoMatchingProposal> matchingProposals;

  /// CORE-GAMEPLAY Phase 6 (Project Interview Gameplay): at most one
  /// in-progress/completed [ClientInterviewSession] per engineer id (its
  /// own [ClientInterviewSession.employeeId]) — the interactive project
  /// interview reused from the main game's own
  /// [ClientInterviewEngine]/[ProjectInterviewEngine]
  /// (`public_demo_project_interview.dart`), exactly like
  /// [interviewSessions] reuses [RecruitmentInterviewEngine]. Additive to
  /// the save schema — see [fromJson]'s backward-compatible default below.
  final List<ClientInterviewSession> projectInterviewSessions;

  /// Complete workflow persistence representation.  This is intentionally
  /// separate from the production constructor: an assignment roster is only
  /// restored from a validated aggregate save, never supplied by gameplay
  /// callers.
  Map<String, dynamic> toJson() => {
    'applicants': applicants.map((applicant) => applicant.toJson()).toList(),
    'engineers': engineers.map((engineer) => engineer.toJson()).toList(),
    'assignments': assignments
        .map((assignment) => assignment.toJson())
        .toList(),
    'interviewSessions': interviewSessions
        .map((session) => session.toJson())
        .toList(),
    'matchingProposals': matchingProposals
        .map((proposal) => proposal.toJson())
        .toList(),
    'projectInterviewSessions': projectInterviewSessions
        .map((session) => session.toJson())
        .toList(),
  };

  factory PublicDemoWorkflowState.fromJson(Map<String, dynamic> json) {
    List requiredList(String key) {
      final value = json[key];
      if (value is! List) throw FormatException('Invalid workflow $key');
      return value;
    }

    List<T> decodeList<T>(List raw, T Function(Map<String, dynamic>) decode) =>
        raw.map((entry) {
          if (entry is! Map) {
            throw const FormatException('Invalid workflow entry');
          }
          return decode(entry.cast<String, dynamic>());
        }).toList();

    // Additive field (CORE-GAMEPLAY Phase 3): a save written before this
    // change has no 'interviewSessions' key at all. Absent means "no
    // interactive interview was ever in progress" — an empty list, not a
    // rejected/invalid save — exactly like every applicant that save
    // already carries: their (unrelated) `stage`/records round-trip
    // unmodified regardless of this key's presence.
    final interviewSessionsRaw = json['interviewSessions'];
    if (interviewSessionsRaw != null && interviewSessionsRaw is! List) {
      throw const FormatException('Invalid workflow interviewSessions');
    }

    // Additive field (CORE-GAMEPLAY Phase 5): a save written before this
    // change has no 'matchingProposals' key at all. Absent means "no
    // proposal was ever recorded" — an empty list, not a rejected/invalid
    // save, exactly like [interviewSessions] above.
    final matchingProposalsRaw = json['matchingProposals'];
    if (matchingProposalsRaw != null && matchingProposalsRaw is! List) {
      throw const FormatException('Invalid workflow matchingProposals');
    }

    // Additive field (CORE-GAMEPLAY Phase 6): a save written before this
    // change has no 'projectInterviewSessions' key at all. Absent means "no
    // project interview was ever in progress" — an empty list, not a
    // rejected/invalid save, exactly like [interviewSessions]/
    // [matchingProposals] above.
    final projectInterviewSessionsRaw = json['projectInterviewSessions'];
    if (projectInterviewSessionsRaw != null &&
        projectInterviewSessionsRaw is! List) {
      throw const FormatException(
        'Invalid workflow projectInterviewSessions',
      );
    }

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
      interviewSessions: List.unmodifiable(
        interviewSessionsRaw == null
            ? const <RecruitmentInterviewSession>[]
            : decodeList(
                interviewSessionsRaw,
                RecruitmentInterviewSession.fromJson,
              ),
      ),
      matchingProposals: List.unmodifiable(
        matchingProposalsRaw == null
            ? const <PublicDemoMatchingProposal>[]
            : decodeList(
                matchingProposalsRaw,
                PublicDemoMatchingProposal.fromJson,
              ),
      ),
      projectInterviewSessions: List.unmodifiable(
        projectInterviewSessionsRaw == null
            ? const <ClientInterviewSession>[]
            : decodeList(
                projectInterviewSessionsRaw,
                ClientInterviewSession.fromJson,
              ),
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
    List<RecruitmentInterviewSession>? interviewSessions,
    List<PublicDemoMatchingProposal>? matchingProposals,
    List<ClientInterviewSession>? projectInterviewSessions,
  }) => PublicDemoWorkflowState._(
    applicants: List.unmodifiable(applicants ?? this.applicants),
    engineers: List.unmodifiable(engineers ?? this.engineers),
    assignments: List.unmodifiable(assignments ?? this.assignments),
    interviewSessions: List.unmodifiable(
      interviewSessions ?? this.interviewSessions,
    ),
    matchingProposals: List.unmodifiable(
      matchingProposals ?? this.matchingProposals,
    ),
    projectInterviewSessions: List.unmodifiable(
      projectInterviewSessions ?? this.projectInterviewSessions,
    ),
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
  //
  // Issue #241 FIRST-FUN-YEAR Recruitment Flow / Next Action Clarity
  // (Fresh Audit finding): every transition below additionally requires
  // `!applicant.hasJoined`. [PublicDemoApplicant.join] can mint a
  // [PublicDemoApplicant.hasJoined]-backing record for an applicant who is
  // still genuinely mid-pre-entry-pipeline (accepted an offer, started
  // pre-entry sales, but had not yet reached `juneOrdered` by the time
  // their own [PublicDemoBindingOffer.fiscalCloseId] month closes) — the
  // pre-entry pipeline itself has no month boundary, but a month-end close
  // does, and [join] only requires a valid, fiscal-close-matching offer,
  // never a completed pre-entry chain. Before this guard, such an
  // already-employed applicant could still be walked further through
  // pre-entry sales stages (`beginPreEntrySelling`, `introducePreEntryProject`,
  // ..., even all the way to a second `juneOrdered`) purely because their
  // `stage` had not moved — even though they are already a real employee
  // in [engineers], reachable via completely different (Employee tab)
  // authority. Once genuinely joined, no pre-entry-pipeline transition is
  // ever the correct next step for that applicant again; every caller
  // (production and test) that reaches these methods post-join now
  // no-ops, exactly like reaching them from any other invalid `stage`.
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
                applicant.canEnterPreJoinSales &&
                !applicant.hasJoined
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
    (applicant) => from.contains(applicant.stage) && !applicant.hasJoined
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

  /// The single sanctioned way to decline an applicant after their
  /// interactive interview (CORE-GAMEPLAY Phase 3), wiring up the
  /// `PublicDemoApplicantStage.rejected` value that has existed on the enum
  /// since WORKFLOW-STATE-1 but was never reachable from any production
  /// command until this phase. A no-op unless the applicant is currently at
  /// `interviewed` — in particular, an applicant who already has a
  /// [PublicDemoApplicant.bindingOffer] or a decided
  /// [PublicDemoApplicantStage.offerDeclined] can never be rejected
  /// retroactively through this method.
  PublicDemoWorkflowState rejectApplicant(String applicantId) =>
      _transitionApplicantStage(
        applicantId,
        from: const {PublicDemoApplicantStage.interviewed},
        to: PublicDemoApplicantStage.rejected,
      );

  // ---------------------------------------------------------------------
  // Interactive recruitment-interview sessions (CORE-GAMEPLAY Phase 3)
  // ---------------------------------------------------------------------

  /// Appends [session] as the interview session for its own
  /// [RecruitmentInterviewSession.applicantId] — a no-op if a session for
  /// that applicant already exists (starting one is otherwise idempotent,
  /// matching [PublicDemoApplicant.completeInterview]'s own idempotency
  /// convention), so a caller can always call this unconditionally before
  /// opening the interview UI without double-appending on a resumed session.
  PublicDemoWorkflowState startInterviewSession(
    RecruitmentInterviewSession session,
  ) {
    if (interviewSessions.any(
      (existing) => existing.applicantId == session.applicantId,
    )) {
      return this;
    }
    return _copyWith(interviewSessions: [...interviewSessions, session]);
  }

  /// Replaces the active (not yet [RecruitmentInterviewSession.completed])
  /// session for [applicantId] with [update]'s result. A no-op when no such
  /// session exists — every real call site (asking a question, answering
  /// the reverse question, concluding the interview) only ever follows a
  /// successful [startInterviewSession], exactly mirroring
  /// [_withApplicant]'s own "missing id is a caller bug, not a real
  /// workflow event" contract.
  PublicDemoWorkflowState updateInterviewSession(
    String applicantId,
    RecruitmentInterviewSession Function(RecruitmentInterviewSession session)
    update,
  ) {
    final index = interviewSessions.indexWhere(
      (session) => session.applicantId == applicantId && !session.completed,
    );
    if (index < 0) return this;
    final next = [...interviewSessions];
    next[index] = update(next[index]);
    return _copyWith(interviewSessions: next);
  }

  /// Records the pre-entry partner-interview outcome for one applicant
  /// (WORKFLOW-STATE-1AB FIX6 P1, moved out of
  /// `PublicDemoAggregate.recordPreEntryPartnerInterviewResult`). A no-op
  /// unless the applicant is currently at `preEntryIntroduced` and has not
  /// already joined (Issue #241 — see the pre-entry-pipeline section doc
  /// above for why [PublicDemoApplicant.hasJoined] must gate this too, not
  /// just `stage`). Derives
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
        applicant.stage != PublicDemoApplicantStage.preEntryIntroduced ||
        applicant.hasJoined) {
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
  /// unless the applicant is currently at `preEntryPartnerPassed` and has
  /// not already joined (Issue #241 — same [PublicDemoApplicant.hasJoined]
  /// guard as [recordPreEntryPartnerInterviewResult]). Derives
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
        applicant.stage != PublicDemoApplicantStage.preEntryPartnerPassed ||
        applicant.hasJoined) {
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

  /// Joins every applicant with a genuinely accepted offer for
  /// [currentFiscalCloseId] via [PublicDemoJoinTransaction] (Issue #221
  /// FIRST-FUN-YEAR: generalizes [joinAndKeepOnly]'s join step beyond May).
  ///
  /// Unlike [joinAndKeepOnly], this never prunes [applicants] down to the
  /// accepted subset — that pruning was a one-time founding-cohort cutoff
  /// specific to the May-to-June transition. Recruitment keeps running
  /// every month from June onward ([PublicDemoAggregate.recruit] has no
  /// month ceiling), so applicants still mid-pipeline — applied,
  /// interviewing, rejected, or awaiting a later offer — must remain in
  /// [applicants] untouched, not be dropped the way May's cohort cutoff
  /// drops them.
  ///
  /// Safe to call at every month-end close, including repeatedly: each
  /// applicant is passed through [PublicDemoJoinTransaction.join]
  /// independently, which itself is a no-op for anyone already joined,
  /// never offered, declined, or whose offer belongs to a different fiscal
  /// close — so re-processing an already-joined cohort at a later month's
  /// close (or a retried close) never double-joins anyone.
  PublicDemoWorkflowState joinAcceptedForFiscalClose({
    required int week,
    required PublicDemoFiscalCloseId currentFiscalCloseId,
  }) {
    const transaction = PublicDemoJoinTransaction();
    final updated = [
      for (final applicant in applicants)
        transaction
            .join(
              applicant: applicant,
              week: week,
              currentFiscalCloseId: currentFiscalCloseId,
            )
            .applicant,
    ];
    return _copyWith(applicants: updated);
  }

  /// Appends a real assignment for every applicant in [newlyJoined] who
  /// joined this close with an already-won pre-entry order
  /// ([PublicDemoApplicantStage.juneOrdered]) — the exact same
  /// authoritative template [assignOrderedForMay]'s own `juneOrdered`
  /// branch already uses for May's cohort, reused here so a June-or-later
  /// hire's already-earned order (a genuine pass through
  /// `beginPreEntrySkillSheet` → `beginPreEntrySelling` →
  /// `introducePreEntryProject` → `recordPreEntryPartnerInterviewResult` →
  /// `recordPreEntryClientInterviewResult` → `recordJuneOrder`) is not
  /// silently discarded into a plain waiting engineer, forcing them to
  /// redo Sales/Matching/interviews from scratch (Issue #221 PR #222
  /// review finding).
  ///
  /// APPEND-only — mirrors [recoverLateYearAssignment]'s own safety
  /// contract, never [assignOrderedForMay]'s wholesale rebuild: every
  /// assignment already on [assignments] for a different `engineerId` is
  /// left completely untouched. Idempotent: an applicant who already has
  /// an assignment entry — a retried close, or one already handled by an
  /// earlier call this same month — is skipped, so this never double-adds
  /// an assignment (and therefore never double-books revenue/payroll)
  /// for the same applicant.
  PublicDemoWorkflowState appendPreEntryOrderAssignments(
    Iterable<PublicDemoApplicant> newlyJoined,
  ) {
    final existingIds = assignments
        .map((assignment) => assignment.engineerId)
        .toSet();
    final additions = [
      for (final applicant in newlyJoined)
        if (applicant.hasJoined &&
            applicant.stage == PublicDemoApplicantStage.juneOrdered &&
            !existingIds.contains(applicant.id))
          PublicDemoAssignment(
            engineerId: applicant.id,
            engineerName: applicant.name,
            projectName: '新規開発支援',
            deliveryPressure: 50,
            budgetHealth: 70,
            humanity: 70,
          ),
    ];
    return additions.isEmpty
        ? this
        : _withAssignments([...assignments, ...additions]);
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

  /// The single sanctioned way to decide a founder follow-up (Issue #167
  /// FIRST-FUN-YEAR-LATE-GAME-1 Phase 1) for [engineerId]. Defense in depth
  /// alongside [PublicDemoAggregate.applyFounderFollowUpDecision]:
  /// re-validates [PublicDemoFounderFollowUp.isEligible] here too, using
  /// this workflow's own authoritative [engineers]/[assignedEngineerIds] —
  /// never the caller-supplied [month] alone — so a stale or
  /// independently-constructed caller can never apply this decision twice,
  /// to a non-founding engineer, or outside its eligible window/roster,
  /// even if the aggregate's own pre-check were ever skipped.
  PublicDemoWorkflowState applyFounderFollowUpDecision(
    String engineerId, {
    required int month,
    required PublicDemoFounderFollowUpDecision decision,
  }) {
    final assigned = assignedEngineerIds(month: month);
    return _withEngineer(engineerId, (engineer) {
      if (!PublicDemoFounderFollowUp.isEligible(
        engineer: engineer,
        month: month,
        assignedEngineerIds: assigned,
      )) {
        return engineer;
      }
      return engineer.copyWith(
        mental:
            (engineer.mental +
                    PublicDemoFounderFollowUp.mentalDeltaFor(decision))
                .clamp(0, 100),
        trust:
            (engineer.trust + PublicDemoFounderFollowUp.trustDeltaFor(decision))
                .clamp(0, 100),
        founderFollowUpMonth: month,
      );
    });
  }

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

  /// CORE-GAMEPLAY Phase 7B: credits exactly one month of real assignment
  /// participation to every assignment whose `engineerId` is in
  /// [engineerIds] — see [PublicDemoAssignment.monthsCredited]'s own doc.
  /// The sole production caller is [PublicDemoAggregate]'s month-end close
  /// helper, which only ever passes this the exact same
  /// `assignedEngineerIds` set it just fed to
  /// [PublicDemoState.applyMonthlyGrowth] for `source: assignment`, and
  /// only when that call actually changed something (never on a
  /// fiscalYearCompleted/already-applied-month no-op) — so this stays in
  /// lockstep with Growth's own once-per-month application without a
  /// second, independent "did growth already run this month" guard here.
  /// A no-op for any assignment whose `engineerId` is not in [engineerIds]
  /// — every other assignment (and its own `monthsCredited`) is carried
  /// forward completely untouched.
  PublicDemoWorkflowState creditAssignmentMonths(Set<String> engineerIds) {
    if (engineerIds.isEmpty) return this;
    return _withAssignments([
      for (final assignment in assignments)
        if (engineerIds.contains(assignment.engineerId))
          assignment.copyWith(
            monthsCredited: assignment.monthsCredited + 1,
          )
        else
          assignment,
    ]);
  }

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
  ///
  /// Issue #227 P1: [PublicDemoAggregate.closeApril] now also calls this —
  /// a genuine April order must materialize its assignment entering May,
  /// not sit un-assigned until June — so this can no longer unconditionally
  /// rebuild every entry from scratch on each call the way a true one-shot
  /// May-only builder could. An engineer/applicant that already has an
  /// entry on [assignments] (built by an earlier call this same method
  /// made, e.g. April's) keeps that exact entry — `nextOrderStatus`,
  /// `replacementStage`, `fieldEvaluation`, `projectId`, and
  /// `monthsCredited` all carried forward untouched — rather than being
  /// silently reset to a fresh [PublicDemoAssignment]'s defaults; only an
  /// engineer/applicant with no existing entry yet gets a newly-built one.
  /// The eligibility SET is still recomputed from current stage facts on
  /// every call, exactly as before: an entry whose engineer/applicant no
  /// longer qualifies is still dropped, and this is still the only way an
  /// entry is ever added.
  PublicDemoWorkflowState assignOrderedForMay() {
    PublicDemoAssignment? existingAssignmentFor(String engineerId) =>
        assignments
            .where((assignment) => assignment.engineerId == engineerId)
            .firstOrNull;

    final nextAssignments = [
      for (final engineer in engineers)
        if (engineer.stage == PublicDemoSalesStage.ordered &&
            engineer.hasGenuineInterviewRecord)
          existingAssignmentFor(engineer.id) ??
              _freshOrderedAssignment(engineer),
      for (final applicant in applicants)
        if (applicant.stage == PublicDemoApplicantStage.juneOrdered &&
            applicant.hasJoined)
          existingAssignmentFor(applicant.id) ??
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

  /// Builds a brand new [PublicDemoAssignment] for [engineer] from this
  /// workflow's own authoritative facts — extracted from
  /// [assignOrderedForMay] so it composes with that method's `??` reuse of
  /// an already-existing entry (an `if`/`case` collection element, the
  /// original inline shape, cannot itself appear as the right-hand side of
  /// `??`).
  ///
  /// CORE-GAMEPLAY Phase 7A: a genuine, project-bound Phase 6 pass always
  /// produces an assignment tied to that exact real project — never the
  /// founding-engineer template/generic placeholder, even when one exists
  /// for this engineer id, so the real project identity Phase 6 already
  /// earned is never silently discarded.
  PublicDemoAssignment _freshOrderedAssignment(
    PublicDemoEngineerSales engineer,
  ) {
    if (engineer.genuineInterviewProjectId case final projectId?) {
      return PublicDemoAssignment.forOrderedEngineer(
        engineerId: engineer.id,
        engineerName: engineer.name,
        humanity: engineer.interviewProfile.humanity,
        projectId: projectId,
      );
    }
    return publicDemoInitialAssignments
            .where((assignment) => assignment.engineerId == engineer.id)
            .firstOrNull ??
        PublicDemoAssignment.forOrderedEngineer(
          engineerId: engineer.id,
          engineerName: engineer.name,
          humanity: engineer.interviewProfile.humanity,
        );
  }

  /// The single domain-owned way to commit a late-year (internal month
  /// 7–14) Recovery order for one economically-waiting engineer back into
  /// [assignments] (RECOVERY-LOOP-1).
  ///
  /// Unlike [assignOrderedForMay], which rebuilds the ENTIRE roster from
  /// this workflow's own facts every May, this is an employee-specific
  /// APPEND/UPSERT: every assignment already on [assignments] for a
  /// different `engineerId` is carried forward completely untouched, in
  /// place. Reusing [assignOrderedForMay]'s wholesale-rebuild approach here
  /// would risk losing a continuation/replacement assignment already
  /// committed for another engineer earlier in the fiscal year (Final
  /// Spec's CRITICAL ASSIGNMENT REQUIREMENT) — this method never calls
  /// [assignOrderedForMay] and never replaces [assignments] wholesale.
  ///
  /// Defense in depth, mirroring [assignOrderedForMay]: a no-op unless
  /// [engineerId] genuinely reached [PublicDemoSalesStage.ordered] through
  /// the real sales pipeline
  /// ([PublicDemoEngineerSales.hasGenuineInterviewRecord], never `stage`/
  /// `lastInterviewScore` alone) and is not already counted assigned for
  /// [month] — [PublicDemoAggregate.recoverAssignment] is responsible for
  /// this workflow's remaining Final Spec eligibility checks (month
  /// window, non-terminal, training-unselected, runtime-ready) via
  /// [PublicDemoRecoveryEligibility] before calling this.
  ///
  /// `nextOrderStatus`/`replacementStage` are always set explicitly here
  /// (`accepted`/`ordered`) rather than left to [PublicDemoAssignment]'s
  /// own constructor defaults, per Final Spec. When [engineerId] already
  /// has an assignment entry (e.g. a May-era founding-engineer template it
  /// never actually used), that existing entry's identity/project/economic
  /// fields are preserved and only its order-state fields are updated —
  /// this is the UPSERT half; a brand new entry is APPENDED only when none
  /// exists yet.
  PublicDemoWorkflowState recoverLateYearAssignment(
    String engineerId, {
    required int month,
  }) {
    final engineer = engineers
        .where((candidate) => candidate.id == engineerId)
        .firstOrNull;
    if (engineer == null ||
        engineer.stage != PublicDemoSalesStage.ordered ||
        !engineer.hasGenuineInterviewRecord ||
        assignedEngineerIds(month: month).contains(engineerId)) {
      return this;
    }
    final existing = assignments
        .where((assignment) => assignment.engineerId == engineerId)
        .firstOrNull;
    final genuineProjectId = engineer.genuineInterviewProjectId;
    // CORE-GAMEPLAY Phase 7A: a genuine, project-bound Phase 6 pass always
    // produces a FRESH entry tied to that exact real project — never a
    // reused `existing`/founding-engineer template, even when one already
    // sits on [assignments] for this engineer id (a placeholder never
    // activated, or a prior cycle's now-superseded entry): reusing it here
    // would silently keep stale identity/project fields (including a
    // `projectId` for a *different* project, or none at all) under this
    // new genuine order. The generic, project-agnostic path (no real
    // project behind this pass) is unchanged from before this field
    // existed — still an UPSERT of `existing`/the template.
    final recovered = genuineProjectId != null
        ? PublicDemoAssignment.forOrderedEngineer(
            engineerId: engineer.id,
            engineerName: engineer.name,
            humanity: engineer.interviewProfile.humanity,
            projectId: genuineProjectId,
          ).copyWith(
            nextOrderStatus: PublicDemoNextOrderStatus.accepted,
            replacementStage: PublicDemoReplacementStage.ordered,
          )
        : (existing ??
                  publicDemoInitialAssignments
                      .where(
                        (assignment) => assignment.engineerId == engineerId,
                      )
                      .firstOrNull ??
                  PublicDemoAssignment.forOrderedEngineer(
                    engineerId: engineer.id,
                    engineerName: engineer.name,
                    humanity: engineer.interviewProfile.humanity,
                  ))
              .copyWith(
                nextOrderStatus: PublicDemoNextOrderStatus.accepted,
                replacementStage: PublicDemoReplacementStage.ordered,
              );
    return _withAssignments([
      for (final assignment in assignments)
        if (assignment.engineerId == engineerId) recovered else assignment,
      if (existing == null) recovered,
    ]);
  }

  /// The single domain-owned way to end an assignment whose next-month
  /// order was explicitly declined (CORE-GAMEPLAY Phase 7A: real
  /// start→active→end→available lifecycle), releasing [engineerId] back to
  /// the genuine Sales pipeline (`stage: waiting`) so they can pursue an
  /// entirely new real project via [startSkillSheetReview] → ... →
  /// [recordOrder] → [recoverLateYearAssignment]/[assignOrderedForMay],
  /// exactly like any other waiting engineer — never a fake/placeholder
  /// re-entry. This is the acceptance-criteria "ended engineer becomes
  /// available and can re-enter Sales/Matching" path, and the counterpart
  /// to the pre-existing `replacementStage` mini-cycle (which keeps the
  /// SAME assignment slot and never leaves it): a player may choose either
  /// path once `nextOrderStatus == notOffered`, but never both for the same
  /// decision — see the precondition below.
  ///
  /// A no-op (idempotent, so a duplicate/re-sent command is always safe)
  /// unless: an assignment for [engineerId] exists; its
  /// `nextOrderStatus == notOffered` (the current project's continuation
  /// was already explicitly declined via [PublicDemoAssignment
  /// .willOfferNextMonthFor] — this can never fire while a renewal is still
  /// undecided/offered/accepted); its `replacementStage !=
  /// PublicDemoReplacementStage.ordered` (a replacement already secured
  /// through the existing mini-cycle is a continued, genuine assignment —
  /// ending it here would silently discard a real order the player already
  /// won); and the engineer is genuinely `ordered`
  /// ([PublicDemoEngineerSales.releaseFromAssignment]'s own precondition —
  /// see its doc for why this alone makes a second call a true no-op).
  ///
  /// [month] (Codex P1 fix, PR #215) is the current
  /// [PublicDemoState.month] — required so this can tell whether removing
  /// the row from [assignments] would change [assignedEngineerIds] for the
  /// month still in progress. Before month 7, [assignedEngineerIds] is
  /// [assignedEngineerIdsUnfiltered] — every assignment counts toward
  /// *this* month's revenue regardless of `nextOrderStatus`, precisely
  /// because a June `notOffered` decision is about JULY's continuation,
  /// never June's own already-earned revenue (see
  /// [assignedEngineerIdsUnfiltered]'s own doc). Removing the row
  /// immediately in that window would silently shrink
  /// [PublicDemoState.engineersAssigned] — and therefore
  /// [PublicDemoRevenue.monthlyRevenueForAssignedCount] — for revenue this
  /// engineer genuinely still earned this month (Codex P1, PR #215: a real
  /// bug in an earlier version of this method, caught before merge). So the
  /// row is removed immediately only when doing so changes nothing about
  /// [assignedEngineerIds] for [month] — from month 7 on, this method's own
  /// `nextOrderStatus`/`replacementStage` precondition above already
  /// excludes it from the *filtered* [assignedEngineerIds], making removal
  /// safe and redundant-data cleanup, never a revenue change. Before month
  /// 7, the row is deliberately left in place — inert, and safely
  /// superseded in place by a later genuine re-order via
  /// [recoverLateYearAssignment]'s own upsert (never duplicated) — while
  /// the engineer's stage reset below still happens immediately, exactly
  /// satisfying the Issue's "begin searching for the next project during
  /// the current month" requirement without touching this month's
  /// Finance projection.
  ///
  /// Whichever branch applies, the roster/stage change is atomic in one
  /// [_copyWith] call: there is no intermediate, persistable state where
  /// the engineer is off the roster yet still frozen at `ordered` (which
  /// would otherwise permanently lock them out of [startSkillSheetReview],
  /// a genuine dead end), nor one where a *removed* row still exists
  /// alongside a `waiting` engineer.
  PublicDemoWorkflowState endAssignment(String engineerId, {required int month}) {
    final assignment = assignments
        .where((candidate) => candidate.engineerId == engineerId)
        .firstOrNull;
    if (assignment == null ||
        assignment.nextOrderStatus != PublicDemoNextOrderStatus.notOffered ||
        assignment.replacementStage == PublicDemoReplacementStage.ordered) {
      return this;
    }
    final engineer = engineers
        .where((candidate) => candidate.id == engineerId)
        .firstOrNull;
    if (engineer == null || engineer.stage != PublicDemoSalesStage.ordered) {
      return this;
    }
    final stillCountedThisMonth = assignedEngineerIds(
      month: month,
    ).contains(engineerId);
    return _copyWith(
      assignments: stillCountedThisMonth
          ? assignments
          : [
              for (final candidate in assignments)
                if (candidate.engineerId != engineerId) candidate,
            ],
      engineers: [
        for (final candidate in engineers)
          if (candidate.id == engineerId)
            candidate.releaseFromAssignment()
          else
            candidate,
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Cross-cutting projections consumed by monthly close / Growth / Revenue
  // ---------------------------------------------------------------------

  /// The engineer count already confirmed, before April's close, to become
  /// May's assigned/revenue-generating headcount — every engineer that has
  /// already reached [PublicDemoSalesStage.ordered] through the real sales
  /// pipeline (reachable only via [recordOrder], itself reachable only
  /// after a genuine client-interview pass — see [recordOrder]'s own doc).
  ///
  /// This is the exact derivation [PublicDemoAggregate.closeApril] already
  /// performs inline to build April's `orderedEngineers` argument to
  /// [PublicDemoMonthlyClose.closeApril]/[PublicDemoState.advanceToMay];
  /// extracted here so both that real close and
  /// [PublicDemoCashForecast] (Issue #148 Phase 1A P1 fix) read the exact
  /// same fact instead of each maintaining its own copy of the `ordered`
  /// stage check. Not clamped to [PublicDemoState.engineerCount] — callers
  /// clamp exactly as [PublicDemoState.advanceToMay] already does.
  int get orderedEngineerCount => engineers
      .where((engineer) => engineer.stage == PublicDemoSalesStage.ordered)
      .length;

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

  // ---------------------------------------------------------------------
  // CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): matching proposals.
  // Deliberately independent of the [PublicDemoSalesStage]/`ordered`
  // pipeline above — a proposal only records the player's decision for
  // Phase 6 to pick up; it does not advance `stage`, consume
  // `salesCapacity`/`salesUsed`, or otherwise touch existing sales-pipeline
  // authority.
  // ---------------------------------------------------------------------

  /// The current proposal for [engineerId], if the player has made one and
  /// not since replaced it with another — `null` otherwise.
  PublicDemoMatchingProposal? matchingProposalFor(String engineerId) {
    for (final proposal in matchingProposals) {
      if (proposal.engineerId == engineerId) return proposal;
    }
    return null;
  }

  /// Records the player's "提案する" decision: [engineerId] proposed for
  /// [projectId], made during [month]. At most one proposal is kept per
  /// engineer — a later call for the same [engineerId] replaces the
  /// earlier one rather than accumulating history, since only the current
  /// decision is meaningful input for Phase 6. A no-op unless [engineerId]
  /// actually names a known engineer in [engineers] — this file's own
  /// precondition-gated-transition convention (see this class's own doc),
  /// so a caller cannot record a proposal for a fabricated id.
  ///
  /// Also a no-op once that engineer has already reached
  /// `clientInterviewPassed`/`ordered` (Codex P1-2 fix, PR #214): a genuine
  /// pass is a binding real-world fact — the engineer was actually
  /// interviewed, and evaluated, for the project their proposal named at
  /// that moment. Allowing a later `proposeMatch` to silently swap that
  /// proposal onto a *different*, never-interviewed project would let
  /// [recordOrder] proceed for a project this engineer was never actually
  /// vetted for — a correctness gap Phase 7A's real order/assignment
  /// handoff must never inherit. Once passed, the proposal is permanently
  /// locked to the interviewed project (recoverable at any time via
  /// [PublicDemoEngineerSales.genuineInterviewProjectId]); a *failed*
  /// interview (`clientInterviewFailed`) is unaffected and still freely
  /// re-proposable, exactly as before.
  PublicDemoWorkflowState withMatchingProposal({
    required String engineerId,
    required String projectId,
    required int month,
  }) {
    final engineer = engineers
        .where((candidate) => candidate.id == engineerId)
        .firstOrNull;
    if (engineer == null ||
        engineer.stage == PublicDemoSalesStage.clientInterviewPassed ||
        engineer.stage == PublicDemoSalesStage.ordered) {
      return this;
    }
    return _copyWith(
      matchingProposals: [
        for (final proposal in matchingProposals)
          if (proposal.engineerId != engineerId) proposal,
        PublicDemoMatchingProposal(
          engineerId: engineerId,
          projectId: projectId,
          decidedMonth: month,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // CORE-GAMEPLAY Phase 6 (Project Interview Gameplay): the interactive
  // 案件面談 that turns a Phase 5 [PublicDemoMatchingProposal] into an
  // actual `clientInterviewPassed`/`clientInterviewFailed` outcome, reusing
  // the existing `partnerInterviewPassed` → client-interview 0-slot stage
  // exactly as-is — nothing here consumes `salesCapacity`/`salesUsed`, and
  // `beginSelling`'s existing `clientInterviewFailed` recovery path already
  // gives a failed attempt a dead-end-free way back to selling.
  // ---------------------------------------------------------------------

  /// The current in-progress/completed project-interview session for
  /// [engineerId], if one exists — `null` otherwise. At most one is ever
  /// kept per engineer (see [startProjectInterviewSession]).
  ClientInterviewSession? projectInterviewSessionFor(String engineerId) {
    for (final session in projectInterviewSessions) {
      if (session.employeeId == engineerId) return session;
    }
    return null;
  }

  /// Starts [session] as the project-interview session for its own
  /// [ClientInterviewSession.employeeId] — a no-op (resume) only when an
  /// incomplete session for that engineer **already exists for the same
  /// [ClientInterviewSession.projectId]** — mirrors
  /// [startInterviewSession]'s own idempotency convention, but additionally
  /// keyed by project (Codex P1 fix, PR #214): resuming an incomplete
  /// session purely by employee id was unsafe — if the player closed an
  /// in-progress interview and then used the Matching screen to replace
  /// that engineer's [PublicDemoMatchingProposal] with a *different*
  /// project, the old session's questions/answers (built for the old
  /// project) would otherwise be resumed and then scored against the new
  /// project's fit/requirements by [chooseFollowUp]/[conclude] — old
  /// questions and new-project scoring must never mix.
  ///
  /// A prior session for the same engineer is replaced (never resumed)
  /// whenever it is already *completed* (a past pass/fail attempt — a
  /// failed project interview must be retryable after the engineer returns
  /// to selling and reaches `partnerInterviewPassed` again, for the same or
  /// a newly proposed project — never a dead end), when it names a
  /// *different* [ClientInterviewSession.projectId] than [session] (the
  /// Codex P1 case above: the stale, project-mismatched session is safely
  /// discarded in favor of this fresh one for the currently proposed
  /// project, rather than either resuming it or leaving two sessions
  /// around for the same engineer), or when it names a *different*
  /// [ClientInterviewSession.startedWeek] (Codex P2 fix, PR #214): Public
  /// Demo's own engineer runtime only ever changes at a month-close
  /// boundary ([PublicDemoState.applyMonthlyGrowth]/`selectInternalTraining`
  /// itself only records a selection mid-month — the actual capability
  /// change lands at the next close), so [session]'s own freshly-derived
  /// `startedWeek` (always [PublicDemoState.month] at the moment [session]
  /// was built — see [PublicDemoProjectInterview.start]) differing from the
  /// existing incomplete session's `startedWeek` is exactly "the player
  /// closed this interview, let at least one month pass (training/growth
  /// may have changed this engineer's runtime), and reopened it" — resuming
  /// would otherwise let old questions/answers (built from the old-month
  /// capability) sit alongside new-month capability at
  /// [chooseFollowUp]/[conclude] time. No new persisted field is needed —
  /// this compares [ClientInterviewSession.startedWeek], which already
  /// exists — and the stale session is safely discarded for a fresh
  /// restart, never resumed, exactly like the projectId case above.
  PublicDemoWorkflowState startProjectInterviewSession(
    ClientInterviewSession session,
  ) {
    final hasMatchingIncomplete = projectInterviewSessions.any(
      (existing) =>
          existing.employeeId == session.employeeId &&
          existing.projectId == session.projectId &&
          existing.startedWeek == session.startedWeek &&
          !existing.completed,
    );
    if (hasMatchingIncomplete) return this;
    return _copyWith(
      projectInterviewSessions: [
        for (final existing in projectInterviewSessions)
          if (existing.employeeId != session.employeeId) existing,
        session,
      ],
    );
  }

  /// Replaces the active (not yet completed) project-interview session for
  /// [engineerId] with [update]'s result — mirrors
  /// [updateInterviewSession] exactly, plus a [projectId] match (Codex P1
  /// fix, PR #214, defense in depth alongside [startProjectInterviewSession]
  /// above): a no-op when no such session exists **for this exact
  /// project**, so a stale session left over for a since-replaced proposal
  /// can never be advanced against the wrong project even if some future
  /// caller reached this without going through [startProjectInterviewSession]
  /// first.
  PublicDemoWorkflowState updateProjectInterviewSession(
    String engineerId,
    String projectId,
    ClientInterviewSession Function(ClientInterviewSession session) update,
  ) {
    final index = projectInterviewSessions.indexWhere(
      (session) =>
          session.employeeId == engineerId &&
          session.projectId == projectId &&
          !session.completed,
    );
    if (index < 0) return this;
    final next = [...projectInterviewSessions];
    next[index] = update(next[index]);
    return _copyWith(projectInterviewSessions: next);
  }

  /// Concludes the project interview for [engineerId] and applies its
  /// genuine outcome to the engineer's sales pipeline — the one place the
  /// actual pass/fail is derived (via
  /// [PublicDemoProjectInterview.conclude], itself
  /// [ClientInterviewEngine.finalRate] + [ProjectInterviewEngine.roll]),
  /// mirroring [recordEngineerInterviewResult]/[PublicDemoEngineerSales
  /// .evaluateInterview]'s own "derive, never accept, the outcome"
  /// contract: [runtime]/[project] are real facts the caller
  /// ([PublicDemoAggregate], the only place with both [runSeed] and the
  /// resolved Phase 5 proposal/project) already has in hand — never a
  /// `passed`/`score` assertion.
  ///
  /// A no-op unless: [engineerId] is currently at `partnerInterviewPassed`
  /// (the existing 0-slot client-interview stage this phase reuses as-is);
  /// a genuine, started session exists for it *for this exact [project]*
  /// (Codex P1 fix, PR #214, defense in depth alongside
  /// [startProjectInterviewSession]'s own doc — a session left over for a
  /// since-replaced proposal must never be concluded against a different
  /// project than the one it was actually interviewed for); that session
  /// was also genuinely started *this exact [currentMonth]* (Codex P2 fix,
  /// PR #214, the same defense-in-depth pairing for the month/runtime
  /// freeze — see [startProjectInterviewSession]'s own doc for why a
  /// month-mismatched session must never be concluded either); and every
  /// question in that session has already received a player-chosen
  /// follow-up ([PublicDemoProjectInterview.isReadyToConclude]) — i.e. the
  /// interactive interview genuinely ran to its end, never a shortcut past
  /// the choice sequence.
  PublicDemoWorkflowState concludeProjectInterview({
    required String engineerId,
    required int runSeed,
    required int currentMonth,
    required PublicDemoEngineerRuntime runtime,
    required Project project,
  }) {
    final engineer = engineers
        .where((candidate) => candidate.id == engineerId)
        .firstOrNull;
    if (engineer == null ||
        engineer.stage != PublicDemoSalesStage.partnerInterviewPassed) {
      return this;
    }
    final session = projectInterviewSessionFor(engineerId);
    if (session == null ||
        session.completed ||
        session.projectId != project.id ||
        session.startedWeek != currentMonth ||
        !PublicDemoProjectInterview.isReadyToConclude(session)) {
      return this;
    }

    final outcome = PublicDemoProjectInterview.conclude(
      runSeed: runSeed,
      runtime: runtime,
      project: project,
      session: session,
    );
    final completedSession = session.copyWith(
      completed: true,
      result: outcome.passed
          ? ClientInterviewResult.passed
          : ClientInterviewResult.failed,
    );
    return _copyWith(
      engineers: [
        for (final candidate in engineers)
          if (candidate.id == engineerId)
            candidate.applyProjectInterviewResult(
              passed: outcome.passed,
              score: outcome.score,
              projectId: project.id,
            )
          else
            candidate,
      ],
      projectInterviewSessions: [
        for (final existing in projectInterviewSessions)
          if (existing.employeeId == engineerId) completedSession else existing,
      ],
    );
  }
}
