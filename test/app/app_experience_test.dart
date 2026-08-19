import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/app/app_entry.dart';
import 'package:smile_enjoy_story/app/app_experience.dart';

void main() {
  test('the normal application URL resolves to Development', () {
    expect(resolveAppExperience(Uri.parse('https://example.test/')), AppExperience.development);
  });

  test('the static-host-safe hash URL resolves to Public Demo 0.1', () {
    expect(
      resolveAppExperience(Uri.parse('https://example.test/#/public-demo-01')),
      AppExperience.publicDemo01,
    );
  });

  test('query parameters before the hash do not change Public Demo entry', () {
    expect(
      resolveAppExperience(Uri.parse('https://example.test/?e2e=1&seed=7#/public-demo-01')),
      AppExperience.publicDemo01,
    );
  });
}
