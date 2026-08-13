/// Lent-laptop tiers for Playable 0.4C §11-15.
///
/// Kept as a game-layer concept (like [OfficeType]) rather than a domain
/// model: it's a welfare/morale knob for the prototype, not a Phase 0
/// concern.
enum PcTier {
  basicLaptop,
  standardLaptop,
  highPerformanceLaptop;

  String get jsonValue => name;

  static PcTier fromJson(String value) => PcTier.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown PcTier: $value'),
  );
}

class PcTierConfig {
  final PcTier tier;
  final String label;
  final int cost;
  final int moraleEffect;

  const PcTierConfig({
    required this.tier,
    required this.label,
    required this.cost,
    required this.moraleEffect,
  });
}

/// Config table for all PC tiers (§11).
const Map<PcTier, PcTierConfig> pcTierConfigs = {
  PcTier.basicLaptop: PcTierConfig(
    tier: PcTier.basicLaptop,
    label: 'ベーシックPC',
    cost: 100000,
    moraleEffect: 0,
  ),
  PcTier.standardLaptop: PcTierConfig(
    tier: PcTier.standardLaptop,
    label: 'スタンダードPC',
    cost: 200000,
    moraleEffect: 2,
  ),
  PcTier.highPerformanceLaptop: PcTierConfig(
    tier: PcTier.highPerformanceLaptop,
    label: '高性能PC',
    cost: 350000,
    moraleEffect: 4,
  ),
};

/// Which [Engineer] currently holds which PC (§12). One entry per employee;
/// upgrading replaces the entry rather than keeping history.
class EmployeeEquipment {
  final String employeeId;
  final PcTier pcTier;
  final int purchaseWeek;
  final int purchaseCost;

  const EmployeeEquipment({
    required this.employeeId,
    required this.pcTier,
    required this.purchaseWeek,
    required this.purchaseCost,
  });

  EmployeeEquipment copyWith({
    PcTier? pcTier,
    int? purchaseWeek,
    int? purchaseCost,
  }) => EmployeeEquipment(
    employeeId: employeeId,
    pcTier: pcTier ?? this.pcTier,
    purchaseWeek: purchaseWeek ?? this.purchaseWeek,
    purchaseCost: purchaseCost ?? this.purchaseCost,
  );

  Map<String, dynamic> toJson() => {
    'employeeId': employeeId,
    'pcTier': pcTier.jsonValue,
    'purchaseWeek': purchaseWeek,
    'purchaseCost': purchaseCost,
  };

  factory EmployeeEquipment.fromJson(Map<String, dynamic> json) =>
      EmployeeEquipment(
        employeeId: json['employeeId'] as String,
        pcTier: PcTier.fromJson(json['pcTier'] as String),
        purchaseWeek: json['purchaseWeek'] as int,
        purchaseCost: json['purchaseCost'] as int,
      );
}
