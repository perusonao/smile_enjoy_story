import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/main.dart';
import 'package:smile_enjoy_story/ui/projects/project_list_screen.dart';
import 'package:smile_enjoy_story/ui/widgets/selection_stepper.dart';

Future<void> _openEmployees(WidgetTester tester, GameState state) async {
  SharedPreferences.setMockInitialValues({
    'ses_playable_save_v1': jsonEncode(state.toJson()),
    'ses_founding_tutorial_seen': true,
  });
  await tester.pumpWidget(SesApp(controller: GameController()));
  await tester.pumpAndSettle();
  final tutorialButton = find.text('社員を見る');
  if (tutorialButton.evaluate().isNotEmpty) {
    await tester.tap(tutorialButton);
    await tester.pumpAndSettle();
  }
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text('社員')),
  );
  await tester.pumpAndSettle();
}

GameState _stateWithApplications(int count, {bool offer = false}) {
  final state = GameEngine.newGame(seed: 42);
  final engineer = state.engineers.first;
  final projects = state.openProjects.map((entry) => entry.project).toList();
  final applications = <ProjectProposal>[
    for (var i = 0; i < count; i++)
      ProjectProposal(
        id: 'application-$i',
        engineerId: engineer.id,
        project: projects[i % projects.length],
        proposedWeek: 1,
        stage: ProposalStage.proposed,
        currentStepIndex:
            i % projects[i % projects.length].selectionFlow.steps.length,
        status: offer && i == 0
            ? ApplicationStatus.offered
            : ApplicationStatus.active,
        fitScore: 70,
      ),
  ];
  return state.copyWith(
    proposals: applications,
    offers: offer
        ? [
            Offer(
              id: 'offer-1',
              applicationId: applications.first.id,
              projectId: applications.first.project.id,
              employeeId: engineer.id,
              monthlyRate: applications.first.project.monthlyRate,
              startWeek: 2,
              responseDeadlineWeek: state.week,
            ),
          ]
        : const [],
  );
}

Future<void> _pumpEmployeeProjectList(WidgetTester tester, GameState state) async {
  SharedPreferences.setMockInitialValues({
    'ses_playable_save_v1': jsonEncode(state.toJson()),
  });
  final controller = GameController();
  await tester.pumpWidget(
    GameScope(
      controller: controller,
      child: MaterialApp(
        home: ProjectListScreen(employeeId: state.engineers.first.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final count in [0, 1, 3]) {
    testWidgets('employee card shows parallel sales $count/3', (tester) async {
      await _openEmployees(tester, _stateWithApplications(count));
      expect(find.text('並行営業 $count / 3'), findsWidgets);
      if (count > 1) {
        expect(find.textContaining('選考'), findsWidgets);
      }
    });
  }

  testWidgets('employee card prioritizes a pending Offer', (tester) async {
    await _openEmployees(tester, _stateWithApplications(2, offer: true));
    expect(find.text('OFFER'), findsOneWidget);
    expect(find.textContaining('回答期限: 今週'), findsOneWidget);
    expect(find.text('並行営業 2 / 3'), findsWidgets);
  });

  testWidgets(
    'project market has no direct proposal action',
    (tester) async {
      final state = GameEngine.newGame(seed: 42);
      final engineer = state.engineers.first;
    await _pumpEmployeeProjectList(tester, state);

      expect(engineer.id,isNotEmpty);
      expect(find.widgetWithText(AppBar, '市場の案件情報'), findsOneWidget);
      expect(find.text('提案する'), findsNothing);
      expect(find.textContaining('応募は社員詳細から営業を開始'), findsWidgets);
    },
  );

  testWidgets('project market remains read-only at the three-project limit', (
    tester,
  ) async {
    final state = _stateWithApplications(3);
    await _pumpEmployeeProjectList(tester, state);
    expect(find.text('提案する'),findsNothing);
  });

  for (final flow in <SelectionFlow>[
    const SelectionFlow.simple(),
    const SelectionFlow.standard(),
    const SelectionFlow.advanced(),
  ]) {
    for (final index in [0, flow.steps.length ~/ 2, flow.steps.length - 1]) {
      testWidgets('stepper ${flow.type.name} at $index is safe at 390px', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 350,
                child: SelectionStepper(
                  steps: flow.steps,
                  currentStepIndex: index,
                  compact: true,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(SelectionStepper), findsOneWidget);
      });
    }
  }
}
