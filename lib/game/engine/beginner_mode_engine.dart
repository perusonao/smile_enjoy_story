import '../../domain/domain.dart';
import '../models/models.dart';
import 'finance_engine.dart';

/// Phase 3A (S.E.S. Development Plan §3.2): continues Beginner Mode's
/// guidance from the first assignment through the end of June (fiscal weeks
/// 1-12) instead of handing the player straight to unrestricted free
/// management the instant the Founding Prologue completes.
///
/// Every fact here is derived from [GameState] alone — nothing is inferred
/// from *when* an action happened, only *whether* it happened (§3.0 rule 5,
/// mirrors [ProgressionEngine.reconcile] / [PrologueEngine.reconcileState]).
/// That means Failure Recovery routes (a rejected candidate, a declined
/// offer, a failed interview, a save/reload mid-week, a quiet no-action
/// week) can never desync Phase 3A guidance from the state that actually
/// earned it — there is nothing here that only fires along one specific
/// path through the game.
///
/// Nothing in this file ever writes to [Company.cash], [AccountsReceivable],
/// [MonthlyClosing] or any other accounting field — Phase 3A's tutorial only
/// *observes* [FinanceEngine]'s existing, already-correct numbers (§14 of
/// the Phase 3A brief: "Tutorial は会計を観測する側であり、会計を歪める側では
/// ない").
class BeginnerModeEngine {
  const BeginnerModeEngine._();

  /// Last fiscal week Phase 3A's continued guidance stays active for (week 1
  /// = April, so week 12 = the end of June). Weeks beyond this simply fall
  /// through to whatever free-management UI already renders — July onward
  /// (Phase 3B/3C/3D) is out of scope for this slice.
  ///
  /// Deliberately left unchanged in name and value by the Phase 3B-1 slice
  /// that introduces [phase3b1LastWeek]/[phase3b2LastWeek]/
  /// [phase3b3LastWeek] below — [isPhase3AActive] and every test/UI call
  /// site that already depends on this exact constant keep working
  /// unmodified (S.E.S. Development Plan §3.9 Phase 3B-1 design brief).
  static const int lastWeek = 12;

  /// Last fiscal week of Phase 3B-1 (July-September, S.E.S. Development Plan
  /// §3.3) — weeks [lastWeek]+1 (13) through this one.
  static const int phase3b1LastWeek = 24;

  /// Last fiscal week of Phase 3B-2 (October-December, §3.4) — weeks
  /// [phase3b1LastWeek]+1 (25) through this one.
  static const int phase3b2LastWeek = 36;

  /// Last fiscal week of Phase 3B-3 (January-March, §3.5) — weeks
  /// [phase3b2LastWeek]+1 (37) through this one. Equal to [totalGameWeeks]
  /// (48): the end of Phase 3B-3 is the end of Beginner Mode's first fiscal
  /// year, i.e. graduation to Normal Mode at week 49 (§3.6, §3.8). Derived
  /// from [totalGameWeeks] rather than a second hardcoded `48`, so the two
  /// can never silently drift apart.
  static const int phase3b3LastWeek = totalGameWeeks;

  /// True for a playthrough that ran through the Founding Prologue — the
  /// only journey Phase 3A's continued guidance applies to. A "自由に開始"
  /// (Free Mode) player already has every system unlocked from turn one and
  /// never goes through this teaching arc.
  static bool isBeginnerJourney(GameState state) => state.gameMode == GameMode.beginner;

  /// True while Home should keep showing Phase 3A's continued guidance (the
  /// "初心者経営期間" card, the softened non-mandatory recommendation
  /// framing that free management already uses) — i.e. founding is done
  /// (first assignment reached) but the end of June hasn't passed yet.
  ///
  /// Unchanged by the Phase 3B-1 slice — see [lastWeek]'s doc comment.
  static bool isPhase3AActive(GameState state) =>
      isBeginnerJourney(state) &&
      state.foundingProgress.has(FoundingMilestone.firstAssignment) &&
      state.week <= lastWeek;

  /// True for the whole of Beginner Mode's first fiscal year (Phase 3A
  /// through Phase 3B-3, weeks 1-[phase3b3LastWeek]) instead of just Phase
  /// 3A's April-June window — i.e. founding is done and the player hasn't
  /// yet reached graduation week 49 (§3.6, §3.8). [isPhase3AActive] keeps
  /// its own narrower meaning and is not redefined in terms of this method,
  /// so existing call sites that specifically mean "Phase 3A only" are
  /// unaffected.
  static bool isBeginnerModeActive(GameState state) =>
      isBeginnerJourney(state) &&
      state.foundingProgress.has(FoundingMilestone.firstAssignment) &&
      state.week <= phase3b3LastWeek;

