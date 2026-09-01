import 'package:flutter_test/flutter_test.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';

/// RECOVERY-LOOP-1: duplicate-assignment protection under repeated/rapid
/// re-invocation of [PublicDemoAggregate.recoverAssignment] — a double
/// tap, a re-render replaying the same handler, or a repeated domain
/// command must never create a second assignment for the same engineer or
/// disturb the one already committed.
void main() {
  test('a double tap (two immediate recoverAssignment calls) commits '
      'exactly one assignment', () {
    var aggregate = publicDemoAggregateAtMonth(7);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');

    final firstTap = aggregate.recoverAssignment('eng-01');
    final secondTap = firstTap.recoverAssignment('eng-01');

    expect(firstTap.workflow.assignments, hasLength(1));
    expect(secondTap.workflow.assignments, hasLength(1));
    expect(
      secondTap,
      same(firstTap),
      reason:
          'once already Recovered, a repeated call must be a structural '
          'no-op — not merely the same count by coincidence',
    );
  });

  test('re-render replay: calling recoverAssignment again on the ALREADY '
      '-recovered aggregate (simulating a widget rebuild re-issuing the '
      'same handler) never duplicates the assignment', () {
    var aggregate = publicDemoAggregateAtMonth(9);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    final recovered = aggregate.recoverAssignment('eng-01');

    var replayed = recovered;
    for (var i = 0; i < 5; i++) {
      replayed = replayed.recoverAssignment('eng-01');
    }

    expect(replayed.workflow.assignments, hasLength(1));
    expect(replayed.state.engineersAssigned, recovered.state.engineersAssigned);
    expect(replayed.state.engineersWaiting, recovered.state.engineersWaiting);
  });

  test('repeating the command against the ORIGINAL (stale) aggregate '
      'reference still never produces two assignments — immutability '
      'means the stale reference itself never changes', () {
    var aggregate = publicDemoAggregateAtMonth(10);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    final original = aggregate;

    final resultA = original.recoverAssignment('eng-01');
    final resultB = original.recoverAssignment('eng-01');

    expect(original.workflow.assignments, isEmpty);
    expect(resultA.workflow.assignments, hasLength(1));
    expect(resultB.workflow.assignments, hasLength(1));
    expect(resultA.workflow.assignments.single.engineerId, 'eng-01');
    expect(resultB.workflow.assignments.single.engineerId, 'eng-01');
  });

  test('three repeated domain commands against the same engineer id in a '
      'row still settle on exactly one assignment and one consistent count '
      'projection', () {
    var aggregate = publicDemoAggregateAtMonth(7);
    aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
    aggregate = aggregate.recoverAssignment('eng-01');
    aggregate = aggregate.recoverAssignment('eng-01');
    aggregate = aggregate.recoverAssignment('eng-01');

    expect(aggregate.workflow.assignments, hasLength(1));
    expect(aggregate.state.engineersAssigned, 1);
    expect(aggregate.state.engineersWaiting, 1);
  });
}
