/// Selects the product experience entered from the app-level URL.
///
/// This is intentionally separate from `GameMode`, which remains the
/// Development game's in-play onboarding choice (`beginner` / `free`).
/// Future public demos and release experiences belong here.
enum AppExperience {
  development,
  publicDemo01;
}
