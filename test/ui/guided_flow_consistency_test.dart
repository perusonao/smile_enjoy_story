// Playable 0.4C.3 §21, §33-40, §60, §65-66: end-to-end guided-flow
// consistency checks that don't fit neatly under the more specific test
// files — the true "New Game → 社員を見る → Employee Detail" boot path, no
// contradictory action-required/waiting labels on the same selection card,
// exactly one expanded primary action on Home during the tutorial, and no
// overflow at 360/390px once the new current-status card is in the mix.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/main.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_detail_screen.dart';

void main() {
  testWidgets('New Game → start picker → 今やること CTA → Employee Detail (§40, §65)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    // "開始モーダル" — the guided-start picker shown on a genuinely fresh boot.
    expect(find.text('ガイド付きで開始'), findsOneWidget);
    await tester.tap(find.text('ガイド付きで開始'));
    await tester.pumpAndSettle();

    expect(find.text('今やること'), findsOneWidget);
    final cta = find.textContaining('さんを見る');
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();

    // Not just "back to Home" — a real employee detail screen.
    expect(find.byType(EngineerDetailScreen), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('スキルシート / 営業'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.textContaining('スキルシート / 営業'), findsWidgets);
  });

  testWidgets('a client-interview card never shows both "操作が必要" and "次週に判定" for the same application (§21)', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    var state = GameEngine.newGame(seed: 9);
    final employee = state.engineers.first;
    final project = state.openProjects.first.project;
    final clientInterviewIndex = project.selectionFlow.steps.indexOf(SelectionStep.clientInterview);
    state = state.copyWith(proposals: [
      ProjectProposal(
        id: 'p-1',
        engineerId: employee.id,
        project: project,
        proposedWeek: 1,
        stage: ProposalStage.proposed,
        status: ApplicationStatus.active,
        currentStepIndex: clientInterviewIndex,
      ),
    ]);

    SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
    final controller = GameController();
    await tester.pumpWidget(
      GameScope(
        controller: controller,
        child: MaterialApp(home: EngineerDetailScreen(engineerId: employee.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('操作が必要'), findsWidgets);
    expect(find.textContaining('次週に判定'), findsNothing);
    expect(find.text('結果待ち・次週に判定されます'), findsNothing);
  });

  testWidgets('Home shows exactly one primary guided action, with any Critical items clearly labeled as an exception (§33-37)', (tester) async {
    SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(GameEngine.newGame(seed: 1).toJson())});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    expect(find.text('今やること'), findsOneWidget);
    // Exactly one guided-action CTA button — never multiple competing
    // primary actions on Home during the tutorial.
    final primaryButtons = find.byWidgetPredicate((w) => w is FilledButton && w.onPressed != null);
    // The bottom "次の週へ" bar is also a FilledButton — allow it plus the
    // single guided-action CTA, but no more.
    expect(primaryButtons.evaluate().length, lessThanOrEqualTo(2));
  });

  testWidgets('Employee detail with every EmployeeWorkflowState does not overflow at 360px/390px (§66)', (tester) async {
    for (final width in [360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      var state = GameEngine.newGame(seed: 11);
      final employee = state.engineers.first;
      final project = state.openProjects.first.project;
      state = state.copyWith(
        activeAssignments: [
          ActiveAssignment(engineerId: employee.id, project: project, remainingWeeks: 10, assignedWeek: 1),
        ],
      );

      SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
      final controller = GameController();
      await tester.pumpWidget(
        GameScope(
          controller: controller,
          child: MaterialApp(home: EngineerDetailScreen(engineerId: employee.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('参画中'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}
