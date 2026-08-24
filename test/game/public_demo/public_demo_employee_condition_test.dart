import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_binding_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_employee_condition.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

import 'test_support/public_demo_offer_test_helpers.dart';

void main() {
  // WORKFLOW-STATE-1AB FIX2 P1-1A: accept() now gates on the unforgeable
  // interview record, not `stage` — markInterviewed() mints it, matching
  // the real interview flow (public_demo_01_placeholder_screen.dart's
  // recruit()).
  final applicant = const PublicDemoApplicant(
    id: 'condition-hire',
    name: 'Condition Hire',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
  ).markInterviewed();
  final fiscalCloseId = PublicDemoFiscalCloseId.forMonth(5);

  // Routes through the real PublicDemoOfferAcceptance.accept command (the
  // only place that can mint a PublicDemoBindingOffer — WORKFLOW-STATE-1
  // §9), letting PublicDemoSalaryOfferEvaluator's real accept/decline
  // threshold decide, exactly as production code does.
  PublicDemoApplicant acceptedAt(int salary) {
    final offer = PublicDemoSalaryOfferEvaluator.evaluate(
      applicant: applicant,
      offeredMonthlySalary: salary,
    );
    return PublicDemoOfferAcceptance.accept(
      applicant: applicant,
      offer: offer,
      fiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
    ).applicant;
  }

  test(
    'salary condition is applied once on entry and retains low/base/high differences',
    () {
      // 300000/340000 (rather than the wider 280000/360000) so both still
      // clear the real evaluator's acceptanceScore>=60 threshold — otherwise
      // the low case would come back declined (no binding offer) and never
      // join. The morale/trust deltas below are fixed by sign of the salary
      // difference, not magnitude, so this preserves the same low<base<high
      // comparison the wider values exercised.
      final low = acceptedAt(
        300000,
      ).join(week: 9, currentFiscalCloseId: fiscalCloseId);
      final base = acceptedAt(
        320000,
      ).join(week: 9, currentFiscalCloseId: fiscalCloseId);
      final high = acceptedAt(
        340000,
      ).join(week: 9, currentFiscalCloseId: fiscalCloseId);

      expect(low.employeeMorale, lessThan(base.employeeMorale!));
      expect(low.employeeCompanyTrust, lessThan(base.employeeCompanyTrust!));
      expect(base.employeeMorale, 65);
      expect(base.employeeCompanyTrust, 60);
      expect(high.employeeMorale, greaterThan(base.employeeMorale!));
      expect(
        high.employeeCompanyTrust,
        greaterThan(base.employeeCompanyTrust!),
      );
      expect(
        low
            .join(week: 9, currentFiscalCloseId: fiscalCloseId)
            .relationshipHistory,
        hasLength(1),
      );
    },
  );

  test('declined offer does not create an employee condition', () {
    final declined = acceptedAt(280000)
        .copyWith(stage: PublicDemoApplicantStage.offerDeclined)
        .join(week: 9, currentFiscalCloseId: fiscalCloseId);
    expect(declined.hasJoined, isFalse);
    expect(declined.relationshipHistory, isEmpty);
  });

  test('entry condition clamps to 0 through 100', () {
    final low = acceptTestOffer(
      applicant,
      offeredMonthlySalary: 280000,
      motivationDelta: -100,
      trustDelta: -100,
    ).join(week: 9, currentFiscalCloseId: fiscalCloseId);
    final high = acceptTestOffer(
      applicant,
      offeredMonthlySalary: 360000,
      motivationDelta: 100,
      trustDelta: 100,
    ).join(week: 9, currentFiscalCloseId: fiscalCloseId);
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
