// HOME-RUNTIME-2B: the Office Stage as a component.
//
// Everything here drives the real widget and the real
// `HomeOfficeStageDisplay`. The split under test is the one the phase rests
// on: the *display* decides who appears, in which order, and with which
// portrait; the *widget* only draws that decision. So the determinism and
// truncation rules are asserted directly on the value object (no pumping
// required, therefore no way for a passing test to depend on layout
// accidents), and the widget tests assert what is painted and that nothing
// overflows at either target size.
//
// Scope guard: the Office Stage is presentation-only. The last group pins
// that it holds no gesture, no callback and no mutation path — HOME's
// single mutation entry point is still HOME-RUNTIME-2C's Recommended
// Action CTA, which lives above this section and is not part of it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/presentation/home/models/home_office_stage_display.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/home_office_stage_section.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';

HomeOfficeStageMember member(String id, {String? name, bool portrait = true}) =>
    HomeOfficeStageMember(
      id: id,
      name: name ?? id,
      portraitAssetPath: portrait ? homeOfficeStagePortraitFor(id) : null,
    );

HomeOfficeStageDisplay displayOf(int count) => HomeOfficeStageDisplay(
  members: [for (var i = 1; i <= count; i++) member('emp-$i', name: '社員$i')],
);

/// Pumps the section at a real target size, inside the same ListView
/// padding the runtime screen gives it, so the widths under test are the
/// widths production actually lays out at.
Future<void> pumpStage(
  WidgetTester tester,
  HomeOfficeStageDisplay display, {
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [HomeOfficeStageSection(display: display)],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('D-G: employee display is capped at three, deterministically', () {
    test('D: one employee occupies one slot and hides nobody', () {
      final display = displayOf(1);
      expect(display.visibleMembers.map((m) => m.id), ['emp-1']);
      expect(display.hiddenMemberCount, 0);
    });

    test('E: two employees', () {
      final display = displayOf(2);
      expect(display.visibleMembers.map((m) => m.id), ['emp-1', 'emp-2']);
      expect(display.hiddenMemberCount, 0);
    });

    test('F: three employees fill the stage exactly', () {
      final display = displayOf(3);
      expect(display.visibleMembers.length, 3);
      expect(display.hiddenMemberCount, 0);
      expect(HomeOfficeStageDisplay.visibleSlotCount, 3);
    });

    test('G: four or more show the first three plus a remainder count', () {
      final four = displayOf(4);
      expect(four.visibleMembers.map((m) => m.id), ['emp-1', 'emp-2', 'emp-3']);
      expect(four.hiddenMemberCount, 1);

      final seven = displayOf(7);
      expect(seven.visibleMembers.length, 3);
      expect(seven.hiddenMemberCount, 4);
    });

    test('the remainder is never negative below the slot count', () {
      expect(displayOf(0).hiddenMemberCount, 0);
      expect(displayOf(2).hiddenMemberCount, 0);
    });

    testWidgets('G: the +N indicator is rendered, and only when needed', (
      tester,
    ) async {
      await pumpStage(tester, displayOf(3));
      expect(find.byKey(const Key('home-office-stage-more')), findsNothing);

      await pumpStage(tester, displayOf(5));
      expect(find.byKey(const Key('home-office-stage-more')), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('他2名'), findsOneWidget);
      // The two employees it stands for are genuinely not drawn.
      expect(find.text('社員4'), findsNothing);
      expect(find.text('社員5'), findsNothing);
    });
  });

  group('O: rendering is deterministic', () {
    test(
      'the same roster always selects the same three, in the same order',
      () {
        for (var run = 0; run < 25; run++) {
          expect(displayOf(9).visibleMembers.map((m) => m.id).toList(), [
            'emp-1',
            'emp-2',
            'emp-3',
          ]);
        }
      },
    );

    test('selection is purely by authoritative emission order', () {
      // Nothing reorders the roster for visual reasons — a rule that did
      // would make the scene change under the player for reasons the
      // player did not cause.
      final display = HomeOfficeStageDisplay(
        members: [member('a'), member('b'), member('c'), member('d')],
      );
      expect(display.visibleMembers.map((m) => m.id), ['a', 'b', 'c']);
      expect(display.hiddenMemberCount, 1);
    });

    test('the portrait pick is stable for the same id across many calls', () {
      for (final id in ['x-1', 'generated-42', 'app-2026-07-03', '鈴木']) {
        final first = homeOfficeStagePortraitFor(id);
        for (var run = 0; run < 50; run++) {
          expect(homeOfficeStagePortraitFor(id), first);
        }
      }
    });

    testWidgets('rebuilding the same display paints the same faces', (
      tester,
    ) async {
      final display = displayOf(5);
      await pumpStage(tester, display);
      final firstPass = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as AssetImage).assetName)
          .toList();

      await pumpStage(tester, display);
      final secondPass = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as AssetImage).assetName)
          .toList();

      expect(secondPass, firstPass);
      expect(firstPass, isNotEmpty);
    });
  });

  group('H-J: the portrait fallback chain', () {
    test('H: the founding team has explicit, distinct portraits', () {
      // These two ids are fixed constants of Public Demo 0.1
      // (publicDemoInitialEngineers), which is what makes an explicit pick
      // possible at all.
      expect(homeOfficeStagePortraitFor('eng-01'), AssetPaths.engineerMidlevel);
      expect(homeOfficeStagePortraitFor('eng-02'), AssetPaths.engineerJunior);
      expect(
        homeOfficeStagePortraitFor('eng-01'),
        isNot(homeOfficeStagePortraitFor('eng-02')),
      );
    });

    test('I: an unknown id falls back to a real bundled generic portrait', () {
      for (var i = 0; i < 200; i++) {
        final path = homeOfficeStagePortraitFor('generated-applicant-$i');
        expect(
          AssetPaths.all,
          contains(path),
          reason: '$path must be a bundled asset, not an invented name',
        );
        expect(path, startsWith('assets/images/characters/engineer_'));
      }
    });

    test('I: the generic fallback actually spreads across the pool', () {
      final picked = {
        for (var i = 0; i < 200; i++)
          homeOfficeStagePortraitFor('generated-applicant-$i'),
      };
      expect(picked.length, greaterThan(1));
    });

    testWidgets('H: an explicit portrait is the image actually painted', (
      tester,
    ) async {
      await pumpStage(
        tester,
        HomeOfficeStageDisplay(members: [member('eng-01', name: '佐藤 健')]),
      );
      final painted = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as AssetImage).assetName);
      expect(painted, contains(AssetPaths.engineerMidlevel));
      expect(find.text('佐藤 健'), findsOneWidget);
    });

    testWidgets('J: a member with no portrait draws the silhouette', (
      tester,
    ) async {
      await pumpStage(
        tester,
        HomeOfficeStageDisplay(
          members: [member('ghost', name: '名無し', portrait: false)],
        ),
      );
      expect(
        find.byKey(const ValueKey('home-office-stage-silhouette-ghost')),
        findsOneWidget,
      );
      expect(find.text('名無し'), findsOneWidget);
    });
  });

  group('K: the office background', () {
    testWidgets('defaults to the dedicated HOME banner asset', (tester) async {
      await pumpStage(tester, displayOf(2));
      final background = tester.widget<Image>(
        find.byKey(const Key('home-office-stage-background')),
      );
      expect(
        (background.image as AssetImage).assetName,
        AssetPaths.locationOfficeDayHomeBanner,
      );
      expect(AssetPaths.all, contains(AssetPaths.locationOfficeDayHomeBanner));
      expect(
        HomeOfficeStageDisplay(members: const []).backgroundAssetPath,
        AssetPaths.locationOfficeDayHomeBanner,
      );
    });

    testWidgets('is chosen at the construction site, not by the widget', (
      tester,
    ) async {
      // The extension point a future office-tier phase uses. It must be a
      // real bundled asset even here — no invented `office_small.jpg`.
      await pumpStage(
        tester,
        HomeOfficeStageDisplay(
          members: [member('eng-01')],
          backgroundAssetPath: AssetPaths.locationOfficeNight,
        ),
      );
      final background = tester.widget<Image>(
        find.byKey(const Key('home-office-stage-background')),
      );
      expect(
        (background.image as AssetImage).assetName,
        AssetPaths.locationOfficeNight,
      );
    });

    testWidgets('every asset this section can reference is bundled', (
      tester,
    ) async {
      await pumpStage(tester, displayOf(6));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        expect(AssetPaths.all, contains((image.image as AssetImage).assetName));
      }
    });
  });

  group('B-C, N: responsive layout safety', () {
    testWidgets('B: 360x800 uses compact mode and stays under its target', (
      tester,
    ) async {
      await pumpStage(tester, displayOf(5), size: const Size(360, 800));
      expect(tester.takeException(), isNull);

      final card = tester.getRect(find.byKey(const Key('home-office-stage')));
      expect(
        card.height,
        lessThanOrEqualTo(HomeOfficeStageMetrics.compactComponentHeight),
      );
      // The 213pt figure is a ceiling, not a target: the compact design
      // must leave real margin under it, or the first growth blows the
      // first-view budget with no warning.
      expect(
        HomeOfficeStageMetrics.compactComponentHeight,
        lessThan(HomeOfficeStageMetrics.safetyCeiling - 20),
      );
      expect(
        card.height,
        lessThan(HomeOfficeStageMetrics.safetyCeiling),
        reason: '${card.height}pt exceeds the 360x800 safety ceiling',
      );
    });

    testWidgets('C: 390x844 uses normal mode and stays under its target', (
      tester,
    ) async {
      await pumpStage(tester, displayOf(5), size: const Size(390, 844));
      expect(tester.takeException(), isNull);

      final card = tester.getRect(find.byKey(const Key('home-office-stage')));
      expect(
        card.height,
        lessThanOrEqualTo(HomeOfficeStageMetrics.normalComponentHeight),
      );
      // 390 is genuinely the roomier mode, not the same layout twice.
      expect(
        HomeOfficeStageMetrics.normalComponentHeight,
        greaterThan(HomeOfficeStageMetrics.compactComponentHeight),
      );
    });

    test('the mode boundary sits between the two target widths', () {
      expect(HomeOfficeStageMetrics.compactWidthThreshold, greaterThan(360));
      expect(HomeOfficeStageMetrics.compactWidthThreshold, lessThan(390));
      expect(HomeOfficeStageMetrics.compact.isCompact, isTrue);
      expect(HomeOfficeStageMetrics.normal.isCompact, isFalse);
      // component = scene + chrome holds in both modes.
      expect(
        HomeOfficeStageMetrics.compact.componentHeight,
        HomeOfficeStageMetrics.compactComponentHeight,
      );
      expect(
        HomeOfficeStageMetrics.normal.componentHeight,
        HomeOfficeStageMetrics.normalComponentHeight,
      );
    });

    for (final size in const [Size(360, 800), Size(390, 844)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      for (final count in const [0, 1, 2, 3, 4, 8]) {
        testWidgets('N: no overflow with $count employees at $label', (
          tester,
        ) async {
          await pumpStage(tester, displayOf(count), size: size);
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow or layout error with $count employees at $label',
          );

          // Nothing paints outside the card horizontally, which is the
          // failure a long name or a fourth figure would actually produce.
          final card = tester.getRect(
            find.byKey(const Key('home-office-stage')),
          );
          expect(card.width, lessThanOrEqualTo(size.width - 32));
          for (final text in find.byType(Text).evaluate()) {
            final rect = tester.getRect(find.byWidget(text.widget));
            expect(rect.left, greaterThanOrEqualTo(card.left - 0.5));
            expect(rect.right, lessThanOrEqualTo(card.right + 0.5));
          }
        });
      }
    }

    testWidgets('a very long name is ellipsised, never overflowed', (
      tester,
    ) async {
      await pumpStage(
        tester,
        HomeOfficeStageDisplay(
          members: [
            for (var i = 0; i < 3; i++)
              member('long-$i', name: '非常に長い日本語の社員名前テスト$i' * 3),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(const Key('home-office-stage')));
      for (final text in find.byType(Text).evaluate()) {
        expect(
          tester.getRect(find.byWidget(text.widget)).right,
          lessThanOrEqualTo(card.right + 0.5),
        );
      }
    });

    testWidgets('the empty office still renders and states why', (
      tester,
    ) async {
      await pumpStage(tester, displayOf(0));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home-office-stage-empty')), findsOneWidget);
      expect(
        find.byKey(const Key('home-office-stage-background')),
        findsOneWidget,
      );
    });
  });

  group('M: the Office Stage introduces no mutation authority', () {
    testWidgets('it holds no gesture, button, or other interactive element', (
      tester,
    ) async {
      await pumpStage(tester, displayOf(5));

      final stage = find.byKey(const Key('home-office-stage'));
      for (final type in [
        ButtonStyleButton,
        InkWell,
        GestureDetector,
        TextField,
        Checkbox,
        Switch,
        Slider,
      ]) {
        expect(
          find.descendant(of: stage, matching: find.byType(type)),
          findsNothing,
          reason: 'the Office Stage must stay presentation-only, found $type',
        );
      }
    });

    testWidgets('it does not restate the KPI\'s 参画/待機 split', (tester) async {
      // HOME-RUNTIME-2A's rule: one fact, one place on screen. The KPI row
      // above owns the participation counts, and three separate
      // authorities disagree about the per-employee version of that fact
      // at different points in a month — see the note at the top of
      // home_office_stage_display.dart.
      await pumpStage(tester, displayOf(3));
      expect(find.textContaining('参画'), findsNothing);
      expect(find.textContaining('待機'), findsNothing);
      expect(find.text('社員の様子'), findsOneWidget);
    });

    test('the display is a pure value: equal rosters compare equal', () {
      expect(displayOf(3), displayOf(3));
      expect(displayOf(3).hashCode, displayOf(3).hashCode);
      expect(displayOf(3), isNot(displayOf(4)));
      expect(
        HomeOfficeStageDisplay(members: [member('a')]),
        isNot(HomeOfficeStageDisplay(members: [member('b')])),
      );
      expect(
        HomeOfficeStageDisplay(members: [member('a')]),
        isNot(HomeOfficeStageDisplay(members: [member('a', portrait: false)])),
      );
    });
  });
}
