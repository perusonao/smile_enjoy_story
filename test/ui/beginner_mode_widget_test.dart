// Phase 3A UI regression: the "初心者経営期間" card (BeginnerModeCard) must
// render on Home once a Beginner Mode playthrough reaches its first
// assignment, without overflowing at the project's target mobile widths
// (§16 of the Phase 3A brief), and must disappear once Phase 3A's window
// (week <= BeginnerModeEngine.lastWeek) has passed.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/main.dart';

import '../game/prologue_engine_test.dart' show playThroughPrologue;
import '../game/test_helpers.dart';

const _widths = [360.0, 390.0];

Future<void> _pumpHome(WidgetTester tester, GameState state, double width) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
  await tester.pumpWidget(SesApp(controller: GameController()));
  await tester.pumpAndSettle();
}

void main() {
  group('BeginnerModeCard on Home', () {
    for (final width in _widths) {
      testWidgets('renders with next-collection + waiting-cost facts, no overflow at ${width}px', (tester) async {
        var state = playThroughPrologue(11);
        state = ProgressionEngine.reconcile(PrologueEngine.completePrologue(state));

        // Give it something concrete to show: a pending AR (next expected
        // collection) and a genuinely waiting second employee.
        final waiter = buildEngineer(id: 'waiter-widget', salary: 320000, status: EngineerStatus.waiting);
        state = state.copyWith(
          engineers: [...state.engineers, waiter],
          company: state.company.copyWith(engineerIds: [...state.company.engineerIds, waiter.id]),
          accountsReceivable: [
            AccountsReceivable(
              id: 'ar-widget-1',
              clientId: state.activeAssignments.first.project.clientId,
              projectId: state.activeAssignments.first.project.id,
              employeeId: state.activeAssignments.first.engineerId,
              amount: 600000,
              generatedMonth: 1,
              dueMonth: 2,
            ),
          ],
        );
        state = BeginnerModeEngine.reconcile(state);
        expect(BeginnerModeEngine.isPhase3AActive(state), isTrue);

        await _pumpHome(tester, state, width);

        expect(find.textContaining('初心者経営期間'), findsOneWidget);
        expect(find.textContaining('次回入金予定'), findsOneWidget);
        expect(find.textContaining('待機社員の給与負担'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('disappears once Phase 3A\'s window has passed (week > lastWeek)', (tester) async {
      var state = playThroughPrologue(11);
      state = ProgressionEngine.reconcile(PrologueEngine.completePrologue(state));
      state = state.copyWith(company: state.company.copyWith(currentWeek: BeginnerModeEngine.lastWeek + 1));
      expect(BeginnerModeEngine.isPhase3AActive(state), isFalse);

      await _pumpHome(tester, state, 390);

      expect(find.textContaining('初心者経営期間'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
