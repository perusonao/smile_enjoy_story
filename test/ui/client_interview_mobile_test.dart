import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/projects/client_interview_screen.dart';

GameState _state() {
  var s = GameEngine.newGame(seed: 44);
  final e = s.engineers.first,
      p = s.openProjects.first.project,
      index = p.selectionFlow.steps.indexOf(SelectionStep.clientInterview);
  s = s.copyWith(
    proposals: [
      ProjectProposal(
        id: 'mobile-client',
        engineerId: e.id,
        project: p,
        proposedWeek: 1,
        stage: ProposalStage.proposed,
        currentStepIndex: index,
        fitScore: 70,
      ),
    ],
  );
  return GameEngine.startClientInterview(s, 'mobile-client');
}

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('client interview fits ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({
        'ses_playable_save_v1': jsonEncode(_state().toJson()),
      });
      final controller = GameController();
      await tester.pumpWidget(
        GameScope(
          controller: controller,
          child: const MaterialApp(
            home: ClientInterviewScreen(applicationId: 'mobile-client'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('質問 1 / 3'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }
}
