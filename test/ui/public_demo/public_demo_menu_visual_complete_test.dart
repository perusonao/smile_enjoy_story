// SES NON-HOME-UI MENU Visual Complete: pins the new メニュータブ Visual
// structure — the icon-led "メニュー" section header, the low-emphasis build
// identity row (`PublicDemoMenuBuildInfoRow`, absent entirely when no build
// metadata is available), the list-row dev/test menu toggle
// (`PublicDemoMenuListRow`), and the warning-toned test-controls card
// (`PublicDemoMenuWarningCard`) — while leaving every pre-existing
// key/behavior assertion for this tab (`build_info_test.dart`,
// `public_demo_01_bottom_nav_tabs_test.dart`,
// `public_demo_01_persistence_test.dart`) unmodified and still green (all
// three suites are re-run, unmodified, alongside this one — see the Result
// report's tests section).
//
// This tab has no gameplay figures of its own to pin (unlike Employee/
// Sales/Accounting Visual Complete) — its only production content is the
// build/deploy identity and the existing collapsed dev/test menu — so every
// assertion below is structural (keys, widget types, collapsed/expanded
// state, absence of Reference-only content) rather than numeric.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/presentation/build_info.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_menu_visual.dart';

import 'public_demo_tab_test_helpers.dart';

// Constructed the same way `build_info_test.dart` does — via the public
// `BuildInfo.fromValues` factory, kept as a shared helper just to avoid
// repeating the literal SHA/PR pair everywhere below.
BuildInfo _availableBuildInfo() => BuildInfo.fromValues(
  commitSha: 'c4beb9e3681ca90e7e0a6481109c71b925dfc72d',
  prNumber: '95',
);

Future<void> pumpMenuTab(
  WidgetTester tester, {
  BuildInfo? buildInfo,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({});
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
        child: PublicDemo01PlaceholderScreen(buildInfo: buildInfo),
      ),
    ),
  );
  await tester.pump();
  await switchPublicDemoTab(tester, PublicDemoTab.menu);
}

const _targetSizes = <Size>[Size(360, 800), Size(390, 844)];

