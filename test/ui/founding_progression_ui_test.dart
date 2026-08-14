// Guided-founding UI tests (Playable 0.4C.1 §57-58): mission-card
// navigation has no dead ends, locked screens explain themselves instead of
// looking broken, and nothing overflows at common mobile widths.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/main.dart';

Future<void> _pumpWithSave(WidgetTester tester, GameState state) async {
  SharedPreferences.setMockInitialValues({
    'ses_playable_save_v1': jsonEncode(state.toJson()),
  });
  await tester.pumpWidget(SesApp(controller: GameController()));
  await tester.pumpAndSettle();
}

GameState _assignedState({int seed = 3}) {
  var state = GameEngine.newGame(seed: seed);
  state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
  state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
  state = GameEngine.recordMilestone(state, FoundingMilestone.startSales);
  state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);
  state = GameEngine.recordMilestone(state, FoundingMilestone.completeClientInterview);
  final engineer = state.engineers.first;
  final project = state.openProjects.first.project;
  final assignment = ActiveAssignment(
    engineerId: engineer.id,
    project: project,
    remainingWeeks: project.durationWeeks,
    assignedWeek: state.week,
  );
  state = state.copyWith(
    engineers: [
      engineer.copyWith(status: EngineerStatus.assigned, salesStatus: SalesStatus.assigned),
      state.engineers[1],
    ],
    activeAssignments: [assignment],
  );
  return GameEngine.recordMilestone(state, FoundingMilestone.firstAssignment);
}

void main() {
  testWidgets('Founding mission Stage 1 CTA navigates to employee detail without a dead end', (
    WidgetTester tester,
  ) async {
    await _pumpWithSave(tester, GameEngine.newGame(seed: 1));

    expect(find.text('今やること'), findsOneWidget);
    expect(find.text('STEP 1 / 9'), findsOneWidget);
    final cta = find.textContaining('さんを見る');
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();

    // Landed on a real employee detail screen, not a dead end.
    expect(find.textContaining('スキルシート / 営業'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recruitment tab is locked before the first assignment, at 360px and 390px', (
    WidgetTester tester,
  ) async {
    for (final width in [360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpWithSave(tester, GameEngine.newGame(seed: 1));
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('採用')),
      );
      await tester.pumpAndSettle();

      expect(find.text('🔒'), findsOneWidget);
      expect(find.textContaining('解放されます'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Recruitment unlocks once the first assignment milestone is recorded', (
    WidgetTester tester,
  ) async {
    await _pumpWithSave(tester, _assignedState());

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('採用')),
    );
    await tester.pumpAndSettle();

    expect(find.text('🔒'), findsNothing);
    expect(find.text('Free Work'), findsOneWidget);
  });

  testWidgets('Welfare section in その他 is locked until Recruitment interview experience', (
    WidgetTester tester,
  ) async {
    await _pumpWithSave(tester, _assignedState());

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('その他')),
    );
    await tester.pumpAndSettle();

    expect(find.text('🔒 福利厚生 / 社員環境'), findsOneWidget);
    expect(find.text('健康診断を実施する'), findsNothing);
    // The rest of "その他" (company info) stays visible even while locked.
    expect(find.text('会社情報'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shows the simplified dashboard before the first assignment, full dashboard after', (
    WidgetTester tester,
  ) async {
    await _pumpWithSave(tester, GameEngine.newGame(seed: 1));
    expect(find.text('待機人数'), findsOneWidget);
    expect(find.text('売掛金'), findsNothing);

    await _pumpWithSave(tester, _assignedState());
    expect(find.text('待機人数'), findsNothing);
    expect(find.text('売掛金'), findsOneWidget);
    expect(find.text('稼働率'), findsOneWidget);
  });

  testWidgets('a skipped tutorial shows no founding mission card and every feature is open', (
    WidgetTester tester,
  ) async {
    await _pumpWithSave(tester, GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 1)));

    expect(find.text('今やること'), findsNothing);

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('採用')),
    );
    await tester.pumpAndSettle();
    expect(find.text('🔒'), findsNothing);
    expect(find.text('Free Work'), findsOneWidget);
  });
}
