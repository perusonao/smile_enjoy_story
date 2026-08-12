/// Breakdown of an engineer/project match, computed by `MatchingEngine`.
///
/// Point allocation (100 total) follows the Playable 0.1 design doc §14:
/// tech 55 (language 30 + domain skill 25), experience 15, personality 20,
/// condition 10.
class FitBreakdown {
  final int techScore;
  final int experienceScore;
  final int personalityScore;
  final int conditionScore;

  const FitBreakdown({
    required this.techScore,
    required this.experienceScore,
    required this.personalityScore,
    required this.conditionScore,
  });

  int get total =>
      (techScore + experienceScore + personalityScore + conditionScore)
          .clamp(0, 100);
}

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
}
