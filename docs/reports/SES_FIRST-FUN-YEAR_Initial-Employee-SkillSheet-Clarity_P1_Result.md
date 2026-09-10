# SES First Fun Year — Initial Employee / SkillSheet Gate Clarity (Package B, P1) — Implementation Result

Status: **Implemented**

Issue: [#231](https://github.com/perusonao/smile_enjoy_story/issues/231) — FIRST-FUN-YEAR P1: Initial Employee / SkillSheet Gate Clarity

BASE SHA: `160b78ab972b00d787dc827620c23e1335144728` (origin/main at task start — matches the SHA Issue #231 itself names; `origin/main` had not advanced past it, confirmed via `git merge-base HEAD origin/main`).

Branch: `claude/ses-first-fun-year-package-b-14y2qi`

FINAL HEAD SHA: `2ff324e819d849347fd8558af65d0aa39e7ef388` (the commit carrying all code/test/report changes below; the PR may carry one small additional docs-only commit filling in the PR URL itself)

## 1. Goal

First Fun Year Human Replay #225 and Package A (Opening Context, Issue #229 / PR #230, already merged to `main`) left a specific comprehension gap for a brand-new April player: which of the two founding engineers (佐藤健／鈴木葵) can start selling right now, why the other one cannot, why a SkillSheet exists at all, and what to do next. Package B ("Package B以外を混ぜない") addresses exactly this — a focused, authority-driven **clarity** fix, not a new feature, not an Employee/Sales/Recruitment/Accounting overhaul, and not a balance change.

## 2. Fresh Audit (required before any implementation)

Traced against the BASE SHA above — the same commit Issue #231 names, confirmed current at task start.

| # | Question | Authority found |
|---|---|---|
| 1 | Initial employee actual-capability authority | `PublicDemoEngineerRuntime.actualCapability` (`lib/game/public_demo/public_demo_engineer_runtime.dart`) — `languageSkills[primaryLanguage]?.actualSkill`. Founding data (`publicDemoInitialEngineerRuntimes`): 佐藤健 (`eng-01`, Java) = **78**, 鈴木葵 (`eng-02`, JavaScript) = **52** — exactly the reference values Issue #231 names. |
| 2 | Sales-eligibility threshold authority | `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement` = **60** (single `static const int`), and `isReadyForFieldSales => actualCapability >= fieldSalesCapabilityRequirement`. The UI already read this via two existing pass-through helpers, `capabilityFor(id)`/`readyForFieldSales(id)` (`public_demo_01_placeholder_screen.dart`), themselves reading `PublicDemoState.runtimeForOrNull(id)` — no UI-local duplicate of either number existed before this change, and none was added. |
| 3 | Training-effect authority | `PublicDemoGrowthEngine` (`public_demo_growth_engine.dart`): internal training uses a `2.0` base multiplier × a `growthPotential`-derived multiplier (`0.70 + growthPotential * 0.15`) × an optional fast-learner multiplier, applied once per month-end close (`PublicDemoAggregate.closeOrdinaryMonth`/`closeJune`/`closeJuly` → `_closeGrowth`) for an engineer with `PublicDemoState.trainingSelections[id]` set via `selectInternalTraining`. Untouched by this change; exercised (not modified) by a new regression test (§5). |
| 4 | Employee/HOME/Sales/SkillSheet navigation | 社員 tab (`_buildEmployeesTab`) is the four-section Employee UI Phase 1 layout: 1) 社員一覧・現在状態 (`_employeeRosterSection`, new focus of this fix), 2) 今やるべき社員アクション (`ec(i)` per-engineer action card, including the SkillSheet-confirm/lock-banner logic), 3) 参画中案件, 4) 成長・スキルシート・研修. HOME shows the same engineers via its own, separately-maintained `_officeStageStatusFor`/Office Stage strip (HOME Freeze — deliberately a different method from anything this fix touches). 営業 (Sales) tab reads `workflow.engineers`/`applicants` directly; a `PublicDemoAdviceActionType.confirmSkillSheet` cash-advisory candidate (ひより Navigator) also targets the same `_openSkillSheetReview` entry point as `ec(i)`, for a still-`waiting` engineer during a forecasted cash shortage. |
| 5 | SkillSheet-confirm hard-gate substance | `PublicDemoWorkflowState.startSkillSheetReview` (`waiting → skillSheet`) then `beginSelling` (`skillSheet/partnerInterviewFailed/clientInterviewFailed → selling`) — a real domain precondition, not merely a UI flag: `_beginSelling`'s production caller only runs once `e.stage == PublicDemoSalesStage.skillSheet`. The UI (`_openSkillSheetReview`) opens `PublicDemoSkillSheetSheet`, and only on **explicit confirm** (`内容を確認`, `Navigator.pop(context, true)`) commits `startSkillSheetReview`; Back/dismiss leaves the workflow untouched. The sheet itself already states its own purpose inline ("取引先へ提示する営業用プロフィールです。内容を確認してから営業開始へ進みます。"). |
| 6 | Public Demo SkillSheet's current role | `PublicDemoSkillSheetSheet`'s own class doc is explicit: "Purely presentational... never mutates or recomputes" either `PublicDemoEngineerSales`, `PublicDemoEngineerRuntime`, or `PublicDemoAssignment`. It has **no** edit affordance and **no** matching/proposal authority for this pre-selling gate — CORE-GAMEPLAY Phase 5 (Matching)'s own SkillSheet reuse is a separate, later-pipeline concern (`availableEngineersForMatching`), unrelated to the `waiting`-stage gate this issue asks about. |
| 7 | `実力` label origin | Player-facing copy inside `ec(i)`'s lock banner (`public_demo_01_placeholder_screen.dart`) — `'営業開始には実力 $fieldSalesRequirement 以上が必要です（現在 $capability）。'` — where both `$fieldSalesRequirement`/`$capability` are the same authority variables from #2, never separately hardcoded numbers. No other player-facing screen redefines or duplicates this term. |

