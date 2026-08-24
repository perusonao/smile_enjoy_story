import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_offer_test_helpers.dart';

/// WORKFLOW-STATE-1AB FIX3: [PublicDemoAggregate] is the single authoritative
/// Public Demo 0.1 root. These tests target the four P1 closures directly
/// through the aggregate — the actual production boundary the widget now
/// exercises (public_demo_01_placeholder_screen.dart) — rather than the
/// lower-level building blocks alone (already covered by
/// public_demo_workflow_state_test.dart, public_demo_binding_offer_test.dart,
/// public_demo_join_test.dart, and public_demo_monthly_close_test.dart).
void main() {
  group('P1-1: interview authority (completeInterview)', () {
    test(
      'a genuine interview succeeds and consumes exactly one sales slot',
      () {
        final aggregate = PublicDemoAggregate.initial();
        final applicantId = aggregate.workflow.applicants.first.id;
        final salesBefore = aggregate.state.salesRemaining;

        final result = aggregate.completeInterview(applicantId);

        expect(result.isCompleted, isTrue);
        expect(
          result.aggregate.state.salesRemaining,
          salesBefore - 1,
          reason:
              'the real prerequisite — a consumed sales slot — must move '
              'together with the interview record, in the same aggregate',
        );
        final interviewed = result.aggregate.workflow.applicants.firstWhere(
          (a) => a.id == applicantId,
        );
        expect(interviewed.hasBeenInterviewed, isTrue);
      },
    );

    test(
      'no sales slot available: completeInterview rejects and changes nothing',
      () {
        // salesCapacity - salesUsed == 0: an exhausted budget reached the
        // same way `useSalesSlot`/`completeInterview` themselves reach it
        // (incrementing `salesUsed`), just precomputed here so the test
        // does not need as many distinct applicants as
        // PublicDemoState.aprilStart()'s salesCapacity.
        final aggregate = PublicDemoAggregate.restore(
          state: PublicDemoState.aprilStart().copyWith(
            salesUsed: PublicDemoState.aprilStart().salesCapacity,
          ),
          workflow: PublicDemoWorkflowState.initial(),
        );
        expect(aggregate.state.salesRemaining, 0);

        final target = aggregate.workflow.applicants[1];
        expect(target.hasBeenInterviewed, isFalse);

        final result = aggregate.completeInterview(target.id);

        expect(result.isCompleted, isFalse);
        expect(result.status, PublicDemoInterviewCompletionStatus.noSalesSlot);
        expect(result.aggregate.state, same(aggregate.state));
        expect(result.aggregate.workflow, same(aggregate.workflow));
      },
    );

    test('unknown applicant id is rejected, not silently accepted', () {
      final aggregate = PublicDemoAggregate.initial();

      final result = aggregate.completeInterview('does-not-exist');

      expect(result.isCompleted, isFalse);
      expect(
        result.status,
        PublicDemoInterviewCompletionStatus.unknownApplicant,
      );
      expect(result.aggregate.state, same(aggregate.state));
    });

    test('duplicate interview transition is a no-op: a second call neither '
        'consumes another slot nor errors', () {
      final aggregate = PublicDemoAggregate.initial();
      final applicantId = aggregate.workflow.applicants.first.id;

      final first = aggregate.completeInterview(applicantId);
      expect(first.isCompleted, isTrue);
      final salesAfterFirst = first.aggregate.state.salesRemaining;

      final second = first.aggregate.completeInterview(applicantId);

      expect(second.isCompleted, isFalse);
      expect(
        second.status,
        PublicDemoInterviewCompletionStatus.alreadyInterviewed,
      );
      expect(second.aggregate.state.salesRemaining, salesAfterFirst);
      expect(second.aggregate, same(first.aggregate));
    });

    // WORKFLOW-STATE-1AB FIX3 P1-1: the direct bypass the independent
    // review flagged — `workflow.withApplicant(id, (a) =>
    // a.markInterviewed())` — no longer compiles at all:
    // `PublicDemoApplicant` has no `markInterviewed()` method any more, and
    // `completeInterview(proof)` requires an unforgeable
    // `PublicDemoSalesSlotConsumptionProof` this test file cannot construct
    // (its constructor is private to public_demo_state.dart, and the only
    // place that mints one is `PublicDemoState.useSalesSlotForInterview`
    // when it genuinely consumes a slot). This test proves the remaining,
    // structurally-available surface — `withApplicant` combined with
    // anything this file *can* construct — still cannot mint one.
    test('withApplicant cannot fabricate interview completion: no lambda this '
        'file can write mints a genuine PublicDemoInterviewRecord', () {
      final workflow = PublicDemoWorkflowState.initial();
      final applicantId = workflow.applicants.first.id;

      // The broadest fabrication attempt available: replace the real
      // applicant with a freshly constructed one that sets `stage`
      // directly (still publicly settable — WORKFLOW-STATE-1AB §6) but
      // supplies no interviewRecord.
      final attempted = workflow.withApplicant(
        applicantId,
        (a) => a.copyWith(stage: PublicDemoApplicantStage.interviewed),
      );

      final fabricated = attempted.applicants.firstWhere(
        (a) => a.id == applicantId,
      );
      expect(fabricated.stage, PublicDemoApplicantStage.interviewed);
      expect(
        fabricated.hasBeenInterviewed,
        isFalse,
        reason: 'stage alone is not proof — see PublicDemoOfferAcceptance',
      );
    });

    test('genuine interview then offer acceptance succeeds end-to-end', () {
      final aggregate = PublicDemoAggregate.initial();
      final applicant = aggregate.workflow.applicants.first;

      final afterInterview = aggregate
          .completeInterview(applicant.id)
          .aggregate;
      final offer = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: afterInterview.workflow.applicants.firstWhere(
          (a) => a.id == applicant.id,
        ),
        offeredMonthlySalary: applicant.requestedMonthlySalary,
      );
      final afterOffer = afterInterview.acceptOffer(
        applicantId: applicant.id,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(4),
      );

      final decided = afterOffer.workflow.applicants.firstWhere(
        (a) => a.id == applicant.id,
      );
      expect(decided.hasBindingOffer, isTrue);
    });

    test('offer acceptance before a genuine interview is rejected, even though '
        'the applicant already exists in the authoritative workflow', () {
      final aggregate = PublicDemoAggregate.initial();
      final applicant = aggregate.workflow.applicants.first;
      expect(applicant.hasBeenInterviewed, isFalse);

      final offer = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: applicant.requestedMonthlySalary,
      );
      final result = aggregate.acceptOffer(
        applicantId: applicant.id,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(4),
      );

      final decided = result.workflow.applicants.firstWhere(
        (a) => a.id == applicant.id,
      );
      expect(decided.hasBindingOffer, isFalse);
    });
  });

  group('P1-2: recruitment atomicity (recruit)', () {
    test('finance-only commit is impossible through the public API: there '
        'is no field that exposes a committed PublicDemoState without the '
        'paired PublicDemoWorkflowState', () {
      final aggregate = PublicDemoAggregate.initial();
      final result = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isTrue);
      // The ONLY way to read the committed outcome is `result.aggregate`,
      // which always carries state and workflow together.
      expect(result.aggregate!.state.cash, lessThan(aggregate.state.cash));
      expect(
        result.aggregate!.workflow.applicants.length,
        greaterThan(aggregate.workflow.applicants.length),
      );
    });

    test('insufficient cash leaves the aggregate unchanged (both roots)', () {
      final aggregate = PublicDemoAggregate.restore(
        state: aggregatePoorState(),
        workflow: PublicDemoWorkflowState.initial(),
      );

      final result = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isFalse);
      expect(result.aggregate, isNull);
    });

    test('applicant generation failure leaves the aggregate unchanged', () {
      final aggregate = PublicDemoAggregate.initial();

      final result = aggregate.recruit(
        PublicDemoRecruitmentMedium.engineer,
        candidateGenerator:
            ({required month, required medium, required count}) => const [],
      );

      expect(result.isSuccess, isFalse);
      expect(result.aggregate, isNull);
    });

    test('success changes finance and workflow together, never one alone', () {
      final aggregate = PublicDemoAggregate.initial();
      final result = aggregate.recruit(PublicDemoRecruitmentMedium.free);

      expect(result.isSuccess, isTrue);
      // Free media costs nothing but still must have used the monthly
      // guard and appended applicants — both roots move together.
      expect(
        result.aggregate!.state.recruitmentMediumUsedMonth,
        aggregate.state.month,
      );
      expect(
        result.aggregate!.workflow.applicants.length,
        aggregate.workflow.applicants.length + 1,
      );
    });

    test('result facts (medium/chargedAmount/generatedApplicants/status) '
        'cannot mutate authority: they are read-only data about the attempt, '
        'not a second root', () {
      final aggregate = PublicDemoAggregate.initial();
      final result = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);

      // Reading these facts has no effect on `aggregate` itself — the
      // original instance is untouched (Dart immutability), and nothing
      // about the result type lets a caller feed them back in as
      // authority (there is no `PublicDemoWorkflowState(...,
      // applicants: result.generatedApplicants)` that would make them
      // "already joined"/"already interviewed" — they are freshly
      // constructed, unauthoritative value objects).
      final originalIds = aggregate.workflow.applicants
          .map((a) => a.id)
          .toSet();
      final generatedIds = result.generatedApplicants.map((a) => a.id).toSet();
      expect(originalIds.intersection(generatedIds), isEmpty);
      for (final applicant in result.generatedApplicants) {
        expect(applicant.hasBeenInterviewed, isFalse);
        expect(applicant.hasJoined, isFalse);
        expect(applicant.hasBindingOffer, isFalse);
      }
    });
  });

  group('P1-3: assignment authority (via closeMay)', () {
    test('fake assignment roster cannot construct an authoritative aggregate: '
        'PublicDemoAggregate.restore + PublicDemoWorkflowState.restore are '
        'the only ways to inject one, and neither is on the production '
        'command surface the widget uses', () {
      const fabricatedRoster = [
        PublicDemoAssignment(
          engineerId: 'intruder',
          engineerName: 'Fabricated',
          projectName: 'Fabricated Project',
          deliveryPressure: 0,
          budgetHealth: 100,
          humanity: 100,
        ),
      ];
      // This compiles ONLY via `.restore` — the safe production factory
      // (`PublicDemoWorkflowState(applicants:, engineers:)`) has no
      // `assignments` parameter at all (P1-3).
      final workflow = PublicDemoWorkflowState.restore(
        applicants: const [],
        engineers: const [],
        assignments: fabricatedRoster,
      );
      // Once restored, `closeMay` (the production transition) always
      // REPLACES the roster wholesale via `assignOrderedForMay` — the
      // fabricated entry never survives a real close.
      final aggregate = PublicDemoAggregate.restore(
        state: aggregateMayState(),
        workflow: workflow,
      );

      final result = aggregate.closeMay(week: 9, monthlyExpenses: 800000);

      expect(
        result.workflow.assignments.any((a) => a.engineerId == 'intruder'),
        isFalse,
      );
    });

    test('valid assignment succeeds: an ordered engineer gets a real May '
        'assignment through closeMay', () {
      const orderedEngineer = PublicDemoEngineerSales(
        id: 'agg-eng-01',
        name: 'Ordered Engineer',
        summary: 'summary',
        stage: PublicDemoSalesStage.ordered,
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 70,
          humanity: 70,
          morale: 70,
          clientTrust: 60,
        ),
      );
      final aggregate = PublicDemoAggregate.restore(
        state: aggregateMayState(),
        workflow: PublicDemoWorkflowState.restore(
          applicants: const [],
          engineers: const [orderedEngineer],
          assignments: const [],
        ),
      );

      final result = aggregate.closeMay(week: 9, monthlyExpenses: 800000);

      expect(result.workflow.assignments, isNotEmpty);
      expect(
        result.workflow.assignments.every(
          (a) =>
              aggregate.workflow.engineers.any((e) => e.id == a.engineerId) ||
              aggregate.workflow.applicants.any((ap) => ap.id == a.engineerId),
        ),
        isTrue,
      );
    });
  });

  group('P1-4: joined/payroll projection (via closeMay)', () {
    test('two genuine joined applicants both survive closeMay — there is no '
        'joinedApplicants parameter on the aggregate to omit either one', () {
      final first = acceptTestOffer(
        const PublicDemoApplicant(
          id: 'agg-hire-01',
          name: 'Hire 1',
          resumeSummary: 'Java 3年',
          interviewScore: 70,
          acceptanceScore: 70,
          salesSkillFit: 70,
          requestedMonthlySalary: 320000,
        ),
        offeredMonthlySalary: 320000,
      );
      final second = acceptTestOffer(
        const PublicDemoApplicant(
          id: 'agg-hire-02',
          name: 'Hire 2',
          resumeSummary: 'Java 2年',
          interviewScore: 65,
          acceptanceScore: 65,
          salesSkillFit: 65,
          requestedMonthlySalary: 300000,
        ),
        offeredMonthlySalary: 300000,
      );
      final aggregate = PublicDemoAggregate.restore(
        state: aggregateMayState(),
        workflow: PublicDemoWorkflowState.restore(
          applicants: [
            first.copyWith(stage: PublicDemoApplicantStage.offerAccepted),
            second.copyWith(stage: PublicDemoApplicantStage.offerAccepted),
          ],
          engineers: const [],
          assignments: const [],
        ),
      );

      final result = aggregate.closeMay(week: 9, monthlyExpenses: 800000);

      expect(result.state.joinedApplicantIds.toSet(), {
        'agg-hire-01',
        'agg-hire-02',
      });
    });

    test('duplicate identity in the workflow cannot duplicate payroll '
        'membership: joinedApplicantIds is a deduplicated set-like list', () {
      final hire = acceptTestOffer(
        const PublicDemoApplicant(
          id: 'agg-hire-dup',
          name: 'Hire',
          resumeSummary: 'Java 3年',
          interviewScore: 70,
          acceptanceScore: 70,
          salesSkillFit: 70,
          requestedMonthlySalary: 320000,
        ),
        offeredMonthlySalary: 320000,
      ).copyWith(stage: PublicDemoApplicantStage.offerAccepted);
      final aggregate = PublicDemoAggregate.restore(
        state: aggregateMayState(),
        workflow: PublicDemoWorkflowState.restore(
          applicants: [hire],
          engineers: const [],
          assignments: const [],
        ),
      );

      final result = aggregate.closeMay(week: 9, monthlyExpenses: 800000);

      expect(
        result.state.joinedApplicantIds.where((id) => id == 'agg-hire-dup'),
        hasLength(1),
      );
    });

    test('salary derives from the authoritative BindingOffer, never a '
        'caller-tampered acceptedMonthlySalary field', () {
      final hire = acceptTestOffer(
        const PublicDemoApplicant(
          id: 'agg-hire-salary',
          name: 'Hire',
          resumeSummary: 'Java 3年',
          interviewScore: 70,
          acceptanceScore: 70,
          salesSkillFit: 70,
          requestedMonthlySalary: 320000,
        ),
        offeredMonthlySalary: 320000,
      ).copyWith(stage: PublicDemoApplicantStage.offerAccepted);
      // Tamper with the field a caller could freely set — the join
      // transition inside closeMay must resolve salary from the
      // BindingOffer, never from this.
      final tampered = hire.copyWith(acceptedMonthlySalary: 1);
      final aggregate = PublicDemoAggregate.restore(
        state: aggregateMayState(),
        workflow: PublicDemoWorkflowState.restore(
          applicants: [tampered],
          engineers: const [],
          assignments: const [],
        ),
      );

      final result = aggregate.closeMay(week: 9, monthlyExpenses: 800000);

      final joined = result.workflow.applicants.firstWhere(
        (a) => a.id == 'agg-hire-salary',
      );
      expect(joined.acceptedMonthlySalary, 320000);
    });
  });
}

/// Test-only fixture: a finance state too poor to afford any recruitment
/// medium, but otherwise a normal April start.
PublicDemoState aggregatePoorState() =>
    PublicDemoState.aprilStart().copyWith(cash: 0);

/// Test-only fixture: a finance state at May (month 5), the month closeMay
/// actually operates on.
PublicDemoState aggregateMayState() => PublicDemoState.aprilStart()
    .advanceToMay(monthlyExpenses: 800000, orderedEngineers: 0);
