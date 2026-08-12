/// Simple S/A/B/C/D end-of-game rank (Playable 0.1 design doc §23).
///
/// The scoring formula is an intentionally simple prototype heuristic, not a
/// balanced final design.
enum GameRank {
  s,
  a,
  b,
  c,
  d;

  String get label => name.toUpperCase();

  static GameRank fromScore(double score) {
    if (score >= 90) return GameRank.s;
    if (score >= 70) return GameRank.a;
    if (score >= 45) return GameRank.b;
    if (score >= 20) return GameRank.c;
    return GameRank.d;
  }
}
