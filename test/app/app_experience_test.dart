import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/app/app_entry.dart';
import 'package:smile_enjoy_story/app/app_experience.dart';

void main() {
  test('the normal application URL resolves to Development', () {
    expect(
      resolveAppExperience(Uri.parse('https://example.test/')),
      AppExperience.development,
    );
  });

  test('the static-host-safe hash URL resolves to Public Demo 0.1', () {
    expect(
      resolveAppExperience(Uri.parse('https://example.test/#/public-demo-01')),
      AppExperience.publicDemo01,
    );
  });

  test('query parameters before the hash do not change Public Demo entry', () {
    expect(
      resolveAppExperience(
        Uri.parse('https://example.test/?e2e=1&seed=7#/public-demo-01'),
      ),
      AppExperience.publicDemo01,
    );
  });

  // SES-FIRST-FUN-YEAR-RELOAD-1 (P0 PLAYTHROUGH BLOCKER — 復帰不能): a
  // reload's URL no longer carrying `#/public-demo-01` (Flutter Web's own
  // Navigator rewrites `location.hash` after first paint, independently of
  // this app's one-shot Uri.base read) must not strand a player who has a
  // real Public Demo save away from it on the unrelated Development
  // start-choice screen.
  //
  // PR #164 review (merge blocker, P1): the fallback must not use mere
  // Public Demo save *presence* as a global launch intent — that hijacked
  // every genuine Development/root entry into Public Demo as soon as a
  // Public Demo save existed anywhere in the browser, even alongside a
  // valid, isolated Development save (see `save_service_isolation_test.dart`
  // for that coexistence contract). `wasPublicDemoThisSession` is the
  // durable-but-scoped ("was *this tab* already showing Public Demo", see
  // `public_demo_session_marker.dart`) signal that distinguishes an actual
  // same-tab reload from a fresh/genuine visit.
  group('resolveAppExperienceWithSaveFallback', () {
    test('an explicit Public Demo URL always wins, regardless of any save', () {
      expect(
        resolveAppExperienceWithSaveFallback(
          fromUrl: AppExperience.publicDemo01,
          hasPublicDemoSave: false,
          wasPublicDemoThisSession: false,
        ),
        AppExperience.publicDemo01,
      );
      expect(
        resolveAppExperienceWithSaveFallback(
          fromUrl: AppExperience.publicDemo01,
          hasPublicDemoSave: true,
          wasPublicDemoThisSession: false,
        ),
        AppExperience.publicDemo01,
      );
    });

    // A. Public Demo reload/resume → Public Demo.
    test(
      'a URL that resolved to Development resumes Public Demo when this tab was already '
      'showing Public Demo and a Public Demo save exists (the reload-after-play case)',
      () {
        expect(
          resolveAppExperienceWithSaveFallback(
            fromUrl: AppExperience.development,
            hasPublicDemoSave: true,
            wasPublicDemoThisSession: true,
          ),
          AppExperience.publicDemo01,
        );
      },
    );

    test(
      'a URL that resolved to Development with no Public Demo save stays on Development '
      'even if this tab was previously showing Public Demo '
      '(the save was since cleared/never existed)',
      () {
        expect(
          resolveAppExperienceWithSaveFallback(
            fromUrl: AppExperience.development,
            hasPublicDemoSave: false,
            wasPublicDemoThisSession: true,
          ),
          AppExperience.development,
        );
      },
    );

    // B. Development/root entry + a Public Demo save exists, but this is a
    // fresh/genuine entry (no same-tab Public Demo session marker) →
    // Development. Mere save presence must never be treated as launch
    // intent on its own.
    test(
      'a genuine Development/root entry stays on Development when a Public Demo save exists '
      'but this tab never showed Public Demo (a fresh visit, not a reload)',
      () {
        expect(
          resolveAppExperienceWithSaveFallback(
            fromUrl: AppExperience.development,
            hasPublicDemoSave: true,
            wasPublicDemoThisSession: false,
          ),
          AppExperience.development,
        );
      },
    );

    // C. Development save and Public Demo save coexist + a genuine
    // Development/root entry → Development. This pure function does not
    // see save contents directly, but `wasPublicDemoThisSession: false`
    // models "this tab's genuine entry", which must win regardless of what
    // saves happen to coexist in storage — never
    // "development + any Public Demo save => Public Demo".
    test(
      'a genuine Development/root entry stays on Development when Development and Public '
      'Demo saves coexist (coexistence must never force Public Demo)',
      () {
        // hasPublicDemoSave: true stands in for "a Public Demo save exists"
        // regardless of whether a Development save also exists — this
        // function is intentionally agnostic to the Development save's
        // presence, since Development's own save/resume is unrelated and
        // untouched by this fallback (see its doc in app_entry.dart).
        expect(
          resolveAppExperienceWithSaveFallback(
            fromUrl: AppExperience.development,
            hasPublicDemoSave: true,
            wasPublicDemoThisSession: false,
          ),
          AppExperience.development,
        );
      },
    );
  });
}
