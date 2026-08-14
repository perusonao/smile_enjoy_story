/// The ordered stages of the Founding Prologue (Playable 0.5A §12-64).
///
/// Unlike the old 0.4C founding tutorial (which starts with two employed
/// founders and gates *feature access*), the Prologue starts from zero
/// engineers and scripts the player through founding the company itself:
/// naming the president, hiring the first engineer, pre-joining sales, and
/// the first project's selection flow, ending with April Week 1's joining +
/// assignment. [PrologueEngine.stage] derives this from [PrologueState] plus
/// the rest of [GameState] — see that class for the "why derive, don't
/// store" rationale, mirrored here from [FoundingProgress]/[ProgressionEngine].
enum PrologueStage {
  presidentNaming,
  intro,
  week1Recruitment,
  week2CandidateSelect,
  week2Interview,
  week2Decision,
  week2AwaitingReply,
  week3SkillSheet,
  week3Sales,
  week4AwaitingRequest,
  week4InterviewRequest,
  week4UpperInterview,
  week4ClientInterview,
  week4Contract,
  complete,
  freeManagement,
}

/// Guided-founding progression state for the Founding Prologue.
///
/// Deliberately holds only *facts the engine can't otherwise derive* — same
/// philosophy as [FoundingProgress] (Playable 0.4C.1): stage, "today's" task
/// text, and unlock gating all live in [PrologueEngine], not here.
class PrologueState {
  /// True while the player is still inside the scripted Prologue. False for
  /// every Free Mode game, and for Beginner Mode games once the player taps
  /// "経営を始める" on the Prologue Complete screen (§63-64).
  final bool active;

  /// 1-4: which March week (創業準備月, §11-58) the player is on. Deliberately
  /// separate from [GameState.week]/`company.currentWeek` — the real 48-week
  /// fiscal year (§11, week 1 = April) only starts once April Week 1 fires,
  /// so March never shifts any existing week-indexed system (AR due months,
  /// contract terms, the 48-week cap) by even one week (§83).
  final int prologueWeek;

  /// The player has tapped through the intro conversation (purpose + office
  /// explanation, §9-10) at least once. Purely a "don't replay the intro on
  /// resume" flag — replaying it costs nothing if it's somehow still false.
  final bool introSeen;

  /// The two March Week 2 candidates (§17-20), fixed once generated so a
  /// save/reload never regenerates a different pair mid-choice.
  final String? candidateAId;
  final String? candidateBId;

  /// Which candidate the player chose to interview this week (§21) — kept
  /// distinct from "who got hired" so the UI can show "interviewing A" before
  /// a hire/reject decision is made.
  final String? interviewingCandidateId;

  /// The player has opened/confirmed the SkillSheet before starting
  /// pre-joining sales (§33-34) — an explicit fact, like `inspectSkillSheet`
  /// in the old tutorial, since there's nothing in [GameState] alone that
  /// proves the player looked.
  final bool skillSheetConfirmed;

  /// The specific first project this playthrough's Week 4 interview request
  /// targets (§40), fixed once chosen so a retry after a failed selection
  /// step (§54-55) can pick a *different* project without losing track of
  /// which one was already tried.
  final String? targetProjectId;

  /// Every project id ever set as [targetProjectId] this playthrough — used
  /// to exclude already-tried projects when picking a rescue project after a
  /// failure (§54-55), so a retry can never re-target the same project it
  /// just failed and loop forever.
  final List<String> triedProjectIds;

  /// How many upper-company/client interview failures this playthrough has
  /// hit so far (§54-55) — used only to pace the rescue re-request, never to
  /// change odds.
  final int failedAttempts;

  /// The player has tapped "経営を始める" on the Prologue Complete screen
  /// (§63). Distinct from [active] going false so a save mid-way through the
  /// final screen can still show it on resume rather than jumping straight
  /// to free management.
  final bool completed;

  const PrologueState({
    this.active = false,
    this.prologueWeek = 1,
    this.introSeen = false,
    this.candidateAId,
    this.candidateBId,
    this.interviewingCandidateId,
    this.skillSheetConfirmed = false,
    this.targetProjectId,
    this.triedProjectIds = const [],
    this.failedAttempts = 0,
    this.completed = false,
  });

  /// Every Free Mode game, and every save from before Playable 0.5A: no
  /// Prologue ever ran, so nothing here matters.
  static const PrologueState notActive = PrologueState();

  /// A brand-new Beginner Mode game's starting state (§4-5).
  static const PrologueState beginnerStart = PrologueState(active: true);

  PrologueState copyWith({
    bool? active,
    int? prologueWeek,
    bool? introSeen,
    String? candidateAId,
    String? candidateBId,
    Object? interviewingCandidateId = _unset,
    bool? skillSheetConfirmed,
    Object? targetProjectId = _unset,
    List<String>? triedProjectIds,
    int? failedAttempts,
    bool? completed,
  }) {
    return PrologueState(
      active: active ?? this.active,
      prologueWeek: prologueWeek ?? this.prologueWeek,
      introSeen: introSeen ?? this.introSeen,
      candidateAId: candidateAId ?? this.candidateAId,
      candidateBId: candidateBId ?? this.candidateBId,
      interviewingCandidateId: identical(interviewingCandidateId, _unset)
          ? this.interviewingCandidateId
          : interviewingCandidateId as String?,
      skillSheetConfirmed: skillSheetConfirmed ?? this.skillSheetConfirmed,
      targetProjectId: identical(targetProjectId, _unset)
          ? this.targetProjectId
          : targetProjectId as String?,
      triedProjectIds: triedProjectIds ?? this.triedProjectIds,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
    'active': active,
    'prologueWeek': prologueWeek,
    'introSeen': introSeen,
    'candidateAId': candidateAId,
    'candidateBId': candidateBId,
    'interviewingCandidateId': interviewingCandidateId,
    'skillSheetConfirmed': skillSheetConfirmed,
    'targetProjectId': targetProjectId,
    'triedProjectIds': triedProjectIds,
    'failedAttempts': failedAttempts,
    'completed': completed,
  };

  /// `null` means this save predates Playable 0.5A, or is a Free Mode game —
  /// either way, the Prologue never ran (mirrors [FoundingProgress.fromJson]).
  factory PrologueState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PrologueState.notActive;
    return PrologueState(
      active: json['active'] as bool? ?? false,
      prologueWeek: json['prologueWeek'] as int? ?? 1,
      introSeen: json['introSeen'] as bool? ?? false,
      candidateAId: json['candidateAId'] as String?,
      candidateBId: json['candidateBId'] as String?,
      interviewingCandidateId: json['interviewingCandidateId'] as String?,
      skillSheetConfirmed: json['skillSheetConfirmed'] as bool? ?? false,
      targetProjectId: json['targetProjectId'] as String?,
      triedProjectIds: (json['triedProjectIds'] as List? ?? const []).cast<String>(),
      failedAttempts: json['failedAttempts'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

const Object _unset = Object();
