import 'dart:convert';

import '../engine/client_interview_engine.dart';
import '../models/client_interview.dart';
import '../public_demo/public_demo_aggregate.dart';
import '../public_demo/public_demo_engineer_runtime.dart';
import '../public_demo/public_demo_matching_fit.dart';
import '../public_demo/public_demo_rng.dart';

/// Versioned, self-contained persistence envelope for Public Demo 0.1.
///
/// This deliberately has no dependency on normal [GameState] persistence.
/// A payload is restored exactly as saved or rejected as a whole; decoding
/// never invokes gameplay reconciliation. The sole exception
/// (SEEDED-RNG-REUSE-1) is `aggregate.state.runSeed`: a save from before
/// that field existed gets one derived deterministically from its own
/// content — see [fromJson]'s own doc — every other field is still
/// required to match exactly or the whole save is rejected.
class PublicDemoSaveCodec {
  static const schemaVersion = 1;
  static const _experience = 'public-demo-01';

  const PublicDemoSaveCodec();

  String encode(PublicDemoAggregate aggregate) => jsonEncode(toJson(aggregate));

  Map<String, dynamic> toJson(PublicDemoAggregate aggregate) => {
    'schemaVersion': schemaVersion,
    'experience': _experience,
    'aggregate': aggregate.toJson(),
  };

  /// Returns null for corrupt, foreign, incomplete, or incompatible saves.
  /// The caller can safely fall back to a new Public Demo session.
  PublicDemoAggregate? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  PublicDemoAggregate? fromJson(Map<String, dynamic> json) {
    try {
      if (json.keys.toSet().length != 3 ||
          !json.keys.toSet().containsAll(const {
            'schemaVersion',
            'experience',
            'aggregate',
          }) ||
          json['schemaVersion'] != schemaVersion ||
          json['experience'] != _experience ||
          json['aggregate'] is! Map ||
          !_hasConsistentAuthorityFacts(json)) {
        return null;
      }
      final aggregate = PublicDemoAggregate.fromJson(
        (json['aggregate'] as Map).cast<String, dynamic>(),
      );

      // Codex P2 fix (PR #214) "Validate restored accumulated interview
      // evaluation": [ClientInterviewSession.fromJson] casts
      // `accumulatedEvaluation`'s five integers verbatim — a shape-valid
      // save can carry ANY values there, and the strict round-trip
      // comparison below only ever detects a value that decoding itself
      // would normalize away, which this is not (any int round-trips
      // byte-identical). [ClientInterviewEngine.finalRate] then trusts
      // `session.accumulatedEvaluation.total.clamp(-15, 15)` as a genuine
      // player-choice-derived adjustment to the pass/fail rate — a
      // corrupted save could shift that by the full ±15 range without
      // touching anything else this method already checks. Reusing
      // [ClientInterviewEngine.evaluate] itself (never a second formula) to
      // replay every recorded follow-up from the session's own
      // authoritative `questions`/`employeeAnswers`/`playerFollowUps` closes
      // this: a stored total that disagrees with what those facts actually
      // produce did not come from any real [PublicDemoProjectInterview
      // .chooseFollowUp] call.
      if (!_hasConsistentProjectInterviewEvaluations(aggregate)) {
        return null;
      }

      // PublicDemoState's legacy decoder intentionally supplies defaults for
      // old normal-game data.  A Public Demo envelope must be stricter: this
      // round-trip comparison rejects missing fields, unknown enums, and any
      // payload that would otherwise be normalized during restoration —
      // EXCEPT for `runSeed` (SEEDED-RNG-REUSE-1): a save persisted before
      // that field existed must go on being playable rather than being
      // discarded as a whole new game, so a missing/invalid `runSeed` is
      // spliced into the comparison baseline using the exact deterministic
      // fallback `PublicDemoState.fromJson` already derived for it — every
      // other field is still required to match exactly, unchanged from
      // before this field existed.
      // Codex P1 fix (PR #212): CORE-GAMEPLAY Phase 5 added two more
      // additive, fallback-defaulted fields — [PublicDemoWorkflowState
      // .matchingProposals] and [PublicDemoEngineerRuntime
      // .totalItExperienceMonths] — exactly like `runSeed`
      // (SEEDED-RNG-REUSE-1) before them: a save written before either
      // field existed decodes fine (their own `fromJson` supplies a
      // backward-compatible default), but without splicing that resolved
      // default into [baseline] here too, the strict round-trip below would
      // find the re-encoded aggregate now carrying a key the original
      // payload never had, fail the comparison, and reject the ENTIRE
      // legacy save — silently discarding real player progress. Both
      // splices are no-ops (return their input unchanged) once a save
      // genuinely already has these keys.
      //
      // PR #214 main-integration fix: the exact same class of gap was found
      // to still apply, unfixed, to TWO more additive
      // [PublicDemoWorkflowState] fields — [interviewSessions] (CORE-
      // GAMEPLAY Phase 3, present since before Phase 5's own Codex P1 fix
      // above but never itself spliced here) and [projectInterviewSessions]
      // (CORE-GAMEPLAY Phase 6). Both were verified, before this fix, to
      // make `fromJson` reject an otherwise-valid save missing either key
      // outright (a legacy save predating Phase 3, or any save predating
      // Phase 6) — exactly the same "reject the ENTIRE legacy save" failure
      // mode this comment already documents for `matchingProposals`/
      // `totalItExperienceMonths`. Spliced the same way, for the same
      // reason.
      //
      // Codex P1-2 fix (PR #214): the same gap again, for a THIRD kind —
      // not a whole additive top-level field this time, but a new,
      // always-emitted key (`interviewRecordProjectId`) inside each
      // `workflow.engineers` entry. Every save written before this fix has
      // no such key on any engineer entry at all (`null` for one every
      // engineer already had — see [_withMigratedInterviewRecordProjectId]'s
      // own doc), so it is spliced in the same per-entry way
      // [_withMigratedEngineerRuntimeExperience] already splices
      // `totalItExperienceMonths`.
      var baseline = _withMigratedRunSeed(json, aggregate.state.runSeed);
      baseline = _withMigratedMatchingProposals(
        baseline,
        aggregate.workflow.matchingProposals
            .map((proposal) => proposal.toJson())
            .toList(),
      );
      baseline = _withMigratedEngineerRuntimeExperience(
        baseline,
        aggregate.state.engineerRuntimes,
      );
      baseline = _withMigratedInterviewSessions(
        baseline,
        aggregate.workflow.interviewSessions
            .map((session) => session.toJson())
            .toList(),
      );
      baseline = _withMigratedProjectInterviewSessions(
        baseline,
        aggregate.workflow.projectInterviewSessions
            .map((session) => session.toJson())
            .toList(),
      );
      baseline = _withMigratedInterviewRecordProjectId(baseline);
      // CORE-GAMEPLAY Phase 7A: the same additive-new-key-inside-each-entry
      // gap as `interviewRecordProjectId` above, this time for
      // `workflow.assignments[*].projectId` (see [PublicDemoAssignment
      // .projectId]'s own doc) — every save written before this field
      // existed has no such key on any assignment entry at all.
      baseline = _withMigratedAssignmentProjectId(baseline);
      if (_canonicalJson(baseline) != _canonicalJson(toJson(aggregate))) {
        return null;
      }
      return aggregate;
    } catch (_) {
      return null;
    }
  }

