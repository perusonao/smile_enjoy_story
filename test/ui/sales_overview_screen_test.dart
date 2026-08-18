// 営業・案件画面 Phase 2 (営業フローの可視化と案件画面再設計): widget-test
// checklist for the redesigned 案件タブ (SalesOverviewScreen) —
//   A.   the screen renders
//   B/C/D/E. 営業中/選考中/オファー/参画中 counts are correct
//   F/G. an engineer with >=2 pendingOffers shows a 案件比較 CTA that reaches
//        ProjectComparisonScreen
//   H.   a 営業状況 card shows engineer/project/client/status
//   I/J. no overflow at 360px/390px
//   K.   no overflow with long names/project/client strings
//   L.   Beginner Mode's existing sales flow (via 案件を探す →
//        ProjectListScreen) stays reachable and unchanged
//   M.   Free Mode renders a mix of multiple engineers/projects/offers
//   N.   viewing/filtering never mutates GameState
//   O.   Fit is shown only as ◎○△×, never a raw score
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/engineers/engineer_detail_screen.dart';
import 'package:smile_enjoy_story/ui/projects/project_comparison_screen.dart';
import 'package:smile_enjoy_story/ui/projects/project_list_screen.dart';
import 'package:smile_enjoy_story/ui/projects/sales_overview_screen.dart';
import 'package:smile_enjoy_story/ui/widgets/fit_badge.dart';
import 'package:smile_enjoy_story/ui/widgets/status_chip.dart';

import '../game/prologue_engine_test.dart' show playThroughPrologue;
import '../game/test_helpers.dart';

const _widths = [360.0, 390.0];

List<SkillSheet> _skillSheetsFor(List<Engineer> engineers, int week) => [
  for (final e in engineers)
    SkillSheet.fromActual(
      employeeId: e.id,
      languageMonths: e.profile.languageSkills.map((k, v) => MapEntry(k, v.actualExperienceMonths)),
      skills: e.profile.techSkills,
      week: week,
    ),
];

