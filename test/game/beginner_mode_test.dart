// Phase 3A (S.E.S. Development Plan §3.2): April-June Beginner Mode
// continuation, tested at the engine level per the Phase 3A test brief
// (Tests A-J). `playThroughPrologue` (imported below) already drives a
// full, seeded Founding Prologue playthrough through to April Week 1's
// first assignment — these tests pick up from there and continue driving
// `GameEngine.advanceWeek` the same way `GameController._apply` would,
// including the reconcile chain (`PrologueEngine.reconcileState` ->
// `ProgressionEngine.reconcile` -> `BeginnerModeEngine.reconcile`).
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'prologue_engine_test.dart' show playThroughPrologue;
import 'test_helpers.dart';

/// Mirrors `GameController._apply`'s reconcile chain — every test below
/// mutates through this instead of calling engines piecemeal, so these tests
/// exercise Phase 3A exactly the way real play does.
GameState _apply(GameState state, GameState Function(GameState) mutate) =>
    BeginnerModeEngine.reconcile(ProgressionEngine.reconcile(PrologueEngine.reconcileState(mutate(state))));

GameState _advanceWeek(GameState state) => _apply(state, GameEngine.advanceWeek);

/// Plays a full Founding Prologue through April Week 1's first assignment,
/// then taps "経営を始める" (`PrologueEngine.completePrologue`) — the exact
/// point Phase 3A guidance is supposed to pick up from instead of handing
/// the player straight to unrestricted free management.
GameState _reachBeginnerManagement(int seed) {
  var state = playThroughPrologue(seed);
  expect(state.activeAssignments, isNotEmpty, reason: 'seed $seed must reach first assignment for this suite to mean anything');
  state = _apply(state, PrologueEngine.completePrologue);
  return state;
}

