import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_offer_result_dialog.dart';

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets(
      'offer result dialog fits at ${width.toInt()}px (accepted)',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const PublicDemoOfferResultDialog(
                        applicantName: '山本 智子',
                        portraitAssetPath: null,
                        accepted: true,
                        offeredMonthlySalary: 310000,
                        reason: '希望給与を上回る条件で入社',
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

        expect(find.text('内定承諾'), findsOneWidget);
        expect(find.text('山本 智子'), findsOneWidget);
        expect(find.text('提示給与 ¥310,000'), findsOneWidget);
        expect(find.text('希望給与を上回る条件で入社'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'offer result dialog fits at ${width.toInt()}px (declined)',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const PublicDemoOfferResultDialog(
                        applicantName: '山本 智子',
                        portraitAssetPath: null,
                        accepted: false,
                        offeredMonthlySalary: 230000,
                        reason: '希望給与を下回る条件で入社',
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

        expect(find.text('内定辞退'), findsOneWidget);
        expect(find.text('提示給与 ¥230,000'), findsOneWidget);
        expect(find.text('希望給与を下回る条件で入社'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const Key('public-demo-offer-result-close')),
        );
        await tester.pumpAndSettle();
        expect(find.text('内定辞退'), findsNothing);
      },
    );
  }
}
