import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_detail_screen.dart';

Future<void> _pumpDetail(WidgetTester tester, GameState state) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({
    'ses_playable_save_v1': jsonEncode(state.toJson()),
  });
  await tester.pumpWidget(
    GameScope(
      controller: GameController(),
      child: MaterialApp(
        home: EngineerDetailScreen(engineerId: state.engineers.first.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('assigned engineer shows current assignment and project title', (
    tester,
  ) async {
    final base = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 84));
    final engineer = base.engineers.first;
    final project = base.openProjects.first.project;
    final state = base.copyWith(
      activeAssignments: [
        ActiveAssignment(
          engineerId: engineer.id,
          project: project,
          remainingWeeks: 8,
          assignedWeek: base.week,
        ),
      ],
    );

    await _pumpDetail(tester, state);

    expect(find.text('現在の案件'), findsOneWidget);
    expect(find.text(project.title), findsOneWidget);
  });

  testWidgets('unassigned engineer omits current assignment section', (
    tester,
  ) async {
    final state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 84));

    await _pumpDetail(tester, state);

    expect(find.text('現在の案件'), findsNothing);
  });
}
