/// Machine-readable tag on a [GameLogEntry], letting the Week Summary
/// dialog and other UI pick out specific events without parsing message
/// text (Playable 0.2 §22).
enum GameLogCategory {
  applicantsArrived,
  newProjects,
  engineerJoined,
  offerAccepted,
  offerDeclined,
  listingExpired,
  interviewPassed,
  interviewFailed,
  assignmentStarted,
  contractEnded,
  bankrupt,
  gameFinished;

  String get jsonValue => name;

  static GameLogCategory fromJson(String value) => GameLogCategory.values
      .firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Unknown GameLogCategory: $value'),
      );
}

/// A single line of the "今週やること" / history log shown to the player.
class GameLogEntry {
  final int week;
  final String message;

  /// Optional machine-readable tag (Playable 0.2). Older saves and
  /// generic messages leave this null.
  final GameLogCategory? category;

  const GameLogEntry({required this.week, required this.message, this.category});

  Map<String, dynamic> toJson() => {
    'week': week,
    'message': message,
    'category': category?.jsonValue,
  };

  factory GameLogEntry.fromJson(Map<String, dynamic> json) => GameLogEntry(
    week: json['week'] as int,
    message: json['message'] as String,
    category: json['category'] != null
        ? GameLogCategory.fromJson(json['category'] as String)
        : null,
  );
}
