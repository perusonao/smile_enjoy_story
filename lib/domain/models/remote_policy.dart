/// How much remote work a [Project] allows.
enum RemotePolicy {
  onsite,
  hybrid,
  remote;

  String get jsonValue => name;

  static RemotePolicy fromJson(String value) => RemotePolicy.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown RemotePolicy: $value'),
  );
}
