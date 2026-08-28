// NAVIGATOR-1A: 佐倉 ひより, in isolation.
//
// This suite pins the widget and the identity behind it without a screen:
// who she is, that she says one fixed thing, that she is completely inert,
// that a portrait which cannot be drawn degrades instead of breaking, and
// that nothing about her is laid out at a height that could slice text at
// an increased system text scale.
//
// The screen-level questions — where she sits in the runtime HOME order,
// that there is exactly one of her, and that adding her changed no game
// state — live in test/ui/public_demo/public_demo_01_home_navigator_test
// .dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/presentation/home/models/home_navigator_display.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/home_navigator_section.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';

const _sizes = <Size>[Size(360, 800), Size(390, 844)];
const _scales = <double>[1.0, 1.15, 1.3, 2.0];

Future<void> pumpNavigator(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  NavigatorExpression expression = NavigatorExpression.normal,
  HomeNavigatorAdvice? advice = HomeNavigatorAdvice.neutral,
  AssetBundle? bundle,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  Widget section = Center(child: HomeNavigatorSection(expression: expression, advice: advice));
  if (bundle != null) {
    section = DefaultAssetBundle(bundle: bundle, child: section);
  }

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: section),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The height this exact text genuinely needs at this width and text scale,
/// computed independently of the widget tree.
///
/// Comparing the painted height against this is what makes "the text is not
/// clipped" a real assertion rather than a screenshot opinion: a box that
/// constrained the text would paint *less* than this, which is precisely
/// the defect Codex found in the Office Stage's fixed 20pt title row.
double requiredTextHeight(
  WidgetTester tester,
  Finder textFinder,
  double maxWidth,
  double textScale,
) {
  final text = tester.widget<Text>(textFinder);
  final painter = TextPainter(
    text: TextSpan(text: text.data, style: text.style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(textScale),
  )..layout(maxWidth: maxWidth);
  return painter.height;
}

/// An asset bundle that fails every load — a corrupt or missing image, from
/// the widget's point of view.
class _FailingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('simulated asset failure: $key');
}

/// An asset bundle whose bytes are not a decodable image.
class _CorruptAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.view(Uint8List.fromList(List<int>.filled(64, 0x7f)).buffer);
}

class _CautionOnlyFailingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == AssetPaths.navigatorCaution) {
      throw FlutterError('simulated asset failure: $key');
    }
    return rootBundle.load(key);
  }
}

