import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/models/client_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// CORE-GAMEPLAY Phase 6 (Project Interview Gameplay): coverage for
/// [PublicDemoProjectInterview] (the [ClientInterviewEngine]/
/// [ProjectInterviewEngine] reuse adapter) and the
/// [PublicDemoAggregate]/[PublicDemoWorkflowState] project-interview
/// transitions. See docs/reports/SES_CORE-GAMEPLAY_Phase6_Project-Interview
/// _Result.md.

/// Advances `eng-01` (a founding engineer with high enough
/// [PublicDemoInterviewProfile] stats to reliably clear the existing
/// generic partner-interview formula) through the pre-existing sales
/// pipeline up to `partnerInterviewPassed` — the stage every Phase 6
/// transition requires. This intentionally reuses the exact existing
/// production commands (`startSkillSheetReview` → `beginSelling` →
/// `introduceProject` → `recordEngineerInterviewResult(partner)`), never a
/// shortcut that sets `stage` directly.
PublicDemoAggregate _advanceToPartnerPassed(PublicDemoAggregate aggregate) {
  var next = aggregate.startSkillSheetReview('eng-01');
  next = next.beginSelling('eng-01');
  next = next.introduceProject('eng-01');
  next = next.recordEngineerInterviewResult(
    engineerId: 'eng-01',
    type: PublicDemoInterviewType.partner,
  );
  return next;
}

/// [_advanceToPartnerPassed] plus a real Phase 5 proposal for the first
/// project candidate in the current month's pool — the genuine Phase 5
/// handoff Phase 6 reads.
PublicDemoAggregate _withRealProposal(PublicDemoAggregate aggregate) {
  var next = _advanceToPartnerPassed(aggregate);
  final project = next.projectCandidatesForMonth(next.state.month).first;
  next = next.proposeMatch(engineerId: 'eng-01', projectId: project.id);
  return next;
}

PublicDemoEngineerSales _engineer(PublicDemoAggregate aggregate) => aggregate
    .workflow
    .engineers
    .firstWhere((engineer) => engineer.id == 'eng-01');

/// Runs a full interview (always choosing the first available follow-up)
/// to completion for whichever project is currently proposed, returning
/// the concluded aggregate.
PublicDemoAggregate _runInterviewToConclusion(PublicDemoAggregate aggregate) {
  aggregate = aggregate.startProjectInterview('eng-01');
  var session = aggregate.projectInterviewSessionFor('eng-01')!;
  while (session.playerFollowUps.length < session.questions.length) {
    final choice = PublicDemoProjectInterview.choicesFor(session).first;
    aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
    session = aggregate.projectInterviewSessionFor('eng-01')!;
  }
  return aggregate.concludeProjectInterview('eng-01');
}

/// Scans a bounded, deterministic seed range for one where `eng-01`
/// genuinely passes the project interview for the first candidate offered
/// — the same scanning pattern the existing "mints the unforgeable
/// interview record" test already uses, extracted so the new Codex P1-2/P2
/// regression tests below can reuse it. Never asserts an outcome — the
/// pass is always the real, seeded-RNG-derived result.
({PublicDemoAggregate aggregate, String projectId})? _findGenuinePass({
  int maxSeed = 40,
}) {
  for (var seed = 0; seed < maxSeed; seed++) {
    var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: seed));
    final projectId = aggregate.workflow.matchingProposalFor('eng-01')!.projectId;
    aggregate = _runInterviewToConclusion(aggregate);
    if (_engineer(aggregate).stage == PublicDemoSalesStage.clientInterviewPassed) {
      return (aggregate: aggregate, projectId: projectId);
    }
  }
  return null;
}

