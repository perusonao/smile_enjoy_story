import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/app/nav_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/main_shell.dart';
import 'package:smile_enjoy_story/ui/recruitment/recruitment_interview_screen.dart';

GameState _readyState() {
  final base=GameEngine.newGame(seed:12); final applicant=ApplicantGenerator(seed:5).generate(1).single;
  final session=RecruitmentInterviewSession(id:'i',applicantId:applicant.id,startedWeek:1,applicantValue:ApplicantValue.careerFocused,
    selectedQuestions:InterviewQuestionCategory.values.take(3).toList(), reverseQuestion:ReverseQuestionCategory.projectChoice,
    companyAnswer:'希望を確認します', applicantReaction:'うなずいた', candidateKnowledge:55, companyImpression:65);
  return base.copyWith(applicants:[ApplicantEntry(applicant:applicant,appearedWeek:1,source:RecruitmentMediaType.freeWork)],interviewedApplicantIds:{applicant.id},recruitmentInterviews:[session]);
}

Future<void> _openSummary(WidgetTester tester) async {
  final state=_readyState(); SharedPreferences.setMockInitialValues({'ses_playable_save_v1':jsonEncode(state.toJson()),'ses_founding_tutorial_seen':true});
  final controller=GameController(); final tab=ValueNotifier<int>(SesTab.home);
  await tester.pumpWidget(
    GameScope(
      controller: controller,
      child: NavScope(
        tabIndex: tab,
        child: MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (context, value, _) => Scaffold(
              body: Center(
                child: value == SesTab.recruitment
                    ? const Text('採用画面')
                    : FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecruitmentInterviewScreen(
                              applicantId: state.applicants.single.applicant.id,
                            ),
                          ),
                        ),
                        child: const Text('応募者を開く'),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  while (controller.isLoading) { await tester.pump(const Duration(milliseconds: 20)); }
  await tester.pumpAndSettle(); await tester.tap(find.text('応募者を開く')); await tester.pumpAndSettle();
  expect(find.text('面接まとめ'),findsOneWidget);
}

void main(){
  testWidgets('hire result CTA returns to recruitment without dead-end',(tester)async{
    await _openSummary(tester); await tester.tap(find.text('採用する')); await tester.pumpAndSettle();
    expect(find.textContaining('内定'),findsWidgets); await tester.tap(find.text('採用画面へ戻る')); await tester.pumpAndSettle();
    expect(find.text('採用画面'),findsOneWidget); expect(tester.takeException(),isNull);
  });
  testWidgets('reject result CTA returns to recruitment without dead-end',(tester)async{
    await _openSummary(tester); await tester.tap(find.text('不採用')); await tester.pumpAndSettle();
    expect(find.text('不採用'),findsOneWidget); await tester.tap(find.text('採用画面へ戻る')); await tester.pumpAndSettle();
    expect(find.text('採用画面'),findsOneWidget); expect(tester.takeException(),isNull);
  });
}
