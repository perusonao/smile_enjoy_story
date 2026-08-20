import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_interview_result_dialog.dart';

void main() {
  testWidgets('shows passed interview result and next action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PublicDemoInterviewResultDialog(
            interviewName: '上位会社面談',
            personName: '佐藤 健',
            score: 72,
            passed: true,
            points: ['案件とのスキル適合が高評価', '人物面も基準を満たしています'],
            nextAction: '次は客先面談です。',
          ),
        ),
      ),
    );

    expect(find.text('上位会社面談 結果'), findsOneWidget);
    expect(find.text('佐藤 健'), findsOneWidget);
    expect(find.text('通過'), findsOneWidget);
    expect(find.text('72点'), findsOneWidget);
    expect(find.text('・案件とのスキル適合が高評価'), findsOneWidget);
    expect(find.text('次は客先面談です。'), findsOneWidget);
  });

  testWidgets('shows failed interview result and recovery action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PublicDemoInterviewResultDialog(
            interviewName: '客先面談',
            personName: '鈴木 葵',
            score: 55,
            passed: false,
            points: ['スキル適合が通過基準に届きませんでした'],
            nextAction: '別案件へ再営業しましょう。',
          ),
        ),
      ),
    );

    expect(find.text('客先面談 結果'), findsOneWidget);
    expect(find.text('不合格'), findsOneWidget);
    expect(find.text('55点'), findsOneWidget);
    expect(find.text('別案件へ再営業しましょう。'), findsOneWidget);
  });
}
