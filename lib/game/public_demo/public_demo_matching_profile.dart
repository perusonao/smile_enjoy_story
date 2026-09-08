import '../../domain/domain.dart';
import 'public_demo_engineer_runtime.dart';
import 'public_demo_recruitment_candidate_generator.dart';
import 'public_demo_rng.dart';

/// CORE-GAMEPLAY Phase 5 (Matching): the sole place Public Demo code
/// constructs the full domain [Engineer] `MatchingEngine.computeFit`
/// (`lib/game/engine/matching_engine.dart`, unmodified — Phase 5 must not
/// touch its scoring) needs, mirroring how
/// `public_demo_recruitment_interview.dart`'s
/// [PublicDemoRecruitmentInterview] is already the sole gateway onto the
/// main game's [RecruitmentInterviewEngine] (Phase 3) for the same reason:
/// keep exactly one place responsible for bridging a Public Demo runtime
/// value onto a full domain model.
///
/// [PublicDemoEngineerRuntime] alone cannot become an [Engineer.profile]
/// truthfully: it carries no [PersonalityTraits] (communication,
/// cleanliness, ...), no `japaneseLevel`, no `desiredWorkStyle` — Public
/// Demo's own runtime model deliberately never generates or tracks any of
/// these (see [PublicDemoEngineerRuntime]'s own class doc: "does not
/// contain SkillSheet/sales values"). Rather than invent neutral
/// placeholders for a per-engineer trait the player would then see rated
/// ◎○△× as if it were measured, this file recovers the *genuine* domain
/// [Applicant] the engineer was originally generated from —
/// [PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant] is the
/// exact same sanctioned, already-audited technique
/// `PublicDemoRecruitmentInterview.domainApplicantFor` (Phase 3) already
/// uses for the identical purpose (giving a main-engine engine real
/// personality/hidden data to read), reused here rather than duplicated.
class PublicDemoMatchingProfile {
  const PublicDemoMatchingProfile._();

  /// Builds the [Engineer] `MatchingEngine.computeFit`/
  /// `ProjectComparisonEngine.rowFor` need for [runtime], deterministically
  /// from `(runSeed, runtime.engineerId)` — the same reload-safe,
  /// never-persisted-separately guarantee every other Phase 4/4.5 Public
  /// Demo adapter already provides.
  ///
  /// Two authoritative sources are combined, never fabricated:
  ///  * Stable identity/personality facts that Public Demo's own runtime
  ///    never tracks at all (personality traits, Japanese level, desired
  ///    work style, age, education, nationality, ...) are read from the
  ///    genuine originally-generated domain [Applicant] (see class doc).
  ///  * Facts Public Demo actively tracks as CURRENT, growth-updated
  ///    ground truth ([PublicDemoEngineerRuntime.techSkills], `.hidden`,
  ///    and the tracked language's experience/skill) are read from
  ///    [runtime] instead, since growth/training can make these differ
  ///    from the applicant's original application-time snapshot.
  ///
  /// Sub-language proficiency is deliberately left empty
  /// (`subLanguages: const []`): Public Demo tracks no CURRENT
  /// sub-language signal for a hired engineer, only [runtime]
  /// .primaryLanguage's own growth (see [PublicDemoEngineerRuntime]'s own
  /// doc) — showing Fit built from a stale application-time sub-language
  /// figure would misrepresent it as still current. This mirrors
  /// [PublicDemoEngineerRuntime.confirmedLanguages] already limiting the
  /// SkillSheet (Phase 4.5) the same way.
  static Engineer engineerForMatching({
    required int runSeed,
    required PublicDemoEngineerRuntime runtime,
  }) {
    final original = _originalApplicant(runSeed, runtime.engineerId);
    final currentSkill = runtime.languageSkills[runtime.primaryLanguage];
    final profile = Applicant(
      id: original.id,
      type: original.type,
      name: original.name,
      age: original.age,
      nationality: original.nationality,
      education: original.education,
      major: original.major,
      totalItExperienceMonths:
          currentSkill?.actualExperienceMonths ??
          original.totalItExperienceMonths,
      jobChangeCount: original.jobChangeCount,
      desiredMonthlySalary: original.desiredMonthlySalary,
      desiredWorkStyle: original.desiredWorkStyle,
      japaneseLevel: original.japaneseLevel,
      englishLevel: original.englishLevel,
      qualifications: original.qualifications,
      languageSkills: currentSkill == null
          ? original.languageSkills
          : {runtime.primaryLanguage: currentSkill},
      mainLanguage: runtime.primaryLanguage,
      subLanguages: const [],
      techSkills: runtime.techSkills,
      personality: original.personality,
      hidden: runtime.hidden,
    );
    return Engineer(
      id: runtime.engineerId,
      sourceApplicantId: original.id,
      profile: profile,
      // Neither field below is read by `MatchingEngine.computeFit` (it only
      // reads `engineer.profile`) or shown anywhere in Phase 5's UI — no
      // Public Demo salary/tenure fact is fabricated to fill them, they are
      // simply structural placeholders `Engineer`'s constructor requires.
      salary: 0,
      employmentWeek: 1,
      status: EngineerStatus.waiting,
    );
  }

  /// Recovers the exact domain [Applicant] [engineerId] was originally
  /// generated from, or — for the two founding engineers and any other id
  /// this generator cannot parse — the same deterministic legacy-fixture
  /// fallback `PublicDemoRecruitmentInterview._legacyFixtureApplicant`
  /// already uses (generalized here to any engineer id, not only a
  /// pre-hire applicant id): a synthetic domain [Applicant], seeded purely
  /// from the id itself via [PublicDemoRng.legacyFixtureSeed] (never from
  /// `runSeed`), so a founding engineer's Fit-relevant flavor stays the
  /// same fixed identity every playthrough, exactly like their SkillSheet
  /// already does.
  static Applicant _originalApplicant(int runSeed, String engineerId) =>
      PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
        runSeed: runSeed,
        applicantId: engineerId,
      ) ??
      ApplicantGenerator(
        seed: PublicDemoRng.legacyFixtureSeed(engineerId),
      ).generate(1).single;
}
