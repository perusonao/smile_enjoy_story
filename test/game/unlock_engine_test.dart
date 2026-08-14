// Playable 0.5A.1 §8: UnlockEngine phase-gating tests. Confirms the
// Founding Prologue no longer unlocks every feature the instant April Week
// 1 fires, while leaving every non-Prologue game (Free Mode, or a save that
// skipped the tutorial) completely untouched.

import 'package:flutter_test/flutter_test.dart';
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
}
