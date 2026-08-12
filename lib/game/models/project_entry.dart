import '../../domain/domain.dart';

/// A [Project] currently sitting in the open marketplace, tagged with when
/// it was posted.
class ProjectEntry {
  final Project project;
  final int postedWeek;

  const ProjectEntry({required this.project, required this.postedWeek});

  Map<String, dynamic> toJson() => {
    'project': project.toJson(),
    'postedWeek': postedWeek,
  };

  factory ProjectEntry.fromJson(Map<String, dynamic> json) => ProjectEntry(
    project: Project.fromJson(json['project'] as Map<String, dynamic>),
    postedWeek: json['postedWeek'] as int,
  );
}
