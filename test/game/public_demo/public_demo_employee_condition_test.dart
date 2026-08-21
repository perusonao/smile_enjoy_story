import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_employee_condition.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

void main() {
  const applicant = PublicDemoApplicant(
    id: 'condition-hire', name: 'Condition Hire', resumeSummary: 'Java 3年',
    interviewScore: 70, acceptanceScore: 70, salesSkillFit: 70,
  );

  PublicDemoApplicant acceptedAt(int salary) {
    final offer = PublicDemoSalaryOfferEvaluator.evaluate(
      applicant: applicant, offeredMonthlySalary: salary,
    );
    return offer.applyTo(applicant).copyWith(
      stage: PublicDemoApplicantStage.offerAccepted,
    );
  }

  test('salary condition is applied once on entry and retains low/base/high differences', () {
    final low = acceptedAt(280000).join(week: 9);
    final base = acceptedAt(320000).join(week: 9);
    final high = acceptedAt(360000).join(week: 9);

    expect(low.employeeMorale, lessThan(base.employeeMorale!));
    expect(low.employeeCompanyTrust, lessThan(base.employeeCompanyTrust!));
    expect(base.employeeMorale, 65);
    expect(base.employeeCompanyTrust, 60);
    expect(high.employeeMorale, greaterThan(base.employeeMorale!));
    expect(high.employeeCompanyTrust, greaterThan(base.employeeCompanyTrust!));
    expect(low.join(week: 9).relationshipHistory, hasLength(1));
  });

  test('declined offer does not create an employee condition', () {
    final declined = acceptedAt(280000).copyWith(
      stage: PublicDemoApplicantStage.offerDeclined,
    ).join(week: 9);
    expect(declined.hasJoined, isFalse);
    expect(declined.relationshipHistory, isEmpty);
  });

  test('entry condition clamps to 0 through 100', () {
    final low = applicant.copyWith(
      acceptedMonthlySalary: 280000, salaryMotivationDelta: -100,
      salaryTrustDelta: -100, salaryRelationshipReason: 'test',
    ).join(week: 9);
    final high = applicant.copyWith(
      acceptedMonthlySalary: 360000, salaryMotivationDelta: 100,
      salaryTrustDelta: 100, salaryRelationshipReason: 'test',
    ).join(week: 9);
    expect(low.employeeMorale, 0);
    expect(low.employeeCompanyTrust, 0);
    expect(high.employeeMorale, 100);
    expect(high.employeeCompanyTrust, 100);
  });

  test('condition labels do not expose numeric values', () {
    expect(PublicDemoEmployeeCondition.label(60), '高い');
    expect(PublicDemoEmployeeCondition.label(40), '普通');
    expect(PublicDemoEmployeeCondition.label(39), 'やや低い');
  });
}
