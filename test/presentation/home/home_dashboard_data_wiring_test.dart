// HOME-UI-1C: widget coverage for wiring HomeDashboardDisplayData into the
// existing HOME-UI-1A/1B presentation widgets.
//
// This does not change how HomeShellPage is mounted into the app (still
// unwired from lib/main.dart/navigation — see home_shell_page_test.dart's
// own header comment). It only proves that, when a caller supplies a real
// projection built from authoritative Public Demo state, the widgets render
// it — and that every widget still falls back to its original Phase 1A/1B
// placeholder behavior when no data is supplied (see the "no data" group
// below and the untouched assertions in home_shell_page_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/presentation/home/home.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/kpi_section.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/month_header_bar.dart';

final _sampleData = HomeDashboardDisplayData.fromPublicDemoState(
  PublicDemoState.aprilStart()
      .advanceToMay(monthlyExpenses: 800000, orderedEngineers: 1)
      .copyWith(cash: 2500000, pendingRevenue: 500000),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

/// For bare (non-Scaffold) section widgets like [KpiSection]: its real
/// host, HomeShellPage, always renders it inside a SingleChildScrollView
/// (see home_shell_page.dart) — mirrored here so an isolated widget test
/// sees the same unbounded-height context, rather than a bare Scaffold
/// body clipping/overflowing a now-7-tile grid.
Future<void> _pumpScrollable(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MonthHeaderBar', () {
    testWidgets('renders the placeholder label when data is not supplied', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(appBar: MonthHeaderBar()));

      expect(find.text('1年目 4月'), findsOneWidget);
    });

    testWidgets('renders the real year/month when data is supplied', (
      tester,
    ) async {
      await _pump(tester, Scaffold(appBar: MonthHeaderBar(data: _sampleData)));

      expect(find.text('1年目 5月'), findsOneWidget);
      expect(find.text('1年目 4月'), findsNothing);
    });
  });

  group('KpiSection', () {
    testWidgets('renders placeholder dashes for every tile without data', (
      tester,
    ) async {
      await _pumpScrollable(tester, const KpiSection());

      expect(find.text('現金'), findsOneWidget);
      expect(find.text('社員数'), findsOneWidget);
      expect(find.text('参画中'), findsOneWidget);
      expect(find.text('売上'), findsOneWidget);
      expect(find.text('入金予定'), findsOneWidget);
      expect(find.text('稼働案件'), findsOneWidget);
      expect(find.text('信用'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(7));
    });

    testWidgets('renders real values for the connected tiles', (tester) async {
      await _pumpScrollable(tester, KpiSection(data: _sampleData));

      expect(find.text('¥250万'), findsOneWidget); // 現金
      expect(find.text('2名'), findsOneWidget); // 社員数
      expect(find.text('1名'), findsOneWidget); // 参画中
      // 売上 (1 assigned engineer x ¥50万) and 入金予定 (¥50万, set directly
      // on the fixture) happen to format to the same string here.
      expect(find.text('¥50万'), findsNWidgets(2));
      // 稼働案件/信用 have no HOME-UI-1C authority yet and stay placeholders.
      expect(find.text('—'), findsNWidgets(2));
    });
  });

  group('HomeShellPage', () {
    testWidgets('threads dashboardData into the month header and KPI section', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeShellPage(dashboardData: _sampleData)),
      );
      await tester.pumpAndSettle();

      expect(find.text('1年目 5月'), findsOneWidget);
      expect(find.text('2名'), findsOneWidget);
      expect(find.text('1名'), findsOneWidget);
    });

    testWidgets('does not overflow at 360x800 with real data', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: HomeShellPage(dashboardData: _sampleData)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at 390x844 with real data', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: HomeShellPage(dashboardData: _sampleData)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the month-end CTA stays disabled even with real dashboard data',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: HomeShellPage(dashboardData: _sampleData)),
        );
        await tester.pumpAndSettle();

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
      },
    );
  });
}