/// 混在状態 (§14): 選考中1名/オファー2名(うち1名は2件受領)/参画中3名/待機中
/// (対象外)1名。4バケットの件数を 0/1/2/3 と全て異なる値にして、要対応・
/// 営業状況・参画中の各セクションと件数表示を同時に検証できるようにする
/// （営業中はあえて0件 — §16 の「営業案件0件」も兼ねる）。
GameState _mixedSalesState() {
  var state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 91));

  final projectInterview = buildProject(id: 'proj-interview', clientId: sampleClients[0].id, title: '客先面談中の案件');
  final projectOfferA = buildProject(id: 'proj-offer-a', clientId: sampleClients[0].id, title: 'オファーA案件');
  final projectOfferB = buildProject(id: 'proj-offer-b', clientId: sampleClients[1].id, title: 'オファーB案件');
  final projectOfferC = buildProject(id: 'proj-offer-c', clientId: sampleClients[0].id, title: 'オファーC案件');
  final projectAssignedA = buildProject(id: 'proj-assigned-a', clientId: sampleClients[0].id, title: '稼働中の案件A');
  final projectAssignedB = buildProject(id: 'proj-assigned-b', clientId: sampleClients[1].id, title: '稼働中の案件B');
  final projectAssignedC = buildProject(id: 'proj-assigned-c', clientId: sampleClients[0].id, title: '稼働中の案件C');

  final eInterview = buildEngineer(id: 'e-interview', profile: buildApplicant(id: 'a-interview', name: '鈴木 花子'));
  final eOfferTwo = buildEngineer(id: 'e-offer-two', profile: buildApplicant(id: 'a-offer-two', name: '山田 太郎'));
  final eOfferOne = buildEngineer(id: 'e-offer-one', profile: buildApplicant(id: 'a-offer-one', name: '中村 五郎'));
  final eAssignedA = buildEngineer(id: 'e-assigned-a', profile: buildApplicant(id: 'a-assigned-a', name: '佐藤 次郎'), status: EngineerStatus.assigned);
  final eAssignedB = buildEngineer(id: 'e-assigned-b', profile: buildApplicant(id: 'a-assigned-b', name: '高橋 三郎'), status: EngineerStatus.assigned);
  final eAssignedC = buildEngineer(id: 'e-assigned-c', profile: buildApplicant(id: 'a-assigned-c', name: '伊藤 六郎'), status: EngineerStatus.assigned);
  final eWaiting = buildEngineer(id: 'e-waiting', profile: buildApplicant(id: 'a-waiting', name: '渡辺 七郎'));

  final engineers = [eInterview, eOfferTwo, eOfferOne, eAssignedA, eAssignedB, eAssignedC, eWaiting];

  final proposalInterview = ProjectProposal(
    id: 'proposal-interview',
    engineerId: eInterview.id,
    project: projectInterview,
    proposedWeek: state.week,
    stage: ProposalStage.proposed,
    currentStepIndex: projectInterview.selectionFlow.steps.indexOf(SelectionStep.clientInterview),
    status: ApplicationStatus.active,
  );
  final proposalOfferA = ProjectProposal(
    id: 'proposal-offer-a',
    engineerId: eOfferTwo.id,
    project: projectOfferA,
    proposedWeek: state.week,
    stage: ProposalStage.proposed,
    currentStepIndex: projectOfferA.selectionFlow.steps.length - 1,
    status: ApplicationStatus.offered,
  );
  final proposalOfferB = ProjectProposal(
    id: 'proposal-offer-b',
    engineerId: eOfferTwo.id,
    project: projectOfferB,
    proposedWeek: state.week,
    stage: ProposalStage.proposed,
    currentStepIndex: projectOfferB.selectionFlow.steps.length - 1,
    status: ApplicationStatus.offered,
  );
  final proposalOfferC = ProjectProposal(
    id: 'proposal-offer-c',
    engineerId: eOfferOne.id,
    project: projectOfferC,
    proposedWeek: state.week,
    stage: ProposalStage.proposed,
    currentStepIndex: projectOfferC.selectionFlow.steps.length - 1,
    status: ApplicationStatus.offered,
  );

  return state.copyWith(
    engineers: engineers,
    company: state.company.copyWith(engineerIds: engineers.map((e) => e.id).toList()),
    skillSheets: _skillSheetsFor(engineers, state.week),
    proposals: [proposalInterview, proposalOfferA, proposalOfferB, proposalOfferC],
    offers: [
      Offer(
        id: 'offer-a',
        applicationId: proposalOfferA.id,
        projectId: projectOfferA.id,
        employeeId: eOfferTwo.id,
        monthlyRate: projectOfferA.monthlyRate,
        startWeek: state.week + 1,
        responseDeadlineWeek: state.week + 2,
      ),
      Offer(
        id: 'offer-b',
        applicationId: proposalOfferB.id,
        projectId: projectOfferB.id,
        employeeId: eOfferTwo.id,
        monthlyRate: projectOfferB.monthlyRate,
        startWeek: state.week + 1,
        responseDeadlineWeek: state.week + 2,
      ),
      Offer(
        id: 'offer-c',
        applicationId: proposalOfferC.id,
        projectId: projectOfferC.id,
        employeeId: eOfferOne.id,
        monthlyRate: projectOfferC.monthlyRate,
        startWeek: state.week + 1,
        responseDeadlineWeek: state.week + 2,
      ),
    ],
    activeAssignments: [
      ActiveAssignment(engineerId: eAssignedA.id, project: projectAssignedA, remainingWeeks: 6, assignedWeek: 1),
      ActiveAssignment(engineerId: eAssignedB.id, project: projectAssignedB, remainingWeeks: 9, assignedWeek: 1),
      ActiveAssignment(engineerId: eAssignedC.id, project: projectAssignedC, remainingWeeks: 3, assignedWeek: 1),
    ],
  );
}

/// 全社員が待機中で営業活動なし（§16「営業案件0件」）: 4カウント全て0、要対応・
/// 参画中セクションは非表示、営業状況は空メッセージのみ。
GameState _noSalesActivityState() {
  var state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 92));
  final engineer = buildEngineer(id: 'e-idle', profile: buildApplicant(id: 'a-idle', name: '空 太郎'));
  return state.copyWith(
    engineers: [engineer],
    company: state.company.copyWith(engineerIds: [engineer.id]),
    skillSheets: _skillSheetsFor([engineer], state.week),
    proposals: const [],
    offers: const [],
    interviewOffers: const [],
    activeAssignments: const [],
  );
}

