// Playable 0.5A: Founding Prologue engine tests. Drives the whole scripted
// March → April sequence through PrologueEngine/GameEngine calls only (no
// widgets) to verify §82's required coverage: beginner initial state,
// president naming, deterministic navigator, navigator salary, calendar,
// week-by-week recruitment/interview/sales/selection, failure recovery,
// April joining + assignment, payment term, prologue completion, save/reload
// round-trip, and that Free Mode is untouched.

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

/// Drives one Prologue playthrough from a fresh Beginner Mode game all the
/// way to either April Week 1's assignment or a bounded number of retries,
/// picking [preferCandidateB] or the first candidate deterministically.
/// Returns the final [GameState].
GameState playThroughPrologue(int seed, {bool preferCandidateB = false, int maxAdvances = 40}) {
  var state = PrologueEngine.newGame(seed: seed);
  state = PrologueEngine.setPresidentName(state, 'テスト社長');
  state = PrologueEngine.markIntroSeen(state);
  state = PrologueEngine.postFreeRecruitment(state);
  state = PrologueEngine.advanceWeek(state); // -> March Week 2, candidates appear

  var advances = 0;
  while (state.activeAssignments.isEmpty && advances < maxAdvances) {
    final stage = PrologueEngine.stage(state);
    switch (stage) {
      case PrologueStage.presidentNaming:
      case PrologueStage.intro:
        throw StateError('unexpected stage $stage');
      case PrologueStage.week1Recruitment:
        state = PrologueEngine.postFreeRecruitment(state);
      case PrologueStage.week2AwaitingReply:
        state = PrologueEngine.advanceWeek(state);
        advances++;
      case PrologueStage.week2CandidateSelect:
        final candidates = state.applicants;
        final chosen = preferCandidateB && candidates.length > 1 ? candidates[1] : candidates.first;
        state = PrologueEngine.selectCandidateForInterview(state, chosen.applicant.id);
      case PrologueStage.week2Interview:
        final id = state.prologueState.interviewingCandidateId!;
        state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.technical);
        state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.teamwork);
        state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.workStyle);
        final session = state.recruitmentInterviews.where((s) => s.applicantId == id).last;
        if (session.questionsComplete && session.companyAnswer == null) {
          state = GameEngine.answerRecruitmentReverseQuestion(state, id, 0);
        }
      case PrologueStage.week2Decision:
        final id = state.prologueState.interviewingCandidateId!;
        state = GameEngine.completeRecruitmentInterview(state, id, InterviewOutcome.hired);
        state = PrologueEngine.decideCandidate(state, id, hire: true);
      case PrologueStage.week3SkillSheet:
        state = PrologueEngine.confirmSkillSheet(state);
      case PrologueStage.week3Sales:
        state = PrologueEngine.startPreJoiningSales(state);
      case PrologueStage.week4AwaitingRequest:
        state = PrologueEngine.advanceWeek(state);
        advances++;
      case PrologueStage.week4InterviewRequest:
        state = PrologueEngine.acceptPrologueInterviewRequest(state);
      case PrologueStage.week4UpperInterview:
      case PrologueStage.week4ClientInterview:
        final engineerId = state.engineers.first.id;
        final proposal = state.proposals.where((p) => p.engineerId == engineerId && p.status == ApplicationStatus.active).first;
        if (stage == PrologueStage.week4UpperInterview) {
          state = GameEngine.startClientInterview(state, proposal.id, step: SelectionStep.upperCompanyInterview, questionCount: 1);
          var session = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.upperCompanyInterview && !s.completed).lastOrNull;
          while (session != null) {
            state = GameEngine.chooseClientInterviewFollowUp(state, session.id, ClientInterviewFollowUp.letEmployeeHandle);
            session = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.upperCompanyInterview && !s.completed).lastOrNull;
          }
        } else {
          state = GameEngine.autoResolveClientInterview(state, proposal.id);
        }
      case PrologueStage.week4Contract:
        state = PrologueEngine.finalizeContractIfReady(state);
        if (state.proposals.any((p) => p.engineerId == state.engineers.first.id && p.status == ApplicationStatus.accepted)) {
          state = PrologueEngine.advanceWeek(state);
          advances++;
        }
      case PrologueStage.complete:
      case PrologueStage.freeManagement:
        return state;
    }
  }
  return state;
}

