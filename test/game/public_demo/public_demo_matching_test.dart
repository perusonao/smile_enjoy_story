import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/models/fit_result.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_matching_fit.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';

/// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): coverage for
/// [PublicDemoEngineerProjectFit] (the [MatchingEngine.computeFit] reuse
/// adapter), [PublicDemoMatchingProspect], and the
/// [PublicDemoAggregate]/[PublicDemoWorkflowState] proposal handoff. See
/// docs/reports/SES_CORE-GAMEPLAY_Phase5_Matching_Result.md.
void main() {
  group('PublicDemoEngineerProjectFit.compute', () {
    test('is deterministic for the same (runtime, project) pair', () {
      final runtime = publicDemoInitialEngineerRuntimes.first; // eng-01, Java
      final project = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 42,
        month: 4,
      ).first.project;

      final first = PublicDemoEngineerProjectFit.compute(
        runtime: runtime,
        project: project,
      );
      final second = PublicDemoEngineerProjectFit.compute(
        runtime: runtime,
        project: project,
      );

      expect(
        first.visibleDetails.map((d) => d.rating).toList(),
        second.visibleDetails.map((d) => d.rating).toList(),
      );
      expect(first.prospect, second.prospect);
    });

    test('never exposes a communication/japanese (personality/condition) '
        'detail — only language/techDomain/experience', () {
      final runtime = publicDemoInitialEngineerRuntimes.first;
      for (final candidate in PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 7,
        month: 4,
        count: 4,
      )) {
        final fit = PublicDemoEngineerProjectFit.compute(
          runtime: runtime,
          project: candidate.project,
        );
        for (final item in fit.visibleDetails) {
          expect(
            item.dimension,
            anyOf(
              FitDimension.language,
              FitDimension.techDomain,
              FitDimension.experience,
            ),
          );
        }
      }
    });

    test('changing the engineer\'s hidden projectInterviewSkill never '
        'changes the visible details or prospect (it only feeds the '
        'personality dimension, which is never surfaced)', () {
      final project = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 3,
        month: 4,
      ).first.project;
      final base = publicDemoInitialEngineerRuntimes.first;
      final variant = base.copyWith(
        hidden: const HiddenParameters(
          growthPotential: 1,
          stressTolerance: 1,
          retention: 1,
          projectInterviewSkill: 1,
          turnoverIntent: 99,
        ),
      );

      final baseFit = PublicDemoEngineerProjectFit.compute(
        runtime: base,
        project: project,
      );
      final variantFit = PublicDemoEngineerProjectFit.compute(
        runtime: variant,
        project: project,
      );

      expect(
        variantFit.visibleDetails.map((d) => d.rating).toList(),
        baseFit.visibleDetails.map((d) => d.rating).toList(),
      );
      expect(variantFit.prospect, baseFit.prospect);
    });

    test('reads only the confirmed primary-language experience — an '
        'unconfirmed capability entry is never treated as real language '
        'experience', () {
      // Mirrors PublicDemoEngineerRuntime.fromApplicant's own "experienced
      // hire" branch: a seeded java capability entry that is deliberately
      // NOT in confirmedLanguages.
      final runtime = PublicDemoEngineerRuntime(
        engineerId: 'eng-99',
        primaryLanguage: ProgrammingLanguage.java,
        languageSkills: {
          ProgrammingLanguage.java: const LanguageSkill(
            language: ProgrammingLanguage.java,
            displayedExperienceMonths: 0,
            actualExperienceMonths: 0,
            actualSkill: 80,
          ),
        },
        techSkills: const TechSkillLevels.zero(),
        hidden: const HiddenParameters(
          growthPotential: 3,
          stressTolerance: 3,
          retention: 3,
          projectInterviewSkill: 3,
          turnoverIntent: 50,
        ),
        // confirmedLanguages left at its default ({}) — unconfirmed.
      );
      final project = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 1,
        month: 4,
      ).first.project;

      final fit = PublicDemoEngineerProjectFit.compute(
        runtime: runtime,
        project: project,
      );

      final languageDetail = fit.visibleDetails
          .where((d) => d.dimension == FitDimension.language)
          .toList();
      // No confirmed language experience at all -> whatever project
      // language is required, this engineer shows as unmatched (poor), not
      // as if the unconfirmed actualSkill:80 proxy were real Java mastery.
      if (languageDetail.isNotEmpty) {
        expect(languageDetail.single.rating, PlayerVisibleFit.poor);
      }
    });
  });

  group('PublicDemoMatchingProspect.fromDetails', () {
    FitDetailItem detail(PlayerVisibleFit rating) => FitDetailItem(
      dimension: FitDimension.experience,
      rating: rating,
    );

    test('empty details -> medium (no truthful signal to judge by)', () {
      expect(
        PublicDemoMatchingProspect.fromDetails(const []),
        PublicDemoMatchingProspect.medium,
      );
    });

    test('all excellent/good -> high', () {
      expect(
        PublicDemoMatchingProspect.fromDetails([
          detail(PlayerVisibleFit.excellent),
          detail(PlayerVisibleFit.good),
        ]),
        PublicDemoMatchingProspect.high,
      );
    });

    test('any poor -> low, even alongside excellent', () {
      expect(
        PublicDemoMatchingProspect.fromDetails([
          detail(PlayerVisibleFit.excellent),
          detail(PlayerVisibleFit.poor),
        ]),
        PublicDemoMatchingProspect.low,
      );
    });

    test('a fair mixed in with good, no poor -> medium', () {
      expect(
        PublicDemoMatchingProspect.fromDetails([
          detail(PlayerVisibleFit.good),
          detail(PlayerVisibleFit.fair),
        ]),
        PublicDemoMatchingProspect.medium,
      );
    });
  });

  group('PublicDemoAggregate matching proposal handoff', () {
    test('availableEngineersForMatching lists both founding engineers '
        'before anyone is assigned', () {
      final aggregate = PublicDemoAggregate.initial();
      expect(
        aggregate.availableEngineersForMatching.map((e) => e.id).toSet(),
        {'eng-01', 'eng-02'},
      );
    });

    test('availableEngineersForMatching excludes an engineer actually '
        'staffed on a project', () {
      var aggregate = publicDemoAggregateAtMonth(4);
      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      aggregate = aggregate.closeApril(monthlyExpenses: 10000);
      aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 10000);
      expect(aggregate.workflow.assignments, hasLength(1));

      expect(
        aggregate.availableEngineersForMatching.map((e) => e.id).toSet(),
        {'eng-02'},
      );
    });

    test('proposeMatch records a proposal resolvable via matchingProposalFor', () {
      final aggregate = PublicDemoAggregate.initial();
      final candidate = aggregate.projectCandidatesForMonth(4).first;

      final next = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidate.id,
      );

      final proposal = next.matchingProposalFor('eng-01');
      expect(proposal, isNotNull);
      expect(proposal!.projectId, candidate.id);
      expect(proposal.decidedMonth, 4);
      // The other engineer is untouched.
      expect(next.matchingProposalFor('eng-02'), isNull);
    });

    test('a later proposeMatch for the same engineer replaces the earlier '
        'one rather than accumulating', () {
      final aggregate = PublicDemoAggregate.initial();
      final candidates = aggregate.projectCandidatesForMonth(4, count: 2);

      final afterFirst = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidates[0].id,
      );
      final afterSecond = afterFirst.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidates[1].id,
      );

      expect(afterSecond.workflow.matchingProposals, hasLength(1));
      expect(
        afterSecond.matchingProposalFor('eng-01')!.projectId,
        candidates[1].id,
      );
    });

    test('proposeMatch is a no-op for a fabricated project id', () {
      final aggregate = PublicDemoAggregate.initial();
      final next = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: 'not-a-real-project-id',
      );
      expect(next.matchingProposalFor('eng-01'), isNull);
      expect(next.workflow.matchingProposals, isEmpty);
    });

    test('proposeMatch is a no-op for an unknown engineer id', () {
      final aggregate = PublicDemoAggregate.initial();
      final candidate = aggregate.projectCandidatesForMonth(4).first;
      final next = aggregate.proposeMatch(
        engineerId: 'not-a-real-engineer',
        projectId: candidate.id,
      );
      expect(next.workflow.matchingProposals, isEmpty);
    });

    test('proposeMatch is a no-op for an engineer already staffed '
        'elsewhere this month', () {
      var aggregate = publicDemoAggregateAtMonth(4);
      aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
      aggregate = aggregate.closeApril(monthlyExpenses: 10000);
      aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 10000);
      final candidate = aggregate.projectCandidatesForMonth(
        aggregate.state.month,
      ).first;

      final next = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidate.id,
      );

      expect(next.matchingProposalFor('eng-01'), isNull);
    });
  });

  group('PublicDemoWorkflowState matchingProposals persistence', () {
    test('toJson/fromJson round-trips proposals', () {
      final workflow = PublicDemoWorkflowState.initial().withMatchingProposal(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );
      final restored = PublicDemoWorkflowState.fromJson(workflow.toJson());
      expect(restored.matchingProposals, hasLength(1));
      expect(restored.matchingProposals.single.engineerId, 'eng-01');
      expect(restored.matchingProposals.single.projectId, 'project-4-1');
      expect(restored.matchingProposals.single.decidedMonth, 4);
    });

    test('a legacy save with no matchingProposals key decodes to an empty '
        'list rather than failing', () {
      final legacyJson = PublicDemoWorkflowState.initial().toJson()
        ..remove('matchingProposals');
      final restored = PublicDemoWorkflowState.fromJson(legacyJson);
      expect(restored.matchingProposals, isEmpty);
    });
  });
}
