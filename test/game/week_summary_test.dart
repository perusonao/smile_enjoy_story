// Playable 0.2 §22: the Week Summary dialog reads GameLogEntry.category to
// pick out this week's noteworthy events. These tests verify the engine
// actually tags the entries it produces, not just that a message string
// exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

GameState _emptyState({int seed = 7}) {
  final base = GameEngine.newGame(seed: seed);
  return base.copyWith(
    engineers: const [],
    activeAssignments: const [],
    applicants: const [],
    openProjects: const [],
    listings: const [],
    proposals: const [],
    pendingHires: const [],
  );
}

void main() {
  group('Week summary categorization', () {
    test('a new hire joining is logged under engineerJoined for the joining week', () {
      final applicant = buildApplicant(id: 'a1');
      var state = _emptyState().copyWith(
        pendingHires: [
          PendingHire(id: 'ph1', applicant: applicant, salary: 400000, decisionWeek: 1, joinWeek: 2),
        ],
      );

      state = GameEngine.advanceWeek(state);

      final thisWeek = state.events.where((e) => e.week == state.week).toList();
      expect(
        thisWeek.any((e) => e.category == GameLogCategory.engineerJoined),
        isTrue,
      );
    });

    test('a resolved project interview is logged as interviewPassed or interviewFailed', () {
      final engineer = buildEngineer(id: 'e1', status: EngineerStatus.waiting);
      final project = buildProject(id: 'p1', applicationDeadlineWeek: 20);
      var state = _emptyState().copyWith(
        engineers: [engineer],
        openProjects: [ProjectEntry(project: project, postedWeek: 1)],
      );
      state = GameEngine.proposeEngineer(state, 'e1', 'p1');
      state = GameEngine.advanceWeek(state);

      final thisWeek = state.events.where((e) => e.week == state.week).toList();
      expect(
        thisWeek.any(
          (e) =>
              e.category == GameLogCategory.interviewPassed ||
              e.category == GameLogCategory.interviewFailed,
        ),
        isTrue,
      );
    });

    test('a listing expiring is logged under listingExpired on the week it lapses', () {
      var state = _emptyState();
      state = GameEngine.postRecruitmentMedia(state, RecruitmentMediaType.freeWork);
      final durationWeeks = recruitmentMediaConfigs[RecruitmentMediaType.freeWork]!.durationWeeks;

      for (var i = 0; i < durationWeeks; i++) {
        state = GameEngine.advanceWeek(state);
      }

      final thisWeek = state.events.where((e) => e.week == state.week).toList();
      expect(
        thisWeek.any((e) => e.category == GameLogCategory.listingExpired),
        isTrue,
      );
    });

    test('an offer decision is logged as offerAccepted or offerDeclined', () {
      final applicant = buildApplicant(id: 'a1');
      var state = _emptyState().copyWith(
        applicants: [
          ApplicantEntry(applicant: applicant, appearedWeek: 1, source: RecruitmentMediaType.freeWork),
        ],
      );
      state = GameEngine.interviewApplicant(state, 'a1');
      state = GameEngine.hireApplicant(state, 'a1');

      final thisWeek = state.events.where((e) => e.week == state.week).toList();
      expect(
        thisWeek.any(
          (e) =>
              e.category == GameLogCategory.offerAccepted ||
              e.category == GameLogCategory.offerDeclined,
        ),
        isTrue,
      );
    });
  });
}
