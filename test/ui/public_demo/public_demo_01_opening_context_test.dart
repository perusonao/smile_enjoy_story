import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_opening_marker.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart' show formatYen;

/// FIRST-FUN-YEAR P1 (Issue #229): focused widget tests for the Public Demo
/// Opening Context — [PublicDemoOpeningContextScreen], and the gating logic
/// on [PublicDemo01PlaceholderScreen] that decides when it replaces HOME.
///
/// [_RecordingSaveService] and [_RecordingOpeningMarker] deliberately avoid
/// real `SharedPreferences` I/O (mirrors `public_demo_01_persistence_test
/// .dart`'s own [_RecordingSaveService]) so every scenario below is
/// deterministic and fast.
class _RecordingSaveService extends PublicDemoSaveService {
  _RecordingSaveService({this.restored});

  PublicDemoAggregate? restored;

  @override
  Future<PublicDemoAggregate?> load() async => restored;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {
    restored = aggregate;
  }

  @override
  Future<bool> clear() async {
    restored = null;
    return true;
  }
}

class _RecordingOpeningMarker extends PublicDemoOpeningMarker {
  _RecordingOpeningMarker({this.seen = false}) : super.persistent();

  bool seen;
  var markSeenCalls = 0;
  var clearCalls = 0;

  @override
  Future<bool> hasSeenOpening() async => seen;

  @override
  Future<void> markSeen() async {
    markSeenCalls++;
    seen = true;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    seen = false;
  }
}

const _openingScreenKey = Key('public-demo-opening-context-screen');
const _bottomNavKey = Key('public-demo-bottom-nav');
const _startButtonKey = Key('public-demo-opening-start-button');

