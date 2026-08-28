import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/widgets/game_event_modal.dart';

void main() {
  Widget host({
    required Widget dialog,
    Size size = const Size(390, 844),
    double textScaleFactor = 1,
  }) {
    return MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScaleFactor)),
      child: MaterialApp(home: Scaffold(body: Center(child: dialog))),
    );
  }

  testWidgets('renders required content and fires action exactly once', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      host(
        dialog: GameEventModal(
          title: 'イベントタイトル',
          actions: [
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => calls++,
                child: const Text('確認'),
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('イベントタイトル'), findsOneWidget);
    await tester.tap(find.text('確認'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('renders image, badge, description and info section', (tester) async {
    const imageKey = Key('event-image');

    await tester.pumpWidget(
      host(
        dialog: GameEventModal(
          imageAsset: 'assets/does-not-exist.jpg',
          imageKey: imageKey,
          category: '採用・応募',
          title: '新しい応募が届きました',
          description: '採用候補者から応募が届いています。',
          infoSection: const Text('次の行動'),
          actions: const [SizedBox(height: 52, child: FilledButton(onPressed: null, child: Text('確認')))],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(imageKey), findsOneWidget);
    expect(find.text('採用・応募'), findsOneWidget);
    expect(find.text('新しい応募が届きました'), findsOneWidget);
    expect(find.text('採用候補者から応募が届いています。'), findsOneWidget);
    expect(find.text('次の行動'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
  });

  testWidgets('long Japanese title wraps without ellipsis', (tester) async {
    const longTitle = '夏季賞与の支給についてご確認ください社員全員分の賞与についての重要なお知らせ';

    await tester.pumpWidget(
      host(
        size: const Size(360, 800),
        dialog: GameEventModal(
          title: longTitle,
          description: '説明文です。',
          actions: const [SizedBox(height: 52, child: FilledButton(onPressed: null, child: Text('確認')))],
        ),
      ),
    );

    final title = tester.widget<Text>(find.text(longTitle));
    expect(title.maxLines, isNull);
    expect(title.overflow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('three actions stay reachable at 360x800 with large text', (tester) async {
    await tester.pumpWidget(
      host(
        size: const Size(360, 800),
        textScaleFactor: 2,
        dialog: GameEventModal(
          title: '長いイベントタイトルです長いイベントタイトルです',
          description: List.filled(20, '長い説明文です。').join(),
          infoSection: const Text('判断に必要な追加情報です。'),
          actions: const [
            SizedBox(height: 52, child: FilledButton(onPressed: null, child: Text('選択肢1'))),
            SizedBox(height: 52, child: FilledButton(onPressed: null, child: Text('選択肢2'))),
            SizedBox(height: 52, child: FilledButton(onPressed: null, child: Text('選択肢3'))),
          ],
        ),
      ),
    );

    expect(find.text('選択肢1'), findsOneWidget);
    expect(find.text('選択肢2'), findsOneWidget);
    expect(find.text('選択肢3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
