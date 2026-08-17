// Phase 3B-1 (S.E.S. Development Plan §3.3 "案件を選ぶ"): ProjectComparisonEngine
// is a pure, deterministic wrapper around the existing MatchingEngine
// (computeFit/monthlyProfit) — this suite verifies it never re-derives or
// re-weights Fit/profit on its own, and that every "derived, not duplicated"
// getter on ProjectComparisonRow actually reads through to the same
// Project/FitBreakdown values instead of storing a second copy. No UI is
// exercised here (Phase 3B-1's comparison/Fit-reason screens are later PRs).
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

void main() {
  group('Phase 3B-1 — ProjectComparisonEngine reuses MatchingEngine exactly', () {
    test('rowFor returns the identical FitBreakdown MatchingEngine.computeFit would', () {
      final engineer = buildEngineer(salary: 500000);
      final project = buildProject(monthlyRate: 700000);

      final expected = MatchingEngine.computeFit(engineer, project);
      final row = ProjectComparisonEngine.rowFor(engineer, project);

      expect(row.fit.total, expected.total);
      expect(row.totalFit, expected.total);
      expect(row.techFit, expected.techScore);
      expect(row.experienceFit, expected.experienceScore);
      expect(row.personalityFit, expected.personalityScore);
      expect(row.conditionFit, expected.conditionScore);
      // Fit理由: the exact same per-dimension detail list, not a
      // re-derived/re-summarized one.
      expect(row.fitReasons.length, expected.details.length);
      for (var i = 0; i < expected.details.length; i++) {
        expect(row.fitReasons[i].dimension, expected.details[i].dimension);
        expect(row.fitReasons[i].rating, expected.details[i].rating);
      }
    });

    test('visibleFit-equivalent total score is unaffected by comparison (scoring weights unchanged)', () {
      final profile = buildApplicant(
        mainLanguageActualSkill: 80,
        techSkills: const TechSkillLevels(database: 0, network: 0, infrastructure: 0, frontend: 0, backend: 4, leader: 0, manager: 0),
      );
      final engineer = buildEngineer(salary: 450000, profile: profile);
      final project = buildProject(monthlyRate: 650000, requiredBackend: 4);

      final direct = MatchingEngine.visibleFit(engineer, project);
      final viaRow = PlayerVisibleFit.fromScore(ProjectComparisonEngine.rowFor(engineer, project).totalFit);
      expect(viaRow, direct);
    });

    test('compare() builds one row per project, in the same order, each matching computeFit individually', () {
      final engineer = buildEngineer(salary: 480000);
      final projects = [
        buildProject(id: 'p1', monthlyRate: 600000),
        buildProject(id: 'p2', monthlyRate: 750000, requiredBackend: 5),
        buildProject(id: 'p3', monthlyRate: 500000, requiredFrontend: 3),
      ];

      final rows = ProjectComparisonEngine.compare(engineer: engineer, projects: projects);

      expect(rows.length, 3);
      for (var i = 0; i < projects.length; i++) {
        expect(rows[i].project.id, projects[i].id);
        expect(rows[i].totalFit, MatchingEngine.computeFit(engineer, projects[i]).total);
      }
    });
  });

  group('Phase 3B-1 — 粗利 / 粗利率', () {
    test('monthlyProfit == monthlyRate - salary, matching MatchingEngine.monthlyProfit exactly', () {
      final engineer = buildEngineer(salary: 420000);
      final project = buildProject(monthlyRate: 680000);

      final row = ProjectComparisonEngine.rowFor(engineer, project);

      expect(row.monthlyProfit, 680000 - 420000);
      expect(row.monthlyProfit, MatchingEngine.monthlyProfit(engineer, project));
    });

    test('grossMarginRate == monthlyProfit / monthlyRate', () {
      final engineer = buildEngineer(salary: 400000);
      final project = buildProject(monthlyRate: 800000);

      final row = ProjectComparisonEngine.rowFor(engineer, project);

      expect(row.grossMarginRate, closeTo(0.5, 1e-9));
      expect(row.grossMarginRate, row.monthlyProfit / row.monthlyRate);
    });

    test('a below-cost assignment produces a negative profit and margin rather than clamping', () {
      final engineer = buildEngineer(salary: 900000);
      final project = buildProject(monthlyRate: 600000);

      final row = ProjectComparisonEngine.rowFor(engineer, project);

      expect(row.monthlyProfit, -300000);
      expect(row.grossMarginRate, lessThan(0));
    });
  });

  group('Phase 3B-1 — 商流/面談回数/支払サイト/契約期間 match Project exactly', () {
    test('every condition field on the row is a passthrough of the same Project value', () {
      final engineer = buildEngineer();
      final project = Project(
        id: 'condition-check',
        clientId: 'client-x',
        title: '条件確認用案件',
        type: ProjectType.webBackend,
        rank: ProjectRank.middle,
        monthlyRate: 720000,
        durationWeeks: 24,
        applicationDeadlineWeek: 10,
        requiredLanguages: const [ProgrammingLanguage.java],
        requiredDatabase: 0,
        requiredNetwork: 0,
        requiredInfrastructure: 0,
        requiredFrontend: 0,
        requiredBackend: 2,
        requiredLeader: 0,
        requiredManager: 0,
        requiredJapaneseLevel: 3,
        remotePolicy: RemotePolicy.hybrid,
        interviewCount: 2,
        difficulty: 3,
        commercialFlow: CommercialFlow.firstTier,
        paymentTermDays: 60,
        contractTermMonths: 6,
      );

      final row = ProjectComparisonEngine.rowFor(engineer, project);

      expect(row.commercialFlow, CommercialFlow.firstTier);
      expect(row.commercialFlow, project.commercialFlow);
      expect(row.interviewCount, 2);
      expect(row.interviewCount, project.interviewCount);
      expect(row.paymentTermDays, 60);
      expect(row.paymentTermDays, project.paymentTermDays);
      expect(row.contractTermMonths, 6);
      expect(row.contractTermMonths, project.contractTermMonths);
      expect(row.monthlyRate, project.monthlyRate);
    });
  });
}
