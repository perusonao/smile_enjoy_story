import 'public_demo_assignment.dart';
import 'public_demo_binding_offer.dart';
import 'public_demo_fiscal_close_id.dart';
import 'public_demo_join.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_sales.dart';
import 'public_demo_salary_offer.dart';

/// The single authoritative source for Public Demo 0.1 workflow facts:
/// applicants (and their recruitment/pre-entry stage, offer, binding offer,
/// and join state), engineer sales-pipeline state, and project assignments.
///
/// Before WORKFLOW-STATE-1A+B, [PublicDemo01PlaceholderScreen] held these
/// three lists as mutable `State` fields and mutated them directly by list
/// index. That made the widget itself the workflow SSOT, with no
/// invariant enforcement beyond whatever the UI happened to check before
/// calling `setState`. This class now owns that data; the widget holds one
/// instance of it and only ever replaces it wholesale via `setState(() =>
/// workflow = ...)`, using the domain methods below (or the dedicated
/// commands in public_demo_binding_offer.dart / public_demo_join.dart /
/// public_demo_recruitment_workflow_transaction.dart) to compute the next
/// value. UI-only concerns (selected tab, dialog visibility, scroll
/// position, the in-progress July summer-bonus confirmation flag) remain
/// widget-local `State` fields — they are not workflow facts.
class PublicDemoWorkflowState {
  factory PublicDemoWorkflowState({
    required List<PublicDemoApplicant> applicants,
    required List<PublicDemoEngineerSales> engineers,
    required List<PublicDemoAssignment> assignments,
  }) => PublicDemoWorkflowState._(
    applicants: List.unmodifiable(applicants),
    engineers: List.unmodifiable(engineers),
    assignments: List.unmodifiable(assignments),
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
    assignments: const [],
  );

  final List<PublicDemoApplicant> applicants;
  final List<PublicDemoEngineerSales> engineers;
  final List<PublicDemoAssignment> assignments;

  /// Deliberately has no `assignments` parameter (WORKFLOW-STATE-1AB FIX2
  /// P1-3): a caller holding a reference to an existing, authoritative
  /// [PublicDemoWorkflowState] cannot inject an arbitrary assignment roster
  /// into it via this public surface. [_copyWith] (below) is the full-field
  /// internal version [_withAssignments] uses instead.
  PublicDemoWorkflowState copyWith({
    List<PublicDemoApplicant>? applicants,
    List<PublicDemoEngineerSales>? engineers,
  }) => _copyWith(applicants: applicants, engineers: engineers);

  PublicDemoWorkflowState _copyWith({
    List<PublicDemoApplicant>? applicants,
    List<PublicDemoEngineerSales>? engineers,
    List<PublicDemoAssignment>? assignments,
  }) => PublicDemoWorkflowState(
    applicants: applicants ?? this.applicants,
    engineers: engineers ?? this.engineers,
    assignments: assignments ?? this.assignments,
  );

  // ---------------------------------------------------------------------
  // Applicants
  // ---------------------------------------------------------------------

  /// Replaces the applicant identified by [applicantId] using [update].
  /// A missing id is a no-op — every call site already has the applicant's
  /// current record in hand, so a missing id would indicate a caller bug
  /// rather than a real workflow event.
  PublicDemoWorkflowState withApplicant(
    String applicantId,
    PublicDemoApplicant Function(PublicDemoApplicant applicant) update,
  ) => copyWith(
    applicants: [
      for (final applicant in applicants)
        if (applicant.id == applicantId) update(applicant) else applicant,
    ],
  );

  PublicDemoWorkflowState withApplicantStage(
    String applicantId,
    PublicDemoApplicantStage stage,
  ) {
    assert(
      stage != PublicDemoApplicantStage.interviewed,
      'interviewed is workflow-significant (WORKFLOW-STATE-1AB FIX2 P1-1A) '
      '— use markApplicantInterviewed instead',
    );
    return withApplicant(
      applicantId,
      (applicant) => applicant.copyWith(stage: stage),
    );
  }

  /// The single sanctioned way to transition an applicant into the
  /// interviewed stage (WORKFLOW-STATE-1AB FIX2 P1-1A) — the prerequisite
  /// [PublicDemoOfferAcceptance.accept] actually checks (via
  /// [PublicDemoApplicant.hasBeenInterviewed]) before it will mint a
  /// [PublicDemoBindingOffer]. [withApplicantStage] intentionally refuses
  /// this specific stage: it is workflow-significant and must not be
  /// reachable through the generic setter.
  PublicDemoWorkflowState markApplicantInterviewed(String applicantId) =>
      withApplicant(applicantId, (applicant) => applicant.markInterviewed());

  /// Appends newly generated applicants (JOB-2/3, now atomic via
  /// public_demo_recruitment_workflow_transaction.dart), skipping any id
  /// already present — mirrors the dedup the widget used to do inline.
  PublicDemoWorkflowState withGeneratedApplicants(
    List<PublicDemoApplicant> generated,
  ) {
    final existingIds = applicants.map((applicant) => applicant.id).toSet();
    return copyWith(
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
  }) => withApplicant(
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
    return copyWith(applicants: kept);
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

  PublicDemoWorkflowState withEngineer(
    String engineerId,
    PublicDemoEngineerSales Function(PublicDemoEngineerSales engineer) update,
  ) => copyWith(
    engineers: [
      for (final engineer in engineers)
        if (engineer.id == engineerId) update(engineer) else engineer,
    ],
  );

  PublicDemoWorkflowState withEngineerStage(
    String engineerId,
    PublicDemoSalesStage stage,
  ) => withEngineer(engineerId, (engineer) => engineer.copyWith(stage: stage));

  /// Adds newly joined applicants as engineers (May's join step), skipping
  /// anyone already present by id — mirrors the widget's former inline
  /// dedup exactly.
  PublicDemoWorkflowState withJoinedEngineers(
    Iterable<PublicDemoApplicant> joined,
  ) => copyWith(
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

  PublicDemoWorkflowState withAssignment(
    String engineerId,
    PublicDemoAssignment Function(PublicDemoAssignment assignment) update,
  ) => _copyWith(
    assignments: [
      for (final assignment in assignments)
        if (assignment.engineerId == engineerId)
          update(assignment)
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
  /// (WORKFLOW-STATE-1AB FIX1 P1-3). Only engineers whose sales pipeline
  /// reached [PublicDemoSalesStage.ordered] and only applicants whose
  /// recruitment pipeline reached [PublicDemoApplicantStage.juneOrdered]
  /// become an assignment — this reads only the authoritative engineer/
  /// applicant stage facts already on this workflow, so the caller (the
  /// widget) supplies no roster of its own and cannot fabricate one.
  /// Reproduces exactly the roster the pre-cutover widget computed inline.
  PublicDemoWorkflowState assignOrderedForMay() {
    final nextAssignments = [
      for (final engineer in engineers)
        if (engineer.stage == PublicDemoSalesStage.ordered)
          publicDemoInitialAssignments
                  .where((assignment) => assignment.engineerId == engineer.id)
                  .firstOrNull ??
              PublicDemoAssignment.forOrderedEngineer(
                engineerId: engineer.id,
                engineerName: engineer.name,
                humanity: engineer.interviewProfile.humanity,
              ),
      for (final applicant in applicants)
        if (applicant.stage == PublicDemoApplicantStage.juneOrdered)
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
