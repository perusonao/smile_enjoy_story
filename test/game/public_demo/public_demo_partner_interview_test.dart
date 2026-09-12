import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';

/// Issue #245 Phase B2 (Partner Interview Gameplay): coverage for the
/// interactive 上位会社面談 — mirrors
/// `public_demo_project_interview_test.dart` (CORE-GAMEPLAY Phase 6) one
/// sales-pipeline stage earlier (`introduced` →
/// `partnerInterviewPassed`/`partnerInterviewFailed`, instead of
/// `partnerInterviewPassed` → `clientInterviewPassed`/`clientInterviewFailed`
/// ), reusing the exact same [ClientInterviewSession]/[ClientInterviewEngine]
/// machinery and persisted [projectInterviewSessions] list — no new score,
/// state, or save schema. See
/// docs/reports/SES_FIRST-FUN-YEAR_Partner-Interview_PhaseB_Result.md.

/// Advances `eng-01` to `introduced` via the pre-existing sales pipeline
/// only (`startSkillSheetReview` → `beginSelling` → `introduceProject`) —
/// never a shortcut that sets `stage` directly. Deliberately does NOT
/// auto-propose a match (unlike the production UI's own `_introduceProject`
/// helper) — mirrors `public_demo_project_interview_test.dart
/// ._advanceToPartnerPassed`'s own convention of keeping the "no real
/// proposal yet" case reachable for its own dedicated test.
PublicDemoAggregate _advanceToIntroduced(PublicDemoAggregate aggregate) {
  var next = aggregate.startSkillSheetReview('eng-01');
  next = next.beginSelling('eng-01');
  next = next.introduceProject('eng-01');
  return next;
}

/// [_advanceToIntroduced] plus a real Phase 5 proposal for the first project
/// candidate in the current month's pool.
PublicDemoAggregate _withRealProposal(PublicDemoAggregate aggregate) {
  var next = _advanceToIntroduced(aggregate);
  final project = next.projectCandidatesForMonth(next.state.month).first;
  next = next.proposeMatch(engineerId: 'eng-01', projectId: project.id);
  return next;
}

PublicDemoEngineerSales _engineer(PublicDemoAggregate aggregate) => aggregate
    .workflow
    .engineers
    .firstWhere((engineer) => engineer.id == 'eng-01');

/// Runs the partner interview to completion (always choosing the first
/// available follow-up), returning the concluded aggregate.
PublicDemoAggregate _runPartnerInterviewToConclusion(
  PublicDemoAggregate aggregate,
) {
  aggregate = aggregate.startPartnerInterview('eng-01');
  var session = aggregate.projectInterviewSessionFor('eng-01')!;
  while (session.playerFollowUps.length < session.questions.length) {
    final choice = PublicDemoProjectInterview.choicesFor(session).first;
    aggregate = aggregate.chooseProjectInterviewFollowUp(
      'eng-01',
      session.currentQuestionIndex,
      choice,
    );
    session = aggregate.projectInterviewSessionFor('eng-01')!;
  }
  return aggregate.concludePartnerInterview('eng-01');
}

/// Scans a bounded, deterministic seed range for one where `eng-01`
/// genuinely passes the partner interview for the first candidate offered —
/// mirrors `public_demo_project_interview_test.dart._findGenuinePass`.
({PublicDemoAggregate aggregate, String projectId})? _findGenuinePartnerPass({
  int maxSeed = 40,
}) {
  for (var seed = 0; seed < maxSeed; seed++) {
    var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: seed));
    final projectId = aggregate.workflow.matchingProposalFor('eng-01')!.projectId;
    aggregate = _runPartnerInterviewToConclusion(aggregate);
    if (_engineer(aggregate).stage == PublicDemoSalesStage.partnerInterviewPassed) {
      return (aggregate: aggregate, projectId: projectId);
    }
  }
  return null;
}

