import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

const _generalAffairs = GeneralAffairsStaff(
  id: 'ga-payroll-finance',
  name: 'テスト総務',
  salary: 280000,
  flavor: '',
);

GameState _normalState({List<Engineer> engineers = const []}) {
  return GameEngine.newGame(seed: 71).copyWith(
    engineers: engineers,
    generalAffairsStaff: _generalAffairs,
    activeAssignments: const [],
    pendingHires: const [],
  );
}

void main() {
  group('PAYROLL-1B.1 FinanceEngine delegation', () {
    test('matches PayrollEngine for multiple engineers plus General Affairs', () {
      final state = _normalState(
        engineers: [
          buildEngineer(id: 'e1', salary: 310001),
          buildEngineer(id: 'e2', salary: 420002),
        ],
      );
      final expected = PayrollEngine.calculateMonthly(
        PayrollInput(
          engineers: state.engineers,
          generalAffairsStaff: state.generalAffairsStaff,
          isPrologueActive: state.prologueState.active,
          hasStartedPrologueAssignment: state.activeAssignments.isNotEmpty,
        ),
      ).totalSalary;

      expect(FinanceEngine.monthlySalaryTotal(state), expected);
      expect(expected, 1010003);
    });

    test('March prologue excludes the materialized pre-join engineer', () {
      final state = PrologueEngine.newGame(seed: 5).copyWith(
        engineers: [buildEngineer(id: 'march-hire', salary: 400000)],
        generalAffairsStaff: _generalAffairs,
        activeAssignments: const [],
      );

      expect(state.prologueState.active, isTrue);
      expect(FinanceEngine.monthlySalaryTotal(state), 280000);
    });

    test('includes the engineer once the first April assignment has started', () {
      final engineer = buildEngineer(
        id: 'april-hire',
        salary: 400000,
        status: EngineerStatus.assigned,
      );
      final project = buildProject(id: 'april-project');
      final state = PrologueEngine.newGame(seed: 5).copyWith(
        engineers: [engineer],
        generalAffairsStaff: _generalAffairs,
        activeAssignments: [
          ActiveAssignment(
            engineerId: engineer.id,
            project: project,
            remainingWeeks: 4,
            assignedWeek: 1,
          ),
        ],
      );

      expect(state.prologueState.active, isTrue);
      expect(FinanceEngine.monthlySalaryTotal(state), 680000);
    });

    test('legacy engineer statuses remain full-pay', () {
      final state = _normalState(
        engineers: [
          buildEngineer(id: 'waiting', salary: 100001),
          buildEngineer(
            id: 'assigned',
            salary: 200002,
            status: EngineerStatus.assigned,
          ),
          buildEngineer(
            id: 'proposed',
            salary: 300003,
            status: EngineerStatus.proposed,
          ),
          buildEngineer(
            id: 'interview',
            salary: 400004,
            status: EngineerStatus.interviewScheduled,
          ),
        ],
      );

      expect(FinanceEngine.monthlySalaryTotal(state), 1280010);
    });

    test('PendingHire stays outside the pre-transition HUD payroll roster', () {
      final applicant = buildApplicant(id: 'pending-applicant');
      final state = _normalState(
        engineers: [buildEngineer(id: 'joined', salary: 350000)],
      ).copyWith(
        pendingHires: [
          PendingHire(
            id: 'pending-hire',
            applicant: applicant,
            salary: 450000,
            decisionWeek: 3,
            joinWeek: 4,
          ),
        ],
      );

      expect(FinanceEngine.monthlySalaryTotal(state), 630000);
    });
  });
}
