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
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/main.dart';

Future<void> _skipToFreeManagement(WidgetTester tester) async {
  final button = find.text('【自由モード】');
  if (button.evaluate().isNotEmpty) {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

/// Playable 0.5A replaced the start picker's "ガイド付きで開始" button with
/// the Founding Prologue (§3) — the old 0.4C.1 guided-founding tutorial
/// (2 already-employed founders, [FoundingStage] gating) still exists in
/// full for saves that predate 0.5A, but is no longer reachable by tapping
/// through the picker, so tests exercising it call the controller directly.
Future<void> _chooseGuidedStart(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  GameScope.of(context).chooseGuidedStart();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app boots into the guided-founding start picker', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();

    expect(find.text('【初心者モード】おすすめ'), findsOneWidget);
    expect(find.text('【自由モード】'), findsOneWidget);
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
    await _chooseGuidedStart(tester);

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
    // Tall enough that Home's whole task list is realized without needing
    // to scroll — the persistent HUD + company-phase banner (Playable
    // 0.4C.3 §2, §10) push later list items further down than the default
    // test surface height.
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _skipToFreeManagement(tester);

    // A brand-new game has no recruitment listing posted yet, so that
    // info-level task should always be present on Week 1 — both as a
    // recommended-action TaskCard and as the plain-text footnote below the
    // list; a short enough test viewport used to leave the second copy
    // unbuilt (Flutter's sliver list only realizes children near the
    // viewport), which is why this used to read findsOneWidget.
    expect(find.text('求人媒体が掲載されていません'), findsWidgets);
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
    await _chooseGuidedStart(tester);

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

  testWidgets('次の週へ advances the week and shows a week-summary dialog when something happened', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _skipToFreeManagement(tester);

    // Give the week something worth summarizing — otherwise (Phase 3A UX
    // review, P2-2) an uneventful week no longer interrupts "次の週へ" with
    // a dialog that only ever said "特に大きな変化はありませんでした"; see
    // the next test for that (now dialog-free) case.
    final context = tester.element(find.byType(MaterialApp));
    final controller = GameScope.of(context);
    for (final engineer in controller.state.engineers) {
      controller.startSales(engineer.id);
    }

    await tester.tap(find.textContaining('次の週へ'));
    await tester.pumpAndSettle();

    expect(find.text('Week 2'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Week 2'), findsWidgets);
  });

  testWidgets('次の週へ does not interrupt an uneventful week with an empty week-summary dialog (P2-2)', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SesApp(controller: GameController()));
    await tester.pumpAndSettle();
    await _skipToFreeManagement(tester);

    // Nothing done this week (both founders still notSelling) — no
    // WeeklySummaryEngine result, no guided action: the dialog must not
    // appear at all, and Home lands straight on Week 2.
    await tester.tap(find.textContaining('次の週へ'));
    await tester.pumpAndSettle();

    expect(find.text('特に大きな変化はありませんでした。'), findsNothing);
    expect(find.textContaining('Week 2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