void main() {
  group('PublicDemoAggregate.startPartnerInterview', () {
    test('is a no-op unless the engineer is genuinely introduced', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 1);
      final withProposal = () {
        final project = aggregate.projectCandidatesForMonth(4).first;
        return aggregate.proposeMatch(engineerId: 'eng-01', projectId: project.id);
      }();
      final started = withProposal.startPartnerInterview('eng-01');
      expect(started.projectInterviewSessionFor('eng-01'), isNull);
    });

    test('is a no-op without a real Phase 5 matching proposal, even at '
        'introduced — the engineer stays on the existing generic '
        'partner-interview path', () {
      final aggregate = _advanceToIntroduced(PublicDemoAggregate.initial(runSeed: 2));
      expect(aggregate.projectInterviewCandidateFor('eng-01'), isNull);
      final started = aggregate.startPartnerInterview('eng-01');
      expect(started.projectInterviewSessionFor('eng-01'), isNull);
    });

    test('starts a real, multi-question session for a genuine proposal', () {
      final aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 3));
      final started = aggregate.startPartnerInterview('eng-01');
      final session = started.projectInterviewSessionFor('eng-01');
      expect(session, isNotNull);
      expect(session!.questions.length, greaterThanOrEqualTo(2));
      expect(session.employeeId, 'eng-01');
      expect(session.completed, isFalse);
    });

    test('resuming does not restart an in-progress session', () {
      final aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 4));
      final started = aggregate.startPartnerInterview('eng-01');
      final resumed = started.startPartnerInterview('eng-01');
      expect(
        resumed.projectInterviewSessionFor('eng-01'),
        same(started.projectInterviewSessionFor('eng-01')),
      );
    });

    test('consumes exactly one real sales slot on a genuinely new attempt, '
        'and never again on resume — the same budget the pre-B2 generic '
        'partner-interview path always spent, never a second/new one', () {
      final aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 10));
      final before = aggregate.state.salesRemaining;
      final started = aggregate.startPartnerInterview('eng-01');
      expect(started.state.salesRemaining, before - 1);

      // Reopening (resuming) the same in-progress session must never spend
      // a second slot.
      final resumed = started.startPartnerInterview('eng-01');
      expect(resumed.state.salesRemaining, before - 1);
    });

    test('never starts (and never spends a slot) once salesRemaining is '
        'exhausted — mirrors the 上位会社面談 button\'s own enablement gate', () {
      final aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 11));
      // A round-trip through the same public toJson/fromJson persistence
      // boundary every save/reload test in this suite already uses — here
      // to directly construct an exhausted-budget state rather than
      // draining it through many unrelated real commands.
      final json = aggregate.toJson();
      final state = (json['state'] as Map).cast<String, dynamic>();
      state['salesUsed'] = state['salesCapacity'];
      final exhausted = PublicDemoAggregate.fromJson(json);
      expect(exhausted.state.salesRemaining, 0);

      final started = exhausted.startPartnerInterview('eng-01');
      expect(started.projectInterviewSessionFor('eng-01'), isNull);
      expect(started.state.salesRemaining, 0);
    });
  });

  group('PublicDemoAggregate.concludePartnerInterview', () {
    test('never mints the unforgeable client-interview record — only a '
        'genuine CLIENT pass may (see hasGenuineInterviewRecord\'s own '
        'doc)', () {
      final found = _findGenuinePartnerPass();
      expect(found, isNotNull, reason: 'no genuine partner pass found in 40 seeds');
      final engineer = _engineer(found!.aggregate);
      expect(engineer.stage, PublicDemoSalesStage.partnerInterviewPassed);
      expect(engineer.hasGenuineInterviewRecord, isFalse);
      expect(engineer.interviewRecord, isNull);
    });

    test('a fully-answered session with no genuine proposal never concludes '
        '(defense in depth)', () {
      final aggregate = _advanceToIntroduced(PublicDemoAggregate.initial(runSeed: 5));
      final concluded = aggregate.concludePartnerInterview('eng-01');
      expect(_engineer(concluded).stage, PublicDemoSalesStage.introduced);
    });

    test('is a no-op unless every question has a player-chosen follow-up', () {
      final aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 6));
      final started = aggregate.startPartnerInterview('eng-01');
      final concluded = started.concludePartnerInterview('eng-01');
      expect(_engineer(concluded).stage, PublicDemoSalesStage.introduced);
      expect(concluded.projectInterviewSessionFor('eng-01')!.completed, isFalse);
    });
  });

  group('a genuine partner pass unblocks the existing client-interview leg '
      'unchanged (Phase 6 reuse, not a fork)', () {
    test('after a partner pass, startProjectInterview (client) replaces the '
        'completed partner session with a fresh client session for the '
        'same project', () {
      final found = _findGenuinePartnerPass();
      expect(found, isNotNull);
      var aggregate = found!.aggregate;
      final partnerSessionId = aggregate.projectInterviewSessionFor('eng-01')!.id;
      expect(
        aggregate.projectInterviewSessionFor('eng-01')!.completed,
        isTrue,
      );

      aggregate = aggregate.startProjectInterview('eng-01');
      final clientSession = aggregate.projectInterviewSessionFor('eng-01')!;
      // Same id shape (employeeId:projectId — same project) but a fresh,
      // not-yet-answered session, not the old completed partner one.
      expect(clientSession.id, partnerSessionId);
      expect(clientSession.completed, isFalse);
      expect(clientSession.playerFollowUps, isEmpty);
    });

    test('end-to-end: introduced → partner pass → client pass → order → '
        'assignOrderedForMay produces a genuine assignment bound to the '
        'real interviewed project', () {
      ({PublicDemoAggregate aggregate, String projectId})? runFull() {
        final found = _findGenuinePartnerPass();
        if (found == null) return null;
        var aggregate = found.aggregate;
        aggregate = aggregate.startProjectInterview('eng-01');
        var session = aggregate.projectInterviewSessionFor('eng-01')!;
        while (session.playerFollowUps.length < session.questions.length) {
          final choice = PublicDemoProjectInterview.choicesFor(session).first;
          aggregate = aggregate.chooseProjectInterviewFollowUp(
            'eng-01',
            session.currentQuestionIndex,
            choice,
          );
          session = aggregate.projectInterviewSessionFor('eng-01')!;
        }
        aggregate = aggregate.concludeProjectInterview('eng-01');
        if (_engineer(aggregate).stage != PublicDemoSalesStage.clientInterviewPassed) {
          return null;
        }
        return (aggregate: aggregate, projectId: found.projectId);
      }

      // Scan a few independent attempts since both legs must genuinely pass
      // (never asserts an outcome — always a real seeded-RNG result).
      for (var attempt = 0; attempt < 5; attempt++) {
        final result = runFull();
        if (result == null) continue;
        var aggregate = result.aggregate;
        aggregate = aggregate.recordOrder('eng-01');
        expect(_engineer(aggregate).stage, PublicDemoSalesStage.ordered);
        // closeApril already builds May's assignment roster internally
        // (assignOrderedForMay) — the real production path, never a direct
        // workflow-level call from outside the aggregate.
        aggregate = aggregate.closeApril(monthlyExpenses: 0);
        final assignment = aggregate.workflow.assignments
            .where((a) => a.engineerId == 'eng-01')
            .firstOrNull;
        expect(assignment, isNotNull);
        expect(assignment!.projectId, result.projectId);
        return;
      }
      fail('no attempt produced a genuine partner+client pass in 5 tries');
    });
  });

  group('month boundary', () {
    test('a partner session started in one month is discarded (never '
        'concluded against stale month/capability) once the month has '
        'advanced without concluding it', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 7));
      aggregate = aggregate.startPartnerInterview('eng-01');
      final sessionBefore = aggregate.projectInterviewSessionFor('eng-01')!;
      expect(sessionBefore.startedWeek, aggregate.state.month);

      // Simulate a genuine month advance without concluding, via the real
      // production close command (never a hand-crafted state mutation) —
      // concludePartnerInterview requires session.startedWeek ==
      // currentMonth, so a stale session must never silently conclude
      // against the new month.
      final laterMonthAggregate = aggregate.closeApril(monthlyExpenses: 0);
      expect(laterMonthAggregate.state.month, isNot(sessionBefore.startedWeek));
      final concluded = laterMonthAggregate.concludePartnerInterview('eng-01');
      expect(_engineer(concluded).stage, PublicDemoSalesStage.introduced);
      expect(
        concluded.projectInterviewSessionFor('eng-01')!.completed,
        isFalse,
      );
    });
  });

  group('save/reload', () {
    const codec = PublicDemoSaveCodec();

    test('an in-progress partner session survives a toJson/fromJson '
        'round-trip', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 8));
      aggregate = aggregate.startPartnerInterview('eng-01');
      final choice = PublicDemoProjectInterview.choicesFor(
        aggregate.projectInterviewSessionFor('eng-01')!,
      ).first;
      aggregate = aggregate.chooseProjectInterviewFollowUp('eng-01', 0, choice);

      final encoded = codec.encode(aggregate);
      final decoded = codec.decode(encoded);
      expect(decoded, isNotNull);
      expect(
        decoded!.projectInterviewSessionFor('eng-01')!.playerFollowUps,
        aggregate.projectInterviewSessionFor('eng-01')!.playerFollowUps,
      );
      expect(_engineer(decoded).stage, PublicDemoSalesStage.introduced);
    });

    test('a completed, genuine partner pass (stage partnerInterviewPassed, '
        'no interviewRecord) round-trips byte-identical — the save codec\'s '
        'cross-checks are all keyed off a CLIENT pass\'s '
        'interviewRecordProjectId, which stays null here', () {
      final found = _findGenuinePartnerPass();
      expect(found, isNotNull);
      final aggregate = found!.aggregate;
      final encoded = codec.encode(aggregate);
      final decoded = codec.decode(encoded);
      expect(decoded, isNotNull);
      expect(_engineer(decoded!).stage, PublicDemoSalesStage.partnerInterviewPassed);
      expect(_engineer(decoded).interviewRecord, isNull);
      expect(
        decoded.projectInterviewSessionFor('eng-01')!.completed,
        isTrue,
      );
    });

    test('a genuine partner FAIL also round-trips cleanly and the engineer '
        'can resume selling', () {
      // Scan for a genuine fail instead of a pass.
      PublicDemoAggregate? failed;
      for (var seed = 0; seed < 40; seed++) {
        var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: seed));
        aggregate = _runPartnerInterviewToConclusion(aggregate);
        if (_engineer(aggregate).stage == PublicDemoSalesStage.partnerInterviewFailed) {
          failed = aggregate;
          break;
        }
      }
      expect(failed, isNotNull, reason: 'no genuine partner fail found in 40 seeds');
      final encoded = codec.encode(failed!);
      final decoded = codec.decode(encoded);
      expect(decoded, isNotNull);
      expect(_engineer(decoded!).stage, PublicDemoSalesStage.partnerInterviewFailed);

      // beginSelling's existing recovery path already covers
      // partnerInterviewFailed — never a dead end.
      final resumed = decoded.beginSelling('eng-01');
      expect(_engineer(resumed).stage, PublicDemoSalesStage.selling);
    });
  });

  group('double tap / stale duplicate submission', () {
    test('choosing the same follow-up twice for an already-answered '
        'question is rejected (Codex P2-2-style guard, reused verbatim from '
        'Phase 6)', () {
      var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: 9));
      aggregate = aggregate.startPartnerInterview('eng-01');
      final session = aggregate.projectInterviewSessionFor('eng-01')!;
      final choice = PublicDemoProjectInterview.choicesFor(session).first;
      final onceAnswered = aggregate.chooseProjectInterviewFollowUp(
        'eng-01',
        0,
        choice,
      );
      // A stale duplicate submission for question index 0 — already
      // answered — must be a no-op, never double-applying the evaluation.
      final duplicate = onceAnswered.chooseProjectInterviewFollowUp(
        'eng-01',
        0,
        choice,
      );
      expect(
        duplicate.projectInterviewSessionFor('eng-01')!.playerFollowUps,
        onceAnswered.projectInterviewSessionFor('eng-01')!.playerFollowUps,
      );
      expect(
        duplicate.projectInterviewSessionFor('eng-01')!.accumulatedEvaluation.total,
        onceAnswered.projectInterviewSessionFor('eng-01')!.accumulatedEvaluation.total,
      );
    });

    test('concluding twice in a row is safe — the second call is a no-op '
        'once the engineer has already left the introduced stage', () {
      final found = _findGenuinePartnerPass();
      expect(found, isNotNull);
      var aggregate = found!.aggregate;
      final stageAfterFirst = _engineer(aggregate).stage;
      aggregate = aggregate.concludePartnerInterview('eng-01');
      expect(_engineer(aggregate).stage, stageAfterFirst);
    });
  });
}
