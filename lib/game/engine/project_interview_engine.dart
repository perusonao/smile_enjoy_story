import '../../domain/domain.dart';
import '../models/models.dart';
import 'matching_engine.dart';
import 'rng.dart';

/// Computes a project-interview success rate and rolls the outcome (§17).
class ProjectInterviewEngine {
  const ProjectInterviewEngine._();

  /// `fitScore + personalityAdjustment - difficultyAdjustment`, clamped to
  /// `[5, 95]`.
  static int successRate(Engineer engineer, Project project) {
    final fit = MatchingEngine.computeFit(engineer, project);
    final pt = engineer.profile.personality;
    final hp = engineer.profile.hidden;

    final personalityAdjustment =
        (pt.communication - 3) * 3 +
        (pt.cleanliness - 3) * 2 +
        (hp.projectInterviewSkill - 3) * 4 +
        // Prototype 0.1 has no on-site trouble mechanics yet, so keep the
        // dishonesty bonus small per the design doc rather than a real
        // advantage.
        (pt.dishonesty - 3) * 1;
    final difficultyAdjustment = project.difficulty * 6;

    final raw = fit.total + personalityAdjustment - difficultyAdjustment;
    return raw.round().clamp(5, 95);
  }

  /// Deterministic pass/fail roll for a given `(seed, week, salt)` triple.
  static bool roll({
    required int rate,
    required int seed,
    required int week,
    required Object salt,
  }) {
    final rng = seededRandom(seed, week, salt);
    return rng.nextInt(100) < rate;
  }

  /// Picks the 1-2 most plausible reasons a project interview failed, from
  /// the weakest points of the [MatchingEngine] fit breakdown (§15). Not a
  /// text generator — just a short, deterministic pick so the player can
  /// see *why* rather than a bare "不合格".
  static List<String> failureReasons(Engineer engineer, Project project) {
    final fit = MatchingEngine.computeFit(engineer, project);
    final reasons = <String>[];

    for (final detail in fit.details) {
      if (reasons.length >= 2) break;
      if (detail.rating != PlayerVisibleFit.poor &&
          detail.rating != PlayerVisibleFit.fair) {
        continue;
      }
      switch (detail.dimension) {
        case FitDimension.language:
          reasons.add('技術経験が要求水準に不足');
        case FitDimension.techDomain:
          reasons.add('${_domainLabel(detail.techDomain)}の経験不足');
        case FitDimension.experience:
          reasons.add('実務経験年数が要求水準に不足');
        case FitDimension.communication:
          reasons.add('コミュニケーション評価不足');
        case FitDimension.japanese:
          reasons.add('日本語レベルが要求水準に不足');
      }
    }

    if (reasons.isEmpty) {
      reasons.add('他候補を優先');
    }
    return reasons.take(2).toList();
  }

  static String _domainLabel(TechDomain? domain) => switch (domain) {
    TechDomain.database => 'DB',
    TechDomain.network => 'ネットワーク',
    TechDomain.infrastructure => 'インフラ',
    TechDomain.frontend => 'フロントエンド',
    TechDomain.backend => 'バックエンド',
    TechDomain.leader => 'リーダー',
    TechDomain.manager => 'マネジメント',
    null => '技術',
  };
}
