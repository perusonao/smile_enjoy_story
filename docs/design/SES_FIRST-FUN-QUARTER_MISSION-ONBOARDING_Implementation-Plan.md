# SES First Fun Quarter — Mission System / Beginner Onboarding — Implementation Plan

Status: **Design, derived from `docs/reports/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Fresh-Audit.md` (READ-ONLY, same session). Read that audit first — this document assumes its findings and does not re-derive them.**

Audited/planned-against `origin/main` SHA: `dfb272619b92219853203a2f72eba4c785c0f66f`

This document is a companion plan, not a second audit. Section numbers below cross-reference the Fresh Audit's own section numbers (e.g. "§3" means the Fresh Audit's §3) rather than restarting numbering, to keep the two documents easy to cross-check.

---

## 1. Scope and Non-Goals

**In scope**: a phased Mission System for Public Demo's First Fun Quarter (April–July), a progressive/conversational onboarding redesign, SkillSheet comprehension and editing, and the recruitment-mission wiring — as scoped by the Fresh Audit's §12 phase table.

**Explicitly out of scope for this plan** (per the Fresh Audit's own findings, do not silently pull these in during implementation):

- Any change to Finance/Payroll/Matching/Revenue calculation formulas — every mission in this plan reads existing authority, none changes it.
- HOME layout changes (HOME Freeze remains in effect — Fresh Audit §1.4, §11 risk 2).
- Age/gender employee data (Fresh Audit §8 — a separate, larger product decision, `docs/DEVELOPMENT_PLAN.md` §7.1).
- Mission rewards/economy hooks of any kind (Fresh Audit §10.3 — deliberately not designed here).
- SkillSheet editing's effect on Fit/Trust/interview risk (Fresh Audit §7.3 point 2 — deferred past this plan's Phase 3).
- Main-game (non-Public-Demo) screens, except the one shared file `lib/ui/widgets/labels.dart` that Phase 3 must touch carefully (Fresh Audit §7.1, §11 risk 4).

---

## 2. Architecture Overview

```
lib/game/public_demo/                          (unchanged domain authority)
  PublicDemoEngineerSales.stage
  PublicDemoApplicant.stage / hasBeenInterviewed / hasBindingOffer / hasJoined
  PublicDemoWorkflowState.assignedEngineerIds(month:)
  PublicDemoState.trainingSelections / (NEW, Phase 1b) trainingCompletionCount-equivalent
  PublicDemoMonthlyReportSnapshot / PublicDemoMonthlyCashFlow
        │  read-only, never mutated by the Mission System
        ▼
lib/game/public_demo/public_demo_mission_resolver.dart        (NEW, Phase 1)
  — pure functions only, no BuildContext, no PublicDemoAggregate mutation,
    mirrors PublicDemoEmployeeStatusResolver's own established convention
    (Fresh Audit §11 risk 1)
  PublicDemoMissionId (enum, stable string ids for save/analytics — see §5 below)
  PublicDemoMissionStatus { locked, available, completed }
  PublicDemoMissionResolver.resolve(workflow, state, month) -> List<PublicDemoMissionStatusEntry>
        │
        ├── lib/ui/public_demo/public_demo_mission_screen.dart      (NEW, Phase 1)
        ├── AppBar entry point in public_demo_01_placeholder_screen.dart (Phase 1, minimal diff)
        └── Opening Context / progressive onboarding triggers (Phase 2)
```

**Why a resolver, not a controller**: every existing consolidation in this codebase that touches "derive a player-facing fact from several authorities" (`PublicDemoEmployeeStatusResolver`, `PublicDemoCashAdviceSelector`, `PublicDemoMonthlyReportDisplayData`) is a pure function taking already-computed primitives and returning a display value — never a widget, never a mutator. The Mission resolver must follow this pattern exactly, both because it is the established idiom and because it makes the resolver trivially unit-testable without any widget harness (Fresh Audit §14 acceptance criteria 1–4 all need this).

---

## 3. Phase 1 — Mission System Foundation + April Main Mission

**Estimated: 2.5–3h Claude Code. Depends on: nothing.**

### 3.1 New file: `lib/game/public_demo/public_demo_mission_resolver.dart`

