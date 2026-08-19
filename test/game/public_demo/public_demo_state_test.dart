import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  group('PublicDemoState', () {
    test('April starts with the Public Demo 0.1 baseline', () {
      final state = PublicDemoState.aprilStart();

      expect(state.month, 4);
      expect(state.cash, 3000000);
      expect(state.engineerCount, 2);
      expect(state.adminCount, 1);
      expect(state.engineersWaiting, 2);
      expect(state.engineersAssigned, 0);
      expect(state.salesCapacity, 4);
      expect(state.salesRemaining, 4);
    });

    test('sales capacity cannot be used beyond four slots', () {
      var state = PublicDemoState.aprilStart();
      for (var i = 0; i < 5; i++) {
        state = state.useSalesSlot();
      }

      expect(state.salesUsed, 4);
      expect(state.salesRemaining, 0);
    });

    test('failed April can advance to May with engineers still waiting', () {
      final may = PublicDemoState.aprilStart().advanceToMay(
        monthlyExpenses: 800000,
        orderedEngineers: 0,
      );

      expect(may.month, 5);
      expect(may.cash, 2200000);
      expect(may.engineersAssigned, 0);
      expect(may.engineersWaiting, 2);
      expect(may.salesUsed, 0);
      expect(may.salesRemaining, 4);
    });

    test('only engineers with May orders become assigned', () {
      final may = PublicDemoState.aprilStart().advanceToMay(
        monthlyExpenses: 800000,
        orderedEngineers: 1,
      );

      expect(may.engineersAssigned, 1);
      expect(may.engineersWaiting, 1);
    });
  });
}
