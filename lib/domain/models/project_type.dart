/// Category of project that the `ProjectGenerator` can produce.
///
/// Base occurrence weights live in `distribution_tables.dart`; a [Client]
/// may bias these via `Client.projectTypeWeights`.
enum ProjectType {
  javaBusiness,
  webBackend,
  frontend,
  infrastructure,
  testSupport,
  pl;

  String get jsonValue => name;

  static ProjectType fromJson(String value) => ProjectType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown ProjectType: $value'),
  );
}