  /// Which Beginner Mode sub-phase [state] currently falls in, or `null`
  /// once [isBeginnerModeActive] is false (not a Beginner Mode journey,
  /// founding not complete yet, or graduation week 49+ already reached) —
  /// a pure, derived read of [GameState.week], never persisted (§3.0 rule 5:
  /// milestone/state reconciliation over fragile week-only flags — this is
  /// the one place week itself is the authority, since sub-phase boundaries
  /// are calendar-defined by design, not event-driven).
  static BeginnerSubPhase? currentSubPhase(GameState state) {
    if (!isBeginnerModeActive(state)) return null;
    final week = state.week;
    if (week <= lastWeek) return BeginnerSubPhase.phase3a;
    if (week <= phase3b1LastWeek) return BeginnerSubPhase.phase3b1;
    if (week <= phase3b2LastWeek) return BeginnerSubPhase.phase3b2;
    return BeginnerSubPhase.phase3b3;
  }

  // -------------------------------------------------------------------
  // Milestone facts (§3.0 rule 1: event-driven, not week-driven — every
  // condition below reads only "has this already happened", never "is it
  // currently week N").
  // -------------------------------------------------------------------

  static bool _isTrue(GameState state, BeginnerMilestone milestone) {
    switch (milestone) {
      case BeginnerMilestone.managementPhaseStarted:
        return state.foundingProgress.has(FoundingMilestone.firstAssignment);
      case BeginnerMilestone.revenueVsCashExplained:
        // Already taught live by the existing first-assignment celebration
        // and/or first-AR tutorial (Playable 0.4C.3/0.4C.4) — reusing that
        // signal instead of showing a second, near-identical dialog (§0:
        // don't reimplement what the app already does).
        return state.foundingProgress.hasSeen(OneTimeEvent.firstAssignmentCelebration) ||
            state.foundingProgress.hasSeen(OneTimeEvent.firstArTutorial);
      case BeginnerMilestone.waitingCostExplained:
        return state.foundingProgress.has(FoundingMilestone.firstAssignment) &&
            state.waitingStreak.values.any((weeks) => weeks >= 1);
      case BeginnerMilestone.firstCollectionCelebrated:
        return state.accountsReceivable.any((ar) => ar.status == ArStatus.paid);
      case BeginnerMilestone.recruitmentTradeoffExplained:
        // The Founding Prologue itself already posts exactly one listing in
        // March (to find the founding hire) — that's not yet a *Beginner
        // Mode* recruitment decision. A second listing means the player
        // chose, post-founding, to grow the team, which is the moment the
        // growth-vs-fixed-cost tradeoff actually applies.
        //
        // Deliberately reads `state.stats.recruitmentListingsPosted`, not
        // `state.listings.length`: the latter only ever holds *currently
        // active* listings (GameEngine.advanceWeek replaces it with the
        // active-only filtered set every week), so it would go back to 1 —
        // silently un-satisfying this condition — the moment the March
        // listing's 4-week duration expired, which typically happens before
        // Beginner Mode's own recruitment unlock (2 weeks after the first
        // assignment) even opens. Found via a real-UI Playwright run (Phase
        // 3A UX review follow-up): no unit test caught this because unit
        // tests construct `listings` directly instead of going through the
        // engine's weekly pruning.
        return state.foundingProgress.has(FoundingMilestone.firstAssignment) &&
            state.stats.recruitmentListingsPosted > 1;
      case BeginnerMilestone.phase3aRecapCelebrated:
        // Fires once Phase 3A's own window (isPhase3AActive) has actually
        // ended — not "reached week 12" but "week 12 is over" (mirrors the
        // same one-week-late reasoning `BeginnerModeEngine.lastWeek`'s own
        // doc comment uses elsewhere): the player should see the whole of
        // June, including its month-end close, before the recap.
        return state.foundingProgress.has(FoundingMilestone.firstAssignment) && state.week > lastWeek;
      case BeginnerMilestone.fitReasonViewed:
      case BeginnerMilestone.projectComparisonUsed:
        // Phase 3B-1 data-model placeholders only (see each enum value's own
        // doc comment in beginner_mode_state.dart) — this PR adds no Fit-
        // reason or project-comparison UI, so there is no GameState fact yet
        // that proves the player looked at either screen. Unlike every case
        // above, these aren't "did an accounting/roster event happen" facts;
        // they're "did the player view this screen" facts, which only the
        // (future) screen itself can know. Deliberately always `false` here
        // so `reconcile`/`pendingMilestones` stay complete no-ops for both
        // until a later PR's UI starts calling `BeginnerModeEngine.markShown`
        // directly — never speculatively derived from unrelated state.
        return false;
    }
  }

  /// Milestones safe to silently backfill via [reconcile] — informational
  /// facts that either already have their own live dialog elsewhere
  /// ([revenueVsCashExplained]) or are marked explicitly at the one moment
  /// they can happen ([managementPhaseStarted], in
  /// [PrologueEngine.completePrologue]; this is just [reconcile]'s usual
  /// safety net for that, mirroring [ProgressionEngine.reconcile]'s own
  /// milestones). Deliberately excludes [BeginnerModeEngine.weeklyMilestones]:
  /// those each have their *own* dedicated one-time dialog, so marking them
  /// complete here — inside the same reconcile pass that runs immediately
  /// after the mutation that made them true — would mark the milestone
  /// "shown" before the player ever actually saw it, and Home's
  /// [pendingMilestones] check (which runs right after) would then find
  /// nothing pending. Those three are only ever marked via [markShown],
  /// called once their dialog has actually been displayed — the same
  /// fact-vs-shown split [FoundingProgress]/[OneTimeEvent] already use for
  /// the March tutorial's own celebratory dialogs.
  static const List<BeginnerMilestone> _backfillOnly = [
    BeginnerMilestone.managementPhaseStarted,
    BeginnerMilestone.revenueVsCashExplained,
  ];

