import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

void main() {
  group('Bankruptcy', () {
    test('cash going below 0 at month-end ends the game as bankrupt (§16)', () {
      final engineer = buildEngineer(
        id: 'expensive-1',
        salary: 4000000, // full monthly salary, due at month-end only
        status: EngineerStatus.waiting,
      );
      var state = GameEngine.newGame(seed: 1).copyWith(
        engineers: [engineer],
        activeAssignments: const [],
        applicants: const [],
        openProjects: const [],
        listings: const [],
        proposals: const [],
        pendingHires: const [],
      );
      state = state.copyWith(
        company: state.company.copyWith(cash: 10000),
      );

      // Weeks 2-3 aren't month-end: no cash moves, so no bankruptcy check
      // fires yet even though the coming salary bill already exceeds cash
      // on hand (§16: mid-month is a predictive warning only).
      state = GameEngine.advanceWeek(state);
      expect(state.status, GameStatus.playing);
      state = GameEngine.advanceWeek(state);
      expect(state.status, GameStatus.playing);

      // Week 4 (month-end): the full salary bill lands and blows past cash.
      state = GameEngine.advanceWeek(state);

      expect(state.status, GameStatus.bankrupt);
      expect(state.company.cash, lessThan(0));
      expect(state.bankruptWeek, state.week);
      expect(state.bankruptCause, isNotNull);
      expect(state.bankruptCause, isNotEmpty);
    });

    test('a healthy company keeps playing past a single turn', () {
      final state = GameEngine.newGame(seed: 2);
      final next = GameEngine.advanceWeek(state);
      expect(next.status, GameStatus.playing);
      expect(next.bankruptWeek, isNull);
    });

    test('reaching week 48 without going bankrupt finishes the game', () {
      var state = GameEngine.newGame(seed: 3);
      for (var i = 0; i < totalGameWeeks && state.status == GameStatus.playing; i++) {
        state = GameEngine.advanceWeek(state);
      }
      expect(state.status, isNot(GameStatus.playing));
      if (state.status == GameStatus.finished) {
        expect(state.week, greaterThanOrEqualTo(totalGameWeeks));
      }
    });

    test('bankruptcy is only ever finalized on a month-end week', () {
      final engineer = buildEngineer(
        id: 'expensive-2',
        salary: 4000000,
        status: EngineerStatus.waiting,
      );
      var state = GameEngine.newGame(seed: 4).copyWith(
        engineers: [engineer],
        activeAssignments: const [],
        applicants: const [],
        openProjects: const [],
        listings: const [],
        proposals: const [],
        pendingHires: const [],
      );
      state = state.copyWith(company: state.company.copyWith(cash: 10000));

      for (var i = 0; i < 3; i++) {
        state = GameEngine.advanceWeek(state);
        if (state.status == GameStatus.bankrupt) {
          expect(GameCalendar.isMonthEnd(state.week), isTrue);
          return;
        }
      }
      fail('expected bankruptcy to have triggered by week 4');
    });
  });
}
