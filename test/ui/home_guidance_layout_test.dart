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
      expect(find.text('1億円'),findsOneWidget);
      expect(find.text('今やること'),findsOneWidget);
      expect(find.text('STEP 1 / 9'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}
