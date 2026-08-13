import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/recruitment/recruitment_interview_screen.dart';

void main(){
  testWidgets('390px interview shows 1/3, 3/3 transition, reverse question and summary',(tester)async{
    tester.view.physicalSize=const Size(390,844); tester.view.devicePixelRatio=1; addTearDown(tester.view.resetPhysicalSize);
    final base=GameEngine.newGame(seed:123); final applicant=ApplicantGenerator(seed:44).generate(1).single;
    final state=base.copyWith(applicants:[ApplicantEntry(applicant:applicant,appearedWeek:1,source:RecruitmentMediaType.freeWork)]);
    SharedPreferences.setMockInitialValues({'ses_playable_save_v1':jsonEncode(state.toJson())}); final controller=GameController();
    await tester.pumpWidget(GameScope(controller:controller,child:MaterialApp(home:RecruitmentInterviewScreen(applicantId:applicant.id)))); await tester.pumpAndSettle();
    expect(find.text('質問 1 / 3'),findsOneWidget);
    for(final label in ['技術経験','役割・経歴','転職理由']){await tester.tap(find.text(label));await tester.pumpAndSettle();}
    expect(find.text('応募者からの質問'),findsOneWidget); expect(tester.takeException(),isNull);
    await tester.tap(find.byType(FilledButton).first); await tester.pumpAndSettle();
    expect(find.text('面接まとめ'),findsOneWidget); expect(find.text('採用する'),findsOneWidget); expect(find.text('不採用'),findsOneWidget); expect(tester.takeException(),isNull);
  });
}
