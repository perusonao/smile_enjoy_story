// Mobile-width checks for the guided-founding UI added in Playable
// 0.4C.2 (§61): the employee-detail guide banner and the SkillSheet
// editor it launches must not overflow at common phone widths.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_detail_screen.dart';

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('guide banner + SkillSheet dialog fit at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final state = GameEngine.newGame(seed: 6);
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
      final controller = GameController();
      await tester.pumpWidget(
        GameScope(controller: controller, child: MaterialApp(home: EngineerDetailScreen(engineerId: focusId))),
      );
      await tester.pumpAndSettle();

      // Merely viewing the screen auto-completes Stage 1 (inspectEmployee)
      // via a postFrameCallback, which pumpAndSettle already flushes — so
      // by now the guide banner has already advanced to Stage 2
      // (SkillSheet), highlighted since this is the focus employee.
      expect(find.text('創業ガイド STEP 2 / 9'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('SkillSheetを開く'), findsWidgets);
      await tester.tap(find.text('SkillSheetを開く').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('営業用スキルシート'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
