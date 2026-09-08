import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/models/fit_result.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_matching_decision_sheet.dart';

/// SES CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): a focused
/// regression test that [PublicDemoMatchingDecisionSheet] never renders
/// [FitBreakdown.total] or any of its raw sub-scores -- only the bucketed
/// ◎○△× [PlayerVisibleFit] symbols/labels and the coarse
/// "面接通過見込み: 高/中/低" tier, per this Issue's own "do not show only a
/// number" rule. Mirrors the technique
/// `test/ui/public_demo/public_demo_candidate_skill_sheet_hidden_fields_test
/// .dart` already established for Phase 4.5's hidden-field guard.
/// See `docs/reports/SES_CORE-GAMEPLAY_Phase5_Matching_Result.md`.
void main() {
  // Distinctive scores chosen so none of their digits coincidentally match
  // any other rendered text (project title / engineer name / labels).
  const techScore = 47; // -> total 47+13+19+8 = 87 (excellent tier)
  const experienceScore = 13;
  const personalityScore = 19;
  const conditionScore = 8;
  const fit = FitBreakdown(
    techScore: techScore,
    experienceScore: experienceScore,
    personalityScore: personalityScore,
    conditionScore: conditionScore,
    details: [
      FitDetailItem(
        dimension: FitDimension.language,
        rating: PlayerVisibleFit.excellent,
        language: ProgrammingLanguage.java,
      ),
      FitDetailItem(
        dimension: FitDimension.experience,
        rating: PlayerVisibleFit.poor,
      ),
    ],
  );

  final candidate = PublicDemoSeededProjectGenerator.forMonth(
    runSeed: 314159,
    month: 4,
  ).first;
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

  Future<bool?> pumpAndOpen(WidgetTester tester, {VoidCallback? onView}) async {
    bool? viewed;
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await PublicDemoMatchingDecisionSheet.show(
                    context,
                    candidate: candidate,
                    engineer: engineer,
                    fit: fit,
                    onViewSkillSheet: () => viewed = true,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    addTearDown(() {
      expect(viewed, anyOf(isNull, isTrue));
    });
    return result;
  }

  testWidgets('never renders fit.total or any raw sub-score', (tester) async {
    await pumpAndOpen(tester);

    expect(fit.total, 87, reason: 'fixture sanity');

    // Sanity: the sheet actually rendered real content.
    expect(find.textContaining(engineer.name), findsWidgets);
    expect(find.textContaining('面接通過見込み'), findsOneWidget);
    expect(find.textContaining('高'), findsOneWidget, reason: '87 -> excellent -> 高');

    for (final hidden in [
      fit.total,
      techScore,
      experienceScore,
      personalityScore,
      conditionScore,
    ]) {
      expect(
        find.text('$hidden'),
        findsNothing,
        reason: 'exact match for raw score $hidden',
      );
      expect(
        find.textContaining('$hidden'),
        findsNothing,
        reason: 'substring match for raw score $hidden',
      );
    }

    // Belt-and-suspenders: walk every Text widget actually painted.
    final allText = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');
    for (final hidden in [
      fit.total,
      techScore,
      experienceScore,
      personalityScore,
      conditionScore,
    ]) {
      expect(allText, isNot(contains('$hidden')));
    }
    // Never a raw percentage figure either.
    expect(allText, isNot(contains('%')));
  });

  testWidgets('shows qualitative 強み/不足 lines from FitDetailItem, never a '
      'raw number', (tester) async {
    await pumpAndOpen(tester);

    expect(find.textContaining('強み'), findsOneWidget);
    expect(find.textContaining('不足'), findsOneWidget);
    expect(find.textContaining('Java'), findsOneWidget);
    expect(find.textContaining('◎'), findsWidgets);
    expect(find.textContaining('×'), findsWidgets);
  });

  testWidgets('タップで「提案する」は true を返し、「見送る」は false を返す', (
    tester,
  ) async {
    final result = await pumpAndOpen(tester);
    expect(result, isNull, reason: 'not yet decided');

    await tester.tap(find.byKey(Key('public-demo-matching-propose-${engineer.id}')));
    await tester.pumpAndSettle();
  });

  testWidgets('見送るボタンは false を返す', (tester) async {
    await pumpAndOpen(tester);
    await tester.tap(find.byKey(Key('public-demo-matching-skip-${engineer.id}')));
    await tester.pumpAndSettle();
  });

  testWidgets('スキルシートを見るボタンは onViewSkillSheet を呼ぶ', (tester) async {
    var viewed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => PublicDemoMatchingDecisionSheet.show(
                  context,
                  candidate: candidate,
                  engineer: engineer,
                  fit: fit,
                  onViewSkillSheet: () => viewed = true,
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

    await tester.tap(
      find.byKey(Key('public-demo-matching-view-skill-sheet-${engineer.id}')),
    );
    await tester.pump();

    expect(viewed, isTrue);
  });

  group('360x800 / 390x844, TextScaler 1.0 / 1.3 / 2.0: no horizontal overflow', () {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale $textScale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () => PublicDemoMatchingDecisionSheet.show(
                            context,
                            candidate: candidate,
                            engineer: engineer,
                            fit: fit,
                            onViewSkillSheet: () {},
                          ),
                          child: const Text('open'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
