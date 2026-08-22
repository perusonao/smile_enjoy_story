import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/models/programming_language.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_growth.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_growth_result_card.dart';

PublicDemoMonthlyGrowth growth({
  required PublicDemoGrowthSource source,
  required int before,
  required int after,
  required int experienceDelta,
}) => PublicDemoMonthlyGrowth(
  engineerId: 'eng-01',
  source: source,
  primaryLanguage: ProgrammingLanguage.java,
  capabilityBefore: before,
  capabilityAfter: after,
  actualExperienceMonthsDelta: experienceDelta,
  industryExperienceMonthsDelta: 0,
);

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('growth result fits at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PublicDemoGrowthResultCard(
            engineerName: '佐藤 健',
            result: growth(
              source: PublicDemoGrowthSource.assignment,
              before: 78,
              after: 80,
              experienceDelta: 1,
            ),
          ),
        ),
      ));

      expect(find.text('Java 78 → 80  (+2)'), findsOneWidget);
      expect(find.text('実務経験 +1か月'), findsOneWidget);
      expect(find.text('案件参画を通じて成長'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('waiting zero-delta result never claims practical experience',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PublicDemoGrowthResultCard(
          engineerName: '佐藤 健',
          result: growth(
            source: PublicDemoGrowthSource.waiting,
            before: 78,
            after: 78,
            experienceDelta: 0,
          ),
        ),
      ),
    ));

    expect(find.text('Java 78 → 78  (+0)'), findsOneWidget);
    expect(find.text('待機中の自己学習'), findsOneWidget);
    expect(find.text('今月は大きな変化なし'), findsOneWidget);
    expect(find.textContaining('実務経験'), findsNothing);
    expect(find.textContaining('業界経験'), findsNothing);
  });
}
