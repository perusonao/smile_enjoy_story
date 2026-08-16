import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/main.dart';

void main(){
  for(final width in [360.0,390.0]){
    testWidgets('home guidance and money do not overflow at ${width.toInt()}px',(tester)async{
      tester.view.physicalSize=Size(width,800);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);
      final base=GameEngine.newGame(seed:8);
      final state=base.copyWith(company:base.company.copyWith(cash:100000000));
      SharedPreferences.setMockInitialValues({'ses_playable_save_v1':jsonEncode(state.toJson()),'ses_founding_tutorial_seen':true});
      await tester.pumpWidget(SesApp(controller:GameController()));await tester.pumpAndSettle();
      // Playable 0.4C.3 §2: the persistent cross-tab HUD (main_shell.dart)
      // now shows cash too, alongside Home's own dashboard — so this is
      // deliberately >=1, not exactly 1.
      expect(find.text('1億円'),findsWidgets);
      expect(find.text('今やること'),findsOneWidget);
      expect(find.text('STEP 1 / 9'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}
