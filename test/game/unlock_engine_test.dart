// Playable 0.5A.1 §8: UnlockEngine phase-gating tests. Confirms the
// Founding Prologue no longer unlocks every feature the instant April Week
// 1 fires, while leaving every non-Prologue game (Free Mode, or a save that
// skipped the tutorial) completely untouched.

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'prologue_engine_test.dart' show playThroughPrologue;

void main() {
  group('UnlockEngine.currentPhase', () {
    test('a game that never ran the Prologue is always freeManagement (no extra restriction)', () {
      final state = GameEngine.newGame(seed: 1);
      expect(UnlockEngine.currentPhase(state), UnlockPhase.freeManagement);
      expect(UnlockEngine.canUseRecruitment(state), isTrue);
      expect(UnlockEngine.canUseWelfare(state), isTrue);
    });

    test('a Prologue still in progress reads as founding', () {
      final state = PrologueEngine.newGame(seed: 1);
      expect(UnlockEngine.currentPhase(state), UnlockPhase.founding);
    });

    test('right after Prologue completion, the game is basicManagement — not everything unlocked at once', () {
      var state = playThroughPrologue(11);
      expect(state.activeAssignments, isNotEmpty);
      state = PrologueEngine.completePrologue(state);
      expect(state.prologueState.completed, isTrue);

      // The older FoundingStage system already reads "tutorial complete"
      // the instant the Prologue finishes (every milestone was earned for
      // real during March) — that's the exact behavior UnlockEngine exists
      // to narrow back down.
      expect(ProgressionEngine.currentStage(state), FoundingStage.freeManagement);
      expect(ProgressionEngine.canUseRecruitment(state), isTrue);
      expect(ProgressionEngine.canUseWelfare(state), isTrue);

      // UnlockEngine additionally restricts both, right after first assignment.
      expect(UnlockEngine.currentPhase(state), UnlockPhase.basicManagement);
      expect(UnlockEngine.canUseRecruitment(state), isFalse);
      expect(UnlockEngine.canUseWelfare(state), isFalse);
    });

    test('a second engineer hired moves the phase to employeeManagement (companyGrowth achieved)', () {
      var state = playThroughPrologue(11);
      state = PrologueEngine.completePrologue(state);
      final second = state.engineers.first.copyWith(id: 'engineer-second');
      state = state.copyWith(engineers: [...state.engineers, second]);
      expect(UnlockEngine.currentPhase(state), UnlockPhase.employeeManagement);
      expect(UnlockEngine.canUseRecruitment(state), isTrue);
      expect(UnlockEngine.canUseWelfare(state), isTrue);
    });

    test('a welfare action taken moves the phase to freeManagement', () {
      var state = playThroughPrologue(11);
      state = PrologueEngine.completePrologue(state);
      final second = state.engineers.first.copyWith(id: 'engineer-second');
      state = state.copyWith(engineers: [...state.engineers, second], lastBonusWeek: state.week);
      expect(UnlockEngine.currentPhase(state), UnlockPhase.freeManagement);
    });
  });

  group('UnlockEngine.currentPhase: companyGrowth is a real, experienced phase (follow-up review)', () {
    test('phase advances exactly one step at a time under real weekly play — companyGrowth is never skipped', () {
      var state = playThroughPrologue(11);
      state = PrologueEngine.completePrologue(state);
      expect(UnlockEngine.currentPhase(state), UnlockPhase.basicManagement);
      // Recruitment is locked the moment basicManagement starts — this is
      // the gate that makes companyGrowth unavoidable: there is no route to
      // a second engineer before it.
      expect(UnlockEngine.canUseRecruitment(state), isFalse);

      // Advance real (post-Prologue) weeks one at a time and record every
      // phase actually observed, in order — proves the sequence is
      // basicManagement -> companyGrowth with nothing skipped in between,
      // not just "eventually companyGrowth is reachable in principle".
      final observedPhases = <UnlockPhase>[UnlockPhase.basicManagement];
      for (var i = 0; i < UnlockEngine.weeksBeforeCompanyGrowth + 1; i++) {
        state = GameEngine.advanceWeek(state);
        final phase = UnlockEngine.currentPhase(state);
        if (phase != observedPhases.last) observedPhases.add(phase);
      }
      expect(observedPhases, [UnlockPhase.basicManagement, UnlockPhase.companyGrowth], reason: 'must transition directly from basicManagement to companyGrowth, in that order, with no phase skipped or reordered');
      expect(UnlockEngine.canUseRecruitment(state), isTrue, reason: 'recruitment unlocks exactly when companyGrowth starts');
      expect(UnlockEngine.canUseWelfare(state), isFalse, reason: 'welfare is still locked — employeeManagement has not started yet');
    });

    test('a genuinely-recruited second engineer (real interview+hire flow, not spliced state) reaches employeeManagement', () {
      var state = playThroughPrologue(11);
      state = PrologueEngine.completePrologue(state);
      for (var i = 0; i < UnlockEngine.weeksBeforeCompanyGrowth + 1; i++) {
        state = GameEngine.advanceWeek(state);
      }
      expect(UnlockEngine.currentPhase(state), UnlockPhase.companyGrowth);
      expect(UnlockEngine.canUseRecruitment(state), isTrue);

      // Real recruitment flow (interview -> hire -> PendingHire -> joins on
      // a later advanceWeek), the same path the now-unlocked 採用 tab drives.
      final applicant = ApplicantGenerator(seed: 42).generate(1).first;
      state = state.copyWith(applicants: [
        ...state.applicants,
        ApplicantEntry(applicant: applicant, appearedWeek: state.week, source: RecruitmentMediaType.freeWork),
      ]);
      state = GameEngine.interviewApplicant(state, applicant.id);
      state = GameEngine.hireApplicant(state, applicant.id);
      expect(state.pendingHires, isNotEmpty, reason: 'the general hire flow queues a PendingHire, not an immediate Engineer');
      expect(UnlockEngine.currentPhase(state), UnlockPhase.companyGrowth, reason: 'still only 1 real Engineer until the PendingHire joins');

      var guard = 0;
      while (state.engineers.length < 2 && guard < 10) {
        state = GameEngine.advanceWeek(state);
        guard++;
      }
      expect(state.engineers.length, 2, reason: 'the PendingHire must actually join within a couple of weeks');
      expect(UnlockEngine.currentPhase(state), UnlockPhase.employeeManagement);
      expect(UnlockEngine.canUseWelfare(state), isTrue);
    });
  });
}
