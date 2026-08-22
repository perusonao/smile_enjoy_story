/// Summer bonus choices supported by Public Demo 0.1.
///
/// This intentionally excludes the main game's two-month plan.
enum PublicDemoSummerBonusPlan {
  none,
  half,
  one;

  double get months => switch (this) {
    PublicDemoSummerBonusPlan.none => 0,
    PublicDemoSummerBonusPlan.half => 0.5,
    PublicDemoSummerBonusPlan.one => 1.0,
  };
}
