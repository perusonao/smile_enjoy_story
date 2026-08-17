// Phase 3A UX review (P2-1): monthly closing figures should read as
// income (green) / expense (red) / neutral at a glance, on the value text
// itself — not just the summary-row labels that already had this. Color is
// a reinforcement only: the +/- sign prefix and each row's own label still
// carry the same meaning without it (checked below too).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/widgets/monthly_closing_dialog.dart';

MonthlyClosing _closing({
  int projectRevenue = 800000,
  int cashCollected = 777777,
  int salaryPaid = 400000,
  int rentPaid = 100000,
  int otherFixedCost = 50000,
  int monthCashMovement = 250000,
}) {
  return MonthlyClosing(
    month: 1,
    week: 4,
    label: '2026年 4月',
    projectRevenue: projectRevenue,
    accountsReceivableGenerated: projectRevenue,
    cashCollected: cashCollected,
    salaryPaid: salaryPaid,
    rentPaid: rentPaid,
    otherFixedCost: otherFixedCost,
    recruitmentCost: 0,
    accountingProfit: projectRevenue - salaryPaid - rentPaid - otherFixedCost,
    cashDelta: cashCollected - salaryPaid - rentPaid - otherFixedCost,
    monthCashMovement: monthCashMovement,
    cashBefore: 1000000,
    cashAfter: 1000000 + monthCashMovement,
  );
}

Future<void> _pumpDialog(WidgetTester tester, MonthlyClosing closing) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showMonthlyClosingDialog(context, closing),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Color? _colorOfValueText(WidgetTester tester, String substring) {
  final finder = find.textContaining(substring);
  expect(finder, findsWidgets, reason: 'expected at least one value row containing "$substring"');
  final widget = tester.widget<Text>(finder.first);
  return widget.style?.color;
}

void main() {
  testWidgets('income rows (revenue/collection) render in a positive (green) color', (tester) async {
    await _pumpDialog(tester, _closing());
    final revenueColor = _colorOfValueText(tester, '+¥800,000');
    expect(revenueColor, isNotNull);
    expect(revenueColor!.g, greaterThan(revenueColor.r)); // green-dominant
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense rows (salary/rent) render in a negative (red) color', (tester) async {
    await _pumpDialog(tester, _closing());
    final salaryColor = _colorOfValueText(tester, '-¥400,000');
    expect(salaryColor, isNotNull);
    expect(salaryColor!.r, greaterThan(salaryColor.g)); // red-dominant
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign prefix and label still carry the same meaning without relying on color alone', (tester) async {
    await _pumpDialog(tester, _closing());
    // Every income figure keeps its explicit "+" prefix; every expense
    // figure keeps its explicit "-" prefix — accessible even without color.
    expect(find.textContaining('+¥800,000'), findsWidgets);
    expect(find.textContaining('-¥400,000'), findsOneWidget);
    expect(find.text('給与'), findsOneWidget);
    expect(find.text('案件売上'), findsOneWidget);
  });

  testWidgets('a positive monthCashMovement colors the cashBefore -> cashAfter arrow/value positively', (tester) async {
    await _pumpDialog(tester, _closing(monthCashMovement: 250000));
    final afterColor = _colorOfValueText(tester, '¥1,250,000');
    expect(afterColor, isNotNull);
    expect(afterColor!.g, greaterThan(afterColor.r));
  });

  testWidgets('a negative monthCashMovement colors the cashBefore -> cashAfter value negatively', (tester) async {
    await _pumpDialog(tester, _closing(monthCashMovement: -150000));
    final afterColor = _colorOfValueText(tester, '¥850,000');
    expect(afterColor, isNotNull);
    expect(afterColor!.r, greaterThan(afterColor.g));
  });
}
