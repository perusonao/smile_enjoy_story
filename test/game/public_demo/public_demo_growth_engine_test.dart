import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/models/hidden_parameters.dart';
import 'package:smile_enjoy_story/domain/models/language_skill.dart';
import 'package:smile_enjoy_story/domain/models/programming_language.dart';
import 'package:smile_enjoy_story/domain/models/sales_profile.dart';
import 'package:smile_enjoy_story/domain/models/tech_skill_levels.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';

void main() {
  PublicDemoEngineerRuntime runtime({
    int skill = 30,
    int potential = 3,
    bool fastLearner = false,
  }) => PublicDemoEngineerRuntime(
    engineerId: 'engineer',
    primaryLanguage: ProgrammingLanguage.java,
    languageSkills: {
      ProgrammingLanguage.java: LanguageSkill(
        language: ProgrammingLanguage.java,
        displayedExperienceMonths: 12,
        actualExperienceMonths: 12,
        actualSkill: skill,
      ),
    },
    techSkills: const TechSkillLevels.zero(),
    hidden: HiddenParameters(
      growthPotential: potential,
      stressTolerance: 3,
      retention: 3,
      projectInterviewSkill: 3,
      turnoverIntent: 50,
    ),
    abilities: fastLearner ? {EmployeeAbility.fastLearner} : {},
  );
  PublicDemoGrowthResult grow(
    PublicDemoEngineerRuntime engineer, {
    PublicDemoGrowthSource source = PublicDemoGrowthSource.assignment,
    int morale = 65,
    Industry? industry = Industry.finance,
  }) => PublicDemoGrowthEngine.calculate(
    engineer,
    PublicDemoGrowthRequest(source: source, morale: morale, industry: industry),
  );

  test('growthPotential 5 gains more than 1', () {
    expect(
      grow(runtime(potential: 5)).capabilityChange.delta,
      greaterThan(grow(runtime(potential: 1)).capabilityChange.delta),
    );
  });

  test('fast learner has an advantage under identical conditions', () {
    expect(
      grow(runtime(potential: 4, fastLearner: true)).capabilityChange.delta,
      greaterThan(grow(runtime(potential: 4)).capabilityChange.delta),
    );
  });

  test('assignment grows more than waiting', () {
    final engineer = runtime(potential: 4);
    expect(
      grow(engineer).capabilityChange.delta,
      greaterThan(
        grow(
          engineer,
          source: PublicDemoGrowthSource.waiting,
        ).capabilityChange.delta,
      ),
    );
  });

  test('high capability has diminishing returns', () {
    expect(
      grow(runtime(skill: 30)).capabilityChange.delta,
      greaterThan(grow(runtime(skill: 86)).capabilityChange.delta),
    );
  });

  test('actual skill never exceeds 100', () {
    final result = grow(runtime(skill: 100));
    expect(result.after.actualCapability, 100);
    expect(result.capabilityChange.delta, 0);
  });

  test(
    'low morale reduces growth but does not stop a low-skill assignment',
    () {
      final result = grow(runtime(skill: 10), morale: 10);
      expect(result.capabilityChange.delta, greaterThan(0));
    },
  );

  test('waiting does not add practical or industry experience', () {
    final result = grow(runtime(), source: PublicDemoGrowthSource.waiting);
    expect(result.actualExperienceMonthsDelta, 0);
    expect(result.industryExperienceMonthsDelta, 0);
  });

  test('assignment records actual and supplied industry experience only', () {
    final result = grow(runtime());
    expect(result.actualExperienceMonthsDelta, 1);
    expect(result.industryExperienceMonthsDelta, 1);
    expect(result.after.industryExperience[Industry.finance], 1);
  });

  test('does not change SkillSheet-facing displayed experience', () {
    final result = grow(runtime());
    expect(
      result
          .after
          .languageSkills[ProgrammingLanguage.java]!
          .displayedExperienceMonths,
      12,
    );
  });

  test('calculation is deterministic and company trust is not an input', () {
    final engineer = runtime(potential: 5, fastLearner: true);
    expect(grow(engineer).after.toJson(), grow(engineer).after.toJson());
  });
}
