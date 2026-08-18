// 社員画面 Phase 2 (レイアウト改修): widget-test checklist for the redesigned
// EngineerListScreen —
//   A. the roster renders
//   B. すべて/参画中/待機中 counts are correct
//   C. the filter switches which engineers are shown
//   D. a card shows name/status/key info
//   E. tapping a card opens EngineerDetailScreen
//   F/G. no overflow at 360px/390px
//   H. no overflow with long names/project/client strings
//   I/J. renders in both Beginner Mode and Free Mode
//   K. viewing/filtering never mutates GameState
//   L. 稼働率 on-screen matches GameState.utilizationPercent
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_detail_screen.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_list_screen.dart';
import 'package:smile_enjoy_story/ui/widgets/status_chip.dart';

import '../game/prologue_engine_test.dart' show playThroughPrologue;
import '../game/test_helpers.dart';

const _widths = [360.0, 390.0];

/// [GameState.skillSheetFor] does an unguarded `firstWhere` — every real
/// engineer always has one (created alongside them by [GameEngine]), so a
/// hand-built roster needs the same to reach [EngineerDetailScreen] without
/// throwing.
List<SkillSheet> _skillSheetsFor(List<Engineer> engineers, int week) => [
  for (final e in engineers)
    SkillSheet.fromActual(
      employeeId: e.id,
      languageMonths: e.profile.languageSkills.map((k, v) => MapEntry(k, v.actualExperienceMonths)),
      skills: e.profile.techSkills,
      week: week,
    ),
];

/// 2名 assigned (別々の案件/顧客) + 1名 waiting — the mix the Phase 2 mock
/// itself uses (§2), so filter counts/summary numbers are non-trivial.
GameState _threeEngineerState() {
  var state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 21));
  final projectA = buildProject(
    id: 'proj-a',
    clientId: sampleClients[0].id,
    title: '販売管理システム開発',
  );
  final projectB = buildProject(
    id: 'proj-b',
    clientId: sampleClients[1].id,
    title: '基幹システム保守',
  );
  final e1 = buildEngineer(
    id: 'e-1',
    profile: buildApplicant(id: 'a-1', name: '鈴木 花子'),
    status: EngineerStatus.assigned,
  );
  final e2 = buildEngineer(
    id: 'e-2',
    profile: buildApplicant(id: 'a-2', name: '田中 一郎'),
    status: EngineerStatus.assigned,
  );
  final e3 = buildEngineer(
    id: 'e-3',
    profile: buildApplicant(id: 'a-3', name: '山田 太郎'),
    status: EngineerStatus.waiting,
  );
  final engineers = [e1, e2, e3];
  return state.copyWith(
    engineers: engineers,
    company: state.company.copyWith(engineerIds: engineers.map((e) => e.id).toList()),
    skillSheets: _skillSheetsFor(engineers, state.week),
    activeAssignments: [
      ActiveAssignment(engineerId: e1.id, project: projectA, remainingWeeks: 8, assignedWeek: 1),
      ActiveAssignment(engineerId: e2.id, project: projectB, remainingWeeks: 5, assignedWeek: 1),
    ],
    waitingStreak: {e3.id: 2},
  );
}

/// One engineer with a deliberately long name, assigned to a project with a
/// long title, at a client whose display name is also long (§13/H).
GameState _longStringsState() {
  var state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 22));
  final client = sampleClients.first;
  final project = buildProject(
    id: 'proj-long',
    clientId: client.id,
    title: '基幹業務システム大規模リプレイス及びクラウド移行プロジェクト（第二期）',
  );
  final engineer = buildEngineer(
    id: 'e-long',
    profile: buildApplicant(
      id: 'a-long',
      name: '田中山田佐藤鈴木高橋渡辺伊藤中村小林加藤',
    ),
    status: EngineerStatus.assigned,
  );
  return state.copyWith(
    engineers: [engineer],
    company: state.company.copyWith(engineerIds: [engineer.id]),
    skillSheets: _skillSheetsFor([engineer], state.week),
    activeAssignments: [
      ActiveAssignment(engineerId: engineer.id, project: project, remainingWeeks: 3, assignedWeek: 1),
    ],
  );
}

