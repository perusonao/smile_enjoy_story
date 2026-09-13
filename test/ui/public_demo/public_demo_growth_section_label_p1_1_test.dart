// SES First Fun Quarter AI Replay Audit #2 P1-1 Fresh Audit fix.
//
// Repro: in May, selecting internal training for an engineer left the
// training card correctly confirming "今月は社内研修", while the growth
// section directly above it -- headed "今月の成長" -- still showed a flat
// 52->52 (+0) "今月は大きな変化なし" result for that same engineer. Both
// numbers were individually true (they were April's real, already-closed
// result), but the "今月の成長" heading made them read as a live preview of
// the training just selected that had failed to update. The real growth for
// the selected training only lands at the next month's close.
//
// Root cause (see `_growthResultsSection`'s own doc in
// public_demo_01_placeholder_screen.dart): `PublicDemoState
// .latestGrowthResults` is only ever written by `applyMonthlyGrowth` at the
// PRIOR month's close, so this section always describes last month, never
// the month in progress -- a labeling bug, not a stale-computation one. The
// fix renames the heading (and the individual result card's own "今月は"
// line) to plainly describe a past, closed result -- no change to
// `PublicDemoGrowthEngine`/`applyMonthlyGrowth`/`PublicDemoMonthlyGrowth`
// (training effect values and the save schema are untouched) and no new UI
// authority.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

const _expense = 800000;

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

Future<void> _pumpScreen(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'training未選択: May, before any training is selected, the growth '
    'section already reads as a past result (先月の成長結果), never 今月の成長',
    (tester) async {
      final aggregate = PublicDemoAggregate.initial(
        runSeed: 1,
      ).closeApril(monthlyExpenses: _expense);
      await _pumpScreen(tester, aggregate);
      await switchPublicDemoTab(tester, PublicDemoTab.employees);

      expect(find.text('先月の成長結果'), findsOneWidget);
      expect(find.text('今月の成長'), findsNothing);
      // April's own flat (待機/自己学習) result never mislabels itself as
      // describing the month in progress either.
      expect(find.text('大きな変化はありませんでした'), findsWidgets);
      expect(find.text('今月は大きな変化なし'), findsNothing);
    },
  );

  testWidgets(
    'training選択直後: selecting 社内研修 for an engineer does not change the '
    "previous month's already-shown result, and no card anywhere claims a "
    'live/updated growth number for the just-made selection',
    (tester) async {
      final aggregate = PublicDemoAggregate.initial(
        runSeed: 1,
      ).closeApril(monthlyExpenses: _expense);
      final engineerId = aggregate.workflow.engineers.first.id;
      await _pumpScreen(tester, aggregate);
      await switchPublicDemoTab(tester, PublicDemoTab.employees);

      final before = find.text('先月の成長結果');
      expect(before, findsOneWidget);

      final trainingButton = find.byKey(
        Key('public-demo-internal-training-action-$engineerId'),
      );
      await tester.scrollUntilVisible(
        trainingButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(trainingButton);
      await tester.pumpAndSettle();
      await tester.tap(trainingButton);
      await tester.pumpAndSettle();

      // The training card confirms the selection...
      expect(find.textContaining('今月は社内研修'), findsOneWidget);
      // ...while the growth section above it is untouched: same heading,
      // still describing last month, never a re-labeled "current" claim.
      expect(find.text('先月の成長結果'), findsOneWidget);
      expect(find.text('今月の成長'), findsNothing);
    },
  );

  testWidgets(
    'month close後: after May closes with 社内研修 selected, the section '
    "shows May's real result for that engineer under the same past-tense "
    'heading -- the number itself was always real, only the framing changed',
    (tester) async {
      var aggregate = PublicDemoAggregate.initial(
        runSeed: 1,
      ).closeApril(monthlyExpenses: _expense);
      final engineerId = aggregate.workflow.engineers.first.id;
      await _pumpScreen(tester, aggregate);
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      final trainingButton = find.byKey(
        Key('public-demo-internal-training-action-$engineerId'),
      );
      await tester.scrollUntilVisible(
        trainingButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(trainingButton);
      await tester.pumpAndSettle();
      await tester.tap(trainingButton);
      await tester.pumpAndSettle();

      await switchPublicDemoTab(tester, PublicDemoTab.home);
      final closeButton = find.widgetWithText(FilledButton, '5月を終了して6月へ');
      await tester.scrollUntilVisible(
        closeButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(closeButton);
      await tester.pumpAndSettle();
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      await dismissMonthGuardIfPresent(tester);
      await dismissMonthlyReportIfPresent(tester);

      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(find.text('先月の成長結果'), findsOneWidget);
      expect(find.text('今月の成長'), findsNothing);
      expect(find.text('社内研修を通じて成長'), findsOneWidget);
    },
  );

  testWidgets(
    'assignment由来growthとの混同なし (Audit #2 P2-6): an engineer whose last '
    "closed month's growth came from a project assignment is never mislabeled "
    "社内研修 -- PublicDemoMonthlyGrowth.source is read verbatim, and the "
    'heading fix removes the only misreading risk (mistaking a past-month '
    "record for the engineer's current status)",
    (tester) async {
      var aggregate = PublicDemoAggregate.initial(
        runSeed: 1,
      ).closeApril(monthlyExpenses: _expense);
      // 佐藤健 (runSeed 1's first founding engineer) deterministically clears
      // both real interviews at his fixed starting capability -- the same
      // fact `public_demo_offer_result_feedback_test.dart`'s own fixture
      // relies on -- so this drives him to a genuine `ordered` assignment
      // before May closes through the real, sanctioned commands his own
      // ec(i) buttons use, never a fabricated stage.
      final engineer = aggregate.workflow.engineers.first;
      aggregate = aggregate.startSkillSheetReview(engineer.id);
      aggregate = aggregate.beginSelling(engineer.id);
      aggregate = aggregate.introduceProject(engineer.id);
      aggregate = aggregate.recordEngineerInterviewResult(
        engineerId: engineer.id,
        type: PublicDemoInterviewType.partner,
      );
      aggregate = aggregate.recordEngineerInterviewResult(
        engineerId: engineer.id,
        type: PublicDemoInterviewType.client,
      );
      aggregate = aggregate.recordOrder(engineer.id);
      final ordered = aggregate.workflow.engineers.firstWhere(
        (e) => e.id == engineer.id,
      );
      expect(
        ordered.stage,
        PublicDemoSalesStage.ordered,
        reason: 'fixture sanity',
      );

      await _pumpScreen(tester, aggregate);
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      final closeButton = find.widgetWithText(FilledButton, '5月を終了して6月へ');
      await tester.scrollUntilVisible(
        closeButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(closeButton);
      await tester.pumpAndSettle();
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      await dismissMonthGuardIfPresent(tester);
      await dismissMonthlyReportIfPresent(tester);

      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(find.text('先月の成長結果'), findsOneWidget);
      expect(find.text('案件参画を通じて成長'), findsOneWidget);
      expect(find.text('社内研修を通じて成長'), findsNothing);
    },
  );
}
