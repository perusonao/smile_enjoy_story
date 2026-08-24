import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_raise.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_payment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';

import 'test_support/public_demo_offer_test_helpers.dart';

void main() {
  const applicant = PublicDemoApplicant(
    id: 'hire-01',
    name: 'Hire',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
    requestedMonthlySalary: 320000,
  );
  PublicDemoApplicant hired() =>
      acceptTestOffer(applicant, offeredMonthlySalary: 320000);

  PublicDemoState july({
    int cash = 3000000,
    PublicDemoSummerBonusPlan plan = PublicDemoSummerBonusPlan.one,
  }) => PublicDemoState.aprilStart()
      .copyWith(month: 7, cash: cash)
      .selectSummerBonus(plan);

  test('calculates initial SSOT eligible total and all supported plans', () {
    expect(
      PublicDemoSalary.bonusEligibleMonthlySalaryTotal(
        applicants: [],
        month: 7,
      ),
      550000,
    );
    expect(
      PublicDemoSummerBonusPayment.calculateSummerBonus(
        plan: PublicDemoSummerBonusPlan.half,
        applicants: [],
        month: 7,
      ),
      275000,
    );
    expect(
      PublicDemoSummerBonusPayment.calculateSummerBonus(
        plan: PublicDemoSummerBonusPlan.one,
        applicants: [],
        month: 7,
      ),
      550000,
    );
    expect(
      PublicDemoSummerBonusPayment.calculateSummerBonus(
        plan: PublicDemoSummerBonusPlan.none,
        applicants: [],
        month: 7,
      ),
      0,
    );
  });

  test(
    'joined engineer is included, while pending applicant and admin are excluded',
    () {
      final joined = hired().join(week: 9);
      expect(
        PublicDemoSummerBonusPayment.calculateSummerBonus(
          plan: PublicDemoSummerBonusPlan.one,
          applicants: [joined],
          month: 7,
        ),
        870000,
      );
      expect(
        PublicDemoSummerBonusPayment.calculateSummerBonus(
          plan: PublicDemoSummerBonusPlan.one,
          applicants: [applicant],
          month: 7,
        ),
        550000,
      );
      expect(PublicDemoSalary.adminMonthlySalary, isNot(equals(0)));
    },
  );

  test('July calculation uses raised current salary', () {
    final raised = hired()
        .join(week: 9)
        .decideRaise(
          decisionMonth: 6,
          week: 24,
          decision: PublicDemoRaiseDecision.requestedRaise,
        );
    expect(
      PublicDemoSummerBonusPayment.calculateSummerBonus(
        plan: PublicDemoSummerBonusPlan.one,
        applicants: [raised],
        month: 7,
      ),
      930000,
    );
  });

  test('only July close pays and records the bonus once', () {
    final beforeJuly = july().copyWith(month: 6);
    expect(
      PublicDemoSummerBonusPayment.closeJuly(
        state: beforeJuly,
        monthlyExpenses: 800000,
        applicants: [],
      ).status,
      PublicDemoSummerBonusPaymentStatus.notApplicable,
    );
    final paid = july().advanceToAugust(
      monthlyExpenses: 800000,
      applicants: [],
    );
    expect(paid.isPaid, isTrue);
    expect(paid.state.cash, 1650000);
    expect(paid.state.summerBonusPaidMonth, 7);
    expect(paid.state.summerBonusPaidAmount, 550000);
    expect(paid.cashMovement, -1350000);
    expect(paid.totalOutflow, 1350000);
    final duplicate = paid.state.advanceToAugust(
      monthlyExpenses: 800000,
      applicants: [],
    );
    expect(duplicate.status, PublicDemoSummerBonusPaymentStatus.notApplicable);
    expect(duplicate.state.cash, paid.state.cash);
  });

  test('insufficient cash leaves all July and bonus fields unchanged', () {
    final before = july(cash: 1349999);
    final result = before.advanceToAugust(
      monthlyExpenses: 800000,
      applicants: [],
    );
    expect(result.isInsufficientCash, isTrue);
    expect(result.state, same(before));
    expect(result.state.summerBonusPaid, isFalse);
    expect(result.state.month, 7);
  });

  test(
    'none marks the July decision paid at zero without double-counting expense',
    () {
      final result = july(
        plan: PublicDemoSummerBonusPlan.none,
      ).advanceToAugust(monthlyExpenses: 800000, applicants: []);
      expect(result.isPaid, isTrue);
      expect(result.bonusAmount, 0);
      expect(result.state.summerBonusPaidAmount, 0);
      expect(result.state.cash, 2200000);
      expect(result.cashMovement, -800000);
    },
  );

  test(
    'normal July monthly expense and bonus reconcile with salary finance',
    () {
      final joined = hired().join(week: 9);
      final expense = PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: [joined],
        month: 7,
      );
      final result = july(
        cash: 3000000,
      ).advanceToAugust(monthlyExpenses: expense, applicants: [joined]);
      expect(result.totalOutflow, expense + 870000);
      expect(result.cashAfter - result.cashBefore, -result.totalOutflow);
    },
  );
}
