/// An applicant's desired working arrangement.
enum WorkStyle {
  onsite,
  hybrid,
  fullRemote;

  String get jsonValue => name;

  static WorkStyle fromJson(String value) => WorkStyle.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown WorkStyle: $value'),
  );
}
