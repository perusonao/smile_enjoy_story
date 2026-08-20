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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Public Demo can be operated from April through July', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PublicDemo01PlaceholderScreen()));
    expect(find.text('4月'), findsOneWidget);

    // April: advance without winning an order. The demo must still recover into May.
    await tapAndSettle(tester, '4月終了→5月');
    expect(find.text('新しい応募が届きました'), findsOneWidget);
    expect(find.byKey(const Key('public-demo-recruitment-application-image')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '確認'));
    await tester.pumpAndSettle();
    expect(find.text('5月'), findsOneWidget);

    // May: advance without hiring. This is a valid failure/recovery route.
    await tapAndSettle(tester, '5月終了→6月');
    expect(find.text('6月'), findsOneWidget);
    expect(find.textContaining('翌月の発注を確認'), findsOneWidget);
    expect(find.text('6月終了→7月'), findsOneWidget);

    // June: no assignments is valid; advance into July waiting state.
    await tapAndSettle(tester, '6月終了→7月');
    expect(find.text('7月'), findsOneWidget);
    expect(find.text('7月開始結果'), findsOneWidget);
    expect(find.textContaining('参画 0名 / 待機 2名'), findsOneWidget);
  });
}
