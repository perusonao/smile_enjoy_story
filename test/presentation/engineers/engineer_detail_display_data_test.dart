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
    List<ProjectProposal> proposals = const [],
  }) {
    final base = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 301));
    return base.copyWith(
      engineers: [engineer],
      company: base.company.copyWith(engineerIds: [engineer.id]),
      skillSheets: skillSheet == null ? const [] : [skillSheet],
      activeAssignments: assignment == null ? const [] : [assignment],
      proposals: proposals,
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

  test(
    'uses the pending client interview proposal for both status details and action target',
    () {
      final engineer = buildEngineer(
        id: 'eng-parallel',
        profile: buildApplicant(id: 'app-parallel', name: '並行 提案'),
      );
      final firstProject = buildProject(
        id: 'project-first',
        title: '先行の上位面談案件',
      );
      final pendingInterviewProject = buildProject(
        id: 'project-interview',
        title: '客先面談待ち案件',
      );
      final clientInterviewIndex = pendingInterviewProject.selectionFlow.steps
          .indexOf(SelectionStep.clientInterview);
      final display = EngineerDetailDisplayFactory.create(
        stateWith(
          engineer,
          proposals: [
            ProjectProposal(
              id: 'proposal-first',
              engineerId: engineer.id,
              project: firstProject,
              proposedWeek: 1,
              stage: ProposalStage.proposed,
              currentStepIndex: 1,
            ),
            ProjectProposal(
              id: 'proposal-client-interview',
              engineerId: engineer.id,
              project: pendingInterviewProject,
              proposedWeek: 2,
              stage: ProposalStage.proposed,
              currentStepIndex: clientInterviewIndex,
            ),
          ],
        ),
        engineer.id,
      )!;

      expect(
        display.currentStatus.state,
        EmployeeWorkflowState.clientInterviewActionRequired,
      );
      expect(display.currentStatus.activeProposal!.project.title, '客先面談待ち案件');
      expect(
        display.currentStatus.clientInterviewApplicationId,
        'proposal-client-interview',
      );
    },
  );

  test(
    'keeps the single pending client interview proposal as the status target',
    () {
      final engineer = buildEngineer(id: 'eng-single');
      final project = buildProject(id: 'project-single', title: '単一面談案件');
      final clientInterviewIndex = project.selectionFlow.steps.indexOf(
        SelectionStep.clientInterview,
      );

      final display = EngineerDetailDisplayFactory.create(
        stateWith(
          engineer,
          proposals: [
            ProjectProposal(
              id: 'proposal-single',
              engineerId: engineer.id,
              project: project,
              proposedWeek: 1,
              stage: ProposalStage.proposed,
              currentStepIndex: clientInterviewIndex,
            ),
          ],
        ),
        engineer.id,
      )!;

      expect(display.currentStatus.activeProposal!.project.title, '単一面談案件');
      expect(
        display.currentStatus.clientInterviewApplicationId,
        'proposal-single',
      );
    },
  );

  test(
    'does not create a client interview action target for other active steps',
    () {
      final engineer = buildEngineer(id: 'eng-no-client-interview');
      final project = buildProject(id: 'project-other-step');

      final display = EngineerDetailDisplayFactory.create(
        stateWith(
          engineer,
          proposals: [
            ProjectProposal(
              id: 'proposal-other-step',
              engineerId: engineer.id,
              project: project,
              proposedWeek: 1,
              stage: ProposalStage.proposed,
              currentStepIndex: 1,
            ),
          ],
        ),
        engineer.id,
      )!;

      expect(
        display.currentStatus.state,
        EmployeeWorkflowState.waitingSelectionResult,
      );
      expect(display.currentStatus.clientInterviewApplicationId, isNull);
      expect(display.currentStatus.activeProposal!.id, 'proposal-other-step');
    },
  );
}
