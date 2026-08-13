import '../../domain/domain.dart';

/// Breakdown of an engineer/project match, computed by `MatchingEngine`.
///
/// Point allocation (100 total) follows the Playable 0.1 design doc §14:
/// tech 55 (language 30 + tech-domain skills 25), experience 15,
/// personality 20, condition 10.
///
/// Playable 0.2 §9 additionally exposes a handful of individual
/// [details] (language / dominant tech domain / experience / communication
/// / Japanese) so the proposal comparison UI can show a short breakdown
/// like "Java: ◎ / Backend: ○ / 経験年数: △ / コミュ力: ◎ / 日本語: ◎"
/// instead of only the aggregate score.
class FitBreakdown {
  final int techScore;
  final int experienceScore;
  final int personalityScore;
  final int conditionScore;
  final List<FitDetailItem> details;

  const FitBreakdown({
    required this.techScore,
    required this.experienceScore,
    required this.personalityScore,
    required this.conditionScore,
    this.details = const [],
  });

  int get total =>
      (techScore + experienceScore + personalityScore + conditionScore)
          .clamp(0, 100);
}

/// Which sub-dimension a [FitDetailItem] rates.
enum FitDimension { language, techDomain, experience, communication, japanese }

/// One line of the Fit breakdown (§9). The UI is responsible for turning
/// [language]/[techDomain] into a localized label — this model layer stays
/// presentation-free.
class FitDetailItem {
  final FitDimension dimension;
  final PlayerVisibleFit rating;
  final ProgrammingLanguage? language;
  final TechDomain? techDomain;

  const FitDetailItem({
    required this.dimension,
    required this.rating,
    this.language,
    this.techDomain,
  });
}

/// The seven technical domain skills tracked on [TechSkillLevels] /
/// [Project]'s `required*` fields, named so [FitDetailItem] can point at
/// "whichever one this project cares about most" without stringly-typed
/// keys.
enum TechDomain { database, network, infrastructure, frontend, backend, leader, manager }

/// The four-tier rating shown to the player instead of a raw score (§15).
enum PlayerVisibleFit {
  excellent, // ◎ かなり有力
  good, // ○ 有力
  fair, // △ 微妙
  poor; // × 厳しい

  String get symbol => switch (this) {
    PlayerVisibleFit.excellent => '◎',
    PlayerVisibleFit.good => '○',
    PlayerVisibleFit.fair => '△',
    PlayerVisibleFit.poor => '×',
  };

  String get label => switch (this) {
    PlayerVisibleFit.excellent => 'かなり有力',
    PlayerVisibleFit.good => '有力',
    PlayerVisibleFit.fair => '微妙',
    PlayerVisibleFit.poor => '厳しい',
  };

  static PlayerVisibleFit fromScore(int score) {
    if (score >= 85) return PlayerVisibleFit.excellent;
    if (score >= 70) return PlayerVisibleFit.good;
    if (score >= 50) return PlayerVisibleFit.fair;
    return PlayerVisibleFit.poor;
  }

  /// Rates a raw `0..max` sub-score the same way [fromScore] rates a
  /// `0..100` total: by normalizing to a percentage first.
  static PlayerVisibleFit fromRaw(num raw, num max) {
    if (max <= 0) return PlayerVisibleFit.fair;
    return fromScore(((raw / max) * 100).round().clamp(0, 100));
  }

  /// Rates a direct 1-5 level (e.g. a personality trait) without going
  /// through a percentage — 5 is always ◎, 1 is always ×.
  static PlayerVisibleFit fromLevel1to5(int level) {
    if (level >= 5) return PlayerVisibleFit.excellent;
    if (level == 4) return PlayerVisibleFit.good;
    if (level == 3) return PlayerVisibleFit.fair;
    return PlayerVisibleFit.poor;
  }
}
