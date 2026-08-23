import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/models/language_skill.dart';
import 'package:smile_enjoy_story/domain/models/programming_language.dart';
import 'package:smile_enjoy_story/domain/models/sales_profile.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_raise.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  PublicDemoApplicant applicant({
    required String id,
    required int experienceMonths,
    required int interviewScore,
    required int acceptanceScore,
    required int salesSkillFit,
    int requestedMonthlySalary = 220000,
  }) => PublicDemoApplicant(
    id: id,
    name: '候補者',
    resumeSummary: 'テスト',
    interviewScore: interviewScore,
    acceptanceScore: acceptanceScore,
    salesSkillFit: salesSkillFit,
    experienceMonths: experienceMonths,
    requestedMonthlySalary: requestedMonthlySalary,
    acceptedMonthlySalary: requestedMonthlySalary,
  );

  group('JUNIOR-3 runtime factory', () {
    test('experienced runtime retains the established sales skill values', () {
      final candidate = applicant(
        id: 'experienced', experienceMonths: 24, interviewScore: 60,
        acceptanceScore: 70, salesSkillFit: 76, requestedMonthlySalary: 320000,
      );
      final runtime = PublicDemoEngineerRuntime.fromApplicant(candidate);
      expect(runtime.actualCapability, 76);
      expect(runtime.hidden.growthPotential, 3);
      expect(runtime.abilities, isEmpty);
      expect(runtime.languageSkills[ProgrammingLanguage.java]!.actualExperienceMonths, 0);
    });

    test('inexperienced candidates cannot enter pre-join sales and join via salary SSOT', () {
      final candidate = applicant(
        id: 'junior', experienceMonths: 0, interviewScore: 64,
        acceptanceScore: 76, salesSkillFit: 26,
      );
      expect(candidate.isInexperienced, isTrue);
      expect(candidate.canEnterPreJoinSales, isFalse);
      expect(candidate.join(week: 9).salaryForMonth(6), 220000);
    });

    test('junior profiles are deterministic and both numeric templates are reachable', () {
      final potential = applicant(id: 'a', experienceMonths: 0, interviewScore: 64, acceptanceScore: 76, salesSkillFit: 26);
      final steady = applicant(id: 'b', experienceMonths: 0, interviewScore: 65, acceptanceScore: 76, salesSkillFit: 26);
      final a = PublicDemoEngineerRuntime.fromApplicant(potential);
      final b = PublicDemoEngineerRuntime.fromApplicant(steady);
      expect(a.actualCapability, 20);
      expect(a.hidden.growthPotential, 5);
      expect(a.abilities, contains(EmployeeAbility.fastLearner));
      expect(b.actualCapability, 28);
      expect(b.hidden.growthPotential, 3);
      expect(b.abilities, isEmpty);
      expect(PublicDemoEngineerRuntime.fromApplicant(potential).toJson(), a.toJson());
    });

    test('junior starts with no work or industry history and supports waiting/training growth', () {
      final runtime = PublicDemoEngineerRuntime.fromApplicant(applicant(id: 'junior', experienceMonths: 0, interviewScore: 64, acceptanceScore: 76, salesSkillFit: 26));
      expect(runtime.careerHistory, isEmpty);
      expect(runtime.industryExperience, isEmpty);
      expect(runtime.languageSkills[ProgrammingLanguage.java]!.actualExperienceMonths, 0);
      final waiting = PublicDemoGrowthEngine.calculate(runtime, const PublicDemoGrowthRequest(source: PublicDemoGrowthSource.waiting, morale: 50));
      final training = PublicDemoGrowthEngine.calculate(runtime, const PublicDemoGrowthRequest(source: PublicDemoGrowthSource.internalTraining, morale: 50));
      expect(waiting.actualExperienceMonthsDelta, 0);
      expect(training.actualExperienceMonthsDelta, 0);
      expect(
        waiting.after.actualCapability,
        runtime.actualCapability,
        reason: 'the established deterministic waiting formula may round to 0',
      );
      expect(training.after.actualCapability, greaterThan(runtime.actualCapability));
      expect(PublicDemoState.aprilStart().selectInternalTraining(runtime.engineerId).trainingSelections[runtime.engineerId], PublicDemoGrowthSource.internalTraining);
    });

    test('assignment remains the only source that adds one experience month', () {
      final runtime = PublicDemoEngineerRuntime.fromApplicant(applicant(id: 'junior', experienceMonths: 0, interviewScore: 64, acceptanceScore: 76, salesSkillFit: 26));
      final assignment = PublicDemoGrowthEngine.calculate(runtime, const PublicDemoGrowthRequest(source: PublicDemoGrowthSource.assignment, morale: 50, industry: Industry.manufacturing));
      expect(assignment.actualExperienceMonthsDelta, 1);
      expect(assignment.after.languageSkills[ProgrammingLanguage.java]!.actualExperienceMonths, 1);
    });

    test('field sales readiness is a pure 60-point boundary and JSON stays compatible', () {
      final below = PublicDemoEngineerRuntime.fromApplicant(applicant(id: 'junior', experienceMonths: 0, interviewScore: 64, acceptanceScore: 76, salesSkillFit: 26));
      final at = below.copyWith(languageSkills: {ProgrammingLanguage.java: const LanguageSkill(language: ProgrammingLanguage.java, displayedExperienceMonths: 0, actualExperienceMonths: 0, actualSkill: 60)});
      expect(below.isReadyForFieldSales, isFalse);
      expect(at.isReadyForFieldSales, isTrue);
      expect(PublicDemoEngineerRuntime.fromJson(at.toJson()).toJson(), at.toJson());
    });
  });
}
