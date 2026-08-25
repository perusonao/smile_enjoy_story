import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_cash_shortage_card.dart';

PublicDemoState state({
  int cash = -400000,
  int pendingRevenue = 500000,
  PublicDemoFinancialStatus financialStatus =
      PublicDemoFinancialStatus.cashShortage,
}) => PublicDemoState(
  month: 8,
  cash: cash,
  engineerCount: 2,
  adminCount: 1,
  salesCapacity: 4,
  salesUsed: 0,
  engineersWaiting: 2,
  engineersAssigned: 0,
  pendingRevenue: pendingRevenue,
  financialStatus: financialStatus,
);

Future<void> pump(WidgetTester tester, PublicDemoState value) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PublicDemoCashShortageCard(state: value)),
      ),
    );

void main() {
  const cardKey = Key('public-demo-cash-shortage-card');

  testWidgets('renders only for the authoritative cashShortage status', (
    tester,
  ) async {
    for (final status in [
      PublicDemoFinancialStatus.normal,
      PublicDemoFinancialStatus.bankruptcy,
      PublicDemoFinancialStatus.marchCashShortageFailure,
    ]) {
      await pump(tester, state(financialStatus: status));
      expect(find.byKey(cardKey), findsNothing, reason: status.name);
    }

    await pump(
      tester,
      state(cash: -400000, financialStatus: PublicDemoFinancialStatus.normal),
    );
    expect(
      find.byKey(cardKey),
      findsNothing,
      reason: 'negative cash alone must not infer cashShortage',
    );

    await pump(tester, state());
    expect(find.byKey(cardKey), findsOneWidget);
  });

  testWidgets('shows committed cash, deficit, AR, and the one-close rule', (
    tester,
  ) async {
    await pump(tester, state(cash: -400000, pendingRevenue: 500000));

    expect(find.text('現在の現預金'), findsOneWidget);
    expect(find.text('-¥400,000'), findsOneWidget);
    expect(find.text('不足額'), findsOneWidget);
    expect(find.text('¥400,000'), findsOneWidget);
    expect(find.text('次回入金予定（売掛金）'), findsOneWidget);
    expect(find.text('¥500,000'), findsOneWidget);
    expect(find.textContaining('次回の月次決算で現預金が0円以上になれば回復'), findsOneWidget);
    expect(find.textContaining('赤字のままの場合は倒産'), findsOneWidget);
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('fits at ${width.toInt()}px without overflow', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await pump(tester, state());
      expect(tester.takeException(), isNull);
    });
  }
}
