// Assignment-acceptance UX (Playable 0.4C.3 §3-11, §54, §58): accepting a
// final Offer must immediately and unambiguously tell the player it worked
// and when the employee starts — not leave them wondering "did that work?"
// the way the original bug report described.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_detail_screen.dart';

GameState _stateWithPendingOffer() {
  var state = GameEngine.newGame(seed: 7);
  final employee = state.engineers.first;
  final project = state.openProjects.first.project;
  final (afterMint, proposalId) = state.mintId('proposal');
  final proposal = ProjectProposal(
    id: proposalId,
    engineerId: employee.id,
    project: project,
    proposedWeek: 1,
    stage: ProposalStage.proposed,
    status: ApplicationStatus.offered,
    fitScore: 80,
  );
  final offer = Offer(
    id: 'offer-1',
    applicationId: proposalId,
    projectId: project.id,
    employeeId: employee.id,
    monthlyRate: project.monthlyRate,
    startWeek: 6,
    responseDeadlineWeek: state.week,
  );
  return afterMint.copyWith(
    engineers: [employee.copyWith(salesStatus: SalesStatus.interviewing), ...state.engineers.skip(1)],
    proposals: [proposal],
    offers: [offer],
  );
}

Future<GameController> _pump(WidgetTester tester, GameState state) async {
  // Tall viewport so every section on the employee-detail page renders
  // without needing to scroll — sidesteps ListView/Sliver lazy-building
  // flakiness in favor of just fitting everything on screen at once.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
  final controller = GameController();
  await tester.pumpWidget(
    GameScope(
      controller: controller,
      child: MaterialApp(home: EngineerDetailScreen(engineerId: state.engineers.first.id)),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('accepting a final Offer shows an explicit result with start week, then "参画予定" everywhere', (tester) async {
    final state = _stateWithPendingOffer();
    await _pump(tester, state);

    await tester.tap(find.text('受諾'));
    await tester.pumpAndSettle();

    // §5, §54: an explicit, unmissable result — not just a state change
    // the player has to go infer from elsewhere.
    expect(find.text('参画オファーを受諾しました'), findsOneWidget);
    expect(find.textContaining('参画開始: Week 6'), findsOneWidget);
    expect(find.textContaining('参画開始待ち'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // §6: the employee card must say "参画予定", never "面談待ち" or a bare
    // "待機中" — this is what EmployeeWorkflowState.assignmentScheduled
    // exists to fix.
    expect(find.text('面談待ち'), findsNothing);
    expect(find.text('参画予定'), findsWidgets);
    expect(find.textContaining('Week 6 から参画開始'), findsOneWidget);
  });

  testWidgets('declining a final Offer asks for confirmation, then gives immediate feedback via a SnackBar', (tester) async {
    // Playable 0.4C.4 §16: declining a participation offer is irreversible,
    // so it now goes through a one-tap confirmation first.
    final state = _stateWithPendingOffer();
    await _pump(tester, state);

    await tester.tap(find.text('辞退'));
    await tester.pumpAndSettle();

    expect(find.text('参画オファーを辞退しますか？'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('辞退する'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('辞退しました'), findsWidgets);
  });
}
