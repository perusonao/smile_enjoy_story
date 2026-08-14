// Playable 0.5A.1 P0 regression tests: every PrologueStage must offer at
// least one real, enabled action (a specific CTA, or "次の週へ") — nothing
// that looks tappable but silently no-ops with no other way forward. See
// PrologueEngine.canInterviewThisWeek and the dead-end analysis in the
// Playable 0.5A.1 final report.

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'prologue_engine_test.dart' show playThroughPrologue, playThroughToHireDecision;

void main() {
  group('P0: 採用面談完了後にdead-endにならない', () {
    test('hire: stage leaves week2CandidateSelect for week3SkillSheet, never stalls', () {
      var state = playThroughToHireDecision(seed: 3);
      expect(state.engineers, hasLength(1));
      expect(PrologueEngine.stage(state), PrologueStage.week3SkillSheet);
    });

    test('reject: the blocked candidate button is not the only option — advanceWeek always progresses the week', () {
      var fresh = _twoCandidatesAtWeek2(seed: 7);
      final firstId = fresh.applicants.first.applicant.id;
      final secondId = fresh.applicants.last.applicant.id;
      final weekBefore = fresh.prologueState.prologueWeek;

      fresh = PrologueEngine.selectCandidateForInterview(fresh, firstId);
      fresh = _finishInterview(fresh, firstId);
      fresh = GameEngine.completeRecruitmentInterview(fresh, firstId, InterviewOutcome.rejected);
      fresh = PrologueEngine.decideCandidate(fresh, firstId, hire: false);

      // Still week2CandidateSelect (second candidate remains) — this is
      // exactly the P0 combination: the stage doesn't change, but the
      // remaining candidate can't be interviewed this week.
      expect(PrologueEngine.stage(fresh), PrologueStage.week2CandidateSelect);
      expect(fresh.applicants.any((e) => e.applicant.id == secondId), isTrue);
      expect(PrologueEngine.canInterviewThisWeek(fresh), isFalse, reason: 'one interview per week already used');

      // The invariant: even though the on-screen "面接する" action is
      // blocked, "次の週へ" (PrologueEngine.advanceWeek) is always a real,
      // state-changing action from this exact stage/state combination.
      final advanced = PrologueEngine.advanceWeek(fresh);
      expect(advanced.prologueState.prologueWeek, weekBefore + 1);
      expect(PrologueEngine.canInterviewThisWeek(advanced), isTrue, reason: 'the slot frees up on the new week');
    });
  });

  group('P0: 不採用後に継続可能', () {
    test('rejecting a candidate keeps the game continuable to a hire next week', () {
      var state = _twoCandidatesAtWeek2(seed: 7);
      final firstId = state.applicants.first.applicant.id;
      state = PrologueEngine.selectCandidateForInterview(state, firstId);
      state = _finishInterview(state, firstId);
      state = GameEngine.completeRecruitmentInterview(state, firstId, InterviewOutcome.rejected);
      state = PrologueEngine.decideCandidate(state, firstId, hire: false);
      expect(state.engineers, isEmpty);

      state = PrologueEngine.advanceWeek(state);
      expect(state.applicants, isNotEmpty, reason: 'a remaining/rescue candidate must always be available');
      final nextId = state.applicants.first.applicant.id;
      state = PrologueEngine.selectCandidateForInterview(state, nextId);
      state = _finishInterview(state, nextId);
      state = GameEngine.completeRecruitmentInterview(state, nextId, InterviewOutcome.hired);
      state = PrologueEngine.decideCandidate(state, nextId, hire: true);
      expect(state.engineers, isNotEmpty, reason: 'reject must never permanently block hiring');
    });
  });

  group('P0: 内定辞退後に継続可能', () {
    test('a declined offer keeps the game continuable to a hire next week', () {
      GameState? declinedState;
      for (var seed = 0; seed < 200 && declinedState == null; seed++) {
        var state = _twoCandidatesAtWeek2(seed: seed);
        final firstId = state.applicants.first.applicant.id;
        state = PrologueEngine.selectCandidateForInterview(state, firstId);
        state = _finishInterview(state, firstId);
        state = GameEngine.completeRecruitmentInterview(state, firstId, InterviewOutcome.hired);
        final before = state.engineers.length;
        state = PrologueEngine.decideCandidate(state, firstId, hire: true);
        if (state.engineers.length == before) declinedState = state;
      }
      expect(declinedState, isNotNull, reason: 'expected at least one decline within 200 seeds');
      var state = declinedState!;
      expect(state.engineers, isEmpty);

      state = PrologueEngine.advanceWeek(state);
      expect(state.applicants, isNotEmpty);
      final nextId = state.applicants.first.applicant.id;
      state = PrologueEngine.selectCandidateForInterview(state, nextId);
      expect(state.prologueState.interviewingCandidateId, nextId, reason: 'decline must never permanently block hiring');
    });
  });

  group('P0: Save/Reload後に継続可能', () {
    test('reloading mid-blocked-week still resolves to a stage with a real action', () {
      var state = _twoCandidatesAtWeek2(seed: 7);
      final firstId = state.applicants.first.applicant.id;
      state = PrologueEngine.selectCandidateForInterview(state, firstId);
      state = _finishInterview(state, firstId);
      state = GameEngine.completeRecruitmentInterview(state, firstId, InterviewOutcome.rejected);
      state = PrologueEngine.decideCandidate(state, firstId, hire: false);

      final reloaded = GameState.fromJson(state.toJson());
      expect(PrologueEngine.stage(reloaded), PrologueStage.week2CandidateSelect);
      expect(PrologueEngine.canInterviewThisWeek(reloaded), isFalse);
      // advanceWeek is still available and still progresses.
      final advanced = PrologueEngine.advanceWeek(reloaded);
      expect(advanced.prologueState.prologueWeek, reloaded.prologueState.prologueWeek + 1);
    });

    test('a full playthrough survives a save/reload at every stage without ever throwing', () {
      var state = playThroughPrologue(21);
      expect(state.activeAssignments, isNotEmpty);
      final reloaded = GameState.fromJson(state.toJson());
      expect(PrologueEngine.stage(reloaded), PrologueEngine.stage(state));
    });
  });

  group('Project interview flow ordering (§6)', () {
    test('上位会社面談 → 客先面談 → 契約成立: the flow always passes through both steps in order', () {
      var state = playThroughPrologue(11);
      expect(state.activeAssignments, isNotEmpty);
      final engineerId = state.engineers.first.id;
      final accepted = state.proposals.firstWhere((p) => p.engineerId == engineerId && p.status == ApplicationStatus.accepted);
      final steps = accepted.stepHistory.map((h) => h.step).toList();
      final upperIndex = steps.indexOf(SelectionStep.upperCompanyInterview);
      final clientIndex = steps.indexOf(SelectionStep.clientInterview);
      expect(upperIndex, greaterThanOrEqualTo(0), reason: '上位会社面談 must have happened');
      expect(clientIndex, greaterThanOrEqualTo(0), reason: '客先面談 must have happened');
      expect(upperIndex, lessThan(clientIndex), reason: '上位会社面談 must precede 客先面談');
    });

    test('客先面談を飛ばせない: the standard flow never reaches offer without a passed clientInterview step', () {
      // Exhaustively drive several seeds through to contract and check the
      // domain invariant on every one, not just a single lucky seed.
      for (final seed in [3, 5, 7, 11, 13]) {
        final state = playThroughPrologue(seed);
        if (state.activeAssignments.isEmpty) continue; // retry budget exhausted for this seed — not what this test checks
        final engineerId = state.engineers.first.id;
        final accepted = state.proposals.firstWhere((p) => p.engineerId == engineerId && p.status == ApplicationStatus.accepted);
        final clientInterviewPassed = accepted.stepHistory.any((h) => h.step == SelectionStep.clientInterview && h.result == SelectionStepResult.passed);
        expect(clientInterviewPassed, isTrue, reason: 'seed $seed reached a contract without a passed 客先面談');
      }
    });

    test('finalizeContractIfReady is a no-op while the proposal is still mid-selection (never mints an offer early)', () {
      var state = playThroughToHireDecision(seed: 3);
      state = PrologueEngine.confirmSkillSheet(state);
      state = PrologueEngine.startPreJoiningSales(state);
      state = PrologueEngine.ensureInterviewRequest(state);
      state = PrologueEngine.acceptPrologueInterviewRequest(state);
      final engineerId = state.engineers.first.id;
      final proposal = state.proposals.firstWhere((p) => p.engineerId == engineerId && p.status == ApplicationStatus.active);
      expect(proposal.currentStep, SelectionStep.upperCompanyInterview);

      final before = state.offers.length;
      final afterNoOp = PrologueEngine.finalizeContractIfReady(state);
      expect(afterNoOp.offers.length, before, reason: 'no offer should be minted before the client interview step is even reached');
    });
  });

  group('案件面談失敗後に再営業可能 (§54-56)', () {
    test('a failed client-interview step returns the engineer to selling and issues a fresh interview request', () {
      var state = playThroughToHireDecision(seed: 3);
      state = PrologueEngine.confirmSkillSheet(state);
      state = PrologueEngine.startPreJoiningSales(state);
      state = PrologueEngine.ensureInterviewRequest(state);
      state = PrologueEngine.acceptPrologueInterviewRequest(state);
      final engineerId = state.engineers.first.id;
      final proposal = state.proposals.firstWhere((p) => p.engineerId == engineerId && p.status == ApplicationStatus.active);

      // Force a client-interview-step rejection directly (deterministic).
      state = state.copyWith(
        proposals: [
          for (final p in state.proposals)
            if (p.id == proposal.id) p.copyWith(status: ApplicationStatus.rejected, stage: ProposalStage.interviewFailed) else p,
        ],
        engineers: [
          for (final e in state.engineers)
            if (e.id == engineerId) e.copyWith(salesStatus: SalesStatus.selling) else e,
        ],
      );
      state = PrologueEngine.advanceWeek(state);
      expect(state.engineers.first.salesStatus, SalesStatus.selling);
      expect(state.interviewOffers.where((o) => o.employeeId == engineerId && o.status == InterviewOfferStatus.pending), isNotEmpty, reason: 'a new interview request must follow a failure — 再営業可能');
    });
  });

  group('Prologue reset (§7)', () {
    test('restart discards progress and starts a brand-new presidentNaming game', () {
      var state = playThroughToHireDecision(seed: 3);
      expect(state.engineers, isNotEmpty);

      final fresh = PrologueEngine.restart(seed: 99);
      expect(fresh.engineers, isEmpty);
      expect(fresh.applicants, isEmpty);
      expect(fresh.company.presidentName, isEmpty);
      expect(fresh.company.name, isEmpty);
      expect(fresh.prologueState.active, isTrue);
      expect(fresh.prologueState.completed, isFalse);
      expect(PrologueEngine.stage(fresh), PrologueStage.presidentNaming);
    });
  });

  group('reconcileState (§7): repairs a broken/old PrologueState', () {
    test('an interviewingCandidateId pointing at a vanished applicant with no session is cleared', () {
      var state = _twoCandidatesAtWeek2(seed: 7);
      final firstId = state.applicants.first.applicant.id;
      // Simulate corruption: interviewingCandidateId set, but no applicant
      // and no recruitment-interview session exist for it (a normal play
      // session can never produce this combination).
      state = state.copyWith(
        applicants: const [],
        prologueState: state.prologueState.copyWith(interviewingCandidateId: firstId),
      );
      final repaired = PrologueEngine.reconcileState(state);
      expect(repaired.prologueState.interviewingCandidateId, isNull);
      // stage() no longer throws/stalls on the corrupted reference — it
      // resolves to a real, resumable stage (the listing from
      // _twoCandidatesAtWeek2 is still active, so "await replies" is next).
      expect(PrologueEngine.stage(repaired), PrologueStage.week2AwaitingReply);
    });

    test('reconcileState is a no-op for a healthy state', () {
      final state = playThroughToHireDecision(seed: 3);
      final reconciled = PrologueEngine.reconcileState(state);
      expect(reconciled.prologueState.interviewingCandidateId, state.prologueState.interviewingCandidateId);
      expect(PrologueEngine.stage(reconciled), PrologueEngine.stage(state));
    });

    test('reconcileState never touches Free Mode / inactive-Prologue games', () {
      final state = GameEngine.newGame(seed: 1);
      final reconciled = PrologueEngine.reconcileState(state);
      expect(identical(reconciled, state), isTrue);
    });
  });

  group('Recruitment listing selection (§3)', () {
    test('the player-chosen medium is recorded and flavors candidate generation', () {
      var state = PrologueEngine.newGame(seed: 4);
      state = PrologueEngine.confirmCompanySetup(state, presidentName: 'テスト社長', companyName: 'テスト会社');
      state = PrologueEngine.markIntroSeen(state);
      final cashBefore = state.company.cash;
      state = PrologueEngine.postRecruitment(state, RecruitmentMediaType.directScout);
      expect(state.prologueState.recruitmentMediaType, RecruitmentMediaType.directScout);
      expect(state.company.cash, lessThan(cashBefore), reason: 'the paid medium must actually cost cash');
      state = PrologueEngine.advanceWeek(state);
      // directScout (agency): a single, higher-quality candidate instead
      // of the usual pair -- applicant count genuinely differs by medium.
      expect(state.applicants, hasLength(1));
    });

    test('free recruitment still produces exactly two candidates (unchanged default)', () {
      var state = PrologueEngine.newGame(seed: 4);
      state = PrologueEngine.confirmCompanySetup(state, presidentName: 'テスト社長', companyName: 'テスト会社');
      state = PrologueEngine.markIntroSeen(state);
      state = PrologueEngine.postRecruitment(state, RecruitmentMediaType.freeWork);
      state = PrologueEngine.advanceWeek(state);
      expect(state.applicants, hasLength(2));
    });
  });
}

GameState _twoCandidatesAtWeek2({required int seed}) {
  var state = PrologueEngine.newGame(seed: seed);
  state = PrologueEngine.confirmCompanySetup(state, presidentName: 'テスト社長', companyName: 'テスト会社');
  state = PrologueEngine.markIntroSeen(state);
  state = PrologueEngine.postFreeRecruitment(state);
  state = PrologueEngine.advanceWeek(state);
  return state;
}

GameState _finishInterview(GameState state, String applicantId) {
  var s = GameEngine.askRecruitmentQuestion(state, applicantId, InterviewQuestionCategory.technical);
  s = GameEngine.askRecruitmentQuestion(s, applicantId, InterviewQuestionCategory.teamwork);
  s = GameEngine.askRecruitmentQuestion(s, applicantId, InterviewQuestionCategory.workStyle);
  s = GameEngine.answerRecruitmentReverseQuestion(s, applicantId, 0);
  return s;
}