```dart
enum PublicDemoMissionId {
  // April chain (Phase 1) — ids are stable strings once shipped; never
  // renumber/rename an id after release, since a future persisted
  // acknowledgement map (Fresh Audit §10.3) will key off these strings.
  viewSkillSheet,       // Mission 1
  beginSelling,         // Mission 3
  proposeToProject,     // Mission 4
  passPartnerInterview, // Mission 5
  passClientInterview,  // Mission 6
  winOrder,             // Mission 7
  assignToProject,      // Mission 8 — April headline mission
  // NOT included in Phase 1 (see Fresh Audit §12): training, recruitment,
  // pre-entry sales, editing SkillSheet, bonus. Adding those ids is Phase
  // 1b/3/4's job, not Phase 1's — keep this enum's Phase-1 subset minimal
  // so Phase 1's own tests stay a closed, reviewable set.
}

enum PublicDemoMissionStatus { locked, available, completed }

class PublicDemoMissionStatusEntry {
  const PublicDemoMissionStatusEntry({
    required this.id,
    required this.status,
    // The specific engineerId this mission's completion is keyed to, when
    // relevant (e.g. viewSkillSheet/beginSelling/... are per-engineer facts
    // collapsed to "has any engineer reached this stage" for the April
    // headline chain — see §3.2 below for exactly which reduction each
    // mission uses). Null for missions with no natural engineer subject.
    this.engineerId,
  });

  final PublicDemoMissionId id;
  final PublicDemoMissionStatus status;
  final String? engineerId;
}
```

### 3.2 Resolver logic — reusing Fresh Audit §3's exact authority column

Each check below is a **direct port** of Fresh Audit §3's "Completion signal" column — do not re-derive independently, and do not read anything not already cited there:

```dart
class PublicDemoMissionResolver {
  const PublicDemoMissionResolver._();

  static List<PublicDemoMissionStatusEntry> resolve({
    required PublicDemoWorkflowState workflow,
    required PublicDemoState state,
  }) {
    // April headline chain: collapse "any engineer has reached this stage"
    // to a single mission-level status — Public Demo's April roster is
    // small (2 founders), and the task's own framing treats "技術者1名を
    // 案件に参画させる" as a single company-level goal, not per-engineer.
    // If a later phase wants per-engineer granularity, extend
    // PublicDemoMissionStatusEntry.engineerId rather than changing this
    // reduction — do not silently change what "completed" means for an
    // already-shipped mission id.
    bool anyEngineerAtLeast(bool Function(PublicDemoEngineerSales) test) =>
        workflow.engineers.any(test);

    final month = state.month;
    final assignedIds = workflow.assignedEngineerIds(month: month);

    return [
      _entry(
        PublicDemoMissionId.viewSkillSheet,
        anyEngineerAtLeast((e) => e.stage != PublicDemoSalesStage.waiting),
      ),
      _entry(
        PublicDemoMissionId.beginSelling,
        anyEngineerAtLeast((e) =>
            e.stage.index >= PublicDemoSalesStage.selling.index &&
            e.stage != PublicDemoSalesStage.waiting &&
            e.stage != PublicDemoSalesStage.skillSheet),
        // NOTE: PublicDemoSalesStage is NOT declared in linear pipeline
        // order in a way that is safe to compare by .index across every
        // branch (partnerInterviewFailed/clientInterviewFailed sit
        // alongside the passed variants, not after them — see the enum
        // declaration in public_demo_sales.dart). Do not use .index
        // comparisons in the real implementation; enumerate the
        // stage set explicitly per mission, exactly as
        // PublicDemoEmployeeStatusResolver's own exhaustive switch does
        // (Fresh Audit §3, "prefer a Dart exhaustive switch... over a
        // runtime default"). The snippet above is illustrative of intent
        // only — implement with an exhaustive `switch` per mission.
      ),
      _entry(
        PublicDemoMissionId.proposeToProject,
        anyEngineerAtLeast((e) => e.stage == PublicDemoSalesStage.introduced ||
            _pastIntroduced(e.stage)),
      ),
      _entry(
        PublicDemoMissionId.passPartnerInterview,
        anyEngineerAtLeast((e) =>
            e.stage == PublicDemoSalesStage.partnerInterviewPassed ||
            _pastPartnerPassed(e.stage)),
      ),
      _entry(
        PublicDemoMissionId.passClientInterview,
        // Fresh Audit §3 row 6: check the unforgeable record, not stage
        // alone.
        anyEngineerAtLeast((e) => e.hasGenuineInterviewRecord),
      ),
      _entry(
        PublicDemoMissionId.winOrder,
        anyEngineerAtLeast((e) => e.stage == PublicDemoSalesStage.ordered),
      ),
      _entry(
        PublicDemoMissionId.assignToProject,
        assignedIds.isNotEmpty,
      ),
    ];
  }

  // ... helper predicates, engineerId-per-mission plumbing, `_entry`
  // (locked/available/completed banding — see §3.3) omitted here; full
  // implementation is Claude Code's job, not this plan's. The point of
  // this section is the *authority citations*, not final Dart syntax.
}
```

