// Playable 0.5A §79-80: mobile-width smoke tests for the Founding Prologue
// UI. Early stages are driven by real taps (§80's golden path); later
// stages are reached by seeding a GameState built with
// PrologueEngine/GameEngine directly into the mocked save (the same
// technique test/ui/guided_flow_consistency_test.dart already uses) so each
// screen can be checked at 360/390px without re-simulating the whole
// interview flow through the widget tree.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/main.dart';
import 'package:smile_enjoy_story/ui/main_shell.dart';

/// Mirrors PrologueEngineTest's driver — advances a fresh Beginner Mode game
/// to the requested [PrologueStage], picking Candidate A throughout.
GameState _stateAt(PrologueStage target, {int seed = 5}) {
  var state = PrologueEngine.newGame(seed: seed);
  state = PrologueEngine.confirmCompanySetup(state, presidentName: 'テスト社長', companyName: 'テスト会社');
  state = PrologueEngine.markIntroSeen(state);
  if (target == PrologueStage.week1Recruitment) return state;
  state = PrologueEngine.postFreeRecruitment(state);
  state = PrologueEngine.advanceWeek(state);
  if (target == PrologueStage.week2CandidateSelect) return state;

  final id = state.applicants.first.applicant.id;
  state = PrologueEngine.selectCandidateForInterview(state, id);
  state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.technical);
  state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.teamwork);
  state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.workStyle);
  state = GameEngine.answerRecruitmentReverseQuestion(state, id, 0);
  state = GameEngine.completeRecruitmentInterview(state, id, InterviewOutcome.hired);
  state = PrologueEngine.decideCandidate(state, id, hire: true);
  if (state.engineers.isEmpty) {
    // Rare decline — retry once with a different seed for a deterministic test fixture.
    return _stateAt(target, seed: seed + 1);
  }
  if (target == PrologueStage.week3SkillSheet) return state;

  state = PrologueEngine.confirmSkillSheet(state);
  if (target == PrologueStage.week3Sales) return state;
  state = PrologueEngine.startPreJoiningSales(state);

  var advances = 0;
  // Deliberately keyed only on activeAssignments/advances, not "stage !=
  // target" — the target stage's own case body (below) is what returns
  // early once reached, so a target whose case has side effects before the
  // check (week4Contract calling finalizeContractIfReady) always runs.
  while (state.activeAssignments.isEmpty && advances < 40) {
    final stage = PrologueEngine.stage(state);
    switch (stage) {
      case PrologueStage.week4AwaitingRequest:
        state = PrologueEngine.advanceWeek(state);
        advances++;
      case PrologueStage.week4InterviewRequest:
        if (target == PrologueStage.week4InterviewRequest) return state;
        state = PrologueEngine.acceptPrologueInterviewRequest(state);
      case PrologueStage.week4UpperInterview:
      case PrologueStage.week4ClientInterview:
        final engineerId = state.engineers.first.id;
        final proposal = state.proposals.where((p) => p.engineerId == engineerId && p.status == ApplicationStatus.active).firstOrNull;
        if (proposal == null) break;
        if (stage == PrologueStage.week4UpperInterview) {
          state = GameEngine.startClientInterview(state, proposal.id, step: SelectionStep.upperCompanyInterview, questionCount: 1);
          var session = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.upperCompanyInterview && !s.completed).toList();
          while (session.isNotEmpty) {
            state = GameEngine.chooseClientInterviewFollowUp(state, session.last.id, ClientInterviewFollowUp.letEmployeeHandle);
            session = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.upperCompanyInterview && !s.completed).toList();
          }
        } else {
          state = GameEngine.autoResolveClientInterview(state, proposal.id);
        }
      case PrologueStage.week4Contract:
        state = PrologueEngine.finalizeContractIfReady(state);
        if (target == PrologueStage.week4Contract) return state;
        if (state.proposals.any((p) => p.engineerId == state.engineers.first.id && p.status == ApplicationStatus.accepted)) {
          state = PrologueEngine.advanceWeek(state);
          advances++;
        }
      default:
        advances++;
    }
  }
  return state;
}

