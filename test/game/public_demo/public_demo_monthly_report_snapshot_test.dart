import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_report_snapshot.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

/// SES ISSUE-232 Phase A: [PublicDemoMonthlyReportSnapshot] is a pure,
/// read-only adapter over already-authoritative facts — [PublicDemoState
/// .latestMonthlyCashFlow] and [PublicDemoWorkflowState.assignedEngineerIds]
/// (Fresh Audit `docs/reports/
/// SES_FIRST-FUN-YEAR_Monthly-Management-Report_Fresh-Audit.md`). These
/// tests never call any close/command method from inside the snapshot
/// itself — every aggregate under test is built the same way production
/// code builds one, through the real [PublicDemoAggregate] command chain,
/// exactly mirroring `public_demo_aggregate_test.dart`'s own fixtures.
void main() {
  group('1. April close -> May snapshot', () {
    test('ready status carries the exact recorded April cash flow', () {
      final aggregate = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: 800000,
      );
      final flow = aggregate.state.latestMonthlyCashFlow!;

      final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
        aggregate,
        closedMonth: 4,
      );

      expect(snapshot.status, PublicDemoMonthlyReportStatus.ready);
      expect(snapshot.isReady, isTrue);
      expect(snapshot.requestedMonth, 4);
      expect(snapshot.cashFlow, same(flow));
    });
  });

  group('2. ordinary month close snapshot (June -> July -> August)', () {
    test('ready status carries the exact recorded ordinary-month cash flow', () {
      final aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: 800000)
          .closeMay(week: 9, monthlyExpenses: 800000)
          .closeJune(assignedInJuly: 0, monthlyExpenses: 800000)
          .closeJuly(monthlyExpenses: 800000)
          .closeOrdinaryMonth(monthlyExpenses: 800000); // closes August
      final flow = aggregate.state.latestMonthlyCashFlow!;
      expect(flow.month, 8);

      final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
        aggregate,
        closedMonth: 8,
      );

      expect(snapshot.status, PublicDemoMonthlyReportStatus.ready);
      expect(snapshot.cashFlow, same(flow));
    });
  });

  group('3. finance fields agree field-for-field with latestMonthlyCashFlow', () {
    test(
      'openingCash / closingCash / netCashMovement / revenue / payroll / '
      'expenses / derived net income all match verbatim',
      () {
        final aggregate = PublicDemoAggregate.initial().closeApril(
          monthlyExpenses: 800000,
        );
        final flow = aggregate.state.latestMonthlyCashFlow!;

        final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
          aggregate,
          closedMonth: 4,
        );

        final s = snapshot.cashFlow!;
        expect(s.openingCash, flow.openingCash);
        expect(s.closingCash, flow.closingCash);
        expect(s.netCashMovement, flow.netCashMovement);
        expect(s.revenue, flow.revenue);
        expect(s.salaryPaid, flow.salaryPaid);
        expect(s.fixedCostsPaid, flow.fixedCostsPaid);
        expect(s.bonusPaid, flow.bonusPaid);
        expect(s.trainingCost, flow.trainingCost);
        expect(s.recruitmentCost, flow.recruitmentCost);
        expect(s.totalOutflow, flow.totalOutflow);
        // Derived net income (SES ISSUE-232 §5.2): the snapshot never
        // recomputes this itself — it must be the exact same value the
        // domain getter already derives.
        expect(s.netIncome, flow.revenue - flow.totalOutflow);
        expect(s.netIncome, flow.netIncome);
      },
    );
  });

  group('4. assigned/waiting agree with assignedEngineerIds', () {
    test('a genuinely-ordered founding engineer is assigned; the other '
        'founding engineer stays waiting', () {
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

      final authoritative = aggregate.workflow.assignedEngineerIds(
        month: aggregate.state.month,
      );
      expect(authoritative, contains(engineerId));
      expect(aggregate.workflow.engineers.length, 2);

      final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
        aggregate,
        closedMonth: 5,
      );

      expect(
        snapshot.assignedEngineers.map((e) => e.id).toSet(),
        authoritative,
      );
      expect(
        snapshot.waitingEngineers.map((e) => e.id).toSet(),
        aggregate.workflow.engineers
            .map((e) => e.id)
            .toSet()
            .difference(authoritative),
      );
      // Every engineer is accounted for exactly once.
      expect(
        snapshot.assignedEngineers.length + snapshot.waitingEngineers.length,
        aggregate.workflow.engineers.length,
      );
      expect(snapshot.waitingEngineers, isNotEmpty);
    });

    test('10. stays stable and consistent across repeated reads with '
        'multiple engineers (no engineer ordered — both wait)', () {
      final aggregate = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: 800000,
      );
      expect(aggregate.workflow.engineers.length, 2);

      final first = PublicDemoMonthlyReportSnapshot.fromAggregate(
        aggregate,
        closedMonth: 4,
      );
      final second = PublicDemoMonthlyReportSnapshot.fromAggregate(
        aggregate,
        closedMonth: 4,
      );

      expect(first.waitingEngineers.map((e) => e.id).toSet(), {
        'eng-01',
        'eng-02',
      });
      expect(first.assignedEngineers, isEmpty);
      // Deterministic: reading the same aggregate twice never disagrees.
      expect(
        first.waitingEngineers.map((e) => e.id).toList(),
        second.waitingEngineers.map((e) => e.id).toList(),
      );
      expect(first.assignedEngineers, second.assignedEngineers);
    });
  });

  group('5. confirmed next-month joins (juneOrdered)', () {
    test(
      'an applicant who genuinely reached juneOrdered is reported',
      () {
        // Same seeded recipe as public_demo_aggregate_test.dart's own
        // "TEST E: genuine applicant happy path" — runSeed 1's first
        // engineer-medium candidate genuinely clears both pre-entry
        // interview thresholds this real chain requires.
        var aggregate = PublicDemoAggregate.initial(runSeed: 1)
            .recruit(PublicDemoRecruitmentMedium.engineer)
            .aggregate!
            .closeApril(monthlyExpenses: 800000); // -> May
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
        // May's own join step consumes the juneOrdered cohort — read the
        // snapshot from the pre-join aggregate, where the stage is still
        // genuinely `juneOrdered`, matching the field this snapshot reads.
        final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
          aggregate,
          closedMonth: 4,
        );

        expect(
          snapshot.confirmedNextMonthJoinApplicantIds,
          contains(applicantId),
        );
        // Sanity: closeMay did go on to actually join/assign this same
        // applicant, confirming the fixture reached a genuine, non-stale
        // juneOrdered stage (not a spoofed/no-op one).
        expect(
          closed.workflow.assignments.any((a) => a.engineerId == applicantId),
          isTrue,
        );
      },
    );

    test('no juneOrdered applicant -> empty set', () {
      final aggregate = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: 800000,
      );
      final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
        aggregate,
        closedMonth: 4,
      );
      expect(snapshot.confirmedNextMonthJoinApplicantIds, isEmpty);
    });
  });

  group('6. latestMonthlyCashFlow null', () {
    test('a fresh aggregate (nothing closed yet) is a safe no-op snapshot', () {
      final aggregate = PublicDemoAggregate.initial();
      expect(aggregate.state.latestMonthlyCashFlow, isNull);

      final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
        aggregate,
        closedMonth: 4,
      );

      expect(snapshot.status, PublicDemoMonthlyReportStatus.notYetRecorded);
      expect(snapshot.isReady, isFalse);
      expect(snapshot.cashFlow, isNull);
      expect(snapshot.assignedEngineers, isEmpty);
      expect(snapshot.waitingEngineers, isEmpty);
      expect(snapshot.confirmedNextMonthJoinApplicantIds, isEmpty);
      expect(snapshot.requestedMonth, 4);
    });
  });

  group('7. stale month mismatch is handled safely', () {
    test(
      'requesting a month that does not match the recorded flow\'s own '
      'month never surfaces that flow under the wrong label',
      () {
        // Simulates exactly the no-op-close scenario Fresh Audit §4/§12
        // warns about: `latestMonthlyCashFlow` still names the last month
        // that genuinely closed (4) while the caller is asking about a
        // later month (5) whose own close never actually recorded a flow
        // (e.g. isCloseBlocked).
        final aggregate = PublicDemoAggregate.initial().closeApril(
          monthlyExpenses: 800000,
        );
        expect(aggregate.state.latestMonthlyCashFlow!.month, 4);

        final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
          aggregate,
          closedMonth: 5,
        );

        expect(snapshot.status, PublicDemoMonthlyReportStatus.staleClosedMonth);
        expect(snapshot.isReady, isFalse);
        // The stale flow must never be exposed under the wrong month.
        expect(snapshot.cashFlow, isNull);
        expect(snapshot.assignedEngineers, isEmpty);
        expect(snapshot.waitingEngineers, isEmpty);
        expect(snapshot.requestedMonth, 5);
      },
    );
  });

  group('8. no mutation of aggregate/state/workflow', () {
    test('building a snapshot never changes the source aggregate', () {
      final aggregate = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: 800000,
      );
      final stateBefore = aggregate.state;
      final workflowBefore = aggregate.workflow;
      final cashBefore = aggregate.state.cash;
      final engineersBefore = aggregate.workflow.engineers.toList();

      PublicDemoMonthlyReportSnapshot.fromAggregate(
        aggregate,
        closedMonth: 4,
      );
      PublicDemoMonthlyReportSnapshot.fromAggregate(
        aggregate,
        closedMonth: 99, // even a mismatched read must not mutate anything.
      );

      expect(identical(aggregate.state, stateBefore), isTrue);
      expect(identical(aggregate.workflow, workflowBefore), isTrue);
      expect(aggregate.state.cash, cashBefore);
      expect(
        aggregate.workflow.engineers.map((e) => e.id).toList(),
        engineersBefore.map((e) => e.id).toList(),
      );
    });
  });
}
