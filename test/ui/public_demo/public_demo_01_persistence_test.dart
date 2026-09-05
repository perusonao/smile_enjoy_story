import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/app_experience.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/persistence/save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

class _RecordingSaveService extends PublicDemoSaveService {
  _RecordingSaveService({this.restored, this.clearResult = true});

  PublicDemoAggregate? restored;
  bool clearResult;
  final saved = <PublicDemoAggregate>[];
  var clearCalls = 0;

  @override
  Future<PublicDemoAggregate?> load() async => restored;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {
    saved.add(aggregate);
    restored = aggregate;
  }

  @override
  Future<bool> clear() async {
    clearCalls++;
    if (clearResult) restored = null;
    return clearResult;
  }
}

class _DelayedSaveService extends _RecordingSaveService {
  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  var saveCalls = 0;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {
    saveCalls++;
    if (saveCalls == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    await super.save(aggregate);
  }
}

PublicDemoState _screenState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

PublicDemoWorkflowState _screenWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

Future<void> _mount(WidgetTester tester, PublicDemoSaveService service) async {
  await tester.pumpWidget(
    MaterialApp(home: PublicDemo01PlaceholderScreen(saveService: service)),
  );
  await tester.pump();
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  final finder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pump();
  if (label == 'SkillSheet確認') {
    // SKILLSHEET-UX-2A Phase A: the SkillSheet presentation is now a
    // showModalBottomSheet (slide-in entrance transition) rather than the
    // #117 AlertDialog (scale/fade transition). A single bare `pump()`
    // after opening it left the confirm button's on-screen position
    // mid-animation, off the visible sheet; settle the entrance transition
    // before locating/tapping it. No assertion below changed.
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
}

/// SES-FIRST-FUN-YEAR-UI-PHASE-2: the test-only restart control now lives
/// inside the bottom "開発・テストメニュー" fold, closed by default so it never
/// reads as part of the normal monthly game flow. Opening that fold first is
/// the only change here — the button itself, its key, and everything it
/// does are unchanged.
Future<void> _openAprilRestart(WidgetTester tester) async {
  // The dev/test menu (and its restart control) is its own メニュー tab now
  // (PUBLIC-DEMO-HOME-UI-3B), not a scroll-reachable fold at the bottom of
  // HOME's own list.
  await switchPublicDemoTab(tester, PublicDemoTab.menu);
  final toggle = find.byKey(const Key('public-demo-dev-menu-toggle'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  final button = find.byKey(const Key('public-demo-restart-april-button'));
  if (button.evaluate().isEmpty) {
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

PublicDemoAggregate _bankruptAggregate() {
  var aggregate = PublicDemoAggregate.initial()
      .closeApril(monthlyExpenses: 800000)
      .closeMay(week: 9, monthlyExpenses: 800000);
  aggregate = aggregate
      .recruit(PublicDemoRecruitmentMedium.free)
      .aggregate!
      .closeJune(assignedInJuly: 0, monthlyExpenses: 800000)
      .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none)
      .closeJuly(monthlyExpenses: 800000);
  for (var i = 0; i < 3; i++) {
    aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 800000);
  }
  assert(
    aggregate.state.financialStatus == PublicDemoFinancialStatus.bankruptcy,
  );
  return aggregate;
}

PublicDemoAggregate _freshJulyAggregate() => PublicDemoAggregate.initial()
    .closeApril(monthlyExpenses: 0)
    .closeMay(week: 9, monthlyExpenses: 0)
    .closeJune(assignedInJuly: 0, monthlyExpenses: 0);

Future<void> _confirmAndReloadWithoutBonusDialog(
  WidgetTester tester,
  PublicDemoSummerBonusPlan plan,
) async {
  final service = _RecordingSaveService(restored: _freshJulyAggregate());
  await _mount(tester, service);

  // The summer bonus decision card is finance detail — on 会計 now
  // (PUBLIC-DEMO-HOME-UI-3B).
  await switchPublicDemoTab(tester, PublicDemoTab.accounting);
  await _tapAction(tester, '夏季賞与を決める');
  await tester.tap(find.byKey(Key('public-demo-summer-bonus-${plan.name}')));
  await tester.pump();

  expect(_screenState(tester).summerBonusDecisionConfirmed, isTrue);
  expect(_screenState(tester).summerBonusSelection, plan);
  expect(service.saved.single.state.summerBonusDecisionConfirmed, isTrue);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await _mount(tester, service);

  expect(_screenState(tester).summerBonusDecisionConfirmed, isTrue);
  await _tapAction(tester, '7月を終了して8月へ');

  expect(
    find.byKey(Key('public-demo-summer-bonus-${plan.name}')),
    findsNothing,
  );
  expect(_screenState(tester).month, 8);
}

void main() {
  testWidgets('no save starts a fresh aggregate after the restore gate', (
    tester,
  ) async {
    final service = _RecordingSaveService();
    await tester.pumpWidget(
      MaterialApp(home: PublicDemo01PlaceholderScreen(saveService: service)),
    );

    expect(find.byKey(const Key('public-demo-restoring')), findsOneWidget);
    await tester.pump();

    expect(
      _screenState(tester).toJson(),
      PublicDemoAggregate.initial().state.toJson(),
    );
    expect(service.saved, isEmpty);
  });

  testWidgets('a valid aggregate restores wholesale without UI-local state', (
    tester,
  ) async {
    final aggregate = PublicDemoAggregate.initial().startSkillSheetReview(
      'eng-01',
    );
    final service = _RecordingSaveService(restored: aggregate);
    await _mount(tester, service);

    expect(_screenState(tester).toJson(), aggregate.state.toJson());
    expect(find.byKey(const Key('public-demo-restoring')), findsNothing);
    expect(service.saved, isEmpty);
  });

  testWidgets(
    'a confirmed non-none July bonus survives reload without reopening the dialog',
    (tester) => _confirmAndReloadWithoutBonusDialog(
      tester,
      PublicDemoSummerBonusPlan.one,
    ),
  );

  testWidgets(
    'a confirmed none July bonus survives reload without reopening the dialog',
    (tester) => _confirmAndReloadWithoutBonusDialog(
      tester,
      PublicDemoSummerBonusPlan.none,
    ),
  );

  testWidgets('a fresh July aggregate still opens the bonus dialog', (
    tester,
  ) async {
    await _mount(
      tester,
      _RecordingSaveService(restored: _freshJulyAggregate()),
    );

    await _tapAction(tester, '7月を終了して8月へ');

    expect(
      find.byKey(const Key('public-demo-summer-bonus-none')),
      findsOneWidget,
    );
  });

  testWidgets('corrupt and incompatible payloads both fall back safely', (
    tester,
  ) async {
    for (final raw in [
      '{broken',
      '{"schemaVersion":2,"experience":"public-demo-01","aggregate":{}}',
    ]) {
      SharedPreferences.setMockInitialValues({PublicDemoSaveService.key: raw});
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );
      await tester.pump();
      expect(
        _screenState(tester).toJson(),
        PublicDemoAggregate.initial().state.toJson(),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('each authoritative mutation queues its resulting aggregate', (
    tester,
  ) async {
    final service = _RecordingSaveService();
    await _mount(tester, service);

    // The employee sales-progression card is on 社員 now.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    await _tapAction(tester, 'SkillSheet確認');
    await tester.pump();

    expect(service.saved, hasLength(1));
    expect(service.saved.single.state.toJson(), _screenState(tester).toJson());
    final envelope = const PublicDemoSaveCodec().toJson(service.saved.single);
    expect(
      envelope.keys,
      containsAll(['schemaVersion', 'experience', 'aggregate']),
    );
    expect(envelope['aggregate'], isNot(contains('selectedTab')));
  });

  testWidgets('a delayed earlier save cannot overtake the later aggregate', (
    tester,
  ) async {
    final service = _DelayedSaveService();
    await _mount(tester, service);

    // The employee sales-progression card is on 社員 now.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    await _tapAction(tester, 'SkillSheet確認');
    await service.firstSaveStarted.future;
    await _tapAction(tester, '営業開始');
    expect(service.saveCalls, 1, reason: 'writes are serialized');

    service.releaseFirstSave.complete();
    await tester.pump();
    await tester.pump();

    expect(service.saved, hasLength(2));
    expect(service.saved.last.state.toJson(), _screenState(tester).toJson());
  });

  testWidgets(
    'restart clears Public Demo storage before creating a fresh run',
    (tester) async {
      final service = _RecordingSaveService(restored: _bankruptAggregate());
      await _mount(tester, service);

      await tester.tap(find.byKey(const Key('public-demo-restart-button')));
      await tester.pump();

      expect(service.clearCalls, 1);
      expect(service.restored, isNull);
      expect(_screenState(tester).summerBonusDecisionConfirmed, isFalse);
      expect(
        _screenState(tester).toJson(),
        PublicDemoAggregate.initial().state.toJson(),
      );
    },
  );

  testWidgets('a failed clear preserves the authoritative terminal session', (
    tester,
  ) async {
    final terminal = _bankruptAggregate();
    final service = _RecordingSaveService(
      restored: terminal,
      clearResult: false,
    );
    await _mount(tester, service);

    await tester.tap(find.byKey(const Key('public-demo-restart-button')));
    await tester.pump();

    expect(service.clearCalls, 1);
    expect(
      _screenState(tester).financialStatus,
      PublicDemoFinancialStatus.bankruptcy,
    );
    expect(service.restored, same(terminal));
    expect(find.text('保存データを削除できませんでした。現在のプレイを続けます。'), findsOneWidget);
  });

  testWidgets('test restart confirms from July and rebuilds the canonical '
      'April aggregate repeatedly', (tester) async {
    final service = _RecordingSaveService(restored: _freshJulyAggregate());
    final canonical = PublicDemoAggregate.initial();
    await _mount(tester, service);

    for (var attempt = 0; attempt < 2; attempt++) {
      await _openAprilRestart(tester);
      expect(
        find.byKey(const Key('public-demo-restart-april-dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('public-demo-restart-april-confirm')),
      );
      await tester.pumpAndSettle();

      expect(_screenState(tester).toJson(), canonical.state.toJson());
      expect(_screenWorkflow(tester).toJson(), canonical.workflow.toJson());
      expect(find.text('1年目 4月'), findsOneWidget);
      expect(find.text('SkillSheetを確認'), findsWidgets);
    }
    expect(service.clearCalls, 2);
  });

  testWidgets(
    'test restart cancellation leaves the current session unchanged',
    (tester) async {
      final current = _freshJulyAggregate();
      final service = _RecordingSaveService(restored: current);
      await _mount(tester, service);

      await _openAprilRestart(tester);
      await tester.tap(
        find.byKey(const Key('public-demo-restart-april-cancel')),
      );
      await tester.pumpAndSettle();

      expect(_screenState(tester).toJson(), current.state.toJson());
      expect(_screenWorkflow(tester).toJson(), current.workflow.toJson());
      expect(service.clearCalls, 0);
      // Cancelling never touches domain state, and it also never switches
      // tabs on its own — this confirms the 月 fact by switching back to
      // HOME, exactly where a real player would still be if they had opened
      // メニュー themselves and then backed out.
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      expect(find.text('1年目 7月'), findsOneWidget);
    },
  );

  testWidgets(
    'Public Demo test restart leaves a normal game save byte-for-byte '
    'unchanged',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final normalService = SaveService.forExperience(
        AppExperience.development,
      );
      final normal = GameEngine.newGame(
        seed: 133,
        companyName: 'Issue 133 normal save',
      );
      await normalService.save(normal);
      final publicDemoService = const PublicDemoSaveService();
      await publicDemoService.save(_freshJulyAggregate());
      final preferences = await SharedPreferences.getInstance();
      final normalRawBefore = preferences.getString(normalService.key);
      expect(normalRawBefore, isNotNull);

      await _mount(tester, publicDemoService);
      await _openAprilRestart(tester);
      await tester.tap(
        find.byKey(const Key('public-demo-restart-april-confirm')),
      );
      await tester.pumpAndSettle();

      expect(preferences.getString(normalService.key), normalRawBefore);
      expect(
        (await normalService.load())!.company.name,
        'Issue 133 normal save',
      );
      expect(preferences.getString(PublicDemoSaveService.key), isNull);
      expect(_screenState(tester).month, 4);
    },
  );
}
