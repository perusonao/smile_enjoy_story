import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  test('risk classification covers honest moderate aggressive and extreme', () {
    final s = GameEngine.newGame(seed: 1),
        e = s.engineers.first,
        base = s.skillSheetFor(e.id),
        lang = e.profile.mainLanguage,
        actual = e.profile.skillFor(lang).actualExperienceMonths;
    SkillSheet at(int months, int backend, int leader) => base.copyWith(
      displayedLanguageExperience: {
        ...base.displayedLanguageExperience,
        lang: actual + months,
      },
      displayedBackend: backend,
      displayedLeader: leader,
    );
    expect(SalesEngine.riskFor(e, base), SkillSheetRisk.honest);
    expect(
      SalesEngine.riskFor(
        e,
        at(12, e.profile.techSkills.backend, e.profile.techSkills.leader),
      ),
      SkillSheetRisk.moderate,
    );
    expect(
      SalesEngine.riskFor(
        e,
        at(24, e.profile.techSkills.backend + 2, e.profile.techSkills.leader),
      ),
      SkillSheetRisk.aggressive,
    );
    expect(
      SalesEngine.riskFor(
        e,
        at(
          36,
          e.profile.techSkills.backend + 2,
          e.profile.techSkills.leader + 2,
        ),
      ),
      SkillSheetRisk.extreme,
    );
  });
  test('SkillSheet changes offer matching but not actual selection rate', () {
    final s = GameEngine.newGame(seed: 2),
        e = s.engineers.first,
        p = s.openProjects.first.project,
        base = s.skillSheetFor(e.id);
    final before = SalesEngine.skillSheetMatch(base, p);
    final inflated = base.copyWith(
      displayedDatabase: 5,
      displayedNetwork: 5,
      displayedInfrastructure: 5,
      displayedFrontend: 5,
      displayedBackend: 5,
      displayedLeader: 5,
      displayedManager: 5,
      displayedLanguageExperience: {
        for (final l in ProgrammingLanguage.values)
          l: e.profile.skillFor(l).actualExperienceMonths + 36,
      },
    );
    expect(
      SalesEngine.skillSheetMatch(inflated, p),
      greaterThanOrEqualTo(before),
    );
    final rate = SelectionEngine.successRate(
      e,
      p,
      SelectionStep.technicalInterview,
    );
    final editedState = GameEngine.editSkillSheet(s, inflated);
    expect(
      SelectionEngine.successRate(
        editedState.engineerById(e.id),
        p,
        SelectionStep.technicalInterview,
      ),
      rate,
    );
  });
  test('weekly summary prioritizes and caps important results with CTA', () {
    final s = GameEngine.newGame(seed: 3).copyWith(
      events: [
        const GameLogEntry(week: 1, message: 'normal'),
        const GameLogEntry(
          week: 1,
          message: 'pass',
          category: GameLogCategory.interviewPassed,
        ),
        const GameLogEntry(
          week: 1,
          message: 'fail',
          category: GameLogCategory.interviewFailed,
        ),
        const GameLogEntry(
          week: 1,
          message: 'offer',
          category: GameLogCategory.offerReceived,
        ),
        const GameLogEntry(
          week: 1,
          message: 'interview offer',
          category: GameLogCategory.interviewOffer,
        ),
      ],
    );
    final rows = WeeklySummaryEngine.importantFor(s);
    expect(rows, hasLength(3));
    expect(rows.map((r) => r.event.message), [
      'offer',
      'interview offer',
      'fail',
    ]);
    expect(rows.every((r) => r.actionLabel != null), isTrue);
    expect(WeeklySummaryEngine.resultsFor(s).length, 5);
  });
  test('selection failure returns employee to selling', () {
    var found = false;
    for (var seed = 1; seed < 100 && !found; seed++) {
      var s = GameEngine.newGame(seed: seed);
      final e = s.engineers.first, p = s.openProjects.first.project;
      s = s.copyWith(
        engineers: [
          e.copyWith(salesStatus: SalesStatus.interviewing),
          ...s.engineers.skip(1),
        ],
        proposals: [
          ProjectProposal(
            id: 'p',
            engineerId: e.id,
            project: p,
            proposedWeek: 1,
            stage: ProposalStage.proposed,
            currentStepIndex: 1,
          ),
        ],
      );
      final n = GameEngine.advanceWeek(s);
      if (n.proposals.single.status == ApplicationStatus.rejected) {
        expect(n.engineerById(e.id).salesStatus, SalesStatus.selling);
        found = true;
      }
    }
    expect(found, isTrue);
  });
  test('employee-first loop reaches assignment without direct proposal', () {
    var completed = false;
    for (var seed = 1; seed <= 40 && !completed; seed++) {
      var s = GameEngine.newGame(seed: seed);
      final employee = s.engineers.first;
      s = GameEngine.editSkillSheet(s, s.skillSheetFor(employee.id));
      s = GameEngine.startSales(s, employee.id);
      for (var week = 0; week < 47 && s.status == GameStatus.playing; week++) {
        for (final interview
            in s.interviewOffers
                .where(
                  (o) =>
                      o.employeeId == employee.id &&
                      o.status == InterviewOfferStatus.pending,
                )
                .toList()) {
          s = GameEngine.acceptInterviewOffer(s, interview.id);
        }
        for (final interview
            in s.proposals
                .where(
                  (p) =>
                      p.engineerId == employee.id &&
                      p.status == ApplicationStatus.active &&
                      p.currentStep == SelectionStep.clientInterview,
                )
                .toList()) {
          s = GameEngine.autoResolveClientInterview(s, interview.id);
        }
        for (final offer
            in s.offers
                .where(
                  (o) =>
                      o.employeeId == employee.id &&
                      o.status == OfferStatus.pending,
                )
                .toList()) {
          s = GameEngine.acceptOffer(s, offer.id);
        }
        if (s.engineerById(employee.id).status == EngineerStatus.waiting &&
            s.engineerById(employee.id).salesStatus != SalesStatus.selling) {
          s = GameEngine.startSales(s, employee.id);
        }
        s = GameEngine.advanceWeek(s);
        if (s.assignmentForEngineer(employee.id) != null) {
          completed = true;
          break;
        }
      }
    }
    expect(completed, isTrue);
  });
}
