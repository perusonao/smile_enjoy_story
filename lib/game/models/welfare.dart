/// Company-wide welfare events: health checks, bonuses, and company trips
/// (Playable 0.4C §16-26). All three are player-initiated, occasional
/// events rather than weekly upkeep (§29) — the engine only tracks *when*
/// each was last run so the UI/recommendations can nudge the player.
library;

enum HealthCheckTier {
  basic,
  premium;

  String get jsonValue => name;
  static HealthCheckTier fromJson(String value) =>
      HealthCheckTier.values.firstWhere((e) => e.name == value);
}

class HealthCheckConfig {
  final HealthCheckTier tier;
  final String label;
  final int costPerEmployee;
  final int moraleEffect;
  final int trustEffect;
  const HealthCheckConfig({
    required this.tier,
    required this.label,
    required this.costPerEmployee,
    required this.moraleEffect,
    required this.trustEffect,
  });
}

const Map<HealthCheckTier, HealthCheckConfig> healthCheckConfigs = {
  HealthCheckTier.basic: HealthCheckConfig(
    tier: HealthCheckTier.basic,
    label: '基本健診',
    costPerEmployee: 10000,
    moraleEffect: 1,
    trustEffect: 1,
  ),
  HealthCheckTier.premium: HealthCheckConfig(
    tier: HealthCheckTier.premium,
    label: '人間ドック',
    costPerEmployee: 40000,
    moraleEffect: 3,
    trustEffect: 2,
  ),
};

/// §18-22: paid twice a year in the flavor text, but the prototype lets the
/// player trigger it whenever — [RecommendationEngine] nudges toward
/// June/December instead of hard-gating it.
enum BonusPlan {
  none,
  half,
  one,
  two;

  String get jsonValue => name;
  static BonusPlan fromJson(String value) =>
      BonusPlan.values.firstWhere((e) => e.name == value);
}

class BonusPlanConfig {
  final BonusPlan plan;
  final String label;
  final double months;
  final int moraleEffect;
  final int trustEffect;
  const BonusPlanConfig({
    required this.plan,
    required this.label,
    required this.months,
    required this.moraleEffect,
    required this.trustEffect,
  });
}

const Map<BonusPlan, BonusPlanConfig> bonusPlanConfigs = {
  BonusPlan.none: BonusPlanConfig(
    plan: BonusPlan.none,
    label: 'なし',
    months: 0,
    moraleEffect: -4,
    trustEffect: -2,
  ),
  BonusPlan.half: BonusPlanConfig(
    plan: BonusPlan.half,
    label: '0.5か月分',
    months: 0.5,
    moraleEffect: 3,
    trustEffect: 1,
  ),
  BonusPlan.one: BonusPlanConfig(
    plan: BonusPlan.one,
    label: '1.0か月分',
    months: 1.0,
    moraleEffect: 7,
    trustEffect: 3,
  ),
  BonusPlan.two: BonusPlanConfig(
    plan: BonusPlan.two,
    label: '2.0か月分',
    months: 2.0,
    moraleEffect: 12,
    trustEffect: 5,
  ),
};

/// §23-26: reaction varies by [EmployeePreference] rather than everyone
/// feeling the same effect.
enum CompanyTripType {
  dayTrip,
  overnightDomestic;

  String get jsonValue => name;
  static CompanyTripType fromJson(String value) =>
      CompanyTripType.values.firstWhere((e) => e.name == value);
}

class CompanyTripConfig {
  final CompanyTripType type;
  final String label;
  final int costPerEmployee;
  const CompanyTripConfig({
    required this.type,
    required this.label,
    required this.costPerEmployee,
  });
}

const Map<CompanyTripType, CompanyTripConfig> companyTripConfigs = {
  CompanyTripType.dayTrip: CompanyTripConfig(
    type: CompanyTripType.dayTrip,
    label: '日帰り旅行',
    costPerEmployee: 20000,
  ),
  CompanyTripType.overnightDomestic: CompanyTripConfig(
    type: CompanyTripType.overnightDomestic,
    label: '一泊旅行(国内)',
    costPerEmployee: 60000,
  ),
};
