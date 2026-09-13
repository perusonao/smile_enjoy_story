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

  /// SES First Fun Quarter AI Replay Audit #3 P1 fix: the actual, final
  /// evaluation used for the offer-eligibility gate and the post-interview
  /// "評価" card label -- once [session] is genuinely finished, this is no
  /// longer [PublicDemoApplicant.interviewScore] alone (a résumé/personality
  /// read fixed at candidate generation, before any interactive interview
  /// even starts).
  ///
  /// Instead it folds in how credible the candidate's own answers actually
  /// were across the 3 questions the player chose to ask
  /// ([RecruitmentInterviewEngine.generateAnswer]'s `credibility`, already
  /// computed and persisted per [ApplicantAnswer] -- no new authority, no
  /// new save-schema field, no new RNG roll here). A candidate who gives
  /// specific, consistent answers to the categories probed pushes this score
  /// up from the baseline; one who is vague, inconsistent, or over-confident
  /// pulls it down -- so which questions the player picks, and how honestly
  /// this particular candidate answers them, now has a real, deterministic
  /// (reload-safe) effect on whether a salary offer ever becomes possible,
  /// instead of zero effect. `interviewScore` itself stays exactly as it
  /// was generated -- still read as-is by
  /// [PublicDemoEngineerRuntime._usesPotentialTemplate] and anywhere else
  /// that is not this offer-eligibility decision -- so this is purely an
  /// additive read, not a redefinition of the existing field.
  ///
  /// Returns `null` before [session] is completed (or if it has no
  /// applicant answers yet): callers must not display or gate on any
  /// evaluation before the interactive interview genuinely concludes -- see
  /// the Result Report's "面談前に結果を先取りして見せない" requirement.
  ///
  /// AI Replay Audit #3 P1-1 backward-compatibility fix: once completed,
  /// [applicant.qaEvaluationApplies] decides which single rule this
  /// applicant's decision is scored under -- never both, never a coin
  /// flip. `false` (a decision made and persisted before this evaluation
  /// existed, including any save from before this field itself existed --
  /// see [PublicDemoApplicant.fromJson]'s default) grandfathers this
  /// applicant to the original, already-promised [interviewScore] alone,
  /// exactly reproducing the eligibility that decision carried at the time
  /// it was made. `true` (a decision this exact build made, via
  /// [PublicDemoAggregate.concludeInterviewSession]) always uses the real,
  /// Q&A-derived evaluation below -- a newly-decided candidate is never
  /// grandfathered, so a genuinely poor performer still fails.
  static int? finalEvaluationScore({
    required PublicDemoApplicant applicant,
    required RecruitmentInterviewSession? session,
  }) {
    if (session == null || !session.completed) {
      return null;
    }
    if (!applicant.qaEvaluationApplies) {
      return applicant.interviewScore;
    }
    if (session.applicantAnswers.isEmpty) {
      return applicant.interviewScore;
    }
    final totalCredibility = session.applicantAnswers.fold<int>(
      0,
      (sum, answer) => sum + answer.credibility,
    );
    final averageCredibility =
        totalCredibility / session.applicantAnswers.length;
    final credibilityDelta = ((averageCredibility - 50) / 2.5).round();
    return (applicant.interviewScore + credibilityDelta).clamp(0, 100);
  }
}
