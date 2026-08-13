import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

/// A clean-slate state (no founder engineers/projects) so each test can set
/// up exactly the scenario it needs.
GameState _emptyState({int seed = 42}) {
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
  group('Weekly simulation', () {
    test('week progresses by exactly 1 each turn', () {
      var state = GameEngine.newGame(seed: 1);
      expect(state.week, 1);
      state = GameEngine.advanceWeek(state);
      expect(state.week, 2);
      state = GameEngine.advanceWeek(state);
      expect(state.week, 3);
    });

    test('waiting engineers still cost salary each week', () {
      final engineer = buildEngineer(
        id: 'waiting-1',
        salary: 400000,
        status: EngineerStatus.waiting,
      );
      final state = _emptyState().copyWith(engineers: [engineer]);
      final cashBefore = state.company.cash;

      final next = GameEngine.advanceWeek(state);

      final expectedSalary = (400000 / 4).round();
      expect(next.company.cash, cashBefore - expectedSalary - weeklyFixedCost);
      expect(next.stats.cumulativeSalary, expectedSalary);
      expect(next.stats.cumulativeFixedCost, weeklyFixedCost);
      expect(next.stats.waitingWeeks, 1);
    });

    test('revenue is added for assigned engineers and duration counts down', () {
      final engineer = buildEngineer(
        id: 'assigned-1',
        salary: 0,
        status: EngineerStatus.assigned,
      );
      final project = buildProject(
        id: 'proj-1',
        monthlyRate: 800000,
        durationWeeks: 3,
      );
      final assignment = ActiveAssignment(
        engineerId: engineer.id,
        project: project,
        remainingWeeks: 3,
        assignedWeek: 1,
      );
      final state = _emptyState().copyWith(
        engineers: [engineer],
        activeAssignments: [assignment],
      );

      final next = GameEngine.advanceWeek(state);

      final expectedRevenue = (800000 / 4).round();
      expect(next.lastWeekRevenue, expectedRevenue);
      expect(next.stats.cumulativeRevenue, expectedRevenue);
      final updated = next.activeAssignments.firstWhere(
        (a) => a.engineerId == engineer.id,
      );
      expect(updated.remainingWeeks, 2);
      expect(next.engineerById(engineer.id).status, EngineerStatus.assigned);
    });

    test('a contract that reaches 0 remaining weeks completes and frees the engineer', () {
      final engineer = buildEngineer(
        id: 'assigned-2',
        salary: 0,
        status: EngineerStatus.assigned,
      );
      final project = buildProject(
        id: 'proj-2',
        monthlyRate: 400000,
        durationWeeks: 1,
      );
      final assignment = ActiveAssignment(
        engineerId: engineer.id,
        project: project,
        remainingWeeks: 1,
        assignedWeek: 1,
      );
      final state = _emptyState().copyWith(
        engineers: [engineer],
        activeAssignments: [assignment],
      );

      final next = GameEngine.advanceWeek(state);

      expect(next.activeAssignments, isEmpty);
      expect(next.engineerById(engineer.id).status, EngineerStatus.waiting);
      // The final week of the contract still counts as revenue.
      expect(next.lastWeekRevenue, (400000 / 4).round());
    });

    test('a proposal progresses through interview to assignment over two turns', () {
      final engineer = buildEngineer(
        id: 'candidate-1',
        salary: 0,
        status: EngineerStatus.waiting,
      );
      final project = buildProject(id: 'proj-3', applicationDeadlineWeek: 20);
      var state = _emptyState().copyWith(
        engineers: [engineer],
        openProjects: [ProjectEntry(project: project, postedWeek: 1)],
      );

      state = GameEngine.proposeEngineer(state, engineer.id, project.id);
      expect(state.engineerById(engineer.id).status, EngineerStatus.proposed);
      expect(state.stats.proposalCount, 1);
      expect(state.isProjectOpenForProposal(project.id), isFalse);

      // Turn 1: the project interview resolves (pass or fail — both are
      // valid outcomes of the seeded roll, so branch on what happened).
      final afterInterview = GameEngine.advanceWeek(state);
      expect(afterInterview.stats.projectInterviewCount, 1);
      final resolved = afterInterview.proposals.firstWhere(
        (p) => p.engineerId == engineer.id,
        orElse: () => afterInterview.proposals.first,
      );

      if (resolved.stage == ProposalStage.interviewPassed) {
        expect(
          afterInterview.engineerById(engineer.id).status,
          EngineerStatus.interviewScheduled,
        );
        expect(afterInterview.stats.projectInterviewSuccess, 1);

        // Turn 2: assignment starts.
        final afterAssignment = GameEngine.advanceWeek(afterInterview);
        expect(
          afterAssignment.engineerById(engineer.id).status,
          EngineerStatus.assigned,
        );
        expect(afterAssignment.activeAssignments, hasLength(1));
        expect(afterAssignment.stats.assignmentsStarted, 1);
        expect(
          afterAssignment.proposals.any((p) => p.engineerId == engineer.id),
          isFalse,
        );
      } else {
        expect(resolved.stage, ProposalStage.interviewFailed);
        expect(
          afterInterview.engineerById(engineer.id).status,
          EngineerStatus.waiting,
        );
        expect(afterInterview.stats.projectInterviewSuccess, 0);
      }
    });

    test('waiting streak increments week over week and resets once no longer waiting (§17-18)', () {
      final engineer = buildEngineer(
        id: 'waiter-1',
        salary: 400000,
        status: EngineerStatus.waiting,
      );
      var state = _emptyState().copyWith(engineers: [engineer]);
      expect(state.waitingStreakFor('waiter-1'), 0);

      state = GameEngine.advanceWeek(state);
      expect(state.waitingStreakFor('waiter-1'), 1);
      // Waiting-week cost this week should match salary / 4 (§18).
      expect(state.lastWeekSalary, (400000 / 4).round());

      state = GameEngine.advanceWeek(state);
      expect(state.waitingStreakFor('waiter-1'), 2);

      state = GameEngine.advanceWeek(state);
      expect(state.waitingStreakFor('waiter-1'), 3);

      // Once proposed, the streak is cleared even before the interview
      // resolves — they're no longer "waiting".
      final project = buildProject(id: 'proj-streak', applicationDeadlineWeek: 20);
      state = state.copyWith(openProjects: [ProjectEntry(project: project, postedWeek: state.week)]);
      state = GameEngine.proposeEngineer(state, 'waiter-1', 'proj-streak');
      expect(state.waitingStreakFor('waiter-1'), 0);
    });

    test('lastWeekExpense breaks down into salary + recruitment cost + fixed cost (§7)', () {
      final engineer = buildEngineer(id: 'w1', salary: 400000, status: EngineerStatus.waiting);
      var state = _emptyState().copyWith(engineers: [engineer]);
      state = GameEngine.postRecruitmentMedia(state, RecruitmentMediaType.engineerCareer);
      final mediaCost = recruitmentMediaConfigs[RecruitmentMediaType.engineerCareer]!.cost;

      final next = GameEngine.advanceWeek(state);

      final expectedSalary = (400000 / 4).round();
      expect(next.lastWeekSalary, expectedSalary);
      expect(next.lastWeekRecruitmentCost, mediaCost);
      expect(
        next.lastWeekExpense,
        expectedSalary + mediaCost + weeklyFixedCost,
      );
      expect(next.lastWeekProfit, next.lastWeekRevenue - next.lastWeekExpense);
    });
  });
}
