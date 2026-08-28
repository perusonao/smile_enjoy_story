import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/presentation/engineers/engineer_detail_display_data.dart';

import '../../game/test_helpers.dart';

void main() {
  GameState stateWith(
    Engineer engineer, {
    SkillSheet? skillSheet,
    ActiveAssignment? assignment,
  }) {
    final base = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 301));
    return base.copyWith(
      engineers: [engineer],
      company: base.company.copyWith(engineerIds: [engineer.id]),
      skillSheets: skillSheet == null ? const [] : [skillSheet],
      activeAssignments: assignment == null ? const [] : [assignment],
    );
  }

  test(
    'projects stored SkillSheet values without recreating them from actual skills',
    () {
      final engineer = buildEngineer(
        id: 'eng-1',
        profile: buildApplicant(id: 'app-1', name: '山田 花子'),
      );
      final sheet = SkillSheet.fromActual(
        employeeId: engineer.id,
        languageMonths: {ProgrammingLanguage.java: 60},
        skills: const TechSkillLevels(
          database: 0,
          network: 0,
          infrastructure: 0,
          frontend: 0,
          backend: 4,
          leader: 0,
          manager: 0,
        ),
        week: 7,
      );

      final display = EngineerDetailDisplayFactory.create(
        stateWith(engineer, skillSheet: sheet),
        engineer.id,
      )!;

      expect(display.skillSheet.sheet, same(sheet));
      expect(
        display.skillSheet.actualPrimaryLanguageMonths,
        engineer.profile
            .skillFor(engineer.profile.mainLanguage)
            .actualExperienceMonths,
      );
      expect(
        display
            .skillSheet
            .sheet!
            .displayedLanguageExperience[ProgrammingLanguage.java],
        60,
      );
      expect(display.skillSheet.sheet!.displayedBackend, 4);
    },
  );

  test(
    'projects the persisted current assignment and safely falls back when absent',
    () {
      final engineer = buildEngineer(
        id: 'eng-2',
        profile: buildApplicant(id: 'app-2', name: '佐藤 次郎'),
      );
      final project = buildProject(
        id: 'project-1',
        clientId: sampleClients.first.id,
        title: '長期保守案件',
      );
      final assigned = stateWith(
        engineer,
        assignment: ActiveAssignment(
          engineerId: engineer.id,
          project: project,
          remainingWeeks: 8,
          assignedWeek: 3,
        ),
      );

      final assignedDisplay = EngineerDetailDisplayFactory.create(
        assigned,
        engineer.id,
      )!;
      final absentDisplay = EngineerDetailDisplayFactory.create(
        stateWith(engineer),
        engineer.id,
      )!;

      expect(
        assignedDisplay.currentStatus.state,
        EmployeeWorkflowState.assigned,
      );
      expect(
        assignedDisplay.currentAssignment!.assignment.project.title,
        '長期保守案件',
      );
      expect(absentDisplay.currentAssignment, isNull);
      expect(EngineerDetailDisplayFactory.create(assigned, 'unknown'), isNull);
    },
  );

  test(
    'keeps a missing legacy SkillSheet unavailable instead of deriving one',
    () {
      final engineer = buildEngineer(
        id: 'eng-3',
        profile: buildApplicant(id: 'app-3', name: '高橋 三郎'),
      );

      final display = EngineerDetailDisplayFactory.create(
        stateWith(engineer),
        engineer.id,
      )!;

      expect(display.skillSheet.sheet, isNull);
      expect(display.currentStatus.state, EmployeeWorkflowState.waiting);
    },
  );
}
