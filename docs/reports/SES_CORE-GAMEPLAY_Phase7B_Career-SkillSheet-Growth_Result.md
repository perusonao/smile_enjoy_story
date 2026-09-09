# SES CORE-GAMEPLAY Phase 7B: Career History / SkillSheet Growth — Result Report

Issue: #208
Base branch: `main`
Working branch: `claude/phase-7b-career-skillsheet-9k0k5s`
BASE SHA: `a7f2938dc55ced3426aaffe82533d6e767a30f60` (Phase 7A merge commit, PR #215 — confirmed an ancestor of `origin/main` before work started)
Final HEAD SHA: `7eedb59211695b4e294fb029e2c1bd0b69b3e387`
PR: [#216](https://github.com/perusonao/smile_enjoy_story/pull/216)

**Actual processing time:** ~35 minutes (git fetch/branch setup through PR creation), against the issue's 90–150 minute estimate.

## 1. Summary

Phase 7B completes the employee-growth loop the issue describes:

```
案件参画 → 実務経験/能力成長 → 案件経歴を記録 → SkillSheetで確認 → 次回Matchingへ反映 → より良い案件を狙える
```

Every step except "案件経歴を記録" (recording career history) already existed in the codebase after Phase 7A:

- `CareerHistoryEntry`, `Engineer.careerHistory`, `PublicDemoEngineerRuntime.careerHistory` — data model already in place, already round-tripped through save/load.
- `PublicDemoSkillSheetDisplayFactory`/`PublicDemoSkillSheetSheet`/`public_demo_skill_sheet_sections.dart` — the SkillSheet UI already reads `runtime.careerHistory` and renders a "案件経歴" section (empty-state text only, since nothing had ever written to it).
- `PublicDemoGrowthEngine`/`PublicDemoState.applyMonthlyGrowth` — monthly growth authority, unchanged in formula.
- `PublicDemoMatchingFit`/`MatchingEngine` — Matching already reads `PublicDemoEngineerRuntime` (`totalItExperienceMonths`, `languageSkills`, `industryExperience`) fresh on every call; no caching, no snapshot to invalidate.

**What was missing, and the only thing this phase adds, was the production writer.** No code anywhere ever constructed a `CareerHistoryEntry` outside of tests. This phase adds exactly one writer, at exactly one lifecycle boundary — `PublicDemoAggregate.endAssignment` (the Phase 7A "assignment genuinely ends" boundary) — plus the minimal supporting bookkeeping needed to make that writer truthful:

1. `PublicDemoAssignment.monthsCredited` — a new, additive field that counts (exactly, never more, never less) how many months `PublicDemoGrowthEngine` actually credited *this specific assignment's* engineer under `source: assignment`.
2. `PublicDemoWorkflowState.creditAssignmentMonths` — increments that counter, called from the exact same month-end close path that calls `PublicDemoState.applyMonthlyGrowth`, and only when that call actually changed something (never on an already-applied-month no-op).
3. `PublicDemoAggregate.endAssignment`'s new CareerHistory writer — builds a `CareerHistoryEntry` from the just-ended assignment's own real facts (`monthsCredited`, and, when the assignment carries a genuine Phase 6 `projectId`, the resolved real `Project`/`Client`) and appends it to that engineer's `PublicDemoEngineerRuntime.careerHistory`.
4. A previously-dead `PublicDemoGrowthRequest.industry` parameter is now actually wired: `PublicDemoAggregate`'s month-end close resolves each assigned engineer's real project `Industry` (via `PublicDemoAssignment.projectId` → `PublicDemoSeededProjectGenerator.regenerate`, the same resolution the CareerHistory writer itself uses) and feeds it into the same, single monthly Growth call — closing the "Real project industry/technology context... where Phase 7A now provides authoritative data" gap the issue calls out, without adding a second growth application.

No other authority was touched. `MatchingEngine`'s formula, HOME, Finance/balance, and SkillSheet's player-editable representation are all unmodified.

## 2. CareerHistory writer boundary

**Single writer, single boundary:** `PublicDemoAggregate.endAssignment(String engineerId)` in `lib/game/public_demo/public_demo_aggregate.dart`. This is the exact method Phase 7A introduced as "the single domain-owned way to end an assignment" — this phase does not introduce a second lifecycle boundary, it only adds a write inside the one that already exists.

```dart
PublicDemoAggregate endAssignment(String engineerId) {
  final ended = workflow.assignments
      .where((assignment) => assignment.engineerId == engineerId)
      .firstOrNull;                      // captured BEFORE ending
  final nextWorkflow = workflow.endAssignment(engineerId, month: state.month);
  if (identical(nextWorkflow, workflow)) return this;   // Phase 7A's own no-op guard
  ...
  // CareerHistory is only ever written in this branch, using `ended` —
  // the pre-transition assignment — never a re-read after the fact.
}
```

### Exactly once, by construction (no second flag needed)

Phase 7A's `PublicDemoWorkflowState.endAssignment` already guarantees `identical(nextWorkflow, workflow)` on any call that isn't a genuine, first-time end (wrong `nextOrderStatus`/`replacementStage`, engineer not `ordered`, no assignment at all — see that method's own precondition doc). The CareerHistory write is placed **inside the exact same `!identical(...)` branch** that the pre-existing Finance re-projection already requires to run. This means:

- **Double end never duplicates.** A second `endAssignment('eng-01')` call hits the identical no-op guard and returns `this` unchanged — verified directly (`identical(again, aggregate)` and `careerHistory` length stays 1).
- **Save/reload never duplicates.** The writer only ever runs from the `endAssignment` command. Loading a save never re-invokes it — `PublicDemoEngineerRuntime.careerHistory` round-trips through `toJson`/`fromJson` like any other field, with no derivation logic on load. Verified by round-tripping through the real `PublicDemoSaveCodec`, twice in a row.

### What gets recorded, and why nothing here is fabricated

| Field | Source | Fabrication risk |
|---|---|---|
| `experienceMonths` | `assignment.monthsCredited` — see §3 | None: this is exactly the number of months `PublicDemoGrowthEngine` already credited under `source: assignment` for this exact assignment, never a calendar span. |
| `projectName` | Resolved `Project.title` when `assignment.projectId` is genuine (Phase 6), else `assignment.projectName` (the real, already-persisted generic value, e.g. `新規開発支援`) | None: both are real, already-authoritative strings; never invented text. |
| `industry` | Resolved `Project.industry` when `projectId` is genuine, else `null` | None: `null` when unknown, never guessed. |
| `clientNameSnapshot` | Resolved `Client.name` when `projectId` is genuine, else `null` | None. |
| `languages` | `[runtime.primaryLanguage]` — the one language `PublicDemoGrowthEngine` actually grew during this assignment | Deliberately **not** `Project.requiredLanguages` verbatim — a project can require a language this specific engineer never touched personally. |
| `technologies` | The resolved `Project`'s own non-zero required-skill domains (`DB`/`Network`/`Infra`/`Frontend`/`Backend`/`Leader`/`Manager`) | These are real, already-authoritative `int` fields on `Project`; `[]` when there is no resolved project (`Project` has no free-text tech list — the issue explicitly forbids inventing one). |
| `role`, `teamSize`, `processes`, `startWeek`/`endWeek` | Left at their defaults (`''`, `0`, `[]`, `null`) | Public Demo has no authoritative source for any of these (no week-granular calendar, no role/team-size tracking) — per the issue's own instruction, nothing here is invented merely because the field exists. |
| `summary` | A short, factual sentence built only from `projectName`/`monthsCredited` | No claim beyond what the two source facts already say. |

**Skip condition:** no entry is written when `monthsCredited == 0`. In the current production flow this is effectively unreachable (see §3 — the first month-end close that creates an assignment always credits it in the same call), so this is a defensive guard, not a gap: it exists so a future code path can never silently produce a `0か月` placeholder entry, which would be truthful but useless clutter, never a fabricated value.

## 3. Growth accounting proof (no double counting)

The issue's hardest constraint: monthly Growth and end-of-assignment Growth must never both apply.

**This phase never calls `PublicDemoGrowthEngine`/`PublicDemoState.applyMonthlyGrowth` from `endAssignment`.** Ending an assignment only *reads* facts Growth already produced; it writes zero capability/experience deltas. Verified directly: `runtime.totalItExperienceMonths` before and after `endAssignment` is asserted equal in the focused test suite.

`PublicDemoAssignment.monthsCredited` is the only new counter, and it is deliberately **not** derived from a calendar span (start month → end month), because a player may leave `nextOrderStatus == notOffered` for several months before finally calling `endAssignment` — none of those idle months ever earned assignment-sourced growth, and a calendar-span count would silently overclaim them. Instead:

- `PublicDemoWorkflowState.creditAssignmentMonths(Set<String> engineerIds)` increments `monthsCredited` by exactly 1 for every assignment whose `engineerId` is in the given set.
- It is called from exactly one place: `PublicDemoAggregate._closeGrowth`, the private helper every month-end close (`closeApril`/`closeMay`/`closeJune`/`closeJuly`/`closeOrdinaryMonth`) already funneled through for `PublicDemoState.applyMonthlyGrowth`.
- It is called **with the exact same `assignedEngineerIds` set** already passed to `applyMonthlyGrowth`, and **only when that call actually changed something** (`!identical(grownState, state)`):

```dart
({PublicDemoState state, PublicDemoWorkflowState workflow}) _closeGrowth(
  Set<String> assignedEngineerIds, {
  PublicDemoWorkflowState? workflow,
}) {
  final effectiveWorkflow = workflow ?? this.workflow;
  final grownState = state.applyMonthlyGrowth(
    assignedEngineerIds: assignedEngineerIds,
    moraleByEngineerId: this.workflow.moraleByEngineerId,
    industryByEngineerId: _industryByEngineerId(assignedEngineerIds, workflow: effectiveWorkflow),
  );
  return (
    state: grownState,
    workflow: identical(grownState, state)
        ? effectiveWorkflow
        : effectiveWorkflow.creditAssignmentMonths(assignedEngineerIds),
  );
}
```

Because `applyMonthlyGrowth` itself is already guarded (`fiscalYearCompleted || growthAppliedMonths.contains(month)` → no-op, returns `this` unchanged by identity), `monthsCredited` can never increment for a month Growth didn't actually apply. This closes exactly the "月次Growthと案件終了時Growthを二重加算しない" and "実際に参加した月数だけ経験として扱う" requirements with one mechanism, not two independently-verified ones.

**Verified in tests** (`public_demo_career_history_writer_test.dart`):
- `monthsCredited` starts at 1 immediately after the May close that creates the assignment (May's own close is the same call that both creates the row and credits its first month).
- Increments by exactly 1 per subsequent real month-end close (June, then July — the latter only once the player explicitly accepts the renewal, matching `assignedEngineerIds`' own July-onward filtering).
- `creditAssignmentMonths` only touches the engineerIds it's given; every other assignment's own counter is untouched.

## 4. SkillSheet authority

No change to the SkillSheet display/edit boundary. `PublicDemoSkillSheetDisplayFactory.create` already read `runtime.careerHistory` verbatim (`careerHistory: runtime?.careerHistory ?? const []`), and `public_demo_skill_sheet_sections.dart`'s `_ExperienceSection` already rendered a "案件経歴" list from it (project name, role if present, `formatExperience(entry.experienceMonths)`, summary) — with an honest empty-state message when there was nothing to show. Because nothing ever *wrote* to `careerHistory` before this phase, that section only ever showed its empty state; this phase makes it show real data, without touching a single line of UI/presentation code.

The always-available "社員タブから在籍社員のスキルシートを常時確認できること" entry point (`_viewEmployeeSkillSheet` in `public_demo_01_placeholder_screen.dart`) already lets the player open any joined employee's SkillSheet at any stage — including after their assignment has ended — so the newly-written CareerHistory is reachable in the running game with zero UI changes.

`CareerHistoryEntry` (factual, gameplay-derived) and the player-editable displayed SkillSheet values (`LanguageSkill.displayedExperienceMonths`, etc.) remain two entirely separate concerns, exactly as the issue requires — this phase never writes to the latter, and the writer never reads or is influenced by it.

## 5. Matching handoff

No change to `MatchingEngine` or `public_demo_matching_fit.dart`'s own scoring/formula. `PublicDemoMatchingFit._placeholderEngineerFor(runtime)` already builds its `Engineer`/`Applicant` freshly from `runtime.totalItExperienceMonths`, `runtime.languageSkills` (confirmed), `runtime.techSkills`, and `runtime.primaryLanguage` on every single call — there is no cached/stale copy anywhere. Because Growth (monthly, unchanged formula) and the new Industry wiring (§6) both write directly into that same `PublicDemoEngineerRuntime`, any accumulated growth is automatically visible to the very next `PublicDemoMatchingFit.compute`/`engineerFor` call, with zero additional plumbing. This satisfies "later Matching can observe the engineer's accumulated authoritative growth without modifying Matching scoring" by construction, not by a new adapter.

## 6. The Industry growth-path fix (real project context → existing growth path)

`PublicDemoGrowthRequest.industry` and the industry-experience branch inside `PublicDemoGrowthEngine.calculate` already existed (added at some point before this phase) but were **never actually passed a value** — `PublicDemoState.applyMonthlyGrowth`'s own pre-existing doc comment said so explicitly: *"The current demo assignment model has no reliable industry field, so this method intentionally does not invent one; industry experience remains 0."*

Phase 7A's `PublicDemoAssignment.projectId` makes that comment stale: a genuine, project-bound assignment now *does* resolve to a real `Project.industry`. This phase:

- Adds `PublicDemoAggregate._industryByEngineerId(assignedEngineerIds, {required workflow})`, which resolves each currently-assigned engineer's real `Industry` via `PublicDemoSeededProjectGenerator.regenerate(runSeed: state.runSeed, projectId: assignment.projectId)` — the exact same resolution the CareerHistory writer itself uses, so both share one derivation.
- Threads it into `PublicDemoState.applyMonthlyGrowth`'s new, **optional** `industryByEngineerId` parameter (defaults to `null`/empty — every existing call site and every existing focused Growth test that doesn't pass it keeps its exact prior behavior, verified: `public_demo_monthly_growth_test.dart` passes unmodified).
- This is still exactly one Growth call per month per engineer — the industry-experience branch inside `PublicDemoGrowthEngine.calculate` was already gated on `practicalExperience > 0` (i.e. `source == assignment`), so this is a **fix to what was already a no-op growth path**, not a new, second growth application.

Verified with a genuine end-to-end seed scan (real proposal → real Phase 6 interview → real order → real May assignment with a genuine `projectId`): `runtime.industryExperience[resolvedProject.industry] == 1` after the May close.

## 7. Persistence / migration

Two new additive fields, both following the exact backward-compatible pattern Phase 5/6/7A already established for `totalItExperienceMonths`/`interviewRecordProjectId`/`projectId`:

- `PublicDemoAssignment.monthsCredited` (`int`, JSON key `monthsCredited`) — absent on any save written before this phase decodes as `0`.
- `PublicDemoEngineerRuntime.careerHistory` already existed and already decoded an absent key as `[]`; unchanged.

**The real gap this phase had to fix itself:** `PublicDemoSaveCodec.fromJson` performs a strict round-trip comparison against a "baseline" that must have every additive-default already spliced in, or a save missing the new key is rejected wholesale (this is exactly the pattern behind `_withMigratedAssignmentProjectId`, `_withMigratedEngineerRuntimeExperience`, etc. — each documented with the same "silently discarding real player progress" warning). This phase adds:

- A new splice, `_withMigratedAssignmentMonthsCredited`, mirroring `_withMigratedAssignmentProjectId` exactly (backward-compatible value `0`).
- Extends the existing `_withMigratedEngineerRuntimeExperience` (renamed in spirit, not in name, to also splice `careerHistory: []` per-entry) rather than adding a parallel method, since both fields live on the same `engineerRuntimes[*]` entries.

Both are wired into `fromJson`'s baseline chain right after the existing `_withMigratedAssignmentProjectId` call.

**Verified in tests:**
- A genuine save/reload immediately after `endAssignment` round-trips the new `CareerHistoryEntry` byte-for-byte (`codec.toJson(restored) == codec.toJson(aggregate)`), and a second reload of the reloaded aggregate does not grow the list.
- A save with `monthsCredited` and `careerHistory` keys stripped entirely (simulating a genuine pre-Phase-7B payload) still decodes successfully, with `monthsCredited == 0` and `careerHistory == []` — never rejected, never a fabricated retroactive figure.
- All pre-existing SaveCodec/assignment-lifecycle focused suites (93 tests across `public_demo_save_codec_test.dart`, `public_demo_assignment_lifecycle_save_codec_test.dart`, `public_demo_assignment_lifecycle_test.dart`) pass unmodified.

## 8. Files changed

| File | Change |
|---|---|
| `lib/game/public_demo/public_demo_assignment.dart` | Adds `monthsCredited` (field, `copyWith`, `toJson`, `fromJson`). |
| `lib/game/public_demo/public_demo_workflow_state.dart` | Adds `creditAssignmentMonths`. |
| `lib/game/public_demo/public_demo_state.dart` | `applyMonthlyGrowth` gains an optional `industryByEngineerId` parameter; wires it into the per-engineer `PublicDemoGrowthRequest`. |
| `lib/game/public_demo/public_demo_aggregate.dart` | `_closeGrowth` restructured to return `(state, workflow)` and credit `monthsCredited`/resolve industry; every month-end close (`closeApril`/`closeMay`/`closeJune`/`closeJuly`/`closeOrdinaryMonth`) updated to the new shape; `endAssignment` gains the CareerHistory writer; adds `_careerHistoryEntryFor`, `_technologiesFor`, `_industryByEngineerId`. |
| `lib/game/persistence/public_demo_save_codec.dart` | Adds `_withMigratedAssignmentMonthsCredited`; extends `_withMigratedEngineerRuntimeExperience` to also splice `careerHistory`; wires the new splice into `fromJson`. |
| `test/game/public_demo/public_demo_career_history_writer_test.dart` | New focused test file (8 tests) — see §9. |
| `test/game/public_demo/public_demo_recovery_aggregate_test.dart` | Updates a pre-existing schema-lock-in test to acknowledge the new additive `monthsCredited` JSON key (caught by the full suite run — see §9). |

No changes to `MatchingEngine`, HOME, Finance/balance code, or any SkillSheet UI/presentation file.

## 9. Tests

### New focused tests — `public_demo_career_history_writer_test.dart` (8/8 passing)

- `monthsCredited` starts at 1 for a freshly-assigned engineer (May's own close both creates and credits it).
- `monthsCredited` increments by exactly 1 per subsequent month-end close, never more.
- `creditAssignmentMonths` only touches the given engineerIds.
- `endAssignment` writes exactly one truthful `CareerHistoryEntry`, tied to `monthsCredited` (never a calendar span, never a second growth application — `totalItExperienceMonths` unchanged by the call itself).
- Double end never duplicates the entry.
- Save/reload never duplicates the entry (including a second reload of the reloaded save).
- A legacy save (assignment stripped of `monthsCredited`/`projectId`; runtime stripped of `careerHistory`) still loads, defaulting to `0`/`[]`.
- A genuine, project-bound assignment (real seed-scanned Phase 6 pass) credits its real project's `Industry` through the ordinary May close.

### Focused regression suites re-run (all green, unmodified)

- `public_demo_assignment_lifecycle_test.dart`
- `public_demo_assignment_lifecycle_save_codec_test.dart`
- `public_demo_monthly_growth_test.dart`
- `public_demo_growth_engine_test.dart`
- `public_demo_save_codec_test.dart`
- `public_demo_matching_test.dart`

(120 tests total across these six files, 120 passing.)

### Full suite / static checks

- `flutter analyze`: **No issues found.**
- `git diff --check`: clean (no whitespace errors).
- `flutter test --concurrency=6` (full suite): **2040/2040 passing.** The first full run caught one pre-existing schema-lock-in test (`public_demo_recovery_aggregate_test.dart`'s "Recovery introduces no new save-schema keys" — an explicit enumeration of `PublicDemoAssignment`'s JSON keys) that needed updating to acknowledge the new additive `monthsCredited` key, following that test's own existing per-phase-field documentation convention (`// CORE-GAMEPLAY Phase 7A: ...` / now `Phase 7B: ...`). This is expected maintenance the test exists specifically to force, not a regression — the second full run passed clean.

## 10. Known limitations

- **`monthsCredited == 0` skip path is currently unreachable in production**, not just untested: the only way an assignment enters `workflow.assignments` is `assignOrderedForMay`/`recoverLateYearAssignment`, both called from within the same `PublicDemoAggregate` month-end-close method that also credits that month's Growth in the same call — so by the time an assignment exists, it already has `monthsCredited >= 1`. The skip guard is kept as defensive-in-depth documentation of intent, not a currently-exercised branch.
- **A legacy save's in-flight assignment starts crediting from `monthsCredited: 0`** at the moment it is loaded under this phase, never retroactively inferred from the save's pre-existing `totalItExperienceMonths`. This matches the exact precedent `projectId`/`interviewRecordProjectId` already set for additive Phase 7A fields — a real, bounded, and honestly-documented gap, not a defect: it only affects an assignment that was already open at the moment of upgrading from a pre-Phase-7B save, and self-heals (starts crediting normally) from the next month-end close onward.
- **`CareerHistoryEntry.role`/`teamSize`/`processes`/`startWeek`/`endWeek` are left at their defaults** for every Public Demo-written entry — Public Demo has no authoritative source for any of them (no role/team-size tracking, no week-granular calendar). Per the issue's own instruction, no unsupported field was invented merely because the model has a slot for it.
- **`technologies` is derived, not literal**: `Project` has no free-text technology list, so this phase maps the project's own non-zero required-skill-domain fields (DB/Network/Infra/Frontend/Backend/Leader/Manager) to their existing SkillSheet-consistent labels. This is a real, non-fabricated fact about the resolved project, but it is a derived projection, not a stored field, and is scoped to the same domain labels the SkillSheet's own tech-skill section already uses.
