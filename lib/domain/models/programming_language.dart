/// Programming languages tracked for applicants and projects.
///
/// Kept intentionally small for Phase 0 — only the languages needed by the
/// applicant/project generators. Extend with care; the distribution tables in
/// `lib/domain/generation/distribution_tables.dart` must stay in sync with
/// this list.
enum ProgrammingLanguage {
  java,
  csharp,
  php,
  python,
  javascript,
  typescript;

  String get jsonValue => name;

  static ProgrammingLanguage fromJson(String value) =>
      ProgrammingLanguage.values.firstWhere(
        (e) => e.name == value,
        orElse: () =>
            throw ArgumentError('Unknown ProgrammingLanguage: $value'),
      );
}
