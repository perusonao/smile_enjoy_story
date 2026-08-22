import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/models/language_skill.dart';
import 'package:smile_enjoy_story/domain/models/programming_language.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  const applicant = PublicDemoApplicant(
    id: 'hire-01',
    name: '新人',
    resumeSummary: '未経験',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 25,
    experienceMonths: 0,
    requestedMonthlySalary: 250000,
  );

  PublicDemoEngineerRuntime runtime(int capability) =>
      PublicDemoEngineerRuntime.fromApplicant(applicant).copyWith(
        languageSkills: {
          ProgrammingLanguage.java: LanguageSkill(
            language: ProgrammingLanguage.java,
            displayedExperienceMonths: 0,
            actualExperienceMonths: 0,
            actualSkill: capability,
          ),
        },
      );

  test('capability 59 cannot start field sales', () {
    expect(runtime(59).isReadyForFieldSales, isFalse);
  });
  test('capability 60 can start field sales', () {
    expect(runtime(60).isReadyForFieldSales, isTrue);
  });
  test('readiness uses runtime actual capability', () {
    expect(runtime(60).actualCapability, 60);
  });
  test('applicant sales skill fit is not rewritten by growth', () {
    runtime(75);
    expect(applicant.salesSkillFit, 25);
  });
  test('new hire enters the existing sales flow at waiting', () {
    expect(
      PublicDemoEngineerSales.fromApplicant(applicant).stage,
      PublicDemoSalesStage.waiting,
    );
  });
  test('runtime capability drives the new hire interview', () {
    final profile = PublicDemoEngineerSales.fromApplicant(
      applicant,
    ).interviewProfile;
    expect(
      PublicDemoInterviewEvaluator.evaluate(
        type: PublicDemoInterviewType.partner,
        profile: profile,
        actualCapability: 80,
      ).passed,
      isTrue,
    );
  });
  test('initial engineer interview remains unchanged', () {
    final profile = publicDemoInitialEngineers.first.interviewProfile;
    expect(
      PublicDemoInterviewEvaluator.evaluate(
        type: PublicDemoInterviewType.partner,
        profile: profile,
        actualCapability: 78,
      ).score,
      PublicDemoInterviewEvaluator.evaluate(
        type: PublicDemoInterviewType.partner,
        profile: profile,
      ).score,
    );
  });
  test('assignment can be created for a non-initial engineer id', () {
    final assignment = PublicDemoAssignment.forOrderedEngineer(
      engineerId: applicant.id,
      engineerName: applicant.name,
      humanity: 60,
    );
    expect(assignment.engineerId, applicant.id);
  });
  test('missing runtime is handled without StateError', () {
    expect(PublicDemoState.aprilStart().runtimeForOrNull('missing'), isNull);
  });
}
