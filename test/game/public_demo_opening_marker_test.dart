import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_opening_marker.dart';

/// FIRST-FUN-YEAR P1 (Issue #229): focused tests for
/// [PublicDemoOpeningMarker] — the isolated, UI-only "has this browser
/// already dismissed the Opening Context" flag. See that class's own doc
/// for why it is deliberately separate from [PublicDemoSaveCodec]/
/// [PublicDemoSaveService].
void main() {
  group('PublicDemoOpeningMarker (inert default)', () {
    test('hasSeenOpening always resolves true, with no storage access', () async {
      const marker = PublicDemoOpeningMarker();
      expect(await marker.hasSeenOpening(), isTrue);
    });

    test('markSeen and clear are genuine no-ops', () async {
      const marker = PublicDemoOpeningMarker();
      // No SharedPreferences.setMockInitialValues call anywhere in this
      // test — if either method touched real storage it would still not
      // throw (the plugin auto-mocks in the test environment), but the
      // point is these calls must not change hasSeenOpening's answer.
      await marker.markSeen();
      await marker.clear();
      expect(await marker.hasSeenOpening(), isTrue);
    });
  });

  group('PublicDemoOpeningMarker.persistent', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('a fresh browser has not seen the Opening Context', () async {
      const marker = PublicDemoOpeningMarker.persistent();
      expect(await marker.hasSeenOpening(), isFalse);
    });

    test('markSeen is durable across independent marker instances', () async {
      const marker = PublicDemoOpeningMarker.persistent();
      await marker.markSeen();

      // A fresh instance (mirrors a real app reload constructing a new
      // widget/State) must read the same persisted flag, not any
      // in-memory state on the first instance.
      const reloaded = PublicDemoOpeningMarker.persistent();
      expect(await reloaded.hasSeenOpening(), isTrue);
    });

    test('clear resets a previously-seen marker back to not-seen', () async {
      const marker = PublicDemoOpeningMarker.persistent();
      await marker.markSeen();
      expect(await marker.hasSeenOpening(), isTrue);

      await marker.clear();
      expect(await marker.hasSeenOpening(), isFalse);
    });

    test('clearing an already-fresh marker is a harmless no-op', () async {
      const marker = PublicDemoOpeningMarker.persistent();
      await marker.clear();
      expect(await marker.hasSeenOpening(), isFalse);
    });

    test('uses an isolated storage key from every other persisted save', () async {
      const marker = PublicDemoOpeningMarker.persistent();
      await marker.markSeen();
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(PublicDemoOpeningMarker.key), isTrue);
      expect(preferences.getKeys(), {PublicDemoOpeningMarker.key});
    });
  });
}
