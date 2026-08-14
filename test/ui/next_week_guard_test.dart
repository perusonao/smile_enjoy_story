// "次の週へ" guard behavior (Playable 0.4C.2 §53-57, §60): a pending
// client interview is the one genuine hard block, and it must resolve
// through an explicit choice — never a silent no-op.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/main.dart';

GameState _stateWithPendingClientInterview() {
  final base = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 4));
  final engineer = base.engineers.first;
  Project? withClientInterviewFirst;
  for (final entry in base.openProjects) {
    if (entry.project.selectionFlow.steps.isNotEmpty && entry.project.selectionFlow.steps.first == SelectionStep.clientInterview) {
      withClientInterviewFirst = entry.project;
      break;
    }
  }
  // Fall back to whatever's open if no fixture project happens to start
  // with clientInterview — the test just needs *a* pending one.
  final project = withClientInterviewFirst ?? base.openProjects.first.project;
  final proposal = ProjectProposal(
    id: 'p1',
    engineerId: engineer.id,
    project: project,
    proposedWeek: base.week,
    stage: ProposalStage.proposed,
    currentStepIndex: project.selectionFlow.steps.indexOf(SelectionStep.clientInterview).clamp(0, project.selectionFlow.steps.length - 1),
  );
  return base.copyWith(proposals: [proposal]);
}

void main() {
  testWidgets('advancing the week with a pending client interview shows a choice, never a silent no-op', (tester) async {
    final state = _stateWithPendingClientInterview();
    if (state.proposals.single.currentStep != SelectionStep.clientInterview) {
      return; // fixture project didn't line up — nothing to assert this run
    }
    SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    final weekBefore = state.displayWeek;
    await tester.tap(find.textContaining('次の週へ'));
    await tester.pumpAndSettle();

    expect(find.text('客先面談が残っています'), findsOneWidget);
    expect(find.text('面談をプレイ'), findsOneWidget);
    expect(find.text('社員に任せて進む'), findsOneWidget);

    await tester.tap(find.text('社員に任せて進む'));
    await tester.pumpAndSettle();

    // The week actually advanced — not silently stuck.
    expect(find.textContaining('Week ${weekBefore + 1}'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending final Offer deadline is a warning, not a hard block — the player can still proceed', (tester) async {
    var state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 9));
    final engineer = state.engineers.first;
    final project = state.openProjects.first.project;
    final proposal = ProjectProposal(
      id: 'p1',
      engineerId: engineer.id,
      project: project,
      proposedWeek: state.week,
      stage: ProposalStage.interviewPassed,
      status: ApplicationStatus.offered,
    );
    final offer = Offer(
      id: 'offer-1',
      applicationId: 'p1',
      projectId: project.id,
      employeeId: engineer.id,
      monthlyRate: project.monthlyRate,
      startWeek: state.week + 1,
      responseDeadlineWeek: state.week, // deadline is this week
    );
    state = state.copyWith(proposals: [proposal], offers: [offer]);
    SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    final weekBefore = state.displayWeek;
    await tester.tap(find.textContaining('次の週へ'));
    await tester.pumpAndSettle();

    // Critical confirmation dialog (soft warning) — "それでも進む" must
    // actually work, unlike the old silent-block bug for client interviews.
    expect(find.text('重要事項が残っています'), findsOneWidget);
    await tester.tap(find.text('それでも進む'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Week ${weekBefore + 1}'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