Future<void> _pumpSeeded(WidgetTester tester, GameState state, double width) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
  await tester.pumpWidget(SesApp(controller: GameController()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('start picker offers Beginner Mode and Free Mode (§3)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    expect(find.text('【初心者モード】おすすめ'), findsOneWidget);
    expect(find.text('【自由モード】'), findsOneWidget);
  });

  testWidgets('Beginner Mode golden path: start → president name → intro → Week 1 recruitment (§4-16)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('【初心者モード】おすすめ'));
    await tester.pumpAndSettle();

    // Company Setup (Playable 0.5A.1 §1): president name + company name.
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, 'テスト社長');
    await tester.enterText(find.byType(TextField).last, 'テスト会社');
    await tester.tap(find.text('会社を設立する'));
    await tester.pumpAndSettle();

    // Intro is a short sequence of navigator cards ending in "次へ進む".
    for (var i = 0; i < 6; i++) {
      final next = find.text('次へ');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('次へ進む'));
    await tester.pumpAndSettle();

    // Week 1 recruitment (Playable 0.5A.1 §3): player picks a medium — no
    // auto-select, three real options.
    expect(find.text('無料求人'), findsOneWidget);
    expect(find.text('有料求人サイト'), findsOneWidget);
    expect(find.text('人材紹介'), findsOneWidget);
    await tester.tap(find.text('この方法で募集する').first);
    await tester.pumpAndSettle();
    expect(find.text('次の週へ'), findsOneWidget);
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('Prologue screens do not overflow at ${width.toInt()}px', (tester) async {
      for (final stage in [
        PrologueStage.week1Recruitment,
        PrologueStage.week2CandidateSelect,
        PrologueStage.week3SkillSheet,
        PrologueStage.week3Sales,
        PrologueStage.week4InterviewRequest,
        PrologueStage.week4Contract,
      ]) {
        final state = _stateAt(stage);
        expect(PrologueEngine.stage(state), stage, reason: 'fixture for $stage');
        await _pumpSeeded(tester, state, width);
        expect(tester.takeException(), isNull, reason: 'stage=$stage width=$width');
      }
    });
  }

  testWidgets('Prologue Complete → 経営を始める hands off to MainShell (§63-64)', (tester) async {
    var state = _stateAt(PrologueStage.week4Contract);
    var advances = 0;
    while (state.activeAssignments.isEmpty && advances < 5) {
      state = PrologueEngine.advanceWeek(state);
      advances++;
    }
    expect(state.activeAssignments, isNotEmpty);
    await _pumpSeeded(tester, state, 390);

    expect(find.text('経営を始める'), findsOneWidget);
    await tester.tap(find.text('経営を始める'));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets('P0 regression: after a same-week reject, Home still offers a real action (次の週へ)', (tester) async {
    // Reproduces the exact combination that caused the reported dead end:
    // week2CandidateSelect stays the stage, but the remaining candidate's
    // 面接する is blocked by the one-interview-per-week rule.
    var state = PrologueEngine.newGame(seed: 7);
    state = PrologueEngine.confirmCompanySetup(state, presidentName: 'テスト社長', companyName: 'テスト会社');
    state = PrologueEngine.markIntroSeen(state);
    state = PrologueEngine.postFreeRecruitment(state);
    state = PrologueEngine.advanceWeek(state);
    final firstId = state.applicants.first.applicant.id;
    state = PrologueEngine.selectCandidateForInterview(state, firstId);
    state = GameEngine.askRecruitmentQuestion(state, firstId, InterviewQuestionCategory.technical);
    state = GameEngine.askRecruitmentQuestion(state, firstId, InterviewQuestionCategory.teamwork);
    state = GameEngine.askRecruitmentQuestion(state, firstId, InterviewQuestionCategory.workStyle);
    state = GameEngine.answerRecruitmentReverseQuestion(state, firstId, 0);
    state = GameEngine.completeRecruitmentInterview(state, firstId, InterviewOutcome.rejected);
    state = PrologueEngine.decideCandidate(state, firstId, hire: false);
    expect(PrologueEngine.stage(state), PrologueStage.week2CandidateSelect);
    expect(PrologueEngine.canInterviewThisWeek(state), isFalse);

    await _pumpSeeded(tester, state, 390);

    // The fallback action is on screen and enabled.
    final nextWeekButton = find.widgetWithText(OutlinedButton, '次の週へ');
    expect(nextWeekButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(nextWeekButton).onPressed, isNotNull);

    // The blocked candidate's 面接する is visibly disabled, not a silent no-op.
    final interviewButton = find.widgetWithText(FilledButton, '面接する');
    expect(interviewButton, findsOneWidget);
    expect(tester.widget<FilledButton>(interviewButton).onPressed, isNull);

    // Tapping the fallback actually progresses the game.
    await tester.tap(nextWeekButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Candidate SkillSheet modal shows required fields and leads into the interview (§4)', (tester) async {
    final state = _stateAt(PrologueStage.week2CandidateSelect);
    await _pumpSeeded(tester, state, 390);

    await tester.tap(find.widgetWithText(OutlinedButton, 'スキルシートを見る').first);
    await tester.pumpAndSettle();

    expect(find.text('年齢'), findsOneWidget);
    expect(find.text('希望年収'), findsOneWidget);
    expect(find.text('経験年数'), findsOneWidget);
    expect(find.text('言語'), findsOneWidget);
    expect(find.text('DB / Infrastructure 等'), findsOneWidget);
    expect(find.text('業界経験'), findsOneWidget);
    expect(find.text('役割経験'), findsOneWidget);
    expect(find.text('この人と面談する'), findsOneWidget);

    await tester.tap(find.text('この人と面談する'));
    await tester.pumpAndSettle();
    // Modal closed and navigated into the interview flow.
    expect(find.text('この人と面談する'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reset entry point is always visible and requires confirmation (§7)', (tester) async {
    final state = _stateAt(PrologueStage.week3Sales);
    await _pumpSeeded(tester, state, 390);

    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pumpAndSettle();

    expect(find.text('初心者モードを最初からやり直しますか？'), findsOneWidget);
    // Cancelling leaves the playthrough untouched.
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('営業を開始する'), findsOneWidget, reason: 'still on week3Sales after cancelling');

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('やり直す'));
    await tester.pumpAndSettle();

    // Back to a brand-new Company Setup screen.
    expect(find.text('会社を設立する'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
