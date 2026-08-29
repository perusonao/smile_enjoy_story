import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

PayrollInput _input({
  Iterable<Engineer> engineers = const [],
  GeneralAffairsStaff? generalAffairsStaff,
  bool isPrologueActive = false,
  bool hasStartedPrologueAssignment = false,
}) => PayrollInput(
  engineers: engineers,
  generalAffairsStaff: generalAffairsStaff,
  isPrologueActive: isPrologueActive,
  hasStartedPrologueAssignment: hasStartedPrologueAssignment,
);

const _generalAffairs = GeneralAffairsStaff(
  id: 'ga-1',
  name: 'テスト総務',
  salary: 280000,
  flavor: '',
);

void main() {
  group('PayrollEngine legacy monthly calculation', () {
    test(
      'zero Engineers produces zero payroll when General Affairs is absent',
      () {
        final result = PayrollEngine.calculateMonthly(_input());

        expect(result.engineerSalaryTotal, 0);
        expect(result.generalAffairsSalaryTotal, 0);
        expect(result.totalSalary, 0);
      },
    );

    test('includes General Affairs as a separate payroll participant', () {
      final result = PayrollEngine.calculateMonthly(
        _input(generalAffairsStaff: _generalAffairs),
      );

      expect(result.engineerSalaryTotal, 0);
      expect(result.generalAffairsSalaryTotal, 280000);
      expect(result.totalSalary, 280000);
    });

    test('pays full salary regardless of current Engineer status', () {
      final result = PayrollEngine.calculateMonthly(
        _input(
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
        ),
      );

      expect(result.engineerSalaryTotal, 1000010);
      expect(result.totalSalary, 1000010);
    });

    test(
      'sums multiple Engineers and General Affairs exactly in integer yen',
      () {
        final result = PayrollEngine.calculateMonthly(
          _input(
            engineers: [
              buildEngineer(id: 'one', salary: 333333),
              buildEngineer(id: 'two', salary: 444444),
            ],
            generalAffairsStaff: _generalAffairs,
          ),
        );

        expect(result.engineerSalaryTotal, 777777);
        expect(result.generalAffairsSalaryTotal, 280000);
        expect(result.totalSalary, 1057777);
      },
    );

    test(
      'excludes the materialized pre-join Engineer during active March prologue',
      () {
        final result = PayrollEngine.calculateMonthly(
          _input(
            engineers: [buildEngineer(salary: 400000)],
            generalAffairsStaff: _generalAffairs,
            isPrologueActive: true,
          ),
        );

        expect(result.engineerSalaryTotal, 0);
        expect(result.generalAffairsSalaryTotal, 280000);
        expect(result.totalSalary, 280000);
      },
    );

    test(
      'includes the Engineer once the prologue April assignment has started',
      () {
        final result = PayrollEngine.calculateMonthly(
          _input(
            engineers: [buildEngineer(salary: 400000)],
            generalAffairsStaff: _generalAffairs,
            isPrologueActive: true,
            hasStartedPrologueAssignment: true,
          ),
        );

        expect(result.engineerSalaryTotal, 400000);
        expect(result.totalSalary, 680000);
      },
    );

    test(
      'a PendingHire is absent from payroll until it has become an Engineer',
      () {
        final beforeJoin = PayrollEngine.calculateMonthly(_input());
        final afterJoin = PayrollEngine.calculateMonthly(
          _input(engineers: [buildEngineer(id: 'joined', salary: 400000)]),
        );

        expect(beforeJoin.totalSalary, 0);
        expect(afterJoin.totalSalary, 400000);
      },
    );
  });
}
