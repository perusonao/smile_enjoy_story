import '../../domain/domain.dart';
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
}
