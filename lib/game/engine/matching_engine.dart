import '../../domain/domain.dart';
import '../models/models.dart';

/// Computes how well a waiting [Engineer] fits a [Project] (§14).
///
/// Pure and deterministic — no randomness. 100 points total:
///  * tech 55 (required language 30 + tech-domain skills 25)
///  * experience 15
///  * personality 20 (communication, cleanliness, projectInterviewSkill)
///  * condition 10 (Japanese level, work style)
class MatchingEngine {
  const MatchingEngine._();

  static const Map<ProjectRank, int> _rankExperienceExpectationMonths = {
    ProjectRank.entry: 6,
    ProjectRank.junior: 18,
    ProjectRank.middle: 36,
    ProjectRank.senior: 60,
    ProjectRank.lead: 84,
  };

  static FitBreakdown computeFit(Engineer engineer, Project project) {
    final profile = engineer.profile;

    final languageResult = _languageScore(profile, project);
    final domainResult = _domainScore(profile, project);
    final techScore = (languageResult.score + domainResult.score)
        .round()
        .clamp(0, 55);

    final expectation =
        _rankExperienceExpectationMonths[project.rank] ?? 36;
    final expRatio = (profile.totalItExperienceMonths / expectation).clamp(
      0.0,
      1.0,
    );
    final experienceScore = (expRatio * 15).round().clamp(0, 15);

    final pt = profile.personality;
    final hp = profile.hidden;
    final personalityRaw =
        (pt.communication + pt.cleanliness + hp.projectInterviewSkill) / 15.0;
    final personalityScore = (personalityRaw * 20).round().clamp(0, 20);

    final conditionScore = _conditionScore(profile, project).round().clamp(
      0,
      10,
    );

    final details = <FitDetailItem>[
      if (languageResult.language != null)
        FitDetailItem(
          dimension: FitDimension.language,
          rating: PlayerVisibleFit.fromRaw(languageResult.score, 30),
          language: languageResult.language,
        ),
      if (domainResult.dominant != null)
        FitDetailItem(
          dimension: FitDimension.techDomain,
          rating: PlayerVisibleFit.fromRaw(domainResult.dominantRatio, 1.0),
          techDomain: domainResult.dominant,
        ),
      FitDetailItem(
        dimension: FitDimension.experience,
        rating: PlayerVisibleFit.fromRaw(expRatio, 1.0),
      ),
      FitDetailItem(
        dimension: FitDimension.communication,
        rating: PlayerVisibleFit.fromLevel1to5(pt.communication),
      ),
      FitDetailItem(
        dimension: FitDimension.japanese,
        rating: PlayerVisibleFit.fromRaw(
          profile.japaneseLevel,
          project.requiredJapaneseLevel,
        ),
      ),
    ];

    return FitBreakdown(
      techScore: techScore,
      experienceScore: experienceScore,
      personalityScore: personalityScore,
      conditionScore: conditionScore,
      details: details,
    );
  }

  static PlayerVisibleFit visibleFit(Engineer engineer, Project project) =>
      PlayerVisibleFit.fromScore(computeFit(engineer, project).total);

  /// Simple `案件月単価 - 社員月給` estimate shown before proposing (§10).
  /// Prototype-level: no social-insurance or other overhead deducted.
  static int monthlyProfit(Engineer engineer, Project project) =>
      project.monthlyRate - engineer.salary;

  static ({double score, ProgrammingLanguage? language}) _languageScore(
    Applicant profile,
    Project project,
  ) {
    if (project.requiredLanguages.isEmpty) return (score: 30, language: null);

    final matchesMain = project.requiredLanguages.contains(
      profile.mainLanguage,
    );
    final matchingSub = project.requiredLanguages
        .where((l) => profile.subLanguages.contains(l))
        .toList();

    if (!matchesMain && matchingSub.isEmpty) {
      // No overlap at all: small baseline, not zero. Still report the
      // project's primary required language so the UI can show "Java: ×".
      return (score: 5, language: project.requiredLanguages.first);
    }

    final language = matchesMain ? profile.mainLanguage : matchingSub.first;
    final skill = profile.skillFor(language).actualSkill; // 0-100
    final weight = matchesMain ? 1.0 : 0.8;
    return (score: (skill / 100) * 30 * weight, language: language);
  }

  static ({double score, TechDomain? dominant, double dominantRatio})
  _domainScore(Applicant profile, Project project) {
    final tech = profile.techSkills;
    final dims = <(TechDomain domain, int required, int actual)>[
      (TechDomain.database, project.requiredDatabase, tech.database),
      (TechDomain.network, project.requiredNetwork, tech.network),
      (
        TechDomain.infrastructure,
        project.requiredInfrastructure,
        tech.infrastructure,
      ),
      (TechDomain.frontend, project.requiredFrontend, tech.frontend),
      (TechDomain.backend, project.requiredBackend, tech.backend),
      (TechDomain.leader, project.requiredLeader, tech.leader),
      (TechDomain.manager, project.requiredManager, tech.manager),
    ];
    final needed = dims.where((d) => d.$2 > 0).toList();
    if (needed.isEmpty) return (score: 25, dominant: null, dominantRatio: 1);

    final ratios = needed
        .map((d) => (d.$1, (d.$3 / d.$2).clamp(0.0, 1.0)))
        .toList();
    final avg =
        ratios.map((r) => r.$2).reduce((a, b) => a + b) / ratios.length;

    // The dominant dimension is the one the project requires most; ties
    // break toward the first in declaration order above.
    needed.sort((a, b) => b.$2.compareTo(a.$2));
    final dominantDim = needed.first.$1;
    final dominantRatio = ratios
        .firstWhere((r) => r.$1 == dominantDim)
        .$2;

    return (score: avg * 25, dominant: dominantDim, dominantRatio: dominantRatio);
  }

  static double _conditionScore(Applicant profile, Project project) {
    var score = 0.0;
    final jpRatio = (profile.japaneseLevel / project.requiredJapaneseLevel)
        .clamp(0.0, 1.0);
    score += jpRatio * 5;
    score += _workStyleCompatible(profile.desiredWorkStyle, project.remotePolicy)
        ? 5
        : 2;
    return score;
  }

  static bool _workStyleCompatible(WorkStyle desired, RemotePolicy policy) {
    switch (desired) {
      case WorkStyle.onsite:
        return policy == RemotePolicy.onsite || policy == RemotePolicy.hybrid;
      case WorkStyle.hybrid:
        return true;
      case WorkStyle.fullRemote:
        return policy == RemotePolicy.remote || policy == RemotePolicy.hybrid;
    }
  }
}