void main() {
  group('Beginner Mode initial state (§4-8)', () {
    test('starts with zero engineers and one general-affairs staff', () {
      final state = PrologueEngine.newGame(seed: 1);
      expect(state.engineers, isEmpty);
      expect(state.generalAffairsStaff, isNotNull);
      expect(state.gameMode, GameMode.beginner);
      expect(state.prologueState.active, isTrue);
      expect(state.company.presidentName, isEmpty);
    });

    test('deterministic navigator: same seed produces the same name', () {
      final a = PrologueEngine.newGame(seed: 42);
      final b = PrologueEngine.newGame(seed: 42);
      expect(a.generalAffairsStaff!.name, b.generalAffairsStaff!.name);
    });

    test('different seeds can produce different navigator names', () {
      final names = {for (var seed = 0; seed < 20; seed++) PrologueEngine.newGame(seed: seed).generalAffairsStaff!.name};
      expect(names.length, greaterThan(1));
    });

    test('navigator salary is included in monthly salary total', () {
      final state = PrologueEngine.newGame(seed: 1);
      expect(FinanceEngine.monthlySalaryTotal(state), state.generalAffairsStaff!.salary);
    });
  });

  group('President naming (§5)', () {
    test('empty name is rejected', () {
      final state = PrologueEngine.newGame(seed: 1);
      final next = PrologueEngine.setPresidentName(state, '   ');
      expect(next.company.presidentName, isEmpty);
    });

    test('name is trimmed and capped to the mobile-friendly length', () {
      final state = PrologueEngine.newGame(seed: 1);
      final next = PrologueEngine.setPresidentName(state, '  ${'あ' * 40}  ');
      expect(next.company.presidentName.length, PrologueEngine.presidentNameMaxLength);
    });
  });

  test('March calendar: prologueWeek advances 1→4 without touching company.currentWeek (§11, §83)', () {
    var state = PrologueEngine.newGame(seed: 1);
    expect(state.prologueState.prologueWeek, 1);
    expect(state.week, 1);
    state = PrologueEngine.advanceWeek(state);
    expect(state.prologueState.prologueWeek, 2);
    expect(state.week, 1); // never moves during March
  });

  test('March Week 1: free recruitment posts a zero-cost listing (§12-16)', () {
    var state = PrologueEngine.newGame(seed: 1);
    final before = state.company.cash;
    state = PrologueEngine.postFreeRecruitment(state);
    expect(state.listings, hasLength(1));
    expect(state.listings.first.type, RecruitmentMediaType.freeWork);
    expect(state.company.cash, before);
  });

  test('March Week 2: exactly two candidates appear, one interview per week (§17-21)', () {
    var state = PrologueEngine.newGame(seed: 7);
    state = PrologueEngine.postFreeRecruitment(state);
    state = PrologueEngine.advanceWeek(state);
    expect(state.applicants, hasLength(2));
    expect(state.prologueState.candidateAId, isNotNull);
    expect(state.prologueState.candidateBId, isNotNull);

    final firstId = state.applicants.first.applicant.id;
    state = PrologueEngine.selectCandidateForInterview(state, firstId);
    expect(state.prologueState.interviewingCandidateId, firstId);

    // Can't start a second interview the same week.
    final secondId = state.applicants.last.applicant.id;
    final blocked = PrologueEngine.selectCandidateForInterview(state, secondId);
    expect(blocked.prologueState.interviewingCandidateId, firstId);
  });

  test('recruitment interview → hire produces a real Engineer, not a PendingHire (§27-31)', () {
    var state = playThroughToHireDecision(seed: 3);
    expect(state.engineers, hasLength(1));
    expect(state.pendingHires, isEmpty);
    expect(state.engineers.first.status, EngineerStatus.waiting);
  });

  test('SkillSheet confirm + pre-joining sales starts sales for the pre-joining engineer (§32-37)', () {
    var state = playThroughToHireDecision(seed: 3);
    state = PrologueEngine.confirmSkillSheet(state);
    expect(state.prologueState.skillSheetConfirmed, isTrue);
    state = PrologueEngine.startPreJoiningSales(state);
    expect(state.engineers.first.salesStatus, SalesStatus.selling);
    expect(state.prologueState.targetProjectId, isNotNull);
  });

  test('March Week 4: interview request targets a standard-flow, well-fit project (§39-41)', () {
    var state = playThroughToHireDecision(seed: 3);
    state = PrologueEngine.confirmSkillSheet(state);
    state = PrologueEngine.startPreJoiningSales(state);
    state = PrologueEngine.ensureInterviewRequest(state);
    expect(state.interviewOffers, hasLength(1));
    final project = state.openProjects.firstWhere((e) => e.project.id == state.interviewOffers.first.projectId).project;
    expect(project.selectionFlow.type, SelectionFlowType.standard);
  });

  test('Upper Company Interview is a real, shortened Client-Interview-shaped session (§45-49)', () {
    var state = playThroughToHireDecision(seed: 3);
    state = PrologueEngine.confirmSkillSheet(state);
    state = PrologueEngine.startPreJoiningSales(state);
    state = PrologueEngine.ensureInterviewRequest(state);
    state = PrologueEngine.acceptPrologueInterviewRequest(state);
    final engineerId = state.engineers.first.id;
    final proposal = state.proposals.firstWhere((p) => p.engineerId == engineerId && p.status == ApplicationStatus.active);
    expect(proposal.currentStep, SelectionStep.upperCompanyInterview);
    state = GameEngine.startClientInterview(state, proposal.id, step: SelectionStep.upperCompanyInterview, questionCount: 1);
    final session = state.clientInterviews.single;
    expect(session.step, SelectionStep.upperCompanyInterview);
    expect(session.questions, hasLength(1));
  });

  test('Client Interview auto-resolves without the player (§50-52)', () {
    var state = playThroughToUpperInterviewPassed(seed: 5);
    final engineerId = state.engineers.first.id;
    final proposal = state.proposals.firstWhere((p) => p.engineerId == engineerId && p.status == ApplicationStatus.active);
    expect(proposal.currentStep, SelectionStep.clientInterview);
    state = GameEngine.autoResolveClientInterview(state, proposal.id);
    final session = state.clientInterviews.where((s) => s.step == SelectionStep.clientInterview).single;
    expect(session.completed, isTrue);
    expect(session.result, isNotNull);
  });

  test('failure recovery: a rejected selection step generates a fresh interview request, never a dead end (§54-56, §71)', () {
    var state = playThroughToHireDecision(seed: 3);
    state = PrologueEngine.confirmSkillSheet(state);
    state = PrologueEngine.startPreJoiningSales(state);
    state = PrologueEngine.ensureInterviewRequest(state);
    state = PrologueEngine.acceptPrologueInterviewRequest(state);
    final engineerId = state.engineers.first.id;
    var proposal = state.proposals.firstWhere((p) => p.engineerId == engineerId && p.status == ApplicationStatus.active);
    // Force a rejection directly (independent of the real roll) to exercise
    // the rescue path deterministically.
    state = state.copyWith(proposals: [
      for (final p in state.proposals) if (p.id == proposal.id) p.copyWith(status: ApplicationStatus.rejected, stage: ProposalStage.interviewFailed) else p,
    ], engineers: [
      for (final e in state.engineers) if (e.id == engineerId) e.copyWith(salesStatus: SalesStatus.selling) else e,
    ]);
    state = PrologueEngine.advanceWeek(state);
    expect(state.prologueState.failedAttempts, 1);
    expect(state.interviewOffers.where((o) => o.employeeId == engineerId && o.status == InterviewOfferStatus.pending), isNotEmpty);
  });

  test('contract success surfaces monthly rate, duration, and payment term (§56-57)', () {
    final state = playThroughPrologue(11);
    expect(state.activeAssignments, isNotEmpty, reason: 'seed 11 should reach an assignment within the retry budget');
    final assignment = state.activeAssignments.first;
    expect(assignment.assignedWeek, 1);
    final client = FinanceEngine.clientById(assignment.project.clientId);
    expect(client.paymentTermDays, anyOf(30, 60));
  });

  test('April Week 1: joining is simultaneous with assignment start (§59-62)', () {
    final state = playThroughPrologue(11);
    expect(state.activeAssignments, isNotEmpty);
    final engineer = state.engineers.first;
    expect(engineer.status, EngineerStatus.assigned);
    expect(state.company.currentWeek, 1);
    expect(state.week, 1);
  });

  test('Prologue Complete hands off to free management (§63-64)', () {
    var state = playThroughPrologue(11);
    expect(PrologueEngine.stage(state), PrologueStage.complete);
    state = PrologueEngine.completePrologue(state);
    expect(state.prologueState.active, isFalse);
    expect(state.prologueState.completed, isTrue);
    expect(ProgressionEngine.currentStage(state), FoundingStage.freeManagement);
    expect(ProgressionEngine.canUseRecruitment(state), isTrue);
    expect(ProgressionEngine.canUseWelfare(state), isTrue);
  });

  test('Free Mode is unaffected: GameEngine.newGame still starts two founders, gameMode free (§73, §85)', () {
    final state = GameEngine.newGame(seed: 1);
    expect(state.engineers, hasLength(2));
    expect(state.gameMode, GameMode.free);
    expect(state.prologueState.active, isFalse);
    expect(state.generalAffairsStaff, isNull);
  });

  test('save/reload round-trip preserves Beginner Mode fields (§69-70)', () {
    var state = playThroughToHireDecision(seed: 3);
    state = PrologueEngine.confirmSkillSheet(state);
    final json = state.toJson();
    final reloaded = GameState.fromJson(json);
    expect(reloaded.gameMode, GameMode.beginner);
    expect(reloaded.generalAffairsStaff!.name, state.generalAffairsStaff!.name);
    expect(reloaded.prologueState.skillSheetConfirmed, isTrue);
    expect(reloaded.company.presidentName, state.company.presidentName);
    expect(PrologueEngine.stage(reloaded), PrologueEngine.stage(state));
  });

  test('reconcile never regresses a Beginner Mode game backward', () {
    var state = playThroughPrologue(11);
    final reconciled = ProgressionEngine.reconcile(state);
    expect(reconciled.foundingProgress.has(FoundingMilestone.firstAssignment), isTrue);
  });
}

