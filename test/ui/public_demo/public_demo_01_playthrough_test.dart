import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  // scrollUntilVisible only guarantees the target exists in the tree, not
  // that it is within the current viewport (FINANCE-UX-1's monthly
  // cash-flow card made this screen's content tall enough for that gap to
  // matter) — ensureVisible explicitly scrolls it into the tappable area.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  // The button's handler now awaits _precacheEventImage(...) before opening
  // any event dialog (iOS rendering fix: decode the image before first
  // paint instead of after). In this Flutter SDK, MultiFrameImageStreamCompleter
  // only resolves via real wall-clock scheduling — the fake clock that
  // tester.pump()/pumpAndSettle() drives never completes it on its own — so
  // give the decode a real-time window via runAsync, interleaved with pumps
  // so a completion queued mid-wait still gets picked up. Looped rather than
  // one fixed delay since real wall-clock timing is noisier under parallel
  // test-file execution (CPU contention) than when a file runs alone.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Public Demo can be operated from April through July', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PublicDemo01PlaceholderScreen()),
    );
    expect(find.text('1年目 4月'), findsOneWidget);

    // April: advance without winning an order. The demo must still recover into May.
    await tapAndSettle(tester, '4月を終了して5月へ');
    expect(find.text('新しい応募が届きました'), findsOneWidget);
    expect(
      find.byKey(const Key('public-demo-recruitment-application-image')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, '確認'));
    await tester.pumpAndSettle();
    expect(find.text('1年目 5月'), findsOneWidget);
    // The completed April growth is visible without another modal. Both
    // engineers waited, so no practical experience is claimed.
    expect(find.text('今月の成長'), findsOneWidget);
    expect(find.text('待機中の自己学習'), findsNWidgets(2));
    expect(find.textContaining('実務経験'), findsNothing);

    // May: advance without hiring. This is a valid failure/recovery route.
    await tapAndSettle(tester, '5月を終了して6月へ');
    expect(find.text('1年目 6月'), findsOneWidget);
    expect(find.textContaining('翌月の発注を確認'), findsOneWidget);
    expect(find.text('6月を終了して7月へ'), findsOneWidget);

    // June: no assignments is valid; advance into July waiting state.
    await tapAndSettle(tester, '6月を終了して7月へ');
    expect(find.text('1年目 7月'), findsOneWidget);
    // Recruitment media is intentionally unavailable in July because this
    // month has no applicant-processing pipeline. Keep asserting the exact
    // July assignment/waiting contract after scrolling to it.
    expect(
      find.byKey(const Key('public-demo-recruitment-media-card')),
      findsNothing,
    );
    expect(find.text('求人媒体を選ぶ'), findsNothing);
    // SES-FIRST-FUN-YEAR-UI-PHASE-1: the July recap's own
    // "参画 X名 / 待機 Y名" line was removed as a duplicate of the always-
    // visible compact KPI's 参画/待機 tiles, which already carry this exact
    // fact on every build (see public_demo_01_placeholder_screen.dart's
    // July-block comment). Assert the fact through its one remaining home,
    // the KPI tile, rather than a line that no longer exists.
    expect(
      find.descendant(
        of: find.byKey(const Key('home-kpi-compact-assigned')),
        matching: find.text('0名'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home-kpi-compact-waiting')),
        matching: find.text('2名'),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('7月開始結果'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('7月開始結果'), findsOneWidget);
    expect(find.text('夏季賞与'), findsOneWidget);

    // The default domain plan is none, but July still explicitly asks the
    // player to confirm that decision before it can be settled.
    await tapAndSettle(tester, '7月を終了して8月へ');
    expect(
      find.byKey(const Key('public-demo-summer-bonus-none')),
      findsOneWidget,
    );
  });

  testWidgets('recruitment media adds applicants through the existing flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PublicDemo01PlaceholderScreen()),
    );
    await tapAndSettle(tester, '4月を終了して5月へ');
    await tester.tap(find.widgetWithText(FilledButton, '確認'));
    await tester.pumpAndSettle();

    final recruitmentMediaButton = find.byKey(
      const Key('public-demo-open-recruitment-media'),
    );
    await tester.ensureVisible(recruitmentMediaButton);
    await tester.pumpAndSettle();
    await tester.tap(recruitmentMediaButton);
    await tester.pumpAndSettle();
    expect(find.text('無料求人'), findsOneWidget);
    expect(find.text('エンジニア求人'), findsOneWidget);
    expect(find.text('費用: ¥0 / 応募: 1名'), findsOneWidget);
    expect(find.text('費用: ¥100000 / 応募: 2名'), findsOneWidget);
    expect(find.text('利用後の現預金: ¥3100000'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('public-demo-recruitment-medium-engineer')),
    );
    await tester.pumpAndSettle();
    expect(find.text('現預金 ¥3100000'), findsWidgets);
    expect(
      find.byKey(const Key('public-demo-open-recruitment-media')),
      findsOneWidget,
    );
    expect(find.text('今月は利用済み'), findsOneWidget);
    expect(find.text('応募者2名を追加しました。'), findsOneWidget);
  });
}
