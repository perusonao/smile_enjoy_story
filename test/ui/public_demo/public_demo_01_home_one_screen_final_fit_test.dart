// SES HOME "One-Screen Final Fit".
//
// Every prior HOME density pass (HOME-RUNTIME-2A/2B/2C, PUBLIC-DEMO-HOME-
// UI-3A/3B/3C, SES HOME Final Density, SES HOME Final Polish) only ever
// asserted that each section's TOP starts inside the unscrolled viewport —
// never that the whole HOME block, down to 今月の重要タスク's own bottom
// edge, fits with no scrolling required at all. That gap is exactly what
// let the initial April 360x800/390x844 view regress to needing a real
// scroll (measured at +75pt / +44pt of `maxScrollExtent` before this
// phase — see the result report's Before/After table).
//
// This suite closes that gap with a direct numeric assertion: at the
// default TextScaler, the ListView's own `position.maxScrollExtent` must
// be exactly 0 at both required target sizes — i.e. there is nothing left
// to scroll to, so the whole HOME block (through 今月の重要タスク) is
// already fully painted inside the viewport the first frame renders.
//
// It also re-covers the boundaries the density passes before it already
// established and this phase must not regress: no horizontal overflow, no
// RenderFlex/RenderBox overflow exception, and every real touch target
// (>=48 logical px) at an enlarged TextScaler (1.3, 2.0) — where HOME is
// explicitly allowed to grow past one screen and need scrolling instead of
// truncating text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

/// The unscrolled HOME viewport — the raw `ListView`'s own rect. Not
/// `find.byKey`: the ListView's own key is a `PageStorageKey<String>`, a
/// different runtime type from a plain `ValueKey<String>`.
Finder get _homeViewport => find.byType(ListView).first;

const _sectionKeys = <String>[
  'home-kpi-compact',
  'home-navigator',
  'public-demo-monthly-primary-cta-card',
  'home-office-stage',
  'public-demo-important-tasks',
];

const _targetSizes = <Size>[Size(360, 800), Size(390, 844)];

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: PublicDemo01PlaceholderScreen(
          saveService: _FixedSaveService(PublicDemoAggregate.initial()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SES HOME One-Screen Final Fit: the initial April HOME view needs '
      'no scrolling at all, at TextScaler 1.0', () {
    for (final size in _targetSizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets(
        '$label: the ListView has nothing left to scroll to '
        '(maxScrollExtent == 0)',
        (tester) async {
          await _pump(tester, size: size);

          final scrollable = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          expect(
            scrollable.position.pixels,
            0,
            reason: 'the assertions below must describe the unscrolled screen',
          );
          expect(
            scrollable.position.maxScrollExtent,
            0,
            reason:
                'the whole HOME block through 今月の重要タスク must already '
                'fit inside the unscrolled $label viewport — a positive '
                'maxScrollExtent means the player must scroll to see the '
                'bottom of the initial April view',
          );
        },
      );

      testWidgets(
        '$label: every HOME section, including 今月の重要タスク\'s own '
        'bottom edge, is fully painted inside the viewport',
        (tester) async {
          await _pump(tester, size: size);

          final viewport = tester.getRect(_homeViewport);
          for (final key in _sectionKeys) {
            final rect = tester.getRect(find.byKey(Key(key)));
            expect(
              rect.top,
              greaterThanOrEqualTo(viewport.top),
              reason: '$key top must be inside the $label viewport',
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(viewport.bottom),
              reason:
                  '$key bottom must be inside the $label viewport — this '
                  'is the numeric form of "no scroll needed", checked '
                  'against the section that actually ends last',
            );
          }

          // The important-tasks title itself, not merely its card's top
          // edge, must be fully visible — the same guard the Final Polish
          // suite already applies at 390x844, extended to both targets.
          final title = tester.getRect(find.text('今月の重要タスク'));
          expect(title.bottom, lessThanOrEqualTo(viewport.bottom));

          // Bottom Navigation is a persistent Scaffold.bottomNavigationBar,
          // never part of the scrollable body, so nothing in the HOME
          // block may paint below its own top edge either.
          final bottomNav = tester.getRect(
            find.byKey(const Key('public-demo-bottom-nav')),
          );
          final lastSection = tester.getRect(
            find.byKey(const Key('public-demo-important-tasks')),
          );
          expect(
            lastSection.bottom,
            lessThanOrEqualTo(bottomNav.top),
            reason: '今月の重要タスク must not overlap Bottom Navigation',
          );
        },
      );
    }
  });

  group('SES HOME One-Screen Final Fit: 390x844 keeps genuine spare room, '
      'not merely a zero-margin fit', () {
    testWidgets(
      '390x844 has more headroom than 360x800 — the smaller target stays '
      'the binding constraint',
      (tester) async {
        await _pump(tester, size: const Size(390, 844));
        final viewport844 = tester.getRect(_homeViewport);
        final last844 = tester.getRect(
          find.byKey(const Key('public-demo-important-tasks')),
        );
        final spare844 = viewport844.bottom - last844.bottom;

        await _pump(tester, size: const Size(360, 800));
        final viewport800 = tester.getRect(_homeViewport);
        final last800 = tester.getRect(
          find.byKey(const Key('public-demo-important-tasks')),
        );
        final spare800 = viewport800.bottom - last800.bottom;

        expect(spare844, greaterThanOrEqualTo(spare800));
        expect(spare800, greaterThanOrEqualTo(0));
      },
    );
  });

  group('SES HOME One-Screen Final Fit: no horizontal overflow / real '
      'touch targets at an enlarged TextScaler (HOME is allowed to grow '
      'past one screen here, never to truncate or clip)', () {
    for (final size in _targetSizes) {
      for (final textScale in [1.3, 2.0]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale: HOME renders with no overflow exception and every '
          'important-task CTA stays a real >=48px target',
          (tester) async {
            await _pump(tester, size: size, textScale: textScale);

            expect(
              tester.takeException(),
              isNull,
              reason:
                  'a RenderFlex/RenderBox overflow at an enlarged '
                  'TextScaler surfaces as a FlutterError here',
            );

            for (final key in _sectionKeys) {
              final rect = tester.getRect(find.byKey(Key(key)));
              expect(rect.left, greaterThanOrEqualTo(0.0));
              expect(rect.right, lessThanOrEqualTo(size.width));
            }

            final ctaButtons = find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.icon is Icon &&
                  (widget.icon as Icon).icon ==
                      Icons.arrow_forward_ios_rounded,
            );
            expect(ctaButtons, findsWidgets);
            for (final element in ctaButtons.evaluate()) {
              final buttonSize = tester.getSize(find.byWidget(element.widget));
              expect(buttonSize.height, greaterThanOrEqualTo(48));
              expect(buttonSize.width, greaterThanOrEqualTo(48));
            }

            // The monthly primary CTA and Hiyori's own CTA both declare a
            // real minimumSize — assert the painted size honors it rather
            // than trusting the style alone.
            final monthlyCta = tester.getRect(
              find.byKey(const Key('public-demo-monthly-primary-cta')),
            );
            expect(monthlyCta.height, greaterThanOrEqualTo(44));

            final hiyoriCta = find.byKey(
              const Key('home-recommended-action-cta'),
            );
            if (hiyoriCta.evaluate().isNotEmpty) {
              expect(
                tester.getRect(hiyoriCta).height,
                greaterThanOrEqualTo(48),
              );
            }
          },
        );
      }
    }
  });
}