**Implementer's note**: the illustrative `_pastIntroduced`/`_pastPartnerPassed` helpers above must be written as **exhaustive switches over `PublicDemoSalesStage`'s actual 9 values** (`waiting, skillSheet, selling, introduced, partnerInterviewFailed, partnerInterviewPassed, clientInterviewFailed, clientInterviewPassed, ordered`, per Fresh Audit §3/Employee-Status-Unified-Display Fresh Audit §1.1) — copy the exhaustive-switch discipline from `PublicDemoEmployeeStatusResolver` verbatim rather than inventing an ordering-based shortcut, since the enum's declared order is **not** a safe proxy for pipeline progress (the two "Failed" variants are declared between their corresponding "Passed" variants, not after every "Passed" state).

### 3.3 `locked` vs. `available` vs. `completed`

Fresh Audit §5 gives the April chain in a fixed narrative order (1→3→4→5→6→7→8), but the *domain* does not enforce that exact linear order for mission-locking purposes beyond what the SkillSheet gate itself already enforces (`waiting→skillSheet→selling`). Recommended locking rule for Phase 1, deliberately conservative: **`available` the moment the previous chain step is `completed`; `completed` per §3.2's checks; `locked` otherwise** — a simple linear gate matching the narrative, layered **on top of**, not replacing, the domain's own real gates (a locked Mission card is advisory UI state only; it must never itself block an action the domain would otherwise allow — the SkillSheet hard gate and every other real precondition continue to be enforced exactly as today, independently of Mission lock state).

### 3.4 New file: `lib/ui/public_demo/public_demo_mission_screen.dart`

