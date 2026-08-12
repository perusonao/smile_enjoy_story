import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

GameState _baseState({int seed = 1, int credit = 20}) {
  final state = GameEngine.newGame(seed: seed);
  return state.copyWith(company: state.company.copyWith(credit: credit));
}

GameState _withApplicants(GameState state, int count, {int genSeed = 500}) {
  final applicants = ApplicantGenerator(seed: genSeed).generate(count);
  final entries = applicants
      .map(
        (a) => ApplicantEntry(
          applicant: a,
          appearedWeek: state.week,
          source: RecruitmentMediaType.freeWork,
        ),
      )
      .toList();
  return state.copyWith(applicants: entries);
}

void main() {
  group('Recruitment', () {
    test('interview marks the applicant interviewed without deciding anything', () {
      var state = _withApplicants(_baseState(), 1);
      final id = state.applicants.first.applicant.id;
      expect(state.interviewedApplicantIds.contains(id), isFalse);

      state = GameEngine.interviewApplicant(state, id);

      expect(state.interviewedApplicantIds.contains(id), isTrue);
      expect(state.applicants.any((e) => e.applicant.id == id), isTrue);
      expect(state.pendingHires, isEmpty);
    });

    test('reject removes the applicant and creates no engineer or pending hire', () {
      var state = _withApplicants(_baseState(), 1);
      final id = state.applicants.first.applicant.id;
      final engineersBefore = state.engineers.length;

      state = GameEngine.rejectApplicant(state, id);

      expect(state.applicants.any((e) => e.applicant.id == id), isFalse);
      expect(state.engineers.length, engineersBefore);
      expect(state.pendingHires, isEmpty);
    });

    test('hire is a no-op before the applicant has been interviewed', () {
      var state = _withApplicants(_baseState(), 1);
      final id = state.applicants.first.applicant.id;
      final applicantsBefore = state.applicants.length;

      state = GameEngine.hireApplicant(state, id);

      expect(state.applicants.length, applicantsBefore);
      expect(state.pendingHires, isEmpty);
    });

    test('offer accepted: very high company credit guarantees acceptance and schedules joining', () {
      var state = _withApplicants(_baseState(credit: 500), 1);
      final id = state.applicants.first.applicant.id;

      state = GameEngine.interviewApplicant(state, id);
      state = GameEngine.hireApplicant(state, id);

      expect(state.applicants, isEmpty);
      expect(state.pendingHires, hasLength(1));
      final hire = state.pendingHires.single;
      expect(hire.joinWeek - hire.decisionWeek, inInclusiveRange(1, 2));
    });

    test('offer declined: very low company credit guarantees decline', () {
      var state = _withApplicants(_baseState(credit: -1000), 1);
      final id = state.applicants.first.applicant.id;

      state = GameEngine.interviewApplicant(state, id);
      state = GameEngine.hireApplicant(state, id);

      expect(state.applicants, isEmpty);
      expect(state.pendingHires, isEmpty);
    });

    test('joining timing: a pending hire becomes a waiting engineer exactly on joinWeek', () {
      var state = _withApplicants(_baseState(credit: 500), 1);
      final applicant = state.applicants.first.applicant;
      state = GameEngine.interviewApplicant(state, applicant.id);
      state = GameEngine.hireApplicant(state, applicant.id);

      final joinWeek = state.pendingHires.single.joinWeek;
      final engineerCountBefore = state.engineers.length;

      while (state.week < joinWeek) {
        state = GameEngine.advanceWeek(state);
        if (state.week < joinWeek) {
          expect(
            state.engineers.length,
            engineerCountBefore,
            reason: 'should not join before its scheduled week',
          );
        }
      }

      expect(state.week, joinWeek);
      expect(state.engineers.length, engineerCountBefore + 1);
      final newEngineer = state.engineers.firstWhere(
        (e) => e.sourceApplicantId == applicant.id,
      );
      expect(newEngineer.status, EngineerStatus.waiting);
      expect(state.pendingHires, isEmpty);
    });
  });
}
