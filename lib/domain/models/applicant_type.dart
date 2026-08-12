/// Category of applicant that the [ApplicantGenerator] can produce.
///
/// Untrained/inexperienced hires and PM candidates are intentionally not
/// part of this Phase 0 enum — see the Phase 0 design doc, section 26.
enum ApplicantType {
  juniorProgrammer,
  midLevelEngineer,
  seniorEngineer,
  frontendSpecialist,
  infrastructureSpecialist,
  plCandidate;

  String get jsonValue => name;

  static ApplicantType fromJson(String value) =>
      ApplicantType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Unknown ApplicantType: $value'),
      );
}
