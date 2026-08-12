/// The player's SES company.
///
/// Phase 0 keeps this deliberately thin — no company-rank, sales-rep, or BP
/// concepts yet (see the Phase 0 design doc, section 26).
class Company {
  final String id;
  final String name;
  final int cash;
  final int credit;
  final int currentWeek;
  final List<String> engineerIds;
  final List<String> clientIds;

  const Company({
    required this.id,
    required this.name,
    required this.cash,
    required this.credit,
    required this.currentWeek,
    required this.engineerIds,
    required this.clientIds,
  });

  /// A freshly-founded company with the Phase 0 starting values.
  factory Company.initial({required String id, required String name}) {
    return Company(
      id: id,
      name: name,
      cash: 5000000,
      credit: 20,
      currentWeek: 1,
      engineerIds: const [],
      clientIds: const [],
    );
  }

  Company copyWith({
    String? id,
    String? name,
    int? cash,
    int? credit,
    int? currentWeek,
    List<String>? engineerIds,
    List<String>? clientIds,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      cash: cash ?? this.cash,
      credit: credit ?? this.credit,
      currentWeek: currentWeek ?? this.currentWeek,
      engineerIds: engineerIds ?? this.engineerIds,
      clientIds: clientIds ?? this.clientIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cash': cash,
    'credit': credit,
    'currentWeek': currentWeek,
    'engineerIds': engineerIds,
    'clientIds': clientIds,
  };

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      cash: json['cash'] as int,
      credit: json['credit'] as int,
      currentWeek: json['currentWeek'] as int,
      engineerIds: (json['engineerIds'] as List).cast<String>(),
      clientIds: (json['clientIds'] as List).cast<String>(),
    );
  }

  @override
  String toString() => 'Company($id, $name, cash:$cash, week:$currentWeek)';
}