void main() {
  group('identity: she is the existing 総務 employee, given a face', () {
    test('name and role are the character reference\'s, verbatim', () {
      expect(HomeNavigatorIdentity.name, '佐倉 ひより');
      expect(HomeNavigatorIdentity.romanizedName, 'Hiyori Sakura');
      expect(HomeNavigatorIdentity.role, '総務');
    });

    test('1D ships artwork for normal and worried only', () {
      expect(
        HomeNavigatorIdentity.portraitAssetFor(NavigatorExpression.normal),
        AssetPaths.navigatorNormal,
      );
      expect(
        HomeNavigatorIdentity.portraitAssetFor(NavigatorExpression.worried),
        AssetPaths.navigatorCaution,
      );
      for (final expression in [
        NavigatorExpression.smile,
        NavigatorExpression.warning,
        NavigatorExpression.celebration,
      ]) {
        expect(
          HomeNavigatorIdentity.portraitAssetFor(expression),
          isNull,
          reason:
              '$expression has no 1D artwork; returning normal\'s image here '
              'would make the widget claim an expression it cannot draw',
        );
      }
    });

    test('the expression vocabulary is the full declared set', () {
      expect(NavigatorExpression.values, <NavigatorExpression>[
        NavigatorExpression.normal,
        NavigatorExpression.smile,
        NavigatorExpression.worried,
        NavigatorExpression.warning,
        NavigatorExpression.celebration,
      ]);
    });

    test('the portrait asset is registered for bundling', () {
      expect(AssetPaths.all, containsAll([
        AssetPaths.navigatorNormal,
        AssetPaths.navigatorCaution,
      ]));
    });

    testWidgets('the registered portrait actually exists in the bundle', (
      tester,
    ) async {
      final data = await rootBundle.load(AssetPaths.navigatorNormal);
      expect(data.lengthInBytes, greaterThan(0));
    });
  });

  group('B: the name and the role are both on screen', () {
    testWidgets('佐倉 ひより, 総務, and the fixed greeting all render', (
      tester,
    ) async {
      await pumpNavigator(tester);

      expect(find.byKey(const Key('home-navigator-name')), findsOneWidget);
      expect(find.text('佐倉 ひより'), findsOneWidget);
      expect(find.byKey(const Key('home-navigator-role')), findsOneWidget);
      expect(find.text('総務'), findsOneWidget);
      expect(
        find.text(HomeNavigatorIdentity.greeting),
        findsOneWidget,
        reason: '1A says exactly one fixed line',
      );
    });

    testWidgets('the greeting is a constant — it is the same string for '
        'every expression the widget can be built with', (tester) async {
      for (final expression in NavigatorExpression.values) {
        await pumpNavigator(tester, expression: expression);
        expect(find.text(HomeNavigatorIdentity.greeting), findsOneWidget);
        expect(find.text('佐倉 ひより'), findsOneWidget);
        expect(find.text('総務'), findsOneWidget);
      }
    });
  });

  group('NAVIGATOR-1B: local inline advice interaction', () {
    testWidgets('suppressed advice exposes no local advice control', (tester) async {
      await pumpNavigator(tester, advice: null);
      expect(find.byKey(const Key('home-navigator-open-advice')), findsNothing);
    });

    testWidgets('an advice CTA runs only its supplied callback', (tester) async {
      var calls = 0;
      await pumpNavigator(tester, advice: HomeNavigatorAdvice(title: 'ひよりからのご案内', message: '既存の案内です。', ctaLabel: '続ける', onCtaPressed: () => calls++));
      await tester.tap(find.byKey(const Key('home-navigator-open-advice')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-navigator-advice-cta')));
      expect(calls, 1);
    });
    testWidgets('starts collapsed, expands and collapses with one fixed identity', (
      tester,
    ) async {
      await pumpNavigator(tester);
      final section = find.byType(HomeNavigatorSection);
      expect(find.byKey(const Key('home-navigator-open-advice')), findsOneWidget);
      expect(find.byKey(const Key('home-navigator-advice-bubble')), findsNothing);
      await tester.tap(find.byKey(const Key('home-navigator-open-advice')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-navigator-advice-bubble')), findsOneWidget);
      expect(find.text(HomeNavigatorAdvice.neutral.title), findsOneWidget);
      expect(find.text(HomeNavigatorAdvice.neutral.message), findsOneWidget);
      expect(find.descendant(of: section, matching: find.text('佐倉 ひより')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-navigator-close-advice')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-navigator-advice-bubble')), findsNothing);
    });

    testWidgets('repeated expansion and image failure keep advice usable', (tester) async {
      await pumpNavigator(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('home-navigator-open-advice')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('home-navigator-close-advice')));
        await tester.pumpAndSettle();
      }
      await pumpNavigator(tester, bundle: _FailingAssetBundle());
      await tester.tap(find.byKey(const Key('home-navigator-open-advice')));
      await tester.pumpAndSettle();
      expect(find.text(HomeNavigatorAdvice.neutral.message), findsOneWidget);
    });

    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('expanded advice fits horizontally at '
            '${size.width.toInt()}x${size.height.toInt()} / textScale $scale', (tester) async {
          await pumpNavigator(tester, size: size, textScale: scale);
          await tester.tap(find.byKey(const Key('home-navigator-open-advice')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final key in const [
            'home-navigator', 'home-navigator-advice-bubble',
            'home-navigator-advice-message', 'home-navigator-close-advice',
          ]) {
            final rect = tester.getRect(find.byKey(Key(key)));
            expect(rect.left, greaterThanOrEqualTo(0.0), reason: key);
            expect(rect.right, lessThanOrEqualTo(size.width), reason: key);
          }
        });
      }
    }
  });

  group('G: a portrait that cannot be drawn degrades, never blocks', () {
    testWidgets('the normal expression draws the bundled portrait', (
      tester,
    ) async {
      await pumpNavigator(tester);

      final image = find.byKey(const Key('home-navigator-portrait'));
      expect(image, findsOneWidget);
      final provider = tester.widget<Image>(image).image as AssetImage;
      expect(provider.assetName, AssetPaths.navigatorNormal);
      expect(
        find.byKey(const Key('home-navigator-portrait-fallback')),
        findsNothing,
      );
    });

    testWidgets('the worried expression draws the caution portrait', (tester) async {
      await pumpNavigator(tester, expression: NavigatorExpression.worried);
      final provider = tester.widget<Image>(
        find.byKey(const Key('home-navigator-portrait')),
      ).image as AssetImage;
      expect(provider.assetName, AssetPaths.navigatorCaution);
    });

    testWidgets('an expression with no artwork falls back to the silhouette '
        'and keeps every other fact readable', (tester) async {
      await pumpNavigator(tester, expression: NavigatorExpression.smile);

      expect(find.byKey(const Key('home-navigator-portrait')), findsNothing);
      expect(
        find.byKey(const Key('home-navigator-portrait-fallback')),
        findsOneWidget,
      );
      expect(find.text('佐倉 ひより'), findsOneWidget);
      expect(find.text('総務'), findsOneWidget);
      expect(find.text(HomeNavigatorIdentity.greeting), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed caution portrait retries the normal portrait', (tester) async {
      await pumpNavigator(
        tester,
        expression: NavigatorExpression.worried,
        bundle: _CautionOnlyFailingAssetBundle(),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      final provider = tester.widget<Image>(
        find.byKey(const Key('home-navigator-portrait')),
      ).image as AssetImage;
      expect(provider.assetName, AssetPaths.navigatorNormal);
    });

    for (final (label, bundle) in <(String, AssetBundle Function())>[
      ('a bundle that fails every load', _FailingAssetBundle.new),
      ('bytes that are not a decodable image', _CorruptAssetBundle.new),
    ]) {
      testWidgets('with $label the section still renders in full', (
        tester,
      ) async {
        await pumpNavigator(tester, bundle: bundle());
        // The decode failure arrives asynchronously; give it real time to
        // land, the way the existing Public Demo image suites do.
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('home-navigator-portrait-fallback')),
          findsOneWidget,
          reason: 'errorBuilder must supply an inert replacement',
        );
        expect(find.text('佐倉 ひより'), findsOneWidget);
        expect(find.text('総務'), findsOneWidget);
        expect(find.text(HomeNavigatorIdentity.greeting), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'a broken image must not throw out of layout',
        );
      });
    }
  });

  group('J: nothing here is a fixed height around text', () {
    for (final size in _sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      for (final scale in _scales) {
        testWidgets('at $label / textScale $scale the name, the role badge '
            'and the greeting are each painted at their full required '
            'height', (tester) async {
          await pumpNavigator(tester, size: size, textScale: scale);

          expect(tester.takeException(), isNull);

          for (final key in const [
            'home-navigator-name',
            'home-navigator-role',
            'home-navigator-message',
          ]) {
            final finder = find.byKey(Key(key));
            final painted = tester.getRect(finder);
            final needed = requiredTextHeight(
              tester,
              finder,
              painted.width + 0.5,
              scale,
            );
            expect(
              painted.height,
              greaterThanOrEqualTo(needed - 0.5),
              reason:
                  '$key is clipped at textScale $scale — painted '
                  '${painted.height} for text that needs $needed',
            );
          }
        });
      }

      testWidgets('at $label the card grows with the text scale instead of '
          'holding a constant height', (tester) async {
        final heights = <double, double>{};
        for (final scale in _scales) {
          await pumpNavigator(tester, size: size, textScale: scale);
          heights[scale] = tester
              .getRect(find.byKey(const Key('home-navigator')))
              .height;
        }

        for (var i = 1; i < _scales.length; i++) {
          expect(
            heights[_scales[i]]!,
            greaterThan(heights[_scales[i - 1]]!),
            reason:
                'a card that does not grow between textScale '
                '${_scales[i - 1]} and ${_scales[i]} is absorbing the '
                'growth by clipping',
          );
        }
        expect(
          heights[2.0]!,
          greaterThan(heights[1.0]! * 1.5),
          reason: 'at 2x the text genuinely takes the room it needs',
        );
      });
    }
  });

  group('H, I: the layout budget', () {
    testWidgets('at 360x800 the collapsed card stays compact while retaining '
        'an accessible advice control', (tester) async {
      await pumpNavigator(tester, size: const Size(360, 800));

      final height = tester
          .getRect(find.byKey(const Key('home-navigator')))
          .height;
      expect(height, lessThanOrEqualTo(HomeNavigatorMetrics.compactCeiling));
      expect(
        height,
        greaterThan(HomeNavigatorMetrics.compact.portraitSize),
        reason:
            'the card must include readable identity and an open control',
      );
    });

    for (final size in _sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      for (final scale in _scales) {
        testWidgets('at $label / textScale $scale nothing paints outside the '
            'screen horizontally', (tester) async {
          await pumpNavigator(tester, size: size, textScale: scale);

          expect(tester.takeException(), isNull);
          for (final key in const [
            'home-navigator',
            'home-navigator-name',
            'home-navigator-role',
            'home-navigator-message',
          ]) {
            final rect = tester.getRect(find.byKey(Key(key)));
            expect(rect.left, greaterThanOrEqualTo(0.0), reason: key);
            expect(rect.right, lessThanOrEqualTo(size.width), reason: key);
          }
        });
      }
    }

    testWidgets('the compact layout is chosen below the threshold and the '
        'normal one at or above it', (tester) async {
      await pumpNavigator(tester, size: const Size(360, 800));
      final compact = tester
          .getRect(find.byKey(const Key('home-navigator-portrait')))
          .width;
      await pumpNavigator(tester, size: const Size(390, 844));
      final normal = tester
          .getRect(find.byKey(const Key('home-navigator-portrait')))
          .width;

      expect(compact, HomeNavigatorMetrics.compact.portraitSize);
      expect(normal, HomeNavigatorMetrics.normal.portraitSize);
      expect(compact, lessThan(normal));
      expect(
        HomeNavigatorMetrics.compactWidthThreshold,
        allOf(greaterThan(360.0), lessThan(390.0)),
        reason:
            'neither required target may be decided by an exact-equality '
            'comparison against the threshold',
      );
    });
  });
}
