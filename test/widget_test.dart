// Smoke test for the app shell.
//
// Verifies the app boots, resolves its (mocked) local-storage save, and
// renders the Home screen with the bottom navigation in place. Playable
// 0.4C.1 introduces a "ガイド付きで開始 / 自由に開始" picker on a genuinely
// fresh boot (no prior save) — tests dismiss it via "自由に開始" so the
// rest of the suite exercises the full, already-unlocked feature set,
// matching this file's original (pre-0.4C.1) scope.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/main.dart';

Future<void> _skipToFreeManagement(WidgetTester tester) async {
  final button = find.text('自由に開始');
  if (button.evaluate().isNotEmpty) {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('app boots into the guided-founding start picker', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    expect(find.text('ガイド付きで開始'), findsOneWidget);
    expect(find.text('自由に開始'), findsOneWidget);
  });

  testWidgets('app boots into the Home screen with bottom navigation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _skipToFreeManagement(tester);

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

  testWidgets('a fresh guided game shows the Stage 1 founding mission on Home', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    // "ガイド付きで開始" just dismisses the picker — tutorial stays on.
    await tester.tap(find.text('ガイド付きで開始'));
    await tester.pumpAndSettle();

    expect(find.text('今やること'), findsOneWidget);
    expect(find.text('STEP 1 / 9'), findsOneWidget);
    expect(find.text('まず社員を確認しましょう'), findsOneWidget);
  });

  testWidgets('bottom navigation switches tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _skipToFreeManagement(tester);

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('社員')),
    );
    await tester.pumpAndSettle();
    expect(find.text('今週の経営判断'), findsNothing);
    expect(find.widgetWithText(AppBar, '社員'), findsOneWidget);
  });

  testWidgets('Home shows the 今週の経営判断 task list on Week 1', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _skipToFreeManagement(tester);

    // A brand-new game has no recruitment listing posted yet, so that
    // info-level task should always be present on Week 1.
    expect(find.text('求人媒体が掲載されていません'), findsOneWidget);
    expect(find.text('資金余命'), findsOneWidget);
  });

  testWidgets('Engineers tab renders the two founding engineers, both waiting', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _skipToFreeManagement(tester);

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('社員')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '社員'), findsOneWidget);
    // Playable 0.3A starts both founders `waiting`, not pre-assigned (§2).
    expect(find.text('待機中'), findsWidgets);
    expect(find.text('参画中'), findsNothing);
  });

  testWidgets('Recruitment tab is locked until the first assignment (guided game)', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ガイド付きで開始'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('採用')),
    );
    await tester.pumpAndSettle();

    expect(find.text('🔒'), findsOneWidget);
    expect(find.text('まず既存社員を1名案件参画させると解放されます。'), findsOneWidget);
    expect(find.text('Free Work'), findsNothing);
  });

  testWidgets('Recruitment tab shows the three media cards and an empty applicant pool when unlocked', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _skipToFreeManagement(tester);

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
    await _skipToFreeManagement(tester);

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('案件')),
    );
    await tester.pumpAndSettle();

    // Playable 0.3A seeds two open project listings at game start instead
    // of pre-assigning the founders to them (§2) — nothing to propose them
    // to yet is no longer the Week 1 story.
    expect(find.text('現在公開中の案件はありません。'), findsNothing);
    expect(find.textContaining('合いそうな社員'), findsWidgets);
    expect(find.textContaining('営業中'), findsWidgets);
    expect(find.textContaining('選考'), findsWidgets);
  });

  testWidgets('次の週へ advances the week and shows a week-summary dialog', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _skipToFreeManagement(tester);

    await tester.tap(find.textContaining('次の週へ'));
    await tester.pumpAndSettle();

    expect(find.text('Week 2'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Week 2'), findsWidgets);
  });
}
