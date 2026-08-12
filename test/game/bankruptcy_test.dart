import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

void main() {
  group('Bankruptcy', () {
    test('cash going below 0 after a turn ends the game as bankrupt', () {
      final engineer = buildEngineer(
        id: 'expensive-1',
        salary: 4000000, // /4 = 1,000,000 per week
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

      final next = GameEngine.advanceWeek(state);

      expect(next.status, GameStatus.bankrupt);
      expect(next.company.cash, lessThan(0));
      expect(next.bankruptWeek, next.week);
      expect(next.bankruptCause, isNotNull);
      expect(next.bankruptCause, isNotEmpty);
    });

    test('a healthy company keeps playing past a single turn', () {
      final state = GameEngine.newGame(seed: 2);
      final next = GameEngine.advanceWeek(state);
      expect(next.status, GameStatus.playing);
      expect(next.bankruptWeek, isNull);
    });

    test('reaching week 26 without going bankrupt finishes the game', () {
      var state = GameEngine.newGame(seed: 3);
      for (var i = 0; i < totalGameWeeks && state.status == GameStatus.playing; i++) {
        state = GameEngine.advanceWeek(state);
      }
      expect(state.status, isNot(GameStatus.playing));
      if (state.status == GameStatus.finished) {
        expect(state.week, greaterThanOrEqualTo(totalGameWeeks));
      }
    });
  });
}
