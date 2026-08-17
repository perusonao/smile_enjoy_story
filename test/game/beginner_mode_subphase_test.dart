// Phase 3B-1 (S.E.S. Development Plan §3.9 "Phase 3B — July-September"):
// Beginner Mode's sub-phase window logic
// (BeginnerModeEngine.phase3b1LastWeek/phase3b2LastWeek/phase3b3LastWeek/
// isBeginnerModeActive/currentSubPhase) and the new Phase 3B-1
// BeginnerMilestone data-model additions (fitReasonViewed/
// projectComparisonUsed), tested at the engine level per the Phase 3B-1
// design brief. Deliberately a new file, not an addition to
// beginner_mode_test.dart's existing Phase 3A "Test A-J" group, so Phase
// 3A's own regression suite is untouched by this PR.
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'prologue_engine_test.dart' show playThroughPrologue;

/// Mirrors beginner_mode_test.dart's own `_reachBeginnerManagement`: plays a
/// full Founding Prologue through April Week 1's first assignment, then taps
/// "経営を始める" ([PrologueEngine.completePrologue]) — the exact point
/// Beginner Mode's continued guidance picks up from.
GameState _reachBeginnerManagement(int seed) {
  var state = playThroughPrologue(seed);
  expect(
    state.activeAssignments,
    isNotEmpty,
    reason: 'seed $seed must reach first assignment for this suite to mean anything',
  );
  state = BeginnerModeEngine.reconcile(ProgressionEngine.reconcile(PrologueEngine.completePrologue(state)));
  return state;
}

/// Jumps straight to [week] without simulating every week in between — the
/// same technique beginner_mode_widget_test.dart already uses
/// (`state.company.copyWith(currentWeek: ...)`) to test week-boundary
/// behavior without a slow full playthrough. Sub-phase gating is a pure
/// function of `GameState.week` (§3.0 rule 5's one calendar-defined
/// exception — see `BeginnerModeEngine.currentSubPhase`'s doc comment), so
/// this is a faithful way to exercise every boundary deterministically.
GameState _atWeek(GameState state, int week) => state.copyWith(company: state.company.copyWith(currentWeek: week));

