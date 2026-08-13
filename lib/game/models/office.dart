/// Office tiers for Playable 0.3A (§5-6).
///
/// Kept out of the domain `Company` model on purpose: office is a game-layer
/// concept (rent/capacity/morale tuning knobs for the prototype), not a
/// Phase 0 domain concern. It lives directly on [GameState] instead.
enum OfficeType {
  homeOffice,
  smallOffice,
  mediumOffice;

  String get jsonValue => name;

  static OfficeType fromJson(String value) => OfficeType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown OfficeType: $value'),
  );
}

/// Static configuration for an [OfficeType].
class OfficeConfig {
  final OfficeType type;
  final String label;
  final int monthlyRent;
  final int employeeCapacity;
  final int moraleModifier;

  const OfficeConfig({
    required this.type,
    required this.label,
    required this.monthlyRent,
    required this.employeeCapacity,
    required this.moraleModifier,
  });
}

/// Config table for all office tiers (Playable 0.3A design doc §5).
const Map<OfficeType, OfficeConfig> officeConfigs = {
  OfficeType.homeOffice: OfficeConfig(
    type: OfficeType.homeOffice,
    label: '自宅オフィス',
    monthlyRent: 50000,
    employeeCapacity: 3,
    moraleModifier: -2,
  ),
  OfficeType.smallOffice: OfficeConfig(
    type: OfficeType.smallOffice,
    label: '小規模オフィス',
    monthlyRent: 150000,
    employeeCapacity: 10,
    moraleModifier: 0,
  ),
  OfficeType.mediumOffice: OfficeConfig(
    type: OfficeType.mediumOffice,
    label: '中規模オフィス',
    monthlyRent: 400000,
    employeeCapacity: 30,
    moraleModifier: 2,
  ),
};
