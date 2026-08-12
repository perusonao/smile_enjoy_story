/// Seniority rank of a project engagement. Drives the base monthly-rate
/// range used by the `ProjectGenerator` — see `distribution_tables.dart`.
enum ProjectRank {
  entry,
  junior,
  middle,
  senior,
  lead;

  String get jsonValue => name;

  static ProjectRank fromJson(String value) => ProjectRank.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown ProjectRank: $value'),
  );
}
