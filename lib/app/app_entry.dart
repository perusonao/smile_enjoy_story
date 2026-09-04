import 'app_experience.dart';

/// Resolves the app-level experience without introducing a Navigator 2.0
/// router. Hash URLs are static-host-safe on GitHub Pages: the server still
/// receives the existing app root, while the Flutter app receives the
/// fragment locally.
AppExperience resolveAppExperience(Uri uri) {
  final fragmentPath = uri.fragment
      .split('?')
      .first
      .replaceFirst(RegExp(r'^/'), '');
  return switch (fragmentPath) {
    'public-demo-01' => AppExperience.publicDemo01,
    _ => AppExperience.development,
  };
}

/// SES-FIRST-FUN-YEAR-RELOAD-1 (P0 PLAYTHROUGH BLOCKER — 復帰不能):
/// [resolveAppExperience] reads [Uri.base] once at boot. Flutter Web's own
/// default Navigator/router rewrites `window.location.hash` to reflect its
/// own internal route stack almost immediately after the first paint,
/// independently of and unaware of this app's `#/public-demo-01` entry
/// marker — confirmed by reproduction: `Uri.base` no longer carries that
/// fragment within ~500ms of a normal Public Demo session, well before any
/// player action. A later browser reload then re-reads that already-
/// stripped URL and [resolveAppExperience] always falls back to
/// [AppExperience.development] (an unrelated start-choice screen),
/// stranding the player away from their Public Demo progress even though it
/// is sitting untouched in its own save
/// (`lib/game/persistence/public_demo_save_service.dart`).
///
/// This is the pure decision this boot-time fallback makes, kept separate
/// from the actual (async) save check so it is unit-testable without a
/// browser or any I/O: if the URL asked for Public Demo, that always wins
/// unchanged; otherwise, if a Public Demo save already exists, resume
/// Public Demo instead of stranding the player on the unrelated
/// Development start-choice screen. The Development experience's own
/// save/resume is unrelated and untouched by this.
///
/// See docs/reports/SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md.
AppExperience resolveAppExperienceWithSaveFallback({
  required AppExperience fromUrl,
  required bool hasPublicDemoSave,
}) {
  if (fromUrl == AppExperience.development && hasPublicDemoSave) {
    return AppExperience.publicDemo01;
  }
  return fromUrl;
}
