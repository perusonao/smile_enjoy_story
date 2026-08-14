// Playable 0.5A §74-78: headless Founding Prologue simulation.
//
// Drives PrologueEngine/GameEngine calls directly (no widgets) across many
// seeds, for both a "always pick Candidate A" and "always pick Candidate B"
// strategy, and reports the metrics §75 asks for. Kept out of lib/ so
// production code has no bulk print calls, matching tool/generation_report.dart.
//
// Reports two distinct kinds of rate on purpose (§53, §76 explicitly forbid
// a scripted 100% pass): *per-attempt* pass rates (a single Upper Company /
// Client Interview roll, which is never rigged) and *eventual* rates (did
// this playthrough ever reach that milestone within the rescue-retry budget,
// §54-56 — expected to trend near 100% precisely because the rescue path
// keeps retrying with a fresh, well-fit project until it does).
//
// Run with: dart run tool/simulate_prologue.dart [gamesPerStrategy]
//
// ignore_for_file: avoid_print

import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

class _Outcome {
  bool acceptedOffer = false;
  bool week4RequestArrived = false;
  bool assignedByApril1 = false; // succeeded within March (prologueWeek <= 4)
  bool assignedByApril2 = false; // succeeded within one extra rescue week
  bool bankruptBeforeAssignment = false;
  int upperAttempts = 0;
  int upperPasses = 0;
  int clientAttempts = 0;
  int clientPasses = 0;
  int failedAttempts = 0;
  int? firstProjectRate;
  int? firstProjectFitTotal;
  int? paymentTermDays;
}

_Outcome _playOne(int seed, {required bool candidateB}) {
  final outcome = _Outcome();
  var state = PrologueEngine.newGame(seed: seed);
  state = PrologueEngine.setPresidentName(state, 'テスト社長');
  state = PrologueEngine.markIntroSeen(state);
  state = PrologueEngine.postFreeRecruitment(state);
  state = PrologueEngine.advanceWeek(state);

  var advances = 0;
  var guard = 0;
  var successProlgueWeek = -1;
  while (state.activeAssignments.isEmpty && advances < 40 && guard < 500) {
    guard++;
    if (state.company.cash < 0) {
      outcome.bankruptBeforeAssignment = true;
      break;
    }
    final stage = PrologueEngine.stage(state);
    switch (stage) {
      case PrologueStage.presidentNaming:
      case PrologueStage.intro:
        throw StateError('unexpected $stage');
      case PrologueStage.week1Recruitment:
        state = PrologueEngine.postFreeRecruitment(state);
      case PrologueStage.week2AwaitingReply:
        state = PrologueEngine.advanceWeek(state);
        advances++;
      case PrologueStage.week2CandidateSelect:
        final candidates = state.applicants;
        final chosen = (candidateB && candidates.length > 1) ? candidates[1] : candidates.first;
        state = PrologueEngine.selectCandidateForInterview(state, chosen.applicant.id);
      case PrologueStage.week2Interview:
        final id = state.prologueState.interviewingCandidateId!;
        state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.technical);
        state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.teamwork);
        state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.workStyle);
        state = GameEngine.answerRecruitmentReverseQuestion(state, id, 0);
      case PrologueStage.week2Decision:
        final id = state.prologueState.interviewingCandidateId!;
        state = GameEngine.completeRecruitmentInterview(state, id, InterviewOutcome.hired);
        final before = state.engineers.length;
        state = PrologueEngine.decideCandidate(state, id, hire: true);
        if (state.engineers.length > before) outcome.acceptedOffer = true;
      case PrologueStage.week3SkillSheet:
        state = PrologueEngine.confirmSkillSheet(state);
      case PrologueStage.week3Sales:
        state = PrologueEngine.startPreJoiningSales(state);
      case PrologueStage.week4AwaitingRequest:
        state = PrologueEngine.advanceWeek(state);
        advances++;
      case PrologueStage.week4InterviewRequest:
        outcome.week4RequestArrived = true;
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
          final resolved = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.upperCompanyInterview).toList();
          if (resolved.isNotEmpty) {
            outcome.upperAttempts++;
            if (resolved.last.result == ClientInterviewResult.passed) outcome.upperPasses++;
          }
        } else {
          state = GameEngine.autoResolveClientInterview(state, proposal.id);
          final resolved = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.clientInterview).toList();
          if (resolved.isNotEmpty) {
            outcome.clientAttempts++;
            if (resolved.last.result == ClientInterviewResult.passed) outcome.clientPasses++;
          }
        }
      case PrologueStage.week4Contract:
        state = PrologueEngine.finalizeContractIfReady(state);
        if (state.proposals.any((p) => p.engineerId == state.engineers.first.id && p.status == ApplicationStatus.accepted)) {
          state = PrologueEngine.advanceWeek(state);
          advances++;
        }
      case PrologueStage.complete:
      case PrologueStage.freeManagement:
        break;
    }
    if (state.activeAssignments.isNotEmpty) {
      successProlgueWeek = state.prologueState.prologueWeek;
      break;
    }
  }

  outcome.failedAttempts = state.prologueState.failedAttempts;
  if (state.activeAssignments.isNotEmpty) {
    outcome.assignedByApril1 = successProlgueWeek <= 4;
    outcome.assignedByApril2 = successProlgueWeek <= 8;
    final assignment = state.activeAssignments.first;
    outcome.firstProjectRate = assignment.project.monthlyRate;
    final engineer = state.engineers.first;
    outcome.firstProjectFitTotal = MatchingEngine.computeFit(engineer, assignment.project).total;
    outcome.paymentTermDays = FinanceEngine.clientById(assignment.project.clientId).paymentTermDays;
  }
  return outcome;
}

