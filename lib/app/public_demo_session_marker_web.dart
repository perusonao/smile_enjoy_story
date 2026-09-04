import 'package:web/web.dart' as web;

/// Web implementation of [readPublicDemoSessionMarker] /
/// [writePublicDemoSessionMarker] — see `public_demo_session_marker.dart`.
///
/// Uses `window.sessionStorage` (not `localStorage`, which is what
/// `PublicDemoSaveService`/`SaveService` use for actual save data): it is
/// per-tab and survives a same-tab reload, which is precisely "was this
/// tab already showing Public Demo". `package:web`/`dart:js_interop` is
/// used rather than the deprecated `dart:html`.
const _key = 'ses_public_demo_01_session_marker_v1';

bool readPublicDemoSessionMarker() {
  try {
    return web.window.sessionStorage.getItem(_key) == '1';
  } catch (_) {
    // Best-effort, exactly like the save services: never let a storage
    // access failure (e.g. disabled storage) crash boot.
    return false;
  }
}

void writePublicDemoSessionMarker() {
  try {
    web.window.sessionStorage.setItem(_key, '1');
  } catch (_) {
    // Best-effort — see readPublicDemoSessionMarker.
  }
}
