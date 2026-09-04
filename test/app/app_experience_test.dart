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
  group('resolveAppExperienceWithSaveFallback', () {
    test('an explicit Public Demo URL always wins, regardless of any save', () {
      expect(
        resolveAppExperienceWithSaveFallback(
          fromUrl: AppExperience.publicDemo01,
          hasPublicDemoSave: false,
        ),
        AppExperience.publicDemo01,
      );
      expect(
        resolveAppExperienceWithSaveFallback(
          fromUrl: AppExperience.publicDemo01,
          hasPublicDemoSave: true,
        ),
        AppExperience.publicDemo01,
      );
    });

    test(
      'a URL that resolved to Development resumes Public Demo when a Public Demo save exists '
      '(the reload-after-play case)',
      () {
        expect(
          resolveAppExperienceWithSaveFallback(
            fromUrl: AppExperience.development,
            hasPublicDemoSave: true,
          ),
          AppExperience.publicDemo01,
        );
      },
    );

    test(
      'a URL that resolved to Development with no Public Demo save stays on Development '
      '(a genuine first-ever visit, or Development-only play, is unaffected)',
      () {
        expect(
          resolveAppExperienceWithSaveFallback(
            fromUrl: AppExperience.development,
            hasPublicDemoSave: false,
          ),
          AppExperience.development,
        );
      },
    );
  });
}
