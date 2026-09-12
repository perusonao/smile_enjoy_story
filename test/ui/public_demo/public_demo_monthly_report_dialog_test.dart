// SES ISSUE-250: focused, deterministic rendering coverage for
// [PublicDemoMonthlyReportDialog] itself — pumping the widget directly with
// a hand-built [PublicDemoMonthlyReportDisplayData] fixture, rather than
// driving the full close pipeline (`public_demo_01_monthly_report_test.dart`
// already covers that end-to-end wiring). This lets every new ISSUE-250
// section (固定費 caption, ひより portrait, 次に考えること) be asserted
// against a known, controlled input instead of depending on which HOME
// recommended action happens to be eligible at a given point in a real
// playthrough.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/ui/public_demo/public_demo_monthly_report_dialog.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_monthly_report_display_data.dart';

const _reportKey = Key('public-demo-monthly-report-dialog');
const _hiyoriPortraitKey = Key('public-demo-monthly-report-hiyori-portrait');
const _nextActionKey = Key('public-demo-monthly-report-next-action');

PublicDemoMonthlyReportDisplayData _fixture({
  int fixedCostsPaid = 50000,
  String? nextActionHeadline,
  bool isFinanciallyTerminal = false,
  bool isFiscalYearCompleted = false,
}) => PublicDemoMonthlyReportDisplayData(
  closedMonth: 8,
  openingCash: 1000000,
  closingCash: 1100000,
  cashDelta: 100000,
  revenue: 800000,
  cashReceived: 800000,
  receivables: 800000,
  totalExpenses: 700000,
  salaryPaid: 600000,
  fixedCostsPaid: fixedCostsPaid,
  bonusPaid: 0,
  trainingCost: 0,
  recruitmentCost: 0,
  netIncome: 100000,
  assignedCount: 2,
  waitingCount: 1,
  nextMonthJoinNames: const [],
  isFiscalYearCompleted: isFiscalYearCompleted,
  isFinanciallyTerminal: isFinanciallyTerminal,
  nextActionHeadline: nextActionHeadline,
);

Future<void> _pump(
  WidgetTester tester,
  PublicDemoMonthlyReportDisplayData data, {
  Size? size,
  double textScale = 1.0,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => PublicDemoMonthlyReportDialog(data: data),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('1. 固定費 caption (SES ISSUE-250)', () {
    testWidgets('固定費 row shows a short composition caption', (tester) async {
      await _pump(tester, _fixture());
      expect(find.text('（家賃・水道光熱費など）'), findsOneWidget);
    });
  });

  group('2. ひより portrait (SES ISSUE-250)', () {
    testWidgets('the report renders a ひより portrait beside her comment', (
      tester,
    ) async {
      await _pump(tester, _fixture());
      expect(find.byKey(_hiyoriPortraitKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('3. 次に考えること (SES ISSUE-250)', () {
    testWidgets('a non-null nextActionHeadline renders the section with '
        'that exact text', (tester) async {
      await _pump(
        tester,
        _fixture(nextActionHeadline: '佐藤 健のスキルシートを確認'),
      );
      expect(find.text('次に考えること'), findsOneWidget);
      expect(find.byKey(_nextActionKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(_nextActionKey)).data,
        '佐藤 健のスキルシートを確認',
      );
    });

    testWidgets('a null nextActionHeadline omits the section entirely — '
        'never shows an impossible future action', (tester) async {
      await _pump(tester, _fixture());
      expect(find.text('次に考えること'), findsNothing);
      expect(find.byKey(_nextActionKey), findsNothing);
    });

    testWidgets('bankruptcy (isFinanciallyTerminal) with a non-null '
        'nextActionHeadline still renders it — the dialog never '
        'second-guesses a value it is handed; the actual terminal gate '
        'lives entirely in the owner screen, not here', (tester) async {
      // This fixture is deliberately inconsistent with real production
      // wiring (the owner screen's own [_recommendedActionSlot] never
      // supplies a headline once `s.isCloseBlocked` holds) — included only
      // to document that the dialog's own rendering rule is a plain
      // null-check, with the actual terminal gate living entirely in the
      // owner screen per [PublicDemoMonthlyReportDisplayData
      // .nextActionHeadline]'s own doc.
      await _pump(
        tester,
        _fixture(
          isFinanciallyTerminal: true,
          nextActionHeadline: '佐藤 健のスキルシートを確認',
        ),
      );
      expect(find.text('次に考えること'), findsOneWidget);
    });
  });

  group('4. One-Screen (SES ISSUE-250): 360x800 / 390x844, '
      'TextScaler 1.0 / 1.3', () {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} at ${scale}x text '
          'scale lays out without overflow',
          (tester) async {
            await _pump(
              tester,
              _fixture(nextActionHeadline: '佐藤 健のスキルシートを確認'),
              size: size,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            expect(find.byKey(_reportKey), findsOneWidget);
          },
        );
      }
    }

    testWidgets('the normal case (360x800, TextScaler 1.0) fits without '
        'scrolling — the One-Screen no-scroll target', (tester) async {
      await _pump(
        tester,
        _fixture(nextActionHeadline: '佐藤 健のスキルシートを確認'),
        size: const Size(360, 800),
      );
      final scrollable = find.descendant(
        of: find.byKey(_reportKey),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(
        position.maxScrollExtent,
        0,
        reason:
            'the normal-case report content must fit the dialog without '
            'needing to scroll at the smallest supported viewport',
      );
    });
  });
}
