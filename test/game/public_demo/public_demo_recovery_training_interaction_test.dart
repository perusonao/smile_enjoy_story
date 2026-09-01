import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';

/// RECOVERY-LOOP-1: the training/Recovery interaction Final Spec calls
/// out explicitly — an engineer currently selected for training must be
/// excluded from Recovery, and the existing training persistence invariant
/// ([PublicDemoAggregate._validateForPersistence]'s
/// `trainingSelections` ⇒ `!assignedEngineerIds.contains(...)` rule) must
/// keep holding once Recovery starts touching the same engineer set.
/// Public Demo 0.1's own Training feature/rules are entirely unchanged —
/// these tests only exercise the boundary between the two.
void main() {
  test('a training-selected engineer is not Recovered even though every '
      'other eligibility fact holds', () {
    var aggregate = publicDemoAggregateAtMonth(8);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    aggregate = aggregate.selectInternalTraining('eng-01');
    expect(
      aggregate.state.trainingSelections.containsKey('eng-01'),
      isTrue,
      reason:
          'internal training must still be selectable for a waiting '
          'engineer — Training\'s own rules are unchanged',
    );

    final after = aggregate.recoverAssignment('eng-01');

    expect(after, same(aggregate));
    expect(after.workflow.assignments, isEmpty);
  });

  test('once training is cancelled, the same engineer becomes Recovery-'
      'eligible again — no new Recovery-only training rule is invented', () {
    var aggregate = publicDemoAggregateAtMonth(8);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    aggregate = aggregate.selectInternalTraining('eng-01');
    // No PublicDemoAggregate-level passthrough exists for
    // PublicDemoState.cancelTraining (it is a pure, single-root state
    // method with no cross-domain concern) — rebuilding through the same
    // public toJson/fromJson persistence boundary every save/load already
    // uses is the sanctioned way to apply it to an aggregate in hand.
    final canceledState = aggregate.state.cancelTraining('eng-01');
    aggregate = PublicDemoAggregate.fromJson({
      'state': canceledState.toJson(),
      'workflow': aggregate.workflow.toJson(),
    });
    expect(aggregate.state.trainingSelections, isEmpty);

    aggregate = aggregate.recoverAssignment('eng-01');

    expect(aggregate.workflow.assignments, hasLength(1));
    expect(aggregate.state.engineersAssigned, 1);
  });

  test('Recovery does not clear another engineer\'s unrelated training '
      'selection', () {
    var aggregate = publicDemoAggregateAtMonth(8);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    aggregate = aggregate.selectInternalTraining('eng-02');

    aggregate = aggregate.recoverAssignment('eng-01');

    expect(aggregate.workflow.assignments, hasLength(1));
    expect(
      aggregate.state.trainingSelections['eng-02'],
      PublicDemoGrowthSource.internalTraining,
    );
  });

  test('the existing persistence invariant (a training selection can never '
      'name an assigned engineer) still holds once a different engineer is '
      'Recovered in the same month', () {
    var aggregate = publicDemoAggregateAtMonth(9);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    aggregate = aggregate.selectInternalTraining('eng-02');

    aggregate = aggregate.recoverAssignment('eng-01');

    final assignedIds = aggregate.workflow.assignedEngineerIds(
      month: aggregate.state.month,
    );
    expect(
      aggregate.state.trainingSelections.keys.every(
        (id) => !assignedIds.contains(id),
      ),
      isTrue,
    );
  });
}
