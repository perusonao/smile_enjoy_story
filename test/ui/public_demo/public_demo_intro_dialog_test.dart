import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_intro_dialog.dart';

void main() {
  Future<void> pumpIntroDialog(WidgetTester tester, {Size? surfaceSize}) async {
    if (surfaceSize != null) {
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const PublicDemoIntroDialog(),
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
  }

  testWidgets(
    'states role, objective, time structure, failure condition, and first action',
    (tester) async {
      await pumpIntroDialog(tester);

      expect(find.byKey(const Key('public-demo-intro-dialog')), findsOneWidget);
      expect(find.text('ようこそ、S.E.S.へ'), findsOneWidget);
      expect(find.textContaining('あなたはこの会社の社長です'), findsOneWidget);
      expect(find.textContaining('4月に創業し'), findsOneWidget);
      expect(find.textContaining('倒産してプレイは終了します'), findsOneWidget);
      expect(find.textContaining('「次にやること」カード'), findsOneWidget);
    },
  );

  testWidgets('confirm button closes the dialog', (tester) async {
    await pumpIntroDialog(tester);

    await tester.tap(find.byKey(const Key('public-demo-intro-dialog-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public-demo-intro-dialog')), findsNothing);
    expect(find.text('ようこそ、S.E.S.へ'), findsNothing);
  });

  testWidgets('does not overflow at a 360x800 surface', (tester) async {
    await pumpIntroDialog(tester, surfaceSize: const Size(360, 800));

    expect(tester.takeException(), isNull);
  });
}
