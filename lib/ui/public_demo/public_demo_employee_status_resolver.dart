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
// Deliberately a pure, presentation-layer-only function: it takes only
// facts its caller already computed from existing authoritative Public Demo
// state ([PublicDemoWorkflowState.assignedEngineerIds],
// [PublicDemoEngineerRuntime.isReadyForFieldSales],
// `_fieldSalesActionReachableThisMonth`, and the existing raw-stage label
// `engineerStatus` already produces) — it never reads
// [PublicDemoAggregate]/[PublicDemoState] itself, adds no new domain
// authority, enum, or persisted field, and never re-derives the raw
// 9-stage label switch that already lives in `engineerStatus`
// (`public_demo_01_placeholder_screen.dart`) — that remains the one place
// that literal switch is written. This mirrors the existing convention
// documented at the top of `public_demo_employee_visual.dart`.

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

  /// Resolves [stage]'s player-facing status.
  ///
  /// Priority (Fresh Audit §5/§6, most important first — matches the
  /// existing, already-correct precedence
  /// `_currentEmployeeStatusLabel`/`_employeeStatusTone` each independently
  /// implemented, now unified into one place):
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
  ///    resolver now closes by construction, not only the
  ///    training-selection one Fresh Audit §3 explicitly found.
  /// 2. **研修が必要 / 営業可能** — [stage] is
  ///    [PublicDemoSalesStage.waiting], split on [isReadyForFieldSales]
  ///    (`PublicDemoEngineerRuntime.isReadyForFieldSales`), with 営業可能
  ///    additionally gated on [fieldSalesActionReachableThisMonth] so it is
  ///    never shown in a month with no reachable control to act on it (PR
  ///    #233 Codex review P2 fix — preserved verbatim).
  /// 3. Otherwise falls back to [rawStageLabel] — the exact, single-source
  ///    raw-stage label `engineerStatus(engineer)` already produces (covers
  ///    翌月参画予定 for a not-yet-assigned `ordered` engineer, and every
  ///    sales-pipeline sub-stage: 営業準備/営業中/案件紹介済/各面談通過・不合格).
  ///
  /// Fresh Audit §3/§6 fix: [hasTrainingSelectedThisMonth] no longer exists
  /// as a parameter here (it did, informally, in the pre-consolidation
  /// `_employeeStatusTone`). `PublicDemoState.trainingSelections` containing
  /// this engineer never overrides the label or tone this resolver
  /// otherwise reaches — an engineer who is 営業可能 (or genuinely `selling`/
  /// `introduced`/etc.) and also happens to have this month's training
  /// selected keeps showing 営業可能 (or their real stage) in both label and
  /// tone, never a training color the visible text does not match. A
  /// distinct "this month's training is also selected" fact remains
  /// available to a caller that wants to show it (`PublicDemoState
  /// .trainingSelections.containsKey(id)`) but it is deliberately not this
  /// resolver's concern — it never raises or lowers the priority of the
  /// employee's own actual current status.
  static PublicDemoEmployeeStatusDisplay resolve({
    required PublicDemoSalesStage stage,
    required bool isCurrentlyAssigned,
    required bool isReadyForFieldSales,
    required bool fieldSalesActionReachableThisMonth,
    required String rawStageLabel,
  }) {
    if (stage == PublicDemoSalesStage.ordered && isCurrentlyAssigned) {
      return const PublicDemoEmployeeStatusDisplay(
        label: '参画中',
        tone: PublicDemoEmployeeStatusTone.assigned,
      );
    }
    if (stage == PublicDemoSalesStage.waiting) {
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
    }
    return PublicDemoEmployeeStatusDisplay(
      label: rawStageLabel,
      tone: PublicDemoEmployeeStatusTone.waiting,
    );
  }
}
