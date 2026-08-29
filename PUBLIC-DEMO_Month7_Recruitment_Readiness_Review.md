# PUBLIC-DEMO Month-7 Recruitment Dead-End: Root Cause & Implementation Readiness Review

**Reviewed SHA:** `4875c7257bfa903ac212eac0991283a1b6254840` (origin/main)  
**Date:** 2026-08-29  
**Mode:** Review only — no code changes, no commits, no tests modified.

---

## 1. Reproduction Result

**CONFIRMED REPRODUCIBLE on current main.**

In month 7 (July) of Public Demo 0.1:

1. The `_RecruitmentMediaCard` is rendered and its button is enabled.
2. Tapping it opens the `_RecruitmentMediaSheet` (free or engineer media).
3. Selecting a medium calls `_openRecruitmentMedia` → `_game.recruit(selected)`.
4. Cash is deducted (¥0 for free, ¥100,000 for engineer medium).
5. Applicants are generated and persisted into `workflow.applicants`.
6. The `ac(i)` applicant cards — which render the resume-review, interview, salary-offer, and pre-entry pipeline — are **never rendered in month 7** (they appear only in the `if (s.month == 5)` block).
7. No subsequent month (8–15) renders `ac(i)` either.
8. The applicants exist in domain state but have no UI path to be reviewed, interviewed, offered a salary, or hired.
9. Advancing the month does not discard them — they persist in the workflow throughout the rest of the fiscal year as stranded, inaccessible state.

---

## 2. Exact Root Cause

### Architecture

The Public Demo screen (`public_demo_01_placeholder_screen.dart`) uses a month-branched `build` method where each calendar month renders a specific set of widgets:

| Month | Rendered widgets |
|-------|-----------------|
| 4 (April) | `ec(i)` (engineer sales cards), close button |
| 5 (May) | `_RecruitmentMediaCard`, `ac(i)` (applicant pipeline cards), close button |
| 6 (June) | Employee condition cards, engineer sales cards (filtered), assignment cards, close button |
| 7 (July) | `_RecruitmentMediaCard`, assignment results, summer bonus decision, close button |
| 8–14 (Aug–Feb) | Month label + close button only |
| 15 (March) | Month label + fiscal year close button |

The **applicant pipeline** (`ac(i)`) — which renders the buttons for 経歴書確認, 採用面談, 合格・給与提示, and the entire pre-entry sales flow — is rendered **only in month 5**.

Month 7 renders the `_RecruitmentMediaCard` (which allows purchase), but **does not render `ac(i)`**. No month after 5 renders `ac(i)`.

### Domain layer

`_normalizedRecruitmentMediaMonth` (in `public_demo_state.dart`) accepts months 4–8 as valid:

```dart
static int? _normalizedRecruitmentMediaMonth(int? month) =>
    month != null && month >= 4 && month <= 8 ? month : null;
```

`canUseRecruitmentMediaInMonth(int month)` returns `true` for month 7 as long as recruitment hasn't been used that month yet. The `recruit()` method on `PublicDemoAggregate` checks `canUseRecruitmentMediaInMonth`, charges cash, generates applicants, and commits both atomically — all without checking whether the current month's UI can process the result.

### Root cause statement

**The domain layer allows recruitment in month 7, and the UI renders the recruitment-media purchase card in month 7, but the UI does not render the applicant-processing pipeline (`ac(i)`) in month 7 or any later month.** This creates a structural dead end: money is spent and applicants are generated, but no subsequent user action can advance those applicants through the hiring flow.

### Historical context

