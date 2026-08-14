import '../models/models.dart';

/// Derives the current [UnlockPhase] for a Prologue-completed Beginner Mode
/// game (Playable 0.5A.1 §8) — see [UnlockPhase] for why this exists
/// alongside, not instead of, [ProgressionEngine].
///
/// [currentPhase] deliberately falls back to [UnlockPhase.freeManagement]
/// (i.e. "impose no extra restriction") for any game that never went
/// through the Founding Prologue at all (Free Mode, or a save from before
/// Playable 0.5A) — this class only ever *narrows* what [ProgressionEngine]'s
/// existing `canUseX` gates already allow, layered in additively at each
/// call site, never replacing them. A Prologue still in progress reads as
/// [UnlockPhase.founding], same as the Prologue's own [PrologueStage]
/// machinery.
class UnlockEngine {
  const UnlockEngine._();

  /// How many weeks of running the company solo (single engineer) the
  /// player experiences in [UnlockPhase.basicManagement] before the game is
  /// willing to call the finance basics "learned" and open the door to a
  /// second hire, i.e. [UnlockPhase.companyGrowth] — two weeks is enough to
  /// see at least one AR/payment-term cycle mentioned on Home.
  static const int weeksBeforeCompanyGrowth = 2;

  static UnlockPhase currentPhase(GameState state) {
    final ps = state.prologueState;
    // A Prologue still in progress is always `founding`, regardless of
    // `completed` (which stays false the whole time it's active) — checked
    // before the "never ran the Prologue" bypass below so an in-progress
    // Beginner Mode game isn't mistaken for a Free Mode one.
    if (ps.active) return UnlockPhase.founding;
    // Free Mode, or a save from before Playable 0.5A: the Prologue never
    // ran at all, so this class imposes no restriction of its own.
    if (!ps.completed) return UnlockPhase.freeManagement;
    if (state.activeAssignments.isEmpty) return UnlockPhase.founding;

    final hasSecondEngineer = state.engineers.length >= 2;
    final hasUsedWelfare = state.lastHealthCheckWeek != null || state.lastBonusWeek != null || state.lastCompanyTripWeek != null;
    if (hasUsedWelfare) return UnlockPhase.freeManagement;
    if (hasSecondEngineer) return UnlockPhase.employeeManagement;

    final firstAssignmentWeek = state.foundingProgress.milestoneWeeks[FoundingMilestone.firstAssignment];
    final weeksSinceFirstAssignment = firstAssignmentWeek == null ? 0 : (state.week - firstAssignmentWeek);
    if (weeksSinceFirstAssignment < weeksBeforeCompanyGrowth) return UnlockPhase.basicManagement;
    return UnlockPhase.companyGrowth;
  }

  /// Recruitment additionally needs [UnlockPhase.companyGrowth] or later —
  /// on top of [ProgressionEngine.canUseRecruitment], which every game
  /// (Prologue or not) already has to satisfy first.
  static bool canUseRecruitment(GameState state) => currentPhase(state).order >= UnlockPhase.companyGrowth.order;

  /// Welfare additionally needs [UnlockPhase.employeeManagement] or later.
  static bool canUseWelfare(GameState state) => currentPhase(state).order >= UnlockPhase.employeeManagement.order;

  /// Short, player-facing reason shown on the locked recruitment/welfare
  /// cards (§8) — never a raw enum name.
  static String lockedReason(GameState state, UnlockPhase requires) {
    final phase = currentPhase(state);
    if (phase == UnlockPhase.founding) return '創業準備が完了すると使えるようになります。';
    if (requires == UnlockPhase.companyGrowth) {
      return 'まずは1人目の社員と一緒に、売上・給与・家賃などの会社運営に慣れましょう。\nしばらく経営すると2人目の採用ができるようになります。';
    }
    return '2人目の社員を採用すると使えるようになります。\n社員が増えると、福利厚生やMorale/Trustの管理が必要になります。';
  }
}
