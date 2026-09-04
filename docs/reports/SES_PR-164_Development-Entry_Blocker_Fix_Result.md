# SES PR #164 — Development Entry Blocker Fix (Result Report)

## Scope

Fix **only** the merge blocker flagged in PR #164's review
([review comment](https://github.com/perusonao/smile_enjoy_story/pull/164#discussion_r3932608621)):
`resolveAppExperienceWithSaveFallback` used mere Public Demo save
**presence** as a global launch **intent**, so it could hijack a genuine
Development/root entry into Public Demo even while a valid, isolated
Development save also existed. PR #164's own reload/resume purpose
(Public Demo → reload → resume Public Demo) had to be preserved.

Nothing else in PR #164 was touched: no HOME/UI redesign, no Issue #122
work, no balance changes, no Sep–Feb content, no finance/domain changes,
no CI/workflow changes, no broader persistence refactor, and the existing
`PublicDemoSaveService` timeouts (100ms / 1000ms) were left exactly as
they were — they are unrelated to this routing decision.

## Base / HEAD

- Base (original PR #164 HEAD, verified current before starting):
  `c8db6c66feb17cfe3beeb2edbb0685dc9b67adbf`
- Final HEAD (pushed to `claude/first-fun-year-audit-x92por`):
  see the commit this report ships with (reported in the final chat
  response).

## Root cause

`lib/app/app_entry.dart`'s `resolveAppExperienceWithSaveFallback`:

```dart
if (fromUrl == AppExperience.development && hasPublicDemoSave) {
  return AppExperience.publicDemo01;
}
```

`hasPublicDemoSave` is `true` for the entire lifetime of a browser that
has ever played Public Demo — isolated saves are never opportunistically
cleared (see `save_service_isolation_test.dart`). So this fallback
converted **every** URL that resolved to Development — including the
documented root URL — into Public Demo, for as long as that save
existed, even with a separate, valid, isolated Development save sitting
right next to it. There was no way to distinguish "this boot is a reload
of an active Public Demo tab" (the case this fallback exists for) from
"this is a genuine, unrelated visit to Development" (the case the review
flagged) — both present identically as `fromUrl == development &&
hasPublicDemoSave == true` to the pure function.

## Fix

Added a second, durable signal that *does* make that distinction: whether
**this exact browser tab** already showed Public Demo before, using
`window.sessionStorage` (per-tab, survives a same-tab reload, empty for
a genuinely new tab/visit — unlike the `localStorage`-backed save data,
which is intentionally durable across the whole browser).

`resolveAppExperienceWithSaveFallback` now requires both:

```dart
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
```

`wasPublicDemoThisSession` comes from a new
`readPublicDemoSessionMarker()` / `writePublicDemoSessionMarker()` pair
(`lib/app/public_demo_session_marker*.dart`), backed by
`window.sessionStorage` on web (via `package:web`/`dart:js_interop`, not
the deprecated `dart:html`) and a no-op stub on non-web targets
(`flutter test` runs on the Dart VM, where there is no browser tab to
scope this to — `resolveAppExperience`/save presence alone still decide
Development there, unaffected by this change).

`lib/main.dart`'s `_GameRootState` writes the marker the moment this tab
shows Public Demo — synchronously in `initState` for an explicit
`#/public-demo-01` URL, and again after the async save check resolves to
Public Demo via the fallback — so a later same-tab reload always finds it.

Explicit `#/public-demo-01` URLs are completely unaffected (they already
short-circuit before this check, regardless of any save or marker).

## Changed files

- `lib/app/app_entry.dart` — `resolveAppExperienceWithSaveFallback` gains
  the `wasPublicDemoThisSession` parameter and the coexistence-safe
  condition; doc comment rewritten to explain the root cause and fix.
- `lib/main.dart` — reads/writes the new session marker around the
  existing async fallback check; no change to the async save check itself
  or its timing.
- `lib/app/public_demo_session_marker.dart` (new) — conditional
  export (web vs. non-web) for the marker read/write functions.
- `lib/app/public_demo_session_marker_web.dart` (new) — web
  implementation using `window.sessionStorage` (`package:web`).
- `lib/app/public_demo_session_marker_stub.dart` (new) — non-web
  no-op fallback (used by `flutter test`, which runs on the Dart VM).
- `pubspec.yaml` / `pubspec.lock` — promoted the already-transitive
  `web` package to a direct dependency (needed to reference
  `package:web` directly instead of the deprecated `dart:html`, which
  `flutter analyze` flags via `avoid_web_libraries_in_flutter`).
- `test/app/app_experience_test.dart` — updated existing
  `resolveAppExperienceWithSaveFallback` tests for the new parameter, and
  added the three required coexistence/genuine-entry cases (below).

No other test file referenced `resolveAppExperienceWithSaveFallback` or
`hasPublicDemoSave`, and no test encoded the rejected
`development + any Public Demo save => Public Demo` spec, so nothing
else needed correcting.

## Behavior before / after

| Scenario | Before | After |
|---|---|---|
| Explicit `#/public-demo-01` URL, any save state | Public Demo | Public Demo (unchanged) |
| Public Demo reload (same tab, hash lost, valid Public Demo save) | Public Demo | Public Demo (unchanged — PR #164's original fix preserved) |
| Genuine Development/root entry, Public Demo save exists, **no** Development save | **Public Demo (bug)** | **Development** |
| Genuine Development/root entry, Development **and** Public Demo saves coexist | **Public Demo (bug)** | **Development** |
| Genuine Development/root entry, no Public Demo save | Development | Development (unchanged) |

"Genuine entry" = this browser tab never previously showed Public Demo
(no session marker) — a fresh visit, a new tab, or Development-only play.

## Tests added/updated

`test/app/app_experience_test.dart` (`resolveAppExperienceWithSaveFallback` group):

- **A. Public Demo reload/resume → Public Demo**: `fromUrl: development,
  hasPublicDemoSave: true, wasPublicDemoThisSession: true` →
  `publicDemo01` (existing case, updated for the new parameter).
- (kept) reload with no Public Demo save (save since cleared) stays on
  Development even if the tab previously showed Public Demo.
- **B. Development/root entry + Public Demo save exists → Development**:
  `fromUrl: development, hasPublicDemoSave: true,
  wasPublicDemoThisSession: false` → `development` (new).
- **C. Development save + Public Demo save coexist + Development/root
  entry → Development**: same inputs as B, documented as modeling the
  coexistence contract from `save_service_isolation_test.dart` — this
  pure function is intentionally agnostic to the Development save's own
  content (new).
- (kept) explicit Public Demo URL always wins regardless of any save.

`save_service_isolation_test.dart` (Development/Public Demo save
coexistence) was already correct and needed no change — it was not
encoding the rejected spec.

## Verification results

Flutter SDK 3.44.9 (matching CI, `subosito/flutter-action` pin) installed
locally for this session; `flutter pub get` run first.

- `flutter analyze` (repo-wide): **No issues found.**
- Focused tests — routing + save/isolation
  (`test/app/app_experience_test.dart`,
  `test/game/save_service_isolation_test.dart`,
  `test/game/public_demo_save_service_test.dart`,
  `test/web/public_demo_entry_page_test.dart`): **14/14 passed.**
- `test/app` + `test/game` (full): **854/854 passed.**
- `test/ui/public_demo` + `test/web`: **232/232 passed.** (Full
  E2E/WebKit intentionally not run per Issue #163 policy;
  repo-policy-required CI checks are left to PR CI.)

## Production changes

Yes — `lib/app/app_entry.dart`, `lib/main.dart`, and the three new
`lib/app/public_demo_session_marker*.dart` files. All directly implement
the fix; no unrelated production code touched.

## Persistence/schema changes

No `GameState`/`PublicDemoAggregate` schema change and no save-format
change. The new `window.sessionStorage` key
(`ses_public_demo_01_session_marker_v1`) is a **route-intent marker
only** — never contains game data, is not read by any save/load path,
and is tab-scoped (cleared automatically when the tab/browser session
ends), unlike the `localStorage`-backed saves.

## CI/workflow changes

None. `pubspec.yaml`/`pubspec.lock` changed only to promote the
already-present transitive `web` dependency to direct, so
`lib/app/public_demo_session_marker_web.dart` can `import
'package:web/web.dart'` instead of the deprecated `dart:html` (which
`flutter analyze` flags).

## Remaining known issue (intentionally out of scope)

PR #164's own "Important remaining issue" — a deeper
close-tab/reopen-browser-context scenario where a genuine, pre-existing
`SharedPreferences`/`localStorage` save can fail to restore in the
automated environment — is **not** addressed by this fix and is left as
a separate, intentional follow-up task (Public Demo save restore
reliability, P0-1 continuation), exactly as PR #164 already states. This
fix's `window.sessionStorage` marker is explicitly scoped to a same-tab
reload only; it does not and is not intended to help with a closed and
reopened tab/browser, which loses `sessionStorage` by design and falls
back to genuine-entry (Development) behavior — consistent with, not a
regression of, that already-documented limitation.

## Merge readiness

- The single review-flagged merge blocker (P1: Development-entry
  hijack when Public Demo/Development saves coexist) is fixed and
  covered by focused tests.
- PR #164's original reload/resume purpose remains intact and tested.
- `flutter analyze` is clean; all focused and full `test/app`+`test/game`
  suites pass (854/854); `test/ui/public_demo`/`test/web` also pass
  (232/232).
- No scope creep: no HOME/UI, Issue #122, balance, Sep–Feb, finance,
  CI/workflow, or broader persistence-refactor changes were made.
- The PR's own documented remaining issue (close/reopen persistence
  reliability) is unchanged and still explicitly deferred.

Recommendation: ready for merge review, pending PR CI's required checks.
