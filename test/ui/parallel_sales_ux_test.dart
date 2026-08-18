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

/// Opens [engineer]'s own [EngineerDetailScreen] from the 社員 tab list and
/// scrolls its `ListView` down to the "営業状況" section. 社員画面 Phase 2
/// moved 並行営業/参画オファー detail off the roster card (§5, §8-9: "一覧＝
/// 概要" / "詳細＝判断・操作") — it still lives in full on the detail screen
/// this reaches, just one tap further than before. The scroll is required,
/// not cosmetic: "営業状況" renders well below the fold, and (same as
/// `guided_flow_consistency_test.dart`'s own "スキルシート / 営業" scroll,
/// and the Chromium E2E harness's `scrollUntilButtonFound` doc comment)
/// Flutter's `SliverList` only materializes children within/near the
/// current viewport, so a fresh route mount never has it in the widget
/// tree until scrolled into view.
Future<void> _openEmployeeDetail(WidgetTester tester, GameState state, Engineer engineer) async {
  await _openEmployees(tester, state);
  await tester.tap(find.text(engineer.profile.name));
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(
    find.textContaining('並行営業'),
    find.byType(ListView),
    const Offset(0, -300),
  );
}

GameState _stateWithApplications(int count, {bool offer = false}) {
  // Free management (guided founding skipped): EngineerDetailScreen's own
  // "スキルシート / 営業" combined section only exists as a *tutorial*
  // simplification (§skillSheet stage) and never shows 並行営業's count —
  // the full 営業状況 section with that count is what a real post-tutorial
  // player sees, and what these tests are actually about.
  final state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 42));
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
    testWidgets('employee detail shows parallel sales $count/3', (tester) async {
      final state = _stateWithApplications(count);
      await _openEmployeeDetail(tester, state, state.engineers.first);
      expect(find.textContaining('並行営業 $count / 3'), findsWidgets);
      if (count > 1) {
        expect(find.textContaining('選考'), findsWidgets);
      }
    });
  }

  testWidgets('employee detail prioritizes a pending Offer', (tester) async {
    final state = _stateWithApplications(2, offer: true);
    await _openEmployeeDetail(tester, state, state.engineers.first);
    expect(find.textContaining('並行営業 2 / 3'), findsWidgets);
    // "参画オファー比較・回答" sits below "営業状況" in the ListView, so the
    // scroll from _openEmployeeDetail alone isn't guaranteed to reach it —
    // same lazy-SliverList reasoning as that helper's own doc comment.
    await tester.dragUntilVisible(
      find.text('参画オファー比較・回答'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('参画オファー比較・回答'), findsOneWidget);
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
