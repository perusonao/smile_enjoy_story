// Phase 3B-1 (S.E.S. Development Plan §3.3, "案件を選ぶ"): FitReasonSheet
// must render the *existing* MatchingEngine.computeFit / FitBreakdown for a
// fixed engineer/project pair — total, the four sub-scores, and per-
// dimension 良い点/注意点 lines — without overflowing at the project's
// target mobile widths, and showFitReasonSheet must mark
// BeginnerMilestone.fitReasonViewed shown exactly once per playthrough, not
// on every open. Everything here uses hand-built, deterministic fixtures
// (buildEngineer/buildProject, GameEngine.newGame's fixed founder seeds) —
// no RNG-dependent assertions.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/app/game_scope.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/widgets/fit_reason_sheet.dart';
import 'package:smile_enjoy_story/ui/widgets/labels.dart';

import '../game/test_helpers.dart';

const _widths = [360.0, 390.0];

/// A hand-built engineer/project pair whose FitBreakdown is guaranteed
/// (deterministically, via the real MatchingEngine — never re-derived) to
/// produce both at least one 良い点 (excellent/good) detail and at least one
/// 注意点 (fair/poor) detail:
///  * Java skill 95 + Backend Lv.5 vs a Backend-Lv.5 requirement → language
///    + tech-domain details both ◎.
///  * 日本語 Lv.5 vs required Lv.3, コミュ力 5/5 → both ◎.
///  * Only 18 months of IT experience against a ProjectRank.middle
///    expectation of 36 months → 経験年数 lands at △/×.
({Engineer engineer, Project project}) _fitFixture() {
  final profile = buildApplicant(
    mainLanguage: ProgrammingLanguage.java,
    mainLanguageActualSkill: 95,
    totalItExperienceMonths: 18,
    japaneseLevel: 5,
    techSkills: const TechSkillLevels(
      database: 0,
      network: 0,
      infrastructure: 0,
      frontend: 0,
      backend: 5,
      leader: 0,
      manager: 0,
    ),
    personality: const PersonalityTraits(
      looks: 3,
      cleanliness: 3,
      communication: 5,
      alcoholTolerance: 3,
      seriousness: 3,
      dishonesty: 3,
    ),
  );
  final engineer = buildEngineer(id: 'fixture-engineer', profile: profile, salary: 500000);
  final project = buildProject(
    id: 'fixture-project',
    title: 'テスト案件フィクスチャ',
    rank: ProjectRank.middle,
    requiredLanguages: const [ProgrammingLanguage.java],
    requiredBackend: 5,
    requiredJapaneseLevel: 3,
  );
  return (engineer: engineer, project: project);
}

