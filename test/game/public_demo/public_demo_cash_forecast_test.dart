import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_forecast.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_payment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';

import 'test_support/public_demo_offer_test_helpers.dart';

void main() {
  final baseline = PublicDemoSalary.baselineMonthlyExpenses;

  group('PublicDemoCashForecast.forecast — AR collection', () {
    test(
      'reflects the existing 30-day payment term: this month collects last '
      "month's pendingRevenue, not this month's own recognized revenue",
      () {
        final state = PublicDemoState.aprilStart().copyWith(
          cash: 1000000,
          pendingRevenue: 500000,
          engineersAssigned: 2,
        );
        final result = PublicDemoCashForecast.forecast(
          state: state,
          joinedApplicants: const [],
        );
        expect(result.months.first.cashReceived, 500000);
        expect(result.months.first.revenueRecognized, 1000000);
        // Next month collects what THIS month recognized, not before.
        expect(result.months[1].cashReceived, 1000000);
      },
    );

    test('0 assigned engineers means every future month collects 0 new AR', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 5000000,
        pendingRevenue: 0,
        engineersAssigned: 0,
      );
      final result = PublicDemoCashForecast.forecast(
        state: state,
        joinedApplicants: const [],
      );
      for (final month in result.months) {
        expect(month.cashReceived, 0);
        expect(month.revenueRecognized, 0);
      }
    });
  });

  group(
    'PublicDemoCashForecast.forecast — matches the real monthly close',
    () {
      test(
        "salary and fixed costs land in the same month as the actual "
        'April close, using the exact same monthlyExpenses helper',
        () {
          final state = PublicDemoState.aprilStart();
          final result = PublicDemoCashForecast.forecast(
            state: state,
            joinedApplicants: const [],
          );
          final expectedExpenses = PublicDemoSalaryFinance.monthlyExpenses(
            baselineExpenses: baseline,
            hires: const [],
            month: 4,
          );
          expect(result.months.first.monthlyExpenses, expectedExpenses);

          final realClose = PublicDemoMonthlyClose.closeApril(
            state: state,
            monthlyExpenses: expectedExpenses,
            orderedEngineers: 0,
          );
          expect(result.months.first.closingCash, realClose.state.cash);
        },
      );

      test(
        "a joined hire's salary is included in the forecasted month exactly "
        'as PublicDemoSalaryFinance.monthlyExpenses computes it',
        () {
          final hired = acceptTestOffer(
            const PublicDemoApplicant(
              id: 'hire-01',
              name: 'Hire',
              resumeSummary: 'Java 3年',
              interviewScore: 70,
              acceptanceScore: 70,
              salesSkillFit: 70,
              requestedMonthlySalary: 320000,
            ),
            offeredMonthlySalary: 320000,
          ).join(
            week: 9,
            currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
          );

          final state = PublicDemoState.aprilStart().copyWith(month: 8);
          final result = PublicDemoCashForecast.forecast(
            state: state,
            joinedApplicants: [hired],
          );
          final expected = PublicDemoSalaryFinance.monthlyExpenses(
            baselineExpenses: baseline,
            hires: [hired],
            month: 8,
          );
          expect(result.months.first.monthlyExpenses, expected);

          final realClose = PublicDemoMonthlyClose.closeOrdinaryMonth(
            state: state,
            monthlyExpenses: expected,
          );
          expect(result.months.first.closingCash, realClose.state.cash);
        },
      );

      test(
        'the currently selected July bonus plan is charged in the forecasted '
        'July month using the exact same bonus calculation as the real close',
        () {
          final state = PublicDemoState.aprilStart()
              .copyWith(month: 5, cash: 5000000)
              .selectSummerBonus(PublicDemoSummerBonusPlan.one);
          final result = PublicDemoCashForecast.forecast(
            state: state,
            joinedApplicants: const [],
            monthsAhead: 3,
          );
          final julyMonth = result.months.firstWhere((m) => m.month == 7);
          final expectedBonus = PublicDemoSummerBonusPayment.calculateSummerBonus(
            plan: PublicDemoSummerBonusPlan.one,
            applicants: const [],
            month: 7,
          );
          expect(julyMonth.bonusPaid, expectedBonus);
          expect(julyMonth.bonusPaid, greaterThan(0));

          // Non-July months in the same window never charge a bonus.
          for (final month in result.months) {
            if (month.month != 7) expect(month.bonusPaid, 0);
          }
        },
      );

      test('an already-paid July bonus is never charged again in the forecast', () {
        // month is still 6 (before July's close), but the bonus record
        // already shows it settled — the forecast must trust that fact
        // over the plan selection, exactly like PublicDemoSummerBonusPayment
        // (guarded by summerBonusPaid, not by month alone).
        final state = PublicDemoState.aprilStart()
            .copyWith(month: 6, cash: 5000000)
            .selectSummerBonus(PublicDemoSummerBonusPlan.one)
            .markSummerBonusPaid(month: 7, amount: 550000);
        expect(state.summerBonusPaid, isTrue);
        final result = PublicDemoCashForecast.forecast(
          state: state,
          joinedApplicants: const [],
          monthsAhead: 3,
        );
        expect(result.months.map((m) => m.month), [6, 7, 8]);
        for (final month in result.months) {
          expect(month.bonusPaid, 0);
        }
      });
    },
  );

  group('PublicDemoCashForecast.forecast — shortage detection', () {
    test(
      'a known waiting-only scenario (no revenue, mandatory expenses only) '
      'returns the first month cash goes negative',
      () {
        // Baseline monthly expenses with no revenue at all: cash runs out.
        final state = PublicDemoState.aprilStart().copyWith(
          cash: baseline + (baseline ~/ 2),
          pendingRevenue: 0,
          engineersAssigned: 0,
        );
        final result = PublicDemoCashForecast.forecast(
          state: state,
          joinedApplicants: const [],
          monthsAhead: 3,
        );
        expect(result.hasShortage, isTrue);
        expect(result.isSafe, isFalse);
        // Month 1 (April): cash - baseline stays >= 0 (1.5x baseline).
        expect(result.months[0].closingCash, greaterThanOrEqualTo(0));
        // Month 2 (May): a second baseline deduction pushes it negative.
        expect(result.firstShortageMonth, 5);
        expect(result.months[1].closingCash, lessThan(0));
      },
    );

    test(
      'confirmed AR collection arriving in time prevents a false-positive '
      'shortage even when this month alone looks tight',
      () {
        final state = PublicDemoState.aprilStart().copyWith(
          cash: baseline,
          // Enough pending revenue lands as cash this month to cover next
          // month's expenses too.
          pendingRevenue: baseline * 3,
          engineersAssigned: 2,
        );
        final result = PublicDemoCashForecast.forecast(
          state: state,
          joinedApplicants: const [],
          monthsAhead: 3,
        );
        expect(result.hasShortage, isFalse);
        expect(result.isSafe, isTrue);
        expect(result.firstShortageMonth, isNull);
        for (final month in result.months) {
          expect(month.closingCash, greaterThanOrEqualTo(0));
        }
      },
    );

    test('a close-blocked state (already bankrupt) forecasts an empty, safe window', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: -100000,
        financialStatus: PublicDemoFinancialStatus.bankruptcy,
      );
      final result = PublicDemoCashForecast.forecast(
        state: state,
        joinedApplicants: const [],
      );
      expect(result.months, isEmpty);
      expect(result.hasShortage, isFalse);
      expect(result.isSafe, isTrue);
    });

    test('a fiscal-year-completed state forecasts an empty, safe window', () {
      final state = PublicDemoState.aprilStart().copyWith(
        month: 15,
        fiscalYearCompleted: true,
      );
      final result = PublicDemoCashForecast.forecast(
        state: state,
        joinedApplicants: const [],
      );
      expect(result.months, isEmpty);
    });

    test('the window is truncated at March (month 15), never past it', () {
      final state = PublicDemoState.aprilStart().copyWith(
        month: 14,
        cash: 10000000,
      );
      final result = PublicDemoCashForecast.forecast(
        state: state,
        joinedApplicants: const [],
        monthsAhead: 5,
      );
      expect(result.months.length, 2);
      expect(result.months.map((m) => m.month), [14, 15]);
    });
  });

  group('PublicDemoCashForecast.forecast — purity', () {
    test('never mutates the input state', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 2,
      );
      final beforeJson = state.toJson();
      PublicDemoCashForecast.forecast(state: state, joinedApplicants: const []);
      expect(state.toJson(), beforeJson);
    });

    test('calling it twice with identical inputs returns identical results', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 2000000,
        pendingRevenue: 300000,
        engineersAssigned: 1,
      );
      final first = PublicDemoCashForecast.forecast(
        state: state,
        joinedApplicants: const [],
      );
      final second = PublicDemoCashForecast.forecast(
        state: state,
        joinedApplicants: const [],
      );
      expect(
        first.months.map((m) => m.closingCash).toList(),
        second.months.map((m) => m.closingCash).toList(),
      );
      expect(first.firstShortageMonth, second.firstShortageMonth);
    });
  });

  group('PublicDemoCashForecast.forecast — confirmed-information basis', () {
    test('every result exposes an explicit confirmed-only basis marker', () {
      final result = PublicDemoCashForecast.forecast(
        state: PublicDemoState.aprilStart(),
        joinedApplicants: const [],
      );
      expect(result.basis, PublicDemoCashForecastBasis.confirmedOnly);
    });
  });
}
