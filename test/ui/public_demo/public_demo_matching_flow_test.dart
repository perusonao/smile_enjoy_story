import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_matching_project_card.dart';

import 'public_demo_tab_test_helpers.dart';

/// SES CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): end-to-end
/// coverage for the required player flow --
/// "案件を見る → 社員を選ぶ → スキルシートを見る → 強み/不足を見る →
/// 提案する/見送る → Phase 6案件面談へ渡す" -- reached from the 営業タブ's
/// new entry point. See
/// `docs/reports/SES_CORE-GAMEPLAY_Phase5_Matching_Result.md`.
class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

PublicDemoWorkflowState currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

Future<void> pumpSalesTab(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        key: UniqueKey(),
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
}

void main() {
  const runSeed = 20260908;

  testWidgets(
    '案件を見る → 社員を選ぶ → スキルシートを見る → 強み/不足を見る → 提案する '
    'で提案が記録される',
    (tester) async {
      final aggregate = PublicDemoAggregate.initial(runSeed: runSeed);
      final expectedFirstProject = aggregate.projectCandidatesForMonth(4).first;

      await pumpSalesTab(tester, aggregate);

      // Step 1: 案件を見る
      expect(
        find.byKey(const Key('public-demo-matching-open-project-list')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('public-demo-matching-open-project-list-tap')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public-demo-matching-project-list-sheet')),
        findsOneWidget,
      );
      expect(find.byType(PublicDemoMatchingProjectCard), findsWidgets);
      expect(find.textContaining(expectedFirstProject.title), findsWidgets);

      await tester.tap(find.byType(PublicDemoMatchingProjectCard).first);
      await tester.pumpAndSettle();

      // Step 2: 社員を選ぶ
      expect(
        find.byKey(const Key('public-demo-matching-engineer-select-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('public-demo-matching-engineer-row-eng-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('public-demo-matching-engineer-row-eng-02')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('public-demo-matching-engineer-row-eng-01')),
      );
      await tester.pumpAndSettle();

      // Step 3: 強み/不足を見る (decision sheet)
      expect(
        find.byKey(const Key('public-demo-matching-decision-sheet-eng-01')),
        findsOneWidget,
      );
      expect(find.textContaining('面接通過見込み'), findsOneWidget);

      // Step 3b: スキルシートを見る (Phase 4.5 authority reuse)
      await tester.tap(
        find.byKey(
          const Key('public-demo-matching-view-skill-sheet-eng-01'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('public-demo-skill-sheet-eng-01')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('public-demo-skill-sheet-cancel-eng-01')),
      );
      await tester.pumpAndSettle();

      // Back on the decision sheet, unchanged.
      expect(
        find.byKey(const Key('public-demo-matching-decision-sheet-eng-01')),
        findsOneWidget,
      );
      expect(currentWorkflow(tester).matchingProposals['eng-01'], isNull);

      // Step 4: 提案する
      await tester.tap(
        find.byKey(const Key('public-demo-matching-propose-eng-01')),
      );
      await tester.pumpAndSettle();

      final proposal = currentWorkflow(tester).matchingProposals['eng-01'];
      expect(proposal, isNotNull);
      expect(proposal!.projectId, expectedFirstProject.id);
      expect(proposal.decidedMonth, 4);

      // The existing, unmodified sales-pipeline stage is untouched by a
      // matching proposal.
      expect(
        currentWorkflow(tester).engineers
            .firstWhere((e) => e.id == 'eng-01')
            .stage,
        PublicDemoSalesStage.waiting,
      );
    },
  );

  testWidgets('見送る では提案が記録されない', (tester) async {
    final aggregate = PublicDemoAggregate.initial(runSeed: runSeed);
    await pumpSalesTab(tester, aggregate);

    await tester.tap(
      find.byKey(const Key('public-demo-matching-open-project-list-tap')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PublicDemoMatchingProjectCard).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('public-demo-matching-engineer-row-eng-02')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('public-demo-matching-skip-eng-02')),
    );
    await tester.pumpAndSettle();

    expect(currentWorkflow(tester).matchingProposals['eng-02'], isNull);
    expect(
      find.byKey(const Key('public-demo-matching-decision-sheet-eng-02')),
      findsNothing,
    );
  });

  testWidgets(
    'deterministic: reopening 案件を見る for the same save shows the same '
    'project list content',
    (tester) async {
      final aggregate = PublicDemoAggregate.initial(runSeed: runSeed);
      await pumpSalesTab(tester, aggregate);

      Future<List<String>> openAndReadTitles() async {
        await tester.tap(
          find.byKey(const Key('public-demo-matching-open-project-list-tap')),
        );
        await tester.pumpAndSettle();
        final titles = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(PublicDemoMatchingProjectCard),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data ?? '')
            .toList();
        await tester.tapAt(const Offset(20, 20)); // dismiss via barrier
        await tester.pumpAndSettle();
        return titles;
      }

      final first = await openAndReadTitles();
      final second = await openAndReadTitles();

      expect(second, first);
    },
  );

  group('360x800 / 390x844, TextScaler 1.0 / 1.3 / 2.0: matching flow has no '
      'horizontal overflow', () {
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
                  child: PublicDemo01PlaceholderScreen(
                    key: UniqueKey(),
                    saveService: _FixedSaveService(
                      PublicDemoAggregate.initial(runSeed: runSeed),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await switchPublicDemoTab(tester, PublicDemoTab.sales);
            expect(tester.takeException(), isNull);

            final openProjectListFinder = find.byKey(
              const Key('public-demo-matching-open-project-list-tap'),
            );
            await tester.ensureVisible(openProjectListFinder);
            await tester.pumpAndSettle();
            await tester.tap(openProjectListFinder);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            await tester.tap(find.byType(PublicDemoMatchingProjectCard).first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            await tester.tap(
              find.byKey(
                const Key('public-demo-matching-engineer-row-eng-01'),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
