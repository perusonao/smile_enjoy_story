import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

void main() {
  group('MatchingEngine', () {
    test('fit score stays within 0-100 for many random engineer/project pairs', () {
      final applicants = ApplicantGenerator(seed: 777).generate(200);
      final projects = ProjectGenerator(
        seed: 778,
        clients: sampleClients,
      ).generate(50, baseWeek: 1);

      for (var i = 0; i < applicants.length; i++) {
        final engineer = buildEngineer(
          id: 'e-$i',
          profile: applicants[i],
        );
        final project = projects[i % projects.length];
        final fit = MatchingEngine.computeFit(engineer, project);
        expect(fit.total, inInclusiveRange(0, 100));
        expect(MatchingEngine.visibleFit(engineer, project), isNotNull);
      }
    });

    test('computeFit is a pure deterministic function of its inputs', () {
      final engineer = buildEngineer(profile: buildApplicant());
      final project = buildProject();

      final first = MatchingEngine.computeFit(engineer, project);
      final second = MatchingEngine.computeFit(engineer, project);

      expect(first.total, second.total);
      expect(first.techScore, second.techScore);
      expect(first.experienceScore, second.experienceScore);
      expect(first.personalityScore, second.personalityScore);
      expect(first.conditionScore, second.conditionScore);
    });

    test('a strong engineer scores higher than a weak one for the same project', () {
      final project = buildProject(
        requiredLanguages: const [ProgrammingLanguage.java],
        requiredBackend: 5,
        requiredJapaneseLevel: 4,
        rank: ProjectRank.senior,
      );

      final strong = buildEngineer(
        id: 'strong',
        profile: buildApplicant(
          id: 'strong-applicant',
          mainLanguage: ProgrammingLanguage.java,
          mainLanguageActualSkill: 95,
          totalItExperienceMonths: 90,
          japaneseLevel: 5,
          desiredWorkStyle: WorkStyle.hybrid,
          techSkills: const TechSkillLevels(
            database: 4,
            network: 3,
            infrastructure: 3,
            frontend: 3,
            backend: 5,
            leader: 3,
            manager: 2,
          ),
          personality: const PersonalityTraits(
            looks: 4,
            cleanliness: 5,
            communication: 5,
            alcoholTolerance: 3,
            seriousness: 5,
            dishonesty: 1,
          ),
          hidden: const HiddenParameters(
            growthPotential: 5,
            stressTolerance: 5,
            retention: 5,
            projectInterviewSkill: 5,
            turnoverIntent: 5,
          ),
        ),
      );

      final weak = buildEngineer(
        id: 'weak',
        profile: buildApplicant(
          id: 'weak-applicant',
          mainLanguage: ProgrammingLanguage.python,
          mainLanguageActualSkill: 10,
          totalItExperienceMonths: 4,
          japaneseLevel: 1,
          desiredWorkStyle: WorkStyle.onsite,
          techSkills: const TechSkillLevels.zero(),
          personality: const PersonalityTraits(
            looks: 2,
            cleanliness: 2,
            communication: 1,
            alcoholTolerance: 2,
            seriousness: 2,
            dishonesty: 4,
          ),
          hidden: const HiddenParameters(
            growthPotential: 1,
            stressTolerance: 1,
            retention: 1,
            projectInterviewSkill: 1,
            turnoverIntent: 90,
          ),
        ),
      );

      final strongFit = MatchingEngine.computeFit(strong, project);
      final weakFit = MatchingEngine.computeFit(weak, project);

      expect(strongFit.total, greaterThan(weakFit.total));
      expect(
        MatchingEngine.visibleFit(strong, project).index,
        lessThanOrEqualTo(MatchingEngine.visibleFit(weak, project).index),
      );
    });
  });
}