/// Drives a playthrough to the moment the Week 2 hire decision has just been
/// made — reused by several tests below that only care about post-hire
/// behavior.
GameState playThroughToHireDecision({required int seed}) {
  var state = PrologueEngine.newGame(seed: seed);
  state = PrologueEngine.setPresidentName(state, 'テスト社長');
  state = PrologueEngine.markIntroSeen(state);
  state = PrologueEngine.postFreeRecruitment(state);
  state = PrologueEngine.advanceWeek(state);
  final id = state.applicants.first.applicant.id;
  state = PrologueEngine.selectCandidateForInterview(state, id);
  state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.technical);
  state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.teamwork);
  state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.workStyle);
  state = GameEngine.answerRecruitmentReverseQuestion(state, id, 0);
  state = GameEngine.completeRecruitmentInterview(state, id, InterviewOutcome.hired);
  state = PrologueEngine.decideCandidate(state, id, hire: true);
  if (state.engineers.isEmpty) {
    // Rare decline (§27 allows up to 15%) — retry with the rescue candidate
    // so downstream tests always have a hired engineer to work with.
    state = PrologueEngine.advanceWeek(state);
    final rescueId = state.applicants.first.applicant.id;
    state = PrologueEngine.selectCandidateForInterview(state, rescueId);
    state = GameEngine.askRecruitmentQuestion(state, rescueId, InterviewQuestionCategory.technical);
    state = GameEngine.askRecruitmentQuestion(state, rescueId, InterviewQuestionCategory.teamwork);
    state = GameEngine.askRecruitmentQuestion(state, rescueId, InterviewQuestionCategory.workStyle);
    state = GameEngine.answerRecruitmentReverseQuestion(state, rescueId, 0);
    state = GameEngine.completeRecruitmentInterview(state, rescueId, InterviewOutcome.hired);
    state = PrologueEngine.decideCandidate(state, rescueId, hire: true);
  }
  return state;
}

