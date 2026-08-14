/// The company's one 総務 (general affairs) employee, seeded at Beginner
/// Mode start (Playable 0.5A §6-8).
///
/// Deliberately thin: this is a real employee whose salary counts against
/// monthly cash burn (§8), not a tutorial-only UI construct — but 0.5A
/// explicitly does not add a general-affairs skill/ability system (§8, §84),
/// so there's nothing here beyond identity and cost.
class GeneralAffairsStaff {
  final String id;
  final String name;
  final int salary;

  /// A short flavor line shown alongside the navigator's name (§67) — purely
  /// cosmetic, never read by any engine.
  final String flavor;

  const GeneralAffairsStaff({
    required this.id,
    required this.name,
    required this.salary,
    required this.flavor,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'salary': salary,
    'flavor': flavor,
  };

  factory GeneralAffairsStaff.fromJson(Map<String, dynamic> json) =>
      GeneralAffairsStaff(
        id: json['id'] as String,
        name: json['name'] as String,
        salary: json['salary'] as int,
        flavor: json['flavor'] as String? ?? '',
      );
}
