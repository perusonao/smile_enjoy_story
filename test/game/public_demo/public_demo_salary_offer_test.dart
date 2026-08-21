import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

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
  });
}