  /// Codex P2 fix (PR #214) "Validate restored accumulated interview
  /// evaluation": recomputes each [ClientInterviewSession]'s
  /// `accumulatedEvaluation` from its own authoritative
  /// `questions`/`employeeAnswers`/`playerFollowUps` — via
  /// [ClientInterviewEngine.evaluate], the exact same call
  /// [PublicDemoProjectInterview.chooseFollowUp] itself makes, never a
  /// second formula — and rejects the save if the recomputed total
  /// disagrees with the stored one. Runs on the already-decoded
  /// [aggregate] (not raw JSON, unlike [_hasConsistentAuthorityFacts]
  /// above) because it needs real [Engineer]/[ClientInterviewSession]
  /// values, not just their JSON shape.
  ///
  /// Every index this walks (`questions[i]`/`employeeAnswers[i]` for
  /// `i < playerFollowUps.length`) is already guaranteed in-bounds by the
  /// P2-1 structural checks in [_hasConsistentAuthorityFacts] (which always
  /// runs first — see [fromJson]) — `employeeAnswers.length ==
  /// currentQuestionIndex + 1` and `playerFollowUps.length` is either
  /// `currentQuestionIndex` or, only once fully answered, `questions.length`
  /// — so `playerFollowUps.length` never exceeds `employeeAnswers.length`
  /// or `questions.length` in a save that reached this point.
  ///
  /// Codex P2 fix (PR #214) "Reject restored follow-ups that were never
  /// offered": before replaying each `playerFollowUps[i]` through
  /// [ClientInterviewEngine.evaluate], it must be one of
  /// [ClientInterviewEngine.choices] for `questions[i]` — the exact same
  /// membership check [PublicDemoProjectInterview.chooseFollowUp] itself
  /// already enforces at write time (never a new choice-validity rule
  /// invented here). `evaluate` has no such guard of its own — it accepts
  /// any [ClientInterviewFollowUp] value — so a shape-valid save that
  /// swaps a recorded follow-up for one `choices` never actually offered
  /// for that question (with `accumulatedEvaluation` doctored to match
  /// `evaluate`'s own output for the substituted value) would otherwise
  /// replay "successfully" and round-trip clean, even though live gameplay
  /// can never produce that combination.
  static bool _hasConsistentProjectInterviewEvaluations(
    PublicDemoAggregate aggregate,
  ) {
    for (final session in aggregate.workflow.projectInterviewSessions) {
      if (session.playerFollowUps.isEmpty) continue;
      final runtime = aggregate.state.runtimeForOrNull(session.employeeId);
      if (runtime == null) return false;
      final engineer = PublicDemoEngineerProjectFit.engineerFor(runtime);
      final seed = PublicDemoRng.derivedSeed(
        runSeed: aggregate.state.runSeed,
        month: session.startedWeek,
        namespace: PublicDemoRngNamespace.projectInterview,
        identifier: '${session.employeeId}:${session.projectId}',
      );
      var recomputed = const ClientInterviewEvaluation();
      for (var i = 0; i < session.playerFollowUps.length; i++) {
        final question = session.questions[i];
        final followUp = session.playerFollowUps[i];
        if (!ClientInterviewEngine.choices(question).contains(followUp)) {
          return false;
        }
        final outcome = ClientInterviewEngine.evaluate(
          engineer,
          question,
          session.employeeAnswers[i],
          followUp,
          seed,
          session.id,
        );
        recomputed = recomputed.add(
          technical: outcome.evaluation.technical,
          experience: outcome.evaluation.experience,
          communication: outcome.evaluation.communication,
          credibility: outcome.evaluation.credibility,
          clientFit: outcome.evaluation.clientFit,
        );
      }
      final stored = session.accumulatedEvaluation;
      if (recomputed.technical != stored.technical ||
          recomputed.experience != stored.experience ||
          recomputed.communication != stored.communication ||
          recomputed.credibility != stored.credibility ||
          recomputed.clientFit != stored.clientFit) {
        return false;
      }
    }
    return true;
  }

