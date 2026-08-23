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

  group('REVENUE-4: pendingRevenue is part of the July affordability basis '
      '(same as PublicDemoMonthlyClose.closeJuly\'s cash guard)', () {
    // Same fixture as the "Revenue settling is what makes salary+bonus
    // payable" case in public_demo_monthly_close_revenue_test.dart:
    // cash alone (1,000,000) cannot cover totalOutflow (1,350,000), but
    // cash + pendingRevenue (1,500,000) can.
    testWidgets(
      'A. cash alone is short but cash + pendingRevenue affords the bonus',
      (tester) async {
        final state = PublicDemoState.aprilStart().copyWith(
          month: 7,
          cash: 1000000,
          pendingRevenue: 500000,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: PublicDemoSummerBonusDialog(
              state: state,
              applicants: const [],
              monthlyExpenses: 800000,
            ),
          ),
        );

        expect(find.text('現預金不足のため選択できません'), findsNothing);
        expect(find.text('支給後の予想現預金 ¥150,000'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('public-demo-summer-bonus-one')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    // Same fixture as the "insufficient cash even after Revenue settles"
    // case in public_demo_monthly_close_revenue_test.dart: cash (800,000) +
    // pendingRevenue (500,000) = 1,300,000, still short of 1,350,000.
    testWidgets(
      'B. cash + pendingRevenue is still short: bonus stays disabled',
      (tester) async {
        final state = PublicDemoState.aprilStart().copyWith(
          month: 7,
          cash: 800000,
          pendingRevenue: 500000,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: PublicDemoSummerBonusDialog(
              state: state,
              applicants: const [],
              monthlyExpenses: 800000,
            ),
          ),
        );

        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('public-demo-summer-bonus-one')),
              )
              .onPressed,
          isNull,
        );
      },
    );

    // C. pendingRevenue = 0: identical to the pre-REVENUE-4 behavior exercised
    // by the two tests above this group (both fixtures leave pendingRevenue
    // at PublicDemoState's default of 0).
  });
}
