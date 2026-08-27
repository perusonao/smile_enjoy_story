// HOME-UI-1A: widget coverage for the static home dashboard shell.
//
// `HomeShellPage` is a standalone presentation component (Phase 1A). It is
// not yet wired into the app's runtime/navigation (see lib/main.dart, which
// is untouched by this phase), so these tests pump it directly inside a
// bare `MaterialApp` rather than going through `SesApp`/`GameController`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/presentation/home/home.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/office_stage_section.dart';

Future<void> _pumpShell(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: HomeShellPage()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home shell renders every dashboard region', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    expect(find.byType(HomeShellPage), findsOneWidget);
    expect(find.text('KPI'), findsOneWidget);
    expect(find.text('オフィス'), findsOneWidget);
    expect(find.text('重要イベント'), findsOneWidget);
    expect(find.text('会社状況'), findsOneWidget);
    expect(find.text('月末処理'), findsOneWidget);
  });

  testWidgets('Month header shows the placeholder turn label', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    expect(find.text('1年目 4月'), findsOneWidget);
  });

  testWidgets('Brand header shows the S.E.S. brand', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    expect(find.text('S.E.S.'), findsOneWidget);
    expect(find.text('Smile Enjoy Story'), findsOneWidget);
  });

  testWidgets('KPI section renders a 2-column grid of 4 placeholder tiles', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    final gridFinder = find.byType(GridView);
    expect(gridFinder, findsOneWidget);
    final grid = tester.widget<GridView>(gridFinder);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);

    expect(find.text('現金'), findsOneWidget);
    expect(find.text('技術者数'), findsOneWidget);
    expect(find.text('稼働案件'), findsOneWidget);
    expect(find.text('信用'), findsOneWidget);
  });

  testWidgets('Office stage section renders 3 empty employee slots', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    expect(
      find.descendant(
        of: find.byType(OfficeStageSection),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('Key events section shows the empty state message', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    expect(find.text('表示できるイベントはありません'), findsOneWidget);
  });

  testWidgets('Company status section shows placeholder rows', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    expect(find.text('会社名'), findsOneWidget);
    expect(find.text('経過週'), findsOneWidget);
    expect(find.text('状態'), findsOneWidget);
    // 3 status rows, all still placeholder ('—'), plus KPI's 4 placeholder
    // values also render as '—' — assert at least the 3 status rows exist.
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('Month-end CTA is disabled', (WidgetTester tester) async {
    await _pumpShell(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Bottom navigation shows all 5 tabs', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    final navBar = find.byType(BottomNavigationBar);
    expect(navBar, findsOneWidget);
    expect(
      find.descendant(of: navBar, matching: find.text('ホーム')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('社員')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('営業')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('採用')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('経営')),
      findsOneWidget,
    );
  });

  testWidgets('Bottom navigation tabs can be selected without error', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    await tester.tap(find.text('経営'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shell does not overflow at 360x800', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpShell(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shell does not overflow at 390x844', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpShell(tester);

    expect(tester.takeException(), isNull);
  });
}
