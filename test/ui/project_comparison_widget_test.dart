// Phase 3B-1 (S.E.S. Development Plan §3.3, "案件を選ぶ"): ProjectComparisonScreen
// must lay out 2-3 candidate projects for one engineer — 単価/粗利/総合Fit/
// Fit内訳(技術・経験・人物相性・条件)/商流/面談回数/支払サイト/契約期間 — all
// read straight through ProjectComparisonEngine (itself a thin wrapper over
// the existing MatchingEngine), never re-derived, without overflowing at the
// project's target mobile widths. showProjectComparisonScreen must mark
// BeginnerMilestone.projectComparisonUsed shown exactly once per playthrough,
// and never at all in Free Mode. Every fixture here is hand-built and
// deterministic (buildEngineer/buildProject, GameEngine.newGame's fixed
// founder seeds) — no RNG-dependent assertions.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/projects/project_comparison_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';
import 'package:smile_enjoy_story/ui/widgets/labels.dart';

import '../game/test_helpers.dart';

const _widths = [360.0, 390.0];

/// A hand-built engineer plus two candidate projects (client-axis-soft /
/// 30日サイト, client-future-web / 60日サイト) with deliberately different
/// monthlyRate/commercialFlow/interviewCount/durationWeeks — so every
/// comparison item actually differs between the two columns instead of
/// coincidentally matching.
({Engineer engineer, Project projectA, Project projectB}) _twoProjectFixture() {
  final profile = buildApplicant(
    mainLanguage: ProgrammingLanguage.java,
    mainLanguageActualSkill: 85,
    totalItExperienceMonths: 60,
    japaneseLevel: 4,
    techSkills: const TechSkillLevels(
      database: 0,
      network: 0,
      infrastructure: 0,
      frontend: 0,
      backend: 4,
      leader: 0,
      manager: 0,
    ),
    personality: const PersonalityTraits(
      looks: 3,
      cleanliness: 3,
      communication: 4,
      alcoholTolerance: 3,
      seriousness: 3,
      dishonesty: 3,
    ),
  );
  final engineer = buildEngineer(id: 'cmp-engineer', profile: profile, salary: 480000);
  final projectA = buildProject(
    id: 'cmp-project-a',
    clientId: 'client-axis-soft',
    title: '比較用案件A',
    rank: ProjectRank.middle,
    monthlyRate: 650000,
    requiredLanguages: const [ProgrammingLanguage.java],
    requiredBackend: 4,
    requiredJapaneseLevel: 3,
    commercialFlow: CommercialFlow.firstTier,
    durationWeeks: 24,
    interviewCount: 1,
  );
  final projectB = buildProject(
    id: 'cmp-project-b',
    clientId: 'client-future-web',
    title: '比較用案件B',
    rank: ProjectRank.middle,
    monthlyRate: 720000,
    requiredLanguages: const [ProgrammingLanguage.java],
    requiredBackend: 2,
    requiredJapaneseLevel: 3,
    commercialFlow: CommercialFlow.thirdTier,
    durationWeeks: 12,
    interviewCount: 3,
  );
  return (engineer: engineer, projectA: projectA, projectB: projectB);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Engineer engineer,
  List<Project> projects,
  double width, {
  int? totalCandidates,
}) async {
  // The comparison screen's content (overview cards + up to 11 spec rows)
  // is taller than one mobile viewport — a tall physicalSize (same trick
  // `assignment_acceptance_test.dart`/`prologue_widget_test.dart` use for
  // other long screens) keeps every row mounted so `find.text` can see it,
  // without this test needing to scroll between assertions.
  tester.view.physicalSize = Size(width, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: ProjectComparisonScreen(engineer: engineer, projects: projects, totalCandidates: totalCandidates),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ProjectComparisonScreen — 2案件比較', () {
    final fixture = _twoProjectFixture();
    final rows = ProjectComparisonEngine.compare(
      engineer: fixture.engineer,
      projects: [fixture.projectA, fixture.projectB],
    );

    for (final width in _widths) {
      testWidgets('renders 単価/粗利/Fit/Fit内訳/商流/面談回数/支払サイト/契約期間 with no overflow at ${width}px', (tester) async {
        await _pumpScreen(tester, fixture.engineer, [fixture.projectA, fixture.projectB], width);

        // 社員名 + タイトル
        expect(find.text('案件を比較'), findsOneWidget);
        expect(find.text(fixture.engineer.profile.name), findsOneWidget);
        expect(find.text('選択中案件 2/2件'), findsOneWidget);

        // 案件ごとの概要カード
        expect(find.text('比較用案件A'), findsOneWidget);
        expect(find.text('比較用案件B'), findsOneWidget);

        // 単価 — formatYen is unique per project since monthlyRate differs.
        expect(find.text('単価'), findsOneWidget);
        expect(find.text(formatYen(rows[0].monthlyRate)), findsOneWidget);
        expect(find.text(formatYen(rows[1].monthlyRate)), findsOneWidget);

        // 粗利 (+ helper caption) — signed, matching MatchingEngine.monthlyProfit exactly.
        expect(find.text('粗利'), findsOneWidget);
        expect(find.text('会社に残る利益'), findsOneWidget);
        for (final row in rows) {
          final expectedProfit = '${row.monthlyProfit >= 0 ? '+' : ''}${formatYen(row.monthlyProfit)}';
          expect(find.text(expectedProfit), findsOneWidget);
        }

        // Fit / Fit内訳 — every sub-score bucketed via the same
        // PlayerVisibleFit.fromRaw/fromScore MatchingEngine already uses,
        // never a re-derived rating.
        expect(find.text('Fit内訳'), findsOneWidget);
        expect(find.text('総合Fit'), findsOneWidget);
        expect(find.text('高いほど面談・参画との相性が良い'), findsOneWidget);
        expect(find.text('技術'), findsOneWidget);
        expect(find.text('経験'), findsOneWidget);
        expect(find.text('人物・相性'), findsOneWidget);
        expect(find.text('条件'), findsOneWidget);
        for (final row in rows) {
          final total = PlayerVisibleFit.fromScore(row.totalFit);
          expect(find.text('${total.symbol} ${total.label}'), findsWidgets);
          final tech = PlayerVisibleFit.fromRaw(row.techFit, 55);
          final exp = PlayerVisibleFit.fromRaw(row.experienceFit, 15);
          final personality = PlayerVisibleFit.fromRaw(row.personalityFit, 20);
          final condition = PlayerVisibleFit.fromRaw(row.conditionFit, 10);
          for (final rating in [tech, exp, personality, condition]) {
            expect(find.text('${rating.symbol} ${rating.label}'), findsWidgets);
          }
          // HiddenParameters guard (PR #18 review fix): 人物・相性 folds in
          // the hidden projectInterviewSkill — the raw x/20 fraction must
          // never be back-solvable from this screen either.
          expect(find.text('${row.personalityFit}/20'), findsNothing);
          expect(find.text('${row.personalityFit} / 20'), findsNothing);
        }

        // 商流 (+ helper caption)
        expect(find.text('商流'), findsOneWidget);
        expect(find.text('浅いほど条件が良い傾向'), findsOneWidget);
        expect(find.text(commercialFlowLabels[rows[0].commercialFlow]!), findsOneWidget);
        expect(find.text(commercialFlowLabels[rows[1].commercialFlow]!), findsOneWidget);

        // 面談回数
        expect(find.text('面談回数'), findsOneWidget);
        expect(find.text('1回'), findsOneWidget);
        expect(find.text('3回'), findsOneWidget);

        // 支払サイト (+ helper caption) — via paymentTermDaysById(clientId),
        // same as every other existing screen (project_detail_screen.dart,
        // project_list_screen.dart, engineer_detail_screen.dart), since the
        // underlying Project.paymentTermDays field is never populated by
        // ProjectGenerator.
        expect(find.text('支払サイト'), findsOneWidget);
        expect(find.text('短いほど早く入金される'), findsOneWidget);
        expect(find.text('${paymentTermDaysById('client-axis-soft')}日'), findsOneWidget);
        expect(find.text('${paymentTermDaysById('client-future-web')}日'), findsOneWidget);
        expect(paymentTermDaysById('client-axis-soft'), 30);
        expect(paymentTermDaysById('client-future-web'), 60);

        // 契約期間 — project.durationWeeks (the field GameEngine actually
        // assigns as the engagement's remainingWeeks), not
        // row.contractTermMonths (ProjectComparisonEngine's passthrough of
        // Project.contractTermMonths, which ProjectGenerator never
        // populates and which only feeds contract-renewal math elsewhere).
        expect(find.text('契約期間'), findsOneWidget);
        expect(find.text('${rows[0].project.durationWeeks}週間'), findsOneWidget);
        expect(find.text('${rows[1].project.durationWeeks}週間'), findsOneWidget);
        expect(find.text('24週間'), findsOneWidget);
        expect(find.text('12週間'), findsOneWidget);

        // No RenderFlex overflow at this width.
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ProjectComparisonScreen — 3案件比較', () {
    final fixture = _twoProjectFixture();
    final projectC = buildProject(
      id: 'cmp-project-c',
      clientId: 'client-nova-infra',
      title: '比較用案件C',
      rank: ProjectRank.middle,
      monthlyRate: 580000,
      requiredLanguages: const [ProgrammingLanguage.java],
      requiredBackend: 3,
      requiredJapaneseLevel: 3,
      commercialFlow: CommercialFlow.secondTier,
      durationWeeks: 36,
      interviewCount: 2,
    );
    final projects = [fixture.projectA, fixture.projectB, projectC];
    final rows = ProjectComparisonEngine.compare(engineer: fixture.engineer, projects: projects);

    for (final width in _widths) {
      testWidgets('renders three columns with no overflow at ${width}px', (tester) async {
        await _pumpScreen(tester, fixture.engineer, projects, width);

        expect(find.text('選択中案件 3/3件'), findsOneWidget);
        expect(find.text('比較用案件A'), findsOneWidget);
        expect(find.text('比較用案件B'), findsOneWidget);
        expect(find.text('比較用案件C'), findsOneWidget);

        for (final row in rows) {
          expect(find.text(formatYen(row.monthlyRate)), findsOneWidget);
        }
        expect(find.text('36週間'), findsOneWidget);
        expect(find.text('2回'), findsOneWidget);
        expect(find.text(commercialFlowLabels[CommercialFlow.secondTier]!), findsOneWidget);

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ProjectComparisonScreen — 選択中案件 n/合計件', () {
    testWidgets('totalCandidates renders as the denominator when more offers were available than were selected', (tester) async {
      final fixture = _twoProjectFixture();
      await _pumpScreen(
        tester,
        fixture.engineer,
        [fixture.projectA, fixture.projectB],
        390,
        totalCandidates: 3,
      );

      expect(find.text('選択中案件 2/3件'), findsOneWidget);
      expect(find.text('選択中案件 2/2件'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to the selected count as the denominator when totalCandidates is omitted', (tester) async {
      final fixture = _twoProjectFixture();
      await _pumpScreen(tester, fixture.engineer, [fixture.projectA, fixture.projectB], 390);

      expect(find.text('選択中案件 2/2件'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('showProjectComparisonScreen — BeginnerMilestone.projectComparisonUsed', () {
    testWidgets('is marked shown the first time the screen opens, and never rewritten on a later open', (tester) async {
      // GameEngine.newGame's two founding engineers/projects come from
      // fixed seeds regardless of the `seed` argument — deterministic
      // without threading a market seed through this test.
      final baseState = GameEngine.newGame().copyWith(gameMode: GameMode.beginner);
      SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(baseState.toJson())});
      final controller = GameController();

      final engineer = baseState.engineers.first;
      final projects = baseState.openProjects.take(2).map((e) => e.project).toList();
      expect(projects.length, 2);

      await tester.pumpWidget(
        GameScope(
          controller: controller,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showProjectComparisonScreen(context, engineer: engineer, projects: projects),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.state.beginnerModeState.has(BeginnerMilestone.projectComparisonUsed), isFalse);

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(controller.state.beginnerModeState.has(BeginnerMilestone.projectComparisonUsed), isTrue);
      expect(notifyCount, 1);
      expect(find.text('案件を比較'), findsOneWidget);

      // Navigate back to the trigger screen, then reopen — GameState must
      // not be rewritten a second time just because the player compared
      // again.
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(controller.state.beginnerModeState.has(BeginnerMilestone.projectComparisonUsed), isTrue);
      expect(notifyCount, 1);
    });

    testWidgets('never marks the milestone outside a Beginner Mode journey (Free Mode)', (tester) async {
      final baseState = GameEngine.newGame().copyWith(gameMode: GameMode.free);
      SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(baseState.toJson())});
      final controller = GameController();

      final engineer = baseState.engineers.first;
      final projects = baseState.openProjects.take(2).map((e) => e.project).toList();

      await tester.pumpWidget(
        GameScope(
          controller: controller,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showProjectComparisonScreen(context, engineer: engineer, projects: projects),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The comparison screen itself must still work in Free Mode (§3.3
      // implementation principle #6: comparison is usable, only the
      // milestone is Beginner-Mode-only).
      expect(find.text('案件を比較'), findsOneWidget);
      expect(controller.state.beginnerModeState.has(BeginnerMilestone.projectComparisonUsed), isFalse);
    });
  });
}
