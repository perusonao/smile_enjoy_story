import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_cash_flow.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_monthly_cash_flow_card.dart';

PublicDemoMonthlyCashFlow flow({
  int month = 5,
  int openingCash = 2200000,
  int cashReceived = 0,
  int salaryPaid = 800000,
  int bonusPaid = 0,
  int trainingCost = 0,
  int recruitmentCost = 0,
  int closingCash = 1400000,
  int revenue = 500000,
  int receivables = 500000,
}) => PublicDemoMonthlyCashFlow(
  month: month,
  openingCash: openingCash,
  cashReceived: cashReceived,
  salaryPaid: salaryPaid,
  bonusPaid: bonusPaid,
  trainingCost: trainingCost,
  recruitmentCost: recruitmentCost,
  closingCash: closingCash,
  revenue: revenue,
  receivables: receivables,
);

void main() {
  Future<void> pump(WidgetTester tester, PublicDemoMonthlyCashFlow value) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PublicDemoMonthlyCashFlowCard(flow: value)),
        ),
      );

  testWidgets('renders as a monthly cash flow card', (tester) async {
    await pump(tester, flow());
    expect(
      find.byKey(const Key('public-demo-monthly-cash-flow-card')),
      findsOneWidget,
    );
  });

  testWidgets('shows opening cash', (tester) async {
    await pump(tester, flow(openingCash: 2200000));
    expect(find.text('月初現預金'), findsOneWidget);
    expect(find.text('¥2,200,000'), findsOneWidget);
  });

  testWidgets('shows closing cash', (tester) async {
    await pump(tester, flow(closingCash: 1400000));
    expect(find.text('月末現預金'), findsOneWidget);
    expect(find.text('¥1,400,000'), findsOneWidget);
  });

  testWidgets('shows revenue', (tester) async {
    await pump(tester, flow(revenue: 500000, receivables: 500000));
    expect(find.text('売上'), findsOneWidget);
    expect(find.text('¥500,000'), findsWidgets);
  });

  testWidgets('shows cash received (入金)', (tester) async {
    await pump(tester, flow(cashReceived: 500000));
    expect(find.text('入金'), findsOneWidget);
    expect(find.text('+¥500,000'), findsOneWidget);
  });

  testWidgets('shows receivables with the next-month-collection label', (
    tester,
  ) async {
    await pump(tester, flow(receivables: 500000));
    expect(find.text('売掛金（来月入金予定）'), findsOneWidget);
    expect(find.text('¥500,000'), findsWidgets);
  });

  testWidgets('shows total outflow', (tester) async {
    await pump(tester, flow(salaryPaid: 800000));
    expect(find.text('支出合計'), findsOneWidget);
    expect(find.text('-¥800,000'), findsOneWidget);
  });

  testWidgets('explains the 30-day cycle only when revenue was recognized', (
    tester,
  ) async {
    await pump(tester, flow(revenue: 500000));
    expect(find.text('今月の売上は来月に入金されます'), findsOneWidget);

    await pump(tester, flow(revenue: 0, receivables: 0));
    expect(find.text('今月の売上は来月に入金されます'), findsNothing);
  });

  testWidgets('itemized breakdown is collapsed but reachable', (tester) async {
    await pump(
      tester,
      flow(salaryPaid: 800000, bonusPaid: 200000, trainingCost: 30000),
    );
    expect(find.text('賞与'), findsNothing);
    expect(find.text('研修費'), findsNothing);

    await tester.tap(find.text('支出の内訳を見る'));
    await tester.pumpAndSettle();
    expect(find.text('給与'), findsOneWidget);
    expect(find.text('-¥800,000'), findsOneWidget);
    expect(find.text('賞与'), findsOneWidget);
    expect(find.text('-¥200,000'), findsOneWidget);
    expect(find.text('研修費'), findsOneWidget);
    expect(find.text('-¥30,000'), findsOneWidget);
  });

  testWidgets('zero-amount breakdown items are omitted', (tester) async {
    await pump(tester, flow(bonusPaid: 0, trainingCost: 0, recruitmentCost: 0));
    await tester.tap(find.text('支出の内訳を見る'));
    await tester.pumpAndSettle();
    expect(find.text('賞与'), findsNothing);
    expect(find.text('研修費'), findsNothing);
    expect(find.text('採用費'), findsNothing);
  });

  testWidgets('negative closing cash still renders correctly', (tester) async {
    await pump(tester, flow(closingCash: -400000));
    expect(find.text('-¥400,000'), findsOneWidget);
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('fits at ${width.toInt()}px without overflow', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await pump(tester, flow());
      expect(tester.takeException(), isNull);
    });
  }
}