void main() {
  group('メニュー section header', () {
    testWidgets('renders an icon-led "メニュー" header', (tester) async {
      await pumpMenuTab(tester, buildInfo: _availableBuildInfo());
      // Exactly 2: the new icon-led section header text, plus the
      // always-present bottom-navigation destination label (unrelated to
      // this Visual Complete change — the nav bar itself is unchanged).
      expect(find.text('メニュー'), findsNWidgets(2));
      expect(find.byIcon(Icons.menu_outlined), findsOneWidget);
    });
  });

  group('BuildInfo area — low emphasis (P0: BuildInfo領域を低強調で整理)', () {
    testWidgets('available build metadata: shown once, inside '
        'PublicDemoMenuCard/PublicDemoMenuBuildInfoRow, key preserved', (
      tester,
    ) async {
      await pumpMenuTab(tester, buildInfo: _availableBuildInfo());

      expect(find.byType(PublicDemoMenuBuildInfoRow), findsOneWidget);
      expect(find.byType(PublicDemoMenuCard), findsOneWidget);
      expect(find.byKey(const Key('build-info-label')), findsOneWidget);
      expect(find.text('Deploy: PR #95 · c4beb9e'), findsOneWidget);
    });

    testWidgets('unavailable build metadata: no build-info row/card at all '
        '— no empty bordered card left behind', (tester) async {
      await pumpMenuTab(tester, buildInfo: BuildInfo.fromValues());

      expect(find.byType(PublicDemoMenuBuildInfoRow), findsNothing);
      expect(find.byKey(const Key('build-info-label')), findsNothing);
      // The one remaining PublicDemoMenuCard-shaped surface on this tab is
      // the dev/test menu toggle's own list-row, not a leftover empty card.
      expect(find.byType(PublicDemoMenuCard), findsNothing);
    });
  });

  group('開発・テストメニュー toggle (collapsed-by-default preserved)', () {
    testWidgets('starts collapsed: toggle visible as PublicDemoMenuListRow, '
        'PublicDemoMenuWarningCard/test-controls not built', (tester) async {
      await pumpMenuTab(tester, buildInfo: _availableBuildInfo());

      final toggle = find.byKey(const Key('public-demo-dev-menu-toggle'));
      expect(toggle, findsOneWidget);
      expect(find.byType(PublicDemoMenuListRow), findsOneWidget);
      expect(find.byType(PublicDemoMenuWarningCard), findsNothing);
      expect(find.byKey(const Key('public-demo-test-controls')), findsNothing);
      expect(
        find.byKey(const Key('public-demo-restart-april-button')),
        findsNothing,
      );
    });

    testWidgets('tapping the toggle expands the warning-toned test-controls '
        'card; tapping again collapses it', (tester) async {
      await pumpMenuTab(tester, buildInfo: _availableBuildInfo());
      final toggle = find.byKey(const Key('public-demo-dev-menu-toggle'));

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.byType(PublicDemoMenuWarningCard), findsOneWidget);
      expect(find.byKey(const Key('public-demo-test-controls')), findsOneWidget);
      expect(find.text('テスト用操作'), findsOneWidget);
      expect(
        find.text('Public Demo 0.1の進行だけを初期状態へ戻します。'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('public-demo-restart-april-button')),
        findsOneWidget,
      );
      expect(find.text('4月からやり直す'), findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.byType(PublicDemoMenuWarningCard), findsNothing);
      expect(find.byKey(const Key('public-demo-test-controls')), findsNothing);
    });
  });

  group('restart authority / existing dialog semantics preserved', () {
    testWidgets('restart button opens the same confirm/cancel dialog with '
        'its existing keys and text', (tester) async {
      await pumpMenuTab(tester, buildInfo: _availableBuildInfo());
      await tester.tap(find.byKey(const Key('public-demo-dev-menu-toggle')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('public-demo-restart-april-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public-demo-restart-april-dialog')),
        findsOneWidget,
      );
      expect(find.text('Public Demoを4月からやり直しますか？'), findsOneWidget);
      expect(
        find.byKey(const Key('public-demo-restart-april-cancel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('public-demo-restart-april-confirm')),
        findsOneWidget,
      );

      // Cancel leaves the collapsed structure intact rather than mutating
      // anything — the same "no-op" semantics
      // `public_demo_01_persistence_test.dart` already pins for this exact
      // dialog, re-checked here only for the new visual shell around it.
      await tester.tap(
        find.byKey(const Key('public-demo-restart-april-cancel')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('public-demo-restart-april-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('public-demo-test-controls')),
        findsOneWidget,
      );
    });
  });

  group('Reference-only content stays absent (STRICTLY FORBIDDEN)', () {
    testWidgets('no manual save/load, settings, tutorial, help/FAQ, About, '
        'Credits, or Menu-local ひより advice card is ever built', (
      tester,
    ) async {
      await pumpMenuTab(tester, buildInfo: _availableBuildInfo());
      await tester.tap(find.byKey(const Key('public-demo-dev-menu-toggle')));
      await tester.pumpAndSettle();

      for (final absentText in [
        'セーブ',
        'ロード',
        '読み込む',
        'ゲーム設定',
        '難易度',
        '表示設定',
        'サウンド設定',
        'チュートリアル',
        'よくある質問',
        'お問い合わせ',
        'このゲームについて',
        'クレジット',
        'ひよりのアドバイス',
      ]) {
        expect(
          find.textContaining(absentText),
          findsNothing,
          reason: '"$absentText" is Reference-only and must not appear',
        );
      }
    });
  });

  group('other-tab isolation', () {
    testWidgets(
      'switching メニュー → ホーム and back leaves no メニュー-visual widget '
      'mounted on ホーム',
      (tester) async {
        await pumpMenuTab(tester, buildInfo: _availableBuildInfo());
        expect(find.byType(PublicDemoMenuCard), findsOneWidget);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(find.byType(PublicDemoMenuCard), findsNothing);
        expect(find.byType(PublicDemoMenuListRow), findsNothing);
        expect(find.byType(PublicDemoMenuWarningCard), findsNothing);

        await switchPublicDemoTab(tester, PublicDemoTab.menu);
        expect(find.byType(PublicDemoMenuCard), findsOneWidget);
      },
    );
  });

  group(
    '360x800 / 390x844, TextScaler 1.0 / 1.3 / 2.0: no horizontal overflow, '
    'collapsed and expanded',
    () {
      for (final size in _targetSizes) {
        for (final textScale in [1.0, 1.3, 2.0]) {
          testWidgets(
            'collapsed at ${size.width.toInt()}x${size.height.toInt()} / '
            'textScale $textScale',
            (tester) async {
              await pumpMenuTab(
                tester,
                buildInfo: _availableBuildInfo(),
                size: size,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull);
            },
          );

          testWidgets(
            'expanded at ${size.width.toInt()}x${size.height.toInt()} / '
            'textScale $textScale',
            (tester) async {
              await pumpMenuTab(
                tester,
                buildInfo: _availableBuildInfo(),
                size: size,
                textScale: textScale,
              );
              await tester.tap(
                find.byKey(const Key('public-demo-dev-menu-toggle')),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            },
          );

          testWidgets(
            'no build metadata, collapsed, at ${size.width.toInt()}x'
            '${size.height.toInt()} / textScale $textScale',
            (tester) async {
              await pumpMenuTab(
                tester,
                buildInfo: BuildInfo.fromValues(),
                size: size,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    },
  );
}
