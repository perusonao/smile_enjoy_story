import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/app_experience.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_opening_marker.dart';
import 'package:smile_enjoy_story/main.dart';

/// FIRST-FUN-YEAR P1 (Issue #229): [SesApp.openingMarker] is threaded
/// straight through to [PublicDemo01PlaceholderScreen] via `_GameRoot`. This
/// is the composition-root wiring `main()`'s own `?e2e=1` branch relies on
/// (see that function's doc) — never itself exercised by a widget test, since
/// `main()` isn't invoked from one, but the threading it depends on is.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'SesApp defaults to the persisted marker for a fresh Public Demo entry — '
    'the Opening Context shows',
    (tester) async {
      await tester.pumpWidget(
        SesApp(
          controller: GameController(),
          experience: AppExperience.publicDemo01,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('public-demo-opening-context-screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SesApp with the inert marker (mirrors the ?e2e=1 branch) skips the '
    'Opening Context for the exact same fresh Public Demo entry',
    (tester) async {
      await tester.pumpWidget(
        SesApp(
          controller: GameController(),
          experience: AppExperience.publicDemo01,
          openingMarker: const PublicDemoOpeningMarker(),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('public-demo-opening-context-screen')),
        findsNothing,
      );
      expect(find.byKey(const Key('public-demo-bottom-nav')), findsOneWidget);
    },
  );
}
