// Playable 0.4C.4 §46-53: mobile-width (360px/390px) overflow checks for
// every state a guided player can land in on the way to (and just after)
// their first assignment — including the failure/retry states the
// EmployeeWorkflowEngine-driven GuidedAction refactor (§15-19) and the
// TaskEngine severity fix (§21-27) newly distinguish.

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

const _widths = [360.0, 390.0];

Future<void> _pumpHome(WidgetTester tester, GameState state, double width) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
  await tester.pumpWidget(SesApp(controller: GameController()));
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(WidgetTester tester, GameState state, String engineerId, double width) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
  final controller = GameController();
  await tester.pumpWidget(
    GameScope(
      controller: controller,
      child: MaterialApp(home: EngineerDetailScreen(engineerId: engineerId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Home, failed-selection state (focus employee reverted to selling)', () {
    for (final width in _widths) {
      testWidgets('no overflow at ${width}px', (tester) async {
        var state = GameEngine.newGame(seed: 1);
        final focusId = ProgressionEngine.focusEmployeeId(state)!;
        state = state.copyWith(
          engineers: [for (final e in state.engineers) if (e.id == focusId) e.copyWith(salesStatus: SalesStatus.selling) else e],
        );
        state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
        state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
        state = GameEngine.recordMilestone(state, FoundingMilestone.startSales);
        state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);

        await _pumpHome(tester, state, width);
        expect(find.text('今やること'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Home, retry-waiting state (a fresh interview request just arrived after a failure)', () {
    for (final width in _widths) {
      testWidgets('no overflow at ${width}px', (tester) async {
        var state = GameEngine.newGame(seed: 1);
        final focusId = ProgressionEngine.focusEmployeeId(state)!;
        final project = state.openProjects.first.project;
        state = state.copyWith(
          engineers: [for (final e in state.engineers) if (e.id == focusId) e.copyWith(salesStatus: SalesStatus.selling) else e],
          interviewOffers: [
            InterviewOffer(
              id: 'io-retry',
              employeeId: focusId,
              projectId: project.id,
              clientId: project.clientId,
              generatedWeek: state.week,
              expiresWeek: state.week + 2,
              skillSheetMatch: 70,
            ),
          ],
        );
        state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
        state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
        state = GameEngine.recordMilestone(state, FoundingMilestone.startSales);
        state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);

        await _pumpHome(tester, state, width);
        expect(find.text('今やること'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Home, long-waiting + selling (economic waiting, not an actionable Critical)', () {
    for (final width in _widths) {
      testWidgets('no overflow at ${width}px', (tester) async {
        var state = GameEngine.newGame(seed: 1);
        final focusId = ProgressionEngine.focusEmployeeId(state)!;
        state = state.copyWith(
          engineers: [for (final e in state.engineers) if (e.id == focusId) e.copyWith(salesStatus: SalesStatus.selling) else e],
          waitingStreak: {focusId: 4},
        );
        state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
        state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
        state = GameEngine.recordMilestone(state, FoundingMilestone.startSales);

        await _pumpHome(tester, state, width);
        expect(find.text('今やること'), findsOneWidget);
        // The busy employee's long-waiting notice is Info-level (§21-27), so
        // it collapses under "その他" rather than sitting expanded in the
        // Critical section — this test's job is the overflow check, which
        // TaskEngine's own unit tests already cover the data side of.
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Employee detail, Final Offer pending', () {
    for (final width in _widths) {
      testWidgets('no overflow at ${width}px', (tester) async {
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
        state = afterMint.copyWith(
          engineers: [employee.copyWith(salesStatus: SalesStatus.interviewing), ...state.engineers.skip(1)],
          proposals: [proposal],
          offers: [offer],
        );

        await _pumpDetail(tester, state, employee.id, width);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Employee detail, Assignment Scheduled ("参画予定")', () {
    for (final width in _widths) {
      testWidgets('no overflow at ${width}px', (tester) async {
        var state = GameEngine.newGame(seed: 1);
        final employee = state.engineers.first;
        final project = state.openProjects.first.project;
        state = state.copyWith(proposals: [
          ProjectProposal(
            id: 'p-scheduled',
            engineerId: employee.id,
            project: project,
            proposedWeek: 1,
            stage: ProposalStage.interviewPassed,
            status: ApplicationStatus.accepted,
            assignWeek: 6,
          ),
        ]);

        await _pumpDetail(tester, state, employee.id, width);
        expect(find.text('参画予定'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Employee detail, Assignment Started ("参画中")', () {
    for (final width in _widths) {
      testWidgets('no overflow at ${width}px', (tester) async {
        var state = GameEngine.newGame(seed: 1);
        final employee = state.engineers.first;
        final project = state.openProjects.first.project;
        state = state.copyWith(activeAssignments: [
          ActiveAssignment(engineerId: employee.id, project: project, remainingWeeks: 10, assignedWeek: 1),
        ]);

        await _pumpDetail(tester, state, employee.id, width);
        expect(find.text('参画中'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
