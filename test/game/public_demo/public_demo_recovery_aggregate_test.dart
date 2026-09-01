import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';

/// RECOVERY-LOOP-1: [PublicDemoAggregate.recoverAssignment] atomic
/// integration tests — the actual production boundary
/// (public_demo_01_placeholder_screen.dart) exercises, mirroring
/// public_demo_aggregate_test.dart's own approach of chaining real
/// commands from [PublicDemoAggregate.initial].
void main() {
  group('atomic transaction', () {
    test('recovering eng-01 in July appends exactly one assignment and '
        're-projects engineersAssigned/engineersWaiting together', () {
      var aggregate = publicDemoAggregateAtMonth(7);
      expect(aggregate.state.engineersAssigned, 0);
      expect(aggregate.state.engineersWaiting, 2);

      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      final beforeRecovery = aggregate;
      aggregate = aggregate.recoverAssignment('eng-01');

      expect(aggregate, isNot(same(beforeRecovery)));
      expect(aggregate.workflow.assignments, hasLength(1));
      expect(aggregate.workflow.assignments.single.engineerId, 'eng-01');
      expect(
        aggregate.workflow.assignments.single.nextOrderStatus,
        PublicDemoNextOrderStatus.accepted,
      );
      expect(
        aggregate.workflow.assignments.single.replacementStage,
        PublicDemoReplacementStage.ordered,
      );
      expect(aggregate.state.engineersAssigned, 1);
      expect(aggregate.state.engineersWaiting, 1);
      expect(
        aggregate.state.engineersAssigned + aggregate.state.engineersWaiting,
        aggregate.state.engineerCount,
      );
    });

    test('counts are re-projected from canonical assignment facts, not a '
        'bare +1/-1 delta — recovering the same engineer id twice never '
        'over-counts', () {
      var aggregate = publicDemoAggregateAtMonth(8);
      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      aggregate = aggregate.recoverAssignment('eng-01');
      aggregate = aggregate.recoverAssignment('eng-01');

      expect(aggregate.state.engineersAssigned, 1);
      expect(aggregate.state.engineersWaiting, 1);
    });

    test('a continuation assignment already established through the '
        'ordinary May→June→July flow survives the atomic Recovery '
        'transaction untouched — the CRITICAL ASSIGNMENT REQUIREMENT this '
        'feature exists to satisfy', () {
      const applicantId = 'app-01';
      // closeApril runs FIRST (May's own closeMay validates the applicant's
      // BindingOffer fiscalCloseId against May's — internal month 5 —
      // PublicDemoFiscalCloseId, so the offer must be accepted once May has
      // already started, exactly like every other Public Demo hire test in
      // this suite, e.g. public_demo_balance_regression_test.dart).
      var aggregate = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: 800000,
      );
      final interview = aggregate.completeInterview(applicantId);
      expect(interview.isCompleted, isTrue);
      aggregate = interview.aggregate;
      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == applicantId,
      );
      aggregate = aggregate
          .acceptOffer(
            applicantId: applicantId,
            offer: PublicDemoSalaryOfferEvaluator.evaluate(
              applicant: applicant,
              offeredMonthlySalary: applicant.requestedMonthlySalary,
            ),
            fiscalCloseId: PublicDemoFiscalCloseId.forMonth(
              aggregate.state.month,
            ),
          )
          .beginPreEntrySkillSheet(applicantId)
          .beginPreEntrySelling(applicantId)
          .introducePreEntryProject(applicantId)
          .recordPreEntryPartnerInterviewResult(applicantId)
          .recordPreEntryClientInterviewResult(applicantId)
          .recordJuneOrder(applicantId)
          .closeMay(week: 9, monthlyExpenses: 800000);

      final hire = aggregate.workflow.joinedApplicants.single;
      final juneExpenses = PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: 800000,
        hires: [hire],
      );
      // app-01 continues into July — set explicitly here (this test is
      // about Recovery, not June's own decideOrder/acceptOrder formula).
      aggregate = aggregate
          .withAssignmentUpdate(
            applicantId,
            nextOrderStatus: PublicDemoNextOrderStatus.accepted,
          )
          .closeJune(assignedInJuly: 1, monthlyExpenses: juneExpenses);
      expect(aggregate.state.month, 7);
      final app01Before = aggregate.workflow.assignments.single;
      expect(app01Before.engineerId, applicantId);

      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      aggregate = aggregate.recoverAssignment('eng-01');

      expect(aggregate.workflow.assignments, hasLength(2));
      final app01After = aggregate.workflow.assignments.firstWhere(
        (assignment) => assignment.engineerId == applicantId,
      );
      expect(app01After.projectName, app01Before.projectName);
      expect(app01After.nextOrderStatus, app01Before.nextOrderStatus);
      expect(app01After.replacementStage, app01Before.replacementStage);
      expect(app01After.humanity, app01Before.humanity);
      expect(aggregate.state.engineersAssigned, 2);
      expect(
        aggregate.state.engineersWaiting,
        1,
        reason: 'eng-02 remains waiting; only eng-01 was Recovered',
      );
    });
  });

  group('persistence invariants', () {
    test('a Recovery-committed aggregate round-trips through JSON without '
        'throwing, and the invariants still hold', () {
      var aggregate = publicDemoAggregateAtMonth(9);
      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      aggregate = aggregate.recoverAssignment('eng-01');

      final encoded = jsonDecode(jsonEncode(aggregate.toJson()));
      final restored = PublicDemoAggregate.fromJson(
        (encoded as Map).cast<String, dynamic>(),
      );

      expect(
        restored.state.engineersAssigned,
        aggregate.state.engineersAssigned,
      );
      expect(restored.state.engineersWaiting, aggregate.state.engineersWaiting);
      expect(restored.workflow.assignments.length, 1);
      expect(restored.workflow.assignments.single.engineerId, 'eng-01');
    });

    test('Recovery introduces no new save-schema keys: the aggregate JSON '
        'still has exactly {state, workflow}, and the recovered assignment '
        'JSON has exactly the pre-existing PublicDemoAssignment fields', () {
      var aggregate = publicDemoAggregateAtMonth(10);
      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      aggregate = aggregate.recoverAssignment('eng-01');

      final json = aggregate.toJson();
      expect(json.keys.toSet(), {'state', 'workflow'});

      final workflowJson = json['workflow'] as Map<String, dynamic>;
      expect(workflowJson.keys.toSet(), {
        'applicants',
        'engineers',
        'assignments',
      });

      final assignmentsJson = workflowJson['assignments'] as List;
      final recoveredJson = assignmentsJson
          .cast<Map<String, dynamic>>()
          .firstWhere((entry) => entry['engineerId'] == 'eng-01');
      expect(recoveredJson.keys.toSet(), {
        'engineerId',
        'engineerName',
        'projectName',
        'deliveryPressure',
        'budgetHealth',
        'humanity',
        'nextOrderStatus',
        'replacementStage',
        'fieldEvaluation',
      });
    });
  });

  group('no-op eligibility gate at the aggregate boundary', () {
    test('recoverAssignment is a structural no-op outside July-February', () {
      var aggregate = publicDemoAggregateAtMonth(6);
      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      final before = aggregate;

      final after = aggregate.recoverAssignment('eng-01');

      expect(after, same(before));
      expect(after.workflow.assignments, isEmpty);
    });

    test('recoverAssignment for an unknown engineer id changes nothing', () {
      final aggregate = publicDemoAggregateAtMonth(7);

      final after = aggregate.recoverAssignment('does-not-exist');

      expect(after, same(aggregate));
    });
  });
}
