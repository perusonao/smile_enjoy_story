import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/presentation/year_end/models/public_demo_year_end_display_data.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_year_end_result_card.dart';

class _RestoringSaveService extends PublicDemoSaveService {
  _RestoringSaveService(this.aggregate);

  PublicDemoAggregate? aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {
    this.aggregate = aggregate;
  }

  @override
  Future<bool> clear() async {
    aggregate = null;
    return true;
  }
}

PublicDemoAggregate _terminalAggregate({required bool success}) {
  final json = PublicDemoAggregate.initial().toJson();
  final state = (json['state'] as Map<String, dynamic>);
  state.addAll({
    'month': 15,
    'cash': success ? 1234567 : -300000,
    'engineersAssigned': 0,
    'engineersWaiting': 2,
    'pendingRevenue': 450000,
    'fiscalYearCompleted': success,
    'financialStatus': success
        ? PublicDemoFinancialStatus.normal.name
        : PublicDemoFinancialStatus.marchCashShortageFailure.name,
    'summerBonusSelection': 'half',
    'summerBonusDecisionConfirmed': true,
    'summerBonusPaid': true,
    'summerBonusPaidMonth': 7,
    'summerBonusPaidAmount': 200000,
    'latestMonthlyCashFlow': {
      'month': 15,
      'openingCash': success ? 1084567 : 500000,
      'cashReceived': 450000,
      'salaryPaid': 600000,
      'fixedCostsPaid': 200000,
      'bonusPaid': 0,
      'trainingCost': 0,
      'recruitmentCost': 0,
      'closingCash': success ? 1234567 : -300000,
      'revenue': 450000,
      'receivables': 450000,
    },
  });
  return PublicDemoAggregate.fromJson(json);
}

Future<void> _mountResult(
  WidgetTester tester,
  PublicDemoYearEndDisplayData data, {
  Size size = const Size(360, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PublicDemoYearEndResultCard(data: data, onRestart: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'successful completion shows truthful Year-End facts and replay CTA at 360x800',
    (tester) async {
      final data = PublicDemoYearEndDisplayData.fromState(
        _terminalAggregate(success: true).state,
      );

      await _mountResult(tester, data);

      expect(find.text('年度終了'), findsOneWidget);
      expect(find.text('第1期終了'), findsOneWidget);
      expect(find.text('¥1,234,567'), findsWidgets);
      expect(find.text('参画 0名 / 待機 2名'), findsOneWidget);
      expect(find.text('入社 0名'), findsOneWidget);
      expect(find.text('¥450,000'), findsWidgets);
      expect(find.text('0.5か月（支給済み）'), findsOneWidget);
      expect(find.text('3月の経営結果'), findsOneWidget);
      expect(
        find.byKey(const Key('public-demo-restart-button')),
        findsOneWidget,
      );
      expect(find.text('もう一度プレイする'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final unsupported in [
        '年間売上',
        '年間利益',
        '年間総経費',
        '会社信頼度',
        '初受注月',
        '初採用月',
      ]) {
        expect(
          find.textContaining(unsupported),
          findsNothing,
          reason: '$unsupported is not derivable from the retained state',
        );
      }
    },
  );

  testWidgets('successful fiscal completion restores into the full screen '
      'with one primary replay CTA', (tester) async {
    final aggregate = _terminalAggregate(success: true);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicDemo01PlaceholderScreen(
          saveService: _RestoringSaveService(aggregate),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('public-demo-fiscal-year-complete')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('public-demo-year-end-result')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('public-demo-restart-button')), findsOneWidget);
    expect(
      find.byKey(const Key('public-demo-restart-april-button')),
      findsNothing,
      reason: 'terminal result keeps one clear primary CTA',
    );
  });

  testWidgets('March cash-shortage failure uses the Year-End result layout '
      'without changing terminal semantics at 390x800', (tester) async {
    final aggregate = _terminalAggregate(success: false);
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PublicDemo01PlaceholderScreen(
          saveService: _RestoringSaveService(aggregate),
        ),
      ),
    );
    await tester.pump();

    expect(
      aggregate.state.financialStatus,
      PublicDemoFinancialStatus.marchCashShortageFailure,
    );
    expect(aggregate.state.fiscalYearCompleted, isFalse);
    expect(aggregate.state.isCloseBlocked, isTrue);
    expect(
      find.byKey(const Key('public-demo-bankruptcy-card')),
      findsOneWidget,
    );
    expect(find.text('経営終了'), findsOneWidget);
    expect(find.text('3月資金不足'), findsOneWidget);
    expect(find.text('-¥300,000'), findsWidgets);
    expect(find.textContaining('資金不足で終了しました'), findsOneWidget);
    expect(find.text('第1期終了'), findsNothing);
    expect(find.text('3月を終了して第1期を完了'), findsNothing);
    expect(find.byKey(const Key('public-demo-restart-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
