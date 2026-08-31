// Regression coverage for the external Public Demo 0.1 playtest entry page
// (`web/public-demo/index.html`). `flutter build web` copies files under
// `web/` verbatim except for `web/index.html` itself (only that file gets
// `--base-href` templating), so asserting on the source file here is
// equivalent to asserting on the deployed artifact at
// `build/web/public-demo/index.html`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'public-demo entry page redirects to the canonical Public Demo 0.1 route',
    () {
      final file = File('web/public-demo/index.html');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'web/public-demo/index.html is missing',
      );

      final html = file.readAsStringSync();

      // Points at the existing hash route resolved by resolveAppExperience()
      // (lib/app/app_entry.dart), not a new/duplicated route.
      expect(html, contains('#/public-demo-01'));

      // The redirect targets must be relative so the page works from
      // whatever subpath the site is served under (e.g. GitHub Pages'
      // /smile_enjoy_story/public-demo/) rather than assuming a domain root.
      expect(html, contains("location.replace('../#/public-demo-01')"));
      expect(html, contains('content="0; url=../#/public-demo-01"'));
      expect(html, isNot(contains('http://')));
      expect(html, isNot(contains('https://')));

      // No JS framework/dependency — just the plain redirect script.
      expect(html, isNot(contains('<script src')));
    },
  );
}