  /// Rejects combinations that are individually serializable but impossible
  /// to obtain from the authoritative Public Demo command path. Persistence
  /// must restore authority, not mint it from caller-controlled JSON fields.
  static bool _hasConsistentAuthorityFacts(Map<String, dynamic> envelope) {
    final aggregateRaw = envelope['aggregate'];
    if (aggregateRaw is! Map) return false;
    final aggregate = aggregateRaw.cast<String, dynamic>();
    final stateRaw = aggregate['state'];
    final workflowRaw = aggregate['workflow'];
    if (stateRaw is! Map || workflowRaw is! Map) return false;
    final state = stateRaw.cast<String, dynamic>();
    final workflow = workflowRaw.cast<String, dynamic>();

    final cash = state['cash'];
    final status = state['financialStatus'];
    final month = state['month'];
    final fiscalYearCompleted = state['fiscalYearCompleted'];
    final monthOpeningCash = state['monthOpeningCash'];
    final trainingSpent = state['monthTrainingSpent'];
    final recruitmentSpent = state['monthRecruitmentSpent'];
    final pendingRevenue = state['pendingRevenue'];
    if (cash is! int ||
        status is! String ||
        month is! int ||
        fiscalYearCompleted is! bool ||
        monthOpeningCash is! int ||
        trainingSpent is! int ||
        recruitmentSpent is! int ||
        pendingRevenue is! int) {
      return false;
    }

    const negativeStatuses = {
      'cashShortage',
      'bankruptcy',
      'marchCashShortageFailure',
    };
    if (cash < 0) {
      if (!negativeStatuses.contains(status)) return false;
    } else if (status != 'normal') {
      return false;
    }
    if (fiscalYearCompleted && (month != 15 || status != 'normal')) {
      return false;
    }
    if (trainingSpent < 0 ||
        recruitmentSpent < 0 ||
        cash != monthOpeningCash - trainingSpent - recruitmentSpent) {
      return false;
    }

    final latestFlowRaw = state['latestMonthlyCashFlow'];
    if (latestFlowRaw != null) {
      if (latestFlowRaw is! Map) return false;
      final flow = latestFlowRaw.cast<String, dynamic>();
      final openingCash = flow['openingCash'];
      final cashReceived = flow['cashReceived'];
      final salaryPaid = flow['salaryPaid'];
      final fixedCostsPaid = flow['fixedCostsPaid'];
      final bonusPaid = flow['bonusPaid'];
      final trainingCost = flow['trainingCost'];
      final recruitmentCost = flow['recruitmentCost'];
      final closingCash = flow['closingCash'];
      final revenue = flow['revenue'];
      final receivables = flow['receivables'];
      if (openingCash is! int ||
          cashReceived is! int ||
          salaryPaid is! int ||
          fixedCostsPaid is! int ||
          bonusPaid is! int ||
          trainingCost is! int ||
          recruitmentCost is! int ||
          closingCash is! int ||
          revenue is! int ||
          receivables is! int) {
        return false;
      }
      if (openingCash +
                  cashReceived -
                  salaryPaid -
                  fixedCostsPaid -
                  bonusPaid -
                  trainingCost -
                  recruitmentCost !=
              closingCash ||
          closingCash != monthOpeningCash ||
          revenue != receivables ||
          pendingRevenue != receivables) {
        return false;
      }
    }

    final engineersRaw = workflow['engineers'];
    final assignmentsRaw = workflow['assignments'];
    if (engineersRaw is! List || assignmentsRaw is! List) return false;
    final assignmentEngineerIds = <String>{};
    // CORE-GAMEPLAY Phase 7A: [PublicDemoAssignment.projectId], keyed by
    // its own `engineerId` — cross-checked below against each engineer's
    // `interviewRecordProjectId`, mirroring the proposal/session
    // cross-checks already performed for that same field further down.
    final assignmentProjectIdByEngineer = <String, String?>{};
    for (final entry in assignmentsRaw) {
      if (entry is! Map) return false;
      final engineerId = entry['engineerId'];
      if (engineerId is! String) return false;
      // [_validateForPersistence] already rejects a duplicate `engineerId`
      // across [PublicDemoWorkflowState.assignments] post-decode; a save
      // reaching that check with two entries for the same id would fail
      // there regardless, but a `Map` build here would otherwise silently
      // let the second entry's `projectId` overwrite the first's for this
      // cross-check specifically — reject outright instead, exactly like
      // the duplicate-matching-proposal case below.
      if (assignmentEngineerIds.contains(engineerId)) return false;
      assignmentEngineerIds.add(engineerId);
      final assignmentProjectId = entry['projectId'];
      if (assignmentProjectId != null && assignmentProjectId is! String) {
        return false;
      }
      assignmentProjectIdByEngineer[engineerId] = assignmentProjectId as String?;
    }
    final engineerIds = <String>{};

    // Codex P2 fix (PR #214): "Validate restored passes against their
    // proposals". A genuine Phase 6 pass (`interviewRecordProjectId !=
    // null`) can only ever exist because [PublicDemoProjectInterview.start]
    // read a real [PublicDemoMatchingProposal] for this exact engineer and
    // interviewed for precisely that proposal's `projectId` —
    // [PublicDemoWorkflowState.withMatchingProposal] then refuses to ever
    // replace that proposal once the engineer reaches
    // `clientInterviewPassed`/`ordered` (the Codex P1-2 fix's own "proposal
    // lock"), so for any real save the two must always still agree. The
    // proposal-lock check above only prevents a NEW mismatch from being
    // produced going forward — it does nothing to stop a corrupted/
    // hand-edited save from simply asserting `interviewRecordProjectId: A`
    // on an engineer whose (equally hand-edited) `matchingProposals` entry
    // still names a different, never-interviewed project `B`. Restoring
    // such a save would let `recordOrder`/`projectInterviewCandidateFor`
    // resolve project `B` for an engineer whose only real, derived
    // authority fact is a pass on project `A` — exactly the
    // never-interviewed-project handoff the runtime lock exists to
    // prevent. Cross-checking both facts here, at restore time, closes the
    // gap the runtime-only lock cannot: a corrupted save is rejected
    // instead of silently resurrecting a broken authority chain.
    final matchingProposalsRaw = workflow['matchingProposals'];
    final proposalProjectIdByEngineer = <String, String>{};
    if (matchingProposalsRaw != null) {
      if (matchingProposalsRaw is! List) return false;
      for (final entry in matchingProposalsRaw) {
        if (entry is! Map) return false;
        final proposal = entry.cast<String, dynamic>();
        final proposalEngineerId = proposal['engineerId'];
        final proposalProjectId = proposal['projectId'];
        if (proposalEngineerId is! String || proposalProjectId is! String) {
          return false;
        }
        // Codex P2 fix (PR #214) "Reject duplicate proposals before
        // validating pass bindings": [PublicDemoWorkflowState
        // .withMatchingProposal] always filters out any existing entry for
        // `engineerId` before appending the new one — at most one proposal
        // per engineer is the only shape any real command path can ever
        // produce, exactly like [projectInterviewSessions]'s own
        // one-per-employeeId invariant above. Building this lookup as a
        // plain `Map` assignment silently let a SECOND, later entry for the
        // same `engineerId` overwrite the first one here, while
        // [PublicDemoWorkflowState.matchingProposalFor] (the one production
        // code actually calls) returns the FIRST match instead — so a
        // corrupted save with e.g. `[project B, project A]` would validate
        // the pass record against A (this map's last-write) while runtime
        // resolves B (the real first-match lookup), letting `recordOrder`
        // proceed for the project the engineer was actually bound to (B)
        // while this check believed A was cross-checked. A second entry for
        // the same engineer is rejected outright rather than resolved by
        // either "first wins" or "last wins" — neither can be produced by
        // any real command path, so there is no correct value to prefer.
        if (proposalProjectIdByEngineer.containsKey(proposalEngineerId)) {
          return false;
        }
        proposalProjectIdByEngineer[proposalEngineerId] = proposalProjectId;
      }
    }
    // A *completed* [ClientInterviewSession] is the other real, derived
    // fact of which project this engineer was actually interviewed for
    // (see [PublicDemoWorkflowState.concludeProjectInterview]'s own
    // `session.projectId != project.id` guard) — cross-checked too, when
    // present, exactly like the proposal above. Read defensively (not the
    // full structural validation the dedicated block below already
    // performs) since only `employeeId`/`projectId`/`completed` are needed
    // here; a genuinely malformed entry is still rejected by that block
    // regardless of what this lookup does with it.
    final projectInterviewSessionsForCrossCheck =
        workflow['projectInterviewSessions'];
    final completedSessionProjectIdByEngineer = <String, String>{};
    if (projectInterviewSessionsForCrossCheck is List) {
      for (final entry in projectInterviewSessionsForCrossCheck) {
        if (entry is! Map) continue;
        final session = entry.cast<String, dynamic>();
        if (session['completed'] != true) continue;
        final sessionEmployeeId = session['employeeId'];
        final sessionProjectId = session['projectId'];
        if (sessionEmployeeId is String && sessionProjectId is String) {
          completedSessionProjectIdByEngineer[sessionEmployeeId] =
              sessionProjectId;
        }
      }
    }

    for (final entry in engineersRaw) {
      if (entry is! Map) return false;
      final engineer = entry.cast<String, dynamic>();
      final id = engineer['id'];
      final stage = engineer['stage'];
      final score = engineer['lastInterviewScore'];
      final recordId = engineer['interviewRecordEngineerId'];
      // Additive (Codex P1-2 fix, PR #214): absent on any save predating
      // that fix — `null` there, exactly the generic-path semantics such a
      // record already had. A non-null value here means this pass was
      // genuinely minted by CORE-GAMEPLAY Phase 6's own stochastic
      // `ClientInterviewEngine.finalRate` + seeded roll
      // (`public_demo_project_interview.dart`), never
      // `PublicDemoInterviewEvaluator`'s fixed `>= 60` threshold — see the
      // score-floor logic below (Codex P1-1 fix, PR #214).
      final recordProjectId = engineer['interviewRecordProjectId'];
      if (id is! String ||
          stage is! String ||
          (recordProjectId != null && recordProjectId is! String)) {
        return false;
      }
      engineerIds.add(id);

      final clientPassStage =
          stage == 'clientInterviewPassed' || stage == 'ordered';
      // Codex P1-1 fix (PR #214): a genuine Phase 6 pass (`recordProjectId
      // != null`) can legitimately carry ANY `ClientInterviewEngine
      // .finalRate` value in its own clamped `[5, 95]` range — the seeded
      // roll can pass at any rate in that range, not only `>= 60` — so the
      // `>= 60` floor (and, symmetrically, the `<= 95` ceiling that range
      // implies) applies ONLY to a genuine Phase 6 record. A record with no
      // project binding at all (`recordProjectId == null`) is the legacy,
      // project-agnostic `PublicDemoInterviewEvaluator` path, whose own
      // `passed = score >= 60` really is a hard, unconditional floor — this
      // never weakens that check: every pre-Phase-6 save, and every
      // legacy-path pass minted since, still requires `score >= 60`,
      // unchanged, with no new upper bound imposed on it either.
      final isStochasticPass = recordProjectId != null;
      final scoreFloor = isStochasticPass ? 5 : 60;
      bool validScore(Object? value) =>
          value is int &&
          value >= scoreFloor &&
          (!isStochasticPass || value <= 95);
      if (recordId != null) {
        if (recordId is! String ||
            recordId != id ||
            !clientPassStage ||
            !validScore(score)) {
          return false;
        }
      }
      if (clientPassStage && (recordId != id || !validScore(score))) {
        return false;
      }
      if (stage == 'ordered' &&
          month >= 5 &&
          !assignmentEngineerIds.contains(id)) {
        return false;
      }
      // Codex P2 fix (PR #214) "Validate restored passes against their
      // proposals": having survived every check above, this is a genuine
      // project-bound pass — its own recorded project must agree with both
      // the (locked, never-replaceable-post-pass) proposal and, when one
      // exists, the completed interview session, for this same engineer.
      // Legacy generic-path records (`recordProjectId == null`) have no
      // project to cross-check at all and are left exactly as before.
      if (recordProjectId != null) {
        if (proposalProjectIdByEngineer[id] != recordProjectId) return false;
        final completedSessionProjectId =
            completedSessionProjectIdByEngineer[id];
        if (completedSessionProjectId != null &&
            completedSessionProjectId != recordProjectId) {
          return false;
        }
      }
      // CORE-GAMEPLAY Phase 7A: "projectId / engineerId / assignment
      // identity不一致を許可しない" — a present [PublicDemoAssignment
      // .projectId] can only ever have been minted from this exact
      // engineer's own `genuineInterviewProjectId` (see
      // [PublicDemoWorkflowState.assignOrderedForMay]/
      // [recoverLateYearAssignment]'s own doc), so it must agree with
      // `recordProjectId` whenever it is present. Deliberately one-way: a
      // `null` assignment `projectId` is never rejected here even when
      // `recordProjectId` is non-null — that is exactly the legacy-save
      // shape every real save written before this field existed has (a
      // genuine Phase 6 pass already existed pre-Phase-7A; the assignment
      // simply never captured its project link yet), and remains fully
      // loadable.
      final assignmentProjectId = assignmentProjectIdByEngineer[id];
      if (assignmentProjectId != null && assignmentProjectId != recordProjectId) {
        return false;
      }
    }

    // Codex P2-1 fix (PR #214): [ClientInterviewSession.fromJson] only casts
    // fields — it never checks that they describe a coherent interview
    // (non-empty questions, an in-range `currentQuestionIndex`, parallel
    // lists that actually stay in lockstep with it). A hand-edited or
    // otherwise corrupted save with, say, an empty `questions` list or an
    // out-of-range `currentQuestionIndex` decodes without error and
    // round-trips byte-for-byte identical (nothing here is normalized away),
    // so the strict comparison above this method's caller performs would
    // accept it — only for `PublicDemoProjectInterviewDialog`'s own
    // `session.questions[session.currentQuestionIndex]`/
    // `session.employeeAnswers[session.currentQuestionIndex]` indexing to
    // crash the first time the player reopens that interview. Every
    // invariant checked below is a genuine structural fact of every session
    // [PublicDemoProjectInterview.start]/[chooseFollowUp] can ever produce —
    // not a new restriction, just enforcing here what production code
    // already guarantees, so no real save is ever rejected by this.
    final projectInterviewSessionsRaw = workflow['projectInterviewSessions'];
    if (projectInterviewSessionsRaw != null) {
      if (projectInterviewSessionsRaw is! List) return false;
      final seenEmployeeIds = <String>{};
      for (final entry in projectInterviewSessionsRaw) {
        if (entry is! Map) return false;
        final session = entry.cast<String, dynamic>();
        final id = session['id'];
        final applicationId = session['applicationId'];
        final employeeId = session['employeeId'];
        final projectId = session['projectId'];
        final startedWeek = session['startedWeek'];
        final currentQuestionIndex = session['currentQuestionIndex'];
        final questionsRaw = session['questions'];
        final employeeAnswersRaw = session['employeeAnswers'];
        final playerFollowUpsRaw = session['playerFollowUps'];
        final interviewerReactionsRaw = session['interviewerReactions'];
        final completed = session['completed'];
        final result = session['result'];
        if (id is! String ||
            applicationId is! String ||
            employeeId is! String ||
            projectId is! String ||
            startedWeek is! int ||
            currentQuestionIndex is! int ||
            questionsRaw is! List ||
            employeeAnswersRaw is! List ||
            playerFollowUpsRaw is! List ||
            interviewerReactionsRaw is! List ||
            completed is! bool) {
          return false;
        }

        // Identity (Codex P2-1 "employee/project identity"):
        // [PublicDemoProjectInterview.start] always sets
        // `applicationId == projectId` and derives `id` from
        // `employeeId:projectId` — a save with mismatched identity fields
        // did not come from that command, whatever its individual field
        // types check out as.
        if (applicationId != projectId ||
            id != 'public-demo-project-interview:$employeeId:$projectId') {
          return false;
        }
        // Duplicate session identity: [projectInterviewSessionFor]/
        // [startProjectInterviewSession] both assume at most one session per
        // engineer; a second entry for the same `employeeId` is unreachable
        // from any real command path.
        if (!seenEmployeeIds.add(employeeId)) return false;
        // The engineer this session belongs to must actually exist in this
        // same save.
        if (!engineerIds.contains(employeeId)) return false;
        // A session cannot have started after the month this save itself
        // records having reached.
        if (startedWeek < 1 || startedWeek > month) return false;

        final questionCount = questionsRaw.length;
        if (questionCount == 0) return false;
        if (currentQuestionIndex < 0 || currentQuestionIndex >= questionCount) {
          return false;
        }
        // [ClientInterviewEngine.answer] always pre-computes exactly one
        // answer ahead of, and including, the current question — see
        // [PublicDemoProjectInterview.start]/[chooseFollowUp].
        if (employeeAnswersRaw.length != currentQuestionIndex + 1) {
          return false;
        }
        // [chooseFollowUp] advances `currentQuestionIndex` in lockstep with
        // `playerFollowUps.length` for every question except the last (which
        // never advances past itself): `playerFollowUps.length` is either
        // exactly `currentQuestionIndex` (this question not yet answered) or,
        // only once `currentQuestionIndex` is the final index, exactly
        // `questionCount` (every question answered, ready for
        // [PublicDemoProjectInterview.conclude]).
        final followUpCount = playerFollowUpsRaw.length;
        final readyToConclude =
            currentQuestionIndex == questionCount - 1 &&
            followUpCount == questionCount;
        if (followUpCount != currentQuestionIndex && !readyToConclude) {
          return false;
        }
        // [interviewerReactions] is appended exactly once per
        // [playerFollowUps] entry, in the same [chooseFollowUp] call.
        if (interviewerReactionsRaw.length != followUpCount) return false;
        // completed/incomplete session invariants: only [conclude] ever sets
        // `completed`, and only once [isReadyToConclude] holds, always
        // together with a genuine `result`.
        if (completed) {
          if (!readyToConclude || (result != 'passed' && result != 'failed')) {
            return false;
          }
        } else if (result != null) {
          return false;
        }
      }
    }

    return true;
  }