Future<void> _pumpSheet(WidgetTester tester, Engineer engineer, Project project, double width) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FitReasonSheet(engineer: engineer, project: project),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FitReasonSheet — shows the existing FitBreakdown, not a re-derived one', () {
    final fixture = _fitFixture();
    final expected = MatchingEngine.computeFit(fixture.engineer, fixture.project);

    for (final width in _widths) {
      testWidgets('renders 総合Fit + 内訳 + 良い点 + 注意点 with no overflow at ${width}px', (tester) async {
        await _pumpSheet(tester, fixture.engineer, fixture.project, width);

        // 1. 総合Fit
        expect(find.text('総合Fit'), findsOneWidget);
        expect(find.text('${expected.total}'), findsOneWidget);
        expect(find.text(PlayerVisibleFit.fromScore(expected.total).symbol), findsWidgets);

        // 2. Fit内訳 — the four existing FitBreakdown sub-scores (real
        // field names/weights 55/15/20/10, never UI-invented ones), shown
        // only as the bucketed ◎○△× rating — never the raw score/max
        // number, since 人物・相性 folds in the hidden
        // `projectInterviewSkill` alongside two *visible* traits, and an
        // exact fraction there would let a player back-solve a stat
        // `HiddenParameters` says is never shown (Codex review on PR #18).
        expect(find.text('Fit内訳'), findsOneWidget);
        expect(find.text('技術'), findsOneWidget);
        expect(find.text('経験'), findsOneWidget);
        expect(find.text('人物・相性'), findsOneWidget);
        expect(find.text('条件'), findsOneWidget);
        expect(find.textContaining('/'), findsNothing); // no raw "x / y" fraction anywhere in the sheet
        final techRating = PlayerVisibleFit.fromRaw(expected.techScore, 55);
        final experienceRating = PlayerVisibleFit.fromRaw(expected.experienceScore, 15);
        final personalityRating = PlayerVisibleFit.fromRaw(expected.personalityScore, 20);
        final conditionRating = PlayerVisibleFit.fromRaw(expected.conditionScore, 10);
        for (final rating in [techRating, experienceRating, personalityRating, conditionRating]) {
          expect(find.text(rating.label), findsWidgets);
        }

        // 3. 良い点 — this fixture's language/tech-domain/communication/
        // Japanese details are all ◎, so at least one positive line exists.
        expect(find.text('良い点'), findsOneWidget);
        final goodDetail = expected.details.firstWhere(
          (d) => d.rating == PlayerVisibleFit.excellent || d.rating == PlayerVisibleFit.good,
        );
        expect(find.text('・${fitDetailLabel(goodDetail)}: ${goodDetail.rating.symbol} ${goodDetail.rating.label}'), findsOneWidget);

        // 4. 注意点 — this fixture's 経験年数 detail is deliberately weak
        // (18mo actual vs a 36mo middle-rank expectation) so it exists too.
        final cautionDetail = expected.details.firstWhere(
          (d) => d.rating == PlayerVisibleFit.fair || d.rating == PlayerVisibleFit.poor,
        );
        expect(find.text('注意点'), findsOneWidget);
        expect(find.text('・${fitDetailLabel(cautionDetail)}: ${cautionDetail.rating.symbol} ${cautionDetail.rating.label}'), findsOneWidget);

        // 5/6. No RenderFlex overflow at this width.
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('注意点 section is absent when every detail is positive', (tester) async {
      // A second fixture tuned so every FitDetailItem rating is ◎/○ — the
      // 注意点 header must not render at all rather than an empty one.
      final profile = buildApplicant(
        mainLanguage: ProgrammingLanguage.java,
        mainLanguageActualSkill: 95,
        totalItExperienceMonths: 80,
        japaneseLevel: 5,
        techSkills: const TechSkillLevels(
          database: 0,
          network: 0,
          infrastructure: 0,
          frontend: 0,
          backend: 5,
          leader: 0,
          manager: 0,
        ),
        personality: const PersonalityTraits(
          looks: 3,
          cleanliness: 5,
          communication: 5,
          alcoholTolerance: 3,
          seriousness: 3,
          dishonesty: 3,
        ),
        hidden: const HiddenParameters(
          growthPotential: 3,
          stressTolerance: 3,
          retention: 3,
          projectInterviewSkill: 5,
          turnoverIntent: 30,
        ),
      );
      final engineer = buildEngineer(id: 'all-good-engineer', profile: profile, salary: 500000);
      final project = buildProject(
        id: 'all-good-project',
        rank: ProjectRank.entry,
        requiredLanguages: const [ProgrammingLanguage.java],
        requiredBackend: 5,
        requiredJapaneseLevel: 3,
      );
      final expected = MatchingEngine.computeFit(engineer, project);
      expect(expected.details.every((d) => d.rating == PlayerVisibleFit.excellent || d.rating == PlayerVisibleFit.good), isTrue);

      await _pumpSheet(tester, engineer, project, 390);

      expect(find.text('良い点'), findsOneWidget);
      expect(find.text('注意点'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('showFitReasonSheet — BeginnerMilestone.fitReasonViewed', () {
    testWidgets('is marked shown the first time the sheet opens, and never rewritten on a later open', (tester) async {
      // GameEngine.newGame's two founding engineers/projects come from
      // fixed seeds regardless of the `seed` argument (game_engine.dart's
      // founderApplicantSeed/founderProjectSeed) — deterministic without
      // needing to thread a market seed through this test at all.
      final baseState = GameEngine.newGame().copyWith(gameMode: GameMode.beginner);
      SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(baseState.toJson())});
      final controller = GameController();

      final engineer = baseState.engineers.first;
      final project = baseState.openProjects.first.project;

      await tester.pumpWidget(
        GameScope(
          controller: controller,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showFitReasonSheet(context, engineer: engineer, project: project),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.state.beginnerModeState.has(BeginnerMilestone.fitReasonViewed), isFalse);

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(controller.state.beginnerModeState.has(BeginnerMilestone.fitReasonViewed), isTrue);
      expect(notifyCount, 1);

      // Dismiss the sheet (tap the modal barrier above it) and reopen —
      // GameState must not be rewritten a second time just because the
      // player looked at the sheet again.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(controller.state.beginnerModeState.has(BeginnerMilestone.fitReasonViewed), isTrue);
      expect(notifyCount, 1);
    });

    testWidgets('never marks the milestone outside a Beginner Mode journey (Free Mode)', (tester) async {
      final baseState = GameEngine.newGame().copyWith(gameMode: GameMode.free);
      SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(baseState.toJson())});
      final controller = GameController();

      final engineer = baseState.engineers.first;
      final project = baseState.openProjects.first.project;

      await tester.pumpWidget(
        GameScope(
          controller: controller,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showFitReasonSheet(context, engineer: engineer, project: project),
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

      expect(controller.state.beginnerModeState.has(BeginnerMilestone.fitReasonViewed), isFalse);
    });
  });
}
