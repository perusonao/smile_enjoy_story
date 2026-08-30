import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

void main() {
  group('PLAYTEST-BALANCE-1B: Public Demo 0.1 starting cash', () {
    test('PublicDemoAggregate.initial starts April with ¥4,000,000 cash', () {
      final aggregate = PublicDemoAggregate.initial();

      expect(aggregate.state.cash, 4000000);
      expect(aggregate.state.month, 4);
    });

    test('Public Demo April opening cash is ¥4,000,000', () {
      final state = PublicDemoAggregate.initial().state;

      expect(state.monthOpeningCash, 4000000);
      expect(state.monthOpeningCash, state.cash);
    });

    test('normal one-hire route reaches fiscal completion with a positive '
        '¥700,000 March cash buffer', () {
      // This is the reasonable PLAYTEST-BALANCE-1A route, not a
      // survival-optimized scenario: one founder wins an initial order,
      // one May applicant is hired at the requested salary and also wins an
      // order, and both assignments continue through March. It deliberately
      // includes no extra hires, training, recruitment spend, or bonus.
      var aggregate = PublicDemoAggregate.initial()
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          )
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.client,
          )
          .recordOrder('eng-01')
          .closeApril(
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          );

      final applicantId = aggregate.workflow.applicants.first.id;
      final interview = aggregate.completeInterview(applicantId);
      expect(interview.isCompleted, isTrue);
      aggregate = interview.aggregate;
      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == applicantId,
      );
      aggregate = aggregate
          .acceptOffer(
            applicantId: applicantId,
            offer: PublicDemoSalaryOfferEvaluator.evaluate(
              applicant: applicant,
              offeredMonthlySalary: applicant.requestedMonthlySalary,
            ),
            fiscalCloseId: PublicDemoFiscalCloseId.forMonth(
              aggregate.state.month,
            ),
          )
          .beginPreEntrySkillSheet(applicantId)
          .beginPreEntrySelling(applicantId)
          .introducePreEntryProject(applicantId)
          .recordPreEntryPartnerInterviewResult(applicantId)
          .recordPreEntryClientInterviewResult(applicantId)
          .recordJuneOrder(applicantId)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          );

      final hire = aggregate.workflow.joinedApplicants.single;
      final monthlyExpenses = PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: [hire],
      );
      expect(monthlyExpenses, 1120000);

      final monthlyCashCheckpoints = <String, int>{
        'April': 3200000,
        'May': aggregate.state.cash,
      };
      aggregate = aggregate.closeJune(
        assignedInJuly: 2,
        monthlyExpenses: monthlyExpenses,
      );
      monthlyCashCheckpoints['June'] = aggregate.state.cash;
      aggregate = aggregate.closeJuly(monthlyExpenses: monthlyExpenses);
      monthlyCashCheckpoints['July'] = aggregate.state.cash;
      for (final month in const [
        'August',
        'September',
        'October',
        'November',
        'December',
        'January',
        'February',
        'March',
      ]) {
        aggregate = aggregate.closeOrdinaryMonth(
          monthlyExpenses: monthlyExpenses,
        );
        monthlyCashCheckpoints[month] = aggregate.state.cash;
      }

      expect(monthlyCashCheckpoints, {
        'April': 3200000,
        'May': 2400000,
        'June': 1780000,
        'July': 1660000,
        'August': 1540000,
        'September': 1420000,
        'October': 1300000,
        'November': 1180000,
        'December': 1060000,
        'January': 940000,
        'February': 820000,
        'March': 700000,
      });
      final minimumCashBuffer = monthlyCashCheckpoints.values.reduce(
        (lowest, cash) => cash < lowest ? cash : lowest,
      );
      expect(minimumCashBuffer, 700000);
      expect(aggregate.state.cash, greaterThan(0));
      expect(aggregate.state.cash, 700000);
      expect(aggregate.state.fiscalYearCompleted, isTrue);
      expect(aggregate.state.financialStatus, PublicDemoFinancialStatus.normal);
    });
  });
}