  /// Splices [resolvedRunSeed] into a copy of [envelope]'s
  /// `aggregate.state.runSeed` only when it isn't already an int there —
  /// i.e. only for a save that predates that field (SEEDED-RNG-REUSE-1) or
  /// carries a corrupted one. Returns [envelope] itself, unchanged,
  /// otherwise — a save that already has a genuine `runSeed` must still
  /// match it exactly on the strict round trip like every other field.
  static Map<String, dynamic> _withMigratedRunSeed(
    Map<String, dynamic> envelope,
    int resolvedRunSeed,
  ) {
    final aggregate = (envelope['aggregate'] as Map).cast<String, dynamic>();
    final state = (aggregate['state'] as Map).cast<String, dynamic>();
    if (state['runSeed'] is int) return envelope;
    return {
      ...envelope,
      'aggregate': {
        ...aggregate,
        'state': {...state, 'runSeed': resolvedRunSeed},
      },
    };
  }

  /// Splices [resolvedMatchingProposals] (the already-decoded, defaulted
  /// value — `[]` for a save predating CORE-GAMEPLAY Phase 5) into a copy of
  /// [envelope]'s `aggregate.workflow.matchingProposals` only when that key
  /// is absent there. Mirrors [_withMigratedRunSeed]'s own shape/doc.
  static Map<String, dynamic> _withMigratedMatchingProposals(
    Map<String, dynamic> envelope,
    List<Map<String, dynamic>> resolvedMatchingProposals,
  ) {
    final aggregate = (envelope['aggregate'] as Map).cast<String, dynamic>();
    final workflow = (aggregate['workflow'] as Map).cast<String, dynamic>();
    if (workflow.containsKey('matchingProposals')) return envelope;
    return {
      ...envelope,
      'aggregate': {
        ...aggregate,
        'workflow': {...workflow, 'matchingProposals': resolvedMatchingProposals},
      },
    };
  }

