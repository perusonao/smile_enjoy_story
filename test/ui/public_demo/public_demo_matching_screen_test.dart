// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): widget coverage for
// the 案件を見る → 社員を選ぶ → スキルシートを見る → 強み/不足を見る →
// 提案する/見送る flow, reached from a new, always-visible 営業タブ section.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import 'public_demo_tab_test_helpers.dart';

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

Future<void> pumpSalesTabAt(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
}

void main() {
  testWidgets(
    '営業タブに常時表示の「案件マッチング」セクションから「案件を見る」で '
    'PublicDemoProjectMatchingScreen を開ける',
    (tester) async {
      await pumpSalesTabAt(tester, PublicDemoAggregate.initial());

      expect(find.text('案件マッチング'), findsOneWidget);
      await tester.tap(find.byKey(const Key('public-demo-open-project-matching')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public-demo-project-matching-screen')),
        findsOneWidget,
      );
      // April's Balance-Guard-eligible slot 0 is always present.
      expect(find.textContaining('月額'), findsWidgets);
    },
  );

  testWidgets(
    '案件を選ぶと社員一覧が開き、両方の創業社員が検討可能に表示される',
    (tester) async {
      await pumpSalesTabAt(tester, PublicDemoAggregate.initial());
      await tester.tap(find.byKey(const Key('public-demo-open-project-matching')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('public-demo-project-matching-card-project-4-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public-demo-matching-engineer-screen')),
        findsOneWidget,
      );
      expect(find.text('佐藤 健'), findsOneWidget);
      expect(find.text('鈴木 葵'), findsOneWidget);
    },
  );

  testWidgets(
    '社員を選ぶと強み/不足と面談通過見込みが展開し、スキルシートを確認でき、'
    '提案すると提案済みになる',
    (tester) async {
      await pumpSalesTabAt(tester, PublicDemoAggregate.initial());
      await tester.tap(find.byKey(const Key('public-demo-open-project-matching')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('public-demo-project-matching-card-project-4-1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('佐藤 健'));
      await tester.pumpAndSettle();

      expect(find.text('面談通過見込み'), findsOneWidget);
      expect(
        find.byKey(const Key('public-demo-match-decision-eng-01')),
        findsOneWidget,
      );

      // Never a raw score/percentage anywhere in the decision panel.
      expect(find.textContaining('%'), findsNothing);

      // スキルシートを見る reuses the existing, already-tested SkillSheet
      // sheet — this only checks it actually opens.
      await tester.tap(
        find.byKey(const Key('public-demo-matching-view-skillsheet-eng-01')),
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

      await tester.tap(
        find.byKey(const Key('public-demo-matching-propose-eng-01')),
      );
      await tester.pumpAndSettle();

      expect(find.text('提案済み'), findsOneWidget);
      final proposeButton = tester.widget<FilledButton>(
        find.byKey(const Key('public-demo-matching-propose-eng-01')),
      );
      expect(proposeButton.onPressed, isNull);
    },
  );

  testWidgets('見送るは状態を変更せず、パネルを閉じるだけ', (tester) async {
    await pumpSalesTabAt(tester, PublicDemoAggregate.initial());
    await tester.tap(find.byKey(const Key('public-demo-open-project-matching')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('public-demo-project-matching-card-project-4-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('佐藤 健'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('public-demo-matching-pass-eng-01')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('public-demo-match-decision-eng-01')),
      findsNothing,
    );
  });
}
