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

    final techScore = (_languageScore(profile, project) + _domainScore(profile, project))
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

    return FitBreakdown(
      techScore: techScore,
      experienceScore: experienceScore,
      personalityScore: personalityScore,
      conditionScore: conditionScore,
    );
  }

  static PlayerVisibleFit visibleFit(Engineer engineer, Project project) =>
      PlayerVisibleFit.fromScore(computeFit(engineer, project).total);

  static double _languageScore(Applicant profile, Project project) {
    if (project.requiredLanguages.isEmpty) return 30;

    final matchesMain = project.requiredLanguages.contains(
      profile.mainLanguage,
    );
    final matchingSub = project.requiredLanguages
        .where((l) => profile.subLanguages.contains(l))
        .toList();

    if (!matchesMain && matchingSub.isEmpty) {
      return 5; // no overlap at all: small baseline, not zero
    }

    final language = matchesMain ? profile.mainLanguage : matchingSub.first;
    final skill = profile.skillFor(language).actualSkill; // 0-100
    final weight = matchesMain ? 1.0 : 0.8;
    return (skill / 100) * 30 * weight;
  }

  static double _domainScore(Applicant profile, Project project) {
    final tech = profile.techSkills;
    final dims = <(int required, int actual)>[
      (project.requiredDatabase, tech.database),
      (project.requiredNetwork, tech.network),
      (project.requiredInfrastructure, tech.infrastructure),
      (project.requiredFrontend, tech.frontend),
      (project.requiredBackend, tech.backend),
      (project.requiredLeader, tech.leader),
      (project.requiredManager, tech.manager),
    ];
    final needed = dims.where((d) => d.$1 > 0).toList();
    if (needed.isEmpty) return 25;

    final ratios = needed.map((d) => (d.$2 / d.$1).clamp(0.0, 1.0));
    final avg = ratios.reduce((a, b) => a + b) / ratios.length;
    return avg * 25;
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
