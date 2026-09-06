import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_founder_follow_up.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_founder_follow_up_dialog.dart';

void main() {
  const engineer = PublicDemoEngineerSales(
    id: 'eng-01',
    name: '佐藤 健',
    summary: 'Java / SQL・開発経験3年',
    interviewProfile: PublicDemoInterviewProfile(
      skillFit: 78,
      humanity: 70,
      morale: 72,
      clientTrust: 60,
    ),
  );

  testWidgets('presents all three choices and returns the tapped decision', (
    tester,
  ) async {
    PublicDemoFounderFollowUpDecision? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<PublicDemoFounderFollowUpDecision>(
                  context: context,
                  builder: (context) => const PublicDemoFounderFollowUpDialog(
                    engineer: engineer,
                    canAffordInvestSupport: true,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('そのまま任せる'), findsOneWidget);
    expect(find.text('声をかける'), findsOneWidget);
    expect(find.text('支援に投資する'), findsOneWidget);

    await tester.tap(find.text('声をかける'));
    await tester.pumpAndSettle();

    expect(result, PublicDemoFounderFollowUpDecision.checkIn);
  });

  testWidgets(
    'disables the paid choice when investSupport is unaffordable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PublicDemoFounderFollowUpDialog(
              engineer: engineer,
              canAffordInvestSupport: false,
            ),
          ),
        ),
      );

      final investButton = tester.widget<FilledButton>(
        find.byKey(
          const Key(
            'public-demo-founder-follow-up-investSupport',
          ),
        ),
      );
      expect(investButton.onPressed, isNull);

      final checkInButton = tester.widget<FilledButton>(
        find.byKey(const Key('public-demo-founder-follow-up-checkIn')),
      );
      expect(checkInButton.onPressed, isNotNull);

      expect(find.textContaining('資金不足のため選択できません'), findsOneWidget);
    },
  );
}
