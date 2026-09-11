import '../../game/public_demo/public_demo_sales.dart';
import 'public_demo_employee_visual.dart';

// SES Employee Status Unified Display (Fresh Audit,
// docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Fresh-Audit.md):
// the single, pure place a still-in-company engineer's player-facing status
// (label + badge tone) is resolved, replacing the three independently
// hand-maintained functions the Fresh Audit found
// (`_currentEmployeeStatusLabel`/`_employeeStatusTone` in the 社員タブ, plus
// each SkillSheet call site passing raw `engineerStatus(engineer)` straight
// through) with one function every call site shares.
//
// PR #238 review follow-up (P1): the Fresh Audit's own §4 recommended
// taxonomy collapses every non-`waiting`, non-`ordered`
// [PublicDemoSalesStage] sub-stage (`skillSheet`/`selling`/`introduced`/
// partner-and-client interview pass/fail) into one player-facing 営業中
// bucket, and states 参画予定 (not the raw pipeline's own '翌月参画予定' text)
// for an `ordered`-but-not-yet-assigned engineer. The first version of this
// resolver still fell back to the caller-supplied raw `engineerStatus`
// label for both of those cases, so the roster/SkillSheet kept showing the
// old, un-collapsed per-sub-stage text (営業準備/案件紹介済/各面談通過・不合格/
// 翌月参画予定) instead of the unified taxonomy this Issue exists to ship.
// Fixed here with explicit, exhaustive branches for every
// [PublicDemoSalesStage] value — no more raw-label fallback parameter at
// all, so a future stage added to the enum fails this `switch` at compile
// time rather than silently reusing an un-collapsed raw label.
//
// Deliberately a pure, presentation-layer-only function: it takes only
// facts its caller already computed from existing authoritative Public Demo
// state ([PublicDemoWorkflowState.assignedEngineerIds],
// [PublicDemoEngineerRuntime.isReadyForFieldSales], and
// `_fieldSalesActionReachableThisMonth`) — it never reads
// [PublicDemoAggregate]/[PublicDemoState] itself, and adds no new domain
// authority, enum, or persisted field. This mirrors the existing convention
// documented at the top of `public_demo_employee_visual.dart`. The raw,
// per-sub-stage 9-way switch (`engineerStatus`,
// `public_demo_01_placeholder_screen.dart`) is unchanged and remains the
// SSOT for the sales-pipeline detail views that still show it verbatim
// (`PublicDemoSalesProgress`'s stepper, the Sales tab) — this resolver
// implements a deliberately coarser, *different* taxonomy for the
// card-level player-facing status, not a re-derivation of that same switch.

/// The resolved player-facing status for one engineer: text + badge tone,
/// always produced together so they can never disagree (Fresh Audit §3
/// found exactly this kind of disagreement between two independently
/// maintained functions).
class PublicDemoEmployeeStatusDisplay {
  const PublicDemoEmployeeStatusDisplay({required this.label, required this.tone});

  final String label;
  final PublicDemoEmployeeStatusTone tone;
}

/// Pure resolver — see this file's own top-of-file doc for the authorities
/// it reads and the ones it deliberately does not re-derive.
class PublicDemoEmployeeStatusResolver {
  const PublicDemoEmployeeStatusResolver._();