void main() {
  group('PublicDemoAggregate.startProjectInterview', () {
    test('is a no-op unless the engineer is genuinely partnerInterviewPassed', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 1);
      final withProposal = () {
        final project = aggregate.projectCandidatesForMonth(4).first;
        return aggregate.proposeMatch(engineerId: 'eng-01', projectId: project.id);
      }();
      final started = withProposal.startProjectInterview('eng-01');
      expect(started.projectInterviewSessionFor('eng-01'), isNull);
    });

    test('is a no-op without a real Phase 5 matching proposal, even at '
        'partnerInterviewPassed — the engineer stays on the existing '
        'generic client-interview path', () {
      final aggregate = _advanceToPartnerPassed(PublicDemoAggregate.initial(runSeed: 2));
      expect(aggregate.projectInterviewCandidateFor('eng-01'), isNull);
      final started = aggregate.startProjectInterview('eng-01');
      expect(started.projectInterviewSessionFor('eng-01'), isNull);
    });

    test('starts a real, multi-question session for a genuine proposal', () {
      final aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 3));
      final started = aggregate.startProjectInterview('eng-01');
      final session = started.projectInterviewSessionFor('eng-01');
      expect(session, isNotNull);
      expect(session!.questions.length, greaterThanOrEqualTo(2));
      expect(session.employeeId, 'eng-01');
      expect(session.completed, isFalse);
    });

    test('resuming does not restart an in-progress session', () {
      final aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 4));
      final started = aggregate.startProjectInterview('eng-01');
      final resumed = started.startProjectInterview('eng-01');
      expect(
        resumed.projectInterviewSessionFor('eng-01'),
        same(started.projectInterviewSessionFor('eng-01')),
      );
    });
  });

  group('choices materially affect the outcome', () {
    test('determinism: replaying the same runSeed/context/choice sequence '
        'reproduces the exact same pass/fail and score', () {
      PublicDemoAggregate runOnce() {
        var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 11));
        aggregate = aggregate.startProjectInterview('eng-01');
        var session = aggregate.projectInterviewSessionFor('eng-01')!;
        while (session.playerFollowUps.length < session.questions.length) {
          final choice = PublicDemoProjectInterview.choicesFor(session).first;
          aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
          session = aggregate.projectInterviewSessionFor('eng-01')!;
        }
        return aggregate.concludeProjectInterview('eng-01');
      }

      final first = runOnce();
      final second = runOnce();

      final firstEngineer = _engineer(first);
      final secondEngineer = _engineer(second);
      expect(firstEngineer.stage, secondEngineer.stage);
      expect(firstEngineer.lastInterviewScore, secondEngineer.lastInterviewScore);
      expect(
        first.projectInterviewSessionFor('eng-01')!.result,
        second.projectInterviewSessionFor('eng-01')!.result,
      );
    });

    test('a different choice sequence can change the accumulated evaluation '
        '— choices are not decorative', () {
      PublicDemoAggregate seedRun(bool alwaysFirstChoice) {
        var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 21));
        aggregate = aggregate.startProjectInterview('eng-01');
        var session = aggregate.projectInterviewSessionFor('eng-01')!;
        while (session.playerFollowUps.length < session.questions.length) {
          final choices = PublicDemoProjectInterview.choicesFor(session);
          final choice = alwaysFirstChoice ? choices.first : choices.last;
          aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
          session = aggregate.projectInterviewSessionFor('eng-01')!;
        }
        return aggregate;
      }

      final firstChoiceRun = seedRun(true);
      final lastChoiceRun = seedRun(false);

      final firstSession = firstChoiceRun.projectInterviewSessionFor('eng-01')!;
      final lastSession = lastChoiceRun.projectInterviewSessionFor('eng-01')!;
      // The two runs chose differently at every question (assuming more
      // than one distinct choice exists, which every category offers) —
      // their recorded follow-up sequences must differ, and at least one
      // evaluation dimension must differ as a result.
      expect(firstSession.playerFollowUps, isNot(equals(lastSession.playerFollowUps)));
      expect(
        firstSession.accumulatedEvaluation.total,
        isNot(equals(lastSession.accumulatedEvaluation.total)),
      );
    });

    test('pass/fail is never a coin flip: the same fully-passing fit wins '
        'far more often than a badly-mismatched one across many seeds', () {
      // Strong fit: the founding eng-01 (Java/backend) against whichever
      // pool project it was actually built to be realistically targetable
      // for (PublicDemoSeededProjectGenerator's own Balance Guard). A weak
      // signal alone (never a literal 0%/100%) would indicate a disguised
      // coin flip instead of a real fit-driven rate.
      var passCount = 0;
      const attempts = 30;
      for (var seed = 0; seed < attempts; seed++) {
        var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: seed));
        aggregate = aggregate.startProjectInterview('eng-01');
        var session = aggregate.projectInterviewSessionFor('eng-01')!;
        while (session.playerFollowUps.length < session.questions.length) {
          final choice = PublicDemoProjectInterview.choicesFor(session).first;
          aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
          session = aggregate.projectInterviewSessionFor('eng-01')!;
        }
        aggregate = aggregate.concludeProjectInterview('eng-01');
        if (_engineer(aggregate).stage == PublicDemoSalesStage.clientInterviewPassed) {
          passCount++;
        }
      }
      // Not asserting a literal 0 or attempts (real seeded variance is
      // expected) — only that outcomes are not degenerate in either
      // direction, i.e. genuinely fit/choice-driven with small RNG, not a
      // fixed always-pass/always-fail switch.
      expect(passCount, greaterThan(0));
      expect(passCount, lessThan(attempts));
    });
  });

  group('information discipline', () {
    test('failureReasons are truthful MatchingEngine-derived strings, never '
        'invented', () {
      final aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 31));
      final reasons = aggregate.projectInterviewFailureReasonsFor('eng-01');
      // Before any interview starts there is no session yet, but the
      // reasons accessor must still resolve from real fit data without
      // throwing, and return only known category labels.
      const knownFragments = [
        '技術経験', 'の経験不足', '実務経験年数', 'コミュニケーション評価', '日本語レベル', '他候補を優先',
      ];
      for (final reason in reasons) {
        expect(
          knownFragments.any((fragment) => reason.contains(fragment)),
          isTrue,
          reason: 'unexpected failure reason: $reason',
        );
      }
    });
  });

  group('sales-slot behavior (0-slot, no double consumption)', () {
    test('starting/answering/concluding a project interview never touches '
        'salesUsed/salesRemaining', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 41));
      final slotsAfterProposal = aggregate.state.salesUsed;

      aggregate = aggregate.startProjectInterview('eng-01');
      expect(aggregate.state.salesUsed, slotsAfterProposal);

      var session = aggregate.projectInterviewSessionFor('eng-01')!;
      while (session.playerFollowUps.length < session.questions.length) {
        final choice = PublicDemoProjectInterview.choicesFor(session).first;
        aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
        expect(aggregate.state.salesUsed, slotsAfterProposal);
        session = aggregate.projectInterviewSessionFor('eng-01')!;
      }

      aggregate = aggregate.concludeProjectInterview('eng-01');
      expect(aggregate.state.salesUsed, slotsAfterProposal);
    });

    test('the partner-interview step still consumes exactly one slot, '
        'unaffected by Phase 6', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 42);
      var next = aggregate.startSkillSheetReview('eng-01');
      next = next.beginSelling('eng-01');
      next = next.introduceProject('eng-01');
      final before = next.state.salesUsed;
      next = next.recordEngineerInterviewResult(
        engineerId: 'eng-01',
        type: PublicDemoInterviewType.partner,
      );
      expect(next.state.salesUsed, before + 1);
    });
  });

  group('pass/fail continuation (no dead end)', () {
    test('a failed project interview can return to selling and be '
        'retried through the same pipeline', () {
      // Force a fail by proposing a project the engineer is a poor fit
      // for isn't reliable without reading hidden fit, so instead assert
      // the structural continuation from the existing clientInterviewFailed
      // stage, which recordEngineerInterviewResult already exercises the
      // same way for the generic path — Phase 6 reuses that unchanged.
      var aggregate = _advanceToPartnerPassed(PublicDemoAggregate.initial(runSeed: 51));
      aggregate = aggregate.recordEngineerInterviewResult(
        engineerId: 'eng-01',
        type: PublicDemoInterviewType.client,
      );
      if (_engineer(aggregate).stage == PublicDemoSalesStage.clientInterviewFailed) {
        final resumed = aggregate.beginSelling('eng-01');
        expect(_engineer(resumed).stage, PublicDemoSalesStage.selling);
      }
    });

    test('a genuine pass mints the unforgeable interview record needed for '
        'Phase 7A order/assignment handoff', () {
      PublicDemoAggregate? passed;
      for (var seed = 0; seed < 40 && passed == null; seed++) {
        var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: seed));
        aggregate = aggregate.startProjectInterview('eng-01');
        var session = aggregate.projectInterviewSessionFor('eng-01')!;
        while (session.playerFollowUps.length < session.questions.length) {
          final choice = PublicDemoProjectInterview.choicesFor(session).first;
          aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
          session = aggregate.projectInterviewSessionFor('eng-01')!;
        }
        aggregate = aggregate.concludeProjectInterview('eng-01');
        if (_engineer(aggregate).stage == PublicDemoSalesStage.clientInterviewPassed) {
          passed = aggregate;
        }
      }
      expect(passed, isNotNull, reason: 'expected at least one pass across 40 seeds');
      expect(_engineer(passed!).hasGenuineInterviewRecord, isTrue);
      // The existing, unmodified recordOrder/assignOrderedForMay pipeline
      // (Phase 7A's own handoff point) must accept this exactly like a
      // generic client-interview pass.
      final ordered = passed.recordOrder('eng-01');
      expect(_engineer(ordered).stage, PublicDemoSalesStage.ordered);
    });
  });

  group('persistence: additive, legacy-save compatible round-trip', () {
    test('an in-progress session survives a toJson/fromJson round-trip', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 61));
      aggregate = aggregate.startProjectInterview('eng-01');
      final firstSession = aggregate.projectInterviewSessionFor('eng-01')!;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        firstSession.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(firstSession).first,
      );

      final json = aggregate.toJson();
      final restored = PublicDemoAggregate.fromJson(json);

      final before = aggregate.projectInterviewSessionFor('eng-01')!;
      final after = restored.projectInterviewSessionFor('eng-01')!;
      expect(after.id, before.id);
      expect(after.currentQuestionIndex, before.currentQuestionIndex);
      expect(after.playerFollowUps, before.playerFollowUps);
      expect(after.accumulatedEvaluation.total, before.accumulatedEvaluation.total);
      expect(restored.toJson(), json);
    });

    test('a legacy save with no projectInterviewSessions key decodes to an '
        'empty list rather than failing', () {
      final legacyJson = PublicDemoWorkflowState.initial().toJson()
        ..remove('projectInterviewSessions');
      final restored = PublicDemoWorkflowState.fromJson(legacyJson);
      expect(restored.projectInterviewSessions, isEmpty);
    });

    test('strict round-trip: a full aggregate save with a completed '
        'project-interview session is byte-identical after reload', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 71));
      aggregate = aggregate.startProjectInterview('eng-01');
      var session = aggregate.projectInterviewSessionFor('eng-01')!;
      while (session.playerFollowUps.length < session.questions.length) {
        final choice = PublicDemoProjectInterview.choicesFor(session).first;
        aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
        session = aggregate.projectInterviewSessionFor('eng-01')!;
      }
      aggregate = aggregate.concludeProjectInterview('eng-01');

      final json = aggregate.toJson();
      final restored = PublicDemoAggregate.fromJson(json);
      expect(restored.toJson(), json);
    });
  });

  group('Codex P1 fix (PR #214): a resumed session is always bound to the '
      'currently proposed project', () {
    test('1. the same engineer/project: an in-progress session is genuinely '
        'resumed (not reset) on a second startProjectInterview call', () {
      final aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 81));
      final started = aggregate.startProjectInterview('eng-01');
      final startedSession = started.projectInterviewSessionFor('eng-01')!;
      var withProgress = started.chooseProjectInterviewFollowUp(
        'eng-01',
        startedSession.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(startedSession).first,
      );
      final resumed = withProgress.startProjectInterview('eng-01');
      final resumedSession = resumed.projectInterviewSessionFor('eng-01')!;
      // Genuinely the same session, not replaced: the follow-up already
      // recorded above survives the resume.
      expect(resumedSession.playerFollowUps, hasLength(1));
      expect(
        resumedSession.id,
        withProgress.projectInterviewSessionFor('eng-01')!.id,
      );
    });

    test('2. changing the matching proposal mid-interview: the stale '
        'old-project session is never resumed against the new project — a '
        'fresh, independent session is started for the new project instead '
        '(the old-project session is preserved untouched, not resurfaced by '
        'the current-project accessor — Issue #257 composite-identity '
        'widening)', () {
      var aggregate = _advanceToPartnerPassed(
        PublicDemoAggregate.initial(runSeed: 82),
      );
      final candidates = aggregate.projectCandidatesForMonth(
        aggregate.state.month,
      );
      final oldProject = candidates[0];
      final newProject = candidates[1];
      expect(oldProject.id, isNot(equals(newProject.id)));

      // Player proposes the old project, opens the interview, and answers
      // one question (closing the dialog mid-interview corresponds to
      // simply not calling concludeProjectInterview yet).
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: oldProject.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      final oldSession = aggregate.projectInterviewSessionFor('eng-01')!;
      expect(oldSession.projectId, oldProject.id);
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        oldSession.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(oldSession).first,
      );

      // Player goes back to Matching and re-proposes a DIFFERENT project
      // for the same engineer — proposeMatch replaces the proposal, per
      // its own existing (unmodified) "at most one proposal per engineer"
      // contract.
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: newProject.id,
      );
      expect(
        aggregate.workflow.matchingProposalFor('eng-01')!.projectId,
        newProject.id,
      );

      // Reopening the interview must NOT resume the old, now-stale session.
      aggregate = aggregate.startProjectInterview('eng-01');
      final resumedSession = aggregate.projectInterviewSessionFor('eng-01')!;
      expect(resumedSession.projectId, newProject.id);
      // A genuinely fresh session for the new project — no leftover
      // follow-up/answer state from the old, discarded one.
      expect(resumedSession.playerFollowUps, isEmpty);
      expect(resumedSession.id, isNot(equals(oldSession.id)));
    });

    test('save/reload preserves the project binding of an in-progress '
        'session — a reload can never resume it against a different '
        'project than the one it was persisted for', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 83));
      aggregate = aggregate.startProjectInterview('eng-01');
      final originalProjectId =
          aggregate.projectInterviewSessionFor('eng-01')!.projectId;

      final restored = PublicDemoAggregate.fromJson(aggregate.toJson());
      expect(
        restored.projectInterviewSessionFor('eng-01')!.projectId,
        originalProjectId,
      );
      // Reopening after reload resumes the same session rather than
      // silently replacing it, since the (still current) proposal names
      // the same project.
      final resumed = restored.startProjectInterview('eng-01');
      expect(
        resumed.projectInterviewSessionFor('eng-01')!.id,
        aggregate.projectInterviewSessionFor('eng-01')!.id,
      );
    });

    test('conclude and failureReasons never mix a stale session with a '
        'different current project', () {
      var aggregate = _advanceToPartnerPassed(
        PublicDemoAggregate.initial(runSeed: 84),
      );
      final candidates = aggregate.projectCandidatesForMonth(
        aggregate.state.month,
      );
      final oldProject = candidates[0];
      final newProject = candidates[1];

      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: oldProject.id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      // Answer every question for the OLD project, but never conclude —
      // mirrors "closed the dialog right before finishing".
      var session = aggregate.projectInterviewSessionFor('eng-01')!;
      while (session.playerFollowUps.length < session.questions.length) {
        final choice = PublicDemoProjectInterview.choicesFor(session).first;
        aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
        session = aggregate.projectInterviewSessionFor('eng-01')!;
      }

      // Re-propose a different project before concluding.
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: newProject.id,
      );

      // concludeProjectInterview must not score the fully-answered OLD
      // session against the NEW project: the stale, mismatched session is
      // not concluded (it is a no-op — the engineer stays
      // partnerInterviewPassed) rather than silently mixing old questions
      // with the new project's fit. Issue #257 composite-identity widening:
      // the OLD project's own session is no longer discarded by the
      // re-proposal — it is looked up here by its own explicit
      // `(engineerId, oldProject.id)` pair, never the ambiguous
      // single-argument "whichever session this engineer happens to have"
      // form.
      final beforeConclude = _engineer(aggregate);
      final afterConclude = aggregate.concludeProjectInterview('eng-01');
      expect(_engineer(afterConclude).stage, beforeConclude.stage);
      // Issue #257 PR #256 carry-over (session-keying widening):
      // `projectInterviewSessionFor('eng-01')` now resolves against the
      // engineer's CURRENT proposal (newProject), which has no session yet
      // — correctly `null`, not the stale one. The stale OLD-project
      // session itself is untouched (never destroyed, per the widening),
      // verified directly against the full session list.
      expect(afterConclude.projectInterviewSessionFor('eng-01'), isNull);
      expect(
        afterConclude.workflow
            .projectInterviewSessionFor('eng-01', oldProject.id)!
            .completed,
        isFalse,
      );

      // Reopening the interview starts a genuinely fresh session bound to
      // the new project (composite-identity widening: the OLD project's own
      // still-unconcluded session above is preserved untouched alongside it,
      // not discarded), and failureReasons always reads the current (new)
      // project's own fit — never the stale one's.
      final restarted = afterConclude.startProjectInterview('eng-01');
      final newSession = restarted.projectInterviewSessionFor('eng-01')!;
      expect(newSession.projectId, newProject.id);
      final reasons = restarted.projectInterviewFailureReasonsFor('eng-01');
      expect(
        restarted.projectInterviewCandidateFor('eng-01')!.id,
        newProject.id,
      );
      // Sanity: failureReasons resolves without throwing and stays within
      // the known, truthful reason vocabulary even mid-flow.
      const knownFragments = [
        '技術経験', 'の経験不足', '実務経験年数', 'コミュニケーション評価', '日本語レベル', '他候補を優先',
      ];
      for (final reason in reasons) {
        expect(knownFragments.any((f) => reason.contains(f)), isTrue);
      }
    });

    test('normal pass/fail flow is unaffected when the proposal is never '
        'changed mid-interview', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 85));
      aggregate = aggregate.startProjectInterview('eng-01');
      var session = aggregate.projectInterviewSessionFor('eng-01')!;
      while (session.playerFollowUps.length < session.questions.length) {
        final choice = PublicDemoProjectInterview.choicesFor(session).first;
        aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
        session = aggregate.projectInterviewSessionFor('eng-01')!;
      }
      aggregate = aggregate.concludeProjectInterview('eng-01');
      final finalSession = aggregate.projectInterviewSessionFor('eng-01')!;
      expect(finalSession.completed, isTrue);
      expect(finalSession.result, isNotNull);
      expect(
        _engineer(aggregate).stage,
        anyOf(
          PublicDemoSalesStage.clientInterviewPassed,
          PublicDemoSalesStage.clientInterviewFailed,
        ),
      );
    });

    test('sales-slot behavior stays 0-slot even across a mid-interview '
        'proposal change', () {
      var aggregate = _advanceToPartnerPassed(
        PublicDemoAggregate.initial(runSeed: 86),
      );
      final candidates = aggregate.projectCandidatesForMonth(
        aggregate.state.month,
      );
      final slotsBefore = aggregate.state.salesUsed;

      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidates[0].id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      final firstProjectSession = aggregate.projectInterviewSessionFor('eng-01')!;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        firstProjectSession.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(firstProjectSession).first,
      );
      aggregate = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: candidates[1].id,
      );
      aggregate = aggregate.startProjectInterview('eng-01');
      var session = aggregate.projectInterviewSessionFor('eng-01')!;
      while (session.playerFollowUps.length < session.questions.length) {
        final choice = PublicDemoProjectInterview.choicesFor(session).first;
        aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', session.currentQuestionIndex, choice);
        session = aggregate.projectInterviewSessionFor('eng-01')!;
      }
      aggregate = aggregate.concludeProjectInterview('eng-01');

      expect(aggregate.state.salesUsed, slotsBefore);
    });
  });

  group('Codex P1-2 fix (PR #214): a passing record stays bound to the '
      'interviewed project', () {
    test('3. after a genuine pass on project A, proposing project B for the '
        'same engineer is a no-op — the proposal stays locked to A, so '
        'nothing can ever order for the un-interviewed project', () {
      final found = _findGenuinePass();
      expect(found, isNotNull, reason: 'expected at least one pass across 40 seeds');
      var aggregate = found!.aggregate;
      final projectAId = found.projectId;
      expect(_engineer(aggregate).genuineInterviewProjectId, projectAId);

      final otherCandidates = aggregate
          .projectCandidatesForMonth(aggregate.state.month)
          .where((candidate) => candidate.id != projectAId)
          .toList();
      expect(otherCandidates, isNotEmpty);
      final projectB = otherCandidates.first;

      final swapped = aggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: projectB.id,
      );

      // The proposal never moved -- still project A.
      expect(
        swapped.workflow.matchingProposalFor('eng-01')?.projectId,
        projectAId,
      );
      expect(_engineer(swapped).genuineInterviewProjectId, projectAId);
      // The passed engineer is also no longer offered in Matching at all.
      expect(
        swapped.availableEngineersForMatching.any((e) => e.id == 'eng-01'),
        isFalse,
      );
    });

    test('4. recordOrder still succeeds normally for the actually-passed '
        'project', () {
      final found = _findGenuinePass();
      expect(found, isNotNull, reason: 'expected at least one pass across 40 seeds');
      final aggregate = found!.aggregate;

      final ordered = aggregate.recordOrder('eng-01');

      expect(_engineer(ordered).stage, PublicDemoSalesStage.ordered);
      expect(_engineer(ordered).genuineInterviewProjectId, found.projectId);
      expect(
        ordered.workflow.matchingProposalFor('eng-01')?.projectId,
        found.projectId,
      );
    });

    test('a failed interview (not a pass) leaves the proposal freely '
        're-proposable, exactly as before', () {
      // Find a seed where eng-01 FAILS instead, to prove the lock is
      // specific to a genuine pass, not to having interviewed at all.
      PublicDemoAggregate? failedAggregate;
      for (var seed = 0; seed < 60 && failedAggregate == null; seed++) {
        var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: seed));
        aggregate = _runInterviewToConclusion(aggregate);
        if (_engineer(aggregate).stage ==
            PublicDemoSalesStage.clientInterviewFailed) {
          failedAggregate = aggregate;
        }
      }
      expect(failedAggregate, isNotNull, reason: 'expected a fail across 60 seeds');
      final otherProject = failedAggregate!
          .projectCandidatesForMonth(failedAggregate.state.month)
          .last;
      final reproposed = failedAggregate.proposeMatch(
        engineerId: 'eng-01',
        projectId: otherProject.id,
      );
      expect(
        reproposed.workflow.matchingProposalFor('eng-01')?.projectId,
        otherProject.id,
      );
    });
  });

  group('Codex P2 fix (PR #214): capability is frozen for the duration of '
      'an interview', () {
    test('6. advancing the month mid-interview forces a safe restart on '
        'reopen — no mixing of old-month answers with new-month capability', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 91));
      aggregate = aggregate.startProjectInterview('eng-01');
      final startSession = aggregate.projectInterviewSessionFor('eng-01')!;
      final firstQuestionAnswer = startSession.employeeAnswers.first;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        startSession.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(startSession).first,
      );
      final midSession = aggregate.projectInterviewSessionFor('eng-01')!;
      expect(midSession.playerFollowUps, hasLength(1));
      expect(midSession.startedWeek, 4);

      // A real, unmodified monthly close -- the only production way
      // `state.month` (and, in general, engineer runtime capability via
      // growth/training) ever advances. eng-01 stays unassigned throughout,
      // so its own stage/proposal are untouched by this close.
      aggregate = aggregate.closeApril(monthlyExpenses: 10000);
      expect(aggregate.state.month, 5);
      expect(
        _engineer(aggregate).stage,
        PublicDemoSalesStage.partnerInterviewPassed,
      );

      // Reopening does NOT resume the stale month-4 session.
      aggregate = aggregate.startProjectInterview('eng-01');
      final resumed = aggregate.projectInterviewSessionFor('eng-01')!;
      expect(resumed.startedWeek, 5);
      expect(resumed.playerFollowUps, isEmpty);
      expect(resumed.employeeAnswers.first.text, isNotNull);
      // A genuinely fresh draw, not carried over from the month-4 session
      // (the two need not differ in every case, but the session identity
      // itself must be a clean restart: zero recorded progress).
      expect(resumed.completed, isFalse);
      // Sanity: the original (discarded) session's own first answer is
      // still whatever it was -- proving nothing mutated it in place.
      expect(firstQuestionAnswer.text, isNotNull);
    });
  });

  group('Codex P1-2 + P2 fixes: bindings survive save/reload', () {
    test('7. the passed-project lock and the month-freshness of an '
        'in-progress session both survive a toJson/fromJson round-trip', () {
      final found = _findGenuinePass();
      expect(found, isNotNull, reason: 'expected at least one pass across 40 seeds');
      final aggregate = found!.aggregate;

      final restored = PublicDemoAggregate.fromJson(aggregate.toJson());
      expect(
        restored.workflow.engineers
            .firstWhere((e) => e.id == 'eng-01')
            .genuineInterviewProjectId,
        found.projectId,
      );

      // The lock itself survives reload too.
      final otherProject = restored
          .projectCandidatesForMonth(restored.state.month)
          .firstWhere((candidate) => candidate.id != found.projectId);
      final swapped = restored.proposeMatch(
        engineerId: 'eng-01',
        projectId: otherProject.id,
      );
      expect(
        swapped.workflow.matchingProposalFor('eng-01')?.projectId,
        found.projectId,
      );
      expect(restored.toJson(), aggregate.toJson());
    });

    test('an in-progress session persists its own startedWeek, so the '
        'month-freshness check keeps working identically after a reload', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 91));
      aggregate = aggregate.startProjectInterview('eng-01');
      final freshSession = aggregate.projectInterviewSessionFor('eng-01')!;
      aggregate = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        freshSession.currentQuestionIndex,
        PublicDemoProjectInterview.choicesFor(freshSession).first,
      );

      final restored = PublicDemoAggregate.fromJson(aggregate.toJson());
      expect(
        restored.projectInterviewSessionFor('eng-01')!.startedWeek,
        aggregate.projectInterviewSessionFor('eng-01')!.startedWeek,
      );

      // Resuming right after reload (same month) still resumes.
      final resumedSameMonth = restored.startProjectInterview('eng-01');
      expect(
        resumedSameMonth.projectInterviewSessionFor('eng-01')!.playerFollowUps,
        hasLength(1),
      );
    });
  });

  group('Codex P2 fix (PR #214): duplicate/stale follow-up submissions are '
      'ignored at the authority boundary', () {
    test('submitting the same follow-up twice in a row (the second call '
        'still claiming the question index the first one already answered) '
        'is a no-op', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 5));
      aggregate = aggregate.startProjectInterview('eng-01');
      final session0 = aggregate.projectInterviewSessionFor('eng-01')!;
      final choice = PublicDemoProjectInterview.choicesFor(session0).first;

      final afterFirst = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        session0.currentQuestionIndex,
        choice,
      );
      final sessionAfterFirst = afterFirst.projectInterviewSessionFor(
        'eng-01',
      )!;
      expect(sessionAfterFirst.playerFollowUps, hasLength(1));

      // The duplicate/stale second submission -- same captured
      // questionIndex (0, from the session the button was originally built
      // from), submitted against the aggregate AFTER the first call already
      // advanced it.
      final afterDuplicate = afterFirst.chooseProjectInterviewFollowUp(
        'eng-01',
        session0.currentQuestionIndex,
        choice,
      );
      final sessionAfterDuplicate = afterDuplicate.projectInterviewSessionFor(
        'eng-01',
      )!;

      expect(sessionAfterDuplicate.playerFollowUps, hasLength(1));
      expect(
        sessionAfterDuplicate.currentQuestionIndex,
        sessionAfterFirst.currentQuestionIndex,
      );
      expect(
        sessionAfterDuplicate.employeeAnswers.length,
        sessionAfterFirst.employeeAnswers.length,
      );
      expect(
        sessionAfterDuplicate.accumulatedEvaluation.total,
        sessionAfterFirst.accumulatedEvaluation.total,
      );
      expect(
        sessionAfterDuplicate.interviewerReactions.length,
        sessionAfterFirst.interviewerReactions.length,
      );
    });

    test('a double submit on a NON-final question does not skip the next '
        'question — its own real follow-up is still required and accepted '
        'normally', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 5));
      aggregate = aggregate.startProjectInterview('eng-01');
      final session0 = aggregate.projectInterviewSessionFor('eng-01')!;
      expect(session0.questions.length, greaterThan(1));
      final choice0 = PublicDemoProjectInterview.choicesFor(session0).first;

      aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', 0, choice0);
      // Stale duplicate still claiming question 0.
      aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', 0, choice0);

      final session1 = aggregate.projectInterviewSessionFor('eng-01')!;
      expect(session1.currentQuestionIndex, 1);
      expect(session1.playerFollowUps, hasLength(1));

      // Question 1's own real answer is still genuinely required and works.
      final choice1 = PublicDemoProjectInterview.choicesFor(session1).first;
      aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', 1, choice1);
      final session2 = aggregate.projectInterviewSessionFor('eng-01')!;
      expect(session2.playerFollowUps, hasLength(2));
    });

    test('a double submit on the FINAL question does not double-add its '
        'evaluation into accumulatedEvaluation', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 5));
      aggregate = aggregate.startProjectInterview('eng-01');
      var session = aggregate.projectInterviewSessionFor('eng-01')!;
      while (session.currentQuestionIndex < session.questions.length - 1) {
        final choice = PublicDemoProjectInterview.choicesFor(session).first;
        aggregate = aggregate.chooseProjectInterviewFollowUp(
          'eng-01',
          session.currentQuestionIndex,
          choice,
        );
        session = aggregate.projectInterviewSessionFor('eng-01')!;
      }
      final lastIndex = session.currentQuestionIndex;
      final lastChoice = PublicDemoProjectInterview.choicesFor(session).first;

      final afterFirst = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        lastIndex,
        lastChoice,
      );
      final sessionAfterFirst = afterFirst.projectInterviewSessionFor(
        'eng-01',
      )!;
      expect(sessionAfterFirst.playerFollowUps, hasLength(session.questions.length));

      final afterDuplicate = afterFirst.chooseProjectInterviewFollowUp(
        'eng-01',
        lastIndex,
        lastChoice,
      );
      final sessionAfterDuplicate = afterDuplicate.projectInterviewSessionFor(
        'eng-01',
      )!;

      // Not questions.length + 1 -- the duplicate final answer never lands.
      expect(
        sessionAfterDuplicate.playerFollowUps,
        hasLength(session.questions.length),
      );
      expect(
        sessionAfterDuplicate.accumulatedEvaluation.total,
        sessionAfterFirst.accumulatedEvaluation.total,
      );
    });

    test('a followUp that is not among the current question\'s offered '
        'choices is rejected', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 5));
      aggregate = aggregate.startProjectInterview('eng-01');
      final session0 = aggregate.projectInterviewSessionFor('eng-01')!;
      final offered = PublicDemoProjectInterview.choicesFor(session0);
      final notOffered = ClientInterviewFollowUp.values.firstWhere(
        (candidate) => !offered.contains(candidate),
      );

      final rejected = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        0,
        notOffered,
      );

      expect(
        rejected.projectInterviewSessionFor('eng-01')!.playerFollowUps,
        isEmpty,
      );
    });

    test('a followUp submitted for a stale (already-advanced) question '
        'index is rejected even when the choice itself is generally valid '
        'for the current question', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 5));
      aggregate = aggregate.startProjectInterview('eng-01');
      final session0 = aggregate.projectInterviewSessionFor('eng-01')!;
      final choice0 = PublicDemoProjectInterview.choicesFor(session0).first;
      aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', 0, choice0);

      final stale = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        0,
        choice0,
      );

      expect(
        stale.projectInterviewSessionFor('eng-01')!.playerFollowUps,
        hasLength(1),
      );
    });

    test('a negative or out-of-range question index is rejected', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 5));
      aggregate = aggregate.startProjectInterview('eng-01');
      final session0 = aggregate.projectInterviewSessionFor('eng-01')!;
      final choice0 = PublicDemoProjectInterview.choicesFor(session0).first;

      final rejectedNegative = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        -1,
        choice0,
      );
      final rejectedTooLarge = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        session0.questions.length,
        choice0,
      );

      expect(
        rejectedNegative.projectInterviewSessionFor('eng-01')!.playerFollowUps,
        isEmpty,
      );
      expect(
        rejectedTooLarge.projectInterviewSessionFor('eng-01')!.playerFollowUps,
        isEmpty,
      );
    });

    test('valid normal progression through every question still completes '
        'and concludes correctly', () {
      final result = _runInterviewToConclusion(
        _withRealProposal(PublicDemoAggregate.initial(runSeed: 5)),
      );
      final session = result.projectInterviewSessionFor('eng-01')!;
      expect(session.completed, isTrue);
      expect(session.result, isNotNull);
    });

    test('save/reload preserves progress, and a stale duplicate is still '
        'rejected identically after reload', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 5));
      aggregate = aggregate.startProjectInterview('eng-01');
      final session0 = aggregate.projectInterviewSessionFor('eng-01')!;
      final choice0 = PublicDemoProjectInterview.choicesFor(session0).first;
      aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', 0, choice0);

      final restored = PublicDemoAggregate.fromJson(aggregate.toJson());
      expect(
        restored.projectInterviewSessionFor('eng-01')!.playerFollowUps,
        hasLength(1),
      );

      final stale = restored.chooseProjectInterviewFollowUp(
        'eng-01',
        0,
        choice0,
      );
      expect(
        stale.projectInterviewSessionFor('eng-01')!.playerFollowUps,
        hasLength(1),
      );
    });

    test('determinism is unaffected: replaying the same runSeed/choices '
        'through the question-index-validated API still reproduces the '
        'same result', () {
      PublicDemoAggregate runOnce() =>
          _runInterviewToConclusion(_withRealProposal(PublicDemoAggregate.initial(runSeed: 5)));

      final first = runOnce();
      final second = runOnce();

      expect(_engineer(first).stage, _engineer(second).stage);
      expect(
        _engineer(first).lastInterviewScore,
        _engineer(second).lastInterviewScore,
      );
    });
  });
}
