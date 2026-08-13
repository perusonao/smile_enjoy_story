import '../../domain/domain.dart';
import '../models/models.dart';

/// Pure cost/effect math for the three welfare events (Playable 0.4C
/// §16-27) plus PC upgrades. [GameEngine] calls these to mutate state; the
/// UI calls the cost functions directly for preview sheets (§22).
class WelfareEngine {
  const WelfareEngine._();

  static int pcUpgradeCost(PcTier tier) => pcTierConfigs[tier]!.cost;

  /// §15: PC quality matters more for technologists who actually feel the
  /// difference, without touching [TechSkillLevels] directly.
  static int pcMoraleDelta(Engineer engineer, PcTier tier) {
    final base = pcTierConfigs[tier]!.moraleEffect;
    if (base <= 0) return base;
    final skills = engineer.profile.techSkills;
    final technical =
        skills.backend >= 3 || skills.frontend >= 3 || skills.infrastructure >= 3;
    return technical ? base + 1 : base;
  }

  static int healthCheckCost(HealthCheckTier tier, int employeeCount) =>
      healthCheckConfigs[tier]!.costPerEmployee * employeeCount;

  static int bonusCost(BonusPlan plan, int totalMonthlySalary) =>
      (totalMonthlySalary * bonusPlanConfigs[plan]!.months).round();

  /// §21-22: scales the flat config value by how much this employee
  /// personally cares about compensation, so "pay a big bonus" isn't a
  /// uniform win — the trade-off is against cash, not against making
  /// everyone equally happy.
  static int bonusMoraleDelta(BonusPlan plan, EmployeePreference preference) {
    final base = bonusPlanConfigs[plan]!.moraleEffect;
    final mult = switch (preference) {
      EmployeePreference.compensation => 1.4,
      EmployeePreference.privateLife => 0.8,
      _ => 1.0,
    };
    return (base * mult).round();
  }

  static int bonusTrustDelta(BonusPlan plan) => bonusPlanConfigs[plan]!.trustEffect;

  static String bonusReaction(EmployeePreference preference, BonusPlan plan) {
    if (plan == BonusPlan.none) return '「賞与がないのは正直厳しいです…」';
    final strong = plan == BonusPlan.one || plan == BonusPlan.two;
    return switch (preference) {
      EmployeePreference.compensation =>
        strong ? '「これはありがたいです、頑張った甲斐がありました」' : '「もう少し欲しいところですが、感謝します」',
      EmployeePreference.stability => '「会社がちゃんとしていて安心しました」',
      EmployeePreference.social => '「みんなも喜んでいると思います」',
      EmployeePreference.growth => '「次はもっと評価される仕事をしたいです」',
      EmployeePreference.privateLife => '「臨時収入はありがたいです」',
    };
  }

  static int companyTripCost(CompanyTripType type, int employeeCount) =>
      companyTripConfigs[type]!.costPerEmployee * employeeCount;

  /// §25-26: social employees love it, privateLife-oriented employees would
  /// rather have the day off, compensation-oriented employees are lukewarm.
  static int tripMoraleDelta(CompanyTripType type, EmployeePreference preference) {
    final base = type == CompanyTripType.dayTrip ? 4 : 8;
    final mult = switch (preference) {
      EmployeePreference.social => 1.5,
      EmployeePreference.privateLife => -0.3,
      EmployeePreference.compensation => 0.2,
      EmployeePreference.growth => 0.6,
      EmployeePreference.stability => 0.8,
    };
    return (base * mult).round();
  }

  static String tripReaction(EmployeePreference preference) => switch (preference) {
    EmployeePreference.social => '「みんなと話せて楽しかったです」',
    EmployeePreference.privateLife => '「正直、休みの方が嬉しかったですね」',
    EmployeePreference.compensation => '「旅行より賞与のほうが良かったです」',
    EmployeePreference.growth => '「息抜きにはなりましたが、次は勉強会とかもいいですね」',
    EmployeePreference.stability => '「毎年恒例なら、それはそれで安心します」',
  };
}
