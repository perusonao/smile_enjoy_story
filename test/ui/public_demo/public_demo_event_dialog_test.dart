import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_event_dialog.dart';

void main() {
  testWidgets('recruitment application event explains what happened and next action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const PublicDemoEventDialog(
                    title: '新しい応募が届きました',
                    imageAsset: AssetPaths.eventRecruitmentApplication,
                    imageKey: Key('public-demo-recruitment-application-image'),
                    message: '採用候補者から応募が届いています。',
                    nextAction: '候補者の経歴書を確認しましょう。',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('新しい応募が届きました'), findsOneWidget);
    expect(find.byKey(const Key('public-demo-recruitment-application-image')), findsOneWidget);
    expect(find.text('採用候補者から応募が届いています。'), findsOneWidget);
    expect(find.text('候補者の経歴書を確認しましょう。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '確認'));
    await tester.pumpAndSettle();
    expect(find.text('新しい応募が届きました'), findsNothing);
  });
}
