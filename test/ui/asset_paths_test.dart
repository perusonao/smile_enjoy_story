// Smoke test for the S.E.S. UI asset import (characters/events/locations).
//
// This only verifies the plumbing — pubspec.yaml's `assets:` entries and
// AssetPaths' string literals actually resolve to bundled files — not any
// screen behavior. 画像付きイベントモーダル Phase 1 wired 4 of the 5 event
// images into founding_dialogs.dart's shared event dialog (see
// test/ui/event_image_dialog_test.dart for that screen-level coverage);
// character/location wiring and portraitId are still out of scope here
// (see lib/ui/asset_paths.dart's doc comment).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/ui/asset_paths.dart';

void main() {
  testWidgets('every registered UI asset can be loaded from the bundle', (tester) async {
    for (final path in AssetPaths.all) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: 'asset missing or empty: $path');
    }
  });

  testWidgets('one representative image per category renders without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Image(image: AssetImage(AssetPaths.salesMale)),
              Image(image: AssetImage(AssetPaths.eventClientContact)),
              Image(image: AssetImage(AssetPaths.locationOfficeDay)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
