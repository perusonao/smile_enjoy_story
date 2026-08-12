/// A short descriptive label for what kind of work a [Client] mostly deals
/// in. Purely descriptive/flavor data for Phase 0 — see [Client
/// .projectTypeWeights] for the mechanical bias applied during generation.
enum ClientSpecialty {
  javaBusiness,
  webFrontend,
  infrastructure,
  general;

  String get jsonValue => name;

  static ClientSpecialty fromJson(String value) =>
      ClientSpecialty.values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Unknown ClientSpecialty: $value'),
      );
}
