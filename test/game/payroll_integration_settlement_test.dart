import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

const _generalAffairs = GeneralAffairsStaff(
  id: 'ga-payroll-settlement',
  name: 'テスト総務',
  salary: 280003,
  flavor: '',
);

GameState _monthEndState({
  List<Engineer> engineers = const [],
  List<PendingHire> pendingHires = const [],
}) {
  final state = GameEngine.newGame(seed: 73);
  return state.copyWith(
    company: state.company.copyWith(currentWeek: 3),
    engineers: engineers,
    generalAffairsStaff: _generalAffairs,
    activeAssignments: const [],
    applicants: const [],
    openProjects: const [],
    listings: const [],
    proposals: const [],
    pendingHires: pendingHires,
    monthAccrualSnapshot: const {},
  );
}

GameState _settle(GameState state) => GameEngine.advanceWeek(state);

void main() {
  group('PAYROLL-1B.2 GameEngine settlement delegation', () {
    test('identical roster snapshot matches PayrollEngine and settlement', () {
      final state = _monthEndState(
        engineers: [
          buildEngineer(id: 'e1', salary: 310001),
          buildEngineer(id: 'e2', salary: 420002),
        ],
      );
      final direct = PayrollEngine.calculateMonthly(
        PayrollInput(
          engineers: state.engineers,
          generalAffairsStaff: state.generalAffairsStaff,
          isPrologueActive: false,
          hasStartedPrologueAssignment: false,
        ),
      ).totalSalary;

      final settled = _settle(state);

      expect(settled.latestClosing!.salaryPaid, direct);
      expect(
        settled.latestClosing!.salaryPaid,
        FinanceEngine.monthlySalaryTotal(state),
      );
    });

    test('multiple engineers and General Affairs are counted exactly once', () {
      final state = _monthEndState(
        engineers: [
          buildEngineer(id: 'e1', salary: 310001),
          buildEngineer(id: 'e2', salary: 420002),
        ],
      );

      final closing = _settle(state).latestClosing!;
      const expectedSalary = 310001 + 420002 + 280003;

      expect(closing.salaryPaid, expectedSalary);
      expect(
        closing.cashDelta,
        closing.cashCollected -
            expectedSalary -
            closing.rentPaid -
            closing.otherFixedCost,
      );
    });

    test('waiting, selling, interviewing, and assigned remain full-pay', () {
      final engineers = [
        buildEngineer(id: 'waiting', salary: 110001),
        buildEngineer(
          id: 'selling',
          salary: 120002,
        ).copyWith(salesStatus: SalesStatus.selling),
        buildEngineer(
          id: 'interviewing',
          salary: 130003,
          status: EngineerStatus.interviewScheduled,
        ).copyWith(salesStatus: SalesStatus.interviewing),
        buildEngineer(
          id: 'assigned',
          salary: 140004,
          status: EngineerStatus.assigned,
        ).copyWith(salesStatus: SalesStatus.assigned),
      ];

      final closing = _settle(
        _monthEndState(engineers: engineers),
      ).latestClosing!;

      expect(
        closing.salaryPaid,
        110001 + 120002 + 130003 + 140004 + _generalAffairs.salary,
      );
    });

    test('PendingHire not yet materialized remains outside payroll', () {
      final pending = PendingHire(
        id: 'pending-later',
        applicant: buildApplicant(id: 'applicant-later'),
        salary: 510005,
        decisionWeek: 2,
        joinWeek: 5,
      );
      final state = _monthEndState(
        engineers: [buildEngineer(id: 'existing', salary: 210001)],
        pendingHires: [pending],
      );

      final settled = _settle(state);

      expect(
        settled.latestClosing!.salaryPaid,
        210001 + _generalAffairs.salary,
      );
      expect(settled.pendingHires, hasLength(1));
      expect(settled.engineers, hasLength(1));
    });

    test('PendingHire joining on month-end is included exactly once', () {
      final pending = PendingHire(
        id: 'pending-now',
        applicant: buildApplicant(id: 'applicant-now'),
        salary: 510005,
        decisionWeek: 2,
        joinWeek: 4,
      );
      final state = _monthEndState(
        engineers: [buildEngineer(id: 'existing', salary: 210001)],
        pendingHires: [pending],
      );
      final preAdvanceForecast = FinanceEngine.monthlySalaryTotal(state);

      final settled = _settle(state);

      expect(preAdvanceForecast, 210001 + _generalAffairs.salary);
      expect(
        settled.latestClosing!.salaryPaid,
        210001 + 510005 + _generalAffairs.salary,
      );
      expect(settled.pendingHires, isEmpty);
      expect(settled.engineers, hasLength(2));
      expect(
        settled.engineers.where(
          (engineer) => engineer.sourceApplicantId == pending.applicant.id,
        ),
        hasLength(1),
      );
    });

    test('closing, cash, and accounting invariants remain consistent', () {
      final state = _monthEndState(
        engineers: [buildEngineer(id: 'existing', salary: 310001)],
      );
      final cumulativeSalaryBefore = state.stats.cumulativeSalary;

      final settled = _settle(state);
      final closing = settled.latestClosing!;

      expect(closing.cashAfter - closing.cashBefore, closing.monthCashMovement);
      expect(
        closing.cashDelta,
        closing.cashCollected -
            closing.salaryPaid -
            closing.rentPaid -
            closing.otherFixedCost,
      );
      expect(
        closing.accountingProfit,
        closing.projectRevenue -
            closing.salaryPaid -
            closing.rentPaid -
            closing.otherFixedCost -
            closing.recruitmentCost,
      );
      expect(settled.company.cash, closing.cashAfter);
      expect(settled.monthStartCash, closing.cashAfter);
      expect(
        settled.stats.cumulativeSalary,
        cumulativeSalaryBefore + closing.salaryPaid,
      );
    });
  });
}
