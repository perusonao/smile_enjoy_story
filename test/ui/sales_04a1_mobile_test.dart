import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_detail_screen.dart';

void main(){for(final width in [360.0,390.0]){testWidgets('SkillSheet and sales confirmation fit at ${width.toInt()}px',(tester)async{tester.view.physicalSize=Size(width,800);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);final state=GameEngine.newGame(seed:22);SharedPreferences.setMockInitialValues({'ses_playable_save_v1':jsonEncode(state.toJson())});final controller=GameController();await tester.pumpWidget(GameScope(controller:controller,child:MaterialApp(home:EngineerDetailScreen(engineerId:state.engineers.first.id))));await tester.pumpAndSettle();expect(find.textContaining('スキルシート / 営業'),findsOneWidget);await tester.tap(find.text('営業を開始する'));await tester.pumpAndSettle();expect(find.textContaining('営業を開始します'),findsOneWidget);expect(tester.takeException(),isNull);});}}