void main() {
  group('Phase 3B-1 — Beginner Mode sub-phase window (weeks 1-48)', () {
    late GameState base;
    setUp(() {
      base = _reachBeginnerManagement(11);
    });

    test('week 12 = Phase 3A', () {
      final state = _atWeek(base, 12);
      expect(BeginnerModeEngine.isPhase3AActive(state), isTrue);
      expect(BeginnerModeEngine.isBeginnerModeActive(state), isTrue);
      expect(BeginnerModeEngine.currentSubPhase(state), BeginnerSubPhase.phase3a);
    });

    test('week 13 = Phase 3B-1 (Phase 3A window still ends exactly at week 12, unchanged)', () {
      final state = _atWeek(base, 13);
      expect(BeginnerModeEngine.isPhase3AActive(state), isFalse);
      expect(BeginnerModeEngine.isBeginnerModeActive(state), isTrue);
      expect(BeginnerModeEngine.currentSubPhase(state), BeginnerSubPhase.phase3b1);
    });

    test('week 24 = Phase 3B-1 (last week of the window)', () {
      final state = _atWeek(base, 24);
      expect(BeginnerModeEngine.currentSubPhase(state), BeginnerSubPhase.phase3b1);
      expect(BeginnerModeEngine.isBeginnerModeActive(state), isTrue);
    });

    test('week 25 = Phase 3B-2', () {
      final state = _atWeek(base, 25);
      expect(BeginnerModeEngine.currentSubPhase(state), BeginnerSubPhase.phase3b2);
    });

    test('week 36 = Phase 3B-2 (last week of the window)', () {
      final state = _atWeek(base, 36);
      expect(BeginnerModeEngine.currentSubPhase(state), BeginnerSubPhase.phase3b2);
    });

    test('week 37 = Phase 3B-3', () {
      final state = _atWeek(base, 37);
      expect(BeginnerModeEngine.currentSubPhase(state), BeginnerSubPhase.phase3b3);
    });

    test("week 48 = Phase 3B-3 (last week of Beginner Mode's first fiscal year)", () {
      final state = _atWeek(base, 48);
      expect(BeginnerModeEngine.currentSubPhase(state), BeginnerSubPhase.phase3b3);
      expect(BeginnerModeEngine.isBeginnerModeActive(state), isTrue);
      expect(BeginnerModeEngine.phase3b3LastWeek, totalGameWeeks, reason: 'graduation must line up with the game\'s own fiscal-year length');
    });

    test('week 49 = Beginner Mode ends (graduation week, Year 2 / Normal Mode territory)', () {
      // NOTE (Codex review on PR #17): `GameEngine.advanceWeek` cannot
      // actually produce week 49 today — see the invariant test right below
      // this one. This test exercises `currentSubPhase`/
      // `isBeginnerModeActive` as the pure functions of `week` they're
      // documented to be (mirrors `isPhase3AActive`, which is defined the
      // same way and is never gated on `GameStatus`), constructing week 49
      // directly rather than through real play, so the derivation is
      // already correct the moment a later phase (Phase 3D) adds a real
      // Year 2 continuation — without this file needing to change again.
      final state = _atWeek(base, 49);
      expect(BeginnerModeEngine.isBeginnerModeActive(state), isFalse);
      expect(BeginnerModeEngine.currentSubPhase(state), isNull);
    });

    test('the real engine invariant this suite relies on: week 48 is the actual terminal week today', () {
      // Codex review on PR #17 (lib/game/engine/beginner_mode_engine.dart:82):
      // confirms week 49 is not reachable via real play under the current
      // GameEngine — driven through the real `GameEngine.advanceWeek` (not
      // the synthetic `_atWeek` helper) to prove it, rather than merely
      // asserting it in prose.
      final week47 = _atWeek(base, totalGameWeeks - 1).copyWith(status: GameStatus.playing);
      final atMonthEnd = GameEngine.advanceWeek(week47);

      expect(atMonthEnd.week, totalGameWeeks);
      expect(atMonthEnd.status, GameStatus.finished, reason: 'GameEngine.advanceWeek itself ends the whole 48-week fiscal year here, not just Beginner Mode');

      // A further advanceWeek call is a documented no-op (the engine's own
      // `if (state.status != GameStatus.playing) return state;` guard) — week
      // 49 genuinely cannot be reached this way.
      final afterFinished = GameEngine.advanceWeek(atMonthEnd);
      expect(afterFinished.week, totalGameWeeks);
      expect(identical(afterFinished, atMonthEnd), isTrue, reason: 'advanceWeek must be a true no-op once the game has finished');

      // At this actually-reachable final state, Beginner Mode's own
      // sub-phase framing still reads as Phase 3B-3 (intentional — see
      // phase3b3LastWeek's doc comment: these are pure functions of `week`
      // alone, independent of `GameStatus`, so the framing can still be
      // used on a year-end result screen even though the game itself has
      // already finished).
      expect(BeginnerModeEngine.isBeginnerModeActive(atMonthEnd), isTrue);
      expect(BeginnerModeEngine.currentSubPhase(atMonthEnd), BeginnerSubPhase.phase3b3);
    });
  });

  group('Phase 3B-1 — sub-phase gating matches Free Mode / pre-founding rules', () {
    test('Free Mode is never treated as a Beginner Mode sub-phase, at any candidate week', () {
      final freeState = GameEngine.newGame(seed: 1);
      expect(BeginnerModeEngine.isBeginnerJourney(freeState), isFalse);
      for (final week in [1, 12, 13, 24, 25, 36, 37, 48, 49]) {
        final state = freeState.copyWith(company: freeState.company.copyWith(currentWeek: week));
        expect(BeginnerModeEngine.isBeginnerModeActive(state), isFalse, reason: 'week $week');
        expect(BeginnerModeEngine.currentSubPhase(state), isNull, reason: 'week $week');
      }
    });

    test('before first assignment, no sub-phase is active even in a Beginner journey', () {
      final fresh = PrologueEngine.newGame(seed: 1);
      expect(BeginnerModeEngine.isBeginnerJourney(fresh), isTrue);
      expect(fresh.foundingProgress.has(FoundingMilestone.firstAssignment), isFalse);
      for (final week in [1, 13, 25, 37]) {
        final state = fresh.copyWith(company: fresh.company.copyWith(currentWeek: week));
        expect(BeginnerModeEngine.isBeginnerModeActive(state), isFalse, reason: 'week $week');
        expect(BeginnerModeEngine.currentSubPhase(state), isNull, reason: 'week $week');
      }
    });
  });

  group('Phase 3B-1 — legacy save safety for the new milestones', () {
    test('a save JSON with no fitReasonViewed/projectComparisonUsed entries loads with both unshown', () {
      final state = _reachBeginnerManagement(11);
      final json = state.toJson();

      // Simulate a genuinely old save: strip any trace of the new milestone
      // names from beginnerModeState, the same way `BeginnerModeState.
      // fromJson` already has to tolerate for every pre-Phase-3B save.
      final beginnerModeJson = Map<String, dynamic>.from(json['beginnerModeState'] as Map<String, dynamic>);
      beginnerModeJson['completedMilestones'] = (beginnerModeJson['completedMilestones'] as List)
          .where((name) => name != 'fitReasonViewed' && name != 'projectComparisonUsed')
          .toList();
      final milestoneWeeks = Map<String, dynamic>.from(beginnerModeJson['milestoneWeeks'] as Map<String, dynamic>);
      milestoneWeeks.remove('fitReasonViewed');
      milestoneWeeks.remove('projectComparisonUsed');
      beginnerModeJson['milestoneWeeks'] = milestoneWeeks;
      json['beginnerModeState'] = beginnerModeJson;

      final reloaded = GameState.fromJson(json);
      expect(reloaded.beginnerModeState.has(BeginnerMilestone.fitReasonViewed), isFalse);
      expect(reloaded.beginnerModeState.has(BeginnerMilestone.projectComparisonUsed), isFalse);

      // Must not crash, and reconcile must be a safe no-op for both new
      // milestones (they are never auto-derived — see
      // BeginnerModeEngine._isTrue's doc comment on this case).
      expect(() => BeginnerModeEngine.reconcile(reloaded), returnsNormally);
      final reconciled = BeginnerModeEngine.reconcile(reloaded);
      expect(reconciled.beginnerModeState.has(BeginnerMilestone.fitReasonViewed), isFalse);
      expect(reconciled.beginnerModeState.has(BeginnerMilestone.projectComparisonUsed), isFalse);
    });

    test('a save JSON predating Phase 3B entirely (no beginnerModeState key at all) is still safe', () {
      final state = _reachBeginnerManagement(11);
      final json = state.toJson();
      json.remove('beginnerModeState');

      final reloaded = GameState.fromJson(json);
      expect(reloaded.beginnerModeState.completedMilestones, isEmpty);
      expect(() => BeginnerModeEngine.currentSubPhase(_atWeek(reloaded, 13)), returnsNormally);
    });
  });
}
