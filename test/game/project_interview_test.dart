import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

void main() {
  group('ProjectInterviewEngine', () {
    test('success rate is always clamped to 5-95, even in extreme cases', () {
      final easyProject = buildProject(
        difficulty: 1,
        requiredLanguages: const [ProgrammingLanguage.java],
        requiredBackend: 1,
        requiredJapaneseLevel: 1,
      );
      final bestEngineer = buildEngineer(
        profile: buildApplicant(
          mainLanguage: ProgrammingLanguage.java,
          mainLanguageActualSkill: 100,
          totalItExperienceMonths: 120,
          japaneseLevel: 5,
          techSkills: const TechSkillLevels(
            database: 5,
            network: 5,
            infrastructure: 5,
            frontend: 5,
            backend: 5,
            leader: 5,
            manager: 5,
          ),
          personality: const PersonalityTraits(
            looks: 5,
            cleanliness: 5,
            communication: 5,
            alcoholTolerance: 5,
            seriousness: 5,
            dishonesty: 5,
          ),
          hidden: const HiddenParameters(
            growthPotential: 5,
            stressTolerance: 5,
            retention: 5,
            projectInterviewSkill: 5,
            turnoverIntent: 0,
          ),
        ),
      );
      final highRate = ProjectInterviewEngine.successRate(bestEngineer, easyProject);
      expect(highRate, lessThanOrEqualTo(95));

      final hardProject = buildProject(
        difficulty: 5,
        requiredLanguages: const [ProgrammingLanguage.java],
        requiredBackend: 5,
        requiredJapaneseLevel: 5,
      );
      final worstEngineer = buildEngineer(
        profile: buildApplicant(
          mainLanguage: ProgrammingLanguage.python,
          mainLanguageActualSkill: 5,
          totalItExperienceMonths: 1,
          japaneseLevel: 1,
          techSkills: const TechSkillLevels.zero(),
          personality: const PersonalityTraits(
            looks: 1,
            cleanliness: 1,
            communication: 1,
            alcoholTolerance: 1,
            seriousness: 1,
            dishonesty: 1,
          ),
          hidden: const HiddenParameters(
            growthPotential: 1,
            stressTolerance: 1,
            retention: 1,
            projectInterviewSkill: 1,
            turnoverIntent: 100,
          ),
        ),
      );
      final lowRate = ProjectInterviewEngine.successRate(worstEngineer, hardProject);
      expect(lowRate, greaterThanOrEqualTo(5));

      expect(highRate, greaterThan(lowRate));
    });

    test('roll is reproducible for the same (rate, seed, week, salt)', () {
      final results = List.generate(
        5,
        (_) => ProjectInterviewEngine.roll(
          rate: 50,
          seed: 12345,
          week: 3,
          salt: 'engineer-1:project-1',
        ),
      );
      expect(results.toSet().length, 1, reason: 'same inputs must always roll the same outcome');
    });

    test('roll differs (in general) across different seeds', () {
      final outcomes = <bool>{
        for (var seed = 0; seed < 20; seed++)
          ProjectInterviewEngine.roll(rate: 50, seed: seed, week: 1, salt: 'x'),
      };
      // With 20 different seeds at a 50% rate we should see both outcomes.
      expect(outcomes.length, 2);
    });
  });
}