  /// Splices [resolvedInterviewSessions] (the already-decoded, defaulted
  /// value — `[]` for a save predating CORE-GAMEPLAY Phase 3) into a copy of
  /// [envelope]'s `aggregate.workflow.interviewSessions` only when that key
  /// is absent there. Mirrors [_withMigratedMatchingProposals]'s own
  /// shape/doc (PR #214 main-integration fix: this additive field predates
  /// `matchingProposals` but was never itself spliced here until now).
  static Map<String, dynamic> _withMigratedInterviewSessions(
    Map<String, dynamic> envelope,
    List<Map<String, dynamic>> resolvedInterviewSessions,
  ) {
    final aggregate = (envelope['aggregate'] as Map).cast<String, dynamic>();
    final workflow = (aggregate['workflow'] as Map).cast<String, dynamic>();
    if (workflow.containsKey('interviewSessions')) return envelope;
    return {
      ...envelope,
      'aggregate': {
        ...aggregate,
        'workflow': {...workflow, 'interviewSessions': resolvedInterviewSessions},
      },
    };
  }

  /// Splices [resolvedProjectInterviewSessions] (the already-decoded,
  /// defaulted value — `[]` for a save predating CORE-GAMEPLAY Phase 6)
  /// into a copy of [envelope]'s
  /// `aggregate.workflow.projectInterviewSessions` only when that key is
  /// absent there. Mirrors [_withMigratedMatchingProposals]'s own shape/doc.
  static Map<String, dynamic> _withMigratedProjectInterviewSessions(
    Map<String, dynamic> envelope,
    List<Map<String, dynamic>> resolvedProjectInterviewSessions,
  ) {
    final aggregate = (envelope['aggregate'] as Map).cast<String, dynamic>();
    final workflow = (aggregate['workflow'] as Map).cast<String, dynamic>();
    if (workflow.containsKey('projectInterviewSessions')) return envelope;
    return {
      ...envelope,
      'aggregate': {
        ...aggregate,
        'workflow': {
          ...workflow,
          'projectInterviewSessions': resolvedProjectInterviewSessions,
        },
      },
    };
  }

