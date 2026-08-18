// 画像付きイベントモーダル Phase 1: widget coverage for the shared
// [FoundingEventDialog]/[showFoundingEventDialog] presentation once it
// gained an optional [FoundingEventDialog.imageAssetPath]/[category] —
// the same widget every existing founding-tutorial/Beginner-Mode dialog
// already goes through (founding_dialogs.dart, beginner_mode_dialogs.dart),
// now also used by the handful of events picked out for an image (§4 of
// the Phase 1 brief). Deliberately drives the dialog directly with
// hand-built [FoundingEventDialog] fixtures rather than a full playthrough
// — the individual events' own copy/condition logic is already covered by
// `founding_progression_ui_test.dart` / `beginner_mode_widget_test.dart`;
// this file's job is the shared presentation Widget itself.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';
import 'package:smile_enjoy_story/ui/widgets/founding_dialogs.dart';

const _widths = [360.0, 390.0];

const _imageDialog = FoundingEventDialog(
  title: '🎉 新機能解放: 採用',
  body: '会社を拡大するため、新しいエンジニアを採用できるようになりました。',
  primaryLabel: '採用を見る',
  celebration: true,
  imageAssetPath: AssetPaths.eventRecruitmentApplication,
  category: '採用・応募',
);

/// Pumps a minimal screen with an "open" button that shows [dialog] via the
/// real [showFoundingEventDialog] entry point — the same call every screen
/// in this app makes (home_screen.dart's `_showPendingFoundingEvents` /
/// `_showPendingBeginnerEvents`). [onResult] mirrors how a real caller
/// reacts to the returned "did the player tap the primary action" bool.
Future<void> _pumpTrigger(
  WidgetTester tester,
  FoundingEventDialog dialog, {
  double width = 390,
  double height = 844,
  GameController? controller,
  void Function(bool tapped)? onResult,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  final button = Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final tapped = await showFoundingEventDialog(context, dialog);
            onResult?.call(tapped);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  final app = MaterialApp(home: button);

  await tester.pumpWidget(controller == null ? app : GameScope(controller: controller, child: app));
  await tester.pumpAndSettle();
}

void main() {
  group('image-backed event dialog (Phase 1 shared presentation)', () {
    testWidgets('A. an image-backed event dialog renders as a real dialog with its image', (tester) async {
      await _pumpTrigger(tester, _imageDialog);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('B. the image is the exact AssetPaths constant the event maps to', (tester) async {
      await _pumpTrigger(tester, _imageDialog);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image;
      expect(assetImage, isA<AssetImage>());
      expect((assetImage as AssetImage).assetName, AssetPaths.eventRecruitmentApplication);
    });

    testWidgets('C. category, title, body, and the primary CTA are all shown as text', (tester) async {
      await _pumpTrigger(tester, _imageDialog);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(_imageDialog.category!), findsOneWidget);
      expect(find.text(_imageDialog.title), findsOneWidget);
      expect(find.text(_imageDialog.body), findsOneWidget);
      expect(find.widgetWithText(FilledButton, _imageDialog.primaryLabel), findsOneWidget);
    });

    testWidgets('D. tapping the CTA resolves the caller\'s existing callback exactly once', (tester) async {
      var resolvedCount = 0;
      await _pumpTrigger(tester, _imageDialog, onResult: (tapped) { if (tapped) resolvedCount++; });

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(resolvedCount, 0); // still open — the callback only fires once the dialog resolves.

      await tester.tap(find.widgetWithText(FilledButton, _imageDialog.primaryLabel));
      await tester.pumpAndSettle();

      expect(resolvedCount, 1);
      expect(find.byType(AlertDialog), findsNothing); // dialog actually closed, not just re-tapped
      expect(tester.takeException(), isNull);
    });

    for (final width in _widths) {
      testWidgets('E/F. no overflow at ${width}px', (tester) async {
        await _pumpTrigger(tester, _imageDialog, width: width);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('G. a long body still leaves the CTA reachable on a short 360px viewport', (tester) async {
      final longDialog = FoundingEventDialog(
        title: _imageDialog.title,
        body: List.generate(40, (i) => '重要情報の説明行 ${i + 1}').join('\n'),
        primaryLabel: _imageDialog.primaryLabel,
        celebration: true,
        imageAssetPath: _imageDialog.imageAssetPath,
        category: _imageDialog.category,
      );
      // A deliberately short viewport (700px tall, not this project's usual
      // 844px) so the image + 40 lines of body genuinely can't all fit
      // without content scrolling — proving the CTA (outside the scroll
      // area, per showFoundingEventDialog's own contract) survives that.
      await _pumpTrigger(tester, longDialog, width: 360, height: 700);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final cta = find.widgetWithText(FilledButton, longDialog.primaryLabel);
      expect(cta, findsOneWidget);
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('H. the shared widget still renders a plain (image-less) dialog exactly as before', (tester) async {
      const plainDialog = FoundingEventDialog(
        title: 'プレーンテキストの確認',
        body: '画像なしの通常イベントでも問題なく表示できます。',
        primaryLabel: 'OK',
      );
      await _pumpTrigger(tester, plainDialog);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('プレーンテキストの確認'), findsOneWidget);
      expect(find.text('画像なしの通常イベントでも問題なく表示できます。'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final mode in [GameMode.beginner, GameMode.free]) {
      testWidgets('I. opening and closing the image dialog never mutates $mode GameState', (tester) async {
        final baseState = GameEngine.newGame().copyWith(gameMode: mode);
        SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(baseState.toJson())});
        final controller = GameController();

        await _pumpTrigger(tester, _imageDialog, controller: controller);
        // GameController's bootstrap load is async — only safe to read
        // controller.state as "the loaded save" after this settle.
        final before = jsonEncode(controller.state.toJson());

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, _imageDialog.primaryLabel));
        await tester.pumpAndSettle();

        expect(jsonEncode(controller.state.toJson()), before);
      });
    }
  });
}
