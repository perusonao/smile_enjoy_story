import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_summer_bonus_dialog.dart';

void main() {
  testWidgets('shows bonus amounts and post-payment cash', (tester) async {
    final state = PublicDemoState.aprilStart().copyWith(
      month: 7,
      cash: 3000000,
    );
    final expenses = PublicDemoSalaryFinance.monthlyExpenses(
      baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      hires: const [],
      month: 7,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PublicDemoSummerBonusDialog(
          state: state,
          applicants: const [],
          monthlyExpenses: expenses,
        ),
      ),
    );

    expect(find.text('夏季賞与'), findsOneWidget);
    expect(find.text('なし'), findsOneWidget);
    expect(find.text('0.5か月'), findsOneWidget);
    expect(find.text('1か月'), findsOneWidget);
    expect(find.text('支給総額 ¥275,000'), findsOneWidget);
    expect(find.text('支給総額 ¥550,000'), findsOneWidget);
    expect(find.text('支給後の予想現預金 ¥1,650,000'), findsOneWidget);
  });

  testWidgets('disables unaffordable plans with a concise reason', (
    tester,
  ) async {
    final state = PublicDemoState.aprilStart().copyWith(
      month: 7,
      cash: 1000000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PublicDemoSummerBonusDialog(
          state: state,
          applicants: const [],
          monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        ),
      ),
    );

    expect(find.text('現預金不足のため選択できません'), findsNWidgets(2));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('public-demo-summer-bonus-half')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('public-demo-summer-bonus-one')),
          )
          .onPressed,
      isNull,
    );
  });
}