  /// Splices each already-decoded [PublicDemoEngineerRuntime
  /// .totalItExperienceMonths] (per [resolvedRuntimes], in the same order as
  /// `aggregate.state.engineerRuntimes`) into a copy of [envelope]'s own
  /// `engineerRuntimes` entries, but only for an entry that doesn't already
  /// carry that key — a save from before CORE-GAMEPLAY Phase 5's Codex P1
  /// fix. Mirrors [_withMigratedRunSeed]'s own shape/doc. Deliberately does
  /// not handle `engineerRuntimes` being entirely absent (a save predating
  /// EG-1) or having a different length than [resolvedRuntimes] — neither
  /// is a scenario this fix's own field-level default was written for.
  static Map<String, dynamic> _withMigratedEngineerRuntimeExperience(
    Map<String, dynamic> envelope,
    List<PublicDemoEngineerRuntime> resolvedRuntimes,
  ) {
    final aggregate = (envelope['aggregate'] as Map).cast<String, dynamic>();
    final state = (aggregate['state'] as Map).cast<String, dynamic>();
    final runtimesRaw = state['engineerRuntimes'];
    if (runtimesRaw is! List || runtimesRaw.length != resolvedRuntimes.length) {
      return envelope;
    }
    var changed = false;
    final migratedRuntimes = <Map<String, dynamic>>[];
    for (var i = 0; i < runtimesRaw.length; i++) {
      final entry = (runtimesRaw[i] as Map).cast<String, dynamic>();
      if (entry.containsKey('totalItExperienceMonths')) {
        migratedRuntimes.add(entry);
      } else {
        changed = true;
        migratedRuntimes.add({
          ...entry,
          'totalItExperienceMonths': resolvedRuntimes[i].totalItExperienceMonths,
        });
      }
    }
    if (!changed) return envelope;
    return {
      ...envelope,
      'aggregate': {
        ...aggregate,
        'state': {...state, 'engineerRuntimes': migratedRuntimes},
      },
    };
  }

