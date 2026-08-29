enum EngineerCertificationCategory {
  development,
  cloudInfrastructure,
  database,
  networkSecurity,
  projectManagement,
  general;

  static EngineerCertificationCategory fromJson(String? value) =>
      EngineerCertificationCategory.values.firstWhere(
        (category) => category.name == value,
        orElse: () => EngineerCertificationCategory.general,
      );
}

/// A company-verified certification held by an engineer.
///
/// Applicant-declared résumé claims remain separately preserved on
/// `Applicant.qualifications` and are never promoted into this model.
class EngineerCertification {
  final String key;
  final String displayName;
  final EngineerCertificationCategory category;
  final int? acquiredWeek;

  const EngineerCertification({
    required this.key,
    required this.displayName,
    this.category = EngineerCertificationCategory.general,
    this.acquiredWeek,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'displayName': displayName,
    'category': category.name,
    'acquiredWeek': acquiredWeek,
  };

  factory EngineerCertification.fromJson(Map<String, dynamic> json) =>
      EngineerCertification(
        key: json['key'] as String,
        displayName: json['displayName'] as String,
        category: EngineerCertificationCategory.fromJson(
          json['category'] as String?,
        ),
        acquiredWeek: json['acquiredWeek'] as int?,
      );
}
