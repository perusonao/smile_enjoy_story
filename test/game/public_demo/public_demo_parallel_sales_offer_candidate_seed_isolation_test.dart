import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_offer_candidate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';

/// Reproduction for a suspected bug found during PR #258 Claude Broad
/// Review: proposing a SECOND project (via the real `proposeMatch` /
/// `withMatchingProposal` production path) for an engineer whose legacy
/// `PublicDemoEngineerSales.stage` has already advanced past `proposed`
/// (e.g. via a genuine partner-interview pass for a DIFFERENT, first
/// project) seeds the brand-new candidate directly at that SAME advanced
/// stage/score, rather than at `proposed`.
void main() {
  PublicDemoEngineerSales engineer(PublicDemoAggregate aggregate, String id) =>
      aggregate.workflow.engineers.firstWhere((e) => e.id == id);

  PublicDemoAggregate advanceToIntroduced(
    PublicDemoAggregate aggregate,
    String engineerId,
  ) => aggregate
      .startSkillSheetReview(engineerId)
      .beginSelling(engineerId)
      .introduceProject(engineerId);

  PublicDemoAggregate runPartnerInterviewToConclusion(
    PublicDemoAggregate aggregate,
    String engineerId,
  ) {
    aggregate = aggregate.startPartnerInterview(engineerId);
    var session = aggregate.projectInterviewSessionFor(engineerId)!;
    while (session.playerFollowUps.length < session.questions.length) {
      final choice = PublicDemoProjectInterview.choicesFor(session).first;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        engineerId,
        session.currentQuestionIndex,
        choice,
      );
      session = aggregate.projectInterviewSessionFor(engineerId)!;
    }
    return aggregate.concludePartnerInterview(engineerId);
  }

  test(
    'REPRO: proposing project B for an engineer who already genuinely '
    'passed the PARTNER interview for project A seeds candidate B '
    'already at partnerInterviewPassed, skipping its own partner '
    'interview entirely (cross-project stage/score leakage)',
    () {
      PublicDemoAggregate? found;
      String? projA;
      String? projB;
      for (var seed = 0; seed < 60; seed++) {
        var aggregate = PublicDemoAggregate.initial(runSeed: seed);
        final projects = aggregate.projectCandidatesForMonth(4);
        final projectA = projects[0];
        final projectB = projects[1];
        aggregate = aggregate.proposeMatch(
          engineerId: 'eng-01',
          projectId: projectA.id,
        );
        aggregate = advanceToIntroduced(aggregate, 'eng-01');
        aggregate = runPartnerInterviewToConclusion(aggregate, 'eng-01');
        if (engineer(aggregate, 'eng-01').stage !=
            PublicDemoSalesStage.partnerInterviewPassed) {
          continue;
        }
        found = aggregate;
        projA = projectA.id;
        projB = projectB.id;
        break;
      }
      expect(found, isNotNull, reason: 'need a genuine partner pass seed');
      var aggregate = found!;

      // Sanity: candidate A really did pass its own partner interview.
      final candidateABefore = aggregate.offerCandidateFor('eng-01', projA!);
      expect(
        candidateABefore!.stage,
        PublicDemoOfferCandidateStage.partnerInterviewPassed,
      );

      // Now propose the SAME engineer for a brand-new, never-interviewed
      // project B via the real production proposeMatch path.
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projB!,
      );

      final candidateB = aggregate.offerCandidateFor('eng-01', projB);

      // EXPECTED (correct) behavior: candidate B, never interviewed for
      // itself, should start at `proposed`.
      expect(
        candidateB!.stage,
        PublicDemoOfferCandidateStage.proposed,
        reason:
            'candidate B must start at `proposed` since ITS OWN partner '
            'interview was never conducted — if this fails, candidate B '
            'inherited an unrelated project\'s genuine interview outcome',
      );
    },
  );
}
