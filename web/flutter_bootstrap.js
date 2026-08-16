// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Playable 0.4C.4 §28: `flutter build web` bundles a local CanvasKit copy
// under build/web/canvaskit/ (canvaskit.js/.wasm), but Flutter's *default*
// auto-generated bootstrap script still fetches the engine itself from
// https://www.gstatic.com/flutter-canvaskit/... unless told otherwise —
// this project already solved the *font* half of that CDN dependency
// (Noto Sans JP bundled locally, see lib/ui/theme.dart), but the engine
// itself was still CDN-bound. In an offline/sandboxed/CI environment where
// that host isn't reachable, the app never boots at all (not just tofu
// glyphs — CanvasKit itself fails to load, so no semantics tree ever
// attaches). `canvasKitBaseUrl` below is the same override Flutter's own
// engine test suite uses, verbatim, "to reduce test flakiness".
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  },
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
