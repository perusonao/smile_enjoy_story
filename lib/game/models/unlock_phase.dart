/// Post-Founding-Prologue feature unlock phases (Playable 0.5A.1 §8).
///
/// The Founding Prologue (Playable 0.5A) condenses recruitment, sales, a
/// recruitment interview *and* a full project-interview flow into one
/// scripted March — by the moment it completes, every [FoundingMilestone]
/// the older two-founder guided tutorial ([ProgressionEngine.currentStage])
/// used to spread across several real weeks is already true. Read through
/// [ProgressionEngine] unchanged, that reads as "tutorial complete" the
/// instant April Week 1 fires, unlocking recruitment, welfare and the full
/// dashboard all at once — exactly the "一括解禁" behavior 0.5A.1 §8 asks to
/// stop.
///
/// [UnlockPhase] is a second, narrower staging axis layered *on top of*
/// [ProgressionEngine] rather than replacing it: it only ever narrows what a
/// Prologue-completed Beginner Mode game can see (never widens it beyond
/// what [ProgressionEngine] already allows), and it is a no-op for every
/// other game (Free Mode, or a save that skipped the tutorial) — see
/// [UnlockEngine.currentPhase]. Nothing here is persisted; like
/// [PrologueStage] and [FoundingStage], it is always derived fresh from
/// facts already in [GameState] so a save/reload can never strand a phase
/// transition.
enum UnlockPhase {
  /// 創業編: recruit → sales → interview → first assignment. This is the
  /// Founding Prologue itself ([PrologueState.active]); [UnlockEngine] only
  /// ever reports this for a game that hasn't finished the Prologue yet.
  founding,

  /// 経営基礎編: revenue, salary, rent, fixed costs, payment terms — the
  /// dashboard the player already lands on right after April Week 1. No new
  /// gate here; this phase is the default the moment [founding] ends.
  basicManagement,

  /// 会社成長編: hiring a second engineer, running multiple sales lines,
  /// expanding the client roster. Recruitment is gated behind entering this
  /// phase (§8's "2人目採用"), not the other way around.
  companyGrowth,

  /// 社員管理編: Morale / Trust / welfare (PC, health checks, bonuses,
  /// company trips).
  employeeManagement,

  /// 自由経営: every feature unlocked, same as
  /// [ProgressionEngine.canUseFullDashboard].
  freeManagement;

  int get order => index;
}