This gap was **known and documented** at the time of the 12MONTH-3 fix (commit `199e2a3`, PR #60):

> "Month 7's identical, pre-existing gap is left untouched (out of scope for this fix; recorded as a follow-up)."

The HOME-RUNTIME-2C fix (commit `75b1401`) addressed the recommendation layer only — preventing the Recommended Action slot from suggesting July's recruitment media — but explicitly left the card, button, and domain command untouched:

> "July's card, its button and its command are untouched: a player who wants it can still use it exactly as before. Whether that card should exist in July at all, or whether July should render the applicant pipeline, is a pre-existing product question."

---

## 3. User-Visible Behavior

### What the player experiences

1. In July, a "候補者を追加募集" card appears with a live "求人媒体を選ぶ" button.
2. Tapping it shows a sheet with "無料求人" (¥0, 1 applicant) and "エンジニア求人" (¥100,000, 2 applicants).
3. Selecting either deducts cash and shows a snackbar "応募者N名を追加しました。"
4. **No applicant card appears.** The newly generated applicants have no visible UI anywhere for the rest of the game.
5. The Recommended Action on HOME never suggests this action (fixed by `75b1401`), but the card is plainly visible to anyone scrolling the July view.

### Classification

**Category C: Paid dead end.**

- Cash is consumed (up to ¥100,000).
- Applicants are generated but structurally unadvanceable.
- No error message, warning, or indication that the action is futile.
- The player cannot recover the spent cash.
- The player can still advance through the fiscal year — progression is not blocked.
- There is no save or data integrity issue — the applicants are properly persisted, just inaccessible.
- The free medium (¥0) creates the same stranded-applicant state but costs nothing.

---

## 4. Transaction/Resource Impact

| Question | Answer |
|----------|--------|
| Can the player purchase recruitment media in month 7? | **Yes.** `canUseRecruitmentMediaInMonth(7)` returns `true`. |
| Is cash deducted? | **Yes.** ¥100,000 for engineer medium, ¥0 for free medium. |
| Is another resource consumed? | **Yes.** The once-per-month recruitment media usage is marked, preventing a second use. |
| Are applicants generated? | **Yes.** 1 or 2 applicants are generated and committed to workflow state. |
| Are applicants persisted? | **Yes.** In `workflow.applicants` via `withGeneratedApplicants`. |
| Is there a UI path to view them? | **No.** `ac(i)` is only rendered when `s.month == 5`. |
| Can the player interview them? | **No.** No UI exists to advance them past `PublicDemoApplicantStage.applied`. |
| Can they be hired? | **No.** |
| Can the player recover without reset? | **No.** Cash is permanently spent. The applicants remain stranded. |
| Does advancing the month discard them? | **No.** They persist as dead state through fiscal year end. |

---

## 5. Authority Map

| Authority | Current owner | Notes |
|-----------|--------------|-------|
| Whether recruitment is available | `_normalizedRecruitmentMediaMonth` on `PublicDemoState` | Returns non-null for months 4–8. Domain authority. |
| Media purchase eligibility | `canUseRecruitmentMediaInMonth` on `PublicDemoState` | Checks normalization + not-already-used-this-month. Domain authority. |
| Recruitment cost | `PublicDemoRecruitmentMedium.cost` | Enum constant. Domain authority. |
| Recruitment cash-deduction + applicant-generation | `PublicDemoAggregate.recruit` → `PublicDemoRecruitmentCalculation.execute` | Atomic aggregate command. Domain authority. |
| Financial restriction block | `PublicDemoState.isFinanciallyRestricted` | Prevents recruitment during shortage. Domain authority. |
| Applicant storage | `PublicDemoWorkflowState.withGeneratedApplicants` | Appends to workflow. Domain authority. |
| Applicant UI visibility (pipeline) | `ac(i)` in `_S.build` | Only rendered when `s.month == 5`. **UI authority.** |
| Recruitment card UI visibility | `_RecruitmentMediaCard` in `_S.build` | Rendered when `s.month == 5` or `s.month == 7`. **UI authority.** |
| Recommendation eligibility | `_addRecruitmentMediaCandidate` | Called only from month-5 branch. Presentation authority. |
| Interview eligibility | `PublicDemoAggregate.completeInterview` | Requires sales-slot proof. Domain authority. |
| Hiring | `PublicDemoApplicant.join` | Requires binding offer + fiscal-close match. Domain authority. |
| Month progression | `advanceToJuly` / `advanceToAugust` / `advanceToNextOrdinaryMonth` | Guards on current month. Domain authority. |

### Authority disagreement

**The domain layer (`canUseRecruitmentMediaInMonth`) and the recruitment card UI both say "yes, recruit in month 7", but the applicant-processing UI says "no pipeline available in month 7."** There is no domain guard, UI warning, or presentation-layer check that reconciles these. The Recommended Action layer now correctly excludes month 7, but that is a recommendation decision — the card and command remain fully functional.

---

## 6. Month 6/7/8 Comparison

| Aspect | Month 6 | Month 7 | Month 8 |
|--------|---------|---------|---------|
| `_RecruitmentMediaCard` rendered | No | **Yes** | No |
| `ac(i)` (applicant pipeline) rendered | No | No | No |
| `canUseRecruitmentMediaInMonth` | `true` | **`true`** | `true` |
| Recruitment card + pipeline together | No | **Card only** | Neither |
| Recommended Action can suggest it | No | **No** (fix `75b1401`) | N/A |
| Cash at risk | None from recruitment | **Up to ¥100,000** | None from recruitment |
| Month-specific content | Condition cards, assignment cards | Summer bonus, assignment results | Salary reflection |

Month 5 is the only month that renders both the card and the pipeline. Month 7 is the only month that renders the card without the pipeline.

---

## 7. Relevant Existing Tests

### Tests that cover recruitment domain (months 4–8)

- `test/game/public_demo/public_demo_recruitment_media_state_test.dart` — Domain-level `canUseRecruitmentMediaInMonth` and `markRecruitmentMediaUsed` for valid/invalid months.
- `test/game/public_demo/public_demo_recruitment_workflow_transaction_test.dart` — Aggregate recruitment atomicity; includes a test "July paid media is charged before bonus closing without double charge" that **explicitly constructs a month-7 state and verifies cash is deducted** (confirming the paid purchase succeeds in the domain).
- Same file, group "recruitment media in months without a processing UI (P1-2)" — Tests that months 9–15 reject recruitment. **Test D explicitly asserts months 4–8 remain valid,** pinning the current range.

### Tests that cover month 7 UI

- `test/ui/public_demo/public_demo_01_playthrough_test.dart` — "Public Demo can be operated from April through July": advances through July, verifies the recruitment media card is present, verifies summer bonus. **Does not attempt to use recruitment media in July.**
- `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart` — "July's 求人媒体 is never recommended": verifies the card is rendered and enabled in July, but HOME never recommends it. **This is the regression test for `75b1401`, not a test for the dead-end itself.**

### Tests that cover months 6 and 8

- `test/ui/public_demo/public_demo_01_fiscal_year_progression_test.dart` — Tests progression through months 8–15.
- `test/ui/public_demo/public_demo_01_assignment_carryforward_test.dart` — Tests assignment carry-forward through July/August.

### Missing regression test (the dead-end scenario itself)

**No existing test reproduces the dead end:**

No test currently:
1. Starts in month 7 (or advances to month 7).
2. Purchases recruitment media (engineer medium, ¥100,000).
3. Verifies cash is deducted.
4. Verifies applicants are generated and persisted.
5. Verifies no `ac(i)` cards are rendered (no "経歴書確認" or "採用面談" buttons).
6. Verifies advancing to month 8 does not surface those applicants.

---

## 8. Missing Test Scenario (for the implementation PR)

```
// Scenario: Month-7 recruitment media purchase is a paid dead end
//
// GIVEN: the game is in month 7 with sufficient cash
// WHEN: the player purchases the engineer recruitment medium (¥100,000)
// THEN:
//   - Cash decreases by ¥100,000
//   - workflow.applicants grows by 2
//   - The new applicants have stage == PublicDemoApplicantStage.applied
//   - No ac(i) card is rendered (find.text('経歴書確認') == findsNothing)
//   - No interview button is rendered (find.text('採用面談') == findsNothing)
// WHEN: the player advances to month 8
// THEN:
//   - The applicants still exist in workflow.applicants
//   - No ac(i) card is rendered
//   - The applicants are stranded for the rest of the fiscal year
```

The implementation PR should transform this scenario from a reproduction test into a fix validation test (i.e., after the fix, the scenario should either prevent the purchase or make the applicants processable, depending on which option is chosen).

---

## 9. Historical Intent

Based on repository evidence:

1. **12MONTH-3 (PR #60, commit `199e2a3`):** The fiscal year extension widened `_normalizedRecruitmentMediaMonth` from 4–8 to 4–15. The accompanying P1-2 fix reverted to 4–8 but explicitly said: *"month 7's identical, pre-existing gap is an intentional follow-up, not something this fix changes."*

2. **HOME-RUNTIME-2C (commit `75b1401`):** Addressed only the recommendation layer — prevented HOME from directing the player to the dead end. The commit message states the underlying question is *"a pre-existing product question, outside HOME-RUNTIME-2C."*

3. **The `_RecruitmentMediaCard` presence in month 7** predates both fixes. It was part of the original July rendering, likely because month 7 was the next natural month to show recruitment alongside the summer bonus decision. The corresponding `ac(i)` rendering was never extended beyond month 5.

**Conclusion:** Month-7 recruitment-media availability is **accidentally exposed legacy behavior**, not intentionally supported functionality. The card was included in the month-7 branch of `build` alongside the summer bonus when July was originally built, but the applicant-processing pipeline was never extended to match. This became more visible when the fiscal-year extension made it clear that no later month would ever pick up those applicants.

---

## 10. Fix Options

### OPTION A: Prevent recruitment-media purchase in month 7

**Approach:** Narrow `_normalizedRecruitmentMediaMonth` from `month >= 4 && month <= 8` to `month >= 4 && month <= 5`, OR remove the `_RecruitmentMediaCard` from the month-7 `build` branch, OR both.

| Aspect | Detail |
|--------|--------|
| Files affected | `public_demo_state.dart` (domain range), `public_demo_01_placeholder_screen.dart` (UI card removal) |
| Gameplay effect | Player cannot use recruitment media in months 6–8. Months 6 and 8 are already not rendering the card, so no visible change there. Month 7 loses the card. |
| State/save impact | Existing saves with `recruitmentMediumUsedMonth: 7` would have that field normalized to `null` on deserialization — safe, no migration needed. |
| Regression risk | Low. Test D in `public_demo_recruitment_workflow_transaction_test.dart` asserts months 4–8 are valid — this test must be updated. The July "charged before bonus" test also uses month 7 — must be updated or removed. |
| Test burden | Update 2 existing tests, add 1 regression test confirming month-7 card no longer appears. |
| Scope change | **Removes a capability** that was partially present. Conservative choice. |

### OPTION B: Render the applicant pipeline in month 7

**Approach:** Add `for (var i = 0; i < workflow.applicants.length; i++) ac(i)` to the month-7 `build` branch, and call `_addRecruitmentMediaCandidate(add)` from the month-7 candidate emission branch (already removed by `75b1401`).

| Aspect | Detail |
|--------|--------|
| Files affected | `public_demo_01_placeholder_screen.dart` only (add `ac(i)` rendering in month 7, restore recommendation candidate) |
| Gameplay effect | Player can hire in July. But applicants who reach the later stages (pre-entry sales, June order) would require month-6-specific UI flows (assignment acceptance, condition cards) that month 7 does not render — this creates a new, deeper dead end at a later pipeline stage. |
| State/save impact | None — only UI rendering changes. |
| Regression risk | **High.** The applicant pipeline was designed around month 5 → join in June → condition in June/July. A July hire would need a different join/condition timeline, touching `advanceToAugust`, payroll, revenue, and growth — a significant redesign. |
| Test burden | High — extensive new tests for the July hiring path, salary negotiation in July, join timing, payroll impact, etc. |
| Scope change | **Broadens Public Demo gameplay** significantly. Not a minimal fix. |

### OPTION C: Normalize month 7 to month 5 for recruitment purposes

**Approach:** Change `_normalizedRecruitmentMediaMonth` to map month 7 → month 5, so a month-7 purchase is treated as if it happened in month 5 in the domain.

| Aspect | Detail |
|--------|--------|
| Files affected | `public_demo_state.dart` (normalization logic) |
| Gameplay effect | Confusing: the domain would think recruitment happened in May while the UI shows July. This would not fix the UI problem — `ac(i)` is still only rendered when `s.month == 5`, and the month is 7. |
| State/save impact | Would break the once-per-month usage guard, potentially allowing double use (month 5 real + month 7 "normalized to 5"). |
| Regression risk | **Very high.** Semantic confusion between display month and domain month. |
| Test burden | High, with many edge cases around the normalization. |
| Scope change | Adds complexity without solving the UI rendering gap. **Not viable.** |

### OPTION D: Remove only the `_RecruitmentMediaCard` from month 7's `build` branch

**Approach:** Delete the `_RecruitmentMediaCard(state: s, onPressed: _openRecruitmentMedia)` widget from the `if (s.month == 7)` block in `build`. Leave the domain range (4–8) unchanged — the domain still *allows* month-7 recruitment, but the UI no longer presents the entry point.

| Aspect | Detail |
|--------|--------|
| Files affected | `public_demo_01_placeholder_screen.dart` only (1 widget removal, ~3 lines) |
| Gameplay effect | Month 7 no longer shows a recruitment card. The domain still allows it (for future expansion), but no UI triggers it. |
| State/save impact | None — domain is unchanged. Existing saves unaffected. |
| Regression risk | **Very low.** No domain change. No recommendation change (already excluded). Only the visual card is removed. |
| Test burden | Minimal — update 1 test (`public_demo_01_playthrough_test.dart` if it asserts the card's presence in July) and add 1 regression test asserting no recruitment card in month 7. The domain tests (months 4–8 valid range) remain unchanged. |
| Scope change | **Minimal.** Removes the visual entry point to the dead end. Domain preserves the month-7 range for future product decisions. |

---

## 11. Recommendation

**OPTION D: Remove the `_RecruitmentMediaCard` from month 7's `build` branch.**

Rationale:

1. **Smallest possible change** — a single widget removal in the UI layer.
2. **No domain change** — preserves `_normalizedRecruitmentMediaMonth`'s 4–8 range, which is tested and may be needed if month 7 later gets a full applicant pipeline.
3. **No recommendation change needed** — `75b1401` already excluded month 7 from recommendations.
4. **No save/state/migration impact.**
5. **No interaction with EVENT-UI Phase 2** — the change is in the month-7 `build` branch, which is in `public_demo_01_placeholder_screen.dart`, not in the presentation/events files.
6. **Consistent with the architecture** — month 6 and months 8–14 also don't render the recruitment card (they're outside the month-5 recruitment window). Month 7 should be the same.
7. **Reversible** — if a product decision later adds a July applicant pipeline, the card can be restored alongside `ac(i)`.

If the product direction later decides to also narrow the domain range (Option A), that's a separate, additive change.

---

## 12. Exact Files Allowed to Change (for the implementation PR)

| File | Change |
|------|--------|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | Remove `_RecruitmentMediaCard` from the `if (s.month == 7)` block in `build`. |
| `test/ui/public_demo/public_demo_01_playthrough_test.dart` | Update if it asserts the card's presence in July. |
| `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart` | Update the July test that asserts the card is "rendered and enabled" — after removal, the card won't be rendered. The recommended-action assertion (never recommends it) should still hold trivially. |
| New test file or section | Add a regression test confirming no recruitment card is rendered in month 7, and that purchasing via the domain in month 7 still works (domain range unchanged). |

---

## 13. Exact Files Forbidden to Change

- `lib/presentation/events/**` (EVENT-UI Phase 2 parallel)
- `lib/ui/widgets/founding_dialogs.dart` (parallel safety)
- `lib/ui/widgets/beginner_mode_dialogs.dart` (parallel safety)
- `lib/ui/widgets/game_event_modal.dart` (parallel safety)
- `lib/game/public_demo/public_demo_state.dart` (no domain change in Option D)
- `lib/game/public_demo/public_demo_aggregate.dart` (no domain change)
- `lib/game/public_demo/public_demo_recruitment_medium.dart` (no domain change)
- `lib/game/public_demo/public_demo_recruitment.dart` (no domain change)
- `lib/game/public_demo/public_demo_workflow_state.dart` (no domain change)
- `lib/presentation/home/models/home_recommended_action.dart` (no recommendation change needed)
- Any PayrollEngine, FinanceEngine, or save schema files
- Any E2E/workflow/retry/timeout files

---

## 14. Parallel Conflict Assessment

**No conflict with EVENT-UI Phase 2.**

- EVENT-UI Phase 2 operates on `lib/presentation/events/**` and related widget files (`founding_dialogs.dart`, `beginner_mode_dialogs.dart`, `game_event_modal.dart`).
- Option D changes only the `if (s.month == 7)` block in `public_demo_01_placeholder_screen.dart`, which is a widget removal deep inside a month-specific conditional — nowhere near the event presentation layer.
- No shared state, no shared authority, no shared test fixtures.

---

## 15. Recommended Implementer

**Codex.**

Rationale:
- The fix is a single widget removal (3 lines deleted from `build`) plus test updates.
- No domain logic changes, no architectural decisions, no design ambiguity.
- The test updates are straightforward: adjust assertion counts and add a focused regression test.
- The fix can be validated by running the existing test suite + the new regression test.
- No interactive debugging, no multi-step reasoning, no concurrent-session coordination required.

---

## 16. Severity

**P2: Confusing/incomplete behavior without meaningful progression loss.**

Justification:
- The free medium costs ¥0, so the dead end can be hit without cash loss.
- The engineer medium costs ¥100,000, which is not insignificant but is not progression-ending (starting cash is ¥3,000,000).
- Progression is never blocked — the player can always advance to month 8 and beyond.
- No save corruption, no data integrity issue.
- The Recommended Action already steers the player away from this action (`75b1401`).
- A player who manually uses the card is spending cash on a clearly futile action (no visible result), but there is no warning — the failure is silent.
- This is worse than P3 (not just a test gap) because real cash can be lost, but does not reach P1 because it requires deliberate player action against an unguided path and does not block progression.

---

## 17. Final Verdict

### **FIX READY**

- Root cause identified and confirmed reproducible on current main (`4875c72`).
- Minimal fix (Option D) identified: remove `_RecruitmentMediaCard` from month 7's `build` block.
- 1 file to change, 2 test files to update, 1 regression test to add.
- No domain, presentation, save, or architectural changes.
- No parallel conflict with EVENT-UI Phase 2.
- Recommended implementer: **Codex**.
- Severity: **P2**.