  /// Splices a `null` `interviewRecordProjectId` into each
  /// `aggregate.workflow.engineers` entry that doesn't already carry that
  /// key — a save from before CORE-GAMEPLAY Phase 6's Codex P1-2 fix.
  /// Mirrors [_withMigratedEngineerRuntimeExperience]'s own per-entry
  /// shape/doc, but the backward-compatible value is always `null` here
  /// (never a value resolved per-entry): every
  /// [PublicDemoEngineerInterviewRecord] minted before this fix existed was
  /// necessarily the generic, project-agnostic
  /// [PublicDemoEngineerSales.evaluateInterview] kind — see
  /// [PublicDemoEngineerInterviewRecord.projectId]'s own doc — so `null` is
  /// the genuinely correct value for every one of them, not a placeholder.
  /// Deliberately does not handle `engineers` being entirely absent — no
  /// save predates that field.
  static Map<String, dynamic> _withMigratedInterviewRecordProjectId(
    Map<String, dynamic> envelope,
  ) {
    final aggregate = (envelope['aggregate'] as Map).cast<String, dynamic>();
    final workflow = (aggregate['workflow'] as Map).cast<String, dynamic>();
    final engineersRaw = workflow['engineers'];
    if (engineersRaw is! List) return envelope;
    var changed = false;
    final migratedEngineers = <Map<String, dynamic>>[];
    for (final raw in engineersRaw) {
      final entry = (raw as Map).cast<String, dynamic>();
      if (entry.containsKey('interviewRecordProjectId')) {
        migratedEngineers.add(entry);
      } else {
        changed = true;
        migratedEngineers.add({...entry, 'interviewRecordProjectId': null});
      }
    }
    if (!changed) return envelope;
    return {
      ...envelope,
      'aggregate': {
        ...aggregate,
        'workflow': {...workflow, 'engineers': migratedEngineers},
      },
    };
  }

