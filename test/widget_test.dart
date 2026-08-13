// Smoke test for the app shell.
//
// Verifies the app boots, resolves its (mocked) local-storage save, and
// renders the Home screen with the bottom navigation in place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/main.dart';

/// A brand-new game shows the Week-1 founding tutorial dialog on first
/// paint (Playable 0.3A §18) — dismiss it so subsequent taps in a test
/// reach the widgets underneath rather than the dialog's modal barrier.
Future<void> _dismissFoundingTutorial(WidgetTester tester) async {
  final button = find.text('案件を見る');
  if (button.evaluate().isNotEmpty) {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

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

  testWidgets('Week 1 shows the founding tutorial dialog', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    expect(find.text('創業1か月目'), findsOneWidget);
    expect(find.textContaining('現金が尽きると倒産します'), findsOneWidget);
    await _dismissFoundingTutorial(tester);
    expect(find.text('創業1か月目'), findsNothing);
  });

  testWidgets('bottom navigation switches tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _dismissFoundingTutorial(tester);

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('社員')),
    );
    await tester.pumpAndSettle();
    expect(find.text('今週の経営判断'), findsNothing);
    expect(find.widgetWithText(AppBar, '社員'), findsOneWidget);
  });

  testWidgets('Home shows the 今週の経営判断 task list with founding guidance on Week 1', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _dismissFoundingTutorial(tester);

    // A brand-new game has no recruitment listing posted yet, so that
    // info-level task should always be present on Week 1, alongside the
    // critical founding-guidance task pointing at the two waiting founders
    // (Playable 0.3A §17-18).
    expect(find.text('求人媒体が掲載されていません'), findsOneWidget);
    expect(find.text('社員2名が待機中です'), findsOneWidget);
    expect(find.text('資金余命'), findsOneWidget);
  });

  testWidgets('Engineers tab renders the two founding engineers, both waiting', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _dismissFoundingTutorial(tester);

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('社員')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '社員'), findsOneWidget);
    // Playable 0.3A starts both founders `waiting`, not pre-assigned (§2).
    expect(find.text('待機中'), findsWidgets);
    expect(find.text('参画中'), findsNothing);
  });

  testWidgets('Recruitment tab shows the three media cards and an empty applicant pool', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _dismissFoundingTutorial(tester);

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

  testWidgets('Projects tab shows the two founder projects open on Week 1', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _dismissFoundingTutorial(tester);

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('案件')),
    );
    await tester.pumpAndSettle();

    // Playable 0.3A seeds two open project listings at game start instead
    // of pre-assigning the founders to them (§2) — nothing to propose them
    // to yet is no longer the Week 1 story.
    expect(find.text('現在公開中の案件はありません。'), findsNothing);
    expect(find.textContaining('提案候補'), findsWidgets);
  });

  testWidgets('次の週へ advances the week and shows a week-summary dialog', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _dismissFoundingTutorial(tester);

    await tester.tap(find.textContaining('次の週へ'));
    await tester.pumpAndSettle();

    expect(find.text('Week 2 開始'), findsOneWidget);
    await tester.tap(find.text('今週を始める'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Week 2'), findsWidgets);
  });
}
