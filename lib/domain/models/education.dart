/// Highest level of education completed by an applicant.
enum Education {
  highSchool,
  vocationalSchool,
  technicalCollege,
  university,
  graduateSchool;

  String get jsonValue => name;

  static Education fromJson(String value) => Education.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown Education: $value'),
  );
}

/// Field of study associated with an applicant's [Education].
enum Major {
  informationTechnology,
  scienceEngineering,
  humanities,
  other;

  String get jsonValue => name;

  static Major fromJson(String value) => Major.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown Major: $value'),
  );
}
