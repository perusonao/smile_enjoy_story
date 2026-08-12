/// Overall lifecycle state of a playthrough.
enum GameStatus {
  /// Still within week 1-26, player can act.
  playing,

  /// cash went below 0 — game over.
  bankrupt,

  /// Week 26 was completed successfully.
  finished;

  String get jsonValue => name;

  static GameStatus fromJson(String value) => GameStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown GameStatus: $value'),
  );
}
