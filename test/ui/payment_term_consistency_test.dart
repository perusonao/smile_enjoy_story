// Payment-term display consistency (Playable 0.4C.3 §22-26, §59, §64).
//
// Root cause of the original bug report: `Project.paymentTermDays` is never
// populated by ProjectGenerator, so it silently sits at the class default
// of 30 — the interview-request card read that dead field directly while
// every other screen (Selection, final Offer) correctly looked up the real
// value via `paymentTermDaysById(clientId)`. This test pins a client with a
// genuine 60-day term and checks the interview-request card shows it
// correctly instead of the stale "30日" — a regression guard for that exact
// bug, not just a description of it.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_detail_screen.dart';
import 'package:smile_enjoy_story/ui/widgets/labels.dart';

import '../game/test_helpers.dart';

void main() {
  test('paymentTermDaysById is the canonical source, and at least one sample client uses 60 days', () {
    final sixtyDayClient = sampleClients.firstWhere((c) => c.paymentTermDays == 60);
    expect(paymentTermDaysById(sixtyDayClient.id), 60);
  });

  testWidgets('the interview-request card shows the client\'s real payment term, not the dead Project field', (tester) async {
    var state = GameEngine.newGame(seed: 4);
    final employee = state.engineers.first;
    final sixtyDayClient = sampleClients.firstWhere((c) => c.paymentTermDays == 60);

    // A project whose `paymentTermDays` field is left at its class default
    // (30) — exactly what ProjectGenerator always produces — but whose
    // *client* genuinely charges 60-day terms.
    final project = buildProject(
      id: state.openProjects.first.project.id,
      clientId: sixtyDayClient.id,
      title: state.openProjects.first.project.title,
    );
    expect(project.paymentTermDays, 30, reason: 'sanity: the dead field really is still 30');
    expect(paymentTermDaysById(project.clientId), 60, reason: 'sanity: the canonical client term really is 60');

    final (afterMint, offerId) = state.mintId('interview-offer');
    state = afterMint.copyWith(
      openProjects: [
        ProjectEntry(project: project, postedWeek: 1),
        ...state.openProjects.skip(1),
      ],
      interviewOffers: [
        InterviewOffer(
          id: offerId,
          employeeId: employee.id,
          projectId: project.id,
          clientId: project.clientId,
          generatedWeek: 1,
          expiresWeek: 10,
          skillSheetMatch: 75,
        ),
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
    await tester.dragUntilVisible(
      find.textContaining('面談依頼！'),
      find.byType(ListView),
      const Offset(0, -300),
    );

    expect(find.textContaining('面談依頼！'), findsOneWidget);
    expect(find.textContaining('支払 60日'), findsOneWidget);
    expect(find.textContaining('支払 30日'), findsNothing);
  });
}
