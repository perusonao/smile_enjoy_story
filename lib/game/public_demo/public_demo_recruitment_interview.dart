import '../../domain/domain.dart';
import '../engine/recruitment_interview_engine.dart';
import '../models/models.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_recruitment_candidate_generator.dart';
import 'public_demo_rng.dart';
import 'public_demo_state.dart';

/// Public Demo's adapter onto the main game's authoritative recruitment
/// interview engine (`lib/game/engine/recruitment_interview_engine.dart`) --
/// reused as-is, not reimplemented (CORE-GAMEPLAY Phase 3). This file is
/// intentionally the only place Public Demo code constructs the full domain
/// [Applicant] a [RecruitmentInterviewSession] needs, or calls
/// [RecruitmentInterviewEngine] directly, mirroring how [PublicDemoRng] is
/// the sole gateway onto `rng.dart`.
class PublicDemoRecruitmentInterview {
  const PublicDemoRecruitmentInterview._();

  /// Recovers the exact same full domain [Applicant] this candidate was
  /// generated from (CORE-GAMEPLAY Phase 2's own documented Phase 3
  /// integration point), re-identified to carry [applicant]'s own
  /// [PublicDemoApplicant.id] rather than the domain generator's internal
  /// `applicant-<seed>-<n>` id -- so the resulting [RecruitmentInterviewSession
  /// .applicantId] (set by [RecruitmentInterviewEngine.start] from
  /// `applicant.id`) stays keyed by the same id Public Demo's own workflow
  /// (`PublicDemoWorkflowState.interviewSessions`) already uses everywhere
  /// else. [Applicant] has no `copyWith` (plain immutable data class from
  /// the Phase 0 domain layer) -- [_reidentified] just re-spreads every
  /// field with the one id swapped, changing nothing else about the
  /// recovered applicant.
  ///
  /// Falls back to [_legacyFixtureApplicant] for the two hand-authored
  /// founding-pool pools (`app-01`/`app-02`/`free-template-*`) that predate
  /// [PublicDemoSeededRecruitmentGenerator] and were never produced by
  /// `ApplicantGenerator` -- see that method's own doc for exactly what the
  /// fallback does and does not guarantee.
  static Applicant domainApplicantFor({
    required int runSeed,
    required PublicDemoApplicant applicant,
  }) {
    final generated =
        PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
          runSeed: runSeed,
          applicantId: applicant.id,
        );
    final base = generated ?? _legacyFixtureApplicant(applicant.id);
    return _reidentified(base, applicant.id);
  }

  static Applicant _reidentified(Applicant a, String id) => Applicant(
    id: id,
    type: a.type,
    name: a.name,
    age: a.age,
    nationality: a.nationality,
    education: a.education,
    major: a.major,
    totalItExperienceMonths: a.totalItExperienceMonths,
    jobChangeCount: a.jobChangeCount,
    desiredMonthlySalary: a.desiredMonthlySalary,
    desiredWorkStyle: a.desiredWorkStyle,
    japaneseLevel: a.japaneseLevel,
    englishLevel: a.englishLevel,
    qualifications: a.qualifications,
    languageSkills: a.languageSkills,
    mainLanguage: a.mainLanguage,
    subLanguages: a.subLanguages,
    techSkills: a.techSkills,
    personality: a.personality,
    hidden: a.hidden,
  );

  /// Legacy-fixture fallback (`app-01`, `app-02`, `free-template-*`):
  /// [PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant]
  /// structurally cannot recover these -- they were hand-authored constants
  /// (`publicDemoMayApplicants`/`publicDemoFreeApplicants`,
  /// `public_demo_recruitment.dart`) from before that generator existed, not
  /// output from `ApplicantGenerator`, so there is no `runSeed`-linked domain
  /// `Applicant` to regenerate.
  ///
  /// A synthetic domain `Applicant` is generated instead purely so
  /// [RecruitmentInterviewEngine] has personality/hidden/skill data to draw
  /// interview flavor (answers, observations) from -- deliberately seeded
  /// from the applicant's own id alone ([PublicDemoRng.legacyFixtureSeed]),
  /// NOT from `runSeed`, since these fixtures are the same for every
  /// playthrough (the founding pool), not seed-generated candidates. This is
  /// a narrow, display-flavor-only exception: the résumé-visible facts a
  /// player actually decides on (name, résumé text, requested salary,
  /// interview/acceptance score gates) still come from the authoritative
  /// [PublicDemoApplicant] fixture itself, never from this synthetic
  /// stand-in, exactly like every other candidate's interview. See the
  /// Phase 3 result report's "legacy save handling" section.
  static Applicant _legacyFixtureApplicant(String applicantId) =>
      ApplicantGenerator(
        seed: PublicDemoRng.legacyFixtureSeed(applicantId),
      ).generate(1).single;

  static int _seed({
    required int runSeed,
    required int month,
    required String applicantId,
  }) => PublicDemoRng.derivedSeed(
    runSeed: runSeed,
    month: month,
    namespace: PublicDemoRngNamespace.recruitmentInterview,
    identifier: applicantId,
  );

  /// Starts a new interview session for [applicant] (already re-identified
  /// via [domainApplicantFor]). Public Demo has no `OfficeType`/company
  /// credit concept of its own yet -- [OfficeType.smallOffice] (the
  /// founding-era baseline) and a neutral `companyCredit: 0` stand in, since
  /// this baseline only shifts the initial `companyImpression` roll by a
  /// small, bounded amount and no Public Demo balance authority reads it.
  /// `companySize` uses Public Demo's own real engineer headcount, the
  /// direct analogue of the main engine's `state.engineers.length`.
  static RecruitmentInterviewSession start({
    required PublicDemoState state,
    required Applicant applicant,
    required int companySize,
  }) => RecruitmentInterviewEngine.start(
    seed: _seed(
      runSeed: state.runSeed,
      month: state.month,
      applicantId: applicant.id,
    ),
    week: state.month,
    applicant: applicant,
    companyCredit: 0,
    officeType: OfficeType.smallOffice,
    companySize: companySize,
  );

  static RecruitmentInterviewSession ask({
    required PublicDemoState state,
    required RecruitmentInterviewSession session,
    required Applicant applicant,
    required InterviewQuestionCategory category,
  }) => RecruitmentInterviewEngine.ask(
    session: session,
    applicant: applicant,
    seed: _seed(
      runSeed: state.runSeed,
      month: state.month,
      applicantId: applicant.id,
    ),
    category: category,
  );

  static RecruitmentInterviewSession answerReverse(
    RecruitmentInterviewSession session,
    int choiceIndex,
  ) => RecruitmentInterviewEngine.answerReverse(session, choiceIndex);
}
