import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

GameState atClientInterview({int seed = 42, bool mismatch = false}) {
  var s = GameEngine.newGame(seed: seed);
  final e = s.engineers.first, p = s.openProjects.first.project;
  var sheet = s.skillSheetFor(e.id);
  if (mismatch && p.requiredLanguages.isNotEmpty) {
    final l = p.requiredLanguages.first;
    sheet = sheet.copyWith(
      displayedLanguageExperience: {
        ...sheet.displayedLanguageExperience,
        l: e.profile.skillFor(l).actualExperienceMonths + 36,
      },
      displayedLeader: 5,
    );
    s = s.copyWith(skillSheets: [sheet, ...s.skillSheets.skip(1)]);
  }
  final index = p.selectionFlow.steps.indexOf(SelectionStep.clientInterview);
  return s.copyWith(
    proposals: [
      ProjectProposal(
        id: 'client-app',
        engineerId: e.id,
        project: p,
        proposedWeek: s.week,
        stage: ProposalStage.proposed,
        currentStepIndex: index,
        fitScore: 70,
      ),
    ],
  );
}

void main() {
  test('client interview waits for manual decision and blocks week', () {
    final s = atClientInterview();
    final advanced = GameEngine.advanceWeek(s);
    expect(advanced.week, s.week);
    expect(
      TaskEngine.generateTasks(
        s,
      ).any((t) => t.id.startsWith('client-interview')),
      isTrue,
    );
  });
  test('play creates three deterministic SkillSheet-driven questions', () {
    final a = GameEngine.startClientInterview(
      atClientInterview(seed: 7, mismatch: true),
      'client-app',
    );
    final b = GameEngine.startClientInterview(
      atClientInterview(seed: 7, mismatch: true),
      'client-app',
    );
    expect(a.clientInterviews.single.questions.length, 3);
    expect(
      a.clientInterviews.single.toJson(),
      b.clientInterviews.single.toJson(),
    );
    expect(
      a.clientInterviews.single.questions.any(
        (q) =>
            q.category == ClientInterviewQuestionCategory.technicalExperience,
      ),
      isTrue,
    );
    expect(
      a.clientInterviews.single.questions.any((q) => q.mismatch > 0),
      isTrue,
    );
  });
  test(
    'actual ability drives answer while inflated sheet raises vague risk',
    () {
      final honest = GameEngine.startClientInterview(
        atClientInterview(seed: 8),
        'client-app',
      ).clientInterviews.single;
      final inflated = GameEngine.startClientInterview(
        atClientInterview(seed: 8, mismatch: true),
        'client-app',
      ).clientInterviews.single;
      final hi = inflated.questions.indexWhere((q) => q.mismatch > 0);
      expect(hi, isNonNegative);
      final ie = atClientInterview(seed: 8, mismatch: true).engineers.first,
          ip = atClientInterview(seed: 8, mismatch: true).proposals.first;
      final answer = ClientInterviewEngine.answer(
        ie,
        ip.project,
        inflated.questions[hi],
      );
      expect(answer.vague, isTrue);
      expect(
        honest.employeeAnswers.first.quality,
        greaterThanOrEqualTo(inflated.employeeAnswers.first.quality),
      );
    },
  );
  test('three follow-ups complete result and selection continues', () {
    var s = GameEngine.startClientInterview(
      atClientInterview(seed: 12),
      'client-app',
    );
    for (var i = 0; i < 3; i++) {
      final session = s.clientInterviews.single;
      s = GameEngine.chooseClientInterviewFollowUp(
        s,
        session.id,
        ClientInterviewFollowUp.letEmployeeHandle,
      );
    }
    expect(s.clientInterviews.single.completed, isTrue);
    expect(s.clientInterviews.single.playerFollowUps.length, 3);
    expect(
      s.proposals.single.status != ApplicationStatus.active ||
          s.proposals.single.currentStepIndex >
              atClientInterview(seed: 12).proposals.single.currentStepIndex,
      isTrue,
    );
  });
  test('auto resolve completes and save round-trips', () {
    final s = GameEngine.autoResolveClientInterview(
      atClientInterview(seed: 14),
      'client-app',
    );
    expect(s.clientInterviews.single.completed, isTrue);
    expect(
      s.clientInterviews.single.playerFollowUps,
      everyElement(ClientInterviewFollowUp.letEmployeeHandle),
    );
    expect(GameState.fromJson(s.toJson()).toJson(), s.toJson());
  });
  test('aggressive mismatch can deep dive and affects trust', () {
    var found = false;
    for (var seed = 1; seed < 100 && !found; seed++) {
      var s = GameEngine.startClientInterview(
        atClientInterview(seed: seed, mismatch: true),
        'client-app',
      );
      final before = s.engineers.first.companyTrust;
      for (var i = 0; i < 3; i++) {
        final session = s.clientInterviews.single;
        final q = session.questions[session.currentQuestionIndex];
        final choice = q.category == ClientInterviewQuestionCategory.leadership
            ? ClientInterviewFollowUp.emphasizeLeadership
            : q.category == ClientInterviewQuestionCategory.industryExperience
            ? ClientInterviewFollowUp.emphasizeIndustry
            : ClientInterviewFollowUp.emphasizeTechnical;
        s = GameEngine.chooseClientInterviewFollowUp(s, session.id, choice);
      }
      if (s.clientInterviews.single.deepDiveOccurred) {
        found = true;
        expect(s.engineers.first.companyTrust, lessThanOrEqualTo(before));
      }
    }
    expect(found, isTrue);
  });
}
