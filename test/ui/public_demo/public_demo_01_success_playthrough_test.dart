import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('successful route reaches July with an active engineer', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PublicDemo01PlaceholderScreen()));

    // April: Sato wins the May order.
    await tapAndSettle(tester, 'SkillSheet確認');
    await tapAndSettle(tester, '営業開始');
    await tapAndSettle(tester, '案件紹介');
    await tapAndSettle(tester, '上位会社面談');
    // UX-2A also renders "客先面談" in progress indicators, so the action
    // label is no longer expected to be globally unique.
    expect(find.text('客先面談'), findsWidgets);
    await tapAndSettle(tester, '客先面談');
    await tapAndSettle(tester, '受注');
    await tapAndSettle(tester, '4月終了→5月');
    expect(find.text('5月'), findsOneWidget);

    // May: Takahashi is hired and wins a June order before joining.
    await tapAndSettle(tester, '経歴書確認');
    await tapAndSettle(tester, '採用面談');
    expect(find.textContaining('評価 74'), findsOneWidget);
    await tapAndSettle(tester, '合格・内定');
    await tapAndSettle(tester, '入社前SkillSheet');
    await tapAndSettle(tester, '入社前営業');
    await tapAndSettle(tester, '案件紹介');
    await tapAndSettle(tester, '上位会社面談');
    await tapAndSettle(tester, '客先面談');
    await tapAndSettle(tester, '6月受注');
    await tapAndSettle(tester, '5月終了→6月');
    expect(find.text('6月'), findsOneWidget);
    expect(find.text('参画'), findsOneWidget);
    expect(find.text('2名'), findsOneWidget);

    // June: accept at least one July continuation.
    await tapAndSettle(tester, '7月分の発注を確認');
    if (find.text('7月分発注あり').evaluate().isNotEmpty) {
      await tapAndSettle(tester, '受注する');
    }
    await tapAndSettle(tester, '6月終了→7月');

    expect(find.text('7月'), findsOneWidget);
    expect(find.text('7月開始結果'), findsOneWidget);
    expect(find.textContaining('参画 1名'), findsOneWidget);
  });
}
