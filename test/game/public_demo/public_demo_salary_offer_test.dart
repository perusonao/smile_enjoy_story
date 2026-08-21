import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/engine/morale_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

import '../test_helpers.dart';

void main() {
  group('PublicDemoSalaryOfferEvaluator', () {
    const applicant = PublicDemoApplicant(
      id: 'test-applicant',
      name: 'Test Applicant',
      resumeSummary: 'Java 3年',
      interviewScore: 70,
      acceptanceScore: 60,
      salesSkillFit: 70,
      requestedMonthlySalary: 320000,
    );

    test('lower salary reduces acceptance, motivation and trust', () {
      final result = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: 280000,
      );

      expect(result.acceptanceScore, lessThan(applicant.acceptanceScore));
      expect(result.motivationDelta, lessThan(0));
      expect(result.trustDelta, lessThan(0));
      expect(result.moraleDelta, result.motivationDelta);
    });

    test('requested salary keeps the candidate baseline neutral', () {
      final result = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: applicant.requestedMonthlySalary,
      );

      expect(result.acceptanceScore, applicant.acceptanceScore);
      expect(result.motivationDelta, 0);
      expect(result.trustDelta, 0);
    });

    test('higher salary improves acceptance, motivation and trust', () {
      final result = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: 360000,
      );

      expect(result.acceptanceScore, greaterThan(applicant.acceptanceScore));
      expect(result.motivationDelta, greaterThan(0));
      expect(result.trustDelta, greaterThan(0));
    });

    test('high salary does not guarantee acceptance', () {
      const reluctantApplicant = PublicDemoApplicant(
        id: 'reluctant',
        name: 'Reluctant Applicant',
        resumeSummary: 'Java 3年',
        interviewScore: 70,
        acceptanceScore: 20,
        salesSkillFit: 70,
        requestedMonthlySalary: 320000,
      );

      final result = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: reluctantApplicant,
        offeredMonthlySalary: 360000,
      );

      expect(result.accepted, isFalse);
    });

    test('applies the salary result to the applicant', () {
      final result = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: 280000,
      );

      final updated = result.applyTo(applicant);

      expect(updated.acceptedMonthlySalary, 280000);
      expect(updated.salaryMotivationDelta, result.motivationDelta);
      expect(updated.salaryTrustDelta, result.trustDelta);
    });

    test('creates an attributed relationship event from the salary result', () {
      final result = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: 280000,
      );

      final event = result.relationshipEvent(week: 6);

      expect(event.week, 6);
      expect(event.reason, '希望給与を下回る条件で入社');
      expect(event.moraleDelta, result.moraleDelta);
      expect(event.trustDelta, result.trustDelta);
    });

    test('relationship event reason describes requested and higher salaries', () {
      final requested = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: 320000,
      );
      final above = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: 360000,
      );

      expect(requested.relationshipEvent(week: 6).reason, '希望給与どおりの条件で入社');
      expect(above.relationshipEvent(week: 6).reason, '希望給与を上回る条件で入社');
    });

    test('relationship application clamps morale and company trust at 0', () {
      final result = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: 280000,
      );
      final event = result.relationshipEvent(week: 6);
      final updated = MoraleEngine.applyDelta(
        buildEngineer().copyWith(morale: 3, companyTrust: 2),
        week: event.week,
        reason: event.reason,
        moraleDelta: event.moraleDelta,
        trustDelta: event.trustDelta,
      );

      expect(updated.morale, 0);
      expect(updated.companyTrust, 0);
      expect(updated.relationshipHistory.single, isA<EmployeeRelationshipEvent>());
    });

    test('relationship application clamps morale and company trust at 100', () {
      final result = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: 360000,
      );
      final event = result.relationshipEvent(week: 6);
      final updated = MoraleEngine.applyDelta(
        buildEngineer().copyWith(morale: 99, companyTrust: 99),
        week: event.week,
        reason: event.reason,
        moraleDelta: event.moraleDelta,
        trustDelta: event.trustDelta,
      );

      expect(updated.morale, 100);
      expect(updated.companyTrust, 100);
    });
  });
}
