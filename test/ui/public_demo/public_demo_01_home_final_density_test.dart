// SES HOME Final Density: finishes HOME's one-screen density beyond what
// PUBLIC-DEMO-HOME-UI-3C (Issue #173) reached.
//
// PUBLIC-DEMO-HOME-UI-3C's own suite
// (public_demo_01_home_ui_3c_density_test.dart) already pins 今月の重要
// タスク starting inside the unscrolled 360x800 viewport. This phase's own
// acceptance criteria go one section further — クイックアクセス — and add
// the 390x844 target this repo's HOME work has always ultimately been
// judged against:
//
//  * At 390x844 (the primary target device, unscrolled, default text
//    scale): every one of KPI / ひより (Navigator) / 月次処理 (the monthly
//    primary CTA) / 社員概要 (Office Stage) / 今月の重要タスク / クイック
//    アクセス starts inside the raw ListView viewport — "原則把握可能" in
//    the SES HOME Final Density brief. Bottom Nav is a persistent
//    `Scaffold.bottomNavigationBar`, not part of the scrollable body, so it
//    is trivially always visible and is not asserted on here.
//  * At 360x800, the same information hierarchy holds (every section
//    through 今月の重要タスク still starts inside the viewport, unchanged
//    from PUBLIC-DEMO-HOME-UI-3C's own guarantee) and クイックアクセス's own
//    entry point sits close enough below the fold that a small scroll
//    reaches it — the weaker, explicitly-downgraded 360x800 bar the brief
//    states as "最低でもQuick Accessの存在/入口が認識可能".
//  * No horizontal overflow and no touch target under 48px at either
//    target width under an enlarged TextScaler (1.3, 2.0) — the brief's
//    "横スクロール禁止" / "touch target >=48px" / TextScaler requirements.
//  * The important-task CTA, now icon-only (a legitimate density lever the
//    brief itself calls out, "Important Task CTAをicon化する場合は
//    Semantics(label: item.ctaLabel)必須"), still carries its real
//    ctaLabel to an assistive-technology user via an explicit
//    `Semantics.label` — the icon never merely implies the action.
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

/// The unscrolled HOME viewport — the raw `ListView`'s own rect, exactly
/// the same finder `public_demo_01_home_ui_3c_density_test.dart` already
/// uses for the equivalent 今月の重要タスク assertion. Not `find.byKey`:
/// the ListView's own key is a `PageStorageKey<String>`, a different
/// runtime type from a plain `ValueKey<String>`, so `Key(...)` equality
/// would never match it.
Finder get _homeViewport => find.byType(ListView).first;

const _sectionKeys = <String>[
  'home-kpi-compact',
  'home-navigator',
  'public-demo-monthly-primary-cta-card',
  'home-office-stage',
  'public-demo-important-tasks',
];

const _quickAccessKey = Key('public-demo-quick-access');

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
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
  group('SES HOME Final Density: 390x844 — every section through '
      'クイックアクセス is graspable in the unscrolled initial view', () {
    testWidgets('KPI / ひより / 月次処理 / 社員概要 / 今月の重要タスク / クイックアクセス '
        'each start inside the raw ListView viewport', (tester) async {
      await _pump(tester, size: const Size(390, 844));

      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        0,
        reason: 'the assertions below must describe the unscrolled screen',
      );

      final viewport = tester.getRect(_homeViewport);
      for (final key in [..._sectionKeys, 'public-demo-quick-access']) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(
          rect.top,
          lessThan(viewport.bottom),
          reason: '$key must start inside the initial 390x844 viewport',
        );
      }
    });
  });

  group('SES HOME Final Density: 360x800 — same information hierarchy, '
      'クイックアクセス at minimum recognizable near the fold', () {
    testWidgets('KPI through 今月の重要タスク still start inside the viewport, and '
        'クイックアクセス starts within a short scroll of it', (tester) async {
      await _pump(tester, size: const Size(360, 800));

      final viewport = tester.getRect(_homeViewport);
      for (final key in _sectionKeys) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(
          rect.top,
          lessThan(viewport.bottom),
          reason:
              '$key must start inside the initial 360x800 viewport — '
              'PUBLIC-DEMO-HOME-UI-3C already guarantees this for 今月の '
              '重要タスク; this phase must not regress it',
        );
      }

      // クイックアクセス itself is the one section the brief explicitly
      // downgrades at 360x800 ("最低でもQuick Accessの存在/入口が認識可能"
      // rather than full "原則把握可能"): its own top may sit just past
      // the fold, but not buried behind an unrelated amount of extra
      // scrolling — a small, deliberate scroll reaches its entry point.
      final quickAccess = tester.getRect(find.byKey(_quickAccessKey));
      expect(
        quickAccess.top - viewport.bottom,
        lessThan(60),
        reason:
            'クイックアクセス must sit close enough below the fold at '
            '360x800 that its entry point reads as reachable, not buried',
      );
    });
  });

  group('SES HOME Final Density: no horizontal overflow / real touch '
      'targets at an enlarged TextScaler', () {
    for (final size in [Size(360, 800), Size(390, 844)]) {
      for (final textScale in [1.3, 2.0]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: HOME renders with no overflow and every important-'
            'task CTA stays a real >=48px target', (tester) async {
          await _pump(tester, size: size, textScale: textScale);

          expect(
            tester.takeException(),
            isNull,
            reason:
                'a RenderFlex/RenderBox overflow at an enlarged '
                'TextScaler surfaces as a FlutterError here',
          );

          for (final finder in [
            find.byKey(const Key('home-kpi-compact')),
            find.byKey(const Key('home-navigator')),
            find.byKey(const Key('public-demo-monthly-primary-cta-card')),
            find.byKey(const Key('home-office-stage')),
            find.byKey(const Key('public-demo-important-tasks')),
            find.byKey(_quickAccessKey),
          ]) {
            final rect = tester.getRect(finder);
            expect(rect.left, greaterThanOrEqualTo(0.0));
            expect(rect.right, lessThanOrEqualTo(size.width));
          }

          // Every important-task icon CTA this state renders is a real,
          // reachable touch target — never shrunk to fit the icon alone.
          final ctaButtons = find.byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                widget.icon is Icon &&
                (widget.icon as Icon).icon == Icons.arrow_forward_ios_rounded,
          );
          expect(ctaButtons, findsWidgets);
          for (final element in ctaButtons.evaluate()) {
            final size = tester.getSize(find.byWidget(element.widget));
            expect(size.height, greaterThanOrEqualTo(48));
            expect(size.width, greaterThanOrEqualTo(48));
          }
        });
      }
    }
  });

  group('SES HOME Final Density: the icon-only important-task CTA keeps '
      'its real label for assistive technology', () {
    testWidgets('April: every important-task row exposes its ctaLabel via '
        'Semantics, never only through the icon', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, size: const Size(390, 844));

      // April's fixed three tasks (see
      // `PublicDemo01PlaceholderScreen._importantTasks`): 営業/採用 both
      // say "対応する", 資金計画 says "確認する". Neither string is ever
      // painted as visible text on the CTA itself any more — it must
      // still reach an assistive-technology user via Semantics.
      expect(find.text('対応する'), findsNothing);
      expect(find.text('確認する'), findsNothing);
      expect(find.bySemanticsLabel('対応する'), findsWidgets);
      expect(find.bySemanticsLabel('確認する'), findsOneWidget);
      handle.dispose();
    });
  });
}
