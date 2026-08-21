import 'programming_language.dart';

/// One real-world project engagement in an engineer's actual career history.
///
/// This is deliberately separate from SkillSheet: career history records the
/// facts, while SkillSheet records the sales-facing representation of them.
class CareerHistoryEntry {
  final String id;
  final String projectName;
  final int experienceMonths;
  final List<ProgrammingLanguage> languages;
  final List<String> technologies;
  final List<String> processes;
  final String role;
  final int teamSize;

  const CareerHistoryEntry({
    required this.id,
    required this.projectName,
    required this.experienceMonths,
    this.languages = const [],
    this.technologies = const [],
    this.processes = const [],
    this.role = '',
    this.teamSize = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectName': projectName,
    'experienceMonths': experienceMonths,
    'languages': languages.map((e) => e.jsonValue).toList(),
    'technologies': technologies,
    'processes': processes,
    'role': role,
    'teamSize': teamSize,
  };

  factory CareerHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CareerHistoryEntry(
        id: json['id'] as String,
        projectName: json['projectName'] as String,
        experienceMonths: json['experienceMonths'] as int,
        languages: (json['languages'] as List? ?? const [])
            .map((e) => ProgrammingLanguage.fromJson(e as String))
            .toList(),
        technologies: (json['technologies'] as List? ?? const []).cast<String>(),
        processes: (json['processes'] as List? ?? const []).cast<String>(),
        role: json['role'] as String? ?? '',
        teamSize: json['teamSize'] as int? ?? 0,
      );
}
