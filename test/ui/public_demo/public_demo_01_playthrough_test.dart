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
    expect(find.text('4月'), findsOneWidget);

    // April: advance without winning an order. The demo must still recover into May.
    await tapAndSettle(tester, '4月終了→5月');
    expect(find.text('新しい応募が届きました'), findsOneWidget);
    expect(
      find.byKey(const Key('public-demo-recruitment-application-image')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, '確認'));
    await tester.pumpAndSettle();
    expect(find.text('5月'), findsOneWidget);
    // The completed April growth is visible without another modal. Both
    // engineers waited, so no practical experience is claimed.
    expect(find.text('今月の成長'), findsOneWidget);
    expect(find.text('待機中の自己学習'), findsNWidgets(2));
    expect(find.textContaining('実務経験'), findsNothing);

    // May: advance without hiring. This is a valid failure/recovery route.
    await tapAndSettle(tester, '5月終了→6月');
    expect(find.text('6月'), findsOneWidget);
    expect(find.textContaining('翌月の発注を確認'), findsOneWidget);
    expect(find.text('6月終了→7月'), findsOneWidget);

    // June: no assignments is valid; advance into July waiting state.
    await tapAndSettle(tester, '6月終了→7月');
    expect(find.text('7月'), findsOneWidget);
    // Recruitment media is now presented at the top of July. Keep asserting
    // the exact July assignment/waiting contract after scrolling to it.
    await tester.scrollUntilVisible(
      find.textContaining('参画 0名 / 待機 2名'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('7月開始結果'), findsOneWidget);
    expect(find.textContaining('参画 0名 / 待機 2名'), findsOneWidget);
    expect(find.text('夏季賞与'), findsOneWidget);

    // The default domain plan is none, but July still explicitly asks the
    // player to confirm that decision before it can be settled.
    await tapAndSettle(tester, '7月終了→8月');
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
    await tapAndSettle(tester, '4月終了→5月');
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
    expect(find.text('利用後の現預金: ¥2100000'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('public-demo-recruitment-medium-engineer')),
    );
    await tester.pumpAndSettle();
    expect(find.text('現預金 ¥2100000'), findsWidgets);
    expect(
      find.byKey(const Key('public-demo-open-recruitment-media')),
      findsOneWidget,
    );
    expect(find.text('今月は利用済み'), findsOneWidget);
    expect(find.text('応募者2名を追加しました。'), findsOneWidget);
  });
}
