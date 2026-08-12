import 'client_specialty.dart';
import 'project_type.dart';

/// A trading partner (取引先) that projects are generated for/from.
///
/// Ver.0.1 scope only — no credit/trust mechanics yet (see the Phase 0
/// design doc, section 26).
class Client {
  final String id;
  final String name;
  final ClientSpecialty specialty;

  /// Relative likelihood this client is picked when a project is generated.
  /// Larger values mean the client shows up more often; the generator
  /// normalizes across all known clients.
  final double projectGenerationWeight;

  /// Optional per-[ProjectType] multipliers applied on top of the base
  /// distribution in `distribution_tables.dart`, letting a given client skew
  /// toward its specialty (e.g. a Java shop rarely puts out frontend work).
  /// A type absent from this map uses a multiplier of 1.0.
  final Map<ProjectType, double> projectTypeWeights;

  const Client({
    required this.id,
    required this.name,
    required this.specialty,
    required this.projectGenerationWeight,
    this.projectTypeWeights = const {},
  }) : assert(projectGenerationWeight > 0);

  double weightFor(ProjectType type) => projectTypeWeights[type] ?? 1.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'specialty': specialty.jsonValue,
    'projectGenerationWeight': projectGenerationWeight,
    'projectTypeWeights': projectTypeWeights.map(
      (key, value) => MapEntry(key.jsonValue, value),
    ),
  };

  factory Client.fromJson(Map<String, dynamic> json) {
    final rawWeights = json['projectTypeWeights'] as Map<String, dynamic>?;
    return Client(
      id: json['id'] as String,
      name: json['name'] as String,
      specialty: ClientSpecialty.fromJson(json['specialty'] as String),
      projectGenerationWeight: (json['projectGenerationWeight'] as num)
          .toDouble(),
      projectTypeWeights: rawWeights == null
          ? const {}
          : rawWeights.map(
              (key, value) => MapEntry(
                ProjectType.fromJson(key),
                (value as num).toDouble(),
              ),
            ),
    );
  }

  @override
  String toString() => 'Client($id, $name, $specialty)';
}
