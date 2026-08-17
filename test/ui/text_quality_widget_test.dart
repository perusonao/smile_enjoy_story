// Phase 3A UX review (P1-3): the interview/judgment screens' "not found"
// branch is only ever reached transiently — after a hire/reject decision
// (or an interview result) removes the applicant/proposal the route was
// still showing, a result dialog sits on top of this same route until the
// player dismisses it and navigates back. It previously rendered an
// alarming "見つかりません" error message underneath that dialog; it now
// renders a blank Scaffold instead (not a spinner either — nothing is
// actually loading here, so an indefinitely-animating indicator would be
// just as misleading, and would never let a `pumpAndSettle()`-based test
// settle — see interview_navigation_test.dart, which exercises this exact
// window).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_detail_screen.dart';
import 'package:smile_enjoy_story/ui/prologue/prologue_interview_screen.dart';
import 'package:smile_enjoy_story/ui/projects/client_interview_screen.dart';
import 'package:smile_enjoy_story/ui/recruitment/recruitment_interview_screen.dart';

Future<void> _pump(WidgetTester tester, GameState state, Widget child) async {
  SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
  final controller = GameController();
  await tester.pumpWidget(GameScope(controller: controller, child: MaterialApp(home: child)));
  await tester.pumpAndSettle();
}

void main() {
  group('transient "not found" states render blank, never the old alarming error text (P1-3)', () {
    testWidgets('PrologueInterviewScreen for an applicantId that is not present', (tester) async {
      final state = GameEngine.newGame(seed: 1);
      await _pump(tester, state, const PrologueInterviewScreen(applicantId: 'gone'));
      expect(find.text('応募者が見つかりません'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RecruitmentInterviewScreen for an applicantId that is not present', (tester) async {
      final state = GameEngine.newGame(seed: 1);
      await _pump(tester, state, const RecruitmentInterviewScreen(applicantId: 'gone'));
      expect(find.text('応募者が見つかりません'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ClientInterviewScreen for an applicationId that is not present', (tester) async {
      final state = GameEngine.newGame(seed: 1);
      await _pump(tester, state, const ClientInterviewScreen(applicationId: 'gone'));
      expect(find.text('案件が見つかりません'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('EngineerDetailScreen unchanged: a genuinely unreachable id is a real dead route, not transient', () {
    testWidgets('shows its own not-found text, no crash', (tester) async {
      final state = GameEngine.newGame(seed: 1);
      await _pump(tester, state, const EngineerDetailScreen(engineerId: 'gone'));
      expect(find.text('社員が見つかりません。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
