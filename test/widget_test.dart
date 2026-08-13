// Smoke test for the Playable 0.1 app shell.
//
// Verifies the app boots, resolves its (mocked) local-storage save, and
// renders the Home screen with the bottom navigation in place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/main.dart';

void main() {
  testWidgets('app boots into the Home screen with bottom navigation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);
    expect(find.text('S.E.S.'), findsWidgets);
    expect(find.descendant(of: navBar, matching: find.text('ホーム')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('社員')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('採用')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('案件')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('その他')), findsOneWidget);
    expect(find.textContaining('次の週へ'), findsOneWidget);
    expect(find.text('今週の経営判断'), findsOneWidget);
  });

  testWidgets('bottom navigation switches tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('社員')),
    );
    await tester.pumpAndSettle();
    expect(find.text('今週の経営判断'), findsNothing);
    expect(find.widgetWithText(AppBar, '社員'), findsOneWidget);
  });

  testWidgets('Home shows the 今週の経営判断 task list with a starting task', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    // A brand-new game has no recruitment listing posted yet, so that
    // info-level task should always be present on Week 1.
    expect(find.text('求人媒体が掲載されていません'), findsOneWidget);
    expect(find.textContaining('今週収支'), findsWidgets);
  });

  testWidgets('Engineers tab renders the two founding engineers', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('社員')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '社員'), findsOneWidget);
    expect(find.text('参画中'), findsWidgets);
  });

  testWidgets('Recruitment tab shows the three media cards and an empty applicant pool', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('採用')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Free Work'), findsOneWidget);
    expect(find.text('Engineer Career'), findsOneWidget);
    expect(find.text('Direct Scout'), findsOneWidget);
    expect(
      find.text('現在応募者はいません。求人媒体に掲載してみましょう。', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('Projects tab starts empty before any week has been advanced', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('案件')),
    );
    await tester.pumpAndSettle();

    expect(find.text('現在公開中の案件はありません。'), findsOneWidget);
  });

  testWidgets('次の週へ advances the week and shows a week-summary dialog', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('次の週へ'));
    await tester.pumpAndSettle();

    expect(find.text('Week 2 開始'), findsOneWidget);
    await tester.tap(find.text('今週を始める'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Week 2'), findsWidgets);
  });
}
