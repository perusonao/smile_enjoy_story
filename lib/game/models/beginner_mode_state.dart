/// One-time teaching/progression checkpoint specific to Phase 3A (the
/// April-June "初心者経営" continuation of Beginner Mode). Deliberately kept
/// separate from [FoundingProgress]/`OneTimeEvent` (the March founding
/// tutorial, Playable 0.4C/0.5A): the two tutorials teach different things
/// at different times, so Phase 3A gets its own small, independently
/// evolvable state slice rather than overloading the March one (S.E.S.
/// Development Plan §3.2, §3.9 "Phase 3A").
enum BeginnerMilestone {
  /// The "創業編クリア → 初心者経営編開始" transition has been shown — set the
  /// moment [PrologueEngine.completePrologue] runs, since that's the only
  /// way a Beginner Mode playthrough ever reaches this point.
  managementPhaseStarted,

  /// "売上と現金は別物" + payment-site has been explained. Already covered
  /// live by the existing first-assignment celebration
  /// ([OneTimeEvent.firstAssignmentCelebration]) and/or the first-AR
  /// tutorial ([OneTimeEvent.firstArTutorial]) — this is just Phase 3A's own
  /// named fact for tests/reporting to check without reaching into
  /// [FoundingProgress]'s unrelated event set (nothing here shows a second,
  /// duplicate dialog).
  revenueVsCashExplained,

  /// "待機社員にも給与が発生しています" has been explained at least once.
  waitingCostExplained,

  /// The first real cash collection (an accounts-receivable record actually
  /// moving from pending to paid) has been celebrated.
  firstCollectionCelebrated,

  /// The recruitment growth-vs-fixed-cost tradeoff has been explained.
  recruitmentTradeoffExplained,

  /// The "初心者経営・前半クリア！" recap has been shown, once, right as
  /// Phase 3A's April-June window ends (week > [BeginnerModeEngine.lastWeek])
  /// — a brief, real-data recap of what the player just experienced (売上
  /// と入金, 月末支払い, 資金繰り), not a Phase 3B preview (Phase 3B is not
  /// implemented yet).
  phase3aRecapCelebrated,

  /// Phase 3B-1 (S.E.S. Development Plan §3.3, weeks 13-24 / July-September):
  /// the player has looked at a project's Fit-reason breakdown (the existing
  /// `MatchingEngine.computeFit` per-dimension ◎○△× detail, surfaced through
  /// `showFitReasonSheet`/`FitReasonSheet`, fit_reason_sheet.dart) at least
  /// once. No engine condition derives it (see [BeginnerModeEngine._isTrue]'s
  /// doc comment on this case) — it's a "did the player view this screen"
  /// fact, so `FitReasonSheet`'s own open callback calls
  /// [BeginnerModeState.withMilestone] / `BeginnerModeEngine.markShown`
  /// directly the first time it opens. Not wired into
  /// [BeginnerModeEngine.weeklyMilestones] or any backfill list — those are
  /// for milestones with their own celebratory dialog / an engine-derivable
  /// fact respectively, neither of which applies here.
  fitReasonViewed,

  /// Phase 3B-1: the player has used the (future) multi-project comparison
  /// screen at least once. Same placeholder status [fitReasonViewed] had
  /// before its own screen (fit_reason_sheet.dart) landed — added now so the
  /// enum/JSON shape is stable and additive before the comparison screen
  /// that will actually set it exists (a later Phase 3B-1 PR).
  projectComparisonUsed,
}

/// Beginner Mode's first-fiscal-year sub-phases (S.E.S. Development Plan
/// §3.9): each maps to a fixed, calendar-defined fiscal-week range via
/// `BeginnerModeEngine.currentSubPhase` — never persisted, always derived
/// from `GameState.week` (mirrors how [BeginnerModeState] itself holds only
/// milestone facts, not phase/stage flags).
enum BeginnerSubPhase {
  /// April-June, weeks 1-`BeginnerModeEngine.lastWeek` (12).
  phase3a,

  /// July-September, weeks 13-`BeginnerModeEngine.phase3b1LastWeek` (24).
  phase3b1,

  /// October-December, weeks 25-`BeginnerModeEngine.phase3b2LastWeek` (36).
  phase3b2,

  /// January-March, weeks 37-`BeginnerModeEngine.phase3b3LastWeek` (48).
  phase3b3,
}

/// Phase 3A progression — deliberately holds only *facts*, mirroring
/// [FoundingProgress]: which one-time Phase 3A teaching moments have been
/// shown, and when. All "what should currently be shown" logic lives in
/// `BeginnerModeEngine`, not here.
class BeginnerModeState {
  /// Milestones shown so far this playthrough.
  final Set<BeginnerMilestone> completedMilestones;

  /// The week each milestone was first shown.
  final Map<BeginnerMilestone, int> milestoneWeeks;

  const BeginnerModeState({
    this.completedMilestones = const {},
    this.milestoneWeeks = const {},
  });

  /// A brand-new game's starting state, and the safe default for any save
  /// that predates Phase 3A (§13: old saves must load with Phase 3A state
  /// starting from a safe default, never crash/guess).
  static const BeginnerModeState initial = BeginnerModeState();

  bool has(BeginnerMilestone milestone) => completedMilestones.contains(milestone);

  /// Returns a copy with [milestone] marked shown at [week] — a no-op if it
  /// was already shown (milestones only move forward, same as
  /// [FoundingProgress.withMilestone]).
  BeginnerModeState withMilestone(BeginnerMilestone milestone, int week) {
    if (has(milestone)) return this;
    return copyWith(
      completedMilestones: {...completedMilestones, milestone},
      milestoneWeeks: {...milestoneWeeks, milestone: week},
    );
  }

  BeginnerModeState copyWith({
    Set<BeginnerMilestone>? completedMilestones,
    Map<BeginnerMilestone, int>? milestoneWeeks,
  }) {
    return BeginnerModeState(
      completedMilestones: completedMilestones ?? this.completedMilestones,
      milestoneWeeks: milestoneWeeks ?? this.milestoneWeeks,
    );
  }

  Map<String, dynamic> toJson() => {
    'completedMilestones': completedMilestones.map((m) => m.name).toList(),
    'milestoneWeeks': milestoneWeeks.map((key, value) => MapEntry(key.name, value)),
  };

  /// `null` (or any key/value this enum no longer recognizes) is treated as
  /// "not shown yet" rather than an error — this must never crash on an
  /// older save that predates Phase 3A, or on any hand-edited/corrupted
  /// save data (§13, mirrors [FoundingProgress.fromJson]).
  factory BeginnerModeState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return BeginnerModeState.initial;
    BeginnerMilestone? byName(String name) {
      for (final m in BeginnerMilestone.values) {
        if (m.name == name) return m;
      }
      return null;
    }

    final milestones = <BeginnerMilestone>{
      for (final name in (json['completedMilestones'] as List? ?? const []))
        if (byName(name as String) != null) byName(name)!,
    };
    final weeks = <BeginnerMilestone, int>{
      for (final entry in (json['milestoneWeeks'] as Map<String, dynamic>? ?? const {}).entries)
        if (byName(entry.key) != null) byName(entry.key)!: entry.value as int,
    };
    return BeginnerModeState(completedMilestones: milestones, milestoneWeeks: weeks);
  }
}