  /// Backfills [_backfillOnly] from facts [GameState] already proves true.
  /// Pure, idempotent, monotonic (never un-shows a milestone) — safe to call
  /// after every mutation, including Failure Recovery routes (§3.0 rule 5).
  static GameState reconcile(GameState state) {
    if (!isBeginnerJourney(state)) return state;
    var progress = state.beginnerModeState;
    for (final m in _backfillOnly) {
      if (!progress.has(m) && _isTrue(state, m)) {
        progress = progress.withMilestone(m, state.week);
      }
    }
    if (identical(progress, state.beginnerModeState)) return state;
    return state.copyWith(beginnerModeState: progress);
  }

  /// Every [BeginnerMilestone] among [candidates] that has become true and
  /// hasn't been shown to the player yet, in declaration order — mirrors
  /// [ProgressionEngine.pendingEvents].
  static List<BeginnerMilestone> pendingMilestones(GameState state, List<BeginnerMilestone> candidates) {
    if (!isBeginnerJourney(state)) return const [];
    return [
      for (final m in candidates)
        if (!state.beginnerModeState.has(m) && _isTrue(state, m)) m,
    ];
  }

  /// Milestones with their own dedicated dialog, checked from Home after
  /// every week advance — same spot [ProgressionEngine.weeklyEvents] is
  /// checked from. `managementPhaseStarted` and `revenueVsCashExplained` are
  /// deliberately excluded: the former is shown inline on the Prologue's own
  /// completion screen (and marked shown the instant that screen fires
  /// [PrologueEngine.completePrologue]); the latter is already covered live
  /// by the existing first-assignment/first-AR dialogs — queuing either here
  /// too would just be a duplicate popup.
  static const List<BeginnerMilestone> weeklyMilestones = [
    BeginnerMilestone.waitingCostExplained,
    BeginnerMilestone.firstCollectionCelebrated,
    BeginnerMilestone.recruitmentTradeoffExplained,
    BeginnerMilestone.phase3aRecapCelebrated,
  ];

  /// Marks [milestone] as shown — the only mutation this engine exposes;
  /// everything else above is pure derivation.
  static GameState markShown(GameState state, BeginnerMilestone milestone) =>
      state.copyWith(beginnerModeState: state.beginnerModeState.withMilestone(milestone, state.week));

  // -------------------------------------------------------------------
  // Cash-flow summary helpers (§10 of the Phase 3A brief: only what
  // [FinanceEngine] already computes safely — no new prediction/accounting
  // engine, no invented precision).
  // -------------------------------------------------------------------

  /// The soonest not-yet-collected [AccountsReceivable] record, or `null`
  /// when there's no pending AR at all — a real upcoming due month pulled
  /// straight from existing AR records, never a guessed "in N.N weeks"
  /// estimate.
  static AccountsReceivable? nextExpectedCollection(GameState state) {
    final pending = state.accountsReceivable.where((ar) => ar.status == ArStatus.pending).toList()
      ..sort((a, b) => a.dueMonth.compareTo(b.dueMonth));
    return pending.isEmpty ? null : pending.first;
  }

  /// Total monthly salary currently being paid to `waiting` employees — real
  /// data (a sum of [Engineer.salary]), not an estimate.
  static int waitingSalaryTotal(GameState state) => state.engineers
      .where((e) => e.status == EngineerStatus.waiting)
      .fold<int>(0, (sum, e) => sum + e.salary);

  /// A one-line "今月の経営ポイント" for the Home card (Phase 3A UX review
  /// follow-up): what the player should actually be paying attention to
  /// *right now*, derived from the same milestone/state facts everything
  /// else here already reads — not a second, independent judgment. Replaces
  /// (not adds to) the card's previous static blurb, so this doesn't grow
  /// Home's information density; it just makes the existing line dynamic
  /// enough that the card reads as "this week's lesson", not a generic,
  /// always-identical info box that blends into the rest of the screen.
  static String currentThemeLabel(GameState state) {
    if (!state.beginnerModeState.has(BeginnerMilestone.revenueVsCashExplained)) {
      return '売上と現金の違いに注目しましょう';
    }
    if (!state.beginnerModeState.has(BeginnerMilestone.firstCollectionCelebrated)) {
      return '入金予定を確認しましょう';
    }
    if (state.waitingEngineerCount > 0) {
      return '待機社員のコストに注意しましょう';
    }
    final runway = FinanceEngine.classifyRunway(FinanceEngine.cashRunwayMonths(state));
    if (runway != RunwayLevel.safe) {
      return '資金繰りを意識しましょう';
    }
    return '案件参画と採用のバランスを見ていきましょう';
  }
}
