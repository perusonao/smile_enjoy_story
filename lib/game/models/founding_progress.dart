/// One achievement in the guided-founding onboarding (Playable 0.4C.1).
///
/// Each value is a concrete thing the player *did*, not a week number —
/// unlocks are milestone-based, not time-based (§5 of the design doc).
enum FoundingMilestone {
  /// Opened an employee's detail screen at least once.
  inspectEmployee,

  /// Opened the SkillSheet editor for an employee at least once (saving is
  /// not required — an honest, unedited sheet still counts, §9).
  inspectSkillSheet,

  /// Started sales for at least one employee.
  startSales,

  /// Received the first ever [InterviewOffer].
  receiveInterviewOffer,

  /// Completed a客先面談 (client interview) — pass or fail both count (§16).
  completeClientInterview,

  /// At least one employee has held an [ActiveAssignment].
  firstAssignment,

  /// Completed at least one recruitment interview conversation (§23).
  firstRecruitmentInterview,

  /// Opened an employee's detail screen after Welfare unlocked, to look at
  /// their Morale/Trust/PC (Playable 0.4C.2 §35-37) — the last guided step
  /// before the player explicitly ends the tutorial.
  welfareIntroSeen,

  /// The player explicitly finished the founding tutorial and moved to
  /// free management (§27-28).
  freeManagement,
}

/// The ordered stages of the founding tutorial (§4, §6-28). Each stage is
/// "active" until its gating [FoundingMilestone] is completed.
enum FoundingStage {
  employeeIntro,
  skillSheet,
  salesStart,
  awaitingOffer,
  clientInterview,
  awaitingAssignment,
  recruitment,
  welfare,

  /// The player has seen the Welfare intro and just needs to tap "自由経営
  /// を始める" to finish (Playable 0.4C.2 §37).
  tutorialComplete,
  freeManagement,
}

/// One-time UI moments (celebrations + contextual tutorials, §39-40, §47)
/// shown at most once per playthrough, tracked via
/// [FoundingProgress.seenTutorials].
enum OneTimeEvent {
  interviewOfferCelebration,
  firstAssignmentCelebration,
  recruitmentUnlockCelebration,
  clientInterviewCelebration,
  recruitmentInterviewCelebration,
  welfareUnlockCelebration,
  firstOfferTutorial,
  firstArTutorial,
  fieldLeadTutorial,
  contractRenewalTutorial,
  clientUnlockTutorial,
}

/// Guided-founding progression state (Playable 0.4C.1 §4, §40, §48-49).
///
/// Deliberately holds only *facts* (what's been completed/seen, and when) —
/// all the "what should the UI show right now" logic lives in
/// [ProgressionEngine] so this stays a plain, serializable data class.
class FoundingProgress {
  /// Milestones completed so far this playthrough.
  final Set<FoundingMilestone> completedMilestones;

  /// The week each milestone was first completed, for the playtest log's
  /// `timeToX` metrics (§49).
  final Map<FoundingMilestone, int> milestoneWeeks;

  /// One-time UI moments ([OneTimeEvent]) already shown.
  final Set<OneTimeEvent> seenTutorials;

  /// True when the player chose "自由に開始" at new-game start (§41-42), or
  /// when this save predates Playable 0.4C.1 and is granted full access
  /// rather than being replayed through a tutorial it never had (§48).
  final bool tutorialSkipped;

  const FoundingProgress({
    this.completedMilestones = const {},
    this.milestoneWeeks = const {},
    this.seenTutorials = const {},
    this.tutorialSkipped = false,
  });

  /// A brand-new game's starting progress (Stage 1).
  static const FoundingProgress initial = FoundingProgress();

  /// Every feature unlocked and the tutorial considered finished — used for
  /// saves from before this feature existed (§48) and for "自由に開始".
  factory FoundingProgress.allUnlocked() => FoundingProgress(
    completedMilestones: FoundingMilestone.values.toSet(),
    tutorialSkipped: true,
  );

  bool has(FoundingMilestone milestone) =>
      completedMilestones.contains(milestone);

  bool hasSeen(OneTimeEvent event) => seenTutorials.contains(event);

  /// Returns a copy with [milestone] marked complete at [week] — a no-op if
  /// it was already completed (milestones only move forward).
  FoundingProgress withMilestone(FoundingMilestone milestone, int week) {
    if (has(milestone)) return this;
    return copyWith(
      completedMilestones: {...completedMilestones, milestone},
      milestoneWeeks: {...milestoneWeeks, milestone: week},
    );
  }

  /// Returns a copy with [event] marked as shown — a no-op if already shown.
  FoundingProgress withTutorialSeen(OneTimeEvent event) {
    if (hasSeen(event)) return this;
    return copyWith(seenTutorials: {...seenTutorials, event});
  }

  FoundingProgress withTutorialSkipped() => copyWith(tutorialSkipped: true);

  FoundingProgress copyWith({
    Set<FoundingMilestone>? completedMilestones,
    Map<FoundingMilestone, int>? milestoneWeeks,
    Set<OneTimeEvent>? seenTutorials,
    bool? tutorialSkipped,
  }) {
    return FoundingProgress(
      completedMilestones: completedMilestones ?? this.completedMilestones,
      milestoneWeeks: milestoneWeeks ?? this.milestoneWeeks,
      seenTutorials: seenTutorials ?? this.seenTutorials,
      tutorialSkipped: tutorialSkipped ?? this.tutorialSkipped,
    );
  }

  Map<String, dynamic> toJson() => {
    'completedMilestones': completedMilestones.map((m) => m.name).toList(),
    'milestoneWeeks': milestoneWeeks.map(
      (key, value) => MapEntry(key.name, value),
    ),
    'seenTutorials': seenTutorials.map((e) => e.name).toList(),
    'tutorialSkipped': tutorialSkipped,
  };

  /// `null` means this save predates Playable 0.4C.1 — grant full access
  /// rather than replaying a tutorial the save never went through (§48).
  factory FoundingProgress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return FoundingProgress.allUnlocked();
    FoundingMilestone? milestoneByName(String name) {
      for (final m in FoundingMilestone.values) {
        if (m.name == name) return m;
      }
      return null;
    }

    OneTimeEvent? eventByName(String name) {
      for (final e in OneTimeEvent.values) {
        if (e.name == name) return e;
      }
      return null;
    }

    final milestones = <FoundingMilestone>{
      for (final name in (json['completedMilestones'] as List? ?? const []))
        if (milestoneByName(name as String) != null) milestoneByName(name)!,
    };
    final weeks = <FoundingMilestone, int>{
      for (final entry
          in (json['milestoneWeeks'] as Map<String, dynamic>? ?? const {})
              .entries)
        if (milestoneByName(entry.key) != null)
          milestoneByName(entry.key)!: entry.value as int,
    };
    final seen = <OneTimeEvent>{
      for (final name in (json['seenTutorials'] as List? ?? const []))
        if (eventByName(name as String) != null) eventByName(name)!,
    };
    return FoundingProgress(
      completedMilestones: milestones,
      milestoneWeeks: weeks,
      seenTutorials: seen,
      tutorialSkipped: json['tutorialSkipped'] as bool? ?? false,
    );
  }
}
