import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

// Some buttons (面談/受注 actions) now await _precacheEventImage(...) before
// opening a dialog (iOS rendering fix: decode the image before first paint
// instead of after). In this Flutter SDK, MultiFrameImageStreamCompleter
// only resolves via real wall-clock scheduling — tester.pump()/
// pumpAndSettle()'s fake clock never completes it on its own — so give the
// decode a real-time window via runAsync before settling the UI. Harmless
// for buttons that don't precache anything; the delay just elapses unused.
Future<void> _settleAfterPossiblePrecache(WidgetTester tester) async {
  // Looped rather than one fixed delay since real wall-clock timing is
  // noisier under parallel test-file execution (CPU contention) than when a
  // file runs alone.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  final finder = actionButton(text);
  for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets, reason: 'Could not find action button: $text');
  await tester.ensureVisible(finder.first);
  // The recruitment-media card can change the scroll extent between the
  // visibility request and the next pointer event; commit that layout first.
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await _settleAfterPossiblePrecache(tester);

  // PUBLIC-DEMO-UX-1A: SkillSheet確認 now opens real inspectable content.
  // This success-path helper explicitly confirms it before continuing; the
  // dedicated SkillSheet tests cover the cancel/no-op branch independently.
  if (text == 'SkillSheet確認' &&
      find.textContaining('営業用SkillSheet').evaluate().isNotEmpty) {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
}

Future<void> dismissInterviewResult(
  WidgetTester tester,
  String interviewName,
) async {
  expect(find.text('$interviewName 結果'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

Future<void> dismissEvent(
  WidgetTester tester,
  String title, {
  Key? imageKey,
}) async {
  expect(find.text(title), findsOneWidget);
  if (imageKey != null) {
    expect(find.byKey(imageKey), findsOneWidget);
  }
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('successful route reaches July with an active engineer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PublicDemo01PlaceholderScreen()),
    );

    // April: Sato wins the May order. The employee sales-progression card
    // is on 社員 now (PUBLIC-DEMO-HOME-UI-3B).
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    await tapAndSettle(tester, 'SkillSheet確認');
    await tapAndSettle(tester, '営業開始');
    await tapAndSettle(tester, '案件紹介');
    await tapAndSettle(tester, '上位会社面談');
    await dismissInterviewResult(tester, '上位会社面談');
    expect(find.text('客先面談'), findsWidgets);
    await tapAndSettle(tester, '客先面談');
    await dismissInterviewResult(tester, '客先面談');
    await tapAndSettle(tester, '受注');
    await dismissEvent(
      tester,
      '案件を受注しました',
      imageKey: const Key('public-demo-order-decision-image'),
    );
    // The month-close CTA is HOME's own monthly primary action.
    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await tapAndSettle(tester, '4月を終了して5月へ');
    expect(find.text('新しい応募が届きました'), findsOneWidget);
    expect(
      find.byKey(const Key('public-demo-recruitment-application-image')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, '確認'));
    await tester.pumpAndSettle();
    expect(find.text('1年目 5月'), findsOneWidget);

    // May: Takahashi is hired at the requested salary and wins a June order
    // before joining. The recruiting/applicant pipeline is on 営業 now.
    await switchPublicDemoTab(tester, PublicDemoTab.sales);
    await tapAndSettle(tester, '経歴書確認');
    await tapAndSettle(tester, '採用面談');
    expect(find.textContaining('評価 74'), findsOneWidget);
    await tapAndSettle(tester, '合格・給与提示');
    expect(find.text('給与を提示'), findsOneWidget);
    expect(find.text('月給 ¥32万'), findsWidgets);
    await tester.tap(find.byKey(const Key('public-demo-salary-offer-320000')));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, '入社前SkillSheet');
    await tapAndSettle(tester, '入社前営業');
    await tapAndSettle(tester, '案件紹介');
    await tapAndSettle(tester, '上位会社面談');
    await dismissInterviewResult(tester, '上位会社面談');
    await tapAndSettle(tester, '客先面談');
    await dismissInterviewResult(tester, '客先面談');
    await tapAndSettle(tester, '6月受注');
    await dismissEvent(
      tester,
      '案件を受注しました',
      imageKey: const Key('public-demo-order-decision-image'),
    );
    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await tapAndSettle(tester, '5月を終了して6月へ');
    await dismissEvent(
      tester,
      '入社・初参画！',
      imageKey: const Key('public-demo-first-assignment-image'),
    );
    expect(find.text('1年目 6月'), findsOneWidget);
    expect(find.text('参画'), findsOneWidget);
    // HOME-RUNTIME-2A merged the legacy 参画 stat card into the single
    // compact KPI, so this assertion now names that KPI tile directly by
    // key. That is strictly stronger than the previous Card-scoped lookup:
    // the old form would have been satisfied by ANY "2名" inside the same
    // card as the 参画 label (the 待機/社員 tiles are its neighbours now),
    // while this one can only be satisfied by the 参画 tile itself.
    expect(
      find.descendant(
        of: find.byKey(const Key('home-kpi-compact-assigned')),
        matching: find.text('2名'),
      ),
      findsOneWidget,
    );
    // Employee condition is employee detail — on 社員 now.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(find.text('社員コンディション'), findsOneWidget);
    expect(find.text('モチベーション：高い'), findsOneWidget);
    expect(find.text('会社への信頼：高い'), findsOneWidget);
    expect(find.textContaining('65'), findsNothing);
    expect(find.textContaining('60'), findsNothing);

    // June: accept at least one July continuation — the assignment
    // (project continuation) pipeline is on 営業 now.
    await switchPublicDemoTab(tester, PublicDemoTab.sales);
    await tapAndSettle(tester, '7月分の発注を確認');
    if (find.text('7月分発注あり').evaluate().isNotEmpty) {
      await tapAndSettle(tester, '受注する');
    }
    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await tapAndSettle(tester, '6月を終了して7月へ');

    expect(find.text('1年目 7月'), findsOneWidget);
    // The completed June growth is on 社員; Sato's assigned result
    // includes practical work.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(find.text('今月の成長'), findsOneWidget);
    expect(find.text('案件参画を通じて成長'), findsWidgets);
    expect(find.text('実務経験 +1か月'), findsWidgets);
    // The July assignment-result narrative is on 営業.
    await switchPublicDemoTab(tester, PublicDemoTab.sales);
    expect(find.text('7月開始結果'), findsOneWidget);
    // SES-FIRST-FUN-YEAR-UI-PHASE-1: the July recap's own
    // "参画 X名 / 待機 Y名" line was removed as a duplicate of the always-
    // visible compact KPI's 参画 tile, which already carries this exact
    // fact on every build (see the KPI-tile assertion above, and
    // public_demo_01_placeholder_screen.dart's July-block comment). The
    // KPI lives on HOME.
    await switchPublicDemoTab(tester, PublicDemoTab.home);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-kpi-compact-assigned')),
        matching: find.text('1名'),
      ),
      findsOneWidget,
    );
  });
}
