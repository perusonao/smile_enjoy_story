// Playable 0.5A §74-78 / 0.5A.1 (post-report follow-up): headless Founding
// Prologue simulation, now driven to completion under the same rules the
// real UI enforces end-to-end (game over or first assignment), not just
// through the first recruitment decision.
//
// Drives PrologueEngine/GameEngine calls directly (no widgets) across many
// seeds, for both a "always pick Candidate A" and "always pick Candidate B"
// strategy, and reports the metrics §75 / the 0.5A.1 follow-up review ask
// for. Kept out of lib/ so production code has no bulk print calls, matching
// tool/generation_report.dart.
//
// Reports two distinct kinds of rate on purpose (§53, §76 explicitly forbid
// a scripted 100% pass): *per-attempt* pass rates (a single Upper Company /
// Client Interview roll, which is never rigged) and *eventual* rates (did
// this playthrough ever reach that milestone within the rescue-retry budget,
// §54-56 — expected to trend near 100% precisely because the rescue path
// keeps retrying with a fresh, well-fit project until it does).
//
// Bug fixed here (tool-only, see the 0.5A.1 follow-up report): the previous
// driver always called PrologueEngine.selectCandidateForInterview on
// PrologueStage.week2CandidateSelect, even when
// PrologueEngine.canInterviewThisWeek(state) was already false (the
// one-interview-per-week slot already used this prologueWeek — e.g. right
// after a decline). That call is a no-op in that state, so `state` never
// changed and the loop spun until the iteration guard cut it off *without
// ever advancing the week* — the simulated game silently gave up on the very
// first decline, which is exactly why 内定承諾率 and 4月2週初参画率 were
// reporting identical numbers. The fix mirrors what PrologueScreen's own
// "次の週へ" fallback (the 0.5A.1 P0 fix) actually does in that situation:
// call PrologueEngine.advanceWeek instead.
//
// Run with: dart run tool/simulate_prologue.dart [gamesPerStrategy]
//
// ignore_for_file: avoid_print

import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

class _Outcome {
  /// The very first recruitment-interview decision this playthrough made
  /// was hire:true and the candidate's RNG-driven acceptance roll passed
  /// (§27). `null` if the playthrough never reached a decision at all
  /// (should not happen under normal rules, but guarded).
  bool? firstAttemptAccepted;

  /// The very first decision resulted in a decline (RNG rejected the
  /// offer, i.e. 内定辞退) — mutually exclusive with [firstAttemptAccepted]
  /// being true.
  bool firstAttemptDeclined = false;

  /// This playthrough explicitly chose 不採用 (decideCandidate(hire:
  /// false)) at least once — only ever true in the dedicated
  /// explicit-reject cohort ([_playOne]'s `forceRejectFirst`).
  bool explicitRejectUsed = false;

  /// An engineer was hired at all before the playthrough ended (by
  /// assignment, bankruptcy, or the safety cap) — the "re-recruitment
  /// after decline/reject" outcome the follow-up report asks to verify.
  bool hiredEventually = false;

  bool bankruptBeforeAssignment = false;
  bool exhaustedSafetyCap = false;

  int upperAttempts = 0;
  int upperPasses = 0;
  int clientAttempts = 0;
  int clientPasses = 0;

  /// Project-interview level Failure Recovery (§54-56): how many times a
  /// failed Upper/Client Interview forced a fresh interview request this
  /// playthrough. `> 0` is the "Failure Recovery used" condition for the
  /// project-interview side of the flow.
  int failedAttempts = 0;

  /// The PrologueState.prologueWeek at which assignment happened, if any —
  /// used for the "初参画までの平均週" and April-week-N cutoffs.
  int? assignedAtPrologueWeek;

  int? firstProjectRate;
  int? firstProjectFitTotal;
  int? paymentTermDays;
}