### Gate decision: **kept, with evidence** (not weakened/removed)

Issue #231 explicitly allows either outcome ("不要なhard gateが残らない、または維持理由がFresh evidenceで説明されている") and explicitly forbids guessing ("推測でgateを削除せず、必ずFresh trace後に決めること"). Fresh Audit found the SkillSheet-confirm step read-only (per #6), which is the condition the issue names as grounds to weaken/remove the gate — but it also found the gate is **not free-floating UI friction with no purpose**, and it is **wired into authorities outside this issue's scope**:

* The sheet already states, inline, why the player is looking at it (the exact "なぜスキルシートを見るのか" the issue's Goal asks for) — it is the one moment Public Demo frames the SkillSheet as "the sales profile presented to a client," not a generic info screen.
* The two-step pipeline (`waiting → skillSheet → selling`) is a named row in `home_recommended_action.dart`'s own documented design-authority table (`employeeSkillSheetReview`/`employeeBeginSelling`, P2 band, sourced from `SES_HOME-RUNTIME-2_Integration_Design.md`) and in `PublicDemoCashAdviceSelector`'s `confirmSkillSheet` action type (ひより Navigator cash-shortage advice). Merging or removing the `skillSheet` stage would require also changing HOME's Recommended Action authority and the Cash Advisor — both explicitly out of this Package B's scope (**HOME Freeze**, no Employee/Sales full overhaul).
* The actual friction cost is one tap ("スキルシート確認") plus one confirm ("内容を確認") — not a form, not repeatable, not blocking any other action.

Given this, removing the gate would trade a real (if small) architecture change touching HOME/Sales authorities for no measurable comprehension gain — the friction was never the top of Issue #231's own Goal list; the roster's silence about *which* engineer is ready was. Package B instead spends its whole budget closing that specific, Fresh-Audit-confirmed gap (§3), leaving Sales/HOME/Recruitment/SkillSheet-gate authority completely untouched.

## 3. What changed

**The actual comprehension gap found**: `_currentEmployeeStatusLabel`/`engineerStatus` labeled *every* still-`waiting` engineer identically, `'待機'` — so Section 1 (社員一覧・現在状態), the very first thing an April player sees, could not distinguish 佐藤健 (already field-sales ready) from 鈴木葵 (not ready) without scrolling down to Section 2's per-engineer action card. This is the literal first two bullets of Issue #231's own Goal.

Two files changed in `lib/`, both presentation-only, both reading existing authority verbatim — no new persisted field, no new domain rule, no UI-local threshold/capability duplicate:

* **`lib/ui/public_demo/public_demo_employee_visual.dart`**: added one new `PublicDemoEmployeeStatusTone` value, `readyForSales` (a distinct color from `assigned`/`training`/`waiting`), and broadened `training`'s doc comment to also cover "still-waiting and below the field-sales threshold" (it already had the right color semantics — attention/needs-action — for this case, so no new color was needed there).
* **`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`**:
  * `_currentEmployeeStatusLabel`: for `stage == waiting`, returns `'営業可能'` or `'研修が必要'` from the existing `readyForFieldSales(id)` boolean (no new eligibility check — the exact same call `ec(i)`'s own lock banner already made). Every other stage's label is untouched (still `engineerStatus(engineer)` verbatim) — `engineerStatus` itself, `_officeStageStatusFor` (HOME's own status function), and the SkillSheet sheet's `statusLabel` parameter are **not** touched, so HOME's Office Stage strip and the SkillSheet sheet keep reading the raw pipeline stage exactly as before (HOME Freeze).
  * `_employeeStatusTone`: mirrors the same `waiting`-stage split, choosing `readyForSales`/`training` from the same `readyForFieldSales` fact — never a second, independently-derived readiness check.
  * `_employeeRosterCard`: for a still-`waiting`, not-yet-ready engineer only, adds one small caption line reusing the exact same authority `ec(i)`'s lock banner already reads (`PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement`, `capabilityFor(id)`) — `'営業には実力60以上が必要（現在52）'` for 鈴木葵 today — so the *reason* is visible in Section 1 itself, without opening the SkillSheet or scrolling to Section 2. A ready engineer gets no extra caption (the badge alone is unambiguous).

No change to `PublicDemoWorkflowState`, `PublicDemoSalesStage`, `PublicDemoEngineerRuntime`, `PublicDemoGrowthEngine`, `PublicDemoCashAdviceSelector`, `home_recommended_action.dart`, HOME (`lib/presentation/home/**`), Recruitment, Finance, or the save schema (`PublicDemoSaveCodec.schemaVersion` stays `1`).

### Explicitly not done (per Issue #231's own Out-of-Scope list)

SkillSheet editing, Employee-tab full redesign, recruitment-logic changes, Sales/Accounting overhaul, age/gender fields, balance changes, Monthly Management Report, any large new feature, and any HOME layout change.

## 4. Tests

Flutter 3.44.8 (stable) — the exact version this repository's own CI (`public-demo-validation.yml`) pins — was installed for this session (none was preinstalled in this remote environment) so every check below is a real, executed result, not a static read.

* `flutter analyze` (whole project): **No issues found.**
* Updated existing tests (3 assertions, all previously encoded the "every waiting engineer reads 待機" assumption this fix deliberately changes):
  * `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` — April fresh-start roster assertion now checks 佐藤=`営業可能`/鈴木=`研修が必要` instead of both `待機`; the August `oneAssignedOneWaitingAtMonth` fixture's still-waiting 鈴木 now expects `研修が必要`.
  * `test/ui/public_demo/public_demo_employee_visual_complete_test.dart` — the badge-tone assertion for the same August fixture now expects label `研修が必要` / tone `.training` for the still-not-ready waiting engineer.
  * `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` — test 4 ("legacy KPI row is gone, not duplicated") no longer asserts `待機` appears twice on 社員 after switching tabs (it appears zero times now); asserts `営業可能`/`研修が必要` each appear once instead. HOME's own three `待機` occurrences (KPI tile + two Office Stage cards) are unaffected and still asserted unchanged.
  * `test/ui/public_demo/public_demo_01_success_playthrough_test.dart` — the "no raw morale/trust number (60/65) leaks from 社員コンディション" assertion is now scoped to that card's own `Card` ancestor (via `find.ancestor`/`find.descendant`), since 鈴木葵 is never trained through in that fixture and now truthfully shows an unrelated, intentional "60" in her own roster reason caption. The condition-card assertion's real intent (no raw score leaks there) is preserved and still passing.
* New focused test file, `test/ui/public_demo/public_demo_issue231_employee_skillsheet_clarity_test.dart` (3 tests):
  1. Fresh April state: 佐藤 reads `営業可能` with no reason caption; 鈴木 reads `研修が必要` with the reason caption stating the *exact* authoritative threshold/capability text (built from `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement`/`actualCapability`, never a re-hardcoded literal in the test either).
  2. Genuine internal training (`selectInternalTraining` + `closeOrdinaryMonth`, the same production commands the training card and month-close button use) run in a loop until 鈴木's `isReadyForFieldSales` flips — proving the roster label tracks `PublicDemoGrowthEngine` authority live, not a one-time April snapshot. The label flips from `研修が必要` to `営業可能` as soon as it does, with no other production code touched to make this pass.
  3. `PublicDemoSaveCodec` encode/decode round trip on the fresh-April aggregate: both engineers' `isReadyForFieldSales` fact survives identically — no UI-local state exists to lose, and none was added.

Full targeted runs (all green, exit code 0):

| Suite | Result |
|---|---|
| `flutter analyze` (whole project) | No issues found |
| `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` + `public_demo_employee_visual_complete_test.dart` | 35/35 passed |
| `test/ui/public_demo/public_demo_issue231_employee_skillsheet_clarity_test.dart` (new) | 3/3 passed |
| `test/ui/public_demo/public_demo_01_success_playthrough_test.dart` + `public_demo_01_home_consolidation_test.dart` + `public_demo_01_playthrough_test.dart` (the two CI-gated playthrough files, per `public-demo-validation.yml`) | 35/35 passed |
| `test/game/public_demo` + `test/ui/public_demo` (full) | Full run 1 (before the two fixes above): 1376 tests, 2 failed — both diagnosed and fixed (§4 above), neither caused by this change's own logic (both were pre-existing test assertions that literally encoded "every waiting engineer reads 待機", the exact assumption this fix intentionally changes; the `success_playthrough` one also needed re-scoping to the 社員コンディション card so its own, unrelated "no raw morale/trust number" intent kept working). Full re-run after both fixes: all previously-failing files green (35/35, §4 table above). |
| `test/widget_test.dart` | 11/11 passed |

Final confirmation run — `test/game/public_demo` + `test/ui/public_demo` + `test/widget_test.dart` together, after both fixes above — **1389 tests, all passed, exit code 0.** After the post-PR Codex-review fix (§5, which adds 4 more regression tests), this same full suite was re-run once more: **1393 tests, all passed, exit code 0.**

## 5. Post-PR review fix (Codex P2 — dead-end month gap)

PR #233's automated Codex review found a real defect (P2) in the first push: `_currentEmployeeStatusLabel` showed `営業可能` for any still-`waiting`, ready engineer in **every** month, but `_employeeNextActionsSection`'s `ec(i)` card — the only control that can actually start selling (`スキルシート確認`/`営業開始`) — only renders in April (unconditionally), June (only for a later-joined hire still in the applicant→engineer funnel), and July–February (RECOVERY-LOOP-1). **May (5) and March (15) never render it at all**, and June never renders it for a founding engineer. A ready-but-still-waiting engineer entering one of those months (e.g. a player who does not act on 佐藤's April card before closing the month, or 鈴木 crossing the threshold exactly entering March) would have read `営業可能` in the roster with no control anywhere on screen to act on it — a new, narrower dead end of exactly the kind Issue #231's own verification matrix forbids.

**Fix**: added `_fieldSalesActionReachableThisMonth(engineer)`, mirroring `ec(i)`'s three render conditions exactly (simplified using the facts already established by the `waiting`-stage caller — never `ordered`, never currently assigned). `_currentEmployeeStatusLabel`/`_employeeStatusTone` now show `営業可能`/`readyForSales` only when this holds; otherwise they fall back to the original, pre-existing `engineerStatus`/`.waiting` (i.e. `待機`) — never a fabricated new label. `研修が必要` needed no equivalent gating: `_employeeGrowthSection`'s internal-training card is unconditionally reachable every month from May through March (`s.month >= 5`), independently of `ec(i)`, so recommending training is never a dead end.

Added 4 new regression tests to `public_demo_issue231_employee_skillsheet_clarity_test.dart` covering exactly the scenarios Codex named: May, March, and June (founding engineer) all correctly fall back to `待機`; July (inside the RECOVERY-LOOP-1 window) still correctly reads `営業可能`, proving the gate is reachability-specific, not a blanket suppression. `flutter analyze` clean; every previously-passing suite (§4's table, full `test/game/public_demo` + `test/ui/public_demo` + `test/widget_test.dart`) re-run green after this fix.

## 6. 360x800 / 390x844 verification

The existing `public_demo_employee_ui_phase1_test.dart` and `public_demo_employee_visual_complete_test.dart` viewport suites (360x800 and 390x844, TextScaler 1.0/1.3/2.0) already exercise the exact fixture (`oneAssignedOneWaitingAtMonth(8)`) whose roster now renders the new reason caption for 鈴木 (still not ready at month 8 in that fixture) — all of these passed unmodified after the change, including at TextScaler 2.0, with no `RenderFlex`/overflow exception and the roster row `Rect` staying within `[0, size.width]`. No new viewport-specific test was needed since the existing suite already covers the new content at both target sizes.

## 7. Authority / persistence impact

* **Authority**: zero new domain rules. Every new/changed line reads `PublicDemoEngineerRuntime.isReadyForFieldSales`/`actualCapability`/`fieldSalesCapabilityRequirement` — the exact same authority `ec(i)`'s pre-existing lock banner already read — through the exact same pre-existing `capabilityFor`/`readyForFieldSales` helpers. No UI-local eligibility formula, no duplicated `60`/`78`/`52` literal in production code (only in tests, matching this codebase's own established convention for asserting against known founding data).
* **Persistence**: no field added to `PublicDemoEngineerRuntime`, `PublicDemoEngineerSales`, `PublicDemoState`, or `PublicDemoWorkflowState`; `PublicDemoSaveCodec.schemaVersion` unchanged (`1`). Confirmed via a new encode/decode round-trip test (§4.3).
* **HOME**: untouched. `_officeStageStatusFor`/HOME's Office Stage strip, HOME's KPI tiles, and `home_recommended_action.dart`'s design table are all unmodified — verified by the (now-updated) `public_demo_01_home_consolidation_test.dart` HOME-side assertions, which are unchanged and still passing.
* **Sales/Recruitment/Finance/monthly-close**: untouched (no file under `lib/game/public_demo/` was edited).

## 8. Verification matrix (Issue #231 §Verification matrix)

| Item | Result |
|---|---|
| Fresh start / Opening Context 4月, 佐藤=営業可能, 鈴木=研修が必要 | Covered by new test §4.1 and existing `public_demo_employee_ui_phase1_test.dart` |
| threshold境界 | Covered by new test §4.2 (crosses the real threshold via real training) |
| 研修前→研修後の表示/次行動 | Covered by new test §4.2 (label flips 研修が必要→営業可能; Section 2's existing lock-banner/営業準備OK swap is untouched and still exercised by the pre-existing suite) |
| SkillSheetを開く/開かないでdead-endなし | Unchanged code path — pre-existing suite (`public_demo_employee_ui_phase1_test.dart` Section 4 group) still passes |
| gate変更時のprogression reconcile | N/A — gate kept unchanged (§2 decision) |
| reload / existing save | Covered by new test §4.3 |
| duplicate / malformed state / ID mismatch防御 | Unaffected — `PublicDemoSaveCodec._hasConsistentAuthorityFacts` and every other existing defense reads fields this change never touches; full `test/game/public_demo` suite (incl. save-codec/duplicate/ID-mismatch tests) run green (§4) |
| 360x800 / 390x844 | §5 |
| Package A Opening Context regression | `PublicDemoOpeningMarker`/opening-context code paths untouched; not part of this diff |
| April→May progression regression | `publicDemoAggregateAtMonth`/RECOVERY-LOOP-1 fixtures (which chain real `closeApril`/`closeMay` calls) pass unmodified across the full suite run |
| Finance/Recruitment/Assignment/monthly-close state mutation | None — no file under `lib/game/public_demo/` was edited |

## 9. Unresolved / Known Limitations

* The SkillSheet-confirm hard gate itself is unchanged (kept, with evidence — §2). If a future Fresh Audit of HOME's Recommended Action design authority and the Cash Advisor decides to also revisit that pipeline, this report's §2 evidence and the specific authorities it names (`home_recommended_action.dart`'s design table, `PublicDemoCashAdviceSelector`) are the starting point.
* `実力` as the player-facing term for capability is left unchanged (Issue #231 makes this optional — "必要なら"). Fresh Audit found it already appears consistently, always alongside the concrete threshold/current numbers (never bare), and is not duplicated elsewhere with a different term.

## 10. Actual elapsed time

Approximately 2 hours (Fresh Audit + implementation + focused/new tests + three full-suite regression runs + the post-PR Codex-review fix (§5) + report), within Issue #231's own 1.5–2.5h estimate. Excludes CI wait time. Includes the one-time setup cost of installing a matching Flutter 3.44.8 SDK in this session's environment (none was preinstalled).

## 11. PR

https://github.com/perusonao/smile_enjoy_story/pull/233