Future<void> _mount(
  WidgetTester tester, {
  PublicDemoSaveService? saveService,
  PublicDemoOpeningMarker? openingMarker,
  int? debugSeed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        key: UniqueKey(),
        saveService: saveService ?? _RecordingSaveService(),
        openingMarker: openingMarker ?? const PublicDemoOpeningMarker(),
        debugSeed: debugSeed,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final expectedCash = formatYen(PublicDemoState.aprilStart().cash);
  final expectedFixedCost = formatYen(PublicDemoSalary.baselineMonthlyExpenses);

  group('gating', () {
    testWidgets(
      'the default (inert) marker never shows the Opening Context, even on '
      'a genuinely fresh start (backward compatibility for every existing '
      'widget test that constructs this screen directly)',
      (tester) async {
        await _mount(tester);

        expect(find.byKey(_openingScreenKey), findsNothing);
        expect(find.byKey(_bottomNavKey), findsOneWidget);
      },
    );

    testWidgets(
      'a persistent marker with no prior record shows the Opening Context '
      'on a fresh (no-save) start',
      (tester) async {
        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: false),
        );

        expect(find.byKey(_openingScreenKey), findsOneWidget);
        expect(find.byKey(_bottomNavKey), findsNothing);
      },
    );

    testWidgets(
      'a persistent marker that already recorded a dismissal skips the '
      'Opening Context on a fresh (no-save) start',
      (tester) async {
        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: true),
        );

        expect(find.byKey(_openingScreenKey), findsNothing);
        expect(find.byKey(_bottomNavKey), findsOneWidget);
      },
    );

    testWidgets(
      'a restored save always skips the Opening Context, even when the '
      'marker itself has no record (a save from before this screen existed)',
      (tester) async {
        await _mount(
          tester,
          saveService: _RecordingSaveService(
            restored: PublicDemoAggregate.initial(),
          ),
          openingMarker: _RecordingOpeningMarker(seen: false),
        );

        expect(find.byKey(_openingScreenKey), findsNothing);
        expect(find.byKey(_bottomNavKey), findsOneWidget);
      },
    );
  });

  group('content — authority-derived, never hardcoded', () {
    testWidgets(
      'shows the exact starting cash and baseline monthly fixed cost read '
      'from Finance/Payroll authority',
      (tester) async {
        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: false),
        );

        expect(find.textContaining(expectedCash), findsOneWidget);
        expect(find.textContaining(expectedFixedCost), findsOneWidget);
      },
    );
  });

  group('dismissal', () {
    testWidgets(
      'tapping the start button dismisses the Opening Context, reveals '
      'HOME, and records the dismissal on the marker',
      (tester) async {
        final marker = _RecordingOpeningMarker(seen: false);
        await _mount(tester, openingMarker: marker);
        expect(find.byKey(_openingScreenKey), findsOneWidget);

        await tester.tap(find.byKey(_startButtonKey));
        await tester.pump();

        expect(find.byKey(_openingScreenKey), findsNothing);
        expect(find.byKey(_bottomNavKey), findsOneWidget);
        expect(find.text('1年目 4月'), findsOneWidget);
        expect(marker.markSeenCalls, 1);
        expect(marker.seen, isTrue);
      },
    );

    testWidgets(
      'a reload after dismissal (same marker, still no save) does not '
      'show the Opening Context again',
      (tester) async {
        final marker = _RecordingOpeningMarker(seen: false);
        final saveService = _RecordingSaveService();
        await _mount(tester, saveService: saveService, openingMarker: marker);
        await tester.tap(find.byKey(_startButtonKey));
        await tester.pump();
        expect(marker.seen, isTrue);

        // Simulate a fresh mount (reload) reusing the same marker/save
        // service instances, mirroring how `public_demo_01_persistence_test
        // .dart`'s own reload scenarios re-mount without a real browser.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await _mount(tester, saveService: saveService, openingMarker: marker);

        expect(find.byKey(_openingScreenKey), findsNothing);
        expect(find.byKey(_bottomNavKey), findsOneWidget);
      },
    );
  });

  group('restart', () {
    Future<void> dismissOpeningAndReachMenuTab(WidgetTester tester) async {
      await tester.tap(find.byKey(_startButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(const Key('public-demo-nav-menu')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      '"4月からやり直す" shows the Opening Context again for a persistent '
      'marker',
      (tester) async {
        final marker = _RecordingOpeningMarker(seen: false);
        await _mount(tester, openingMarker: marker, debugSeed: 42);
        await dismissOpeningAndReachMenuTab(tester);

        final toggle = find.byKey(const Key('public-demo-dev-menu-toggle'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        var button = find.byKey(const Key('public-demo-restart-april-button'));
        if (button.evaluate().isEmpty) {
          await tester.tap(toggle);
          await tester.pumpAndSettle();
        }
        button = find.byKey(const Key('public-demo-restart-april-button'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('public-demo-restart-april-confirm')),
        );
        await tester.pump();

        expect(marker.clearCalls, 1);
        expect(find.byKey(_openingScreenKey), findsOneWidget);
      },
    );

    testWidgets(
      'the default (inert) marker keeps restart landing directly on HOME, '
      'unchanged from before this screen existed',
      (tester) async {
        await _mount(tester, debugSeed: 42);
        await tester.tap(find.byKey(const Key('public-demo-nav-menu')));
        await tester.pumpAndSettle();
        final toggle = find.byKey(const Key('public-demo-dev-menu-toggle'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        var button = find.byKey(const Key('public-demo-restart-april-button'));
        if (button.evaluate().isEmpty) {
          await tester.tap(toggle);
          await tester.pumpAndSettle();
        }
        button = find.byKey(const Key('public-demo-restart-april-button'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('public-demo-restart-april-confirm')),
        );
        await tester.pump();

        expect(find.byKey(_openingScreenKey), findsNothing);
        expect(find.byKey(_bottomNavKey), findsOneWidget);
      },
    );
  });

  group('mobile layout', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      testWidgets('renders without overflow at ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: false),
        );

        expect(find.byKey(_openingScreenKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