A `StatelessWidget` (or minimal `StatefulWidget` if a "just completed" animation is wanted — not required for Phase 1) taking `List<PublicDemoMissionStatusEntry>` plus display copy (a separate small `const Map<PublicDemoMissionId, PublicDemoMissionCopy>` — title, 目的, 操作 hint, one Hiyori sentence per Fresh Audit's own 目的→操作→結果→説明→次Mission shape) and rendering a simple vertical list, ordered by the April chain's fixed sequence. Mirrors `PublicDemoCandidateSkillSheetSheet`'s existing shape (`showModalBottomSheet` **or** a full `Navigator.push` route — recommend full-route, since Fresh Audit §9 Option E specifically wants an always-reachable, not transient-sheet, destination). 360×800/390×844 × TextScaler 1.0/1.3, same convention as every existing Public Demo screen.

### 3.5 Minimal-diff touch to `public_demo_01_placeholder_screen.dart`

Two changes only, both additive:

1. `AppBar.actions`: one new `IconButton` next to the existing 🔔 (`public-demo-app-bar-notifications`), key `public-demo-app-bar-mission`, opening `PublicDemoMissionScreen` via `Navigator.push`, reading `_game.workflow`/`_game.state` at build time (read-only, same pattern as every other read in this file).
2. Mission 8's completion narration (Fresh Audit §2.3/§5): extend the **existing** `_recordEngineerOrder`/assignment-related event copy (find the exact dialog/snackbar that already fires when an engineer becomes assigned — do not add a second, competing notification) with one added sentence connecting participation to future revenue. If no single existing notification covers "became assigned" (assignment is often a silent month-close consequence, not a live dialog — verify at implementation time, since Fresh Audit did not trace every assignment-adjacent notification exhaustively), prefer surfacing this sentence **inside the Mission screen's own copy** for `assignToProject` rather than inventing a new standalone dialog — keeps the touch to the placeholder screen minimal.

**Everything else in Phase 1 lives in the two new files (§3.1, §3.4).** No other existing function in `public_demo_01_placeholder_screen.dart` should need to change for Phase 1 — if implementation finds it needs to, stop and re-check against Fresh Audit §3 before proceeding, since that likely means an authority was misread.

### 3.6 Phase 1 test plan

- Resolver unit tests: one per mission id, covering `locked`/`available`/`completed` boundaries, using the exact fixture conventions already established in `public_demo_employee_status_resolver_test.dart` (construct `PublicDemoEngineerSales`/`PublicDemoWorkflowState` directly, no widget harness).
- Regression-pin: an `ordered`+assigned engineer must show `winOrder` **and** `assignToProject` both `completed` simultaneously (mirrors the existing precedent in `PublicDemoEmployeeStatusResolver`'s own test suite for the same underlying fact).
- Month-boundary test: advance from June to July and confirm `assignToProject`'s completion does not flicker for an engineer whose continuation was already decided (`nextOrderStatus == accepted`) — this is `assignedEngineerIds`'s own well-tested July filter (Fresh Audit §10.6); the new test only needs to confirm the resolver calls it correctly, not re-test the filter itself.
- Save/reload: load a save with an engineer already at `assignedEngineerIds` membership (pre-dating the Mission System) and confirm every prerequisite mission (1, 3–8) shows `completed` on first resolve, with **zero new fields present in that save** (Fresh Audit §14 criteria 1–2).
- Widget test: Mission screen renders at 360×800/390×844 × TextScaler 1.0/1.3; AppBar icon present on every tab (not just HOME).
- `flutter analyze` clean; full `test/game/public_demo` + `test/ui/public_demo` green; `git diff --check` clean.

---

## 4. Phase 1b — Training Completion Persistence

**Estimated: 1.5–2h. Depends on: Phase 1 (reuses `PublicDemoMissionId` enum shape, adds one id).**

### 4.1 New persisted field

Per Fresh Audit §3 row 9 / §10.2: add a new field to `PublicDemoState`, e.g.:

```dart
// PublicDemoState
final Map<String, int> trainingCompletionCounts; // engineerId -> lifetime count
```

(A `Set<String>`/single bool-per-engineer would also satisfy Mission 9's "受講した at least once" check; a count is recommended only if a future phase might want "trained N times" — do not over-build past what Mission 9 needs if a `Set<String>` is simpler to review. **Implementer's choice, not this plan's mandate** — either satisfies Fresh Audit §3 row 9.)

### 4.2 Wiring point — before, not after, the existing clear

`PublicDemoState.applyMonthlyGrowth` (public_demo_state.dart:744, confirmed this session) currently ends with `trainingSelections: const {}` after applying growth. Insert the new field's update **immediately before** that clear, reading the same `trainingSelections` map that is about to be erased — this is the one and only place the transient-to-durable conversion can correctly happen, since it is the sole call site that both knows "training was genuinely applied this month" and is about to discard the evidence.

### 4.3 Save-codec splice

Follow the `qaEvaluationApplies`/`offerCandidates` precedent exactly (Fresh Audit §10.1): add the field to `PublicDemoState.toJson()`/`fromJson()`, default `const {}` (or equivalent) for any save missing the key, **do not** bump `schemaVersion`. Add a focused migration test asserting a pre-Phase-1b save loads with the field empty (not null, not a crash) and that `_hasConsistentAuthorityFacts` (or its `PublicDemoState`-level equivalent, verify exact location at implementation time) does not reject a legitimate save merely for lacking this key.

### 4.4 Resolver addition

Add `PublicDemoMissionId.completeTraining` (not part of the April headline chain — reachable from May per Fresh Audit §3 row 9's own month-gate note); completion = `trainingCompletionCounts[anyEngineerId] > 0` (or the `Set` equivalent).

### 4.5 Test plan

- Unit test: select training in May, close May, confirm the new field reflects completion and `trainingSelections` is empty again (both facts, same assertion block).
- Save/reload across the May→June boundary specifically (the exact moment the transient map would have been lost pre-fix).
- Legacy-save test: a save with no `trainingCompletionCounts` key loads with the field empty, Mission 9 shows `locked`/`available` (never `completed`) — honest per Fresh Audit §10.2, not a data-loss bug.

---

## 5. Phase 2 — Mission-Driven Progressive Onboarding

**Status: COMPLETE (2026-09-14) — see `docs/reports/
SES_FIRST-FUN-QUARTER_MISSION-PHASE2_Result.md` for the full implementation
record, Fresh-Audit-at-implementation-time findings, and Phase 3 hand-off.**
Implemented as a paged Opening Context (§5.1, 5 pages rather than a strict
port of the original 6 `_OpeningSection` widgets — content was consolidated,
not dropped, onto the task's own "会社設立/社員/4月目標/資金/MISSION" shape)
plus one copy-only SkillSheet-gate fix (§5.3) and a non-modal Mission
AppBar badge in place of the §5.2 one-time-dialog trigger table — a
same-session audit found Phase 1's own Mission screen already explains each
§5.2 trigger's content, so a competing set of dialogs was deliberately not
built (see the Result report's "Fresh Audit — before implementing" section).

**Estimated: 2–2.5h. Depends on: Phase 1 (reuses Mission unlock/completion signals as explanation triggers, per Fresh Audit §6.2's table).**

### 5.1 `PublicDemoOpeningContextScreen` → paged flow

Refactor the existing six `_OpeningSection` children (Fresh Audit §6.2) into a `PageView`/index-driven "次へ" flow. **Constraint: reuse the existing section widgets and copy verbatim** — this is a presentation-shape change, not a copywriting task. Stop at the Fresh Audit §6.2 four-step subset for the *first* screen (会社設立/ひよりサポート/4月目標/CTA); move the remaining sections (cash/fixed-cost/risk detail, founding roster) to the event-driven triggers table (§5.2 below) rather than deleting them.

`PublicDemoOpeningMarker` usage is unchanged (Fresh Audit §10.4) — still `SharedPreferences`-backed, still outside save schema. If a mid-flow position needs to survive a screen rebuild (unlikely for a `PageView` within one screen instance, but verify), keep it in `State`, not `SharedPreferences`/save — it does not need to survive an app restart mid-flow; re-showing from the start on a rare interruption is acceptable and matches the existing one-shot-marker granularity (marker is only set on final completion, not per-page).

### 5.2 Event-driven explanation triggers

Implement the Fresh Audit §6.2 table as a small set of one-time dialogs, each gated by a **derived** condition (no new persisted "have I shown this yet" field beyond what's needed to make it one-time — reuse the same `SharedPreferences`-tier, non-save-schema pattern as `PublicDemoOpeningMarker`, one key per trigger):

| Trigger key | Condition | Copy source |
|---|---|---|
| `skillSheetWhyExplained` | Player opens 社員タブ for the first time with ≥1 engineer at `stage == waiting` | Fresh Audit §6.3's one-clause addition |
| `recruitmentFlowExplained` | `workflow.applicants.isNotEmpty` first becomes true | New, short — 求人媒体/書類選考 in one sentence |
| `revenueVsCashExplained` | First month-close with `PublicDemoMonthlyReportSnapshot.revenueReceived > 0` (this is also Mission 23's own completion trigger, Fresh Audit §2.4 — **reuse the same derived check, do not compute it twice**) | Reuse Monthly Report's own existing 現金/売上/入金/売掛金 wording, do not invent new financial terminology |
| `bonusExplained` | `s.month == 7` first reached | New, short — 夏季賞与制度 in one sentence |

### 5.3 SkillSheet gate copy (Fresh Audit §6.3)

One-line addition to the existing subtitle in `PublicDemoSkillSheetBody`/`_openSkillSheetReview`'s call site — not a new dialog, per Fresh Audit §6.3's own recommendation to keep this a copy change, not a new mechanic.

### 5.4 Test plan

- Each trigger fires exactly once per browser (SharedPreferences-backed, same test pattern as the existing `PublicDemoOpeningMarker` tests).
- Paged Opening Context: all six sections' original copy is still reachable somewhere (either the paged flow or an event trigger) — a regression test asserting no copy was silently dropped.
- Existing ~80 Opening-Context-adjacent widget tests + Playwright suite (Fresh Audit §1.1's own note about this constraint) still pass unmodified or with only expected, reviewed diffs.

---

## 6. Phase 3 — SkillSheet Comprehension + Editing

**Status: COMPLETE (2026-09-14) — see `docs/reports/
SES_FIRST-FUN-QUARTER_MISSION-PHASE3_Result.md` for the full implementation
record, the implementation-time Fresh Audit, and the two deliberate
deviations from this section's original plan (§6.1's shared-helper edit and
§6.2's per-language editor, both superseded below).**

**Estimated: 3h total, consider splitting into 3a (label fix + copy, 1h) and 3b (editing feature, 2h) if a single session runs long, per the governing SSOT's own 2–3h sizing guidance.**

**Superseded at implementation time (Fresh Audit findings — code kept as
authority over this plan, per this task's own "既存設計の前提と違う場合は、
コードを正として計画を修正する" rule):**

- §6.1's "edit both `_techSkillDomainLabels` and the shared `techDomainLabels`"
  is NOT what shipped. The implementation-time audit found `techDomainLabels`
  (`lib/ui/widgets/labels.dart`) read from more main-game call sites than
  this plan assumed — `project_detail_screen.dart`, `engineer_detail_screen
  .dart`, `engineer_list_screen.dart`, `applicant_detail_screen.dart`, and
  (via `fitDetailLabel`) Public Demo's own Matching screen Fit-reason line —
  none of them in this phase's scope. Localizing that shared map would have
  changed main-game screens this task never asked to touch, exactly the risk
  §6.1's own "verification required" caveat flagged. Only the private,
  Public-Demo-local `_techSkillDomainLabels` was translated; the shared
  `labels.dart` map, and the main-game screens/Public-Demo-Matching Fit-
  reason line that read it, are unchanged and left as a documented future-
  phase candidate.
- §6.2's per-language `editSkillSheetDisplayedExperience(..., language: ...)`
  shape did not ship. The implementation only edits the engineer's own
  `primaryLanguage` entry (`PublicDemoState.updateDisplayedExperience`,
  `PublicDemoAggregate.confirmSkillSheetEdit`) — Public Demo's SkillSheet
  only ever shows one confirmed language's experience comparison per
  employee in practice (see `PublicDemoSkillSheetDisplayFactory`'s own
  "only a confirmed language" rule), so a multi-language editor would add
  surface area with nothing real for the player to point it at. §6.2's own
  open clamp-bound question is resolved by reusing the main game's existing
  `SkillSheet.maxExperienceInflationMonths` (36 months) verbatim, as
  `PublicDemoEngineerRuntime.maxDisplayedExperienceInflationMonths` — never
  a second, Public-Demo-only balance constant.
- **New scope beyond this section's original text**: the governing task also
  asked for a Mission chain entry ("技術者のSkillSheetを編集する", inserted as
  Mission #2 between `viewSkillSheet` and `beginSelling`) and a dedicated
  `PublicDemoEngineerSales.salesProfileEditConfirmed` domain fact for it —
  neither was in this plan's original §6 text. See the Result Report's
  Mission-authority section for the persistence-vs-derived-fact design
  decision.

### 6.1 Phase 3a — English label fix (Fresh Audit §7.1)

Edit **both** `_techSkillDomainLabels` (`public_demo_skill_sheet_display_projection.dart:131-139`) and `techDomainLabels` (`lib/ui/widgets/labels.dart:159-167`) — translate `network/infrastructure/frontend/backend/leader/manager` to Japanese (`database`'s existing `'DB'` stays, per Fresh Audit §7.1's "conventionally kept" finding). Suggested Japanese labels (implementer/product to confirm final wording, this plan does not mandate exact copy): `ネットワーク`/`インフラ`/`フロントエンド`/`バックエンド`/`リーダー`/`マネージャー` — katakana, matching how these terms actually appear in Japanese SES job postings/skill sheets in practice (unlike the bare-English words currently shown).

**Verification required, not optional** (Fresh Audit §11 risk 4): grep every call site of `techDomainLabels`/`topRequiredSkillLabel` outside Public Demo (the main game's Project/Fit screens) and confirm the new Japanese labels still fit their layout — this is a shared file, changing it changes main-game screens too, unlike every other Phase-3 change which is Public-Demo-local.

Add the §6.3 SkillSheet-gate copy addition here too if not already done in Phase 2 (either phase is a valid home for that one-line change — do not do it twice).

### 6.2 Phase 3b — SkillSheet editing (display-only scope, Fresh Audit §7.3)

1. New domain method on `PublicDemoAggregate` (name illustrative): `editSkillSheetDisplayedExperience({required String engineerId, required ProgrammingLanguage language, required int displayedMonths})` — validates the engineer/language exist and `language ∈ confirmedLanguages` (do not allow editing an unconfirmed language into existence — that would be inventing experience, not adjusting how real experience is presented), clamps `displayedMonths` to a reasonable bound (e.g. `actualMonths * 2`, or a flat cap — **product decision needed on the exact bound**, this plan only asserts a bound must exist so editing cannot be used to claim arbitrary decades of fabricated experience), writes to the existing `LanguageSkill.displayedExperienceMonths` field.
2. **No save-schema change** — the field already round-trips (Fresh Audit §7.3 point 3).
3. UI: a small edit affordance inside `_ExperienceSection` (`public_demo_skill_sheet_sections.dart`) — an edit icon per experience-comparison row, opening a minimal number-input dialog, calling the new domain method through the same `_commitAggregate` pattern every other mutation in the placeholder screen already uses.
4. **Explicitly do not** wire this to `PublicDemoEngineerProjectFit.compute` or any interview evaluator in this phase (Fresh Audit §7.3 point 2) — both must keep reading `actualExperienceMonths`/`actualCapability` only, unchanged.

### 6.3 Test plan

- Label fix: a text-content assertion test for the SkillSheet's tech-skill chips (no more bare `Frontend`/`Backend`/etc.), plus a main-game regression spot-check on whichever screen uses `topRequiredSkillLabel`.
- Editing: unit test the new domain method's validation/clamping; widget test the edit flow round-trips through save/reload; confirm `PublicDemoEngineerProjectFit.compute` output is bit-for-bit unchanged before/after an edit (the explicit non-goal from §6.2 point 4, pinned as a regression test).

---

## 7. Phase 4 — Recruitment Missions

**Estimated: 2.5–3h. Depends on: Phase 1 (resolver pattern).**

### 7.1 Mission ids to add

Per Fresh Audit §3/§2: `postRecruitmentMedium` (11), `viewApplicantSkillSheet` (12, completion widened to `resumeReviewed` per §3 row 12 — do not add separate view-tracking), `screenApplicantResume` (13), `conductHiringInterview` (14, keyed to `session.completed`), `presentSalaryAndOffer` (15+16 merged), `preEntrySellingStarted` (18), `preEntryOrderWon` (19), `applicantJoined` (20), `assignNewHire` (21, reusing Phase 1's `assignToProject` check scoped to a post-join engineer). **Do not add an id for Mission 17** (dropped per Fresh Audit §2.2) or Mission 22 (folded into 8/21 per §2.3).

### 7.2 Document-screening rejection (Fresh Audit §8 backlog item)

Small, real gap-fix, bundle into this phase since it shares the recruitment-card UI surface: add a "不採用にする" button on the `resumeReviewed`-stage applicant card, calling the **already-public** `PublicDemoWorkflowState.rejectApplicant`/`PublicDemoAggregate` equivalent (verify exact aggregate-level entry point at implementation time — `rejectApplicant` is confirmed to exist on `PublicDemoWorkflowState`; confirm whether `PublicDemoAggregate` already exposes a passthrough or one needs to be added, mirroring the existing `reviewResume`/`concludeInterviewSession` passthrough pattern). No new domain logic — this reuses an existing, already-tested transition, just from an earlier stage than its current sole call site.

### 7.3 Test plan

- One resolver test per new mission id, reusing Fresh Audit §3's cited authority per row.
- Widget test for the new "書類選考で不採用にする" button: confirm it moves the applicant to `rejected`, confirm a rejected-at-resume-stage applicant behaves identically downstream (payroll/join eligibility) to one rejected post-interview (both are the same `rejected` stage — this should be a thin wiring test, not a new behavior test).
- Pre-entry sequence (18/19) test: confirm mission unlock correctly reflects the `canEnterPreJoinSales`/`isInexperienced` gate (Fresh Audit §3 row 18) so an inexperienced hire's Mission list does not show these as a dead-end "available" item.

---

## 8. Phase 5 — Visual/Data Polish

**Estimated: 2–2.5h, excluding external asset re-export lead time (event-image quality) and excluding the age/gender item (out of scope, Fresh Audit §8).**

- Wire the existing 8 role-based character images into `_employeeRosterCard` (Fresh Audit §8) — role tier → image mapping only (junior/midlevel/veteran engineer), explicitly documented in code comments as **not** identity/demographic-linked, to avoid the confusion Fresh Audit §8 specifically warns about.
- Hiyori result-image sizing parity fix (locate the exact result-card file at implementation time; Fresh Audit did not pin the exact line).
- Sales-candidate-card height re-measurement against existing 360×800/390×844 fixtures (Fresh Audit §8 — verify before redesigning; may already be within acceptable bounds and only *feel* large without being a real overflow/scroll problem).
- Coordinate (not implement in-repo) the event-image re-export — this is an asset-production task, not a Claude Code code change; track separately from the code-touching items above.

---

## 9. Cross-Phase Save Compatibility Checklist

Re-stated from Fresh Audit §10 as an implementation-time checklist, apply on every phase that touches persistence (1b, 3b):

- [ ] `schemaVersion` stays `1` — new fields are additive-only, never a hard-reject trigger.
- [ ] Every new field has an explicit, documented default for a save that predates it.
- [ ] The default is *honest* (e.g. "never trained" for a legacy save, not a guessed/backfilled value).
- [ ] A migration test loads a **fixture saved before the field existed** (construct the JSON by hand, omitting the new key — do not just construct a fresh object and call `toJson` from current code, which would trivially include the field) and asserts a clean, non-crashing load with the documented default.
- [ ] No new field is ever required for `_hasConsistentAuthorityFacts` (or equivalent) to treat an old, otherwise-valid save as consistent.
- [ ] No `month` value is captured and reused stale across a resolver call (Fresh Audit §10.6).

---

## 10. Risks Carried Forward From the Fresh Audit (do not re-litigate, re-check before proceeding)

1. **HOME Freeze / AppBar interpretation (Fresh Audit §11 risk 2, §16 verdict)** — confirm before Phase 1's AppBar change lands. If the interpretation is rejected, the fallback is Fresh Audit §9 Option C (メニュー内Mission入口) — strictly worse for discoverability but zero-ambiguity Freeze-safe; do not fall back to Option A (6th tab) or B/D (HOME card) without a separate, explicit sign-off, since both carry confirmed risk/policy conflicts (§9).
2. **6,721-line placeholder screen** — if any phase finds itself making more than the minimal-diff touches this plan specifies (§3.5, and the equivalent "minimal touch" principle for Phases 2–4), stop and reconsider whether the new logic belongs in a new file instead.
3. **Shared `labels.dart` file (Phase 3a)** — main-game regression check is mandatory, not optional, per §6.1 above.
4. **Mission 9's field shape (Phase 1b)** — get the count-vs-set decision made once, deliberately (§4.1); do not let it drift across the implementation session.

---

## 11. Summary Timeline

| Phase | Est. | Cumulative |
|---|---|---|
| 1 | 2.5–3h | 2.5–3h |
| 1b | 1.5–2h | 4–5h |
| 2 | 2–2.5h | 6–7.5h |
| 3 (3a+3b) | 3h | 9–10.5h |
| 4 | 2.5–3h | 11.5–13.5h |
| 5 | 2–2.5h | 13.5–16h |

Total: **~13.5–16h across 6 Claude Code sessions**, each individually within the governing SSOT's 2–3h recommended sizing (`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`, "AI task sizing" section) except Phase 3 combined (3h, at the edge — split into 3a/3b as two sessions if preferred, per §6's own note).

---

## 12. Next Action — Phase 1 Hand-off

The next Claude Code session for this initiative should be given **exactly**:

> Implement Phase 1 of `docs/design/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md` (§3 of that document): the Mission System foundation and April main mission. Create `lib/game/public_demo/public_demo_mission_resolver.dart` and `lib/ui/public_demo/public_demo_mission_screen.dart` per §3.1–§3.4, add the AppBar entry point and Mission-8 completion narration per §3.5 (minimal diff to `public_demo_01_placeholder_screen.dart` only), and implement the test plan in §3.6. Do not implement Phase 1b, 2, 3, 4, or 5. Confirm the HOME-Freeze/AppBar interpretation (§10 risk 1 of this plan, §11 risk 2 / §16 of the Fresh Audit) before touching the AppBar, or flag it for human sign-off if genuinely ambiguous rather than guessing. Read `docs/reports/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Fresh-Audit.md` §3 and §5 first for the authority citations this plan's resolver logic is derived from.

This is the "次にClaude Codeへそのまま渡せるPhase 1実装範囲" the task requested.