/// 長い社員名・案件名・顧客名（§16 K）: 要対応の比較CTA・営業状況カード・
/// 参画中カードいずれも overflow しないことを確認する。
GameState _longStringsState() {
  var state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 93));
  const longClientId = 'client-なが過ぎる名前の取引先株式会社ホールディングス（本社・第二営業部）';
  final projectOfferA = buildProject(
    id: 'proj-long-offer-a',
    clientId: longClientId,
    title: '基幹業務システム大規模リプレイス及びクラウド移行プロジェクト（第一期）',
  );
  final projectOfferB = buildProject(
    id: 'proj-long-offer-b',
    clientId: longClientId,
    title: '基幹業務システム大規模リプレイス及びクラウド移行プロジェクト（第二期）',
  );
  final projectAssigned = buildProject(
    id: 'proj-long-assigned',
    clientId: longClientId,
    title: '全社統合データ基盤刷新及び分析基盤構築プロジェクト',
  );
  final eOffer = buildEngineer(
    id: 'e-long-offer',
    profile: buildApplicant(id: 'a-long-offer', name: '田中山田佐藤鈴木高橋渡辺伊藤中村小林加藤'),
  );
  final eAssigned = buildEngineer(
    id: 'e-long-assigned',
    profile: buildApplicant(id: 'a-long-assigned', name: '長谷川小笠原九十九里浜田中村上'),
    status: EngineerStatus.assigned,
  );
  final engineers = [eOffer, eAssigned];

  final proposalA = ProjectProposal(
    id: 'proposal-long-a',
    engineerId: eOffer.id,
    project: projectOfferA,
    proposedWeek: state.week,
    stage: ProposalStage.proposed,
    currentStepIndex: projectOfferA.selectionFlow.steps.length - 1,
    status: ApplicationStatus.offered,
  );
  final proposalB = ProjectProposal(
    id: 'proposal-long-b',
    engineerId: eOffer.id,
    project: projectOfferB,
    proposedWeek: state.week,
    stage: ProposalStage.proposed,
    currentStepIndex: projectOfferB.selectionFlow.steps.length - 1,
    status: ApplicationStatus.offered,
  );

  return state.copyWith(
    engineers: engineers,
    company: state.company.copyWith(engineerIds: engineers.map((e) => e.id).toList()),
    skillSheets: _skillSheetsFor(engineers, state.week),
    proposals: [proposalA, proposalB],
    offers: [
      Offer(
        id: 'offer-long-a',
        applicationId: proposalA.id,
        projectId: projectOfferA.id,
        employeeId: eOffer.id,
        monthlyRate: projectOfferA.monthlyRate,
        startWeek: state.week + 1,
        responseDeadlineWeek: state.week + 2,
      ),
      Offer(
        id: 'offer-long-b',
        applicationId: proposalB.id,
        projectId: projectOfferB.id,
        employeeId: eOffer.id,
        monthlyRate: projectOfferB.monthlyRate,
        startWeek: state.week + 1,
        responseDeadlineWeek: state.week + 2,
      ),
    ],
    activeAssignments: [
      ActiveAssignment(engineerId: eAssigned.id, project: projectAssigned, remainingWeeks: 4, assignedWeek: 1),
    ],
  );
}

/// 営業案件・参画案件が多数（§16「営業案件多数」「参画案件多数」）: 選考中6名
/// +参画中6名で一覧が長くなってもoverflowしないことを確認する。
GameState _manyEngineersState() {
  var state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 94));
  final engineers = <Engineer>[];
  final proposals = <ProjectProposal>[];
  final assignments = <ActiveAssignment>[];
  for (var i = 0; i < 6; i++) {
    final project = buildProject(id: 'proj-many-selection-$i', clientId: sampleClients[i % sampleClients.length].id, title: '選考中案件$i');
    final engineer = buildEngineer(id: 'e-many-selection-$i', profile: buildApplicant(id: 'a-many-selection-$i', name: '選考社員$i'));
    engineers.add(engineer);
    proposals.add(
      ProjectProposal(
        id: 'proposal-many-$i',
        engineerId: engineer.id,
        project: project,
        proposedWeek: state.week,
        stage: ProposalStage.proposed,
        currentStepIndex: 0,
        status: ApplicationStatus.active,
      ),
    );
  }
  for (var i = 0; i < 6; i++) {
    final project = buildProject(id: 'proj-many-assigned-$i', clientId: sampleClients[i % sampleClients.length].id, title: '参画中案件$i');
    final engineer = buildEngineer(id: 'e-many-assigned-$i', profile: buildApplicant(id: 'a-many-assigned-$i', name: '参画社員$i'), status: EngineerStatus.assigned);
    engineers.add(engineer);
    assignments.add(ActiveAssignment(engineerId: engineer.id, project: project, remainingWeeks: 5, assignedWeek: 1));
  }
  return state.copyWith(
    engineers: engineers,
    company: state.company.copyWith(engineerIds: engineers.map((e) => e.id).toList()),
    skillSheets: _skillSheetsFor(engineers, state.week),
    proposals: proposals,
    activeAssignments: assignments,
  );
}

