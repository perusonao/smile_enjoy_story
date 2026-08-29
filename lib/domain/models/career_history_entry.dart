import 'programming_language.dart';
import 'sales_profile.dart';

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
  final Industry? industry;
  final int? startWeek;
  final int? endWeek;
  final String? clientNameSnapshot;
  final String summary;

  const CareerHistoryEntry({
    required this.id,
    required this.projectName,
    required this.experienceMonths,
    this.languages = const [],
    this.technologies = const [],
    this.processes = const [],
    this.role = '',
    this.teamSize = 0,
    this.industry,
    this.startWeek,
    this.endWeek,
    this.clientNameSnapshot,
    this.summary = '',
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
    'industry': industry?.name,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'clientNameSnapshot': clientNameSnapshot,
    'summary': summary,
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
        industry: _industryFromJson(json['industry'] as String?),
        startWeek: json['startWeek'] as int?,
        endWeek: json['endWeek'] as int?,
        clientNameSnapshot: json['clientNameSnapshot'] as String?,
        summary: json['summary'] as String? ?? '',
      );
}

Industry? _industryFromJson(String? value) {
  if (value == null) return null;
  return Industry.values.firstWhere(
    (industry) => industry.name == value,
    orElse: () => Industry.other,
  );
}