Future<GameController> _pumpList(WidgetTester tester, GameState state, {double width = 390}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
  final controller = GameController();
  await tester.pumpWidget(
    GameScope(
      controller: controller,
      child: const MaterialApp(home: EngineerListScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('A/D: roster renders with name/status/key info', () {
    testWidgets('all three cards show name, status chip, and role/skill line', (tester) async {
      await _pumpList(tester, _threeEngineerState());

      expect(find.text('鈴木 花子'), findsOneWidget);
      expect(find.text('田中 一郎'), findsOneWidget);
      expect(find.text('山田 太郎'), findsOneWidget);
      expect(find.widgetWithText(EngineerStatusChip, '参画中'), findsNWidgets(2));
      expect(find.widgetWithText(EngineerStatusChip, '待機中'), findsOneWidget);
      // P1: current project/client/remaining-weeks for the assigned two.
      expect(find.textContaining('販売管理システム開発'), findsOneWidget);
      expect(find.textContaining(sampleClients[0].name), findsOneWidget);
      expect(find.textContaining('8週'), findsOneWidget);
      expect(find.textContaining('基幹システム保守'), findsOneWidget);
      expect(find.textContaining(sampleClients[1].name), findsOneWidget);
      expect(find.textContaining('5週'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('B: filter counts match GameState getters', () {
    testWidgets('すべて/参画中/待機中 chips show the real counts', (tester) async {
      final state = _threeEngineerState();
      await _pumpList(tester, state);

      expect(state.engineers.length, 3);
      expect(state.assignedEngineerCount, 2);
      expect(state.waitingEngineerCount, 1);
      expect(find.text('すべて 3'), findsOneWidget);
      expect(find.text('参画中 2'), findsOneWidget);
      expect(find.text('待機中 1'), findsOneWidget);
      // Summary card mirrors the same three counts.
      expect(find.text('社員数'), findsOneWidget);
      expect(find.text('3名'), findsOneWidget);
      expect(find.text('2名'), findsOneWidget);
      expect(find.text('1名'), findsOneWidget);
    });
  });

  group('C: filtering switches which cards show', () {
    testWidgets('tapping 参画中 hides the waiting engineer; tapping 待機中 hides the assigned ones', (tester) async {
      await _pumpList(tester, _threeEngineerState());

      await tester.tap(find.text('参画中 2'));
      await tester.pumpAndSettle();
      expect(find.text('鈴木 花子'), findsOneWidget);
      expect(find.text('田中 一郎'), findsOneWidget);
      expect(find.text('山田 太郎'), findsNothing);

      await tester.tap(find.text('待機中 1'));
      await tester.pumpAndSettle();
      expect(find.text('鈴木 花子'), findsNothing);
      expect(find.text('田中 一郎'), findsNothing);
      expect(find.text('山田 太郎'), findsOneWidget);

      await tester.tap(find.text('すべて 3'));
      await tester.pumpAndSettle();
      expect(find.text('鈴木 花子'), findsOneWidget);
      expect(find.text('田中 一郎'), findsOneWidget);
      expect(find.text('山田 太郎'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('E: tapping a card opens EngineerDetailScreen', () {
    testWidgets('tapping the waiting engineer card navigates to its detail screen', (tester) async {
      await _pumpList(tester, _threeEngineerState());

      await tester.tap(find.text('山田 太郎'));
      await tester.pumpAndSettle();

      expect(find.byType(EngineerDetailScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, '山田 太郎'), findsOneWidget);
    });
  });

  group('F/G: no overflow at 360px/390px', () {
    for (final width in _widths) {
      testWidgets('three-engineer roster at ${width.toInt()}px', (tester) async {
        await _pumpList(tester, _threeEngineerState(), width: width);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('H: no overflow with long names/project/client strings', () {
    for (final width in _widths) {
      testWidgets('long strings at ${width.toInt()}px', (tester) async {
        await _pumpList(tester, _longStringsState(), width: width);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('I: renders in Beginner Mode', () {
    testWidgets('a Beginner Mode journey shows the roster with no exception', (tester) async {
      final state = playThroughPrologue(11);
      expect(BeginnerModeEngine.isBeginnerJourney(state), isTrue);
      await _pumpList(tester, state);
      expect(find.byType(EngineerListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('J: renders in Free Mode', () {
    testWidgets('a free-management save shows the roster with no exception', (tester) async {
      final state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 23));
      expect(BeginnerModeEngine.isBeginnerJourney(state), isFalse);
      await _pumpList(tester, state);
      expect(find.byType(EngineerListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('K: viewing/filtering never mutates GameState', () {
    testWidgets('GameState is byte-identical (toJson) before and after filter taps', (tester) async {
      final controller = await _pumpList(tester, _threeEngineerState());
      // Baseline captured *after* boot, not before: [GameController]'s own
      // load-time reconcile (BeginnerModeEngine/ProgressionEngine/
      // PrologueEngine) is expected, ordinary boot behavior, unrelated to
      // this screen — what this test guards is that simply looking at 社員
      // and switching its filter causes no *further* change on top of that.
      final baseline = jsonEncode(controller.state.toJson());

      for (final label in ['参画中 2', '待機中 1', 'すべて 3']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(jsonEncode(controller.state.toJson()), baseline);
      }
    });
  });

  group('L: utilization display matches GameState.utilizationPercent', () {
    testWidgets('稼働率 shows the same value as state.utilizationPercent', (tester) async {
      final state = _threeEngineerState();
      // 2 assigned / 3 engineers = 67% (rounded), the same rounding
      // GameState.utilizationPercent itself uses — no UI-side re-derivation.
      expect(state.utilizationPercent, 67);
      await _pumpList(tester, state);
      expect(find.text('${state.utilizationPercent}%'), findsOneWidget);
    });
  });
}
