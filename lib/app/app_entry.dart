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
/// unchanged; otherwise, resume Public Demo instead of stranding the player
/// on the unrelated Development start-choice screen, but **only** when both
/// [hasPublicDemoSave] and [wasPublicDemoThisSession] hold. The Development
/// experience's own save/resume is unrelated and untouched by this.
///
/// PR #164 review (merge blocker, P1): the first version of this fallback
/// used [hasPublicDemoSave] alone as a stand-in for "the player wants
/// Public Demo". That is wrong — mere save *presence* is not launch
/// *intent*. A browser that has ever played Public Demo carries that save
/// in `localStorage` indefinitely (isolated saves are never opportunistically
/// cleared — see `save_service_isolation_test.dart`), so it converted every
/// later genuine visit to the documented Development/root URL into Public
/// Demo too, even with its own valid, isolated Development save sitting
/// right next to it — making Development unreachable until the player
/// manually deleted the demo save. [wasPublicDemoThisSession] is the fix:
/// a durable *and* properly scoped signal (`readPublicDemoSessionMarker`/
/// `writePublicDemoSessionMarker` in `public_demo_session_marker.dart`,
/// backed by `window.sessionStorage` — per-tab, survives a same-tab
/// reload, empty for a genuinely new tab/visit) that answers "was this
/// exact browser tab already showing Public Demo", which mere save
/// presence cannot. A fresh/genuine Development entry — first-ever visit,
/// a new tab, or simply never having opened Public Demo in this tab — has
/// no marker and therefore stays on Development regardless of what saves
/// exist, satisfying both saves' documented coexistence contract. A reload
/// of an active Public Demo tab still has the marker set (written the
/// moment that tab first showed Public Demo) and so still resumes Public
/// Demo, preserving this fallback's original reload/resume purpose.
///
/// See docs/reports/SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md and
/// docs/reports/SES_PR-164_Development-Entry_Blocker_Fix_Result.md.
AppExperience resolveAppExperienceWithSaveFallback({
  required AppExperience fromUrl,
  required bool hasPublicDemoSave,
  required bool wasPublicDemoThisSession,
}) {
  if (fromUrl == AppExperience.development &&
      hasPublicDemoSave &&
      wasPublicDemoThisSession) {
    return AppExperience.publicDemo01;
  }
  return fromUrl;
}