GameState playThroughToUpperInterviewPassed({required int seed}) {
  var state = playThroughToHireDecision(seed: seed);
  state = PrologueEngine.confirmSkillSheet(state);
  state = PrologueEngine.startPreJoiningSales(state);
  var guard = 0;
  while (state.activeAssignments.isEmpty && guard < 20) {
    guard++;
    state = PrologueEngine.ensureInterviewRequest(state);
    if (state.interviewOffers.where((o) => o.employeeId == state.engineers.first.id && o.status == InterviewOfferStatus.pending).isEmpty) {
      state = PrologueEngine.advanceWeek(state);
      continue;
    }
    state = PrologueEngine.acceptPrologueInterviewRequest(state);
    final engineerId = state.engineers.first.id;
    final proposal = state.proposals.where((p) => p.engineerId == engineerId && p.status == ApplicationStatus.active).firstOrNull;
    if (proposal == null || proposal.currentStep != SelectionStep.upperCompanyInterview) continue;
    state = GameEngine.startClientInterview(state, proposal.id, step: SelectionStep.upperCompanyInterview, questionCount: 1);
    var session = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.upperCompanyInterview && !s.completed).lastOrNull;
    while (session != null) {
      state = GameEngine.chooseClientInterviewFollowUp(state, session.id, ClientInterviewFollowUp.letEmployeeHandle);
      session = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.upperCompanyInterview && !s.completed).lastOrNull;
    }
    final updatedProposal = state.proposals.firstWhere((p) => p.id == proposal.id);
    if (updatedProposal.currentStep == SelectionStep.clientInterview) return state;
    state = PrologueEngine.advanceWeek(state);
  }
  return state;
}
