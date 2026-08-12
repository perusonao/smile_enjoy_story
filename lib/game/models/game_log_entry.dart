/// A single line of the "今週やること" / history log shown to the player.
class GameLogEntry {
  final int week;
  final String message;

  const GameLogEntry({required this.week, required this.message});

  Map<String, dynamic> toJson() => {'week': week, 'message': message};

  factory GameLogEntry.fromJson(Map<String, dynamic> json) => GameLogEntry(
    week: json['week'] as int,
    message: json['message'] as String,
  );
}
