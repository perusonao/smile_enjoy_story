import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_opening_marker.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_mission_screen.dart'
    show publicDemoAprilHeadlineGoal;
import 'package:smile_enjoy_story/ui/theme.dart' show formatYen;

/// FIRST-FUN-YEAR P1 (Issue #229) / SES First Fun Quarter Mission System
/// Phase 2 (Progressive Onboarding): focused widget tests for the Public
/// Demo Opening Context — [PublicDemoOpeningContextScreen]'s paged "次へ"
/// flow, and the gating logic on [PublicDemo01PlaceholderScreen] that
/// decides when it replaces HOME.
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
const _nextButtonKey = Key('public-demo-opening-next-button');
const _backButtonKey = Key('public-demo-opening-back-button');

/// Phase 2's Opening Context is a fixed 5-page "次へ" flow (this file's own
/// `_pageCount` constant mirrors `_PublicDemoOpeningContextScreenState
/// ._pages.length` in production — a test-side drift here would show up
/// immediately as either a stuck "次へ" button or a missing "経営を始める").
const _pageCount = 5;

Future<void> _tapOpeningButton(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// Advances the Opening Context [steps] pages forward via "次へ", without
/// tapping the final "経営を始める" CTA.
Future<void> _advance(WidgetTester tester, int steps) async {
  for (var i = 0; i < steps; i++) {
    await _tapOpeningButton(tester, _nextButtonKey);
  }
}

/// Walks every page of the Opening Context in order (asserting the page
/// indicator advances correctly and no exception is thrown on any page)
/// and finally taps "経営を始める" to dismiss it.
Future<void> _completeOpening(WidgetTester tester) async {
  for (var page = 1; page < _pageCount; page++) {
    expect(
      find.text('$page / $_pageCount'),
      findsOneWidget,
      reason: 'page indicator should read "$page / $_pageCount" before '
          'advancing past it',
    );
    await _tapOpeningButton(tester, _nextButtonKey);
  }
  expect(find.text('$_pageCount / $_pageCount'), findsOneWidget);
  await _tapOpeningButton(tester, _startButtonKey);
}

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

  group('paged flow — content, authority-derived, never hardcoded', () {
    testWidgets(
      'page 1/5 introduces the company/goal with ひより, single "次へ" CTA '
      'visible, no "戻る" on the first page',
      (tester) async {
        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: false),
        );

        expect(find.text('1 / $_pageCount'), findsOneWidget);
        expect(find.byKey(_nextButtonKey), findsOneWidget);
        expect(find.byKey(_backButtonKey), findsNothing);
        expect(find.byKey(_startButtonKey), findsNothing);
      },
    );

    testWidgets(
      'page 2/5 introduces the founding engineers by their real name/summary '
      'from publicDemoInitialEngineers, and states their real headcount — '
      'never a fabricated differentiator or a hardcoded "2名"',
      (tester) async {
        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: false),
        );
        await _advance(tester, 1);

        expect(find.text('2 / $_pageCount'), findsOneWidget);
        expect(
          find.textContaining('${publicDemoInitialEngineers.length}名'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('public-demo-opening-founders')),
          findsOneWidget,
        );
        for (final engineer in publicDemoInitialEngineers) {
          expect(find.textContaining(engineer.name), findsOneWidget);
          expect(find.textContaining(engineer.summary), findsOneWidget);
        }
      },
    );

    testWidgets(
      'page 3/5 states the April headline goal using the exact same wording '
      'the Mission screen itself uses (shared constant, no drift)',
      (tester) async {
        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: false),
        );
        await _advance(tester, 2);

        expect(find.text('3 / $_pageCount'), findsOneWidget);
        expect(
          find.textContaining(publicDemoAprilHeadlineGoal),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'page 4/5 shows the exact starting cash and baseline monthly fixed '
      'cost read from Finance/Payroll authority',
      (tester) async {
        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: false),
        );
        await _advance(tester, 3);

        expect(find.text('4 / $_pageCount'), findsOneWidget);
        expect(find.textContaining(expectedCash), findsOneWidget);
        expect(find.textContaining(expectedFixedCost), findsOneWidget);
      },
    );

    testWidgets(
      'page 5/5 mentions MISSION as the ongoing guide and shows the single '
      '"経営を始める" CTA, with no second/alternate CTA',
      (tester) async {
        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: false),
        );
        await _advance(tester, 4);

        expect(find.text('5 / $_pageCount'), findsOneWidget);
        expect(find.textContaining('MISSION'), findsOneWidget);
        expect(find.byKey(_startButtonKey), findsOneWidget);
        expect(find.byKey(_nextButtonKey), findsNothing);
      },
    );

    testWidgets(
      '"戻る" steps back exactly one page and never past the first page',
      (tester) async {
        await _mount(
          tester,
          openingMarker: _RecordingOpeningMarker(seen: false),
        );
        await _advance(tester, 2);
        expect(find.text('3 / $_pageCount'), findsOneWidget);

        await _tapOpeningButton(tester, _backButtonKey);
        expect(find.text('2 / $_pageCount'), findsOneWidget);

        await _tapOpeningButton(tester, _backButtonKey);
        expect(find.text('1 / $_pageCount'), findsOneWidget);
        expect(find.byKey(_backButtonKey), findsNothing);
      },
    );
  });

  group('dismissal', () {
    testWidgets(
      'paging through every screen and tapping the final start button '
      'dismisses the Opening Context, reveals HOME (never a forced Mission '
      'screen), and records the dismissal on the marker — SkillSheet is not '
      'required first',
      (tester) async {
        final marker = _RecordingOpeningMarker(seen: false);
        await _mount(tester, openingMarker: marker);
        expect(find.byKey(_openingScreenKey), findsOneWidget);

        await _completeOpening(tester);

        expect(find.byKey(_openingScreenKey), findsNothing);
        expect(find.byKey(_bottomNavKey), findsOneWidget);
        expect(find.text('1年目 4月'), findsOneWidget);
        expect(marker.markSeenCalls, 1);
        expect(marker.seen, isTrue);
        // Landed on HOME, not forced onto 社員 (SkillSheet is reached only
        // through April Mission #1 now, never a pre-management choice).
        expect(
          find.byKey(const PageStorageKey('public-demo-home-tab')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a reload after dismissal (same marker, still no save) does not '
      'show the Opening Context again',
      (tester) async {
        final marker = _RecordingOpeningMarker(seen: false);
        final saveService = _RecordingSaveService();
        await _mount(tester, saveService: saveService, openingMarker: marker);
        await _completeOpening(tester);
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
      await _completeOpening(tester);
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
        expect(find.text('1 / $_pageCount'), findsOneWidget);
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
      for (final textScale in const [1.0, 1.3]) {
        testWidgets(
          'renders every one of the $_pageCount pages without overflow at '
          '${size.width.toInt()}x${size.height.toInt()} / '
          'TextScaler $textScale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: PublicDemo01PlaceholderScreen(
                  key: UniqueKey(),
                  saveService: _RecordingSaveService(),
                  openingMarker: _RecordingOpeningMarker(seen: false),
                ),
              ),
            );
            await tester.pump();

            for (var page = 1; page <= _pageCount; page++) {
              expect(find.byKey(_openingScreenKey), findsOneWidget);
              expect(tester.takeException(), isNull);
              if (page < _pageCount) {
                await _tapOpeningButton(tester, _nextButtonKey);
              }
            }
            expect(find.byKey(_startButtonKey), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