Future<GameController> _pumpScreen(WidgetTester tester, GameState state, {double width = 390}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
  final controller = GameController();
  await tester.pumpWidget(
    GameScope(
      controller: controller,
      child: const MaterialApp(home: SalesOverviewScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Scrolls the screen's single `ListView` until [finder] is built — mirrors
/// `_openEmployeeDetail`'s own doc comment (test/game/test_helpers.dart):
/// Flutter's `SliverList` only materializes children within/near the
/// viewport, so content below the fold isn't in the Element tree yet on a
/// fresh pump.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(finder, find.byType(ListView), const Offset(0, -300));
}

void main() {
  group('A: the screen renders', () {
    testWidgets('shows the 営業・案件 app bar and its sections', (tester) async {
      await _pumpScreen(tester, _mixedSalesState());
      expect(find.widgetWithText(AppBar, '営業・案件'), findsOneWidget);
      expect(find.text('要対応'), findsOneWidget);
      expect(find.text('営業状況'), findsOneWidget);
      await _scrollTo(tester, find.text('参画中の案件'));
      expect(find.text('参画中の案件'), findsOneWidget);
      await _scrollTo(tester, find.text('案件を探す'));
      expect(find.text('案件を探す'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('B/C/D/E: summary counts are correct', () {
    testWidgets('営業中/選考中/オファー/参画中 show 0/1/2/3', (tester) async {
      await _pumpScreen(tester, _mixedSalesState());
      expect(find.text('営業中'), findsOneWidget);
      expect(find.text('選考中'), findsOneWidget);
      expect(find.text('オファー'), findsOneWidget);
      expect(find.text('参画中'), findsOneWidget);
      expect(find.text('0名'), findsOneWidget);
      expect(find.text('1名'), findsOneWidget);
      expect(find.text('2名'), findsOneWidget);
      expect(find.text('3名'), findsOneWidget);
    });
  });

  group('F/G: pendingOffers >= 2 shows a 案件比較 CTA reaching ProjectComparisonScreen', () {
    testWidgets('山田太郎 (2件のオファー) gets a 案件を比較する button; 中村五郎 (1件) does not', (tester) async {
      await _pumpScreen(tester, _mixedSalesState());
      expect(find.textContaining('オファーが2件届いています'), findsOneWidget);
      expect(find.textContaining('オファーが届いています'), findsOneWidget);
      expect(find.text('案件を比較する'), findsOneWidget);

      await tester.tap(find.text('案件を比較する'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectComparisonScreen), findsOneWidget);
    });
  });

  group('H: a 営業状況 card shows engineer/project/client/status', () {
    testWidgets('鈴木花子の客先面談カードに社員/案件/顧客/状態が表示される', (tester) async {
      await _pumpScreen(tester, _mixedSalesState());
      await _scrollTo(tester, find.text('客先面談中の案件'));
      // 鈴木花子 also appears in 要対応 above (client-interview action item) —
      // this test is about the 営業状況 card's own content, so at least one
      // match (not necessarily exactly one) is the right bar here.
      expect(find.text('鈴木 花子'), findsWidgets);
      expect(find.text('客先面談中の案件'), findsOneWidget);
      expect(find.textContaining(sampleClients[0].name), findsWidgets);
      expect(find.widgetWithText(EngineerStatusChip, '客先面談あり'), findsOneWidget);
    });
  });

  group('参画中の案件: project-centric, not duplicating 社員画面', () {
    testWidgets('稼働中の3案件がそれぞれ案件名を先頭に表示される', (tester) async {
      await _pumpScreen(tester, _mixedSalesState());
      await _scrollTo(tester, find.text('稼働中の案件A'));
      expect(find.text('稼働中の案件A'), findsOneWidget);
      await _scrollTo(tester, find.text('稼働中の案件B'));
      expect(find.text('稼働中の案件B'), findsOneWidget);
      await _scrollTo(tester, find.text('稼働中の案件C'));
      expect(find.text('稼働中の案件C'), findsOneWidget);
      expect(find.textContaining('残り6週'), findsOneWidget);
    });
  });

  group('要対応から除外される社員: waiting engineers stay off this screen', () {
    testWidgets('待機中で営業活動のない社員はどのセクションにも出てこない', (tester) async {
      await _pumpScreen(tester, _mixedSalesState());
      expect(find.text('渡辺 七郎'), findsNothing);
    });
  });

  group('§16 営業案件0件: empty pipeline shows a calm message, no 要対応/参画中 sections', () {
    testWidgets('no sales activity at all', (tester) async {
      await _pumpScreen(tester, _noSalesActivityState());
      expect(find.text('0名'), findsNWidgets(4));
      expect(find.text('要対応'), findsNothing);
      expect(find.text('参画中の案件'), findsNothing);
      expect(find.text('該当する営業案件はありません。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('I/J: no overflow at 360px/390px', () {
    for (final width in _widths) {
      testWidgets('mixed sales state at ${width.toInt()}px', (tester) async {
        await _pumpScreen(tester, _mixedSalesState(), width: width);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('K: no overflow with long names/project/client strings', () {
    for (final width in _widths) {
      testWidgets('long strings at ${width.toInt()}px', (tester) async {
        await _pumpScreen(tester, _longStringsState(), width: width);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('§16 営業案件多数/参画案件多数: many cards at 360px/390px', () {
    for (final width in _widths) {
      testWidgets('6 selling + 6 assigned engineers at ${width.toInt()}px', (tester) async {
        await _pumpScreen(tester, _manyEngineersState(), width: width);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('L: Beginner Mode keeps the existing sales flow reachable', () {
    testWidgets('a Beginner Mode journey renders this screen, and 案件を探す still reaches the unchanged market list', (tester) async {
      final state = playThroughPrologue(31);
      expect(BeginnerModeEngine.isBeginnerJourney(state), isTrue);
      await _pumpScreen(tester, state);
      expect(find.byType(SalesOverviewScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('案件一覧を見る'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectListScreen), findsOneWidget);
      // Playable 0.4C.3 §140-152 (parallel_sales_ux_test.dart): the market
      // list must never gain a direct proposal action — verify the new
      // entry point still reaches that same, unchanged screen.
      expect(find.text('提案する'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('M: Free Mode renders multiple engineers/projects/offers mixed together', () {
    testWidgets('a free-management save with a full mix of states renders with no exception', (tester) async {
      final state = _mixedSalesState();
      expect(BeginnerModeEngine.isBeginnerJourney(state), isFalse);
      await _pumpScreen(tester, state);
      expect(find.byType(SalesOverviewScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('N: viewing/filtering never mutates GameState', () {
    testWidgets('GameState is byte-identical (toJson) before and after filter taps', (tester) async {
      final controller = await _pumpScreen(tester, _mixedSalesState());
      final baseline = jsonEncode(controller.state.toJson());

      for (final label in ['営業中 0', '選考中 1', 'オファー 2', 'すべて 3']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(jsonEncode(controller.state.toJson()), baseline);
      }
    });
  });

  group('O: Fit is shown only as ◎○△×, never a raw score', () {
    testWidgets('the 営業状況 card with a known project shows FitBadge but no raw score', (tester) async {
      await _pumpScreen(tester, _mixedSalesState());
      await _scrollTo(tester, find.text('客先面談中の案件'));
      expect(find.byType(FitBadge), findsWidgets);
      // PR #18 policy: never a bare fraction/points score in list context.
      expect(find.textContaining('/20'), findsNothing);
      expect(find.textContaining('/100'), findsNothing);
      expect(find.textContaining('点'), findsNothing);
    });
  });

  group('タップ導線: cards navigate to EngineerDetailScreen', () {
    testWidgets('営業状況カードをタップすると社員詳細へ遷移する', (tester) async {
      await _pumpScreen(tester, _mixedSalesState());
      // 鈴木花子 appears both in 要対応 (name only, no card-level tap target)
      // and in 営業状況 (the tappable card) — target the latter explicitly.
      await _scrollTo(tester, find.text('客先面談中の案件'));
      await tester.tap(find.text('鈴木 花子').last);
      await tester.pumpAndSettle();
      expect(find.byType(EngineerDetailScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, '鈴木 花子'), findsOneWidget);
    });

    testWidgets('要対応カードの「社員詳細を見る」からも社員詳細へ遷移できる', (tester) async {
      await _pumpScreen(tester, _mixedSalesState());
      await tester.tap(find.text('社員詳細を見る').first);
      await tester.pumpAndSettle();
      expect(find.byType(EngineerDetailScreen), findsOneWidget);
    });
  });
}
