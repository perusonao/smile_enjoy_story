import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_forecast.dart';
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

/// Builds a forecast entry with the given opening cash, pending AR, and
/// next-close expected costs, mirroring the real-play repro in the P0 task
/// (opening -¥35,000, AR ¥500,000, expected costs ¥800,000 -> -¥335,000).
PublicDemoCashForecastMonth forecastEntry({
  required int openingCash,
  required int cashReceived,
  required int monthlyExpenses,
  int bonusPaid = 0,
}) => PublicDemoCashForecastMonth(
  month: 9,
  openingCash: openingCash,
  cashReceived: cashReceived,
  revenueRecognized: 0,
  monthlyExpenses: monthlyExpenses,
  bonusPaid: bonusPaid,
  closingCash: openingCash + cashReceived - monthlyExpenses - bonusPaid,
);

Future<void> pump(
  WidgetTester tester,
  PublicDemoState value, {
  PublicDemoCashForecastMonth? nextClose,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: PublicDemoCashShortageCard(state: value, nextClose: nextClose),
    ),
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

    await pump(
      tester,
      state(),
      nextClose: forecastEntry(
        openingCash: -400000,
        cashReceived: 500000,
        monthlyExpenses: 200000,
      ),
    );
    expect(find.byKey(cardKey), findsOneWidget);
  });

  testWidgets('shows committed cash, deficit, AR, and the forecasted '
      'next-close outcome', (tester) async {
    await pump(
      tester,
      state(cash: -400000, pendingRevenue: 500000),
      nextClose: forecastEntry(
        openingCash: -400000,
        cashReceived: 500000,
        monthlyExpenses: 200000,
      ),
    );

    expect(find.text('現在の現預金'), findsOneWidget);
    expect(find.text('-¥400,000'), findsOneWidget);
    expect(find.text('不足額'), findsOneWidget);
    expect(find.text('¥400,000'), findsOneWidget);
    expect(find.text('次回入金予定（売掛金）'), findsOneWidget);
    expect(find.text('¥500,000'), findsOneWidget);
  });

  group('FIRST-FUN-YEAR P0: forecast-truthful outlook', () {
    testWidgets('real-play repro (-¥35,000 cash, ¥500,000 AR, ¥800,000 next '
        'costs -> -¥335,000): the card never claims recovery, states the '
        'shortage-continues fact verbatim, and shows the AR/expected-cost '
        'evidence line', (tester) async {
      final entry = forecastEntry(
        openingCash: -35000,
        cashReceived: 500000,
        monthlyExpenses: 800000,
      );
      expect(entry.closingCash, -335000);

      await pump(
        tester,
        state(cash: -35000, pendingRevenue: 500000),
        nextClose: entry,
      );

      expect(find.text('次回決算後見込み'), findsOneWidget);
      expect(find.text('-¥335,000'), findsOneWidget);
      // The headline/evidence-line/continuation prose is one continuously
      // wrapping RichText (see the card's own doc on why) — `findRichText:
      // true` is required for `find.text`/`find.textContaining` to look
      // inside it at all; without it these would trivially find nothing
      // and assert nothing real.
      expect(
        find.textContaining(
          '次回決算後も資金不足の見込みです。赤字のままの場合は倒産となります。',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '入金予定 ¥500,000 に対し、見込み費用 ¥800,000。',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('0円以上になれば回復', findRichText: true),
        findsNothing,
        reason:
            'a next-close forecast that is still negative must never '
            'read as if it will recover',
      );
      expect(find.textContaining('回復します', findRichText: true), findsNothing);
    });

    testWidgets(
      'a positive next-close forecast states the recovery expectation, '
      'never the shortage-continues fact',
      (tester) async {
        final entry = forecastEntry(
          openingCash: -35000,
          cashReceived: 500000,
          monthlyExpenses: 200000,
        );
        expect(entry.closingCash, 265000);

        await pump(
          tester,
          state(cash: -35000, pendingRevenue: 500000),
          nextClose: entry,
        );

        expect(find.text('次回決算後見込み'), findsOneWidget);
        expect(find.text('¥265,000'), findsOneWidget);
        expect(
          find.textContaining(
            '次回の月次決算で現預金が¥265,000となり、資金不足から回復する見込みです。',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('倒産となります', findRichText: true),
          findsNothing,
        );
        expect(
          find.textContaining(
            '入金予定 ¥500,000 に対し、見込み費用 ¥200,000。',
            findRichText: true,
          ),
          findsNothing,
          reason: 'the AR/expected-cost evidence line is shortage-only',
        );
      },
    );
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('fits at ${width.toInt()}px without overflow', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await pump(
        tester,
        state(),
        nextClose: forecastEntry(
          openingCash: -35000,
          cashReceived: 500000,
          monthlyExpenses: 800000,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
