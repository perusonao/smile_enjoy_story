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

/// Advances [state] by [count] weeks in a row.
GameState _advance(GameState state, int count) {
  var next = state;
  for (var i = 0; i < count; i++) {
    next = GameEngine.advanceWeek(next);
  }
  return next;
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

    test(
      'waiting engineers cost nothing week-to-week but draw full salary at month-end (§7-8)',
      () {
        final engineer = buildEngineer(
          id: 'waiting-1',
          salary: 400000,
          status: EngineerStatus.waiting,
        );
        final state = _emptyState().copyWith(engineers: [engineer]);
        final cashBefore = state.company.cash;

        // Weeks 2-3 aren't month-end: no cash moves at all.
        var next = GameEngine.advanceWeek(state);
        expect(next.company.cash, cashBefore);
        next = GameEngine.advanceWeek(next);
        expect(next.company.cash, cashBefore);

        // Week 4 (month-end): full monthly salary + rent + other fixed cost
        // land all at once. Waiting engineers draw 100% salary too.
        next = GameEngine.advanceWeek(next);
        final rent = officeConfigs[OfficeType.smallOffice]!.monthlyRent;
        expect(next.company.cash, cashBefore - 400000 - rent - otherMonthlyFixedCost);
        expect(next.stats.cumulativeSalary, 400000);
        expect(next.stats.cumulativeRent, rent);
        expect(next.stats.cumulativeFixedCost, otherMonthlyFixedCost);
        expect(next.stats.waitingWeeks, 3);
      },
    );

    test(
      'an assigned engineer\'s revenue becomes accounts receivable at month-end, not immediate cash (§9, §13)',
      () {
        final engineer = buildEngineer(
          id: 'assigned-1',
          salary: 0,
          status: EngineerStatus.assigned,
        );
        final project = buildProject(
          id: 'proj-1',
          clientId: 'client-axis-soft', // 支払30日
          monthlyRate: 800000,
          durationWeeks: 12,
        );
        final assignment = ActiveAssignment(
          engineerId: engineer.id,
          project: project,
          remainingWeeks: 12,
          assignedWeek: 1,
        );
        final state = _emptyState().copyWith(
          engineers: [engineer],
          activeAssignments: [assignment],
        );
        final cashBefore = state.company.cash;

        final next = _advance(state, 3); // through week 4 (month-end)

        expect(next.stats.cumulativeRevenue, 800000);
        expect(next.stats.cumulativeCashCollected, 0);
        expect(next.accountsReceivable, hasLength(1));
        final ar = next.accountsReceivable.single;
        expect(ar.status, ArStatus.pending);
        expect(ar.amount, 800000);
        expect(ar.clientId, 'client-axis-soft');
        expect(ar.generatedMonth, 1);
        expect(ar.dueMonth, 2); // 30日サイト → 翌月末

        final rent = officeConfigs[OfficeType.smallOffice]!.monthlyRent;
        expect(next.company.cash, cashBefore - rent - otherMonthlyFixedCost);
        final updated = next.activeAssignments.firstWhere(
          (a) => a.engineerId == engineer.id,
        );
        expect(updated.remainingWeeks, 9);
        expect(next.engineerById(engineer.id).status, EngineerStatus.assigned);
      },
    );

    test('a 30-day payment term client\'s AR is collected at the next month-end (§14-15)', () {
      final engineer = buildEngineer(id: 'e30', salary: 0, status: EngineerStatus.assigned);
      final project = buildProject(
        id: 'p30',
        clientId: 'client-axis-soft', // 支払30日
        monthlyRate: 700000,
      );
      final assignment = ActiveAssignment(
        engineerId: 'e30',
        project: project,
        remainingWeeks: 3, // completes exactly at week 4 (month 1's close)
        assignedWeek: 1,
      );
      var state = _emptyState().copyWith(
        engineers: [engineer],
        activeAssignments: [assignment],
      );

      state = _advance(state, 3); // week 4: AR generated, dueMonth 2
      expect(state.accountsReceivable.single.status, ArStatus.pending);
      expect(state.accountsReceivable.single.dueMonth, 2);

      state = _advance(state, 4); // week 8: month 2 closes → AR collected
      expect(state.accountsReceivable, hasLength(1));
      expect(state.accountsReceivable.single.status, ArStatus.paid);
      expect(state.stats.cumulativeCashCollected, 700000);
    });

    test('a 60-day payment term client\'s AR is collected two month-ends later (§14-15)', () {
      final engineer = buildEngineer(id: 'e60', salary: 0, status: EngineerStatus.assigned);
      final project = buildProject(
        id: 'p60',
        clientId: 'client-future-web', // 支払60日
        monthlyRate: 900000,
      );
      final assignment = ActiveAssignment(
        engineerId: 'e60',
        project: project,
        remainingWeeks: 3,
        assignedWeek: 1,
      );
      var state = _emptyState().copyWith(
        engineers: [engineer],
        activeAssignments: [assignment],
      );

      state = _advance(state, 3); // week 4: AR generated, dueMonth 3
      expect(state.accountsReceivable.single.dueMonth, 3);

      state = _advance(state, 4); // week 8: month 2 closes — not due yet
      expect(state.accountsReceivable.single.status, ArStatus.pending);
      expect(state.stats.cumulativeCashCollected, 0);

      state = _advance(state, 4); // week 12: month 3 closes — now collected
      expect(state.accountsReceivable.single.status, ArStatus.paid);
      expect(state.stats.cumulativeCashCollected, 900000);
    });

    test(
      'accounting profit and cash delta are computed independently (§20-21)',
      () {
        final engineer = buildEngineer(id: 'e1', salary: 0, status: EngineerStatus.assigned);
        final project = buildProject(
          id: 'p1',
          clientId: 'client-axis-soft',
          monthlyRate: 800000,
        );
        final assignment = ActiveAssignment(
          engineerId: 'e1',
          project: project,
          remainingWeeks: 12,
          assignedWeek: 1,
        );
        final state = _emptyState().copyWith(
          engineers: [engineer],
          activeAssignments: [assignment],
        );

        final next = _advance(state, 3);
        final closing = next.latestClosing!;
        // Revenue was recognized (¥800,000) but no cash arrived this month
        // (nothing was already due), while rent + fixed cost were paid —
        // so profit is positive while cash actually fell.
        expect(closing.accountingProfit, greaterThan(0));
        expect(closing.cashDelta, lessThan(0));
      },
    );

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
    });

    test('legacy single-interview proposal remains compatible over two turns', () {
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

    test('month-end closing breaks down salary + rent + fixed cost + recruitment cost (§20)', () {
      final engineer = buildEngineer(id: 'w1', salary: 400000, status: EngineerStatus.waiting);
      var state = _emptyState().copyWith(engineers: [engineer]);
      state = GameEngine.postRecruitmentMedia(state, RecruitmentMediaType.engineerCareer);
      final mediaCost = recruitmentMediaConfigs[RecruitmentMediaType.engineerCareer]!.cost;

      final next = _advance(state, 3); // week 4: month-end

      final closing = next.latestClosing!;
      final rent = officeConfigs[OfficeType.smallOffice]!.monthlyRent;
      expect(closing.salaryPaid, 400000);
      expect(closing.rentPaid, rent);
      expect(closing.otherFixedCost, otherMonthlyFixedCost);
      expect(closing.recruitmentCost, mediaCost);
      expect(
        closing.accountingProfit,
        closing.projectRevenue - 400000 - rent - otherMonthlyFixedCost - mediaCost,
      );
    });
  });
}
