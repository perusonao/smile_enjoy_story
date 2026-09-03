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
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_offer_test_helpers.dart';

/// Empty authoritative workflow — the production shape ([forecast] has no
/// `joinedApplicants`/`hires` parameter of its own, only this whole
/// [PublicDemoWorkflowState]).
PublicDemoWorkflowState _emptyWorkflow() =>
    PublicDemoWorkflowState(applicants: const [], engineers: const []);

PublicDemoWorkflowState _workflowWith(List<PublicDemoApplicant> applicants) =>
    PublicDemoWorkflowState(applicants: applicants, engineers: const []);

PublicDemoApplicant _joinedApplicant({
  required String id,
  required int offeredMonthlySalary,
}) => acceptTestOffer(
  PublicDemoApplicant(
    id: id,
    name: id,
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
    requestedMonthlySalary: offeredMonthlySalary,
  ),
  offeredMonthlySalary: offeredMonthlySalary,
).join(week: 9, currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5));

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
          workflow: _emptyWorkflow(),
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
        workflow: _emptyWorkflow(),
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
            workflow: _emptyWorkflow(),
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
          final hired = _joinedApplicant(
            id: 'hire-01',
            offeredMonthlySalary: 320000,
          );

          final state = PublicDemoState.aprilStart().copyWith(month: 8);
          final result = PublicDemoCashForecast.forecast(
            state: state,
            workflow: _workflowWith([hired]),
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
            workflow: _emptyWorkflow(),
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

      test(
        'the July forecast, including a joined engineer bonus-eligible salary, '
        'matches PublicDemoMonthlyClose.closeJuly exactly for salary, bonus, '
        'and closing cash — using the same authoritative workflow',
        () {
          final hired = _joinedApplicant(
            id: 'hire-02',
            offeredMonthlySalary: 320000,
          );
          final workflow = _workflowWith([hired]);
          final state = PublicDemoState.aprilStart()
              .copyWith(month: 7, cash: 5000000)
              .selectSummerBonus(PublicDemoSummerBonusPlan.half);

          final expenses = PublicDemoSalaryFinance.monthlyExpenses(
            baselineExpenses: baseline,
            hires: workflow.joinedApplicants,
            month: 7,
          );
          final result = PublicDemoCashForecast.forecast(
            state: state,
            workflow: workflow,
            monthsAhead: 1,
          );
          final forecastJuly = result.months.single;
          expect(forecastJuly.monthlyExpenses, expenses);

          final realClose = PublicDemoMonthlyClose.closeJuly(
            state: state,
            monthlyExpenses: expenses,
            applicants: workflow.joinedApplicants,
          );
          expect(realClose.isClosed, isTrue);
          expect(forecastJuly.bonusPaid, greaterThan(0));
          expect(
            forecastJuly.openingCash -
                forecastJuly.monthlyExpenses -
                forecastJuly.bonusPaid,
            realClose.state.cash,
          );
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
          workflow: _emptyWorkflow(),
          monthsAhead: 3,
        );
        expect(result.months.map((m) => m.month), [6, 7, 8]);
        for (final month in result.months) {
          expect(month.bonusPaid, 0);
        }
      });
    },
  );

  group('PublicDemoCashForecast.forecast — joined-roster authority', () {
    test(
      'every joined mid-career employee in the workflow is always included, '
      'with no way to pass a subset — two joined applicants both count',
      () {
        final first = _joinedApplicant(id: 'hire-a', offeredMonthlySalary: 300000);
        final second = _joinedApplicant(id: 'hire-b', offeredMonthlySalary: 280000);
        final workflow = _workflowWith([first, second]);

        final state = PublicDemoState.aprilStart().copyWith(month: 9);
        final result = PublicDemoCashForecast.forecast(
          state: state,
          workflow: workflow,
        );

        final expected = PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: baseline,
          hires: [first, second],
          month: 9,
        );
        expect(result.months.first.monthlyExpenses, expected);
        // Both salaries are actually in the total — not just one of them.
        expect(
          expected,
          baseline + 300000 + 280000,
        );
      },
    );

    test(
      'a pre-join applicant (offer accepted but not yet joined) is excluded '
      'from the forecasted payroll, exactly like PublicDemoSalaryFinance '
      'excludes anyone whose hasJoined is false',
      () {
        final joined = _joinedApplicant(id: 'hire-c', offeredMonthlySalary: 300000);
        final notYetJoined = acceptTestOffer(
          const PublicDemoApplicant(
            id: 'pending-01',
            name: 'Pending',
            resumeSummary: 'Java 2年',
            interviewScore: 70,
            acceptanceScore: 70,
            salesSkillFit: 70,
            requestedMonthlySalary: 350000,
          ),
          offeredMonthlySalary: 350000,
        );
        expect(notYetJoined.hasJoined, isFalse);

        final workflow = _workflowWith([joined, notYetJoined]);
        final state = PublicDemoState.aprilStart().copyWith(month: 8);
        final result = PublicDemoCashForecast.forecast(
          state: state,
          workflow: workflow,
        );

        final expectedWithoutPending = PublicDemoSalaryFinance.monthlyExpenses(
          baselineExpenses: baseline,
          hires: [joined],
          month: 8,
        );
        // The pending applicant's requested salary (350,000) never enters
        // the total: only the joined applicant's 300,000 does.
        expect(expectedWithoutPending, baseline + 300000);
        expect(result.months.first.monthlyExpenses, expectedWithoutPending);
      },
    );

    test(
      'an applicant with no interview/offer/join at all (bare applied stage) '
      'never contributes to the forecast either',
      () {
        const untouched = PublicDemoApplicant(
          id: 'applied-only',
          name: 'Applied Only',
          resumeSummary: 'Java 1年',
          interviewScore: 50,
          acceptanceScore: 50,
          salesSkillFit: 50,
          requestedMonthlySalary: 400000,
        );
        expect(untouched.hasJoined, isFalse);
        final workflow = _workflowWith([untouched]);
        final state = PublicDemoState.aprilStart().copyWith(month: 8);
        final result = PublicDemoCashForecast.forecast(
          state: state,
          workflow: workflow,
        );
        expect(result.months.first.monthlyExpenses, baseline);
      },
    );
  });

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
          workflow: _emptyWorkflow(),
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
          workflow: _emptyWorkflow(),
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
        workflow: _emptyWorkflow(),
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
        workflow: _emptyWorkflow(),
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
        workflow: _emptyWorkflow(),
        monthsAhead: 5,
      );
      expect(result.months.length, 2);
      expect(result.months.map((m) => m.month), [14, 15]);
    });
  });

  group('PublicDemoCashForecast.forecast — purity', () {
    test('never mutates the input state or workflow', () {
      final hired = _joinedApplicant(id: 'hire-d', offeredMonthlySalary: 300000);
      final workflow = _workflowWith([hired]);
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 2,
      );
      final beforeStateJson = state.toJson();
      final beforeWorkflowJson = workflow.toJson();
      PublicDemoCashForecast.forecast(state: state, workflow: workflow);
      expect(state.toJson(), beforeStateJson);
      expect(workflow.toJson(), beforeWorkflowJson);
    });

    test('calling it twice with identical inputs returns identical results', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 2000000,
        pendingRevenue: 300000,
        engineersAssigned: 1,
      );
      final workflow = _emptyWorkflow();
      final first = PublicDemoCashForecast.forecast(
        state: state,
        workflow: workflow,
      );
      final second = PublicDemoCashForecast.forecast(
        state: state,
        workflow: workflow,
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
        workflow: _emptyWorkflow(),
      );
      expect(result.basis, PublicDemoCashForecastBasis.confirmedOnly);
    });
  });
}
