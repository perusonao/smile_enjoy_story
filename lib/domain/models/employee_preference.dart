/// What an employee primarily values, driving how they react to welfare
/// events (Playable 0.4C §25-26). Each engineer has exactly one primary
/// preference — kept intentionally simple rather than a full weighted
/// vector, per the "minimal trade-off" scope for this playable.
enum EmployeePreference {
  social,
  privateLife,
  compensation,
  growth,
  stability;

  String get jsonValue => name;

  static EmployeePreference fromJson(String value) =>
      EmployeePreference.values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Unknown EmployeePreference: $value'),
      );

  String get label => switch (this) {
    EmployeePreference.social => '社内の人間関係',
    EmployeePreference.privateLife => 'プライベート重視',
    EmployeePreference.compensation => '待遇・報酬重視',
    EmployeePreference.growth => '成長・スキルアップ',
    EmployeePreference.stability => '安定志向',
  };
}
