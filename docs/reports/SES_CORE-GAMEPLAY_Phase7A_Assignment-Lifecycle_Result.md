# SES CORE-GAMEPLAY Phase 7A: Assignment Lifecycle — Result Report

**Issue:** [#207](https://github.com/perusonao/smile_enjoy_story/issues/207)
**Branch:** `claude/assignment-lifecycle-phase-7a-fi92g1`
**BASE SHA:** `7662a4c756769d006d0e57b4e50c7811b48002ae` (Merge PR #214: CORE-GAMEPLAY Phase 6 Project Interview, `origin/main` HEAD at task start)
**Dependency verified:** Phase 6 PR #214's merge commit is contained in `origin/main` (`git merge-base --is-ancestor` confirmed) before any implementation work began.

## 1. Actual processing time

Roughly 2.5 hours of continuous execution (audit → design → implementation → hardening → focused tests → full regression → report), within the Issue's 120–180 minute estimate.

## 2. Latest-main / authority audit

Read/audited before writing any code:

- `ActiveAssignment` (`lib/game/models/project_proposal.dart`) and its lifecycle in `game_engine.dart` (`remainingWeeks` decrement → contract end → `engineer.status = waiting` → re-enters selling).
- `PublicDemoAssignment` / `PublicDemoWorkflowState` / `PublicDemoAggregate` (`lib/game/public_demo/`).
- `PublicDemoSaveCodec` strict round-trip machinery (`lib/game/persistence/public_demo_save_codec.dart`), including its per-entry additive-field migration pattern (`_withMigratedInterviewRecordProjectId` etc.) and its cross-record identity checks (proposal/session/record cross-checks).
- Phase 6 pass/order handoff: `PublicDemoEngineerSales.genuineInterviewProjectId` / `PublicDemoEngineerInterviewRecord.projectId` / `PublicDemoMatchingProposal.projectId` / `PublicDemoSeededProjectGenerator.regenerate`.
- Existing Finance/Month authority: `PublicDemoRevenue.monthlyRevenueForAssignedCount`, `PublicDemoWorkflowState.assignedEngineerIds`, `PublicDemoState.engineersAssigned`/`engineersWaiting`, `PublicDemoMonthlyClose`.
- The existing `nextOrderStatus`/`replacementStage` per-month renewal/replacement decision loop, already domain-owned via `PublicDemoAggregate.withAssignmentUpdate`/`consumeSlotAndSetReplacementStage`/`recoverAssignment` — the UI (`public_demo_01_placeholder_screen.dart`'s `decideOrder`/`acceptOrder`/`replacementPartner`/`replacementClient`) was already a thin caller of these, not a second authority.
- `PublicDemoRecoveryEligibility`/RECOVERY-LOOP-1 (`recoverLateYearAssignment`) — the existing late-year (month 7–14) "genuinely re-ordered engineer gets picked up into `assignments`" path Phase 7A's own re-entry relies on.

**Key finding that shaped the design:** the main game already has a real start→active→end→available lifecycle (`ActiveAssignment.remainingWeeks`); Public Demo's own `assignOrderedForMay`/`recoverLateYearAssignment` create assignments but **discarded** the real Phase 6 project identity (`PublicDemoEngineerSales.genuineInterviewProjectId`), always falling back to a generic placeholder (`projectName: '新規開発支援'`). Separately, an engineer whose contract ended (`nextOrderStatus: notOffered`) with no replacement secured had **no way back into the real Sales pipeline** — `stage` stayed frozen at `ordered` forever (no production path resets it to `waiting`), so `startSkillSheetReview`'s own precondition (`stage == waiting`) could never fire again. These were the two concrete, scoped gaps Phase 7A needed to close — not a rewrite of the existing (already well-hardened) `nextOrderStatus`/`replacementStage` decision loop.

## 3. Lifecycle/persistence design (confirmed before implementation)

Reused existing authority rather than inventing a parallel lifecycle:

- **Real project identity** — added `PublicDemoAssignment.projectId` (nullable `String`), populated only from `PublicDemoEngineerSales.genuineInterviewProjectId` at the moment an assignment is created (`assignOrderedForMay`, `recoverLateYearAssignment`). Resolvable back to the full `Project`/`Client` via `PublicDemoSeededProjectGenerator.regenerate(runSeed, projectId)` — the exact same mechanism `PublicDemoMatchingProposal.projectId` already uses; no new resolution formula invented. `null` for the pre-existing generic (project-agnostic) interview path — unchanged behavior.
- **End → available → re-entry** — added `PublicDemoWorkflowState.endAssignment(engineerId)` / `PublicDemoAggregate.endAssignment(engineerId)`: removes the assignment and resets the engineer's `PublicDemoSalesStage` to `waiting` atomically, gated on `nextOrderStatus == notOffered && replacementStage != ordered`. This is the counterpart to the existing `replacementStage` mini-cycle (which keeps the same slot); the player may choose either path once a renewal is declined, never both. Re-entry then reuses the **existing, unmodified** Sales pipeline (`startSkillSheetReview` → … → `recordOrder` → `recoverLateYearAssignment`/`assignOrderedForMay`) — satisfying the Issue's "begin searching for the next project during the current month" requirement with no new gameplay mechanic.
- **Persistence** — `projectId` is additive/backward-compatible: `fromJson` defaults absent to `null`; `PublicDemoSaveCodec` gained a per-entry migration splice (`_withMigratedAssignmentProjectId`, mirroring the existing `_withMigratedInterviewRecordProjectId` pattern) plus a new identity cross-check (assignment `projectId`, when present, must agree with its own engineer's `interviewRecordProjectId` — one-directional, so a pre-Phase-7A legacy save with a real Phase 6 pass but no `projectId` on its assignment still loads).
- **Finance boundary** — untouched. `endAssignment` only re-projects `engineersAssigned`/`engineersWaiting` from the existing `assignedEngineerIds` projection (mirrors `recoverAssignment`'s own pattern); it never touches `cash`/`pendingRevenue`. An ended assignment was already excluded from `assignedEngineerIds` (month ≥ 7) the moment `nextOrderStatus` became `notOffered`, so no revenue was ever booked for it after that point — ending it changes no already-recognized figure.

## 4. Implementation

| File | Change |
|---|---|
| `lib/game/public_demo/public_demo_assignment.dart` | Added `projectId` (identity field, additive to JSON, preserved through `copyWith`, threaded through `forOrderedEngineer`). |
| `lib/game/public_demo/public_demo_workflow_state.dart` | `assignOrderedForMay`/`recoverLateYearAssignment` now thread `engineer.genuineInterviewProjectId` into new assignments; added `endAssignment(engineerId, {required int month})` — month-aware, deferred removal before month 7. |
| `lib/game/public_demo/public_demo_sales.dart` | Added `PublicDemoEngineerSales.releaseFromAssignment()` — resets `stage` to `waiting` and genuinely clears `interviewRecord` (unlike `copyWith`). |
| `lib/game/public_demo/public_demo_aggregate.dart` | Added `endAssignment(engineerId)` — re-projects `engineersAssigned`/`engineersWaiting`, mirrors `recoverAssignment`. |
| `lib/game/persistence/public_demo_save_codec.dart` | Added `_withMigratedAssignmentProjectId` legacy-save splice; added the `projectId`/`interviewRecordProjectId` identity cross-check and a structural duplicate-`engineerId` rejection in `_hasConsistentAuthorityFacts`. |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | One new button ("契約終了して営業へ戻す") wired to `endAssignment`, shown only while `nextOrderStatus == notOffered && replacementStage != ordered` — the minimum truthful UI needed to exercise the new lifecycle command; no other visual change. |

**Bug caught by the hardening pass itself:** the first `copyWith` implementation did not carry `projectId` forward, silently dropping it on every `recoverLateYearAssignment` upsert. Caught by the new focused tests before any PR review round, fixed in the same pass (`copyWith` now explicitly preserves `projectId`, matching every other identity field).

**Two P1 bugs caught by Codex's automated PR review, both confirmed and fixed in the same pass** (per Issue #207's "一括Hardening" instruction — no iterative back-and-forth):

1. **Save/reload after ending an assignment was silently rejected.** `endAssignment` reset `stage` to `waiting` but `PublicDemoEngineerSales.copyWith` cannot null an already-set `interviewRecord` (its `?? this.field` convention) — leaving stage=`waiting` with a still-present `interviewRecord`, a combination `PublicDemoSaveCodec._hasConsistentAuthorityFacts` correctly refuses to restore. Fixed with a dedicated `PublicDemoEngineerSales.releaseFromAssignment()` (constructs fresh, explicitly nulling `interviewRecord`) instead of `copyWith`. The original regression tests used `PublicDemoAggregate.fromJson` directly, which bypasses this exact check — new tests use the real `PublicDemoSaveCodec.decode`/`encode` round trip.
2. **Ending an assignment in June could lose June's already-earned revenue.** `assignedEngineerIds` is intentionally *unfiltered* before month 7 (a June `notOffered` decision is about *July's* continuation, not June's own billing — see `assignedEngineerIdsUnfiltered`'s own doc), but the first `endAssignment` removed the row immediately regardless of month, prematurely shrinking `engineersAssigned` — and therefore `closeJune`'s revenue booking — for an engineer who genuinely worked all of June. Fixed by making `endAssignment` month-aware (`{required int month}`): the row is removed immediately only when doing so cannot change `assignedEngineerIds(month)` (true for month ≥ 7, since the row is already excluded from the *filtered* set by this method's own precondition); before month 7 the engineer's stage still resets to `waiting` immediately (satisfying "begin searching during the current month"), but the row itself is left in place — inert, and safely superseded in place by a later genuine re-order via `recoverLateYearAssignment`'s existing upsert, never duplicated.

## 5. Lifecycle state machine (as implemented)

```
interview/order accepted (Phase 6 recordOrder, stage: ordered)
        │
        ▼
assignOrderedForMay / recoverLateYearAssignment
  → assignment created (projectId = genuineInterviewProjectId | null)
        │
        ▼
        ACTIVE  ──(decideOrder → accepted)──► continues next month (unchanged)
        │
        └─(decideOrder → notOffered)─┐
                                      ▼
                    ┌── replacementStage mini-cycle ──► ordered (secured; same slot, unchanged)
                    │
                    └── endAssignment ──► assignment removed, engineer.stage = waiting
                                              │
                                              ▼
                                   startSkillSheetReview → … → recordOrder
                                              │
                                              ▼
                                  recoverLateYearAssignment / assignOrderedForMay
                                   (fresh assignment, new real projectId)
```

Both `notOffered` branches (replacement mini-cycle vs. `endAssignment`) are mutually exclusive per decision — `endAssignment`'s own precondition refuses once `replacementStage == ordered`.

## 6. Persistence / migration

- `PublicDemoAssignment.projectId`: additive, nullable, `fromJson` defaults absent → `null`.
- `PublicDemoSaveCodec` legacy migration: `_withMigratedAssignmentProjectId` splices `projectId: null` into the strict-round-trip baseline for any assignment entry missing the key — a pre-Phase-7A save (including one with a genuine Phase 6 pass already recorded) still decodes.
- New identity invariant: an assignment's `projectId`, when present, must equal its own engineer's `interviewRecordProjectId` — verified in `_hasConsistentAuthorityFacts` (rejects a tampered/mismatched save) — and structurally unforgeable in live gameplay since `projectId` is only ever set from `genuineInterviewProjectId` inside the two trusted builder methods, never exposed as a public mutable parameter.
- New structural check: a duplicate assignment `engineerId` is now rejected at the raw-JSON stage too (previously only caught post-decode by `_validateForPersistence`'s `_areUnique` check).

## 7. Invariants verified (focused tests)

- Assignment start cannot double-fire (`recoverLateYearAssignment`'s existing `!assignedEngineerIds(...).contains(id)` guard, exercised via the re-entry test).
- `endAssignment` cannot double-fire — idempotent, verified by explicit `identical()` check on a second call.
- Renewal (`replacementStage == ordered`) cannot be silently discarded by `endAssignment` — explicit precondition test.
- Engineer never simultaneously `waiting` and present in `assignments` — explicit before/after assertion, plus atomicity by construction (single `_copyWith` call).
- Ended engineer returns to `available` (stage `waiting`) exactly once, and can re-enter the real Sales pipeline (`startSkillSheetReview` verified to succeed post-release) and reach exactly one new assignment for a new real project — no duplicate/stale carryover.
- `engineerId`/`projectId` identity mismatch rejected at load (SaveCodec cross-check), including the "generic pass, non-null assignment projectId" case.
- Phase 6 project identity preserved end-to-end: genuine pass → `assignOrderedForMay`/`recoverLateYearAssignment` → real `projectId` on the assignment → round-trips through save/reload.
- Save/reload stability around the end boundary (`toJson`/`fromJson` round trip immediately after `endAssignment`, verified against `_validateForPersistence`).
- Legacy save migration: a save with no `projectId` key on its assignments still loads (`projectId` defaults to `null`); a save that already carries a real `projectId` round-trips it exactly (migration never fires for a present key).
- No double month settlement / no double revenue counting: `endAssignment` never mutates `cash`/`pendingRevenue`, verified directly; the existing `assignedEngineerIds`/`PublicDemoRevenue` Finance authority is untouched (no second implementation).
- Command re-execution atomicity: every new/changed method is a pure function returning either the unchanged input (no-op) or a fully-transitioned new value — no partial-state path exists.

## 8. Finance/Month regression

Existing Finance/Month/Recovery/SaveCodec suites (all pre-existing tests under `test/game/public_demo/`) re-run unmodified except for one expected update: `public_demo_recovery_aggregate_test.dart`'s exact-JSON-key-set assertion for a recovered assignment was updated to include the new additive `projectId` key (matching this suite's own established convention for every prior additive field). All Finance/Month/Recovery/Revenue tests pass unchanged otherwise.

## 9. Tests

New focused files:
- `test/game/public_demo/public_demo_assignment_lifecycle_test.dart` (23 tests) — workflow/aggregate-level lifecycle invariants (real project identity threading, `endAssignment` preconditions/atomicity/idempotency/month-awareness, re-entry, Finance re-projection, and dedicated regressions for both Codex P1 findings above — real `PublicDemoSaveCodec` round trip, and June revenue preservation through `closeJune`).
- `test/game/public_demo/public_demo_assignment_lifecycle_save_codec_test.dart` (6 tests) — genuine round-trip, legacy migration, identity-mismatch rejection, duplicate-assignment rejection.
- `test/game/public_demo/test_support/public_demo_sales_test_helpers.dart` — added `recordTestProjectInterviewPass` (project-bound counterpart to the existing `recordTestClientInterviewPass`).
- `test/game/public_demo/public_demo_recovery_aggregate_test.dart` — updated one exact-key-set assertion for the new additive field.

## 10. CI status (this session)

- `flutter analyze`: **0 issues** (whole repo).
- `flutter test test/game/public_demo/ --concurrency=6`: **720/720 passed.**
- `flutter test --concurrency=6` (full suite): **2030/2030 passed.**
- `git diff --check`: clean (no whitespace errors).

No repository CI workflow run was triggered from this session beyond the above local runs (same Flutter stable toolchain the repo pins via `.metadata`/`pubspec.yaml`).

## 11. Unresolved blockers

None.

## 12. Known limitations

- The pre-existing `replacementStage` mini-cycle (finding a replacement client for the *same* assignment slot) is intentionally unchanged — it still uses the pre-Phase-6 abstract capability-based pass/fail rolls, not a real newly-matched `Project`. Phase 7A's real-project-identity wiring applies to the *initial* Phase 6 → assignment handoff and to genuine re-orders reached via `endAssignment` → the full Sales pipeline, per the Issue's explicit scope (no Matching/Interview scoring changes).
- `endAssignment`'s new UI button surfaces only the minimum truthful status/decision affordance (a single button, existing widget style) — no new visual treatment, consistent with "no Visual Complete 2."
- CareerHistory/SkillSheet growth completion remains entirely out of scope (Phase 7B), as instructed.

## 13. Phase 7B handoff

- `PublicDemoAssignment.projectId` and `PublicDemoWorkflowState.endAssignment` are the two new stable hooks Phase 7B (CareerHistory/SkillSheet growth) can build on: a CareerHistory writer can react to `endAssignment`'s transition (a genuine contract conclusion) and to the real `projectId` now available on every Phase-6-originated assignment, without needing to re-derive project identity from `projectName` text.
- No CareerHistory writer or SkillSheet growth logic was added in this Issue, per the explicit prohibition.

## 14. Files changed (this Issue)

```
 lib/game/persistence/public_demo_save_codec.dart                       |  79 ++++++
 lib/game/public_demo/public_demo_aggregate.dart                        |  31 +++
 lib/game/public_demo/public_demo_assignment.dart                       |  41 +++
 lib/game/public_demo/public_demo_workflow_state.dart                   | 140 ++++++++---
 lib/ui/public_demo/public_demo_01_placeholder_screen.dart               |  25 ++
 test/game/public_demo/public_demo_recovery_aggregate_test.dart          |   6 +
 test/game/public_demo/test_support/public_demo_sales_test_helpers.dart  |  24 ++
 test/game/public_demo/public_demo_assignment_lifecycle_test.dart        | (new)
 test/game/public_demo/public_demo_assignment_lifecycle_save_codec_test.dart | (new)
 docs/reports/SES_CORE-GAMEPLAY_Phase7A_Assignment-Lifecycle_Result.md   | (new, this report)
```
