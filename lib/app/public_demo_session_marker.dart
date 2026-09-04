/// A durable, per-browser-tab indication of whether *this tab* already
/// launched Public Demo 0.1 (see [resolveAppExperienceWithSaveFallback] in
/// `app_entry.dart` for why this exists).
///
/// Backed by `window.sessionStorage` on Flutter Web: unlike the
/// `localStorage`-backed save data (`PublicDemoSaveService`,
/// `SaveService`), `sessionStorage` survives a same-tab reload (`F5` /
/// `page.reload()`) but starts empty for a genuinely new tab, window, or
/// browser session — even when a Public Demo save already exists in
/// `localStorage` from an earlier visit. That is exactly the "was this
/// boot a reload of an active Public Demo tab, or a fresh visit" signal
/// mere save presence cannot provide on its own.
///
/// On any non-web target (including `flutter test`, which runs on the
/// Dart VM) there is no browser tab to scope this to, so the stub always
/// reports no marker and writes are no-ops — [AppExperience.development]
/// resolution is then decided purely by [resolveAppExperience]/save
/// presence, same as before this file existed.
library;

export 'public_demo_session_marker_stub.dart'
    if (dart.library.html) 'public_demo_session_marker_web.dart';
