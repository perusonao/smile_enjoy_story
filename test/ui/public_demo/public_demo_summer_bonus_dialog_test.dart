import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_summer_bonus_dialog.dart';

class _Issue133Harness extends StatefulWidget {
  const _Issue133Harness();

  @override
  State<_Issue133Harness> createState() => _Issue133HarnessState();
}

class _Issue133HarnessState extends State<_Issue133Harness> {
  static const monthlyExpenses = 1570000;
  PublicDemoState state = PublicDemoState(
    month: 7,
    cash: 860000,
    engineerCount: 3,
    adminCount: 1,
    salesCapacity: 4,
    salesUsed: 0,
    engineersWaiting: 2,
    engineersAssigned: 1,
    pendingRevenue: 500000,
  );

  Future<void> decide() async {
    final plan = await showDialog<PublicDemoSummerBonusPlan>(
      context: context,
      builder: (context) => PublicDemoSummerBonusDialog(
        state: state,
        applicants: const [],
        monthlyExpenses: monthlyExpenses,
      ),
    );
    if (plan == null) return;
    setState(() => state = state.confirmSummerBonusDecision(plan));
  }

  void closeJuly() {
    final result = PublicDemoMonthlyClose.closeJuly(
      state: state,
      monthlyExpenses: monthlyExpenses,
      applicants: const [],
    );
    setState(() => state = result.state);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('month:${state.month}'),
        Text('cash:${state.cash}'),
        FilledButton(onPressed: decide, child: const Text('賞与を決める')),
        FilledButton(onPressed: closeJuly, child: const Text('7月を閉じる')),
      ],
    ),
  );
}

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

  testWidgets('Issue #133: none stays enabled at projected -210,000 and '
      'the widget flow reaches August', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Issue133Harness()));

    await tester.tap(find.text('賞与を決める'));
    await tester.pumpAndSettle();

    expect(find.text('支給後の予想現預金 -¥210,000'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('public-demo-summer-bonus-none')),
          )
          .onPressed,
      isNotNull,
    );
    for (final plan in ['half', 'one']) {
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(Key('public-demo-summer-bonus-$plan')),
            )
            .onPressed,
        isNull,
      );
    }

    await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7月を閉じる'));
    await tester.pump();

    expect(find.text('month:8'), findsOneWidget);
    expect(find.text('cash:-210000'), findsOneWidget);
  });
}
