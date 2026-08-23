import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_internal_training_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_raise.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_raise_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';

/// POST-12MONTH-1: once [PublicDemoState.fiscalYearCompleted] is true,
/// Public Demo 0.1 is a read-only terminal state. No user action that
/// changes game progression or management state (raise, training,
/// recruitment media, sales slots, summer bonus selection) may mutate
/// state past that point; Monthly Close's own idempotency is already
/// covered end-to-end by public_demo_monthly_close_ordinary_month_test.dart
/// and is not re-tested here.
void main() {
  PublicDemoState completedState({int cash = 3000000}) =>
      PublicDemoState.aprilStart().copyWith(
        month: 15,
        cash: cash,
        fiscalYearCompleted: true,
      );

  PublicDemoApplicant joinedApplicant() => const PublicDemoApplicant(
    id: 'raise-hire',
    name: 'Raise Hire',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
    acceptedMonthlySalary: 320000,
  ).join(week: 9);

  group('A. Raise is locked after fiscal year completion', () {
    // POST-12MONTH-1-FIX1 P1-1: PublicDemoRaiseTransaction — not
    // PublicDemoApplicant.decideRaise itself — is the sanctioned entry
    // point. It takes the real PublicDemoState as a required parameter and
    // reads state.fiscalYearCompleted directly, so there is no bool
    // parameter a caller could omit or override to bypass the guard.
    const transaction = PublicDemoRaiseTransaction();

    test('PublicDemoRaiseTransaction rejects with fiscalYearCompleted once '
        'completed, even though the applicant is in-window and eligible', () {
      final before = joinedApplicant();
      final state = completedState();
      final result = transaction.execute(
        state: state,
        applicant: before,
        decisionMonth: 15,
        week: 60,
        decision: PublicDemoRaiseDecision.requestedRaise,
      );
      expect(
        result.status,
        PublicDemoRaiseTransactionStatus.fiscalYearCompleted,
      );
      expect(identical(result.applicant, before), isTrue);
      expect(result.applicant.raiseDecision, isNull);
      expect(result.applicant.raisedMonthlySalary, isNull);
      expect(result.applicant.employeeMorale, before.employeeMorale);
      expect(
        result.applicant.employeeCompanyTrust,
        before.employeeCompanyTrust,
      );
      expect(result.applicant.relationshipHistory, before.relationshipHistory);
      expect(result.applicant.salaryForMonth(16), before.salaryForMonth(16));
    });

    test('the transaction API has no flag to override: completion is read '
        'only from the state object passed in, so passing an otherwise '
        'identical but not-completed state still succeeds — proving the '
        'rejection above came from state.fiscalYearCompleted, not some '
        'other eligibility check', () {
      final before = joinedApplicant();
      final notCompleted = completedState().copyWith(
        fiscalYearCompleted: false,
      );
      final result = transaction.execute(
        state: notCompleted,
        applicant: before,
        decisionMonth: 15,
        week: 60,
        decision: PublicDemoRaiseDecision.requestedRaise,
      );
      expect(result.status, PublicDemoRaiseTransactionStatus.success);
      expect(result.applicant.raiseDecision, isNotNull);
    });
  });

  group('B. Training is locked after fiscal year completion', () {
    test(
      'PublicDemoInternalTrainingTransaction rejects with fiscalYearCompleted '
      'and neither charges cash nor selects training',
      () {
        const transaction = PublicDemoInternalTrainingTransaction();
        final before = completedState();
        final result = transaction.execute(
          state: before,
          engineerId: 'eng-01',
          assignedEngineerIds: const {},
        );
        expect(
          result.status,
          PublicDemoInternalTrainingStatus.fiscalYearCompleted,
        );
        expect(identical(result.state, before), isTrue);
        expect(result.state.cash, before.cash);
        expect(result.state.trainingSelections, isEmpty);
        expect(result.chargedAmount, 0);
      },
    );

    test('PublicDemoState.selectInternalTraining/selectExternalTraining/'
        'cancelTraining are all no-ops once completed (direct domain-API '
        'defense in depth)', () {
      final before = completedState();
      expect(
        identical(before.selectInternalTraining('eng-01'), before),
        isTrue,
      );
      expect(
        identical(before.selectExternalTraining('eng-01'), before),
        isTrue,
      );
      final withSelection = PublicDemoState.aprilStart()
          .selectInternalTraining('eng-01')
          .copyWith(month: 15, fiscalYearCompleted: true);
      expect(
        identical(withSelection.cancelTraining('eng-01'), withSelection),
        isTrue,
      );
      expect(withSelection.trainingSelections, {
        'eng-01': PublicDemoGrowthSource.internalTraining,
      });
    });
  });

  group('Other mutations locked after fiscal year completion', () {
    test('useSalesSlot is a no-op once completed', () {
      final before = completedState();
      final after = before.useSalesSlot();
      expect(identical(after, before), isTrue);
      expect(after.salesUsed, before.salesUsed);
    });

    test('selectSummerBonus is a no-op once completed', () {
      final before = completedState().copyWith(
        summerBonusSelection: PublicDemoSummerBonusPlan.none,
      );
      final after = before.selectSummerBonus(PublicDemoSummerBonusPlan.one);
      expect(identical(after, before), isTrue);
      expect(after.summerBonusSelection, PublicDemoSummerBonusPlan.none);
    });
  });

  group('D. Pre-completion regression: existing raise/training behavior '
      'is unchanged', () {
    test('raise still works exactly as before when not completed', () {
      final before = joinedApplicant();
      final after = before.decideRaise(
        decisionMonth: 6,
        week: 24,
        decision: PublicDemoRaiseDecision.requestedRaise,
      );
      expect(after.raiseDecision, PublicDemoRaiseDecision.requestedRaise);
      expect(after.raisedMonthlySalary, 380000);
      expect(after.salaryForMonth(7), 380000);
    });

    test(
      'PublicDemoRaiseTransaction (the sanctioned entry point) produces the '
      'exact same result as calling decideRaise directly when not completed',
      () {
        const transaction = PublicDemoRaiseTransaction();
        final before = joinedApplicant();
        final result = transaction.execute(
          state: PublicDemoState.aprilStart().copyWith(month: 6),
          applicant: before,
          decisionMonth: 6,
          week: 24,
          decision: PublicDemoRaiseDecision.requestedRaise,
        );
        expect(result.status, PublicDemoRaiseTransactionStatus.success);
        expect(
          result.applicant.raiseDecision,
          PublicDemoRaiseDecision.requestedRaise,
        );
        expect(result.applicant.raisedMonthlySalary, 380000);
        expect(result.applicant.salaryForMonth(7), 380000);
      },
    );

    test('PublicDemoRaiseTransaction still respects the pre-existing month/'
        'already-decided eligibility window when not completed', () {
      const transaction = PublicDemoRaiseTransaction();
      final tooEarly = transaction.execute(
        state: PublicDemoState.aprilStart().copyWith(month: 5),
        applicant: joinedApplicant(),
        decisionMonth: 5,
        week: 20,
        decision: PublicDemoRaiseDecision.hold,
      );
      expect(tooEarly.status, PublicDemoRaiseTransactionStatus.notEligible);
      expect(tooEarly.applicant.raiseDecision, isNull);
    });

    test('internal training still works exactly as before when not '
        'completed', () {
      const transaction = PublicDemoInternalTrainingTransaction();
      final before = PublicDemoState.aprilStart();
      final result = transaction.execute(
        state: before,
        engineerId: 'eng-01',
        assignedEngineerIds: const {},
      );
      expect(result.isSuccess, isTrue);
      expect(result.state.cash, before.cash - 30000);
      expect(result.state.trainingSelections, {
        'eng-01': PublicDemoGrowthSource.internalTraining,
      });
    });

    test(
      'useSalesSlot and selectSummerBonus still work when not completed',
      () {
        final start = PublicDemoState.aprilStart();
        expect(start.useSalesSlot().salesUsed, 1);
        expect(
          start
              .selectSummerBonus(PublicDemoSummerBonusPlan.half)
              .summerBonusSelection,
          PublicDemoSummerBonusPlan.half,
        );
      },
    );
  });
}
