/// Lifecycle status of an [Engineer] within the project pipeline.
///
/// This Phase only defines the enum; the transitions between these states
/// (案件提案 → 案件面談 → 参画) are implemented in later phases.
enum EngineerStatus {
  waiting,
  proposed,
  interviewScheduled,
  assigned;

  String get jsonValue => name;

  static EngineerStatus fromJson(String value) =>
      EngineerStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Unknown EngineerStatus: $value'),
      );
}
