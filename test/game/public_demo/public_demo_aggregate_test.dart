import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// WORKFLOW-STATE-1AB FIX3/FIX4: [PublicDemoAggregate] is the single
/// authoritative Public Demo 0.1 root. These tests target the four P1
/// closures directly through the aggregate — the actual production
/// boundary the widget exercises (public_demo_01_placeholder_screen.dart)
/// — rather than the lower-level building blocks alone (already covered by
/// public_demo_workflow_state_test.dart, public_demo_binding_offer_test.dart,
/// public_demo_join_test.dart, and public_demo_monthly_close_test.dart).
///
/// FIX4: independent review found that FIX3's own `PublicDemoAggregate
/// .restore(state:, workflow:)` and `.withState(newState)` were themselves
/// still public, production-reachable APIs — so combining them with
/// public lower-level helpers (`PublicDemoMonthlyClose.closeMay`,
/// `PublicDemoState.advanceToJune`) let a caller commit finance-only or
/// workflow-only changes, inject an arbitrary workflow/assignment roster,
/// or supply a stale/omitted/subsetted joined-applicant set as if
/// authoritative. Both are now gone. Every fixture below is built by
/// chaining the SAME real [PublicDemoAggregate] commands production code
/// uses, starting from [PublicDemoAggregate.initial] — never a
/// reconstruction shortcut, because none exists any more.
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
        // WORKFLOW-STATE-1AB FIX4 P1-2: PublicDemoAggregate.restore is
        // gone — drain the real sales-slot budget (4, from aprilStart)
        // through repeated real commands instead of constructing a
        // pre-exhausted state directly. FIX5 P1: `applyEngineerInterviewResult`
        // (repeatable on the same engineer, with no stage precondition) is
        // itself gone — its replacement, `recordEngineerInterviewResult`,
        // requires each engineer to genuinely be at `introduced` first and
        // only consumes one slot per engineer (it does not re-consume once
        // the engineer has moved past that stage). Both real initial
        // engineers' partner interviews (2 slots) plus both real initial
        // applicants' completeInterview (2 slots) exhausts the budget of 4
        // — a freshly recruited third applicant, never interviewed, is the
        // target below.
        var aggregate = PublicDemoAggregate.initial();
        aggregate = aggregate
            .recruit(PublicDemoRecruitmentMedium.engineer)
            .aggregate!;

        for (final engineerId in aggregate.workflow.engineers.map(
          (e) => e.id,
        )) {
          aggregate = aggregate
              .startSkillSheetReview(engineerId)
              .beginSelling(engineerId)
              .introduceProject(engineerId)
              .recordEngineerInterviewResult(
                engineerId: engineerId,
                type: PublicDemoInterviewType.partner,
              );
        }
        for (final applicant in aggregate.workflow.applicants.where(
          (a) => !a.hasBeenInterviewed,
        )) {
          if (aggregate.state.salesRemaining <= 0) break;
          aggregate = aggregate.completeInterview(applicant.id).aggregate;
        }
        expect(aggregate.state.salesRemaining, 0);

        final target = aggregate.workflow.applicants.firstWhere(
          (a) => !a.hasBeenInterviewed,
        );
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
    // when it genuinely consumes a slot).
    //
    // WORKFLOW-STATE-1AB FIX6 P1: `PublicDemoWorkflowState.withApplicant`
    // itself — the broadest fabrication tool this test used to demonstrate
    // against — is gone too (private `_withApplicant` now, unreachable
    // from this file: `workflow.withApplicant(...)` below would no longer
    // compile). This test now proves the same conclusion through the
    // remaining, structurally-available surface — directly constructing a
    // `PublicDemoApplicant` (still publicly settable — WORKFLOW-STATE-1AB
    // §6) — still cannot mint interview completion.
    test(
      'a directly-constructed applicant cannot fabricate interview '
      'completion: `stage` alone mints no genuine PublicDemoInterviewRecord',
      () {
        const fabricated = PublicDemoApplicant(
          id: 'intruder',
          name: 'Intruder',
          resumeSummary: 'Java 1年',
          interviewScore: 90,
          acceptanceScore: 90,
          salesSkillFit: 90,
          stage: PublicDemoApplicantStage.interviewed,
        );

        expect(fabricated.stage, PublicDemoApplicantStage.interviewed);
        expect(
          fabricated.hasBeenInterviewed,
          isFalse,
          reason: 'stage alone is not proof — see PublicDemoOfferAcceptance',
        );
      },
    );

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
    test('A: finance-only recruitment commit cannot be performed', () {
      // Old attack: `old.withState(next.state)`. `withState` no longer
      // exists on PublicDemoAggregate at all (FIX4) — there is no method
      // through which the finance half of a recruit() result could be
      // committed alone, so this is necessarily a structural/compile-time
      // guarantee rather than a runtime failure to trigger. The runtime
      // half of the guarantee: recruit()'s only handle on a committed
      // outcome, `result.aggregate`, always carries workflow together
      // with state — asserted below and in the FIX4 bypass audit (see
      // SES_WORKFLOW-STATE-1AB_FIX4_Result.md).
      final aggregate = PublicDemoAggregate.initial();
      final result = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isTrue);
      expect(result.aggregate!.state.cash, isNot(aggregate.state.cash));
      expect(
        result.aggregate!.workflow.applicants.length,
        isNot(aggregate.workflow.applicants.length),
      );
    });

    test('B: workflow-only recruitment commit cannot be performed', () {
      // Old attack: `PublicDemoAggregate.restore(state: old.state,
      // workflow: next.workflow)`. `.restore` no longer exists at all
      // (FIX4) — there is no production API that accepts a caller-supplied
      // (state, workflow) pair and stores it as authoritative, so a
      // caller cannot recombine one aggregate's original state with
      // another's post-recruit workflow either. Structural guarantee,
      // same reasoning as A.
      final aggregate = PublicDemoAggregate.initial();
      final result = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isTrue);
      // The only way to read the committed workflow is paired with its
      // own committed state in the same `result.aggregate` — there is no
      // field or method that would let this test (or any caller) build a
      // "workflow moved, state didn't" aggregate even if it wanted to.
      expect(
        result.aggregate!.workflow.applicants.length,
        aggregate.workflow.applicants.length + 2,
      );
      expect(result.aggregate!.state.cash, aggregate.state.cash - 100000);
    });

    test(
      'I: insufficient cash leaves the aggregate unchanged (both roots)',
      () {
        // Reaches a genuinely poor aggregate through a real command chain
        // (closeApril's own monthlyExpenses parameter draining nearly all of
        // PublicDemoAggregate.initial's starting cash) rather than
        // constructing one directly.
        final poor = PublicDemoAggregate.initial().closeApril(
          monthlyExpenses: 2999999,
        );
        expect(poor.state.cash, 1);

        final result = poor.recruit(PublicDemoRecruitmentMedium.engineer);

        expect(result.isSuccess, isFalse);
        expect(result.aggregate, isNull);
      },
    );

    test('I: applicant generation failure leaves the aggregate unchanged', () {
      final aggregate = PublicDemoAggregate.initial();

      final result = aggregate.recruit(
        PublicDemoRecruitmentMedium.engineer,
        candidateGenerator:
            ({required month, required medium, required count}) => const [],
      );

      expect(result.isSuccess, isFalse);
      expect(result.aggregate, isNull);
    });

    test('J: recruitment success commits both together, never one alone', () {
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
    test(
      'C: arbitrary assignment restore cannot become authority — there is no '
      'production API that accepts a caller-constructed PublicDemoAssignment '
      'and stores it as authoritative',
      () {
        const fabricated = PublicDemoAssignment(
          engineerId: 'intruder',
          engineerName: 'Fabricated',
          projectName: 'Fabricated Project',
          deliveryPressure: 0,
          budgetHealth: 100,
          humanity: 100,
        );
        // The only way to reach a workflow with ANY assignment content is
        // assignOrderedForMay (via closeMay), which computes the roster
        // itself from engineer/applicant stage facts already on the
        // aggregate — there is no parameter anywhere to inject
        // `fabricated` into, and no `.restore(...)`/public
        // `copyWith(assignments: ...)` left to plant it directly either
        // (both removed in FIX4).
        final aggregate = PublicDemoAggregate.initial()
            .closeApril(monthlyExpenses: 800000)
            .closeMay(week: 9, monthlyExpenses: 800000);

        expect(
          aggregate.workflow.assignments.any(
            (a) => a.engineerId == fabricated.engineerId,
          ),
          isFalse,
        );
      },
    );

    test('valid assignment succeeds: an ordered engineer gets a real May '
        'assignment through closeMay', () {
      // WORKFLOW-STATE-1AB FIX5 P1: `withEngineerStage` is gone — reach
      // `ordered` through the real sales-pipeline chain instead. eng-01's
      // fixed interview profile (skillFit 78, matching its initial
      // PublicDemoEngineerRuntime capability) deterministically passes
      // both the partner and client interview thresholds.
      final engineerId =
          PublicDemoAggregate.initial().workflow.engineers.first.id;
      final aggregate = PublicDemoAggregate.initial()
          .startSkillSheetReview(engineerId)
          .beginSelling(engineerId)
          .introduceProject(engineerId)
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.partner,
          )
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.client,
          )
          .recordOrder(engineerId)
          .closeApril(monthlyExpenses: 800000)
          .closeMay(week: 9, monthlyExpenses: 800000);

      expect(aggregate.workflow.assignments, isNotEmpty);
      expect(
        aggregate.workflow.assignments.every(
          (a) => aggregate.workflow.engineers.any((e) => e.id == a.engineerId),
        ),
        isTrue,
      );
    });
  });

  group('P1-4: joined/payroll projection (via closeMay)', () {
    /// Accepts a binding offer for [applicantId] via the real, production
    /// `PublicDemoAggregate.completeInterview`/`acceptOffer` commands —
    /// `acceptanceScore: 100` forces acceptance so this fixture does not
    /// also have to satisfy the real evaluator's threshold. The
    /// [PublicDemoFiscalCloseId] is derived from [aggregate]'s own current
    /// month — a genuine join requires the offer and the eventual
    /// closeMay to share the same fiscal close (join happens the same
    /// month applicants are actually hired, i.e. May, matching the real
    /// widget's own offer()/may() sequencing).
    PublicDemoAggregate hireApplicant(
      PublicDemoAggregate aggregate,
      String applicantId,
    ) {
      final applicant = aggregate.workflow.applicants.firstWhere(
        (a) => a.id == applicantId,
      );
      final interviewed = aggregate.completeInterview(applicant.id).aggregate;
      final offer = PublicDemoSalaryOffer(
        requestedMonthlySalary: applicant.requestedMonthlySalary,
        offeredMonthlySalary: applicant.requestedMonthlySalary,
        acceptanceScore: 100,
        motivationDelta: 0,
        trustDelta: 0,
      );
      return interviewed.acceptOffer(
        applicantId: applicant.id,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(
          interviewed.state.month,
        ),
      );
    }

    test('D/G: two genuine joined applicants both survive closeMay, and '
        'joinedApplicantIds reflects exactly them — there is no '
        'joinedApplicants/joinedApplicantIds parameter on the aggregate to '
        'omit either one or substitute an arbitrary list', () {
      var aggregate = PublicDemoAggregate.initial();
      final ids = aggregate.workflow.applicants.map((a) => a.id).toList();
      expect(ids, hasLength(2), reason: 'the fixture needs exactly two');

      aggregate = aggregate.closeApril(monthlyExpenses: 800000);
      aggregate = hireApplicant(aggregate, ids[0]);
      aggregate = hireApplicant(aggregate, ids[1]);

      final result = aggregate.closeMay(week: 9, monthlyExpenses: 800000);

      expect(result.state.joinedApplicantIds.toSet(), ids.toSet());
    });

    test('E: joined omission cannot control May close — closeMay(week:, '
        'monthlyExpenses:) has no parameter through which a caller could ask '
        'for fewer than the genuinely-joined applicants', () {
      var aggregate = PublicDemoAggregate.initial();
      final ids = aggregate.workflow.applicants.map((a) => a.id).toList();
      aggregate = aggregate.closeApril(monthlyExpenses: 800000);
      // Only ONE of the two pool applicants is hired — the other never
      // gets an offer, so it genuinely does not join. The point: nothing
      // about closeMay's signature would let a caller who DID hire both
      // choose to report only one — the previous test (D/G) already
      // proves both survive when both are genuine. This test confirms
      // the complementary case: a genuinely-not-joined applicant is
      // correctly absent, not present through some caller override.
      aggregate = hireApplicant(aggregate, ids[0]);
      final neverHired = ids[1];

      final result = aggregate.closeMay(week: 9, monthlyExpenses: 800000);

      expect(result.state.joinedApplicantIds, isNot(contains(neverHired)));
      expect(result.state.joinedApplicantIds, hasLength(1));
    });

    test('F: stale workflow cannot be supplied to close — closeMay always '
        'operates on this aggregate\'s own current workflow; there is no '
        '`workflow:` parameter through which an earlier-held reference could '
        'be substituted', () {
      final base = PublicDemoAggregate.initial();

      // Advance the REAL aggregate (recruit adds a brand-new applicant
      // id that never existed in `base.workflow` at all); `base` itself
      // stays untouched (Dart immutability) and now-stale. There is no
      // way to hand closeMay `base.workflow` instead of the advanced
      // aggregate's own current one, because closeMay accepts no
      // workflow argument at all.
      var advanced = base.recruit(PublicDemoRecruitmentMedium.free).aggregate!;
      final recruitedId = advanced.workflow.applicants
          .where((a) => !base.workflow.applicants.any((b) => b.id == a.id))
          .single
          .id;
      advanced = advanced.closeApril(monthlyExpenses: 800000);
      advanced = hireApplicant(advanced, recruitedId);

      final closed = advanced.closeMay(week: 9, monthlyExpenses: 800000);

      // If closeMay could somehow have operated on `base.workflow`
      // (captured before the recruit) instead of `advanced`'s own live
      // one, the recruited-and-hired applicant would be structurally
      // absent — it did not exist in `base.workflow` at all. Its
      // presence in the payroll projection proves closeMay used the
      // aggregate's own current workflow, never the stale reference.
      expect(closed.state.joinedApplicantIds, contains(recruitedId));
    });

    test('salary derives from the authoritative BindingOffer, never a '
        'caller-tampered acceptedMonthlySalary field', () {
      var aggregate = PublicDemoAggregate.initial();
      final applicant = aggregate.workflow.applicants.first;
      aggregate = aggregate.closeApril(monthlyExpenses: 800000);
      aggregate = hireApplicant(aggregate, applicant.id);

      // Tamper with the field a caller could freely set directly on an
      // applicant value via the public `copyWith` (WORKFLOW-STATE-1AB
      // FIX6 P1: `PublicDemoWorkflowState.withApplicant` — the generic
      // callback mutator that used to let a caller re-commit a tampered
      // applicant back onto the workflow itself — is gone entirely) — the
      // join transition inside closeMay must resolve salary from the
      // BindingOffer, never from this. This LOCAL value is never committed
      // anywhere: there is no aggregate API left (no restore, no
      // withWorkflow, no withApplicant) that would let a caller substitute
      // it for the real workflow before calling closeMay.
      final tampered = aggregate.workflow.applicants
          .firstWhere((a) => a.id == applicant.id)
          .copyWith(acceptedMonthlySalary: 1);
      expect(tampered.acceptedMonthlySalary, 1);

      final result = aggregate.closeMay(week: 9, monthlyExpenses: 800000);

      final joined = result.workflow.applicants.firstWhere(
        (a) => a.id == applicant.id,
      );
      expect(joined.acceptedMonthlySalary, applicant.requestedMonthlySalary);
    });
  });

  // WORKFLOW-STATE-1AB FIX5 P1: required adversarial coverage for the
  // assignment-authority closure — `withEngineerStage`/`withApplicantStage`
  // (and the equally-shaped `applyEngineerInterviewResult`/
  // `consumeSlotAndSetApplicantStage`) are gone; TEST A/B below re-attempt
  // the exact FIX4-flagged bypasses through the real replacement commands
  // and confirm they are no-ops all the way through closeMay. TEST C
  // exercises the join-failure defense in depth (section 5/6) through a
  // genuinely-reachable production path, not a fabricated object. TEST
  // D/E/F confirm the legitimate happy paths (and retry-safety) still
  // work exactly as before.
  group(
    'WORKFLOW-STATE-1AB FIX5 P1: assignment-authority adversarial tests',
    () {
      test(
        'TEST A: engineer stage spoof — recordOrder without genuine sales '
        'progression is a no-op, and closeMay creates no assignment for it',
        () {
          final engineerId =
              PublicDemoAggregate.initial().workflow.engineers.first.id;

          // The former attack: PublicDemoAggregate.withEngineerStage(id,
          // PublicDemoSalesStage.ordered). That method no longer exists; the
          // closest remaining surface is calling the real recordOrder
          // command directly, skipping every real sales-pipeline event. It
          // must be a no-op — recordOrder requires clientInterviewPassed.
          var aggregate = PublicDemoAggregate.initial().recordOrder(engineerId);
          expect(
            aggregate.workflow.engineers
                .firstWhere((e) => e.id == engineerId)
                .stage,
            PublicDemoSalesStage.waiting,
          );

          aggregate = aggregate
              .closeApril(monthlyExpenses: 800000)
              .closeMay(week: 9, monthlyExpenses: 800000);

          expect(
            aggregate.workflow.assignments.any(
              (a) => a.engineerId == engineerId,
            ),
            isFalse,
          );
        },
      );

      test('TEST B: applicant stage spoof — recordJuneOrder without a genuine '
          'offer/pre-entry chain is a no-op, and closeMay creates no assignment '
          'for it', () {
        final applicantId =
            PublicDemoAggregate.initial().workflow.applicants.first.id;

        // The former attack: PublicDemoAggregate.withApplicantStage(id,
        // PublicDemoApplicantStage.juneOrdered) on a non-joined, no-
        // BindingOffer applicant. That method no longer exists; calling
        // the real recordJuneOrder command directly must be a no-op —
        // it requires preEntryClientPassed.
        var aggregate = PublicDemoAggregate.initial().recordJuneOrder(
          applicantId,
        );
        expect(
          aggregate.workflow.applicants
              .firstWhere((a) => a.id == applicantId)
              .stage,
          PublicDemoApplicantStage.applied,
        );

        aggregate = aggregate
            .closeApril(monthlyExpenses: 800000)
            .closeMay(week: 9, monthlyExpenses: 800000);

        expect(
          aggregate.workflow.assignments.any(
            (a) => a.engineerId == applicantId,
          ),
          isFalse,
        );
      });

      test('TEST C: a genuine juneOrdered applicant whose join fails (stale '
          'fiscal close) never becomes an assignment', () {
        var aggregate = PublicDemoAggregate.initial();
        final applicantId = aggregate.workflow.applicants.first.id;
        aggregate = aggregate.completeInterview(applicantId).aggregate;
        final applicant = aggregate.workflow.applicants.firstWhere(
          (a) => a.id == applicantId,
        );
        final offer = PublicDemoSalaryOffer(
          requestedMonthlySalary: applicant.requestedMonthlySalary,
          offeredMonthlySalary: applicant.requestedMonthlySalary,
          acceptanceScore: 100,
          motivationDelta: 0,
          trustDelta: 0,
        );
        // Accepted at month 4 (before April closes) — genuinely minted,
        // but bound to that fiscal close.
        aggregate = aggregate.acceptOffer(
          applicantId: applicantId,
          offer: offer,
          fiscalCloseId: PublicDemoFiscalCloseId.forMonth(4),
        );
        aggregate = aggregate.closeApril(monthlyExpenses: 800000); // -> May

        // Walk the real pre-entry chain to juneOrdered — every stage
        // precondition genuinely satisfied.
        aggregate = aggregate
            .beginPreEntrySkillSheet(applicantId)
            .beginPreEntrySelling(applicantId)
            .introducePreEntryProject(applicantId)
            .recordPreEntryPartnerInterviewResult(applicantId)
            .recordPreEntryClientInterviewResult(applicantId)
            .recordJuneOrder(applicantId);
        expect(
          aggregate.workflow.applicants
              .firstWhere((a) => a.id == applicantId)
              .stage,
          PublicDemoApplicantStage.juneOrdered,
        );

        // closeMay's join step now runs against May's fiscal close — the
        // BindingOffer above was minted for April's, so the join fails
        // (PublicDemoJoinStatus.staleFiscalClose), leaving hasJoined
        // false despite the genuine juneOrdered stage.
        final closed = aggregate.closeMay(week: 9, monthlyExpenses: 800000);
        final result = closed.workflow.applicants.firstWhere(
          (a) => a.id == applicantId,
        );
        expect(result.stage, PublicDemoApplicantStage.juneOrdered);
        expect(result.hasJoined, isFalse);
        expect(
          closed.workflow.assignments.any((a) => a.engineerId == applicantId),
          isFalse,
        );
      });

      test('TEST D: genuine engineer happy path — an assignment is created '
          'exactly once', () {
        final engineerId =
            PublicDemoAggregate.initial().workflow.engineers.first.id;
        final aggregate = PublicDemoAggregate.initial()
            .startSkillSheetReview(engineerId)
            .beginSelling(engineerId)
            .introduceProject(engineerId)
            .recordEngineerInterviewResult(
              engineerId: engineerId,
              type: PublicDemoInterviewType.partner,
            )
            .recordEngineerInterviewResult(
              engineerId: engineerId,
              type: PublicDemoInterviewType.client,
            )
            .recordOrder(engineerId)
            .closeApril(monthlyExpenses: 800000)
            .closeMay(week: 9, monthlyExpenses: 800000);

        expect(
          aggregate.workflow.assignments
              .where((a) => a.engineerId == engineerId)
              .length,
          1,
        );
      });

      test('TEST E: genuine applicant happy path (interview -> offer -> '
          'BindingOffer -> join -> valid order progression) — an assignment is '
          'created exactly once', () {
        var aggregate = PublicDemoAggregate.initial().closeApril(
          monthlyExpenses: 800000,
        ); // -> May
        final applicantId = aggregate.workflow.applicants.first.id;
        aggregate = aggregate.completeInterview(applicantId).aggregate;
        final applicant = aggregate.workflow.applicants.firstWhere(
          (a) => a.id == applicantId,
        );
        final offer = PublicDemoSalaryOffer(
          requestedMonthlySalary: applicant.requestedMonthlySalary,
          offeredMonthlySalary: applicant.requestedMonthlySalary,
          acceptanceScore: 100,
          motivationDelta: 0,
          trustDelta: 0,
        );
        aggregate = aggregate.acceptOffer(
          applicantId: applicantId,
          offer: offer,
          fiscalCloseId: PublicDemoFiscalCloseId.forMonth(
            aggregate.state.month,
          ),
        );
        aggregate = aggregate
            .beginPreEntrySkillSheet(applicantId)
            .beginPreEntrySelling(applicantId)
            .introducePreEntryProject(applicantId)
            .recordPreEntryPartnerInterviewResult(applicantId)
            .recordPreEntryClientInterviewResult(applicantId)
            .recordJuneOrder(applicantId);

        final closed = aggregate.closeMay(week: 9, monthlyExpenses: 800000);

        final result = closed.workflow.applicants.firstWhere(
          (a) => a.id == applicantId,
        );
        expect(result.hasJoined, isTrue);
        expect(
          closed.workflow.assignments
              .where((a) => a.engineerId == applicantId)
              .length,
          1,
        );
      });

      test('TEST F: retrying the close/assignment command never duplicates the '
          'assignment', () {
        final engineerId =
            PublicDemoAggregate.initial().workflow.engineers.first.id;
        final ordered = PublicDemoAggregate.initial()
            .startSkillSheetReview(engineerId)
            .beginSelling(engineerId)
            .introduceProject(engineerId)
            .recordEngineerInterviewResult(
              engineerId: engineerId,
              type: PublicDemoInterviewType.partner,
            )
            .recordEngineerInterviewResult(
              engineerId: engineerId,
              type: PublicDemoInterviewType.client,
            )
            .recordOrder(engineerId)
            .closeApril(monthlyExpenses: 800000);

        final once = ordered.closeMay(week: 9, monthlyExpenses: 800000);
        final twice = once.closeMay(week: 9, monthlyExpenses: 800000);

        expect(
          twice.workflow.assignments
              .where((a) => a.engineerId == engineerId)
              .length,
          1,
        );
      });
    },
  );

  // WORKFLOW-STATE-1AB FIX6 P1: independent focused review of FIX5 found
  // one more P1 — `PublicDemoWorkflowState.withEngineer`/`withApplicant`
  // remained PUBLIC generic callback mutators (`workflow.withEngineer(id,
  // (e) => e.copyWith(stage: ordered, lastInterviewScore: 80))` — the
  // confirmed attack below), and FIX5's own `lastInterviewScore != null`
  // corroboration was itself insufficient because `lastInterviewScore`
  // remained caller-writable via that same public `copyWith`. Both
  // `withEngineer`/`withApplicant` are now private
  // (`_withEngineer`/`_withApplicant`) — every line below that used to call
  // `workflow.withEngineer(...)`/`workflow.withApplicant(...)` directly no
  // longer compiles from this file, which is itself part of the closure
  // (a structural, compile-time guarantee, not just a behavioral one). A
  // new unforgeable `PublicDemoEngineerInterviewRecord` (mirroring
  // `PublicDemoInterviewRecord`/`PublicDemoJoinRecord`) replaces
  // `lastInterviewScore` as the corroborating fact `assignOrderedForMay`
  // actually checks.
  group('WORKFLOW-STATE-1AB FIX6 P1: generic-mutator and '
      'constructor-injection adversarial tests', () {
    test('TEST A: the confirmed review attack — fabricating stage+score '
        'directly, the way `workflow.withEngineer(id, (e) => '
        'e.copyWith(stage: ordered, lastInterviewScore: 80))` used to — '
        'cannot produce an assignment', () {
      // `withEngineer` itself is gone (private `_withEngineer`); the line
      // `PublicDemoWorkflowState.initial().withEngineer(id, (e) => ...)`
      // the review used to confirm this attack would no longer compile
      // from this file. The broadest remaining production-reachable
      // surface for the identical fabrication (same fields, same
      // values) is constructing a whole engineer directly via the public
      // `PublicDemoEngineerSales` constructor, then handing it to the
      // public `PublicDemoWorkflowState(applicants:, engineers:)`
      // factory.
      const fabricated = PublicDemoEngineerSales(
        id: 'intruder',
        name: 'Intruder',
        summary: 'summary',
        stage: PublicDemoSalesStage.ordered,
        lastInterviewScore: 80,
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 99,
          humanity: 99,
          morale: 99,
          clientTrust: 99,
        ),
      );

      final assigned = PublicDemoWorkflowState(
        applicants: const [],
        engineers: const [fabricated],
      ).assignOrderedForMay();

      expect(assigned.assignments, isEmpty);
      expect(fabricated.hasGenuineInterviewRecord, isFalse);
    });

    test('TEST I: the public PublicDemoWorkflowState factory constructor '
        'cannot inject an authoritative fabricated roster — neither a '
        'fabricated ordered engineer nor a fabricated juneOrdered/joined-'
        'looking applicant becomes an assignment', () {
      const fabricatedEngineer = PublicDemoEngineerSales(
        id: 'intruder-eng',
        name: 'Intruder Engineer',
        summary: 'summary',
        stage: PublicDemoSalesStage.ordered,
        lastInterviewScore: 100,
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 99,
          humanity: 99,
          morale: 99,
          clientTrust: 99,
        ),
      );
      const fabricatedApplicant = PublicDemoApplicant(
        id: 'intruder-app',
        name: 'Intruder Applicant',
        resumeSummary: 'Java 99年',
        interviewScore: 99,
        acceptanceScore: 99,
        salesSkillFit: 99,
        stage: PublicDemoApplicantStage.juneOrdered,
      );

      final assigned = PublicDemoWorkflowState(
        applicants: const [fabricatedApplicant],
        engineers: const [fabricatedEngineer],
      ).assignOrderedForMay();

      expect(assigned.assignments, isEmpty);
    });

    test('TEST B: the engineer sales pipeline still cannot be skipped through '
        'the aggregate — recordOrder alone, with no genuine progression, '
        'never reaches closeMay with an assignment', () {
      final engineerId =
          PublicDemoAggregate.initial().workflow.engineers.first.id;

      final aggregate = PublicDemoAggregate.initial()
          .recordOrder(engineerId)
          .closeApril(monthlyExpenses: 800000)
          .closeMay(week: 9, monthlyExpenses: 800000);

      expect(
        aggregate.workflow.assignments.any((a) => a.engineerId == engineerId),
        isFalse,
      );
    });

    test('TEST C: genuine engineer happy path still creates exactly one '
        'assignment', () {
      final engineerId =
          PublicDemoAggregate.initial().workflow.engineers.first.id;
      final aggregate = PublicDemoAggregate.initial()
          .startSkillSheetReview(engineerId)
          .beginSelling(engineerId)
          .introduceProject(engineerId)
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.partner,
          )
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.client,
          )
          .recordOrder(engineerId)
          .closeApril(monthlyExpenses: 800000)
          .closeMay(week: 9, monthlyExpenses: 800000);

      expect(
        aggregate.workflow.assignments
            .where((a) => a.engineerId == engineerId)
            .length,
        1,
      );
      final orderedEngineer = aggregate.workflow.engineers.firstWhere(
        (e) => e.id == engineerId,
      );
      expect(orderedEngineer.hasGenuineInterviewRecord, isTrue);
    });

    test('TEST H: no finance-only/workflow-only aggregate commit bypass is '
        'reintroduced — recruit() still always commits cash and generated '
        'applicants together, or neither', () {
      final aggregate = PublicDemoAggregate.initial();
      final result = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isTrue);
      expect(result.aggregate!.state.cash, isNot(aggregate.state.cash));
      expect(
        result.aggregate!.workflow.applicants.length,
        isNot(aggregate.workflow.applicants.length),
      );
    });
  });

  // WORKFLOW-STATE-1AB FIX7 P2: FIX6's independent review found one more
  // provenance gap — `PublicDemoEngineerSales.recordInterviewOutcome`
  // remained a PUBLIC API accepting `type`/`passed`/`score` as direct
  // parameters. That let a production caller mint a genuine-looking
  // `PublicDemoEngineerInterviewRecord` with a call like
  // `engineer.recordInterviewOutcome(type: client, passed: true, score:
  // 80)` — no real interview, no stage precondition, nothing but asserted
  // literals. `recordInterviewOutcome` is gone; the line above no longer
  // compiles from this file (a structural, compile-time closure, not just
  // a behavioral one). Its replacement,
  // `PublicDemoEngineerSales.evaluateInterview`, accepts only `type` and
  // `actualCapability` — an interview-time skill signal, never an outcome
  // assertion — and derives everything else (the required current stage,
  // the pass/fail result, the score, and the record itself) internally.
  group('WORKFLOW-STATE-1AB FIX7 P2: direct interview-record provenance '
      'closure', () {
    test('TEST A: the direct public interview-record mint attack is closed — '
        'evaluateInterview cannot be used to skip the partner interview and '
        'mint a client-interview-pass record directly, however favorable '
        'the supplied capability/profile', () {
      // The old attack constructed an engineer and called
      // `recordInterviewOutcome(type: client, passed: true, score: 80)`
      // directly — no stage check existed at all. The broadest remaining
      // public surface for the same intent is calling `evaluateInterview`
      // directly on an engineer that never genuinely passed a partner
      // interview (here: still at the default `waiting` stage), with a
      // maximally favorable profile/capability so any real formula would
      // also pass.
      const fabricated = PublicDemoEngineerSales(
        id: 'intruder-direct',
        name: 'Intruder',
        summary: 'summary',
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 99,
          humanity: 99,
          morale: 99,
          clientTrust: 99,
        ),
      );

      final attempted = fabricated.evaluateInterview(
        type: PublicDemoInterviewType.client,
        actualCapability: 100,
      );

      expect(
        attempted.hasGenuineInterviewRecord,
        isFalse,
        reason:
            'evaluateInterview requires stage == partnerInterviewPassed '
            'before a client interview can even be attempted; a waiting '
            'engineer is an unconditional no-op',
      );
      expect(attempted.stage, PublicDemoSalesStage.waiting);
      expect(attempted.lastInterviewScore, isNull);

      final assigned = PublicDemoWorkflowState(
        applicants: const [],
        engineers: [attempted.copyWith(stage: PublicDemoSalesStage.ordered)],
      ).assignOrderedForMay();
      expect(assigned.assignments, isEmpty);
    });

    test('TEST DIRECT PROVENANCE ATTACK: the exact FIX6-review attack shape '
        '— mint via the remaining public construction/evaluation surface, '
        'force stage to ordered, wrap in a detached workflow — still '
        'cannot satisfy genuine provenance and still produces no '
        'assignment', () {
      const fabricated = PublicDemoEngineerSales(
        id: 'intruder-detached',
        name: 'Intruder',
        summary: 'summary',
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 99,
          humanity: 99,
          morale: 99,
          clientTrust: 99,
        ),
      );

      final detachedWorkflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: [
          fabricated
              .evaluateInterview(
                type: PublicDemoInterviewType.client,
                actualCapability: 100,
              )
              .copyWith(stage: PublicDemoSalesStage.ordered),
        ],
      );

      expect(
        detachedWorkflow.engineers.single.hasGenuineInterviewRecord,
        isFalse,
      );
      expect(detachedWorkflow.assignOrderedForMay().assignments, isEmpty);
    });

    test('TEST E: wrong/invalid interview progression never produces a '
        'genuine record — a partner interview attempted from `waiting`, and '
        'a client interview attempted from `introduced` (partner not yet '
        'passed), are both no-ops', () {
      const engineer = PublicDemoEngineerSales(
        id: 'eng-progression',
        name: 'Engineer',
        summary: 'summary',
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 90,
          humanity: 90,
          morale: 90,
          clientTrust: 90,
        ),
      );

      final clientFromWaiting = engineer.evaluateInterview(
        type: PublicDemoInterviewType.client,
        actualCapability: 100,
      );
      expect(clientFromWaiting.stage, PublicDemoSalesStage.waiting);
      expect(clientFromWaiting.hasGenuineInterviewRecord, isFalse);

      final introduced = engineer.copyWith(
        stage: PublicDemoSalesStage.introduced,
      );
      final clientFromIntroduced = introduced.evaluateInterview(
        type: PublicDemoInterviewType.client,
        actualCapability: 100,
      );
      expect(clientFromIntroduced.stage, PublicDemoSalesStage.introduced);
      expect(clientFromIntroduced.hasGenuineInterviewRecord, isFalse);
    });

    test('TEST C/D: genuine partner -> client interview progression through '
        'the aggregate still mints a genuine record and still produces '
        'exactly one assignment', () {
      final engineerId =
          PublicDemoAggregate.initial().workflow.engineers.first.id;
      final aggregate = PublicDemoAggregate.initial()
          .startSkillSheetReview(engineerId)
          .beginSelling(engineerId)
          .introduceProject(engineerId)
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.partner,
          )
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.client,
          )
          .recordOrder(engineerId)
          .closeApril(monthlyExpenses: 800000)
          .closeMay(week: 9, monthlyExpenses: 800000);

      final orderedEngineer = aggregate.workflow.engineers.firstWhere(
        (e) => e.id == engineerId,
      );
      expect(orderedEngineer.hasGenuineInterviewRecord, isTrue);
      expect(
        aggregate.workflow.assignments
            .where((a) => a.engineerId == engineerId)
            .length,
        1,
      );
    });
  });
}