  /// Resolves [stage]'s player-facing status — the minimal six-value
  /// taxonomy Fresh Audit §4 specifies (研修が必要/営業可能/営業中/参画予定/
  /// 参画中/待機), never the raw 9-stage `engineerStatus` label.
  ///
  /// Priority (Fresh Audit §5/§6, most important first):
  ///
  /// 1. **参画中** — [stage] is [PublicDemoSalesStage.ordered] AND
  ///    [isCurrentlyAssigned] (the exact
  ///    `PublicDemoWorkflowState.assignedEngineerIds(month:)` membership
  ///    fact every other authoritative reader — Revenue, Growth, Monthly
  ///    Report — already keys off). Deliberately requires **both**: an
  ///    engineer whose assignment was ended mid-month while this month's
  ///    already-earned revenue still counts them
  ///    (`PublicDemoWorkflowState.endAssignment`'s own documented "row kept,
  ///    stage reset to `waiting`" case for a pre-July end) is genuinely back
  ///    at [PublicDemoSalesStage.waiting] even though [isCurrentlyAssigned]
  ///    can still be `true` for the remainder of that same month — checking
  ///    [isCurrentlyAssigned] alone would mislabel that engineer as still
  ///    participating right after they were released. The 参画中 tone had
  ///    this exact gap before this consolidation (`_employeeStatusTone`
  ///    checked assignment membership alone, unlike
  ///    `_currentEmployeeStatusLabel`'s label, which already required both)
  ///    — a second, previously-undetected label/tone disagreement this
  ///    resolver closes by construction, not only the training-selection
  ///    one Fresh Audit §3 explicitly found.
  /// 2. **参画予定** — [stage] is [PublicDemoSalesStage.ordered] and NOT
  ///    [isCurrentlyAssigned] — the one genuinely "won the order, waiting
  ///    for next month's close" case (Fresh Audit §4/§5: kept as its own
  ///    bucket rather than folded into 営業中 because the correct next
  ///    action, "wait for month close", genuinely differs from every
  ///    営業中 sub-state's "act now").
  /// 3. **研修が必要 / 営業可能** — [stage] is
  ///    [PublicDemoSalesStage.waiting], split on [isReadyForFieldSales]
  ///    (`PublicDemoEngineerRuntime.isReadyForFieldSales`), with 営業可能
  ///    additionally gated on [fieldSalesActionReachableThisMonth] so it is
  ///    never shown in a month with no reachable control to act on it (PR
  ///    #233 Codex review P2 fix — preserved verbatim; Issue #243 widened
  ///    the reachable window itself to April-February, so this fallback
  ///    now only fires in March). Neither condition holds (`waiting`,
  ///    ready, but no reachable action this month — March only) falls back
  ///    to **待機**, matching what `engineerStatus`
  ///    already states for `waiting` verbatim.
  /// 4. **営業中** — every other [PublicDemoSalesStage] value: `skillSheet`,
  ///    `selling`, `introduced`, `partnerInterviewPassed`/`Failed`,
  ///    `clientInterviewPassed`/`Failed`. Collapses six raw pipeline
  ///    sub-stages into one truthful "not generating revenue yet, still in
  ///    motion" bucket (Fresh Audit §4's own mapping rationale) — the raw
  ///    detail remains visible elsewhere (`PublicDemoSalesProgress`'s
  ///    stepper, the Sales tab), never invented or hidden, just not
  ///    repeated at the card-level status this Issue is about. A failed
  ///    interview is not its own bucket: RECOVERY-LOOP-1 already re-enters
  ///    the same 営業中 flow next month, so a distinct "面談不合格" bucket
  ///    would be a dead end with no different next action.
  ///
  /// Fresh Audit §3/§6 fix: `trainingSelections` is not a parameter here at
  /// all (it was, informally, in the pre-consolidation `_employeeStatusTone`
  /// — the training tone silently outranked the waiting/ready split there).
  /// `PublicDemoState.trainingSelections` containing this engineer never
  /// overrides the label or tone this resolver otherwise reaches — an
  /// engineer who is 営業可能 (or genuinely on the 営業中 pipeline) and also
  /// happens to have this month's training selected keeps showing 営業可能
  /// (or 営業中) in both label and tone, never a training color the visible
  /// text does not match. A distinct "this month's training is also
  /// selected" fact remains available to a caller that wants to show it
  /// (`PublicDemoState.trainingSelections.containsKey(id)`) but it is
  /// deliberately not this resolver's concern.
  static PublicDemoEmployeeStatusDisplay resolve({
    required PublicDemoSalesStage stage,
    required bool isCurrentlyAssigned,
    required bool isReadyForFieldSales,
    required bool fieldSalesActionReachableThisMonth,
  }) {
    switch (stage) {
      case PublicDemoSalesStage.ordered:
        return isCurrentlyAssigned
            ? const PublicDemoEmployeeStatusDisplay(
                label: '参画中',
                tone: PublicDemoEmployeeStatusTone.assigned,
              )
            : const PublicDemoEmployeeStatusDisplay(
                label: '参画予定',
                tone: PublicDemoEmployeeStatusTone.waiting,
              );
      case PublicDemoSalesStage.waiting:
        if (!isReadyForFieldSales) {
          return const PublicDemoEmployeeStatusDisplay(
            label: '研修が必要',
            tone: PublicDemoEmployeeStatusTone.training,
          );
        }
        if (fieldSalesActionReachableThisMonth) {
          return const PublicDemoEmployeeStatusDisplay(
            label: '営業可能',
            tone: PublicDemoEmployeeStatusTone.readyForSales,
          );
        }
        return const PublicDemoEmployeeStatusDisplay(
          label: '待機',
          tone: PublicDemoEmployeeStatusTone.waiting,
        );
      case PublicDemoSalesStage.skillSheet:
      case PublicDemoSalesStage.selling:
      case PublicDemoSalesStage.introduced:
      case PublicDemoSalesStage.partnerInterviewPassed:
      case PublicDemoSalesStage.partnerInterviewFailed:
      case PublicDemoSalesStage.clientInterviewPassed:
      case PublicDemoSalesStage.clientInterviewFailed:
        return const PublicDemoEmployeeStatusDisplay(
          label: '営業中',
          tone: PublicDemoEmployeeStatusTone.waiting,
        );
    }
  }
}
