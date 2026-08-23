import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_internal_training_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  const transaction = PublicDemoInternalTrainingTransaction();
  PublicDemoState state({int cash = 3000000}) =>
      PublicDemoState.aprilStart().copyWith(cash: cash);

  PublicDemoApplicant junior() => const PublicDemoApplicant(
    id: 'junior',
    name: '未経験社員',
    resumeSummary: 'テスト',
    interviewScore: 64,
    acceptanceScore: 76,
    salesSkillFit: 26,
    experienceMonths: 0,
    requestedMonthlySalary: 220000,
  );

  test('waiting engineer is charged exactly ¥30,000 and selected', () {
    final result = transaction.execute(
      state: state(),
      engineerId: 'eng-01',
      assignedEngineerIds: const {},
    );
    expect(result.isSuccess, isTrue);
    expect(result.chargedAmount, 30000);
    expect(result.state.cash, 2970000);
    expect(result.state.trainingSelections, {
      'eng-01': PublicDemoGrowthSource.internalTraining,
    });
  });

  test('insufficient cash fails atomically and never makes cash negative', () {
    final before = state(cash: 29999);
    final result = transaction.execute(
      state: before,
      engineerId: 'eng-01',
      assignedEngineerIds: const {},
    );
    expect(result.status, PublicDemoInternalTrainingStatus.insufficientCash);
    expect(identical(result.state, before), isTrue);
    expect(result.state.cash, 29999);
    expect(result.state.cash, isNonNegative);
    expect(result.state.trainingSelections, isEmpty);
  });

  test('assigned, unknown, and duplicate engineer are rejected unchanged', () {
    final before = state();
    final assigned = transaction.execute(
      state: before,
      engineerId: 'eng-01',
      assignedEngineerIds: const {'eng-01'},
    );
    final unknown = transaction.execute(
      state: before,
      engineerId: 'missing',
      assignedEngineerIds: const {},
    );
    final selected = before.selectInternalTraining('eng-01');
    final duplicate = transaction.execute(
      state: selected,
      engineerId: 'eng-01',
      assignedEngineerIds: const {},
    );
    expect(assigned.status, PublicDemoInternalTrainingStatus.assigned);
    expect(unknown.status, PublicDemoInternalTrainingStatus.unknownEngineer);
    expect(duplicate.status, PublicDemoInternalTrainingStatus.alreadySelected);
    expect(identical(assigned.state, before), isTrue);
    expect(identical(unknown.state, before), isTrue);
    expect(identical(duplicate.state, selected), isTrue);
  });

  test('multiple waiting engineers are independently selectable', () {
    final first = transaction.execute(
      state: state(),
      engineerId: 'eng-01',
      assignedEngineerIds: const {},
    );
    final second = transaction.execute(
      state: first.state,
      engineerId: 'eng-02',
      assignedEngineerIds: const {},
    );
    expect(second.isSuccess, isTrue);
    expect(second.state.cash, 2940000);
    expect(
      second.state.trainingSelections.keys,
      containsAll(['eng-01', 'eng-02']),
    );
  });

  test(
    'experienced and JUNIOR-3 inexperienced waiting engineers can train',
    () {
      final experienced = transaction.execute(
        state: state(),
        engineerId: 'eng-02',
        assignedEngineerIds: const {},
      );
      final juniorRuntime = PublicDemoEngineerRuntime.fromApplicant(junior());
      final juniorState = state().copyWith(
        engineerRuntimes: [...state().engineerRuntimes, juniorRuntime],
      );
      final inexperienced = transaction.execute(
        state: juniorState,
        engineerId: 'junior',
        assignedEngineerIds: const {},
      );
      expect(experienced.isSuccess, isTrue);
      expect(inexperienced.isSuccess, isTrue);
    },
  );

  test(
    'growth consumes training, improves capability, and preserves experience',
    () {
      final juniorRuntime = PublicDemoEngineerRuntime.fromApplicant(junior());
      final trainingState = state().copyWith(
        engineerRuntimes: [...state().engineerRuntimes, juniorRuntime],
      );
      final selected = transaction
          .execute(
            state: trainingState,
            engineerId: 'junior',
            assignedEngineerIds: const {},
          )
          .state;
      final before = selected.runtimeFor('junior');
      final closed = selected.applyMonthlyGrowth(
        assignedEngineerIds: const {},
        moraleByEngineerId: const {'junior': 50},
      );
      final result = closed.latestGrowthResults.last;
      expect(result.source, PublicDemoGrowthSource.internalTraining);
      expect(closed.trainingSelections, isEmpty);
      expect(
        closed.runtimeFor('junior').actualCapability,
        greaterThan(before.actualCapability),
      );
      expect(result.actualExperienceMonthsDelta, 0);
    },
  );

  test(
    'assignment still adds one month and unrelated finance state is unchanged',
    () {
      final before = state().copyWith(
        summerBonusPaid: true,
        summerBonusPaidMonth: 7,
        summerBonusPaidAmount: 0,
        recruitmentMediumUsedMonth: 4,
      );
      final result = transaction.execute(
        state: before,
        engineerId: 'eng-02',
        assignedEngineerIds: const {},
      );
      final closed = result.state.applyMonthlyGrowth(
        assignedEngineerIds: const {'eng-01'},
        moraleByEngineerId: const {},
      );
      expect(closed.latestGrowthResults.first.actualExperienceMonthsDelta, 1);
      expect(result.state.summerBonusPaid, before.summerBonusPaid);
      expect(result.state.summerBonusPaidAmount, before.summerBonusPaidAmount);
      expect(
        result.state.recruitmentMediumUsedMonth,
        before.recruitmentMediumUsedMonth,
      );
    },
  );
}
