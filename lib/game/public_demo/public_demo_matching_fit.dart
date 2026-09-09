import '../../domain/domain.dart';
import '../engine/matching_engine.dart';
import '../models/fit_result.dart';
import 'public_demo_engineer_runtime.dart';

/// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): evaluates a Public
/// Demo employee against a real Phase 4 [Project] candidate by reusing the
/// main game's authoritative [MatchingEngine.computeFit] — never a second,
/// Public-Demo-only matching formula.
///
/// [MatchingEngine.computeFit] requires a full [Engineer] (whose
/// [Applicant] profile carries several fields Public Demo's own
/// [PublicDemoEngineerRuntime] does not model at all: `PersonalityTraits
/// .communication`/`.cleanliness`, `japaneseLevel`, `desiredWorkStyle`, plus
/// a handful more the formula never reads — age/education/major/...).
/// [_placeholderEngineerFor] builds the minimal [Engineer] needed to call
/// that function:
///  - genuinely authoritative Public Demo data for every input the
///    dimensions this file actually exposes to the player
///    ([FitDimension.language], [FitDimension.techDomain],
///    [FitDimension.experience]) read: [PublicDemoEngineerRuntime
///    .primaryLanguage] as `mainLanguage`, only the *confirmed*
///    [PublicDemoEngineerRuntime.languageSkills] entries (mirrors
///    `PublicDemoSkillSheetDisplayFactory`'s own "only a confirmed language
///    is real" rule in public_demo_skill_sheet_display_projection.dart — an
///    unconfirmed seeded capability entry is never presented as real
///    language experience here either), [PublicDemoEngineerRuntime
///    .techSkills] verbatim, and — as of the Codex P1 fix on PR #212 —
///    [PublicDemoEngineerRuntime.totalItExperienceMonths] as
///    `totalItExperienceMonths`. This is **not** derived from
///    [PublicDemoEngineerRuntime.confirmedLanguages]/`languageSkills`: an
///    experienced hire's résumé total IT experience is a real fact
///    independent of which language it was earned in, and
///    [PublicDemoEngineerRuntime.fromApplicant] carries it through
///    separately from the (deliberately unconfirmed) per-language capability
///    entry precisely so this adapter never has to choose between
///    fabricating language-specific experience and discarding a known
///    total. See [PublicDemoEngineerRuntime.totalItExperienceMonths]'s own
///    doc for the full before/after.
///  - a fixed, documented, never-varying, never-displayed placeholder for
///    every field only the personality/condition dimensions
///    ([FitDimension.communication]/[FitDimension.japanese]) or unrelated
///    Applicant/Engineer shape fields (age/education/major/...) read.
///    Public Demo does not model personality traits, Japanese level, or
///    desired work style for an employee at all, so
///    [PublicDemoEngineerProjectFit.visibleDetails] below never reads
///    those two dimensions out of the resulting [FitBreakdown]. Because the
///    placeholder is one fixed constant shared by every employee, it
///    carries no per-employee information and cannot be used to back-solve
///    any real (hidden or otherwise) value — the one genuinely
///    employee-specific hidden input passed through, [PublicDemoEngineerRuntime
///    .hidden] itself, only ever affects the personality dimension this
///    class deliberately never surfaces.
class PublicDemoEngineerProjectFit {
  const PublicDemoEngineerProjectFit._(this._fit);

  final FitBreakdown _fit;

  /// Only the [FitDetailItem]s this file can defend as fully truthful for a
  /// Public Demo employee: language / tech-domain / experience, in that
  /// order. The personality/condition-derived items are never exposed —
  /// see this class's own doc for why.
  List<FitDetailItem> get visibleDetails => [
    for (final item in _fit.details)
      if (item.dimension == FitDimension.language ||
          item.dimension == FitDimension.techDomain ||
          item.dimension == FitDimension.experience)
        item,
  ];

  /// A coarse "面談通過見込み" (interview passage prospect) tier — Issue
  /// #205's own example wording — derived only from [visibleDetails]' own
  /// ◎○△× tiers (see [PublicDemoMatchingProspect.fromDetails]). Never the
  /// raw [FitBreakdown.total] (which folds in the placeholder-driven
  /// personality/condition scores this class never shows), and never a new
  /// probability formula over hidden parameters.
  PublicDemoMatchingProspect get prospect =>
      PublicDemoMatchingProspect.fromDetails(visibleDetails);

  /// The one and only [MatchingEngine.computeFit] call for a given
  /// (employee, project) pair — everything else in this file only reshapes
  /// its result, never re-derives it.
  static PublicDemoEngineerProjectFit compute({
    required PublicDemoEngineerRuntime runtime,
    required Project project,
  }) => PublicDemoEngineerProjectFit._(
    MatchingEngine.computeFit(_placeholderEngineerFor(runtime), project),
  );

