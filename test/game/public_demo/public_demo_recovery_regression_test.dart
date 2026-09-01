import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';

/// RECOVERY-LOOP-1: regression coverage proving May's existing assignment
/// authority ([PublicDemoWorkflowState.assignOrderedForMay], reached via
/// [PublicDemoAggregate.closeMay]) and the ordinary April→July sales flow
/// are byte-for-byte unaffected by adding
/// [PublicDemoWorkflowState.recoverLateYearAssignment]/
/// [PublicDemoAggregate.recoverAssignment] to the same two classes. Neither
/// test below ever calls `recoverAssignment` — both are the SAME
/// established scenario public_demo_aggregate_test.dart's own May-assignment
/// group already exercises.
void main() {
  test('May assignment behavior remains valid: a founding engineer ordered '
      'before April closes is picked up by assignOrderedForMay exactly as '
      'before, using the initial-assignment template', () {
    final aggregate = PublicDemoAggregate.initial()
        .startSkillSheetReview('eng-01')
        .beginSelling('eng-01')
        .introduceProject('eng-01')
        .recordEngineerInterviewResult(
          engineerId: 'eng-01',
          type: PublicDemoInterviewType.partner,
        )
        .recordEngineerInterviewResult(
          engineerId: 'eng-01',
          type: PublicDemoInterviewType.client,
        )
        .recordOrder('eng-01')
        .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
        .closeMay(
          week: 9,
          monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        );

    expect(aggregate.workflow.assignments, hasLength(1));
    final assignment = aggregate.workflow.assignments.single;
    expect(assignment.engineerId, 'eng-01');
    expect(assignment.projectName, '販売管理システム開発');
    expect(assignment.deliveryPressure, 45);
    expect(assignment.budgetHealth, 75);
    expect(assignment.humanity, 70);
    // May's own roster leaves nextOrderStatus/replacementStage at their
    // constructor defaults — June's decideOrder/acceptOrder flow (untouched
    // by Recovery) is what later sets them, not assignOrderedForMay itself.
    expect(assignment.nextOrderStatus, PublicDemoNextOrderStatus.undecided);
    expect(assignment.replacementStage, PublicDemoReplacementStage.none);
  });

  test('the existing non-Recovery sales flow (April→May→June→July, no '
      'Recovery call anywhere) still reaches July with the expected '
      'engineersAssigned/engineersWaiting projection', () {
    var aggregate = PublicDemoAggregate.initial()
        .startSkillSheetReview('eng-01')
        .beginSelling('eng-01')
        .introduceProject('eng-01')
        .recordEngineerInterviewResult(
          engineerId: 'eng-01',
          type: PublicDemoInterviewType.partner,
        )
        .recordEngineerInterviewResult(
          engineerId: 'eng-01',
          type: PublicDemoInterviewType.client,
        )
        .recordOrder('eng-01')
        .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
        .closeMay(
          week: 9,
          monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        );

    aggregate = aggregate
        .withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.accepted,
        )
        .closeJune(
          assignedInJuly: 1,
          monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        )
        .closeJuly(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses);

    expect(aggregate.state.month, 8);
    expect(aggregate.state.engineersAssigned, 1);
    expect(aggregate.state.engineersWaiting, 1);
  });
}
