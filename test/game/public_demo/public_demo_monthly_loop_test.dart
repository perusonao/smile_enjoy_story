import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  test('Public Demo can advance from April through July', () {
    var state = PublicDemoState.aprilStart();

    // April: one of two engineers wins a May order.
    state = state.advanceToMay(
      monthlyExpenses: 800000,
      orderedEngineers: 1,
    );
    expect(state.month, 5);
    expect(state.engineersAssigned, 1);
    expect(state.engineersWaiting, 1);

    // May: one applicant accepts and also wins a June order before joining.
    state = state.advanceToJune(
      monthlyExpenses: 800000,
      acceptedHires: 1,
      hiredWithOrders: 1,
    );
    expect(state.month, 6);
    expect(state.engineerCount, 3);
    expect(state.engineersAssigned, 2);
    expect(state.engineersWaiting, 1);

    // June: only one engineer has a July assignment; the others become waiting.
    state = state.advanceToJuly(
      monthlyExpenses: 800000,
      assignedInJuly: 1,
    );
    expect(state.month, 7);
    expect(state.cash, 600000);
    expect(state.engineerCount, 3);
    expect(state.engineersAssigned, 1);
    expect(state.engineersWaiting, 2);
    expect(state.salesRemaining, 4);
  });
}
