// Smoke tests for the Phase 1A static home dashboard shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/main.dart';

void main() {
  testWidgets('Home shell renders every dashboard region', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SesApp());

    expect(find.text('S.E.S.'), findsOneWidget);
    expect(find.text('KPI'), findsOneWidget);
    expect(find.text('オフィス'), findsOneWidget);
    expect(find.text('重要イベント'), findsOneWidget);
    expect(find.text('会社状況'), findsOneWidget);
    expect(find.text('月末処理'), findsOneWidget);

    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('社員'), findsOneWidget);
    expect(find.text('営業'), findsOneWidget);
    expect(find.text('採用'), findsOneWidget);
    expect(find.text('経営'), findsOneWidget);
  });

  testWidgets('Bottom navigation tabs can be selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SesApp());

    await tester.tap(find.text('経営'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shell does not overflow at 360x640', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SesApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shell does not overflow at 390x844', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SesApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