  /// CORE-GAMEPLAY Phase 6 (Project Interview Gameplay): exposes this
  /// file's own [_placeholderEngineerFor] builder so
  /// `public_demo_project_interview.dart` can hand the exact same
  /// placeholder [Engineer] Phase 5's [compute] already builds for this
  /// [runtime] to [ClientInterviewEngine]/[ProjectInterviewEngine] — never
  /// a second, independently-built stand-in that could quietly drift from
  /// the one Matching itself scored against.
  static Engineer engineerFor(PublicDemoEngineerRuntime runtime) =>
      _placeholderEngineerFor(runtime);

  static Engineer _placeholderEngineerFor(PublicDemoEngineerRuntime runtime) {
    final confirmedLanguageSkills = <ProgrammingLanguage, LanguageSkill>{
      for (final skill in runtime.languageSkills.values)
        if (runtime.confirmedLanguages.contains(skill.language))
          skill.language: skill,
    };

    final profile = Applicant(
      id: runtime.engineerId,
      // Shape-only field: ApplicantType never enters computeFit's math.
      type: ApplicantType.midLevelEngineer,
      name: '',
      age: 30,
      nationality: 'JP',
      education: Education.university,
      major: Major.informationTechnology,
      // Codex P1 fix (PR #212): the employee's real aggregate IT experience
      // — independent of confirmedLanguages/languageSkills, see this file's
      // own class doc and PublicDemoEngineerRuntime.totalItExperienceMonths.
      totalItExperienceMonths: runtime.totalItExperienceMonths,
      jobChangeCount: 0,
      desiredMonthlySalary: 0,
      // Placeholder: only feeds FitDimension.japanese (condition), which
      // [PublicDemoEngineerProjectFit.visibleDetails] never surfaces.
      desiredWorkStyle: WorkStyle.hybrid,
      // Placeholder: only feeds FitDimension.japanese (condition), never
      // surfaced — see this class's own doc.
      japaneseLevel: 3,
      englishLevel: 3,
      qualifications: const [],
      languageSkills: confirmedLanguageSkills,
      mainLanguage: runtime.primaryLanguage,
      // Public Demo tracks no confirmed secondary-language mastery.
      subLanguages: const [],
      techSkills: runtime.techSkills,
      // Placeholder: communication/cleanliness only feed
      // FitDimension.communication (personality), never surfaced — see
      // this class's own doc. Not read from anywhere real because Public
      // Demo does not model personality traits for an employee at all.
      personality: const PersonalityTraits(
        looks: 3,
        cleanliness: 3,
        communication: 3,
        alcoholTolerance: 3,
        seriousness: 3,
        dishonesty: 3,
      ),
      // Genuinely authoritative — but only ever affects the personality
      // dimension this class never surfaces to the player.
      hidden: runtime.hidden,
    );

    return Engineer(
      id: runtime.engineerId,
      sourceApplicantId: runtime.engineerId,
      profile: profile,
      salary: 0,
      employmentWeek: 1,
      status: EngineerStatus.waiting,
    );
  }
}

/// A coarse, qualitative "面談通過見込み" tier (Issue #205's own required
/// wording) — never a raw score or percentage.
enum PublicDemoMatchingProspect {
  high,
  medium,
  low;

  String get label => switch (this) {
    PublicDemoMatchingProspect.high => '高',
    PublicDemoMatchingProspect.medium => '中',
    PublicDemoMatchingProspect.low => '低',
  };

  /// A simple, disclosed aggregation rule over already-computed, non-hidden
  /// [FitDetailItem] tiers — deliberately NOT a new probability/formula
  /// over hidden parameters (Issue #205's explicit constraint):
  ///  - any ×（[PlayerVisibleFit.poor]）among [details] → low
  ///  - every detail ◎/○ → high
  ///  - otherwise (a mix that includes at least one △ but no ×) → medium
  static PublicDemoMatchingProspect fromDetails(List<FitDetailItem> details) {
    if (details.isEmpty) return PublicDemoMatchingProspect.medium;
    final hasPoor = details.any(
      (item) => item.rating == PlayerVisibleFit.poor,
    );
    if (hasPoor) return PublicDemoMatchingProspect.low;
    final allPositive = details.every(
      (item) =>
          item.rating == PlayerVisibleFit.excellent ||
          item.rating == PlayerVisibleFit.good,
    );
    if (allPositive) return PublicDemoMatchingProspect.high;
    return PublicDemoMatchingProspect.medium;
  }
}