/// Plays one Founding Prologue from scratch to either a first assignment, a
/// pre-assignment bankruptcy, or the safety cap — always continuing under
/// the same rules PrologueScreen itself offers (including the "次の週へ"
/// fallback the 0.5A.1 P0 fix added), never stopping early just because a
/// decline/reject happened.
///
/// [forceRejectFirst]: if true, the very first recruitment-interview
/// decision this playthrough reaches is an explicit 不採用
/// (decideCandidate(hire: false)) instead of the usual hire attempt — this
/// is how the dedicated "不採用後の再採用成功率" cohort below exercises
/// that route at scale without corrupting the natural-play acceptance-rate
/// numbers in the main cohort (which always attempts hire on sight, same as
/// the tool's original behavior).
_Outcome _playOne(int seed, {required bool candidateB, bool forceRejectFirst = false}) {
  final outcome = _Outcome();
  var state = PrologueEngine.newGame(seed: seed);
  state = PrologueEngine.confirmCompanySetup(state, presidentName: 'テスト社長', companyName: 'テスト会社');
  state = PrologueEngine.markIntroSeen(state);
  state = PrologueEngine.postFreeRecruitment(state);
  state = PrologueEngine.advanceWeek(state);

  var advances = 0;
  var guard = 0;
  var decisionsMade = 0;
  const maxAdvances = 60; // generous: real weekly progression, not a retry count
  const maxGuard = 2000;

  while (state.activeAssignments.isEmpty && advances < maxAdvances && guard < maxGuard) {
    guard++;
    if (state.company.cash < 0) {
      outcome.bankruptBeforeAssignment = true;
      break;
    }
    final beforeState = state;
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
        if (!PrologueEngine.canInterviewThisWeek(state)) {
          // Mirrors PrologueScreen's own "次の週へ" fallback (0.5A.1 P0
          // fix): the weekly interview slot is already used (e.g. right
          // after a decline/reject this same prologueWeek) —
          // selectCandidateForInterview would silently no-op here, so the
          // real next action is advancing the week, exactly like the UI.
          state = PrologueEngine.advanceWeek(state);
          advances++;
        } else {
          final candidates = state.applicants;
          final chosen = (candidateB && candidates.length > 1) ? candidates[1] : candidates.first;
          state = PrologueEngine.selectCandidateForInterview(state, chosen.applicant.id);
        }
      case PrologueStage.week2Interview:
        final id = state.prologueState.interviewingCandidateId!;
        state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.technical);
        state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.teamwork);
        state = GameEngine.askRecruitmentQuestion(state, id, InterviewQuestionCategory.workStyle);
        state = GameEngine.answerRecruitmentReverseQuestion(state, id, 0);
      case PrologueStage.week2Decision:
        final id = state.prologueState.interviewingCandidateId!;
        final rejectThisOne = forceRejectFirst && decisionsMade == 0;
        if (rejectThisOne) {
          state = GameEngine.completeRecruitmentInterview(state, id, InterviewOutcome.rejected);
          state = PrologueEngine.decideCandidate(state, id, hire: false);
          outcome.explicitRejectUsed = true;
        } else {
          state = GameEngine.completeRecruitmentInterview(state, id, InterviewOutcome.hired);
          final before = state.engineers.length;
          state = PrologueEngine.decideCandidate(state, id, hire: true);
          final accepted = state.engineers.length > before;
          if (decisionsMade == 0) {
            outcome.firstAttemptAccepted = accepted;
            outcome.firstAttemptDeclined = !accepted;
          }
        }
        decisionsMade++;
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
      outcome.assignedAtPrologueWeek = state.prologueState.prologueWeek;
      break;
    }
    // Defensive stall guard: if a whole iteration produced no state change
    // at all (shouldn't happen after the week2CandidateSelect fix above,
    // but would otherwise spin silently to the guard cap like the original
    // bug did), force a week advance instead of looping uselessly.
    if (identical(state, beforeState)) {
      state = PrologueEngine.advanceWeek(state);
      advances++;
    }
  }

  outcome.hiredEventually = state.engineers.isNotEmpty;
  outcome.failedAttempts = state.prologueState.failedAttempts;
  outcome.exhaustedSafetyCap = state.activeAssignments.isEmpty && !outcome.bankruptBeforeAssignment && (advances >= maxAdvances || guard >= maxGuard);
  if (state.activeAssignments.isNotEmpty) {
    final assignment = state.activeAssignments.first;
    outcome.firstProjectRate = assignment.project.monthlyRate;
    final engineer = state.engineers.first;
    outcome.firstProjectFitTotal = MatchingEngine.computeFit(engineer, assignment.project).total;
    outcome.paymentTermDays = FinanceEngine.clientById(assignment.project.clientId).paymentTermDays;
  }
  return outcome;
}

class _Agg {
  int games = 0;
  int firstAttemptAccepted = 0;
  int firstAttemptDeclined = 0;
  int declinedThenHiredEventually = 0;
  int explicitRejectGames = 0;
  int explicitRejectThenHiredEventually = 0;
  int hiredEventually = 0;
  int assignedApril1 = 0; // prologueWeek <= 4 (within March itself)
  int assignedApril2 = 0; // prologueWeek <= 8
  int assignedApril3 = 0; // prologueWeek <= 12
  int bankrupt = 0;
  int exhaustedSafetyCap = 0;
  int projectFailureRecoveryUsed = 0; // failedAttempts > 0
  int upperAttempts = 0, upperPasses = 0, clientAttempts = 0, clientPasses = 0;
  int weekSum = 0, weekCount = 0;

