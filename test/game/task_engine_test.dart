import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

GameState _emptyState({int seed = 1}) {
  final base = GameEngine.newGame(seed: seed);
  return base.copyWith(
    engineers: const [],
    activeAssignments: const [],
    applicants: const [],
    openProjects: const [],
    listings: const [],
    proposals: const [],
    pendingHires: const [],
    waitingStreak: const {},
  );
}

void main() {
  group('TaskEngine', () {
    test('a healthy, empty state produces no tasks', () {
      final state = _emptyState().copyWith(
        // The default `_emptyState` still has no active listing, which by
        // itself generates an info task — post one so this really is a
        // "nothing to do" baseline.
        listings: [
          const RecruitmentListing(
            id: 'l1',
            type: RecruitmentMediaType.freeWork,
            postedWeek: 1,
            durationWeeks: 4,
          ),
        ],
      );
      expect(TaskEngine.generateTasks(state), isEmpty);
    });

    test('an uninterviewed applicant produces a warning task', () {
      final applicant = buildApplicant(id: 'a1');
      final state = _emptyState().copyWith(
        applicants: [
          ApplicantEntry(applicant: applicant, appearedWeek: 1, source: RecruitmentMediaType.freeWork),
        ],
      );
      final tasks = TaskEngine.generateTasks(state);
      final interviewTask = tasks.where((t) => t.id == 'interview-pending').single;
      expect(interviewTask.priority, TaskPriority.warning);
      expect(interviewTask.targetType, TaskTargetType.recruitmentTab);
    });

    test('waiting streak escalates from warning (2 weeks) to critical (3+ weeks)', () {
      final e1 = buildEngineer(id: 'e1', status: EngineerStatus.waiting);
      final e2 = buildEngineer(id: 'e2', status: EngineerStatus.waiting);
      final state = _emptyState().copyWith(
        engineers: [e1, e2],
        waitingStreak: {'e1': 2, 'e2': 3},
      );
      final tasks = TaskEngine.generateTasks(state);

      final warning = tasks.where((t) => t.id == 'waiting-warning-e1').single;
      expect(warning.priority, TaskPriority.warning);
      expect(warning.targetType, TaskTargetType.employeeDetail);
      expect(warning.targetId, 'e1');

      final critical = tasks.where((t) => t.id == 'waiting-critical-e2').single;
      expect(critical.priority, TaskPriority.critical);
      expect(critical.targetId, 'e2');
    });

    test('a fresh (1-week) waiter is summarized as a single aggregate task', () {
      final e1 = buildEngineer(id: 'e1', status: EngineerStatus.waiting);
      final state = _emptyState().copyWith(
        engineers: [e1],
        waitingStreak: {'e1': 1},
      );
      final tasks = TaskEngine.generateTasks(state);
      final task = tasks.where((t) => t.id == 'waiting-fresh').single;
      expect(task.priority, TaskPriority.warning);
      expect(task.title, contains('1'));
    });

    test('a projected month-end cash shortfall produces a critical cash-danger task (§11, §16)', () {
      final engineer = buildEngineer(id: 'costly', salary: 900000, status: EngineerStatus.waiting);
      final state = _emptyState().copyWith(engineers: [engineer]);
      final poor = state.copyWith(company: state.company.copyWith(cash: 1000));
      final tasks = TaskEngine.generateTasks(poor);
      expect(tasks.where((t) => t.id == 'cash-danger').single.priority, TaskPriority.critical);
    });

    test('a comfortable cash runway produces no cash-danger or cash-runway task', () {
      final state = _emptyState();
      final tasks = TaskEngine.generateTasks(state);
      expect(tasks.where((t) => t.id == 'cash-danger'), isEmpty);
      expect(tasks.where((t) => t.id == 'cash-runway-danger'), isEmpty);
      expect(tasks.where((t) => t.id == 'cash-runway-caution'), isEmpty);
    });

    test('a contract ending within a week produces a critical task', () {
      final engineer = buildEngineer(id: 'e1', status: EngineerStatus.assigned);
      final project = buildProject(id: 'p1');
      final state = _emptyState().copyWith(
        engineers: [engineer],
        activeAssignments: [
          ActiveAssignment(engineerId: 'e1', project: project, remainingWeeks: 1, assignedWeek: 1),
        ],
      );
      final tasks = TaskEngine.generateTasks(state);
      final task = tasks.where((t) => t.id == 'contract-ending-e1').single;
      expect(task.priority, TaskPriority.critical);
      expect(task.targetType, TaskTargetType.employeeDetail);
    });

    test('a proposal resolved this week produces an interview-results task', () {
      final engineer = buildEngineer(id: 'e1');
      final project = buildProject(id: 'p1');
      final state = _emptyState().copyWith(
        engineers: [engineer],
        proposals: [
          ProjectProposal(
            id: 'prop1',
            engineerId: 'e1',
            project: project,
            proposedWeek: 1,
            stage: ProposalStage.interviewPassed,
            interviewWeek: 1,
            assignWeek: 2,
          ),
        ],
      );
      final tasks = TaskEngine.generateTasks(state);
      expect(
        tasks.where((t) => t.id == 'project-interview-results').single.targetType,
        TaskTargetType.interviewResults,
      );
    });

    test('a project posted this week produces an info-level new-projects task', () {
      final project = buildProject(id: 'p1');
      final state = _emptyState().copyWith(
        openProjects: [ProjectEntry(project: project, postedWeek: 1)],
      );
      final tasks = TaskEngine.generateTasks(state);
      final task = tasks.where((t) => t.id == 'new-projects').single;
      expect(task.priority, TaskPriority.info);
      expect(task.targetType, TaskTargetType.projectsTab);
    });

    test('no active recruitment listing produces an info task', () {
      final state = _emptyState();
      final task = TaskEngine.generateTasks(state).where((t) => t.id == 'no-active-listing').single;
      expect(task.priority, TaskPriority.info);
    });

    test('a pending hire produces an info task naming the next join week', () {
      final applicant = buildApplicant(id: 'a1', name: 'テスト花子');
      final state = _emptyState().copyWith(
        pendingHires: [
          PendingHire(id: 'ph1', applicant: applicant, salary: 400000, decisionWeek: 1, joinWeek: 3),
        ],
      );
      final task = TaskEngine.generateTasks(state).where((t) => t.id == 'pending-hires').single;
      expect(task.priority, TaskPriority.info);
      expect(task.subtitle, contains('Week 3'));
    });
  });
}
