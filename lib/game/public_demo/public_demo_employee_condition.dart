/// Qualitative, player-facing labels for Public Demo employee conditions.
/// Numeric morale/trust values remain runtime-only.
class PublicDemoEmployeeCondition {
  const PublicDemoEmployeeCondition._();

  static String label(int value) {
    if (value >= 60) return '高い';
    if (value >= 40) return '普通';
    return 'やや低い';
  }
}
