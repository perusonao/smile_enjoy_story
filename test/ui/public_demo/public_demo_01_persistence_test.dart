import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

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
}

PublicDemoAggregate _bankruptAggregate() {
  var aggregate = PublicDemoAggregate.initial()
      .closeApril(monthlyExpenses: 800000)
      .closeMay(week: 9, monthlyExpenses: 800000);
  aggregate = aggregate
      .recruit(PublicDemoRecruitmentMedium.free)
      .aggregate!
      .closeJune(assignedInJuly: 0, monthlyExpenses: 800000)
      .closeJuly(monthlyExpenses: 800000)
      .closeOrdinaryMonth(monthlyExpenses: 800000);
  assert(
    aggregate.state.financialStatus == PublicDemoFinancialStatus.bankruptcy,
  );
  return aggregate;
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
}