  void add(_Outcome o) {
    games++;
    if (o.firstAttemptAccepted == true) firstAttemptAccepted++;
    if (o.firstAttemptDeclined) {
      firstAttemptDeclined++;
      if (o.hiredEventually) declinedThenHiredEventually++;
    }
    if (o.explicitRejectUsed) {
      explicitRejectGames++;
      if (o.hiredEventually) explicitRejectThenHiredEventually++;
    }
    if (o.hiredEventually) hiredEventually++;
    if (o.bankruptBeforeAssignment) bankrupt++;
    if (o.exhaustedSafetyCap) exhaustedSafetyCap++;
    if (o.failedAttempts > 0) projectFailureRecoveryUsed++;
    upperAttempts += o.upperAttempts;
    upperPasses += o.upperPasses;
    clientAttempts += o.clientAttempts;
    clientPasses += o.clientPasses;
    final week = o.assignedAtPrologueWeek;
    if (week != null) {
      if (week <= 4) assignedApril1++;
      if (week <= 8) assignedApril2++;
      if (week <= 12) assignedApril3++;
      weekSum += week;
      weekCount++;
    }
  }
}

void _printMainCohort(String label, _Agg a) {
  print('=== $label — natural play (${a.games} games, always attempts hire) ===');
  print('最初の応募者の内定承諾率: ${_pct(a.firstAttemptAccepted, a.games)}');
  print('内定辞退発生率(最初の応募者): ${_pct(a.firstAttemptDeclined, a.games)}');
  print('内定辞退後の再採用成功率: ${_pct(a.declinedThenHiredEventually, a.firstAttemptDeclined)}  (母数=内定辞退が発生した${a.firstAttemptDeclined}ゲーム)');
  print('最終的に技術者を採用できた率: ${_pct(a.hiredEventually, a.games)}');
  print('4月1週初参画率: ${_pct(a.assignedApril1, a.games)}');
  print('4月2週初参画率: ${_pct(a.assignedApril2, a.games)}');
  print('4月3週初参画率: ${_pct(a.assignedApril3, a.games)}');
  print('初参画までの平均週(prologueWeek, 参画できたゲームのみ): ${a.weekCount == 0 ? 'n/a' : (a.weekSum / a.weekCount).toStringAsFixed(2)}');
  print('初参画前倒産率: ${_pct(a.bankrupt, a.games)}');
  print('安全キャップ到達(未参画のまま打ち切り)率: ${_pct(a.exhaustedSafetyCap, a.games)}');
  print('案件面談Failure Recovery(§54-56)を1回以上利用したゲームの割合: ${_pct(a.projectFailureRecoveryUsed, a.games)}');
  print('上位会社面談 通過率(1回あたり): ${_pct(a.upperPasses, a.upperAttempts)}  (attempts=${a.upperAttempts})');
  print('客先面談 通過率(1回あたり): ${_pct(a.clientPasses, a.clientAttempts)}  (attempts=${a.clientAttempts})');
  print('');
}

void _printRejectCohort(String label, _Agg a) {
  print('=== $label — explicit 不採用 cohort (${a.games} games, first candidate always explicitly rejected) ===');
  print('不採用後の再採用成功率: ${_pct(a.explicitRejectThenHiredEventually, a.explicitRejectGames)}  (母数=${a.explicitRejectGames}ゲーム)');
  print('最終的に技術者を採用できた率: ${_pct(a.hiredEventually, a.games)}');
  print('4月1週初参画率: ${_pct(a.assignedApril1, a.games)}');
  print('4月2週初参画率: ${_pct(a.assignedApril2, a.games)}');
  print('4月3週初参画率: ${_pct(a.assignedApril3, a.games)}');
  print('初参画までの平均週: ${a.weekCount == 0 ? 'n/a' : (a.weekSum / a.weekCount).toStringAsFixed(2)}');
  print('初参画前倒産率: ${_pct(a.bankrupt, a.games)}');
  print('安全キャップ到達率: ${_pct(a.exhaustedSafetyCap, a.games)}');
  print('');
}

void main(List<String> args) {
  final gamesPerStrategy = args.isNotEmpty ? int.parse(args.first) : 1000;

  for (final candidateB in [false, true]) {
    final label = candidateB ? 'Candidate B' : 'Candidate A';

    final main = _Agg();
    for (var i = 0; i < gamesPerStrategy; i++) {
      final seed = 1000000 + i * 7919 + (candidateB ? 500000 : 0);
      main.add(_playOne(seed, candidateB: candidateB));
    }
    _printMainCohort(label, main);

    final rejectCohort = _Agg();
    for (var i = 0; i < gamesPerStrategy; i++) {
      final seed = 9000000 + i * 7919 + (candidateB ? 500000 : 0);
      rejectCohort.add(_playOne(seed, candidateB: candidateB, forceRejectFirst: true));
    }
    _printRejectCohort(label, rejectCohort);
  }
}

String _pct(int count, int total) => total == 0 ? 'n/a' : '${(count / total * 100).toStringAsFixed(1)}%';
