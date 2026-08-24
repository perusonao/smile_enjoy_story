import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_raise.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';

import 'test_support/public_demo_offer_test_helpers.dart';

void main() {
  final joined = acceptTestOffer(
    const PublicDemoApplicant(
      id: 'raise-hire',
      name: 'Raise Hire',
      resumeSummary: 'Java 3年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
      requestedMonthlySalary: 320000,
    ),
    offeredMonthlySalary: 320000,
  ).join(week: 9);

  test(
    'a joined employee can request one raise from June and sees all three choices',
    () {
      expect(joined.canRequestRaiseIn(5), isFalse);
      expect(joined.canRequestRaiseIn(6), isTrue);
      final request = PublicDemoRaiseRequest.forApplicant(joined);
      expect(request.salaryFor(PublicDemoRaiseDecision.hold), 320000);
      expect(request.salaryFor(PublicDemoRaiseDecision.smallRaise), 340000);
      expect(request.salaryFor(PublicDemoRaiseDecision.requestedRaise), 380000);
    },
  );

  test('raise affects salary only from the following month', () {
    final decided = joined.decideRaise(
      decisionMonth: 6,
      week: 24,
      decision: PublicDemoRaiseDecision.requestedRaise,
    );
    expect(decided.salaryForMonth(6), 320000);
    expect(decided.salaryForMonth(7), 380000);
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: 800000,
        hires: [decided],
        month: 6,
      ),
      1120000,
    );
    expect(
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: 800000,
        hires: [decided],
        month: 7,
      ),
      1180000,
    );
  });

  test('decision applies morale, trust, and history exactly once', () {
    final once = joined.decideRaise(
      decisionMonth: 6,
      week: 24,
      decision: PublicDemoRaiseDecision.hold,
    );
    final twice = once.decideRaise(
      decisionMonth: 6,
      week: 24,
      decision: PublicDemoRaiseDecision.requestedRaise,
    );
    expect(once.employeeMorale, joined.employeeMorale! - 4);
    expect(once.employeeCompanyTrust, joined.employeeCompanyTrust! - 5);
    expect(
      once.relationshipHistory,
      hasLength(joined.relationshipHistory.length + 1),
    );
    expect(once.relationshipHistory.last.reason, '昇給希望を今回は据え置き');
    expect(twice.raisedMonthlySalary, once.raisedMonthlySalary);
    expect(
      twice.relationshipHistory,
      hasLength(once.relationshipHistory.length),
    );
    expect(twice.employeeMorale, once.employeeMorale);
    expect(twice.employeeCompanyTrust, once.employeeCompanyTrust);
  });

  test('recovery path without a hire still has no raise request', () {
    const applicant = PublicDemoApplicant(
      id: 'unjoined',
      name: 'Unjoined',
      resumeSummary: 'Java 2年',
      interviewScore: 70,
      acceptanceScore: 70,
      salesSkillFit: 70,
    );
    expect(applicant.canRequestRaiseIn(6), isFalse);
  });
}