  /// Splices a `null` `projectId` into each `aggregate.workflow.assignments`
  /// entry that doesn't already carry that key — a save from before
  /// CORE-GAMEPLAY Phase 7A. Mirrors
  /// [_withMigratedInterviewRecordProjectId]'s own per-entry shape/doc: the
  /// backward-compatible value is always `null` here too — every assignment
  /// persisted before this field existed was necessarily built without any
  /// notion of a real Phase 6 project link (see [PublicDemoAssignment
  /// .projectId]'s own doc), so `null` is the genuinely correct value for
  /// every one of them, not a placeholder. Deliberately does not handle
  /// `assignments` being entirely absent — no save predates that field.
  static Map<String, dynamic> _withMigratedAssignmentProjectId(
    Map<String, dynamic> envelope,
  ) {
    final aggregate = (envelope['aggregate'] as Map).cast<String, dynamic>();
    final workflow = (aggregate['workflow'] as Map).cast<String, dynamic>();
    final assignmentsRaw = workflow['assignments'];
    if (assignmentsRaw is! List) return envelope;
    var changed = false;
    final migratedAssignments = <Map<String, dynamic>>[];
    for (final raw in assignmentsRaw) {
      final entry = (raw as Map).cast<String, dynamic>();
      if (entry.containsKey('projectId')) {
        migratedAssignments.add(entry);
      } else {
        changed = true;
        migratedAssignments.add({...entry, 'projectId': null});
      }
    }
    if (!changed) return envelope;
    return {
      ...envelope,
      'aggregate': {
        ...aggregate,
        'workflow': {...workflow, 'assignments': migratedAssignments},
      },
    };
  }

  static String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.map((entry) {
        if (entry.key is! String) {
          throw const FormatException('Save object keys must be strings');
        }
        return MapEntry(entry.key as String, _canonicalize(entry.value));
      }).toList()..sort((left, right) => left.key.compareTo(right.key));
      return {for (final entry in entries) entry.key: entry.value};
    }
    if (value is List) return value.map(_canonicalize).toList();
    if (value is String || value is num || value is bool || value == null) {
      return value;
    }
    throw const FormatException('Unsupported save value');
  }
}