void main(List<String> args) {
  final gamesPerStrategy = args.isNotEmpty ? int.parse(args.first) : 500;

  for (final candidateB in [false, true]) {
    var accepted = 0, week4Request = 0, assignedApril1 = 0, assignedApril2 = 0, bankrupt = 0;
    var upperAttempts = 0, upperPasses = 0, clientAttempts = 0, clientPasses = 0, totalFailedAttempts = 0;
    var rateSum = 0, fitSum = 0, rateCount = 0;
    final paymentTerms = <int, int>{};

    for (var i = 0; i < gamesPerStrategy; i++) {
      final seed = 1000000 + i * 7919 + (candidateB ? 500000 : 0);
      final o = _playOne(seed, candidateB: candidateB);
      if (o.acceptedOffer) accepted++;
      if (o.week4RequestArrived) week4Request++;
      if (o.assignedByApril1) assignedApril1++;
      if (o.assignedByApril2) assignedApril2++;
      if (o.bankruptBeforeAssignment) bankrupt++;
      upperAttempts += o.upperAttempts;
      upperPasses += o.upperPasses;
      clientAttempts += o.clientAttempts;
      clientPasses += o.clientPasses;
      totalFailedAttempts += o.failedAttempts;
      if (o.firstProjectRate != null) {
        rateSum += o.firstProjectRate!;
        fitSum += o.firstProjectFitTotal!;
        rateCount++;
        paymentTerms[o.paymentTermDays!] = (paymentTerms[o.paymentTermDays!] ?? 0) + 1;
      }
    }

    final label = candidateB ? 'Candidate B' : 'Candidate A';
    print('=== $label ($gamesPerStrategy games) ===');
    print('内定承諾率 (§27, target 85-95%): ${_pct(accepted, gamesPerStrategy)}');
    print('3月4週までの面談依頼到達率: ${_pct(week4Request, gamesPerStrategy)}');
    print('上位会社面談 通過率(1回あたり, §48): ${_pct(upperPasses, upperAttempts)}  (attempts=$upperAttempts)');
    print('客先面談 通過率(1回あたり, §53): ${_pct(clientPasses, clientAttempts)}  (attempts=$clientAttempts)');
    print('4月1週までの初参画率 (§76 target 80-90%+): ${_pct(assignedApril1, gamesPerStrategy)}');
    print('4月2週までの初参画率 (§76 target 95%+): ${_pct(assignedApril2, gamesPerStrategy)}');
    print('初参画前倒産率 (§76 target ~0%): ${_pct(bankrupt, gamesPerStrategy)}');
    print('平均リトライ回数(failedAttempts): ${(totalFailedAttempts / gamesPerStrategy).toStringAsFixed(2)}');
    if (rateCount > 0) {
      print('初案件平均単価: ¥${rateSum ~/ rateCount}');
      print('初案件平均Fit: ${fitSum ~/ rateCount}/100');
      print('支払サイト内訳: ${paymentTerms.entries.map((e) => '${e.key}日:${e.value}').join(', ')}');
    }
    print('');
  }
}

String _pct(int count, int total) => total == 0 ? 'n/a' : '${(count / total * 100).toStringAsFixed(1)}%';
