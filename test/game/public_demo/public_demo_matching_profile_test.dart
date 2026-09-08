import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/engine/matching_engine.dart';
import 'package:smile_enjoy_story/game/engine/project_comparison_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_matching_profile.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';

/// SES CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): coverage for
/// [PublicDemoMatchingProfile] -- the sole adapter that builds the domain
/// [Engineer] `MatchingEngine.computeFit` needs from a Public Demo
/// [PublicDemoEngineerRuntime]. See
/// `docs/reports/SES_CORE-GAMEPLAY_Phase5_Matching_Result.md`.
void main() {
  group('deterministic', () {
    test('same (runSeed, runtime) always builds a byte-identical Engineer '
        'profile', () {
      final runtime = publicDemoInitialEngineerRuntimes.first; // eng-01

      final first = PublicDemoMatchingProfile.engineerForMatching(
        runSeed: 42,
        runtime: runtime,
      );
      final second = PublicDemoMatchingProfile.engineerForMatching(
        runSeed: 42,
        runtime: runtime,
      );

      expect(first.profile.toJson(), second.profile.toJson());
    });

    test('the resulting Engineer x Project Fit is stable across repeated '
        'ProjectComparisonEngine.rowFor calls (no hidden RNG draw inside '
        'Matching)', () {
      final runtime = publicDemoInitialEngineerRuntimes.first;
      final engineer = PublicDemoMatchingProfile.engineerForMatching(
        runSeed: 999,
        runtime: runtime,
      );
      final project = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 999,
        month: 4,
      ).first.project;

      final firstFit = ProjectComparisonEngine.rowFor(engineer, project).fit;
      final secondFit = ProjectComparisonEngine.rowFor(engineer, project).fit;

      expect(firstFit.total, secondFit.total);
      expect(firstFit.techScore, secondFit.techScore);
      expect(firstFit.experienceScore, secondFit.experienceScore);
      expect(firstFit.personalityScore, secondFit.personalityScore);
      expect(firstFit.conditionScore, secondFit.conditionScore);
    });

    test('a founding engineer (legacy fixture id) keeps the same personality '
        'facts across different runSeeds -- their profile predates any '
        'playthrough seed', () {
      final runtime = publicDemoInitialEngineerRuntimes.first; // eng-01

      final underSeedA = PublicDemoMatchingProfile.engineerForMatching(
        runSeed: 111,
        runtime: runtime,
      );
      final underSeedB = PublicDemoMatchingProfile.engineerForMatching(
        runSeed: 222,
        runtime: runtime,
      );

      expect(
        underSeedA.profile.personality.toJson(),
        underSeedB.profile.personality.toJson(),
      );
      expect(underSeedA.profile.japaneseLevel, underSeedB.profile.japaneseLevel);
      expect(
        underSeedA.profile.desiredWorkStyle,
        underSeedB.profile.desiredWorkStyle,
      );
    });
  });

  group('current runtime facts override the original application snapshot', () {
    test('techSkills/hidden come from the CURRENT runtime, not the original '
        'generated applicant', () {
      const runtime = PublicDemoEngineerRuntime(
        engineerId: 'eng-01',
        primaryLanguage: ProgrammingLanguage.java,
        languageSkills: {
          ProgrammingLanguage.java: LanguageSkill(
            language: ProgrammingLanguage.java,
            displayedExperienceMonths: 48,
            actualExperienceMonths: 48,
            actualSkill: 91,
          ),
        },
        techSkills: TechSkillLevels(
          database: 5,
          network: 0,
          infrastructure: 0,
          frontend: 0,
          backend: 5,
          leader: 2,
          manager: 0,
        ),
        hidden: HiddenParameters(
          growthPotential: 5,
          stressTolerance: 5,
          retention: 5,
          projectInterviewSkill: 5,
          turnoverIntent: 10,
        ),
      );

      final engineer = PublicDemoMatchingProfile.engineerForMatching(
        runSeed: 7,
        runtime: runtime,
      );

      expect(engineer.profile.techSkills.toJson(), runtime.techSkills.toJson());
      expect(engineer.profile.hidden.toJson(), runtime.hidden.toJson());
      expect(engineer.profile.mainLanguage, ProgrammingLanguage.java);
      expect(
        engineer.profile.languageSkills[ProgrammingLanguage.java]
            ?.actualExperienceMonths,
        48,
      );
      expect(
        engineer.profile.languageSkills[ProgrammingLanguage.java]?.actualSkill,
        91,
      );
      // No fabricated sub-language signal (see PublicDemoMatchingProfile's
      // own doc): Public Demo tracks no current sub-language proficiency.
      expect(engineer.profile.subLanguages, isEmpty);
    });
  });

  group('MatchingEngine.computeFit is the only scoring path exercised', () {
    test('the adapter never reimplements Fit scoring -- computeFit on the '
        'adapted Engineer produces a valid 0..100 total', () {
      final runtime = publicDemoInitialEngineerRuntimes[1]; // eng-02
      final engineer = PublicDemoMatchingProfile.engineerForMatching(
        runSeed: 55,
        runtime: runtime,
      );
      final project = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 55,
        month: 6,
      )[1].project;

      final fit = MatchingEngine.computeFit(engineer, project);

      expect(fit.total, inInclusiveRange(0, 100));
      expect(
        fit.techScore + fit.experienceScore + fit.personalityScore + fit.conditionScore,
        fit.total,
      );
    });
  });
}
