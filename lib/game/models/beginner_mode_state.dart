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
