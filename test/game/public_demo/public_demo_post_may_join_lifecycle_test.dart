import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';

/// Issue #221 FIRST-FUN-YEAR: end-to-end regression for the recruitment→
/// join→employee-authority connection for applicants hired in May or any
/// later month (June/July/August — Public Demo 0.1's real recruiting
/// window per [PublicDemoState.canUseRecruitmentMediaInMonth]).
///
/// Root cause (see the result report): [PublicDemoAggregate.closeMay] was
/// the ONLY month-end close that ever actually joined an accepted
/// applicant (via `PublicDemoWorkflowState.joinAndKeepOnly`) or recorded
/// the join into [PublicDemoState.engineerCount]/[joinedApplicantIds] (via
/// `PublicDemoState.advanceToJune`). `closeJune`/`closeJuly`/
/// `closeOrdinaryMonth` never did either, so an applicant recruited and
/// hired after May reached a real accepted/ordered stage and then simply
/// stayed there forever — never an engineer, never on payroll, never
/// visible to SkillSheet/Sales/Matching. Fixed by generalizing the join
/// step (`PublicDemoAggregate._joinAcceptedApplicants`,
/// `PublicDemoWorkflowState.joinAcceptedForFiscalClose`,
/// `PublicDemoState.recordNewJoins`) to every month-end close.
void main() {
  /// Recruits via the real `engineer` medium, interviews, and accepts an
  /// offer at the requested salary for the first generated applicant —
  /// mirrors `public_demo_aggregate_test.dart`'s own `hireApplicant`
  /// fixture, generalized to run in whatever month [aggregate] is
  /// currently at (never hard-coded to May). `acceptanceScore: 100` is a
  /// deliberately hand-built offer (not `PublicDemoSalaryOfferEvaluator
  /// .evaluate`) so this fixture always accepts regardless of the
  /// generated applicant's own (seed-dependent) acceptanceScore — the same
  /// reason `hireApplicant` there does it.
  ({PublicDemoAggregate aggregate, String applicantId}) recruitAndAccept(
    PublicDemoAggregate aggregate,
  ) {
    final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);
    expect(recruited.isSuccess, isTrue);
    var next = recruited.aggregate!;
    final applicantId = next.workflow.applicants.first.id;
    final interview = next.completeInterview(applicantId);
    expect(interview.isCompleted, isTrue);
    next = interview.aggregate;
    final applicant = next.workflow.applicants.firstWhere(
      (candidate) => candidate.id == applicantId,
    );
    final offer = PublicDemoSalaryOffer(
      requestedMonthlySalary: applicant.requestedMonthlySalary,
      offeredMonthlySalary: applicant.requestedMonthlySalary,
      acceptanceScore: 100,
      motivationDelta: 0,
      trustDelta: 0,
    );
    final beforeAccept = next.state.month;
    next = next.acceptOffer(
      applicantId: applicantId,
      offer: offer,
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(beforeAccept),
    );
    final accepted = next.workflow.applicants.firstWhere(
      (candidate) => candidate.id == applicantId,
    );
    expect(
      accepted.stage,
      PublicDemoApplicantStage.offerAccepted,
      reason: 'acceptanceScore: 100 must always accept',
    );
    return (aggregate: next, applicantId: applicantId);
  }

  group('May hire: unaffected baseline (closeMay already worked)', () {
    test('a May-accepted applicant joins at closeMay, appears on the '
        'engineer roster, and is counted in the headcount/roster '
        'projection', () {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses);
      final hired = recruitAndAccept(aggregate);
      aggregate = hired.aggregate.closeMay(
        week: 9,
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      );

      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(applicant.hasJoined, isTrue);
      expect(
        aggregate.workflow.engineers.any((e) => e.id == hired.applicantId),
        isTrue,
      );
      expect(aggregate.state.joinedApplicantIds, contains(hired.applicantId));
    });
  });

  group('June/July/August hires: previously a structural dead end, now '
      'reach the same employee authority as May hires', () {
    test('a June-accepted applicant joins at closeJune, becomes an '
        'engineer, and is on the roster/headcount projection', () {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          ); // month 6
      final engineersBefore = aggregate.workflow.engineers.length;
      final hired = recruitAndAccept(aggregate);
      final beforeClose = hired.aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(beforeClose.hasJoined, isFalse);

      aggregate = hired.aggregate.closeJune(
        assignedInJuly: 0,
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: hired.aggregate.workflow.joinedApplicants,
        ),
      );

      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(applicant.hasJoined, isTrue);
      expect(aggregate.workflow.engineers, hasLength(engineersBefore + 1));
      expect(
        aggregate.workflow.engineers.any((e) => e.id == hired.applicantId),
        isTrue,
      );
      expect(aggregate.state.joinedApplicantIds, contains(hired.applicantId));
      expect(aggregate.state.engineerCount, engineersBefore + 1);
    });

    test('a July-accepted applicant joins at closeJuly (with the zero '
        'summer-bonus plan, so the close is always eligible), becomes an '
        'engineer, and is on the roster/headcount projection', () {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          )
          .closeJune(
            assignedInJuly: 0,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          ); // month 7
      final engineersBefore = aggregate.workflow.engineers.length;
      final hired = recruitAndAccept(aggregate);

      aggregate = hired.aggregate.closeJuly(
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: hired.aggregate.workflow.joinedApplicants,
          month: 7,
        ),
      );

      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(applicant.hasJoined, isTrue);
      expect(aggregate.workflow.engineers, hasLength(engineersBefore + 1));
      expect(aggregate.state.joinedApplicantIds, contains(hired.applicantId));
      expect(aggregate.state.engineerCount, engineersBefore + 1);
    });

    test('an August-accepted applicant joins at closeOrdinaryMonth (the '
        'last month recruit() is legal — canUseRecruitmentMediaInMonth '
        'ends at 8), becomes an engineer, and is on the roster/headcount '
        'projection', () {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          )
          .closeJune(
            assignedInJuly: 0,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          )
          .closeJuly(
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          ); // month 8
      expect(aggregate.state.month, 8);
      expect(aggregate.state.canUseRecruitmentMediaInMonth(8), isTrue);
      final engineersBefore = aggregate.workflow.engineers.length;
      final hired = recruitAndAccept(aggregate);

      aggregate = hired.aggregate.closeOrdinaryMonth(
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: hired.aggregate.workflow.joinedApplicants,
          month: 8,
        ),
      );

      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(applicant.hasJoined, isTrue);
      expect(aggregate.workflow.engineers, hasLength(engineersBefore + 1));
      expect(aggregate.state.joinedApplicantIds, contains(hired.applicantId));
    });

    test('an applicant who is NEVER offered/accepted never joins, even '
        'after every later month-end close now performs the join step', () {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          );
      final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);
      expect(recruited.isSuccess, isTrue);
      aggregate = recruited.aggregate!;
      final applicantId = aggregate.workflow.applicants.first.id;
      final engineersBefore = aggregate.workflow.engineers.length;

      // Never interviewed/offered — just left in the pipeline.
      aggregate = aggregate
          .closeJune(assignedInJuly: 0, monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeJuly(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeOrdinaryMonth(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses);

      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == applicantId,
      );
      expect(applicant.hasJoined, isFalse);
      expect(aggregate.workflow.engineers, hasLength(engineersBefore));
      expect(aggregate.state.joinedApplicantIds, isNot(contains(applicantId)));
    });

    test('duplicate/retry safety: the same already-joined applicant is '
        'never double-joined, never duplicated on the engineer roster, and '
        'never double-counted in headcount across repeated ordinary-month '
        'closes', () {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          )
          .closeJune(
            assignedInJuly: 0,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          ); // month 7
      final hired = recruitAndAccept(aggregate);
      aggregate = hired.aggregate.closeJuly(
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      ); // joins here; month 8
      final countAfterJoin = aggregate.state.engineerCount;
      final engineersAfterJoin = aggregate.workflow.engineers.length;

      // Two more ordinary-month closes (month-crossing retries).
      aggregate = aggregate
          .closeOrdinaryMonth(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeOrdinaryMonth(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses);

      expect(aggregate.state.engineerCount, countAfterJoin);
      expect(aggregate.workflow.engineers, hasLength(engineersAfterJoin));
      expect(
        aggregate.workflow.engineers
            .where((e) => e.id == hired.applicantId)
            .length,
        1,
      );
      expect(
        aggregate.state.joinedApplicantIds
            .where((id) => id == hired.applicantId)
            .length,
        1,
      );
    });

    test('payroll boundary: before joining the hire is never on payroll; '
        'after joining, existing payroll authority (currentMonthlySalaryFor) '
        'picks them up automatically', () {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          ); // month 6
      final hired = recruitAndAccept(aggregate);

      // Before joining: not on payroll, regardless of stage.
      expect(
        PublicDemoSalary.currentMonthlySalaryFor(
          hired.applicantId,
          applicants: hired.aggregate.workflow.applicants,
        ),
        isNull,
      );

      aggregate = hired.aggregate.closeJune(
        assignedInJuly: 0,
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: hired.aggregate.workflow.joinedApplicants,
        ),
      );

      // After joining: on payroll, at their own accepted salary.
      final salary = PublicDemoSalary.currentMonthlySalaryFor(
        hired.applicantId,
        applicants: aggregate.workflow.applicants,
      );
      expect(salary, isNotNull);
      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(salary, applicant.acceptedMonthlySalary);
    });

    test('save/reload round-trips correctly both before and after joining '
        '— hasJoined, engineerCount, and joinedApplicantIds all survive', () {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          );
      final hired = recruitAndAccept(aggregate);

      // Before joining.
      final beforeJson = hired.aggregate.toJson();
      final beforeReloaded = PublicDemoAggregate.fromJson(beforeJson);
      final beforeApplicant = beforeReloaded.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(beforeApplicant.hasJoined, isFalse);
      expect(
        beforeReloaded.workflow.engineers.any((e) => e.id == hired.applicantId),
        isFalse,
      );

      // After joining.
      final joined = hired.aggregate.closeJune(
        assignedInJuly: 0,
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: hired.aggregate.workflow.joinedApplicants,
        ),
      );
      final afterJson = joined.toJson();
      final afterReloaded = PublicDemoAggregate.fromJson(afterJson);
      final afterApplicant = afterReloaded.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(afterApplicant.hasJoined, isTrue);
      expect(
        afterReloaded.workflow.engineers.any((e) => e.id == hired.applicantId),
        isTrue,
      );
      expect(afterReloaded.state.joinedApplicantIds, contains(hired.applicantId));
      expect(afterReloaded.state.engineerCount, joined.state.engineerCount);
    });

    test('full lifecycle to 参画 (assignment): a June-joined hire walks '
        'SkillSheet → selling → Matching-introduction → partner interview '
        '→ client interview → order → Recovery-assignment (participation), '
        'the same production authority every other engineer uses', () {
      // Seed 358's first `engineer`-medium candidate generated right after
      // closeApril/closeMay has salesSkillFit 100 (found via a one-off
      // deterministic search of the same seeded generator every other
      // candidate uses) — comfortably clears both the partner (60) and
      // client (60) interview thresholds together with the
      // fromApplicant() default humanity/morale/clientTrust profile, with
      // no change to any evaluator/threshold.
      var aggregate = PublicDemoAggregate.initial(runSeed: 358)
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          ); // month 6
      final hired = recruitAndAccept(aggregate);
      final applicant = hired.aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(applicant.salesSkillFit, greaterThanOrEqualTo(70));

      aggregate = hired.aggregate.closeJune(
        assignedInJuly: 0,
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: hired.aggregate.workflow.joinedApplicants,
        ),
      ); // month 7 — Recovery-eligible from here on.
      final engineerId = hired.applicantId;
      expect(
        aggregate.workflow.engineers.any((e) => e.id == engineerId),
        isTrue,
      );

      // SkillSheet review → selling → Matching introduction.
      aggregate = aggregate
          .startSkillSheetReview(engineerId)
          .beginSelling(engineerId)
          .introduceProject(engineerId);
      expect(
        aggregate.workflow.engineers
            .firstWhere((e) => e.id == engineerId)
            .stage,
        PublicDemoSalesStage.introduced,
      );

      // 上位会社面談 (partner interview) → 客先面談 (client interview).
      aggregate = aggregate.recordEngineerInterviewResult(
        engineerId: engineerId,
        type: PublicDemoInterviewType.partner,
      );
      expect(
        aggregate.workflow.engineers
            .firstWhere((e) => e.id == engineerId)
            .stage,
        PublicDemoSalesStage.partnerInterviewPassed,
      );
      aggregate = aggregate.recordEngineerInterviewResult(
        engineerId: engineerId,
        type: PublicDemoInterviewType.client,
      );
      expect(
        aggregate.workflow.engineers
            .firstWhere((e) => e.id == engineerId)
            .stage,
        PublicDemoSalesStage.clientInterviewPassed,
      );

      // 受注 (order).
      aggregate = aggregate.recordOrder(engineerId);
      expect(
        aggregate.workflow.engineers
            .firstWhere((e) => e.id == engineerId)
            .stage,
        PublicDemoSalesStage.ordered,
      );

      // 参画: Recovery is the production authority that turns a genuinely
      // ordered engineer — new hire or not — into a real assignment from
      // month 7 onward (RECOVERY-LOOP-1 was deliberately written with no
      // "already had a prior assignment" precondition) — `aggregate` is
      // already at month 7 here (closeJune's own May->June->July
      // transition), exactly Recovery's first eligible month.
      expect(aggregate.state.month, 7);
      aggregate = aggregate.recoverAssignment(engineerId);

      expect(
        aggregate.workflow.assignments.any((a) => a.engineerId == engineerId),
        isTrue,
      );
      expect(
        aggregate.workflow.assignedEngineerIds(month: aggregate.state.month),
        contains(engineerId),
      );
      // 給与/売上: on payroll, and counted in the assigned headcount every
      // existing Finance/Revenue authority already keys revenue off.
      expect(
        PublicDemoSalary.currentMonthlySalaryFor(
          engineerId,
          applicants: aggregate.workflow.applicants,
        ),
        isNotNull,
      );
      expect(aggregate.state.engineersAssigned, greaterThanOrEqualTo(1));
    });
  });

  group('pre-entry order preservation at a later join (PR #222 review '
      'finding)', () {
    /// Walks [applicantId] through the same pre-entry pipeline May's own
    /// cohort uses to secure an order before officially joining —
    /// `beginPreEntrySkillSheet` → `beginPreEntrySelling` →
    /// `introducePreEntryProject` → `recordPreEntryPartnerInterviewResult`
    /// → `recordPreEntryClientInterviewResult` → `recordJuneOrder` — none
    /// of which is month-gated, so a June-or-later hire can win this exact
    /// same order too.
    PublicDemoAggregate walkToPreEntryOrder(
      PublicDemoAggregate aggregate,
      String applicantId,
    ) => aggregate
        .beginPreEntrySkillSheet(applicantId)
        .beginPreEntrySelling(applicantId)
        .introducePreEntryProject(applicantId)
        .recordPreEntryPartnerInterviewResult(applicantId)
        .recordPreEntryClientInterviewResult(applicantId)
        .recordJuneOrder(applicantId);

    test('a June-accepted applicant who also wins a pre-entry order before '
        'closeJune joins already assigned to a real project — not '
        'downgraded to a plain waiting engineer who would have to redo '
        'Sales/Matching/interviews for an order already won', () {
      // Seed 358's first `engineer`-medium candidate generated right after
      // closeApril/closeMay has salesSkillFit 100 (same seed the "full
      // lifecycle" test above uses, same generation point) — needed here
      // because recordPreEntryPartnerInterviewResult/
      // recordPreEntryClientInterviewResult derive pass/fail deterministically
      // from the applicant's own salesSkillFit (>=60/>=65), so an
      // unseeded default aggregate would make this pre-entry walk flaky.
      var aggregate = PublicDemoAggregate.initial(runSeed: 358)
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          ); // month 6
      final hired = recruitAndAccept(aggregate);
      aggregate = walkToPreEntryOrder(hired.aggregate, hired.applicantId);
      final beforeClose = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(beforeClose.stage, PublicDemoApplicantStage.juneOrdered);
      expect(beforeClose.hasJoined, isFalse);
      final assignedBefore = aggregate.state.engineersAssigned;

      aggregate = aggregate.closeJune(
        assignedInJuly: 0,
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: aggregate.workflow.joinedApplicants,
        ),
      );

      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(applicant.hasJoined, isTrue);
      expect(
        aggregate.workflow.assignments
            .any((a) => a.engineerId == hired.applicantId),
        isTrue,
        reason: 'the already-won pre-entry order must become a real '
            'assignment, not be discarded',
      );
      expect(aggregate.state.engineersAssigned, assignedBefore + 1);

      // Retrying the same close idempotently — no duplicate assignment.
      final retried = aggregate.closeJune(
        assignedInJuly: 0,
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      );
      expect(
        retried.workflow.assignments
            .where((a) => a.engineerId == hired.applicantId)
            .length,
        1,
      );
    });

    test('a July-accepted applicant with a pre-entry order joins assigned '
        'at closeJuly too — the fix generalizes beyond June', () {
      // Seed 454's first `engineer`-medium candidate generated right after
      // closeApril/closeMay/closeJune has salesSkillFit 100 — same
      // determinism reason as the June test above, re-searched for this
      // sequence's own RNG stream position (one more recruit/close ahead).
      var aggregate = PublicDemoAggregate.initial(runSeed: 454)
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          )
          .closeJune(
            assignedInJuly: 0,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          ); // month 7
      final hired = recruitAndAccept(aggregate);
      aggregate = walkToPreEntryOrder(hired.aggregate, hired.applicantId);
      final assignedBefore = aggregate.state.engineersAssigned;

      aggregate = aggregate.closeJuly(
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: aggregate.workflow.joinedApplicants,
          month: 7,
        ),
      );

      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(applicant.hasJoined, isTrue);
      expect(
        aggregate.workflow.assignments
            .any((a) => a.engineerId == hired.applicantId),
        isTrue,
      );
      expect(aggregate.state.engineersAssigned, assignedBefore + 1);
    });

    test('a June-accepted applicant WITHOUT a pre-entry order still joins '
        'as a plain waiting engineer — the fix only preserves a genuine, '
        'already-won order, it never fabricates an assignment for someone '
        'who never earned one', () {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          ); // month 6
      final hired = recruitAndAccept(aggregate);
      // No pre-entry pipeline walked — stage stays offerAccepted.

      final aggregateAfter = hired.aggregate.closeJune(
        assignedInJuly: 0,
        monthlyExpenses: PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          hires: hired.aggregate.workflow.joinedApplicants,
        ),
      );

      final applicant = aggregateAfter.workflow.applicants.firstWhere(
        (candidate) => candidate.id == hired.applicantId,
      );
      expect(applicant.hasJoined, isTrue);
      expect(
        aggregateAfter.workflow.assignments
            .any((a) => a.engineerId == hired.applicantId),
        isFalse,
      );
      expect(
        aggregateAfter.workflow.engineers
            .firstWhere((e) => e.id == hired.applicantId)
            .stage,
        PublicDemoSalesStage.waiting,
      );
    });
  });

  group(
    'Issue #241 FIRST-FUN-YEAR Recruitment Flow / Next Action Clarity: '
    'Fresh Audit §9 — an applicant can never appear without a genuine '
    'recruit() call, at any month boundary',
    () {
      test(
        'April with no recruitment media used: closing April into May '
        'produces zero applicants — the Human Replay #225 "4月に求人を出して'
        'いないのに5月に応募者が出る" symptom does not reproduce on current '
        'main (CORE-GAMEPLAY Phase 4.5 already removed all pre-seeded '
        'applicants; PublicDemoWorkflowState.initial() starts genuinely '
        'empty, and no month-close command ever generates an applicant)',
        () {
          final aggregate = PublicDemoAggregate.initial();
          expect(
            aggregate.workflow.applicants,
            isEmpty,
            reason: 'a new game must start with zero applicants',
          );

          final mayAggregate = aggregate.closeApril(
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          );
          expect(mayAggregate.state.month, 5);
          expect(
            mayAggregate.workflow.applicants,
            isEmpty,
            reason:
                'no applicant may ever appear in May without an explicit '
                'recruit() call in April or May — closeApril is the only '
                'production path from month 4 to month 5, and it never '
                'calls recruit()/withGeneratedApplicants itself',
          );

          // The same holds walking forward without ever recruiting: no
          // month-end close command anywhere in the aggregate invents an
          // applicant on its own.
          final juneAggregate = mayAggregate.closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          );
          expect(juneAggregate.workflow.applicants, isEmpty);
        },
      );
    },
  );
}
