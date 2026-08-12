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

    expect(find.text('S.E.S.'), findsWidgets);
    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('社員'), findsOneWidget);
    expect(find.text('採用'), findsOneWidget);
    expect(find.text('案件'), findsOneWidget);
    expect(find.text('その他'), findsOneWidget);
    expect(find.textContaining('次の週へ'), findsOneWidget);
  });

  testWidgets('bottom navigation switches tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('社員'));
    await tester.pumpAndSettle();
    expect(find.text('稼働率'), findsNothing);
    expect(find.widgetWithText(AppBar, '社員'), findsOneWidget);
  });
}
