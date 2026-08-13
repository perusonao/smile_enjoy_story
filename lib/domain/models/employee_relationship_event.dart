/// One line of an [Engineer]'s morale/trust change history (Playable 0.4C
/// §38-39) — "why did this number move", kept short and always attributed
/// to a concrete cause (§40: no hidden/unexplained swings).
class EmployeeRelationshipEvent {
  final int week;
  final String reason;
  final int moraleDelta;
  final int trustDelta;

  const EmployeeRelationshipEvent({
    required this.week,
    required this.reason,
    this.moraleDelta = 0,
    this.trustDelta = 0,
  });

  Map<String, dynamic> toJson() => {
    'week': week,
    'reason': reason,
    'moraleDelta': moraleDelta,
    'trustDelta': trustDelta,
  };

  factory EmployeeRelationshipEvent.fromJson(Map<String, dynamic> json) =>
      EmployeeRelationshipEvent(
        week: json['week'] as int,
        reason: json['reason'] as String,
        moraleDelta: json['moraleDelta'] as int? ?? 0,
        trustDelta: json['trustDelta'] as int? ?? 0,
      );
}
