import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_sales_test_helpers.dart';

/// RECOVERY-LOOP-1: [PublicDemoWorkflowState.recoverLateYearAssignment]
/// unit tests, exercised directly on the workflow (no
/// [PublicDemoAggregate]/[PublicDemoState] needed — this method itself
/// never reads finance facts).
void main() {
  PublicDemoEngineerSales genuineEngineer(String id) =>
      recordTestClientInterviewPass(
        PublicDemoEngineerSales(
          id: id,
          name: 'エンジニア $id',
          summary: 'テスト用',
          interviewProfile: const PublicDemoInterviewProfile(
            skillFit: 90,
            humanity: 90,
            morale: 90,
            clientTrust: 90,
          ),
        ),
      );

  PublicDemoWorkflowState orderedWorkflow(List<String> engineerIds) {
    var workflow = PublicDemoWorkflowState(
      applicants: const [],
      engineers: [for (final id in engineerIds) genuineEngineer(id)],
    );
    for (final id in engineerIds) {
      workflow = workflow.recordOrder(id);
    }
    return workflow;
  }

  group('atomic append/upsert', () {
    test('a founding engineer (eng-01) is upserted using the existing '
        'publicDemoInitialAssignments template, not the generic default', () {
      final workflow = orderedWorkflow([
        'eng-01',
      ]).recoverLateYearAssignment('eng-01', month: 7);

      expect(workflow.assignments, hasLength(1));
      final assignment = workflow.assignments.single;
      expect(assignment.engineerId, 'eng-01');
      expect(
        assignment.projectName,
        '販売管理システム開発',
        reason:
            'matches publicDemoInitialAssignments so Recovery does not '
            'silently change an already-established project identity',
      );
    });

    test('a non-founding engineer falls back to forOrderedEngineer', () {
      final workflow = orderedWorkflow([
        'eng-recovery',
      ]).recoverLateYearAssignment('eng-recovery', month: 7);

      expect(workflow.assignments, hasLength(1));
      expect(workflow.assignments.single.engineerId, 'eng-recovery');
    });

    test('nextOrderStatus is explicitly accepted and replacementStage is '
        'explicitly ordered — never left to PublicDemoAssignment defaults', () {
      final workflow = orderedWorkflow([
        'eng-01',
      ]).recoverLateYearAssignment('eng-01', month: 7);

      final assignment = workflow.assignments.single;
      expect(assignment.nextOrderStatus, PublicDemoNextOrderStatus.accepted);
      expect(assignment.replacementStage, PublicDemoReplacementStage.ordered);
    });
  });

  group('existing assignments are preserved', () {
    test('recovering eng-01 does not touch an assignment already committed '
        'for eng-02', () {
      var workflow = orderedWorkflow(['eng-01', 'eng-02']);
      workflow = workflow.recoverLateYearAssignment('eng-02', month: 7);
      final eng02Before = workflow.assignments.single;

      workflow = workflow.recoverLateYearAssignment('eng-01', month: 7);

      expect(workflow.assignments, hasLength(2));
      final eng02After = workflow.assignments.firstWhere(
        (assignment) => assignment.engineerId == 'eng-02',
      );
      expect(eng02After.projectName, eng02Before.projectName);
      expect(eng02After.nextOrderStatus, eng02Before.nextOrderStatus);
      expect(eng02After.replacementStage, eng02Before.replacementStage);
      expect(eng02After.deliveryPressure, eng02Before.deliveryPressure);
      expect(eng02After.budgetHealth, eng02Before.budgetHealth);
      expect(eng02After.humanity, eng02Before.humanity);
    });

    test('an unrelated existing assignment for a different engineer, with '
        'custom field values, survives byte-for-byte', () {
      var workflow = orderedWorkflow([
        'eng-01',
        'eng-02',
      ]).recoverLateYearAssignment('eng-02', month: 7);
      // Simulate a mid-year replacement decision already committed for
      // eng-02 before eng-01's Recovery is attempted.
      workflow = workflow.withAssignmentUpdate('eng-02', fieldEvaluation: 77);
      final eng02Before = workflow.assignments.firstWhere(
        (assignment) => assignment.engineerId == 'eng-02',
      );

      workflow = workflow.recoverLateYearAssignment('eng-01', month: 8);

      final eng02After = workflow.assignments.firstWhere(
        (assignment) => assignment.engineerId == 'eng-02',
      );
      expect(eng02After.fieldEvaluation, 77);
      expect(eng02After.fieldEvaluation, eng02Before.fieldEvaluation);
    });
  });

  group('duplicate protection', () {
    test('calling recoverLateYearAssignment twice for the same engineer '
        'never creates a second entry', () {
      var workflow = orderedWorkflow(['eng-01']);
      workflow = workflow.recoverLateYearAssignment('eng-01', month: 7);
      workflow = workflow.recoverLateYearAssignment('eng-01', month: 7);

      expect(workflow.assignments, hasLength(1));
    });

    test('a repeated call once already assigned is a structural no-op', () {
      final once = orderedWorkflow([
        'eng-01',
      ]).recoverLateYearAssignment('eng-01', month: 7);
      final twice = once.recoverLateYearAssignment('eng-01', month: 7);

      expect(twice.assignments.length, once.assignments.length);
      expect(
        twice.assignments.single.nextOrderStatus,
        once.assignments.single.nextOrderStatus,
      );
    });
  });

  group('no-op guards (defense in depth)', () {
    test('an engineer not yet ordered is unchanged', () {
      final sellingWorkflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: [
          genuineEngineer(
            'eng-01',
          ).copyWith(stage: PublicDemoSalesStage.selling),
        ],
      );

      final result = sellingWorkflow.recoverLateYearAssignment(
        'eng-01',
        month: 7,
      );

      expect(result.assignments, isEmpty);
    });

    test('an engineer without a genuine interview record is unchanged', () {
      final forgedWorkflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: const [
          PublicDemoEngineerSales(
            id: 'eng-01',
            name: '佐藤 健',
            summary: 'テスト用',
            interviewProfile: PublicDemoInterviewProfile(
              skillFit: 90,
              humanity: 90,
              morale: 90,
              clientTrust: 90,
            ),
            stage: PublicDemoSalesStage.ordered,
          ),
        ],
      );

      final result = forgedWorkflow.recoverLateYearAssignment(
        'eng-01',
        month: 7,
      );

      expect(result.assignments, isEmpty);
    });

    test('an already-assigned engineer for the given month is unchanged', () {
      var workflow = orderedWorkflow(['eng-01']);
      workflow = workflow.recoverLateYearAssignment('eng-01', month: 7);
      final onceAssigned = workflow;

      final result = workflow.recoverLateYearAssignment('eng-01', month: 7);

      expect(result.assignments, onceAssigned.assignments);
    });
  });
}