void main() {
  group('Phase 3A — Test A: Beginner Mode continues past first assignment', () {
    test('the old founding tutorial finishes, but Phase 3A guidance keeps going', () {
      final state = _reachBeginnerManagement(11);

      // The March founding tutorial (FoundingProgress/ProgressionEngine) is
      // legitimately done — this is not what changed.
      expect(ProgressionEngine.currentStage(state), FoundingStage.freeManagement);

      // Phase 3A is a *separate* continuation, not gated by the old
      // tutorial's completion.
      expect(BeginnerModeEngine.isBeginnerJourney(state), isTrue);
      expect(BeginnerModeEngine.isPhase3AActive(state), isTrue);
      expect(state.beginnerModeState.has(BeginnerMilestone.managementPhaseStarted), isTrue);
    });

    test('stays active week to week through June, then ends naturally at week 13 (no dead end)', () {
      var state = _reachBeginnerManagement(11);
      expect(state.week, 1);

      for (var w = state.week; w < BeginnerModeEngine.lastWeek; w++) {
        state = _advanceWeek(state);
        expect(state.status, GameStatus.playing, reason: 'week ${state.week} unexpectedly ended the game');
        expect(BeginnerModeEngine.isPhase3AActive(state), isTrue, reason: 'Phase 3A should still be active at week ${state.week}');
      }

      expect(state.week, BeginnerModeEngine.lastWeek);
      state = _advanceWeek(state);
      expect(state.week, BeginnerModeEngine.lastWeek + 1);
      expect(BeginnerModeEngine.isPhase3AActive(state), isFalse, reason: 'Phase 3A should gracefully end once July starts');
      // Ending is not a dead end — the game itself is still playable.
      expect(state.status, GameStatus.playing);
    });
  });

  group('Phase 3A — Test B/C: revenue != cash milestone', () {
    test('fires once, the moment the existing first-assignment/first-AR tutorials are shown', () {
      var state = _reachBeginnerManagement(11);
      // In the real UI this is marked seen on the Prologue completion
      // screen and/or via the first-AR dialog; simulate that UI action here
      // to exercise the underlying reconciliation.
      expect(state.beginnerModeState.has(BeginnerMilestone.revenueVsCashExplained), isFalse, reason: 'not shown until the existing celebration/AR dialog actually fires');

      state = _apply(state, (s) => GameEngine.markTutorialSeen(s, OneTimeEvent.firstAssignmentCelebration));
      expect(state.beginnerModeState.has(BeginnerMilestone.revenueVsCashExplained), isTrue);

      // Idempotent / one-time: re-running reconcile (as every mutation
      // does) never un-marks or duplicates it.
      final before = state.beginnerModeState.milestoneWeeks[BeginnerMilestone.revenueVsCashExplained];
      state = _advanceWeek(state);
      expect(state.beginnerModeState.milestoneWeeks[BeginnerMilestone.revenueVsCashExplained], before);
    });

    test('save/load round-trip: an already-shown milestone never re-fires (Test C)', () {
      var state = _reachBeginnerManagement(11);
      state = _apply(state, (s) => GameEngine.markTutorialSeen(s, OneTimeEvent.firstArTutorial));
      expect(state.beginnerModeState.has(BeginnerMilestone.revenueVsCashExplained), isTrue);

      final reloaded = GameState.fromJson(state.toJson());
      expect(reloaded.beginnerModeState.has(BeginnerMilestone.revenueVsCashExplained), isTrue);
      expect(
        BeginnerModeEngine.pendingMilestones(reloaded, BeginnerModeEngine.weeklyMilestones + const [BeginnerMilestone.revenueVsCashExplained]),
        isNot(contains(BeginnerMilestone.revenueVsCashExplained)),
      );
    });
  });

  group('Phase 3A — Test D: first cash collection milestone', () {
    test('becomes pending exactly once an AR record is actually paid, then fires once shown (real UI two-step)', () {
      var state = _reachBeginnerManagement(5);
      expect(state.beginnerModeState.has(BeginnerMilestone.firstCollectionCelebrated), isFalse);

      GameState? afterFirstCollection;
      var weeks = 0;
      // Payment sites are 30 or 60 days (one or two months out) — 20 weeks
      // is a generous bound that comfortably covers either case without the
      // test caring which one this seed drew.
      while (afterFirstCollection == null && weeks < 20) {
        state = _advanceWeek(state);
        weeks++;
        if (state.accountsReceivable.any((ar) => ar.status == ArStatus.paid)) {
          afterFirstCollection = state;
        }
      }

      expect(afterFirstCollection, isNotNull, reason: 'expected at least one AR collection within $weeks weeks');
      // The fact is true, but — mirroring exactly how Home's
      // _showPendingBeginnerEvents/markBeginnerMilestoneShown work — it
      // isn't marked "shown" by reconcile alone; reconcile must never
      // silently consume a milestone before the player's dialog actually
      // displays it (this was a real bug caught by the Phase 3A Playwright
      // run: the dialog never appeared because reconcile marked it shown a
      // tick too early).
      expect(state.beginnerModeState.has(BeginnerMilestone.firstCollectionCelebrated), isFalse);
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), contains(BeginnerMilestone.firstCollectionCelebrated));

      final closing = state.monthlyClosings.firstWhere((c) => c.cashCollected > 0);
      expect(closing.cashCollected, greaterThan(0));

      // The UI now shows the dialog and marks it shown (GameController.markBeginnerMilestoneShown).
      state = _apply(state, (s) => BeginnerModeEngine.markShown(s, BeginnerMilestone.firstCollectionCelebrated));
      expect(state.beginnerModeState.has(BeginnerMilestone.firstCollectionCelebrated), isTrue);
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), isNot(contains(BeginnerMilestone.firstCollectionCelebrated)));

      // One-time: the milestone week doesn't move on further weeks/closings.
      final firedWeek = state.beginnerModeState.milestoneWeeks[BeginnerMilestone.firstCollectionCelebrated];
      state = _advanceWeek(state);
      expect(state.beginnerModeState.milestoneWeeks[BeginnerMilestone.firstCollectionCelebrated], firedWeek);
    });
  });

  group('Phase 3A — Test E/F: waiting-cost guidance', () {
    test('Test E: becomes pending once a second employee is genuinely waiting on salary, fires once shown', () {
      var state = _reachBeginnerManagement(11);
      expect(state.waitingEngineerCount, 0, reason: 'the founding hire is assigned, not waiting');
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), isNot(contains(BeginnerMilestone.waitingCostExplained)));

      final waiter = buildEngineer(id: 'waiter-1', salary: 350000, status: EngineerStatus.waiting);
      state = state.copyWith(engineers: [...state.engineers, waiter], company: state.company.copyWith(engineerIds: [...state.company.engineerIds, waiter.id]));
      state = _advanceWeek(state); // waitingStreak now accrues for the new waiter

      expect(state.waitingStreak[waiter.id], greaterThanOrEqualTo(1));
      // Pending (ready for Home to show it), not yet marked shown — same
      // fact-vs-shown split as Test D above.
      expect(state.beginnerModeState.has(BeginnerMilestone.waitingCostExplained), isFalse);
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), contains(BeginnerMilestone.waitingCostExplained));
      expect(BeginnerModeEngine.waitingSalaryTotal(state), 350000);

      state = _apply(state, (s) => BeginnerModeEngine.markShown(s, BeginnerMilestone.waitingCostExplained));
      expect(state.beginnerModeState.has(BeginnerMilestone.waitingCostExplained), isTrue);
    });

    test('Test F: never fires when there is no waiting employee', () {
      var state = _reachBeginnerManagement(11);
      for (var i = 0; i < 4; i++) {
        state = _advanceWeek(state);
        expect(state.waitingEngineerCount, 0);
        expect(state.beginnerModeState.has(BeginnerMilestone.waitingCostExplained), isFalse);
      }
    });

    // CI investigation follow-up (PR #15, CI run 32023887460): the real-UI
    // Playwright E2E (beginner-mode-waiting-and-recruitment.spec.ts) proves
    // the milestone fires through the *full* stack (real hire clicks, real
    // RNG accept/decline rolls, real UI navigation) but is inherently
    // probabilistic and slow — a single flaky interview/navigation step
    // anywhere in a 9-candidate loop can obscure whether a failure is a
    // genuine milestone regression or just an unlucky roll/CI timing hiccup
    // (exactly what happened investigating that CI run: engine-level replay
    // showed the milestone firing correctly, so the CI failure was never a
    // milestone bug at all). Test E above already covers the milestone
    // *condition* deterministically, but by injecting an already-`waiting`
    // Engineer directly — it never exercises the actual
    // `PendingHire` -> `advanceWeek` join transition
    // (`GameEngine.advanceWeek`'s "3. 入社予定者処理" step) that both the
    // real player and the E2E actually depend on. This test closes that gap
    // without any RNG/interview dependency: a `PendingHire` is constructed
    // directly (as if `GameEngine.hireApplicant`'s accept roll had already
    // succeeded), so this is the fast, deterministic "logic verification"
    // half the investigation asked to separate from "full-playthrough
    // verification" (the Playwright E2E, which stays as the real-UI sanity
    // check).
    test('Test E2: PendingHire -> join -> waiting -> waiting-cost milestone, with no interview/RNG involved', () {
      var state = _reachBeginnerManagement(11);
      expect(state.pendingHires, isEmpty);
      expect(state.waitingEngineerCount, 0);

      // Mirrors exactly what `GameEngine.hireApplicant` produces the moment
      // `RecruitmentEngine.rollAcceptance` succeeds — never touching that
      // roll, or the interview flow that feeds its `companyImpression`, at
      // all.
      final applicant = buildApplicant(id: 'pending-applicant-1', name: 'テスト 応募者');
      final pendingHire = PendingHire(
        id: 'pending-hire-1',
        applicant: applicant,
        salary: 350000,
        decisionWeek: state.week,
        joinWeek: state.week + 1,
      );
      state = state.copyWith(pendingHires: [...state.pendingHires, pendingHire]);

      // Week N -> N+1: `GameEngine.advanceWeek`'s own "入社予定者処理" step
      // mints a real `Engineer` (status `waiting`) for anyone whose
      // `joinWeek` matches — and, in that very same call, the "待機延べ週数
      // の更新" step immediately counts them as waiting for 1 week (both
      // steps read the *same* end-of-advanceWeek `engineers` list — see
      // `beginner_mode_engine.dart`'s `waitingCostExplained` doc comment).
      state = _advanceWeek(state);
      expect(state.pendingHires, isEmpty, reason: 'the pending hire should have joined this week');
      expect(state.waitingEngineerCount, 1);
      final joined = state.engineers.singleWhere((e) => e.sourceApplicantId == applicant.id);
      expect(joined.status, EngineerStatus.waiting);
      expect(state.waitingStreak[joined.id], greaterThanOrEqualTo(1));

      expect(state.beginnerModeState.has(BeginnerMilestone.waitingCostExplained), isFalse);
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), contains(BeginnerMilestone.waitingCostExplained));

      state = _apply(state, (s) => BeginnerModeEngine.markShown(s, BeginnerMilestone.waitingCostExplained));
      expect(state.beginnerModeState.has(BeginnerMilestone.waitingCostExplained), isTrue);
    });
  });

  group('Phase 3A — Test G: recommended actions vary with GameState', () {
    test('a waiting employee changes the recommendation list', () {
      final base = _reachBeginnerManagement(11);
      final baseline = RecommendationEngine.recommendedActions(base);

      final waiter = buildEngineer(id: 'waiter-g', salary: 300000, status: EngineerStatus.waiting);
      final withWaiter = base.copyWith(
        engineers: [...base.engineers, waiter],
        company: base.company.copyWith(engineerIds: [...base.company.engineerIds, waiter.id]),
        waitingStreak: {...base.waitingStreak, waiter.id: 3},
      );
      final withWaiterActions = RecommendationEngine.recommendedActions(withWaiter);

      expect(withWaiterActions, isNot(equals(baseline)));
      expect(withWaiterActions.any((t) => t.id.contains('waiting')), isTrue);
    });

    test('recruitment tradeoff guidance appears once a listing is posted post-assignment', () {
      var state = _reachBeginnerManagement(11);
      expect(state.beginnerModeState.has(BeginnerMilestone.recruitmentTradeoffExplained), isFalse);

      // playThroughPrologue already posted a 無料求人 listing in March to
      // find the founding hire — that's not a Beginner Mode decision. Post
      // a *different* medium here so it actually lands as a new listing
      // instead of a same-type no-op (postRecruitmentMedia refuses to
      // double-post an already-active listing of the same type).
      final listingsBefore = state.listings.length;
      state = _apply(state, (s) => GameEngine.postRecruitmentMedia(s, RecruitmentMediaType.engineerCareer));
      expect(state.listings.length, greaterThan(listingsBefore));
      // Pending, not auto-shown — same fact-vs-shown split as Test D/E.
      expect(state.beginnerModeState.has(BeginnerMilestone.recruitmentTradeoffExplained), isFalse);
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), contains(BeginnerMilestone.recruitmentTradeoffExplained));

      state = _apply(state, (s) => BeginnerModeEngine.markShown(s, BeginnerMilestone.recruitmentTradeoffExplained));
      expect(state.beginnerModeState.has(BeginnerMilestone.recruitmentTradeoffExplained), isTrue);
    });
  });

  group('Phase 3A — Test H: Failure Recovery does not dead-end Phase 3A progression', () {
    test('a rejected recruitment candidate mid-Beginner-Mode does not break week advancement through June', () {
      var state = _reachBeginnerManagement(5);

      // Exercise a Failure Recovery route: post a listing, get applicants,
      // explicitly reject one — a legitimate negative outcome, not a bug.
      state = _apply(state, (s) => GameEngine.postRecruitmentMedia(s, RecruitmentMediaType.freeWork));
      final withApplicants = state.copyWith(
        applicants: [
          ...state.applicants,
          ApplicantEntry(applicant: buildApplicant(id: 'reject-me'), appearedWeek: state.week, source: RecruitmentMediaType.freeWork),
        ],
      );
      state = _apply(withApplicants, (s) => GameEngine.interviewApplicant(s, 'reject-me'));
      state = _apply(state, (s) => GameEngine.rejectApplicant(s, 'reject-me'));
      expect(state.applicants.any((e) => e.applicant.id == 'reject-me'), isFalse);

      // Keep playing April -> May -> June: no dead end, no crash, no
      // unexpected game-over from the rejection itself.
      for (var i = 0; i < 20 && state.status == GameStatus.playing; i++) {
        state = _advanceWeek(state);
      }
      expect(state.week, greaterThanOrEqualTo(BeginnerModeEngine.lastWeek));
    });
  });

  group('Phase 3A — Test I: Phase 2 accounting invariant is preserved', () {
    test('cashAfter - cashBefore == monthCashMovement for every closing produced while Phase 3A code runs', () {
      var state = _reachBeginnerManagement(5);
      for (var i = 0; i < 16 && state.status == GameStatus.playing; i++) {
        state = _advanceWeek(state);
      }
      expect(state.monthlyClosings, isNotEmpty);
      for (final closing in state.monthlyClosings) {
        expect(closing.cashAfter - closing.cashBefore, closing.monthCashMovement, reason: 'violated for ${closing.label}');
      }
    });
  });

  group('Phase 3A — Test J: legacy saves start Phase 3A state from a safe default', () {
    test('a save JSON with no beginnerModeState key loads with an empty/inactive Phase 3A state', () {
      final state = _reachBeginnerManagement(11);
      final json = state.toJson();
      json.remove('beginnerModeState');

      final reloaded = GameState.fromJson(json);
      expect(reloaded.beginnerModeState.completedMilestones, isEmpty);
      // Still resolvable/safe: Phase 3A logic doesn't crash on this state,
      // and correctly re-derives what it safely can on the next reconcile.
      final reconciled = BeginnerModeEngine.reconcile(reloaded);
      expect(() => BeginnerModeEngine.isPhase3AActive(reconciled), returnsNormally);
    });

    test('a Free Mode save is never treated as a Beginner Mode journey', () {
      final state = GameEngine.newGame(seed: 1);
      expect(BeginnerModeEngine.isBeginnerJourney(state), isFalse);
      expect(BeginnerModeEngine.isPhase3AActive(state), isFalse);
      expect(BeginnerModeEngine.reconcile(state).beginnerModeState.completedMilestones, isEmpty);
    });
  });

  group('Phase 3A end-of-June recap (P1 UX review follow-up)', () {
    test('fires once, only after week 12 is actually over, with real cumulative figures — never before', () {
      var state = _reachBeginnerManagement(5);
      for (var i = 0; i < 20 && state.week <= BeginnerModeEngine.lastWeek && state.status == GameStatus.playing; i++) {
        expect(
          BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones),
          isNot(contains(BeginnerMilestone.phase3aRecapCelebrated)),
          reason: 'must not be pending while week ${state.week} <= ${BeginnerModeEngine.lastWeek}',
        );
        state = _advanceWeek(state);
      }
      if (state.status != GameStatus.playing) {
        return; // bankruptcy is a legitimate outcome; nothing further to assert here.
      }
      expect(state.week, greaterThan(BeginnerModeEngine.lastWeek));
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), contains(BeginnerMilestone.phase3aRecapCelebrated));
      expect(state.beginnerModeState.has(BeginnerMilestone.phase3aRecapCelebrated), isFalse, reason: 'pending, not yet shown');

      state = _apply(state, (s) => BeginnerModeEngine.markShown(s, BeginnerMilestone.phase3aRecapCelebrated));
      expect(state.beginnerModeState.has(BeginnerMilestone.phase3aRecapCelebrated), isTrue);
      expect(state.stats.cumulativeRevenue, greaterThan(0), reason: 'the recap must have real revenue data to show');

      // One-time: stays shown, doesn't re-fire on further weeks.
      final firedWeek = state.beginnerModeState.milestoneWeeks[BeginnerMilestone.phase3aRecapCelebrated];
      state = _advanceWeek(state);
      expect(state.beginnerModeState.milestoneWeeks[BeginnerMilestone.phase3aRecapCelebrated], firedWeek);
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), isNot(contains(BeginnerMilestone.phase3aRecapCelebrated)));
    });

    test('never fires for a Free Mode game', () {
      final state = GameEngine.newGame(seed: 1);
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), isNot(contains(BeginnerMilestone.phase3aRecapCelebrated)));
    });
  });

  group('Beginner Mode card "今月の経営ポイント" theme (UX review follow-up)', () {
    test('changes as the player progresses through what they have and have not experienced yet', () {
      var state = _reachBeginnerManagement(11);
      expect(BeginnerModeEngine.currentThemeLabel(state), contains('売上と現金'));

      state = _apply(state, (s) => GameEngine.markTutorialSeen(s, OneTimeEvent.firstAssignmentCelebration));
      expect(state.beginnerModeState.has(BeginnerMilestone.revenueVsCashExplained), isTrue);
      expect(BeginnerModeEngine.currentThemeLabel(state), contains('入金予定'));

      // Once the first collection has been experienced too, a genuinely
      // idle second employee shifts the theme to waiting cost.
      state = _apply(state, (s) => BeginnerModeEngine.markShown(s, BeginnerMilestone.firstCollectionCelebrated));
      final waiter = buildEngineer(id: 'waiter-theme', salary: 300000, status: EngineerStatus.waiting);
      final withWaiter = state.copyWith(engineers: [...state.engineers, waiter], company: state.company.copyWith(engineerIds: [...state.company.engineerIds, waiter.id]));
      expect(BeginnerModeEngine.currentThemeLabel(withWaiter), contains('待機社員'));
    });
  });
}
