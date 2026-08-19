import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

void main() {
  testWidgets('Public Demo can be operated from April through July', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PublicDemo01PlaceholderScreen()));
    expect(find.text('4月'), findsOneWidget);

    // April: advance without winning an order. The demo must still recover into May.
    await tester.tap(find.text('4月終了→5月'));
    await tester.pumpAndSettle();
    expect(find.text('5月'), findsOneWidget);

    // May: advance without hiring. This is a valid failure/recovery route.
    await tester.tap(find.text('5月終了→6月'));
    await tester.pumpAndSettle();
    expect(find.text('6月'), findsOneWidget);
    expect(find.text('参画案件'), findsOneWidget);

    // June: no assignments is valid; advance into July waiting state.
    await tester.tap(find.text('6月終了→7月'));
    await tester.pumpAndSettle();
    expect(find.text('7月'), findsOneWidget);
    expect(find.text('7月開始結果'), findsOneWidget);
    expect(find.textContaining('参画 0名 / 待機 2名'), findsOneWidget);
    expect(find.text('営業枠は4枠へリセットされました。'), findsOneWidget);
  });
}
