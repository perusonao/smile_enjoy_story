/// Non-web fallback for [readPublicDemoSessionMarker] /
/// [writePublicDemoSessionMarker] — see `public_demo_session_marker.dart`.
///
/// There is no browser tab to scope a "was this a reload of an active
/// Public Demo session" signal to outside a web build, so this
/// conservatively never claims one, and never records one.
bool readPublicDemoSessionMarker() => false;

void writePublicDemoSessionMarker() {}
